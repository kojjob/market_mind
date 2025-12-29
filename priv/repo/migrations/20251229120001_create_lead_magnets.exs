defmodule MarketMind.Repo.Migrations.CreateLeadMagnets do
  use Ecto.Migration

  def change do
    create table(:lead_magnets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :magnet_type, :string, null: false  # checklist, guide, cheatsheet, template, worksheet
      add :status, :string, null: false, default: "draft"  # draft, active, archived

      # The actual content (markdown)
      add :content, :text

      # Landing page customization
      add :headline, :string
      add :subheadline, :text
      add :cta_text, :string, default: "Get Free Access"
      add :thank_you_message, :text
      add :download_url, :string  # Optional external file URL

      # SEO
      add :meta_description, :string

      # Stats (denormalized for performance)
      add :download_count, :integer, default: 0
      add :conversion_rate, :decimal  # Calculated periodically

      # Relationships
      add :content_id, references(:contents, type: :binary_id, on_delete: :nilify_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lead_magnets, [:project_id, :slug])
    create index(:lead_magnets, [:project_id])
    create index(:lead_magnets, [:content_id])
    create index(:lead_magnets, [:status])
  end
end
