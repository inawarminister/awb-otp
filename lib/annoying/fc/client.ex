defmodule Annoying.FC.Client do
  @moduledoc "Behavior for 4Chan API clients."
  alias Annoying.FC.Post

  @type t :: {module(), term()}

  @type board_id :: String.t()
  @type thread_id :: integer()

  @type board_state :: %{thread_id => DateTime.t()}
  @type callback(type) :: (type -> any())
  @type request ::
          {:board, board_id, callback(board_state)}
          | {:thread, board_id, thread_id, callback([Post.t()])}

  @callback load(term(), request) :: :ok

  @spec load_board(t, board_id, callback(board_state)) :: :ok
  def load_board({module, term}, board, callback) do
    module.load(term, {:board, board, callback})
  end

  @spec load_thread(t, board_id, thread_id, callback([Post.t()])) :: :ok
  def load_thread({module, term}, board, thread, callback) do
    module.load(term, {:thread, board, thread, callback})
  end
end
