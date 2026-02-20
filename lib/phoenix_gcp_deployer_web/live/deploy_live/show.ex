defmodule PhoenixGcpDeployerWeb.DeployLive.Show do
  @moduledoc "Shows a saved deployment project and its generated files."

  use PhoenixGcpDeployerWeb, :live_view

  alias PhoenixGcpDeployer.Deployments

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Deployments.get_project(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> redirect(to: ~p"/")}

      project ->
        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:deployments, Deployments.list_deployments(project))
         |> assign(:page_title, "Project: #{project.github_url}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <.link navigate={~p"/"} class="inline-flex items-center gap-2 text-slate-400 hover:text-white text-sm mb-6 transition-colors">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
          Back to home
        </.link>

        <div class="bg-white/5 backdrop-blur rounded-2xl border border-white/10 p-8">
          <h1 class="text-2xl font-bold text-white mb-2">
            <%= @project.github_url |> String.replace("https://github.com/", "") %>
          </h1>
          <p class="text-slate-400 text-sm mb-6"><%= @project.github_url %></p>

          <%= if length(@deployments) == 0 do %>
            <div class="text-center py-12">
              <p class="text-slate-400 mb-4">No deployments configured yet.</p>
              <.link
                navigate={~p"/deploy"}
                class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 text-white text-sm font-medium"
              >
                Configure deployment
              </.link>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for deployment <- @deployments do %>
                <div class="p-4 rounded-xl bg-white/5 border border-white/10">
                  <div class="flex justify-between items-start">
                    <div>
                      <p class="text-white font-medium"><%= deployment.name %></p>
                      <p class="text-slate-500 text-xs mt-1">
                        <%= deployment.environment %> · <%= deployment.gcp_region %>
                      </p>
                    </div>
                    <span class={[
                      "text-xs px-2 py-1 rounded-full font-medium",
                      case deployment.status do
                        "ready" -> "bg-green-500/20 text-green-400"
                        "draft" -> "bg-slate-500/20 text-slate-400"
                        _ -> "bg-orange-500/20 text-orange-400"
                      end
                    ]}>
                      <%= deployment.status %>
                    </span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
