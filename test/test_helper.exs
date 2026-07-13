quackdb_only? = System.get_env("QUACKDB_ONLY") == "1"

unless quackdb_only? do
  Application.ensure_all_started(:postgrex)

  Oban.Test.Repo.start_link()
  Oban.Test.DolphinRepo.start_link()
  Oban.Test.LiteRepo.start_link()
  Oban.Test.UnboxedRepo.start_link()
end

quackdb_test? = quackdb_only? or System.get_env("QUACKDB_TEST") == "1"
exclude = if quackdb_test?, do: [:skip], else: [:skip, :quackdb]

quack_cleanup =
  if quackdb_test? do
    path = Path.join(System.tmp_dir!(), "oban-quack-#{System.unique_integer([:positive])}.duckdb")
    port = 20_000 + rem(System.unique_integer([:positive]), 30_000)
    token = "oban_quack_#{System.unique_integer([:positive])}"
    uri = "http://[::1]:#{port}"

    {:ok, server} =
      QuackDB.Server.start_link(
        duckdb: :managed,
        database: path,
        endpoint: "quack:localhost:#{port}",
        uri: uri,
        token: token,
        wait_timeout: 10_000
      )

    Application.put_env(
      :oban,
      Oban.Test.QuackRepo,
      Keyword.merge(Application.get_env(:oban, Oban.Test.QuackRepo, []),
        uri: uri,
        token: token
      )
    )

    Oban.Test.QuackRepo.start_link()
    Ecto.Migrator.up(Oban.Test.QuackRepo, 1, Oban.Test.QuackMigration, log: false)

    {server, path}
  end

ExUnit.start(assert_receive_timeout: 2_000, refute_receive_timeout: 50, exclude: exclude)

if quack_cleanup do
  {server, path} = quack_cleanup

  ExUnit.after_suite(fn _result ->
    if Process.alive?(server), do: GenServer.stop(server)
    File.rm(path)
  end)
end

unless quackdb_only? do
  Ecto.Adapters.SQL.Sandbox.mode(Oban.Test.DolphinRepo, :manual)
  Ecto.Adapters.SQL.Sandbox.mode(Oban.Test.Repo, :manual)
end

:pg.start_link(Oban.Notifiers.PG)
