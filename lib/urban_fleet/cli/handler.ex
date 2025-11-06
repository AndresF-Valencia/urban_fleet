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

  ## ===============================
  ## COMANDOS DE USUARIO
  ## ===============================

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

  defp parse_command("disconnect", user) when not is_nil(user) do
    IO.puts("Sesión cerrada")
    {:continue, nil}
  end

  defp parse_command("score", user) when not is_nil(user) do
    case UserManager.get_user_score(user) do
      {:ok, score} -> IO.puts("Tu puntaje: #{score}")
      _ -> IO.puts("Error obteniendo puntaje")
    end
    {:continue, user}
  end

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

  ## ===============================
  ## COMANDOS DE VIAJES
  ## ===============================

  # CLIENTE solicita un viaje
  defp parse_command("request_trip " <> rest, %{role: :client} = user) do
    case String.split(rest, " ") do
      [origin, dest] ->
        {:ok, pid} = TripManager.request_trip(user, origin, dest)
        IO.puts("Solicitud de viaje creada (PID: #{inspect(pid)})")
        {:continue, user}

      _ ->
        IO.puts("Uso: request_trip origen destino")
        {:continue, user}
    end
  end

  # CONDUCTOR acepta un viaje
  defp parse_command("accept_trip " <> id_str, %{role: :driver} = user) do
    case Integer.parse(id_str) do
      {id, _} ->
        case TripManager.accept_trip(id, user) do
          :ok -> IO.puts("Viaje aceptado")
          {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
        end

      _ ->
        IO.puts("Uso: accept_trip id_viaje")
    end

    {:continue, user}
  end

  # CONDUCTOR completa un viaje
  defp parse_command("complete_trip " <> id_str, %{role: :driver} = user) do
    case Integer.parse(id_str) do
      {id, _} ->
        TripManager.complete_trip(id)
        IO.puts("Viaje completado exitosamente")

      _ ->
        IO.puts("Uso: complete_trip id_viaje")
    end

    {:continue, user}
  end

  ## ===============================
  ## OTROS COMANDOS
  ## ===============================

  defp parse_command("locations", user) do
    LocationManager.list_locations()
    {:continue, user}
  end

  defp parse_command("help", user) do
    IO.puts("""
    Comandos:

      connect user pass        - Conectar/registrar
      disconnect               - Salir
      score                    - Ver tu puntaje
      ranking client|driver    - Ver ranking
      request_trip o d         - Cliente crea viaje
      accept_trip id           - Conductor acepta viaje
      complete_trip id         - Conductor finaliza viaje
      locations                - Ver ubicaciones
      exit                     - Cerrar programa
    """)
    {:continue, user}
  end

  defp parse_command("exit", _user), do: :exit

  defp parse_command(_, user) do
    IO.puts("Comando desconocido. Escribe 'help'")
    {:continue, user}
  end
end
