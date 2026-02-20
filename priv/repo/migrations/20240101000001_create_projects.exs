defmodule PhoenixGcpDeployer.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string, null: false
      add :github_url, :string, null: false
      add :phoenix_version, :string
      add :elixir_version, :string
      add :otp_version, :string
      add :has_ecto, :boolean, default: false, null: false
      add :has_oban, :boolean, default: false, null: false
      add :has_live_view, :boolean, default: false, null: false
      add :status, :string, null: false, default: "pending"
      add :analysis_result, :map

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:github_url])
    create index(:projects, [:status])
  end
end
