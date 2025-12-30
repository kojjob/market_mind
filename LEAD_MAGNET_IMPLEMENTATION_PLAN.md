# Lead Magnet System Implementation Plan

**Created:** December 29, 2025
**Status:** Ready for Implementation
**Goal:** FREE Lead Capture + Email Nurture System (No Paid Services)

---

## Overview

Build a complete lead capture and email nurturing system that transforms MarketMind's AI-generated blog content into downloadable lead magnets, captures email subscribers, and nurtures them through automated email sequences.

**Core Flow:**
```
Blog Post → AI Transforms → Lead Magnet (Checklist/Guide) → Landing Page → Email Capture → Nurture Sequence
```

**Key Constraint:** No paid services - uses free tiers only (Mailgun 5k/month, Brevo 300/day, or local SMTP for dev)

---

## Phase 1: Foundation (Swoosh + Subscribers)

### Step 1.1: Add Swoosh Dependency

**File:** `mix.exs`
```elixir
{:swoosh, "~> 1.16"},
{:gen_smtp, "~> 1.0"},  # For local SMTP testing
{:hackney, "~> 1.9"}    # HTTP client for Mailgun/Brevo
```

### Step 1.2: Configure Swoosh

**File:** `config/config.exs`
```elixir
config :market_mind, MarketMind.Mailer,
  adapter: Swoosh.Adapters.Local  # Development default
```

**File:** `config/dev.exs`
```elixir
config :market_mind, MarketMind.Mailer,
  adapter: Swoosh.Adapters.Local

config :swoosh, :api_client, false  # Disable API in dev
```

**File:** `config/prod.exs`
```elixir
# Option A: Mailgun (5,000 emails/month free)
config :market_mind, MarketMind.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: System.get_env("MAILGUN_API_KEY"),
  domain: System.get_env("MAILGUN_DOMAIN")

# Option B: Brevo/Sendinblue (300 emails/day free)
# config :market_mind, MarketMind.Mailer,
#   adapter: Swoosh.Adapters.Sendinblue,
#   api_key: System.get_env("BREVO_API_KEY")
```

### Step 1.3: Create Mailer Module

**File:** `lib/market_mind/mailer.ex`
```elixir
defmodule MarketMind.Mailer do
  use Swoosh.Mailer, otp_app: :market_mind
end
```

### Step 1.4: Create Subscribers Migration

**File:** `priv/repo/migrations/TIMESTAMP_create_subscribers.exs`
```elixir
create table(:subscribers, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :email, :string, null: false
  add :first_name, :string
  add :status, :string, null: false, default: "pending"  # pending, confirmed, unsubscribed
  add :confirmed_at, :utc_datetime
  add :unsubscribed_at, :utc_datetime
  add :source, :string  # "lead_magnet", "blog", "manual"
  add :source_id, :binary_id  # ID of lead_magnet or content
  add :tags, {:array, :string}, default: []
  add :metadata, :map, default: %{}  # Extra data from capture form

  # GDPR Compliance
  add :consent_given_at, :utc_datetime
  add :consent_ip, :string
  add :consent_user_agent, :text

  add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
  timestamps()
end

create unique_index(:subscribers, [:email, :project_id])
create index(:subscribers, [:project_id])
create index(:subscribers, [:status])
```

### Step 1.5: Create Subscriber Schema

**File:** `lib/market_mind/leads/subscriber.ex`
```elixir
defmodule MarketMind.Leads.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscribers" do
    field :email, :string
    field :first_name, :string
    field :status, :string, default: "pending"
    field :confirmed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime
    field :source, :string
    field :source_id, :binary_id
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}
    field :consent_given_at, :utc_datetime
    field :consent_ip, :string
    field :consent_user_agent, :string

    belongs_to :project, MarketMind.Products.Project

    timestamps()
  end

  @valid_statuses ~w(pending confirmed unsubscribed)

  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email, :first_name, :status, :source, :source_id, :tags, :metadata,
                    :consent_given_at, :consent_ip, :consent_user_agent, :project_id])
    |> validate_required([:email, :project_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:email, :project_id])
  end

  def confirm_changeset(subscriber) do
    subscriber
    |> change(status: "confirmed", confirmed_at: DateTime.utc_now())
  end

  def unsubscribe_changeset(subscriber) do
    subscriber
    |> change(status: "unsubscribed", unsubscribed_at: DateTime.utc_now())
  end
end
```

