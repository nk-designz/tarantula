defmodule DiscourseAppWeb.DocumentsLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.Projects

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:documents,
        accept: Projects.supported_extensions(),
        max_entries: 10,
        max_file_size: 20_000_000
      )
      |> assign(:project, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    project = Projects.get_project!(id)

    if connected?(socket) do
      Projects.subscribe_project(project.id)
      Projects.subscribe_projects()
    end

    {:noreply, assign(socket, :project, project)}
  end

  @impl true
  def handle_event("save_documents", _params, %{assigns: %{project: project}} = socket) do
    results =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        result =
          Projects.add_uploaded_document(project, %{
            path: path,
            client_name: entry.client_name,
            client_type: entry.client_type
          })

        {:ok, result}
      end)

    had_error? = Enum.any?(results, &match?({:error, _}, &1))

    socket = refresh_project(socket)

    if had_error? do
      {:noreply, put_flash(socket, :error, "One or more uploads failed")}
    else
      {:noreply, put_flash(socket, :info, "Documents saved")}
    end
  end

  @impl true
  def handle_event("delete_document", %{"id" => id}, socket) do
    case Projects.delete_document(id) do
      {:ok, _} -> {:noreply, socket |> refresh_project() |> put_flash(:info, "Document deleted")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not delete document")}
    end
  end

  @impl true
  def handle_event("analyze_project", _params, %{assigns: %{project: project}} = socket) do
    case Projects.enqueue_analysis(project) do
      {:ok, _} -> {:noreply, put_flash(socket, :info, "Analysis queued")}
      {:error, :no_documents} -> {:noreply, put_flash(socket, :error, "Upload documents first")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_info({:project_updated, _project_id}, socket) do
    {:noreply, refresh_project(socket)}
  end

  @impl true
  def handle_info(:projects_updated, socket) do
    {:noreply, refresh_project(socket)}
  end

  @impl true
  def handle_info({:projects_updated, _project_id}, socket) do
    {:noreply, refresh_project(socket)}
  end

  defp refresh_project(%{assigns: %{project: nil}} = socket), do: socket

  defp refresh_project(socket) do
    assign(socket, :project, Projects.get_project!(socket.assigns.project.id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <%= if @project do %>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 class="text-4xl font-semibold tracking-[-0.03em]">Documents</h1>
            <p class="mt-1 text-sm text-[color:var(--text-muted)]">
              Project:
              <span class="font-semibold text-[color:var(--text-main)]">{@project.name}</span>
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link navigate={~p"/projects/#{@project.id}"} class="dna-button dna-button-secondary">
              Project
            </.link>
            <.link
              navigate={~p"/projects/#{@project.id}/graph"}
              class="dna-button dna-button-secondary"
            >
              DNA Graph
            </.link>
            <.link navigate={~p"/"} class="dna-button dna-button-secondary">Dashboard</.link>
          </div>
        </div>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-2xl font-semibold">Upload and analysis</h2>
              <p class="mt-1 text-sm text-[color:var(--text-muted)]">
                Upload documents then run project analysis in the background.
              </p>
            </div>

            <button
              id="analyze-project"
              type="button"
              phx-click="analyze_project"
              disabled={@project.documents == [] or @project.status in ["queued", "processing"]}
              class="dna-button dna-button-primary"
            >
              {if @project.status in ["queued", "processing"],
                do: "Analysis running",
                else: "Analyze project"}
            </button>
          </div>

          <div class="mt-4 h-3 overflow-hidden rounded-full" style="background: var(--surface-muted);">
            <div
              class="h-full rounded-full bg-[linear-gradient(90deg,#0f766e_0%,#f97316_100%)] transition-all duration-500"
              style={"width: #{@project.progress}%"}
            >
            </div>
          </div>

          <div class="mt-2 text-sm text-[color:var(--text-muted)]">
            {@project.current_step} · ETA {Projects.format_eta(@project.eta_seconds)} · {@project.progress}%
          </div>

          <.form
            for={%{}}
            id="document-upload-form"
            phx-submit="save_documents"
            class="mt-6 space-y-4"
          >
            <div
              class="rounded-2xl border border-dashed p-4"
              style="border-color: var(--line); background: var(--surface-muted);"
            >
              <label
                for={@uploads.documents.ref}
                class="flex cursor-pointer flex-col items-center justify-center gap-3 rounded-2xl border px-4 py-8 text-center transition"
                style="border-color: var(--line); background: var(--surface-strong);"
              >
                <.icon name="hero-arrow-up-tray" class="size-8" />
                <div class="space-y-1">
                  <div class="text-sm font-semibold">Drop files here or browse</div>
                  <div class="text-xs text-[color:var(--text-muted)]">MD, TXT, PDF</div>
                </div>
                <.live_file_input upload={@uploads.documents} class="hidden" />
              </label>
            </div>

            <%= if @uploads.documents.entries != [] do %>
              <div class="space-y-2">
                <%= for entry <- @uploads.documents.entries do %>
                  <div
                    class="rounded-2xl border px-3 py-3 text-sm"
                    style="border-color: var(--line); background: var(--surface-strong);"
                  >
                    <div class="flex items-center justify-between">
                      <div class="font-medium">{entry.client_name}</div>
                      <div>{entry.progress}%</div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <button type="submit" class="dna-button dna-button-secondary">
              Save uploaded documents
            </button>
          </.form>
        </section>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <h2 class="text-2xl font-semibold">Document list</h2>

          <div class="mt-4 space-y-3">
            <%= if @project.documents == [] do %>
              <div
                class="rounded-2xl border border-dashed px-4 py-8 text-sm text-[color:var(--text-muted)]"
                style="border-color: var(--line);"
              >
                No documents uploaded yet.
              </div>
            <% end %>

            <%= for document <- @project.documents do %>
              <article
                class="rounded-2xl border px-4 py-4"
                style="border-color: var(--line); background: var(--surface-strong);"
              >
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 class="text-lg font-semibold">{document.original_filename}</h3>
                    <p class="text-sm text-[color:var(--text-muted)]">
                      {document.content_type || "unknown"}
                    </p>
                  </div>

                  <span class="dna-badge">{document.status}</span>
                </div>

                <div class="mt-3 flex flex-wrap gap-2 text-sm">
                  <a
                    href={"/" <> document.storage_path}
                    target="_blank"
                    class="dna-button dna-button-secondary"
                  >
                    View source
                  </a>
                  <button
                    type="button"
                    phx-click="delete_document"
                    phx-value-id={document.id}
                    data-confirm="Delete this document?"
                    class="dna-button dna-button-ghost"
                  >
                    Delete
                  </button>
                </div>

                <%= if document.last_error do %>
                  <p class="mt-3 text-sm text-[color:var(--danger)]">{document.last_error}</p>
                <% end %>
              </article>
            <% end %>
          </div>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
