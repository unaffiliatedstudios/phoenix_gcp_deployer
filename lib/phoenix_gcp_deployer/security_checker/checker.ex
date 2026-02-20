defmodule PhoenixGcpDeployer.SecurityChecker.Checker do
  @moduledoc """
  Validates deployment configurations against security best practices.

  Checks generated Terraform, Dockerfile, and Cloud Build configs
  for common security misconfigurations.
  """

  @type config :: %{
          ssl_policy: String.t(),
          enable_secret_manager: boolean(),
          enable_armor: boolean(),
          min_instances: non_neg_integer(),
          gcp_project_id: String.t() | nil,
          domain_name: String.t() | nil
        }

  @type issue :: %{
          severity: :critical | :high | :medium | :low | :info,
          code: atom(),
          message: String.t(),
          recommendation: String.t()
        }

  @type check_result :: %{
          passed: [issue()],
          warnings: [issue()],
          errors: [issue()],
          score: non_neg_integer()
        }

  @doc """
  Runs all security checks against the given deployment configuration.

  Returns a result map with a security score (0-100), passed checks,
  warnings, and errors.
  """
  @spec check(config()) :: check_result()
  def check(config) do
    all_checks = [
      check_ssl_policy(config),
      check_secret_manager(config),
      check_cloud_armor(config),
      check_gcp_project_configured(config),
      check_domain_configured(config),
      check_min_instances_zero_cost(config)
    ]

    errors = Enum.filter(all_checks, &(&1.severity in [:critical, :high]))
    warnings = Enum.filter(all_checks, &(&1.severity == :medium))
    passed = Enum.filter(all_checks, &(&1.severity in [:low, :info]))

    score = calculate_score(errors, warnings, all_checks)

    %{
      passed: passed,
      warnings: warnings,
      errors: errors,
      score: score
    }
  end

  @doc """
  Scans generated Terraform content for security issues.
  """
  @spec scan_terraform(String.t()) :: [issue()]
  def scan_terraform(content) when is_binary(content) do
    []
    |> check_no_public_db_ip(content)
    |> check_ssl_enforced(content)
    |> check_no_wide_firewall_rules(content)
  end

  @doc """
  Scans a Dockerfile content for security issues.
  """
  @spec scan_dockerfile(String.t()) :: [issue()]
  def scan_dockerfile(content) when is_binary(content) do
    []
    |> check_no_root_user(content)
    |> check_no_exposed_secrets(content)
    |> check_specific_base_image(content)
  end

  # --- Config checks ---

  defp check_ssl_policy(%{ssl_policy: "modern"}),
    do: issue(:info, :ssl_modern, "SSL policy is set to modern", "No action needed.")

  defp check_ssl_policy(%{ssl_policy: "compatible"}),
    do: issue(:medium, :ssl_compatible, "SSL policy allows older cipher suites",
        "Consider upgrading to 'modern' SSL policy to prevent downgrade attacks.")

  defp check_ssl_policy(%{ssl_policy: "restricted"}),
    do: issue(:info, :ssl_restricted, "SSL policy is restricted (most secure)", "No action needed.")

  defp check_ssl_policy(_),
    do: issue(:medium, :ssl_unknown, "Unknown SSL policy configured",
        "Set ssl_policy to 'modern' or 'restricted'.")

  defp check_secret_manager(%{enable_secret_manager: true}),
    do: issue(:info, :secret_manager_enabled, "Secret Manager is enabled",
        "Environment secrets will be stored securely in GCP Secret Manager.")

  defp check_secret_manager(_),
    do: issue(:high, :secret_manager_disabled, "Secret Manager is not enabled",
        "Enable Secret Manager to avoid embedding secrets in environment variables or image layers.")

  defp check_cloud_armor(%{enable_armor: true}),
    do: issue(:info, :cloud_armor_enabled, "Cloud Armor WAF protection is enabled",
        "DDoS and WAF protection active.")

  defp check_cloud_armor(_),
    do: issue(:low, :cloud_armor_disabled, "Cloud Armor is not enabled",
        "Consider enabling Cloud Armor for production workloads for WAF/DDoS protection.")

  defp check_gcp_project_configured(%{gcp_project_id: id}) when is_binary(id) and id != "",
    do: issue(:info, :gcp_project_set, "GCP project ID is configured", "No action needed.")

  defp check_gcp_project_configured(_),
    do: issue(:medium, :gcp_project_missing, "GCP project ID is not set",
        "Set your GCP project ID to scope all resources correctly.")

  defp check_domain_configured(%{domain_name: domain}) when is_binary(domain) and domain != "",
    do: issue(:info, :domain_configured, "Custom domain is configured", "No action needed.")

  defp check_domain_configured(_),
    do: issue(:low, :no_custom_domain, "No custom domain configured",
        "Using a custom domain with managed SSL certificates is recommended for production.")

  defp check_min_instances_zero_cost(%{min_instances: 0}),
    do: issue(:low, :min_instances_zero, "Min instances is 0 (cold start possible)",
        "For production, set min_instances >= 1 to avoid cold start latency.")

  defp check_min_instances_zero_cost(_),
    do: issue(:info, :min_instances_set, "Min instances configured to prevent cold starts",
        "No action needed.")

  # --- Terraform content checks ---

  defp check_no_public_db_ip(acc, content) do
    if String.contains?(content, "ipv4_enabled = true") or
         String.contains?(content, ~s|"ipv4_enabled": true|) do
      [issue(:high, :public_db_ip, "Cloud SQL has a public IP enabled",
            "Disable public IP and use Cloud SQL Auth Proxy or Private Service Connect.") | acc]
    else
      [issue(:info, :no_public_db_ip, "Cloud SQL does not have a public IP", "") | acc]
    end
  end

  defp check_ssl_enforced(acc, content) do
    if String.contains?(content, "require_ssl = true") or
         String.contains?(content, "ssl_mode") do
      [issue(:info, :ssl_enforced, "SSL is enforced for database connections", "") | acc]
    else
      [issue(:medium, :ssl_not_enforced, "SSL enforcement not found in DB config",
            "Add `require_ssl = true` to your Cloud SQL settings.") | acc]
    end
  end

  defp check_no_wide_firewall_rules(acc, content) do
    if String.contains?(content, "0.0.0.0/0") do
      [issue(:high, :wide_firewall, "Firewall rule allows traffic from all IPs (0.0.0.0/0)",
            "Restrict firewall rules to specific IP ranges.") | acc]
    else
      [issue(:info, :restricted_firewall, "No wildcard firewall rules detected", "") | acc]
    end
  end

  # --- Dockerfile checks ---

  defp check_no_root_user(acc, content) do
    if String.contains?(content, "USER root") or not String.contains?(content, "USER ") do
      [issue(:high, :running_as_root, "Container may run as root",
            "Add a non-root USER instruction to your Dockerfile.") | acc]
    else
      [issue(:info, :non_root_user, "Container runs as non-root user", "") | acc]
    end
  end

  defp check_no_exposed_secrets(acc, content) do
    secret_patterns = [~r/ARG.*PASSWORD/i, ~r/ARG.*SECRET/i, ~r/ARG.*KEY/i, ~r/ENV.*PASSWORD/i]

    if Enum.any?(secret_patterns, &Regex.match?(&1, content)) do
      [issue(:critical, :secrets_in_dockerfile, "Potential secrets found in Dockerfile ARG/ENV",
            "Use GCP Secret Manager or build-time secret mounts instead of ARG/ENV for secrets.") | acc]
    else
      [issue(:info, :no_dockerfile_secrets, "No obvious secrets in Dockerfile", "") | acc]
    end
  end

  defp check_specific_base_image(acc, content) do
    if Regex.match?(~r/FROM .+:latest/, content) do
      [issue(:medium, :latest_tag, "Dockerfile uses :latest tag",
            "Pin to a specific image version for reproducible builds.") | acc]
    else
      [issue(:info, :pinned_base_image, "Base image is pinned to a specific version", "") | acc]
    end
  end

  # --- Helpers ---

  defp issue(severity, code, message, recommendation) do
    %{severity: severity, code: code, message: message, recommendation: recommendation}
  end

  defp calculate_score(errors, warnings, all_checks) do
    total = length(all_checks)
    penalty = length(errors) * 20 + length(warnings) * 5
    max(0, round(100 - penalty / total * 10))
  end
end
