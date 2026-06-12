defmodule DiscourseAppWeb.DashboardLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.Projects

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Projects.subscribe_projects()
    end

    {:ok, refresh(socket)}
  end

  @impl true
  def handle_info(:projects_updated, socket) do
    {:noreply, refresh(socket)}
  end

  @impl true
  def handle_info({:projects_updated, _project_id}, socket) do
    {:noreply, refresh(socket)}
  end

  defp refresh(socket) do
    projects = Projects.list_projects()

    detailed_projects =
      projects
      |> Enum.take(8)
      |> Enum.map(&Projects.get_project!(&1.id))

    totals = %{
      projects: length(projects),
      documents:
        Enum.reduce(detailed_projects, 0, fn project, acc -> acc + length(project.documents) end),
      stances:
        Enum.reduce(detailed_projects, 0, fn project, acc -> acc + length(project.stances) end)
    }

    socket
    |> assign(:projects, detailed_projects)
    |> assign(:totals, totals)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}} nav_section={:dashboard}>
      <section class="surface-panel-strong rounded-[1.9rem] p-6 md:p-8">
        <div class="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-4">
            <div class="dna-badge">Dashboard</div>
            <h1 class="max-w-3xl text-4xl font-semibold tracking-[-0.04em] sm:text-5xl">
              Discourse program status at a glance.
            </h1>
            <p class="max-w-2xl text-sm leading-7 text-[color:var(--text-muted)] sm:text-base">
              Move from project setup to document ingestion and graph export using dedicated views.
            </p>
          </div>

          <div class="grid grid-cols-3 gap-3 text-center text-sm sm:min-w-[26rem]">
            <div
              class="rounded-2xl border p-4"
              style="border-color: var(--line); background: var(--surface-strong);"
            >
              <div class="text-xs uppercase tracking-[0.15em] text-[color:var(--text-muted)]">
                Projects
              </div>
              <div class="mt-2 text-2xl font-semibold">{@totals.projects}</div>
            </div>
            <div
              class="rounded-2xl border p-4"
              style="border-color: var(--line); background: var(--surface-strong);"
            >
              <div class="text-xs uppercase tracking-[0.15em] text-[color:var(--text-muted)]">
                Documents
              </div>
              <div class="mt-2 text-2xl font-semibold">{@totals.documents}</div>
            </div>
            <div
              class="rounded-2xl border p-4"
              style="border-color: var(--line); background: var(--surface-strong);"
            >
              <div class="text-xs uppercase tracking-[0.15em] text-[color:var(--text-muted)]">
                Stances
              </div>
              <div class="mt-2 text-2xl font-semibold">{@totals.stances}</div>
            </div>
          </div>
        </div>
      </section>

      <section class="mt-6 grid grid-cols-1 gap-6 xl:grid-cols-3">
        <.link
          navigate={~p"/projects"}
          class="surface-panel rounded-3xl p-6 transition hover:translate-y-[-2px]"
        >
          <div class="dna-badge">1</div>
          <h2 class="mt-4 text-2xl font-semibold tracking-[-0.02em]">Projects</h2>
          <p class="mt-2 text-sm leading-7 text-[color:var(--text-muted)]">
            Create, edit, delete, and inspect project metadata.
          </p>
        </.link>

        <%= if List.first(@projects) do %>
          <.link
            navigate={~p"/projects/#{List.first(@projects).id}/documents"}
            class="surface-panel rounded-3xl p-6 transition hover:translate-y-[-2px]"
          >
            <div class="dna-badge">2</div>
            <h2 class="mt-4 text-2xl font-semibold tracking-[-0.02em]">Documents</h2>
            <p class="mt-2 text-sm leading-7 text-[color:var(--text-muted)]">
              Upload, remove, inspect status, and trigger analysis runs.
            </p>
          </.link>

          <.link
            navigate={~p"/projects/#{List.first(@projects).id}/graph"}
            class="surface-panel rounded-3xl p-6 transition hover:translate-y-[-2px]"
          >
            <div class="dna-badge">3</div>
            <h2 class="mt-4 text-2xl font-semibold tracking-[-0.02em]">DNA Graph</h2>
            <p class="mt-2 text-sm leading-7 text-[color:var(--text-muted)]">
              View converged actor-concept graphs and export snapshots.
            </p>
          </.link>
        <% else %>
          <div class="surface-panel rounded-3xl p-6 xl:col-span-2">
            <h2 class="text-2xl font-semibold tracking-[-0.02em]">No projects yet</h2>
            <p class="mt-2 text-sm leading-7 text-[color:var(--text-muted)]">
              Open the Projects page to create your first workspace.
            </p>
            <.link navigate={~p"/projects"} class="dna-button dna-button-primary mt-4">
              Open Projects
            </.link>
          </div>
        <% end %>
      </section>

      <section class="surface-panel mt-6 rounded-3xl p-6">
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-semibold tracking-[-0.02em]">Recent projects</h2>
          <.link navigate={~p"/projects"} class="dna-button dna-button-secondary">Manage all</.link>
        </div>

        <div class="mt-4 space-y-3">
          <%= if @projects == [] do %>
            <div
              class="rounded-2xl border border-dashed px-4 py-8 text-sm text-[color:var(--text-muted)]"
              style="border-color: var(--line);"
            >
              No projects to show.
            </div>
          <% end %>

          <%= for project <- @projects do %>
            <div
              class="rounded-2xl border px-4 py-4"
              style="border-color: var(--line); background: var(--surface-strong);"
            >
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h3 class="text-lg font-semibold">{project.name}</h3>
                  <p class="text-sm text-[color:var(--text-muted)]">{project.current_step}</p>
                </div>

                <div class="flex flex-wrap gap-2">
                  <.link
                    navigate={~p"/projects/#{project.id}"}
                    class="dna-button dna-button-secondary"
                  >
                    View
                  </.link>
                  <.link
                    navigate={~p"/projects/#{project.id}/documents"}
                    class="dna-button dna-button-secondary"
                  >
                    Documents
                  </.link>
                  <.link
                    navigate={~p"/projects/#{project.id}/actors"}
                    class="dna-button dna-button-secondary"
                  >
                    Actors
                  </.link>
                  <.link
                    navigate={~p"/projects/#{project.id}/concepts"}
                    class="dna-button dna-button-secondary"
                  >
                    Concepts
                  </.link>
                  <.link
                    navigate={~p"/projects/#{project.id}/graph"}
                    class="dna-button dna-button-secondary"
                  >
                    Graph
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
