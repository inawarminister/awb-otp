defmodule Annoying.FC.ThreadWorker do
  use GenServer, restart: :transient

  @type option ::
          {:client, Annoying.FC.Client.t()}
          | {:board, String.t()}
          | {:thread, integer()}
          | {:name, GenServer.name()}

  @spec start_link([option]) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(
      __MODULE__,
      options,
      Keyword.take(options, [:name])
    )
  end

  def lookup(pid, number) do
    GenServer.call(pid, {:lookup, number})
  end

  def delete(pid) do
    GenServer.cast(pid, :delete)
  end

  def update(pid) do
    GenServer.cast(pid, :update)
  end

  @impl true
  def init(options) do
    state = Enum.into(options, %{data: []})
    load_async(state.client, state.board, state.thread)
    {:ok, state}
  end

  @impl true
  def handle_call({:lookup, number}, _from, %{data: posts} = state) do
    case Enum.find(posts, fn post -> post.number == number end) do
      nil -> {:reply, {:error, :post_not_found}, state}
      post -> {:reply, {:ok, post}, state}
    end
  end

  @impl true
  def handle_cast({:fetched_thread, data}, state) do
    {:noreply, %{state | data: data}}
  end

  @impl true
  def handle_cast(:update, state) do
    load_async(state.client, state.board, state.thread)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:delete, _state) do
    {:stop, :normal, %{}}
  end

  defp load_async(client, board, thread) do
    pid = self()

    Annoying.FC.Client.load_thread(client, board, thread, fn posts ->
      GenServer.cast(pid, {:fetched_thread, posts})
    end)
  end
end
