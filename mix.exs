defmodule Modbuzz.MixProject do
  use Mix.Project

  @source_url "https://github.com/tombo-works/modbuzz"

  def project do
    [
      app: :modbuzz,
      version: "0.1.2",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ] ++ hex() ++ docs()
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Modbuzz.Application, []},
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

  defp hex() do
    [
      description: "Yet another MODBUS TCP library.",
      package: [
        files: ~w"LICENSES lib README.md REUSE.toml mix.exs",
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => @source_url}
      ]
    ]
  end

  defp test_coverage() do
    [
      summary: [threshold: 80],
      ignore_modules: [
        ~r/^Modbuzz\.PDU\.[a-zA-Z0-9]+\.(Req|Res|Err)$/,
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
      source_url: @source_url,
      docs: [
        main: "readme",
        extras: ["README.md"],
        nest_modules_by_prefix: [
          Modbuzz.PDU
        ]
      ]
    ]
  end
end
