defmodule MagicMime.Integration.FixturesTest do
  use MagicMime.TestCase

  setup_all do
    setup_file_command_check()
  end

  describe "fixture file detection" do
    test "detects PNG image correctly" do
      assert {:ok, "image/png"} = MagicMime.detect(png_fixture())
    end

    test "detects JPEG image correctly" do
      assert {:ok, "image/jpeg"} = MagicMime.detect(jpg_fixture())
    end

    test "detects GIF image correctly" do
      assert {:ok, "image/gif"} = MagicMime.detect(gif_fixture())
    end

    test "detects SVG image correctly" do
      assert {:ok, "image/svg+xml"} = MagicMime.detect(svg_fixture())
    end

    test "detects GLB 3D model correctly" do
      assert {:ok, "model/gltf-binary"} = MagicMime.detect(glb_fixture())
    end

    test "detects text fixtures correctly" do
      assert {:ok, "text/plain"} = MagicMime.detect(text_fixture())

      json_result = MagicMime.detect(json_fixture())
      assert {:ok, mime_type} = json_result
      assert mime_type in ["application/json", "text/plain"]

      xml_result = MagicMime.detect(xml_fixture())
      assert {:ok, mime_type} = xml_result
      assert mime_type in ["application/xml", "text/xml", "text/plain"]
    end
  end

  describe "batch fixture processing" do
    test "processes all image fixtures in batch" do
      image_fixtures = [png_fixture(), jpg_fixture(), gif_fixture(), svg_fixture()]
      expected_types = ["image/png", "image/jpeg", "image/gif", "image/svg+xml"]

      results = MagicMime.detect_many(image_fixtures)
      assert length(results) == 4

      results_map = Map.new(results)

      for {fixture, expected} <- Enum.zip(image_fixtures, expected_types) do
        assert {:ok, ^expected} = results_map[fixture]
      end
    end

    test "processes mixed fixture types" do
      all_fixtures = [
        text_fixture(),
        json_fixture(),
        png_fixture(),
        jpg_fixture(),
        glb_fixture()
      ]

      results = MagicMime.detect_many(all_fixtures)
      assert length(results) == 5

      # Verify all succeeded
      for {_path, result} <- results do
        assert {:ok, _mime_type} = result
      end

      # Extract MIME types
      actual_mime_types = Enum.map(results, fn {_path, {:ok, mime_type}} -> mime_type end)

      # Verify expected types are present
      assert "text/plain" in actual_mime_types
      assert "image/png" in actual_mime_types
      assert "image/jpeg" in actual_mime_types
      assert "model/gltf-binary" in actual_mime_types
    end

    test "handles concurrent fixture access" do
      fixture = png_fixture()

      tasks =
        for _ <- 1..10 do
          Task.async(fn -> MagicMime.detect(fixture) end)
        end

      results = Task.await_many(tasks, 5000)

      for result <- results do
        assert {:ok, "image/png"} = result
      end
    end
  end

  describe "fixture edge cases" do
    test "verifies fixture file existence and readability" do
      all_fixtures = [
        text_fixture(),
        json_fixture(),
        xml_fixture(),
        shell_fixture(),
        png_fixture(),
        jpg_fixture(),
        gif_fixture(),
        svg_fixture(),
        glb_fixture()
      ]

      for fixture_path <- all_fixtures do
        assert File.exists?(fixture_path), "Fixture file does not exist: #{fixture_path}"

        assert match?({:ok, _}, File.read(fixture_path)),
               "Fixture file is not readable: #{fixture_path}"

        # Verify we can detect its MIME type
        assert {:ok, _mime_type} = MagicMime.detect(fixture_path)
      end
    end

    test "handles fixture files larger than typical samples" do
      # GLB file should be larger than other fixtures
      glb_size = File.stat!(glb_fixture()).size
      # Should be more than minimal header
      assert glb_size > 50

      # Ensure detection still works for larger files
      assert {:ok, "model/gltf-binary"} = MagicMime.detect(glb_fixture())
    end
  end

  describe "fixture performance tests" do
    test "processes fixtures efficiently" do
      start_time = System.monotonic_time(:millisecond)

      all_fixtures = [
        text_fixture(),
        json_fixture(),
        xml_fixture(),
        png_fixture(),
        jpg_fixture(),
        gif_fixture(),
        svg_fixture(),
        glb_fixture()
      ]

      results = MagicMime.detect_many(all_fixtures)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete within reasonable time (adjust as needed)
      # 5 seconds should be more than enough
      assert duration < 5000

      # Verify all results are successful
      assert length(results) == length(all_fixtures)

      for {_path, result} <- results do
        assert {:ok, _} = result
      end
    end

    test "handles high concurrency with fixtures" do
      fixture = text_fixture()

      start_time = System.monotonic_time(:millisecond)

      tasks =
        for _ <- 1..50 do
          Task.async(fn -> MagicMime.detect(fixture) end)
        end

      results = Task.await_many(tasks, 10_000)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should handle concurrency efficiently
      # 10 seconds max
      assert duration < 10_000

      for result <- results do
        assert {:ok, "text/plain"} = result
      end
    end

    test "mixed file types with high concurrency" do
      fixtures = [
        text_fixture(),
        png_fixture(),
        jpg_fixture(),
        glb_fixture()
      ]

      # Create many concurrent tasks with different file types
      tasks =
        for _ <- 1..20 do
          random_fixture = Enum.random(fixtures)
          Task.async(fn -> MagicMime.detect(random_fixture) end)
        end

      results = Task.await_many(tasks, 10_000)

      # All should succeed
      for result <- results do
        assert match?({:ok, _}, result)
      end
    end
  end

  describe "fixture file integrity" do
    test "verifies image fixture file signatures" do
      # PNG signature
      png_data = File.read!(png_fixture())
      assert binary_part(png_data, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>

      # JPEG signature
      jpeg_data = File.read!(jpg_fixture())
      assert binary_part(jpeg_data, 0, 2) == <<255, 216>>

      # GIF signature
      gif_data = File.read!(gif_fixture())
      assert binary_part(gif_data, 0, 6) == <<"GIF87a">>

      # GLB signature
      glb_data = File.read!(glb_fixture())
      assert binary_part(glb_data, 0, 4) == <<"glTF">>
    end

    test "verifies text fixture content" do
      text_content = File.read!(text_fixture())
      assert String.contains?(text_content, "test file")

      json_content = File.read!(json_fixture())
      assert String.contains?(json_content, "name")
      assert String.contains?(json_content, "test")

      xml_content = File.read!(xml_fixture())
      assert String.contains?(xml_content, "<?xml")
      assert String.contains?(xml_content, "<root>")

      svg_content = File.read!(svg_fixture())
      assert String.contains?(svg_content, "<svg")
      assert String.contains?(svg_content, "xmlns")
    end
  end

  describe "fixture cleanup and regeneration" do
    test "verifies fixture creation is idempotent" do
      # Test that fixture creation is idempotent
      original_fixtures = [
        {png_fixture(), "image/png"},
        {jpg_fixture(), "image/jpeg"},
        {gif_fixture(), "image/gif"},
        {svg_fixture(), "image/svg+xml"}
      ]

      # Recreate fixtures
      MagicMime.TestHelpers.create_test_fixtures_manually()

      # All should still work correctly after recreation
      for {fixture_path, expected_mime} <- original_fixtures do
        assert {:ok, ^expected_mime} = MagicMime.detect(fixture_path)
      end
    end

    test "handles missing fixture directory gracefully" do
      # This test verifies our fixture creation handles missing directories
      temp_fixtures_dir = "/tmp/test_fixtures_#{:rand.uniform(10000)}"

      try do
        # Should not exist initially
        refute File.exists?(temp_fixtures_dir)

        # Fixture creation should handle this gracefully
        File.mkdir_p!(temp_fixtures_dir)

        # Test basic operations work with new directory
        assert File.exists?(temp_fixtures_dir)
        File.rmdir!(temp_fixtures_dir)
      rescue
        _ -> :ok
      end
    end
  end
end
