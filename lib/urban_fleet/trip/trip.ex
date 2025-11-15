defmodule Trip do
  use GenServer
  alias UserStorage

  ## =======================
  ##   API
  ## =======================

  def start_link({client, origin, dest}) do
    GenServer.start_link(__MODULE__, {client, origin, dest})
  end

  def accept(pid, driver), do: GenServer.call(pid, {:accept, driver})
  def complete(pid), do: GenServer.cast(pid, :complete)
  def state(pid), do: GenServer.call(pid, :state)

  ## =======================
  ##   INIT
  ## =======================

  def init({client, origin, dest}) do
    # 20 segundos para expirar
    Process.send_after(self(), :expire, 20_000)

    trip_id = System.unique_integer([:positive])

    {:ok,
      %{
        id: trip_id,
        client: client,
        driver: nil,
        origin: origin,
        destination: dest,
        status: :waiting
      }
    }
  end

  ## =======================
  ##   HANDLE CALLS / CASTS
  ## =======================

  def handle_call({:accept, driver}, _from, %{status: :waiting, driver: nil} = s) do
    {:reply, {:ok, :accepted}, %{s | driver: driver, status: :accepted}}
  end

  def handle_call({:accept, _}, _from, state) do
    {:reply, {:error, :already_taken}, state}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_cast(:complete, %{client: c, driver: d, status: :accepted} = s) do
    update_score(c, :completed)
    update_score(d, :completed)
    {:stop, :normal, %{s | status: :completed}}
  end

  ## =======================
  ##   EXPIRACIÓN
  ## =======================

  def handle_info(:expire, %{status: :waiting, client: c} = s) do
    update_score(c, :expired)
    {:stop, :normal, %{s | status: :expired}}
  end

  def handle_info(:expire, s), do: {:noreply, s}

  ## =======================
  ##   PUNTAJES
  ## =======================

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
        if u.name == username do
          %{u | score: u.score + score}
        else
          u
        end
      end)

    # Sobrescribir la lista completa
    File.write!("data/users.dat", Enum.map_join(updated, "\n", fn u ->
      "#{u.name}|#{u.role}|#{u.password_hash}|#{u.score}"
    end) <> "\n")

    :ok
  end
end
