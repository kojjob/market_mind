defmodule MarketMind.EmailMarketingTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.EmailMarketing
  alias MarketMind.EmailMarketing.{EmailSequence, SequenceEmail, EmailDelivery}
  alias MarketMind.Fixtures

  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    project = Fixtures.project_fixture()
    subscriber = Fixtures.subscriber_fixture(project)

    %{project: project, subscriber: subscriber}
  end

  # ============================================================================
  # Sequence CRUD Tests
  # ============================================================================

  describe "list_sequences/1" do
    test "returns all sequences for a project", %{project: project} do
      sequence1 = Fixtures.sequence_fixture(project, %{name: "Sequence 1"})
      sequence2 = Fixtures.sequence_fixture(project, %{name: "Sequence 2"})

      # Different project shouldn't show up
      other_project = Fixtures.project_fixture()
      _other_sequence = Fixtures.sequence_fixture(other_project)

      sequences = EmailMarketing.list_sequences(project)

      assert length(sequences) == 2
      assert Enum.any?(sequences, &(&1.id == sequence1.id))
      assert Enum.any?(sequences, &(&1.id == sequence2.id))
    end

    test "returns empty list when no sequences exist", %{project: project} do
      assert EmailMarketing.list_sequences(project) == []
    end

    test "orders by inserted_at descending", %{project: project} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Use explicit timestamps for deterministic ordering
      sequence1 = Fixtures.sequence_fixture(project, %{
        name: "First",
        inserted_at: DateTime.add(now, -1, :second)
      })
      sequence2 = Fixtures.sequence_fixture(project, %{
        name: "Second",
        inserted_at: now
      })

      sequences = EmailMarketing.list_sequences(project)

      # Most recent first
      assert Enum.at(sequences, 0).id == sequence2.id
      assert Enum.at(sequences, 1).id == sequence1.id
    end
  end

  describe "list_active_sequences/1" do
    test "returns only active sequences", %{project: project} do
      _draft = Fixtures.sequence_fixture(project, %{status: "draft"})
      active = Fixtures.sequence_fixture(project, %{status: "active"})
      _paused = Fixtures.sequence_fixture(project, %{status: "paused"})

      sequences = EmailMarketing.list_active_sequences(project)

      assert length(sequences) == 1
      assert hd(sequences).id == active.id
    end

    test "returns empty list when no active sequences", %{project: project} do
      _draft = Fixtures.sequence_fixture(project, %{status: "draft"})

      assert EmailMarketing.list_active_sequences(project) == []
    end
  end

  describe "get_sequence!/1" do
    test "returns sequence by ID", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      fetched = EmailMarketing.get_sequence!(sequence.id)

      assert fetched.id == sequence.id
      assert fetched.name == sequence.name
    end

    test "raises when sequence doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        EmailMarketing.get_sequence!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_sequence_with_emails!/1" do
    test "returns sequence with emails preloaded", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email1 = Fixtures.sequence_email_fixture(sequence, %{position: 2})
      email2 = Fixtures.sequence_email_fixture(sequence, %{position: 1})

      fetched = EmailMarketing.get_sequence_with_emails!(sequence.id)

      assert fetched.id == sequence.id
      assert length(fetched.emails) == 2
      # Ordered by position
      assert Enum.at(fetched.emails, 0).id == email2.id
      assert Enum.at(fetched.emails, 1).id == email1.id
    end

    test "returns empty emails list when no emails", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      fetched = EmailMarketing.get_sequence_with_emails!(sequence.id)

      assert fetched.emails == []
    end
  end

  describe "find_sequence_by_trigger/3" do
    test "finds active sequence by trigger type", %{project: project} do
      _draft = Fixtures.sequence_fixture(project, %{trigger: "manual", status: "draft"})
      active = Fixtures.sequence_fixture(project, %{trigger: "manual", status: "active"})

      found = EmailMarketing.find_sequence_by_trigger(project, "manual")

      assert found.id == active.id
    end

    test "finds sequence by trigger type with trigger_id", %{project: project} do
      lead_magnet = Fixtures.lead_magnet_fixture(project)

      sequence =
        Fixtures.sequence_fixture(project, %{
          trigger: "lead_magnet_download",
          trigger_id: lead_magnet.id,
          status: "active"
        })

      found = EmailMarketing.find_sequence_by_trigger(project, "lead_magnet_download", lead_magnet.id)

      assert found.id == sequence.id
    end

    test "returns nil when no matching sequence", %{project: project} do
      _sequence = Fixtures.sequence_fixture(project, %{trigger: "manual", status: "active"})

      assert is_nil(EmailMarketing.find_sequence_by_trigger(project, "subscriber_confirmed"))
    end

    test "returns nil for inactive sequences", %{project: project} do
      _paused = Fixtures.sequence_fixture(project, %{trigger: "manual", status: "paused"})

      assert is_nil(EmailMarketing.find_sequence_by_trigger(project, "manual"))
    end
  end

  describe "create_sequence/2" do
    test "creates sequence with valid attributes", %{project: project} do
      attrs = %{name: "Welcome Sequence", trigger: "subscriber_confirmed"}

      assert {:ok, sequence} = EmailMarketing.create_sequence(project, attrs)

      assert sequence.name == "Welcome Sequence"
      assert sequence.trigger == "subscriber_confirmed"
      assert sequence.project_id == project.id
      assert sequence.status == "draft"
    end

    test "creates sequence with lead_magnet_download trigger", %{project: project} do
      lead_magnet = Fixtures.lead_magnet_fixture(project)

      attrs = %{
        name: "Lead Magnet Follow-up",
        trigger: "lead_magnet_download",
        trigger_id: lead_magnet.id
      }

      assert {:ok, sequence} = EmailMarketing.create_sequence(project, attrs)

      assert sequence.trigger == "lead_magnet_download"
      assert sequence.trigger_id == lead_magnet.id
    end

    test "fails when missing required fields", %{project: project} do
      assert {:error, changeset} = EmailMarketing.create_sequence(project, %{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).trigger
    end

    test "fails with invalid trigger type", %{project: project} do
      attrs = %{name: "Test", trigger: "invalid_trigger"}

      assert {:error, changeset} = EmailMarketing.create_sequence(project, attrs)

      assert "must be one of: lead_magnet_download, subscriber_confirmed, manual" in errors_on(changeset).trigger
    end

    test "fails when lead_magnet_download trigger missing trigger_id", %{project: project} do
      attrs = %{name: "Test", trigger: "lead_magnet_download"}

      assert {:error, changeset} = EmailMarketing.create_sequence(project, attrs)

      assert "is required for lead_magnet_download trigger" in errors_on(changeset).trigger_id
    end
  end

  describe "update_sequence/2" do
    test "updates sequence with valid attributes", %{project: project} do
      sequence = Fixtures.sequence_fixture(project, %{name: "Original"})

      assert {:ok, updated} = EmailMarketing.update_sequence(sequence, %{name: "Updated"})

      assert updated.name == "Updated"
    end

    test "fails with invalid attributes", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      assert {:error, changeset} = EmailMarketing.update_sequence(sequence, %{trigger: "invalid"})

      assert "must be one of: lead_magnet_download, subscriber_confirmed, manual" in errors_on(changeset).trigger
    end
  end

  describe "activate_sequence/1" do
    test "activates a draft sequence", %{project: project} do
      sequence = Fixtures.sequence_fixture(project, %{status: "draft"})

      assert {:ok, activated} = EmailMarketing.activate_sequence(sequence)

      assert activated.status == "active"
    end

    test "activates a paused sequence", %{project: project} do
      sequence = Fixtures.sequence_fixture(project, %{status: "paused"})

      assert {:ok, activated} = EmailMarketing.activate_sequence(sequence)

      assert activated.status == "active"
    end
  end

  describe "pause_sequence/1" do
    test "pauses an active sequence", %{project: project} do
      sequence = Fixtures.sequence_fixture(project, %{status: "active"})

      assert {:ok, paused} = EmailMarketing.pause_sequence(sequence)

      assert paused.status == "paused"
    end
  end

  describe "delete_sequence/1" do
    test "deletes a sequence", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      assert {:ok, _deleted} = EmailMarketing.delete_sequence(sequence)

      assert_raise Ecto.NoResultsError, fn ->
        EmailMarketing.get_sequence!(sequence.id)
      end
    end
  end

  # ============================================================================
  # Sequence Email CRUD Tests
  # ============================================================================

  describe "list_sequence_emails/1" do
    test "returns all emails in sequence ordered by position", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email3 = Fixtures.sequence_email_fixture(sequence, %{position: 3})
      email1 = Fixtures.sequence_email_fixture(sequence, %{position: 1})
      email2 = Fixtures.sequence_email_fixture(sequence, %{position: 2})

      emails = EmailMarketing.list_sequence_emails(sequence)

      assert length(emails) == 3
      assert Enum.at(emails, 0).id == email1.id
      assert Enum.at(emails, 1).id == email2.id
      assert Enum.at(emails, 2).id == email3.id
    end

    test "returns empty list when no emails", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      assert EmailMarketing.list_sequence_emails(sequence) == []
    end
  end

  describe "get_sequence_email!/1" do
    test "returns email by ID", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      fetched = EmailMarketing.get_sequence_email!(email.id)

      assert fetched.id == email.id
      assert fetched.subject == email.subject
    end

    test "raises when email doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        EmailMarketing.get_sequence_email!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_sequence_email/2" do
    test "creates email with valid attributes", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      attrs = %{
        subject: "Welcome!",
        body: "Hello {{first_name}}!",
        position: 1,
        delay_days: 0,
        delay_hours: 0
      }

      assert {:ok, email} = EmailMarketing.create_sequence_email(sequence, attrs)

      assert email.subject == "Welcome!"
      assert email.body == "Hello {{first_name}}!"
      assert email.position == 1
      assert email.sequence_id == sequence.id
      assert email.status == "active"
    end

    test "creates email with delay", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      attrs = %{
        subject: "Day 3 Email",
        body: "Content",
        position: 2,
        delay_days: 3,
        delay_hours: 12
      }

      assert {:ok, email} = EmailMarketing.create_sequence_email(sequence, attrs)

      assert email.delay_days == 3
      assert email.delay_hours == 12
    end

    test "fails when missing required fields", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      assert {:error, changeset} = EmailMarketing.create_sequence_email(sequence, %{})

      assert "can't be blank" in errors_on(changeset).subject
      assert "can't be blank" in errors_on(changeset).body
      assert "can't be blank" in errors_on(changeset).position
    end

    test "fails with invalid delay_hours", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      attrs = %{subject: "Test", body: "Body", position: 1, delay_hours: 25}

      assert {:error, changeset} = EmailMarketing.create_sequence_email(sequence, attrs)

      assert "must be less than 24" in errors_on(changeset).delay_hours
    end

    test "fails with negative delay_days", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      attrs = %{subject: "Test", body: "Body", position: 1, delay_days: -1}

      assert {:error, changeset} = EmailMarketing.create_sequence_email(sequence, attrs)

      assert "must be greater than or equal to 0" in errors_on(changeset).delay_days
    end

    test "fails with position <= 0", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      attrs = %{subject: "Test", body: "Body", position: 0}

      assert {:error, changeset} = EmailMarketing.create_sequence_email(sequence, attrs)

      assert "must be greater than 0" in errors_on(changeset).position
    end
  end

  describe "update_sequence_email/2" do
    test "updates email with valid attributes", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      assert {:ok, updated} = EmailMarketing.update_sequence_email(email, %{subject: "New Subject"})

      assert updated.subject == "New Subject"
    end
  end

  describe "pause_sequence_email/1" do
    test "pauses an active email", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence, %{status: "active"})

      assert {:ok, paused} = EmailMarketing.pause_sequence_email(email)

      assert paused.status == "paused"
    end
  end

  describe "activate_sequence_email/1" do
    test "activates a paused email", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence, %{status: "paused"})

      assert {:ok, activated} = EmailMarketing.activate_sequence_email(email)

      assert activated.status == "active"
    end
  end

  describe "delete_sequence_email/1" do
    test "deletes a sequence email", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      assert {:ok, _deleted} = EmailMarketing.delete_sequence_email(email)

      assert_raise Ecto.NoResultsError, fn ->
        EmailMarketing.get_sequence_email!(email.id)
      end
    end
  end

  # ============================================================================
  # Sequence Triggering Tests
  # ============================================================================

  describe "trigger_sequence/3" do
    test "triggers sequence and schedules deliveries", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project, %{trigger: "manual", status: "active"})
      _email1 = Fixtures.sequence_email_fixture(sequence, %{position: 1, delay_days: 0})
      _email2 = Fixtures.sequence_email_fixture(sequence, %{position: 2, delay_days: 1})

      assert {:ok, count} = EmailMarketing.trigger_sequence(subscriber, "manual")

      assert count == 2
    end

    test "returns 0 when no matching sequence", %{subscriber: subscriber} do
      assert {:ok, 0} = EmailMarketing.trigger_sequence(subscriber, "nonexistent")
    end

    test "only schedules active emails", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project, %{trigger: "manual", status: "active"})
      _active = Fixtures.sequence_email_fixture(sequence, %{position: 1, status: "active"})
      _paused = Fixtures.sequence_email_fixture(sequence, %{position: 2, status: "paused"})

      assert {:ok, count} = EmailMarketing.trigger_sequence(subscriber, "manual")

      assert count == 1
    end

    test "triggers with trigger_id for lead_magnet_download", %{project: project, subscriber: subscriber} do
      lead_magnet = Fixtures.lead_magnet_fixture(project)

      sequence =
        Fixtures.sequence_fixture(project, %{
          trigger: "lead_magnet_download",
          trigger_id: lead_magnet.id,
          status: "active"
        })

      _email = Fixtures.sequence_email_fixture(sequence, %{position: 1})

      assert {:ok, count} = EmailMarketing.trigger_sequence(subscriber, "lead_magnet_download", lead_magnet.id)

      assert count == 1
    end
  end

  describe "schedule_sequence_for_subscriber/2" do
    test "creates deliveries for all active emails", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email1 = Fixtures.sequence_email_fixture(sequence, %{position: 1, status: "active"})
      email2 = Fixtures.sequence_email_fixture(sequence, %{position: 2, status: "active"})

      assert {:ok, 2} = EmailMarketing.schedule_sequence_for_subscriber(sequence, subscriber)

      # Verify deliveries were created
      delivery1 = Repo.get_by!(EmailDelivery, subscriber_id: subscriber.id, sequence_email_id: email1.id)
      delivery2 = Repo.get_by!(EmailDelivery, subscriber_id: subscriber.id, sequence_email_id: email2.id)

      assert delivery1.status == "scheduled"
      assert delivery2.status == "scheduled"
    end

    test "calculates scheduled_for based on email delay", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence, %{position: 1, delay_days: 1, delay_hours: 6})

      {:ok, _} = EmailMarketing.schedule_sequence_for_subscriber(sequence, subscriber)

      delivery = Repo.get_by!(EmailDelivery, subscriber_id: subscriber.id, sequence_email_id: email.id)

      # Should be scheduled for ~30 hours from now (1 day + 6 hours)
      expected_seconds = 1 * 86_400 + 6 * 3_600
      now = DateTime.utc_now()
      diff = DateTime.diff(delivery.scheduled_for, now, :second)

      # Allow 5 second tolerance
      assert abs(diff - expected_seconds) < 5
    end

    test "handles duplicate subscribers with on_conflict: nothing", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      _email = Fixtures.sequence_email_fixture(sequence, %{position: 1})

      # First scheduling
      assert {:ok, 1} = EmailMarketing.schedule_sequence_for_subscriber(sequence, subscriber)

      # Second scheduling - should be skipped due to unique constraint
      assert {:ok, 0} = EmailMarketing.schedule_sequence_for_subscriber(sequence, subscriber)
    end
  end

  # ============================================================================
  # Delivery Management Tests
  # ============================================================================

  describe "get_delivery!/1" do
    test "returns delivery by ID", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email)

      fetched = EmailMarketing.get_delivery!(delivery.id)

      assert fetched.id == delivery.id
    end

    test "raises when delivery doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        EmailMarketing.get_delivery!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_delivery_with_details!/1" do
    test "returns delivery with preloaded associations", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email)

      fetched = EmailMarketing.get_delivery_with_details!(delivery.id)

      assert fetched.id == delivery.id
      assert fetched.subscriber.id == subscriber.id
      assert fetched.sequence_email.id == email.id
      assert fetched.sequence_email.sequence.id == sequence.id
    end
  end

  describe "list_pending_deliveries/1" do
    test "returns deliveries where scheduled_for <= now and status = scheduled", %{
      project: project,
      subscriber: subscriber
    } do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      # Scheduled for past (should be included)
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second)
      past_delivery = Fixtures.delivery_fixture(subscriber, email, %{scheduled_for: past_time})

      # Different subscriber for future delivery
      subscriber2 = Fixtures.subscriber_fixture(project)
      future_time = DateTime.utc_now() |> DateTime.add(3600, :second)
      _future_delivery = Fixtures.delivery_fixture(subscriber2, email, %{scheduled_for: future_time})

      deliveries = EmailMarketing.list_pending_deliveries()

      assert length(deliveries) == 1
      assert hd(deliveries).id == past_delivery.id
    end

    test "excludes non-scheduled statuses", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second)

      _sent_delivery = Fixtures.delivery_fixture(subscriber, email, %{scheduled_for: past_time, status: "sent"})

      deliveries = EmailMarketing.list_pending_deliveries()

      assert deliveries == []
    end

    test "respects limit parameter", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second)

      for _ <- 1..5 do
        sub = Fixtures.subscriber_fixture(project)
        Fixtures.delivery_fixture(sub, email, %{scheduled_for: past_time})
      end

      deliveries = EmailMarketing.list_pending_deliveries(2)

      assert length(deliveries) == 2
    end

    test "preloads subscriber and sequence_email with sequence", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second)
      _delivery = Fixtures.delivery_fixture(subscriber, email, %{scheduled_for: past_time})

      [fetched] = EmailMarketing.list_pending_deliveries()

      assert fetched.subscriber.email == subscriber.email
      assert fetched.sequence_email.subject == email.subject
      assert fetched.sequence_email.sequence.name == sequence.name
    end
  end

  describe "list_retriable_deliveries/2" do
    test "returns failed deliveries under max attempts", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      retriable =
        Fixtures.delivery_fixture(subscriber, email, %{
          status: "failed",
          attempts: 1,
          error_message: "Connection failed"
        })

      subscriber2 = Fixtures.subscriber_fixture(project)

      _maxed_out =
        Fixtures.delivery_fixture(subscriber2, email, %{
          status: "failed",
          attempts: 3
        })

      deliveries = EmailMarketing.list_retriable_deliveries(3)

      assert length(deliveries) == 1
      assert hd(deliveries).id == retriable.id
    end

    test "respects custom max_attempts", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      _delivery =
        Fixtures.delivery_fixture(subscriber, email, %{
          status: "failed",
          attempts: 4
        })

      # With max 5, should be included
      deliveries = EmailMarketing.list_retriable_deliveries(5)
      assert length(deliveries) == 1

      # With max 3, should be excluded
      deliveries = EmailMarketing.list_retriable_deliveries(3)
      assert deliveries == []
    end
  end

  describe "mark_delivery_pending/1" do
    test "marks delivery as pending and increments attempts", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email, %{attempts: 0})

      assert {:ok, updated} = EmailMarketing.mark_delivery_pending(delivery)

      assert updated.status == "pending"
      assert updated.attempts == 1
    end
  end

  describe "mark_delivery_sent/1" do
    test "marks delivery as sent with timestamp", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email)

      assert {:ok, updated} = EmailMarketing.mark_delivery_sent(delivery)

      assert updated.status == "sent"
      assert updated.sent_at != nil
    end
  end

  describe "mark_delivery_failed/2" do
    test "marks delivery as failed with error message", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email)

      assert {:ok, updated} = EmailMarketing.mark_delivery_failed(delivery, "SMTP connection failed")

      assert updated.status == "failed"
      assert updated.error_message == "SMTP connection failed"
    end
  end

  describe "mark_delivery_opened/1" do
    test "marks delivery as opened with timestamp", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email, %{status: "sent"})

      assert {:ok, updated} = EmailMarketing.mark_delivery_opened(delivery)

      assert updated.status == "opened"
      assert updated.opened_at != nil
    end
  end

  describe "mark_delivery_clicked/1" do
    test "marks delivery as clicked with timestamp", %{project: project, subscriber: subscriber} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)
      delivery = Fixtures.delivery_fixture(subscriber, email, %{status: "opened"})

      assert {:ok, updated} = EmailMarketing.mark_delivery_clicked(delivery)

      assert updated.status == "clicked"
      assert updated.clicked_at != nil
    end
  end

  # ============================================================================
  # Analytics Tests
  # ============================================================================

  describe "sequence_stats/1" do
    test "returns delivery stats grouped by status", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      sub1 = Fixtures.subscriber_fixture(project)
      sub2 = Fixtures.subscriber_fixture(project)
      sub3 = Fixtures.subscriber_fixture(project)

      Fixtures.delivery_fixture(sub1, email, %{status: "sent"})
      Fixtures.delivery_fixture(sub2, email, %{status: "sent"})
      Fixtures.delivery_fixture(sub3, email, %{status: "opened"})

      stats = EmailMarketing.sequence_stats(sequence)

      assert stats["sent"] == 2
      assert stats["opened"] == 1
    end

    test "returns empty map when no deliveries", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)

      stats = EmailMarketing.sequence_stats(sequence)

      assert stats == %{}
    end
  end

  describe "email_stats/1" do
    test "returns delivery stats for specific email", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      sub1 = Fixtures.subscriber_fixture(project)
      sub2 = Fixtures.subscriber_fixture(project)

      Fixtures.delivery_fixture(sub1, email, %{status: "scheduled"})
      Fixtures.delivery_fixture(sub2, email, %{status: "failed"})

      stats = EmailMarketing.email_stats(email)

      assert stats["scheduled"] == 1
      assert stats["failed"] == 1
    end
  end

  describe "delivery_count/2" do
    test "returns total deliveries for project", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      sub1 = Fixtures.subscriber_fixture(project)
      sub2 = Fixtures.subscriber_fixture(project)

      Fixtures.delivery_fixture(sub1, email, %{status: "sent"})
      Fixtures.delivery_fixture(sub2, email, %{status: "scheduled"})

      count = EmailMarketing.delivery_count(project)

      assert count == 2
    end

    test "filters by status when provided", %{project: project} do
      sequence = Fixtures.sequence_fixture(project)
      email = Fixtures.sequence_email_fixture(sequence)

      sub1 = Fixtures.subscriber_fixture(project)
      sub2 = Fixtures.subscriber_fixture(project)

      Fixtures.delivery_fixture(sub1, email, %{status: "sent"})
      Fixtures.delivery_fixture(sub2, email, %{status: "scheduled"})

      assert EmailMarketing.delivery_count(project, "sent") == 1
      assert EmailMarketing.delivery_count(project, "scheduled") == 1
      assert EmailMarketing.delivery_count(project, "failed") == 0
    end

    test "returns 0 for project with no deliveries", %{project: project} do
      assert EmailMarketing.delivery_count(project) == 0
    end
  end

  # ============================================================================
  # Schema Helper Tests
  # ============================================================================

  describe "EmailSequence schema helpers" do
    test "valid_triggers/0 returns all valid trigger types" do
      triggers = EmailSequence.valid_triggers()

      assert "lead_magnet_download" in triggers
      assert "subscriber_confirmed" in triggers
      assert "manual" in triggers
    end

    test "valid_statuses/0 returns all valid statuses" do
      statuses = EmailSequence.valid_statuses()

      assert "draft" in statuses
      assert "active" in statuses
      assert "paused" in statuses
    end
  end

  describe "SequenceEmail schema helpers" do
    test "valid_statuses/0 returns all valid statuses" do
      statuses = SequenceEmail.valid_statuses()

      assert "active" in statuses
      assert "paused" in statuses
    end

    test "total_delay_seconds/1 calculates total seconds" do
      email = %SequenceEmail{delay_days: 2, delay_hours: 6}

      seconds = SequenceEmail.total_delay_seconds(email)

      # 2 days * 86400 + 6 hours * 3600 = 172800 + 21600 = 194400
      assert seconds == 194_400
    end

    test "scheduled_send_time/2 calculates send time" do
      email = %SequenceEmail{delay_days: 1, delay_hours: 0}
      start = ~U[2024-01-15 10:00:00Z]

      scheduled = SequenceEmail.scheduled_send_time(email, start)

      assert scheduled == ~U[2024-01-16 10:00:00Z]
    end
  end

  describe "EmailDelivery schema helpers" do
    test "valid_statuses/0 returns all valid statuses" do
      statuses = EmailDelivery.valid_statuses()

      assert "scheduled" in statuses
      assert "pending" in statuses
      assert "sent" in statuses
      assert "failed" in statuses
      assert "opened" in statuses
      assert "clicked" in statuses
    end

    test "ready_to_send?/1 returns true for past scheduled deliveries" do
      past = DateTime.utc_now() |> DateTime.add(-60, :second)
      delivery = %EmailDelivery{status: "scheduled", scheduled_for: past}

      assert EmailDelivery.ready_to_send?(delivery)
    end

    test "ready_to_send?/1 returns false for future scheduled deliveries" do
      future = DateTime.utc_now() |> DateTime.add(3600, :second)
      delivery = %EmailDelivery{status: "scheduled", scheduled_for: future}

      refute EmailDelivery.ready_to_send?(delivery)
    end

    test "ready_to_send?/1 returns false for non-scheduled status" do
      past = DateTime.utc_now() |> DateTime.add(-60, :second)
      delivery = %EmailDelivery{status: "sent", scheduled_for: past}

      refute EmailDelivery.ready_to_send?(delivery)
    end

    test "retriable?/1 returns true for failed under max attempts" do
      delivery = %EmailDelivery{status: "failed", attempts: 1}

      assert EmailDelivery.retriable?(delivery)
    end

    test "retriable?/1 returns false for failed at max attempts" do
      delivery = %EmailDelivery{status: "failed", attempts: 3}

      refute EmailDelivery.retriable?(delivery, 3)
    end

    test "retriable?/1 returns false for non-failed status" do
      delivery = %EmailDelivery{status: "sent", attempts: 1}

      refute EmailDelivery.retriable?(delivery)
    end
  end
end