### Step 1.6: Create Leads Context

**File:** `lib/market_mind/leads.ex`
```elixir
defmodule MarketMind.Leads do
  import Ecto.Query
  alias MarketMind.Repo
  alias MarketMind.Leads.Subscriber
  alias MarketMind.Products.Project

  def list_subscribers(%Project{} = project) do
    Subscriber
    |> where([s], s.project_id == ^project.id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def list_confirmed_subscribers(%Project{} = project) do
    Subscriber
    |> where([s], s.project_id == ^project.id and s.status == "confirmed")
    |> Repo.all()
  end

  def get_subscriber!(id), do: Repo.get!(Subscriber, id)

  def get_subscriber_by_email(project, email) do
    Repo.get_by(Subscriber, project_id: project.id, email: String.downcase(email))
  end

  def create_subscriber(%Project{} = project, attrs, consent_info \\ %{}) do
    %Subscriber{}
    |> Subscriber.changeset(Map.merge(attrs, %{
      project_id: project.id,
      email: String.downcase(attrs[:email] || attrs["email"]),
      consent_given_at: DateTime.utc_now(),
      consent_ip: consent_info[:ip],
      consent_user_agent: consent_info[:user_agent]
    }))
    |> Repo.insert()
  end

  def confirm_subscriber(%Subscriber{} = subscriber) do
    subscriber
    |> Subscriber.confirm_changeset()
    |> Repo.update()
  end

  def unsubscribe(%Subscriber{} = subscriber) do
    subscriber
    |> Subscriber.unsubscribe_changeset()
    |> Repo.update()
  end

  def subscriber_count(%Project{} = project, status \\ nil) do
    query = from s in Subscriber, where: s.project_id == ^project.id
    query = if status, do: where(query, [s], s.status == ^status), else: query
    Repo.aggregate(query, :count)
  end
end
```

---

## Phase 2: Lead Magnets

### Step 2.1: Create Lead Magnets Migration

**File:** `priv/repo/migrations/TIMESTAMP_create_lead_magnets.exs`
```elixir
create table(:lead_magnets, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :title, :string, null: false
  add :slug, :string, null: false
  add :description, :text
  add :magnet_type, :string, null: false  # "checklist", "guide", "cheatsheet", "template", "worksheet"
  add :status, :string, null: false, default: "draft"  # draft, active, archived

  # The actual content (markdown)
  add :content, :text

  # Landing page customization
  add :headline, :string
  add :subheadline, :text
  add :cta_text, :string, default: "Get Free Access"
  add :thank_you_message, :text
  add :download_url, :string  # Optional external file URL

  # SEO
  add :meta_description, :string

  # Stats (denormalized for performance)
  add :download_count, :integer, default: 0
  add :conversion_rate, :decimal  # Calculated periodically

  # Relationships
  add :content_id, references(:contents, type: :binary_id, on_delete: :nilify_all)
  add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

  timestamps()
end

create unique_index(:lead_magnets, [:project_id, :slug])
create index(:lead_magnets, [:project_id])
create index(:lead_magnets, [:content_id])
```

### Step 2.2: Create Lead Magnet Schema

**File:** `lib/market_mind/lead_magnets/lead_magnet.ex`
```elixir
defmodule MarketMind.LeadMagnets.LeadMagnet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lead_magnets" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :magnet_type, :string
    field :status, :string, default: "draft"
    field :content, :string
    field :headline, :string
    field :subheadline, :string
    field :cta_text, :string, default: "Get Free Access"
    field :thank_you_message, :string
    field :download_url, :string
    field :meta_description, :string
    field :download_count, :integer, default: 0
    field :conversion_rate, :decimal

    belongs_to :source_content, MarketMind.Content.Content, foreign_key: :content_id
    belongs_to :project, MarketMind.Products.Project
    has_many :subscribers, MarketMind.Leads.Subscriber, foreign_key: :source_id

    timestamps()
  end

  @valid_types ~w(checklist guide cheatsheet template worksheet)
  @valid_statuses ~w(draft active archived)

  def changeset(lead_magnet, attrs) do
    lead_magnet
    |> cast(attrs, [:title, :slug, :description, :magnet_type, :status, :content,
                    :headline, :subheadline, :cta_text, :thank_you_message,
                    :download_url, :meta_description, :content_id, :project_id])
    |> validate_required([:title, :magnet_type, :project_id])
    |> validate_inclusion(:magnet_type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> generate_slug()
    |> unique_constraint([:project_id, :slug])
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title ->
        slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
        put_change(changeset, :slug, slug)
    end
  end
end
```

