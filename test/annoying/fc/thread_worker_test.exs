defmodule Annoying.FC.ThreadWorkerTest do
  use ExUnit.Case, async: true
  alias Annoying.FC.ThreadWorker
  alias Annoying.FC.Post

  defmodule ClientMock do
    use Agent
    alias Annoying.FC.Client
    @behaviour Client

    def start_link(init_state) do
      Agent.start_link(fn -> init_state end)
    end

    @impl Client
    def load(agent, {:thread, _, _, callback}) do
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

  @op %Post{
    op?: true,
    board: "s4s",
    thread: 1,
    number: 1,
    time: ~U[2023-01-01 12:00:00Z],
    poster: "Anonymous",
    subject: "time to shine niceagents",
    comment:
      Floki.parse_document!("""
      lets all give our best to make [s4s] a nicer place :^)
      <br>
      new nicefren thread
      <span class="fortune" style="color:#bac200">
        <br>
        <br>
        <b>Your fortune: Average Luck</b>
      </span>
      """)
  }

  @reply %Post{
    board: "s4s",
    thread: 1,
    number: 2,
    time: ~U[2023-01-01 12:05:00Z],
    poster: "Anonymous",
    comment:
      Floki.parse_document!("""
      <a href="#p1" class="quotelink">&gt;&gt;1</a>
      <br>
      Nice isnt something I'm trying to be, it's what I am!
      """)
  }

  setup do
    client = start_supervised!({ClientMock, [@op]})

    worker =
      start_supervised!({
        ThreadWorker,
        client: {ClientMock, client}, event_sink: {MockEventSink, self()}, board: "s4s", thread: 1
      })

    %{client: client, worker: worker}
  end

  test "sink receives :post_mentioned", %{client: client, worker: worker} do
    ClientMock.set(client, [@op, @reply])
    ThreadWorker.update(worker)

    assert_receive {:post_mentioned,
                    %{board: "s4s", thread: 1, post: @op, old_mentions: 0, new_mentions: 1}}

    ThreadWorker.update(worker)
    refute_receive {:post_mentioned, _}

    ClientMock.set(client, [@op, @reply, @reply])
    ThreadWorker.update(worker)

    assert_receive {:post_mentioned,
                    %{board: "s4s", thread: 1, post: @op, old_mentions: 1, new_mentions: 2}}
  end
end
