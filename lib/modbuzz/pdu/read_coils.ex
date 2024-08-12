defmodule Modbuzz.PDU.ReadCoils do
  defstruct [:starting_address, :quantity_of_coils]
end

defimpl Modbuzz.PDU, for: Modbuzz.PDU.ReadCoils do
  import Bitwise

  @read_coils 0x01

  def encode(struct) do
    <<@read_coils::8, struct.starting_address::16, struct.quantity_of_coils::16>>
  end

  def decode(struct, <<@read_coils::8, byte_counts::8, coil_status::binary-size(byte_counts)>>) do
    coil_status
    |> :binary.bin_to_list()
    |> Enum.flat_map(&for(i <- 0..7, do: (&1 >>> i &&& 1) == 1))
    |> Enum.take(struct.quantity_of_coils)
    |> then(&{:ok, &1})
  end
end
