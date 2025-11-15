defmodule User do
  @moduledoc """
  Representa a un usuario del sistema.
  """

  defstruct [
    :name,        # Identificador único
    :role,            # :client o :driver
    :password_hash,   # Hash SHA256
    score: 0          # Puntuación inicial
  ]
end
