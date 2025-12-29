defmodule MarketMind.Mailer do
  @moduledoc """
  Mailer module for sending emails via Swoosh.

  In development, emails are stored in memory and viewable at `/dev/mailbox`.

  In production, configure via MAILER_ADAPTER environment variable:
  - "mailgun" (default): Mailgun API (5,000 emails/month free)
  - "brevo": Brevo/Sendinblue API (300 emails/day free)
  - "local": Local adapter for testing production config
  """

  use Swoosh.Mailer, otp_app: :market_mind
end
