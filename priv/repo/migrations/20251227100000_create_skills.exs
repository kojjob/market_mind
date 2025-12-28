defmodule MarketMind.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :version, :string, null: false, default: "1.0.0"
      add :category, :string, null: false

      # The skill's brain
      add :prompt_template, :text, null: false
      add :system_prompt, :text

      # Input/output contracts
      add :input_schema, :map, null: false, default: %{}
      add :output_schema, :map, null: false, default: %{}

      # What this skill needs
      add :required_context, {:array, :string}, default: []
      add :tools, {:array, :string}, default: []

      # LLM preferences
      add :llm_provider, :string, default: "gemini"
      add :llm_model, :string, default: "gemini-1.5-flash"
      add :llm_config, :map, default: %{"temperature" => 0.7}

      # Quality tracking
      add :usage_count, :integer, default: 0
      add :success_count, :integer, default: 0
      add :avg_quality_score, :decimal, precision: 3, scale: 2
      add :avg_execution_time_ms, :integer

      # Status
      add :is_active, :boolean, default: true
      add :is_beta, :boolean, default: false

      # Metadata
      add :created_by, :binary_id
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:skills, [:name])
    create unique_index(:skills, [:slug])
    create index(:skills, [:category])
    create index(:skills, [:is_active])
  end
end
