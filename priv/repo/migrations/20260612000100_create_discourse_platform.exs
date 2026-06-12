defmodule DiscourseApp.Repo.Migrations.CreateDiscoursePlatform do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"
      add :current_step, :string, null: false, default: "idle"
      add :progress, :integer, null: false, default: 0
      add :eta_seconds, :integer
      add :network_snapshot, :map
      add :last_error, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create table(:documents) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :original_filename, :string, null: false
      add :content_type, :string
      add :storage_path, :string, null: false
      add :source_type, :string, null: false, default: "upload"
      add :status, :string, null: false, default: "uploaded"
      add :extracted_text, :text
      add :last_error, :text
      add :metadata, :map

      timestamps()
    end

    create index(:documents, [:project_id])

    create table(:actors) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :occurrences_count, :integer, null: false, default: 0
      add :document_count, :integer, null: false, default: 0
      add :metadata, :map

      timestamps()
    end

    create unique_index(:actors, [:project_id, :slug])

    create table(:concepts) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :occurrences_count, :integer, null: false, default: 0
      add :document_count, :integer, null: false, default: 0
      add :metadata, :map

      timestamps()
    end

    create unique_index(:concepts, [:project_id, :slug])

    create table(:stances) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :actor_id, references(:actors, on_delete: :nilify_all)
      add :concept_id, references(:concepts, on_delete: :nilify_all)
      add :actor_name, :string, null: false
      add :concept_name, :string, null: false
      add :stance, :string, null: false
      add :excerpt, :text
      add :line_start, :integer
      add :line_end, :integer
      add :metadata, :map

      timestamps()
    end

    create index(:stances, [:project_id])
    create index(:stances, [:document_id])
    create index(:stances, [:actor_id])
    create index(:stances, [:concept_id])
  end
end
