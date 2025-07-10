defmodule MagicMime.Unit.StringProcessingTest do
  use ExUnit.Case, async: true

  describe "error pattern detection in command output" do
    test "detects 'cannot open' pattern" do
      outputs = [
        "cannot open `file.txt' (No such file or directory)",
        "file: cannot open `test.bin': Permission denied",
        "cannot open magic words",
        "Cannot open /path/to/file: Invalid argument"
      ]

      for output <- outputs do
        assert String.contains?(String.downcase(output), "cannot open")
      end
    end

    test "detects 'No such file' pattern" do
      outputs = [
        "No such file or directory",
        "file: No such file: test.txt",
        "ERROR: No such file",
        "no such file found"
      ]

      for output <- outputs do
        downcase_output = String.downcase(output)
        assert String.contains?(downcase_output, "no such file")
      end
    end

    test "detects 'permission denied' pattern" do
      outputs = [
        "Permission denied",
        "file: Permission denied: /etc/shadow",
        "permission denied while accessing file",
        "PERMISSION DENIED"
      ]

      for output <- outputs do
        downcase_output = String.downcase(output)
        assert String.contains?(downcase_output, "permission denied")
      end
    end

    test "does not match normal MIME types" do
      normal_outputs = [
        "text/plain",
        "image/png",
        "application/json",
        "video/mp4",
        "audio/mpeg"
      ]

      for output <- normal_outputs do
        downcase_output = String.downcase(output)
        refute String.contains?(downcase_output, "cannot open")
        refute String.contains?(downcase_output, "no such file")
        refute String.contains?(downcase_output, "permission denied")
      end
    end
  end

  describe "MIME type validation" do
    test "validates standard MIME type format" do
      valid_types = [
        "text/plain",
        "image/jpeg",
        "application/json",
        "video/mp4",
        "audio/mpeg",
        "model/gltf-binary",
        "application/vnd.ms-excel"
      ]

      for mime_type <- valid_types do
        assert String.contains?(mime_type, "/")
        [type, subtype] = String.split(mime_type, "/", parts: 2)
        assert String.length(type) > 0
        assert String.length(subtype) > 0
      end
    end

    test "detects invalid MIME type formats" do
      invalid_types = [
        "",
        "text",
        "/plain",
        "text/",
        "cannot open file",
        "No such file",
        "Permission denied"
      ]

      for invalid_type <- invalid_types do
        parts = String.split(invalid_type, "/")
        assert length(parts) != 2 or Enum.any?(parts, &(String.length(&1) == 0))
      end
    end
  end

  describe "string trimming and normalization" do
    test "removes whitespace from command output" do
      test_cases = [
        {" text/plain ", "text/plain"},
        {"\nimage/png\n", "image/png"},
        {"\t\tapplication/json\t\t", "application/json"},
        {" \n\t video/mp4 \t\n ", "video/mp4"}
      ]

      for {input, expected} <- test_cases do
        assert String.trim(input) == expected
      end
    end

    test "handles empty and whitespace-only strings" do
      whitespace_strings = [
        "",
        " ",
        "\n",
        "\t",
        "   ",
        "\n\n\n",
        "\t\t\t",
        " \n\t \n "
      ]

      for ws_string <- whitespace_strings do
        assert String.trim(ws_string) == ""
      end
    end

    test "preserves internal whitespace" do
      test_cases = [
        "application/vnd.ms excel",
        "text/plain; charset=utf-8",
        "multipart/form data"
      ]

      for input <- test_cases do
        trimmed = String.trim(input)
        assert trimmed == input
        assert String.contains?(trimmed, " ")
      end
    end
  end

  describe "path string validation" do
    test "detects empty paths" do
      empty_paths = ["", "   ", "\n", "\t", " \n\t "]

      for path <- empty_paths do
        assert String.trim(path) == ""
      end
    end

    test "detects absolute vs relative paths" do
      absolute_paths = [
        "/usr/bin/file",
        "/tmp/test.txt",
        "/dev/null",
        "/etc/passwd"
      ]

      relative_paths = [
        "test.txt",
        "lib/magic_mime.ex",
        "../test",
        "./file.bin"
      ]

      for path <- absolute_paths do
        assert String.starts_with?(path, "/")
      end

      for path <- relative_paths do
        refute String.starts_with?(path, "/")
      end
    end

    test "handles special characters in paths" do
      special_paths = [
        "/tmp/file with spaces.txt",
        "/tmp/файл.txt",
        "/tmp/ファイル.txt",
        "/tmp/file-with-dashes.txt",
        "/tmp/file_with_underscores.txt",
        "/tmp/file.with.dots.txt"
      ]

      for path <- special_paths do
        assert is_binary(path)
        assert String.length(path) > 0
      end
    end
  end

  describe "command argument processing" do
    test "processes file command arguments" do
      base_args = ["--mime-type"]
      file_path = "/tmp/test.txt"
      full_args = base_args ++ [file_path]

      assert length(full_args) == 2
      assert List.first(full_args) == "--mime-type"
      assert List.last(full_args) == file_path
    end

    test "handles version command arguments" do
      version_args = ["--version"]

      assert length(version_args) == 1
      assert List.first(version_args) == "--version"
    end

    test "validates command argument format" do
      valid_args = [
        ["--mime-type", "file.txt"],
        ["--version"],
        ["--help"],
        ["-i", "file.bin"]
      ]

      for args <- valid_args do
        assert is_list(args)
        assert length(args) > 0
        assert Enum.all?(args, &is_binary/1)
      end
    end
  end

  describe "unicode and encoding handling" do
    test "handles UTF-8 strings correctly" do
      utf8_strings = [
        "text/plain; charset=utf-8",
        "ファイル.txt",
        "файл.doc",
        "αρχείο.pdf",
        "🎵 music.mp3"
      ]

      for utf8_string <- utf8_strings do
        assert String.valid?(utf8_string)
        assert is_binary(utf8_string)
      end
    end

    test "handles binary data in strings" do
      binary_strings = [
        <<255, 254, 253>>,
        <<0, 1, 2, 3>>,
        <<"text", 0, 0, 0>>,
        # PNG signature start
        <<137, 80, 78, 71>>
      ]

      for binary_string <- binary_strings do
        assert is_binary(binary_string)
        # May or may not be valid UTF-8
        _valid = String.valid?(binary_string)
      end
    end
  end

  describe "edge case string patterns" do
    test "handles very long strings" do
      long_string = String.duplicate("a", 10_000)
      assert String.length(long_string) == 10_000
      assert String.trim(long_string) == long_string
    end

    test "handles strings with null bytes" do
      null_strings = [
        "text\0file",
        "\0start",
        "end\0",
        "middle\0byte\0here"
      ]

      for null_string <- null_strings do
        assert String.contains?(null_string, <<0>>)
        assert is_binary(null_string)
      end
    end

    test "handles mixed content strings" do
      mixed_strings = [
        "text/plain\nwith newline",
        "type\twith\ttab",
        "path with spaces and/slashes",
        "mix3d_w1th_numb3rs.txt"
      ]

      for mixed_string <- mixed_strings do
        assert is_binary(mixed_string)
        assert String.length(mixed_string) > 0
      end
    end
  end
end
