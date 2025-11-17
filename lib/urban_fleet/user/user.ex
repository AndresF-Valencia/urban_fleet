defmodule User do
  @moduledoc"""
  Estructura de usuario persistida en users.dat
  """

  defstruct username: nil,
            role: nil,
            password_hash: nil,
            score: 0
end
