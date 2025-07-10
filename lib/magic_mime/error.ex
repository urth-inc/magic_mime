defmodule MagicMime.Error do
  @moduledoc """
  Custom exception for MagicMime operations.
  """

  defexception [:message, :type, :details]

  @impl true
  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, type: :unknown, details: nil}
  end

  def exception({type, message}) when is_atom(type) and is_binary(message) do
    %__MODULE__{message: message, type: type, details: nil}
  end

  def exception({type, message, details})
      when is_atom(type) and is_binary(message) do
    %__MODULE__{message: message, type: type, details: details}
  end
end
