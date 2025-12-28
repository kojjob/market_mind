defmodule MarketMindWeb.ProjectLive.Index do
  @moduledoc """
  LiveView for listing user's projects.

  Shows all projects belonging to the current user with their
  analysis status and quick actions.
  """
  use MarketMindWeb, :live_view

  alias MarketMind.Products

  @impl true
  def mount(_params, _session, socket) do
    # For now, we'll use a temporary user approach
    # In production, this would come from authentication
    user = get_or_create_user()
    projects = Products.list_projects_for_user(user)

    {:ok,
     socket
     |> assign(:page_title, "Your Projects")
     |> assign(:user, user)
     |> assign(:projects, projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-base-content">Your Projects</h1>
        <.link
          navigate={~p"/projects/new"}
          class="btn btn-primary"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Add Project
        </.link>
      </div>

      <%= if Enum.empty?(@projects) do %>
        <div class="card bg-base-200 shadow-lg">
          <div class="card-body items-center text-center py-16">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-base-content/40 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h2 class="card-title text-xl">No projects yet</h2>
            <p class="text-base-content/70 mb-4">
              Add your first project to start analyzing your SaaS product's marketing potential.
            </p>
            <.link navigate={~p"/projects/new"} class="btn btn-primary">
              Add your first project
            </.link>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for project <- @projects do %>
            <.link navigate={~p"/projects/#{project.slug}"} class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer">
              <div class="card-body">
                <div class="flex justify-between items-start">
                  <h2 class="card-title text-lg"><%= project.name %></h2>
                  <.status_badge status={project.analysis_status} />
                </div>
                <p class="text-base-content/70 text-sm truncate"><%= project.url %></p>
                <%= if project.description do %>
                  <p class="text-base-content/60 text-sm line-clamp-2"><%= project.description %></p>
                <% end %>
                <div class="card-actions justify-end mt-4">
                  <span class="text-xs text-base-content/50">
                    Created <%= format_date(project.inserted_at) %>
                  </span>
                </div>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Status badge component
  defp status_badge(assigns) do
    badge_class = case assigns.status do
      "pending" -> "badge-warning"
      "queued" -> "badge-info"
      "analyzing" -> "badge-info badge-outline"
      "completed" -> "badge-success"
      "failed" -> "badge-error"
      _ -> "badge-ghost"
    end

    assigns = assign(assigns, :badge_class, badge_class)

    ~H"""
    <span class={"badge #{@badge_class} capitalize"}>
      <%= @status %>
    </span>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  # Temporary user helper - in production this would use authentication
  defp get_or_create_user do
    alias MarketMind.Accounts.User
    alias MarketMind.Repo

    case Repo.get_by(User, email: "demo@marketmind.app") do
      nil ->
        # Demo user with placeholder password - in production, use proper auth
        {:ok, user} = Repo.insert(%User{
          email: "demo@marketmind.app",
          hashed_password: "$2b$12$demo_placeholder_hash_for_development"
        })
        user

      user ->
        user
    end
  end
end
