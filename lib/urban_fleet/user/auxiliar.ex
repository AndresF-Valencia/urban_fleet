defmodule Auth do
  alias User
  alias UserStorage

  @doc """
  Registra un nuevo usuario si no existe.
  """
  def register(username, role, password) when role in [:client, :driver] do
    case UserStorage.find_user(username) do
      nil ->
        user = %User{
          username: username,
          role: role,
          password_hash: hash_password(password),
          score: 0
        }

        UserStorage.save_user(user)
        {:ok, :registered, user}

      _ ->
        {:error, :user_exists}
    end
  end

  @doc """
  Inicia sesión de un usuario si las credenciales son válidas.
  """
  def login(username, password) do
    case UserStorage.find_user(username) do
      nil ->
        {:error, :not_found}

      user ->
        if verify_password(user, password) do
          {:ok, :logged_in, user}
        else
          {:error, :wrong_password}
        end
    end
  end

  @doc """
  Genera el hash SHA-256 de la contraseña.
  """
  defp hash_password(password) do
    :crypto.hash(:sha256, password)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifica si la contraseña coincide con el hash almacenado.
  """
  defp verify_password(user, password) do
    hash_password(password) == user.password_hash
  end
end
