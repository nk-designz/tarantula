defmodule DiscourseApp.Repo.Migrations.AddRetrySettingsToLlmSettings do
  use Ecto.Migration

  def change do
    alter table(:llm_settings) do
      add :analysis_max_retries, :integer, null: false, default: 3
      add :analysis_retry_delay_s, :integer, null: false, default: 2
    end
  end
end
