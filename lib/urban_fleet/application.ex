children = [
  {Registry, keys: :unique, name: TripRegistry},
  TripSupervisor,
  TripManager
]
def start(_type, _args) do
  children = [
    TripRegistry,
    TripSupervisor   # si decides conservarlo
    # otros procesos...
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
