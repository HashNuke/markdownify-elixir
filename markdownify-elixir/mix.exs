defmodule MarkdownifyEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :markdownify_ex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Convert HTML to Markdown."
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:floki, "~> 0.37"}
    ]
  end

  defp package do
    [
      name: "markdownify_ex",
      licenses: ["MIT"],
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      links: %{"GitHub" => "https://github.com/akash/markdownify-elixir"}
    ]
  end
end
