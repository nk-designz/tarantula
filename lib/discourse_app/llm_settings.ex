defmodule DiscourseApp.LlmSettings do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ["ollama", "claude", "openai"]

  @claude_models [
    "claude-opus-4-5",
    "claude-sonnet-4-5",
    "claude-haiku-4-5",
    "claude-3-7-sonnet-20250219",
    "claude-3-5-sonnet-20241022",
    "claude-3-5-haiku-20241022",
    "claude-3-opus-20240229"
  ]

  @openai_models [
    "gpt-4o",
    "gpt-4o-mini",
    "gpt-4-turbo",
    "gpt-4",
    "o1-preview",
    "o1-mini"
  ]

  def providers, do: @providers
  def claude_models, do: @claude_models
  def openai_models, do: @openai_models

  schema "llm_settings" do
    field(:provider, :string, default: "ollama")
    field(:ollama_url, :string, default: "http://localhost:11434")
    field(:ollama_model, :string, default: "")
    field(:claude_api_key, :string, default: "")
    field(:claude_model, :string, default: "claude-opus-4-5")
    field(:openai_api_key, :string, default: "")
    field(:openai_model, :string, default: "gpt-4o")

    timestamps()
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [
      :provider,
      :ollama_url,
      :ollama_model,
      :claude_api_key,
      :claude_model,
      :openai_api_key,
      :openai_model
    ])
    |> validate_required([:provider])
    |> validate_inclusion(:provider, @providers)
  end
end
