defmodule ResultLogger do
  @moduledoc "Guarda el historial de viajes en data/results.log"
  @ruta "data/results.log"

  @doc """
  Registra un viaje en el archivo de historial.
  """
  def log_trip(%{fecha: fecha, cliente: cliente, conductor: conductor, origen: origen, destino: destino, estado: estado}) do
    File.mkdir_p!("data")
    if not File.exists?(@ruta), do: File.write!(@ruta, "")
    linea = Enum.join([fecha, cliente, conductor, origen, destino, estado], ";") <> "\n"
    File.write!(@ruta, linea, [:append])
  end
end
