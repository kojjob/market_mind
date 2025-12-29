defmodule MarketMind.Repo.Migrations.CreateContents do
  use Ecto.Migration

  def change do
    create table(:contents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content_type, :string, null: false, default: "blog_post"
      add :status, :string, null: false, default: "draft"
      add :body, :text
      add :meta_description, :string
      add :target_keyword, :string
      add :secondary_keywords, {:array, :string}, default: []
      add :word_count, :integer
      add :reading_time_minutes, :integer
      add :seo_data, :map, default: %{}
      add :persona_id, references(:personas, type: :binary_id, on_delete: :nilify_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:contents, [:project_id])
    create index(:contents, [:persona_id])
    create unique_index(:contents, [:project_id, :slug])
  end
end
