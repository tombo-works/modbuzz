defmodule Modbuzz.MixProject do
  use Mix.Project

  def project do
    [
      app: :modbuzz,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ] ++ docs()
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
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp test_coverage() do
    [
      summary: [threshold: 80],
      ignore_modules: [
        ~r/^Modbuzz\.PDU\.[a-zA-Z0-9]+$/,
        Modbuzz.TCP.Client.Transaction
      ]
    ]
  end

  defp dialyzer() do
    [
      plt_local_path: "priv/plts/modbuzz.plt",
      plt_core_path: "priv/plts/core.plt"
    ]
  end

  defp docs() do
    [
      name: "Modbuzz",
      source_url: "https://github.com/pojiro/modbuzz",
      docs: [
        main: "readme",
        extras: ["README.md"],
        nest_modules_by_prefix: [Modbuzz.PDU]
      ]
    ]
  end
end
