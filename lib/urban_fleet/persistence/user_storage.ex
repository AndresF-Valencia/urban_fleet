defmodule UserStorage do
  @ruta "data/users.dat"

  alias User

  # ===============================
  # Cargar todos los usuarios
  # ===============================
  def load_users do
    ensure_data_dir()

    case File.read(@ruta) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_line/1)
        |> Enum.reject(&is_nil/1)

      {:error, :enoent} ->
        [] # ensure_data_dir ya creó el archivo
    end
  end

  # ===============================
  # Buscar usuario por username
  # ===============================
  def find_user(username) when is_binary(username) do
    load_users()
    |> Enum.find(&(&1.username == username))
  end

  # ===============================
  # Guardar o actualizar un usuario (solo un user)
  # ===============================
  def save_user(%User{} = user) do
    users =
      load_users()
      |> Enum.reject(&(&1.username == user.username))

    new_list = users ++ [user]

    save_users(new_list)
  end

  # ===============================
  # Guardar lista completa (sobrescribe)
  # ===============================
  def save_users(users) when is_list(users) do
    ensure_data_dir()

    content =
      users
      |> Enum.map(&format_line/1)
      |> Enum.join("\n")

    File.write!(@ruta, content <> "\n")
    :ok
  end

  # ===============================
  # FORMATO DEL ARCHIVO
  # ===============================

  # username|role|password_hash|score
  defp format_line(%User{username: username, role: role, password_hash: hash, score: score}) do
    "#{username}|#{role}|#{hash}|#{score}"
  end

  defp parse_line(line) do
    case String.split(line, "|") do
      [username, role, hash, score] ->
        %User{
          username: username,
          role: String.to_atom(role),
          password_hash: hash,
          score: String.to_integer(score)
        }

      _ ->
        nil
    end
  end

  defp ensure_data_dir do
    File.mkdir_p!("data")
    if not File.exists?(@ruta), do: File.write!(@ruta, "")
  end
end
