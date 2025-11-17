defmodule UrbanFleet.MixProject do
  use Mix.Project

  def project do
    [
      app: :urban_fleet,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
  [
    extra_applications: [:logger],
    mod: {UrbanFleet.Application, []}
  ]
end


  defp deps do
    []
  end
end
