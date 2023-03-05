defmodule Annoying.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Annoying.Scheduler,
      {Finch, name: Annoying.FC.Finch},
      {Task.Supervisor, name: Annoying.FC.TaskSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Annoying.FC.Supervisor},
      {Registry, keys: :unique, name: Annoying.FC.Registry}
    ]

    opts = [strategy: :one_for_one, name: Annoying.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
