defmodule Modbuzz.PDU do
  @moduledoc """
  MODBUS Protocol Data Unit

  This module defines PDU functions
  """

  import Bitwise

  @read_coils 0x01
  @write_single_coil 0x05

  def encode({:rc, starting_address, quantity_of_coils}) do
    <<@read_coils::8, starting_address::16, quantity_of_coils::16>>
  end

  def encode({:wsc, output_address, output_value}) when is_boolean(output_value) do
    output_value = if output_value, do: 0xFF00, else: 0x0000
    <<@write_single_coil::8, output_address::16, output_value::16>>
  end

  def decode(<<@read_coils::8, byte_counts::8, coil_status::binary-size(byte_counts)>>) do
    coil_status
    |> :binary.bin_to_list()
    |> Enum.flat_map(&for(i <- 0..7, do: (&1 >>> i &&& 1) == 1))
  end
end
