defmodule MarketMindWeb.Public.LeadMagnetControllerTest do
  use MarketMindWeb.ConnCase, async: false

  import MarketMind.Fixtures

  describe "download/2" do
    setup do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "Ultimate Testing Guide",
        content: "## Test Content\n\nThis is the downloadable content.",
        download_url: nil
      })

      # Create subscriber with correct source attribution
      subscriber = subscriber_fixture(project, %{
        email: "downloader@example.com",
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      %{project: project, lead_magnet: lead_magnet, subscriber: subscriber}
    end

    test "redirects to external URL when download_url is present", %{
      conn: conn,
      project: project,
      subscriber: subscriber
    } do
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "External Resource",
        download_url: "https://example.com/download.pdf",
        content: nil
      })

      # Update subscriber to match this lead magnet
      updated_subscriber = subscriber_fixture(project, %{
        email: "external@example.com",
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{updated_subscriber.id}")

      assert redirected_to(conn) == "https://example.com/download.pdf"
    end

    test "serves inline content as markdown attachment", %{
      conn: conn,
      project: project,
      lead_magnet: lead_magnet,
      subscriber: subscriber
    } do
      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/markdown; charset=utf-8"]
      assert get_resp_header(conn, "content-disposition") == ["attachment; filename=\"ultimate-testing-guide.md\""]
      assert conn.resp_body =~ "## Test Content"
      assert conn.resp_body =~ "This is the downloadable content."
    end

    test "generates correct filename from title with special characters", %{
      conn: conn,
      project: project
    } do
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "The Ultimate Guide: 10 Tips & Tricks!",
        content: "Content here",
        download_url: nil
      })

      subscriber = subscriber_fixture(project, %{
        email: "special@example.com",
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 200
      # Special characters should be converted to hyphens
      assert get_resp_header(conn, "content-disposition") == ["attachment; filename=\"the-ultimate-guide-10-tips-tricks.md\""]
    end

    test "redirects with error when no content is available", %{conn: conn, project: project} do
      # Lead magnet with neither download_url nor content
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "Empty Resource",
        content: nil,
        download_url: nil
      })

      subscriber = subscriber_fixture(project, %{
        email: "empty@example.com",
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Download not available"
    end

    test "redirects with error when content is empty string", %{conn: conn, project: project} do
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "Empty Content",
        content: "",
        download_url: ""
      })

      subscriber = subscriber_fixture(project, %{
        email: "emptystring@example.com",
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Download not available"
    end
  end

  describe "download/2 - 404 errors" do
    test "returns 404 for non-existent lead magnet slug", %{conn: conn} do
      project = project_fixture()
      subscriber = subscriber_fixture(project)

      conn = get(conn, ~p"/p/#{project.slug}/non-existent-slug/download/#{subscriber.id}")

      assert conn.status == 404
    end

    test "returns 404 for non-existent project slug", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)
      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/non-existent-project/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 404
    end

    test "returns 404 for non-existent subscriber", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)
      fake_subscriber_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{fake_subscriber_id}")

      assert conn.status == 404
    end

    test "returns 404 for draft lead magnet", %{conn: conn} do
      project = project_fixture()
      # Create a draft lead magnet (not active)
      lead_magnet = lead_magnet_fixture(project, %{status: "draft"})
      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 404
    end

    test "returns 404 for archived lead magnet", %{conn: conn} do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "archived"})
      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 404
    end
  end

  describe "download/2 - 403 access denied errors" do
    test "returns 403 when subscriber is from a different project", %{conn: conn} do
      project1 = project_fixture()
      project2 = project_fixture()

      lead_magnet = active_lead_magnet_fixture(project1)

      # Subscriber belongs to project2, not project1
      subscriber = subscriber_fixture(project2, %{
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project1.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 403
    end

    test "returns 403 when subscriber source is not lead_magnet", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)

      # Subscriber has wrong source type
      subscriber = subscriber_fixture(project, %{
        source: "blog",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 403
    end

    test "returns 403 when subscriber source is manual", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)

      subscriber = subscriber_fixture(project, %{
        source: "manual",
        source_id: nil
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 403
    end

    test "returns 403 when subscriber source_id doesn't match lead_magnet", %{conn: conn} do
      project = project_fixture()
      lead_magnet1 = active_lead_magnet_fixture(project, %{title: "Lead Magnet 1"})
      lead_magnet2 = active_lead_magnet_fixture(project, %{title: "Lead Magnet 2"})

      # Subscriber signed up for lead_magnet2, but trying to download lead_magnet1
      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: lead_magnet2.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet1.slug}/download/#{subscriber.id}")

      assert conn.status == 403
    end

    test "returns 403 when subscriber source_id is nil", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)

      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: nil
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      assert conn.status == 403
    end
  end

  describe "download/2 - download_url precedence" do
    test "prefers external download_url over inline content", %{conn: conn} do
      project = project_fixture()

      # Lead magnet has both download_url AND content
      lead_magnet = active_lead_magnet_fixture(project, %{
        title: "Both Options",
        download_url: "https://cdn.example.com/guide.pdf",
        content: "This content should not be served"
      })

      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: lead_magnet.id
      })

      conn = get(conn, ~p"/p/#{project.slug}/#{lead_magnet.slug}/download/#{subscriber.id}")

      # Should redirect to external URL, not serve inline content
      assert redirected_to(conn) == "https://cdn.example.com/guide.pdf"
    end
  end
end
