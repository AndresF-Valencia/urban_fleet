defmodule LocationStorage do
  @ruta "data/locations.dat"

  def load_locations do
    case File.read(@ruta) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      {:error, :enoent} ->
        IO.puts("Advertencia: #{@ruta} no encontrado. Creando un archivo nuevo...")
        File.mkdir_p!("data")
        File.write!(@ruta, "Centro\nNorte\nSur\nEste\nOeste")
        load_locations()

        {:error, reason}->
          IO.puts("Error leyendo ubicaciones: #{inspect(reason)}") []
        end
  end

  def save_locations(locations) do
    locations = load_locations()

    if Enum.member?(locations, location) do
      {:error, :duplicate}
    else
      File.write(@ruta, Enum.join(locations ++ [location], "\n")
      "\n")
   end
  end
end
