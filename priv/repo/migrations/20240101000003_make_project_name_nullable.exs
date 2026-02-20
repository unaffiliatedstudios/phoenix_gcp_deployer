defmodule PhoenixGcpDeployer.Repo.Migrations.MakeProjectNameNullable do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      modify :name, :string, null: true
    end
  end
end