### Step 2.3: Create LeadMagnetAgent

**File:** `lib/market_mind/agents/lead_magnet_agent.ex`
```elixir
defmodule MarketMind.Agents.LeadMagnetAgent do
  @moduledoc """
  AI agent that transforms blog content into downloadable lead magnets.
  """

  alias MarketMind.LLM.Gemini
  alias MarketMind.Content.Content
  alias MarketMind.Products.Project

  @lead_magnet_schema %{
    title: :string,
    description: :string,
    magnet_type: :string,
    headline: :string,
    subheadline: :string,
    content: :string,
    cta_text: :string,
    thank_you_message: :string
  }

  def generate(%Project{} = project, %Content{} = content, magnet_type \\ "checklist") do
    prompt = build_prompt(project, content, magnet_type)

    case Gemini.complete_json(prompt, @lead_magnet_schema) do
      {:ok, result} when is_map(result) ->
        {:ok, normalize_result(result, content, magnet_type)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_prompt(project, content, magnet_type) do
    """
    You are an expert content marketer creating lead magnets.
    Transform this blog post into a valuable #{magnet_type} that readers will exchange their email for.

    ## Product: #{project.name}
    ## Blog Post Title: #{content.title}
    ## Blog Post Content:
    #{content.body}

    ## Lead Magnet Type: #{magnet_type}
    #{type_instructions(magnet_type)}

    ## Requirements:
    1. **title**: Compelling title for the lead magnet (max 60 chars)
    2. **description**: 2-3 sentence description of what they'll get
    3. **headline**: Landing page headline (benefit-focused, max 80 chars)
    4. **subheadline**: Supporting text (1-2 sentences)
    5. **content**: The actual #{magnet_type} content in markdown format
    6. **cta_text**: Button text (action-oriented, max 25 chars)
    7. **thank_you_message**: Message shown after signup (include next steps)

    Return valid JSON only.
    """
  end

  defp type_instructions("checklist") do
    """
    Create a checklist format with:
    - 10-15 actionable items
    - Checkbox format (use - [ ] in markdown)
    - Grouped into 3-4 sections with headers
    - Each item should be specific and actionable
    """
  end

  defp type_instructions("guide") do
    """
    Create a mini-guide format with:
    - 5-7 key sections
    - Each section: heading + 2-3 paragraphs
    - Include practical examples
    - End with clear action steps
    """
  end

  defp type_instructions("cheatsheet") do
    """
    Create a cheatsheet format with:
    - Quick-reference style
    - Tables or bullet lists for easy scanning
    - Key terms, formulas, or commands
    - Fits on 1-2 pages when printed
    """
  end

  defp type_instructions(_), do: "Create valuable, actionable content."

  defp normalize_result(result, content, magnet_type) do
    %{
      title: result["title"],
      description: result["description"],
      magnet_type: magnet_type,
      headline: result["headline"],
      subheadline: result["subheadline"],
      content: result["content"],
      cta_text: result["cta_text"] || "Get Free Access",
      thank_you_message: result["thank_you_message"],
      content_id: content.id
    }
  end
end
```

### Step 2.4: Add to Agents Context

**File:** `lib/market_mind/agents.ex` (add)
```elixir
alias MarketMind.Agents.LeadMagnetAgent
alias MarketMind.LeadMagnets

def run_lead_magnet_generation(%Project{} = project, %Content{} = content, opts \\ []) do
  magnet_type = opts[:type] || "checklist"

  case LeadMagnetAgent.generate(project, content, magnet_type) do
    {:ok, attrs} ->
      LeadMagnets.create_lead_magnet(project, attrs)

    {:error, reason} = error ->
      require Logger
      Logger.error("Lead magnet generation failed: #{inspect(reason)}")
      error
  end
end
```

---

## Phase 3: Email Sequences

### Step 3.1: Create Email Sequences Migration

