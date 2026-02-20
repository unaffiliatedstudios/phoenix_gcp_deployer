defmodule PhoenixGcpDeployer.CostCalculator.Pricing do
  @moduledoc """
  Embedded GCP pricing data (USD per month).

  Prices are approximate and based on us-central1 region.
  Last updated: 2024-01. Users should verify against current GCP pricing.
  """

  @cloud_run_cpu_per_vcpu_second 0.00002400
  @cloud_run_memory_per_gib_second 0.00000250
  @cloud_run_request_per_million 0.40
  @cloud_run_min_instances_vcpu_hour 0.01800
  @cloud_run_min_instances_memory_per_gib_hour 0.00200

  # Cloud SQL pricing (us-central1, hourly rates)
  @cloud_sql_tiers %{
    "db-f1-micro" => %{vcpu: 0.6, ram_gb: 0.6, price_per_hour: 0.0150},
    "db-g1-small" => %{vcpu: 1.7, ram_gb: 1.7, price_per_hour: 0.0500},
    "db-n1-standard-1" => %{vcpu: 1, ram_gb: 3.75, price_per_hour: 0.0965},
    "db-n1-standard-2" => %{vcpu: 2, ram_gb: 7.5, price_per_hour: 0.1930},
    "db-n1-standard-4" => %{vcpu: 4, ram_gb: 15.0, price_per_hour: 0.3860},
    "db-n1-highmem-2" => %{vcpu: 2, ram_gb: 13.0, price_per_hour: 0.2320},
    "db-n1-highmem-4" => %{vcpu: 4, ram_gb: 26.0, price_per_hour: 0.4640}
  }

  @cloud_sql_storage_per_gb_month 0.17
  @cloud_sql_backup_per_gb_month 0.08

  # Cloud Armor pricing
  @armor_policy_per_month 5.00
  @armor_per_million_requests 0.75

  # Cloud CDN
  @cdn_cache_egress_per_gb 0.02
  @cdn_cache_fill_per_gb 0.01

  # Secret Manager
  @secret_manager_per_10k_access 0.03
  @secret_manager_active_version_per_month 0.06

  @doc "Returns Cloud SQL tier pricing map."
  def cloud_sql_tiers, do: @cloud_sql_tiers

  @doc "Returns Cloud SQL storage price per GB per month."
  def cloud_sql_storage_per_gb_month, do: @cloud_sql_storage_per_gb_month

  @doc "Returns all pricing constants as a map for reference."
  def all do
    %{
      cloud_run: %{
        cpu_per_vcpu_second: @cloud_run_cpu_per_vcpu_second,
        memory_per_gib_second: @cloud_run_memory_per_gib_second,
        request_per_million: @cloud_run_request_per_million,
        min_instance_cpu_per_hour: @cloud_run_min_instances_vcpu_hour,
        min_instance_memory_per_gib_hour: @cloud_run_min_instances_memory_per_gib_hour
      },
      cloud_sql: %{
        tiers: @cloud_sql_tiers,
        storage_per_gb_month: @cloud_sql_storage_per_gb_month,
        backup_per_gb_month: @cloud_sql_backup_per_gb_month
      },
      cloud_armor: %{
        policy_per_month: @armor_policy_per_month,
        per_million_requests: @armor_per_million_requests
      },
      cdn: %{
        egress_per_gb: @cdn_cache_egress_per_gb,
        fill_per_gb: @cdn_cache_fill_per_gb
      },
      secret_manager: %{
        per_10k_access: @secret_manager_per_10k_access,
        active_version_per_month: @secret_manager_active_version_per_month
      }
    }
  end
end
