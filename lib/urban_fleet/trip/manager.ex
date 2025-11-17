defmodule TripManager do
  use DynamicSupervisor
  alias Trip

  @doc """
  Inicia el DynamicSupervisor que gestionará los procesos de viaje (Trip).
  """
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Configura el DynamicSupervisor con estrategia :one_for_one.
  """
  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Crea un viaje y devuelve { :ok, id, pid } o {:error, reason}
  """
  def request_trip(client, origin, dest) do
    spec = {Trip, {client, origin, dest}}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        id = Trip.state(pid).id
        IO.puts("Nuevo viaje creado con ID #{id}")
        {:ok, id, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Acepta un viaje usando su ID y el conductor asignado.
  """
  def accept_trip(id, driver) do
    case Registry.lookup(:trip_registry, id) do
      [{pid, _}] -> Trip.accept(pid, driver)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Marca un viaje como completado usando su ID.
  """
  def complete_trip(id) do
    case Registry.lookup(:trip_registry, id) do
      [{pid, _}] ->
        Trip.complete(pid)
        {:ok, :completed}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Obtiene el estado actual de un viaje mediante su ID.
  """
  def get_trip_state(id) do
    case Registry.lookup(:trip_registry, id) do
      [{pid, _}] -> Trip.state(pid)
      [] -> {:error, :not_found}
    end
  end

  @doc"""
  Retorna solo los viajes en estado :waiting.
  """
  def list_pending do
    Registry.select(:trip_registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.map(&get_trip_state/1)
    |> Enum.filter(fn
      %{status: :waiting} -> true
      _ -> false
    end)
  end
end
