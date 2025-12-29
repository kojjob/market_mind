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
       |> assign(:loading_agents, %{})}
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
    <div class="relative px-4 sm:px-12 py-12 sm:py-20">
      <!-- Background Effects -->
      <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-0 right-0 size-[50%] bg-primary/5 rounded-full blur-[120px]"></div>
        <div class="absolute bottom-0 left-0 size-[40%] bg-secondary/5 rounded-full blur-[100px]">
        </div>
      </div>

    <!-- Hero Header -->
      <div class="relative pb-24 overflow-hidden">
        <div class="max-w-7xl mx-auto relative">
          <nav class="flex mb-12" aria-label="Breadcrumb">
            <ol class="flex items-center space-x-4">
              <li>
                <.link
                  navigate={~p"/projects"}
                  class="text-zinc-500 hover:text-primary transition-colors"
                >
                  <.icon name="hero-home" class="size-5" />
                </.link>
              </li>
              <li>
                <div class="flex items-center">
                  <.icon name="hero-chevron-right" class="size-4 text-zinc-800" />
                  <.link
                    navigate={~p"/projects"}
                    class="ml-4 text-sm font-black text-zinc-500 hover:text-primary transition-colors"
                  >
                    Projects
                  </.link>
                </div>
              </li>
              <li>
                <div class="flex items-center">
                  <.icon name="hero-chevron-right" class="size-4 text-zinc-800" />
                  <span class="ml-4 text-sm font-black text-white">
                    {@project.name}
                  </span>
                </div>
              </li>
            </ol>
          </nav>

          <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-12">
            <div class="space-y-8 max-w-4xl">
              <div class="flex items-center gap-6">
                <div class="size-20 rounded-[2rem] bg-linear-to-br from-primary to-secondary flex items-center justify-center shadow-2xl shadow-primary/20">
                  <.icon name="hero-briefcase" class="size-10 text-white" />
                </div>
                <.status_indicator status={@project.analysis_status} />
              </div>

              <h1 class="text-6xl sm:text-8xl font-black tracking-tighter leading-[0.9]">
                {@project.name}
              </h1>

              <div class="flex flex-wrap items-center gap-8">
                <a
                  href={@project.url}
                  target="_blank"
                  class="group flex items-center gap-3 text-xl font-black text-primary hover:text-primary/80 transition-colors"
                >
                  {@project.url}
                  <.icon
                    name="hero-arrow-top-right-on-square"
                    class="size-6 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform"
                  />
                </a>
                <div class="h-8 w-px bg-zinc-800"></div>
                <div class="flex items-center gap-3 text-zinc-500 font-bold">
                  <.icon name="hero-calendar" class="size-6" />
                  Added {Calendar.strftime(@project.inserted_at, "%b %d, %Y")}
                </div>
              </div>

              <%= if @project.description do %>
                <p class="text-2xl text-zinc-400 leading-relaxed font-medium">
                  {@project.description}
                </p>
              <% end %>
            </div>

            <div class="flex flex-wrap gap-4">
              <%= if @project.analysis_status in ["completed", "failed"] do %>
                <button
                  phx-click="reanalyze"
                  class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-white text-zinc-950 font-black text-xl hover:scale-105 active:scale-95 transition-all shadow-2xl shadow-white/10"
                >
                  <.icon name="hero-arrow-path" class="size-6" /> Re-analyze
                </button>
              <% end %>
              <button
                disabled
                class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-zinc-900 text-zinc-600 font-black text-xl cursor-not-allowed border border-white/5"
              >
                <.icon name="hero-pencil-square" class="size-6" /> Edit
              </button>
            </div>
          </div>
        </div>
      </div>

    <!-- Content Section -->
      <div class="max-w-7xl mx-auto pb-24 relative z-10">
        <div id="analysis-container" phx-update="replace">
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
              />
            <% "failed" -> %>
              <.failed_state project={@project} />
            <% _ -> %>
              <.unknown_state />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Status Components

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
    <div class="inline-flex items-center gap-3 px-6 py-3 rounded-full bg-white/5 border border-white/10 backdrop-blur-xl shadow-2xl">
      <div class={["size-2.5 rounded-full", @config.color, @config[:animate] && "animate-pulse"]}>
      </div>
      <span class="text-xs font-black uppercase tracking-[0.3em] text-zinc-300">{@config.text}</span>
    </div>
    """
  end

  defp pending_state(assigns) do
    ~H"""
    <div class="rounded-[3rem] bg-white/5 border border-white/10 backdrop-blur-xl p-24 text-center shadow-2xl">
      <div class="mx-auto size-24 rounded-3xl bg-amber-500/10 flex items-center justify-center text-amber-500 mb-8">
        <.icon name="hero-clock" class="size-12" />
      </div>
      <h2 class="text-4xl font-black mb-4">Waiting to Start</h2>
      <p class="text-xl text-zinc-500 max-w-md mx-auto leading-relaxed">
        Your project is in the system and waiting for the analysis engine to pick it up.
      </p>
    </div>
    """
  end

  defp queued_state(assigns) do
    ~H"""
    <div class="rounded-[3rem] bg-white/5 border border-white/10 backdrop-blur-xl p-24 text-center shadow-2xl">
      <div class="mx-auto size-24 rounded-3xl bg-blue-500/10 flex items-center justify-center text-blue-500 mb-8">
        <.icon name="hero-list-bullet" class="size-12" />
      </div>
      <h2 class="text-4xl font-black mb-4">In the Queue</h2>
      <p class="text-xl text-zinc-500 max-w-md mx-auto leading-relaxed">
        We've received your request. Analysis will begin as soon as a worker is available.
      </p>
    </div>
    """
  end

  defp analyzing_state(assigns) do
    ~H"""
    <div class="rounded-[3rem] bg-white/5 border border-white/10 backdrop-blur-xl p-24 text-center shadow-2xl overflow-hidden relative">
      <div class="absolute inset-0 bg-linear-to-r from-primary/10 via-transparent to-secondary/10 animate-pulse">
      </div>
      <div class="relative">
        <div class="mx-auto size-32 rounded-full border-8 border-white/5 border-t-primary animate-spin mb-12">
        </div>
        <h2 class="text-4xl font-black mb-4">Analyzing Your Product</h2>
        <p class="text-xl text-zinc-500 max-w-md mx-auto leading-relaxed mb-12">
          Our AI is currently crawling your website and extracting key marketing insights.
        </p>
        <div class="flex flex-wrap justify-center gap-6">
          <div class="flex items-center gap-3 px-8 py-4 rounded-2xl bg-white/5 text-zinc-400 font-black">
            <.icon name="hero-globe-alt" class="size-6" /> Fetching Content
          </div>
          <div class="flex items-center gap-3 px-8 py-4 rounded-2xl bg-primary/20 text-primary font-black ring-2 ring-primary/30">
            <.icon name="hero-sparkles" class="size-6 animate-bounce" /> AI Processing
          </div>
          <div class="flex items-center gap-3 px-8 py-4 rounded-2xl bg-white/5 text-zinc-400 font-black opacity-50">
            <.icon name="hero-document-text" class="size-6" /> Generating Report
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp completed_state(assigns) do
    ~H"""
    <div class="space-y-16 animate-in fade-in slide-in-from-bottom-8 duration-1000">
      <!-- Product Overview Card -->
      <div class="group relative">
        <div class="absolute -inset-1 bg-linear-to-r from-primary to-secondary rounded-[4rem] blur opacity-10 group-hover:opacity-20 transition duration-1000">
        </div>
        <div class="relative rounded-[4rem] bg-white/5 border border-white/10 backdrop-blur-2xl overflow-hidden shadow-2xl">
          <div class="p-12 sm:p-20">
            <div class="flex flex-col md:flex-row md:items-end justify-between gap-12 mb-20">
              <div class="space-y-6">
                <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/20 text-primary text-xs font-black uppercase tracking-[0.3em] ring-1 ring-primary/30">
                  Product Identity
                </div>
                <h2 class="text-6xl font-black tracking-tighter">
                  {@analysis["product_name"]}
                </h2>
                <p class="text-4xl text-primary font-black italic tracking-tight leading-none">
                  "{@analysis["tagline"]}"
                </p>
              </div>
              <div class="flex flex-wrap gap-4">
                <div class="px-8 py-4 rounded-2xl bg-white/5 border border-white/10 text-white font-black text-sm uppercase tracking-widest">
                  {@analysis["pricing_model"]}
                </div>
                <div class="px-8 py-4 rounded-2xl bg-white/5 border border-white/10 text-white font-black text-sm uppercase tracking-widest">
                  {@analysis["tone"]}
                </div>
              </div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-24">
              <div class="space-y-12">
                <div class="space-y-6">
                  <h3 class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em]">
                    Target Audience
                  </h3>
                  <p class="text-2xl text-zinc-300 leading-relaxed font-medium">
                    {@analysis["target_audience"]}
                  </p>
                </div>

                <div class="space-y-6">
                  <h3 class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em]">
                    Industries
                  </h3>
                  <div class="flex flex-wrap gap-4">
                    <%= for industry <- @analysis["industries"] || [] do %>
                      <span class="px-6 py-3 rounded-2xl bg-white/5 border border-white/10 text-zinc-300 font-black text-sm hover:border-primary/50 transition-colors">
                        {industry}
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="space-y-12">
                <div class="space-y-8">
                  <div class="flex items-center gap-4">
                    <div class="size-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary border border-primary/20">
                      <.icon name="hero-bolt" class="size-5" />
                    </div>
                    <h3 class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em]">
                      Value Propositions
                    </h3>
                  </div>

                  <div class="grid grid-cols-1 gap-6">
                    <%= for vp <- @analysis["value_propositions"] || [] do %>
                      <div class="group/vp relative">
                        <div class="absolute -inset-0.5 bg-linear-to-r from-primary/20 to-transparent rounded-3xl opacity-0 group-hover/vp:opacity-100 transition duration-500">
                        </div>
                        <div class="relative p-8 rounded-3xl bg-white/5 border border-white/10 backdrop-blur-xl hover:bg-white/10 transition-all duration-500">
                          <div class="flex gap-6 items-start">
                            <div class="size-10 rounded-xl bg-zinc-900 border border-white/10 flex items-center justify-center shrink-0 group-hover/vp:scale-110 group-hover/vp:rotate-3 transition-all duration-500">
                              <.icon name="hero-check" class="size-5 text-primary" />
                            </div>
                            <p class="text-xl font-black text-white leading-relaxed">
                              {vp}
                            </p>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

    <!-- Key Features Grid -->
      <div class="space-y-16">
        <div class="flex flex-col md:flex-row md:items-end justify-between gap-8">
          <div>
            <div class="inline-flex items-center gap-3 px-4 py-2 rounded-full bg-secondary/10 text-secondary text-[10px] font-black uppercase tracking-[0.3em] mb-8 ring-1 ring-secondary/20">
              <.icon name="hero-cpu-chip" class="size-4" /> Core Capabilities
            </div>
            <h3 class="text-5xl sm:text-6xl font-black tracking-tighter">
              Key
              <span class="text-transparent bg-clip-text bg-linear-to-r from-white to-white/40">
                Features
              </span>
            </h3>
          </div>
          <p class="text-xl text-zinc-500 font-medium max-w-md leading-relaxed">
            A deep dive into the functional architecture and user-facing capabilities of the product.
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          <%= for feature <- @analysis["key_features"] || [] do %>
            <div class="group/feature relative">
              <div class="absolute -inset-1 bg-linear-to-br from-secondary/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/feature:opacity-100 transition duration-700">
              </div>
              <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-secondary/50 transition-all duration-500 flex flex-col">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-secondary mb-10 group-hover/feature:scale-110 group-hover/feature:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-sparkles" class="size-8" />
                </div>
                <h4 class="text-3xl font-black mb-6 group-hover/feature:text-secondary transition-colors leading-tight">
                  {feature["name"]}
                </h4>
                <p class="text-zinc-400 font-bold text-lg leading-relaxed">
                  {feature["description"]}
                </p>
                <div class="mt-auto pt-10">
                  <div class="h-1 w-12 bg-secondary/20 rounded-full group-hover/feature:w-full transition-all duration-700">
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

    <!-- Differentiators -->
      <div class="relative group">
        <div class="absolute -inset-1 bg-linear-to-r from-primary/20 to-secondary/20 rounded-[4rem] blur-2xl opacity-50 group-hover:opacity-75 transition duration-1000">
        </div>
        <div class="relative rounded-[4rem] bg-zinc-900/50 border border-white/10 backdrop-blur-3xl p-16 sm:p-24 overflow-hidden shadow-2xl">
          <!-- Decorative background elements -->
          <div class="absolute top-0 right-0 size-96 bg-primary/10 rounded-full blur-[120px] -translate-y-1/2 translate-x-1/2">
          </div>
          <div class="absolute bottom-0 left-0 size-96 bg-secondary/10 rounded-full blur-[120px] translate-y-1/2 -translate-x-1/2">
          </div>

          <div class="relative z-10">
            <div class="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-20">
              <div>
                <div class="inline-flex items-center gap-3 px-4 py-2 rounded-full bg-primary/10 text-primary text-[10px] font-black uppercase tracking-[0.3em] mb-8 ring-1 ring-primary/20">
                  <.icon name="hero-sparkles" class="size-4" /> Competitive Edge
                </div>
                <h3 class="text-5xl sm:text-6xl font-black tracking-tighter">
                  Unique
                  <span class="text-transparent bg-clip-text bg-linear-to-r from-white to-white/40">
                    Differentiators
                  </span>
                </h3>
              </div>
              <p class="text-xl text-zinc-500 font-medium max-w-md leading-relaxed">
                These are the core pillars that set your product apart in the current market landscape.
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
              <%= for {diff, index} <- Enum.with_index(@analysis["unique_differentiators"] || []) do %>
                <div class="group/item relative">
                  <div class="absolute -inset-0.5 bg-linear-to-r from-white/10 to-transparent rounded-[2.5rem] opacity-0 group-hover/item:opacity-100 transition duration-500">
                  </div>
                  <div class="relative px-10 py-12 rounded-[2.5rem] bg-white/5 border border-white/10 backdrop-blur-sm hover:bg-white/10 transition-all duration-500 flex gap-8 items-start">
                    <div class="size-16 rounded-2xl bg-linear-to-br from-primary/20 to-secondary/20 flex items-center justify-center shrink-0 border border-white/10 group-hover/item:scale-110 group-hover/item:rotate-3 transition-all duration-500">
                      <span class="text-2xl font-black text-white">{index + 1}</span>
                    </div>
                    <div class="space-y-2">
                      <p class="text-2xl sm:text-3xl font-black tracking-tight text-white leading-tight">
                        {diff}
                      </p>
                      <div class="h-1 w-12 bg-primary/50 rounded-full group-hover/item:w-24 transition-all duration-500">
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

    <!-- Strategic Intelligence -->
      <div class="space-y-16">
        <div class="flex flex-col md:flex-row md:items-end justify-between gap-8">
          <div>
            <div class="inline-flex items-center gap-3 px-4 py-2 rounded-full bg-primary/10 text-primary text-[10px] font-black uppercase tracking-[0.3em] mb-8 ring-1 ring-primary/20">
              <.icon name="hero-cpu-chip" class="size-4" /> AI Agents
            </div>
            <h3 class="text-5xl sm:text-6xl font-black tracking-tighter">
              Strategic
              <span class="text-transparent bg-clip-text bg-linear-to-r from-white to-white/40">
                Intelligence
              </span>
            </h3>
          </div>
          <p class="text-xl text-zinc-500 font-medium max-w-md leading-relaxed">
            Deploy specialized AI agents to deep-dive into specific market opportunities.
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          <!-- Persona Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-indigo-500/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-indigo-500/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-indigo-400 group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-user-circle" class="size-8" />
                </div>
                <%= if @personas != [] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    Ready
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">Persona Builder</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Create detailed Ideal Customer Profiles (ICPs) with demographics and psychographics.
              </p>

              <div class="mt-auto">
                <%= if @personas != [] do %>
                  <div class="space-y-4 mb-8">
                    <%= for persona <- Enum.take(@personas, 2) do %>
                      <div class="flex items-center justify-between text-sm font-bold text-zinc-300">
                        <span>{persona.name}</span>
                        <span class="text-indigo-400">{persona.role}</span>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="personas"
                  disabled={@loading_agents["personas"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@personas != [],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else: "bg-indigo-600 text-white shadow-2xl shadow-indigo-500/20 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["personas"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Building...
                  <% else %>
                    <.icon
                      name={if(@personas != [], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@personas != [], do: "Rebuild Personas", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>

          <!-- Competitor Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-primary/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-primary/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-primary group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-magnifying-glass-circle" class="size-8" />
                </div>
                <%= if @analysis["competitors"] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    Ready
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">Competitor Gap Analysis</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Identify direct competitors and find the "Market Gap" where you can win.
              </p>

              <div class="mt-auto">
                <%= if @analysis["competitors"] do %>
                  <div class="space-y-4 mb-8">
                    <%= for comp <- Enum.take(@analysis["competitors"], 2) do %>
                      <div class="flex items-center justify-between text-sm font-bold text-zinc-300">
                        <span>{comp["name"]}</span>
                        <span class="text-primary">{comp["pricing_strategy"]}</span>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="competitors"
                  disabled={@loading_agents["competitors"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@analysis["competitors"],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else: "bg-primary text-white shadow-2xl shadow-primary/20 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["competitors"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Analyzing...
                  <% else %>
                    <.icon
                      name={if(@analysis["competitors"], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@analysis["competitors"], do: "Refresh Analysis", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>

    <!-- Lead Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-secondary/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-secondary/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-secondary group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-user-group" class="size-8" />
                </div>
                <%= if @analysis["leads"] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    Ready
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">Lead Discovery Agent</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Find high-intent customer segments and personalized outreach hooks.
              </p>

              <div class="mt-auto">
                <%= if @analysis["leads"] do %>
                  <div class="space-y-4 mb-8">
                    <%= for segment <- Enum.take(@analysis["leads"], 2) do %>
                      <div class="flex items-center justify-between text-sm font-bold text-zinc-300">
                        <span>{segment["name"]}</span>
                        <span class="text-secondary">Hook Ready</span>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="leads"
                  disabled={@loading_agents["leads"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@analysis["leads"],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else: "bg-secondary text-white shadow-2xl shadow-secondary/20 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["leads"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Discovering...
                  <% else %>
                    <.icon
                      name={if(@analysis["leads"], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@analysis["leads"], do: "Refresh Leads", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>

    <!-- Content Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-white/10 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-white/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-white group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-megaphone" class="size-8" />
                </div>
                <%= if @analysis["content"] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    Ready
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">Content Atomizer</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Generate multi-channel content atoms from your product's core value.
              </p>

              <div class="mt-auto">
                <%= if @analysis["content"] do %>
                  <div class="space-y-4 mb-8">
                    <div class="text-sm font-bold text-zinc-300">
                      Strategy:
                      <span class="text-white font-medium">
                        {String.slice(@analysis["content"]["strategy"] || "", 0, 40)}...
                      </span>
                    </div>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="content"
                  disabled={@loading_agents["content"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@analysis["content"],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else: "bg-white text-zinc-950 shadow-2xl shadow-white/10 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["content"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Generating...
                  <% else %>
                    <.icon
                      name={if(@analysis["content"], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@analysis["content"], do: "Refresh Content", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>

    <!-- CRO Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-emerald-500/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-emerald-500/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-emerald-500 group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-presentation-chart-line" class="size-8" />
                </div>
                <%= if @analysis["cro_audit"] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    Ready
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">Landing Page Auditor</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Get a professional CRO audit with specific fixes to increase conversions.
              </p>

              <div class="mt-auto">
                <%= if @analysis["cro_audit"] do %>
                  <div class="flex items-center gap-4 mb-8">
                    <div class="text-4xl font-black text-emerald-500">
                      {@analysis["cro_audit"]["overall_score"]}%
                    </div>
                    <div class="text-xs font-black text-zinc-500 uppercase tracking-widest">
                      Overall Score
                    </div>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="cro"
                  disabled={@loading_agents["cro"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@analysis["cro_audit"],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else:
                        "bg-emerald-500 text-white shadow-2xl shadow-emerald-500/20 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["cro"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Auditing...
                  <% else %>
                    <.icon
                      name={if(@analysis["cro_audit"], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@analysis["cro_audit"], do: "Refresh Audit", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>

    <!-- AEO Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-amber-500/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-amber-500/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-amber-500 group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-cpu-chip" class="size-8" />
                </div>
                <%= if @analysis["aeo_strategy"] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    Ready
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">AEO Strategy Agent</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Optimize for AI search engines like Perplexity and SearchGPT.
              </p>

              <div class="mt-auto">
                <%= if @analysis["aeo_strategy"] do %>
                  <div class="space-y-4 mb-8">
                    <div class="text-sm font-bold text-zinc-300">
                      Clusters:
                      <span class="text-amber-500">
                        {length(@analysis["aeo_strategy"]["semantic_clusters"] || [])} Identified
                      </span>
                    </div>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="aeo"
                  disabled={@loading_agents["aeo"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@analysis["aeo_strategy"],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else: "bg-amber-500 text-white shadow-2xl shadow-amber-500/20 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["aeo"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Optimizing...
                  <% else %>
                    <.icon
                      name={if(@analysis["aeo_strategy"], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@analysis["aeo_strategy"], do: "Refresh AEO", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>

    <!-- Content Writer Agent -->
          <div class="group/agent relative">
            <div class="absolute -inset-1 bg-linear-to-br from-blue-500/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/agent:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 backdrop-blur-3xl hover:border-blue-500/50 transition-all duration-500 flex flex-col">
              <div class="flex items-center justify-between mb-10">
                <div class="size-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-blue-500 group-hover/agent:scale-110 group-hover/agent:rotate-3 transition-all duration-500 shadow-2xl">
                  <.icon name="hero-pencil-square" class="size-8" />
                </div>
                <%= if @contents != [] do %>
                  <span class="px-4 py-1 rounded-full bg-emerald-500/10 text-emerald-500 text-[10px] font-black uppercase tracking-widest border border-emerald-500/20">
                    {length(@contents)} Posts
                  </span>
                <% end %>
              </div>
              <h4 class="text-3xl font-black mb-4 leading-tight">Content Writer</h4>
              <p class="text-zinc-400 font-bold text-lg leading-relaxed mb-10">
                Generate SEO-optimized blog posts tailored to your target personas.
              </p>

              <div class="mt-auto">
                <%= if @contents != [] do %>
                  <div class="space-y-3 mb-8">
                    <div :for={content <- Enum.take(@contents, 2)} class="p-4 rounded-xl bg-white/5 border border-white/10">
                      <div class="text-sm font-black text-white truncate">{content.title}</div>
                      <div class="text-xs text-zinc-500 mt-1">{content.target_keyword}</div>
                    </div>
                    <%= if length(@contents) > 2 do %>
                      <div class="text-xs text-zinc-500 font-bold text-center">
                        +{length(@contents) - 2} more posts
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <button
                  phx-click="run_agent"
                  phx-value-agent="content_writer"
                  disabled={@loading_agents["content_writer"]}
                  class={[
                    "w-full py-5 rounded-2xl font-black text-lg transition-all flex items-center justify-center gap-3",
                    if(@contents != [],
                      do: "bg-white/5 text-white hover:bg-white/10",
                      else: "bg-blue-500 text-white shadow-2xl shadow-blue-500/20 hover:scale-105"
                    )
                  ]}
                >
                  <%= if @loading_agents["content_writer"] do %>
                    <.icon name="hero-arrow-path" class="size-6 animate-spin" /> Writing...
                  <% else %>
                    <.icon
                      name={if(@contents != [], do: "hero-eye", else: "hero-play")}
                      class="size-6"
                    />
                    {if(@contents != [], do: "Generate More", else: "Run Agent")}
                  <% end %>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <.persona_results personas={@personas} project={@project} />
      <.competitor_results competitors={@analysis["competitors"]} />
      <.lead_results leads={@analysis["leads"]} />
      <.content_results content={@analysis["content"]} />
      <.cro_results audit={@analysis["cro_audit"]} />
      <.aeo_results strategy={@analysis["aeo_strategy"]} />

    <!-- Analysis Footer -->
      <div class="flex flex-col sm:flex-row items-center justify-between gap-8 p-12 rounded-[3rem] bg-white/5 border border-white/10 backdrop-blur-xl shadow-2xl">
        <div class="flex items-center gap-6">
          <div class="size-16 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-500 border border-emerald-500/20">
            <.icon name="hero-check-badge" class="size-8" />
          </div>
          <div>
            <p class="text-xs font-black uppercase tracking-[0.3em] text-zinc-500 mb-1">
              Analysis Complete
            </p>
            <p class="text-xl font-black">
              Generated on {Calendar.strftime(@analyzed_at, "%b %d, %Y at %I:%M %p")}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-4">
          <button class="px-10 py-5 rounded-2xl bg-white/5 border border-white/10 text-white font-black text-lg hover:bg-white/10 transition-colors">
            Export PDF
          </button>
          <button class="px-10 py-5 rounded-2xl bg-primary text-white font-black text-lg shadow-2xl shadow-primary/20 hover:scale-105 transition-all">
            Share Report
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp failed_state(assigns) do
    ~H"""
    <div class="rounded-[3rem] bg-rose-500/5 border border-rose-500/20 backdrop-blur-xl p-24 text-center shadow-2xl">
      <div class="mx-auto size-24 rounded-3xl bg-rose-500/10 flex items-center justify-center text-rose-500 mb-8">
        <.icon name="hero-exclamation-triangle" class="size-12" />
      </div>
      <h2 class="text-4xl font-black mb-4">Analysis Failed</h2>
      <p class="text-xl text-zinc-400 max-w-md mx-auto leading-relaxed mb-12">
        We encountered an error while analyzing your website. This could be due to a timeout or the site blocking our crawler.
      </p>
      <button
        phx-click="reanalyze"
        class="inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-rose-600 text-white font-black text-xl hover:scale-105 active:scale-95 transition-all shadow-2xl shadow-rose-600/20"
      >
        <.icon name="hero-arrow-path" class="size-6" /> Try Again
      </button>
    </div>
    """
  end

  defp unknown_state(assigns) do
    ~H"""
    <div class="rounded-[3rem] bg-white/5 border border-white/10 backdrop-blur-xl p-24 text-center shadow-2xl">
      <p class="text-xl text-zinc-500">Unknown status. Please refresh the page.</p>
    </div>
    """
  end

  defp persona_results(assigns) do
    ~H"""
    <div :if={@personas != []} class="space-y-12 pt-24 border-t border-white/5">
      <div class="flex items-center justify-between gap-4">
        <div class="flex items-center gap-4">
          <div class="size-12 rounded-2xl bg-indigo-500/10 flex items-center justify-center text-indigo-400 border border-indigo-500/20">
            <.icon name="hero-user-group" class="size-6" />
          </div>
          <h3 class="text-4xl font-black tracking-tighter">Ideal Customer Profiles</h3>
        </div>
        <.link
          navigate={~p"/projects/#{@project.slug}/personas/compare"}
          class="inline-flex items-center gap-3 px-6 py-3 rounded-xl bg-white/5 border border-white/10 text-white font-black text-sm hover:bg-white/10 transition-all"
        >
          <.icon name="hero-arrows-right-left" class="size-5" /> Compare Personas
        </.link>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <%= for persona <- @personas do %>
          <div class="group/persona relative">
            <div class="absolute -inset-1 bg-linear-to-br from-indigo-500/20 to-transparent rounded-[3rem] blur-xl opacity-0 group-hover/persona:opacity-100 transition duration-700">
            </div>
            <div class="relative h-full rounded-[3rem] bg-zinc-900/50 border border-white/10 p-10 backdrop-blur-3xl hover:border-indigo-500/50 transition-all duration-500 flex flex-col">
              <div class="flex items-start justify-between mb-8">
                <div class="space-y-1">
                  <div class="flex items-center gap-3">
                    <h4 class="text-3xl font-black text-white leading-tight">{persona.name}</h4>
                    <%= if persona.is_primary do %>
                      <span class="px-2 py-0.5 rounded-md bg-amber-500/10 text-amber-500 text-[10px] font-black uppercase tracking-widest border border-amber-500/20">
                        Primary
                      </span>
                    <% end %>
                  </div>
                  <p class="text-indigo-400 font-black text-sm uppercase tracking-widest">
                    {persona.role}
                  </p>
                </div>
                <button
                  phx-click="set_primary_persona"
                  phx-value-id={persona.id}
                  class={[
                    "size-12 rounded-xl border transition-all flex items-center justify-center",
                    if(persona.is_primary,
                      do: "bg-amber-500/10 border-amber-500/50 text-amber-500",
                      else: "bg-white/5 border-white/10 text-zinc-500 hover:border-amber-500/50 hover:text-amber-500"
                    )
                  ]}
                >
                  <.icon
                    name={if(persona.is_primary, do: "hero-star-solid", else: "hero-star")}
                    class="size-6"
                  />
                </button>
              </div>

              <div class="space-y-8">
                <!-- Demographics -->
                <div class="grid grid-cols-2 gap-4">
                  <div class="p-4 rounded-2xl bg-white/5 border border-white/10">
                    <div class="text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-1">
                      Age Range
                    </div>
                    <div class="text-white font-bold">{persona.demographics["age_range"]}</div>
                  </div>
                  <div class="p-4 rounded-2xl bg-white/5 border border-white/10">
                    <div class="text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-1">
                      Job Title
                    </div>
                    <div class="text-white font-bold">{persona.demographics["job_title"]}</div>
                  </div>
                </div>

                <!-- Personality -->
                <div class="space-y-4">
                  <h5 class="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">
                    Personality Traits
                  </h5>
                  <div class="flex flex-wrap gap-2">
                    <%= for {trait, value} <- persona.personality_traits || %{} do %>
                      <span class="px-3 py-1 rounded-lg bg-indigo-500/5 text-indigo-400 text-[10px] font-black uppercase tracking-widest border border-indigo-500/10">
                        {String.capitalize(trait)}: {value}
                      </span>
                    <% end %>
                  </div>
                </div>

                <!-- Pain Points -->
                <div class="space-y-4">
                  <h5 class="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">
                    Core Pain Points
                  </h5>
                  <ul class="space-y-3">
                    <%= for pain <- persona.pain_points || [] do %>
                      <li class="flex gap-3 text-sm font-bold text-zinc-400 leading-relaxed">
                        <.icon name="hero-no-symbol" class="size-5 text-rose-500 shrink-0" />
                        {pain}
                      </li>
                    <% end %>
                  </ul>
                </div>

                <!-- Goals -->
                <div class="space-y-4">
                  <h5 class="text-xs font-black text-zinc-500 uppercase tracking-[0.3em]">
                    Primary Goals
                  </h5>
                  <ul class="space-y-3">
                    <%= for goal <- persona.goals || [] do %>
                      <li class="flex gap-3 text-sm font-bold text-zinc-400 leading-relaxed">
                        <.icon name="hero-check-circle" class="size-5 text-emerald-500 shrink-0" />
                        {goal}
                      </li>
                    <% end %>
                  </ul>
                </div>
              </div>

              <div class="mt-auto pt-10 flex items-center justify-between gap-4">
                <div class="p-6 rounded-2xl bg-indigo-500/5 border border-indigo-500/10 italic text-sm font-medium text-indigo-300 leading-relaxed flex-1">
                  "{persona.description}"
                </div>
                <.link
                  navigate={~p"/projects/#{@project.slug}/personas/#{persona.id}"}
                  class="size-12 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center text-zinc-500 hover:text-indigo-400 hover:border-indigo-500/50 transition-all shrink-0"
                >
                  <.icon name="hero-arrow-right" class="size-6" />
                </.link>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp competitor_results(assigns) do
    ~H"""
    <div :if={@competitors} class="space-y-12 pt-24 border-t border-white/5">
      <div class="flex items-center gap-4">
        <div class="size-12 rounded-2xl bg-primary/10 flex items-center justify-center text-primary border border-primary/20">
          <.icon name="hero-magnifying-glass" class="size-6" />
        </div>
        <h3 class="text-4xl font-black tracking-tighter">Competitor Gap Analysis</h3>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for comp <- @competitors do %>
          <div class="group/comp relative rounded-[3rem] bg-white/5 border border-white/10 p-12 hover:border-primary/50 transition-all duration-500">
            <div class="flex justify-between items-start mb-8">
              <h4 class="text-3xl font-black">{comp["name"]}</h4>
              <span class="px-4 py-2 rounded-xl bg-primary/10 text-primary text-xs font-black uppercase tracking-widest border border-primary/20">
                {comp["pricing_strategy"]}
              </span>
            </div>
            <p class="text-zinc-400 font-bold mb-8 leading-relaxed">{comp["description"]}</p>

            <div class="space-y-8">
              <div>
                <h5 class="text-[10px] font-black text-zinc-500 uppercase tracking-[0.3em] mb-4">
                  Core Strengths
                </h5>
                <div class="flex flex-wrap gap-2">
                  <%= for strength <- comp["strengths"] || [] do %>
                    <span class="px-3 py-1 rounded-lg bg-emerald-500/10 text-emerald-500 text-xs font-bold border border-emerald-500/20">
                      {strength}
                    </span>
                  <% end %>
                </div>
              </div>

              <div class="p-6 rounded-2xl bg-primary/5 border border-primary/10">
                <h5 class="text-[10px] font-black text-primary uppercase tracking-[0.3em] mb-3">
                  The Market Gap
                </h5>
                <p class="text-white font-bold leading-relaxed">{comp["market_gap"]}</p>
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
    <div :if={@leads} class="space-y-12 pt-24 border-t border-white/5">
      <div class="flex items-center gap-4">
        <div class="size-12 rounded-2xl bg-secondary/10 flex items-center justify-center text-secondary border border-secondary/20">
          <.icon name="hero-user-group" class="size-6" />
        </div>
        <h3 class="text-4xl font-black tracking-tighter">Lead Discovery</h3>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for segment <- @leads do %>
          <div class="group/lead relative rounded-[3rem] bg-white/5 border border-white/10 p-12 hover:border-secondary/50 transition-all duration-500">
            <h4 class="text-3xl font-black mb-6">{segment["name"]}</h4>

            <div class="space-y-8">
              <div>
                <h5 class="text-[10px] font-black text-zinc-500 uppercase tracking-[0.3em] mb-4">
                  Pain Points
                </h5>
                <ul class="space-y-2">
                  <%= for pain <- segment["pain_points"] || [] do %>
                    <li class="flex items-center gap-3 text-zinc-300 font-bold">
                      <div class="size-1.5 rounded-full bg-secondary"></div>
                      {pain}
                    </li>
                  <% end %>
                </ul>
              </div>

              <div class="p-8 rounded-[2rem] bg-secondary/5 border border-secondary/10 space-y-6">
                <div>
                  <h5 class="text-[10px] font-black text-secondary uppercase tracking-[0.3em] mb-2">
                    Lead Magnet Idea
                  </h5>
                  <p class="text-white font-black text-lg">{segment["lead_magnet_idea"]}</p>
                </div>
                <div class="h-px bg-secondary/10"></div>
                <div>
                  <h5 class="text-[10px] font-black text-secondary uppercase tracking-[0.3em] mb-2">
                    Outreach Hook
                  </h5>
                  <p class="text-zinc-300 font-bold italic leading-relaxed">
                    "{segment["outreach_hook"]}"
                  </p>
                </div>
              </div>

              <div>
                <h5 class="text-[10px] font-black text-zinc-500 uppercase tracking-[0.3em] mb-4">
                  Where to find them
                </h5>
                <div class="flex flex-wrap gap-2">
                  <%= for place <- segment["where_to_find"] || [] do %>
                    <span class="px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-zinc-400 text-xs font-black">
                      {place}
                    </span>
                  <% end %>
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
    <div :if={@content} class="space-y-12 pt-24 border-t border-white/5">
      <div class="flex items-center gap-4">
        <div class="size-12 rounded-2xl bg-white/10 flex items-center justify-center text-white border border-white/20">
          <.icon name="hero-megaphone" class="size-6" />
        </div>
        <h3 class="text-4xl font-black tracking-tighter">Content Atomizer</h3>
      </div>

      <div class="p-12 rounded-[3rem] bg-white/5 border border-white/10 mb-12">
        <h5 class="text-[10px] font-black text-zinc-500 uppercase tracking-[0.4em] mb-6">
          Overall Strategy
        </h5>
        <p class="text-2xl text-white font-medium leading-relaxed">{@content["strategy"]}</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for atom <- @content["content_atoms"] || [] do %>
          <div class="group/atom relative rounded-[3rem] bg-zinc-900/50 border border-white/10 p-12 hover:bg-white/5 transition-all duration-500">
            <div class="flex justify-between items-center mb-8">
              <div class="flex items-center gap-3">
                <div class="size-10 rounded-xl bg-white/5 flex items-center justify-center">
                  <.icon
                    name={
                      case atom["platform"] do
                        "Twitter" -> "hero-chat-bubble-left-right"
                        "LinkedIn" -> "hero-user-circle"
                        _ -> "hero-document-text"
                      end
                    }
                    class="size-5 text-zinc-400"
                  />
                </div>
                <span class="text-sm font-black uppercase tracking-widest text-zinc-500">
                  {atom["platform"]}
                </span>
              </div>
              <span class="text-xs font-bold text-zinc-600">{atom["format"]}</span>
            </div>

            <h4 class="text-2xl font-black text-white mb-6 leading-tight">
              {atom["hook"]}
            </h4>

            <div class="space-y-6">
              <div class="p-6 rounded-2xl bg-white/5 border border-white/5 text-zinc-400 font-medium leading-relaxed whitespace-pre-line">
                {atom["body_outline"]}
              </div>
              <div class="flex items-center gap-3 text-primary font-black">
                <.icon name="hero-cursor-arrow-rays" class="size-5" />
                {atom["cta"]}
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp cro_results(assigns) do
    ~H"""
    <div :if={@audit} class="space-y-12 pt-24 border-t border-white/5">
      <div class="flex items-center gap-4">
        <div class="size-12 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-500 border border-emerald-500/20">
          <.icon name="hero-presentation-chart-line" class="size-6" />
        </div>
        <h3 class="text-4xl font-black tracking-tighter">Landing Page Audit</h3>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <div class="lg:col-span-1 p-12 rounded-[3rem] bg-emerald-500/5 border border-emerald-500/10 flex flex-col items-center justify-center text-center">
          <div class="text-8xl font-black text-emerald-500 mb-4">{@audit["overall_score"]}%</div>
          <div class="text-sm font-black text-zinc-500 uppercase tracking-[0.3em]">
            Overall CRO Score
          </div>
        </div>

        <div class="lg:col-span-3 grid grid-cols-1 md:grid-cols-3 gap-8">
          <div class="p-10 rounded-[2.5rem] bg-white/5 border border-white/10">
            <div class="text-xs font-black text-zinc-500 uppercase tracking-widest mb-4">Clarity</div>
            <div class="flex items-end gap-2">
              <div class="text-4xl font-black text-white">{@audit["clarity_rating"]}</div>
              <div class="text-zinc-600 font-bold mb-1">/ 10</div>
            </div>
            <div class="mt-6 h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
              <div
                class="h-full bg-emerald-500 rounded-full"
                style={"width: #{@audit["clarity_rating"] * 10}%"}
              >
              </div>
            </div>
          </div>

          <div class="p-10 rounded-[2.5rem] bg-white/5 border border-white/10">
            <div class="text-xs font-black text-zinc-500 uppercase tracking-widest mb-4">Trust</div>
            <div class="flex items-end gap-2">
              <div class="text-4xl font-black text-white">{@audit["trust_rating"]}</div>
              <div class="text-zinc-600 font-bold mb-1">/ 10</div>
            </div>
            <div class="mt-6 h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
              <div
                class="h-full bg-emerald-500 rounded-full"
                style={"width: #{@audit["trust_rating"] * 10}%"}
              >
              </div>
            </div>
          </div>

          <div class="p-10 rounded-[2.5rem] bg-white/5 border border-white/10">
            <div class="text-xs font-black text-zinc-500 uppercase tracking-widest mb-4">CTA</div>
            <div class="flex items-end gap-2">
              <div class="text-4xl font-black text-white">{@audit["cta_rating"]}</div>
              <div class="text-zinc-600 font-bold mb-1">/ 10</div>
            </div>
            <div class="mt-6 h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
              <div
                class="h-full bg-emerald-500 rounded-full"
                style={"width: #{@audit["cta_rating"] * 10}%"}
              >
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-12">
        <div class="space-y-8">
          <h4 class="text-2xl font-black text-white">Key Findings</h4>
          <div class="space-y-6">
            <%= for finding <- @audit["findings"] || [] do %>
              <div class="p-8 rounded-[2rem] bg-white/5 border border-white/10 hover:bg-white/10 transition-colors">
                <div class="flex justify-between items-start mb-4">
                  <span class="text-xs font-black text-emerald-500 uppercase tracking-widest">
                    {finding["area"]}
                  </span>
                  <span class={[
                    "px-3 py-1 rounded-lg text-[10px] font-black uppercase tracking-widest",
                    if(finding["impact"] == "High",
                      do: "bg-rose-500/10 text-rose-500",
                      else: "bg-amber-500/10 text-amber-500"
                    )
                  ]}>
                    {finding["impact"]} Impact
                  </span>
                </div>
                <h5 class="text-xl font-black text-white mb-3">{finding["issue"]}</h5>
                <p class="text-zinc-400 font-bold leading-relaxed">{finding["recommendation"]}</p>
              </div>
            <% end %>
          </div>
        </div>

        <div class="space-y-8">
          <h4 class="text-2xl font-black text-white">Hero Section Rewrite</h4>
          <div class="relative group/hero">
            <div class="absolute -inset-1 bg-linear-to-r from-emerald-500/20 to-primary/20 rounded-[3rem] blur-xl opacity-50">
            </div>
            <div class="relative p-12 rounded-[3rem] bg-zinc-900 border border-emerald-500/30 backdrop-blur-xl">
              <div class="size-12 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-500 mb-8">
                <.icon name="hero-pencil-square" class="size-6" />
              </div>
              <h5 class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em] mb-6">
                Suggested Headline
              </h5>
              <p class="text-4xl font-black text-white tracking-tight mb-10 leading-tight">
                {@audit["hero_rewrite"]["headline"]}
              </p>
              <div class="h-px bg-white/10 mb-10"></div>
              <h5 class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em] mb-6">
                Suggested Subheadline
              </h5>
              <p class="text-2xl text-zinc-300 font-medium leading-relaxed">
                {@audit["hero_rewrite"]["subheadline"]}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp aeo_results(assigns) do
    ~H"""
    <div :if={@strategy} class="space-y-12 pt-24 border-t border-white/5">
      <div class="flex items-center gap-4">
        <div class="size-12 rounded-2xl bg-amber-500/10 flex items-center justify-center text-amber-500 border border-amber-500/20">
          <.icon name="hero-cpu-chip" class="size-6" />
        </div>
        <h3 class="text-4xl font-black tracking-tighter">AEO Strategy (AI Search Optimization)</h3>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 space-y-8">
          <h4 class="text-2xl font-black text-white">Semantic Clusters</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%= for cluster <- @strategy["semantic_clusters"] || [] do %>
              <div class="p-8 rounded-[2rem] bg-white/5 border border-white/10 hover:border-amber-500/30 transition-all">
                <h5 class="text-xl font-black text-white mb-4">{cluster["topic"]}</h5>
                <div class="flex flex-wrap gap-2 mb-6">
                  <%= for keyword <- cluster["keywords"] || [] do %>
                    <span class="px-3 py-1 rounded-lg bg-amber-500/5 text-amber-500 text-[10px] font-black uppercase tracking-widest border border-amber-500/10">
                      {keyword}
                    </span>
                  <% end %>
                </div>
                <p class="text-zinc-400 font-bold text-sm leading-relaxed">{cluster["intent_gap"]}</p>
              </div>
            <% end %>
          </div>
        </div>

        <div class="space-y-8">
          <h4 class="text-2xl font-black text-white">Entity Graph</h4>
          <div class="p-10 rounded-[3rem] bg-zinc-900 border border-white/10 space-y-8">
            <%= for entity <- @strategy["entity_graph"] || [] do %>
              <div class="space-y-3">
                <div class="flex justify-between items-center">
                  <span class="text-sm font-black text-white">{entity["entity"]}</span>
                  <span class="text-[10px] font-black text-zinc-500 uppercase tracking-widest">
                    {entity["type"]}
                  </span>
                </div>
                <div class="flex flex-wrap gap-2">
                  <%= for rel <- entity["relationships"] || [] do %>
                    <span class="px-2 py-1 rounded-md bg-white/5 text-zinc-500 text-[10px] font-bold border border-white/5">
                      → {rel}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="p-12 rounded-[3rem] bg-amber-500/5 border border-amber-500/10">
        <h4 class="text-2xl font-black text-white mb-8">Direct Answer Optimization</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-12">
          <%= for qa <- @strategy["direct_answer_targets"] || [] do %>
            <div class="space-y-4">
              <div class="flex items-start gap-4">
                <div class="size-8 rounded-lg bg-amber-500/20 flex items-center justify-center text-amber-500 shrink-0 mt-1">
                  <span class="font-black text-xs">Q</span>
                </div>
                <p class="text-xl font-black text-white leading-tight">{qa["question"]}</p>
              </div>
              <div class="flex items-start gap-4">
                <div class="size-8 rounded-lg bg-emerald-500/20 flex items-center justify-center text-emerald-500 shrink-0 mt-1">
                  <span class="font-black text-xs">A</span>
                </div>
                <p class="text-zinc-400 font-bold leading-relaxed italic">
                  "{qa["optimized_answer"]}"
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers

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
