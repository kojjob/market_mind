defmodule MarketMind.Workers.EmailDeliveryWorker do
  @moduledoc """
  Oban worker for sending individual email deliveries.

  This worker is responsible for:
  - Fetching the email delivery record
  - Rendering the email content with variable substitution
  - Sending via Swoosh
  - Updating delivery status (sent/failed)
  - Handling retries with exponential backoff

  ## Usage

  Called by EmailMarketing.schedule_pending_emails/0:

      %{delivery_id: delivery_id}
      |> EmailDeliveryWorker.new()
      |> Oban.insert()

  """
  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    priority: 1

  require Logger

  alias MarketMind.EmailMarketing
  alias MarketMind.EmailMarketing.EmailDelivery
  alias MarketMind.Leads.Subscriber
  alias MarketMind.Mailer

  import Swoosh.Email

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}, attempt: attempt}) do
    Logger.info("Processing email delivery #{delivery_id}, attempt #{attempt}")

    with {:ok, delivery} <- fetch_delivery(delivery_id),
         {:ok, delivery} <- mark_pending(delivery),
         {:ok, email} <- build_email(delivery),
         {:ok, _result} <- send_email(email) do
      mark_sent(delivery)
      Logger.info("Successfully sent email delivery #{delivery_id}")
      :ok
    else
      {:error, :not_found} ->
        Logger.error("Email delivery #{delivery_id} not found")
        {:error, "Delivery not found"}

      {:error, :already_sent} ->
        Logger.info("Email delivery #{delivery_id} already sent, skipping")
        :ok

      {:error, :subscriber_unsubscribed} ->
        Logger.info("Subscriber unsubscribed, cancelling delivery #{delivery_id}")
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to send email delivery #{delivery_id}: #{inspect(reason)}")
        mark_failed(delivery_id, reason)
        error
    end
  end

  # Fetch delivery with all necessary preloads
  defp fetch_delivery(delivery_id) do
    case EmailMarketing.get_delivery_with_details!(delivery_id) do
      nil ->
        {:error, :not_found}

      %EmailDelivery{status: status} when status in ["sent", "opened", "clicked"] ->
        {:error, :already_sent}

      %EmailDelivery{subscriber: %Subscriber{status: "unsubscribed"}} ->
        {:error, :subscriber_unsubscribed}

      delivery ->
        {:ok, delivery}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  # Mark as pending (being processed)
  defp mark_pending(%EmailDelivery{} = delivery) do
    case EmailMarketing.mark_delivery_pending(delivery) do
      {:ok, updated} -> {:ok, updated}
      {:error, _} = error -> error
    end
  end

  # Build the Swoosh email
  defp build_email(%EmailDelivery{} = delivery) do
    %{
      subscriber: subscriber,
      sequence_email: sequence_email
    } = delivery

    %{sequence: sequence} = sequence_email

    # Get project for from address (could be configured per project)
    project = MarketMind.Repo.preload(sequence, :project).project

    from_name = project.name || "MarketMind"
    from_email = get_from_email(project)

    email =
      new()
      |> to({subscriber.first_name || "", subscriber.email})
      |> from({from_name, from_email})
      |> subject(render_subject(sequence_email.subject, subscriber))
      |> html_body(render_body(sequence_email.body, subscriber))
      |> text_body(render_text_body(sequence_email.body, subscriber))

    {:ok, email}
  end

  # Render subject with variable substitution
  defp render_subject(subject, subscriber) do
    subject
    |> replace_variables(subscriber)
  end

  # Render HTML body with variable substitution
  defp render_body(body, subscriber) do
    body
    |> replace_variables(subscriber)
    |> wrap_in_html_template()
  end

  # Create plain text version
  defp render_text_body(body, subscriber) do
    body
    |> replace_variables(subscriber)
    |> strip_html()
  end

  # Replace template variables
  defp replace_variables(content, subscriber) do
    content
    |> String.replace("{{first_name}}", subscriber.first_name || "there")
    |> String.replace("{{email}}", subscriber.email)
    |> String.replace("{{subscriber_id}}", subscriber.id || "")
  end

  # Simple HTML wrapper for email body
  defp wrap_in_html_template(body) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        a { color: #0066cc; }
        p { margin: 1em 0; }
      </style>
    </head>
    <body>
      #{body}
    </body>
    </html>
    """
  end

  # Strip HTML tags for plain text version
  defp strip_html(html) do
    html
    |> String.replace(~r/<br\s*\/?>/, "\n")
    |> String.replace(~r/<\/p>/, "\n\n")
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  # Get from email address (can be configured per project in future)
  defp get_from_email(_project) do
    Application.get_env(:market_mind, :default_from_email, "noreply@marketmind.app")
  end

  # Send email via Swoosh
  defp send_email(email) do
    case Mailer.deliver(email) do
      {:ok, _} = success -> success
      {:error, reason} -> {:error, {:send_failed, reason}}
    end
  end

  # Mark delivery as sent
  defp mark_sent(%EmailDelivery{} = delivery) do
    EmailMarketing.mark_delivery_sent(delivery)
  end

  # Mark delivery as failed
  defp mark_failed(delivery_id, reason) do
    case EmailMarketing.get_delivery!(delivery_id) do
      nil -> :ok
      delivery -> EmailMarketing.mark_delivery_failed(delivery, inspect(reason))
    end
  rescue
    _ -> :ok
  end
end
