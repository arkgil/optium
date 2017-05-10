defmodule Optium.Mixfile do
  use Mix.Project

  def project do
    [app: :optium,
     version: "0.1.0",
     name: "Optium",
     description: "Library for validating arguments passed in keyword lists",
     source_url: "https://github.com/arkgil/optium",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     dialyzer: dialyzer(),
     docs: docs(),
     package: package()]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [{:dialyxir, "~> 0.5", only: :dev, runtime: false},
     {:ex_doc, "~> 0.14", only: :dev, runtime: false},
     {:credo, "~> 0.7", only: :dev, runtime: false}]
  end

  defp dialyzer do
    [flags: ["-Wunmatched_returns", "-Werror_handling",
             "-Wrace_conditions", "-Wunderspecs"]]
  end

  defp docs do
    [main: "Optium",
     extras: ["README.md": [title: "Optium"]]]
  end

  defp package do
    [licenses: ["MIT"],
     maintainers: ["Arkadiusz Gil"],
     links: %{"GitHub" => "https://github.com/arkgil/optium"}]
  end
end
