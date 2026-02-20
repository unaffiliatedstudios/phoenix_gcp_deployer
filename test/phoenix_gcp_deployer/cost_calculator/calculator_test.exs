defmodule PhoenixGcpDeployer.CostCalculator.CalculatorTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  alias PhoenixGcpDeployer.CostCalculator.Calculator

  @base_config %{
    min_instances: 1,
    max_instances: 10,
    memory_mb: 512,
    cpu_count: 1,
    db_tier: "db-f1-micro",
    db_disk_size_gb: 10,
    enable_cdn: false,
    enable_armor: false,
    enable_secret_manager: true
  }

  describe "estimate/1" do
    test "returns a map with all cost components" do
      result = Calculator.estimate(@base_config)

      assert is_map(result)
      assert Map.has_key?(result, :cloud_run)
      assert Map.has_key?(result, :cloud_sql)
      assert Map.has_key?(result, :cloud_armor)
      assert Map.has_key?(result, :cdn)
      assert Map.has_key?(result, :secret_manager)
      assert Map.has_key?(result, :total)
      assert result.currency == "USD"
    end

    test "total equals sum of components" do
      result = Calculator.estimate(@base_config)

      expected_total =
        Float.round(
          result.cloud_run + result.cloud_sql + result.cloud_armor + result.cdn +
            result.secret_manager,
          2
        )

      assert result.total == expected_total
    end

    test "cloud armor cost is zero when disabled" do
      result = Calculator.estimate(%{@base_config | enable_armor: false})
      assert result.cloud_armor == 0.0
    end

    test "cloud armor cost is positive when enabled" do
      result = Calculator.estimate(%{@base_config | enable_armor: true})
      assert result.cloud_armor > 0
    end

    test "cdn cost is zero when disabled" do
      result = Calculator.estimate(%{@base_config | enable_cdn: false})
      assert result.cdn == 0.0
    end

    test "cdn cost is positive when enabled" do
      result = Calculator.estimate(%{@base_config | enable_cdn: true})
      assert result.cdn > 0
    end

    test "secret manager cost is zero when disabled" do
      result = Calculator.estimate(%{@base_config | enable_secret_manager: false})
      assert result.secret_manager == 0.0
    end

    test "more memory increases cloud run cost" do
      low_mem = Calculator.estimate(%{@base_config | memory_mb: 256})
      high_mem = Calculator.estimate(%{@base_config | memory_mb: 4096})

      assert high_mem.cloud_run > low_mem.cloud_run
    end

    test "larger db tier increases cloud sql cost" do
      small = Calculator.estimate(%{@base_config | db_tier: "db-f1-micro"})
      large = Calculator.estimate(%{@base_config | db_tier: "db-n1-standard-4"})

      assert large.cloud_sql > small.cloud_sql
    end

    test "larger disk size increases cloud sql cost" do
      small_disk = Calculator.estimate(%{@base_config | db_disk_size_gb: 10})
      large_disk = Calculator.estimate(%{@base_config | db_disk_size_gb: 500})

      assert large_disk.cloud_sql > small_disk.cloud_sql
    end

    test "all costs are non-negative" do
      result = Calculator.estimate(@base_config)

      assert result.cloud_run >= 0
      assert result.cloud_sql >= 0
      assert result.cloud_armor >= 0
      assert result.cdn >= 0
      assert result.secret_manager >= 0
      assert result.total >= 0
    end

    test "returns rounded to 2 decimal places" do
      result = Calculator.estimate(@base_config)

      Enum.each([:cloud_run, :cloud_sql, :cloud_armor, :cdn, :secret_manager, :total], fn key ->
        value = result[key]
        assert value == Float.round(value, 2), "#{key} should be rounded to 2 decimals"
      end)
    end
  end

  describe "estimate/1 property tests" do
    property "total is always non-negative" do
      check all(
              min_instances <- StreamData.integer(0..10),
              max_instances <- StreamData.integer(1..100),
              memory_mb <- StreamData.member_of([256, 512, 1024, 2048, 4096]),
              cpu_count <- StreamData.integer(1..8),
              db_disk <- StreamData.integer(10..1000)
            ) do
        config = %{
          @base_config
          | min_instances: min_instances,
            max_instances: max(max_instances, min_instances),
            memory_mb: memory_mb,
            cpu_count: cpu_count,
            db_disk_size_gb: db_disk
        }

        result = Calculator.estimate(config)
        assert result.total >= 0
      end
    end

    property "enabling features never decreases total cost" do
      check all(
              enable_armor <- StreamData.boolean(),
              enable_cdn <- StreamData.boolean()
            ) do
        base = Calculator.estimate(%{@base_config | enable_armor: false, enable_cdn: false})
        with_features = Calculator.estimate(%{@base_config | enable_armor: enable_armor, enable_cdn: enable_cdn})

        assert with_features.total >= base.total
      end
    end
  end

  describe "tier_description/1" do
    test "returns description for known tier" do
      desc = Calculator.tier_description("db-f1-micro")
      assert String.contains?(desc, "vCPU")
    end

    test "returns tier name for unknown tier" do
      assert Calculator.tier_description("unknown-tier") == "unknown-tier"
    end
  end
end
