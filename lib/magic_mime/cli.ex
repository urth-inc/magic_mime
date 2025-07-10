defmodule MagicMime.CLI do
  @moduledoc """
  Internal module for executing the `file` command.
  """

  alias MagicMime.{CommandExecutor, FileSystem}

  # Default dependencies
  @default_command_executor CommandExecutor.System
  @default_file_system FileSystem.File

  @doc """
  Checks if the `file` command is available on the system.
  """
  @spec file_command_available?(keyword()) :: boolean()
  def file_command_available?(opts \\ []) do
    command_executor = opts[:command_executor] || @default_command_executor

    case command_executor.find_executable("file") do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Executes the `file` command to detect MIME type for a given file path.
  """
  @spec detect_mime_type(Path.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def detect_mime_type(path, opts \\ []) do
    command_executor = opts[:command_executor] || @default_command_executor

    # Set LANG=C to ensure English error messages for reliable parsing
    env_opts = [env: [{"LANG", "C"}], stderr_to_stdout: true]

    case command_executor.cmd("file", ["--mime-type", "-b", path], env_opts) do
      {output, 0} ->
        mime_type = String.trim(output)

        # Check if the output indicates an error (file command sometimes returns 0 even for errors)
        if String.contains?(mime_type, "cannot open") or
             String.contains?(mime_type, "No such file") do
          {:error, {:command_error, 0, output}}
        else
          {:ok, mime_type}
        end

      {error_output, exit_code} ->
        {:error, {:command_error, exit_code, error_output}}
    end
  rescue
    e in [ErlangError, RuntimeError, ArgumentError] ->
      {:error, e}
  end

  @doc """
  Gets the version of the `file` command.
  """
  @spec get_version(keyword()) :: {:ok, String.t()} | {:error, term()}
  def get_version(opts \\ []) do
    command_executor = opts[:command_executor] || @default_command_executor

    # Set LANG=C for consistent output
    env_opts = [env: [{"LANG", "C"}], stderr_to_stdout: true]

    case command_executor.cmd("file", ["--version"], env_opts) do
      {output, 0} ->
        version = output |> String.split("\n") |> List.first() |> String.trim()
        {:ok, version}

      {error_output, exit_code} ->
        {:error, {:command_error, exit_code, error_output}}
    end
  rescue
    e in [ErlangError, RuntimeError, ArgumentError] ->
      {:error, e}
  end

  @doc """
  Validates if a file path exists and is accessible.
  """
  @spec validate_file_path(Path.t(), keyword()) :: :ok | {:error, term()}
  def validate_file_path(path, opts \\ []) do
    file_system = opts[:file_system] || @default_file_system

    case file_system.exists?(path) do
      false ->
        {:error, :enoent}

      true ->
        case file_system.stat(path) do
          {:ok, _} ->
            :ok

          {:error, :eacces} ->
            {:error, :eacces}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end
end
