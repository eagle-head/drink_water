import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :drink_water, DrinkWater.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "drink_water_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :drink_water, DrinkWaterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "w+erZ4F6VhIs04VUg0cP5EhvZO9xFQn13CfGOAWRU+a2erea2S59JdbQKPDA/hHf",
  server: false

# In test we don't send emails
config :drink_water, DrinkWater.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Disable rate limiting in tests (enabled explicitly in rate limiter tests)
config :drink_water, rate_limiting_enabled: false

# Disable PromEx metrics server in test
config :drink_water, DrinkWater.PromEx, disabled: true

# Disable OpenTelemetry trace export in test
config :opentelemetry, traces_exporter: :none

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

# Disable Sentry in test
config :sentry, dsn: nil
