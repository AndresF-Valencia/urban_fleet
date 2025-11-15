defmodule UserStorage do
  @ruta "data/users.dat"

  alias User

  # ===============================
  # Cargar todos los usuarios
  # ===============================
  def load_users do
    case File.read(@ruta) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_line/1)
        |> Enum.reject(&is_nil/1)

      {:error, :enoent} ->
        File.mkdir_p!("data")
        File.write!(@ruta, "")
        []
    end
  end

  # ===============================
  # Buscar usuario por username
  # ===============================
  def find_user(username) do
    load_users()
    |> Enum.find(&(&1.username == username))
  end

  # ===============================
  # Guardar o actualizar un usuario
  # ===============================
  def save_user(%User{} = user) do
    users =
      load_users()
      |> Enum.reject(&(&1.username == user.username))

    new_list = users ++ [user]

    File.write!(@ruta, Enum.map_join(new_list, "\n", &format_line/1) <> "\n")

    :ok
  end

  # ===============================
  # FORMATO DEL ARCHIVO
  # ===============================

  # id|username|role|password_hash|score
  defp format_line(%User{ name: username, role: role, password_hash: hash, score: score}) do
    "#{username}|#{role}|#{hash}|#{score}"
  end

  defp parse_line(line) do
    case String.split(line, "|") do
      [username, role, hash, score] ->
        %User{
          name: username,
          role: String.to_atom(role),
          password_hash: hash,
          score: String.to_integer(score)
        }

      _ ->
        nil
    end
  end
end
