defmodule Oban.Engines.QuackDBTest do
  use ExUnit.Case, async: false

  alias Oban.Engines.QuackDB, as: QuackEngine
  alias Oban.{Config, Errors, Job}
  alias Oban.Test.QuackRepo

  @moduletag :quackdb

  setup do
    QuackRepo.delete_all(Job)

    conf =
      Config.new(
        engine: QuackEngine,
        name: make_ref(),
        node: "quack-test",
        peer: false,
        repo: QuackRepo
      )

    {:ok, conf: conf}
  end

  test "claims each job once across concurrent producers", %{conf: conf} do
    changesets = for id <- 1..10, do: job(%{id: id})
    jobs = QuackEngine.insert_all_jobs(conf, changesets, [])

    assert length(jobs) == 10
    assert {:ok, first_meta} = QuackEngine.init(conf, limit: 5, queue: "default")
    assert {:ok, second_meta} = QuackEngine.init(conf, limit: 5, queue: "default")

    parent = self()

    tasks =
      for meta <- [first_meta, second_meta] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :fetch -> QuackEngine.fetch_jobs(conf, meta, %{})
          end
        end)
      end

    pids =
      for _ <- tasks do
        assert_receive {:ready, pid}
        pid
      end

    Enum.each(pids, &send(&1, :fetch))

    claimed =
      tasks
      |> Task.await_many(10_000)
      |> Enum.flat_map(fn {:ok, {_meta, jobs}} -> jobs end)

    assert length(claimed) == 10
    assert claimed |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 10
  end

  test "serializes concurrent unique inserts", %{conf: conf} do
    parent = self()
    unique = [period: :infinity, fields: [:worker, :args]]

    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :insert ->
              QuackEngine.insert_job(conf, job(%{id: 1}, unique: unique), expected_retry: 20)
          end
        end)
      end

    pids =
      for _ <- tasks do
        assert_receive {:ready, pid}
        pid
      end

    Enum.each(pids, &send(&1, :insert))

    assert [{:ok, first}, {:ok, second}] = Task.await_many(tasks, 10_000)
    assert first.id == second.id
    assert Enum.sort([first.conflict?, second.conflict?]) == [false, true]
    assert QuackRepo.aggregate(Job, :count) == 1
  end

  test "classifies only retriable QuackDB errors as expected" do
    assert Errors.expected_error?(QuackDB.Error.new(:conflict, "conflict", retriable?: true))
    refute Errors.expected_error?(QuackDB.Error.new(:server_error, "boom"))
  end

  test "fails explicitly when the uniqueness lock is missing", %{conf: conf} do
    QuackRepo.query!("DELETE FROM oban_locks WHERE name = 'unique'")

    try do
      assert_raise RuntimeError, ~r/missing QuackDB uniqueness lock/, fn ->
        QuackEngine.insert_job(conf, job(%{id: 1}, unique: [period: :infinity]), [])
      end
    after
      QuackRepo.query!("INSERT INTO oban_locks (name) VALUES ('unique') ON CONFLICT DO NOTHING")
    end
  end

  defp job(args, opts \\ []) do
    Job.new(args, Keyword.merge([worker: "QuackWorker", queue: "default"], opts))
  end
end
