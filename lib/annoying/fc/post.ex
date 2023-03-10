defmodule Annoying.FC.Post do
  alias __MODULE__

  @enforce_keys [:board, :thread, :number, :time, :poster]

  defstruct [
    :board,
    :thread,
    :number,
    :time,
    :poster,
    :subject,
    :comment,
    :attachment,
    op?: false
  ]

  @type board_id :: String.t()
  @type thread_id :: integer()
  @type post_id :: integer()

  @type t :: %Post{
          board: board_id,
          thread: thread_id,
          number: post_id,
          time: DateTime.t(),
          poster: String.t(),
          op?: boolean(),
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
  @link_pattern ~r{https://boards.4channel.org/(?<board>[[:alnum:]]+)/thread/(?<thread>[[:digit:]]+)(#p(?<post>[[:digit:]]))?}

  @doc "Parse post reference link and return post identifier tuple on success."
  @spec parse_link(String.t()) :: {:ok, {board_id, thread_id, post_id}} | nil
  def parse_link(text) do
    case Regex.named_captures(@link_pattern, text) do
      %{"board" => board, "thread" => thread, "post" => post} ->
        {thread_id, ""} = Integer.parse(thread)

        post_id =
          with {parsed, ""} <- Integer.parse(post),
               do: parsed,
               else: (_ -> thread_id)

        {:ok, {board, thread_id, post_id}}

      _ ->
        nil
    end
  end

  @doc "Lists posts referenced by this posts' comment."
  @spec references(%Post{}) :: [post_id]
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

  @doc "Returns attachment link if post has an attachment"
  @spec attachment_link(%Post{}) :: {:ok, String.t()} | nil
  def attachment_link(%Post{board: board, attachment: attachment}) do
    with %{id: id, extension: ext} <- attachment,
         do: {:ok, "https://i.4cdn.org/#{board}/#{id}#{ext}"}
  end

  @doc "Returns post link."
  @spec link(%Post{}) :: String.t()
  def link(post) do
    case post do
      %Post{op?: true, board: board, thread: thread} ->
        "https://boards.4channel.org/#{board}/thread/#{thread}"

      %Post{op?: false, board: board, thread: thread, number: number} ->
        "https://boards.4channel.org/#{board}/thread/#{thread}#p#{number}"
    end
  end

  @doc "Returns comment as plain text."
  @spec text(%Post{}) :: String.t()
  def text(%Post{comment: comment}), do: Floki.text(comment)

  @doc "Traverse a list of posts and build a map of number of mentions to each post."
  @spec map_mentions([Post.t()]) :: %{post_id => integer()}
  def map_mentions(list) do
    list
    |> Enum.map(&Post.references/1)
    |> List.flatten()
    |> Enum.frequencies()
  end
end
