defmodule MarketMind.EmailMarketing.EmailSequence do
  @moduledoc """
  Schema for email sequences - automated email campaigns triggered by events.

  Sequences are triggered by specific events:
  - lead_magnet_download: When a subscriber downloads a lead magnet
  - subscriber_confirmed: When a subscriber confirms their email
  - manual: Manually triggered by admin

  Lifecycle: draft → active → paused
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_triggers ~w(lead_magnet_download subscriber_confirmed manual)
  @valid_statuses ~w(draft active paused)

  schema "email_sequences" do
    field :name, :string
    field :description, :string
    field :trigger, :string
    field :trigger_id, :binary_id
    field :status, :string, default: "draft"

    belongs_to :project, MarketMind.Products.Project
    has_many :emails, MarketMind.EmailMarketing.SequenceEmail, foreign_key: :sequence_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid trigger types.
  """
  def valid_triggers, do: @valid_triggers

  @doc """
  Returns the list of valid statuses.
  """
  def valid_statuses, do: @valid_statuses

  @doc """
  Changeset for creating or updating an email sequence.
  """
  def changeset(sequence, attrs) do
    sequence
    |> cast(attrs, [:name, :description, :trigger, :trigger_id, :status, :project_id])
    |> validate_required([:name, :trigger, :project_id])
    |> validate_inclusion(:trigger, @valid_triggers, message: "must be one of: #{Enum.join(@valid_triggers, ", ")}")
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_trigger_id()
  end

  @doc """
  Changeset for activating a sequence.
  """
  def activate_changeset(sequence) do
    sequence
    |> change(%{status: "active"})
  end

  @doc """
  Changeset for pausing a sequence.
  """
  def pause_changeset(sequence) do
    sequence
    |> change(%{status: "paused"})
  end

  # Private functions

  defp validate_trigger_id(changeset) do
    trigger = get_field(changeset, :trigger)
    trigger_id = get_field(changeset, :trigger_id)

    case trigger do
      "lead_magnet_download" when is_nil(trigger_id) ->
        add_error(changeset, :trigger_id, "is required for lead_magnet_download trigger")

      _ ->
        changeset
    end
  end
end
