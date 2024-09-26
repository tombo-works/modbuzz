defmodule Modbuzz.TCP.Log do
  @moduledoc false

  require Logger

  def debug(what_happend) do
    Logger.debug(what_happend)
  end

  def debug(what_happend, state) do
    Logger.debug(what_happend <> where(state))
  end

  def error(what_happend) do
    Logger.error(what_happend)
  end

  def error(what_happend, reason, state) do
    Logger.error(what_happend <> why(reason) <> where(state))
  end

  def warning(what_happend, reason, state) do
    Logger.warning(what_happend <> why(reason) <> where(state))
  end

  defp why(nil), do: ""
  defp why(reason), do: ", the reason is #{inspect(reason)}"

  defp where(state) do
    %{address: address, port: port} = state
    " (address: #{inspect(address)}, port: #{inspect(port)})"
  end
end
