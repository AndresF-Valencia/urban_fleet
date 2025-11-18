defmodule Handler do
  use GenServer

  alias Auth
  alias UserManager
  alias TripManager
  alias LocationManager

  @doc """
  Inicia el sistema, arranca el GenServer y ejecuta el ciclo de comandos.
  """
  def start do
    IO.puts("=== Urban Fleet System ===")
    IO.puts("Escribe 'help' para ver comandos.\n")
    GenServer.start_link(__MODULE__, %{session: nil, active_trip: nil}, name: __MODULE__)
    loop()
  end

  defp loop do
    input = IO.gets("> ") |> String.trim()
    GenServer.cast(__MODULE__, {:command, input})
    loop()
  end

  @doc """
  Inicializa el estado del GenServer.
  """
  @impl true
  def init(state), do: {:ok, state}

  @doc """
  Procesa comandos recibidos desde la consola.
  Maneja la solicitud de viaje de un cliente.
  Muestra el estado del viaje activo de un cliente.
  Muestra los viajes pendientes para el conductor.
  Permite a un conductor aceptar un viaje.
  Permite a un conductor completar un viaje.
  Maneja comandos desconocidos.
  """
  @impl true
  def handle_cast({:command, input}, state) do
    case parse(input) do
      {:ok, :help} ->
        {:noreply, state}

      {:ok, {:register, u, r, p}} ->
        reply(Auth.register(u, r, p))
        {:noreply, state}

      {:ok, {:login, u, p}} ->
        case Auth.login(u, p) do
          {:ok, :logged_in, user} ->
            IO.puts("Bienvenido #{user.username} (#{user.role})")
            {:noreply, %{state | session: user}}

          {:error, :not_found} ->
            IO.puts("Usuario no encontrado.")
            {:noreply, state}

          {:error, :wrong_password} ->
            IO.puts("Contraseña incorrecta.")
            {:noreply, state}
        end

      {:ok, :logout} ->
        IO.puts("Sesión cerrada.")
        {:noreply, %{state | session: nil, active_trip: nil}}

      {:ok, :whoami} ->
        case state.session do
          nil -> IO.puts("No has iniciado sesión.")
          user -> IO.puts("Usuario: #{user.username} (#{user.role})")
        end

        {:noreply, state}

      {:ok, {:client_request, origin, dest}} ->
        case state.session do
          %{role: :client, username: _u} ->
            with {:ok, _origin_loc} <- LocationManager.valid_location?(origin),
                 {:ok, _dest_loc} <- LocationManager.valid_location?(dest),
                 {:ok, trip_id, _pid} <- TripManager.request_trip(state.session, origin, dest) do
              IO.puts("Viaje creado con ID #{trip_id}")
              {:noreply, %{state | active_trip: trip_id}}
            else
              {:error, :invalid_location} ->
                IO.puts("Ubicación inválida.")
                {:noreply, state}
            end

          _ ->
            no_perm(:client)
            {:noreply, state}
        end

      {:ok, :client_trip_status} ->
        case {state.session, state.active_trip} do
          {nil, _} ->
            IO.puts("Debes iniciar sesión.")
            {:noreply, state}

          {%{role: :client}, nil} ->
            IO.puts("No tienes viajes activos.")
            {:noreply, state}

          {%{role: :client}, id} ->
            case TripManager.get_trip_state(id) do
              {:error, :not_found} ->
                IO.puts("Ese viaje ya no existe.")
                {:noreply, %{state | active_trip: nil}}

              state_info ->
                IO.inspect(state_info, label: "Estado actual del viaje")
                {:noreply, state}
            end

          _ ->
            no_perm(:client)
            {:noreply, state}
        end

      {:ok, :driver_pending} ->
        if driver?(state) do
          show_pending()
          {:noreply, state}
        else
          no_perm(:driver)
          {:noreply, state}
        end

      {:ok, {:driver_accept, id}} ->
        if driver?(state) do
          reply(TripManager.accept_trip(id, state.session))
          {:noreply, state}
        else
          no_perm(:driver)
          {:noreply, state}
        end

      {:ok, {:driver_complete, id}} ->
        if driver?(state) do
          reply(TripManager.complete_trip(id))
          {:noreply, state}
        else
          no_perm(:driver)
          {:noreply, state}
        end

      {:ok, :score} ->
        case state.session do
          nil ->
            IO.puts("Debes iniciar sesión.")
            {:noreply, state}

          %User{} = user ->
            case UserManager.get_user_score(user.username) do
              {:ok, score} -> IO.puts("Tu puntaje actual es: #{score}")
              {:error, :not_found} -> IO.puts("Usuario no encontrado.")
            end

            {:noreply, state}
        end

      {:ok, :my_trips} ->
        case state.session do
          nil ->
            IO.puts("Debes iniciar sesión.")
            {:noreply, state}

          %User{role: :client, username: u} ->
            trips = TripManager.list_user_trips(u)
            IO.puts("=== Tus viajes como cliente ===")

            Enum.each(trips, fn t ->
              IO.puts(
                "ID: #{t.id}, Estado: #{t.status}, Origen: #{t.origin}, Destino: #{t.destination}"
              )
            end)

            {:noreply, state}

          %User{role: :driver, username: u} ->
            trips = TripManager.list_driver_trips(u)
            IO.puts("=== Tus viajes como conductor ===")

            Enum.each(trips, fn t ->
              IO.puts(
                "ID: #{t.id}, Estado: #{t.status}, Cliente: #{t.client.username}, Origen: #{t.origin}, Destino: #{t.destination}"
              )
            end)

            {:noreply, state}
        end

      {:ok, {:ranking, role}} ->
        ranking = UserManager.ranking(role)

        IO.puts("=== Ranking de #{role}s ===")

        Enum.with_index(ranking, 1)
        |> Enum.each(fn {user, idx} ->
          IO.puts("#{idx}. #{user.username} - Puntaje: #{user.score}")
        end)

        {:noreply, state}

      {:error, :unknown} ->
        IO.puts("Comando no reconocido. Escribe 'help'.")
        {:noreply, state}
    end
  end

  defp parse("help"), do: help()

  defp parse("logout"), do: {:ok, :logout}

  defp parse("whoami"), do: {:ok, :whoami}

  defp parse("register " <> rest) do
    case String.split(rest, " ") do
      [u, role, p] ->
        {:ok, {:register, u, String.to_atom(role), p}}

      _ ->
        {:error, :unknown}
    end
  end

  defp parse("login " <> rest) do
    case String.split(rest, " ") do
      [u, p] -> {:ok, {:login, u, p}}
      _ -> {:error, :unknown}
    end
  end

  defp parse("client request_trip " <> rest) do
    case Regex.scan(~r/"([^"]+)"/, rest) do
      [[_, origin], [_, dest]] ->
        {:ok, {:client_request, origin, dest}}

      _ ->
        {:error, :unknown}
    end
  end

  defp parse("client trip_status"), do: {:ok, :client_trip_status}

  defp parse("driver pending_trips"), do: {:ok, :driver_pending}

  defp parse("driver accept " <> id),
    do: {:ok, {:driver_accept, String.to_integer(id)}}

  defp parse("driver complete " <> id),
    do: {:ok, {:driver_complete, String.to_integer(id)}}

  defp parse("score"), do: {:ok, :score}

  defp parse("my_trips"), do: {:ok, :my_trips}

  defp parse("ranking client"), do: {:ok, {:ranking, :client}}

  defp parse("ranking driver"), do: {:ok, {:ranking, :driver}}

  defp parse(_), do: {:error, :unknown}

  defp help do
    IO.puts("""
    === COMANDOS DISPONIBLES ===

    >> USUARIO
    register <username> <client|driver> <password>
    login <username> <password>
    logout
    whoami
    score
    my_trips

    >> CLIENTE
    client request_trip <origin> <dest>
    client trip_status
    ranking client

    >> DRIVER
    driver pending_trips
    driver accept <trip_id>
    driver complete <trip_id>
    ranking driver
    """)

    {:ok, :help}
  end

  defp driver?(state),
    do: state.session != nil and state.session.role == :driver

  defp no_perm(role),
    do: IO.puts("Debes ser #{role} para usar este comando.")

  defp reply(resp), do: IO.inspect(resp, label: "Respuesta")

  defp show_pending do
    IO.puts("=== Viajes Pendientes ===")
    pending = TripManager.list_pending()

    if pending == [] do
      IO.puts("No hay viajes pendientes.")
    else
      Enum.each(pending, fn trip ->
        IO.puts("ID: #{trip.id}, Origen: #{trip.origin}, Destino: #{trip.destination}")
      end)
    end

    IO.puts("Usa 'driver accept <id>' para aceptar uno.")
  end
end
