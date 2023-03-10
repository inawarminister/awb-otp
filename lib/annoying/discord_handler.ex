defmodule Annoying.DiscordHandler do
  use Nostrum.Consumer

  alias Annoying.FC.Post

  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Message

  @admin_pattern ~r{^awb (?<term>.+)$}

  def start_link() do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, message, _ws_state}) do
    with :ignored <- handle_admin(message),
         :ignored <- handle_content_link(message),
         do: :noop
  end

  def handle_event(_event) do
    :noop
  end

  @spec handle_admin(%Message{}) :: :handled | :ignored
  defp handle_admin(%Message{content: content, channel_id: channel}) do
    :ignored
  end

  defp handle_content_link(%Message{content: content, channel_id: channel}) do
    with {:ok, {board, thread_id, post_id}} <- Post.parse_link(content),
         {:ok, post} <- Annoying.FC.lookup_post(board, thread_id, post_id) do
      embed = as_embed(post)
      Task.Supervisor.start_child(Annoying.DiscordTaskSupervisor, fn ->
        Api.create_message!(channel, embed: embed)
      end, restart: :transient)
      :handled
    else
      _ -> :ignored
    end
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
