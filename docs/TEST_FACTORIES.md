# Test Factories & Fixtures

> ExMachina factories and test helpers for TDD workflow.

## Factory Setup

```elixir
# test/support/factory.ex
defmodule MarketMind.Factory do
  @moduledoc """
  ExMachina factory definitions for test data.
  
  Usage:
    import MarketMind.Factory
    
    # Create and insert
    user = insert(:user)
    project = insert(:project, user: user)
    
    # Build without insert
    attrs = params_for(:project)
    
    # Build struct without insert
    project = build(:project)
  """
  
  use ExMachina.Ecto, repo: MarketMind.Repo
  
  alias MarketMind.Accounts.User
  alias MarketMind.Products.Project
  alias MarketMind.Personas.Persona
  alias MarketMind.Content.ContentPiece
  alias MarketMind.Skills.Skill
  alias MarketMind.Agents.{Agent, Task}
  
  # =============================================
  # Users
  # =============================================
  
  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: sequence(:name, &"User #{&1}"),
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
  
  def unconfirmed_user_factory do
    struct!(user_factory(), %{confirmed_at: nil})
  end
  
  # =============================================
  # Projects
  # =============================================
  
  def project_factory do
    %Project{
      name: sequence(:project_name, &"Project #{&1}"),
      slug: sequence(:project_slug, &"project-#{&1}"),
      url: sequence(:project_url, &"https://project#{&1}.com"),
      description: "A sample project for testing",
      value_propositions: [
        "Save time with automation",
        "Reduce costs by 50%",
        "Improve team productivity"
      ],
      features: [
        %{
          "name" => "Feature 1",
          "description" => "Does something useful",
          "benefit" => "Makes life easier"
        }
      ],
      analysis_data: %{
        "analyzed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "product_name" => "Test Product"
      },
      brand_voice: %{
        "tone" => "Professional but friendly",
        "personality_traits" => ["Helpful", "Expert", "Approachable"]
      },
      analysis_status: "completed",
      is_active: true,
      user: build(:user)
    }
  end
  
  def pending_project_factory do
    struct!(project_factory(), %{
      analysis_status: "pending",
      analysis_data: %{}
    })
  end
  
  # =============================================
  # Personas
  # =============================================
  
  def persona_factory do
    %Persona{
      name: sequence(:persona_name, &"Persona #{&1}"),
      role: "Product Manager",
      description: "A mid-level product manager at a SaaS startup",
      demographics: %{
        "age_range" => "28-35",
        "location" => "San Francisco, CA",
        "education" => "Bachelor's degree"
      },
      goals: [
        "Ship features faster",
        "Improve user retention",
        "Make data-driven decisions"
      ],
      pain_points: [
        "Too many meetings",
        "Lack of engineering resources",
        "Difficulty prioritizing features"
      ],
      objections: [
        "Will this integrate with our existing tools?",
        "How long until we see ROI?"
      ],
      motivations: [
        "Career advancement",
        "Building products users love"
      ],
      channels: ["LinkedIn", "Twitter", "Product Hunt"],
      keywords: ["product management", "SaaS metrics", "user research"],
      is_primary: false,
      is_active: true,
      project: build(:project)
    }
  end
  
  def primary_persona_factory do
    struct!(persona_factory(), %{is_primary: true})
  end
  
  # =============================================
  # Skills
  # =============================================
  
  def skill_factory do
    %Skill{
      name: sequence(:skill_name, &"skill_#{&1}"),
      slug: sequence(:skill_slug, &"skill-#{&1}"),
      description: "A test skill for doing things",
      version: "1.0.0",
      category: :content,
      prompt_template: """
      You are a helpful assistant.
      
      Input: {{input.text}}
      
      Generate output based on the input.
      """,
      system_prompt: "You are a helpful AI assistant.",
      input_schema: %{
        "type" => "object",
        "properties" => %{
          "text" => %{"type" => "string"}
        },
        "required" => ["text"]
      },
      output_schema: %{
        "type" => "object",
        "properties" => %{
          "result" => %{"type" => "string"}
        }
      },
      required_context: [],
      llm_provider: :gemini,
      llm_model: "gemini-1.5-flash",
      llm_config: %{
        "temperature" => 0.7,
        "max_tokens" => 1024
      },
      usage_count: 0,
      success_count: 0,
      is_active: true,
      is_beta: false,
      is_system: true
    }
  end
  
  def product_analyzer_skill_factory do
    struct!(skill_factory(), %{
      name: "product_analyzer",
      slug: "product-analyzer",
      category: :analysis,
      required_context: []
    })
  end
  
  def persona_builder_skill_factory do
    struct!(skill_factory(), %{
      name: "persona_builder",
      slug: "persona-builder",
      category: :analysis,
      required_context: ["project"]
    })
  end
  
  def seo_blog_writer_skill_factory do
    struct!(skill_factory(), %{
      name: "seo_blog_writer",
      slug: "seo-blog-writer",
      category: :content,
      required_context: ["project", "persona"]
    })
  end
  
  # =============================================
  # Agents
  # =============================================
  
  def agent_factory do
    %Agent{
      name: sequence(:agent_name, &"Agent #{&1}"),
      status: :available,
      tasks_completed: 0,
      error_count: 0
    }
  end
  
  def working_agent_factory do
    struct!(agent_factory(), %{
      status: :working,
      current_project: build(:project)
    })
  end
  
  # =============================================
  # Tasks
  # =============================================
  
  def task_factory do
    %Task{
      task_type: "content_generation",
      status: :pending,
      priority: 5,
      input_data: %{"topic" => "AI Marketing"},
      requires_approval: false,
      approval_status: :not_required,
      project: build(:project),
      skill: build(:skill)
    }
  end
  
  def pending_task_factory do
    task_factory()
  end
  
  def running_task_factory do
    struct!(task_factory(), %{
      status: :running,
      started_at: DateTime.utc_now()
    })
  end
  
  def completed_task_factory do
    struct!(task_factory(), %{
      status: :completed,
      started_at: DateTime.utc_now() |> DateTime.add(-60, :second),
      completed_at: DateTime.utc_now(),
      duration_ms: 60_000,
      output_data: %{"result" => "Generated content here"}
    })
  end
  
  def approval_pending_task_factory do
    struct!(task_factory(), %{
      status: :completed,
      requires_approval: true,
      approval_status: :pending
    })
  end
  
  # =============================================
  # Content
  # =============================================
  
  def content_piece_factory do
    %ContentPiece{
      title: sequence(:content_title, &"Blog Post #{&1}"),
      slug: sequence(:content_slug, &"blog-post-#{&1}"),
      content_type: :blog,
      status: :draft,
      body: """
      # Introduction
      
      This is a test blog post about an interesting topic.
      
      ## Main Section
      
      Here's some valuable content for the reader.
      
      ## Conclusion
      
      Thanks for reading!
      """,
      summary: "A test blog post about interesting topics.",
      meta_title: "Test Blog Post | MarketMind",
      meta_description: "Learn about interesting topics in this comprehensive guide.",
      primary_keyword: "test keyword",
      secondary_keywords: ["related term", "another keyword"],
      word_count: 150,
      estimated_read_time: 1,
      faq: [
        %{"question" => "What is this about?", "answer" => "It's about testing."}
      ],
      version: 1,
      project: build(:project)
    }
  end
  
  def approved_content_factory do
    struct!(content_piece_factory(), %{
      status: :approved,
      approved_at: DateTime.utc_now()
    })
  end
  
  def published_content_factory do
    struct!(content_piece_factory(), %{
      status: :published,
      published_at: DateTime.utc_now(),
      published_url: "https://blog.example.com/post-1"
    })
  end
  
  # =============================================
  # Helpers
  # =============================================
  
  @doc """
  Create a complete project with personas and content.
  """
  def project_with_content_factory do
    project = build(:project)
    
    %{
      project: project,
      personas: [
        build(:primary_persona, project: project),
        build(:persona, project: project)
      ],
      content: [
        build(:content_piece, project: project),
        build(:approved_content, project: project)
      ]
    }
  end
end
```

