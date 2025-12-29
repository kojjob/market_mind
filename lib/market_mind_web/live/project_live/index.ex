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
     |> assign(:current_scope, :dashboard)
     |> assign(:projects, projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative px-4 sm:px-12 py-12 sm:py-20">
      <!-- Background Effects -->
      <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute -top-[10%] -left-[10%] size-[40%] bg-primary/10 rounded-full blur-[120px] animate-pulse">
        </div>
        <div
          class="absolute top-[20%] -right-[10%] size-[30%] bg-secondary/10 rounded-full blur-[100px] animate-pulse"
          style="animation-delay: 2s"
        >
        </div>
        <div class="absolute bottom-0 left-[20%] size-[50%] bg-primary/5 rounded-full blur-[150px]">
        </div>
      </div>

      <div class="relative max-w-7xl mx-auto">
        <!-- Hero Section -->
        <div class="space-y-8 mb-24">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 backdrop-blur-md text-xs font-black uppercase tracking-[0.3em] text-primary animate-in fade-in slide-in-from-top-4 duration-1000">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
            </span>
            Intelligence Dashboard
          </div>

          <h1 class="text-5xl sm:text-7xl font-black tracking-tighter leading-[0.9] animate-in fade-in slide-in-from-bottom-8 duration-1000 delay-200">
            Master Your <br />
            <span class="text-transparent bg-clip-text bg-linear-to-b from-white via-white to-white/20">
              Market Presence
            </span>
          </h1>

          <p class="text-xl text-zinc-400 max-w-2xl leading-relaxed animate-in fade-in slide-in-from-bottom-8 duration-1000 delay-300">
            Harness the power of AI to dissect your product, understand your audience, and dominate your niche with data-driven marketing strategies.
          </p>

          <div class="flex flex-col sm:flex-row items-center gap-6 pt-8 animate-in fade-in slide-in-from-bottom-8 duration-1000 delay-500">
            <.link
              navigate={~p"/projects/new"}
              class="group relative px-10 py-5 rounded-2xl bg-white text-zinc-950 font-black text-xl hover:scale-105 active:scale-95 transition-all shadow-[0_0_40px_rgba(255,255,255,0.1)] overflow-hidden"
            >
              <div class="absolute inset-0 bg-linear-to-r from-primary/20 to-secondary/20 opacity-0 group-hover:opacity-100 transition-opacity">
              </div>
              <span class="relative z-10 flex items-center gap-3">
                <.icon name="hero-plus-circle" class="size-6" /> Initialize Project
              </span>
            </.link>
          </div>
        </div>

    <!-- Stats Row -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-8 mb-24 animate-in fade-in slide-in-from-bottom-8 duration-1000 delay-700">
          <%= for {label, value, icon, color} <- [
            {"Total Projects", Enum.count(@projects), "hero-briefcase", "text-primary"},
            {"Active Analysis", Enum.count(@projects, & &1.analysis_status == "analyzing"), "hero-arrow-path", "text-secondary"},
            {"Completed", Enum.count(@projects, & &1.analysis_status == "completed"), "hero-check-badge", "text-emerald-400"},
            {"Success Rate", "98.2%", "hero-chart-bar", "text-amber-400"}
          ] do %>
            <div class="p-8 rounded-[2rem] bg-white/5 border border-white/10 backdrop-blur-xl hover:bg-white/10 transition-colors group">
              <div class={[
                "size-12 rounded-xl bg-white/5 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform",
                color
              ]}>
                <.icon name={icon} class="size-6" />
              </div>
              <div class="text-3xl font-black mb-1">{value}</div>
              <div class="text-xs font-black uppercase tracking-widest text-zinc-500">{label}</div>
            </div>
          <% end %>
        </div>

    <!-- Projects Grid -->
        <div class="space-y-12">
          <div class="flex items-center justify-between">
            <h2 class="text-3xl font-black tracking-tight">Active Projects</h2>
            <div class="flex items-center gap-4">
              <button class="p-3 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-colors">
                <.icon name="hero-squares-2x2" class="size-5" />
              </button>
              <button class="p-3 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-colors opacity-50">
                <.icon name="hero-list-bullet" class="size-5" />
              </button>
            </div>
          </div>

          <%= if Enum.empty?(@projects) do %>
            <div class="relative group">
              <div class="absolute -inset-4 bg-linear-to-r from-primary/20 via-secondary/20 to-primary/20 rounded-[4rem] blur-3xl opacity-20 group-hover:opacity-40 transition duration-1000 animate-pulse">
              </div>
              <div class="relative flex flex-col items-center justify-center rounded-[4rem] bg-zinc-900/50 border border-white/10 p-24 text-center backdrop-blur-3xl overflow-hidden">
                <div class="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 size-96 bg-primary/10 rounded-full blur-[120px]">
                </div>

                <div class="relative z-10">
                  <div class="size-32 rounded-[2.5rem] bg-white/5 border border-white/10 flex items-center justify-center text-zinc-700 mb-12 group-hover:rotate-12 group-hover:scale-110 transition-all duration-700 shadow-2xl">
                    <.icon name="hero-rocket-launch" class="size-16" />
                  </div>
                  <h2 class="text-5xl font-black mb-6 tracking-tighter">No Projects Found</h2>
                  <p class="text-2xl text-zinc-500 max-w-lg mx-auto mb-16 leading-relaxed font-medium">
                    Your intelligence workspace is ready. Initialize your first project to start generating market-dominating insights.
                  </p>
                  <.link
                    navigate={~p"/projects/new"}
                    class="group relative inline-flex items-center gap-4 px-12 py-6 rounded-3xl bg-white text-zinc-950 font-black text-2xl hover:scale-105 active:scale-95 transition-all shadow-[0_0_50px_rgba(255,255,255,0.1)] overflow-hidden"
                  >
                    <div class="absolute inset-0 bg-linear-to-r from-primary/20 to-secondary/20 opacity-0 group-hover:opacity-100 transition-opacity">
                    </div>
                    <span class="relative z-10">Get Started</span>
                    <.icon
                      name="hero-arrow-right"
                      class="size-8 relative z-10 group-hover:translate-x-2 transition-transform"
                    />
                  </.link>
                </div>
              </div>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
              <%= for project <- @projects do %>
                <div class="group relative">
                  <!-- Card Glow -->
                  <div class="absolute -inset-0.5 bg-linear-to-br from-primary/20 to-secondary/20 rounded-[3rem] blur opacity-0 group-hover:opacity-100 transition duration-700">
                  </div>

                  <.link
                    navigate={~p"/projects/#{project.slug}"}
                    class="relative flex flex-col h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 hover:border-white/20 transition-all duration-500 overflow-hidden backdrop-blur-3xl"
                  >
                    <!-- Glass Reflection -->
                    <div class="absolute top-0 left-0 w-full h-1/2 bg-linear-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700">
                    </div>

    <!-- Card Content -->
                    <div class="relative p-10 flex flex-col h-full">
                      <div class="flex justify-between items-start mb-10">
                        <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-zinc-500 group-hover:text-white group-hover:border-primary/50 group-hover:scale-110 transition-all duration-500 shadow-2xl">
                          <.icon name="hero-briefcase" class="size-8" />
                        </div>
                        <div class="flex flex-col items-end gap-3">
                          <.status_indicator status={project.analysis_status} />
                          <button class="size-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center text-zinc-500 hover:text-white hover:bg-white/10 transition-all">
                            <.icon name="hero-ellipsis-horizontal" class="size-6" />
                          </button>
                        </div>
                      </div>

                      <div class="space-y-4 mb-8">
                        <h3 class="text-3xl font-black tracking-tight group-hover:text-primary transition-colors duration-300 leading-tight">
                          {project.name}
                        </h3>
                        <div class="flex items-center gap-3 text-sm font-black text-zinc-500 uppercase tracking-widest">
                          <div class="size-6 rounded-lg bg-white/5 flex items-center justify-center">
                            <.icon name="hero-link" class="size-3" />
                          </div>
                          <span class="truncate max-w-[200px]">{project.url}</span>
                        </div>
                      </div>

                      <%= if project.description do %>
                        <p class="text-zinc-400 font-bold text-lg line-clamp-2 leading-relaxed mb-10">
                          {project.description}
                        </p>
                      <% end %>

                      <div class="mt-auto pt-8 border-t border-white/5 flex items-center justify-between">
                        <div class="flex items-center gap-4">
                          <div class="relative">
                            <div class="absolute -inset-1 bg-linear-to-r from-primary to-secondary rounded-full blur opacity-20 group-hover:opacity-40 transition duration-500">
                            </div>
                            <div class="relative size-12 rounded-full bg-zinc-800 border border-white/10 flex items-center justify-center text-[10px] font-black text-white">
                              AI
                            </div>
                          </div>
                          <div class="flex flex-col">
                            <span class="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-600">
                              Last Analysis
                            </span>
                            <span class="text-sm font-black text-zinc-300">
                              {Calendar.strftime(project.inserted_at, "%b %d, %Y")}
                            </span>
                          </div>
                        </div>

                        <div class="size-14 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-zinc-500 group-hover:text-zinc-950 group-hover:bg-white group-hover:border-white group-hover:translate-x-2 transition-all duration-500 shadow-2xl">
                          <.icon name="hero-arrow-right" class="size-7" />
                        </div>
                      </div>
                    </div>
                  </.link>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Status indicator component
  defp status_indicator(assigns) do
    config =
      case assigns.status do
        "pending" ->
          %{color: "bg-amber-400", text: "Pending", icon: "hero-clock"}

        "queued" ->
          %{color: "bg-blue-400", text: "Queued", icon: "hero-list-bullet"}

        "analyzing" ->
          %{color: "bg-primary", text: "Analyzing", icon: "hero-arrow-path", animate: true}

        "completed" ->
          %{color: "bg-emerald-500", text: "Completed", icon: "hero-check-circle"}

        "failed" ->
          %{color: "bg-rose-500", text: "Failed", icon: "hero-exclamation-triangle"}

        _ ->
          %{color: "bg-zinc-400", text: "Unknown", icon: "hero-question-mark-circle"}
      end

    assigns = assign(assigns, :config, config)

    ~H"""
    <div class="flex items-center gap-2.5 px-4 py-2 rounded-full bg-white/5 border border-white/10 backdrop-blur-md">
      <div class={["size-2 rounded-full", @config.color, @config[:animate] && "animate-pulse"]}></div>
      <span class="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-300">
        {@config.text}
      </span>
    </div>
    """
  end

  # Temporary user helper - in production this would use authentication
  defp get_or_create_user do
    alias MarketMind.Accounts.User
    alias MarketMind.Repo

    case Repo.get_by(User, email: "demo@marketmind.app") do
      nil ->
        # Demo user with placeholder password - in production, use proper auth
        {:ok, user} =
          Repo.insert(%User{
            email: "demo@marketmind.app",
            hashed_password: "$2b$12$demo_placeholder_hash_for_development"
          })

        user

      user ->
        user
    end
  end
end
