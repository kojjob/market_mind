ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MarketMind.Repo, :manual)

# Define Mox mocks
Mox.defmock(MarketMind.LLM.Mock, for: MarketMind.LLM)
