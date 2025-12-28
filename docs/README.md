# Architecture Decision Records

> This directory contains Architecture Decision Records (ADRs) for MarketMind.

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](001-elixir-phoenix-stack.md) | Use Elixir/Phoenix Stack | Accepted | 2024-12-27 |
| [002](002-genserver-agents.md) | GenServer for Agent Workers | Accepted | 2024-12-27 |
| [003](003-skill-based-architecture.md) | Skill-Based Agent Architecture | Accepted | 2024-12-27 |
| [004](004-gemini-primary-llm.md) | Gemini Flash as Primary LLM | Accepted | 2024-12-27 |
| [005](005-jsonb-flexible-fields.md) | JSONB for Flexible Schema | Accepted | 2024-12-27 |
| [006](006-oban-background-jobs.md) | Oban for Background Jobs | Accepted | 2024-12-27 |

---

## ADR-001: Use Elixir/Phoenix Stack

### Status
Accepted

### Context
We need to choose a backend technology stack for MarketMind. Key requirements:
- Real-time updates for dashboard and agent status
- Concurrent execution of multiple AI agents
- Cost-effective hosting
- Developer productivity

### Decision
Use Elixir 1.16+ with Phoenix 1.7+ and LiveView.

### Consequences
**Positive:**
- Native concurrency via BEAM VM - perfect for agent orchestration
- LiveView eliminates need for separate frontend framework
- Phoenix PubSub for real-time agent status updates
- Excellent fault tolerance with supervision trees
- Low memory footprint = cheaper hosting

**Negative:**
- Smaller talent pool than Node.js/Python
- Learning curve for OTP patterns
- Fewer AI/ML libraries (mitigated by HTTP APIs to LLMs)

**Mitigations:**
- Comprehensive CLAUDE.md for AI-assisted development
- Use Req for HTTP, avoid complex NIFs

---

## ADR-002: GenServer for Agent Workers

### Status
Accepted

### Context
Agents need to maintain state (current project, equipped skills) and execute tasks. Options:
1. GenServer - Simple stateful processes
2. GenStage - Backpressure-aware pipelines
3. Broadway - High-throughput data pipelines

### Decision
Use GenServer for agent workers with a DynamicSupervisor pool.

### Consequences
**Positive:**
- Simple mental model: one process per agent
- Easy state management (current_project, equipped_skills)
- Built-in message passing
- Can upgrade to GenStage later if needed

**Negative:**
- No built-in backpressure (use Oban for queue management)
- Must handle process crashes manually (Supervisor handles restart)

### Implementation
```elixir
defmodule MarketMind.Agents.Worker do
  use GenServer
  
  defstruct [:id, :name, :status, :current_project, :equipped_skills]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end
  
  def assign_project(agent_id, project) do
    GenServer.call(via_tuple(agent_id), {:assign_project, project})
  end
  
  def execute_skill(agent_id, skill, input) do
    GenServer.call(via_tuple(agent_id), {:execute_skill, skill, input}, 60_000)
  end
end
```

---

## ADR-003: Skill-Based Agent Architecture

### Status
Accepted

### Context
How should agents know what to do? Options:
1. Hard-coded agent types (ContentAgent, AnalysisAgent)
2. Skill-based system where agents can equip any skill
3. Plugin architecture with external skill packages

### Decision
Implement skills as database records that agents can dynamically equip.

### Consequences
**Positive:**
- Skills can be added/updated without code deployment
- A/B testing of skill versions
- Usage analytics per skill
- Users can create custom skills (future)
- Single agent type simplifies codebase

**Negative:**
- More complex than hard-coded agents
- Must validate skill schemas at runtime
- Database dependency for skill loading (mitigated by caching)

### Skill Schema
```elixir
%Skill{
  name: "seo_blog_writer",
  category: :content,
  prompt_template: "...",
  input_schema: %{...},
  output_schema: %{...},
  llm_provider: :gemini,
  llm_model: "gemini-1.5-flash"
}
```

---

## ADR-004: Gemini Flash as Primary LLM

### Status
Accepted

### Context
Need to choose LLM provider(s) for AI tasks. Cost is critical for indie pricing.

| Provider | Model | Input Cost | Output Cost |
|----------|-------|------------|-------------|
| Google | Gemini 1.5 Flash | $0.075/1M | $0.30/1M |
| OpenAI | GPT-4o-mini | $0.15/1M | $0.60/1M |
| Anthropic | Claude 3.5 Haiku | $0.25/1M | $1.25/1M |
| Anthropic | Claude 3.5 Sonnet | $3.00/1M | $15.00/1M |

