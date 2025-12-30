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
    <Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="max-w-7xl mx-auto">
        <.header>
          Intelligence Dashboard
          <:subtitle>Welcome back! Here's what's happening with your projects.</:subtitle>
          <:actions>
            <.button navigate={~p"/projects/new"} variant="primary">
              <.icon name="hero-plus" class="size-5 mr-2" /> New Project
            </.button>
          </:actions>
        </.header>

        <!-- Stats Row -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
          <%= for {label, value, icon, color_class, trend} <- [
            {"Total Projects", Enum.count(@projects), "hero-briefcase", "bg-indigo-50 dark:bg-indigo-500/10 text-indigo-500", "+3.5%"},
            {"Active Analysis", Enum.count(@projects, & &1.analysis_status == "analyzing"), "hero-arrow-path", "bg-amber-50 dark:bg-amber-500/10 text-amber-500", "-2.1%"},
            {"Completed", Enum.count(@projects, & &1.analysis_status == "completed"), "hero-check-badge", "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-500", "+12.5%"},
            {"Insights Generated", "1.2k", "hero-sparkles", "bg-sky-50 dark:bg-sky-500/10 text-sky-500", "+0.5%"}
          ] do %>
            <div class="p-8 bg-white dark:bg-[#122C36] p-7 rounded-[2rem] shadow-soft border border-[#F1F3F5] dark:border-white/5 relative overflow-hidden group hover:border-[#27C281]/30 transition-all">
              <div class="flex items-center justify-between mb-6">
                <div class={["size-14 rounded-2xl flex items-center justify-center shrink-0 shadow-sm transition-transform group-hover:scale-110", color_class]}>
                  <.icon name={icon} class="size-7" />
                </div>
                <div class="text-right">
                  <span class="text-xs font-extrabold text-[#A0AEC0] uppercase tracking-widest">{label}</span>
                </div>
              </div>
              <div class="flex items-end justify-between">
                <div class="text-4xl font-extrabold text-[#0B222C] dark:text-white tracking-tight">{value}</div>
                <div class={[
                  "px-2.5 py-1.5 rounded-xl text-[10px] font-extrabold flex items-center gap-1.5 uppercase tracking-wider",
                  if(String.starts_with?(trend, "+"), do: "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-500", else: "bg-rose-50 dark:bg-rose-500/10 text-rose-500")
                ]}>
                  <.icon name={if(String.starts_with?(trend, "+"), do: "hero-arrow-trending-up", else: "hero-arrow-trending-down")} class="size-3.5" />
                  {trend}
                </div>
              </div>
              <div class="mt-3 text-[11px] font-bold text-[#A0AEC0] uppercase tracking-wider">vs last 7 days</div>
            </div>
          <% end %>
        </div>

        <!-- Projects Section -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Table -->
          <div class="lg:col-span-2">
            <.table id="projects" rows={@projects} row_click={fn project -> JS.navigate(~p"/projects/#{project.slug}") end}>
              <:col :let={project} label="Project">
                <div class="flex items-center gap-4">
                  <div class="size-12 rounded-2xl bg-[#f8f9fa] flex items-center justify-center text-primary font-bold text-sm border border-[#edf2f7]">
                    {String.slice(project.name, 0, 2) |> String.upcase()}
                  </div>
                  <div>
                    <div class="text-sm font-bold text-[#1a202c]">
                      {project.name}
                    </div>
                    <div class="text-xs text-[#a0aec0] mt-0.5">{project.url}</div>
                  </div>
                </div>
              </:col>
              <:col :let={project} label="Status">
                <span class={[
                  "px-3 py-1 rounded-xl text-[10px] font-bold uppercase tracking-wider",
                  case project.analysis_status do
                    "completed" -> "bg-[#e6f7ef] text-primary"
                    "analyzing" -> "bg-[#fff4e5] text-warning animate-pulse"
                    "failed" -> "bg-[#fff5f5] text-[#e53e3e]"
                    _ -> "bg-[#f8f9fa] text-[#a0aec0]"
                  end
                ]}>
                  {project.analysis_status}
                </span>
              </:col>
              <:col :let={project} label="Created">
                <div class="text-xs font-medium text-[#718096]">
                  {Calendar.strftime(project.inserted_at, "%d %B %Y")}
                </div>
              </:col>
              <:action :let={project}>
                <.link
                  navigate={~p"/projects/#{project.slug}"}
                  class="inline-flex items-center justify-center size-10 rounded-xl bg-[#F9FAFB] dark:bg-white/5 text-[#A0AEC0] hover:text-primary hover:bg-primary/10 transition-all border border-[#F1F3F5] dark:border-white/5"
                >
                  <.icon name="hero-chevron-right" class="size-5" />
                </.link>
              </:action>
            </.table>
          </div>

          <!-- Sidebar Cards -->
          <div class="space-y-8">
            <!-- Quick Start Card -->
            <div class="bg-[#0B222C] p-8 rounded-[2.5rem] shadow-2xl shadow-[#0B222C]/30 text-white relative overflow-hidden group">
               <div class="absolute top-0 right-0 p-8 opacity-10 -rotate-12 group-hover:scale-110 transition-transform">
                  <.icon name="hero-rocket-launch" class="size-32" />
               </div>
               <div class="relative z-10">
                  <h3 class="font-extrabold text-gray-700 uppercase tracking-wider">Ready to scale?</h3>
                  <p class="text-slate-300 text-sm leading-relaxed mb-8">
                     Analyze your product to unlock deep market insights and growth strategies.
                  </p>
                  <.link navigate={~p"/projects/new"} class="inline-flex items-center gap-2 px-6 py-3 rounded-2xl bg-[#27C281] text-[#0B222C] font-extrabold text-sm shadow-xl shadow-[#27C281]/20 hover:scale-105 transition-all">
                     Start New Project <.icon name="hero-arrow-right" class="size-4" />
                  </.link>
               </div>
            </div>

            <!-- Recent Analysis History -->
            <div class="bg-white dark:bg-[#122C36] p-8 rounded-[2.5rem] shadow-soft border border-[#F1F3F5] dark:border-white/5">
              <h3 class="font-extrabold text-[#0B222C] dark:text-white mb-8 tracking-tight uppercase text-xs tracking-widest text-[#A0AEC0]">Recent Market Events</h3>
              <div class="space-y-7">
                <%= for {title, date, status, icon, color} <- [
                  {"Persona Builder", "12 Jan 2024", "Completed", "hero-user-group", "bg-indigo-50 dark:bg-indigo-500/10 text-indigo-500 mb-4"},
                  {"Competitor Analysis", "11 Jan 2024", "Analyzing", "hero-magnifying-glass", "bg-amber-50 dark:bg-amber-500/10 text-amber-500 mb-4"},
                  {"Strategy Optimized", "07 Jan 2024", "Completed", "hero-sparkles", "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-500 mb-4"}
                ] do %>
                  <div class="flex items-center justify-between group cursor-pointer">
                    <div class="flex items-center gap-4">
                      <div class={["size-12 rounded-2xl flex items-center justify-center transition-transform group-hover:scale-110", color]}>
                        <.icon name={icon} class="size-6" />
                      </div>
                      <div>
                        <p class="text-sm font-extrabold text-[#0B222C] dark:text-white tracking-tight leading-none mb-1">{title}</p>
                        <p class="text-[11px] font-bold text-[#A0AEC0] uppercase tracking-wider">{date}</p>
                      </div>
                    </div>
                    <div class={[
                      "text-[10px] font-extrabold uppercase tracking-widest px-2 py-1 rounded-lg",
                      if(status == "Completed", do: "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-500", else: "bg-amber-50 dark:bg-amber-500/10 text-amber-500 animate-pulse")
                    ]}>
                      {status}
                    </div>
                  </div>
                <% end %>
              </div>
              <button class="w-full mt-10 py-4 rounded-[1.5rem] bg-[#F9FAFB] dark:bg-white/5 text-sm font-extrabold text-[#718096] dark:text-[#A0AEC0] hover:bg-gray-100 dark:hover:bg-white/10 transition-all uppercase tracking-widest">
                View Full Logs
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
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
