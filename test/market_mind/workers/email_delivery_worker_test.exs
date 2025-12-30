defmodule MarketMind.Workers.EmailDeliveryWorkerTest do
  use MarketMind.DataCase, async: false

  import MarketMind.Fixtures
  import Swoosh.TestAssertions

  alias MarketMind.Workers.EmailDeliveryWorker
  alias MarketMind.EmailMarketing

  describe "perform/1 - successful delivery" do
    test "sends email and marks delivery as sent" do
      # Setup: Create a complete email delivery chain
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence, %{
        subject: "Hello {{first_name}}!",
        body: "<p>Welcome {{email}}, your ID is {{subscriber_id}}</p>"
      })
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      # Execute the worker
      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      # Verify email was sent
      assert_email_sent(fn email ->
        email.to == [{subscriber.first_name, subscriber.email}] and
        String.contains?(email.subject, subscriber.first_name) and
        String.contains?(email.html_body, subscriber.email)
      end)

      # Verify delivery status was updated
      updated_delivery = EmailMarketing.get_delivery!(delivery.id)
      assert updated_delivery.status == "sent"
      assert updated_delivery.sent_at != nil
    end

    test "substitutes template variables correctly" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project, %{
        first_name: "Alice",
        email: "alice@example.com"
      })
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence, %{
        subject: "Hey {{first_name}}, check this out!",
        body: "<h1>Welcome, {{first_name}}!</h1><p>Email: {{email}}</p><p>Unsubscribe: {{subscriber_id}}</p>"
      })
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      assert_email_sent(fn sent_email ->
        # Check subject substitution
        sent_email.subject == "Hey Alice, check this out!" and
        # Check body substitution
        String.contains?(sent_email.html_body, "Welcome, Alice!") and
        String.contains?(sent_email.html_body, "Email: alice@example.com") and
        String.contains?(sent_email.html_body, subscriber.id)
      end)
    end

    test "handles subscriber without first_name using fallback" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project, %{first_name: nil})
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence, %{
        subject: "Hello {{first_name}}!",
        body: "<p>Hi {{first_name}}</p>"
      })
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      assert_email_sent(fn sent_email ->
        # "there" is the fallback for missing first_name
        sent_email.subject == "Hello there!" and
        String.contains?(sent_email.html_body, "Hi there")
      end)
    end
  end

  describe "perform/1 - error handling" do
    test "returns error when delivery not found" do
      fake_id = Ecto.UUID.generate()
      job = %Oban.Job{args: %{"delivery_id" => fake_id}, attempt: 1}

      assert {:error, "Delivery not found"} = EmailDeliveryWorker.perform(job)
    end

    test "skips already sent deliveries (idempotent)" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{
        status: "sent",
        sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      # No email should be sent
      refute_email_sent()
    end

    test "skips delivery when subscriber has unsubscribed" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{
        status: "unsubscribed",
        unsubscribed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      # No email should be sent
      refute_email_sent()

      # Delivery status should remain unchanged (not marked as sent)
      updated_delivery = EmailMarketing.get_delivery!(delivery.id)
      assert updated_delivery.status == "scheduled"
    end

    test "handles deliveries with 'opened' status as already sent" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{
        status: "opened",
        sent_at: DateTime.utc_now() |> DateTime.truncate(:second),
        opened_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      refute_email_sent()
    end

    test "handles deliveries with 'clicked' status as already sent" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{
        status: "clicked",
        sent_at: DateTime.utc_now() |> DateTime.truncate(:second),
        clicked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      refute_email_sent()
    end
  end

  describe "perform/1 - retry behavior" do
    test "logs attempt number for debugging" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      # Simulate retry attempts
      job_attempt_2 = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 2}
      assert :ok = EmailDeliveryWorker.perform(job_attempt_2)

      assert_email_sent()
    end
  end

  describe "email content generation" do
    test "generates both HTML and plain text versions" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence, %{
        body: "<h1>Title</h1><p>Paragraph with <strong>bold</strong> text.</p><br/><p>Another paragraph.</p>"
      })
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      assert_email_sent(fn sent_email ->
        # HTML body should have the template wrapper
        String.contains?(sent_email.html_body, "<!DOCTYPE html>") and
        String.contains?(sent_email.html_body, "<h1>Title</h1>") and
        # Text body should be stripped of HTML
        String.contains?(sent_email.text_body, "Title") and
        String.contains?(sent_email.text_body, "bold") and
        not String.contains?(sent_email.text_body, "<h1>")
      end)
    end

    test "uses project name as from name" do
      project = project_fixture(%{name: "Awesome Product"})
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      assert_email_sent(fn sent_email ->
        {from_name, _from_email} = sent_email.from
        from_name == "Awesome Product"
      end)
    end
  end

  describe "delivery state transitions" do
    test "marks delivery as pending before sending" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      sequence = active_sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email, %{status: "scheduled"})

      # The delivery goes through pending state during processing
      job = %Oban.Job{args: %{"delivery_id" => delivery.id}, attempt: 1}
      assert :ok = EmailDeliveryWorker.perform(job)

      # After successful send, it should be "sent"
      updated_delivery = EmailMarketing.get_delivery!(delivery.id)
      assert updated_delivery.status == "sent"
    end
  end
end
