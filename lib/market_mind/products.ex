defmodule MarketMind.Products do
  @moduledoc """
  The Products context manages projects (SaaS products) and their analysis lifecycle.

  ## Core Responsibilities:
  - CRUD operations for projects scoped to users
  - Analysis status management (pending → queued → analyzing → completed/failed)
  - Background job enqueueing for product analysis
  - Query operations for project discovery

  ## Analysis Workflow:
  1. User creates a project with a URL
  2. Project is created with status "pending"
  3. User triggers analysis, status becomes "queued" and Oban job is enqueued
  4. Worker fetches website, calls LLM, status becomes "analyzing"
  5. On success: status "completed" with analysis_data populated
  6. On failure: status "failed"
  """

  import Ecto.Query, warn: false
  alias MarketMind.Repo
  alias MarketMind.Products.Project

  @doc """
  Returns a list of projects for a given user.

  ## Examples

      iex> list_projects_for_user(user)
      [%Project{}, ...]

  """
  def list_projects_for_user(user) do
    Project
    |> where([p], p.user_id == ^user.id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Gets a project by its slug.

  Returns nil if no project is found.

  ## Examples

      iex> get_project_by_slug("my-product-abc123")
      %Project{}

      iex> get_project_by_slug("non-existent")
      nil

  """
  def get_project_by_slug(slug) do
    Repo.get_by(Project, slug: slug)
  end

  @doc """
  Creates a project for a user.

  ## Examples

      iex> create_project(user, %{name: "My SaaS", url: "https://mysaas.com"})
      {:ok, %Project{}}

      iex> create_project(user, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(user, attrs \\ %{}) do
    # Ensure user_id is added with matching key type (string or atom)
    attrs =
      if is_map_key(attrs, :name) or attrs == %{} do
        Map.put(attrs, :user_id, user.id)
      else
        Map.put(attrs, "user_id", user.id)
      end

    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  Does not allow changing the slug or user_id.

  ## Examples

      iex> update_project(project, %{name: "New Name"})
      {:ok, %Project{}}

      iex> update_project(project, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  @doc """
  Updates the analysis status of a project.

  ## Examples

      iex> update_analysis_status(project, "analyzing")
      {:ok, %Project{analysis_status: "analyzing"}}

  """
  def update_analysis_status(%Project{} = project, status) do
    project
    |> Project.analysis_changeset(%{analysis_status: status})
    |> Repo.update()
  end

  @doc """
  Updates the analysis status and data of a project.

  Sets analyzed_at timestamp when status is "completed".

  ## Examples

      iex> update_analysis_status(project, "completed", %{"product_name" => "Test"})
      {:ok, %Project{analysis_status: "completed", analysis_data: %{...}}}

  """
  def update_analysis_status(%Project{} = project, status, analysis_data) do
    project
    |> Project.analysis_changeset(%{analysis_status: status, analysis_data: analysis_data})
    |> Repo.update()
  end

  @doc """
  Updates the analysis data of a project without changing status.
  """
  def update_project_analysis(%Project{} = project, attrs) do
    project
    |> Project.analysis_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Queues a project for analysis.

  Updates the status to "queued" and enqueues an Oban job to perform the analysis.

  ## Examples

      iex> queue_analysis(project)
      {:ok, %Project{analysis_status: "queued"}}

  """
  def queue_analysis(%Project{} = project) do
    with {:ok, updated_project} <- update_analysis_status(project, "queued") do
      # Enqueue the analysis job
      %{project_id: project.id}
      |> MarketMind.Products.ProductAnalyzerWorker.new()
      |> Oban.insert()

      {:ok, updated_project}
    end
  end

  @doc """
  Returns a list of projects with "pending" status.

  Useful for batch processing or monitoring.

  ## Examples

      iex> list_pending_projects()
      [%Project{analysis_status: "pending"}, ...]

  """
  def list_pending_projects do
    Project
    |> where([p], p.analysis_status == "pending")
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end
end
