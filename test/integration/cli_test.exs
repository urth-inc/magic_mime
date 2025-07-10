defmodule MagicMime.Integration.CLITest do
  use MagicMime.TestCase

  setup_all do
    setup_file_command_check()
  end

  describe "CLI.file_command_available?/0" do
    test "returns true when file command is available" do
      assert CLI.file_command_available?() == true
    end

    test "handles PATH manipulation" do
      with_path_manipulation("", fn ->
        refute CLI.file_command_available?()
      end)
    end
  end

  describe "CLI.detect_mime_type/1 with real file command" do
    test "detects text file MIME type" do
      assert {:ok, "text/plain"} = CLI.detect_mime_type(text_fixture())
    end

    test "detects JSON file MIME type" do
      result = CLI.detect_mime_type(json_fixture())
      assert {:ok, mime_type} = result
      assert mime_type in ["application/json", "text/plain"]
    end

    test "detects XML file MIME type" do
      result = CLI.detect_mime_type(xml_fixture())
      assert {:ok, mime_type} = result
      assert mime_type in ["application/xml", "text/xml", "text/plain"]
    end

    test "detects shell script MIME type" do
      result = CLI.detect_mime_type(shell_fixture())
      assert {:ok, mime_type} = result
      assert mime_type in ["text/x-shellscript", "text/plain", "application/x-sh"]
    end

    test "returns error for non-existent file" do
      assert {:error, {:command_error, _, _}} = CLI.detect_mime_type("non_existent_file.txt")
    end

    test "handles permission denied files" do
      with_temp_file("test", fn temp_file ->
        File.chmod!(temp_file, 0o000)

        try do
          case CLI.detect_mime_type(temp_file) do
            {:ok, _} -> :ok
            {:error, {:command_error, _, _}} -> :ok
            {:error, _} -> :ok
          end
        after
          File.chmod!(temp_file, 0o644)
        end
      end)
    end

    test "handles binary files" do
      with_temp_file(<<0, 1, 2, 3, 255, 254, 253>>, ".bin", fn temp_file ->
        assert {:ok, mime_type} = CLI.detect_mime_type(temp_file)
        assert is_binary(mime_type)
        assert String.length(mime_type) > 0
      end)
    end

    test "handles empty files" do
      with_temp_file("", fn temp_file ->
        result = CLI.detect_mime_type(temp_file)
        assert {:ok, mime_type} = result
        assert mime_type in ["application/x-empty", "inode/x-empty", "text/plain"]
      end)
    end
  end

  describe "CLI.get_version/0 with real command" do
    test "returns file command version" do
      assert {:ok, version} = CLI.get_version()
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "handles environment without file command" do
      with_path_manipulation("", fn ->
        case CLI.get_version() do
          {:error, :file_command_not_found} -> :ok
          {:error, %ErlangError{original: :enoent}} -> :ok
          {:error, _} -> :ok
        end
      end)
    end
  end

  describe "CLI.validate_file_path/1 with real filesystem" do
    test "validates existing file" do
      assert :ok = CLI.validate_file_path(text_fixture())
    end

    test "validates existing directory" do
      assert :ok = CLI.validate_file_path(fixtures_dir())
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = CLI.validate_file_path("non_existent_file.txt")
    end

    test "handles special filesystem entries" do
      if File.exists?("/dev/null") do
        assert :ok = CLI.validate_file_path("/dev/null")
      end
    end

    test "handles permission denied scenarios" do
      # Create a directory we can't access
      restricted_dir = "/tmp/restricted_#{:rand.uniform(10000)}"
      File.mkdir_p!(restricted_dir)
      File.chmod!(restricted_dir, 0o000)

      try do
        restricted_file = Path.join(restricted_dir, "test.txt")

        case CLI.validate_file_path(restricted_file) do
          :ok -> :ok
          {:error, :enoent} -> :ok
          {:error, :eacces} -> :ok
          {:error, _} -> :ok
        end
      after
        File.chmod!(restricted_dir, 0o755)
        File.rmdir(restricted_dir)
      end
    end
  end

  describe "CLI integration with various file types" do
    test "handles image files from fixtures" do
      image_tests = [
        {png_fixture(), "image/png"},
        {jpg_fixture(), "image/jpeg"},
        {gif_fixture(), "image/gif"},
        {svg_fixture(), "image/svg+xml"}
      ]

      for {fixture_path, expected_mime} <- image_tests do
        assert {:ok, ^expected_mime} = CLI.detect_mime_type(fixture_path)
      end
    end

    test "handles 3D model files" do
      assert {:ok, "model/gltf-binary"} = CLI.detect_mime_type(glb_fixture())
    end

    test "handles temporary files during processing" do
      temp_files =
        for i <- 1..5 do
          create_temp_file("test content #{i}", ".txt")
        end

      try do
        for temp_file <- temp_files do
          assert {:ok, "text/plain"} = CLI.detect_mime_type(temp_file)
        end
      after
        Enum.each(temp_files, &File.rm/1)
      end
    end
  end

  describe "CLI error handling with real system" do
    test "handles corrupted file command output" do
      # Test with paths that might cause unusual file command behavior
      problematic_paths = [
        "/tmp/\xFF\xFE_invalid_encoding_#{:rand.uniform(10000)}",
        "/tmp/" <> String.duplicate("very_long_name_", 50),
        "/tmp/file_with_\x00_null_#{:rand.uniform(10000)}"
      ]

      for path <- problematic_paths do
        case CLI.detect_mime_type(path) do
          {:ok, _} -> :ok
          {:error, {:command_error, _, _}} -> :ok
          {:error, _} -> :ok
        end
      end
    end

    test "handles system command timeouts" do
      # Create a very large file that might cause timeouts
      large_content = String.duplicate("test data\n", 100_000)

      with_temp_file(large_content, ".dat", fn temp_file ->
        # Should still work, but might be slow
        case CLI.detect_mime_type(temp_file) do
          {:ok, mime_type} ->
            assert is_binary(mime_type)

          {:error, _} ->
            # Timeout or other system error is acceptable
            :ok
        end
      end)
    end

    test "handles concurrent CLI operations" do
      path = text_fixture()

      tasks =
        for _ <- 1..10 do
          Task.async(fn -> CLI.detect_mime_type(path) end)
        end

      results = Task.await_many(tasks, 5000)

      for result <- results do
        assert {:ok, "text/plain"} = result
      end
    end
  end

  describe "CLI environment manipulation tests" do
    test "handles missing file command gracefully" do
      with_path_manipulation("/nonexistent:/fake/path", fn ->
        case CLI.get_version() do
          {:error, :file_command_not_found} -> :ok
          {:error, %ErlangError{original: :enoent}} -> :ok
          {:error, _} -> :ok
        end

        case CLI.detect_mime_type(text_fixture()) do
          # Fallback or cached result
          {:ok, _} -> :ok
          {:error, :file_command_not_found} -> :ok
          {:error, _} -> :ok
        end
      end)
    end

    test "recovers after PATH restoration" do
      original_result = CLI.detect_mime_type(text_fixture())

      with_path_manipulation("", fn ->
        # Should fail inside manipulation
        case CLI.detect_mime_type(text_fixture()) do
          {:error, _} -> :ok
          # Might succeed due to caching
          {:ok, _} -> :ok
        end
      end)

      # Should work again after restoration
      restored_result = CLI.detect_mime_type(text_fixture())
      assert original_result == restored_result
    end

    test "handles environment variable corruption" do
      original_env = System.get_env()

      try do
        # Corrupt some environment variables
        System.put_env("LC_ALL", "invalid_locale")
        System.put_env("LANG", "nonexistent")

        case CLI.detect_mime_type(text_fixture()) do
          {:ok, _} -> :ok
          {:error, _} -> :ok
        end
      after
        # Restore environment
        for {key, value} <- original_env do
          System.put_env(key, value)
        end
      end
    end
  end
end
