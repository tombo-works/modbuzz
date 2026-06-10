# External API Guide

This guide focuses on the external API in `Modbuzz`.

If you are new to this library, read in this order:

1. README Quick Start
2. Request APIs (`request`, `request_async`)
3. Lifecycle APIs (`start_*`, `stop_*`)
4. Optional data server APIs (`create_unit`, `upsert`, `delete`, `dump`)

## Request APIs

### Synchronous request

- `Modbuzz.request(name, request)`
- `Modbuzz.request(name, unit_id, request)`
- `Modbuzz.request(name, unit_id, request, timeout)`

Use synchronous request for straightforward command flows.

Expected returns:

- `{:ok, response}`
- `{:error, error_response}`
- `{:error, reason}`

### Asynchronous request

- `Modbuzz.request_async(name, request)`
- `Modbuzz.request_async(name, unit_id, request)`
- `Modbuzz.request_async(name, unit_id, request, pid)`
- `Modbuzz.request_async(name, unit_id, request, pid, timeout)`

Use asynchronous request when non-blocking behavior is required.

`request_async` returns `:ok` immediately and sends one result message:

```elixir
{:modbuzz, name, unit_id, request, {:ok, response}}
{:modbuzz, name, unit_id, request, {:error, error_response_or_error_reason}}
```

## Lifecycle APIs

Start APIs:

- `Modbuzz.start_data_server/1`
- `Modbuzz.start_tcp_client/3`
- `Modbuzz.start_rtu_client/3`
- `Modbuzz.start_tcp_server/4`
- `Modbuzz.start_rtu_server/4`

Stop APIs:

- `Modbuzz.stop_data_server/1`
- `Modbuzz.stop_tcp_client/1`
- `Modbuzz.stop_rtu_client/1`
- `Modbuzz.stop_tcp_server/1`
- `Modbuzz.stop_rtu_server/1`

Common return values:

- Start: `:ok | {:error, :already_started}`
- Stop: `:ok | {:error, :not_started}`

## Data server APIs

Use these when you want a local test double without hardware.

- `Modbuzz.create_unit/2`
- `Modbuzz.upsert/4`
- `Modbuzz.delete/3`
- `Modbuzz.dump/2`

Each API above also has a shorter form without explicit `unit_id`:

- `Modbuzz.create_unit/1`
- `Modbuzz.upsert/3`
- `Modbuzz.delete/2`
- `Modbuzz.dump/1`

Hardware-first flow:

```elixir
:ok = Modbuzz.start_tcp_client(:client, {192, 168, 0, 10}, 502)
{:ok, _response} = Modbuzz.request(:client, request)
:ok = Modbuzz.stop_tcp_client(:client)
```

Optional local test-double flow:

```elixir
:ok = Modbuzz.start_data_server(:data)
:ok = Modbuzz.create_unit(:data, 1)
:ok = Modbuzz.upsert(:data, 1, request, response)
{:ok, ^response} = Modbuzz.request(:data, 1, request)
:ok = Modbuzz.stop_data_server(:data)
```

## Choosing a data source for servers

`Modbuzz.start_tcp_server/4` and `Modbuzz.start_rtu_server/4` accept these as `data_source`:

- Data server name
- TCP client name
- RTU client name

This enables TCP/RTU gateway patterns without changing request API shape.
