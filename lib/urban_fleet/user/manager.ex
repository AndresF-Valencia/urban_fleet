defmodule UserManager do
  use GenServer

  alias Auth
  alias UserStorage
  alias User

  @doc """
  Inicia el UserManager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  @doc """
  Conecta un usuario mediante login.
  """
  def connect(username, password) do
    GenServer.call(__MODULE__, {:connect, username, password})
  end

  @doc """
  Registra un nuevo usuario.
  """
  def register(username, role, password) do
    GenServer.call(__MODULE__, {:register, username, role, password})
  end

  @doc """
  Desconecta un usuario.
  """
  def disconnect(username) do
    GenServer.call(__MODULE__, {:disconnect, username})
  end

  @doc """
  Obtiene el puntaje de un usuario.
  """
  def get_user_score(username) do
    GenServer.call(__MODULE__, {:get_score, username})
  end

  @doc """
  Actualiza el puntaje de un usuario.
  """
  def update_score(username, delta) do
    GenServer.call(__MODULE__, {:update_score, username, delta})
  end

  @doc """
  Obtiene el ranking de usuarios por rol.
  """
  def ranking(role) when role in [:client, :driver] do
    GenServer.call(__MODULE__, {:ranking, role})
  end

  @doc """
  Inicializa el estado del servidor.
  """
  @impl true
  def init(:ok) do
    {:ok, %{connected: MapSet.new()}}
  end

  @doc """
  Maneja la conexión de un usuario mediante login.
  """
  @impl true
  def handle_call({:connect, username, password}, _from, state) do
    case Auth.login(username, password) do
      {:ok, :logged_in, user} ->
        new_state = %{state | connected: MapSet.put(state.connected, user.username)}
        {:reply, {:ok, :logged_in, user}, new_state}

      {:error, :not_found} ->
        # Devolvemos que no existe: el Handler debe pedir el role y llamar register
        {:reply, {:error, :not_found}, state}

      {:error, :wrong_password} = err ->
        {:reply, err, state}
    end
  end


  @impl true
  def handle_call({:register, username, role, password}, _from, state) do
    case Auth.register(username, role, password) do
      {:ok, :registered, user} ->
        new_state = %{state | connected: MapSet.put(state.connected, user.username)}
        {:reply, {:ok, :registered, user}, new_state}

      error ->
        {:reply, error, state}
    end
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
  def handle_call({:update_score, username, delta}, _from, state) do
    case UserStorage.find_user(username) do
      nil ->
        {:reply, {:error, :not_found}, state}

      user ->
        updated = %{user | score: user.score + delta}
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
