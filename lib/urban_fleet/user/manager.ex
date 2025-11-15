defmodule UserManager do
  use GenServer

  alias Auth
  alias UserStorage

  # ===============================
  #  API PÚBLICA
  # ===============================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  # LOGIN
  def connect(username, password) do
    GenServer.call(__MODULE__, {:connect, username, password})
  end

  # LOGOUT
  def disconnect(username) do
    GenServer.call(__MODULE__, {:disconnect, username})
  end

  # OBTENER SCORE DEL USUARIO
  def get_user_score(username) do
    GenServer.call(__MODULE__, {:get_score, username})
  end

  # MODIFICAR SCORE
  def update_score(username, points) do
    GenServer.call(__MODULE__, {:update_score, username, points})
  end

  # RANKING POR ROL
  def ranking(role) when role in [:client, :driver] do
    GenServer.call(__MODULE__, {:ranking, role})
  end

  # ===============================
  # ESTADO DEL SERVIDOR
  # ===============================
  @impl true
  def init(:ok) do
    {:ok, %{connected: MapSet.new()}}
  end

  # ===============================
  # HANDLERS
  # ===============================

  @impl true
  def handle_call({:connect, username, password}, _from, state) do
    response =
      case Auth.login(username, password) do
        {:ok, :logged_in, user} ->
          {:ok, :logged_in, user}

        {:error, :not_found} ->
          # Si el usuario no existe: se registra automáticamente
          IO.puts("Usuario nuevo. Escribe rol (client/driver):")
          role =
            IO.gets("> ")
            |> String.trim()
            |> String.to_atom()

          case Auth.register(username, role, password) do
            {:ok, :registered, user} ->
              {:ok, :registered, user}

            error ->
              error
          end

        error ->
          error
      end

    new_state =
      case response do
        {:ok, _, user} -> %{state | connected: MapSet.put(state.connected, user.username)}
        _ -> state
      end

    {:reply, response, new_state}
  end

  @impl true
  def handle_call({:disconnect, username}, _from, state) do
    {:reply, :ok, %{state | connected: MapSet.delete(state.connected, username)}}
  end

  @impl true
  def handle_call({:get_score, username}, _from, state) do
    case UserStorage.find_user(username) do
      nil -> {:reply, {:error, :not_found}, state}
      user -> {:reply, {:ok, user.score}, state}
    end
  end

  @impl true
  def handle_call({:update_score, username, points}, _from, state) do
    case UserStorage.find_user(username) do
      nil ->
        {:reply, {:error, :not_found}, state}

      user ->
        updated = %{user | score: user.score + points}
        UserStorage.save_user(updated)
        {:reply, {:ok, updated.score}, state}
    end
  end

  @impl true
  def handle_call({:ranking, role}, _from, state) do
    ranking =
      UserStorage.load_users()
      |> Enum.filter(&(&1.role == role))
      |> Enum.sort_by(& &1.score, :desc)

    {:reply, ranking, state}
  end
end
