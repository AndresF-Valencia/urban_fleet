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

    @doc """
  Lee comandos del usuario y los envía al GenServer.
  """
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

      @doc """
      Maneja la solicitud de viaje de un cliente.
      """
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

      @doc """
      Muestra el estado del viaje activo de un cliente.
      """
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


      @doc """
      Muestra los viajes pendientes para el conductor.
      """
      {:ok, :driver_pending} ->
        if driver?(state) do
          show_pending()
          {:noreply, state}
        else
          no_perm(:driver)
          {:noreply, state}
        end

      @doc """
      Permite a un conductor aceptar un viaje.
      """
      {:ok, {:driver_accept, id}} ->
        if driver?(state) do
          reply(TripManager.accept_trip(id, state.session.username))
          {:noreply, state}
        else
          no_perm(:driver)
          {:noreply, state}
        end

      @doc """
      Permite a un conductor completar un viaje.
      """
      {:ok, {:driver_complete, id}} ->
        if driver?(state) do
          reply(TripManager.complete_trip(id))
          {:noreply, state}
        else
          no_perm(:driver)
          {:noreply, state}
        end

      @doc """
      Maneja comandos desconocidos.
      """

      {:error, :unknown} ->
        IO.puts("Comando no reconocido. Escribe 'help'.")
        {:noreply, state}
    end
  end

  @doc """
  Procesa el comando 'help'.
  """
  defp parse("help"), do: help()

  @doc """
  Procesa el comando 'logout'.
  """
  defp parse("logout"), do: {:ok, :logout}

  @doc """
  Procesa el comando 'whoami'.
  """
  defp parse("whoami"), do: {:ok, :whoami}

  @doc """
  Procesa el comando de registro de usuario.
  """
  defp parse("register " <> rest) do
    case String.split(rest, " ") do
      [u, role, p] ->
        {:ok, {:register, u, String.to_atom(role), p}}

      _ ->
        {:error, :unknown}
    end
  end

   @doc """
  Procesa el comando de login.
  """
  defp parse("login " <> rest) do
    case String.split(rest, " ") do
      [u, p] -> {:ok, {:login, u, p}}
      _ -> {:error, :unknown}
    end
  end

  @doc """
  Procesa la solicitud de viaje de un cliente.
  """
  defp parse("client request_trip " <> rest) do
  case Regex.scan(~r/"([^"]+)"/, rest) do
    [[_, origin], [_, dest]] ->
      {:ok, {:client_request, origin, dest}}

    _ ->
      {:error, :unknown}
  end
end

 @doc """
  Procesa el comando para ver el estado del viaje del cliente.
  """
  defp parse("client trip_status"), do: {:ok, :client_trip_status}

  @doc """
  Procesa el comando para ver viajes pendientes del conductor.
  """
  defp parse("driver pending_trips"), do: {:ok, :driver_pending}

  @doc """
  Procesa el comando para que el conductor acepte un viaje.
  """
  defp parse("driver accept " <> id),
    do: {:ok, {:driver_accept, String.to_integer(id)}}

  @doc """
  Procesa el comando para que el conductor complete un viaje.
  """
  defp parse("driver complete " <> id),
    do: {:ok, {:driver_complete, String.to_integer(id)}}

  @doc """
  Procesa comandos desconocidos.
  """
  defp parse(_), do: {:error, :unknown}

  @doc """
  Muestra los comandos disponibles.
  """
  defp help do
    IO.puts("""
    === COMANDOS DISPONIBLES ===

    >> USUARIO
    register <username> <client|driver> <password>
    login <username> <password>
    logout
    whoami

    >> CLIENTE
    client request_trip <origin> <dest>
    client trip_status

    >> DRIVER
    driver pending_trips
    driver accept <trip_id>
    driver complete <trip_id>
    """)

    {:ok, :help}
  end

  @doc """
  Verifica si el usuario actual es conductor.
  """
  defp driver?(state),
    do: state.session != nil and state.session.role == :driver

  @doc """
  Muestra mensaje de falta de permisos.
  """

  defp no_perm(role),
    do: IO.puts("Debes ser #{role} para usar este comando.")

  @doc """
  Imprime una respuesta formateada.
  """
  defp reply(resp), do: IO.inspect(resp, label: "Respuesta")

  @doc """
  Muestra los viajes pendientes.
  """
  defp show_pending do
    IO.puts("=== Viajes Pendientes ===")
    IO.puts("Usa 'driver accept <id>' para aceptar uno.")
  end
end
