defmodule PhoenixGcpDeployerWeb.DeployLive.Index do
  @moduledoc """
  Multi-step deployment configuration wizard.

  Steps:
    1. :repo    — Enter GitHub URL and analyze
    2. :env     — Select environment and GCP project
    3. :database — Configure Cloud SQL
    4. :compute  — Configure Cloud Run scaling/resources
    5. :security — Security settings
    6. :review   — Review, cost estimate, and generate
  """

  use PhoenixGcpDeployerWeb, :live_view

  alias PhoenixGcpDeployer.{CostCalculator.Calculator, GithubAnalyzer.Analyzer}
  alias PhoenixGcpDeployer.Deployments.Deployment
  alias PhoenixGcpDeployer.TemplateEngine.Engine
  alias PhoenixGcpDeployer.SecurityChecker.Checker

  @steps [:repo, :env, :database, :compute, :security, :review]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:step, :repo)
     |> assign(:github_url, "")
     |> assign(:analyzing, false)
     |> assign(:analysis_result, nil)
     |> assign(:analysis_error, nil)
     |> assign(:config, default_config())
     |> assign(:cost_estimate, nil)
     |> assign(:security_report, nil)
     |> assign(:generated_files, nil)
     |> assign(:generating, false)
     |> assign(:page_title, "Deploy to GCP")}
  end

  @impl true
  def handle_event("set_url", %{"url" => url}, socket) do
    {:noreply, assign(socket, :github_url, url)}
  end

  def handle_event("analyze_repo", %{"url" => url}, socket) do
    socket =
      socket
      |> assign(:github_url, url)
      |> assign(:analyzing, true)
      |> assign(:analysis_error, nil)

    send(self(), {:analyze, url})
    {:noreply, socket}
  end

  def handle_event("update_config", %{"config" => params}, socket) do
    config = merge_config(socket.assigns.config, params)
    cost = if socket.assigns.step == :review, do: recalculate_cost(config), else: socket.assigns.cost_estimate
    {:noreply, socket |> assign(:config, config) |> assign(:cost_estimate, cost)}
  end

  def handle_event("next_step", _params, socket) do
    current = socket.assigns.step
    next = next_step(current)

    socket =
      case next do
        :review ->
          cost = recalculate_cost(socket.assigns.config)
          security = Checker.check(socket.assigns.config)
          socket |> assign(:cost_estimate, cost) |> assign(:security_report, security)

        _ ->
          socket
      end

    {:noreply, assign(socket, :step, next)}
  end

  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, prev_step(socket.assigns.step))}
  end

  def handle_event("generate", _params, socket) do
    socket = assign(socket, :generating, true)
    send(self(), :generate_files)
    {:noreply, socket}
  end

  def handle_event("goto_step", %{"step" => step_str}, socket) do
    step = String.to_existing_atom(step_str)

    if step_accessible?(step, socket.assigns.step, socket.assigns.analysis_result) do
      {:noreply, assign(socket, :step, step)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:analyze, url}, socket) do
    result =
      case Analyzer.analyze(url) do
        {:ok, analysis} -> {:ok, analysis}
        {:error, reason} -> {:error, format_error(reason)}
      end

    socket =
      case result do
        {:ok, analysis} ->
          socket
          |> assign(:analysis_result, analysis)
          |> assign(:analyzing, false)
          |> assign(:config, Map.put(socket.assigns.config, :app_name, analysis[:name] || "myapp"))
          |> assign(:step, :env)

        {:error, msg} ->
          socket
          |> assign(:analyzing, false)
          |> assign(:analysis_error, msg)
      end

    {:noreply, socket}
  end

  def handle_info(:generate_files, socket) do
    context = Engine.build_context(struct(Deployment, socket.assigns.config), socket.assigns.analysis_result || %{})

    result =
      case Engine.generate_all(context) do
        {:ok, files} -> {:ok, files}
        {:error, reason} -> {:error, reason}
      end

    socket =
      case result do
        {:ok, files} ->
          socket
          |> assign(:generated_files, files)
          |> assign(:generating, false)

        {:error, _reason} ->
          assign(socket, :generating, false)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <.link navigate={~p"/"} class="inline-flex items-center gap-2 text-slate-400 hover:text-white text-sm mb-6 transition-colors">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to home
          </.link>
          <h1 class="text-3xl font-bold text-white">Deploy to GCP</h1>
          <p class="text-slate-400 mt-2">Configure your Phoenix app for Google Cloud Platform</p>
        </div>

        <!-- Step Indicator -->
        <.step_indicator step={@step} analysis_result={@analysis_result} />

        <!-- Step Content -->
        <div class="bg-white/5 backdrop-blur rounded-2xl border border-white/10 p-8 mt-6">
          <.repo_step
            :if={@step == :repo}
            github_url={@github_url}
            analyzing={@analyzing}
            analysis_error={@analysis_error}
          />
          <.env_step :if={@step == :env} config={@config} analysis_result={@analysis_result} />
          <.database_step :if={@step == :database} config={@config} />
          <.compute_step :if={@step == :compute} config={@config} />
          <.security_step :if={@step == :security} config={@config} />
          <.review_step
            :if={@step == :review}
            config={@config}
            analysis_result={@analysis_result}
            cost_estimate={@cost_estimate}
            security_report={@security_report}
            generated_files={@generated_files}
            generating={@generating}
          />
        </div>

        <!-- Navigation -->
        <div :if={@step != :repo} class="flex justify-between mt-6">
          <button
            phx-click="prev_step"
            class="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-white/10 text-white hover:bg-white/20 transition-colors text-sm font-medium"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Back
          </button>

          <button
            :if={@step != :review}
            phx-click="next_step"
            class="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 text-white hover:shadow-lg hover:shadow-orange-500/25 transition-all text-sm font-medium"
          >
            Next
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # --- Step Components ---

  defp step_indicator(assigns) do
    steps = [
      {:repo, "Repository"},
      {:env, "Environment"},
      {:database, "Database"},
      {:compute, "Compute"},
      {:security, "Security"},
      {:review, "Review"}
    ]

    current_idx = Enum.find_index(steps, fn {s, _} -> s == assigns.step end) || 0
    assigns = assign(assigns, steps: steps, current_idx: current_idx)

    ~H"""
    <div class="flex items-center justify-between relative">
      <div class="absolute left-0 right-0 top-4 h-0.5 bg-white/10 -z-10"></div>
      <button
        :for={{{step, label}, idx} <- Enum.with_index(@steps)}
        phx-click="goto_step"
        phx-value-step={step}
        class={[
          "flex flex-col items-center gap-1.5 relative z-10 group",
          if(idx <= @current_idx, do: "cursor-pointer", else: "cursor-default")
        ]}
      >
        <div class={[
          "w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold border-2 transition-all",
          cond do
            step == @step -> "bg-orange-500 border-orange-500 text-white shadow-lg shadow-orange-500/30"
            idx < @current_idx -> "bg-green-500/20 border-green-500 text-green-400"
            true -> "bg-white/5 border-white/20 text-slate-500"
          end
        ]}>
          <svg :if={idx < @current_idx} class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          <span :if={idx >= @current_idx}><%= idx + 1 %></span>
        </div>
        <span class={[
          "text-xs hidden sm:block transition-colors",
          if(step == @step, do: "text-white font-medium", else: "text-slate-500")
        ]}>
          <%= label %>
        </span>
      </button>
    </div>
    """
  end

  defp repo_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold text-white mb-2">Enter your GitHub repository</h2>
      <p class="text-slate-400 text-sm mb-6">
        We'll fetch your <code class="text-orange-400">mix.exs</code> to detect your Phoenix version and dependencies.
      </p>

      <form phx-submit="analyze_repo">
        <div class="flex gap-3">
          <div class="flex-1 relative">
            <div class="absolute inset-y-0 left-3 flex items-center pointer-events-none">
              <svg class="w-5 h-5 text-slate-500" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd" />
              </svg>
            </div>
            <input
              type="url"
              name="url"
              value={@github_url}
              placeholder="https://github.com/owner/myapp"
              required
              class="w-full pl-10 pr-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm"
            />
          </div>
          <button
            type="submit"
            disabled={@analyzing}
            class="px-6 py-3 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 text-white font-medium text-sm hover:shadow-lg hover:shadow-orange-500/25 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <svg :if={@analyzing} class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span :if={@analyzing}>Analyzing...</span>
            <span :if={!@analyzing}>Analyze</span>
          </button>
        </div>
      </form>

      <div :if={@analysis_error} class="mt-4 p-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm flex items-start gap-3">
        <svg class="w-5 h-5 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span><%= @analysis_error %></span>
      </div>

      <div class="mt-8 p-4 rounded-xl bg-blue-500/10 border border-blue-500/20">
        <p class="text-blue-300 text-sm font-medium mb-2">Supported repositories</p>
        <ul class="text-slate-400 text-sm space-y-1">
          <li>✓ Public GitHub repositories</li>
          <li>✓ Phoenix 1.6+ with or without LiveView</li>
          <li>✓ Apps with Ecto, Oban, and other popular deps</li>
        </ul>
      </div>
    </div>
    """
  end

  defp env_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold text-white mb-2">Environment & GCP Project</h2>

      <div :if={@analysis_result} class="mb-6 p-4 rounded-xl bg-green-500/10 border border-green-500/30">
        <p class="text-green-400 text-sm font-medium mb-2">✓ Analysis complete</p>
        <div class="grid grid-cols-2 gap-2 text-sm">
          <.analysis_badge label="App" value={@analysis_result[:name] || "unknown"} />
          <.analysis_badge label="Phoenix" value={@analysis_result[:phoenix_version] || "unknown"} />
          <.analysis_badge label="Elixir" value={@analysis_result[:elixir_version] || "unknown"} />
          <.analysis_badge label="LiveView" value={if @analysis_result[:has_live_view], do: "yes", else: "no"} />
          <.analysis_badge label="Ecto" value={if @analysis_result[:has_ecto], do: "yes", else: "no"} />
          <.analysis_badge label="Oban" value={if @analysis_result[:has_oban], do: "yes", else: "no"} />
        </div>
      </div>

      <form phx-change="update_config">
        <div class="space-y-5">
          <.config_field label="Environment" name="config[environment]" value={@config[:environment]}>
            <select name="config[environment]" class="form-select-dark">
              <option value="production" selected={@config[:environment] == "production"}>Production</option>
              <option value="staging" selected={@config[:environment] == "staging"}>Staging</option>
              <option value="development" selected={@config[:environment] == "development"}>Development</option>
            </select>
          </.config_field>

          <.config_field label="GCP Project ID" name="config[gcp_project_id]" value={@config[:gcp_project_id]}>
            <input
              type="text"
              name="config[gcp_project_id]"
              value={@config[:gcp_project_id]}
              placeholder="my-gcp-project-123"
              class="form-input-dark"
            />
          </.config_field>

          <.config_field label="GCP Region" name="config[gcp_region]" value={@config[:gcp_region]}>
            <select name="config[gcp_region]" class="form-select-dark">
              <option value="us-central1">us-central1 (Iowa)</option>
              <option value="us-east1">us-east1 (South Carolina)</option>
              <option value="us-west1">us-west1 (Oregon)</option>
              <option value="europe-west1">europe-west1 (Belgium)</option>
              <option value="europe-west4">europe-west4 (Netherlands)</option>
              <option value="asia-east1">asia-east1 (Taiwan)</option>
              <option value="asia-northeast1">asia-northeast1 (Tokyo)</option>
              <option value="australia-southeast1">australia-southeast1 (Sydney)</option>
            </select>
          </.config_field>

          <.config_field label="Custom Domain (optional)" name="config[domain_name]" value={@config[:domain_name]}>
            <input
              type="text"
              name="config[domain_name]"
              value={@config[:domain_name]}
              placeholder="myapp.example.com"
              class="form-input-dark"
            />
          </.config_field>
        </div>
      </form>
    </div>
    """
  end

  defp database_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold text-white mb-2">Database Configuration</h2>
      <p class="text-slate-400 text-sm mb-6">Cloud SQL PostgreSQL instance settings.</p>

      <form phx-change="update_config">
        <div class="space-y-5">
          <.config_field label="Machine Tier" name="config[db_tier]" value={@config[:db_tier]}>
            <select name="config[db_tier]" class="form-select-dark">
              <option value="db-f1-micro">db-f1-micro — 0.6 vCPU, 614 MB (dev/test)</option>
              <option value="db-g1-small">db-g1-small — 1 vCPU, 1.7 GB</option>
              <option value="db-n1-standard-1">db-n1-standard-1 — 1 vCPU, 3.75 GB</option>
              <option value="db-n1-standard-2">db-n1-standard-2 — 2 vCPU, 7.5 GB</option>
              <option value="db-n1-standard-4">db-n1-standard-4 — 4 vCPU, 15 GB</option>
              <option value="db-n1-highmem-2">db-n1-highmem-2 — 2 vCPU, 13 GB</option>
            </select>
          </.config_field>

          <.config_field label="PostgreSQL Version" name="config[db_version]" value={@config[:db_version]}>
            <select name="config[db_version]" class="form-select-dark">
              <option value="POSTGRES_16">PostgreSQL 16</option>
              <option value="POSTGRES_15">PostgreSQL 15</option>
              <option value="POSTGRES_14">PostgreSQL 14</option>
            </select>
          </.config_field>

          <.config_field label="Disk Size (GB)" name="config[db_disk_size_gb]" value={@config[:db_disk_size_gb]}>
            <input
              type="number"
              name="config[db_disk_size_gb]"
              value={@config[:db_disk_size_gb]}
              min="10"
              max="64000"
              class="form-input-dark"
            />
          </.config_field>
        </div>
      </form>
    </div>
    """
  end

  defp compute_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold text-white mb-2">Compute Configuration</h2>
      <p class="text-slate-400 text-sm mb-6">Cloud Run auto-scaling and resource settings.</p>

      <form phx-change="update_config">
        <div class="space-y-5">
          <div class="grid grid-cols-2 gap-4">
            <.config_field label="Min Instances" name="config[min_instances]" value={@config[:min_instances]}>
              <input type="number" name="config[min_instances]" value={@config[:min_instances]} min="0" max="100" class="form-input-dark" />
              <p class="text-slate-500 text-xs mt-1">Set to 1+ to avoid cold starts</p>
            </.config_field>

            <.config_field label="Max Instances" name="config[max_instances]" value={@config[:max_instances]}>
              <input type="number" name="config[max_instances]" value={@config[:max_instances]} min="1" max="1000" class="form-input-dark" />
            </.config_field>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.config_field label="Memory (MB)" name="config[memory_mb]" value={@config[:memory_mb]}>
              <select name="config[memory_mb]" class="form-select-dark">
                <option value="256">256 MB</option>
                <option value="512">512 MB</option>
                <option value="1024">1 GB</option>
                <option value="2048">2 GB</option>
                <option value="4096">4 GB</option>
                <option value="8192">8 GB</option>
              </select>
            </.config_field>

            <.config_field label="CPU Count" name="config[cpu_count]" value={@config[:cpu_count]}>
              <select name="config[cpu_count]" class="form-select-dark">
                <option value="1">1 vCPU</option>
                <option value="2">2 vCPU</option>
                <option value="4">4 vCPU</option>
                <option value="6">6 vCPU</option>
                <option value="8">8 vCPU</option>
              </select>
            </.config_field>
          </div>

          <div class="p-4 rounded-xl bg-white/5 border border-white/10">
            <label class="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                name="config[use_vpc]"
                checked={@config[:use_vpc]}
                value="true"
                class="w-4 h-4 rounded accent-orange-500"
              />
              <div>
                <p class="text-white text-sm font-medium">Enable VPC networking</p>
                <p class="text-slate-500 text-xs">Required for private Cloud SQL access (recommended)</p>
              </div>
            </label>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp security_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold text-white mb-2">Security Settings</h2>
      <p class="text-slate-400 text-sm mb-6">Configure security features for your deployment.</p>

      <form phx-change="update_config">
        <div class="space-y-4">
          <.security_toggle
            name="config[enable_secret_manager]"
            checked={@config[:enable_secret_manager]}
            title="Secret Manager"
            description="Store DATABASE_URL and SECRET_KEY_BASE in GCP Secret Manager (strongly recommended)"
            badge="Recommended"
          />

          <.security_toggle
            name="config[enable_armor]"
            checked={@config[:enable_armor]}
            title="Cloud Armor WAF"
            description="DDoS protection and web application firewall (~$5/month base cost)"
          />

          <.security_toggle
            name="config[enable_cdn]"
            checked={@config[:enable_cdn]}
            title="Cloud CDN"
            description="Cache static assets at Google's edge locations for faster global delivery"
          />

          <.config_field label="SSL Policy" name="config[ssl_policy]" value={@config[:ssl_policy]}>
            <select name="config[ssl_policy]" class="form-select-dark">
              <option value="modern">Modern — TLS 1.2+ only (recommended)</option>
              <option value="restricted">Restricted — TLS 1.2+ strict ciphers</option>
              <option value="compatible">Compatible — TLS 1.0+ (legacy support)</option>
            </select>
          </.config_field>
        </div>
      </form>
    </div>
    """
  end

  defp review_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold text-white mb-6">Review & Generate</h2>

      <!-- Cost Estimate -->
      <div :if={@cost_estimate} class="mb-6 p-5 rounded-xl bg-gradient-to-br from-orange-500/10 to-pink-500/10 border border-orange-500/20">
        <h3 class="text-orange-400 font-semibold mb-3 flex items-center gap-2">
          <span>💰</span> Estimated Monthly Cost
        </h3>
        <div class="grid grid-cols-3 gap-3 mb-4">
          <.cost_row label="Cloud Run" value={@cost_estimate.cloud_run} />
          <.cost_row label="Cloud SQL" value={@cost_estimate.cloud_sql} />
          <.cost_row label="Security" value={@cost_estimate.cloud_armor + @cost_estimate.secret_manager} />
        </div>
        <div class="pt-3 border-t border-orange-500/20 flex justify-between items-center">
          <span class="text-white font-semibold">Total</span>
          <span class="text-2xl font-bold text-orange-400">$<%= @cost_estimate.total %>/mo</span>
        </div>
      </div>

      <!-- Security Report -->
      <div :if={@security_report} class="mb-6 p-5 rounded-xl bg-white/5 border border-white/10">
        <h3 class="text-white font-semibold mb-3 flex items-center gap-2 justify-between">
          <span class="flex items-center gap-2">
            <span>🔒</span> Security Score
          </span>
          <span class={[
            "text-lg font-bold",
            if(@security_report.score >= 80, do: "text-green-400", else: if(@security_report.score >= 60, do: "text-yellow-400", else: "text-red-400"))
          ]}>
            <%= @security_report.score %>/100
          </span>
        </h3>
        <.security_issue :for={issue <- @security_report.errors} issue={issue} />
        <.security_issue :for={issue <- @security_report.warnings} issue={issue} />
      </div>

      <!-- Generate Button -->
      <button
        :if={is_nil(@generated_files)}
        phx-click="generate"
        disabled={@generating}
        class="w-full py-4 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 text-white font-semibold text-lg hover:shadow-xl hover:shadow-orange-500/25 transition-all disabled:opacity-50 flex items-center justify-center gap-3"
      >
        <svg :if={@generating} class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span :if={@generating}>Generating files...</span>
        <svg :if={!@generating} class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
        </svg>
        <span :if={!@generating}>Generate Deployment Package</span>
      </button>

      <!-- Generated Files Preview -->
      <div :if={@generated_files} class="space-y-4">
        <div class="flex items-center gap-3 p-4 rounded-xl bg-green-500/10 border border-green-500/30">
          <svg class="w-5 h-5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-green-400 font-medium">Deployment package generated!</p>
        </div>

        <div class="space-y-2">
          <.file_preview title="Dockerfile" content={@generated_files.dockerfile} />
          <.file_preview title="terraform/main.tf" content={@generated_files.terraform_main} />
          <.file_preview title="terraform/variables.tf" content={@generated_files.terraform_variables} />
          <.file_preview title="cloudbuild.yaml" content={@generated_files.cloudbuild} />
        </div>
      </div>
    </div>
    """
  end

  # --- Small UI components ---

  defp analysis_badge(assigns) do
    ~H"""
    <div class="flex gap-2 text-xs">
      <span class="text-slate-500"><%= @label %>:</span>
      <span class="text-green-300 font-medium"><%= @value %></span>
    </div>
    """
  end

  defp config_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-slate-300 mb-1.5"><%= @label %></label>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  defp security_toggle(assigns) do
    ~H"""
    <div class="p-4 rounded-xl bg-white/5 border border-white/10">
      <label class="flex items-start gap-3 cursor-pointer">
        <input
          type="checkbox"
          name={@name}
          checked={@checked}
          value="true"
          class="w-4 h-4 rounded accent-orange-500 mt-0.5"
        />
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <p class="text-white text-sm font-medium"><%= @title %></p>
            <span :if={Map.get(assigns, :badge)} class="text-xs px-2 py-0.5 rounded-full bg-green-500/20 text-green-400 font-medium"><%= @badge %></span>
          </div>
          <p class="text-slate-500 text-xs mt-0.5"><%= @description %></p>
        </div>
      </label>
    </div>
    """
  end

  defp cost_row(assigns) do
    ~H"""
    <div class="text-center">
      <p class="text-slate-400 text-xs mb-1"><%= @label %></p>
      <p class="text-white font-semibold">$<%= @value %></p>
    </div>
    """
  end

  defp security_issue(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-2 text-xs p-2 rounded-lg mb-1.5",
      case @issue.severity do
        s when s in [:critical, :high] -> "bg-red-500/10 text-red-400"
        :medium -> "bg-yellow-500/10 text-yellow-400"
        _ -> "bg-green-500/10 text-green-400"
      end
    ]}>
      <span class="mt-0.5">
        <%= case @issue.severity do %>
          <% s when s in [:critical, :high] -> %> ✗
          <% :medium -> %> ⚠
          <% _ -> %> ✓
        <% end %>
      </span>
      <div>
        <p class="font-medium"><%= @issue.message %></p>
        <p :if={@issue.recommendation != ""} class="opacity-75 mt-0.5"><%= @issue.recommendation %></p>
      </div>
    </div>
    """
  end

  defp file_preview(assigns) do
    ~H"""
    <details class="group rounded-xl bg-black/30 border border-white/10 overflow-hidden">
      <summary class="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-white/5 transition-colors">
        <span class="text-slate-300 text-sm font-mono font-medium"><%= @title %></span>
        <svg class="w-4 h-4 text-slate-500 group-open:rotate-180 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </summary>
      <pre class="px-4 pb-4 text-xs text-slate-300 overflow-x-auto whitespace-pre font-mono leading-5 max-h-96 overflow-y-auto"><code><%= @content %></code></pre>
    </details>
    """
  end

  # --- Helpers ---

  defp default_config do
    %{
      app_name: "myapp",
      environment: "production",
      gcp_project_id: "",
      gcp_region: "us-central1",
      gcp_zone: "us-central1-a",
      db_tier: "db-f1-micro",
      db_version: "POSTGRES_15",
      db_disk_size_gb: 10,
      min_instances: 1,
      max_instances: 10,
      memory_mb: 512,
      cpu_count: 1,
      use_vpc: true,
      enable_cdn: false,
      domain_name: "",
      enable_secret_manager: true,
      enable_armor: false,
      ssl_policy: "modern"
    }
  end

  defp merge_config(config, params) do
    bool_fields = ~w(use_vpc enable_cdn enable_secret_manager enable_armor)
    int_fields = ~w(db_disk_size_gb min_instances max_instances memory_mb cpu_count)

    Enum.reduce(params, config, fn {k, v}, acc ->
      key = String.to_existing_atom(k)

      parsed =
        cond do
          k in bool_fields -> v == "true"
          k in int_fields -> String.to_integer(v)
          true -> v
        end

      Map.put(acc, key, parsed)
    end)
  rescue
    _ -> config
  end

  defp recalculate_cost(config) do
    Calculator.estimate(%{
      min_instances: config[:min_instances] || 1,
      max_instances: config[:max_instances] || 10,
      memory_mb: config[:memory_mb] || 512,
      cpu_count: config[:cpu_count] || 1,
      db_tier: config[:db_tier] || "db-f1-micro",
      db_disk_size_gb: config[:db_disk_size_gb] || 10,
      enable_cdn: config[:enable_cdn] || false,
      enable_armor: config[:enable_armor] || false,
      enable_secret_manager: config[:enable_secret_manager] || true
    })
  end

  defp next_step(current) do
    idx = Enum.find_index(@steps, &(&1 == current)) || 0
    Enum.at(@steps, idx + 1, current)
  end

  defp prev_step(current) do
    idx = Enum.find_index(@steps, &(&1 == current)) || 0
    Enum.at(@steps, idx - 1, current)
  end

  defp step_accessible?(target, current, analysis_result) do
    target_idx = Enum.find_index(@steps, &(&1 == target)) || 0
    current_idx = Enum.find_index(@steps, &(&1 == current)) || 0
    has_analysis = not is_nil(analysis_result)

    cond do
      target_idx == 0 -> true
      target_idx <= current_idx -> true
      target_idx == 1 and has_analysis -> true
      true -> false
    end
  end

  defp format_error(:invalid_github_url), do: "Please enter a valid GitHub URL (e.g. https://github.com/owner/repo)"
  defp format_error(:not_found), do: "Repository not found. Make sure it's public and the URL is correct."
  defp format_error(:unauthorized), do: "GitHub API access denied. The repository may be private."
  defp format_error(:rate_limited), do: "GitHub API rate limit exceeded. Please wait a few minutes and try again."
  defp format_error(_), do: "Failed to analyze repository. Please check the URL and try again."
end
