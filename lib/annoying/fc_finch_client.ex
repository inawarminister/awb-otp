defmodule Annoying.FC.FinchClient do
  @moduledoc "4Chan API client backed by Finch."
  alias Annoying.FC.Client
  alias Finch.Response
  @behaviour Client

  @impl Client
  def threads!(board) do
    {:ok, %Response{status: 200, body: body}} =
      Finch.build(:get, "https://a.4cdn.org/#{board}/threads.json")
      |> Finch.request(Annoying.FC.Finch)

    Jason.decode!(body, keys: :atoms)
  end

  @impl Client
  def thread!(board, thread) do
    {:ok, %Response{status: 200, body: body}} =
      Finch.build(:get, "https://a.4cdn.org/#{board}/thread/#{thread}.json")
      |> Finch.request(Annoying.FC.Finch)

    Jason.decode!(body, keys: :atoms)
  end
end
