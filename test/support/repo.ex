defmodule Oban.Test.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :oban,
    adapter: Ecto.Adapters.Postgres
end

defmodule Oban.Test.DynamicRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :oban,
    adapter: Ecto.Adapters.Postgres

  def use_dynamic_repo(pid) do
    pid
  end

  def init(_, _) do
    {:ok, Oban.Test.Repo.config()}
  end
end

defmodule Oban.Test.LiteRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban, adapter: Ecto.Adapters.SQLite3
end

if Code.ensure_loaded?(Ecto.Adapters.QuackDB) do
  defmodule Oban.Test.QuackRepo do
    @moduledoc false

    use Ecto.Repo, otp_app: :oban, adapter: Ecto.Adapters.QuackDB
  end

  defmodule Oban.Test.QuackMigration do
    @moduledoc false

    use Ecto.Migration

    def up, do: Oban.Migrations.up()
    def down, do: Oban.Migrations.down()
  end
end

defmodule Oban.Test.DolphinRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban, adapter: Ecto.Adapters.MyXQL
end

defmodule Oban.Test.UnboxedRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :oban,
    adapter: Ecto.Adapters.Postgres

  def init(_, _) do
    config = Oban.Test.Repo.config()

    {:ok, Keyword.delete(config, :pool)}
  end
end
