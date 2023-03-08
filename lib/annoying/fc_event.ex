defmodule Annoying.FC.Event do
  @moduledoc "Common behavior for cache event subscribers."
  alias Annoying.FC.Types

  @type sink :: {module(), term()}
  @type thread_updated :: {:thread_updated, Types.board(), Types.thread(), DateTime.t()}
  @type t :: thread_updated

  @callback process(term(), t) :: :ok

  @spec emit_thread_updated(sink, Types.board(), Types.thread(), DateTime.t()) :: :ok
  def emit_thread_updated({module, term}, board, thread, timestamp) do
    module.process(term, {:thread_updated, board, thread, timestamp})
  end
end