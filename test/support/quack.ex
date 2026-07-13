if Code.ensure_loaded?(Ecto.Adapters.QuackDB) do
  defmodule Oban.Test.Quack do
    @moduledoc false

    alias Oban.Test.{QuackMigration, QuackRepo}

    def start do
      path =
        Path.join(System.tmp_dir!(), "oban-quack-#{System.unique_integer([:positive])}.duckdb")

      port = available_port()
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

      config = Application.get_env(:oban, QuackRepo, [])
      Application.put_env(:oban, QuackRepo, Keyword.merge(config, uri: uri, token: token))

      {:ok, repo} = QuackRepo.start_link()
      Ecto.Migrator.up(QuackRepo, 1, QuackMigration, log: false)

      {repo, server, path}
    end

    def stop({repo, server, path}) do
      if Process.alive?(repo), do: GenServer.stop(repo)
      if Process.alive?(server), do: GenServer.stop(server)

      File.rm(path)
      File.rm(path <> ".wal")
    end

    defp available_port do
      {:ok, socket} = :gen_tcp.listen(0, active: false)
      {:ok, port} = :inet.port(socket)
      :ok = :gen_tcp.close(socket)
      port
    end
  end
end
