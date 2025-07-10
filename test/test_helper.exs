ExUnit.start()

# Load support files
Code.require_file("support/test_helpers.exs", __DIR__)
Code.require_file("support/mock_command_executor.ex", __DIR__)
Code.require_file("support/mock_file_system.ex", __DIR__)

# Test fixtures are committed to git - no auto-generation needed

# Common test case module
defmodule MagicMime.TestCase do
  # Common macros for all test files
  # Set async: false because tests manipulate global environment variables (PATH, LANG, etc.)
  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: false
      import MagicMime.TestHelpers
      alias MagicMime.{CLI, Error}
    end
  end
end
