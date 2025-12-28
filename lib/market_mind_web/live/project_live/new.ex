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
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 max-w-2xl">
      <div class="mb-8">
        <.link navigate={~p"/projects"} class="btn btn-ghost btn-sm gap-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Back to Projects
        </.link>
      </div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h1 class="card-title text-2xl mb-6">Add New Project</h1>

          <.form
            for={@form}
            id="project-form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <div class="form-control">
              <label class="label" for="project_name">
                <span class="label-text font-medium">Project Name</span>
              </label>
              <input
                type="text"
                id="project_name"
                name="project[name]"
                value={@form[:name].value}
                placeholder="e.g., My Awesome SaaS"
                class={"input input-bordered w-full #{if @form[:name].errors != [], do: "input-error"}"}
                required
              />
              <%= if @form[:name].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    <%= translate_error(hd(@form[:name].errors)) %>
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label" for="project_url">
                <span class="label-text font-medium">Product URL</span>
              </label>
              <input
                type="url"
                id="project_url"
                name="project[url]"
                value={@form[:url].value}
                placeholder="https://yourproduct.com"
                class={"input input-bordered w-full #{if @form[:url].errors != [], do: "input-error"}"}
                required
              />
              <label class="label">
                <span class="label-text-alt text-base-content/70">
                  We'll analyze your website to understand your product
                </span>
              </label>
              <%= if @form[:url].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    <%= translate_error(hd(@form[:url].errors)) %>
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label" for="project_description">
                <span class="label-text font-medium">Description (Optional)</span>
              </label>
              <textarea
                id="project_description"
                name="project[description]"
                placeholder="Brief description of your product..."
                class="textarea textarea-bordered w-full h-24"
              ><%= @form[:description].value %></textarea>
            </div>

            <div class="card-actions justify-end pt-4">
              <.link navigate={~p"/projects"} class="btn btn-ghost">
                Cancel
              </.link>
              <button type="submit" class="btn btn-primary">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
                Create & Analyze
              </button>
            </div>
          </.form>
        </div>
      </div>

      <div class="mt-6 text-center text-base-content/60 text-sm">
        <p>After creation, our AI will analyze your product website and generate marketing insights.</p>
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
