defmodule Annoying.MixProject do
  use Mix.Project

  def project do
    [
      app: :annoying,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Annoying.Application, []}
    ]
  end

  defp deps do
    [
      # {:nostrum, "~> 0.6.1"},
      {:nimble_parsec, "~> 1.0"},
      {:quantum, "~> 3.0"},
      {:floki, "~> 0.34.0"},
      {:finch, "~> 0.3.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
