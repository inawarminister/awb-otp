defmodule Annoying.FC.Client do
  @moduledoc "Behavior for 4Chan API clients."
  alias Annoying.FC.{Types, Post}

  @type t :: {module(), term()}
  @type board_state :: %{Types.thread() => DateTime.t()}
  @type callback(type) :: (type -> any())
  @type request ::
          {:board, Types.board(), callback(board_state)}
          | {:thread, Types.board(), Types.thread(), callback([Post.t()])}

  @callback load(term(), request) :: :ok

  @spec load_board(t, Types.board(), callback(board_state)) :: :ok
  def load_board({module, term}, board, callback) do
    module.load(term, {:board, board, callback})
  end

  @spec load_thread(t, Types.board(), Types.thread(), callback([Post.t()])) :: :ok
  def load_thread({module, term}, board, thread, callback) do
    module.load(term, {:thread, board, thread, callback})
  end
end
