defmodule MarketMind.Fixtures do
  @moduledoc """
  Test fixtures for creating test data.
  """

  alias MarketMind.Repo

  @doc """
  Creates a user directly in the database for testing.
  """
  def user_fixture(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      email: "user#{unique_id}@example.com",
      hashed_password: "hashed_password_#{unique_id}",
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    user_attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    {1, _} = Repo.insert_all("users", [user_attrs])

    # Fetch the inserted user to get proper typed fields
    Repo.get!(MarketMind.Accounts.User, uuid)
  end
end
