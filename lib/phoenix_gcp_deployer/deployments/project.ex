defmodule PhoenixGcpDeployer.Deployments.Project do
  @moduledoc "Represents a GitHub repository that has been analyzed."

  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(pending analyzing analyzed failed)

  schema "projects" do
    field :name, :string
    field :github_url, :string
    field :phoenix_version, :string
    field :elixir_version, :string
    field :otp_version, :string
    field :has_ecto, :boolean, default: false
    field :has_oban, :boolean, default: false
    field :has_live_view, :boolean, default: false
    field :status, :string, default: "pending"
    field :analysis_result, :map

    has_many :deployments, PhoenixGcpDeployer.Deployments.Deployment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :github_url,
      :phoenix_version,
      :elixir_version,
      :otp_version,
      :has_ecto,
      :has_oban,
      :has_live_view,
      :status,
      :analysis_result
    ])
    |> validate_required([:github_url])
    |> validate_length(:github_url, max: 500)
    |> validate_format(:github_url, ~r|^https://github\.com/|, message: "must be a GitHub URL")
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:github_url)
  end
end
