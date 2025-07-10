defmodule MagicMime.Test.MockCommandExecutor do
  @moduledoc """
  Mock implementation of CommandExecutor for testing.
  """

  defstruct [
    :find_executable_result,
    :cmd_results
  ]

  def find_executable(_command) do
    case Process.get(:mock_find_executable, :default) do
      # Default success
      :default -> "/usr/bin/file"
      result -> result
    end
  end

  def cmd(_command, _args, _opts) do
    case Process.get(:mock_cmd_result, :default) do
      # Default success
      :default -> {"text/plain", 0}
      {:exception, exception} -> raise exception
      result -> result
    end
  end

  # Helper functions for tests
  def set_find_executable_result(result) do
    Process.put(:mock_find_executable, result)
  end

  def set_cmd_result(result) do
    Process.put(:mock_cmd_result, result)
  end

  def reset do
    Process.delete(:mock_find_executable)
    Process.delete(:mock_cmd_result)
  end

  # Predefined scenarios
  def simulate_file_command_not_found do
    set_find_executable_result(nil)
  end

  def simulate_command_success(output) do
    set_cmd_result({output, 0})
  end

  def simulate_command_error(output, exit_code) do
    set_cmd_result({output, exit_code})
  end

  def simulate_command_exception(exception) do
    set_cmd_result({:exception, exception})
  end

  def simulate_cannot_open_error do
    set_cmd_result({"cannot open `test.txt' (No such file or directory)", 0})
  end

  def simulate_permission_denied_error do
    set_cmd_result({"file: Permission denied: test.txt", 1})
  end

  def simulate_version_output(version) do
    set_cmd_result({"#{version}\nother output", 0})
  end

  def simulate_version_error do
    set_cmd_result({"command not found", 127})
  end
end
