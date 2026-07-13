defmodule Oban.Migrations.QuackDBTest do
  use ExUnit.Case, async: false

  alias Oban.Test.{QuackMigration, QuackRepo}

  @moduletag :quackdb

  test "migrates QuackDB storage up and down" do
    assert Oban.Migration.current_version(repo: QuackRepo) == 1
    assert Oban.Migration.migrated_version(repo: QuackRepo) == 1
    assert table_exists?("oban_jobs")
    assert table_exists?("oban_locks")

    assert :ok = Ecto.Migrator.down(QuackRepo, 1, QuackMigration, log: false)
    refute table_exists?("oban_jobs")
    refute table_exists?("oban_locks")

    assert :ok = Ecto.Migrator.up(QuackRepo, 1, QuackMigration, log: false)
    assert table_exists?("oban_jobs")
    assert table_exists?("oban_locks")

    assert %{rows: [["JSON[]"]]} =
             QuackRepo.query!("""
             SELECT data_type
             FROM information_schema.columns
             WHERE table_name = 'oban_jobs' AND column_name = 'errors'
             """)
  end

  defp table_exists?(table) do
    %{rows: [[count]]} =
      QuackRepo.query!(
        """
        SELECT count(*)
        FROM information_schema.tables
        WHERE table_name = ?
        """,
        [table]
      )

    count == 1
  end
end
