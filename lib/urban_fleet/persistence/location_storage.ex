defmodule LocationStorage do
  @ruta "data/locations.dat"

  @doc """
  Carga las ubicaciones desde el archivo correspondiente.
  """
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

      {:error, reason} ->
        IO.puts("Error leyendo ubicaciones: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Guarda una nueva ubicación si no existe.
  """
  def save_location(location) do
    locations = load_locations()

    if location in locations do
      {:error, :duplicate}
    else
      new_list = locations ++ [location]
      File.write!(@ruta, Enum.join(new_list, "\n") <> "\n")
      {:ok, new_list}
    end
  end
end
