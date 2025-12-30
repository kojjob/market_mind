defmodule MarketMindWeb.Public.UnsubscribeControllerTest do
  use MarketMindWeb.ConnCase, async: false

  import MarketMind.Fixtures

  alias MarketMind.Leads

  describe "show/2" do
    setup do
      project = project_fixture()
      %{project: project}
    end

    test "renders confirmation page for pending subscriber", %{conn: conn, project: project} do
      subscriber = subscriber_fixture(project, %{status: "pending"})

      conn = get(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Unsubscribe"
      refute conn.assigns[:already_unsubscribed]
    end

    test "renders confirmation page for confirmed subscriber", %{conn: conn, project: project} do
      subscriber = confirmed_subscriber_fixture(project)

      conn = get(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Unsubscribe"
      refute conn.assigns[:already_unsubscribed]
    end

    test "shows already unsubscribed state for unsubscribed subscriber", %{conn: conn, project: project} do
      subscriber = subscriber_fixture(project, %{
        status: "unsubscribed",
        unsubscribed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      conn = get(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200)
      assert conn.assigns[:already_unsubscribed] == true
    end

    test "returns 404 for non-existent token", %{conn: conn} do
      fake_token = Ecto.UUID.generate()

      conn = get(conn, ~p"/p/unsubscribe/#{fake_token}")

      assert conn.status == 404
    end

    test "returns 404 for invalid token format", %{conn: conn} do
      conn = get(conn, ~p"/p/unsubscribe/invalid-not-a-uuid")

      assert conn.status == 404
    end
  end

  describe "unsubscribe/2" do
    setup do
      project = project_fixture()
      %{project: project}
    end

    test "successfully unsubscribes a pending subscriber", %{conn: conn, project: project} do
      subscriber = subscriber_fixture(project, %{status: "pending"})

      conn = post(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Successfully Unsubscribed"

      # Verify subscriber was actually unsubscribed
      updated_subscriber = Leads.get_subscriber(subscriber.id)
      assert updated_subscriber.status == "unsubscribed"
      assert updated_subscriber.unsubscribed_at != nil
    end

    test "successfully unsubscribes a confirmed subscriber", %{conn: conn, project: project} do
      subscriber = confirmed_subscriber_fixture(project)

      conn = post(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Successfully Unsubscribed"

      # Verify subscriber was actually unsubscribed
      updated_subscriber = Leads.get_subscriber(subscriber.id)
      assert updated_subscriber.status == "unsubscribed"
      assert updated_subscriber.unsubscribed_at != nil
    end

    test "idempotent - works for already unsubscribed subscriber", %{conn: conn, project: project} do
      # Create an already unsubscribed subscriber
      subscriber = subscriber_fixture(project, %{
        status: "unsubscribed",
        unsubscribed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      # Should still render confirmed without error
      conn = post(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Successfully Unsubscribed"
    end

    test "returns 404 for non-existent token", %{conn: conn} do
      fake_token = Ecto.UUID.generate()

      conn = post(conn, ~p"/p/unsubscribe/#{fake_token}")

      assert conn.status == 404
    end

    test "returns 404 for invalid token format", %{conn: conn} do
      conn = post(conn, ~p"/p/unsubscribe/invalid-not-a-uuid")

      assert conn.status == 404
    end
  end

  describe "unsubscribe flow - subscriber from different sources" do
    test "unsubscribes subscriber from lead_magnet source", %{conn: conn} do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)

      subscriber = subscriber_fixture(project, %{
        source: "lead_magnet",
        source_id: lead_magnet.id,
        status: "confirmed"
      })

      conn = post(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Successfully Unsubscribed"

      updated_subscriber = Leads.get_subscriber(subscriber.id)
      assert updated_subscriber.status == "unsubscribed"
    end

    test "unsubscribes subscriber from manual source", %{conn: conn} do
      project = project_fixture()

      subscriber = subscriber_fixture(project, %{
        source: "manual",
        source_id: nil,
        status: "confirmed"
      })

      conn = post(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Successfully Unsubscribed"

      updated_subscriber = Leads.get_subscriber(subscriber.id)
      assert updated_subscriber.status == "unsubscribed"
    end

    test "unsubscribes subscriber from blog source", %{conn: conn} do
      project = project_fixture()

      subscriber = subscriber_fixture(project, %{
        source: "blog",
        source_id: nil,
        status: "confirmed"
      })

      conn = post(conn, ~p"/p/unsubscribe/#{subscriber.id}")

      assert html_response(conn, 200) =~ "Successfully Unsubscribed"

      updated_subscriber = Leads.get_subscriber(subscriber.id)
      assert updated_subscriber.status == "unsubscribed"
    end
  end

  describe "unsubscribe flow - multi-project isolation" do
    test "subscriber token only works for their own subscription", %{conn: conn} do
      project1 = project_fixture()
      project2 = project_fixture()

      # Create subscribers in both projects with same email
      subscriber1 = subscriber_fixture(project1, %{email: "shared@example.com"})
      subscriber2 = subscriber_fixture(project2, %{email: "shared@example.com"})

      # Unsubscribe from project1
      conn = post(conn, ~p"/p/unsubscribe/#{subscriber1.id}")
      assert html_response(conn, 200) =~ "Successfully Unsubscribed"

      # Verify only project1 subscriber is unsubscribed
      updated_subscriber1 = Leads.get_subscriber(subscriber1.id)
      updated_subscriber2 = Leads.get_subscriber(subscriber2.id)

      assert updated_subscriber1.status == "unsubscribed"
      assert updated_subscriber2.status == "pending"
    end
  end
end
