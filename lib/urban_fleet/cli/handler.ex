defmodule Handler do
  def start do
    IO.puts("=== Urban Fleet System ===")
    IO.puts("Escribe 'help' para ver comandos\n")
    loop(nil)
  end

  defp loop(current_user) do
    prompt =
      if current_user,
        do: "#{current_user.username}> ",
        else: "> "

    input = IO.gets(prompt) |> String.trim()

    case parse_command(input, current_user) do
      {:continue, new_user} -> loop(new_user)
      :exit -> IO.puts("Adiós")
    end
  end

  # CONNECT
  defp parse_command("connect " <> rest, nil) do
    case String.split(rest, " ") do
      [user, pass] ->
        case UserManager.connect(user, pass) do
          {:ok, :registered, u} ->
            IO.puts("Registrado exitosamente")
            {:continue, u}

          {:ok, :logged_in, u} ->
            IO.puts("Bienvenido de nuevo")
            {:continue, u}

          {:error, :wrong_password} ->
            IO.puts("Contraseña incorrecta")
            {:continue, nil}

          _ ->
            IO.puts("Error: No se pudo iniciar sesión")
            {:continue, nil}
        end

      _ ->
        IO.puts("Uso: connect username password")
        {:continue, nil}
    end
  end

  # DISCONNECT
  defp parse_command("disconnect", user) when not is_nil(user) do
    IO.puts("Sesión cerrada")
    {:continue, nil}
  end

  # SCORE
  defp parse_command("score", user) when not is_nil(user) do
    case UserManager.get_user_score(user) do
      {:ok, score} -> IO.puts("Tu puntaje: #{score}")
      _ -> IO.puts("Error obteniendo puntaje")
    end
    {:continue, user}
  end

  # RANKING
  defp parse_command("ranking " <> role, user) do
    role_atom = String.to_atom(role)
    ranking = UserManager.ranking(role_atom)

    IO.puts("\n--- Ranking #{role} ---")
    Enum.with_index(ranking, 1)
    |> Enum.each(fn {u, i} ->
      IO.puts("#{i}. #{u.username}: #{u.score} pts")
    end)

    {:continue, user}
  end

  # LOCATIONS
  defp parse_command("locations", user) do
    LocationManager.list_locations()
    {:continue, user}
  end

  # HELP
  defp parse_command("help", user) do
    IO.puts("""
    Comandos:

      connect user pass      - Conectar/registrar
      disconnect             - Salir
      score                  - Ver tu puntaje
      ranking client|driver  - Ver ranking
      locations              - Ver ubicaciones
      exit                   - Cerrar programa
    """)
    {:continue, user}
  end

  defp parse_command("exit", _user), do: :exit

  defp parse_command(_, user) do
    IO.puts("Comando desconocido. Escribe 'help'")
    {:continue, user}
  end
end
