# Modbuzz

[![hex](https://img.shields.io/hexpm/v/modbuzz.svg)](https://hex.pm/packages/modbuzz)
[![CI](https://github.com/tombo-works/modbuzz/actions/workflows/ci.yaml/badge.svg)](https://github.com/tombo-works/modbuzz/actions/workflows/ci.yaml)
[![license](https://img.shields.io/hexpm/l/modbuzz.svg)](https://github.com/tombo-works/modbuzz/blob/main/REUSE.toml)
[![REUSE](https://api.reuse.software/badge/github.com/tombo-works/modbuzz)](https://api.reuse.software/info/github.com/tombo-works/modbuzz)

<p align="center">
  <img src="assets/modbuzz.png" alt="Modbuzz icon" width="220" />
</p>

Yet another MODBUS library, supporting both TCP and RTU, providing gateway functionality.

## Index

- [Usage](#usage)
  - [30-second overview](#30-second-overview)
  - [Quick Start (3 minutes)](#quick-start-3-minutes)
  - [Client usage (primary use case)](#client-usage-primary-use-case)
    - [TCP client](#tcp-client)
    - [RTU client](#rtu-client)
    - [Data server as value source](#data-server-as-value-source)
  - [API map](#api-map)
  - [Synchronous vs asynchronous request](#synchronous-vs-asynchronous-request)
  - [Lifecycle (start and stop)](#lifecycle-start-and-stop)
  - [Server setup](#server-setup)
  - [Gateway recipes](#gateway-recipes)
    - [TCP/RTU gateway](#tcp-rtu-gateway)
    - [RTU/TCP gateway](#rtu-tcp-gateway)
    - [TCP/TCP gateway](#tcp-tcp-gateway)
    - [RTU/RTU gateway](#rtu-rtu-gateway)
  - [Troubleshooting](#troubleshooting)
- [Installation](#installation)
- [License](#license)
- [MODBUS References](#modbus-references)

## Usage

### 30-second overview

Modbuzz provides one consistent public API for:

- Connecting to real MODBUS devices over TCP or RTU.
- Running TCP/RTU clients and servers.
- Building TCP/RTU gateways by connecting a server to another data source.

If you are evaluating this library, start from Quick Start and verify one request end-to-end first.

### Quick Start (3 minutes)

This flow assumes a real MODBUS device is available:

1. Start a TCP client or RTU client.
2. Send one request to the device.
3. Stop the client.

```elixir
:ok = Modbuzz.start_tcp_client(:demo_tcp_client, {192, 168, 0, 10}, 502)

alias Modbuzz.PDU.WriteSingleCoil

req = %WriteSingleCoil.Req{output_address: 0, output_value: true}

{:ok, _res} = Modbuzz.request(:demo_tcp_client, req)

:ok = Modbuzz.stop_tcp_client(:demo_tcp_client)
```

You can also use a data server as an in-memory value source behind TCP/RTU servers.

### Client usage (primary use case)

#### TCP client

`Modbuzz.start_tcp_client/3` starts a TCP client instance.

`Modbuzz.request/2` or `Modbuzz.request/3` requests synchronously. The 2nd argument, `unit_id`, can be omitted. If omitted, its value defaults to 0.

```elixir
:ok = Modbuzz.start_tcp_client(:your_tcp_client, {192, 168, 0, 10}, 502)
alias Modbuzz.PDU.WriteSingleCoil
req = %WriteSingleCoil.Req{output_address: 0, output_value: true}
{:ok, _res} = Modbuzz.request(:your_tcp_client, req)
```

#### RTU client

`Modbuzz.start_rtu_client/3` starts an RTU client instance.

`Modbuzz.request/2` or `Modbuzz.request/3` requests synchronously. The 2nd argument, `unit_id`, can be omitted. If omitted, its value defaults to 0.

```elixir
:ok = Modbuzz.start_rtu_client(:your_rtu_client, "ttyUSB0", [speed: 9600])
alias Modbuzz.PDU.WriteSingleCoil
req = %WriteSingleCoil.Req{output_address: 0, output_value: true}
{:ok, _res} = Modbuzz.request(:your_rtu_client, 1, req)
```

#### Data server as value source

`Modbuzz.start_data_server/1` starts a data server instance.
Data server lets you expose your own application data (for example, sensor values) as Modbus values through TCP/RTU servers.

```elixir
:ok = Modbuzz.start_data_server(:your_data_server)
alias Modbuzz.PDU.WriteSingleCoil
req = %WriteSingleCoil.Req{output_address: 0, output_value: true}
res = %WriteSingleCoil.Res{output_address: 0, output_value: true}
:ok = Modbuzz.create_unit(:your_data_server, 1)
:ok = Modbuzz.upsert(:your_data_server, 1, req, res)
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_data_server)
```

In this setup, external Modbus clients can read/write values through your TCP/RTU server, backed by the data server mappings.

### API map

| Goal | API |
| --- | --- |
| Send a request and wait for result | `Modbuzz.request/2`, `Modbuzz.request/3`, `Modbuzz.request/4` |
| Send a request and receive by message | `Modbuzz.request_async/2`, `Modbuzz.request_async/3`, `Modbuzz.request_async/4`, `Modbuzz.request_async/5` |
| Start/stop data server | `Modbuzz.start_data_server/1`, `Modbuzz.stop_data_server/1` |
| Manage data server content | `Modbuzz.create_unit/1`, `Modbuzz.create_unit/2`, `Modbuzz.upsert/3`, `Modbuzz.upsert/4`, `Modbuzz.delete/2`, `Modbuzz.delete/3`, `Modbuzz.dump/1`, `Modbuzz.dump/2` |
| Start/stop TCP client | `Modbuzz.start_tcp_client/3`, `Modbuzz.stop_tcp_client/1` |
| Start/stop RTU client | `Modbuzz.start_rtu_client/3`, `Modbuzz.stop_rtu_client/1` |
| Start/stop TCP server | `Modbuzz.start_tcp_server/4`, `Modbuzz.stop_tcp_server/1` |
| Start/stop RTU server | `Modbuzz.start_rtu_server/4`, `Modbuzz.stop_rtu_server/1` |

For detailed external API behavior, see [External API Guide](external_api.md).

### Synchronous vs asynchronous request

`Modbuzz.request/2`, `/3`, and `/4` are synchronous and return result directly.

`Modbuzz.request_async/2`, `/3`, `/4`, and `/5` return `:ok` immediately and send result as a message:

```elixir
{:modbuzz, name, unit_id, request, {:ok, response}}
{:modbuzz, name, unit_id, request, {:error, error_response_or_error_reason}}
```

Use synchronous request for simple command flow.
Use asynchronous request when you need non-blocking behavior or concurrent request orchestration.

### Lifecycle (start and stop)

Start functions return:

- `:ok`
- `{:error, :already_started}`

Stop functions return:

- `:ok`
- `{:error, :not_started}`

It is safe to call stop even when the process may already be down, as long as you handle `{:error, :not_started}`.

### Server setup

`data_source` for `Modbuzz.start_tcp_server/4` and `Modbuzz.start_rtu_server/4` can be:

- Data server name
- TCP client name
- RTU client name

TCP server example:

```elixir
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_data_source)
```

RTU server example:

```elixir
:ok = Modbuzz.start_rtu_server(:your_rtu_server, "ttyUSB1", [speed: 19200], :your_data_source)
```

### Gateway recipes

Use these recipes after you confirm Quick Start works.

#### TCP/RTU gateway

TCP server receives a request and passes it through to RTU client.

```elixir
:ok = Modbuzz.start_rtu_client(:your_rtu_client, "ttyUSB0", [speed: 9600])
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_rtu_client)
```

#### RTU/TCP gateway

RTU server receives a request and passes it through to TCP client.

```elixir
:ok = Modbuzz.start_tcp_client(:your_tcp_client, {192, 168, 0, 10}, 502)
:ok = Modbuzz.start_rtu_server(:your_rtu_server, "ttyUSB1", [speed: 19200], :your_tcp_client)
```

#### TCP/TCP gateway

TCP server receives a request and passes it through to TCP client.

```elixir
:ok = Modbuzz.start_tcp_client(:your_tcp_client, {192, 168, 0, 10}, 502)
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_tcp_client)
```

#### RTU/RTU gateway

RTU server receives a request and passes it through to RTU client.

```elixir
:ok = Modbuzz.start_rtu_client(:your_rtu_client, "ttyUSB0", [speed: 9600])
:ok = Modbuzz.start_rtu_server(:your_rtu_server, "ttyUSB1", [speed: 19200], :your_rtu_client)
```

### Troubleshooting

- Timeout on request:
  Check that the client/server is started, the device is reachable, and the request matches the expected unit/address.
- No async result message:
  `request_async` returns `:ok` even if the target process is not running. Verify the client/server startup first.
- Wrong or missing unit data:
  If you are using a data server as backend source, ensure `create_unit/2` was called with the same `unit_id` used by the request.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `modbuzz` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:modbuzz, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/modbuzz>.

## License

This project is licensed under the Apache-2.0 license.

And this project follows the REUSE compliance.
For more details, see the [REUSE SOFTWARE](https://reuse.software/).

## MODBUS References

- WEB: https://modbus.org/
