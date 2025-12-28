defmodule MarketMind.Repo do
  use Ecto.Repo,
    otp_app: :market_mind,
    adapter: Ecto.Adapters.Postgres
end
