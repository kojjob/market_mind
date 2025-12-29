defmodule MarketMind.EmailMarketing.EmailDelivery do
  @moduledoc """
  Schema for tracking individual email deliveries to subscribers.

  Each delivery represents one email being sent (or scheduled to be sent)
  to one subscriber. This allows tracking of:
  - When the email is scheduled to be sent
  - Delivery status (scheduled → pending → sent/failed)
  - Engagement tracking (opened, clicked)
  - Retry attempts and error messages

  Status lifecycle:
  - scheduled: Initial state, waiting for scheduled_for time
  - pending: Being processed by the email worker
  - sent: Successfully delivered to email provider
  - failed: Delivery failed after max attempts
  - opened: Email was opened (tracked via pixel)
  - clicked: Link in email was clicked
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(scheduled pending sent failed opened clicked)

  schema "email_deliveries" do
    field :status, :string, default: "scheduled"
    field :scheduled_for, :utc_datetime
    field :sent_at, :utc_datetime
    field :opened_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :error_message, :string
    field :attempts, :integer, default: 0

    belongs_to :subscriber, MarketMind.Leads.Subscriber
    belongs_to :sequence_email, MarketMind.EmailMarketing.SequenceEmail

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid statuses.
  """
  def valid_statuses, do: @valid_statuses

  @doc """
  Changeset for creating a new email delivery.
  """
  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [:status, :scheduled_for, :subscriber_id, :sequence_email_id])
    |> validate_required([:scheduled_for, :subscriber_id, :sequence_email_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:subscriber_id, :sequence_email_id])
  end

  @doc """
  Changeset for marking a delivery as pending (about to be processed).
  """
  def pending_changeset(delivery) do
    delivery
    |> change(%{
      status: "pending",
      attempts: (delivery.attempts || 0) + 1
    })
  end

  @doc """
  Changeset for marking a delivery as sent.
  """
  def sent_changeset(delivery) do
    delivery
    |> change(%{
      status: "sent",
      sent_at: DateTime.utc_now()
    })
  end

  @doc """
  Changeset for marking a delivery as failed.
  """
  def failed_changeset(delivery, error_message) do
    delivery
    |> change(%{
      status: "failed",
      error_message: error_message
    })
  end

  @doc """
  Changeset for marking a delivery as opened.
  """
  def opened_changeset(delivery) do
    delivery
    |> change(%{
      status: "opened",
      opened_at: DateTime.utc_now()
    })
  end

  @doc """
  Changeset for marking a delivery as clicked.
  """
  def clicked_changeset(delivery) do
    delivery
    |> change(%{
      status: "clicked",
      clicked_at: DateTime.utc_now()
    })
  end

  @doc """
  Returns true if the delivery is ready to be sent.
  """
  def ready_to_send?(%__MODULE__{status: status, scheduled_for: scheduled_for}) do
    status == "scheduled" && DateTime.compare(scheduled_for, DateTime.utc_now()) in [:lt, :eq]
  end

  @doc """
  Returns true if the delivery can be retried.
  """
  def retriable?(%__MODULE__{status: status, attempts: attempts}, max_attempts \\ 3) do
    status == "failed" && attempts < max_attempts
  end
end
