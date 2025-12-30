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
  alias MarketMind.Personas
  alias MarketMind.Content

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
       |> assign(:current_scope, :dashboard)
       |> assign(:project, project)
       |> assign(:personas, Personas.list_personas(project))
       |> assign(:contents, Content.list_contents(project))
       |> assign(:loading_agents, %{})
       |> assign(:active_tab, "overview")}
    else
      {:ok,
       socket
       |> put_flash(:error, "Project not found")
       |> assign(:current_scope, :dashboard)
       |> push_navigate(to: ~p"/projects")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="relative w-full max-w-7xl mx-auto pb-20">
        <!-- Background Ambient Mesh -->
        <div class="absolute top-0 left-0 w-full h-[500px] bg-gradient-to-b from-indigo-50/50 via-white to-transparent dark:from-[#122C36] dark:via-[#0B222C] dark:to-[#0B222C] -z-10 blur-3xl opacity-60 pointer-events-none"></div>
        <div class="absolute -top-20 -right-20 size-96 bg-[#27C281]/10 rounded-full blur-[100px] pointer-events-none"></div>
        <div class="absolute top-20 -left-20 size-72 bg-blue-500/10 rounded-full blur-[80px] pointer-events-none"></div>

        <!-- Header & Breadcrumbs -->
        <div class="relative z-10 flex flex-col md:flex-row md:items-end justify-between gap-8 mb-16 pt-8">
          <div class="flex-1">
            <nav class="flex mb-6" aria-label="Breadcrumb">
              <ol class="inline-flex items-center gap-3">
                <li>
                  <.link navigate={~p"/projects"} class="text-xs font-extrabold text-[#A0AEC0] hover:text-[#0B222C] dark:hover:text-white transition-colors uppercase tracking-widest flex items-center gap-2">
                    <.icon name="hero-squares-2x2" class="size-4" />
                    Dashboard
                  </.link>
                </li>
                <li>
                  <div class="flex items-center gap-3 text-[#A0AEC0]">
                    <.icon name="hero-chevron-right" class="size-3 stroke-[3px]" />
                    <span class="text-xs font-extrabold text-[#0B222C] dark:text-white uppercase tracking-widest bg-white/50 dark:bg-white/5 px-2 py-1 rounded-lg">
                      {@project.name}
                    </span>
                  </div>
                </li>
              </ol>
            </nav>

            <div class="flex items-center gap-8">
              <div class="relative group">
                <div class="absolute inset-0 bg-gradient-to-tr from-[#27C281] to-blue-500 rounded-[2rem] blur opacity-20 group-hover:opacity-40 transition-opacity duration-500"></div>
                <div class="relative size-24 rounded-[2rem] bg-white dark:bg-[#122C36] flex items-center justify-center shadow-soft border border-[#F1F3F5] dark:border-white/5 z-10 group-hover:scale-105 transition-transform duration-300">
                  <div class="absolute inset-0 rounded-[2rem] bg-gradient-to-br from-white/40 to-transparent dark:from-white/5 dark:to-transparent pointer-events-none"></div>
                  <.icon name="hero-bolt" class="size-10 text-[#0B222C] dark:text-white" />
                </div>
              </div>

              <div class="space-y-3">
                <h1 class="text-5xl font-black text-[#0B222C] dark:text-white tracking-tight leading-none drop-shadow-sm">
                  {@project.name}
                </h1>
                <div class="flex items-center gap-4">
                  <.status_badge status={@project.analysis_status} />
                  <div class="h-1.5 w-1.5 rounded-full bg-[#A0AEC0]"></div>
                  <span class="text-xs font-bold text-[#A0AEC0] uppercase tracking-widest flex items-center gap-2">
                    <.icon name="hero-link" class="size-3" />
                    {@project.url}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-4 pb-2">
            <%= if @project.analysis_status in ["completed", "failed"] do %>
              <button
                phx-click="reanalyze"
                class="glass-panel px-6 py-4 rounded-2xl shadow-sm hover:shadow-md text-xs font-extrabold text-[#0B222C] dark:text-white transition-all uppercase tracking-widest hover:-translate-y-1 flex items-center gap-2"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Re-analyze
              </button>
            <% end %>
            <a
              href={@project.url}
              target="_blank"
              class="relative px-8 py-4 bg-[#0B222C] dark:bg-[#27C281] text-white dark:text-[#0B222C] rounded-2xl shadow-xl shadow-[#0B222C]/20 dark:shadow-[#27C281]/20 text-xs font-extrabold hover:-translate-y-1 hover:shadow-2xl transition-all uppercase tracking-widest flex items-center gap-2 overflow-hidden group"
            >
              <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300"></div>
              <.icon name="hero-arrow-top-right-on-square" class="size-4" /> Visit Site
            </a>
          </div>
        </div>

        <div id="analysis-container" phx-update="replace" class="animate-in fade-in slide-in-from-bottom-8 duration-700">
          <%= case @project.analysis_status do %>
            <% "pending" -> %>
              <.pending_state />
            <% "queued" -> %>
              <.queued_state />
            <% "analyzing" -> %>
              <.analyzing_state />
            <% "completed" -> %>
              <.completed_state
                analysis={@project.analysis_data}
                personas={@personas}
                contents={@contents}
                analyzed_at={@project.analyzed_at}
                loading_agents={@loading_agents}
                project={@project}
                active_tab={@active_tab}
              />
            <% "failed" -> %>
              <.failed_state project={@project} />
            <% _ -> %>
              <.unknown_state />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Status Components

  defp status_badge(assigns) do
    {color_class, text, dot_color} =
      case assigns.status do
        "pending" -> {"bg-gray-100/50 text-gray-500 dark:bg-white/5 dark:text-gray-400", "Pending", "bg-gray-400"}
        "queued" -> {"bg-blue-50/50 text-blue-500 dark:bg-blue-500/10 dark:text-blue-400", "Queued", "bg-blue-500"}
        "analyzing" -> {"bg-amber-50/50 text-amber-500 dark:bg-amber-500/10 dark:text-amber-400", "Analyzing", "bg-amber-500"}
        "completed" -> {"bg-[#27C281]/10 text-[#27C281]", "Completed", "bg-[#27C281]"}
        "failed" -> {"bg-red-50/50 text-red-500 dark:bg-red-500/10 dark:text-red-400", "Failed", "bg-red-500"}
        _ -> {"bg-gray-100/50 text-gray-500", "Unknown", "bg-gray-400"}
      end

    assigns = assign(assigns, color_class: color_class, text: text, dot_color: dot_color)

    ~H"""
    <span class={["pl-2.5 pr-4 py-1.5 rounded-full text-[0.65rem] font-extrabold uppercase tracking-[0.15em] shadow-sm backdrop-blur-md flex items-center gap-2 border border-black/5 dark:border-white/5", @color_class]}>
      <span class={["size-2 rounded-full animate-pulse", @dot_color]}></span>
      {@text}
    </span>
    """
  end

  defp pending_state(assigns) do
    ~H"""
    <div class="glass-card rounded-[2.5rem] p-24 text-center">
      <div class="relative size-32 mx-auto mb-12">
        <div class="absolute inset-0 bg-[#A0AEC0]/10 rounded-full animate-pulse-soft blur-xl"></div>
        <div class="relative size-32 rounded-full bg-white dark:bg-[#122C36] shadow-soft flex items-center justify-center text-[#A0AEC0] border border-[#F1F3F5] dark:border-white/5">
          <.icon name="hero-clock" class="size-14" />
        </div>
      </div>
      <h3 class="text-3xl font-black text-[#0B222C] dark:text-white tracking-tight mb-4">Awaiting Analysis</h3>
      <p class="text-base font-bold text-[#A0AEC0] max-w-md mx-auto leading-relaxed">
        Your project is in the system and waiting for the analysis engine to pick it up.
      </p>
    </div>
    """
  end

  defp queued_state(assigns) do
    ~H"""
    <div class="glass-card rounded-[2.5rem] p-24 text-center">
      <div class="relative size-32 mx-auto mb-12">
        <div class="absolute inset-0 bg-blue-500/10 rounded-full animate-pulse-soft blur-xl"></div>
        <div class="relative size-32 rounded-full bg-white dark:bg-[#122C36] shadow-soft flex items-center justify-center text-blue-500 border border-[#F1F3F5] dark:border-white/5">
          <.icon name="hero-queue-list" class="size-14" />
        </div>
      </div>
      <h3 class="text-3xl font-black text-[#0B222C] dark:text-white tracking-tight mb-4">Analysis Queued</h3>
      <p class="text-base font-bold text-[#A0AEC0] max-w-md mx-auto leading-relaxed">
        We've received your request. Analysis will begin as soon as a worker is available.
      </p>
    </div>
    """
  end

  defp analyzing_state(assigns) do
    ~H"""
    <div class="glass-card rounded-[2.5rem] p-24 text-center relative overflow-hidden group">
      <!-- Shimmer Progress Top -->
      <div class="absolute top-0 left-0 w-full h-1">
        <div class="h-full bg-gradient-to-r from-transparent via-[#27C281] to-transparent animate-shimmer"></div>
      </div>

      <div class="relative z-10">
        <div class="relative size-32 mx-auto mb-12">
          <div class="absolute inset-0 bg-[#27C281]/20 rounded-full animate-ping opacity-20"></div>
          <div class="relative size-32 rounded-full bg-white dark:bg-[#122C36] shadow-soft flex items-center justify-center text-[#27C281] border border-[#F1F3F5] dark:border-white/5">
             <.icon name="hero-arrow-path" class="size-14 animate-spin" />
          </div>
        </div>
        <h3 class="text-3xl font-black text-[#0B222C] dark:text-white tracking-tight mb-4">Analyzing Your Product</h3>
        <p class="text-base font-bold text-[#A0AEC0] max-w-md mx-auto leading-relaxed mb-12">
          Our AI is currently crawling your website and generating tailored insights for your market.
        </p>

        <div class="flex flex-wrap justify-center gap-4">
          <%= for {icon, label, active} <- [
            {"hero-globe-alt", "Crawling Pages", true},
            {"hero-user-group", "Generating Personas", true},
            {"hero-document-text", "Generating Report", false}
          ] do %>
            <div class={[
              "px-6 py-3 rounded-2xl border flex items-center gap-3 text-xs font-extrabold uppercase tracking-widest transition-all",
              if(active, do: "bg-white dark:bg-[#122C36] border-[#27C281]/30 text-[#0B222C] dark:text-white shadow-lg shadow-[#27C281]/10", else: "bg-transparent border-dashed border-[#A0AEC0]/30 text-[#A0AEC0] opacity-60")
            ]}>
              <%= if active do %>
                <div class="size-2 rounded-full bg-[#27C281] animate-pulse"></div>
              <% else %>
                <.icon name={icon} class="size-4" />
              <% end %>
              {label}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp completed_state(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row gap-8">
      <div class="flex-1 space-y-8">
        <!-- Floating Glass Tabs Navigation -->
        <div class="sticky top-4 z-20 flex justify-center pb-4">
          <div class="glass-panel p-1.5 rounded-full shadow-lg border border-white/20 dark:border-white/5 backdrop-blur-2xl inline-flex items-center gap-1 overflow-x-auto max-w-full no-scrollbar">
            <%= for {id, label, icon} <- [
              {"overview", "Overview", "hero-squares-2x2"},
              {"personas", "Personas", "hero-user-group"},
              {"competitors", "Competitors", "hero-magnifying-glass"},
              {"leads", "Leads", "hero-user-plus"},
              {"content", "Content", "hero-megaphone"},
              {"cro", "CRO", "hero-presentation-chart-line"},
              {"aeo", "AEO", "hero-cpu-chip"}
            ] do %>
              <button
                phx-click="switch_tab"
                phx-value-tab={id}
                class={[
                  "flex items-center gap-2 px-5 py-2.5 text-[0.7rem] font-black transition-all rounded-full whitespace-nowrap uppercase tracking-widest relative group overflow-hidden",
                  @active_tab == id && "bg-[#0B222C] dark:bg-[#27C281] text-white dark:text-[#0B222C] shadow-lg shadow-[#0B222C]/20 dark:shadow-[#27C281]/30",
                  @active_tab != id && "text-[#A0AEC0] hover:text-[#0B222C] dark:hover:text-white hover:bg-white/50 dark:hover:bg-white/5"
                ]}
              >
                <%= if @active_tab == id do %>
                   <div class="absolute inset-0 bg-gradient-to-tr from-white/10 to-transparent pointer-events-none"></div>
                <% end %>
                <.icon name={icon} class="size-4" />
                {label}
              </button>
            <% end %>
          </div>
        </div>

        <div class="tab-content animate-in slide-in-from-bottom-8 duration-700">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab analysis={@analysis} analyzed_at={@analyzed_at} loading_agents={@loading_agents} personas={@personas} />
            <% "personas" -> %>
              <.persona_results personas={@personas} project={@project} loading={@loading_agents["personas"]} />
            <% "competitors" -> %>
              <.competitor_results competitors={@analysis["competitors"]} loading={@loading_agents["competitors"]} />
            <% "leads" -> %>
              <.lead_results leads={@analysis["leads"]} loading={@loading_agents["leads"]} />
            <% "content" -> %>
              <.content_results content={@analysis["content"]} loading={@loading_agents["content"]} />
            <% "cro" -> %>
              <.cro_results audit={@analysis["cro_audit"]} loading={@loading_agents["cro"]} />
            <% "aeo" -> %>
              <.aeo_results aeo={@analysis["aeo_strategy"]} loading={@loading_agents["aeo"]} />
          <% end %>
        </div>
      </div>

      <!-- Right Column: Summary & Actions -->
      <div class="w-full lg:w-[350px] space-y-8">
        <div class="glass-card rounded-[2.5rem] p-8 relative overflow-hidden group">
          <div class="absolute top-0 right-0 p-8 opacity-5 group-hover:opacity-10 transition-opacity">
            <.icon name="hero-chart-bar-square" class="size-48" />
          </div>
          <div class="relative z-10">
            <h3 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-widest mb-8 flex items-center gap-2">
              <div class="size-1.5 rounded-full bg-[#27C281] animate-pulse"></div> Analysis Summary
            </h3>
            <div class="space-y-6">
              <%= for {icon, label, count, color, bg_color} <- [
                {"hero-user-group", "Personas", Enum.count(@personas), "text-indigo-500", "bg-indigo-50 dark:bg-indigo-500/10"},
                {"hero-magnifying-glass", "Competitors", Enum.count(@analysis["competitors"] || []), "text-blue-500", "bg-blue-50 dark:bg-blue-500/10"},
                {"hero-user-plus", "strategies", Enum.count(@analysis["leads"] || []), "text-amber-500", "bg-amber-50 dark:bg-amber-500/10"}
              ] do %>
                <div class="flex items-center justify-between group/item p-4 rounded-3xl hover:bg-[#F9FAFB] dark:hover:bg-white/5 transition-colors border border-transparent hover:border-[#F1F3F5] dark:hover:border-white/5 cursor-default">
                  <div class="flex items-center gap-4">
                    <div class={["size-12 rounded-2xl flex items-center justify-center shadow-sm transition-transform group-hover/item:scale-110", bg_color, color]}>
                      <.icon name={icon} class="size-6" />
                    </div>
                    <div>
                      <p class="text-[0.6rem] font-extrabold text-[#A0AEC0] uppercase tracking-wider mb-0.5">{label}</p>
                      <p class="text-xl font-black text-[#0B222C] dark:text-white leading-none">
                        {count}
                      </p>
                    </div>
                  </div>
                  <div class="size-6 rounded-full bg-[#27C281]/10 flex items-center justify-center">
                     <.icon name="hero-check" class="size-3 text-[#27C281]" />
                  </div>
                </div>
              <% end %>
            </div>

            <div class="mt-8 pt-8 border-t border-[#F1F3F5] dark:border-white/5">
              <p class="text-[0.65rem] font-bold text-[#A0AEC0] uppercase tracking-wider mb-6 text-center">
                Analyzed {Calendar.strftime(@analyzed_at, "%b %d, %H:%M")}
              </p>
              <button class="w-full py-4 bg-[#0B222C] dark:bg-white dark:text-[#0B222C] text-white rounded-2xl font-extrabold shadow-xl shadow-[#0B222C]/20 hover:shadow-2xl hover:-translate-y-1 transition-all flex items-center justify-center gap-3 uppercase tracking-widest text-xs group/btn">
                <.icon name="hero-arrow-down-tray" class="size-4 group-hover/btn:animate-bounce" />
                Download Report
              </button>
            </div>
          </div>
        </div>

        <div class="relative rounded-[2.5rem] bg-gradient-to-br from-[#27C281] to-[#20A06A] p-8 text-[#0B222C] overflow-hidden group shadow-glow">
          <div class="absolute inset-0 bg-[url('/images/noise.png')] opacity-10 mix-blend-overlay"></div>
          <div class="absolute -bottom-10 -right-10 p-10 opacity-20 group-hover:scale-110 transition-transform duration-700 ease-out">
            <.icon name="hero-sparkles" class="size-48 rotate-12" />
          </div>

          <div class="relative z-10">
             <div class="size-12 rounded-2xl bg-[#0B222C] flex items-center justify-center mb-6 shadow-lg shadow-[#0B222C]/20 text-[#27C281]">
                <.icon name="hero-star" class="size-6" />
             </div>
            <h3 class="text-2xl font-black mb-4 tracking-tight leading-tight">Need deeper marketing depth?</h3>
            <p class="text-[#0B222C]/80 text-sm font-bold leading-relaxed mb-8">
              Unlock AI-generated content calendars and email sequences tailored to these results.
            </p>
            <button class="w-full px-6 py-4 bg-[#0B222C] text-white hover:bg-[#122C36] rounded-2xl font-extrabold transition-all text-xs uppercase tracking-widest shadow-lg shadow-[#0B222C]/20 flex items-center justify-center gap-2 group/btn">
              Upgrade Analysis <.icon name="hero-arrow-right" class="size-3 group-hover/btn:translate-x-1 transition-transform" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp overview_tab(assigns) do
    ~H"""
    <div class="space-y-10">
      <!-- Product Identity -->
      <div class="glass-card rounded-[2.5rem] overflow-hidden hover:shadow-glow transition-all duration-300 group">
        <div class="p-10 border-b border-[#F1F3F5] dark:border-white/5 flex items-center justify-between bg-[#F9FAFB]/50 dark:bg-white/5 backdrop-blur-sm">
          <h3 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] group-hover:text-[#27C281] transition-colors">Product Identity</h3>
          <div class="flex gap-4">
            <span class="px-5 py-2 rounded-xl bg-indigo-50 dark:bg-indigo-500/10 text-indigo-500 text-[0.65rem] font-black uppercase tracking-widest shadow-sm border border-indigo-100 dark:border-indigo-500/20">
              {@analysis["pricing_model"]}
            </span>
            <span class="px-5 py-2 rounded-xl bg-[#27C281]/10 text-[#27C281] text-[0.65rem] font-black uppercase tracking-widest shadow-sm border border-[#27C281]/20">
              {@analysis["tone"]}
            </span>
          </div>
        </div>
        <div class="p-10">
          <div class="mb-12">
            <h4 class="text-6xl font-black text-[#0B222C] dark:text-white tracking-tighter leading-none mb-6">
               {@analysis["product_name"]}
            </h4>
            <p class="text-2xl text-[#27C281] font-bold italic opacity-90 leading-snug tracking-tight max-w-4xl">
               "{@analysis["tagline"]}"
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-16">
            <div>
              <h5 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-8 flex items-center gap-2">
                <div class="size-1 rounded-full bg-[#A0AEC0]"></div> Target Audience
              </h5>
              <p class="text-[#4a5568] dark:text-[#A0AEC0] leading-loose font-bold text-lg">
                {@analysis["target_audience"]}
              </p>
            </div>
            <div>
              <h5 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-8 flex items-center gap-2">
                <div class="size-1 rounded-full bg-[#A0AEC0]"></div> Market Verticals
              </h5>
              <div class="flex flex-wrap gap-4">
                <%= for industry <- @analysis["industries"] || [] do %>
                  <span class="px-6 py-3 rounded-2xl bg-[#F9FAFB] dark:bg-white/5 text-[#4a5568] dark:text-[#A0AEC0] text-sm font-extrabold border border-[#F1F3F5] dark:border-white/10 shadow-sm hover:scale-105 transition-transform cursor-default">
                    {industry}
                  </span>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Value Propositions & Features -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div class="glass-card rounded-[2.5rem] overflow-hidden hover:shadow-glow transition-all duration-300 group h-full">
          <div class="p-8 border-b border-[#F1F3F5] dark:border-white/5 bg-[#F9FAFB]/50 dark:bg-white/5 backdrop-blur-sm">
            <h3 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] group-hover:text-[#27C281] transition-colors">Value Propositions</h3>
          </div>
          <div class="p-10">
            <div class="space-y-6">
              <%= for vp <- @analysis["value_propositions"] || [] do %>
                <div class="flex gap-6 p-6 rounded-[2rem] bg-[#F9FAFB] dark:bg-white/5 border border-[#F1F3F5] dark:border-white/10 group/item hover:translate-x-2 transition-transform duration-300 hover:border-[#27C281]/20 hover:bg-white dark:hover:bg-[#1A3845] hover:shadow-lg">
                  <div class="size-12 rounded-2xl bg-[#27C281] flex items-center justify-center text-[#0B222C] shrink-0 shadow-lg shadow-[#27C281]/30 group-hover/item:scale-110 transition-transform">
                    <.icon name="hero-check" class="size-6 font-bold" />
                  </div>
                  <p class="text-base font-extrabold text-[#4a5568] dark:text-[#A0AEC0] leading-relaxed pt-1 group-hover/item:text-[#0B222C] dark:group-hover/item:text-white transition-colors">
                    {vp}
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="glass-card rounded-[2.5rem] overflow-hidden hover:shadow-glow transition-all duration-300 group h-full">
          <div class="p-8 border-b border-[#F1F3F5] dark:border-white/5 bg-[#F9FAFB]/50 dark:bg-white/5 backdrop-blur-sm">
            <h3 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] group-hover:text-[#27C281] transition-colors">Key Features</h3>
          </div>
          <div class="p-10">
            <div class="space-y-8">
              <%= for feature <- @analysis["key_features"] || [] do %>
                <div class="space-y-3 group/feature p-4 rounded-[2rem] hover:bg-[#F9FAFB] dark:hover:bg-white/5 transition-colors -mx-4 px-4">
                  <h4 class="text-xl font-black text-[#0B222C] dark:text-white flex items-center gap-4 tracking-tight group-hover/feature:translate-x-1 transition-transform">
                    <div class="size-2.5 rounded-full bg-[#27C281] shadow-[0_0_10px_rgba(39,194,129,0.6)] group-hover/feature:scale-150 transition-transform"></div>
                    {feature["name"]}
                  </h4>
                  <p class="text-sm font-bold text-[#718096] dark:text-[#A0AEC0] leading-relaxed pl-7">
                    {feature["description"]}
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp failed_state(assigns) do
    # Extract error message from analysis_data if available
    error_message = get_error_message(assigns.project)

    assigns = assign(assigns, :error_message, error_message)

    ~H"""
    <div class="bg-white dark:bg-[#2f3349] rounded-xl shadow-sm border border-[#dbdade] dark:border-[#43496e] p-12 text-center">
      <div class="mx-auto size-20 rounded-xl bg-danger/10 flex items-center justify-center text-danger mb-6">
        <.icon name="hero-exclamation-triangle" class="size-10" />
      </div>
      <h2 class="text-2xl font-bold text-[#5d596c] dark:text-[#cfd3ec] mb-4">Analysis Failed</h2>
      <p class="text-base text-[#a8aaae] max-w-md mx-auto leading-relaxed mb-8">
        {@error_message}
      </p>
      <%= if rate_limited?(@project) do %>
        <p class="text-sm text-warning font-bold mb-8">
          <.icon name="hero-clock" class="size-4 inline mr-1" />
          The AI service is temporarily rate limited. Please wait a few minutes before retrying.
        </p>
      <% end %>
      <button
        phx-click="reanalyze"
        class="inline-flex items-center gap-2 px-6 py-3 rounded-lg bg-danger text-white font-bold hover:bg-danger/90 transition-all shadow-sm shadow-danger/20"
      >
        <.icon name="hero-arrow-path" class="size-5" /> Try Again
      </button>
    </div>
    """
  end

  defp get_error_message(%{analysis_data: %{"error_message" => msg}}) when is_binary(msg), do: msg

  defp get_error_message(_project) do
    "We encountered an error while analyzing your website. This could be due to a timeout or the site blocking our crawler."
  end

  defp rate_limited?(%{analysis_data: %{"error_message" => msg}}) when is_binary(msg) do
    String.contains?(String.downcase(msg), "rate limit")
  end

  defp rate_limited?(_), do: false

  defp unknown_state(assigns) do
    ~H"""
    <div class="rounded-[3rem] bg-white/5 border border-white/10 backdrop-blur-xl p-24 text-center shadow-2xl">
      <p class="text-xl text-zinc-500">Unknown status. Please refresh the page.</p>
    </div>
    """
  end

  defp persona_results(assigns) do
    ~H"""
    <div class="space-y-10">
      <div class="flex items-center justify-between">
        <h3 class="text-4xl font-black text-[#0B222C] dark:text-white tracking-tighter">Target Personas</h3>
        <div class="flex items-center gap-4">
          <%= if assigns[:loading] do %>
            <div class="flex items-center gap-2 text-[#27C281] text-xs font-black uppercase tracking-widest animate-pulse">
              <div class="size-3 border-2 border-[#27C281]/20 border-t-[#27C281] rounded-full animate-spin"></div>
              Generating...
            </div>
          <% end %>
          <.link
            navigate={~p"/projects/#{@project.slug}/personas/compare"}
            class="hidden md:inline-flex items-center px-6 py-3 rounded-2xl bg-[#27C281]/10 text-[#27C281] text-[0.65rem] font-black uppercase tracking-widest hover:bg-[#27C281] hover:text-[#0B222C] transition-all shadow-sm hover:shadow-lg hover:-translate-y-0.5"
          >
            <.icon name="hero-arrows-right-left" class="size-4 mr-2" /> Compare All
          </.link>
        </div>
      </div>

      <div class={[
        "grid grid-cols-1 md:grid-cols-2 gap-8 transition-opacity duration-300",
        assigns[:loading] && "opacity-50 pointer-events-none"
      ]}>
        <%= if @personas == [] && !assigns[:loading] do %>
          <div class="md:col-span-2 glass-card rounded-[2.5rem] p-24 text-center group">
            <div class="mx-auto size-24 rounded-[2rem] bg-emerald-50 dark:bg-emerald-500/10 flex items-center justify-center text-[#27C281] mb-8 shadow-inner group-hover:scale-110 transition-transform duration-500">
              <.icon name="hero-user-group" class="size-12" />
            </div>
            <h4 class="text-3xl font-black text-[#0B222C] dark:text-white mb-4 tracking-tight">No Personas Yet</h4>
            <p class="text-[#A0AEC0] mb-12 max-w-sm mx-auto font-bold leading-relaxed">Run the Persona Builder agent to generate your ideal customer profiles.</p>
            <button
              phx-click="run_agent"
              phx-value-agent="personas"
              class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-[#27C281] text-[#0B222C] font-black hover:bg-[#20A06A] hover:text-white transition-all shadow-xl shadow-[#27C281]/20 hover:shadow-2xl hover:-translate-y-1 uppercase tracking-widest text-xs"
            >
              <.icon name="hero-play" class="size-5" /> Run Agent
            </button>
          </div>
        <% end %>
        <%= for persona <- @personas do %>
          <div class="glass-card rounded-[2.5rem] overflow-hidden flex flex-col group hover:shadow-glow hover:-translate-y-1 transition-all duration-300 border border-transparent hover:border-[#27C281]/20">
            <div class="p-10 border-b border-[#F1F3F5] dark:border-white/5 flex items-center justify-between bg-[#F9FAFB]/50 dark:bg-white/5 backdrop-blur-sm">
              <div class="flex items-center gap-6">
                <div class="size-16 rounded-2xl bg-gradient-to-br from-emerald-50 to-white dark:from-emerald-900/20 dark:to-transparent flex items-center justify-center text-[#27C281] group-hover:scale-110 transition-transform shadow-sm border border-emerald-100 dark:border-emerald-500/10">
                  <.icon name="hero-user" class="size-8" />
                </div>
                <div>
                  <h4 class="text-2xl font-black text-[#0B222C] dark:text-white tracking-tight leading-none mb-1 group-hover:text-[#27C281] transition-colors">{persona.name}</h4>
                  <p class="text-[0.65rem] text-[#A0AEC0] font-black uppercase tracking-widest">{persona.role} • {persona.age_range}</p>
                </div>
              </div>
              <%= if persona.is_primary do %>
                <span class="px-4 py-2 rounded-full bg-[#27C281]/10 text-[#27C281] text-[0.6rem] font-black uppercase tracking-widest shadow-sm border border-[#27C281]/10">
                  Primary
                </span>
              <% end %>
            </div>

            <div class="p-10 flex-1 space-y-10">
              <div>
                <h5 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-6 flex items-center gap-2">
                   <div class="size-1 rounded-full bg-red-400"></div> Pain Points
                </h5>
                <ul class="grid grid-cols-1 gap-3">
                  <%= for pain <- Enum.take(persona.pain_points || [], 3) do %>
                    <li class="flex items-start gap-4 text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold p-4 rounded-2xl bg-[#F9FAFB] dark:bg-white/5 border border-[#F1F3F5] dark:border-white/10 group/item hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors">
                      <.icon name="hero-minus-circle" class="size-5 text-red-400 shrink-0 mt-0.5 group-hover/item:scale-110 transition-transform" />
                      <span class="leading-relaxed">{pain}</span>
                    </li>
                  <% end %>
                </ul>
              </div>

              <div>
                <h5 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-6 flex items-center gap-2">
                   <div class="size-1 rounded-full bg-[#27C281]"></div> Goals
                </h5>
                <ul class="grid grid-cols-1 gap-3">
                  <%= for goal <- Enum.take(persona.goals || [], 3) do %>
                    <li class="flex items-start gap-4 text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold p-4 rounded-2xl bg-[#F9FAFB] dark:bg-white/5 border border-[#F1F3F5] dark:border-white/10 group/item hover:bg-emerald-50 dark:hover:bg-emerald-900/10 transition-colors">
                      <.icon name="hero-check-circle" class="size-5 text-[#27C281] shrink-0 mt-0.5 group-hover/item:scale-110 transition-transform" />
                      <span class="leading-relaxed">{goal}</span>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>

            <div class="p-8 bg-[#F9FAFB]/50 dark:bg-white/5 border-t border-[#F1F3F5] dark:border-white/5 backdrop-blur-sm">
              <.link
                navigate={~p"/projects/#{@project.slug}/personas/#{persona.id}"}
                class="w-full flex items-center justify-center py-4 text-[0.7rem] font-black text-[#0B222C] dark:text-white hover:text-[#27C281] transition-colors bg-white dark:bg-[#0B222C] rounded-2xl border border-[#F1F3F5] dark:border-white/10 shadow-sm hover:shadow-md uppercase tracking-widest group/btn"
              >
                View Full Profile <.icon name="hero-arrow-right" class="size-3.5 ml-2 group-hover/btn:translate-x-1 transition-transform" />
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp competitor_results(assigns) do
    ~H"""
    <div class="space-y-10">
      <div class="flex items-center justify-between">
        <h3 class="text-4xl font-black text-[#0B222C] dark:text-white tracking-tighter">Market Competitors</h3>
        <%= if assigns[:loading] do %>
          <div class="flex items-center gap-2 text-[#27C281] text-xs font-black uppercase tracking-widest animate-pulse">
            <div class="size-3 border-2 border-[#27C281]/20 border-t-[#27C281] rounded-full animate-spin"></div>
            Analyzing...
          </div>
        <% end %>
      </div>

      <div class={[
        "grid grid-cols-1 md:grid-cols-2 gap-8 transition-opacity duration-300",
        assigns[:loading] && "opacity-50 pointer-events-none"
      ]}>
        <%= if (@competitors == [] || is_nil(@competitors)) && !assigns[:loading] do %>
          <div class="md:col-span-2 glass-card rounded-[2.5rem] p-24 text-center group">
            <div class="mx-auto size-24 rounded-[2rem] bg-blue-50 dark:bg-blue-500/10 flex items-center justify-center text-blue-500 mb-8 shadow-inner group-hover:scale-110 transition-transform duration-500">
              <.icon name="hero-globe-alt" class="size-12" />
            </div>
            <h4 class="text-3xl font-black text-[#0B222C] dark:text-white mb-4 tracking-tight">No Competitors Yet</h4>
            <p class="text-[#A0AEC0] mb-12 max-w-sm mx-auto font-bold leading-relaxed">Run the Competitor Agent to identify your market rivals.</p>
            <button
              phx-click="run_agent"
              phx-value-agent="competitors"
              class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-[#0B222C] text-white font-black hover:bg-[#122C36] transition-all shadow-xl shadow-[#0B222C]/20 hover:shadow-2xl hover:-translate-y-1 uppercase tracking-widest text-xs"
            >
              <.icon name="hero-play" class="size-5" /> Run Agent
            </button>
          </div>
        <% end %>
        <%= for comp <- @competitors || [] do %>
          <div class="glass-card rounded-[2.5rem] p-10 group hover:shadow-glow hover:-translate-y-1 transition-all duration-300 border border-transparent hover:border-[#27C281]/20">
            <div class="flex justify-between items-start mb-10">
              <div class="flex items-center gap-6">
                <div class="size-16 rounded-2xl bg-blue-50 dark:bg-blue-500/10 flex items-center justify-center text-blue-500 group-hover:scale-110 transition-transform shadow-sm border border-blue-100 dark:border-blue-500/10">
                  <.icon name="hero-globe-alt" class="size-8" />
                </div>
                <div>
                  <h4 class="text-2xl font-black text-[#0B222C] dark:text-white mb-2 tracking-tight group-hover:text-blue-500 transition-colors">{comp["name"]}</h4>
                  <span class="px-4 py-2 rounded-full bg-blue-50 dark:bg-blue-500/10 text-blue-500 text-[0.6rem] font-black uppercase tracking-widest shadow-sm border border-blue-100 dark:border-blue-500/20">
                    {comp["pricing_strategy"]}
                  </span>
                </div>
              </div>
            </div>

            <p class="text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold mb-10 leading-loose">
              {comp["description"]}
            </p>

            <div class="space-y-10">
              <div>
                <h5 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-6 flex items-center gap-2">
                   <div class="size-1 rounded-full bg-blue-500"></div> Strengths
                </h5>
                <div class="flex flex-wrap gap-3">
                  <%= for strength <- comp["strengths"] || [] do %>
                    <span class="px-4 py-2.5 rounded-2xl bg-[#F9FAFB] dark:bg-white/5 text-[#4a5568] dark:text-[#A0AEC0] text-xs font-extrabold border border-[#F1F3F5] dark:border-white/10 shadow-sm hover:scale-105 transition-transform cursor-default">
                      {strength}
                    </span>
                  <% end %>
                </div>
              </div>

              <div class="p-8 rounded-[2rem] bg-gradient-to-br from-[#27C281]/5 to-transparent border border-[#27C281]/10 group-hover:from-[#27C281]/10 transition-all">
                <h5 class="text-[0.65rem] font-black text-[#27C281] uppercase tracking-[0.2em] mb-4 flex items-center gap-2">
                  <.icon name="hero-bolt" class="size-3" /> Market Gap Opportunity
                </h5>
                <p class="text-base font-black text-[#0B222C] dark:text-white leading-relaxed">
                  {comp["market_gap"]}
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp lead_results(assigns) do
    ~H"""
    <div class="space-y-10">
      <div class="flex items-center justify-between">
        <h3 class="text-4xl font-black text-[#0B222C] dark:text-white tracking-tighter">Lead Discovery</h3>
        <%= if assigns[:loading] do %>
          <div class="flex items-center gap-2 text-[#27C281] text-xs font-black uppercase tracking-widest animate-pulse">
            <div class="size-3 border-2 border-[#27C281]/20 border-t-[#27C281] rounded-full animate-spin"></div>
            Discovering...
          </div>
        <% end %>
      </div>

      <div class={[
        "grid grid-cols-1 md:grid-cols-2 gap-8 transition-opacity duration-300",
        assigns[:loading] && "opacity-50 pointer-events-none"
      ]}>
        <%= if (@leads == [] || is_nil(@leads)) && !assigns[:loading] do %>
          <div class="md:col-span-2 glass-card rounded-[2.5rem] p-24 text-center group">
            <div class="mx-auto size-24 rounded-[2rem] bg-amber-50 dark:bg-amber-500/10 flex items-center justify-center text-amber-500 mb-8 shadow-inner group-hover:scale-110 transition-transform duration-500">
              <.icon name="hero-user-plus" class="size-12" />
            </div>
            <h4 class="text-3xl font-black text-[#0B222C] dark:text-white mb-4 tracking-tight">No Leads Yet</h4>
            <p class="text-[#A0AEC0] mb-12 max-w-sm mx-auto font-bold leading-relaxed">Run the Lead Agent to find your target audience segments.</p>
            <button
              phx-click="run_agent"
              phx-value-agent="leads"
              class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-[#0B222C] text-white font-black hover:bg-[#122C36] transition-all shadow-xl shadow-[#0B222C]/20 hover:shadow-2xl hover:-translate-y-1 uppercase tracking-widest text-xs"
            >
              <.icon name="hero-play" class="size-5" /> Run Agent
            </button>
          </div>
        <% end %>
        <%= for segment <- @leads || [] do %>
          <div class="glass-card rounded-[2.5rem] p-10 group hover:shadow-glow hover:-translate-y-1 transition-all duration-300 border border-transparent hover:border-[#27C281]/20">
            <div class="flex items-center gap-6 mb-10">
              <div class="size-16 rounded-2xl bg-gradient-to-br from-amber-50 to-white dark:from-amber-900/20 dark:to-transparent flex items-center justify-center text-amber-500 group-hover:scale-110 transition-transform shadow-sm border border-amber-100 dark:border-amber-500/10">
                <.icon name="hero-user-plus" class="size-8" />
              </div>
              <h4 class="text-2xl font-black text-[#0B222C] dark:text-white tracking-tight leading-none group-hover:text-amber-500 transition-colors">{segment["name"]}</h4>
            </div>

            <div class="space-y-10">
              <div>
                <h5 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-6 flex items-center gap-2">
                   <div class="size-1 rounded-full bg-red-400"></div> Pain Points
                </h5>
                <ul class="grid grid-cols-1 gap-3">
                  <%= for pain <- segment["pain_points"] || [] do %>
                    <li class="flex items-start gap-4 text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold p-4 rounded-2xl bg-[#F9FAFB] dark:bg-white/5 border border-[#F1F3F5] dark:border-white/10 group/item hover:bg-white dark:hover:bg-white/10 transition-colors">
                      <div class="size-2 rounded-full bg-red-400 mt-2 shrink-0 shadow-lg shadow-red-400/40 group-hover/item:scale-150 transition-transform"></div>
                      <span class="leading-relaxed">{pain}</span>
                    </li>
                  <% end %>
                </ul>
              </div>

              <div class="grid grid-cols-1 gap-6">
                <div class="p-8 rounded-[2rem] bg-gradient-to-br from-[#27C281]/5 to-transparent border border-[#27C281]/10 group-hover:from-[#27C281]/10 transition-all">
                  <h5 class="text-[0.65rem] font-black text-[#27C281] uppercase tracking-[0.2em] mb-4 flex items-center gap-2">
                    <.icon name="hero-magnet" class="size-3" /> Lead Magnet Strategy
                  </h5>
                  <p class="text-lg font-black text-[#0B222C] dark:text-white leading-tight">
                    {segment["lead_magnet_idea"]}
                  </p>
                </div>

                <div class="p-8 rounded-[2rem] bg-[#F9FAFB]/50 dark:bg-white/5 border border-[#F1F3F5] dark:border-white/10 backdrop-blur-sm">
                  <h5 class="text-[0.65rem] font-black text-[#A0AEC0] uppercase tracking-[0.2em] mb-4 flex items-center gap-2">
                     <.icon name="hero-chat-bubble-bottom-center-text" class="size-3" /> Outreach Hook
                  </h5>
                  <p class="text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold italic leading-relaxed">
                    "{segment["outreach_hook"]}"
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp content_results(assigns) do
    ~H"""
    <div class="space-y-10">
      <div class="flex items-center justify-between">
        <h3 class="text-4xl font-black text-[#0B222C] dark:text-white tracking-tighter">Content Strategy</h3>
        <%= if assigns[:loading] do %>
          <div class="flex items-center gap-2 text-[#27C281] text-xs font-black uppercase tracking-widest animate-pulse">
            <div class="size-3 border-2 border-[#27C281]/20 border-t-[#27C281] rounded-full animate-spin"></div>
            Generating...
          </div>
        <% end %>
      </div>

      <div class={[
        "space-y-10 transition-opacity duration-300",
        assigns[:loading] && "opacity-50 pointer-events-none"
      ]}>
        <%= if (@content == %{} || is_nil(@content)) && !assigns[:loading] do %>
          <div class="glass-card rounded-[2.5rem] p-24 text-center group">
            <div class="mx-auto size-24 rounded-[2rem] bg-indigo-50 dark:bg-indigo-500/10 flex items-center justify-center text-indigo-500 mb-8 shadow-inner group-hover:scale-110 transition-transform duration-500">
              <.icon name="hero-megaphone" class="size-12" />
            </div>
            <h4 class="text-3xl font-black text-[#0B222C] dark:text-white mb-4 tracking-tight">No Content Strategy Yet</h4>
            <p class="text-[#A0AEC0] mb-12 max-w-sm mx-auto font-bold leading-relaxed">Run the Content Agent to generate a multi-platform strategy.</p>
            <button
              phx-click="run_agent"
              phx-value-agent="content"
              class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-[#0B222C] text-white font-black hover:bg-[#122C36] transition-all shadow-xl shadow-[#0B222C]/20 hover:shadow-2xl hover:-translate-y-1 uppercase tracking-widest text-xs"
            >
              <.icon name="hero-play" class="size-5" /> Run Agent
            </button>
          </div>
        <% else %>
          <div class="bg-[#0B222C] dark:bg-[#122C36] rounded-[2.5rem] shadow-soft p-12 relative overflow-hidden group hover:shadow-glow transition-all duration-500">
            <div class="absolute inset-0 bg-[url('/images/noise.png')] opacity-20 mix-blend-overlay"></div>
            <div class="absolute top-0 right-0 p-8 opacity-10 group-hover:opacity-20 group-hover:scale-110 transition-all duration-700 ease-out">
              <.icon name="hero-sparkles" class="size-64 text-white" />
            </div>
            <div class="relative z-10">
              <h3 class="text-[0.65rem] font-black text-[#27C281] uppercase tracking-[0.2em] mb-8 flex items-center gap-2">
                 <div class="size-1.5 rounded-full bg-[#27C281] animate-pulse"></div> Master Strategy
              </h3>
              <p class="text-3xl font-bold text-white leading-relaxed max-w-4xl">
                {@content["strategy"]}
              </p>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
            <%= for atom <- @content["content_atoms"] || [] do %>
              <div class="glass-card rounded-[2.5rem] overflow-hidden flex flex-col group hover:shadow-glow hover:-translate-y-1 transition-all duration-300 border border-transparent hover:border-[#27C281]/20">
                <div class="p-10 border-b border-[#F1F3F5] dark:border-white/5 flex items-center justify-between bg-[#F9FAFB]/50 dark:bg-white/5 backdrop-blur-sm">
                  <div class="flex items-center gap-6">
                    <div class="size-14 rounded-2xl bg-gradient-to-br from-indigo-50 to-white dark:from-indigo-900/20 dark:to-transparent flex items-center justify-center text-indigo-500 group-hover:scale-110 transition-transform shadow-sm border border-indigo-100 dark:border-indigo-500/10">
                      <.icon
                        name={
                          case atom["platform"] do
                            "Twitter" -> "hero-chat-bubble-left-right"
                            "LinkedIn" -> "hero-user-circle"
                            _ -> "hero-document-text"
                          end
                        }
                        class="size-7"
                      />
                    </div>
                    <div>
                      <h4 class="text-xl font-black text-[#0B222C] dark:text-white tracking-tight leading-none mb-1 group-hover:text-indigo-500 transition-colors">{atom["platform"]}</h4>
                      <p class="text-[0.65rem] text-[#A0AEC0] font-black uppercase tracking-widest">{atom["format"]}</p>
                    </div>
                  </div>
                </div>

                <div class="p-10 flex-1 space-y-8">
                  <h5 class="text-xl font-black text-[#0B222C] dark:text-white leading-tight group-hover:text-indigo-500 transition-colors">
                    {atom["hook"]}
                  </h5>
                  <div class="p-8 rounded-[2rem] bg-[#F9FAFB] dark:bg-white/5 text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold leading-loose whitespace-pre-line border border-[#F1F3F5] dark:border-white/10">
                    {atom["body_outline"]}
                  </div>
                </div>

                <div class="p-8 bg-[#F9FAFB]/50 dark:bg-white/5 border-t border-[#F1F3F5] dark:border-white/5 backdrop-blur-sm">
                  <div class="flex items-center gap-3 text-[0.65rem] font-black text-[#27C281] uppercase tracking-widest">
                    <.icon name="hero-cursor-arrow-rays" class="size-4 animate-pulse" />
                    CTA: {atom["cta"]}
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp cro_results(assigns) do
    ~H"""
    <div class="space-y-10">
      <div class="flex items-center justify-between">
        <h3 class="text-3xl font-extrabold text-[#0B222C] dark:text-white tracking-tight">Conversion Audit</h3>
        <%= if assigns[:loading] do %>
          <div class="flex items-center gap-2 text-[#27C281] text-sm font-extrabold uppercase tracking-widest">
            <div class="size-4 border-2 border-[#27C281]/20 border-t-[#27C281] rounded-full animate-spin"></div>
            Auditing...
          </div>
        <% end %>
      </div>

      <div class={[
        "space-y-12 transition-opacity duration-300",
        assigns[:loading] && "opacity-50 pointer-events-none"
      ]}>
        <%= if (@audit == %{} || is_nil(@audit)) && !assigns[:loading] do %>
          <div class="bg-white dark:bg-[#122C36] rounded-[2.5rem] shadow-soft border border-[#F1F3F5] dark:border-white/5 p-20 text-center">
            <div class="mx-auto size-24 rounded-3xl bg-emerald-50 dark:bg-emerald-500/10 flex items-center justify-center text-[#27C281] mb-8 shadow-sm">
              <.icon name="hero-presentation-chart-line" class="size-12" />
            </div>
            <h4 class="text-2xl font-extrabold text-[#0B222C] dark:text-white mb-4 tracking-tight">No Audit Yet</h4>
            <p class="text-[#A0AEC0] mb-10 max-w-sm mx-auto font-bold">Run the CRO Agent to analyze your landing page conversion potential.</p>
            <button
              phx-click="run_agent"
              phx-value-agent="cro"
              class="inline-flex items-center gap-3 px-10 py-4 rounded-2xl bg-[#27C281] text-[#0B222C] font-extrabold hover:bg-[#27C281]/90 transition-all shadow-xl shadow-[#27C281]/20 uppercase tracking-widest text-xs"
            >
              <.icon name="hero-play" class="size-5" /> Run Agent
            </button>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div class="bg-[#0B222C] dark:bg-[#122C36] rounded-[2.5rem] shadow-soft p-10 flex flex-col items-center justify-center text-center group transition-all">
              <div class="text-6xl font-extrabold text-[#27C281] mb-4 group-hover:scale-110 transition-transform">{@audit["overall_score"]}%</div>
              <div class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em]">Health Score</div>
            </div>

            <%= for {label, value} <- [
              {"Clarity", @audit["clarity_rating"]},
              {"Trust", @audit["trust_rating"]},
              {"Conversion", @audit["cta_rating"]}
            ] do %>
              <div class="bg-white dark:bg-[#122C36] rounded-[2rem] shadow-soft border border-[#F1F3F5] dark:border-white/5 p-10 group hover:border-[#27C281]/30 transition-all">
                <h4 class="text-[0.65rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.2em] mb-8">{label}</h4>
                <div class="flex items-end gap-2 mb-8">
                  <div class="text-5xl font-extrabold text-[#0B222C] dark:text-white">{value}</div>
                  <div class="text-sm font-bold text-[#A0AEC0] mb-2 uppercase">/ 10</div>
                </div>
                <div class="h-2.5 w-full bg-[#F9FAFB] dark:bg-white/5 rounded-full overflow-hidden shadow-inner">
                  <div
                    class="h-full rounded-full bg-[#27C281] shadow-lg shadow-[#27C281]/40"
                    style={"width: #{value * 10}%"}
                  >
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12">
            <div class="space-y-10">
              <h4 class="text-2xl font-extrabold text-[#0B222C] dark:text-white tracking-tight">Key Findings</h4>
              <div class="space-y-8">
                <%= for finding <- @audit["findings"] || [] do %>
                  <div class="bg-white dark:bg-[#122C36] rounded-[2.5rem] shadow-soft border border-[#F1F3F5] dark:border-white/5 p-10 group hover:border-[#27C281]/30 transition-all">
                    <div class="flex justify-between items-start mb-10">
                      <span class="px-5 py-2 rounded-xl bg-[#F9FAFB] dark:bg-white/5 text-[#A0AEC0] text-[0.65rem] font-extrabold uppercase tracking-widest border border-[#F1F3F5] dark:border-white/10 shadow-sm">
                        {finding["area"]}
                      </span>
                      <div class={[
                        "flex items-center gap-2 px-5 py-2 rounded-xl text-[0.65rem] font-extrabold uppercase tracking-widest shadow-sm",
                        if(finding["impact"] == "High", do: "bg-red-50 dark:bg-red-500/10 text-red-500", else: "bg-amber-50 dark:bg-amber-500/10 text-amber-500")
                      ]}>
                        <div class={["size-2 rounded-full", if(finding["impact"] == "High", do: "bg-red-500 shadow-lg shadow-red-500/40", else: "bg-amber-500 shadow-lg shadow-amber-500/40")]}></div>
                        {finding["impact"]} Impact
                      </div>
                    </div>
                    <h5 class="text-xl font-extrabold text-[#0B222C] dark:text-white mb-4 tracking-tight">{finding["issue"]}</h5>
                    <p class="text-base text-[#4a5568] dark:text-[#A0AEC0] font-bold leading-relaxed">
                      {finding["recommendation"]}
                    </p>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="space-y-10">
              <h4 class="text-2xl font-extrabold text-[#0B222C] dark:text-white tracking-tight">Elevated Copywriting</h4>
              <div class="bg-[#27C281] rounded-[2.5rem] p-12 relative overflow-hidden group shadow-xl shadow-[#27C281]/20">
                <div class="absolute top-0 right-0 p-10 opacity-20 -rotate-12 group-hover:scale-110 transition-transform">
                  <.icon name="hero-pencil-square" class="size-48 text-[#0B222C]" />
                </div>
                <div class="relative z-10 space-y-12">
                  <div class="size-16 rounded-2xl bg-[#0B222C]/10 flex items-center justify-center text-[#0B222C] mb-10 shadow-sm">
                    <.icon name="hero-sparkles" class="size-8" />
                  </div>
                  <div>
                    <h5 class="text-[0.65rem] font-extrabold text-[#0B222C]/60 uppercase tracking-[0.2em] mb-6">Suggested Headline</h5>
                    <p class="text-4xl font-extrabold text-[#0B222C] leading-tight tracking-tight">
                      {@audit["hero_rewrite"]["headline"]}
                    </p>
                  </div>
                  <div class="h-px bg-[#0B222C]/10"></div>
                  <div>
                    <h5 class="text-[0.65rem] font-extrabold text-[#0B222C]/60 uppercase tracking-[0.2em] mb-6">Suggested Subheadline</h5>
                    <p class="text-xl text-[#0B222C]/80 font-bold leading-relaxed">
                      {@audit["hero_rewrite"]["subheadline"]}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp aeo_results(assigns) do
    ~H"""
    <div class="space-y-10">
      <div class="flex items-center justify-between">
        <h3 class="text-4xl font-black text-[#0B222C] dark:text-white tracking-tighter">AEO Strategy</h3>
        <%= if assigns[:loading] do %>
          <div class="flex items-center gap-2 text-[#27C281] text-xs font-black uppercase tracking-widest animate-pulse">
            <div class="size-3 border-2 border-[#27C281]/20 border-t-[#27C281] rounded-full animate-spin"></div>
            Optimizing...
          </div>
        <% end %>
      </div>

      <div class={[
        "space-y-10 transition-opacity duration-300",
        assigns[:loading] && "opacity-50 pointer-events-none"
      ]}>
        <%= if is_nil(@aeo) && !assigns[:loading] do %>
          <div class="glass-card rounded-[2.5rem] p-24 text-center group">
            <div class="mx-auto size-24 rounded-[2rem] bg-rose-50 dark:bg-rose-500/10 flex items-center justify-center text-rose-500 mb-8 shadow-inner group-hover:scale-110 transition-transform duration-500">
              <.icon name="hero-cpu-chip" class="size-12" />
            </div>
            <h4 class="text-3xl font-black text-[#0B222C] dark:text-white mb-4 tracking-tight">No AEO Strategy Yet</h4>
            <p class="text-[#A0AEC0] mb-12 max-w-sm mx-auto font-bold leading-relaxed">Run the AEO Agent to optimize for AI answer engines.</p>
            <button
              phx-click="run_agent"
              phx-value-agent="aeo"
              class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-[#0B222C] text-white font-black hover:bg-[#122C36] transition-all shadow-xl shadow-[#0B222C]/20 hover:shadow-2xl hover:-translate-y-1 uppercase tracking-widest text-xs"
            >
              <.icon name="hero-play" class="size-5" /> Run Agent
            </button>
          </div>
        <% else %>
          <div class="bg-[#0B222C] dark:bg-[#122C36] rounded-[2.5rem] shadow-soft p-12 relative overflow-hidden group hover:shadow-glow transition-all duration-500">
             <div class="absolute inset-0 bg-[url('/images/noise.png')] opacity-20 mix-blend-overlay"></div>
             <div class="absolute top-0 right-0 p-8 opacity-10 group-hover:opacity-20 group-hover:scale-110 transition-all duration-700 ease-out">
               <.icon name="hero-cpu-chip" class="size-64 text-white" />
             </div>
            <div class="relative z-10">
              <h3 class="text-[0.65rem] font-black text-[#27C281] uppercase tracking-[0.2em] mb-8 flex items-center gap-2">
                 <div class="size-1.5 rounded-full bg-[#27C281] animate-pulse"></div> Overview
              </h3>
              <p class="text-3xl font-bold text-white leading-relaxed max-w-4xl">
                {@aeo["overview"]}
              </p>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div class="glass-card rounded-[2.5rem] p-10 group hover:shadow-glow transition-all duration-300 border border-transparent hover:border-[#27C281]/20">
               <div class="flex items-center gap-4 mb-8">
                  <div class="size-12 rounded-xl bg-gradient-to-br from-rose-50 to-white dark:from-rose-900/20 dark:to-transparent flex items-center justify-center text-rose-500 shadow-sm border border-rose-100 dark:border-rose-500/10">
                    <.icon name="hero-tag" class="size-6" />
                  </div>
                  <h4 class="text-2xl font-black text-[#0B222C] dark:text-white tracking-tight">Keywords & Phrases</h4>
               </div>
              <div class="flex flex-wrap gap-3">
                <%= for phrase <- @aeo["keywords"] || [] do %>
                  <span class="px-5 py-2.5 rounded-xl bg-[#F9FAFB] dark:bg-white/5 text-[#4a5568] dark:text-[#A0AEC0] text-sm font-black border border-[#F1F3F5] dark:border-white/10 hover:bg-[#0B222C] hover:text-white dark:hover:bg-white transition-colors cursor-default">
                    {phrase}
                  </span>
                <% end %>
              </div>
            </div>

            <div class="glass-card rounded-[2.5rem] p-10 group hover:shadow-glow transition-all duration-300 border border-transparent hover:border-[#27C281]/20">
               <div class="flex items-center gap-4 mb-8">
                  <div class="size-12 rounded-xl bg-gradient-to-br from-indigo-50 to-white dark:from-indigo-900/20 dark:to-transparent flex items-center justify-center text-indigo-500 shadow-sm border border-indigo-100 dark:border-indigo-500/10">
                    <.icon name="hero-adjustments-horizontal" class="size-6" />
                  </div>
                  <h4 class="text-2xl font-black text-[#0B222C] dark:text-white tracking-tight">Platform Optimizations</h4>
               </div>
              <div class="space-y-6">
                <%= for {platform, tips} <- @aeo["platform_specifics"] || %{} do %>
                  <div class="p-6 rounded-[2rem] bg-[#F9FAFB]/50 dark:bg-white/5 border border-[#F1F3F5] dark:border-white/10 backdrop-blur-sm group/item">
                    <h5 class="text-sm font-black text-[#0B222C] dark:text-white mb-3 flex items-center gap-2">
                       <span class="w-1.5 h-1.5 rounded-full bg-indigo-500 group-hover/item:scale-150 transition-transform"></span>
                       {String.capitalize(platform)}
                    </h5>
                    <p class="text-sm text-[#4a5568] dark:text-[#A0AEC0] font-bold leading-relaxed">{tips}</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("set_primary_persona", %{"id" => id}, socket) do
    persona = Personas.get_persona!(id)

    case Personas.set_primary_persona(persona) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:personas, Personas.list_personas(socket.assigns.project))
         |> put_flash(:info, "Primary persona updated!")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update primary persona")}
    end
  end

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

  @impl true
  def handle_event("run_agent", %{"agent" => agent_type}, socket) do
    project = socket.assigns.project

    # Mark agent as loading
    socket =
      assign(socket, :loading_agents, Map.put(socket.assigns.loading_agents, agent_type, true))

    # Run agent in a Task
    parent_pid = self()

    Task.start(fn ->
      result =
        case agent_type do
          "personas" -> MarketMind.Agents.run_persona_generation(project)
          "competitors" -> MarketMind.Agents.run_competitor_analysis(project)
          "leads" -> MarketMind.Agents.run_lead_discovery(project)
          "content" -> MarketMind.Agents.run_content_generation(project)
          "cro" -> MarketMind.Agents.run_cro_audit(project)
          "aeo" -> MarketMind.Agents.run_aeo_strategy(project)
          "content_writer" -> MarketMind.Agents.run_content_writer(project)
        end

      send(parent_pid, {:agent_finished, agent_type, result})
    end)

    {:noreply, socket}
  end

  # PubSub Handlers

  @impl true
  def handle_info({:analysis_completed, %{status: _status}}, socket) do
    # Reload the project to get the latest data
    project = Products.get_project!(socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:personas, Personas.list_personas(project))}
  end

  def handle_info({:analysis_status_changed, %{status: _status}}, socket) do
    # Reload the project on any status change
    project = Products.get_project!(socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:personas, Personas.list_personas(project))}
  end

  @impl true
  def handle_info({:agent_finished, agent_type, result}, socket) do
    # Remove loading state
    loading_agents = Map.delete(socket.assigns.loading_agents, agent_type)
    project = Products.get_project!(socket.assigns.project.id)

    socket =
      socket
      |> assign(:loading_agents, loading_agents)
      |> assign(:project, project)
      |> assign(:personas, Personas.list_personas(project))
      |> assign(:contents, Content.list_contents(project))

    case result do
      {:ok, _} ->
        {:noreply,
         put_flash(socket, :info, "#{String.capitalize(agent_type)} analysis complete!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Agent failed: #{inspect(reason)}")}
    end
  end
end
