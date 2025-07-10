defmodule MagicMime do
  @moduledoc """
  Fast and secure MIME type detection using the system's `file` command.

  This library provides a safe interface to detect MIME types for files
  without requiring NIFs or external dependencies (other than the system's
  `file` command).

  ## Examples

      iex> {:ok, mime_type} = MagicMime.detect("mix.exs")
      iex> String.starts_with?(mime_type, "text/")
      true

      iex> mime_type = MagicMime.detect!("mix.exs")
      iex> String.starts_with?(mime_type, "text/")
      true

      iex> results = MagicMime.detect_many(["mix.exs", "README.md"])
      iex> Enum.all?(results, fn {_path, {:ok, mime_type}} -> String.starts_with?(mime_type, "text/") end)
      true

  ## Requirements

  This library requires the `file` command to be available on the system.
  It's pre-installed on most Unix-like systems (Linux, macOS, etc.).

  **Note**: Windows is not supported.
  """

  alias MagicMime.{CLI, Error}

  @type path :: Path.t()
  @type mime_type :: String.t()
  @type error_reason :: atom() | {atom(), term()} | {atom(), term(), term()} | Exception.t()

  @doc """
  Detects the MIME type of a file.

  Returns `{:ok, mime_type}` on success, or `{:error, reason}` on failure.

  ## Options

  - `:command_executor` - Custom command executor for dependency injection
  - `:file_system` - Custom file system for dependency injection

  ## Examples

      iex> {:ok, mime_type} = MagicMime.detect("mix.exs")
      iex> String.starts_with?(mime_type, "text/")
      true

      iex> MagicMime.detect("nonexistent.file")
      {:error, :enoent}

  ## Error Types

  - `:file_command_not_found` - The `file` command is not available
  - `:enoent` - File does not exist
  - `:eacces` - Permission denied
  - `{:command_error, exit_code, stderr}` - Command execution failed
  """
  @spec detect(path(), keyword()) :: {:ok, mime_type()} | {:error, error_reason()}
  def detect(path, opts \\ []) do
    with :ok <- check_file_command_available(opts),
         expanded_path <- Path.expand(path),
         {:ok, mime_type} <- CLI.detect_mime_type(expanded_path, opts) do
      {:ok, mime_type}
    else
      {:error, {:command_error, exit_code, error_output}} ->
        # Parse file command errors to provide better error categorization
        cond do
          String.contains?(error_output, "No such file") or
              (String.contains?(error_output, "cannot open") and
                 String.contains?(error_output, "No such file or directory")) ->
            {:error, :enoent}

          String.contains?(error_output, "Permission denied") ->
            {:error, :eacces}

          true ->
            {:error, {:command_error, exit_code, error_output}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detects the MIME type of a file, raising an exception on failure.

  Returns the MIME type as a string on success, or raises `MagicMime.Error`
  on failure.

  ## Options

  - `:command_executor` - Custom command executor for dependency injection
  - `:file_system` - Custom file system for dependency injection

  ## Examples

      iex> mime_type = MagicMime.detect!("mix.exs")
      iex> String.starts_with?(mime_type, "text/")
      true

      iex> MagicMime.detect!("nonexistent.file")
      ** (MagicMime.Error) File does not exist: nonexistent.file

  """
  @spec detect!(path(), keyword()) :: mime_type() | no_return()
  def detect!(path, opts \\ []) do
    case detect(path, opts) do
      {:ok, mime_type} ->
        mime_type

      {:error, :file_command_not_found} ->
        raise Error, {:file_command_not_found, "The file command is not available on this system"}

      {:error, :enoent} ->
        raise Error, {:enoent, "File does not exist: #{path}"}

      {:error, :eacces} ->
        raise Error, {:eacces, "Permission denied: #{path}"}

      {:error, {:command_error, exit_code, stderr}} ->
        raise Error,
              {:command_error, "Command failed with exit code #{exit_code}",
               %{exit_code: exit_code, stderr: stderr}}

      {:error, %struct{} = exception} when struct in [RuntimeError, ArgumentError, ErlangError] ->
        raise exception
    end
  end

  @doc """
  Detects MIME types for multiple files in parallel.

  Returns a list of tuples containing the file path and the result
  (`{:ok, mime_type}` or `{:error, reason}`).

  ## Options

  - `:concurrency` - Number of concurrent tasks (default: `System.schedulers_online()`)
  - `:command_executor` - Custom command executor for dependency injection
  - `:file_system` - Custom file system for dependency injection

  ## Examples

      iex> results = MagicMime.detect_many(["mix.exs", "README.md"])
      iex> Enum.all?(results, fn {_path, {:ok, mime_type}} -> String.starts_with?(mime_type, "text/") end)
      true

      iex> results = MagicMime.detect_many(["mix.exs", "README.md"], concurrency: 2)
      iex> Enum.all?(results, fn {_path, {:ok, mime_type}} -> String.starts_with?(mime_type, "text/") end)
      true

  """
  @spec detect_many([path()], keyword()) :: [
          {path(), {:ok, mime_type()} | {:error, error_reason()}}
        ]
  def detect_many(paths, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())

    paths
    |> Task.async_stream(
      fn path ->
        {path, detect(path, opts)}
      end,
      max_concurrency: concurrency
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  @doc """
  Checks if MIME type detection is supported on this system.

  Returns `true` if the `file` command is available, `false` otherwise.

  ## Options

  - `:command_executor` - Custom command executor for dependency injection

  ## Examples

      iex> MagicMime.mime_supported?()
      true

  """
  @spec mime_supported?(keyword()) :: boolean()
  def mime_supported?(opts \\ []) do
    CLI.file_command_available?(opts)
  end

  @doc """
  Returns the version of the `file` command.

  Returns `{:ok, version}` on success, or `{:error, reason}` on failure.

  ## Options

  - `:command_executor` - Custom command executor for dependency injection

  ## Examples

      iex> {:ok, version} = MagicMime.version()
      iex> is_binary(version)
      true

      iex> {:ok, version} = MagicMime.version()
      iex> is_binary(version)
      true

  """
  @spec version(keyword()) :: {:ok, String.t()} | {:error, error_reason()}
  def version(opts \\ []) do
    CLI.get_version(opts)
  end

  # Private helper functions

  defp check_file_command_available(opts) do
    if CLI.file_command_available?(opts) do
      :ok
    else
      {:error, :file_command_not_found}
    end
  end
end
