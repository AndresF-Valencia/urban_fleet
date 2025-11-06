defmodule Trip do
  use GenServer
  alias UserStorage


  # Iniciar un viaje
  def start_link({client, origin, dest}) do
    GenServer.start_link(Trip, {client, origin, dest})
  end

  # Conductor acepta viaje
  def accept(pid, driver) do
    GenServer.call(pid, {:accept, driver})
  end

  # Conductor finaliza viaje
  def complete(pid) do
    GenServer.cast(pid, :complete)
  end

  # Ver estado de viaje
  def state(pid) do
    GenServer.call(pid, :state)
  end


  def init({client, origin, dest}) do
    # Timer 20s para expirar si no hay conductor
    Process.send_after(self(), :expire, 20_000)

    {:ok,
      %{
        client: client,
        driver: nil,
        origin: origin,
        destination: dest,
        status: :waiting
      }
    }
  end

  # Conductor acepta viaje si está libre
  def handle_call({:accept, driver}, _from, %{status: :waiting, driver: nil} = s) do
    {:reply, {:ok, :accepted}, %{s | driver: driver, status: :accepted}}
  end

  # Si ya tiene conductor
  def handle_call({:accept, _}, _from, state) do
    {:reply, {:error, :already_taken}, state}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  # Finalizar viaje -> dar puntajes
  def handle_cast(:complete, %{client: c, driver: d, status: :accepted} = s) do
    update_score(c, :complet)
    update_score(d, :complet)
    {:stop, :normal, %{s | status: :completed}}
  end

  # Expira sin conductor -> penalizar cliente
  def handle_info(:expire, %{status: :waiting, client: c} = s) do
    update_score(c, :expired)
    {:stop, :normal, %{s | status: :expired}}
  end

  # Si expira pero ya estaba aceptado, ignorar
  def handle_info(:expire, s), do: {:noreply, s}

  ## =========================
  ##  LOGICA DE PUNTAJE
  ## =========================

  defp update_score(user, result) do
    score =
      case {user.role, result} do
        {:client, :complet} -> 10
        {:client, :expired} -> -5
        {:driver, :complet} -> 15
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

    UserStorage.save_user(updated)
  end
end
