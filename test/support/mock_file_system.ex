defmodule MagicMime.Test.MockFileSystem do
  @moduledoc """
  Mock implementation of FileSystem for testing.
  """
  def exists?(_path) do
    case Process.get(:mock_file_exists, :default) do
      # Default success
      :default -> true
      result -> result
    end
  end

  def stat(_path) do
    case Process.get(:mock_file_stat, :default) do
      # Default success
      :default -> {:ok, %File.Stat{}}
      result -> result
    end
  end

  # Helper functions for tests
  def set_file_exists_result(result) do
    Process.put(:mock_file_exists, result)
  end

  def set_file_stat_result(result) do
    Process.put(:mock_file_stat, result)
  end

  def reset do
    Process.delete(:mock_file_exists)
    Process.delete(:mock_file_stat)
  end

  # Predefined scenarios
  def simulate_file_not_found do
    set_file_exists_result(false)
  end

  def simulate_file_exists do
    set_file_exists_result(true)
  end

  def simulate_permission_denied do
    set_file_exists_result(true)
    set_file_stat_result({:error, :eacces})
  end

  def simulate_stat_error(reason) do
    set_file_exists_result(true)
    set_file_stat_result({:error, reason})
  end

  def simulate_file_success do
    set_file_exists_result(true)
    set_file_stat_result({:ok, %File.Stat{type: :regular, size: 1024}})
  end
end
