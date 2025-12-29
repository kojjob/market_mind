defmodule MarketMind.Workers.SequenceSchedulerWorker do
  @moduledoc """
  Oban cron worker that runs periodically to schedule email deliveries.

  This worker:
  1. Finds all email deliveries with status "scheduled" where scheduled_for <= now
  2. Creates EmailDeliveryWorker jobs for each
  3. Prevents duplicate jobs by using unique constraints

  ## Configuration

  Add to your Oban config:

      config :market_mind, Oban,
        plugins: [
          {Oban.Plugins.Cron,
           crontab: [
             {"* * * * *", MarketMind.Workers.SequenceSchedulerWorker}
           ]}
        ]

  This runs every minute to check for pending emails.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    unique: [period: 60]

  require Logger

  alias MarketMind.EmailMarketing
  alias MarketMind.Workers.EmailDeliveryWorker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Running sequence scheduler...")

    case EmailMarketing.schedule_pending_emails() do
      {:ok, count} when count > 0 ->
        Logger.info("Scheduled #{count} email deliveries for sending")
        :ok

      {:ok, 0} ->
        Logger.debug("No pending emails to schedule")
        :ok

      {:error, reason} = error ->
        Logger.error("Sequence scheduler failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Manually trigger email scheduling.
  Useful for testing or manual intervention.
  """
  def run_now do
    %{}
    |> new()
    |> Oban.insert()
  end

  @doc """
  Schedule retry processing for failed deliveries.
  Called periodically to retry failed emails that haven't exceeded max attempts.
  """
  def schedule_retries do
    deliveries = EmailMarketing.list_retriable_deliveries()

    Enum.each(deliveries, fn delivery ->
      # Reschedule with exponential backoff
      delay = calculate_backoff(delivery.attempts)

      %{delivery_id: delivery.id}
      |> EmailDeliveryWorker.new(scheduled_at: DateTime.add(DateTime.utc_now(), delay, :second))
      |> Oban.insert()
    end)

    {:ok, length(deliveries)}
  end

  # Calculate exponential backoff: 1min, 5min, 30min
  defp calculate_backoff(attempts) do
    base_delays = [60, 300, 1800]

    Enum.at(base_delays, attempts - 1, 3600)
  end
end
