defmodule TripSupervisor do
  use DynamicSupervisor

  ##  INICIO DEL SUPERVISOR
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # Estrategia :one_for_one -> si un viaje falla, no afecta los demás
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  ##  API PÚBLICA

  # Crear un nuevo proceso de viaje
  def start_trip(client, origin, dest) do
    spec = {Trip, {client, origin, dest}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
