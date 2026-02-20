defmodule PhoenixGcpDeployer.Deployments.Deployment do
  @moduledoc "Represents a GCP deployment configuration for a project."

  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(draft generating ready archived)
  @valid_environments ~w(production staging development)
  @valid_ssl_policies ~w(modern compatible restricted)

  schema "deployments" do
    belongs_to :project, PhoenixGcpDeployer.Deployments.Project

    field :name, :string
    field :environment, :string, default: "production"
    field :gcp_project_id, :string
    field :gcp_region, :string, default: "us-central1"
    field :gcp_zone, :string, default: "us-central1-a"

    field :db_tier, :string, default: "db-f1-micro"
    field :db_version, :string, default: "POSTGRES_15"
    field :db_disk_size_gb, :integer, default: 10

    field :min_instances, :integer, default: 0
    field :max_instances, :integer, default: 10
    field :memory_mb, :integer, default: 512
    field :cpu_count, :integer, default: 1

    field :use_vpc, :boolean, default: true
    field :enable_cdn, :boolean, default: false
    field :domain_name, :string

    field :enable_secret_manager, :boolean, default: true
    field :enable_armor, :boolean, default: false
    field :ssl_policy, :string, default: "modern"

    field :estimated_monthly_cost_usd, :decimal
    field :terraform_config, :string
    field :dockerfile, :string
    field :cloudbuild_config, :string

    field :status, :string, default: "draft"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deployment, attrs) do
    deployment
    |> cast(attrs, [
      :project_id,
      :name,
      :environment,
      :gcp_project_id,
      :gcp_region,
      :gcp_zone,
      :db_tier,
      :db_version,
      :db_disk_size_gb,
      :min_instances,
      :max_instances,
      :memory_mb,
      :cpu_count,
      :use_vpc,
      :enable_cdn,
      :domain_name,
      :enable_secret_manager,
      :enable_armor,
      :ssl_policy,
      :estimated_monthly_cost_usd,
      :terraform_config,
      :dockerfile,
      :cloudbuild_config,
      :status
    ])
    |> validate_required([:name, :environment, :gcp_region])
    |> validate_inclusion(:environment, @valid_environments)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:ssl_policy, @valid_ssl_policies)
    |> validate_number(:min_instances, greater_than_or_equal_to: 0)
    |> validate_number(:max_instances, greater_than: 0)
    |> validate_number(:memory_mb, greater_than_or_equal_to: 256)
    |> validate_number(:db_disk_size_gb, greater_than: 0)
    |> validate_max_gte_min()
  end

  defp validate_max_gte_min(changeset) do
    min = get_field(changeset, :min_instances)
    max = get_field(changeset, :max_instances)

    if min && max && max < min do
      add_error(changeset, :max_instances, "must be greater than or equal to min_instances")
    else
      changeset
    end
  end
end
