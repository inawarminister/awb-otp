defmodule Annoying.FC.BoardWorkerTest do
  use ExUnit.Case, async: true
  alias Annoying.FC.BoardWorker

  defmodule ClientMock do
    use Agent
    alias Annoying.FC.Client
    @behaviour Client

    def start_link(init_state) do
      Agent.start_link(fn -> init_state end)
    end

    @impl Client
    def load(agent, {:board, _, callback}) do
      callback.(Agent.get(agent, fn data -> data end))
    end

    def set(agent, data) do
      Agent.update(agent, fn _ -> data end)
    end
  end

  defmodule MockEventSink do
    @behaviour Annoying.FC.Event
    @impl Annoying.FC.Event
    def process(pid, event), do: send(pid, event)
  end

  setup do
    client = start_supervised!({ClientMock, %{1 => ~U[2023-01-01 12:00:00Z]}})

    worker =
      start_supervised!({
        BoardWorker,
        client: {ClientMock, client}, event_sink: {MockEventSink, self()}, board: "vt"
      })

    %{client: client, worker: worker}
  end

  test "sink receives :thread_updated", %{client: client, worker: worker} do
    assert_receive {:thread_updated,
                    %{board: "vt", thread: 1, timestamp: ~U[2023-01-01 12:00:00Z]}}

    ClientMock.set(client, %{1 => ~U[2023-01-01 12:00:00Z]})
    BoardWorker.update(worker)
    refute_receive {:thread_updated, _}
    ClientMock.set(client, %{1 => ~U[2023-01-01 12:01:00Z]})
    BoardWorker.update(worker)

    assert_receive {:thread_updated,
                    %{board: "vt", thread: 1, timestamp: ~U[2023-01-01 12:01:00Z]}}
  end

  test "sink receives :thread_pruned", %{worker: worker} do
    BoardWorker.prune(worker, ~U[2023-01-01 00:00:00Z])
    refute_receive {:thread_pruned, _}
    BoardWorker.prune(worker, ~U[2023-01-01 12:01:00Z])
    assert_receive {:thread_pruned, %{board: "vt", thread: 1}}
  end
end
