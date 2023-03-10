defmodule Annoying.FC.ThreadWorker do
  use GenServer, restart: :transient

  alias Annoying.FC.{Client, Event, Post}

  @type state :: %{
          client: Client.t(),
          event_sink: Event.sink(),
          board: Post.board_id(),
          thread: Post.thread_id(),
          name: GenServer.name(),
          data: [Post.t()],
          annotations: nil | annotations
        }

  @type annotations :: %{
          mentions: %{Post.post_id() => integer()}
        }

  @spec start_link(state) :: GenServer.on_start()
  def start_link(init_state) do
    GenServer.start_link(__MODULE__, init_state, name: Map.get(init_state, :name))
  end

  @doc "Asks thread worker to lookup a specified post in the cache."
  @spec lookup(GenServer.server(), Post.post_id()) :: {:ok, Post.t()} | {:error, :post_not_found}
  def lookup(server, post_id) do
    GenServer.call(server, {:lookup, post_id})
  end

  @doc "Signals thread worker process to terminate."
  @spec delete(GenServer.server()) :: :ok
  def delete(server) do
    GenServer.cast(server, :delete)
  end

  @doc "Signals thread worker to perform an update."
  @spec update(GenServer.server()) :: :ok
  def update(server) do
    GenServer.cast(server, :update)
  end

  @impl true
  def init(init_state) do
    load_async(init_state)
    {:ok, init_state}
  end

  @impl true
  def handle_call({:lookup, number}, _from, %{data: posts} = state) do
    case Enum.find(posts, fn post -> post.number == number end) do
      nil -> {:reply, {:error, :post_not_found}, state}
      post -> {:reply, {:ok, post}, state}
    end
  end

  @impl true
  def handle_cast({:fetched_thread, data}, %{annotations: old_annotations} = state) do
    new_annotations = %{
      mentions: Post.map_mentions(data)
    }

    if old_annotations do
      emit_events(data, new_annotations, old_annotations, state)
    end

    {:noreply, %{state | data: data, annotations: new_annotations}}
  end

  @impl true
  def handle_cast(:update, state) do
    load_async(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:delete, _state) do
    {:stop, :normal, %{}}
  end

  @spec load_async(state) :: term()
  defp load_async(%{client: client, board: board, thread: thread}) do
    pid = self()

    Annoying.FC.Client.load_thread(client, board, thread, fn posts ->
      GenServer.cast(pid, {:fetched_thread, posts})
    end)
  end

  @spec emit_events([Post.t()], annotations, annotations, state) :: term()
  defp emit_events(
         updated_thread,
         new_annotations,
         old_annotations,
         %{event_sink: event_sink, board: board, thread: thread} = state
       ) do
    for post <- updated_thread do
      new_mentions = Map.get(new_annotations.mentions, post.number, 0)
      old_mentions = Map.get(old_annotations.mentions, post.number, 0)

      if old_mentions < new_mentions do
        Event.emit_post_mentioned(event_sink, %{
          board: board,
          thread: thread,
          post: post,
          old_mentions: old_mentions,
          new_mentions: new_mentions
        })
      end
    end
  end
end
