defmodule MarketMindWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MarketMindWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-950 selection:bg-primary/30 flex">
      <!-- Sidebar -->
      <aside class="fixed inset-y-0 left-0 z-50 w-80 bg-zinc-950 border-r border-white/5 hidden lg:flex flex-col">
        <!-- Logo Section -->
        <div class="p-10">
          <a href="/" class="flex items-center gap-4 group">
            <div class="size-12 rounded-2xl bg-linear-to-br from-primary to-secondary flex items-center justify-center shadow-2xl shadow-primary/20 group-hover:scale-110 group-hover:rotate-3 transition-all duration-500">
              <.icon name="hero-sparkles" class="size-7 text-white" />
            </div>
            <span class="text-3xl font-black tracking-tighter text-white">
              Market<span class="text-primary">Mind</span>
            </span>
          </a>
        </div>

    <!-- Navigation -->
        <nav class="flex-1 px-6 py-4 space-y-2 overflow-y-auto custom-scrollbar">
          <div class="px-4 mb-8">
            <.link
              navigate={~p"/projects/new"}
              class="w-full group relative flex items-center justify-center gap-3 px-6 py-4 rounded-2xl bg-white text-zinc-950 font-black text-sm uppercase tracking-widest hover:scale-[1.02] active:scale-[0.98] transition-all shadow-2xl shadow-white/10"
            >
              <.icon name="hero-plus-circle" class="size-5" /> New Project
            </.link>
          </div>

          <div class="text-[10px] font-black text-zinc-600 uppercase tracking-[0.4em] px-4 mb-6">
            Main Menu
          </div>

          <.sidebar_link
            navigate={~p"/projects"}
            icon="hero-squares-2x2"
            label="Dashboard"
            active={@current_scope == :dashboard}
          />
          <.sidebar_link navigate="#" icon="hero-chart-bar" label="Intelligence" />
          <.sidebar_link navigate="#" icon="hero-globe-alt" label="Market Network" />
          <.sidebar_link navigate="#" icon="hero-cpu-chip" label="AI Agents" />

          <div class="pt-10">
            <div class="text-[10px] font-black text-zinc-600 uppercase tracking-[0.4em] px-4 mb-6">
              System
            </div>
            <.sidebar_link navigate="#" icon="hero-cog-6-tooth" label="Settings" />
            <.sidebar_link navigate="#" icon="hero-shield-check" label="Security" />
          </div>
        </nav>

    <!-- User Section -->
        <div class="p-6 mt-auto">
          <div class="relative group">
            <div class="absolute -inset-1 bg-linear-to-r from-primary to-secondary rounded-3xl blur opacity-0 group-hover:opacity-20 transition duration-500">
            </div>
            <div class="relative p-4 rounded-3xl bg-white/5 border border-white/10 flex items-center gap-4">
              <div class="size-12 rounded-2xl bg-zinc-800 flex items-center justify-center text-zinc-400 font-black border border-white/5">
                JD
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-black text-white truncate">John Doe</p>
                <p class="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Pro Plan</p>
              </div>
              <button class="size-8 rounded-xl hover:bg-white/5 flex items-center justify-center text-zinc-500 hover:text-white transition-colors">
                <.icon name="hero-ellipsis-vertical" class="size-5" />
              </button>
            </div>
          </div>
        </div>
      </aside>

    <!-- Mobile Header -->
      <header class="lg:hidden fixed top-0 z-50 w-full border-b border-white/5 bg-zinc-950/80 backdrop-blur-2xl px-6 py-4 flex justify-between items-center">
        <a href="/" class="flex items-center gap-3">
          <div class="size-9 rounded-xl bg-linear-to-br from-primary to-secondary flex items-center justify-center">
            <.icon name="hero-sparkles" class="size-5 text-white" />
          </div>
          <span class="text-xl font-black tracking-tighter text-white">MarketMind</span>
        </a>
        <button class="size-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center text-white">
          <.icon name="hero-bars-3" class="size-6" />
        </button>
      </header>

    <!-- Main Content -->
      <main class="flex-1 lg:pl-80 min-h-screen relative">
        <!-- Top Bar (Desktop) -->
        <div class="hidden lg:flex sticky top-0 z-40 h-24 items-center justify-between px-12 bg-zinc-950/50 backdrop-blur-xl border-b border-white/5">
          <div class="flex-1 max-w-xl">
            <div class="relative group">
              <div class="absolute inset-y-0 left-0 pl-5 flex items-center pointer-events-none">
                <.icon
                  name="hero-magnifying-glass"
                  class="size-5 text-zinc-500 group-focus-within:text-primary transition-colors"
                />
              </div>
              <input
                type="text"
                id="global-search"
                phx-hook="Search"
                placeholder="Search projects, intelligence, or agents..."
                class="w-full bg-white/5 border border-white/10 rounded-2xl py-3.5 pl-14 pr-6 text-sm font-bold text-white placeholder:text-zinc-600 focus:outline-hidden focus:ring-2 focus:ring-primary/20 focus:border-primary/50 focus:bg-white/10 transition-all"
              />
              <div class="absolute inset-y-0 right-0 pr-4 flex items-center pointer-events-none">
                <kbd class="hidden sm:inline-flex items-center px-2 py-1 rounded-lg bg-white/5 border border-white/10 text-[10px] font-black text-zinc-500 uppercase tracking-widest">
                  ⌘K
                </kbd>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-6 ml-12">
            <div class="flex items-center gap-3 px-4 py-2 rounded-full bg-white/5 border border-white/10">
              <div class="size-2 rounded-full bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)] animate-pulse">
              </div>
              <span class="text-[10px] font-black text-zinc-400 uppercase tracking-[0.2em]">
                Engine Active
              </span>
            </div>

            <div class="h-8 w-px bg-white/5"></div>

            <div class="relative group/notifications">
              <button class="relative size-12 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-zinc-400 hover:text-white hover:border-white/20 transition-all group">
                <.icon name="hero-bell" class="size-6 group-hover:rotate-12 transition-transform" />
                <span class="absolute top-3 right-3 size-2.5 bg-primary rounded-full border-2 border-zinc-950">
                </span>
              </button>

    <!-- Notification Dropdown -->
              <div class="absolute top-full right-0 mt-4 w-96 bg-zinc-900 border border-white/10 rounded-[2rem] shadow-2xl opacity-0 translate-y-4 pointer-events-none group-hover/notifications:opacity-100 group-hover/notifications:translate-y-0 group-hover/notifications:pointer-events-auto transition-all duration-500 z-50 overflow-hidden">
                <div class="p-8 border-b border-white/5 flex items-center justify-between">
                  <h4 class="text-lg font-black text-white">Notifications</h4>
                  <span class="text-[10px] font-black text-primary uppercase tracking-widest">
                    2 New
                  </span>
                </div>
                <div class="max-h-[400px] overflow-y-auto custom-scrollbar">
                  <div class="p-6 hover:bg-white/5 transition-colors border-b border-white/5 flex gap-4">
                    <div class="size-10 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-500 shrink-0">
                      <.icon name="hero-check-circle" class="size-5" />
                    </div>
                    <div>
                      <p class="text-sm font-bold text-white mb-1">Analysis Complete</p>
                      <p class="text-xs text-zinc-500 leading-relaxed">
                        Your analysis for 'MarketMind AI' is ready for review.
                      </p>
                      <p class="text-[10px] text-zinc-600 mt-2 font-black uppercase tracking-widest">
                        2 mins ago
                      </p>
                    </div>
                  </div>
                  <div class="p-6 hover:bg-white/5 transition-colors border-b border-white/5 flex gap-4">
                    <div class="size-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary shrink-0">
                      <.icon name="hero-sparkles" class="size-5" />
                    </div>
                    <div>
                      <p class="text-sm font-bold text-white mb-1">New Agent Available</p>
                      <p class="text-xs text-zinc-500 leading-relaxed">
                        The AEO Strategy Agent is now active in your dashboard.
                      </p>
                      <p class="text-[10px] text-zinc-600 mt-2 font-black uppercase tracking-widest">
                        1 hour ago
                      </p>
                    </div>
                  </div>
                </div>
                <a
                  href="#"
                  class="block p-6 text-center text-xs font-black text-zinc-500 hover:text-white transition-colors uppercase tracking-widest bg-white/5"
                >
                  View All Notifications
                </a>
              </div>
            </div>

            <button class="px-8 py-3 rounded-2xl bg-white text-zinc-950 font-black text-sm uppercase tracking-widest hover:scale-105 active:scale-95 transition-all shadow-2xl shadow-white/10">
              Upgrade
            </button>
          </div>
        </div>

        <div class="pt-24 lg:pt-0">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "group flex items-center gap-4 px-4 py-4 rounded-2xl transition-all duration-300",
        if(assigns[:active],
          do: "bg-white text-zinc-950 shadow-2xl shadow-white/10",
          else: "text-zinc-500 hover:text-white hover:bg-white/5"
        )
      ]}
    >
      <div class={[
        "size-10 rounded-xl flex items-center justify-center transition-all duration-300",
        if(assigns[:active],
          do: "bg-zinc-950 text-white",
          else: "bg-white/5 group-hover:bg-white/10 group-hover:scale-110"
        )
      ]}>
        <.icon name={@icon} class="size-5" />
      </div>
      <span class="text-sm font-black uppercase tracking-widest">{@label}</span>
      <%= if assigns[:active] do %>
        <div class="ml-auto size-1.5 rounded-full bg-zinc-950"></div>
      <% end %>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
