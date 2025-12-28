# Quick Reference

> Cheat sheet for common patterns and commands in MarketMind.

## Terminal Commands

```bash
# Setup
mix deps.get                    # Install dependencies
mix ecto.setup                  # Create + migrate + seed DB
mix phx.server                  # Start dev server
iex -S mix phx.server           # Start with IEx

# Database
mix ecto.create                 # Create database
mix ecto.migrate                # Run migrations
mix ecto.rollback               # Rollback last migration
mix ecto.reset                  # Drop + create + migrate + seed
mix ecto.gen.migration NAME     # Generate migration

# Generators
mix phx.gen.auth Accounts User users     # Auth scaffold
mix phx.gen.context Ctx Model table      # Context + schema
mix phx.gen.live Ctx Model table         # LiveView CRUD
mix phx.gen.schema Model table           # Schema only

# Testing
mix test                        # Run all tests
mix test path/to/test.exs       # Run single file
mix test path/to/test.exs:42    # Run single test
mix test --cover                # With coverage
mix test.watch                  # Watch mode

# Quality
mix format                      # Format code
mix credo --strict              # Lint
mix dialyzer                    # Type check
```

---

## Context Patterns

```elixir
# List with user scope
def list_projects(%User{} = user) do
  Project
  |> where(user_id: ^user.id)
  |> where(is_active: true)
  |> order_by(desc: :inserted_at)
  |> Repo.all()
end

# Get with preloads
def get_project!(id) do
  Project
  |> preload([:personas, :content_pieces])
  |> Repo.get!(id)
end

# Create with association
def create_project(%User{} = user, attrs) do
  %Project{}
  |> Project.changeset(attrs)
  |> Ecto.Changeset.put_assoc(:user, user)
  |> Repo.insert()
end

# Update
def update_project(%Project{} = project, attrs) do
  project
  |> Project.changeset(attrs)
  |> Repo.update()
end

# Delete (soft)
def archive_project(%Project{} = project) do
  update_project(project, %{is_active: false})
end
```

---

## LiveView Patterns

### Mount with Auth

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Dashboard")
   |> assign_projects()}
end

defp assign_projects(socket) do
  projects = Products.list_projects(socket.assigns.current_user)
  assign(socket, :projects, projects)
end
```

### Handle Events

```elixir
# Form submit
def handle_event("save", %{"project" => params}, socket) do
  case Products.create_project(socket.assigns.current_user, params) do
    {:ok, project} ->
      {:noreply,
       socket
       |> put_flash(:info, "Project created!")
       |> push_navigate(to: ~p"/projects/#{project}")}

    {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
  end
end

# Delete with confirmation
def handle_event("delete", %{"id" => id}, socket) do
  project = Products.get_project!(id)
  {:ok, _} = Products.delete_project(project)

  {:noreply,
   socket
   |> put_flash(:info, "Project deleted")
   |> assign_projects()}
end
```

### PubSub

```elixir
# Subscribe on mount
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MarketMind.PubSub, "project:#{socket.assigns.project.id}")
  end
  {:ok, socket}
end

# Handle broadcasts
def handle_info({:task_completed, task}, socket) do
  {:noreply, update(socket, :tasks, &[task | &1])}
end

# Broadcast from context
def complete_task(task) do
  {:ok, task} = update_task(task, %{status: :completed})
  Phoenix.PubSub.broadcast(MarketMind.PubSub, "project:#{task.project_id}", {:task_completed, task})
  {:ok, task}
end
```

---

## Oban Workers

```elixir
defmodule MarketMind.Workers.AnalyzeProduct do
  use Oban.Worker,
    queue: :analysis,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    project = Products.get_project!(project_id)
    
    with {:ok, html} <- fetch_website(project.url),
         {:ok, analysis} <- analyze(html) do
      Products.update_project(project, %{analysis_data: analysis})
    end
  end
end

# Enqueue
%{project_id: project.id}
|> MarketMind.Workers.AnalyzeProduct.new()
|> Oban.insert()

# Schedule
%{project_id: project.id}
|> MarketMind.Workers.AnalyzeProduct.new(scheduled_at: DateTime.add(DateTime.utc_now(), 3600))
|> Oban.insert()
```

---

## Schema Patterns

### With JSONB

```elixir
schema "personas" do
  field :name, :string
  field :demographics, :map, default: %{}
  field :goals, {:array, :string}, default: []
  
  belongs_to :project, Project
  timestamps()
end

def changeset(persona, attrs) do
  persona
  |> cast(attrs, [:name, :demographics, :goals])
  |> validate_required([:name])
  |> validate_length(:name, min: 2, max: 100)
