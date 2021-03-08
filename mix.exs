defmodule OpenTelemetry.Tesla.MixProject do
  use Mix.Project

  @app :opentelemetry_tesla
  @description "OpenTelemetry integration for Tesla"
  @main "OpenTelemetry.Tesla"
  @repo "https://github.com/garthk/opentelemetry_tesla"
  @version "0.6.0-rc1"

  def project do
    [
      app: @app,
      deps: deps(),
      description: @description,
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.8",
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        docs: :dev
      ],
      source_url: @repo,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:credo, "~> 1.5.5", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.21.3", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14.0", only: :test, runtime: false},
      {:licensir, "~> 0.6.1", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0.2", only: :dev, runtime: false},
      {:mox, "~> 1.0.0", only: :test, runtime: false},
      # versions for runtime dependencies deliberately set low and loose:
      {:tesla, "~> 1.2"},
      {:opentelemetry, "~> 0.5"},
      {:opentelemetry_api, "~> 0.5"}
    ]
  end

  defp dialyzer() do
    [
      # 'mix dialyzer --format dialyzer' to get lines you can paste into:
      # ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true,
      plt_add_deps: [:app_tree]
    ]
  end

  defp docs() do
    [
      authors: ["Garth Kidd"],
      canonical: "https://hex.pm/packages/#{@app}",
      main: @main,
      source_ref: "v#{@version}"
    ]
  end

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub repo" => @repo,
        "OpenTelemetry BEAM" => "https://github.com/opentelemetry-beam",
        "OpenTelemetry" => "https://opentelemetry.io"
      }
    ]
  end
end
