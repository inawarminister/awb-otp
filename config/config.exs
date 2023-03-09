import Config

config :annoying, Annoying.Scheduler,
  debug_logging: false,
  jobs: []

config :logger,
  level: :warn

config :nostrum,
  token: System.get_env("BOT_TOKEN")
