defmodule UserManager do
  @moduledoc """
  Maneja el registro, autenticación y carga/guardado de usuarios en el sistema.
  """
  defmodule UserManager do

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(UserManager, :ok, opts ++ [name: UserManager])
  end

  def connect(username, password) do
    GenServer.call(UserManager, {:connect, username, password})
  end

  def disconnect(username) do
    GenServer.call(UserManager, {:disconnect, username})
  end

  def get_user_score(username) do
    GenServer.call(UserManager, {:get_score, username})
  end

  def update_score(username, points) do
    GenServer.call(UserManager, {:update_score, username, points})
  end

  def ranking(role) when role in [:client, :driver] do
    GenServer.call(UserManager, {:ranking, role})
  end

  @impl true
  def init(:ok) do
    {:ok, %{connected: MapSet.new()}}
  end

  @impl true
  def handle_call({:connect, username, password}, _from, state) do
    user = UserStorage.find_user(username)

    result = case user do
      nil ->
        IO.puts("Usuario nuevo. ¿Rol? (client/driver):")
        role = IO.gets("> ") |> String.trim() |> String.to_atom()
        new_user = %{
          username: username,
          role: role,
          password_hash: hash_password(password),
          score: 0
        }
        UserStorage.save_user(new_user)
        {:ok, :registered, new_user}
      existing ->
        if verify_password(existing, password) do
          {:ok, :logged_in, existing}
        else
          {:error, :wrong_password}
        end
    end

    new_state = if match?({:ok, _, _}, result) do
      %{state | connected: MapSet.put(state.connected, username)}
    else
      state
    end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:disconnect, username}, _from, state) do
    new_state = %{state | connected: MapSet.delete(state.connected, username)}
    {:reply, :ok, new_state}
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

  defp hash_password(pwd) do
    :crypto.hash(:sha256, pwd) |> Base.encode16()
  end

  defp verify_password(user, pwd) do
    user.password_hash == hash_password(pwd)
  end
end

  alias UserStorage
  alias User

  @doc """
  Crea y guarda un nuevo usuario si el nombre no existe.
  """
  def register_user(name, role, password) do
    users = UserStorage.load_users()

    case Enum.find(users, &(&1.name == name)) do
      nil ->
        new_user = %User{
          id: generate_id(),
          name: name,
          role: role,
          password_hash: hash_password(password),
          score: 0
        }

        UserStorage.save_users(users ++ [new_user])
        {:ok, new_user}

      _existing ->
        {:error, :usuario_ya_existente}
    end
  end

  @doc """
  Inicia sesión verificando el nombre y la contraseña de un usuario.
  """
  def login(name, password) do
    users = UserStorage.load_users()

    case Enum.find(users, &(&1.name == name)) do
      nil ->
        {:error, :usuario_no_encontrado}

      user ->
        if verificar_password(user, password),
          do: {:ok, user},
          else: {:error, :contraseña_incorrecta}
    end
  end

  def get_score_by_id(id) do
    users = UserStorage.load_users()

    case Enum.find(users, &(&1.id == id)) do
      nil -> {:error, :usuario_no_encontrado}
      user -> {:ok, user.score}
    end
  end

  def ranking do
    users = UserStorage.load_users()

    users
    |> Enum.group_by(& &1.role)
    |> Enum.map(fn {role, users_in_role} ->
      {
        role,
        Enum.sort_by(users_in_role, & &1.score, :desc)
      }
    end)
  end

  defp generate_id, do: :erlang.unique_integer([:positive])

  defp hash_password(password),
    do: :crypto.hash(:sha256, password) |> Base.encode16()

  defp verificar_password(user, password),
    do: hash_password(password) == user.password_hash
end
