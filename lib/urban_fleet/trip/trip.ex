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
    # 20 segundos para expirar si no hay conductor
    Process.send_after(self(), :expire, 20_000)

    trip_id = System.unique_integer([:positive])

    state = %{
      id: trip_id,
      client: client,
      driver: nil,
      origin: origin,
      destination: dest,
      status: :waiting,
      inserted_at: DateTime.utc_now()
    }

    # Registrarse en el Registry con la clave trip_id
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

  @doc """
  Retorna error si el viaje ya fue aceptado.
  """
  def handle_call({:accept, _}, _from, state) do
    {:reply, {:error, :already_taken}, state}
  end

  @doc """
  Devuelve el estado actual del viaje.
  """
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @doc """
  Completa el viaje y actualiza puntajes y registro.
  """
  def handle_cast(:complete, %{client: c, driver: d, status: :accepted} = s) do
    # Delegar el update de puntajes al UserManager
    UserManager.update_score(c.username, 10)
    UserManager.update_score(d.username, 15)

    # Loggear el resultado
    ResultLogger.log_trip(%{
      fecha: DateTime.utc_now() |> DateTime.to_iso8601(),
      cliente: c.username,
      conductor: d.username,
      origen: s.origin,
      destino: s.destination,
      estado: "Completado"
    })

    {:stop, :normal, %{s | status: :completed, completed_at: DateTime.utc_now()}}
  end

  @doc """
  Expira el viaje si sigue en espera.
  """
  def handle_info(:expire, %{status: :waiting, client: c} = s) do
    UserManager.update_score(c.username, -5)

    ResultLogger.log_trip(%{
      fecha: DateTime.utc_now() |> DateTime.to_iso8601(),
      cliente: c.username,
      conductor: "N/A",
      origen: s.origin,
      destino: s.destination,
      estado: "Expirado"
    })

    {:stop, :normal, %{s | status: :expired}}
  end

  @doc """
  Ignora la expiración si el viaje ya cambió de estado.
  """
  def handle_info(:expire, s), do: {:noreply, s}

  @doc """
  Operación de cierre del GenServer.
  """
  def terminate(_reason, _state), do: :ok
end
