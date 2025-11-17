defmodule TripRegistry do
  use Supervisor

@doc """
Inicia el supervisor y lo registra con su nombre.
"""
  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

@doc """
Inicializa el supervisor con un Registry y estrategia one_for_one.
"""
  @impl true
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: :trip_registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