---

## Test Helpers

```elixir
# test/support/data_case.ex
defmodule MarketMind.DataCase do
  @moduledoc """
  Test case for tests that require database access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias MarketMind.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MarketMind.DataCase
      import MarketMind.Factory
    end
  end

  setup tags do
    MarketMind.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MarketMind.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Helper for returning list of errors from a changeset.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
```

```elixir
# test/support/conn_case.ex
defmodule MarketMindWeb.ConnCase do
  @moduledoc """
  Test case for controllers and LiveViews.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint MarketMindWeb.Endpoint

      use MarketMindWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import MarketMindWeb.ConnCase
      import MarketMind.Factory
    end
  end

  setup tags do
    MarketMind.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = MarketMind.Factory.insert(:user)
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.
  """
  def log_in_user(conn, user) do
    token = MarketMind.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
```

---

## LLM Mock

```elixir
# test/support/llm_mock.ex
defmodule MarketMind.LLM.Mock do
  @moduledoc """
  Mock LLM client for testing.
  
  Allows setting expected responses:
  
      MarketMind.LLM.Mock.set_response({:ok, "Mocked response"})
      
  Or use pattern-based responses:
  
      MarketMind.LLM.Mock.set_response(:product_analysis, %{...})
  """
  
  @behaviour MarketMind.LLM.Client
  
  use Agent
  
  def start_link(_opts) do
    Agent.start_link(fn -> %{responses: %{}, default: {:ok, "Mock response"}} end, name: __MODULE__)
  end
  
  def set_response(response) do
    Agent.update(__MODULE__, fn state -> %{state | default: response} end)
  end
  
  def set_response(key, response) do
    Agent.update(__MODULE__, fn state ->
      %{state | responses: Map.put(state.responses, key, response)}
    end)
  end
  
  def clear_responses do
    Agent.update(__MODULE__, fn _ -> %{responses: %{}, default: {:ok, "Mock response"}} end)
  end
  
  @impl true
  def complete(model, messages, opts) do
    state = Agent.get(__MODULE__, & &1)
    
    # Check for pattern-based response
    case find_matching_response(state.responses, messages) do
      nil -> state.default
      response -> response
    end
  end
  
  @impl true
  def stream(_model, _messages, _opts, callback) do
    callback.("Streaming ")
    callback.("mock ")
    callback.("response")
    {:ok, "Streaming mock response"}
  end
  
  @impl true
  def count_tokens(text) do
    # Rough approximation: ~4 chars per token
    {:ok, div(String.length(text), 4)}
  end
  
  defp find_matching_response(responses, messages) do
    last_message = List.last(messages)
    content = last_message[:content] || ""
    
    Enum.find_value(responses, fn {key, response} ->
      if String.contains?(content, to_string(key)), do: response
    end)
  end
end
```

