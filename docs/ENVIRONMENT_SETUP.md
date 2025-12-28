# Environment Setup

> Configuration files for local development and deployment.

---

## .env.example

```bash
# ===========================================
# MarketMind Environment Configuration
# ===========================================
# Copy this file to .env and fill in your values
# DO NOT commit .env to version control

# -------------------------------------------
# Database
# -------------------------------------------
DATABASE_URL=postgres://postgres:postgres@localhost:5432/marketmind_dev

# For production (Fly.io will set this automatically)
# DATABASE_URL=postgres://user:pass@host:5432/marketmind

# -------------------------------------------
# Phoenix
# -------------------------------------------
# Generate with: mix phx.gen.secret
SECRET_KEY_BASE=your_secret_key_base_here_at_least_64_characters_long

# Host configuration
PHX_HOST=localhost
PORT=4000

# -------------------------------------------
# LLM APIs
# -------------------------------------------
# Google Gemini (Primary - required)
# Get key: https://makersuite.google.com/app/apikey
GEMINI_API_KEY=your_gemini_api_key

# Anthropic Claude (For complex tasks - optional for MVP)
# Get key: https://console.anthropic.com/
ANTHROPIC_API_KEY=your_anthropic_api_key

# -------------------------------------------
# Email (SendGrid)
# -------------------------------------------
# Get key: https://app.sendgrid.com/settings/api_keys
# Free tier: 100 emails/day
SENDGRID_API_KEY=your_sendgrid_api_key
SENDGRID_FROM_EMAIL=noreply@yourdomain.com

# -------------------------------------------
# Optional: Analytics
# -------------------------------------------
# PostHog (Product analytics)
POSTHOG_API_KEY=
POSTHOG_HOST=https://app.posthog.com

# Sentry (Error tracking)
SENTRY_DSN=

# -------------------------------------------
# Optional: Stripe (Phase 4)
# -------------------------------------------
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PUBLISHABLE_KEY=

# -------------------------------------------
# Feature Flags
# -------------------------------------------
ENABLE_CLAUDE_TOOLS=false
ENABLE_COMPETITOR_RADAR=false
ENABLE_PERSONA_SIMULATION=false
```

---

## docker-compose.yml

```yaml
# Docker Compose for local development
# Usage: docker-compose up -d

version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:16-alpine
    container_name: marketmind_db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: marketmind_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./priv/repo/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Redis (for caching - optional, can use ETS instead)
  # redis:
  #   image: redis:7-alpine
  #   container_name: marketmind_redis
  #   ports:
  #     - "6379:6379"
  #   volumes:
  #     - redis_data:/data

  # MailHog (local email testing)
  mailhog:
    image: mailhog/mailhog
    container_name: marketmind_mail
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI
    logging:
      driver: none

volumes:
  postgres_data:
  # redis_data:
```

---

## Database Init Script

```sql
-- priv/repo/init.sql
-- Run on database creation

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- For fuzzy search

-- Set timezone
SET timezone = 'UTC';
```

---

## config/dev.exs (partial)

```elixir
import Config

# Database
config :market_mind, MarketMind.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "marketmind_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Endpoint
config :market_mind, MarketMindWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_chars_for_development_only",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:market_mind, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:market_mind, ~w(--watch)]}
  ]

# Live reload
config :market_mind, MarketMindWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/market_mind_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Mailer - use Mailhog in dev
config :market_mind, MarketMind.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "localhost",
  port: 1025

# LLM - use real APIs even in dev (with rate limiting)
config :market_mind, MarketMind.LLM.Gemini,
  api_key: System.get_env("GEMINI_API_KEY"),
  base_url: "https://generativelanguage.googleapis.com/v1beta",
  default_model: "gemini-1.5-flash",
  timeout: 60_000

# Oban
config :market_mind, Oban,
  repo: MarketMind.Repo,
  queues: [default: 10, analysis: 5, content: 10, email: 20],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ]
```

---

## config/test.exs (partial)

```elixir
import Config

# Database - use sandbox for isolation
config :market_mind, MarketMind.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "marketmind_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Endpoint
config :market_mind, MarketMindWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_characters_long_for_testing",
  server: false

# Mailer - test adapter
config :market_mind, MarketMind.Mailer, adapter: Swoosh.Adapters.Test

# LLM - mock in tests
config :market_mind, MarketMind.LLM.Gemini,
  adapter: MarketMind.LLM.Mock

config :market_mind, MarketMind.LLM.Claude,
  adapter: MarketMind.LLM.Mock

# Oban - inline mode for tests
config :market_mind, Oban, testing: :inline

# Faster password hashing in tests
config :bcrypt_elixir, :log_rounds, 1

# Logger - only warnings and errors
config :logger, level: :warning
```

---

## config/runtime.exs (partial)

```elixir
import Config

if config_env() == :prod do
  # Database from environment
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is missing"

  config :market_mind, MarketMind.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true,
    ssl_opts: [verify: :verify_none]

  # Secret key
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE environment variable is missing"

  host = System.get_env("PHX_HOST") || "marketmind.app"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :market_mind, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :market_mind, MarketMindWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # LLM APIs
  config :market_mind, MarketMind.LLM.Gemini,
    api_key: System.get_env("GEMINI_API_KEY") || raise("GEMINI_API_KEY required"),
    base_url: "https://generativelanguage.googleapis.com/v1beta",
    default_model: "gemini-1.5-flash",
    timeout: 60_000

  if anthropic_key = System.get_env("ANTHROPIC_API_KEY") do
    config :market_mind, MarketMind.LLM.Claude,
      api_key: anthropic_key,
      base_url: "https://api.anthropic.com/v1",
      default_model: "claude-3-5-sonnet-20241022",
      timeout: 120_000
  end

  # Email
  if sendgrid_key = System.get_env("SENDGRID_API_KEY") do
    config :market_mind, MarketMind.Mailer,
      adapter: Swoosh.Adapters.Sendgrid,
      api_key: sendgrid_key
  end

  # Stripe
  if stripe_key = System.get_env("STRIPE_SECRET_KEY") do
    config :stripity_stripe,
      api_key: stripe_key,
      webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET")
  end
end
```

---

## Fly.io Configuration

```toml
# fly.toml
app = "marketmind"
primary_region = "iad"
kill_signal = "SIGTERM"
kill_timeout = "5s"

[build]

[deploy]
  release_command = "/app/bin/migrate"

[env]
  PHX_HOST = "marketmind.fly.dev"
  PORT = "8080"
  POOL_SIZE = "10"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1
  processes = ["app"]

  [http_service.concurrency]
    type = "connections"
    hard_limit = 250
    soft_limit = 200

[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
  cpus = 1
```

---

## GitHub Actions CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.16"
  OTP_VERSION: "26"

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: marketmind_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-

      - name: Cache build
        uses: actions/cache@v4
        with:
          path: _build
          key: ${{ runner.os }}-build-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-build-

      - name: Install dependencies
        run: mix deps.get

      - name: Check formatting
        run: mix format --check-formatted

      - name: Compile (warnings as errors)
        run: mix compile --warnings-as-errors

      - name: Run Credo
        run: mix credo --strict

      - name: Setup database
        run: mix ecto.setup

      - name: Run tests
        run: mix test --cover

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: always()
```

---

## .gitignore additions

```gitignore
# Environment
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Elixir/Phoenix (already in default)
/_build/
/deps/
/priv/static/assets/
*.ez
.elixir_ls/

# Test
/cover/
/doc/

# Secrets
*.pem
*.key

# Local dev
.docker-data/
```