### Decision
- **Primary:** Gemini 1.5 Flash for most tasks
- **Complex reasoning:** Claude 3.5 Sonnet for tool use, competitor analysis
- **Abstraction layer:** LLM behaviour module for easy switching

### Consequences
**Positive:**
- 2-4x cost savings vs alternatives
- Gemini handles most marketing content well
- Claude for complex multi-step reasoning
- Can route dynamically based on task complexity

**Negative:**
- Two API integrations to maintain
- Gemini has different prompt patterns than Claude
- Must handle rate limits for both

### Implementation
```elixir
defmodule MarketMind.LLM do
  @callback complete(model :: String.t(), prompt :: String.t(), opts :: map()) ::
    {:ok, String.t()} | {:error, term()}
end

defmodule MarketMind.LLM.Router do
  def route(%Skill{llm_provider: :gemini}), do: MarketMind.LLM.Gemini
  def route(%Skill{llm_provider: :claude}), do: MarketMind.LLM.Claude
end
```

---

## ADR-005: JSONB for Flexible Schema

### Status
Accepted

### Context
AI outputs are semi-structured and evolve over time. Options:
1. Strict relational columns
2. JSONB columns for flexible data
3. Document database (MongoDB)

### Decision
Use PostgreSQL JSONB columns for AI-generated and frequently-changing fields.

### Consequences
**Positive:**
- Schema flexibility without migrations
- Can query/index JSONB fields
- Stay on PostgreSQL (no additional database)
- Perfect for: persona demographics, analysis results, skill configs

**Negative:**
- No compile-time schema validation
- Must validate at application layer
- Harder to enforce data consistency

### Usage Pattern
```elixir
# Schema
schema "personas" do
  field :name, :string              # Always present, structured
  field :demographics, :map         # JSONB - flexible structure
  field :goals, {:array, :string}   # JSONB array
end

# Changeset validation
def changeset(persona, attrs) do
  persona
  |> cast(attrs, [:name, :demographics, :goals])
  |> validate_required([:name])
  |> validate_demographics()  # Custom validation
end

defp validate_demographics(changeset) do
  validate_change(changeset, :demographics, fn _, demographics ->
    case validate_demographics_schema(demographics) do
      :ok -> []
      {:error, msg} -> [demographics: msg]
    end
  end)
end
```

---

## ADR-006: Oban for Background Jobs

### Status
Accepted

### Context
Need reliable background job processing for:
- LLM API calls (slow, may timeout)
- Website scraping
- Email sending
- Scheduled content generation

Options: Oban, Exq, custom GenServer queue

### Decision
Use Oban with PostgreSQL backend.

### Consequences
**Positive:**
- PostgreSQL-backed (no Redis dependency)
- Built-in retry, uniqueness, scheduling
- Web UI available (Oban Web)
- Cron-like scheduling for recurring tasks
- Telemetry integration

**Negative:**
- Adds database load (polling)
- Learning curve for Oban patterns

### Queue Configuration
```elixir
# config/config.exs
config :market_mind, Oban,
  repo: MarketMind.Repo,
  queues: [
    default: 10,
    analysis: 5,      # Website scraping, product analysis
    content: 10,      # Content generation
    email: 20,        # Email sending (high throughput)
    scheduled: 5      # Cron jobs
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},  # 7 days
    {Oban.Plugins.Cron, crontab: [
      {"0 * * * *", MarketMind.Workers.CompetitorCheck},  # Hourly
      {"0 0 * * *", MarketMind.Workers.DailyDigest}       # Daily
    ]}
  ]
```

### Worker Pattern
```elixir
defmodule MarketMind.Workers.GenerateContent do
  use Oban.Worker,
    queue: :content,
    max_attempts: 3,
    priority: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    task = Tasks.get_task!(task_id)
    
    with {:ok, content} <- generate(task),
         {:ok, _} <- save_content(task, content) do
      :ok
    else
      {:error, :rate_limited} ->
        {:snooze, 60}  # Retry in 60 seconds
      {:error, reason} ->
        {:error, reason}  # Will retry based on max_attempts
    end
  end
end
```

---

## Template for New ADRs

```markdown
## ADR-XXX: [Title]

### Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

### Context
[What is the issue that we're seeing that is motivating this decision?]

### Decision
[What is the change that we're proposing?]

### Consequences
**Positive:**
- [Benefit 1]
- [Benefit 2]

**Negative:**
- [Drawback 1]
- [Drawback 2]

**Mitigations:**
- [How we address the negatives]
```
