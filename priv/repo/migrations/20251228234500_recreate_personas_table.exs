defmodule MarketMind.Repo.Migrations.RecreatePersonasTable do
  use Ecto.Migration

  def up do
    drop_if_exists table(:personas)

    create table(:personas, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :role, :string
      add :description, :text
      add :demographics, :map
      add :goals, {:array, :string}
      add :pain_points, {:array, :string}
      add :objections, {:array, :string}
      add :motivations, {:array, :string}
      add :channels, {:array, :string}
      add :keywords, {:array, :string}
      add :personality_traits, :map
      add :is_primary, :boolean, default: false, null: false
      add :project_id, references(:projects, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:personas, [:project_id])
  end

  def down do
    drop table(:personas)
  end
end
