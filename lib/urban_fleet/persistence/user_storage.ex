defmodule UserStorage do
  @moduledoc """
  Módulo encargado de leer y escribir usuarios en el archivo `data/users.dat`.

  Formato de cada línea: id|nombre|rol|password_hash|puntaje
  """

  @ruta "data/users.dat"

  @doc """
  Guarda una lista de usuarios en el archivo `users.dat`.
  Cada usuario se escribe en una línea con formato: id|nombre|rol|password_hash|puntaje
  """
  def save_users(user_map) do
    users= load_users()
    updated = [user_map | Enum.reject(users, &(&1. username ==
      user_map.username))]

      content = Enum.map_join(updated, "\n", &format_line/1 <> "\n")
      File.write(@ruta, content)
    end
  end

  @doc"""
  Busca los usuarios por el nombre y el id
  """
  def find_user(username, id) do
    load_users() |>Enum.find(&(&1.username == username))
    load_users() |>Enum.find(&(&1.id == id))
  end

  @doc """
  Carga todos los usuarios desde el archivo `users.dat` y los convierte en structs.
  Si el archivo no existe, devuelve una lista vacía.
  """
  def load_users do
    case File.read(@ruta) do
      {:ok, content} -> content
      |>String.split("\n", trim: true)
      |>Enun.map(&parse_line/1)
      |>Enum.reject(&is_nil/1)

      {:error:, :enoent}->
        File.mkdir_p!("data")
        File.write!(@ruta, "")[]

        {:error, _}->[] end
      end

  defp parse_line(line) do
    case String.split(line, "|")do
      [name, role, hash, score]->
        %{
          username: name,
          role: String.to_atom(role),
          password_hash: hash,
          score: String.to_integer(score)
        }
        _-> nil
    end

    defp format_line(user) do
      "#{user.username}|#{user.role}|#{user.password_hash}|#{user.score}"
    end
  end
