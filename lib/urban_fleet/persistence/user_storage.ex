defmodule UserStorage do
  @ruta "data/users.dat"

  def save_user(user_map) do
    users = load_users()

    updated =
      [user_map | Enum.reject(users, &(&1.username == user_map.username))]

    content = Enum.map_join(updated, "\n", &format_line/1) <> "\n"
    File.write!(@ruta, content)

    :ok
  end

  def find_user(username) do
    Enum.find(load_users(), &(&1.username == username))
  end

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

  defp parse_line(line) do
    case String.split(line, "|") do
      [username, role, hash, score] ->
        %{
          username: username,
          role: String.to_atom(role),
          password_hash: hash,
          score: String.to_integer(score)
        }

      _ ->
        nil
    end
  end

  defp format_line(user) do
    "#{user.username}|#{user.role}|#{user.password_hash}|#{user.score}"
  end
end
