defmodule MarketMindWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MarketMindWeb, :html

  # Embed all files in layouts/* within this module.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil, doc: "the current scope"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="layout-wrapper min-h-screen bg-[#F9FAFB] dark:bg-[#0B222C] p-0 lg:p-6 xl:p-8 flex items-stretch">
      <div class="flex-1 flex bg-white dark:bg-[#122C36] rounded-none lg:rounded-[2.5rem] shadow-soft overflow-hidden border-none lg:border lg:border-[#F1F3F5] dark:lg:border-white/5 relative">
        <!-- Sidebar -->
        <aside
          id="layout-menu"
          class="w-[280px] bg-[#0B222C] border-r border-white/5 hidden lg:flex flex-col flex-shrink-0"
        >
          <!-- Logo Section -->
          <div class="flex items-center h-[100px] px-10">
            <a href="/" class="flex items-center gap-4 group">
              <div class="size-11 rounded-2xl bg-[#27C281] flex items-center justify-center shadow-lg shadow-[#0B222C]/10 transition-transform group-hover:scale-105">
                <.icon name="hero-megaphone" class="size-6 text-[#0B222C]" />
              </div>
              <span class="font-extrabold text-xl tracking-tight text-white">
                MarketMind
              </span>
            </a>
          </div>

          <!-- Navigation -->
          <nav class="flex-1 py-4 space-y-10 overflow-y-auto px-6">
            <div>
              <div class="px-4 mb-4 text-[0.7rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.15em]">
                Workspace
              </div>
              <div class="space-y-1">
                <.sidebar_link
                  navigate={~p"/projects"}
                  icon="hero-squares-2x2"
                  label="Dashboard"
                  active={@current_scope == :dashboard}
                />
                <.sidebar_link navigate="#" icon="hero-shopping-bag" label="Products" />
                <.sidebar_link navigate="#" icon="hero-user-group" label="Personas" />
                <.sidebar_link navigate="#" icon="hero-document-text" label="Content" />
                <.sidebar_link navigate="#" icon="hero-rocket-launch" label="Campaigns" />
              </div>
            </div>

            <div>
              <div class="px-4 mb-4 text-[0.7rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.15em]">
                Growth
              </div>
              <div class="space-y-1">
                <.sidebar_link navigate="#" icon="hero-user-plus" label="Leads" />
                <.sidebar_link navigate="#" icon="hero-chart-bar-square" label="Analytics" />
              </div>
            </div>

            <div class="pt-4 mt-auto">
              <div class="px-4 mb-4 text-[0.7rem] font-extrabold text-[#A0AEC0] uppercase tracking-[0.15em]">
                Account
              </div>
              <div class="space-y-1">
                <.sidebar_link navigate="#" icon="hero-cog-8-tooth" label="Settings" />
                <.sidebar_link navigate="#" icon="hero-question-mark-circle" label="Support" />
              </div>
            </div>
          </nav>

          <!-- Logout Section -->
          <div class="p-8 mt-auto border-t border-[#F1F3F5] dark:border-white/5">
            <button class="flex items-center gap-3 text-[#FF4D4D] font-bold text-sm hover:opacity-80 transition-opacity px-4 py-2 w-full rounded-xl hover:bg-red-50 dark:hover:bg-red-500/10">
              <.icon name="hero-arrow-left-on-rectangle" class="size-5" />
              <span>Log out</span>
            </button>
          </div>
        </aside>

        <!-- Main Content Section -->
        <div class="flex-1 flex flex-col min-h-0 min-w-0 bg-white dark:bg-[#122C36]">
          <!-- Top Navbar -->
          <nav class="h-[100px] flex items-center justify-between px-10 border-b border-[#F1F3F5] dark:border-white/5 sticky top-0 z-40 bg-white/80 dark:bg-[#122C36]/80 backdrop-blur-md">
            <!-- Search -->
            <div class="flex-1 max-w-lg">
              <div class="relative group">
                <div class="absolute inset-y-0 left-5 flex items-center pointer-events-none">
                  <.icon name="hero-magnifying-glass" class="size-5 text-[#A0AEC0] group-focus-within:text-[#0B222C] transition-colors" />
                </div>
                <input
                  type="text"
                  class="w-full bg-[#F9FAFB] dark:bg-[#0B222C]/40 border-0 rounded-2xl py-3.5 pl-14 pr-16 text-sm text-[#0B222C] dark:text-white placeholder:text-[#A0AEC0] shadow-none focus:ring-2 focus:ring-[#0B222C]/5 dark:focus:ring-white/5 transition-all outline-none"
                  placeholder="Universal Search..."
                />
                <div class="absolute inset-y-0 right-5 flex items-center pointer-events-none">
                  <kbd class="hidden sm:inline-flex items-center gap-1 px-2.5 py-1 text-[10px] font-extrabold text-[#A0AEC0] bg-white dark:bg-[#122C36] border border-[#F1F3F5] dark:border-white/10 rounded-lg shadow-sm">
                    <span class="text-xs">⌘</span> K
                  </kbd>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-8">
              <div class="hidden md:flex items-center gap-4 mr-2">
                 <.theme_toggle />
              </div>

              <button class="relative size-12 rounded-2xl bg-white dark:bg-[#0B222C]/40 flex items-center justify-center text-[#4a5568] dark:text-gray-400 border border-[#F1F3F5] dark:border-white/5 hover:bg-[#F9FAFB] transition-all">
                <.icon name="hero-bell" class="size-6" />
                <span class="absolute top-3.5 right-3.5 size-2.5 bg-[#27C281] rounded-full border-2 border-white dark:border-[#0B222C]"></span>
              </button>

              <div class="flex items-center gap-4">
                <div class="text-right hidden sm:block">
                  <p class="text-sm font-extrabold text-[#0B222C] dark:text-white">Richard Azet</p>
                  <p class="text-[10px] font-bold text-[#A0AEC0] uppercase tracking-wider">Growth Lead</p>
                </div>
                <button class="size-12 rounded-2xl overflow-hidden ring-1 ring-[#F1F3F5] dark:ring-white/10 p-0.5">
                  <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Richard" alt="Avatar" class="size-full object-cover rounded-[14px]" />
                </button>
              </div>
            </div>
          </nav>

          <!-- Actual Page Content -->
          <main class="flex-1 overflow-y-auto px-10 py-10">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-4 px-4 py-3.5 rounded-2xl transition-all duration-300 group relative",
        if(assigns[:active],
          do: "bg-[#27C281] text-[#0B222C] shadow-lg shadow-[#27C281]/20 font-bold",
          else: "text-[#94A3B8] hover:text-white hover:bg-white/5"
        )
      ]}
    >
      <.icon
        name={@icon}
        class={[
          "size-6 transition-all",
          if(assigns[:active],
            do: "text-[#0B222C]",
            else: "text-[#64748B] group-hover:text-white"
          )
        ]}
      />
      <span class="text-[0.95rem] tracking-tight">{@label}</span>
    </.link>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="fixed top-8 right-8 z-[100] space-y-4">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="flex items-center bg-[#F9FAFB] dark:bg-[#0B222C]/40 p-1.5 rounded-2xl border border-[#F1F3F5] dark:border-white/5">
      <button
        class="size-8 rounded-xl flex items-center justify-center transition-all [[data-theme=light]_&]:bg-white [[data-theme=light]_&]:shadow-sm [[data-theme=light]_&]:text-[#0B222C] text-[#A0AEC0] hover:text-[#0B222C]"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun" class="size-4" />
      </button>

      <button
        class="size-8 rounded-xl flex items-center justify-center transition-all [[data-theme=dark]_&]:bg-[#27C281] [[data-theme=dark]_&]:shadow-sm [[data-theme=dark]_&]:text-[#0B222C] text-[#A0AEC0] dark:hover:text-white"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon" class="size-4" />
      </button>
    </div>
    """
  end
end
