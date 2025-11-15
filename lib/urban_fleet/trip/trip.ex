defmodule Trip do
  use GenServer

  @moduledoc """
  Representa un viaje dentro del sistema.
  Controla su estado, conductor asignado y notificaciones.
  """

  # =============================
  #   API PÚBLICA
  # =============================

  def start_link({client, origin, dest}) do
    GenServer.start_link(__MODULE__, {client, origin, dest})
  end

  def state(pid), do: GenServer.call(pid, :get_state)

  def accept(pid, driver), do: GenServer.call(pid, {:accept, driver})

  def complete(pid), do: GenServer.call(pid, :complete)

  # =============================
  #   ESTADO INICIAL
  # =============================

  @impl true
  def init({client, origin, dest}) do
    trip_id = System.unique_integer([:positive])

    {:ok,
      %{
        id: trip_id,
        client: client,
        driver: nil,
        origin: origin,
        destination: dest,
        status: :waiting_driver,
        inserted_at: now(),
        accepted_at: nil,
        completed_at: nil
      }}
  end

  # =============================
  #   EVENTOS PRINCIPALES
  # =============================

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:accept, driver}, _from, %{status: :waiting_driver} = state) do
    new_state = %{
      state
      | status: :accepted,
        driver: driver,
        accepted_at: now()
    }

    {:reply, {:ok, :accepted}, new_state}
  end

  def handle_call({:accept, _driver}, _from, state) do
    {:reply, {:error, :already_taken}, state}
  end

  @impl true
  def handle_call(:complete, _from, %{status: :accepted} = state) do
    new_state = %{
      state
      | status: :completed,
        completed_at: now()
    }

    {:reply, {:ok, :completed}, new_state}
  end

  def handle_call(:complete, _from, %{status: :waiting_driver} = state) do
    {:reply, {:error, :not_accepted_yet}, state}
  end

  def handle_call(:complete, _from, %{status: :completed} = state) do
    {:reply, {:error, :already_completed}, state}
  end

  # =============================
  #   UTILIDADES PRIVADAS
  # =============================

  defp now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
