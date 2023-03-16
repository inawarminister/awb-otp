defmodule Annoying.DiscordAdmin do
  import NimbleParsec
  Module.register_attribute(__MODULE__, :command, accumulate: true)

  @type command :: embeds
  @type embeds :: {:embeds, %{board: String.t(), enabled: bool()}}

  @command {:embeds, enabled: :boolean, board: :board}

  @commands Enum.into(@command, %{}, fn
              {atom, requirements} -> {Atom.to_string(atom), {atom, requirements}}
            end)

  @spec parse_text(String.t()) :: {:ok, command} | {:error, String.t()}
  def parse_text(text) do
    case parse_command(String.trim(text)) do
      {:error, reason, rest, %{}, _pos, _offset} ->
        {:error, "Unable to parse command: #{reason} at `#{rest}`"}

      {:ok, [cmd | args], "", %{}, _pos, _offset} ->
        tranform_cmd(cmd, Enum.into(args, %{}))
    end
  end

  defp tranform_cmd(cmd, args) do
    case Map.fetch(@commands, cmd) do
      :error ->
        similar = Enum.max_by(Map.keys(@commands), &String.jaro_distance(cmd, &1))
        {:error, "Unknown command `#{cmd}`. Did you mean `#{similar}`?"}

      {:ok, {atom, reqs}} ->
        transform_args(atom, reqs, args, %{})
    end
  end

  defp transform_args(cmd, [], _args, pars) do
    {:ok, {cmd, pars}}
  end

  defp transform_args(cmd, [{atom, type} | reqs], args, pars) do
    case Map.fetch(args, Atom.to_string(atom)) do
      :error ->
        {:error, "Missing parameter `#{atom}`"}

      {:ok, val} ->
        with {:ok, sanitized} <- sanitize(atom, type, val) do
          transform_args(cmd, reqs, args, Map.put(pars, atom, sanitized))
        end
    end
  end

  defp sanitize(_, :boolean, {"yes", :id}), do: {:ok, true}
  defp sanitize(_, :boolean, {"no", :id}), do: {:ok, false}

  defp sanitize(name, :boolean, _) do
    {:error, "Incorrect value for `#{name}`, should be `yes` or `no`."}
  end

  defp sanitize(_, :board, {"vt", :id}), do: {:ok, "vt"}

  defp sanitize(name, :board, _) do
    {:error, "Incorrect value for `#{name}`, should be `vt`."}
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
    |> map({:{}, [:string]})

  term_number =
    integer(min: 1)
    |> map({:{}, [:integer]})

  term = choice([term_string, term_number, map(term_id, {:{}, [:id]})])

  rule_parameter =
    term_id
    |> ignore(string(":"))
    |> concat(term_whitespace)
    |> concat(term)
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
