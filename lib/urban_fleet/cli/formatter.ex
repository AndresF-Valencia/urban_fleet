defmodule Formatter do

  # Crear un viaje base cuando el cliente lo solicita
  def format_trip_data(client, origin, destination) do
    %{
      client: client.username,
      driver: nil,
      origin: origin,
      destination: destination,
      status: :pending
    }
  end

  # Cuando el conductor acepta
  def apply_driver(trip, driver) do
    Map.put(trip, :driver, driver.username)
    |> Map.put(:status, :accepted)
  end

  # Cuando el viaje se completa
  def complete_trip(trip) do
    Map.put(trip, :status, :completed)
  end
end
