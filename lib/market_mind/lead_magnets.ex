defmodule MarketMind.LeadMagnets do
  @moduledoc """
  The LeadMagnets context manages lead magnet content and landing pages.

  This module provides functions for:
  - Creating and managing lead magnets from blog content
  - Landing page configuration
  - Download tracking and analytics
  - Lead magnet activation lifecycle
  """
  import Ecto.Query
  alias MarketMind.Repo
  alias MarketMind.LeadMagnets.LeadMagnet
  alias MarketMind.Products.Project

  # ============================================================================
  # Lead Magnet CRUD
  # ============================================================================

  @doc """
  Lists all lead magnets for a project.
  Returns lead magnets ordered by most recent first.
  """
  def list_lead_magnets(%Project{} = project) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id)
    |> order_by([lm], desc: lm.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists only active lead magnets for a project.
  Useful for public-facing pages.
  """
  def list_active_lead_magnets(%Project{} = project) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id and lm.status == "active")
    |> order_by([lm], desc: lm.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single lead magnet by ID.
  Raises Ecto.NoResultsError if not found.
  """
  def get_lead_magnet!(id), do: Repo.get!(LeadMagnet, id)

  @doc """
  Gets a lead magnet by slug within a project.
  Returns nil if not found.
  """
  def get_lead_magnet_by_slug(%Project{} = project, slug) when is_binary(slug) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id and lm.slug == ^slug)
    |> Repo.one()
  end

  @doc """
  Gets an active lead magnet by slug within a project.
  Raises Ecto.NoResultsError if not found or not active.
  Used for public landing pages.
  """
  def get_active_lead_magnet_by_slug!(%Project{} = project, slug) when is_binary(slug) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id and lm.slug == ^slug and lm.status == "active")
    |> Repo.one!()
  end

  @doc """
  Gets an active lead magnet by project slug and lead magnet slug.
  Used for public-facing routes.
  Raises Ecto.NoResultsError if not found.
  """
  def get_active_lead_magnet_by_slugs!(project_slug, lead_magnet_slug) do
    LeadMagnet
    |> join(:inner, [lm], p in Project, on: lm.project_id == p.id)
    |> where([lm, p], p.slug == ^project_slug and lm.slug == ^lead_magnet_slug and lm.status == "active")
    |> Repo.one!()
    |> Repo.preload(:project)
  end

  @doc """
  Creates a new lead magnet.
  """
  def create_lead_magnet(%Project{} = project, attrs) do
    %LeadMagnet{}
    |> LeadMagnet.changeset(Map.put(attrs, :project_id, project.id))
    |> Repo.insert()
  end

  @doc """
  Updates a lead magnet.
  """
  def update_lead_magnet(%LeadMagnet{} = lead_magnet, attrs) do
    lead_magnet
    |> LeadMagnet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lead magnet.
  """
  def delete_lead_magnet(%LeadMagnet{} = lead_magnet) do
    Repo.delete(lead_magnet)
  end

  # ============================================================================
  # Status Management
  # ============================================================================

  @doc """
  Activates a lead magnet, making it available on public landing pages.
  """
  def activate_lead_magnet(%LeadMagnet{} = lead_magnet) do
    lead_magnet
    |> LeadMagnet.activate_changeset()
    |> Repo.update()
  end

  @doc """
  Archives a lead magnet, removing it from public visibility.
  """
  def archive_lead_magnet(%LeadMagnet{} = lead_magnet) do
    lead_magnet
    |> LeadMagnet.archive_changeset()
    |> Repo.update()
  end

  # ============================================================================
  # Download Tracking
  # ============================================================================

  @doc """
  Increments the download count for a lead magnet.
  Called when a subscriber successfully signs up.
  """
  def increment_download_count(%LeadMagnet{} = lead_magnet) do
    lead_magnet
    |> LeadMagnet.increment_download_changeset()
    |> Repo.update()
  end

  @doc """
  Updates the conversion rate for a lead magnet.
  Conversion rate = downloads / page views (requires analytics integration).
  """
  def update_conversion_rate(%LeadMagnet{} = lead_magnet, page_views) when page_views > 0 do
    rate = Decimal.div(Decimal.new(lead_magnet.download_count), Decimal.new(page_views))

    lead_magnet
    |> Ecto.Changeset.change(%{conversion_rate: rate})
    |> Repo.update()
  end

  def update_conversion_rate(%LeadMagnet{} = lead_magnet, _page_views) do
    {:ok, lead_magnet}
  end

  # ============================================================================
  # Analytics
  # ============================================================================

  @doc """
  Returns the total number of lead magnets for a project.
  """
  def lead_magnet_count(%Project{} = project, status \\ nil) do
    query = from(lm in LeadMagnet, where: lm.project_id == ^project.id)

    query =
      if status do
        where(query, [lm], lm.status == ^status)
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @doc """
  Returns the total downloads across all lead magnets for a project.
  """
  def total_downloads(%Project{} = project) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id)
    |> select([lm], sum(lm.download_count))
    |> Repo.one()
    |> Kernel.||(0)
  end

  @doc """
  Returns lead magnets by type for a project.
  """
  def lead_magnets_by_type(%Project{} = project) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id)
    |> group_by([lm], lm.magnet_type)
    |> select([lm], {lm.magnet_type, count(lm.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the top performing lead magnets by download count.
  """
  def top_performing_lead_magnets(%Project{} = project, limit \\ 5) do
    LeadMagnet
    |> where([lm], lm.project_id == ^project.id and lm.status == "active")
    |> order_by([lm], desc: lm.download_count)
    |> limit(^limit)
    |> Repo.all()
  end

  # ============================================================================
  # Content Relationship
  # ============================================================================

  @doc """
  Gets a lead magnet with its source content preloaded.
  """
  def get_lead_magnet_with_source!(id) do
    LeadMagnet
    |> Repo.get!(id)
    |> Repo.preload(:source_content)
  end

  @doc """
  Lists lead magnets created from a specific piece of content.
  """
  def list_lead_magnets_for_content(content_id) do
    LeadMagnet
    |> where([lm], lm.content_id == ^content_id)
    |> order_by([lm], desc: lm.inserted_at)
    |> Repo.all()
  end
end
