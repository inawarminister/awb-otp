import Config

config :annoying, Annoying.Scheduler,
  debug_logging: false,
  jobs: [
    # {"* * * * *", {Annoying.FC.BoardWorker, :update, []}}
  ]
