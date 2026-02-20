defmodule PhoenixGcpDeployer.SecurityChecker.CheckerTest do
  use ExUnit.Case, async: true

  alias PhoenixGcpDeployer.SecurityChecker.Checker

  @base_config %{
    ssl_policy: "modern",
    enable_secret_manager: true,
    enable_armor: false,
    min_instances: 1,
    gcp_project_id: "my-project",
    domain_name: "myapp.example.com"
  }

  describe "check/1" do
    test "returns a result map with expected keys" do
      result = Checker.check(@base_config)

      assert Map.has_key?(result, :passed)
      assert Map.has_key?(result, :warnings)
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :score)
    end

    test "score is between 0 and 100" do
      result = Checker.check(@base_config)
      assert result.score >= 0
      assert result.score <= 100
    end

    test "a well-configured deployment has no critical errors" do
      result = Checker.check(@base_config)
      critical_or_high = Enum.filter(result.errors, &(&1.severity in [:critical, :high]))
      assert length(critical_or_high) == 0
    end

    test "missing secret manager triggers high severity error" do
      config = %{@base_config | enable_secret_manager: false}
      result = Checker.check(config)

      high_errors = Enum.filter(result.errors, &(&1.severity == :high))
      assert Enum.any?(high_errors, &(&1.code == :secret_manager_disabled))
    end

    test "compatible SSL policy triggers medium severity warning" do
      config = %{@base_config | ssl_policy: "compatible"}
      result = Checker.check(config)

      medium_warnings = Enum.filter(result.warnings, &(&1.severity == :medium))
      assert Enum.any?(medium_warnings, &(&1.code == :ssl_compatible))
    end

    test "modern SSL policy passes with info severity" do
      result = Checker.check(%{@base_config | ssl_policy: "modern"})
      passed_codes = Enum.map(result.passed ++ result.warnings, & &1.code)
      assert :ssl_modern in passed_codes
    end

    test "missing GCP project triggers medium severity warning" do
      config = Map.put(@base_config, :gcp_project_id, nil)
      result = Checker.check(config)

      medium_warnings = Enum.filter(result.warnings, &(&1.severity == :medium))
      assert Enum.any?(medium_warnings, &(&1.code == :gcp_project_missing))
    end

    test "min_instances zero triggers low severity info" do
      config = %{@base_config | min_instances: 0}
      result = Checker.check(config)

      all_issues = result.passed ++ result.warnings ++ result.errors
      assert Enum.any?(all_issues, &(&1.code == :min_instances_zero))
    end

    test "cloud armor enabled triggers info (positive)" do
      config = %{@base_config | enable_armor: true}
      result = Checker.check(config)

      all = result.passed ++ result.warnings ++ result.errors
      assert Enum.any?(all, &(&1.code == :cloud_armor_enabled))
    end

    test "all issues have required fields" do
      result = Checker.check(@base_config)
      all_issues = result.passed ++ result.warnings ++ result.errors

      Enum.each(all_issues, fn issue ->
        assert Map.has_key?(issue, :severity)
        assert Map.has_key?(issue, :code)
        assert Map.has_key?(issue, :message)
        assert Map.has_key?(issue, :recommendation)
      end)
    end
  end

  describe "scan_dockerfile/1" do
    test "detects root user warning" do
      dockerfile = """
      FROM debian:bookworm
      USER root
      RUN apt-get update
      """

      issues = Checker.scan_dockerfile(dockerfile)
      assert Enum.any?(issues, &(&1.code == :running_as_root))
    end

    test "passes when non-root user set" do
      dockerfile = """
      FROM debian:bookworm
      RUN adduser appuser
      USER appuser
      CMD ["./app"]
      """

      issues = Checker.scan_dockerfile(dockerfile)
      root_issues = Enum.filter(issues, &(&1.code == :running_as_root))
      assert length(root_issues) == 0
    end

    test "detects :latest tag warning" do
      dockerfile = "FROM node:latest\nRUN echo hi"
      issues = Checker.scan_dockerfile(dockerfile)
      assert Enum.any?(issues, &(&1.code == :latest_tag))
    end

    test "passes when specific tag used" do
      dockerfile = "FROM node:20.11-alpine\nUSER node"
      issues = Checker.scan_dockerfile(dockerfile)
      latest_issues = Enum.filter(issues, &(&1.code == :latest_tag))
      assert length(latest_issues) == 0
    end

    test "detects secrets in ENV" do
      dockerfile = """
      FROM alpine:3.19
      ENV DATABASE_PASSWORD=secret123
      USER nobody
      """

      issues = Checker.scan_dockerfile(dockerfile)
      assert Enum.any?(issues, &(&1.code == :secrets_in_dockerfile))
    end

    test "detects secrets in ARG" do
      dockerfile = """
      FROM alpine:3.19
      ARG SECRET_KEY=abc123
      USER nobody
      """

      issues = Checker.scan_dockerfile(dockerfile)
      assert Enum.any?(issues, &(&1.code == :secrets_in_dockerfile))
    end
  end

  describe "scan_terraform/1" do
    test "detects public IP on Cloud SQL" do
      terraform = """
      resource "google_sql_database_instance" "main" {
        settings {
          ip_configuration {
            ipv4_enabled = true
          }
        }
      }
      """

      issues = Checker.scan_terraform(terraform)
      assert Enum.any?(issues, &(&1.code == :public_db_ip))
    end

    test "detects missing SSL enforcement" do
      terraform = """
      resource "google_sql_database_instance" "main" {
        settings {
          ip_configuration {}
        }
      }
      """

      issues = Checker.scan_terraform(terraform)
      assert Enum.any?(issues, &(&1.code == :ssl_not_enforced))
    end

    test "detects wide open firewall rule" do
      terraform = """
      resource "google_compute_firewall" "allow_all" {
        source_ranges = ["0.0.0.0/0"]
      }
      """

      issues = Checker.scan_terraform(terraform)
      assert Enum.any?(issues, &(&1.code == :wide_firewall))
    end

    test "passes when SSL is enforced" do
      terraform = """
      resource "google_sql_database_instance" "main" {
        settings {
          ip_configuration {
            ipv4_enabled = false
            require_ssl = true
          }
        }
      }
      """

      issues = Checker.scan_terraform(terraform)
      ssl_issues = Enum.filter(issues, &(&1.code == :ssl_not_enforced))
      assert length(ssl_issues) == 0
    end
  end
end
