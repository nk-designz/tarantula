defmodule DiscourseApp.Settings do
  @moduledoc "Manages application-level settings, starting with LLM configuration."

  import Ecto.Query
  alias DiscourseApp.{Repo, LlmSettings}

  @doc "Returns the single LLM settings row, creating defaults if not yet present."
  def get_llm_settings do
    case Repo.one(from(s in LlmSettings, limit: 1)) do
      nil ->
        %LlmSettings{}
        |> LlmSettings.changeset(%{})
        |> Repo.insert!()

      settings ->
        settings
    end
  end

  @doc "Updates the LLM settings with the given attrs. Returns {:ok, settings} or {:error, changeset}."
  def update_llm_settings(attrs) do
    get_llm_settings()
    |> LlmSettings.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Fetches the list of available model names from the local Ollama instance.
  Returns {:ok, [model_name]} or {:error, reason_string}.
  """
  def fetch_ollama_models(base_url \\ "http://localhost:11434") do
    url = String.trim_trailing(base_url, "/") <> "/api/tags"

    case Req.get(url, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"models" => models}}} when is_list(models) ->
        names = Enum.map(models, & &1["name"])
        {:ok, names}

      {:ok, %{status: status}} ->
        {:error, "Ollama returned HTTP #{status}"}

      {:error, %{reason: reason}} ->
        {:error, "Cannot reach Ollama at #{base_url}: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Cannot reach Ollama at #{base_url}: #{inspect(reason)}"}
    end
  end
end
