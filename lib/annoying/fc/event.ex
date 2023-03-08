defmodule Annoying.FC.Event do
  @moduledoc "Common behavior for cache event subscribers."
  alias Annoying.FC.Types

  @type sink :: {module(), term()}
  @type thread_updated :: {:thread_updated, Types.board(), Types.thread(), DateTime.t()}
  @type thread_pruned :: {:thread_pruned, Types.board(), Types.thread()}
  @type t :: thread_updated | thread_pruned

  @callback process(term(), t) :: :ok

  @spec emit_thread_updated(sink, Types.board(), Types.thread(), DateTime.t()) :: :ok
  def emit_thread_updated({module, term}, board, thread, timestamp) do
    module.process(term, {:thread_updated, board, thread, timestamp})
  end

  @spec emit_thread_pruned(sink, Types.board(), Types.thread()) :: :ok
  def emit_thread_pruned({module, term}, board, thread) do
    module.process(term, {:thread_pruned, board, thread})
  end
end
