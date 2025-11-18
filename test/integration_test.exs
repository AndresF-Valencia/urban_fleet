defmodule IntegrationTest do
  use ExUnit.Case

  alias TripManager
  alias UserManager

  @moduletag :integration

  test "registro, login y solicitud de viaje" do
    {:ok, :registered, client} = UserManager.register("juan", :client, "123")
    {:ok, :registered, driver} = UserManager.register("pedro", :driver, "123")

    {:ok, :logged_in, _} = UserManager.connect("juan", "123")
    {:ok, :logged_in, _} = UserManager.connect("pedro", "123")

    {:ok, :accepted, trip} = TripManager.request_trip(client, "Centro", "Parque Sucre")
    {:ok, :accepted} = TripManager.accept_trip(trip.pid, driver)

    state = TripManager.get_trip_state(trip.pid)
    assert state.status == :accepted
  end
end
