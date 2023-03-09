defmodule Annoying.DiscordHandler do
  use Nostrum.Consumer

  alias Annoying.FC.Post

  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Message

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, %Message{content: content, channel_id: channel}, _ws_state}) do
    with {:ok, %{board: board, thread: thread, post: post_id}} <- Post.parse_link(content),
         {:ok, post} <- Annoying.FC.lookup_post(board, thread, post_id),
         do: Api.create_message!(channel, embed: as_embed(post))
  end

  def handle_event(_event) do
    :noop
  end

  defp as_embed(%Post{time: time} = post) do
    %Embed{
      title:
        case post do
          %Post{op?: true, number: number, subject: nil} -> "Thread ##{number}"
          %Post{op?: true, number: number, subject: subject} -> "Thread ##{number}: #{subject}"
          %Post{op?: false, thread: thread} -> "Reply to ##{thread}"
        end,
      url: Post.link(post),
      description: Post.text(post),
      thumbnail:
        case Post.attachment_link(post) do
          {:ok, link} -> %Embed.Thumbnail{url: link}
          _ -> nil
        end,
      timestamp: time
    }
  end
end
