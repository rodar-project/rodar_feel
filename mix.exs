defmodule RodarFeel.MixProject do
  use Mix.Project

  def project do
    [
      app: :rodar_feel,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      description: "FEEL (Friendly Enough Expression Language) evaluator for BPMN 2.0",

      # Docs
      name: "RodarFeel",
      source_url: "https://github.com/rodar-project/rodar_feel",
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  defp package do
    [
      name: "rodar_feel",
      files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG.md"],
      maintainers: ["Rodrigo Couto"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/rodar-project/rodar_feel"}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false}
    ]
  end
end
