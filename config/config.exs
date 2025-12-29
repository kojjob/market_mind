# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :market_mind,
  ecto_repos: [MarketMind.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :market_mind, MarketMindWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MarketMindWeb.ErrorHTML, json: MarketMindWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MarketMind.PubSub,
  live_view: [signing_salt: "Ly8rkLWC"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  market_mind: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  market_mind: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban background job configuration
config :market_mind, Oban,
  repo: MarketMind.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Run sequence scheduler every minute to check for pending emails
       {"* * * * *", MarketMind.Workers.SequenceSchedulerWorker}
     ]}
  ],
  queues: [default: 10, analysis: 5, content: 3, emails: 5]

# Default from email for sequence emails
config :market_mind, :default_from_email, "noreply@marketmind.app"

# Swoosh email configuration (default adapter, overridden per environment)
config :market_mind, MarketMind.Mailer, adapter: Swoosh.Adapters.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
