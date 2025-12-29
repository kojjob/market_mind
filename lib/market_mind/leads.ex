defmodule MarketMind.Leads do
  @moduledoc """
  The Leads context manages email subscribers and lead capture.

  This module provides functions for:
  - Creating and managing subscribers
  - Double opt-in confirmation flow
  - Unsubscribe handling
  - Subscriber segmentation via tags
  - Analytics and reporting
  """
  import Ecto.Query
  alias MarketMind.Repo
  alias MarketMind.Leads.Subscriber
  alias MarketMind.Products.Project

  # ============================================================================
  # Subscriber CRUD
  # ============================================================================

  @doc """
  Lists all subscribers for a project.
  Returns subscribers ordered by most recent first.
  """
  def list_subscribers(%Project{} = project) do
    Subscriber
    |> where([s], s.project_id == ^project.id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists only confirmed subscribers for a project.
  Useful for email campaigns.
  """
  def list_confirmed_subscribers(%Project{} = project) do
    Subscriber
    |> where([s], s.project_id == ^project.id and s.status == "confirmed")
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists subscribers with a specific tag.
  """
  def list_subscribers_by_tag(%Project{} = project, tag) when is_binary(tag) do
    Subscriber
    |> where([s], s.project_id == ^project.id and ^tag in s.tags)
    |> where([s], s.status == "confirmed")
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single subscriber by ID.
  Raises Ecto.NoResultsError if not found.
  """
  def get_subscriber!(id), do: Repo.get!(Subscriber, id)

  @doc """
  Gets a single subscriber by ID.
  Returns nil if not found.
  """
  def get_subscriber(id), do: Repo.get(Subscriber, id)

  @doc """
  Gets a subscriber by email within a project.
  Returns nil if not found.
  """
  def get_subscriber_by_email(%Project{} = project, email) when is_binary(email) do
    normalized_email = String.downcase(String.trim(email))

    Subscriber
    |> where([s], s.project_id == ^project.id and s.email == ^normalized_email)
    |> Repo.one()
  end

  @doc """
  Creates a new subscriber with GDPR consent tracking.

  ## Options
    - consent_info: Map with :ip and :user_agent for GDPR compliance
  """
  def create_subscriber(%Project{} = project, attrs, consent_info \\ %{}) do
    %Subscriber{}
    |> Subscriber.changeset(
      Map.merge(attrs, %{
        project_id: project.id,
        consent_given_at: DateTime.utc_now() |> DateTime.truncate(:second),
        consent_ip: consent_info[:ip],
        consent_user_agent: consent_info[:user_agent]
      })
    )
    |> Repo.insert()
  end

  @doc """
  Updates a subscriber.
  """
  def update_subscriber(%Subscriber{} = subscriber, attrs) do
    subscriber
    |> Subscriber.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a subscriber.
  """
  def delete_subscriber(%Subscriber{} = subscriber) do
    Repo.delete(subscriber)
  end

  # ============================================================================
  # Status Management
  # ============================================================================

  @doc """
  Confirms a subscriber (double opt-in).
  Sets status to "confirmed" and records confirmation timestamp.
  """
  def confirm_subscriber(%Subscriber{} = subscriber) do
    subscriber
    |> Subscriber.confirm_changeset()
    |> Repo.update()
  end

  @doc """
  Unsubscribes a subscriber.
  Sets status to "unsubscribed" and records unsubscribe timestamp.
  """
  def unsubscribe(%Subscriber{} = subscriber) do
    subscriber
    |> Subscriber.unsubscribe_changeset()
    |> Repo.update()
  end

  # ============================================================================
  # Tag Management
  # ============================================================================

  @doc """
  Adds tags to a subscriber.
  Duplicates are automatically removed.
  """
  def add_tags(%Subscriber{} = subscriber, tags) when is_list(tags) do
    subscriber
    |> Subscriber.add_tags_changeset(tags)
    |> Repo.update()
  end

  @doc """
  Removes tags from a subscriber.
  """
  def remove_tags(%Subscriber{} = subscriber, tags) when is_list(tags) do
    subscriber
    |> Subscriber.remove_tags_changeset(tags)
    |> Repo.update()
  end

  # ============================================================================
  # Analytics
  # ============================================================================

  @doc """
  Returns subscriber count for a project.
  Optionally filter by status.

  ## Examples

      Leads.subscriber_count(project)          # All subscribers
      Leads.subscriber_count(project, "confirmed")  # Only confirmed
  """
  def subscriber_count(%Project{} = project, status \\ nil) do
    query = from(s in Subscriber, where: s.project_id == ^project.id)

    query =
      if status do
        where(query, [s], s.status == ^status)
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @doc """
  Returns subscriber counts grouped by status for a project.
  """
  def subscriber_stats(%Project{} = project) do
    Subscriber
    |> where([s], s.project_id == ^project.id)
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns subscriber counts grouped by source for a project.
  """
  def subscribers_by_source(%Project{} = project) do
    Subscriber
    |> where([s], s.project_id == ^project.id)
    |> group_by([s], s.source)
    |> select([s], {s.source, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns recent subscribers for a project.
  """
  def recent_subscribers(%Project{} = project, limit \\ 10) do
    Subscriber
    |> where([s], s.project_id == ^project.id)
    |> order_by([s], desc: s.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # ============================================================================
  # Bulk Operations
  # ============================================================================

  @doc """
  Imports subscribers in bulk.
  Returns {:ok, count} on success or {:error, reason} on failure.
  """
  def import_subscribers(%Project{} = project, subscribers_data, consent_info \\ %{})
      when is_list(subscribers_data) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(subscribers_data, fn data ->
        email = data[:email] || data["email"]
        first_name = data[:first_name] || data["first_name"]

        %{
          id: Ecto.UUID.generate(),
          email: String.downcase(String.trim(email || "")),
          first_name: first_name,
          status: "pending",
          source: "manual",
          tags: [],
          metadata: %{},
          consent_given_at: now,
          consent_ip: consent_info[:ip],
          consent_user_agent: consent_info[:user_agent],
          project_id: project.id,
          inserted_at: now,
          updated_at: now
        }
      end)
      |> Enum.filter(&valid_email?(&1.email))

    {count, _} =
      Repo.insert_all(
        Subscriber,
        entries,
        on_conflict: :nothing,
        conflict_target: [:email, :project_id]
      )

    {:ok, count}
  end

  defp valid_email?(email) when is_binary(email) do
    String.contains?(email, "@") and String.length(email) > 3
  end

  defp valid_email?(_), do: false
end
