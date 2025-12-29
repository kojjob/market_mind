defmodule MarketMind.EmailMarketing.SequenceEmail do
  @moduledoc """
  Schema for individual emails within a sequence.

  Each email has a delay (days + hours) from the sequence trigger point.
  Emails are ordered by position within the sequence.

  The body can contain variables that are replaced at send time:
  - {{first_name}} - Subscriber's first name (or "there" if not set)
  - {{email}} - Subscriber's email address
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(active paused)

  schema "sequence_emails" do
    field :subject, :string
    field :body, :string
    field :delay_days, :integer, default: 0
    field :delay_hours, :integer, default: 0
    field :position, :integer
    field :status, :string, default: "active"

    belongs_to :sequence, MarketMind.EmailMarketing.EmailSequence
    has_many :deliveries, MarketMind.EmailMarketing.EmailDelivery

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid statuses.
  """
  def valid_statuses, do: @valid_statuses

  @doc """
  Changeset for creating or updating a sequence email.
  """
  def changeset(email, attrs) do
    email
    |> cast(attrs, [:subject, :body, :delay_days, :delay_hours, :position, :status, :sequence_id])
    |> validate_required([:subject, :body, :position, :sequence_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:delay_days, greater_than_or_equal_to: 0)
    |> validate_number(:delay_hours, greater_than_or_equal_to: 0, less_than: 24)
    |> validate_number(:position, greater_than: 0)
    |> unique_constraint([:sequence_id, :position])
  end

  @doc """
  Changeset for pausing an email.
  """
  def pause_changeset(email) do
    email
    |> change(%{status: "paused"})
  end

  @doc """
  Changeset for activating an email.
  """
  def activate_changeset(email) do
    email
    |> change(%{status: "active"})
  end

  @doc """
  Calculates the total delay in seconds from sequence start.
  """
  def total_delay_seconds(%__MODULE__{delay_days: days, delay_hours: hours}) do
    days * 86_400 + hours * 3_600
  end

  @doc """
  Calculates when this email should be sent based on sequence start time.
  """
  def scheduled_send_time(%__MODULE__{} = email, sequence_started_at) do
    DateTime.add(sequence_started_at, total_delay_seconds(email), :second)
  end
end
