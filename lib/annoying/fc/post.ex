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

  @ref_pattern ~r{>>(?<ref>[[:digit:]]+)}

  @doc "Lists posts referenced by this posts' comment."
  def references(%Post{comment: comment}) do
    Floki.find(comment, "a.quotelink")
    |> Enum.map(&Floki.children/1)
    |> List.flatten()
    |> Enum.map(&Regex.named_captures(@ref_pattern, &1))
    |> Enum.flat_map(fn
      %{"ref" => ref} ->
        {number, ""} = Integer.parse(ref)
        [number]

      _ ->
        []
    end)
  end

  @doc "Returns comment as plain text."
  def text(%Post{comment: comment}), do: Floki.text(comment)

  @doc "Traverse a list of posts and build a map of number of mentions to each post."
  @spec map_mentions([Post.t()]) :: %{integer() => integer()}
  def map_mentions(list) do
    list
    |> Enum.map(&Post.references/1)
    |> List.flatten()
    |> Enum.frequencies()
  end
end
