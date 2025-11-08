defmodule TripManager do
  use DynamicSupervisor
  alias Trip

  ##  SUPERVISOR

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # Cada viaje es un proceso independiente
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  ##  API PÚBLICA

  # Inicializar el registro de viajes (solo una vez en la app)
  def setup_registry do
    Registry.start_link(keys: :unique, name: TripRegistry)
  end

  # Cliente solicita un viaje
  def request_trip(client, origin, destination) do
    spec = {Trip, {client, origin, destination}}
    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, spec)

    id = :erlang.phash2(pid)
    Registry.register(TripRegistry, id, pid)

    IO.puts("🚗 Nuevo viaje creado con ID #{id}")
    {:ok, id}
  end

  # Conductor acepta un viaje
  def accept_trip(id, driver) do
    case lookup_trip(id) do
      {:ok, pid} ->
        case Trip.accept(pid, driver) do
          {:ok, :accepted} ->
            IO.puts("🟢 Viaje #{id} aceptado por #{driver.username}")
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _} = e -> e
    end
  end

  # Conductor completa un viaje
  def complete_trip(id) do
    case lookup_trip(id) do
      {:ok, pid} ->
        Trip.complete(pid)
        IO.puts("✅ Viaje #{id} completado")
        :ok

      {:error, _} = e -> e
    end
  end

  # Ver estado actual de un viaje
  def get_trip_state(id) do
    case lookup_trip(id) do
      {:ok, pid} -> Trip.state(pid)
      {:error, _} = e -> e
    end
  end

  # Listar todos los viajes activos
  def list_trips do
    Registry.select(TripRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$3"}}]}])
  end

  ##  PRIVADO

  defp lookup_trip(id) do
    case Registry.lookup(TripRegistry, id) do
      [{_pid, pid}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
end
