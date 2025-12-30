defmodule MarketMindWeb.Public.LeadMagnetLiveTest do
  use MarketMindWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MarketMind.Fixtures

  alias MarketMind.Leads

  describe "mount/3" do
    test "renders landing page for active lead magnet", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "Ultimate Testing Guide",
        headline: "Master Testing Today",
        subheadline: "Learn the best practices",
        description: "A comprehensive guide to testing"
      })

      {:ok, _live, html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      assert html =~ "Master Testing Today"
      assert html =~ "Learn the best practices"
      assert html =~ "A comprehensive guide to testing"
      assert html =~ "Free checklist"
    end

    test "redirects for non-existent lead magnet", %{conn: conn} do
      project = project_fixture()

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Lead magnet not found"}}}} =
               live(conn, ~p"/p/#{project.slug}/non-existent-slug")
    end

    test "redirects for non-existent project", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Lead magnet not found"}}}} =
               live(conn, ~p"/p/non-existent-project/some-slug")
    end

    test "redirects for draft lead magnet", %{conn: conn} do
      project = project_fixture()
      # Create a draft lead magnet (not active)
      lead_magnet = lead_magnet_fixture(project, %{status: "draft"})

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Lead magnet not found"}}}} =
               live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")
    end

    test "sets page title to lead magnet title", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{title: "My Awesome Guide"})

      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      assert page_title(live) =~ "My Awesome Guide"
    end
  end

  describe "form submission" do
    setup do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "Test Lead Magnet",
        headline: "Get Your Free Guide",
        cta_text: "Download Now",
        thank_you_message: "Thanks for subscribing!"
      })

      %{project: project, lead_magnet: lead_magnet}
    end

    test "successfully creates subscriber with valid email", %{conn: conn, project: project, lead_magnet: lead_magnet} do
      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      # Submit the form
      html =
        live
        |> form("form", %{email: "test@example.com", first_name: "John"})
        |> render_submit()

      # Should show thank you state (apostrophe is HTML-encoded)
      assert html =~ "You&#39;re In!"
      assert html =~ "Thanks for subscribing!"

      # Verify subscriber was created
      subscriber = Leads.get_subscriber_by_email(project, "test@example.com")
      assert subscriber != nil
      assert subscriber.first_name == "John"
      assert subscriber.source == "lead_magnet"
      assert subscriber.source_id == lead_magnet.id
    end

    test "creates subscriber with email only (first_name optional)", %{conn: conn, project: project, lead_magnet: lead_magnet} do
      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      html =
        live
        |> form("form", %{email: "nofirstname@example.com", first_name: ""})
        |> render_submit()

      assert html =~ "You&#39;re In!"

      subscriber = Leads.get_subscriber_by_email(project, "nofirstname@example.com")
      assert subscriber != nil
      assert subscriber.first_name == "" || subscriber.first_name == nil
    end

    test "shows error for duplicate email", %{conn: conn, project: project, lead_magnet: lead_magnet} do
      # Create existing subscriber
      subscriber_fixture(project, %{email: "existing@example.com"})

      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      html =
        live
        |> form("form", %{email: "existing@example.com", first_name: "Test"})
        |> render_submit()

      # Should show error, not thank you
      refute html =~ "You&#39;re In!"
      assert html =~ "already subscribed" || html =~ "error"
    end

    test "shows error for invalid email format", %{conn: conn, project: project, lead_magnet: lead_magnet} do
      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      html =
        live
        |> form("form", %{email: "not-an-email", first_name: "Test"})
        |> render_submit()

      refute html =~ "You&#39;re In!"
      assert html =~ "valid email" || html =~ "error"
    end

    test "increments download count on successful subscription", %{conn: conn, project: project, lead_magnet: lead_magnet} do
      initial_count = lead_magnet.download_count

      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      live
      |> form("form", %{email: "counter@example.com", first_name: "Counter"})
      |> render_submit()

      # Reload lead magnet to check count
      updated_lead_magnet = MarketMind.LeadMagnets.get_lead_magnet!(lead_magnet.id)
      assert updated_lead_magnet.download_count == initial_count + 1
    end

    test "adds lead_magnet tag to subscriber", %{conn: conn, project: project, lead_magnet: lead_magnet} do
      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      live
      |> form("form", %{email: "tagged@example.com", first_name: "Tagged"})
      |> render_submit()

      subscriber = Leads.get_subscriber_by_email(project, "tagged@example.com")
      assert "lead_magnet:#{lead_magnet.slug}" in subscriber.tags
    end
  end

  describe "landing page rendering" do
    test "displays custom CTA text", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{cta_text: "Get My Free Guide"})

      {:ok, _live, html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      assert html =~ "Get My Free Guide"
    end

    test "displays download button when download_url is present", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{
        download_url: "https://example.com/download.pdf",
        thank_you_message: "Thanks!"
      })

      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      # Submit form to get to thank you state
      html =
        live
        |> form("form", %{email: "download@example.com", first_name: "Download"})
        |> render_submit()

      assert html =~ "Download Now"
      assert html =~ "https://example.com/download.pdf"
    end

    test "shows content preview when content is present", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{
        content: "## Getting Started\n\n- First item\n- Second item"
      })

      {:ok, _live, html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      assert html =~ "What&#39;s Inside"
      assert html =~ "Getting Started"
    end

    test "displays project name in footer", %{conn: conn} do
      project = project_fixture(%{name: "My Amazing Project"})
      lead_magnet = active_lead_magnet_fixture(project)

      {:ok, _live, html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      # Footer has project name in a span, so check both parts separately
      assert html =~ "Powered by"
      assert html =~ "My Amazing Project"
    end

    test "shows correct magnet type badge", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{magnet_type: "guide"})

      {:ok, _live, html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      assert html =~ "Free guide"
    end
  end

  describe "thank you state" do
    test "displays custom thank you message", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{
        thank_you_message: "You're awesome! Check your inbox."
      })

      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      html =
        live
        |> form("form", %{email: "thanks@example.com", first_name: ""})
        |> render_submit()

      assert html =~ "You&#39;re awesome! Check your inbox."
    end

    test "displays default thank you message when none set", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{thank_you_message: nil})

      {:ok, live, _html} = live(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}")

      html =
        live
        |> form("form", %{email: "default@example.com", first_name: ""})
        |> render_submit()

      assert html =~ "Thank you for subscribing"
    end
  end
end
