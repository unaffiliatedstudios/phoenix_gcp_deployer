defmodule PhoenixGcpDeployer.TemplateEngine.Engine do
  @moduledoc """
  Generates deployment configuration files from EEx templates.

  All templates live under `priv/templates/`. Rendering is done with EEx
  using safe binding so that user inputs cannot inject arbitrary code.
  """

  @templates_dir :phoenix_gcp_deployer |> :code.priv_dir() |> Path.join("templates")

  @type render_context :: %{
          app_name: String.t(),
          environment: String.t(),
          gcp_project_id: String.t(),
          gcp_region: String.t(),
          gcp_zone: String.t(),
          elixir_version: String.t(),
          otp_version: String.t(),
          db_tier: String.t(),
          db_version: String.t(),
          db_disk_size_gb: pos_integer(),
          min_instances: non_neg_integer(),
          max_instances: pos_integer(),
          memory_mb: pos_integer(),
          cpu_count: pos_integer(),
          use_vpc: boolean(),
          enable_cdn: boolean(),
          enable_armor: boolean(),
          enable_secret_manager: boolean(),
          ssl_policy: String.t(),
          domain_name: String.t() | nil
        }

  @type generated_files :: %{
          dockerfile: String.t(),
          terraform_main: String.t(),
          terraform_variables: String.t(),
          terraform_outputs: String.t(),
          cloudbuild: String.t()
        }

  @doc """
  Generates all deployment files for the given context.

  Returns a map with file names and their rendered content.
  """
  @spec generate_all(render_context()) :: {:ok, generated_files()} | {:error, term()}
  def generate_all(context) do
    with {:ok, dockerfile} <- render_template("dockerfile.eex", context),
         {:ok, tf_main} <- render_template("terraform/main.tf.eex", context),
         {:ok, tf_vars} <- render_template("terraform/variables.tf.eex", context),
         {:ok, tf_outputs} <- render_template("terraform/outputs.tf.eex", context),
         {:ok, cloudbuild} <- render_template("cloudbuild.yaml.eex", context) do
      {:ok,
       %{
         dockerfile: dockerfile,
         terraform_main: tf_main,
         terraform_variables: tf_vars,
         terraform_outputs: tf_outputs,
         cloudbuild: cloudbuild
       }}
    end
  end

  @doc """
  Renders a single named template with the provided context.

  Template names are relative to `priv/templates/`.
  """
  @spec render_template(String.t(), render_context()) :: {:ok, String.t()} | {:error, term()}
  def render_template(template_name, context) do
    template_path = Path.join(@templates_dir, template_name)

    if File.exists?(template_path) do
      try do
        binding = Map.to_list(context)
        result = EEx.eval_file(template_path, binding)
        {:ok, result}
      rescue
        e -> {:error, {:render_error, Exception.message(e)}}
      end
    else
      {:error, {:template_not_found, template_name}}
    end
  end

  @doc """
  Builds the render context from a deployment struct and analysis result.
  """
  @spec build_context(map(), map()) :: render_context()
  def build_context(deployment, analysis \\ %{}) do
    %{
      app_name: Map.get(analysis, :name, "myapp"),
      environment: deployment.environment,
      gcp_project_id: deployment.gcp_project_id || "",
      gcp_region: deployment.gcp_region,
      gcp_zone: deployment.gcp_zone,
      elixir_version: Map.get(analysis, :elixir_version, "1.18"),
      otp_version: "27",
      db_tier: deployment.db_tier,
      db_version: deployment.db_version,
      db_disk_size_gb: deployment.db_disk_size_gb,
      min_instances: deployment.min_instances,
      max_instances: deployment.max_instances,
      memory_mb: deployment.memory_mb,
      cpu_count: deployment.cpu_count,
      use_vpc: deployment.use_vpc,
      enable_cdn: deployment.enable_cdn,
      enable_armor: deployment.enable_armor,
      enable_secret_manager: deployment.enable_secret_manager,
      ssl_policy: deployment.ssl_policy,
      domain_name: deployment.domain_name
    }
  end
end
