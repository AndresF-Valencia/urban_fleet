defmodule Trip do
  use GenServer
  alias UserStorage

  ##  API PÚBLICA

  # Iniciar un viaje
  def start_link({client, origin, destination}) do
    GenServer.start_link(__MODULE__, {client, origin, destination})
  end

  # Conductor acepta el viaje
  def accept(pid, driver) do
    GenServer.call(pid, {:accept, driver})
  end

  # Conductor finaliza el viaje
  def complete(pid) do
    GenServer.cast(pid, :complete)
  end

  # Consultar el estado actual del viaje
  def state(pid) do
    GenServer.call(pid, :state)
  end

  ##  CALLBACKS DEL SERVIDOR

  def init({client, origin, destination}) do
    # Temporizador: expira si nadie acepta en 20 segundos
    Process.send_after(self(), :expire, 20_000)

    {:ok,
      %{
        client: client,
        driver: nil,
        origin: origin,
        destination: destination,
        status: :pending
      }
    }
  end

  # Aceptar viaje (si está pendiente)
  def handle_call({:accept, driver}, _from, %{status: :pending, driver: nil} = s) do
    {:reply, {:ok, :accepted}, %{s | driver: driver, status: :accepted}}
  end

  # Si ya fue aceptado
  def handle_call({:accept, _}, _from, state) do
    {:reply, {:error, :already_taken}, state}
  end

  # Obtener estado
  def handle_call(:state, _from, state), do: {:reply, state, state}

  # Completar viaje
  def handle_cast(:complete, %{client: c, driver: d, status: :accepted} = s) do
    update_score(c, :completed)
    update_score(d, :completed)
    IO.puts("✅ Viaje completado por #{d.username}")
    {:stop, :normal, %{s | status: :completed}}
  end

  # Si expira sin conductor → penalizar cliente
  def handle_info(:expire, %{status: :pending, client: c} = s) do
    update_score(c, :expired)
    IO.puts("⏰ Viaje expirado para #{c.username}")
    {:stop, :normal, %{s | status: :expired}}
  end

  # Si ya estaba aceptado, ignorar expiración
  def handle_info(:expire, s), do: {:noreply, s}

  ##  LÓGICA DE PUNTAJE

  defp update_score(user, result) do
    score =
      case {user.role, result} do
        {:client, :completed} -> 10
        {:client, :expired} -> -5
        {:driver, :completed} -> 15
        _ -> 0
      end

    apply_score(user.username, score)
  end

  defp apply_score(_username, 0), do: :ok

  defp apply_score(username, score) do
    users = UserStorage.load_users()

    updated =
      Enum.map(users, fn u ->
        if u.username == username do
          %{u | score: u.score + score}
        else
          u
        end
      end)

    UserStorage.save_users(updated)
  end
end
