defmodule Annoying.DiscordAdmin do
  import NimbleParsec
  Module.register_attribute(__MODULE__, :command, accumulate: true)

  @type command :: enable_embeds_t | disable_embeds_t
  @type enable_embeds_t :: {:enable_embeds, %{board: String.t()}}
  @type disable_embeds_t :: {:disable_embeds, %{board: String.t()}}

  @command {:enable_embeds, [:board]}
  @command {:disable_embeds, [:board]}
  @commands Enum.into(@command, %{}, fn
              {atom, requirements} -> {Atom.to_string(atom), {atom, requirements}}
            end)

  @spec parse_text(String.t()) :: {:ok, command} | {:error, String.t()}
  def parse_text(text) do
    case parse_command(String.trim(text)) do
      {:error, reason, rest, %{}, _pos, _offset} ->
        {:error, "Unable to parse command: #{reason} at `#{rest}`"}

      {:ok, [name | args], "", %{}, _pos, _offset} ->
        transform_results(name, Enum.into(args, %{}))
    end
  end

  defp transform_results(name, args) do
    case Map.fetch(@commands, name) do
      :error ->
        similar = Enum.max_by(Map.keys(@commands), &String.jaro_distance(name, &1))
        {:error, "Did you mean `#{similar}`?"}

      {:ok, {atom, required}} ->
        transform_args_into(atom, args, required, %{})
    end
  end

  defp transform_args_into(atom, _args, [], map) do
    {:ok, {atom, map}}
  end

  defp transform_args_into(atom, args, [arg | required], map) do
    case Map.fetch(args, Atom.to_string(arg)) do
      :error ->
        {:error, "Missing parameter `#{arg}`"}

      {:ok, value} ->
        transform_args_into(atom, args, required, Map.put(map, arg, value))
    end
  end

  term_whitespace =
    utf8_char([?\s])
    |> repeat()
    |> ignore()

  term_id =
    times(utf8_char([?_, ?a..?z, ?0..?9]), min: 1)
    |> reduce(:to_string)

  term_string =
    ignore(utf8_char([?"]))
    |> repeat(utf8_char([{:not, ?"}]))
    |> ignore(utf8_char([?"]))
    |> reduce(:to_string)

  rule_parameter =
    term_id
    |> ignore(string(":"))
    |> concat(term_whitespace)
    |> concat(term_string)
    |> post_traverse(:post_traverse_rule_parameter)

  defp post_traverse_rule_parameter(r, [value, key], ctx, _line, _offset) do
    {r, [{key, value}], ctx}
  end

  rule_parameter_list =
    rule_parameter
    |> repeat(
      term_whitespace
      |> ignore(string(","))
      |> concat(term_whitespace)
      |> concat(rule_parameter)
    )

  rule_command =
    term_id
    |> concat(term_whitespace)
    |> optional(rule_parameter_list)
    |> eos()

  defparsecp(:parse_command, rule_command)
end
