defmodule MarketMind.Products.ProductAnalyzerWorker do
  @moduledoc """
  Oban worker that performs product analysis.

  This worker:
  1. Fetches the project's website content
  2. Sends content to Gemini for analysis
  3. Updates the project with analysis results
  4. Broadcasts completion via PubSub

  ## Job Args

      %{project_id: "uuid-string"}

  ## Analysis Flow

      queued → analyzing → completed/failed

  """
  use Oban.Worker, queue: :analysis, max_attempts: 3

  alias MarketMind.Products
  alias MarketMind.Products.WebsiteFetcher
  alias MarketMind.LLM.Gemini
  alias MarketMind.Agents

  @analysis_schema %{
    product_name: :string,
    tagline: :string,
    value_propositions: [:string],
    key_features: [%{name: :string, description: :string}],
    target_audience: :string,
    pricing_model: :string,
    industries: [:string],
    tone: :string,
    unique_differentiators: [:string]
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    case get_project(project_id) do
      nil ->
        {:error, :project_not_found}

      project ->
        run_analysis(project)
    end
  end

  # Private Functions

  defp get_project(project_id) do
    Products.get_project!(project_id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp run_analysis(project) do
    # Update status to analyzing
    {:ok, project} = Products.update_analysis_status(project, "analyzing")

    # Execute the analysis pipeline
    result =
      with {:ok, website_data} <- fetch_website(project.url),
           {:ok, analysis_data} <- analyze_content(website_data) do
        complete_analysis(project, analysis_data)
      end

    case result do
      :ok ->
        :ok

      {:error, reason} ->
        fail_analysis(project, reason)
        {:error, reason}
    end
  end

  defp fetch_website(url) do
    case WebsiteFetcher.fetch(url) do
      {:ok, data} ->
        {:ok, data}

      {:error, {:http_error, status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, {:network_error, reason}} ->
        {:error, "Network error: #{inspect(reason)}"}

      {:error, :invalid_url} ->
        {:error, "Invalid URL"}
    end
  end

  defp analyze_content(website_data) do
    prompt = build_analysis_prompt(website_data)

    case Gemini.complete_json(prompt, @analysis_schema) do
      {:ok, analysis_data} ->
        {:ok, analysis_data}

      {:error, :invalid_json} ->
        {:error, "LLM returned invalid JSON"}

      {:error, {:api_error, status, message}} ->
        {:error, "API error (#{status}): #{message}"}

      {:error, {:rate_limited, message}} ->
        {:error, "Rate limited: #{message}"}

      {:error, {:network_error, reason}} ->
        {:error, "Network error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Analysis failed: #{inspect(reason)}"}
    end
  end

  defp build_analysis_prompt(website_data) do
    """
    Analyze this SaaS product website and extract marketing intelligence.

    Website Title: #{website_data.title}

    Website Content:
    #{website_data.content}

    #{if website_data.meta_description, do: "Meta Description: #{website_data.meta_description}", else: ""}

    Extract the following in JSON format:
    {
      "product_name": "The product's name",
      "tagline": "The product's main tagline or value proposition",
      "value_propositions": ["VP1", "VP2", "VP3"],
      "key_features": [{"name": "Feature Name", "description": "What it does"}],
      "target_audience": "Who this product is for",
      "pricing_model": "free|freemium|subscription|one-time|usage-based|unknown",
      "industries": ["Industry1", "Industry2"],
      "tone": "professional|casual|technical|friendly",
      "unique_differentiators": ["What makes this product unique"]
    }

    Respond with valid JSON only. No markdown, no explanation.
    """
  end

  defp complete_analysis(project, analysis_data) do
    require Logger
    {:ok, updated_project} = Products.update_analysis_status(project, "completed", analysis_data)

    # Trigger persona generation after successful analysis
    case Agents.run_persona_generation(updated_project) do
      {:ok, :completed} ->
        Logger.info("Product analysis and persona generation completed for project #{project.id}")

      {:error, reason} ->
        Logger.warning("Product analysis completed but persona generation failed for project #{project.id}: #{inspect(reason)}")
    end

    broadcast_completion(updated_project, "completed")
    :ok
  end

  defp fail_analysis(project, reason) do
    require Logger
    error_message = if is_binary(reason), do: reason, else: inspect(reason)
    Logger.error("Analysis failed for project #{project.id}: #{error_message}")

    # Store error information in analysis_data for debugging
    error_data = %{
      "error" => true,
      "error_message" => error_message,
      "failed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, updated_project} = Products.update_analysis_status(project, "failed", error_data)
    broadcast_completion(updated_project, "failed")
  end

  defp broadcast_completion(project, status) do
    Phoenix.PubSub.broadcast(
      MarketMind.PubSub,
      "project:#{project.id}",
      {:analysis_completed, %{project_id: project.id, status: status}}
    )
  end
end
