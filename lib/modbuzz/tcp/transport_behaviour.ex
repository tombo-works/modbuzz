defmodule Modbuzz.TCP.TransportBehaviour do
  @moduledoc false

  _ = """
  This behaviour provides the exact same interface as :gen_tcp.

  We use `identifier()` as socket type for unit tests.
  """

  @callback connect(
              address :: :inet.socket_address() | :inet.hostname(),
              port :: :inet.port_number(),
              opts :: [:inet.inet_backend() | :gen_tcp.connect_option()],
              timeout :: timeout()
            ) :: {:ok, socket :: identifier()} | {:error, :timeout | :inet.posix()}

  @callback listen(
              port :: :inet.port_number(),
              opts :: [:inet.inet_backend() | :gen_tcp.listen_option()]
            ) :: {:ok, socket :: identifier()} | {:error, :inet.posix()}

  @callback accept(listen_socket :: identifier()) ::
              {:ok, socket :: identifier()} | {:error, :timeout | :inet.posix()}

  @callback close(socket :: identifier()) :: :ok

  @callback controlling_process(socket :: identifier(), pid()) ::
              :ok | {:error, :inet.posix()}

  @callback send(socket :: identifier(), packet :: iodata()) ::
              :ok | {:error, :closed | {:timeout, rest_data :: binary()} | :inet.posix()}

  @callback setopts(socket :: identifier(), opts :: keyword()) ::
              :ok | {:error, :inet.posix()}

  @callback recv(socket :: identifier(), length :: non_neg_integer(), timeout :: timeout()) ::
              {:ok, binary()} | {:error, :closed | :inet.posix()}
end
