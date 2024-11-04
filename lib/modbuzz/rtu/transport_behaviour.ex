defmodule Modbuzz.RTU.TransportBehaviour do
  @moduledoc false

  _ = """
  This behaviour provides the exact same interface as Circuit.UART.
  """

  @callback start_link(GenServer.options()) :: GenServer.on_start()
  @callback open(GenServer.server(), binary(), [Circuits.UART.uart_option()]) ::
              :ok | {:error, File.posix()}
  @callback controlling_process(GenServer.server(), pid()) :: :ok | {:error, File.posix()}
  @callback write(GenServer.server(), iodata(), non_neg_integer()) :: :ok | {:error, File.posix()}
end
