defmodule Annoying.DiscordAdmin do
  Module.register_attribute(__MODULE__, :command, accumulate: true)

  @type command :: enable_embeds_t | disable_embeds_t
  @type error :: {:command, String.t()} | {:code, {binary() | {binary(), binary()}, binary()}}

  @doc "Parses `text` and returns an admin command if any is recognized, error message otherwise"
  @spec parse_command(String.t()) :: {:ok, command} | {:error, error}
  def parse_command(text) do
    case Code.string_to_quoted(text, existing_atoms_only: true) do
      {:error, {_, message, token}} ->
        {:error, {:code, message, token}}

      {:ok, form} ->
        case parse_form(form) do
          {:error, message} ->
            {:error, {:command, "Invalid command `#{Macro.to_string(form)}`: #{message}"}}

          {:ok, command} ->
            {:ok, command}
        end
    end
  end

  @type enable_embeds_t :: {:enable_embeds, %{board: String.t()}}
  @command {:enable_embeds,
            [
              {:board, type: &is_binary/1, required_message: "Missing `board` parameter"}
            ]}

  @type disable_embeds_t :: {:disable_embeds, %{board: String.t()}}
  @command {:disable_embeds,
            [
              {:board, type: &is_binary/1, required_message: "Missing `board` parameter"}
            ]}

  @command_strings @command |> Keyword.keys() |> Enum.map(&Atom.to_string/1)

  @spec parse_form(Macro.t()) :: {:ok, command} | {:error, String.t()}
  defp parse_form({command, _, args}) do
    keywords =
      case args do
        [kws] when is_list(kws) -> kws
        _ -> []
      end

    case Keyword.fetch(@command, command) do
      :error ->
        similar =
          Enum.min_by(@command_strings, &String.jaro_distance(Atom.to_string(command), &1))

        {:error, "Did you mean: `#{similar}`?"}

      {:ok, spec} ->
        Enum.reduce(spec, {:ok, {command, %{}}}, fn
          {name, parameter}, {:ok, {command, map}} ->
            case Keyword.fetch(keywords, name) do
              {:ok, value} ->
                if parameter[:type].(value) do
                  {:ok, {command, Map.put(map, name, value)}}
                else
                  {:error, "Invalid type for parameter `#{name}`."}
                end

              :error ->
                case Keyword.fetch(parameter, :required_message) do
                  {:ok, message} ->
                    {:error, message}

                  :error ->
                    {:ok, {command, map}}
                end
            end

          _, error ->
            error
        end)
    end
  end

  defp parse_form(_), do: {:error, "Illegal command form."}
end
