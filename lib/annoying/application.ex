defmodule Annoying.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Annoying.Scheduler,
      Annoying.FC
    ]

    opts = [strategy: :one_for_one, name: Annoying.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
