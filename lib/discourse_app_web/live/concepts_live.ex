defmodule DiscourseAppWeb.ConceptsLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.Projects

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :project, nil)}
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
  def handle_info({:project_updated, _project_id}, socket) do
    {:noreply, assign(socket, :project, Projects.get_project!(socket.assigns.project.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <%= if @project do %>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 class="text-4xl font-semibold tracking-[-0.03em]">Concepts</h1>
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
              navigate={~p"/projects/#{@project.id}/actors"}
              class="dna-button dna-button-secondary"
            >
              Actors
            </.link>
            <.link
              navigate={~p"/projects/#{@project.id}/documents"}
              class="dna-button dna-button-secondary"
            >
              Documents
            </.link>
            <.link
              navigate={~p"/projects/#{@project.id}/graph"}
              class="dna-button dna-button-secondary"
            >
              DNA Graph
            </.link>
          </div>
        </div>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <h2 class="text-2xl font-semibold">Concept registry</h2>
          <p class="mt-1 text-sm text-[color:var(--text-muted)]">
            Converged concepts and their occurrence footprint across project documents.
          </p>

          <div class="mt-4 space-y-3">
            <%= if @project.concepts == [] do %>
              <div
                class="rounded-2xl border border-dashed px-4 py-8 text-sm text-[color:var(--text-muted)]"
                style="border-color: var(--line);"
              >
                No concepts extracted yet. Run analysis from the Documents page.
              </div>
            <% end %>

            <%= for concept <- @project.concepts do %>
              <article
                class="rounded-2xl border px-4 py-4"
                style="border-color: var(--line); background: var(--surface-strong);"
              >
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 class="text-lg font-semibold">{concept.name}</h3>
                    <p class="text-sm text-[color:var(--text-muted)]">slug: {concept.slug}</p>
                  </div>

                  <div class="grid grid-cols-2 gap-2 text-right text-sm">
                    <div>
                      <div class="text-xs uppercase tracking-[0.12em] text-[color:var(--text-muted)]">
                        Occurrences
                      </div>
                      <div class="text-lg font-semibold">{concept.occurrences_count}</div>
                    </div>
                    <div>
                      <div class="text-xs uppercase tracking-[0.12em] text-[color:var(--text-muted)]">
                        Documents
                      </div>
                      <div class="text-lg font-semibold">{concept.document_count}</div>
                    </div>
                  </div>
                </div>
              </article>
            <% end %>
          </div>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
