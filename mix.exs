defmodule Modbuzz.MixProject do
  use Mix.Project

  @source_url "https://github.com/tombo-works/modbuzz"

  def project do
    [
      app: :modbuzz,
      version: "0.2.0",
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
      extra_applications:
        [:logger] ++
          case Mix.target() do
            :host -> [:runtime_tools, :wx, :observer]
            _ -> []
          end
    ]
  end

  def pdu_seed() do
    [
      {0x01, ReadCoils},
      {0x02, ReadDiscreteInputs},
      {0x03, ReadHoldingRegisters},
      {0x04, ReadInputRegisters},
      {0x05, WriteSingleCoil},
      {0x06, WriteSingleRegister},
      {0x08, Diagnostics},
      {0x0F, WriteMultipleCoils},
      {0x10, WriteMultipleRegisters}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_uart, "~> 1.5"},
      {:cerlc, "~> 0.2.0"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp hex() do
    [
      description:
        "Yet another MODBUS library, supporting both TCP and RTU, providing gateway functionality.",
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
        nest_modules_by_prefix:
          for {_modbus_function_code, modbus_function} <- pdu_seed() do
            Module.concat([Modbuzz.PDU, modbus_function])
          end
      ]
    ]
  end
end
