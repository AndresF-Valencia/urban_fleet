defmodule LocationManager do

 alias LocationStorage

 def valid_location?(location) do
   locations = LocationStorage.load_locations()
   if String.downcase(location) in Enum.map(locations, &String.downcase/1) do
    {:ok, location}
  else
    {:error, :invalid_location}end
 end

 def list_locations do
  case LocationStorage.load_locations()do
    {:ok, []} ->
      IO.puts("No hay ubicaciones disponibles.")
      {:ok, locations} ->
        IO.puts("\n===Ubicaciones disponibles===")
        Enum.each(locations, fn loc -> IO.puts("    #{loc}") end)

        {:eror, reason}->
          IO.puts("Error al cargar ubicaciones: #{inspect(reason)}")
          IO.puts("Contacte al administrador del sistema.")
        end
  end
end
