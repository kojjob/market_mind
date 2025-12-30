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
  end
end
