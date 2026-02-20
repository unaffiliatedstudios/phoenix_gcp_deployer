defmodule PhoenixGcpDeployer.TemplateEngine.EngineTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  alias PhoenixGcpDeployer.TemplateEngine.Engine

  @base_context %{
    app_name: "my_app",
    environment: "production",
    gcp_project_id: "my-gcp-project",
    gcp_region: "us-central1",
    gcp_zone: "us-central1-a",
    elixir_version: "1.17",
    otp_version: "27",
    db_tier: "db-f1-micro",
    db_version: "POSTGRES_15",
    db_disk_size_gb: 10,
    min_instances: 1,
    max_instances: 10,
    memory_mb: 512,
    cpu_count: 1,
    use_vpc: true,
    enable_cdn: false,
    enable_armor: false,
    enable_secret_manager: true,
    ssl_policy: "modern",
    domain_name: nil
  }

  describe "generate_all/1" do
    test "generates all expected file types" do
      assert {:ok, files} = Engine.generate_all(@base_context)

      assert Map.has_key?(files, :dockerfile)
      assert Map.has_key?(files, :terraform_main)
      assert Map.has_key?(files, :terraform_variables)
      assert Map.has_key?(files, :terraform_outputs)
      assert Map.has_key?(files, :cloudbuild)
    end

    test "all generated files are non-empty strings" do
      assert {:ok, files} = Engine.generate_all(@base_context)

      Enum.each(files, fn {key, content} ->
        assert is_binary(content), "#{key} should be a string"
        assert String.length(content) > 0, "#{key} should not be empty"
      end)
    end

    test "dockerfile contains app name" do
      assert {:ok, %{dockerfile: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "my_app")
    end

    test "dockerfile contains elixir version" do
      assert {:ok, %{dockerfile: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "1.17")
    end

    test "dockerfile contains non-root USER instruction" do
      assert {:ok, %{dockerfile: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "USER appuser")
    end

    test "terraform main contains app name" do
      assert {:ok, %{terraform_main: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "my_app")
    end

    test "terraform main contains GCP project ID" do
      assert {:ok, %{terraform_main: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "my-gcp-project")
    end

    test "terraform includes VPC when use_vpc is true" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | use_vpc: true})

      assert String.contains?(content, "google_compute_network")
    end

    test "terraform excludes VPC when use_vpc is false" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | use_vpc: false})

      refute String.contains?(content, "vpc_access_connector")
    end

    test "terraform includes secret manager when enabled" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | enable_secret_manager: true})

      assert String.contains?(content, "google_secret_manager_secret")
    end

    test "terraform excludes secret manager when disabled" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | enable_secret_manager: false})

      refute String.contains?(content, "google_secret_manager_secret")
    end

    test "terraform includes cloud armor when enabled" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | enable_armor: true})

      assert String.contains?(content, "google_compute_security_policy")
    end

    test "terraform variables contain correct defaults" do
      assert {:ok, %{terraform_variables: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "us-central1")
      assert String.contains?(content, "db-f1-micro")
    end

    test "cloudbuild contains GCP project ID" do
      assert {:ok, %{cloudbuild: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "my-gcp-project")
    end

    test "cloudbuild contains region" do
      assert {:ok, %{cloudbuild: content}} = Engine.generate_all(@base_context)
      assert String.contains?(content, "us-central1")
    end

    test "production deployment has deletion_protection enabled in terraform" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | environment: "production"})

      assert String.contains?(content, "deletion_protection = true")
    end

    test "staging deployment has deletion_protection disabled in terraform" do
      assert {:ok, %{terraform_main: content}} =
               Engine.generate_all(%{@base_context | environment: "staging"})

      assert String.contains?(content, "deletion_protection = false")
    end
  end

  describe "render_template/2" do
    test "returns error for non-existent template" do
      assert {:error, {:template_not_found, "nonexistent.eex"}} =
               Engine.render_template("nonexistent.eex", @base_context)
    end
  end

  describe "generate_all/1 property tests" do
    property "app_name always appears in all generated files" do
      check all(
              app_name <-
                StreamData.string(:alphanumeric, min_length: 3, max_length: 20)
                |> StreamData.filter(&Regex.match?(~r/^[a-z]/, &1))
            ) do
        context = %{@base_context | app_name: app_name}

        case Engine.generate_all(context) do
          {:ok, files} ->
            Enum.each(files, fn {_key, content} ->
              assert String.contains?(content, app_name)
            end)

          {:error, _} ->
            true
        end
      end
    end
  end
end
