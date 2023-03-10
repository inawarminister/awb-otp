defmodule Annoying.FC.BoardWorker do
  use GenServer

  alias Annoying.FC.{Client, Event, Post}

  @type state :: %{
          client: Client.t(),
          event_sink: Event.sink(),
          board: Post.board_id(),
          name: GenServer.name()
        }

  @spec start_link(state) :: GenServer.on_start()
  def start_link(init_state) do
    GenServer.start_link(__MODULE__, init_state, name: Map.get(init_state, :name))
  end

  @doc "Signals cache to perform an update."
  @spec update(GenServer.server()) :: :ok
  def update(server) do
    GenServer.cast(server, :update)
  end

  @doc "Signals cache to prune threads older than the specified `deadline`."
  @spec prune(GenServer.server(), DateTime.t()) :: :ok
  def prune(server, deadline) do
    GenServer.cast(server, {:prune, deadline})
  end

  @impl true
  def init(init_state) do
    load_async(init_state)
    {:ok, init_state}
  end

  @impl true
  def handle_cast({:fetched_threads, threads}, %{data: data} = state) do
    for {thread, modified} <- threads do
      with {:ok, last_modified} <- Map.fetch(data, thread) do
        if DateTime.compare(last_modified, modified) == :lt do
          Event.emit_thread_updated(state.event_sink, %{
            board: state.board,
            thread: thread,
            timestamp: modified
          })
        end
      else
        :error ->
          Event.emit_thread_updated(state.event_sink, %{
            board: state.board,
            thread: thread,
            timestamp: modified
          })
      end
    end

    {:noreply, %{state | data: threads}}
  end

  @impl true
  def handle_cast(:update, state) do
    load_async(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:prune, deadline}, %{data: data} = state) do
    pruned =
      for {thread, modified} <- data, DateTime.compare(modified, deadline) == :lt do
        Event.emit_thread_pruned(state.event_sink, %{
          board: state.board,
          thread: thread
        })

        thread
      end

    {:noreply, %{state | data: Map.drop(data, pruned)}}
  end

  @spec load_async(state) :: term()
  defp load_async(%{client: client, board: board}) do
    pid = self()

    Client.load_board(client, board, fn threads ->
      GenServer.cast(pid, {:fetched_threads, threads})
    end)
  end
end
