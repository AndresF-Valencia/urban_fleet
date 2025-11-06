defmodule TripManager do
  use DynamicSupervisor
  alias Trip

  ## ===============================
  ##  INICIO Y SUPERVISOR
  ## ===============================

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # Estrategia simple: cada viaje es independiente
    Registry.start_link(keys: :unique, name: TripRegistry)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  ## ===============================
  ##  API PÚBLICA
  ## ===============================

  # Cliente solicita un viaje
  def request_trip(client, origin, dest) do
    # Inicia un proceso Trip bajo el DynamicSupervisor
    spec = {Trip, {client, origin, dest}}
    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, spec)

    id = :erlang.phash2(pid)
    Registry.register(TripRegistry, id, pid)

    IO.puts("🚗 Nuevo viaje creado con ID #{id}")
    {:ok, pid}
  end

  # Conductor acepta un viaje
  def accept_trip(id, driver) do
    case Registry.lookup(TripRegistry, id) do
      [{_pid, pid}] ->
        case Trip.accept(pid, driver) do
          {:ok, :accepted} -> :ok
          {:error, reason} -> {:error, reason}
        end

      [] ->
        {:error, :not_found}
    end
  end

  # Conductor completa un viaje
  def complete_trip(id) do
    case Registry.lookup(TripRegistry, id) do
      [{_pid, pid}] ->
        Trip.complete(pid)
        IO.puts("✅ Viaje #{id} completado")
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  # Ver estado actual del viaje
  def get_trip_state(id) do
    case Registry.lookup(TripRegistry, id) do
      [{_pid, pid}] -> Trip.state(pid)
      [] -> {:error, :not_found}
    end
  end
end
