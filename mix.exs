defmodule Modbuzz.MixProject do
  use Mix.Project

  def project do
    [
      app: :modbuzz,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: false,
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp test_coverage() do
    [
      summary: [threshold: 80],
      ignore_modules: []
    ]
  end

  defp dialyzer() do
    [
      plt_local_path: "priv/plts/modbuzz.plt",
      plt_core_path: "priv/plts/core.plt"
    ]
  end
end
