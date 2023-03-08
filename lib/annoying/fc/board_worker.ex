defmodule Annoying.FC.BoardWorker do
  use GenServer

  alias Annoying.FC.{Client, Event}

  @type option ::
          {:client, Client.t()}
          | {:event_sink, Event.sink()}
          | {:board, String.t()}
          | {:name, GenServer.name()}

  @spec start_link([option]) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(
      __MODULE__,
      options,
      Keyword.take(options, [:name])
    )
  end

  def update(server) do
    GenServer.cast(server, :update)
  end

  @doc "Signals cache to prune threads older than the specified `deadline`."
  @spec prune(GenServer.server(), DateTime.t()) :: :ok
  def prune(server, deadline) do
    GenServer.cast(server, {:prune, deadline})
  end

  @impl true
  def init(options) do
    state = Enum.into(options, %{data: %{}})
    load_async(state.client, state.board)
    {:ok, state}
  end

  @impl true
  def handle_cast({:fetched_threads, threads}, %{data: data} = state) do
    for {thread, modified} <- threads do
      with {:ok, last_modified} <- Map.fetch(data, thread) do
        if DateTime.compare(last_modified, modified) == :lt do
          Event.emit_thread_updated(state.event_sink, state.board, thread, modified)
        end
      else
        :error -> Event.emit_thread_updated(state.event_sink, state.board, thread, modified)
      end
    end

    {:noreply, %{state | data: threads}}
  end

  @impl true
  def handle_cast(:update, state) do
    load_async(state.client, state.board)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:prune, deadline}, %{data: data} = state) do
    pruned =
      for {thread, modified} <- data, DateTime.compare(modified, deadline) == :lt do
        Event.emit_thread_pruned(state.event_sink, state.board, thread)
        thread
      end

    {:noreply, %{state | data: Map.drop(data, pruned)}}
  end

  defp load_async(client, board) do
    pid = self()

    Annoying.FC.Client.load_board(client, board, fn threads ->
      GenServer.cast(pid, {:fetched_threads, threads})
    end)
  end
end
