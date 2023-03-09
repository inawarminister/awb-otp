import Config

config :annoying, Annoying.Scheduler,
  debug_logging: false,
  jobs: [
    # {"* * * * *", {Annoying.FC.BoardWorker, :update, []}}
  ]
  config :nostrum,
  token: "", # The token of your bot as a string
  gateway_intents: :all
