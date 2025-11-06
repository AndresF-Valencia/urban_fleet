defmodule LocationManager do
  alias LocationStorage

  def valid_location?(location) do
    locations = LocationStorage.load_locations()

    exists? =
      Enum.any?(locations, fn loc ->
        String.downcase(loc) == String.downcase(location)
      end)

    if exists?, do: {:ok, location}, else: {:error, :invalid_location}
  end

  def list_locations do
    locations = LocationStorage.load_locations()

    if locations == [] do
      IO.puts("No hay ubicaciones registradas.")
    else
      IO.puts("\n=== Ubicaciones Disponibles ===")
      Enum.each(locations, fn loc -> IO.puts(" - #{loc}") end)
    end

    :ok
  end
end
