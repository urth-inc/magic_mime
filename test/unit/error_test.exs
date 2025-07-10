defmodule MagicMime.Unit.ErrorTest do
  use ExUnit.Case, async: true
  alias MagicMime.Error

  describe "Error.exception/1 with string message" do
    test "creates error with default type :unknown" do
      error = Error.exception("Simple error message")

      assert error.message == "Simple error message"
      assert error.type == :unknown
      assert error.details == nil
    end

    test "handles empty string message" do
      error = Error.exception("")

      assert error.message == ""
      assert error.type == :unknown
      assert error.details == nil
    end

    test "handles unicode messages" do
      unicode_message = "エラーメッセージ: ファイルが見つかりません"
      error = Error.exception(unicode_message)

      assert error.message == unicode_message
      assert error.type == :unknown
      assert error.details == nil
    end
  end

  describe "Error.exception/1 with {type, message} tuple" do
    test "creates error with specified type" do
      error = Error.exception({:enoent, "File not found"})

      assert error.message == "File not found"
      assert error.type == :enoent
      assert error.details == nil
    end

    test "handles all standard error types" do
      standard_types = [
        {:file_command_not_found, "Command not available"},
        {:enoent, "File does not exist"},
        {:eacces, "Permission denied"},
        {:command_error, "Command failed"},
        {:unknown, "Unknown error"}
      ]

      for {type, message} <- standard_types do
        error = Error.exception({type, message})

        assert error.type == type
        assert error.message == message
        assert error.details == nil
      end
    end

    test "handles custom error types" do
      error = Error.exception({:custom_error_type, "Custom message"})

      assert error.type == :custom_error_type
      assert error.message == "Custom message"
      assert error.details == nil
    end
  end

  describe "Error.exception/1 with {type, message, details} tuple" do
    test "creates error with details map" do
      details = %{exit_code: 1, stderr: "error output"}
      error = Error.exception({:command_error, "Command failed", details})

      assert error.message == "Command failed"
      assert error.type == :command_error
      assert error.details == details
    end

    test "handles nil details" do
      error = Error.exception({:command_error, "Command failed", nil})

      assert error.message == "Command failed"
      assert error.type == :command_error
      assert error.details == nil
    end

    test "handles empty details map" do
      error = Error.exception({:command_error, "Command failed", %{}})

      assert error.message == "Command failed"
      assert error.type == :command_error
      assert error.details == %{}
    end

    test "handles complex details structures" do
      complex_details = %{
        exit_code: 127,
        stderr: "Command not found",
        stdout: "",
        command: ["file", "--mime-type", "nonexistent.txt"],
        timestamp: System.system_time(:millisecond),
        env: %{"PATH" => "/usr/bin"}
      }

      error = Error.exception({:command_error, "Complex error", complex_details})

      assert error.message == "Complex error"
      assert error.type == :command_error
      assert error.details == complex_details
    end
  end

  describe "Exception protocol implementation" do
    test "Exception.message/1 returns the error message" do
      error = Error.exception("Test message")
      message = Exception.message(error)

      assert message == "Test message"
    end

    test "Exception.message/1 works with all error creation patterns" do
      test_cases = [
        Error.exception("String message"),
        Error.exception({:enoent, "Tuple message"}),
        Error.exception({:command_error, "Detailed message", %{code: 1}})
      ]

      for error <- test_cases do
        message = Exception.message(error)
        assert is_binary(message)
        assert String.length(message) > 0
        assert message == error.message
      end
    end

    test "works with raise/1" do
      assert_raise Error, "Test error", fn ->
        raise Error.exception("Test error")
      end
    end

    test "works with raise/2" do
      assert_raise Error, "Detailed error", fn ->
        raise Error, "Detailed error"
      end
    end
  end

  describe "error struct properties" do
    test "has all required fields" do
      error = Error.exception("test")

      assert Map.has_key?(error, :message)
      assert Map.has_key?(error, :type)
      assert Map.has_key?(error, :details)
      assert Map.has_key?(error, :__exception__)
    end

    test "is a proper exception struct" do
      error = Error.exception("test")

      assert error.__exception__ == true
      assert error.__struct__ == Error
    end

    test "can be pattern matched" do
      error = Error.exception({:enoent, "Not found", %{path: "/test"}})

      assert %Error{
               type: :enoent,
               message: "Not found",
               details: %{path: "/test"}
             } = error
    end
  end

  describe "error equality and comparison" do
    test "errors with same content are equal" do
      error1 = Error.exception({:enoent, "File not found"})
      error2 = Error.exception({:enoent, "File not found"})

      assert error1 == error2
    end

    test "errors with different content are not equal" do
      error1 = Error.exception({:enoent, "File not found"})
      error2 = Error.exception({:eacces, "Permission denied"})

      assert error1 != error2
    end

    test "errors with same message but different details are not equal" do
      error1 = Error.exception({:command_error, "Failed", %{code: 1}})
      error2 = Error.exception({:command_error, "Failed", %{code: 2}})

      assert error1 != error2
    end
  end
end
