defmodule Annoying.FC.Post do
  alias __MODULE__

  defstruct [:number, :time, :poster, :subject, :comment, :attachment]

  @type t :: %Post{
          number: integer(),
          time: DateTime.t(),
          poster: String.t(),
          subject: nil | String.t(),
          comment: nil | Floki.html_tree(),
          attachment:
            nil
            | %{
                id: integer(),
                filename: String.t(),
                extension: String.t()
              }
        }
end
