defmodule PhoenixGcpDeployer.CostCalculator.Calculator do
  @moduledoc """
  Estimates monthly GCP infrastructure costs based on deployment configuration.

  All costs are in USD and represent approximate monthly totals.
  Actual costs will vary based on traffic, usage patterns, and billing options.
  """

  alias PhoenixGcpDeployer.CostCalculator.Pricing

  @hours_per_month 730.0
  @seconds_per_month 730 * 3600
  # Assume 10% CPU utilization for active instances
  @default_cpu_utilization 0.1
  # Assume 100k requests/month as a starting estimate
  @default_monthly_requests 100_000

  @type deployment_config :: %{
          min_instances: non_neg_integer(),
          max_instances: pos_integer(),
          memory_mb: pos_integer(),
          cpu_count: pos_integer(),
          db_tier: String.t(),
          db_disk_size_gb: pos_integer(),
          enable_cdn: boolean(),
          enable_armor: boolean(),
          enable_secret_manager: boolean()
        }

  @type cost_breakdown :: %{
          cloud_run: float(),
          cloud_sql: float(),
          cloud_armor: float(),
          cdn: float(),
          secret_manager: float(),
          total: float(),
          currency: String.t()
        }

  @doc """
  Calculates the estimated monthly cost for a given deployment configuration.

  ## Examples

      iex> config = %{
      ...>   min_instances: 1,
      ...>   max_instances: 10,
      ...>   memory_mb: 512,
      ...>   cpu_count: 1,
      ...>   db_tier: "db-f1-micro",
      ...>   db_disk_size_gb: 10,
      ...>   enable_cdn: false,
      ...>   enable_armor: false,
      ...>   enable_secret_manager: true
      ...> }
      iex> PhoenixGcpDeployer.CostCalculator.Calculator.estimate(config)
      %{cloud_run: _, cloud_sql: _, total: _, ...}
  """
  @spec estimate(deployment_config()) :: cost_breakdown()
  def estimate(config) do
    cloud_run = estimate_cloud_run(config)
    cloud_sql = estimate_cloud_sql(config)
    cloud_armor = if config.enable_armor, do: estimate_cloud_armor(), else: 0.0
    cdn = if config.enable_cdn, do: estimate_cdn(), else: 0.0
    secret_manager = if config.enable_secret_manager, do: estimate_secret_manager(), else: 0.0

    total = cloud_run + cloud_sql + cloud_armor + cdn + secret_manager

    %{
      cloud_run: round_cents(cloud_run),
      cloud_sql: round_cents(cloud_sql),
      cloud_armor: round_cents(cloud_armor),
      cdn: round_cents(cdn),
      secret_manager: round_cents(secret_manager),
      total: round_cents(total),
      currency: "USD"
    }
  end

  @doc "Returns a human-readable tier description for display."
  @spec tier_description(String.t()) :: String.t()
  def tier_description(tier) do
    case Pricing.cloud_sql_tiers()[tier] do
      %{vcpu: vcpu, ram_gb: ram} -> "#{vcpu} vCPU, #{ram} GB RAM"
      nil -> tier
    end
  end

  # --- Private ---

  defp estimate_cloud_run(%{
         min_instances: min_instances,
         memory_mb: memory_mb,
         cpu_count: cpu_count
       }) do
    pricing = Pricing.all().cloud_run
    memory_gib = memory_mb / 1024.0

    # Cost for minimum always-on instances
    min_instance_cpu_cost =
      min_instances * cpu_count * @hours_per_month * pricing.min_instance_cpu_per_hour

    min_instance_mem_cost =
      min_instances * memory_gib * @hours_per_month * pricing.min_instance_memory_per_gib_hour

    # Cost for active request handling (assumes 10% average utilization on top)
    active_cpu_seconds = @seconds_per_month * @default_cpu_utilization * cpu_count
    active_cpu_cost = active_cpu_seconds * pricing.cpu_per_vcpu_second

    active_mem_seconds = @seconds_per_month * @default_cpu_utilization * memory_gib
    active_mem_cost = active_mem_seconds * pricing.memory_per_gib_second

    # Request cost
    request_cost =
      @default_monthly_requests / 1_000_000.0 * pricing.request_per_million

    min_instance_cpu_cost + min_instance_mem_cost + active_cpu_cost + active_mem_cost +
      request_cost
  end

  defp estimate_cloud_sql(%{db_tier: tier, db_disk_size_gb: disk_gb}) do
    pricing = Pricing.all().cloud_sql

    instance_cost =
      case pricing.tiers[tier] do
        %{price_per_hour: price} -> price * @hours_per_month
        nil -> 0.0
      end

    storage_cost = disk_gb * pricing.storage_per_gb_month
    # Assume backup = 25% of disk size
    backup_cost = disk_gb * 0.25 * pricing.backup_per_gb_month

    instance_cost + storage_cost + backup_cost
  end

  defp estimate_cloud_armor do
    pricing = Pricing.all().cloud_armor
    # Policy fee + requests
    pricing.policy_per_month +
      @default_monthly_requests / 1_000_000.0 * pricing.per_million_requests
  end

  defp estimate_cdn do
    pricing = Pricing.all().cdn
    # Assume 1 GB egress and 0.5 GB cache fill per month as baseline
    1.0 * pricing.egress_per_gb + 0.5 * pricing.fill_per_gb
  end

  defp estimate_secret_manager do
    pricing = Pricing.all().secret_manager
    # Assume 5 active secrets, 1000 accesses/month
    5 * pricing.active_version_per_month +
      1000 / 10_000.0 * pricing.per_10k_access
  end

  defp round_cents(value) do
    Float.round(value, 2)
  end
end
