defmodule DiscourseApp.Repo.Migrations.CreateLlmSettings do
  use Ecto.Migration

  def change do
    create table(:llm_settings) do
      add :provider, :string, null: false, default: "ollama"
      add :ollama_url, :string, null: false, default: "http://localhost:11434"
      add :ollama_model, :string, null: false, default: ""
      add :claude_api_key, :string, null: false, default: ""
      add :claude_model, :string, null: false, default: "claude-opus-4-5"
      add :openai_api_key, :string, null: false, default: ""
      add :openai_model, :string, null: false, default: "gpt-4o"

      timestamps()
    end
  end
end
