defmodule UrbanFleet.Application do
  use Application

  @doc """
  Inicia la aplicación UrbanFleet y sus procesos supervisados.
  """
  def start(_type, _args) do
    children = [
      TripRegistry,
      {DynamicSupervisor, name: TripSupervisor, strategy: :one_for_one},
      TripManager,
      UserManager,
      {Task, fn -> Handler.start() end}
    ]

    opts = [strategy: :one_for_one, name: UrbanFleet.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
