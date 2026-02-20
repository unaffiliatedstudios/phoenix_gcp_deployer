defmodule PhoenixGcpDeployer.Repo.Migrations.AddUniqueIndexToProjects do
  use Ecto.Migration

  def change do
    drop index(:projects, [:github_url])
    create unique_index(:projects, [:github_url])
  end
end
