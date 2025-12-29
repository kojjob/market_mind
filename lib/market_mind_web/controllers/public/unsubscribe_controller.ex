defmodule MarketMindWeb.Public.UnsubscribeController do
  @moduledoc """
  Controller for handling email unsubscribe requests.

  Provides a one-click unsubscribe flow compliant with email best practices
  and CAN-SPAM/GDPR requirements.

  ## Routes

      get "/p/unsubscribe/:token", UnsubscribeController, :show
      post "/p/unsubscribe/:token", UnsubscribeController, :unsubscribe

  ## Security

  - Token is the subscriber_id (UUID) which serves as an access token
  - No authentication required (must work from email links)
  - Idempotent - multiple clicks have the same effect
  """
  use MarketMindWeb, :controller

  alias MarketMind.Leads

  @doc """
  Shows the unsubscribe confirmation page.

  Displays subscriber info and asks for confirmation before unsubscribing.
  """
  def show(conn, %{"token" => token}) do
    case fetch_subscriber(token) do
      {:ok, subscriber} ->
        conn
        |> assign(:subscriber, subscriber)
        |> assign(:already_unsubscribed, subscriber.status == "unsubscribed")
        |> render(:show)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: MarketMindWeb.ErrorHTML)
        |> render("404.html")
    end
  end

  @doc """
  Processes the unsubscribe request.

  Sets subscriber status to "unsubscribed" and shows confirmation.
  """
  def unsubscribe(conn, %{"token" => token}) do
    case fetch_subscriber(token) do
      {:ok, subscriber} ->
        case Leads.unsubscribe(subscriber) do
          {:ok, updated_subscriber} ->
            conn
            |> assign(:subscriber, updated_subscriber)
            |> render(:confirmed)

          {:error, _changeset} ->
            conn
            |> put_flash(:error, "Unable to process unsubscribe request. Please try again.")
            |> redirect(to: ~p"/p/unsubscribe/#{token}")
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: MarketMindWeb.ErrorHTML)
        |> render("404.html")
    end
  end

  defp fetch_subscriber(token) do
    case Leads.get_subscriber(token) do
      nil -> {:error, :not_found}
      subscriber -> {:ok, subscriber}
    end
  end
end
