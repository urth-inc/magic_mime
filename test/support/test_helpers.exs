defmodule MagicMime.TestHelpers do
  @moduledoc """
  Common test helpers and utilities for MagicMime tests.
  """

  @fixtures_dir "test/integration/fixtures"

  def fixtures_dir, do: @fixtures_dir

  def setup_file_command_check do
    # Skip tests if file command is not available
    if MagicMime.CLI.file_command_available?() do
      :ok
    else
      {:skip, "file command not available"}
    end
  end

  def create_temp_file(content, suffix \\ ".txt") do
    temp_file = "/tmp/test_#{:rand.uniform(10000)}#{suffix}"
    File.write!(temp_file, content)
    temp_file
  end

  def with_temp_file(content, suffix \\ ".txt", fun) do
    temp_file = create_temp_file(content, suffix)

    try do
      fun.(temp_file)
    after
      File.rm(temp_file)
    end
  end

  def with_permission_denied_file(content, fun) do
    # Create a temporary directory with no access permissions
    base_dir = "/tmp/test_perm_#{:rand.uniform(100000)}"
    File.mkdir_p!(base_dir)

    temp_file = Path.join(base_dir, "inaccessible_file.txt")
    File.write!(temp_file, content)

    # Remove all permissions from the directory, making the file inaccessible
    File.chmod!(base_dir, 0o000)

    try do
      # Verify that the file is actually inaccessible
      case File.stat(temp_file) do
        {:error, :eacces} ->
          fun.(temp_file)
        {:error, :enoent} ->
          fun.(temp_file)  # In some environments, it may appear as non-existent
        {:ok, _} ->
          # If still accessible, fallback to file-level chmod
          File.chmod!(base_dir, 0o755)
          File.chmod!(temp_file, 0o000)
          try do
            fun.(temp_file)
          after
            File.chmod!(temp_file, 0o644)
          end
      end
    after
      # Restore permissions for cleanup
      File.chmod!(base_dir, 0o755)
      File.rm_rf(base_dir)
    end
  end

  def with_path_manipulation(new_path, fun) do
    original_path = System.get_env("PATH")

    try do
      System.put_env("PATH", new_path)
      fun.()
    after
      if original_path, do: System.put_env("PATH", original_path)
    end
  end

  def fixture_path(path_segments) when is_list(path_segments) do
    Path.join([@fixtures_dir | path_segments])
  end

  def fixture_path(path) when is_binary(path) do
    Path.join(@fixtures_dir, path)
  end

  # Image fixture paths
  def png_fixture, do: fixture_path(["imgs", "urth.png"])
  def jpg_fixture, do: fixture_path(["imgs", "urth.jpg"])
  def gif_fixture, do: fixture_path(["imgs", "urth.gif"])
  def svg_fixture, do: fixture_path(["imgs", "urth.svg"])
  def glb_fixture, do: fixture_path(["duck-glb", "Duck.glb"])

  # Text fixture paths
  def text_fixture, do: fixture_path("test.txt")
  def json_fixture, do: fixture_path("test.json")
  def xml_fixture, do: fixture_path("test.xml")
  def shell_fixture, do: fixture_path("test.sh")

  @doc """
  Manual creation helper for test fixture files (run once to setup).

  Note: Fixtures are now committed to git, no auto-generation.
  """
  def create_test_fixtures_manually do
    File.mkdir_p!(@fixtures_dir)
    File.mkdir_p!(fixture_path("imgs"))
    File.mkdir_p!(fixture_path("duck-glb"))

    # Create text fixtures
    File.write!(text_fixture(), "This is a test file.\nIt contains some text for testing.\n")
    File.write!(json_fixture(), ~s({"name": "test", "value": 42, "items": ["a", "b", "c"]}))
    File.write!(xml_fixture(), ~s(<?xml version="1.0"?>\n<root><item>test</item></root>))
    File.write!(shell_fixture(), "#!/bin/bash\necho 'Hello World'\n")

    # Create image fixtures (binary data for different formats)

    # PNG signature (8 bytes) + minimal IHDR chunk
    png_data =
      <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8,
        2, 0, 0, 0, 144, 119, 83, 222>>

    File.write!(png_fixture(), png_data)

    # JPEG signature + minimal SOF marker
    jpeg_data =
      <<255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, 72, 0, 72, 0, 0, 255, 219, 0,
        67, 0, 255, 217>>

    File.write!(jpg_fixture(), jpeg_data)

    # GIF87a signature + minimal data
    gif_data =
      <<71, 73, 70, 56, 55, 97, 1, 0, 1, 0, 0, 0, 0, 44, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 4, 1, 0,
        59>>

    File.write!(gif_fixture(), gif_data)

    # SVG XML content
    svg_data = ~s(<?xml version="1.0"?>
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
  <circle cx="50" cy="50" r="40" fill="blue"/>
</svg>)
    File.write!(svg_fixture(), svg_data)

    # glTF binary (GLB) signature + minimal header
    glb_data =
      <<103, 108, 84, 70, 2, 0, 0, 0, 76, 0, 0, 0, 60, 0, 0, 0, 74, 83, 79, 78, 123, 34, 97, 115,
        115, 101, 116, 34, 58, 123, 34, 118, 101, 114, 115, 105, 111, 110, 34, 58, 34, 50, 46, 48,
        34, 125, 125, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0>>

    File.write!(glb_fixture(), glb_data)

    :ok
  end
end
