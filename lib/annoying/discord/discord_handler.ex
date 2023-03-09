defmodule Annoying.DC.Client do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Struct.Embed


  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE,msg,_ws_state}) do
    if Regex.match?(~r/https:\/\/boards.4channel.org\/[[:alnum:]]+\/thread\/(?<threadno>\d+)(#p(?<postno>\d+))?/,msg.content) do
      caps = Regex.named_captures(~r/https:\/\/boards.4channel.org\/(?<board>[[:alnum:]]+)\/thread\/(?<threadno>\d+)(#p(?<postno>\d+))?/,msg.content)


      {found, embed} =
          Annoying.FC.lookup_post(caps["board"],elem(Integer.parse(caps["threadno"]),0),elem(Integer.parse(if caps["postno"] == "" do caps["threadno"] else caps["postno"] end),0))

      if found == :ok do
        postembed = make_embed(caps["board"],caps["threadno"],embed)
        Api.create_message!(msg.channel_id,embed: postembed)
      end
    end
  end

  def handle_event(_event) do
    :noop
  end

  def make_embed(board,threadno,post) do
    postembed = %Embed{
      title: "Post ##{post.number}",
      url: "https://boards.4channel.org/#{board}/thread/#{threadno}#p#{post.number}",
      description:  cond do post.comment != nil -> Floki.text(post.comment)
                            post.subject != nil -> post.subject
                            true -> ""
                    end,
      thumbnail: if post.attachment != nil do %Embed.Thumbnail{url: "https://i.4cdn.org/vt/#{post.attachment.id}#{post.attachment.extension}"} end,
      timestamp: post.time
    }
    postembed
  end

end
