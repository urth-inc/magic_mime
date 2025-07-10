defmodule MagicMime.FileSystem do
  @moduledoc """
  Protocol for file system operations. Allows dependency injection for testing.
  """

  defmodule File do
    @moduledoc """
    Default implementation using Elixir's File module.
    """

    def exists?(path), do: Elixir.File.exists?(path)

    def stat(path), do: Elixir.File.stat(path)
  end
end
