defmodule MarketMind.Accounts.User do
  @moduledoc """
  User schema for authentication and multi-tenancy.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :confirmed_at, :utc_datetime

    has_many :projects, MarketMind.Products.Project

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for user registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :hashed_password])
    |> validate_required([:email, :hashed_password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> unique_constraint(:email)
  end
end
