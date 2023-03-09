defmodule Annoying.FC.FinchClient do
  use GenServer
  alias Annoying.FC.Client
  alias Annoying.FC.Post
  alias Finch.Response
  @behaviour Client

  def start_link(options) do
    GenServer.start_link(
      __MODULE__,
      [],
      Keyword.take(options, [:name])
    )
  end

  @impl Client
  def load({}, request) do
    GenServer.call(__MODULE__, request)
  end

  @impl true
  def init([]) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:thread, board, thread, callback}, _from, state) do
    Task.Supervisor.start_child(Annoying.FC.TaskSupervisor, fn ->
      {:ok, %Response{status: 200, body: body}} =
        Finch.build(:get, "https://a.4cdn.org/#{board}/thread/#{thread}.json")
        |> Finch.request(Annoying.FC.Finch)

      Jason.decode!(body, keys: :atoms)
      |> parse_thread(board)
      |> callback.()
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:board, board, callback}, _from, state) do
    Task.Supervisor.start_child(Annoying.FC.TaskSupervisor, fn ->
      {:ok, %Response{status: 200, body: body}} =
        Finch.build(:get, "https://a.4cdn.org/#{board}/threads.json")
        |> Finch.request(Annoying.FC.Finch)

      Jason.decode!(body, keys: :atoms)
      |> parse_threads()
      |> callback.()
    end)

    {:reply, :ok, state}
  end

  defp parse_threads(json) do
    for %{threads: list} <- json,
        %{no: number, last_modified: timestamp} <- list,
        {:ok, time} = DateTime.from_unix(timestamp),
        into: %{},
        do: {number, time}
  end

  defp parse_thread(json, board) do
    for post <- json.posts do
      %Post{
        board: board,
        thread: if(post.resto == 0, do: post.no, else: post.resto),
        number: post.no,
        poster: post.name,
        op?: post.resto == 0,
        time: DateTime.from_unix!(post.time),
        subject: Map.get(post, :sub),
        comment: parse_comment(post),
        attachment: parse_attachment(post)
      }
    end
  end

  defp parse_attachment(json) do
    with {:ok, id} <- Map.fetch(json, :tim),
         {:ok, filename} <- Map.fetch(json, :filename),
         {:ok, extension} <- Map.fetch(json, :ext),
         do: %{id: id, filename: filename, extension: extension},
         else: (_ -> nil)
  end

  defp parse_comment(json) do
    with {:ok, html} <- Map.fetch(json, :com),
         {:ok, document} <- Floki.parse_document(html),
         do: document,
         else: (_ -> nil)
  end
end
