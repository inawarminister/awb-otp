defmodule Annoying.FC.ThreadWorker do
  use GenServer, restart: :transient

  def spawn(board, thread, client \\ Annoying.FC.FinchClient) do
    DynamicSupervisor.start_child(
      Annoying.FC.Supervisor,
      {Annoying.FC.ThreadWorker, {board, thread, client}}
    )
  end

  def lookup(board, thread) do
    Registry.select(Annoying.FC.Registry, [
      {
        {{:thread, board, thread}, :"$1", :_},
        [],
        [:"$1"]
      }
    ])
  end

  def delete(pid) do
    GenServer.cast(pid, :delete)
  end

  def update(pid) do
    GenServer.cast(pid, :update)
  end

  def start_link({board, thread, client}) do
    GenServer.start_link(
      __MODULE__,
      {board, thread, client},
      name: {:via, Registry, {Annoying.FC.Registry, {:thread, board, thread}}}
    )
  end

  @impl true
  def init({board, thread, client}) do
    load_thread_async(client, board, thread, self())
    {:ok, %{client: client, board: board, thread: thread, data: %{}}}
  end

  @impl true
  def handle_cast({:fetched, data}, state) do
    {:noreply, %{state | data: data}}
  end

  @impl true
  def handle_cast(:update, state) do
    %{client: client, board: board, thread: thread} = state
    load_thread_async(client, board, thread, self())
    {:noreply, state}
  end

  @impl true
  def handle_cast(:delete, _state) do
    {:stop, :normal, %{}}
  end

  def load_thread_async(client, board, thread, pid) do
    Task.Supervisor.start_child(Annoying.FC.TaskSupervisor, fn ->
      GenServer.cast(pid, {:fetched, client.thread!(board, thread)})
    end)
  end
end
