defmodule AepfOpensearch.MixProject do
  use Mix.Project

  def project do
    [
      app: :aepf_opensearch,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AepfOpensearch.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.17"},
      {:nimble_options, "~> 1.0"},

      # only for dev / test
      {:mox, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  # Hex.pm shows this in searches and on the package page
  defp description do
    "OpenSearch data layer for the Ash Framework (implements AepfOpensearch.DataLayer)"
  end

  # Hex.pm “Links” sidebar + licence badge
  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mft-labs/aepf_opensearch",
        "Docs"   => "https://hexdocs.pm/aepf_opensearch",
      },
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end
end
