defmodule MagicMime.Unit.DependencyInjectionTest do
  use ExUnit.Case, async: false

  alias MagicMime.Test.{MockCommandExecutor, MockFileSystem}

  setup do
    MockCommandExecutor.reset()
    MockFileSystem.reset()
    :ok
  end

  describe "MagicMime.detect/2 with dependency injection" do
    test "handles file command not found" do
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.simulate_file_command_not_found()

      assert {:error, :file_command_not_found} =
               MagicMime.detect("test.txt", command_executor: MockCommandExecutor)
    end

    test "handles file not found" do
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockFileSystem.simulate_file_not_found()
      assert {:error, :enoent} = MagicMime.detect("test.txt", file_system: MockFileSystem)
    end

    test "handles permission denied" do
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.set_cmd_result({"cannot open: Permission denied", 0})

      assert {:error, :eacces} =
               MagicMime.detect("test.txt", command_executor: MockCommandExecutor)
    end

    test "handles various file command errors" do
      test_cases = [
        {"No such file or directory", :enoent},
        {"cannot open `test.txt' (No such file or directory)", :enoent},
        {"cannot open: Permission denied", :eacces}
      ]

      for {error_message, expected_error} <- test_cases do
        MockCommandExecutor.reset()
        MockFileSystem.reset()
        MockCommandExecutor.set_cmd_result({error_message, 0})

        assert {:error, ^expected_error} =
                 MagicMime.detect("test.txt", command_executor: MockCommandExecutor)
      end
    end

    test "handles 'cannot open' error" do
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.simulate_cannot_open_error()
      MockFileSystem.simulate_file_success()

      assert {:error, :enoent} =
               MagicMime.detect("test.txt",
                 command_executor: MockCommandExecutor,
                 file_system: MockFileSystem
               )
    end

    test "handles command errors with exit codes" do
      for exit_code <- [1, 2, 127, 255] do
        MockCommandExecutor.reset()
        MockFileSystem.reset()
        MockCommandExecutor.simulate_command_error("Command failed", exit_code)
        MockFileSystem.simulate_file_success()

        assert {:error, {:command_error, ^exit_code, "Command failed"}} =
                 MagicMime.detect("test.txt",
                   command_executor: MockCommandExecutor,
                   file_system: MockFileSystem
                 )
      end
    end

    test "handles system exceptions" do
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      exception = %RuntimeError{message: "system error"}
      MockCommandExecutor.simulate_command_exception(exception)
      MockFileSystem.simulate_file_success()

      assert {:error, ^exception} =
               MagicMime.detect("test.txt",
                 command_executor: MockCommandExecutor,
                 file_system: MockFileSystem
               )
    end
  end

  describe "MagicMime.detect!/2 with dependency injection" do
    test "raises all error types correctly" do
      # Test file command not found
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.simulate_file_command_not_found()

      assert_raise MagicMime.Error, ~r/file command is not available/, fn ->
        MagicMime.detect!("test.txt", command_executor: MockCommandExecutor)
      end

      # Test file not found
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.set_cmd_result({"No such file or directory", 0})

      assert_raise MagicMime.Error, ~r/File does not exist/, fn ->
        MagicMime.detect!("test.txt", command_executor: MockCommandExecutor)
      end

      # Test permission denied
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.set_cmd_result({"cannot open: Permission denied", 0})

      assert_raise MagicMime.Error, ~r/Permission denied/, fn ->
        MagicMime.detect!("test.txt", command_executor: MockCommandExecutor)
      end

      # Test command error
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.simulate_command_error("Command failed", 1)
      MockFileSystem.simulate_file_success()

      assert_raise MagicMime.Error, ~r/Command failed with exit code 1/, fn ->
        MagicMime.detect!("test.txt",
          command_executor: MockCommandExecutor,
          file_system: MockFileSystem
        )
      end

      # Test that unexpected exceptions are not wrapped
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.simulate_command_exception(%RuntimeError{message: "unknown"})
      MockFileSystem.simulate_file_success()

      assert_raise RuntimeError, ~r/unknown/, fn ->
        MagicMime.detect!("test.txt",
          command_executor: MockCommandExecutor,
          file_system: MockFileSystem
        )
      end
    end
  end

  describe "CLI functions with dependency injection" do
    test "CLI.detect_mime_type/2 handles all patterns" do
      # Test 'cannot open' detection
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_cannot_open_error()

      assert {:error, {:command_error, 0, _}} =
               MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)

      # Test 'No such file' detection
      MockCommandExecutor.reset()
      MockCommandExecutor.set_cmd_result({"No such file or directory", 0})

      assert {:error, {:command_error, 0, _}} =
               MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)

      # Test successful detection
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_command_success("text/plain")

      assert {:ok, "text/plain"} =
               MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)

      # Test command error
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_command_error("error", 1)

      assert {:error, {:command_error, 1, "error"}} =
               MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)

      # Test command exception
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_command_exception(%ArgumentError{message: "bad arg"})
      exception = %ArgumentError{message: "bad arg"}

      assert {:error, ^exception} =
               MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)
    end

    test "CLI.detect_mime_type/2 validates MIME type format robustly" do
      # Test valid MIME types (should succeed)
      valid_types = [
        "text/plain",
        "image/jpeg",
        "application/json",
        "video/mp4",
        "audio/mpeg",
        "model/gltf-binary",
        "application/vnd.ms-excel",
        "text/x-shellscript"
      ]

      for mime_type <- valid_types do
        MockCommandExecutor.reset()
        MockCommandExecutor.simulate_command_success(mime_type)

        assert {:ok, ^mime_type} =
                 MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)
      end

      # Test invalid formats that match English error patterns (should fail with exit code 0)
      invalid_outputs = [
        # English command error messages (LANG=C ensures these)
        "cannot open file",
        "No such file or directory",
        "cannot open `test.txt' (No such file or directory)",
        # Actual format from file command
        "cannot open: Permission denied"

        # Other invalid outputs that don't match known error patterns will be treated as MIME types
        # This is acceptable since LANG=C should prevent localized messages
      ]

      for invalid_output <- invalid_outputs do
        MockCommandExecutor.reset()
        MockCommandExecutor.set_cmd_result({invalid_output, 0})

        assert {:error, {:command_error, 0, ^invalid_output}} =
                 MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)
      end

      # Test that non-English messages would be treated as MIME types
      # (This demonstrates the limitation, but LANG=C should prevent this scenario)
      non_english_outputs = [
        "ファイルが見つかりません",
        "Datei nicht gefunden",
        "Fichier non trouvé"
      ]

      for output <- non_english_outputs do
        MockCommandExecutor.reset()
        MockCommandExecutor.set_cmd_result({output, 0})
        # These would be incorrectly treated as MIME types without LANG=C
        assert {:ok, ^output} =
                 MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)
      end
    end

    test "CLI.detect_mime_type/2 prioritizes exit code over output content" do
      # Even if output looks like valid MIME type, non-zero exit code should cause error
      MockCommandExecutor.reset()
      MockCommandExecutor.set_cmd_result({"text/plain", 1})

      assert {:error, {:command_error, 1, "text/plain"}} =
               MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)

      # Test various non-zero exit codes
      for exit_code <- [1, 2, 127, 255] do
        MockCommandExecutor.reset()
        MockCommandExecutor.set_cmd_result({"application/json", exit_code})

        assert {:error, {:command_error, ^exit_code, "application/json"}} =
                 MagicMime.CLI.detect_mime_type("test.txt", command_executor: MockCommandExecutor)
      end
    end

    test "CLI.get_version/1 handles all scenarios" do
      # Test successful version
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_version_output("file-5.45")
      assert {:ok, "file-5.45"} = MagicMime.CLI.get_version(command_executor: MockCommandExecutor)

      # Test command error
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_version_error()

      assert {:error, {:command_error, 127, "command not found"}} =
               MagicMime.CLI.get_version(command_executor: MockCommandExecutor)

      # Test command exception
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_command_exception(%RuntimeError{message: "error"})
      exception = %RuntimeError{message: "error"}

      assert {:error, ^exception} =
               MagicMime.CLI.get_version(command_executor: MockCommandExecutor)
    end

    test "CLI.validate_file_path/2 handles all file system scenarios" do
      # Test file not found
      MockFileSystem.reset()
      MockFileSystem.simulate_file_not_found()

      assert {:error, :enoent} =
               MagicMime.CLI.validate_file_path("test.txt", file_system: MockFileSystem)

      # Test permission denied
      MockFileSystem.reset()
      MockFileSystem.simulate_permission_denied()

      assert {:error, :eacces} =
               MagicMime.CLI.validate_file_path("test.txt", file_system: MockFileSystem)

      # Test other stat errors
      MockFileSystem.reset()
      MockFileSystem.simulate_stat_error(:eisdir)

      assert {:error, :eisdir} =
               MagicMime.CLI.validate_file_path("test.txt", file_system: MockFileSystem)

      # Test success
      MockFileSystem.reset()
      MockFileSystem.simulate_file_success()
      assert :ok = MagicMime.CLI.validate_file_path("test.txt", file_system: MockFileSystem)
    end
  end

  describe "API functions with dependency injection" do
    test "version/1 with DI" do
      # Test successful version
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_version_output("file-5.45")
      assert {:ok, "file-5.45"} = MagicMime.version(command_executor: MockCommandExecutor)

      # Test error returns error tuple
      MockCommandExecutor.reset()
      MockCommandExecutor.simulate_version_error()
      assert {:error, _} = MagicMime.version(command_executor: MockCommandExecutor)
    end

    test "detect_many/2 with DI" do
      MockCommandExecutor.reset()
      MockFileSystem.reset()
      MockCommandExecutor.simulate_command_success("text/plain")
      MockFileSystem.simulate_file_success()

      results =
        MagicMime.detect_many(["test1.txt", "test2.txt"],
          command_executor: MockCommandExecutor,
          file_system: MockFileSystem
        )

      assert length(results) == 2

      for {_path, result} <- results do
        assert match?({:ok, _}, result)
      end
    end
  end
end
