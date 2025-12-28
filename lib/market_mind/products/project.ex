defmodule MarketMind.Products.Project do
  @moduledoc """
  Project schema representing a SaaS product to be analyzed.

  A project contains:
  - Basic product information (name, URL, description)
  - A unique slug for URL-friendly identification
  - Analysis status tracking (pending → queued → analyzing → completed/failed)
  - Analysis data stored as JSONB containing extracted marketing intelligence
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(pending queued analyzing completed failed)

  schema "projects" do
    field :name, :string
    field :slug, :string
    field :url, :string
    field :description, :string
    field :analysis_status, :string, default: "pending"
    field :analysis_data, :map
    field :analyzed_at, :utc_datetime
    field :brand_voice, :string
    field :tone, :string

    belongs_to :user, MarketMind.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new project.
  Generates a unique slug from the name and sets default analysis status.
  """
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :url, :description, :user_id])
    |> validate_required([:name, :url, :user_id])
    |> validate_url(:url)
    |> generate_slug()
    |> put_default_status()
  end

  @doc """
  Creates a changeset for updating a project.
  Does not allow changing slug or user_id.
  """
  def update_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :url, :description])
    |> validate_required([:name, :url])
    |> validate_url(:url)
  end

  @doc """
  Creates a changeset for updating analysis status and data.
  Sets analyzed_at timestamp when status is "completed".
  """
  def analysis_changeset(project, attrs) do
    project
    |> cast(attrs, [:analysis_status, :analysis_data])
    |> validate_inclusion(:analysis_status, @valid_statuses)
    |> maybe_set_analyzed_at()
  end

  # Private functions

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      if valid_url?(url) do
        []
      else
        [{field, "must be a valid URL"}]
      end
    end)
  end

  defp valid_url?(url) when is_binary(url) do
    String.starts_with?(url, "http://") or String.starts_with?(url, "https://")
  end

  defp valid_url?(_), do: false

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        base_slug = slugify(name)
        unique_slug = "#{base_slug}-#{random_suffix()}"
        put_change(changeset, :slug, unique_slug)
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp random_suffix do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16(case: :lower)
  end

  defp put_default_status(changeset) do
    if get_field(changeset, :analysis_status) do
      changeset
    else
      put_change(changeset, :analysis_status, "pending")
    end
  end

  defp maybe_set_analyzed_at(changeset) do
    if get_change(changeset, :analysis_status) == "completed" do
      put_change(changeset, :analyzed_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end
end
