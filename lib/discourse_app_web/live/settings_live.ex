defmodule DiscourseAppWeb.SettingsLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.{Settings, LlmSettings}

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_llm_settings()
    form = settings_to_form(settings)

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:form, form)
     |> assign(:ollama_models, [])
     |> assign(:ollama_status, nil)
     |> assign(:saving, false)}
  end

  @impl true
  def handle_event("validate", %{"llm_settings" => attrs}, socket) do
    merged = Map.merge(settings_fields(socket.assigns.settings), attrs)
    {:noreply, assign(socket, :form, to_form(merged, as: :llm_settings))}
  end

  @impl true
  def handle_event("save", %{"llm_settings" => attrs}, socket) do
    case Settings.update_llm_settings(attrs) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign(:settings, settings)
         |> assign(:form, settings_to_form(settings))
         |> put_flash(:info, "Settings saved.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save settings.")}
    end
  end

  @impl true
  def handle_event("fetch_ollama_models", _params, socket) do
    url = socket.assigns.form.params["ollama_url"] || socket.assigns.settings.ollama_url

    case Settings.fetch_ollama_models(url) do
      {:ok, []} ->
        {:noreply,
         assign(
           socket,
           :ollama_status,
           {:warn, "Ollama is reachable but has no models pulled yet."}
         )}

      {:ok, models} ->
        {:noreply,
         socket
         |> assign(:ollama_models, models)
         |> assign(:ollama_status, {:ok, "#{length(models)} model(s) available."})}

      {:error, reason} ->
        {:noreply, assign(socket, :ollama_status, {:error, reason})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}} nav_section={:settings}>
      <div class="max-w-2xl">
        <div class="mb-6">
          <h1 class="text-3xl font-semibold tracking-tight">Settings</h1>
          <p class="mt-1 text-sm" style="color: var(--text-muted);">
            Configure which LLM provider is used for document analysis.
          </p>
        </div>

        <.form
          for={@form}
          id="llm-settings-form"
          phx-change="validate"
          phx-submit="save"
        >
          <%!-- Provider selector --%>
          <div class="settings-card">
            <h2 class="settings-section-title">LLM Provider</h2>
            <p class="settings-section-desc">Choose which service processes your documents.</p>

            <div class="mt-4 grid grid-cols-3 gap-3">
              <label class={provider_card_class(@form[:provider].value == "ollama")}>
                <input
                  type="radio"
                  name="llm_settings[provider]"
                  value="ollama"
                  checked={@form[:provider].value == "ollama"}
                  class="sr-only"
                />
                <.icon name="hero-server" class="size-5 mb-1" />
                <span class="font-semibold text-sm">Ollama</span>
                <span class="text-xs mt-0.5" style="color: var(--text-muted);">Local / private</span>
              </label>

              <label class={provider_card_class(@form[:provider].value == "claude")}>
                <input
                  type="radio"
                  name="llm_settings[provider]"
                  value="claude"
                  checked={@form[:provider].value == "claude"}
                  class="sr-only"
                />
                <.icon name="hero-sparkles" class="size-5 mb-1" />
                <span class="font-semibold text-sm">Claude</span>
                <span class="text-xs mt-0.5" style="color: var(--text-muted);">Anthropic</span>
              </label>

              <label class={provider_card_class(@form[:provider].value == "openai")}>
                <input
                  type="radio"
                  name="llm_settings[provider]"
                  value="openai"
                  checked={@form[:provider].value == "openai"}
                  class="sr-only"
                />
                <.icon name="hero-cpu-chip" class="size-5 mb-1" />
                <span class="font-semibold text-sm">ChatGPT</span>
                <span class="text-xs mt-0.5" style="color: var(--text-muted);">OpenAI</span>
              </label>
            </div>
          </div>

          <%!-- Ollama settings --%>
          <div class={["settings-card mt-4", @form[:provider].value != "ollama" && "hidden"]}>
            <h2 class="settings-section-title">Ollama</h2>
            <p class="settings-section-desc">
              Runs models locally. Make sure Ollama is running before analyzing.
            </p>

            <div class="mt-4 space-y-4">
              <div class="dna-field">
                <label class="dna-label" for="llm_settings_ollama_url">Server URL</label>
                <input
                  id="llm_settings_ollama_url"
                  type="text"
                  name="llm_settings[ollama_url]"
                  value={@form[:ollama_url].value}
                  placeholder="http://localhost:11434"
                  class="dna-input"
                />
              </div>

              <div class="dna-field">
                <div class="flex items-center justify-between mb-1">
                  <label class="dna-label mb-0" for="llm_settings_ollama_model">Model</label>
                  <button
                    type="button"
                    class="dna-button dna-button-secondary"
                    style="padding: 0.3rem 0.75rem; font-size: 0.78rem;"
                    phx-click="fetch_ollama_models"
                  >
                    <.icon name="hero-arrow-path" class="size-3.5" /> Refresh
                  </button>
                </div>

                <%= if @ollama_models != [] do %>
                  <select
                    id="llm_settings_ollama_model"
                    name="llm_settings[ollama_model]"
                    class="dna-input"
                  >
                    <option value="">— select a model —</option>
                    <%= for m <- @ollama_models do %>
                      <option value={m} selected={@form[:ollama_model].value == m}>{m}</option>
                    <% end %>
                  </select>
                <% else %>
                  <input
                    id="llm_settings_ollama_model"
                    type="text"
                    name="llm_settings[ollama_model]"
                    value={@form[:ollama_model].value}
                    placeholder="e.g. llama3 or deepseek-coder-v2:latest"
                    class="dna-input"
                  />
                <% end %>

                <%= if @ollama_status do %>
                  <p class={status_text_class(elem(@ollama_status, 0))}>
                    {elem(@ollama_status, 1)}
                  </p>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Claude settings --%>
          <div class={["settings-card mt-4", @form[:provider].value != "claude" && "hidden"]}>
            <h2 class="settings-section-title">Claude — Anthropic</h2>
            <p class="settings-section-desc">
              Uses the Anthropic Messages API. Requires a valid API key from <a
                href="https://console.anthropic.com"
                target="_blank"
                style="color: var(--accent);"
              >console.anthropic.com</a>.
            </p>

            <div class="mt-4 space-y-4">
              <div class="dna-field">
                <label class="dna-label" for="llm_settings_claude_api_key">API Key</label>
                <input
                  id="llm_settings_claude_api_key"
                  type="password"
                  name="llm_settings[claude_api_key]"
                  value={@form[:claude_api_key].value}
                  placeholder="sk-ant-..."
                  class="dna-input"
                  autocomplete="off"
                />
              </div>

              <div class="dna-field">
                <label class="dna-label" for="llm_settings_claude_model">Model</label>
                <select
                  id="llm_settings_claude_model"
                  name="llm_settings[claude_model]"
                  class="dna-input"
                >
                  <%= for m <- LlmSettings.claude_models() do %>
                    <option value={m} selected={@form[:claude_model].value == m}>{m}</option>
                  <% end %>
                </select>
              </div>
            </div>
          </div>

          <%!-- OpenAI settings --%>
          <div class={["settings-card mt-4", @form[:provider].value != "openai" && "hidden"]}>
            <h2 class="settings-section-title">ChatGPT — OpenAI</h2>
            <p class="settings-section-desc">
              Uses the OpenAI Chat Completions API. Requires a valid API key from <a
                href="https://platform.openai.com/api-keys"
                target="_blank"
                style="color: var(--accent);"
              >platform.openai.com</a>.
            </p>

            <div class="mt-4 space-y-4">
              <div class="dna-field">
                <label class="dna-label" for="llm_settings_openai_api_key">API Key</label>
                <input
                  id="llm_settings_openai_api_key"
                  type="password"
                  name="llm_settings[openai_api_key]"
                  value={@form[:openai_api_key].value}
                  placeholder="sk-..."
                  class="dna-input"
                  autocomplete="off"
                />
              </div>

              <div class="dna-field">
                <label class="dna-label" for="llm_settings_openai_model">Model</label>
                <select
                  id="llm_settings_openai_model"
                  name="llm_settings[openai_model]"
                  class="dna-input"
                >
                  <%= for m <- LlmSettings.openai_models() do %>
                    <option value={m} selected={@form[:openai_model].value == m}>{m}</option>
                  <% end %>
                </select>
              </div>
            </div>
          </div>

          <%!-- Analysis retry settings --%>
          <div class="settings-card mt-4">
            <h2 class="settings-section-title">Analysis retries</h2>
            <p class="settings-section-desc">
              How many times to retry a failed document analysis, and how long to wait between attempts.
            </p>

            <div class="mt-4 grid grid-cols-2 gap-4">
              <div class="dna-field">
                <label class="dna-label" for="llm_settings_analysis_max_retries">Max retries</label>
                <input
                  id="llm_settings_analysis_max_retries"
                  type="number"
                  name="llm_settings[analysis_max_retries]"
                  value={@form[:analysis_max_retries].value}
                  min="1"
                  max="10"
                  class="dna-input"
                />
                <p class="mt-1 text-xs" style="color: var(--text-muted);">1 – 10 attempts</p>
              </div>

              <div class="dna-field">
                <label class="dna-label" for="llm_settings_analysis_retry_delay_s">Retry delay (seconds)</label>
                <input
                  id="llm_settings_analysis_retry_delay_s"
                  type="number"
                  name="llm_settings[analysis_retry_delay_s]"
                  value={@form[:analysis_retry_delay_s].value}
                  min="0"
                  max="60"
                  class="dna-input"
                />
                <p class="mt-1 text-xs" style="color: var(--text-muted);">Base delay; doubles each attempt</p>
              </div>
            </div>
          </div>

          <div class="mt-6">
            <button type="submit" class="dna-button dna-button-primary">
              <.icon name="hero-check" class="size-4" /> Save settings
            </button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp settings_fields(s) do
    %{
      "provider" => s.provider,
      "ollama_url" => s.ollama_url,
      "ollama_model" => s.ollama_model,
      "claude_api_key" => s.claude_api_key,
      "claude_model" => s.claude_model,
      "openai_api_key" => s.openai_api_key,
      "openai_model" => s.openai_model,
      "analysis_max_retries" => s.analysis_max_retries,
      "analysis_retry_delay_s" => s.analysis_retry_delay_s
    }
  end

  defp settings_to_form(settings),
    do: to_form(settings_fields(settings), as: :llm_settings)

  defp provider_card_class(active) do
    base =
      "flex flex-col items-center gap-0.5 rounded-xl border p-4 cursor-pointer transition-all"

    if active do
      "#{base} border-[color:var(--accent)] bg-[color:var(--accent-soft)] text-[color:var(--accent-strong)]"
    else
      "#{base} border-[color:var(--line)] bg-[color:var(--surface-strong)] text-[color:var(--text-muted)] hover:border-[color:var(--line-strong)] hover:text-[color:var(--text-main)]"
    end
  end

  defp status_text_class(:ok), do: "mt-1.5 text-xs text-green-600"
  defp status_text_class(:warn), do: "mt-1.5 text-xs text-amber-600"
  defp status_text_class(:error), do: "mt-1.5 text-xs text-red-600"
end
