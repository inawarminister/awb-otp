defmodule Annoying.FC.BoardWorker do
  use GenServer

  alias Finch.Response
  alias Annoying.FC.ThreadWorker

  def spawn(board) do
    DynamicSupervisor.start_child(
      Annoying.FC.Supervisor,
      {Annoying.FC.BoardWorker, board}
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

  def start_link(board) do
    GenServer.start_link(
      __MODULE__,
      board,
      name: {:via, Registry, {Annoying.FC.Registry, {:board, board}}}
    )
  end

  def update() do
    for {board, pid} <- list() do
      load_threads_async(board, pid)
    end
  end

  def prune() do
    for {_, pid} <- list() do
      GenServer.cast(pid, :prune)
    end
  end

  @impl true
  def init(board) do
    load_threads_async(board, self())
    {:ok, %{board: board, threads: %{}}}
  end

  @impl true
  def handle_cast(:prune, state) do
    %{board: board, threads: threads} = state
    now = DateTime.utc_now()

    pruned =
      for {thread, modified} <- threads,
          DateTime.diff(modified, now, :hours) > 48 do
        with [pid] <- ThreadWorker.lookup(board, thread), do: ThreadWorker.delete(pid)
        thread
      end

    {:noreply, %{state | threads: Map.drop(threads, pruned)}}
  end

  @impl true
  def handle_info({:fetched, pages}, state) do
    %{board: board, threads: threads} = state

    updated_threads =
      for %{"threads" => list} <- pages,
          %{"no" => thread, "last_modified" => modified} <- list,
          {:ok, date} = DateTime.from_unix(modified),
          into: %{},
          do: {thread, date}

    for {thread, modified} <- updated_threads do
      case {ThreadWorker.lookup(board, thread), Map.fetch(threads, thread)} do
        {[], _} ->
          ThreadWorker.spawn(board, thread)

        {[pid], {:ok, last_modified}} ->
          case DateTime.compare(last_modified, modified) do
            :lt -> ThreadWorker.update(pid)
            _ -> :ok
          end

        _ ->
          :ok
      end
    end

    {:noreply, Map.put(state, :threads, Map.merge(threads, updated_threads))}
  end

  defp load_threads_async(board, pid) do
    Task.Supervisor.start_child(Annoying.FC.TaskSupervisor, fn ->
      {:ok, %Response{status: 200, body: body}} =
        Finch.build(:get, "https://a.4cdn.org/#{board}/threads.json")
        |> Finch.request(Annoying.FC.Finch)

      send(pid, {:fetched, Jason.decode!(body)})
    end)
  end
end
