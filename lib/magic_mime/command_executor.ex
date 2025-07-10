defmodule MagicMime.CommandExecutor do
  @moduledoc """
  Protocol for executing system commands. Allows dependency injection for testing.
  """

  defmodule System do
    @moduledoc """
    Default implementation using Elixir's System module.
    """

    def find_executable(command), do: Elixir.System.find_executable(command)

    def cmd(command, args, opts), do: Elixir.System.cmd(command, args, opts)
  end
end
