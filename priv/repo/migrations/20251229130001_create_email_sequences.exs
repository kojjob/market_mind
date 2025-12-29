defmodule MarketMind.Repo.Migrations.CreateEmailSequences do
  use Ecto.Migration

  def change do
    # Email sequences - automated email campaigns triggered by events
    create table(:email_sequences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :trigger, :string, null: false  # "lead_magnet_download", "subscriber_confirmed", "manual"
      add :trigger_id, :binary_id  # ID of lead_magnet if trigger is lead_magnet_download
      add :status, :string, null: false, default: "draft"  # draft, active, paused

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:email_sequences, [:project_id])
    create index(:email_sequences, [:status])
    create index(:email_sequences, [:trigger])

    # Individual emails within a sequence
    create table(:sequence_emails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :subject, :string, null: false
      add :body, :text, null: false  # HTML or markdown content
      add :delay_days, :integer, null: false, default: 0  # Days after sequence start
      add :delay_hours, :integer, default: 0  # Additional hours after delay_days
      add :position, :integer, null: false  # Order in sequence
      add :status, :string, default: "active"  # active, paused

      add :sequence_id, references(:email_sequences, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sequence_emails, [:sequence_id])
    create unique_index(:sequence_emails, [:sequence_id, :position])

    # Tracks delivery of each email to each subscriber
    create table(:email_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "scheduled"  # scheduled, pending, sent, failed, opened, clicked
      add :scheduled_for, :utc_datetime  # When this email should be sent
      add :sent_at, :utc_datetime
      add :opened_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :error_message, :text
      add :attempts, :integer, default: 0

      add :subscriber_id, references(:subscribers, type: :binary_id, on_delete: :delete_all), null: false
      add :sequence_email_id, references(:sequence_emails, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:email_deliveries, [:subscriber_id])
    create index(:email_deliveries, [:sequence_email_id])
    create index(:email_deliveries, [:status])
    create index(:email_deliveries, [:scheduled_for])
    create unique_index(:email_deliveries, [:subscriber_id, :sequence_email_id])
  end
end
