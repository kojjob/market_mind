# CLAUDE.md - MarketMind Project Context

> This file provides context for Claude Code to work effectively on the MarketMind project.

## Project Overview

**MarketMind** is an AI-powered marketing automation platform for indie makers and solo founders. It provides an autonomous AI marketing team at SMB-friendly prices ($29-99/mo).

**Tech Stack:**
- **Backend:** Elixir 1.16+ / Phoenix 1.7+ / LiveView
- **Database:** PostgreSQL 16 with JSONB
- **Background Jobs:** Oban
- **Primary LLM:** Google Gemini Flash (cost optimization)
- **Complex Tasks:** Claude (tool use)
- **CSS:** TailwindCSS (no custom CSS unless necessary)
- **Deployment:** Fly.io

## Project Structure

```
marketmind/
├── lib/
│   ├── market_mind/              # Business logic (contexts)
│   │   ├── accounts/             # User authentication
│   │   ├── products/             # Product/Project management
│   │   ├── personas/             # Persona management
│   │   ├── content/              # Content generation
│   │   ├── campaigns/            # Email campaigns
│   │   ├── leads/                # Lead management
│   │   ├── analytics/            # Analytics & insights
│   │   ├── agents/               # Agent orchestration
│   │   │   ├── worker.ex         # GenServer worker
│   │   │   ├── pool.ex           # Worker pool supervisor
│   │   │   └── orchestrator.ex   # Task routing
│   │   ├── skills/               # Skill system
│   │   │   ├── skill.ex          # Skill schema
│   │   │   ├── registry.ex       # Skill loading/caching
│   │   │   └── executor.ex       # Skill execution
│   │   └── llm/                  # LLM abstraction
│   │       ├── client.ex         # Behaviour definition
│   │       ├── gemini.ex         # Gemini implementation
│   │       └── claude.ex         # Claude implementation
│   └── market_mind_web/          # Web layer
│       ├── live/                 # LiveView modules
│       ├── components/           # Reusable components
│       └── layouts/              # App layouts
├── test/
│   ├── market_mind/              # Context tests
│   ├── market_mind_web/          # Web tests
│   └── support/                  # Test helpers
├── priv/
│   └── repo/
│       ├── migrations/           # Database migrations
│       └── seeds/                # Seed data
├── config/                       # Environment configs
├── docs/                         # Documentation
│   ├── PRD.md                    # Product requirements
│   ├── TODO.md                   # Implementation roadmap
│   └── adrs/                     # Architecture decisions
└── .claude/                      # Claude Code config
```

## Coding Standards

### Elixir Style

```elixir
# Use pattern matching in function heads
def process(%User{role: :admin} = user), do: admin_flow(user)
def process(%User{} = user), do: standard_flow(user)

# Pipe operator for transformations (3+ operations)
data
|> transform_a()
|> transform_b()
|> transform_c()

# With statements for complex validations
with {:ok, user} <- fetch_user(id),
     {:ok, project} <- authorize(user, project_id),
     {:ok, result} <- execute(project) do
  {:ok, result}
end

# Always use @doc and @spec for public functions
@doc """
Creates a new project for the given user.

## Examples

    iex> create_project(user, %{name: "My App", url: "https://myapp.com"})
    {:ok, %Project{}}

"""
@spec create_project(User.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
def create_project(%User{} = user, attrs) do
  # implementation
end
```

### Phoenix/LiveView Patterns

```elixir
# LiveView: Handle events with pattern matching
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

# Use assign_new for expensive operations
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign_new(:projects, fn -> Products.list_projects(socket.assigns.current_user) end)}
end

# Components: Use function components with slots
attr :title, :string, required: true
attr :class, :string, default: ""
slot :inner_block, required: true
slot :actions

def card(assigns) do
  ~H"""
  <div class={["bg-white rounded-lg shadow p-6", @class]}>
    <h3 class="text-lg font-semibold"><%= @title %></h3>
    <div class="mt-4">
      <%= render_slot(@inner_block) %>
    </div>
    <%= if @actions do %>
      <div class="mt-6 flex justify-end gap-3">
        <%= render_slot(@actions) %>
      </div>
    <% end %>
  </div>
  """
end
```

