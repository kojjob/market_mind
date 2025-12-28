defmodule MarketMind.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :url, :string, null: false
      add :description, :text
      add :analysis_status, :string, default: "pending"
      add :analysis_data, :map
      add :analyzed_at, :utc_datetime
      add :brand_voice, :string
      add :tone, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:projects, [:slug])
    create index(:projects, [:user_id])
    create index(:projects, [:analysis_status])
  end
end
