defmodule Handler do
  use GenServer

  alias Auth
  alias UserManager
  alias TripManager
  alias LocationManager

  ## ==========================================
  ## ============  PUBLIC API  =================
  ## ==========================================

  def start do
    IO.puts("=== Urban Fleet System ===")
    IO.puts("Escribe 'help' para ver comandos.\n")
    GenServer.start_link(__MODULE__, %{session: nil, active_trip: nil}, name: __MODULE__)
    loop()
  end

  ## CLI principal
  defp loop do
    input = IO.gets("> ") |> String.trim()
    GenServer.cast(__MODULE__, {:command, input})
    loop()
  end

  ## ==========================================
  ## ============  GEN SERVER  =================
  ## ==========================================

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:command, input}, state) do
    case parse(input) do
      {:ok, {:register, u, r, p}} ->
        reply(Auth.register(u, r, p))
        {:noreply, state}

      {:ok, {:login, u, p}} ->
        case Auth.login(u, p) do
          {:ok, :logged_in, user} ->
            IO.puts("Bienvenido #{user.username} (#{user.role})")
            {:noreply, %{state | session: user}}

          err ->
            reply(err)
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

      ## ========================= CLIENT =========================

      {:ok, {:client_request, origin, dest}} ->
        case state.session do
          %{role: :client, username: u} ->
            with {:ok, _, _} <- LocationManager.valid_location?(origin),
                 {:ok, _, _} <- LocationManager.valid_location?(dest),
                 {:ok, trip_id, pid} <- TripManager.request_trip(u, origin, dest)
            do
              IO.puts("🚗 Viaje creado con ID #{trip_id}")

              {:noreply, %{state | active_trip: trip_id}}
            else
              {:error, :invalid_location} ->
                IO.puts("❌ Ubicación inválida.")
                {:noreply, state}
            end

          _ -> no_perm(:client); {:noreply, state}
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

          _ -> no_perm(:client); {:noreply, state}
        end

      ## ======================= DRIVER ==========================

      {:ok, :driver_pending} ->
        if driver?(state) do
          show_pending()
          {:noreply, state}
        else
          no_perm(:driver); {:noreply, state}
        end

      {:ok, {:driver_accept, id}} ->
        if driver?(state) do
          reply(TripManager.accept_trip(id, state.session.username))
          {:noreply, state}
        else
          no_perm(:driver); {:noreply, state}
        end

      {:ok, {:driver_complete, id}} ->
        if driver?(state) do
          reply(TripManager.complete_trip(id))
          {:noreply, state}
        else
          no_perm(:driver); {:noreply, state}
        end

      ## ========================= OTROS =========================

      {:error, :unknown} ->
        IO.puts("Comando no reconocido. Escribe 'help'.")
        {:noreply, state}
    end
  end

  ## ==========================================
  ## ============  PARSER CLI  =================
  ## ==========================================

  defp parse("help"), do: help()

  defp parse("logout"), do: {:ok, :logout}
  defp parse("whoami"), do: {:ok, :whoami}

  # Registro
  defp parse("register " <> rest) do
    case String.split(rest, " ") do
      [u, role, p] ->
        {:ok, {:register, u, String.to_atom(role), p}}
      _ -> {:error, :unknown}
    end
  end

  # Login
  defp parse("login " <> rest) do
    case String.split(rest, " ") do
      [u, p] -> {:ok, {:login, u, p}}
      _ -> {:error, :unknown}
    end
  end

  ## CLIENTE
  defp parse("client request_trip " <> rest) do
    case String.split(rest, " ") do
      [o, d] -> {:ok, {:client_request, o, d}}
      _ -> {:error, :unknown}
    end
  end

  defp parse("client trip_status"), do: {:ok, :client_trip_status}

  ## DRIVER
  defp parse("driver pending_trips"), do: {:ok, :driver_pending}

  defp parse("driver accept " <> id),
    do: {:ok, {:driver_accept, String.to_integer(id)}}

  defp parse("driver complete " <> id),
    do: {:ok, {:driver_complete, String.to_integer(id)}}

  defp parse(_), do: {:error, :unknown}

  ## ==========================================
  ## ============ HELP Y UTILIDADES ===========
  ## ==========================================

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

  defp driver?(state),
    do: state.session != nil and state.session.role == :driver

  defp no_perm(role),
    do: IO.puts("❌ Debes ser #{role} para usar este comando.")

  defp reply(resp), do: IO.inspect(resp, label: "Respuesta")

  defp show_pending do
    IO.puts("=== Viajes Pendientes ===")
    IO.puts("Usa 'driver accept <id>' para aceptar uno.")
  end
end
