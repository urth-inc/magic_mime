defmodule MagicMime.Integration.SystemTest do
  use MagicMime.TestCase

  setup_all do
    setup_file_command_check()
  end

  describe "MagicMime.detect/1 integration" do
    test "detects MIME types for real files" do
      assert {:ok, "text/plain"} = MagicMime.detect(text_fixture())
      assert {:ok, "image/png"} = MagicMime.detect(png_fixture())
      assert {:ok, "model/gltf-binary"} = MagicMime.detect(glb_fixture())
    end

    test "handles file not found errors" do
      # Should specifically return :enoent for non-existent files
      assert {:error, :enoent} = MagicMime.detect("non_existent_file.txt")
      assert {:error, :enoent} = MagicMime.detect("definitely_does_not_exist.txt")
      assert {:error, :enoent} = MagicMime.detect("/path/to/nowhere/file.txt")
    end

    test "handles permission denied errors" do
      with_temp_file("test", fn temp_file ->
        File.chmod!(temp_file, 0o000)

        try do
          # Should specifically return :eacces when permission is denied
          assert {:error, :eacces} = MagicMime.detect(temp_file)
        after
          File.chmod!(temp_file, 0o644)
        end
      end)
    end

    test "handles system command unavailable" do
      with_path_manipulation("", fn ->
        # Should specifically return :file_command_not_found when file command is unavailable
        assert {:error, :file_command_not_found} = MagicMime.detect(text_fixture())
      end)
    end
  end

  describe "MagicMime.detect!/1 integration" do
    test "returns MIME type for valid files" do
      assert "text/plain" = MagicMime.detect!(text_fixture())
      assert "image/png" = MagicMime.detect!(png_fixture())
    end

    test "raises Error for non-existent files" do
      assert_raise Error, ~r/File does not exist/, fn ->
        MagicMime.detect!("non_existent_file.txt")
      end
    end

    test "raises Error when file command unavailable" do
      with_path_manipulation("", fn ->
        assert_raise Error, ~r/file command is not available/, fn ->
          MagicMime.detect!("any_file.txt")
        end
      end)
    end

    test "raises Error for permission denied" do
      with_temp_file("test", fn temp_file ->
        File.chmod!(temp_file, 0o000)

        try do
          # Should specifically raise Error with permission denied message
          assert_raise Error, ~r/Permission denied/, fn ->
            MagicMime.detect!(temp_file)
          end
        after
          File.chmod!(temp_file, 0o644)
        end
      end)
    end
  end

  describe "MagicMime.detect/2 error categorization" do
    test "consistently categorizes permission denied errors" do
      with_temp_file("permission test", fn temp_file ->
        File.chmod!(temp_file, 0o000)

        try do
          # Test multiple attempts to ensure consistency
          for _i <- 1..3 do
            assert {:error, :eacces} = MagicMime.detect(temp_file)
          end
        after
          File.chmod!(temp_file, 0o644)
        end
      end)
    end

    test "consistently categorizes various non-existent file patterns" do
      non_existent_files = [
        "does_not_exist.txt",
        "/tmp/fake_file_#{:rand.uniform(999_999)}.txt",
        "#{System.tmp_dir()}/missing_#{:rand.uniform(999_999)}.bin"
      ]

      for file <- non_existent_files do
        # Each should specifically return :enoent regardless of path pattern
        assert {:error, :enoent} = MagicMime.detect(file)
      end
    end

    test "file command unavailable is consistently detected" do
      with_path_manipulation("", fn ->
        # Test multiple attempts to ensure consistency
        for _i <- 1..3 do
          assert {:error, :file_command_not_found} = MagicMime.detect("any_file.txt")
        end
      end)
    end
  end

  describe "MagicMime.detect_many/2 integration" do
    test "processes multiple files successfully" do
      files = [text_fixture(), png_fixture(), jpg_fixture()]
      results = MagicMime.detect_many(files)

      assert length(results) == 3

      for {_path, result} <- results do
        assert {:ok, _mime_type} = result
      end
    end

    test "handles mix of valid and invalid files" do
      files = [
        text_fixture(),
        "non_existent.txt",
        png_fixture(),
        "another_fake.bin"
      ]

      results = MagicMime.detect_many(files)
      assert length(results) == 4

      results_map = Map.new(results)
      assert {:ok, "text/plain"} = results_map[text_fixture()]
      assert {:ok, "image/png"} = results_map[png_fixture()]
      assert {:error, :enoent} = results_map["non_existent.txt"]
      assert {:error, :enoent} = results_map["another_fake.bin"]
    end

    test "respects concurrency setting" do
      files =
        Enum.map(1..20, fn i ->
          create_temp_file("test content #{i}", ".txt")
        end)

      try do
        start_time = System.monotonic_time(:millisecond)
        results = MagicMime.detect_many(files, concurrency: 5)
        end_time = System.monotonic_time(:millisecond)

        duration = end_time - start_time

        # Should complete reasonably quickly with concurrency
        # 10 seconds
        assert duration < 10_000
        assert length(results) == 20

        for {_path, result} <- results do
          assert {:ok, "text/plain"} = result
        end
      after
        Enum.each(files, &File.rm/1)
      end
    end

    test "handles high file count" do
      large_file_list = Enum.map(1..100, fn _i -> text_fixture() end)

      results = MagicMime.detect_many(large_file_list, concurrency: 10)
      assert length(results) == 100

      for {_path, result} <- results do
        assert {:ok, "text/plain"} = result
      end
    end
  end

  describe "MagicMime.version/0 integration" do
    test "returns file command version when available" do
      {:ok, version} = MagicMime.version()
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "returns error when file command unavailable" do
      with_path_manipulation("", fn ->
        assert {:error, _} = MagicMime.version()
      end)
    end

    test "handles corrupted PATH gracefully" do
      with_path_manipulation("/fake:/nonexistent:/also/fake", fn ->
        case MagicMime.version() do
          {:ok, version} -> assert is_binary(version)
          {:error, _} -> :ok
        end
      end)
    end
  end

  describe "system integration edge cases" do
    test "handles rapid successive calls" do
      file_path = text_fixture()

      # Make many rapid calls
      results =
        for _ <- 1..50 do
          MagicMime.detect(file_path)
        end

      # All should succeed
      for result <- results do
        assert {:ok, "text/plain"} = result
      end
    end

    test "handles interleaved detect and detect! calls" do
      file_path = png_fixture()

      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            if rem(i, 2) == 0 do
              MagicMime.detect(file_path)
            else
              {:ok, MagicMime.detect!(file_path)}
            end
          end)
        end

      results = Task.await_many(tasks, 5000)

      for result <- results do
        case result do
          {:ok, "image/png"} -> :ok
          "image/png" -> :ok
        end
      end
    end

    test "survives system stress scenarios" do
      # Create temporary stress
      stress_files =
        for i <- 1..10 do
          create_temp_file(String.duplicate("stress test #{i}\n", 1000), ".txt")
        end

      try do
        # Process with high concurrency
        results = MagicMime.detect_many(stress_files, concurrency: 20)

        assert length(results) == 10

        for {_path, result} <- results do
          assert {:ok, "text/plain"} = result
        end

        # Verify system still works after stress
        assert {:ok, "text/plain"} = MagicMime.detect(text_fixture())
      after
        Enum.each(stress_files, &File.rm/1)
      end
    end

    test "handles filesystem race conditions" do
      temp_file = create_temp_file("race condition test")

      try do
        # Start multiple operations
        task1 = Task.async(fn -> MagicMime.detect(temp_file) end)

        # Delete file during processing
        spawn(fn ->
          :timer.sleep(1)
          File.rm(temp_file)
        end)

        task2 =
          Task.async(fn ->
            :timer.sleep(5)
            MagicMime.detect(temp_file)
          end)

        # First might succeed, second should fail
        result1 = Task.await(task1, 1000)
        result2 = Task.await(task2, 1000)

        case result1 do
          {:ok, "text/plain"} -> :ok
          {:error, _} -> :ok
        end

        case result2 do
          # Race condition - file might still exist
          {:ok, _} -> :ok
          {:error, :enoent} -> :ok
          {:error, _} -> :ok
        end
      after
        # Cleanup if still exists
        File.rm(temp_file)
      end
    end
  end

  describe "error propagation and recovery" do
    test "recovers from temporary file command unavailability" do
      # Normal operation
      assert {:ok, "text/plain"} = MagicMime.detect(text_fixture())

      # Simulate command unavailability
      with_path_manipulation("", fn ->
        # Should specifically return :file_command_not_found
        assert {:error, :file_command_not_found} = MagicMime.detect(text_fixture())
      end)

      # Should recover after PATH restoration
      assert {:ok, "text/plain"} = MagicMime.detect(text_fixture())
    end

    test "proper error handling across all functions" do
      non_existent = "definitely_does_not_exist.txt"

      # detect/1 should return error tuple
      assert {:error, :enoent} = MagicMime.detect(non_existent)

      # detect!/1 should raise
      assert_raise Error, fn ->
        MagicMime.detect!(non_existent)
      end

      # detect_many/2 should include error in results
      results = MagicMime.detect_many([non_existent])
      assert [{^non_existent, {:error, :enoent}}] = results

      # version/0 should handle gracefully
      with_path_manipulation("", fn ->
        assert {:error, _} = MagicMime.version()
      end)
    end

    test "maintains consistency across process boundaries" do
      # Spawn multiple processes doing detection
      parent = self()

      for i <- 1..5 do
        spawn_link(fn ->
          result = MagicMime.detect(text_fixture())
          send(parent, {:result, i, result})
        end)
      end

      # Collect results from all processes
      results =
        for _i <- 1..5 do
          receive do
            {:result, _i, result} -> result
          after
            5000 -> {:error, :timeout}
          end
        end

      # All should succeed
      for result <- results do
        assert {:ok, "text/plain"} = result
      end
    end
  end

  describe "integration with external factors" do
    test "handles large file processing" do
      large_content = String.duplicate("Large file content line\n", 10_000)

      with_temp_file(large_content, ".txt", fn temp_file ->
        assert {:ok, "text/plain"} = MagicMime.detect(temp_file)
      end)
    end

    test "works with files containing special characters" do
      special_content = "Special chars: äöü ñ é 中文 русский 🚀\n"

      with_temp_file(special_content, ".txt", fn temp_file ->
        result = MagicMime.detect(temp_file)
        assert {:ok, mime_type} = result
        assert String.contains?(mime_type, "text")
      end)
    end

    test "handles binary data correctly" do
      binary_data =
        for _ <- 1..1000 do
          :rand.uniform(256) - 1
        end
        |> :binary.list_to_bin()

      with_temp_file(binary_data, ".bin", fn temp_file ->
        assert {:ok, mime_type} = MagicMime.detect(temp_file)
        assert is_binary(mime_type)
        assert String.length(mime_type) > 0
      end)
    end
  end
end