**File:** `priv/repo/migrations/TIMESTAMP_create_email_sequences.exs`
```elixir
create table(:email_sequences, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :name, :string, null: false
  add :description, :text
  add :trigger, :string, null: false  # "lead_magnet_download", "manual", "tag_added"
  add :trigger_id, :binary_id  # ID of lead_magnet if trigger is lead_magnet_download
  add :status, :string, default: "draft"  # draft, active, paused

  add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
  timestamps()
end

create table(:sequence_emails, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :subject, :string, null: false
  add :body, :text, null: false  # HTML or markdown
  add :delay_days, :integer, null: false, default: 0  # Days after sequence start
  add :delay_hours, :integer, default: 0
  add :position, :integer, null: false  # Order in sequence
  add :status, :string, default: "active"  # active, paused

  add :sequence_id, references(:email_sequences, type: :binary_id, on_delete: :delete_all), null: false
  timestamps()
end

create table(:email_deliveries, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :status, :string, null: false, default: "pending"  # pending, sent, failed, opened, clicked
  add :sent_at, :utc_datetime
  add :opened_at, :utc_datetime
  add :clicked_at, :utc_datetime
  add :error_message, :text

  add :subscriber_id, references(:subscribers, type: :binary_id, on_delete: :delete_all), null: false
  add :sequence_email_id, references(:sequence_emails, type: :binary_id, on_delete: :delete_all), null: false
  timestamps()
end

create index(:email_sequences, [:project_id])
create index(:sequence_emails, [:sequence_id])
create index(:email_deliveries, [:subscriber_id])
create index(:email_deliveries, [:sequence_email_id])
create index(:email_deliveries, [:status])
create unique_index(:email_deliveries, [:subscriber_id, :sequence_email_id])
```

### Step 3.2: Create EmailDeliveryWorker

**File:** `lib/market_mind/workers/email_delivery_worker.ex`
```elixir
defmodule MarketMind.Workers.EmailDeliveryWorker do
  use Oban.Worker, queue: :emails, max_attempts: 3

  alias MarketMind.Repo
  alias MarketMind.Leads.Subscriber
  alias MarketMind.EmailMarketing.{SequenceEmail, EmailDelivery}
  alias MarketMind.Mailer
  import Swoosh.Email

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
    delivery = Repo.get!(EmailDelivery, delivery_id)
    |> Repo.preload([:subscriber, :sequence_email])

    case send_email(delivery) do
      {:ok, _} ->
        delivery
        |> EmailDelivery.sent_changeset()
        |> Repo.update()
        :ok

      {:error, reason} ->
        delivery
        |> EmailDelivery.failed_changeset(inspect(reason))
        |> Repo.update()
        {:error, reason}
    end
  end

  defp send_email(delivery) do
    email =
      new()
      |> to(delivery.subscriber.email)
      |> from({"MarketMind", "noreply@marketmind.app"})
      |> subject(delivery.sequence_email.subject)
      |> html_body(render_body(delivery))

    Mailer.deliver(email)
  end

  defp render_body(delivery) do
    # Replace variables in email body
    delivery.sequence_email.body
    |> String.replace("{{first_name}}", delivery.subscriber.first_name || "there")
    |> String.replace("{{email}}", delivery.subscriber.email)
  end
end
```

### Step 3.3: Create SequenceSchedulerWorker

**File:** `lib/market_mind/workers/sequence_scheduler_worker.ex`
```elixir
defmodule MarketMind.Workers.SequenceSchedulerWorker do
  @moduledoc """
  Runs periodically to schedule email deliveries for subscribers in active sequences.
  """
  use Oban.Worker, queue: :default

  alias MarketMind.Repo
  alias MarketMind.EmailMarketing

  @impl Oban.Worker
  def perform(_job) do
    EmailMarketing.schedule_pending_emails()
    :ok
  end
end
```

---

## Phase 4: Public Capture Pages

### Step 4.1: Create Public Lead Magnet LiveView

