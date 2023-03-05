defmodule Annoying.FC.ThreadWorker do
  use GenServer, restart: :transient

  alias Finch.Response

  def spawn(board, thread) do
    DynamicSupervisor.start_child(
      Annoying.FC.Supervisor,
      {Annoying.FC.ThreadWorker, {board, thread}}
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

  def start_link({board, thread}) do
    GenServer.start_link(
      __MODULE__,
      {board, thread},
      name: {:via, Registry, {Annoying.FC.Registry, {:thread, board, thread}}}
    )
  end

  @impl true
  def init({board, thread}) do
    load_thread_async(board, thread, self())
    {:ok, %{board: board, thread: thread}}
  end

  @impl true
  def handle_info({:fetched, data}, state) do
    {:noreply, Map.put(state, :data, data)}
  end

  @impl true
  def handle_cast(:update, state) do
    %{board: board, thread: thread} = state
    load_thread_async(board, thread, self())
    {:noreply, state}
  end

  @impl true
  def handle_cast(:delete, _state) do
    {:stop, :normal, %{}}
  end

  def load_thread_async(board, thread, pid) do
    Task.Supervisor.start_child(Annoying.FC.TaskSupervisor, fn ->
      {:ok, %Response{status: 200, body: body}} =
        Finch.build(:get, "https://a.4cdn.org/#{board}/thread/#{thread}.json")
        |> Finch.request(Annoying.FC.Finch)

      send(pid, {:fetched, Jason.decode!(body)})
    end)
  end
end
