defmodule TripManager do
  alias UserStorage

  def score_for_trip(user, result) do
    score =
      case {user.role, result} do
        {:client, :complet} -> 10
        {:client, :expired} -> -5
        {:driver, :complet} -> 15
        _ -> 0
      end

    update_score(user, score)
  end

  defp update_score(user, score) when score != 0 do
    users = UserStorage.load_users()

    updated_users =
      Enum.map(users, fn u ->
        if u.id == user.id, do: %{u | score: u.score + score}, else: u
      end)

    UserStorage.save_user(updated_users)
    {:ok, score}
  end

  defp update_score(_, _), do: {:ok, 0}
end
