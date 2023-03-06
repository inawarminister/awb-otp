defmodule Annoying.FC.BoardWorker do
  use GenServer

  @keepalive_hours 48

  alias Annoying.FC.ThreadWorker

  def spawn(board, client \\ Annoying.FC.FinchClient) do
    DynamicSupervisor.start_child(
      Annoying.FC.Supervisor,
      {Annoying.FC.BoardWorker, {board, client}}
    )
  end

  def list() do
    Registry.select(Annoying.FC.Registry, [
      {
        {{:board, :"$1"}, :"$2", :_},
        [],
        [{{:"$1", :"$2"}}]
      }
    ])
  end

  def start_link({board, client}) do
    GenServer.start_link(
      __MODULE__,
      {board, client},
      name: {:via, Registry, {Annoying.FC.Registry, {:board, board}}}
    )
  end

  def update() do
    for {_, pid} <- list(), do: GenServer.cast(pid, :update)
  end

  def prune() do
    for {_, pid} <- list(), do: GenServer.cast(pid, :prune)
  end

  @impl true
  def init({board, client}) do
    load_threads_async(client, board, self())
    {:ok, %{client: client, board: board, threads: %{}}}
  end

  @impl true
  def handle_cast(:update, state) do
    %{client: client, board: board} = state
    load_threads_async(client, board, self())
    {:noreply, state}
  end

  @impl true
  def handle_cast(:prune, state) do
    %{board: board, threads: threads} = state
    now = DateTime.utc_now()

    pruned =
      for {thread, modified} <- threads,
          @keepalive_hours < DateTime.diff(modified, now, :hours) do
        with [pid] <- ThreadWorker.lookup(board, thread), do: ThreadWorker.delete(pid)
        thread
      end

    {:noreply, %{state | threads: Map.drop(threads, pruned)}}
  end

  @impl true
  def handle_cast({:fetched, pages}, state) do
    updated_threads = as_thread_updates(pages)
    notify_workers(updated_threads, state)
    {:noreply, %{state | threads: Map.merge(state.threads, updated_threads)}}
  end

  defp notify_workers(updated_threads, %{client: client, board: board, threads: threads}) do
    for {thread, modified} <- updated_threads do
      case ThreadWorker.lookup(board, thread) do
        [] ->
          ThreadWorker.spawn(board, thread, client)

        [worker | _] ->
          with {:ok, last_modified} <- Map.fetch(threads, thread),
               :lt <- DateTime.compare(last_modified, modified),
               do: ThreadWorker.update(worker)
      end
    end
  end

  defp as_thread_updates(pages) do
    for %{threads: list} <- pages,
        %{no: thread, last_modified: modified} <- list,
        {:ok, date} = DateTime.from_unix(modified),
        into: %{},
        do: {thread, date}
  end

  defp load_threads_async(client, board, pid) do
    Task.Supervisor.start_child(Annoying.FC.TaskSupervisor, fn ->
      GenServer.cast(pid, {:fetched, client.threads!(board)})
    end)
  end
end
