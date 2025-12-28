# Database Schema - MarketMind

> Complete schema definition for all database tables.

## Overview

MarketMind uses PostgreSQL with JSONB for flexible data storage. Tables are organized by bounded context.

---

## Migration Files to Create

### 001 - Users (Accounts Context)

```elixir
# priv/repo/migrations/001_create_users.exs
defmodule MarketMind.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :citext, null: false
      add :name, :string
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      
      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
```

```elixir
# priv/repo/migrations/002_create_users_tokens.exs
defmodule MarketMind.Repo.Migrations.CreateUsersTokens do
  use Ecto.Migration

  def change do
    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
```

---

### 002 - Projects (Products Context)

```elixir
# priv/repo/migrations/003_create_projects.exs
defmodule MarketMind.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :url, :string, null: false
      add :description, :text
      
      # Flexible JSONB fields
      add :value_propositions, {:array, :string}, default: []
      add :features, :jsonb, default: "[]"
      add :analysis_data, :jsonb, default: "{}"
      add :brand_voice, :jsonb, default: "{}"
      add :brand_colors, :jsonb, default: "{}"
      add :target_industries, {:array, :string}, default: []
      add :pricing_model, :string
      
      # Status
      add :analysis_status, :string, default: "pending"
      add :is_active, :boolean, default: true
      
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      timestamps()
    end

    create unique_index(:projects, [:slug, :user_id])
    create index(:projects, [:user_id])
    create index(:projects, [:is_active])
  end
end
```

---

### 003 - Personas (Personas Context)

```elixir
# priv/repo/migrations/004_create_personas.exs
defmodule MarketMind.Repo.Migrations.CreatePersonas do
  use Ecto.Migration

  def change do
    create table(:personas) do
      add :name, :string, null: false
      add :role, :string
      add :description, :text
      
      # Core persona data (JSONB for flexibility)
      add :demographics, :jsonb, default: "{}"
      add :goals, {:array, :string}, default: []
      add :pain_points, {:array, :string}, default: []
      add :objections, {:array, :string}, default: []
      add :motivations, {:array, :string}, default: []
      add :channels, {:array, :string}, default: []
      add :keywords, {:array, :string}, default: []
      
      # For persona simulation
      add :personality_traits, :jsonb, default: "{}"
      add :decision_factors, :jsonb, default: "{}"
      add :communication_style, :string
      
      # Flags
      add :is_primary, :boolean, default: false
      add :is_active, :boolean, default: true
      
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      
      timestamps()
    end

    create index(:personas, [:project_id])
    create index(:personas, [:is_primary])
  end
end
```

---

### 004 - Skills (Skills Context)

```elixir
# priv/repo/migrations/005_create_skills.exs
defmodule MarketMind.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    # Skill categories enum
    execute(
      "CREATE TYPE skill_category AS ENUM ('content', 'analysis', 'outreach', 'optimization', 'meta')",
      "DROP TYPE skill_category"
    )
    
    # LLM providers enum
    execute(
      "CREATE TYPE llm_provider AS ENUM ('gemini', 'claude', 'openai')",
      "DROP TYPE llm_provider"
    )

    create table(:skills) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :version, :string, default: "1.0.0"
      add :category, :skill_category, null: false
      
      # Prompt configuration
      add :prompt_template, :text, null: false
      add :system_prompt, :text
      
      # Schema definitions
      add :input_schema, :jsonb, default: "{}"
      add :output_schema, :jsonb, default: "{}"
      add :required_context, {:array, :string}, default: []
      
      # Tool/function calling
      add :tools, :jsonb, default: "[]"
      
      # LLM configuration
      add :llm_provider, :llm_provider, default: "gemini"
      add :llm_model, :string, default: "gemini-1.5-flash"
      add :llm_config, :jsonb, default: "{}"
      
      # Usage tracking
      add :usage_count, :integer, default: 0
      add :success_count, :integer, default: 0
      add :avg_quality_score, :float
      add :avg_execution_time_ms, :integer
      
      # Flags
      add :is_active, :boolean, default: true
      add :is_beta, :boolean, default: false
      add :is_system, :boolean, default: true  # vs user-created
      
      timestamps()
    end

    create unique_index(:skills, [:slug])
    create index(:skills, [:category])
    create index(:skills, [:is_active])
    create index(:skills, [:llm_provider])
  end
end
```

