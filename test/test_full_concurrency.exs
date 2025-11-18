alias User
alias UserManager
alias TripManager
IO.puts("\n=== INICIANDO TEST DE CONCURRENCIA ===\n")

  # Creamos los usuarios
  alice = %User{username: "alice", role: :client, password_hash: "xxx", score: 0}
  sofia = %User{username: "sofia", role: :client, password_hash: "xxx", score: 0}
  pablo = %User{username: "pablo", role: :driver, password_hash: "xxx", score: 0}
  ana = %User{username: "ana", role: :driver, password_hash: "xxx", score: 0}

  [alice, sofia, pablo, ana]
  |> Enum.each(fn u ->
    case UserManager.register(u.username, u.role, "1234") do
      {:ok, _, _} -> :ok
      _ -> :ok
    end
  end)

  # Creamos viajes concurrentemente
  trip_tasks =
    [
      Task.async(fn -> TripManager.request_trip(alice, "Centro", "Parque Sucre") end),
      Task.async(fn -> TripManager.request_trip(sofia, "Estadio", "Museo") end),
      Task.async(fn -> TripManager.request_trip(alice, "Terminal", "Plaza") end),
      Task.async(fn -> TripManager.request_trip(sofia, "Hospital", "Aeropuerto") end)
    ]
    |> Enum.map(&Task.await(&1))

  IO.puts("\n--- Viajes creados ---")
  Enum.each(trip_tasks, fn {:ok, id, _pid} -> IO.puts("ID: #{id}") end)

  # Listamos viajes pendientes
  IO.puts("\n--- Viajes pendientes ---")
  TripManager.list_pending()
  |> Enum.each(fn trip ->
    IO.puts("ID: #{trip.id}, Origen: #{trip.origin}, Destino: #{trip.destination}, Estado: #{trip.status}")
  end)

  pending_trips = TripManager.list_pending()

  # Aceptamos viajes concurrentemente y completamos algunos
  complete_tasks =
    pending_trips
    |> Enum.with_index()
    |> Enum.map(fn {trip, idx} ->
      driver_user =
        case rem(idx, 2) do
          0 -> pablo
          1 -> ana
        end

      Task.async(fn ->
        :timer.sleep(500 + idx * 200)   # simulamos pequeñas demoras
        {:ok, :accepted} = TripManager.accept_trip(trip.id, driver_user)

        # Completamos solo la mitad de los viajes
        if rem(idx, 2) == 0 do
          :timer.sleep(1000)  # tiempo de viaje
          {:ok, :completed} = TripManager.complete_trip(trip.id)
        end
      end)
    end)
    |> Enum.map(&Task.await(&1))

  # Esperamos para que los viajes pendientes "expiren"
  IO.puts("\n--- Esperando que los viajes pendientes expiren (20s) ---")
  :timer.sleep(21_000)

  IO.puts("\n--- Estados finales de los viajes ---")
  all_trip_ids = Enum.map(trip_tasks, fn {:ok, id, _} -> id end)

  Enum.each(all_trip_ids, fn id ->
    state = TripManager.get_trip_state(id)
    IO.inspect(state)
  end)

  # Mostramos viajes por cliente
  IO.puts("\n--- Viajes por cliente ---")
  [alice, sofia]
  |> Enum.each(fn client ->
    IO.puts("\nCliente #{client.username}:")
    TripManager.list_user_trips(client.username)
    |> Enum.each(&IO.inspect(&1))
  end)

  # Mostramos viajes por conductor
  IO.puts("\n--- Viajes por conductor ---")
  [pablo, ana]
  |> Enum.each(fn driver ->
    IO.puts("\nConductor #{driver.username}:")
    TripManager.list_driver_trips(driver.username)
    |> Enum.each(&IO.inspect(&1))
  end)

  # Ranking
  IO.puts("\n--- Ranking de Clientes ---")
  UserManager.ranking(:client)
  |> Enum.each(fn u -> IO.puts("#{u.username}: #{u.score}") end)

  IO.puts("\n--- Ranking de Conductores ---")
  UserManager.ranking(:driver)
  |> Enum.each(fn u -> IO.puts("#{u.username}: #{u.score}") end)

  IO.puts("\n=== TEST DE CONCURRENCIA FINALIZADO ===\n")
