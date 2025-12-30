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
    <Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="max-w-7xl mx-auto pb-20">
        <!-- Breadcrumbs -->
        <nav class="flex mb-10" aria-label="Breadcrumb">
          <ol class="inline-flex items-center gap-3">
            <li class="inline-flex items-center">
              <.link navigate={~p"/projects"} class="inline-flex items-center text-sm font-bold text-[#A0AEC0] hover:text-[#0B222C] dark:hover:text-white transition-colors uppercase tracking-widest">
                <.icon name="hero-home" class="size-4 mr-2" /> Dashboard
              </.link>
            </li>
            <li>
              <div class="flex items-center gap-3">
                <.icon name="hero-chevron-right" class="size-4 text-[#A0AEC0]" />
                <span class="text-sm font-bold text-[#0B222C] dark:text-white uppercase tracking-widest">New Project</span>
              </div>
            </li>
          </ol>
        </nav>

        <div class="flex flex-col lg:flex-row gap-10">
          <!-- Main Form Column -->
          <div class="flex-1">
            <div class="bg-white dark:bg-[#122C36] rounded-[2.5rem] shadow-soft border border-[#F1F3F5] dark:border-white/5 overflow-hidden">
              <div class="p-10 border-b border-[#F1F3F5] dark:border-white/5 bg-[#F9FAFB] dark:bg-white/5">
                <h2 class="text-3xl font-extrabold text-[#0B222C] dark:text-white tracking-tight">Initialize New Project</h2>
                <p class="text-base font-bold text-[#A0AEC0] mt-2">Provide your project details to start the AI market analysis.</p>
              </div>

              <div class="p-10">
                <.form
                  for={@form}
                  id="project-form"
                  phx-submit="save"
                  phx-change="validate"
                  class="space-y-10"
                >
                  <div class="grid grid-cols-1 gap-10">
                    <div class="space-y-3">
                      <.input
                        field={@form[:name]}
                        type="text"
                        label="Project Name"
                        placeholder="e.g., MarketMind AI"
                        required
                      />
                      <p class="text-[0.8rem] font-bold text-[#A0AEC0] ml-1 uppercase tracking-wider">A descriptive name for your project or product.</p>
                    </div>

                    <div class="space-y-3">
                      <.input
                        field={@form[:url]}
                        type="url"
                        label="Website URL"
                        placeholder="https://example.com"
                        required
                      />
                      <p class="text-[0.8rem] font-bold text-[#A0AEC0] ml-1 uppercase tracking-wider">The URL of your product landing page or website.</p>
                    </div>

                    <div class="space-y-3">
                      <.input
                        field={@form[:description]}
                        type="textarea"
                        label="Product Description (Optional)"
                        placeholder="Briefly describe what your product does, its key features, and target audience..."
                      />
                      <p class="text-[0.8rem] font-bold text-[#A0AEC0] ml-1 uppercase tracking-wider">Detailed information helps our AI provide more accurate insights.</p>
                    </div>
                  </div>

                  <div class="pt-6 flex items-center gap-6">
                    <.button type="submit" phx-disable-with="Initializing..." class="px-10 py-4 text-base">
                      Create Project
                    </.button>
                    <.link navigate={~p"/projects"} class="text-sm font-extrabold text-[#A0AEC0] hover:text-[#0B222C] dark:hover:text-white transition-colors uppercase tracking-widest">
                      Cancel
                    </.link>
                  </div>
                </.form>
              </div>
            </div>
          </div>

          <!-- Sidebar Info Column -->
          <div class="w-full lg:w-[380px] space-y-8">
            <div class="bg-[#0B222C] rounded-[2.5rem] p-10 shadow-2xl shadow-[#0B222C]/30 text-white relative overflow-hidden group">
               <div class="absolute top-0 right-0 p-10 opacity-10 -rotate-12 group-hover:scale-110 transition-transform">
                  <.icon name="hero-sparkles" class="size-48" />
               </div>
               <div class="relative z-10">
                  <div class="size-16 rounded-2xl bg-[#27C281] flex items-center justify-center text-[#0B222C] mb-8 shadow-xl shadow-[#27C281]/20">
                    <.icon name="hero-sparkles" class="size-8" />
                  </div>
                  <h3 class="text-2xl font-extrabold mb-4 tracking-tight">AI-Powered Analysis</h3>
                  <p class="text-gray-400 text-sm leading-relaxed mb-8">
                    Our AI engine will automatically crawl your website and analyze your product to generate:
                  </p>
                  <ul class="space-y-5">
                    <%= for item <- ["Ideal Customer Personas", "Competitor Analysis", "Content Strategy", "Lead Magnet Ideas"] do %>
                      <li class="flex items-center gap-3 text-sm font-bold">
                        <div class="size-6 rounded-lg bg-[#27C281]/20 flex items-center justify-center text-[#27C281]">
                           <.icon name="hero-check" class="size-4" />
                        </div>
                        {item}
                      </li>
                    <% end %>
                  </ul>
               </div>
            </div>

            <div class="bg-white dark:bg-[#122C36] rounded-[2.5rem] p-10 border border-[#F1F3F5] dark:border-white/5 shadow-soft">
              <h3 class="text-xs font-extrabold text-[#A0AEC0] uppercase tracking-widest mb-6">Need Help?</h3>
              <p class="text-sm font-bold text-[#718096] dark:text-[#A0AEC0] leading-relaxed mb-8">
                Check our documentation for tips on how to get the best results from your analysis.
              </p>
              <.link href="#" class="inline-flex items-center gap-2 text-primary dark:text-[#27C281] font-extrabold text-sm uppercase tracking-widest hover:translate-x-1 transition-transform">
                Open Docs <.icon name="hero-arrow-right" class="size-4" />
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
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