```elixir
# priv/repo/migrations/006_create_skill_versions.exs
defmodule MarketMind.Repo.Migrations.CreateSkillVersions do
  use Ecto.Migration

  def change do
    create table(:skill_versions) do
      add :version, :string, null: false
      add :prompt_template, :text, null: false
      add :system_prompt, :text
      add :changelog, :text
      
      # A/B testing
      add :traffic_percentage, :integer, default: 0
      
      # Performance
      add :usage_count, :integer, default: 0
      add :success_count, :integer, default: 0
      add :avg_quality_score, :float
      
      add :skill_id, references(:skills, on_delete: :delete_all), null: false
      
      timestamps()
    end

    create index(:skill_versions, [:skill_id])
    create unique_index(:skill_versions, [:skill_id, :version])
  end
end
```

---

### 005 - Agents (Agents Context)

```elixir
# priv/repo/migrations/007_create_agents.exs
defmodule MarketMind.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    # Agent status enum
    execute(
      "CREATE TYPE agent_status AS ENUM ('available', 'working', 'paused', 'error')",
      "DROP TYPE agent_status"
    )

    create table(:agents) do
      add :name, :string, null: false
      add :status, :agent_status, default: "available"
      
      # Current assignment
      add :current_project_id, references(:projects, on_delete: :nilify_all)
      add :current_task_id, :integer  # Will reference tasks table
      add :equipped_skill_ids, {:array, :integer}, default: []
      
      # Performance metrics
      add :tasks_completed, :integer, default: 0
      add :avg_task_duration_ms, :integer
      add :error_count, :integer, default: 0
      add :success_rate, :float
      
      # Runtime info (for debugging)
      add :pid, :string  # Erlang PID as string
      add :started_at, :utc_datetime
      add :last_heartbeat, :utc_datetime
      
      timestamps()
    end

    create index(:agents, [:status])
    create index(:agents, [:current_project_id])
  end
end
```

---

### 006 - Tasks

```elixir
# priv/repo/migrations/008_create_tasks.exs
defmodule MarketMind.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    # Task status enum
    execute(
      "CREATE TYPE task_status AS ENUM ('pending', 'queued', 'running', 'completed', 'failed', 'cancelled')",
      "DROP TYPE task_status"
    )
    
    # Approval status enum
    execute(
      "CREATE TYPE approval_status AS ENUM ('not_required', 'pending', 'approved', 'rejected', 'revision_requested')",
      "DROP TYPE approval_status"
    )

    create table(:tasks) do
      add :task_type, :string, null: false
      add :status, :task_status, default: "pending"
      add :priority, :integer, default: 5  # 1-10, higher = more urgent
      
      # Input/Output
      add :input_data, :jsonb, default: "{}"
      add :output_data, :jsonb
      add :error_message, :text
      
      # Scheduling
      add :scheduled_for, :utc_datetime
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :duration_ms, :integer
      
      # Cost tracking
      add :tokens_used, :integer
      add :llm_cost_estimate, :decimal, precision: 10, scale: 6
      
      # Approval workflow
      add :requires_approval, :boolean, default: false
      add :approval_status, :approval_status, default: "not_required"
      add :approval_feedback, :text
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, on_delete: :nilify_all)
      
      # Relationships
      add :skill_id, references(:skills, on_delete: :nilify_all)
      add :project_id, references(:projects, on_delete: :cascade), null: false
      add :persona_id, references(:personas, on_delete: :nilify_all)
      add :assigned_agent_id, references(:agents, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:tasks, [:status])
    create index(:tasks, [:project_id])
    create index(:tasks, [:skill_id])
    create index(:tasks, [:scheduled_for])
    create index(:tasks, [:approval_status])
    create index(:tasks, [:priority, :scheduled_for])
  end
end
```

---

### 007 - Skill Executions (Analytics)

```elixir
# priv/repo/migrations/009_create_skill_executions.exs
defmodule MarketMind.Repo.Migrations.CreateSkillExecutions do
  use Ecto.Migration

  def change do
    create table(:skill_executions) do
      add :skill_version, :string
      
      # Input/Output snapshot
      add :input_data, :jsonb
      add :output_data, :jsonb
      
      # LLM details
      add :llm_provider, :string
      add :llm_model, :string
      add :prompt_tokens, :integer
      add :completion_tokens, :integer
      add :total_tokens, :integer
      add :cost_estimate, :decimal, precision: 10, scale: 6
      
      # Performance
      add :duration_ms, :integer
      add :status, :string  # success, error, timeout
      add :error_message, :text
      
      # Quality
      add :quality_score, :float
      add :feedback, :text
      add :feedback_by_id, references(:users, on_delete: :nilify_all)
      
      # Relationships
      add :skill_id, references(:skills, on_delete: :nilify_all)
      add :agent_id, references(:agents, on_delete: :nilify_all)
      add :task_id, references(:tasks, on_delete: :cascade)
      add :project_id, references(:projects, on_delete: :cascade)
      
      timestamps()
    end

    create index(:skill_executions, [:skill_id])
    create index(:skill_executions, [:project_id])
    create index(:skill_executions, [:status])
    create index(:skill_executions, [:inserted_at])
  end
end
```