**File:** `lib/market_mind_web/live/public/lead_magnet_live.ex`
```elixir
defmodule MarketMindWeb.Public.LeadMagnetLive do
  use MarketMindWeb, :live_view

  alias MarketMind.LeadMagnets
  alias MarketMind.Leads

  def mount(%{"project_slug" => project_slug, "slug" => slug}, _session, socket) do
    lead_magnet = LeadMagnets.get_active_lead_magnet_by_slug!(project_slug, slug)

    {:ok, assign(socket,
      lead_magnet: lead_magnet,
      form: to_form(%{"email" => "", "first_name" => ""}),
      submitted: false,
      error: nil
    )}
  end

  def handle_event("submit", %{"email" => email, "first_name" => first_name}, socket) do
    lead_magnet = socket.assigns.lead_magnet

    consent_info = %{
      ip: get_connect_info(socket, :peer_data)[:address] |> format_ip(),
      user_agent: get_connect_info(socket, :user_agent)
    }

    case Leads.create_subscriber(lead_magnet.project, %{
      email: email,
      first_name: first_name,
      source: "lead_magnet",
      source_id: lead_magnet.id
    }, consent_info) do
      {:ok, subscriber} ->
        # Increment download count
        LeadMagnets.increment_download_count(lead_magnet)

        # Trigger email sequence if configured
        MarketMind.EmailMarketing.trigger_sequence(subscriber, "lead_magnet_download", lead_magnet.id)

        {:noreply, assign(socket, submitted: true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        error = changeset.errors[:email] |> elem(0)
        {:noreply, assign(socket, error: error)}
    end
  end

  defp format_ip(nil), do: nil
  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
end
```

### Step 4.2: Add Public Routes

**File:** `lib/market_mind_web/router.ex` (add)
```elixir
scope "/p", MarketMindWeb.Public do
  pipe_through :browser

  live "/:project_slug/:slug", LeadMagnetLive, :show
  get "/:project_slug/:slug/download/:subscriber_id", LeadMagnetController, :download
  get "/unsubscribe/:token", UnsubscribeController, :show
end
```

---

## Files to Create/Modify Summary

| File | Action | Purpose |
|------|--------|---------|
| `mix.exs` | Modify | Add Swoosh, gen_smtp, hackney |
| `config/*.exs` | Modify | Swoosh configuration |
| `lib/market_mind/mailer.ex` | Create | Mailer module |
| `priv/repo/migrations/*_create_subscribers.exs` | Create | Subscribers table |
| `priv/repo/migrations/*_create_lead_magnets.exs` | Create | Lead magnets table |
| `priv/repo/migrations/*_create_email_sequences.exs` | Create | Email tables |
| `lib/market_mind/leads/subscriber.ex` | Create | Subscriber schema |
| `lib/market_mind/leads.ex` | Create | Leads context |
| `lib/market_mind/lead_magnets/lead_magnet.ex` | Create | Lead magnet schema |
| `lib/market_mind/lead_magnets.ex` | Create | Lead magnets context |
| `lib/market_mind/email_marketing/*.ex` | Create | Email sequence schemas |
| `lib/market_mind/email_marketing.ex` | Create | Email marketing context |
| `lib/market_mind/agents/lead_magnet_agent.ex` | Create | AI transformation agent |
| `lib/market_mind/agents.ex` | Modify | Add run_lead_magnet_generation/3 |
| `lib/market_mind/workers/email_delivery_worker.ex` | Create | Oban email worker |
| `lib/market_mind/workers/sequence_scheduler_worker.ex` | Create | Sequence scheduler |
| `lib/market_mind_web/live/public/*.ex` | Create | Public capture pages |
| `lib/market_mind_web/router.ex` | Modify | Add public routes |

---

## Success Criteria

- [ ] Swoosh configured with local adapter (dev) and Mailgun/Brevo option (prod)
- [ ] Subscribers can sign up via public landing page
- [ ] Lead magnets auto-generated from blog content via AI
- [ ] Email sequences trigger on lead magnet download
- [ ] GDPR-compliant consent tracking
- [ ] Unsubscribe functionality works
- [ ] All tests pass (90%+ coverage)

---

## Free Service Limits

| Service | Free Tier | Notes |
|---------|-----------|-------|
| Mailgun | 5,000 emails/month | Requires credit card for verification |
| Brevo (Sendinblue) | 300 emails/day | No credit card required |
| Local SMTP | Unlimited | Dev/testing only |

---

## Technical Notes

1. **Double opt-in**: Subscribers start as "pending", confirm via email link
2. **Sequence delays**: Calculated in days/hours from subscription time
3. **Email variables**: Support `{{first_name}}`, `{{email}}` in templates
4. **Rate limiting**: Use Oban's built-in rate limiting for email queue
5. **Tracking**: Open/click tracking via email pixels (Phase 2 enhancement)
