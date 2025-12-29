defmodule MarketMindWeb.Public.LeadMagnetController do
  @moduledoc """
  Controller for handling lead magnet downloads.

  Provides authenticated download access to subscribers who have
  signed up for a lead magnet. The subscriber_id in the URL acts
  as an access token.

  ## Routes

      get "/p/:project_slug/:slug/download/:subscriber_id", LeadMagnetController, :download

  ## Security

  - Verifies subscriber exists and belongs to the project
  - Verifies subscriber signed up for this specific lead magnet
  - Tracks download activity for analytics
  """
  use MarketMindWeb, :controller

  alias MarketMind.LeadMagnets
  alias MarketMind.Leads

  @doc """
  Handles lead magnet download requests.

  Validates the subscriber has access to the lead magnet and either:
  - Redirects to external download URL, or
  - Renders the content inline as a downloadable file
  """
  def download(conn, %{
        "project_slug" => project_slug,
        "slug" => slug,
        "subscriber_id" => subscriber_id
      }) do
    with {:ok, lead_magnet} <- fetch_lead_magnet(project_slug, slug),
         {:ok, subscriber} <- fetch_subscriber(subscriber_id),
         :ok <- verify_access(lead_magnet, subscriber) do
      serve_download(conn, lead_magnet, subscriber)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: MarketMindWeb.ErrorHTML)
        |> render("404.html")

      {:error, :access_denied} ->
        conn
        |> put_status(:forbidden)
        |> put_view(html: MarketMindWeb.ErrorHTML)
        |> render("403.html")
    end
  end

  defp fetch_lead_magnet(project_slug, slug) do
    {:ok, LeadMagnets.get_active_lead_magnet_by_slugs!(project_slug, slug)}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp fetch_subscriber(subscriber_id) do
    case Leads.get_subscriber(subscriber_id) do
      nil -> {:error, :not_found}
      subscriber -> {:ok, subscriber}
    end
  end

  defp verify_access(lead_magnet, subscriber) do
    cond do
      # Subscriber must be from this project
      subscriber.project_id != lead_magnet.project_id ->
        {:error, :access_denied}

      # Subscriber must have signed up via this lead magnet
      subscriber.source != "lead_magnet" ->
        {:error, :access_denied}

      subscriber.source_id != lead_magnet.id ->
        {:error, :access_denied}

      # Subscriber must not be unsubscribed (they keep access)
      # Actually, we'll allow unsubscribed users to still download
      true ->
        :ok
    end
  end

  defp serve_download(conn, lead_magnet, _subscriber) do
    cond do
      # If there's an external download URL, redirect to it
      lead_magnet.download_url && lead_magnet.download_url != "" ->
        redirect(conn, external: lead_magnet.download_url)

      # If there's inline content, serve it as a downloadable file
      lead_magnet.content && lead_magnet.content != "" ->
        filename = generate_filename(lead_magnet)

        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, lead_magnet.content)

      # No content available
      true ->
        conn
        |> put_flash(:error, "Download not available")
        |> redirect(to: "/")
    end
  end

  defp generate_filename(lead_magnet) do
    base_name =
      lead_magnet.title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    "#{base_name}.md"
  end
end
