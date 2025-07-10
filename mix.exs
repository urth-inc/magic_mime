defmodule MagicMime.MixProject do
  use Mix.Project

  def project do
    [
      app: :magic_mime,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :app_tree,
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    "Fast and secure MIME type detection using the system's file command"
  end

  defp package do
    [
      name: "magic_mime",
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/urth-inc/magic_mime"}
    ]
  end

  defp docs do
    [
      main: "MagicMime",
      extras: ["README.md"]
    ]
  end
end
