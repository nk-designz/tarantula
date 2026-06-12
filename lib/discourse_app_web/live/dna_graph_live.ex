defmodule DiscourseAppWeb.DnaGraphLive do
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
      send(self(), :push_graph)
    end

    {:noreply, assign(socket, :project, project)}
  end

  @impl true
  def handle_info(:push_graph, socket) do
    {:noreply, maybe_push_graph(socket)}
  end

  @impl true
  def handle_info({:project_updated, _project_id}, socket) do
    socket = assign(socket, :project, Projects.get_project!(socket.assigns.project.id))
    {:noreply, maybe_push_graph(socket)}
  end

  defp maybe_push_graph(%{assigns: %{project: nil}} = socket), do: socket

  defp maybe_push_graph(socket) do
    push_event(socket, "render_network", Projects.network_snapshot(socket.assigns.project))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <%= if @project do %>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 class="text-4xl font-semibold tracking-[-0.03em]">DNA Graph</h1>
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
              navigate={~p"/projects/#{@project.id}/documents"}
              class="dna-button dna-button-secondary"
            >
              Documents
            </.link>
            <a href={~p"/projects/#{@project.id}/graph/export"} class="dna-button dna-button-primary">
              Export JSON
            </a>
          </div>
        </div>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <h2 class="text-2xl font-semibold">Graph view</h2>
          <p class="mt-1 text-sm text-[color:var(--text-muted)]">
            Converged actor-concept edges with stance polarity and weighting.
          </p>

          <div
            id="network-container"
            phx-hook="DiscourseNetwork"
            phx-update="ignore"
            class="ambient-grid mt-4 h-[560px] rounded-[1.5rem]"
          >
          </div>
        </section>

        <section class="surface-panel mt-6 rounded-3xl p-6">
          <h2 class="text-2xl font-semibold">Latest references</h2>

          <div class="mt-4 space-y-3">
            <%= if @project.stances == [] do %>
              <div
                class="rounded-2xl border border-dashed px-4 py-8 text-sm text-[color:var(--text-muted)]"
                style="border-color: var(--line);"
              >
                No stance evidence yet.
              </div>
            <% end %>

            <%= for stance <- Enum.take(@project.stances, 15) do %>
              <article
                class="rounded-2xl border px-4 py-4"
                style="border-color: var(--line); background: var(--surface-strong);"
              >
                <div class="flex flex-wrap items-center gap-2 text-sm">
                  <span class="font-semibold">{stance.actor_name}</span>
                  <span class="dna-badge">{stance.stance}</span>
                  <span>on</span>
                  <span class="font-medium">{stance.concept_name}</span>
                </div>
                <p :if={stance.excerpt} class="mt-3 text-sm leading-7 text-[color:var(--text-muted)]">
                  {stance.excerpt}
                </p>
              </article>
            <% end %>
          </div>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
