defmodule Annoying.FC do
  use Supervisor
  alias Annoying.FC.{FinchClient, ThreadWorker, BoardWorker}

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children = [
      {Finch, name: Annoying.FC.Finch},
      {Task.Supervisor, name: Annoying.FC.TaskSupervisor},
      {FinchClient, name: FinchClient},
      {Registry, keys: :unique, name: Annoying.FC.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Annoying.FC.Supervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmodule EventSink do
    @behaviour Annoying.FC.Event
    @impl Annoying.FC.Event
    def process({}, {:thread_updated, board, thread, _timestamp}) do
      Annoying.FC.update_thread(board, thread)
    end
  end

  def spawn_board(board) do
    DynamicSupervisor.start_child(
      Annoying.FC.Supervisor,
      {BoardWorker,
       client: {FinchClient, {}},
       event_sink: {Annoying.FC.EventSink, {}},
       board: board,
       name: {:via, Registry, {Annoying.FC.Registry, {:board, board}}}}
    )
  end

  def list_boards() do
    Registry.select(Annoying.FC.Registry, [
      {
        {{:board, :"$1"}, :"$2", :_},
        [],
        [{{:"$1", :"$2"}}]
      }
    ])
  end

  def update() do
    for {_, pid} <- list_boards(), do: BoardWorker.update(pid)
  end

  def spawn_thread(board, thread) do
    DynamicSupervisor.start_child(
      Annoying.FC.Supervisor,
      {ThreadWorker,
       client: {FinchClient, {}},
       board: board,
       thread: thread,
       name: {:via, Registry, {Annoying.FC.Registry, {:thread, board, thread}}}}
    )
  end

  def lookup_thread(board, thread) do
    pids =
      Registry.select(Annoying.FC.Registry, [
        {
          {{:thread, board, thread}, :"$1", :_},
          [],
          [:"$1"]
        }
      ])

    case pids do
      [] -> {:error, :thread_not_found}
      [pid] -> {:ok, pid}
    end
  end

  def update_thread(board, thread) do
    case lookup_thread(board, thread) do
      {:ok, pid} -> ThreadWorker.update(pid)
      _ -> spawn_thread(board, thread)
    end
  end

  def lookup_post(board, thread, number) do
    with {:ok, pid} <- lookup_thread(board, thread),
         do: ThreadWorker.lookup(pid, number)
  end
end