---

## Fixtures

```elixir
# test/support/fixtures.ex
defmodule MarketMind.Fixtures do
  @moduledoc """
  Static fixtures for common test data.
  """
  
  @doc """
  Sample website HTML for product analysis tests.
  """
  def sample_website_html do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Acme SaaS - Automate Your Workflow</title>
      <meta name="description" content="Acme helps teams automate repetitive tasks and focus on what matters.">
    </head>
    <body>
      <header>
        <h1>Acme SaaS</h1>
        <p class="tagline">Automate Your Workflow, Amplify Your Impact</p>
      </header>
      <main>
        <section id="hero">
          <h2>Stop wasting time on repetitive tasks</h2>
          <p>Acme automates your workflow so you can focus on building your business.</p>
        </section>
        <section id="features">
          <h2>Features</h2>
          <div class="feature">
            <h3>Smart Automation</h3>
            <p>Set up workflows in minutes, not hours.</p>
          </div>
          <div class="feature">
            <h3>Team Collaboration</h3>
            <p>Work together seamlessly with shared automations.</p>
          </div>
        </section>
        <section id="pricing">
          <h2>Pricing</h2>
          <p>Starting at $29/month. Free trial available.</p>
        </section>
      </main>
    </body>
    </html>
    """
  end
  
  @doc """
  Sample product analysis result.
  """
  def sample_product_analysis do
    %{
      "product_name" => "Acme SaaS",
      "tagline" => "Automate Your Workflow, Amplify Your Impact",
      "description" => "Acme automates workflows for teams, helping them focus on high-value work.",
      "value_propositions" => [
        "Save time with automation",
        "Easy setup in minutes",
        "Seamless team collaboration"
      ],
      "features" => [
        %{"name" => "Smart Automation", "description" => "Set up workflows in minutes"},
        %{"name" => "Team Collaboration", "description" => "Shared automations"}
      ],
      "target_audience" => %{
        "primary" => "Small to medium teams",
        "industries" => ["SaaS", "Tech"]
      },
      "brand_voice" => %{
        "tone" => "Professional yet approachable",
        "personality_traits" => ["Helpful", "Efficient"]
      },
      "pricing_model" => "Subscription"
    }
  end
  
  @doc """
  Sample generated blog post.
  """
  def sample_blog_post do
    %{
      "title" => "5 Ways to Automate Your Marketing Workflow",
      "meta_description" => "Learn how to save time and boost productivity with marketing automation.",
      "slug" => "automate-marketing-workflow",
      "tldr" => "Marketing automation saves time and improves consistency. Here are 5 practical ways to get started.",
      "body" => """
      # 5 Ways to Automate Your Marketing Workflow

      **TL;DR:** Marketing automation saves time and improves consistency. Here are 5 practical ways to get started.

      ## Introduction

      If you're spending hours on repetitive marketing tasks, you're not alone...

      ## 1. Automate Social Media Posting

      Schedule your content in advance...

      ## 2. Set Up Email Sequences

      Create automated email workflows...

      ## Conclusion

      Start small and expand your automation as you see results.
      """,
      "faq" => [
        %{"question" => "What is marketing automation?", "answer" => "Marketing automation uses software to automate repetitive marketing tasks."},
        %{"question" => "How much time can I save?", "answer" => "Most teams save 5-10 hours per week."}
      ],
      "word_count" => 1200
    }
  end
end
```

