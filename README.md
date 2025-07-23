# MagicMime

[![CI](https://github.com/urth-inc/magic_mime/workflows/Test/badge.svg)](https://github.com/urth-inc/magic_mime/actions)
[![Coverage Status](https://coveralls.io/repos/github/urth-inc/magic_mime/badge.svg?branch=develop)](https://coveralls.io/github/urth-inc/magic_mime?branch=develop)
[![Hex.pm](https://img.shields.io/hexpm/v/magic_mime.svg)](https://hex.pm/packages/magic_mime)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/magic_mime)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/github-urth--inc%2Fmagic__mime-blue.svg)](https://github.com/urth-inc/magic_mime)

Elixir wrapper for MIME type detection using the system's file command.

## Features

- Wrapper around the system file command
- Binary detection (not guess from file extension)
- Parallel processing support for multiple files

## Requirements

- System file command must be available

Note: Windows is not supported.

## Installation

Add magic_mime to your list of dependencies in mix.exs:

```elixir
def deps do
  [
    {:magic_mime, "~> 0.1"}
  ]
end
```

## Usage

### Basic Detection

```elixir
# Detect MIME type for a single file
{:ok, mime_type} = MagicMime.detect("path/to/file.png")
# => {:ok, "image/png"}

# Exception-raising version
mime_type = MagicMime.detect!("path/to/file.png")
# => "image/png"
```

### Parallel Processing

```elixir
# Process multiple files in parallel
paths = ["image.png", "document.pdf", "data.json"]
results = MagicMime.detect_many(paths)
# => [
#      {"image.png", {:ok, "image/png"}},
#      {"document.pdf", {:ok, "application/pdf"}},
#      {"data.json", {:ok, "application/json"}}
#    ]

# Specify concurrency level
results = MagicMime.detect_many(paths, concurrency: 4)
```

### System Support Check

```elixir
# Check if file command is available
MagicMime.mime_supported?()
# => true

# Get file command version information
MagicMime.version()
# => "file-5.44"
```

## Error Handling

MagicMime provides the following error types:

- `:file_command_not_found` - file command not found
- `:enoent` - file does not exist
- `:eacces` - permission denied
- `{:command_error, exit_code, stderr}` - command execution error

```elixir
case MagicMime.detect("nonexistent.file") do
  {:ok, mime_type} -> IO.puts("MIME Type: #{mime_type}")
  {:error, :enoent} -> IO.puts("File not found")
  {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
end
```

## Development

### Setup

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs
```

### Code Quality

```bash
# Format code
mix format

# Static analysis
mix credo --strict

# Type checking
mix dialyzer
```

## Contributing

Pull requests and issue reports are welcome.

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -am 'Add amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request

## License

MIT License.