end
```

### State Machine (Approval)

```elixir
@statuses [:pending, :approved, :rejected, :revision_requested]

def changeset(content, attrs) do
  content
  |> cast(attrs, [:status])
  |> validate_inclusion(:status, @statuses)
  |> validate_status_transition()
end

defp validate_status_transition(changeset) do
  case {get_field(changeset, :status), get_change(changeset, :status)} do
    {_, nil} -> changeset
    {:pending, :approved} -> changeset
    {:pending, :rejected} -> changeset
    {:pending, :revision_requested} -> changeset
    {:revision_requested, :pending} -> changeset
    {from, to} -> add_error(changeset, :status, "cannot transition from #{from} to #{to}")
  end
end
```

---

## Test Patterns

### Context Tests

```elixir
defmodule MarketMind.ProductsTest do
  use MarketMind.DataCase, async: true

  describe "create_project/2" do
    test "with valid data creates project" do
      user = insert(:user)
      attrs = params_for(:project)

      assert {:ok, project} = Products.create_project(user, attrs)
      assert project.user_id == user.id
    end

    test "with invalid data returns error" do
      user = insert(:user)
      
      assert {:error, changeset} = Products.create_project(user, %{})
      assert "can't be blank" in errors_on(changeset).name
    end
  end
end
```

### LiveView Tests

```elixir
defmodule MarketMindWeb.ProjectLive.IndexTest do
  use MarketMindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "lists projects", %{conn: conn, user: user} do
    project = insert(:project, user: user)

    {:ok, view, html} = live(conn, ~p"/projects")

    assert html =~ project.name
  end

  test "creates new project", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects")

    view
    |> element("a", "New Project")
    |> render_click()

    assert_patch(view, ~p"/projects/new")

    view
    |> form("#project-form", project: %{name: "Test", url: "https://test.com"})
    |> render_submit()

    assert_redirect(view, ~p"/projects/" <> _)
  end
end
```

---

## Component Patterns

### Function Component

```elixir
attr :status, :atom, required: true
attr :class, :string, default: ""

def status_badge(assigns) do
  ~H"""
  <span class={["px-2 py-1 text-xs rounded-full", status_class(@status), @class]}>
    <%= humanize(@status) %>
  </span>
  """
end

defp status_class(:pending), do: "bg-gray-100 text-gray-800"
defp status_class(:approved), do: "bg-green-100 text-green-800"
defp status_class(:rejected), do: "bg-red-100 text-red-800"
```

### With Slots

```elixir
attr :title, :string, required: true
slot :actions
slot :inner_block, required: true

def page_header(assigns) do
  ~H"""
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-2xl font-bold text-gray-900"><%= @title %></h1>
    <div :if={@actions != []} class="flex gap-3">
      <%= render_slot(@actions) %>
    </div>
  </div>
  <%= render_slot(@inner_block) %>
  """
end
```

---

## File Locations

```
lib/
├── market_mind/
│   ├── accounts/           # Auth context
│   │   ├── user.ex
│   │   └── user_token.ex
│   ├── products/           # Projects context
│   │   └── project.ex
│   ├── personas/           # Personas context
│   │   └── persona.ex
│   ├── content/            # Content context
│   │   └── content_piece.ex
│   ├── skills/             # Skills context
│   │   ├── skill.ex
│   │   ├── registry.ex
│   │   └── executor.ex
│   ├── agents/             # Agents context
│   │   ├── agent.ex
│   │   ├── task.ex
│   │   ├── worker.ex
│   │   └── pool.ex
│   ├── llm/                # LLM abstraction
│   │   ├── client.ex
│   │   ├── gemini.ex
│   │   └── claude.ex
│   └── workers/            # Oban workers
│       └── analyze_product.ex
│
├── market_mind_web/
│   ├── components/
│   │   ├── core_components.ex
│   │   └── layouts/
│   ├── live/
│   │   ├── project_live/
│   │   ├── persona_live/
│   │   └── dashboard_live.ex
│   └── router.ex
│
test/
├── market_mind/            # Context tests
├── market_mind_web/        # Web tests
└── support/
    ├── factory.ex          # ExMachina
    ├── data_case.ex
    └── conn_case.ex
```

---

## Common Imports

```elixir
# In contexts
import Ecto.Query
alias MarketMind.Repo

# In LiveView
use MarketMindWeb, :live_view
alias MarketMind.{Products, Personas, Content}

# In tests
use MarketMind.DataCase, async: true
import MarketMind.Factory
```
