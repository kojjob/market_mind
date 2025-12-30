defmodule MarketMindWeb.ProjectLiveTest do
  use MarketMindWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MarketMind.Accounts.User
  alias MarketMind.Products
  alias MarketMind.Products.WebsiteFetcher
  alias MarketMind.LLM.Gemini
  alias MarketMind.Repo

  # Helper to get or create the demo user that LiveViews use
  defp get_or_create_demo_user do
    case Repo.get_by(User, email: "demo@marketmind.app") do
      nil ->
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

  @sample_analysis_json ~s({
    "product_name": "TestProduct",
    "tagline": "The best testing product",
    "value_propositions": ["Fast", "Reliable"],
    "key_features": [{"name": "Feature 1", "description": "Does something great"}],
    "target_audience": "Developers",
    "pricing_model": "freemium",
    "industries": ["Technology"],
    "tone": "professional",
    "unique_differentiators": ["Best in class"]
  })

  describe "Index" do
    test "lists user projects", %{conn: conn} do
      # Use the demo user that the LiveView uses
      user = get_or_create_demo_user()

      {:ok, project} =
        Products.create_project(user, %{name: "Test Project", url: "https://test.com"})

      {:ok, _index_live, html} = live(conn, ~p"/projects")

      assert html =~ "Your Projects"
      assert html =~ project.name
    end

    test "shows empty state when no projects", %{conn: conn} do
      # Demo user with no projects should show the dashboard with empty table
      _user = get_or_create_demo_user()

      {:ok, _index_live, html} = live(conn, ~p"/projects")

      # Dashboard renders with stats and empty projects table
      assert html =~ "Intelligence Dashboard"
      assert html =~ "Total Projects"
    end
  end

  describe "New" do
    test "renders new project form", %{conn: conn} do
      {:ok, _new_live, html} = live(conn, ~p"/projects/new")

      assert html =~ "New"
      assert html =~ "Project"
      assert html =~ "Website URL"
    end

    test "creates project and redirects to show on success", %{conn: conn} do
      _user = get_or_create_demo_user()

      # Stub external services for the analysis that runs after creation
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>Test</title></head><body>Content</body></html>")
      end)

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => @sample_analysis_json}]}}
          ]
        })
      end)

      {:ok, new_live, _html} = live(conn, ~p"/projects/new")

      new_live
      |> form("#project-form", project: %{name: "My SaaS Product", url: "https://example.com"})
      |> render_submit()

      # Should redirect to show page (assert_redirect returns {path, flash})
      {path, _flash} = assert_redirect(new_live)
      assert path =~ ~r{/projects/.+}
    end

    test "shows validation errors for invalid data", %{conn: conn} do
      {:ok, new_live, _html} = live(conn, ~p"/projects/new")

      result =
        new_live
        |> form("#project-form", project: %{name: "", url: "not-a-url"})
        |> render_submit()

      assert result =~ "can&#39;t be blank" or result =~ "must be a valid URL"
    end
  end

  describe "Show" do
    setup do
      # Use the demo user that LiveViews use
      user =
        case Repo.get_by(User, email: "demo@marketmind.app") do
          nil ->
            {:ok, u} =
              Repo.insert(%User{
                email: "demo@marketmind.app",
                hashed_password: "$2b$12$demo_placeholder_hash_for_development"
              })

            u

          u ->
            u
        end

      {:ok, project} =
        Products.create_project(user, %{name: "Test Project", url: "https://test.com"})

      %{user: user, project: project}
    end

    test "displays project details", %{conn: conn, project: project} do
      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ project.name
      assert html =~ project.url
      assert html =~ "pending" or html =~ "Pending"
    end

    test "displays analysis status badge", %{conn: conn, project: project} do
      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "Pending" or html =~ "PENDING"
    end

    test "shows analyzing state during analysis", %{conn: conn, project: project} do
      # Update to analyzing status
      Products.update_analysis_status(project, "analyzing")

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "analyzing" or html =~ "Analyzing"
    end

    test "displays analysis results when completed", %{conn: conn, project: project} do
      analysis_data = %{
        "product_name" => "TestProduct",
        "tagline" => "The best testing product",
        "value_propositions" => ["Fast", "Reliable"],
        "key_features" => [%{"name" => "Feature 1", "description" => "Great"}],
        "target_audience" => "Developers",
        "pricing_model" => "freemium",
        "industries" => ["Technology"],
        "tone" => "professional",
        "unique_differentiators" => ["Best in class"]
      }

      Products.update_analysis_status(project, "completed", analysis_data)

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "TestProduct"
      assert html =~ "The best testing product"
      assert html =~ "Developers"
    end

    test "updates in real-time when analysis completes", %{conn: conn, project: project} do
      {:ok, show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      # Initial state should be pending
      assert html =~ "pending" or html =~ "Pending"

      # Simulate analysis completion via PubSub broadcast
      analysis_data = %{
        "product_name" => "LiveUpdate Test",
        "tagline" => "Real-time updates work!",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "Everyone",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => []
      }

      Products.update_analysis_status(project, "completed", analysis_data)

      Phoenix.PubSub.broadcast(
        MarketMind.PubSub,
        "project:#{project.id}",
        {:analysis_completed, %{project_id: project.id, status: "completed"}}
      )

      # LiveView should update to show completed status
      updated_html = render(show_live)
      assert updated_html =~ "completed" or updated_html =~ "LiveUpdate Test"
    end

    test "redirects for non-existent project", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/projects", flash: %{"error" => "Project not found"}}}} =
               live(conn, ~p"/projects/non-existent-slug")
    end

    test "shows queued state during queued status", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "queued")

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "queued" or html =~ "Queued"
      assert html =~ "Analysis Queued"
    end

    test "shows failed state with error message", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "failed", %{"error_message" => "Custom error occurred"})

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "failed" or html =~ "Failed"
      assert html =~ "Analysis Failed"
      assert html =~ "Custom error occurred"
    end

    test "shows default error message when no specific error", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "failed", %{})

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "encountered an error"
    end

    test "shows rate limit warning when error contains rate limit", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "failed", %{"error_message" => "Rate limit exceeded"})

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "rate limited"
    end

    test "switch_tab event changes active tab", %{conn: conn, project: project} do
      analysis_data = %{
        "product_name" => "TestProduct",
        "tagline" => "Test tagline",
        "value_propositions" => ["VP1"],
        "key_features" => [%{"name" => "F1", "description" => "D1"}],
        "target_audience" => "Devs",
        "pricing_model" => "free",
        "industries" => ["Tech"],
        "tone" => "casual",
        "unique_differentiators" => ["Unique"]
      }

      Products.update_analysis_status(project, "completed", analysis_data)

      {:ok, show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      # Default tab should be overview
      assert html =~ "Product Identity"

      # Switch to personas tab
      html = show_live |> element("button[phx-value-tab='personas']") |> render_click()
      assert html =~ "Target Personas"

      # Switch to competitors tab
      html = show_live |> element("button[phx-value-tab='competitors']") |> render_click()
      assert html =~ "Market Competitors"

      # Switch to leads tab
      html = show_live |> element("button[phx-value-tab='leads']") |> render_click()
      assert html =~ "Lead Discovery"

      # Switch to content tab
      html = show_live |> element("button[phx-value-tab='content']") |> render_click()
      assert html =~ "Content Strategy"

      # Switch to cro tab
      html = show_live |> element("button[phx-value-tab='cro']") |> render_click()
      assert html =~ "Conversion Audit"

      # Switch to aeo tab
      html = show_live |> element("button[phx-value-tab='aeo']") |> render_click()
      assert html =~ "AEO Strategy"
    end

    test "reanalyze event queues new analysis", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => []
      })

      # Stub external services for Oban worker (runs inline in test)
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>Test</title></head><body>Content</body></html>")
      end)

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => @sample_analysis_json}]}}
          ]
        })
      end)

      {:ok, show_live, html} = live(conn, ~p"/projects/#{project.slug}")
      assert html =~ "Re-analyze"

      # Click reanalyze button
      show_live |> element("button", "Re-analyze") |> render_click()

      # Check flash message
      assert render(show_live) =~ "Re-analysis started!" or render(show_live) =~ "queued"
    end

    test "reanalyze button shown when status is failed", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "failed", %{})

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "Try Again"
    end

    test "reanalyze button hidden when status is pending", %{conn: conn, project: project} do
      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      refute html =~ "Re-analyze"
    end

    test "shows empty personas state with run agent button", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => []
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to personas tab
      html = show_live |> element("button[phx-value-tab='personas']") |> render_click()

      assert html =~ "No Personas Yet"
      assert html =~ "Run Agent"
    end

    test "shows empty competitors state with run agent button", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "competitors" => []
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to competitors tab
      html = show_live |> element("button[phx-value-tab='competitors']") |> render_click()

      assert html =~ "No Competitors Yet"
      assert html =~ "Run Agent"
    end

    test "shows empty leads state with run agent button", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "leads" => []
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to leads tab
      html = show_live |> element("button[phx-value-tab='leads']") |> render_click()

      assert html =~ "No Leads Yet"
      assert html =~ "Run Agent"
    end

    test "shows empty content state with run agent button", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "content" => nil
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to content tab
      html = show_live |> element("button[phx-value-tab='content']") |> render_click()

      assert html =~ "No Content Strategy Yet"
      assert html =~ "Run Agent"
    end

    test "shows empty CRO audit state with run agent button", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "cro_audit" => nil
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to CRO tab
      html = show_live |> element("button[phx-value-tab='cro']") |> render_click()

      assert html =~ "No Audit Yet"
      assert html =~ "Run Agent"
    end

    test "shows empty AEO state with run agent button", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "aeo_strategy" => nil
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to AEO tab
      html = show_live |> element("button[phx-value-tab='aeo']") |> render_click()

      assert html =~ "No AEO Strategy Yet"
      assert html =~ "Run Agent"
    end

    test "displays competitors when present", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "competitors" => [
          %{
            "name" => "CompetitorOne",
            "description" => "A competing product",
            "pricing_strategy" => "Premium",
            "strengths" => ["Fast", "Reliable"],
            "market_gap" => "Missing feature X"
          }
        ]
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to competitors tab
      html = show_live |> element("button[phx-value-tab='competitors']") |> render_click()

      assert html =~ "CompetitorOne"
      assert html =~ "A competing product"
      assert html =~ "Premium"
      assert html =~ "Fast"
      assert html =~ "Missing feature X"
    end

    test "displays leads when present", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "leads" => [
          %{
            "name" => "Enterprise Segment",
            "pain_points" => ["Slow processes", "High costs"],
            "lead_magnet_idea" => "Free ROI calculator",
            "outreach_hook" => "Reduce costs by 50%"
          }
        ]
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to leads tab
      html = show_live |> element("button[phx-value-tab='leads']") |> render_click()

      assert html =~ "Enterprise Segment"
      assert html =~ "Slow processes"
      assert html =~ "Free ROI calculator"
      assert html =~ "Reduce costs by 50%"
    end

    test "displays content strategy when present", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "content" => %{
          "strategy" => "Focus on educational content",
          "content_atoms" => [
            %{
              "platform" => "Twitter",
              "format" => "Thread",
              "hook" => "5 ways to improve",
              "body_outline" => "Step by step guide",
              "cta" => "Follow for more"
            }
          ]
        }
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to content tab
      html = show_live |> element("button[phx-value-tab='content']") |> render_click()

      assert html =~ "Focus on educational content"
      assert html =~ "Twitter"
      assert html =~ "5 ways to improve"
      assert html =~ "Follow for more"
    end

    test "displays CRO audit results when present", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "cro_audit" => %{
          "overall_score" => 75,
          "clarity_rating" => 8,
          "trust_rating" => 7,
          "cta_rating" => 6,
          "findings" => [
            %{
              "area" => "CTA",
              "issue" => "Button not visible",
              "recommendation" => "Use contrasting colors",
              "impact" => "High"
            }
          ],
          "hero_rewrite" => %{
            "headline" => "Better Headline Here",
            "subheadline" => "Improved subheadline"
          }
        }
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to CRO tab
      html = show_live |> element("button[phx-value-tab='cro']") |> render_click()

      assert html =~ "75%"
      assert html =~ "Button not visible"
      assert html =~ "Use contrasting colors"
      assert html =~ "Better Headline Here"
    end

    test "displays AEO strategy when present", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => [],
        "aeo_strategy" => %{
          "overview" => "Optimize for AI search engines",
          "keywords" => ["AI tool", "automation", "productivity"],
          "platform_specifics" => %{
            "chatgpt" => "Focus on clear product descriptions"
          }
        }
      })

      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # Navigate to AEO tab
      html = show_live |> element("button[phx-value-tab='aeo']") |> render_click()

      assert html =~ "Optimize for AI search engines"
      assert html =~ "AI tool"
      assert html =~ "Chatgpt"
      assert html =~ "Focus on clear product descriptions"
    end

    test "handles analysis_status_changed PubSub message", %{conn: conn, project: project} do
      {:ok, show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      assert html =~ "pending" or html =~ "Pending"

      # Update status in database
      Products.update_analysis_status(project, "analyzing")

      # Broadcast status change
      Phoenix.PubSub.broadcast(
        MarketMind.PubSub,
        "project:#{project.id}",
        {:analysis_status_changed, %{status: "analyzing"}}
      )

      # LiveView should update
      updated_html = render(show_live)
      assert updated_html =~ "analyzing" or updated_html =~ "Analyzing"
    end

    test "displays overview tab with value propositions and features", %{conn: conn, project: project} do
      Products.update_analysis_status(project, "completed", %{
        "product_name" => "SuperApp",
        "tagline" => "The best app ever",
        "value_propositions" => ["Fast deployment", "Easy to use"],
        "key_features" => [
          %{"name" => "Dashboard", "description" => "Real-time analytics"},
          %{"name" => "API", "description" => "RESTful endpoints"}
        ],
        "target_audience" => "Developers and startups",
        "pricing_model" => "subscription",
        "industries" => ["Tech", "Finance"],
        "tone" => "professional",
        "unique_differentiators" => ["Best in class"]
      })

      {:ok, _show_live, html} = live(conn, ~p"/projects/#{project.slug}")

      # Check overview content
      assert html =~ "SuperApp"
      assert html =~ "The best app ever"
      assert html =~ "Fast deployment"
      assert html =~ "Easy to use"
      assert html =~ "Dashboard"
      assert html =~ "Real-time analytics"
      assert html =~ "API"
      assert html =~ "RESTful endpoints"
      assert html =~ "Developers and startups"
      assert html =~ "subscription"
      assert html =~ "Tech"
      assert html =~ "Finance"
    end

    test "sets page title to project name", %{conn: conn, project: project} do
      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      assert page_title(show_live) =~ project.name
    end
  end

  describe "Show handle_event switch_tab" do
    setup do
      user = get_or_create_demo_user()

      {:ok, project} =
        Products.create_project(user, %{name: "Tab Test Project", url: "https://tab-test.com"})

      Products.update_analysis_status(project, "completed", %{
        "product_name" => "Test",
        "tagline" => "Test",
        "value_propositions" => [],
        "key_features" => [],
        "target_audience" => "All",
        "pricing_model" => "free",
        "industries" => [],
        "tone" => "casual",
        "unique_differentiators" => []
      })

      %{project: project}
    end

    test "switch_tab event with overview", %{conn: conn, project: project} do
      {:ok, show_live, _html} = live(conn, ~p"/projects/#{project.slug}")

      # First switch to another tab
      show_live |> element("button[phx-value-tab='personas']") |> render_click()

      # Then switch back to overview
      html = show_live |> element("button[phx-value-tab='overview']") |> render_click()

      assert html =~ "Product Identity"
    end
  end
end
