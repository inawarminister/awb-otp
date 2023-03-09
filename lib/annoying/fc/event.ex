defmodule Annoying.FC.Event do
  @moduledoc "Common behavior for cache event subscribers."

  @type sink :: {module(), term()}

  @type board :: String.id()
  @type thread :: integer()

  @type thread_updated :: %{
          board: board,
          thread: thread,
          timestamp: DateTime.t()
        }

  @type thread_pruned :: %{
          board: board,
          thread: thread
        }

  @type t ::
          {:thread_updated, thread_updated}
          | {:thread_pruned, thread_pruned}

  @callback process(term(), t) :: :ok

  @spec emit_thread_updated(sink, thread_updated) :: :ok
  def emit_thread_updated({module, term}, event),
    do: module.process(term, {:thread_updated, event})

  @spec emit_thread_pruned(sink, thread_pruned) :: :ok
  def emit_thread_pruned({module, term}, event),
    do: module.process(term, {:thread_pruned, event})
end
