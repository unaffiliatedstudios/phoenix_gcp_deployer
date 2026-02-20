defmodule PhoenixGcpDeployer.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_gcp_deployer,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      mod: {PhoenixGcpDeployer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix & LiveView
      {:phoenix, "~> 1.7.21"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},

      # Build tools
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Database
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},

      # HTTP client
      {:req, "~> 0.5"},

      # Email
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},

      # Utilities
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # Archive / ZIP generation
      {:zstream, "~> 0.6"},

      # Development tools
      {:tidewave, "~> 0.5", only: :dev},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},

      # Testing
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:wallaby, "~> 0.30", runtime: false, only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},

      # Security auditing
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind phoenix_gcp_deployer", "esbuild phoenix_gcp_deployer"],
      "assets.deploy": [
        "tailwind phoenix_gcp_deployer --minify",
        "esbuild phoenix_gcp_deployer --minify",
        "phx.digest"
      ]
    ]
  end
end
