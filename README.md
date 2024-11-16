# Modbuzz

[![hex](https://img.shields.io/hexpm/v/modbuzz.svg)](https://hex.pm/packages/modbuzz)
[![CI](https://github.com/tombo-works/modbuzz/actions/workflows/ci.yaml/badge.svg)](https://github.com/tombo-works/modbuzz/actions/workflows/ci.yaml)
[![license](https://img.shields.io/hexpm/l/modbuzz.svg)](https://github.com/tombo-works/modbuzz/blob/main/REUSE.toml)
[![REUSE](https://api.reuse.software/badge/github.com/tombo-works/modbuzz)](https://api.reuse.software/info/github.com/tombo-works/modbuzz)

Yet another MODBUS library, supporting both TCP and RTU, providing gateway functionality.

## Index

- [Usage](#usage)
  - [TCP client](#tcp-client)
  - [RTU client](#rtu-client)
  - [Data server](#data-server)
  - [TCP server](#tcp-server)
  - [RTU server](#rtu-server)
  - [TCP/TCP gateway](#tcp-tcp-gateway)
  - [TCP/RTU gateway](#tcp-rtu-gateway)
  - [RTU/TCP gateway](#rtu-tcp-gateway)
  - [RTU/RTU gateway](#rtu-rtu-gateway)
- [Installation](#installation)
- [License](#license)
- [MODBUS References](#modbus-references)

## Usage

### TCP client

`Modbuzz.start_tcp_client/3` starts a TCP client instance.

`Modbuzz.request/3` requests synchronously.  
The 2nd argument, `unit_id`, can be omitted. If omitted, its value defaults to 0.

```elixir
:ok = Modbuzz.start_tcp_client(:your_tcp_client, {192, 168, 0, 10}, 502)
alias Modbuzz.PDU.WriteSingleCoil
req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
{:ok, _res} = Modbuzz.request(:your_tcp_client, req)
```

### RTU client

`Modbuzz.start_rtu_client/3` starts a RTU client instance.

`Modbuzz.request/3` requests synchronously.  
The 2nd argument, `unit_id`, can be omitted. If omitted, its value defaults to 0.

```elixir
:ok = Modbuzz.start_rtu_client(:your_rtu_client, "ttyUSB0", [speed: 9600])
alias Modbuzz.PDU.WriteSingleCoil
req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
{:ok, _res} = Modbuzz.request(:your_rtu_client, 1, req)
```

### Data server

`Modbuzz.start_data_server/1` starts a Data server instance.  
Data server can be used as data source of TCP/RTU server.

```elixir
:ok = Modbuzz.start_data_server(:your_data_server)
alias Modbuzz.PDU.WriteSingleCoil
req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
res = %WriteSingleCoil.Res{output_address: 0 , output_value: true}
:ok = Modbuzz.create_unit(:your_data_server, 1)
:ok = Modbuzz.upsert(:your_data_server, 1, req, res)
```

### TCP server

`Modbuzz.start_tcp_server/4` starts a TCP server instance.  
The 4th argument, `data_source`, can be [Data server](#data-server)
/ [TCP client](#tcp-client) / [RTU client](#rtu-client).

```elixir
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_data_source)
```

### RTU server

`Modbuzz.start_rtu_server/4` starts a RTU server instance.  
The 4th argument, `data_source`, can be [Data server](#data-server)
/ [TCP client](#tcp-client) / [RTU client](#rtu-client).

```elixir
:ok = Modbuzz.start_tcp_server(:your_rtu_server, "ttyUSB1", [speed: 19200], :your_data_source)
```

### TCP/RTU gateway

TCP server receives a request and pass through it to RTU client.

```elixir
:ok = Modbuzz.start_rtu_client(:your_rtu_client, "ttyUSB0", [speed: 9600])
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_rtu_client)
```

### RTU/TCP gateway

RTU server receives a request and pass through it to TCP client.

```elixir
:ok = Modbuzz.start_tcp_client(:your_tcp_client, {192, 168, 0, 10}, 502)
:ok = Modbuzz.start_rtu_server(:your_rtu_server, "ttyUSB1", [speed: 19200], :your_tcp_client)
```

### TCP/TCP gateway

TCP server receives a request and pass through it to TCP client.

```elixir
:ok = Modbuzz.start_tcp_client(:your_tcp_client, {192, 168, 0, 10}, 502)
:ok = Modbuzz.start_tcp_server(:your_tcp_server, {192, 168, 1, 10}, 502, :your_tcp_client)
```

### RTU/RTU gateway

RTU server receives a request and pass through it to RTU client.

```elixir
:ok = Modbuzz.start_rtu_client(:your_rtu_client, "ttyUSB0", [speed: 9600])
:ok = Modbuzz.start_rtu_server(:your_rtu_server, "ttyUSB1", [speed: 19200], :your_rtu_client)
```

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

## MODBUS References

- WEB: https://modbus.org/
  - PDF: [MODBUS APPLICATION PROTOCOL SPECIFICATION V1.1b3](https://modbus.org/docs/Modbus_Application_Protocol_V1_1b3.pdf)
  - PDF: [MODBUS MESSAGING ON TCP/IP IMPLEMENTATION GUIDE V1.0b](https://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf)

## License

This project is licensed under the Apache-2.0 license.

And this project follows the REUSE compliance.
For more details, see the [REUSE SOFTWARE](https://reuse.software/).
