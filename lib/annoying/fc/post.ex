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

  @type t :: %Post{
          board: String.t(),
          thread: integer(),
          number: integer(),
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

  @doc "Parse post reference link."
  @spec parse_link(String.t()) ::
          {:ok, %{board: String.t(), thread: integer(), post: integer()}} | :error
  def parse_link(text) do
    case Regex.named_captures(@link_pattern, text) do
      %{"board" => board, "thread" => thread, "post" => post} ->
        {thread_id, ""} = Integer.parse(thread)

        post_id =
          with {parsed, ""} <- Integer.parse(post),
               do: parsed,
               else: (_ -> thread_id)

        {:ok, %{board: board, thread: thread_id, post: post_id}}

      _ ->
        :error
    end
  end

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

  @doc "Returns attachment link if post has an attachment"
  def attachment_link(%Post{board: board} = post) do
    case post.attachment do
      %{id: id, extension: ext} ->
        {:ok, "https://i.4cdn.org/#{board}/#{id}#{ext}"}

      nil ->
        :error
    end
  end

  @doc "Returns post link."
  def link(post) do
    case post do
      %Post{op?: true, board: board, thread: thread} ->
        "https://boards.4channel.org/#{board}/thread/#{thread}"

      %Post{op?: false, board: board, thread: thread, number: number} ->
        "https://boards.4channel.org/#{board}/thread/#{thread}#p#{number}"
    end
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
