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

quack_cleanup = if quackdb_test?, do: Oban.Test.Quack.start()

ExUnit.start(assert_receive_timeout: 2_000, refute_receive_timeout: 50, exclude: exclude)

if quack_cleanup do
  ExUnit.after_suite(fn _result -> Oban.Test.Quack.stop(quack_cleanup) end)
end

unless quackdb_only? do
  Ecto.Adapters.SQL.Sandbox.mode(Oban.Test.DolphinRepo, :manual)
  Ecto.Adapters.SQL.Sandbox.mode(Oban.Test.Repo, :manual)
end

:pg.start_link(Oban.Notifiers.PG)
