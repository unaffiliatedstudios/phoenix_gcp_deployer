defmodule PhoenixGcpDeployerWeb.HomeLive do
  @moduledoc "Landing page with value proposition and quick-start."

  use PhoenixGcpDeployerWeb, :live_view

  alias PhoenixGcpDeployer.Deployments

  @impl true
  def mount(_params, _session, socket) do
    recent_projects = Deployments.list_projects() |> Enum.take(5)
    {:ok, assign(socket, recent_projects: recent_projects, page_title: "Phoenix GCP Deployer")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <!-- Hero Section -->
      <div class="relative overflow-hidden">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24">
          <div class="text-center">
            <!-- Logo / Icon -->
            <div class="flex justify-center mb-8">
              <div class="w-20 h-20 bg-gradient-to-br from-orange-400 to-pink-600 rounded-2xl flex items-center justify-center shadow-2xl">
                <svg class="w-12 h-12 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z" />
                </svg>
              </div>
            </div>

            <h1 class="text-5xl font-extrabold text-white mb-6 tracking-tight">
              Phoenix GCP Deployer
            </h1>
            <p class="text-xl text-slate-300 max-w-2xl mx-auto mb-10">
              Generate production-ready Google Cloud Platform infrastructure for your
              Phoenix LiveView app — without becoming a DevOps expert.
            </p>

            <.link
              navigate={~p"/deploy"}
              class="inline-flex items-center gap-3 px-8 py-4 text-lg font-semibold rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-lg hover:shadow-orange-500/25 hover:scale-105 transition-all duration-200"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              Start Deploying
            </.link>
          </div>
        </div>
      </div>

      <!-- Features Grid -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-20">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-16">
          <.feature_card
            icon="🔍"
            title="Auto-Analyze"
            description="Paste your GitHub URL and we'll analyze your mix.exs to detect Phoenix version, dependencies, and configuration."
          />
          <.feature_card
            icon="⚙️"
            title="Configure"
            description="Step through an intuitive wizard to set your GCP region, database tier, auto-scaling, and security settings."
          />
          <.feature_card
            icon="📦"
            title="Generate"
            description="Download a ready-to-use ZIP with Terraform, Dockerfile, and Cloud Build configs optimized for your app."
          />
        </div>

        <!-- What You Get -->
        <div class="bg-white/5 backdrop-blur rounded-2xl border border-white/10 p-8 mb-12">
          <h2 class="text-2xl font-bold text-white mb-6">What gets generated</h2>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <.artifact_pill icon="🐳" label="Dockerfile" sub="Multi-stage build" />
            <.artifact_pill icon="🏗️" label="Terraform" sub="Cloud Run + SQL" />
            <.artifact_pill icon="🔧" label="Cloud Build" sub="CI/CD pipeline" />
            <.artifact_pill icon="💰" label="Cost estimate" sub="Monthly breakdown" />
          </div>
        </div>

        <!-- Recent Projects -->
        <div :if={@recent_projects != []} class="bg-white/5 backdrop-blur rounded-2xl border border-white/10 p-8">
          <h2 class="text-2xl font-bold text-white mb-6">Recent projects</h2>
          <div class="space-y-3">
            <.link
              :for={project <- @recent_projects}
              navigate={~p"/deploy/#{project.id}"}
              class="flex items-center justify-between p-4 rounded-xl bg-white/5 hover:bg-white/10 transition-colors border border-white/5 group"
            >
              <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-lg bg-orange-500/20 flex items-center justify-center">
                  <svg class="w-4 h-4 text-orange-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd" />
                  </svg>
                </div>
                <div>
                  <p class="text-white font-medium text-sm group-hover:text-orange-300 transition-colors">
                    <%= project.github_url |> String.replace("https://github.com/", "") %>
                  </p>
                  <p class="text-slate-500 text-xs"><%= project.status %></p>
                </div>
              </div>
              <svg class="w-4 h-4 text-slate-600 group-hover:text-orange-400 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp feature_card(assigns) do
    ~H"""
    <div class="bg-white/5 backdrop-blur rounded-2xl border border-white/10 p-6 hover:border-orange-500/30 transition-colors">
      <div class="text-3xl mb-4"><%= @icon %></div>
      <h3 class="text-lg font-semibold text-white mb-2"><%= @title %></h3>
      <p class="text-slate-400 text-sm leading-relaxed"><%= @description %></p>
    </div>
    """
  end

  defp artifact_pill(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-3 rounded-xl bg-white/5 border border-white/5">
      <span class="text-2xl"><%= @icon %></span>
      <div>
        <p class="text-white text-sm font-medium"><%= @label %></p>
        <p class="text-slate-500 text-xs"><%= @sub %></p>
      </div>
    </div>
    """
  end
end
