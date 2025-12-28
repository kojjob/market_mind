import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :market_mind, MarketMind.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "market_mind_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :market_mind, MarketMindWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PQrf3dHrjOrheBJyT78CKBcdsqQBouXADmzJ2pHG9MejEPwTYO8NahhU1HdNAMvo",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Oban test configuration - use inline mode for synchronous execution
config :market_mind, Oban, testing: :inline

# Use mock LLM client in tests
config :market_mind, :llm_client, MarketMind.LLM.Mock

# Set environment for conditional test adapters
config :market_mind, :env, :test
