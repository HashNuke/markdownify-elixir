defmodule MarkdownifyEx.MixProject do
  use Mix.Project

  # Track the upstream Python project's major/minor version. The patch version
  # is reserved for Elixir-specific releases on that upstream line.
  @version "1.2.0"

  def project do
    [
      app: :markdownify_ex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Convert HTML to Markdown. Elixir port of markdownify Python package",
      docs: docs(),
      source_url: "https://github.com/HashNuke/markdownify-elixir",
      homepage_url: "https://github.com/HashNuke/markdownify-elixir"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:floki, "~> 0.37"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "markdownify_ex",
      licenses: ["MIT"],
      files: ["lib", "bin", "mix.exs", "README.md", "LICENSE"],
      links: %{"GitHub" => "https://github.com/HashNuke/markdownify-elixir"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}"
    ]
  end
end
