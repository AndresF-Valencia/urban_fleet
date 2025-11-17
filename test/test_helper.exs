defmodule UrbanFleet.HelperTest do
  use ExUnit.Case
  alias UrbanFleet.Helper

  test "función de ejemplo del helper" do
    assert Helper.format_trip("A", "B") == "Trip from A to B"
  end
end
