defmodule MarketMind.LeadMagnets.LeadMagnet do
  @moduledoc """
  Schema for lead magnets - downloadable content assets created from blog posts.

  Lead magnets are transformed versions of existing content designed to capture
  email subscribers. They can be checklists, guides, cheatsheets, templates, or worksheets.

  Lifecycle: draft → active → archived
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(checklist guide cheatsheet template worksheet)
  @valid_statuses ~w(draft active archived)

  schema "lead_magnets" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :magnet_type, :string
    field :status, :string, default: "draft"

    # The actual lead magnet content (markdown)
    field :content, :string

    # Landing page customization
    field :headline, :string
    field :subheadline, :string
    field :cta_text, :string, default: "Get Free Access"
    field :thank_you_message, :string
    field :download_url, :string

    # SEO
    field :meta_description, :string

    # Stats
    field :download_count, :integer, default: 0
    field :conversion_rate, :decimal

    # Relationships
    belongs_to :source_content, MarketMind.Content.Content, foreign_key: :content_id
    belongs_to :project, MarketMind.Products.Project

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid lead magnet types.
  """
  def valid_types, do: @valid_types

  @doc """
  Returns the list of valid statuses.
  """
  def valid_statuses, do: @valid_statuses

  @doc """
  Changeset for creating or updating a lead magnet.
  """
  def changeset(lead_magnet, attrs) do
    lead_magnet
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :magnet_type,
      :status,
      :content,
      :headline,
      :subheadline,
      :cta_text,
      :thank_you_message,
      :download_url,
      :meta_description,
      :content_id,
      :project_id
    ])
    |> validate_required([:title, :magnet_type, :project_id])
    |> validate_inclusion(:magnet_type, @valid_types, message: "must be one of: #{Enum.join(@valid_types, ", ")}")
    |> validate_inclusion(:status, @valid_statuses)
    |> generate_slug()
    |> unique_constraint([:project_id, :slug])
  end

  @doc """
  Changeset for activating a lead magnet.
  """
  def activate_changeset(lead_magnet) do
    lead_magnet
    |> change(%{status: "active"})
  end

  @doc """
  Changeset for archiving a lead magnet.
  """
  def archive_changeset(lead_magnet) do
    lead_magnet
    |> change(%{status: "archived"})
  end

  @doc """
  Changeset for incrementing the download count.
  """
  def increment_download_changeset(lead_magnet) do
    lead_magnet
    |> change(%{download_count: (lead_magnet.download_count || 0) + 1})
  end

  # Private functions

  defp generate_slug(changeset) do
    case get_change(changeset, :title) do
      nil ->
        changeset

      title ->
        slug =
          title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