---

### 008 - Content Pieces (Content Context)

```elixir
# priv/repo/migrations/010_create_content_pieces.exs
defmodule MarketMind.Repo.Migrations.CreateContentPieces do
  use Ecto.Migration

  def change do
    # Content type enum
    execute(
      "CREATE TYPE content_type AS ENUM ('blog', 'email', 'social_twitter', 'social_linkedin', 'social_reddit', 'ad_copy', 'landing_page', 'newsletter', 'other')",
      "DROP TYPE content_type"
    )
    
    # Content status enum
    execute(
      "CREATE TYPE content_status AS ENUM ('draft', 'pending_approval', 'approved', 'rejected', 'revision_requested', 'published', 'archived')",
      "DROP TYPE content_status"
    )

    create table(:content_pieces) do
      add :title, :string, null: false
      add :slug, :string
      add :content_type, :content_type, null: false
      add :status, :content_status, default: "draft"
      
      # Content body
      add :body, :text
      add :body_html, :text  # Rendered version
      add :summary, :text
      
      # SEO fields
      add :meta_title, :string
      add :meta_description, :string
      add :primary_keyword, :string
      add :secondary_keywords, {:array, :string}, default: []
      
      # Metadata
      add :word_count, :integer
      add :estimated_read_time, :integer  # minutes
      add :faq, :jsonb, default: "[]"
      
      # Publishing
      add :published_at, :utc_datetime
      add :published_url, :string
      
      # Approval
      add :approval_feedback, :text
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, on_delete: :nilify_all)
      
      # Version tracking
      add :version, :integer, default: 1
      add :parent_id, references(:content_pieces, on_delete: :nilify_all)
      
      # Relationships
      add :project_id, references(:projects, on_delete: :cascade), null: false
      add :persona_id, references(:personas, on_delete: :nilify_all)
      add :task_id, references(:tasks, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:content_pieces, [:project_id])
    create index(:content_pieces, [:content_type])
    create index(:content_pieces, [:status])
    create index(:content_pieces, [:persona_id])
    create index(:content_pieces, [:published_at])
    create unique_index(:content_pieces, [:project_id, :slug], where: "slug IS NOT NULL")
  end
end
```

---

### 009 - Email Campaigns (Campaigns Context)

```elixir
# priv/repo/migrations/011_create_email_sequences.exs
defmodule MarketMind.Repo.Migrations.CreateEmailSequences do
  use Ecto.Migration

  def change do
    # Sequence type enum
    execute(
      "CREATE TYPE sequence_type AS ENUM ('welcome', 'nurture', 'onboarding', 'winback', 'promotional', 'custom')",
      "DROP TYPE sequence_type"
    )

    create table(:email_sequences) do
      add :name, :string, null: false
      add :description, :text
      add :sequence_type, :sequence_type, null: false
      
      # Targeting
      add :target_personas, {:array, :integer}, default: []
      
      # Status
      add :is_active, :boolean, default: false
      add :is_draft, :boolean, default: true
      
      # Stats
      add :total_subscribers, :integer, default: 0
      add :total_sent, :integer, default: 0
      add :total_opened, :integer, default: 0
      add :total_clicked, :integer, default: 0
      
      add :project_id, references(:projects, on_delete: :cascade), null: false
      
      timestamps()
    end

    create index(:email_sequences, [:project_id])
    create index(:email_sequences, [:sequence_type])
    create index(:email_sequences, [:is_active])
  end
end
```

```elixir
# priv/repo/migrations/012_create_sequence_steps.exs
defmodule MarketMind.Repo.Migrations.CreateSequenceSteps do
  use Ecto.Migration

  def change do
    create table(:sequence_steps) do
      add :position, :integer, null: false
      add :name, :string
      
      # Timing
      add :delay_days, :integer, default: 0
      add :delay_hours, :integer, default: 0
      add :send_time, :time  # Preferred send time
      
      # Content
      add :subject, :string, null: false
      add :preview_text, :string
      add :body_html, :text, null: false
      add :body_text, :text
      
      # A/B testing (optional)
      add :subject_variants, {:array, :string}, default: []
      
      # Stats
      add :sent_count, :integer, default: 0
      add :open_count, :integer, default: 0
      add :click_count, :integer, default: 0
      
      add :sequence_id, references(:email_sequences, on_delete: :cascade), null: false
      add :content_piece_id, references(:content_pieces, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:sequence_steps, [:sequence_id])
    create unique_index(:sequence_steps, [:sequence_id, :position])
  end
end
```

