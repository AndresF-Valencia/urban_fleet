defmodule TripManager do
  @moduledoc """
  Maneja la creación y administración de viajes usando
  DynamicSupervisor y TripRegistry.
  """

  use DynamicSupervisor
  alias Trip

  # ======================
  # Supervisor
  # ======================
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # ======================
  # API
  # ======================

  @doc """
  Crea un viaje y devuelve { :ok, id, pid }.
  """
  def request_trip(client, origin, dest) do
    {:ok, pid} = DynamicSupervisor.start_child(
      __MODULE__,
      {Trip, {client, origin, dest}}
    )

    id = Trip.state(pid).id

    Registry.register(TripRegistry, id, nil)

    IO.puts("🚗 Nuevo viaje creado con ID #{id}")

    {:ok, id, pid}
  end

  @doc """
  El driver acepta el viaje.
  """
  def accept_trip(id, driver) do
    case Registry.lookup(TripRegistry, id) do
      [{pid, _}] -> Trip.accept(pid, driver)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Completa un viaje existente.
  """
  def complete_trip(id) do
    case Registry.lookup(TripRegistry, id) do
      [{pid, _}] ->
        Trip.complete(pid)
        IO.puts("✅ Viaje #{id} completado")
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Obtiene el estado de un viaje por ID.
  """
  def get_trip_state(id) do
    case Registry.lookup(TripRegistry, id) do
      [{pid, _}] -> Trip.state(pid)
      [] -> {:error, :not_found}
    end
  end
end
