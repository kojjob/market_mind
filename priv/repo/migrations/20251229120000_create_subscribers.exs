defmodule MarketMind.Repo.Migrations.CreateSubscribers do
  use Ecto.Migration

  def change do
    create table(:subscribers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :first_name, :string
      add :status, :string, null: false, default: "pending"
      add :confirmed_at, :utc_datetime
      add :unsubscribed_at, :utc_datetime
      add :source, :string
      add :source_id, :binary_id
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}

      # GDPR Compliance
      add :consent_given_at, :utc_datetime
      add :consent_ip, :string
      add :consent_user_agent, :text

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:subscribers, [:email, :project_id])
    create index(:subscribers, [:project_id])
    create index(:subscribers, [:status])
  end
end