---

### 010 - Leads (Leads Context)

```elixir
# priv/repo/migrations/013_create_leads.exs
defmodule MarketMind.Repo.Migrations.CreateLeads do
  use Ecto.Migration

  def change do
    # Lead status enum
    execute(
      "CREATE TYPE lead_status AS ENUM ('new', 'nurturing', 'qualified', 'converted', 'lost', 'unsubscribed')",
      "DROP TYPE lead_status"
    )

    create table(:leads) do
      add :email, :citext, null: false
      add :name, :string
      add :company, :string
      add :status, :lead_status, default: "new"
      
      # Scoring
      add :score, :integer, default: 0
      add :score_factors, :jsonb, default: "[]"
      
      # Source tracking
      add :source, :string  # form, import, api
      add :source_details, :jsonb, default: "{}"
      add :utm_params, :jsonb, default: "{}"
      
      # Custom fields
      add :custom_fields, :jsonb, default: "{}"
      
      # Email preferences
      add :email_verified, :boolean, default: false
      add :unsubscribed_at, :utc_datetime
      
      # Relationships
      add :project_id, references(:projects, on_delete: :cascade), null: false
      add :matched_persona_id, references(:personas, on_delete: :nilify_all)
      add :current_sequence_id, references(:email_sequences, on_delete: :nilify_all)
      
      timestamps()
    end

    create unique_index(:leads, [:project_id, :email])
    create index(:leads, [:status])
    create index(:leads, [:score])
    create index(:leads, [:matched_persona_id])
  end
end
```

---

### 011 - Competitors (Analytics Context)

```elixir
# priv/repo/migrations/014_create_competitors.exs
defmodule MarketMind.Repo.Migrations.CreateCompetitors do
  use Ecto.Migration

  def change do
    create table(:competitors) do
      add :name, :string, null: false
      add :url, :string, null: false
      add :description, :text
      
      # Tracking status
      add :is_tracked, :boolean, default: true
      add :last_checked_at, :utc_datetime
      add :check_frequency_hours, :integer, default: 24
      
      # Cached data
      add :pricing_data, :jsonb, default: "{}"
      add :features, :jsonb, default: "[]"
      add :recent_changes, :jsonb, default: "[]"
      
      add :project_id, references(:projects, on_delete: :cascade), null: false
      
      timestamps()
    end

    create index(:competitors, [:project_id])
    create index(:competitors, [:is_tracked])
    create unique_index(:competitors, [:project_id, :url])
  end
end
```

---

## Full Schema Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    users    │────<│   projects  │────<│   personas  │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                    │
                           │                    │
                    ┌──────┴──────┐      ┌──────┴──────┐
                    ▼             ▼      ▼             ▼
              ┌─────────┐  ┌───────────┐  ┌─────────────┐
              │  tasks  │  │ content_  │  │   leads     │
              └─────────┘  │  pieces   │  └─────────────┘
                    │      └───────────┘         │
                    │             │              │
              ┌─────┴─────┐       │        ┌─────┴─────┐
              ▼           ▼       │        ▼           ▼
        ┌─────────┐ ┌─────────┐   │  ┌───────────┐ ┌─────────┐
        │ agents  │ │ skills  │   │  │  email_   │ │sequence_│
        └─────────┘ └─────────┘   │  │ sequences │ │  steps  │
              │           │       │  └───────────┘ └─────────┘
              │           │       │
              └─────┬─────┘       │
                    ▼             │
              ┌───────────────┐   │
              │    skill_     │───┘
              │  executions   │
              └───────────────┘

┌─────────────────┐
│   competitors   │──── (standalone per project)
└─────────────────┘
```

---

## Indexes Summary

- All foreign keys are indexed
- Status/enum fields are indexed for filtering
- Composite indexes for common query patterns
- Unique constraints where applicable
- GIN indexes can be added for JSONB fields if needed

---

## Notes

1. All timestamps use `timestamps()` which creates `inserted_at` and `updated_at`
2. Use `citext` extension for case-insensitive email matching
3. JSONB fields default to `"{}"` or `"[]"` (strings, not Elixir maps)
4. Soft deletes via `is_active` flags where applicable
5. Use `nilify_all` for optional references to preserve data
