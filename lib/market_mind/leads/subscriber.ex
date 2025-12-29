defmodule MarketMind.Leads.Subscriber do
  @moduledoc """
  Subscriber schema for email list management.

  Subscribers are captured through lead magnets and other signup forms.
  Each subscriber belongs to a project and can have:
  - Status tracking (pending → confirmed → unsubscribed)
  - Source attribution (lead_magnet, blog, manual)
  - GDPR-compliant consent tracking
  - Tags for segmentation
  - Metadata for additional capture data
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(pending confirmed unsubscribed)
  @valid_sources ~w(lead_magnet blog manual api)

  schema "subscribers" do
    field :email, :string
    field :first_name, :string
    field :status, :string, default: "pending"
    field :confirmed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime
    field :source, :string
    field :source_id, :binary_id
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    # GDPR Compliance
    field :consent_given_at, :utc_datetime
    field :consent_ip, :string
    field :consent_user_agent, :string

    belongs_to :project, MarketMind.Products.Project

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new subscriber.
  Normalizes email to lowercase and validates required fields.
  """
  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [
      :email,
      :first_name,
      :status,
      :source,
      :source_id,
      :tags,
      :metadata,
      :consent_given_at,
      :consent_ip,
      :consent_user_agent,
      :project_id
    ])
    |> validate_required([:email, :project_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:source, @valid_sources, message: "must be one of: #{Enum.join(@valid_sources, ", ")}")
    |> normalize_email()
    |> unique_constraint([:email, :project_id], message: "is already subscribed")
  end

  @doc """
  Changeset for confirming a subscriber (double opt-in).
  """
  def confirm_changeset(subscriber) do
    subscriber
    |> change(%{
      status: "confirmed",
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Changeset for unsubscribing.
  """
  def unsubscribe_changeset(subscriber) do
    subscriber
    |> change(%{
      status: "unsubscribed",
      unsubscribed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Changeset for adding tags to a subscriber.
  """
  def add_tags_changeset(subscriber, new_tags) when is_list(new_tags) do
    current_tags = subscriber.tags || []
    updated_tags = Enum.uniq(current_tags ++ new_tags)

    subscriber
    |> change(%{tags: updated_tags})
  end

  @doc """
  Changeset for removing tags from a subscriber.
  """
  def remove_tags_changeset(subscriber, tags_to_remove) when is_list(tags_to_remove) do
    current_tags = subscriber.tags || []
    updated_tags = current_tags -- tags_to_remove

    subscriber
    |> change(%{tags: updated_tags})
  end

  # Private functions

  defp normalize_email(changeset) do
    case get_change(changeset, :email) do
      nil -> changeset
      email -> put_change(changeset, :email, String.downcase(String.trim(email)))
    end
  end
end