### TailwindCSS Usage

```html
<!-- DO: Use Tailwind utilities -->
<div class="flex items-center justify-between p-4 bg-white rounded-lg shadow">
  <h2 class="text-lg font-semibold text-gray-900">Title</h2>
  <button class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700">
    Action
  </button>
</div>

<!-- DON'T: Mix custom CSS with Tailwind -->
<div class="custom-card flex items-center">  <!-- Avoid this -->
```

### Test-Driven Development

```elixir
# Always write tests FIRST
# test/market_mind/products_test.exs
defmodule MarketMind.ProductsTest do
  use MarketMind.DataCase

  alias MarketMind.Products
  alias MarketMind.Products.Project

  describe "create_project/2" do
    setup do
      user = insert(:user)
      {:ok, user: user}
    end

    test "creates project with valid data", %{user: user} do
      attrs = %{name: "Test App", url: "https://testapp.com"}
      
      assert {:ok, %Project{} = project} = Products.create_project(user, attrs)
      assert project.name == "Test App"
      assert project.user_id == user.id
    end

    test "returns error with invalid url", %{user: user} do
      attrs = %{name: "Test App", url: "not-a-url"}
      
      assert {:error, changeset} = Products.create_project(user, attrs)
      assert "is not a valid URL" in errors_on(changeset).url
    end
  end
end
```

## Key Patterns

### Context Module Pattern

Each bounded context follows this structure:

```elixir
defmodule MarketMind.Products do
  @moduledoc """
  The Products context handles project management and product analysis.
  """
  
  import Ecto.Query
  alias MarketMind.Repo
  alias MarketMind.Products.Project

  # List operations
  def list_projects(user), do: ...
  
  # Get operations (raise on not found)
  def get_project!(id), do: ...
  
  # Get operations (return nil on not found)
  def get_project(id), do: ...
  
  # Create operations
  def create_project(user, attrs), do: ...
  
  # Update operations  
  def update_project(project, attrs), do: ...
  
  # Delete operations
  def delete_project(project), do: ...
  
  # Changeset for forms
  def change_project(project, attrs \\ %{}), do: ...
end
```

### Schema Pattern

```elixir
defmodule MarketMind.Products.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "projects" do
    field :name, :string
    field :slug, :string
    field :url, :string
    field :description, :string
    
    # JSONB fields for flexible data
    field :value_propositions, {:array, :string}, default: []
    field :features, {:array, :map}, default: []
    field :analysis_data, :map, default: %{}
    field :brand_voice, :map, default: %{}
    
    belongs_to :user, MarketMind.Accounts.User
    has_many :personas, MarketMind.Personas.Persona
    has_many :content_pieces, MarketMind.Content.ContentPiece
    
    timestamps()
  end

  @required_fields ~w(name url user_id)a
  @optional_fields ~w(slug description value_propositions features analysis_data brand_voice)a

  def changeset(project, attrs) do
    project
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_url(:url)
    |> generate_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
          []
        _ ->
          [{field, "is not a valid URL"}]
      end
    end)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Slug.slugify(name))
    end
  end
end
```

### Skill Execution Pattern

```elixir
defmodule MarketMind.Skills.Executor do
  @moduledoc """
  Executes skills by building prompts and calling LLMs.
  """
  
  alias MarketMind.Skills.Skill
  alias MarketMind.LLM

  def execute(%Skill{} = skill, context, input) do
    with {:ok, prompt} <- build_prompt(skill, context, input),
         {:ok, response} <- call_llm(skill, prompt),
         {:ok, output} <- parse_output(skill, response) do
      log_execution(skill, input, output)
      {:ok, output}
    end
  end

  defp build_prompt(skill, context, input) do
    prompt = skill.prompt_template
    |> replace_context_placeholders(context)
    |> replace_input_placeholders(input)
    
    {:ok, prompt}
  end

  defp call_llm(skill, prompt) do
    client = get_client(skill.llm_provider)
    client.complete(skill.llm_model, prompt, skill.llm_config)
  end

  defp get_client(:gemini), do: LLM.Gemini
  defp get_client(:claude), do: LLM.Claude
end
```

