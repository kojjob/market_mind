defmodule MarketMindWeb.ProjectLive.Show do
  @moduledoc """
  LiveView for displaying project details and analysis results.

  Features:
  - Real-time status updates via PubSub
  - Analysis progress tracking
  - Comprehensive analysis result display
  - Actions for re-analyzing or editing
  """
  use MarketMindWeb, :live_view

  alias MarketMind.Products

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project = Products.get_project_by_slug(slug)

    if project do
      # Subscribe to real-time updates for this project
      if connected?(socket) do
        Phoenix.PubSub.subscribe(MarketMind.PubSub, "project:#{project.id}")
      end

      {:ok,
       socket
       |> assign(:page_title, project.name)
       |> assign(:project, project)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Project not found")
       |> push_navigate(to: ~p"/projects")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <.link navigate={~p"/projects"} class="btn btn-ghost btn-sm gap-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Back to Projects
        </.link>
      </div>

      <div class="flex flex-col lg:flex-row gap-6">
        <!-- Main Content -->
        <div class="flex-1">
          <!-- Header Card -->
          <div class="card bg-base-100 shadow-xl mb-6">
            <div class="card-body">
              <div class="flex justify-between items-start">
                <div>
                  <h1 class="card-title text-3xl"><%= @project.name %></h1>
                  <a href={@project.url} target="_blank" class="link link-primary text-sm flex items-center gap-1 mt-1">
                    <%= @project.url %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                  </a>
                </div>
                <.status_badge status={@project.analysis_status} />
              </div>

              <%= if @project.description do %>
                <p class="text-base-content/70 mt-4"><%= @project.description %></p>
              <% end %>
            </div>
          </div>

          <!-- Analysis Status / Results -->
          <%= case @project.analysis_status do %>
            <% "pending" -> %>
              <.pending_state />
            <% "queued" -> %>
              <.queued_state />
            <% "analyzing" -> %>
              <.analyzing_state />
            <% "completed" -> %>
              <.completed_state analysis={@project.analysis_data} analyzed_at={@project.analyzed_at} />
            <% "failed" -> %>
              <.failed_state project={@project} />
            <% _ -> %>
              <.unknown_state />
          <% end %>
        </div>

        <!-- Sidebar -->
        <div class="lg:w-80">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title text-lg">Project Info</h2>
              <div class="divider my-2"></div>

              <div class="space-y-4 text-sm">
                <div>
                  <span class="font-medium text-base-content/70">Status</span>
                  <p class="capitalize"><%= @project.analysis_status %></p>
                </div>

                <div>
                  <span class="font-medium text-base-content/70">Created</span>
                  <p><%= format_datetime(@project.inserted_at) %></p>
                </div>

                <%= if @project.analyzed_at do %>
                  <div>
                    <span class="font-medium text-base-content/70">Last Analyzed</span>
                    <p><%= format_datetime(@project.analyzed_at) %></p>
                  </div>
                <% end %>
              </div>

              <div class="divider my-2"></div>

              <div class="card-actions flex-col gap-2">
                <%= if @project.analysis_status in ["completed", "failed"] do %>
                  <button phx-click="reanalyze" class="btn btn-primary btn-block">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    Re-analyze
                  </button>
                <% end %>
                <button class="btn btn-ghost btn-block" disabled>
                  Edit Project
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Status Components

  defp pending_state(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center py-12">
        <div class="loading loading-spinner loading-lg text-warning"></div>
        <h2 class="card-title text-xl mt-4">Pending Analysis</h2>
        <p class="text-base-content/70">
          Your project is waiting to be analyzed. This should start shortly.
        </p>
      </div>
    </div>
    """
  end

  defp queued_state(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center py-12">
        <div class="loading loading-dots loading-lg text-info"></div>
        <h2 class="card-title text-xl mt-4">Queued for Analysis</h2>
        <p class="text-base-content/70">
          Your project is in the queue. Analysis will begin soon.
        </p>
      </div>
    </div>
    """
  end

  defp analyzing_state(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center py-12">
        <div class="radial-progress text-primary" style="--value:70; --size:5rem;">
          <span class="loading loading-spinner loading-sm"></span>
        </div>
        <h2 class="card-title text-xl mt-4">Analyzing Your Product</h2>
        <p class="text-base-content/70">
          Our AI is examining your website and extracting marketing insights...
        </p>
        <div class="mt-4 flex flex-wrap gap-2 justify-center">
          <span class="badge badge-outline">Fetching website</span>
          <span class="badge badge-outline badge-primary">Analyzing content</span>
          <span class="badge badge-outline">Generating insights</span>
        </div>
      </div>
    </div>
    """
  end

  defp completed_state(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Success Banner -->
      <div class="alert alert-success">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span>Analysis completed successfully on <%= format_datetime(@analyzed_at) %></span>
      </div>

      <!-- Product Overview -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-2xl"><%= @analysis["product_name"] %></h2>
          <p class="text-lg text-primary font-medium italic">"<%= @analysis["tagline"] %>"</p>

          <div class="divider"></div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 class="font-bold text-base-content/80 mb-2">Target Audience</h3>
              <p><%= @analysis["target_audience"] %></p>
            </div>
            <div>
              <h3 class="font-bold text-base-content/80 mb-2">Pricing Model</h3>
              <span class="badge badge-lg badge-primary capitalize"><%= @analysis["pricing_model"] %></span>
            </div>
            <div>
              <h3 class="font-bold text-base-content/80 mb-2">Tone</h3>
              <span class="badge badge-lg badge-secondary capitalize"><%= @analysis["tone"] %></span>
            </div>
            <div>
              <h3 class="font-bold text-base-content/80 mb-2">Industries</h3>
              <div class="flex flex-wrap gap-2">
                <%= for industry <- @analysis["industries"] || [] do %>
                  <span class="badge badge-outline"><%= industry %></span>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Value Propositions -->
      <%= if @analysis["value_propositions"] && length(@analysis["value_propositions"]) > 0 do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Value Propositions</h2>
            <ul class="list-disc list-inside space-y-2">
              <%= for vp <- @analysis["value_propositions"] do %>
                <li class="text-base-content/80"><%= vp %></li>
              <% end %>
            </ul>
          </div>
        </div>
      <% end %>

      <!-- Key Features -->
      <%= if @analysis["key_features"] && length(@analysis["key_features"]) > 0 do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Key Features</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
              <%= for feature <- @analysis["key_features"] do %>
                <div class="p-4 bg-base-200 rounded-lg">
                  <h3 class="font-bold"><%= feature["name"] %></h3>
                  <p class="text-sm text-base-content/70"><%= feature["description"] %></p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Unique Differentiators -->
      <%= if @analysis["unique_differentiators"] && length(@analysis["unique_differentiators"]) > 0 do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Unique Differentiators</h2>
            <div class="flex flex-wrap gap-3 mt-2">
              <%= for diff <- @analysis["unique_differentiators"] do %>
                <span class="badge badge-lg badge-accent"><%= diff %></span>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp failed_state(assigns) do
    ~H"""
    <div class="card bg-error/10 shadow-lg">
      <div class="card-body items-center text-center py-12">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <h2 class="card-title text-xl mt-4 text-error">Analysis Failed</h2>
        <p class="text-base-content/70">
          We couldn't complete the analysis for this project.
          This might be due to the website being unavailable or blocking our access.
        </p>
        <button phx-click="reanalyze" class="btn btn-primary mt-4">
          Try Again
        </button>
      </div>
    </div>
    """
  end

  defp unknown_state(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center py-12">
        <p class="text-base-content/70">Unknown status. Please refresh the page.</p>
      </div>
    </div>
    """
  end

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
    <span class={"badge #{@badge_class} capitalize status-badge"}>
      <%= @status %>
    </span>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("reanalyze", _params, socket) do
    project = socket.assigns.project

    case Products.queue_analysis(project) do
      {:ok, updated_project} ->
        {:noreply,
         socket
         |> assign(:project, updated_project)
         |> put_flash(:info, "Re-analysis started!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start re-analysis")}
    end
  end

  # PubSub Handlers

  @impl true
  def handle_info({:analysis_completed, %{status: _status}}, socket) do
    # Reload the project to get the latest data
    project = Products.get_project!(socket.assigns.project.id)
    {:noreply, assign(socket, :project, project)}
  end

  def handle_info({:analysis_status_changed, %{status: _status}}, socket) do
    # Reload the project on any status change
    project = Products.get_project!(socket.assigns.project.id)
    {:noreply, assign(socket, :project, project)}
  end

  # Helpers

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
