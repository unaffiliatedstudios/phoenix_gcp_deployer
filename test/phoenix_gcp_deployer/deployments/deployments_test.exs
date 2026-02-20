defmodule PhoenixGcpDeployer.DeploymentsTest do
  use PhoenixGcpDeployer.DataCase, async: true

  alias PhoenixGcpDeployer.Deployments
  alias PhoenixGcpDeployer.Deployments.{Deployment, Project}

  describe "create_project/1" do
    test "creates a project with valid attrs" do
      assert {:ok, %Project{} = project} =
               Deployments.create_project(%{github_url: "https://github.com/owner/myapp"})

      assert project.github_url == "https://github.com/owner/myapp"
      assert project.status == "pending"
    end

    test "returns error for missing github_url" do
      assert {:error, changeset} = Deployments.create_project(%{})
      assert "can't be blank" in errors_on(changeset).github_url
    end

    test "returns error for non-GitHub URL" do
      assert {:error, changeset} =
               Deployments.create_project(%{github_url: "https://gitlab.com/owner/repo"})

      assert "must be a GitHub URL" in errors_on(changeset).github_url
    end

    test "returns error for duplicate github_url" do
      attrs = %{github_url: "https://github.com/owner/unique"}
      {:ok, _} = Deployments.create_project(attrs)

      assert {:error, changeset} = Deployments.create_project(attrs)
      assert "has already been taken" in errors_on(changeset).github_url
    end
  end

  describe "update_project/2" do
    test "updates project status" do
      {:ok, project} = Deployments.create_project(%{github_url: "https://github.com/owner/app1"})

      assert {:ok, updated} = Deployments.update_project(project, %{status: "analyzed"})
      assert updated.status == "analyzed"
    end

    test "returns error for invalid status" do
      {:ok, project} = Deployments.create_project(%{github_url: "https://github.com/owner/app2"})

      assert {:error, changeset} = Deployments.update_project(project, %{status: "invalid"})
      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "list_projects/0" do
    test "returns all projects" do
      {:ok, p1} = Deployments.create_project(%{github_url: "https://github.com/a/b"})
      {:ok, p2} = Deployments.create_project(%{github_url: "https://github.com/c/d"})

      projects = Deployments.list_projects()
      ids = Enum.map(projects, & &1.id)

      assert p1.id in ids
      assert p2.id in ids
    end

    test "returns empty list when no projects" do
      assert Deployments.list_projects() == []
    end
  end

  describe "create_deployment/1" do
    setup do
      {:ok, project} =
        Deployments.create_project(%{github_url: "https://github.com/owner/test"})

      %{project: project}
    end

    test "creates deployment with valid attrs", %{project: project} do
      assert {:ok, %Deployment{} = dep} =
               Deployments.create_deployment(%{
                 project_id: project.id,
                 name: "Production Deploy",
                 environment: "production",
                 gcp_region: "us-central1"
               })

      assert dep.name == "Production Deploy"
      assert dep.environment == "production"
      assert dep.status == "draft"
    end

    test "validates max_instances >= min_instances", %{project: project} do
      assert {:error, changeset} =
               Deployments.create_deployment(%{
                 project_id: project.id,
                 name: "Bad Config",
                 environment: "production",
                 gcp_region: "us-central1",
                 min_instances: 10,
                 max_instances: 5
               })

      assert "must be greater than or equal to min_instances" in errors_on(changeset).max_instances
    end

    test "validates memory_mb minimum", %{project: project} do
      assert {:error, changeset} =
               Deployments.create_deployment(%{
                 project_id: project.id,
                 name: "Low Mem",
                 environment: "production",
                 gcp_region: "us-central1",
                 memory_mb: 64
               })

      assert "must be greater than or equal to 256" in errors_on(changeset).memory_mb
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
