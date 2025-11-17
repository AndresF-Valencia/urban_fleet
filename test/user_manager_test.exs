defmodule UrbanFleet.UserManagerTest do
  use ExUnit.Case
  alias UrbanFleet.UserManager

  test "registro y login de usuario" do
    {:ok, :registered, _} = UserManager.register("juan", :client, "123")
    {:ok, :logged_in, _} = UserManager.connect("juan", "123")
  end

  test "actualizar puntaje" do
    {:ok, :registered, _} = UserManager.register("pedro", :driver, "123")
    {:ok, score} = UserManager.update_score("pedro", 10)
    assert score == 10
  end
end
