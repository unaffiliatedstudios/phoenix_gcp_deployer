defmodule PhoenixGcpDeployer.Deployments do
  @moduledoc """
  Context module for managing deployment projects and configurations.
  """

  import Ecto.Query
  alias PhoenixGcpDeployer.Repo
  alias PhoenixGcpDeployer.Deployments.{Deployment, Project}

  # --- Projects ---

  @doc "Returns all projects, most recently updated first."
  def list_projects do
    Repo.all(from p in Project, order_by: [desc: p.updated_at])
  end

  @doc "Gets a single project by ID. Raises if not found."
  def get_project!(id), do: Repo.get!(Project, id)

  @doc "Gets a project by ID. Returns nil if not found."
  def get_project(id), do: Repo.get(Project, id)

  @doc "Creates a project from a GitHub URL."
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a project."
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a project."
  def delete_project(%Project{} = project), do: Repo.delete(project)

  @doc "Returns a changeset for project form validation."
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  # --- Deployments ---

  @doc "Returns all deployments for a given project."
  def list_deployments(%Project{id: project_id}) do
    Repo.all(from d in Deployment, where: d.project_id == ^project_id, order_by: [desc: d.updated_at])
  end

  @doc "Gets a single deployment by ID. Raises if not found."
  def get_deployment!(id), do: Repo.get!(Deployment, id)

  @doc "Creates a deployment configuration."
  def create_deployment(attrs \\ %{}) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a deployment."
  def update_deployment(%Deployment{} = deployment, attrs) do
    deployment
    |> Deployment.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a deployment."
  def delete_deployment(%Deployment{} = deployment), do: Repo.delete(deployment)

  @doc "Returns a changeset for deployment form validation."
  def change_deployment(%Deployment{} = deployment, attrs \\ %{}) do
    Deployment.changeset(deployment, attrs)
  end
end
