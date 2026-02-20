defmodule PhoenixGcpDeployer.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :environment, :string, null: false, default: "production"
      add :gcp_project_id, :string
      add :gcp_region, :string, null: false, default: "us-central1"
      add :gcp_zone, :string, null: false, default: "us-central1-a"

      # Database config
      add :db_tier, :string, null: false, default: "db-f1-micro"
      add :db_version, :string, null: false, default: "POSTGRES_15"
      add :db_disk_size_gb, :integer, null: false, default: 10

      # App config
      add :min_instances, :integer, null: false, default: 0
      add :max_instances, :integer, null: false, default: 10
      add :memory_mb, :integer, null: false, default: 512
      add :cpu_count, :integer, null: false, default: 1

      # Networking
      add :use_vpc, :boolean, default: true, null: false
      add :enable_cdn, :boolean, default: false, null: false
      add :domain_name, :string

      # Security
      add :enable_secret_manager, :boolean, default: true, null: false
      add :enable_armor, :boolean, default: false, null: false
      add :ssl_policy, :string, default: "modern"

      # Cost estimate
      add :estimated_monthly_cost_usd, :decimal, precision: 10, scale: 2

      # Generated configs
      add :terraform_config, :text
      add :dockerfile, :text
      add :cloudbuild_config, :text

      add :status, :string, null: false, default: "draft"

      timestamps(type: :utc_datetime)
    end

    create index(:deployments, [:project_id])
    create index(:deployments, [:status])
    create index(:deployments, [:environment])
  end
end
