defmodule UrbanFleet.TripTest do
  use ExUnit.Case

  alias UrbanFleet.Trip

  setup do
    {:ok, pid} = Trip.start_link({%UrbanFleet.User{username: "juan", role: :client}, "A", "B"})
    %{pid: pid}
  end

  test "aceptar viaje", %{pid: pid} do
    {:ok, :accepted} = Trip.accept(pid, %UrbanFleet.User{username: "pedro", role: :driver})
    state = Trip.state(pid)
    assert state.status == :accepted
  end

  test "completar viaje", %{pid: pid} do
    {:ok, :accepted} = Trip.accept(pid, %UrbanFleet.User{username: "pedro", role: :driver})
    Trip.complete(pid)
    Process.sleep(50) # espera que se ejecute el cast
    state = Trip.state(pid)
    assert state.status == :completed
  end
end
