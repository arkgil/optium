defmodule Optium.Mixfile do
  use Mix.Project

  def project do
    [app: :optium,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     dialyzer: dialyzer(),
     docs: docs()]
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
    [main: "Readme",
     extras: ["README.md": [title: "Optium"]]]
  end
end
