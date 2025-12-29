defmodule MarketMindWeb.ProjectLive.New do
  @moduledoc """
  LiveView for creating a new project.

  Provides a form to add a new SaaS product for analysis.
  On successful creation, queues the product for AI analysis
  and redirects to the show page.
  """
  use MarketMindWeb, :live_view

  alias MarketMind.Products
  alias MarketMind.Products.Project

  @impl true
  def mount(_params, _session, socket) do
    user = get_or_create_user()
    changeset = Products.change_project(%Project{})

    {:ok,
     socket
     |> assign(:page_title, "Add New Project")
     |> assign(:user, user)
     |> assign(:current_scope, :dashboard)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative px-4 sm:px-12 py-12 sm:py-20 overflow-hidden">
      <!-- Background Glows -->
      <div class="absolute top-0 left-1/4 size-[500px] bg-primary/10 rounded-full blur-[120px] -translate-y-1/2">
      </div>
      <div class="absolute bottom-0 right-1/4 size-[500px] bg-secondary/10 rounded-full blur-[120px] translate-y-1/2">
      </div>

      <div class="relative max-w-6xl mx-auto">
        <!-- Breadcrumb -->
        <div class="mb-16 animate-in fade-in slide-in-from-left-4 duration-700">
          <.link
            navigate={~p"/projects"}
            class="group inline-flex items-center gap-4 text-xs font-black uppercase tracking-[0.3em] text-zinc-500 hover:text-primary transition-all"
          >
            <div class="size-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center group-hover:border-primary/50 group-hover:-translate-x-2 transition-all">
              <.icon name="hero-arrow-left" class="size-5" />
            </div>
            Back to Intelligence Dashboard
          </.link>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-20">
          <div class="lg:col-span-2">
            <!-- Header Section -->
            <div class="mb-20 animate-in fade-in slide-in-from-bottom-4 duration-700 delay-100">
              <div class="inline-flex items-center gap-3 px-4 py-2 rounded-full bg-primary/10 text-primary text-[10px] font-black uppercase tracking-[0.3em] mb-8 ring-1 ring-primary/20">
                <span class="relative flex h-2 w-2">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75">
                  </span>
                  <span class="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                </span>
                Initialize Analysis
              </div>
              <h1 class="text-7xl font-black tracking-tighter mb-6">
                New
                <span class="text-transparent bg-clip-text bg-linear-to-r from-white via-white to-white/40">
                  Project
                </span>
              </h1>
              <p class="text-2xl text-zinc-500 font-medium max-w-xl leading-relaxed">
                Deploy our AI engine to dissect your product's market presence and extract strategic insights.
              </p>
            </div>

    <!-- Form Card -->
            <div class="relative group animate-in fade-in slide-in-from-bottom-8 duration-1000 delay-200">
              <div class="absolute -inset-1 bg-linear-to-r from-primary to-secondary rounded-[4rem] blur opacity-10 group-hover:opacity-20 transition duration-1000">
              </div>
              <div class="relative rounded-[4rem] bg-zinc-900/50 border border-white/10 backdrop-blur-2xl overflow-hidden shadow-2xl">
                <div class="p-12 sm:p-20">
                  <.form
                    for={@form}
                    id="project-form"
                    phx-submit="save"
                    phx-change="validate"
                    class="space-y-12"
                  >
                    <div class="grid grid-cols-1 gap-12">
                      <div class="space-y-4">
                        <label class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em] ml-2">
                          Project Identity
                        </label>
                        <.input
                          field={@form[:name]}
                          type="text"
                          placeholder="e.g., MarketMind AI"
                          required
                          class="w-full px-8 py-6 rounded-3xl bg-white/5 border border-white/10 focus:border-primary/50 focus:bg-white/10 transition-all outline-hidden text-xl font-black placeholder:text-zinc-700"
                        />
                      </div>

                      <div class="space-y-4">
                        <label class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em] ml-2">
                          Product URL
                        </label>
                        <.input
                          field={@form[:url]}
                          type="url"
                          placeholder="https://marketmind.ai"
                          required
                          class="w-full px-8 py-6 rounded-3xl bg-white/5 border border-white/10 focus:border-primary/50 focus:bg-white/10 transition-all outline-hidden text-xl font-black placeholder:text-zinc-700"
                        />
                      </div>

                      <div class="space-y-4">
                        <label class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em] ml-2">
                          Strategic Context (Optional)
                        </label>
                        <.input
                          field={@form[:description]}
                          type="textarea"
                          placeholder="What core problem does your product solve?"
                          rows="4"
                          class="w-full px-8 py-6 rounded-3xl bg-white/5 border border-white/10 focus:border-primary/50 focus:bg-white/10 transition-all outline-hidden text-xl font-black placeholder:text-zinc-700 resize-none"
                        />
                      </div>
                    </div>

                    <div class="pt-8">
                      <button
                        type="submit"
                        phx-disable-with="Initializing..."
                        class="w-full group relative flex items-center justify-center gap-4 px-12 py-8 rounded-3xl bg-white text-zinc-950 font-black text-2xl shadow-[0_0_50px_rgba(255,255,255,0.1)] hover:scale-[1.02] active:scale-[0.98] transition-all overflow-hidden"
                      >
                        <div class="absolute inset-0 bg-linear-to-r from-primary/20 to-secondary/20 opacity-0 group-hover:opacity-100 transition-opacity">
                        </div>
                        <span class="relative z-10">Start Intelligence Analysis</span>
                        <.icon
                          name="hero-sparkles"
                          class="size-8 relative z-10 group-hover:rotate-12 transition-transform"
                        />
                      </button>
                      <p class="text-center mt-8 text-zinc-600 font-bold text-sm">
                        Our AI will crawl your site and generate a comprehensive report in ~60 seconds.
                      </p>
                    </div>
                  </.form>
                </div>
              </div>
            </div>
          </div>

    <!-- Sidebar Tips -->
          <div class="space-y-12 pt-32 animate-in fade-in slide-in-from-right-8 duration-1000 delay-300">
            <div class="space-y-8">
              <h3 class="text-xs font-black text-zinc-500 uppercase tracking-[0.4em]">
                Strategic Tips
              </h3>

              <div class="space-y-6">
                <%= for {title, desc, icon} <- [
                  {"Accurate URL", "Ensure the URL is public and accessible for our AI crawler.", "hero-globe-alt"},
                  {"Context Matters", "Providing a brief description helps our AI focus on your core value.", "hero-light-bulb"},
                  {"Real-time Data", "We analyze your live site to ensure the most up-to-date insights.", "hero-arrow-path"}
                ] do %>
                  <div class="group/tip p-8 rounded-[2.5rem] bg-white/5 border border-white/10 hover:bg-white/10 transition-all duration-500">
                    <div class="size-12 rounded-2xl bg-primary/10 flex items-center justify-center text-primary mb-6 group-hover/tip:scale-110 transition-transform">
                      <.icon name={icon} class="size-6" />
                    </div>
                    <h4 class="text-xl font-black text-white mb-2">{title}</h4>
                    <p class="text-zinc-500 font-bold leading-relaxed">{desc}</p>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="p-8 rounded-[2.5rem] bg-linear-to-br from-primary/20 to-secondary/20 border border-white/10">
              <p class="text-sm font-black text-white uppercase tracking-widest mb-4">Pro Tip</p>
              <p class="text-zinc-300 font-bold leading-relaxed">
                Analyze your competitors' URLs to see how they stack up against your product.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    changeset =
      %Project{}
      |> Products.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    case Products.create_project(socket.assigns.user, project_params) do
      {:ok, project} ->
        # Queue the analysis
        Products.queue_analysis(project)

        {:noreply,
         socket
         |> put_flash(:info, "Project created! Analysis has started.")
         |> push_navigate(to: ~p"/projects/#{project.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
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
