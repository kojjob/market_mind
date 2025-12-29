defmodule MarketMind.EmailMarketing do
  @moduledoc """
  The EmailMarketing context manages automated email sequences.

  This module provides functions for:
  - Creating and managing email sequences
  - Adding emails to sequences with delays
  - Triggering sequences for subscribers
  - Scheduling and tracking email deliveries
  - Analytics and reporting
  """
  import Ecto.Query
  alias MarketMind.Repo
  alias MarketMind.EmailMarketing.{EmailSequence, SequenceEmail, EmailDelivery}
  alias MarketMind.Leads.Subscriber
  alias MarketMind.Products.Project

  # ============================================================================
  # Sequence CRUD
  # ============================================================================

  @doc """
  Lists all sequences for a project.
  """
  def list_sequences(%Project{} = project) do
    EmailSequence
    |> where([s], s.project_id == ^project.id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists active sequences for a project.
  """
  def list_active_sequences(%Project{} = project) do
    EmailSequence
    |> where([s], s.project_id == ^project.id and s.status == "active")
    |> Repo.all()
  end

  @doc """
  Gets a sequence by ID.
  """
  def get_sequence!(id), do: Repo.get!(EmailSequence, id)

  @doc """
  Gets a sequence with its emails preloaded.
  """
  def get_sequence_with_emails!(id) do
    EmailSequence
    |> Repo.get!(id)
    |> Repo.preload(emails: from(e in SequenceEmail, order_by: e.position))
  end

  @doc """
  Finds an active sequence by trigger type for a project.
  """
  def find_sequence_by_trigger(%Project{} = project, trigger, trigger_id \\ nil) do
    query =
      EmailSequence
      |> where([s], s.project_id == ^project.id)
      |> where([s], s.trigger == ^trigger)
      |> where([s], s.status == "active")

    query =
      if trigger_id do
        where(query, [s], s.trigger_id == ^trigger_id)
      else
        query
      end

    Repo.one(query)
  end

  @doc """
  Creates a new sequence.
  """
  def create_sequence(%Project{} = project, attrs) do
    %EmailSequence{}
    |> EmailSequence.changeset(Map.put(attrs, :project_id, project.id))
    |> Repo.insert()
  end

  @doc """
  Updates a sequence.
  """
  def update_sequence(%EmailSequence{} = sequence, attrs) do
    sequence
    |> EmailSequence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Activates a sequence.
  """
  def activate_sequence(%EmailSequence{} = sequence) do
    sequence
    |> EmailSequence.activate_changeset()
    |> Repo.update()
  end

  @doc """
  Pauses a sequence.
  """
  def pause_sequence(%EmailSequence{} = sequence) do
    sequence
    |> EmailSequence.pause_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes a sequence.
  """
  def delete_sequence(%EmailSequence{} = sequence) do
    Repo.delete(sequence)
  end

  # ============================================================================
  # Sequence Email CRUD
  # ============================================================================

  @doc """
  Lists all emails in a sequence, ordered by position.
  """
  def list_sequence_emails(%EmailSequence{} = sequence) do
    SequenceEmail
    |> where([e], e.sequence_id == ^sequence.id)
    |> order_by([e], asc: e.position)
    |> Repo.all()
  end

  @doc """
  Gets a sequence email by ID.
  """
  def get_sequence_email!(id), do: Repo.get!(SequenceEmail, id)

  @doc """
  Creates a new email in a sequence.
  """
  def create_sequence_email(%EmailSequence{} = sequence, attrs) do
    %SequenceEmail{}
    |> SequenceEmail.changeset(Map.put(attrs, :sequence_id, sequence.id))
    |> Repo.insert()
  end

  @doc """
  Updates a sequence email.
  """
  def update_sequence_email(%SequenceEmail{} = email, attrs) do
    email
    |> SequenceEmail.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Pauses a sequence email.
  """
  def pause_sequence_email(%SequenceEmail{} = email) do
    email
    |> SequenceEmail.pause_changeset()
    |> Repo.update()
  end

  @doc """
  Activates a sequence email.
  """
  def activate_sequence_email(%SequenceEmail{} = email) do
    email
    |> SequenceEmail.activate_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes a sequence email.
  """
  def delete_sequence_email(%SequenceEmail{} = email) do
    Repo.delete(email)
  end

  # ============================================================================
  # Sequence Triggering
  # ============================================================================

  @doc """
  Triggers a sequence for a subscriber.

  This finds an active sequence matching the trigger type and schedules
  all emails in the sequence for delivery to the subscriber.

  ## Parameters
    - subscriber: The subscriber to send emails to
    - trigger: The trigger type (e.g., "lead_magnet_download")
    - trigger_id: Optional ID for trigger-specific sequences

  ## Returns
    - {:ok, delivery_count} on success
    - {:ok, 0} if no matching sequence found
    - {:error, reason} on failure
  """
  def trigger_sequence(%Subscriber{} = subscriber, trigger, trigger_id \\ nil) do
    project = Repo.preload(subscriber, :project).project

    case find_sequence_by_trigger(project, trigger, trigger_id) do
      nil ->
        {:ok, 0}

      sequence ->
        schedule_sequence_for_subscriber(sequence, subscriber)
    end
  end

  @doc """
  Schedules all emails in a sequence for a subscriber.
  """
  def schedule_sequence_for_subscriber(%EmailSequence{} = sequence, %Subscriber{} = subscriber) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    emails =
      SequenceEmail
      |> where([e], e.sequence_id == ^sequence.id and e.status == "active")
      |> order_by([e], asc: e.position)
      |> Repo.all()

    deliveries =
      Enum.map(emails, fn email ->
        scheduled_for = SequenceEmail.scheduled_send_time(email, now)

        %{
          id: Ecto.UUID.generate(),
          status: "scheduled",
          scheduled_for: scheduled_for,
          subscriber_id: subscriber.id,
          sequence_email_id: email.id,
          attempts: 0,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(EmailDelivery, deliveries, on_conflict: :nothing, conflict_target: [:subscriber_id, :sequence_email_id])

    {:ok, count}
  end

  # ============================================================================
  # Delivery Management
  # ============================================================================

  @doc """
  Gets a delivery by ID.
  """
  def get_delivery!(id), do: Repo.get!(EmailDelivery, id)

  @doc """
  Gets a delivery with preloaded associations.
  """
  def get_delivery_with_details!(id) do
    EmailDelivery
    |> Repo.get!(id)
    |> Repo.preload([:subscriber, sequence_email: :sequence])
  end

  @doc """
  Lists pending deliveries that are ready to be sent.
  Returns deliveries where scheduled_for <= now and status = "scheduled".
  """
  def list_pending_deliveries(limit \\ 100) do
    now = DateTime.utc_now()

    EmailDelivery
    |> where([d], d.status == "scheduled" and d.scheduled_for <= ^now)
    |> order_by([d], asc: d.scheduled_for)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload([:subscriber, sequence_email: :sequence])
  end

  @doc """
  Lists failed deliveries that can be retried.
  """
  def list_retriable_deliveries(max_attempts \\ 3, limit \\ 100) do
    EmailDelivery
    |> where([d], d.status == "failed" and d.attempts < ^max_attempts)
    |> order_by([d], asc: d.updated_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload([:subscriber, sequence_email: :sequence])
  end

  @doc """
  Marks a delivery as pending (being processed).
  """
  def mark_delivery_pending(%EmailDelivery{} = delivery) do
    delivery
    |> EmailDelivery.pending_changeset()
    |> Repo.update()
  end

  @doc """
  Marks a delivery as sent.
  """
  def mark_delivery_sent(%EmailDelivery{} = delivery) do
    delivery
    |> EmailDelivery.sent_changeset()
    |> Repo.update()
  end

  @doc """
  Marks a delivery as failed.
  """
  def mark_delivery_failed(%EmailDelivery{} = delivery, error_message) do
    delivery
    |> EmailDelivery.failed_changeset(error_message)
    |> Repo.update()
  end

  @doc """
  Marks a delivery as opened.
  """
  def mark_delivery_opened(%EmailDelivery{} = delivery) do
    delivery
    |> EmailDelivery.opened_changeset()
    |> Repo.update()
  end

  @doc """
  Marks a delivery as clicked.
  """
  def mark_delivery_clicked(%EmailDelivery{} = delivery) do
    delivery
    |> EmailDelivery.clicked_changeset()
    |> Repo.update()
  end

  # ============================================================================
  # Scheduling (for Oban worker)
  # ============================================================================

  @doc """
  Schedules Oban jobs for all pending deliveries.
  Called by the SequenceSchedulerWorker.
  """
  @spec schedule_pending_emails() :: {:ok, non_neg_integer()} | {:error, term()}
  def schedule_pending_emails do
    deliveries = list_pending_deliveries()

    Enum.each(deliveries, fn delivery ->
      %{delivery_id: delivery.id}
      |> MarketMind.Workers.EmailDeliveryWorker.new()
      |> Oban.insert()
    end)

    {:ok, length(deliveries)}
  rescue
    e -> {:error, e}
  end

  # ============================================================================
  # Analytics
  # ============================================================================

  @doc """
  Returns delivery stats for a sequence.
  """
  def sequence_stats(%EmailSequence{} = sequence) do
    email_ids =
      SequenceEmail
      |> where([e], e.sequence_id == ^sequence.id)
      |> select([e], e.id)
      |> Repo.all()

    EmailDelivery
    |> where([d], d.sequence_email_id in ^email_ids)
    |> group_by([d], d.status)
    |> select([d], {d.status, count(d.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns delivery stats for a sequence email.
  """
  def email_stats(%SequenceEmail{} = email) do
    EmailDelivery
    |> where([d], d.sequence_email_id == ^email.id)
    |> group_by([d], d.status)
    |> select([d], {d.status, count(d.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the total number of deliveries for a project.
  """
  def delivery_count(%Project{} = project, status \\ nil) do
    sequence_ids =
      EmailSequence
      |> where([s], s.project_id == ^project.id)
      |> select([s], s.id)
      |> Repo.all()

    email_ids =
      SequenceEmail
      |> where([e], e.sequence_id in ^sequence_ids)
      |> select([e], e.id)
      |> Repo.all()

    query = from(d in EmailDelivery, where: d.sequence_email_id in ^email_ids)

    query =
      if status do
        where(query, [d], d.status == ^status)
      else
        query
      end

    Repo.aggregate(query, :count)
  end
end