---

## Test Example

```elixir
# test/market_mind/products_test.exs
defmodule MarketMind.ProductsTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.Products
  alias MarketMind.Products.Project

  describe "list_projects/1" do
    test "returns projects for the given user" do
      user = insert(:user)
      project = insert(:project, user: user)
      _other_project = insert(:project)  # Different user

      assert [returned_project] = Products.list_projects(user)
      assert returned_project.id == project.id
    end

    test "returns empty list when user has no projects" do
      user = insert(:user)
      assert [] = Products.list_projects(user)
    end
  end

  describe "create_project/2" do
    test "creates project with valid attributes" do
      user = insert(:user)
      attrs = params_for(:project, user: nil)

      assert {:ok, %Project{} = project} = Products.create_project(user, attrs)
      assert project.name == attrs.name
      assert project.user_id == user.id
    end

    test "returns error with invalid url" do
      user = insert(:user)
      attrs = params_for(:project, url: "not-a-url")

      assert {:error, changeset} = Products.create_project(user, attrs)
      assert "is not a valid URL" in errors_on(changeset).url
    end

    test "generates slug from name" do
      user = insert(:user)
      attrs = params_for(:project, name: "My Awesome Project")

      assert {:ok, project} = Products.create_project(user, attrs)
      assert project.slug == "my-awesome-project"
    end
  end
end
```

```elixir
# test/market_mind/skills/executor_test.exs
defmodule MarketMind.Skills.ExecutorTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.Skills.Executor

  setup do
    # Start the mock LLM
    start_supervised!(MarketMind.LLM.Mock)
    :ok
  end

  describe "execute/3" do
    test "executes skill and returns parsed output" do
      skill = insert(:skill)
      project = insert(:project)
      
      MarketMind.LLM.Mock.set_response({:ok, ~s({"result": "Generated content"})})
      
      context = %{project: project}
      input = %{text: "Test input"}
      
      assert {:ok, output} = Executor.execute(skill, context, input)
      assert output["result"] == "Generated content"
    end

    test "returns error when LLM fails" do
      skill = insert(:skill)
      
      MarketMind.LLM.Mock.set_response({:error, :rate_limited})
      
      assert {:error, :rate_limited} = Executor.execute(skill, %{}, %{text: "Test"})
    end
  end
end
```
