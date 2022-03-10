defmodule ExNews.MixProject do
  use Mix.Project

  def project do
    [
      app: :exnews,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExNews.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 2.9"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
