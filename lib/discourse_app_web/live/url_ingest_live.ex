defmodule DiscourseAppWeb.UrlIngestLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.Projects

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:project, nil)
      |> assign(:url, "")
      |> assign(:status, :idle)
      |> assign(:result_markdown, nil)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    project = Projects.get_project!(id)

    if connected?(socket) do
      Projects.subscribe_project(project.id)
    end

    {:noreply, assign(socket, :project, project)}
  end

  @impl true
  def handle_event("ingest_url", %{"url" => url}, socket) do
    url = String.trim(url)

    if url == "" do
      {:noreply, assign(socket, :error, "Please enter a URL")}
    else
      socket =
        socket
        |> assign(:url, url)
        |> assign(:status, :fetching)
        |> assign(:error, nil)
        |> assign(:result_markdown, nil)

      send(self(), {:do_ingest, url})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:url, "")
     |> assign(:status, :idle)
     |> assign(:result_markdown, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_info({:do_ingest, url}, %{assigns: %{project: project}} = socket) do
    case Projects.add_url_document(project, url) do
      {:ok, document} ->
        {:noreply,
         socket
         |> assign(:status, :done)
         |> assign(:result_markdown, document.name)
         |> put_flash(:info, "URL ingested and saved as \"#{document.name}\"")}

      {:error, reason} ->
        reason_str =
          cond do
            is_binary(reason) -> reason
            is_map(reason) -> inspect(reason)
            true -> inspect(reason)
          end

        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, reason_str)
         |> put_flash(:error, "Ingest failed: #{reason_str}")}
    end
  end

  @impl true
  def handle_info({:project_updated, _project_id}, socket) do
    {:noreply, assign(socket, :project, Projects.get_project!(socket.assigns.project.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={%{}}
      current_project={@project}
      nav_section={:ingest_url}
    >
      <%= if @project do %>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 class="text-4xl font-semibold tracking-[-0.03em]">Ingest URL</h1>
            <p class="mt-1 text-sm text-[color:var(--text-muted)]">
              Project:
              <span class="font-semibold text-[color:var(--text-main)]">{@project.name}</span>
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link navigate={~p"/projects/#{@project.id}/documents"} class="dna-button dna-button-secondary">
              Documents
            </.link>
            <.link navigate={~p"/projects/#{@project.id}"} class="dna-button dna-button-secondary">
              Project
            </.link>
          </div>
        </div>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <h2 class="text-2xl font-semibold">Fetch and convert a web page</h2>
          <p class="mt-1 text-sm text-[color:var(--text-muted)]">
            Enter a URL. The page will be fetched and converted to Markdown via the configured LLM, then saved as a project document.
          </p>

          <.form
            for={%{}}
            id="url-ingest-form"
            phx-submit="ingest_url"
            class="mt-6 space-y-4"
          >
            <div class="flex gap-3">
              <input
                id="url-input"
                name="url"
                type="url"
                value={@url}
                placeholder="https://example.com/article"
                disabled={@status == :fetching}
                class={[
                  "flex-1 rounded-2xl border px-4 py-3 text-sm focus:outline-none focus:ring-2 transition",
                  "focus:ring-[color:var(--accent)]",
                  if(@status == :fetching,
                    do: "opacity-50 cursor-not-allowed",
                    else: ""
                  )
                ]}
                style="border-color: var(--line); background: var(--surface-strong); color: var(--text-main);"
              />
              <button
                type="submit"
                id="ingest-submit"
                disabled={@status == :fetching}
                class={[
                  "dna-button dna-button-primary whitespace-nowrap",
                  @status == :fetching && "opacity-50 cursor-not-allowed"
                ]}
              >
                <%= if @status == :fetching do %>
                  <.icon name="hero-arrow-path" class="size-4 animate-spin" /> Fetching…
                <% else %>
                  <.icon name="hero-arrow-down-tray" class="size-4" /> Ingest
                <% end %>
              </button>
            </div>
          </.form>

          <%= if @error do %>
            <div
              class="mt-4 rounded-2xl border px-4 py-3 text-sm"
              style="border-color: var(--danger); background: color-mix(in srgb, var(--danger) 10%, transparent); color: var(--danger);"
            >
              <div class="flex items-start gap-2">
                <.icon name="hero-exclamation-circle" class="size-4 mt-0.5 shrink-0" />
                <span>{@error}</span>
              </div>
            </div>
          <% end %>

          <%= if @status == :done do %>
            <div
              class="mt-4 rounded-2xl border px-4 py-3 text-sm"
              style="border-color: var(--success, #10b981); background: color-mix(in srgb, #10b981 10%, transparent); color: #059669;"
            >
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                  <.icon name="hero-check-circle" class="size-4 shrink-0" />
                  <span>Document <strong>{@result_markdown}</strong> saved successfully.</span>
                </div>
                <button
                  type="button"
                  id="clear-btn"
                  phx-click="clear"
                  class="dna-button dna-button-secondary text-xs"
                >
                  Ingest another
                </button>
              </div>
            </div>
          <% end %>
        </section>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <h2 class="text-2xl font-semibold">Document list</h2>
          <p class="mt-1 text-sm text-[color:var(--text-muted)]">
            URL-ingested documents for this project.
          </p>

          <div class="mt-4 space-y-3">
            <%= if Enum.filter(@project.documents, &(&1.source_type == "url")) == [] do %>
              <div
                class="rounded-2xl border border-dashed px-4 py-8 text-center text-sm text-[color:var(--text-muted)]"
                style="border-color: var(--line);"
              >
                No URL-ingested documents yet.
              </div>
            <% else %>
              <%= for doc <- Enum.filter(@project.documents, &(&1.source_type == "url")) do %>
                <div
                  class="flex items-center justify-between gap-3 rounded-2xl border px-4 py-3 text-sm"
                  style="border-color: var(--line); background: var(--surface-strong);"
                >
                  <div class="min-w-0">
                    <div class="font-medium truncate">{doc.name}</div>
                    <div class="text-xs text-[color:var(--text-muted)] truncate">
                      {get_in(doc.metadata, ["url"]) || doc.original_filename}
                    </div>
                  </div>
                  <span class={[
                    "shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
                    Projects.status_tone(doc.status)
                  ]}>
                    {doc.status}
                  </span>
                </div>
              <% end %>
            <% end %>
          </div>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
