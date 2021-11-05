use Mix.Config

config :blitz, Blitz, riot_api_key: "<your-api-key>"

config :hammer,

  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 2]}