### Oban Worker Pattern

```elixir
defmodule MarketMind.Workers.AnalyzeProduct do
  use Oban.Worker, 
    queue: :analysis,
    max_attempts: 3,
    priority: 1

  alias MarketMind.Products
  alias MarketMind.Skills

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    project = Products.get_project!(project_id)
    
    with {:ok, html} <- fetch_website(project.url),
         {:ok, content} <- parse_html(html),
         {:ok, analysis} <- Skills.execute("product_analyzer", %{}, content) do
      Products.update_project(project, %{analysis_data: analysis})
    end
  end

  defp fetch_website(url) do
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

## Common Tasks

### Creating a New Context

```bash
# Generate context with schema
mix phx.gen.context Products Project projects \
  name:string slug:string url:string description:text \
  user_id:references:users

# Then add JSONB fields manually in migration
```

### Creating a New LiveView

```bash
# Generate LiveView
mix phx.gen.live Products Project projects \
  name:string url:string --no-context

# Structure:
# lib/market_mind_web/live/project_live/
#   ├── index.ex
#   ├── index.html.heex
#   ├── show.ex
#   ├── show.html.heex
#   ├── form_component.ex
#   └── form_component.html.heex
```

### Adding a New Skill

1. Create migration for skill seed:
```elixir
# priv/repo/seeds/skills/seo_blog_writer.exs
%{
  name: "seo_blog_writer",
  slug: "seo-blog-writer",
  category: :content,
  prompt_template: "...",
  input_schema: %{...},
  output_schema: %{...},
  llm_provider: :gemini,
  llm_model: "gemini-1.5-flash"
}
```

2. Run seeds: `mix run priv/repo/seeds.exs`

### Running Tests

```bash
# All tests
mix test

# Specific file
mix test test/market_mind/products_test.exs

# Specific test
mix test test/market_mind/products_test.exs:42

# With coverage
mix test --cover

# Watch mode (with mix_test_watch)
mix test.watch
```

## Environment Variables

Required in `.env`:

```bash
# Database
DATABASE_URL=postgres://localhost/marketmind_dev

# LLM APIs
GEMINI_API_KEY=your_gemini_key
ANTHROPIC_API_KEY=your_anthropic_key

# Email (SendGrid)
SENDGRID_API_KEY=your_sendgrid_key

# App
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret
PHX_HOST=localhost
```

## Current Sprint

See `docs/TODO.md` for current tasks. Focus on:

1. **Phase 1 MVP** - Core functionality
2. **TDD** - Write tests first
3. **Small commits** - One feature per commit

## Decision Log

Key architectural decisions:

1. **GenServer for agents** (not GenStage) - Simpler, migrate later if needed
2. **JSONB for flexible fields** - Avoid migrations for schema changes
3. **Gemini Flash as primary** - Cost optimization ($0.075/1M tokens)
4. **Skills as database records** - Versioning, A/B testing, no redeploys

## Helpful Commands

```bash
# Start dev server
mix phx.server

# Interactive console
iex -S mix phx.server

# Database
mix ecto.create
mix ecto.migrate
mix ecto.rollback
mix ecto.reset  # drop + create + migrate + seed

# Dependencies
mix deps.get
mix deps.compile

# Format code
mix format

# Credo (linting)
mix credo --strict

# Dialyzer (types)
mix dialyzer
```

## Files to Never Edit Directly

- `_build/` - Compiled artifacts
- `deps/` - Dependencies
- `priv/static/assets/` - Compiled assets (use `assets/`)

## Getting Help

- **Elixir docs:** https://hexdocs.pm/elixir
- **Phoenix docs:** https://hexdocs.pm/phoenix
- **LiveView docs:** https://hexdocs.pm/phoenix_live_view
- **Oban docs:** https://hexdocs.pm/oban
