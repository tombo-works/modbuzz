defmodule Modbuzz.RTU.Log do
  @moduledoc false

  require Logger

  def error(what_happend, reason, state) do
    Logger.error(what_happend <> why(reason) <> where(state))
  end

  def warning(what_happend, reason, state) do
    Logger.warning(what_happend <> why(reason) <> where(state))
  end

  defp why(nil), do: ""
  defp why(reason), do: ", the reason is #{inspect(reason)}"

  defp where(state) do
    %{device_name: device_name} = state
    " (device_name: #{inspect(device_name)})"
  end
end
