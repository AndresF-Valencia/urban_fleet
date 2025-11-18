defmodule Trip do
  use GenServer

  alias UserManager
  alias ResultLogger

  @doc """
  Inicia el GenServer con los datos del viaje.
  """
  def start_link({client, origin, dest}) do
    GenServer.start_link(__MODULE__, {client, origin, dest})
  end

  @doc """
  Acepta el viaje con el conductor dado.
  """
  def accept(pid, driver), do: GenServer.call(pid, {:accept, driver})

  @doc """
  Marca el viaje como completado.
  """
  def complete(pid), do: GenServer.cast(pid, :complete)

  @doc """
  Retorna el estado actual del viaje.
  """
  def state(pid), do: GenServer.call(pid, :get_state)

  @doc """
  Inicializa el estado del viaje y programa su expiración.
  """
  def init({%User{} = client, origin, dest}) do
    trip_id = System.unique_integer([:positive])
    Process.send_after(self(), :expire, 20_000)

    state = %{
      id: trip_id,
      client: client,
      driver: nil,
      origin: origin,
      destination: dest,
      status: :waiting,
      inserted_at: DateTime.utc_now(),
      accepted_at: nil,
      completed_at: nil,
      logged: false
    }

    {:ok, _pid} =
      Registry.register(:trip_registry, trip_id, nil)

    {:ok, state}
  end

  @doc """
  Acepta el viaje si está disponible.
  """
  def handle_call({:accept, driver}, _from, %{status: :waiting, driver: nil} = s) do
    new_state = %{s | driver: driver, status: :accepted, accepted_at: DateTime.utc_now()}
    {:reply, {:ok, :accepted}, new_state}
  end

  def handle_call({:accept, _}, _from, state) do
    {:reply, {:error, :already_taken}, state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @doc """
  Completa el viaje y actualiza puntajes y registro.
  """
  def handle_cast(:complete, %{client: c, driver: d, status: :accepted, logged: false} = s) do
    UserManager.update_score(c.username, 10)
    UserManager.update_score(d.username, 15)

    ResultLogger.log_trip(%{
      fecha: DateTime.utc_now() |> DateTime.to_iso8601(),
      cliente: c.username,
      conductor: d.username,
      origen: s.origin,
      destino: s.destination,
      estado: "Completado"
    })

    {:noreply, %{s | status: :completed, completed_at: DateTime.utc_now(), logged: true}}
  end

  def handle_cast(:complete, %{logged: true} = s) do
    {:noreply, s}
  end

  @doc """
  Expira el viaje si sigue en espera.
  """
  def handle_info(:expire, %{status: :waiting, logged: false} = s) do
    UserManager.update_score(s.client.username, -5) 
    ResultLogger.log_trip(%{
      fecha: DateTime.utc_now() |> DateTime.to_iso8601(),
      cliente: s.client.username,
      conductor: "N/A",
      origen: s.origin,
      destino: s.destination,
      estado: "Expirado"
    })

    {:noreply, %{s | status: :expired, logged: true}}
  end

  def handle_info(:expire, %{status: status} = s) when status in [:accepted, :completed, :expired] do
  {:noreply, s}
end

  @doc """
  Operación de cierre del GenServer.
  """
  def terminate(_reason, _state), do: :ok
end
