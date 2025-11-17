defmodule Formatter do

  @doc """
  Construye los datos iniciales de un viaje.
  """
  def format_trip_data(client, origin, destination) do
    %{
      client: client.username,
      driver: nil,
      origin: origin,
      destination: destination,
      status: :pending
    }
  end

  @doc """
  Asigna un conductor a un viaje.
  """
  def apply_driver(trip, driver) do
    Map.put(trip, :driver, driver.username)
    |> Map.put(:status, :accepted)
  end


  @doc """
  Marca un viaje como completado.
  """
  def complete_trip(trip) do
    Map.put(trip, :status, :completed)
  end
end
