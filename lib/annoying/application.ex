defmodule Annoying.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Annoying.FC,
      {Task.Supervisor, name: Annoying.DiscordTaskSupervisor},
      Annoying.Scheduler
    ]

    opts = [strategy: :one_for_one, name: Annoying.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
