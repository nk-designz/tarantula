defmodule DiscourseAppWeb.ProjectsLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.Projects

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Projects.subscribe_projects()
    end

    {:ok,
     socket
     |> assign(:projects, Projects.list_projects())
     |> assign(:selected_project, nil)
     |> assign(:project_form, to_form(%{"name" => "", "description" => ""}, as: :project))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    selected = Projects.get_project!(id)

    form_params = %{
      "name" => selected.name || "",
      "description" => selected.description || ""
    }

    {:noreply,
     socket
     |> assign(:selected_project, selected)
     |> assign(:project_form, to_form(form_params, as: :project))
     |> assign(:projects, Projects.list_projects())}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:selected_project, nil)
     |> assign(:project_form, to_form(%{"name" => "", "description" => ""}, as: :project))
     |> assign(:projects, Projects.list_projects())}
  end

  @impl true
  def handle_event("create_project", %{"project" => params}, socket) do
    case Projects.create_project(params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created")
         |> push_navigate(to: ~p"/projects/#{project.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :project_form, to_form(changeset, as: :project))}
    end
  end

  @impl true
  def handle_event(
        "update_project",
      %{"project" => _params},
        %{assigns: %{selected_project: nil}} = socket
      ) do
    {:noreply, put_flash(socket, :error, "Select a project first")}
  end

  @impl true
  def handle_event("update_project", %{"project" => params}, socket) do
    case Projects.update_project(socket.assigns.selected_project, params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated")
         |> push_navigate(to: ~p"/projects/#{project.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :project_form, to_form(changeset, as: :project))}
    end
  end

  @impl true
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Projects.get_project!(id)

    case Projects.delete_project(project) do
      {:ok, _} ->
        next_path =
          if socket.assigns.selected_project &&
               to_string(socket.assigns.selected_project.id) == id do
            ~p"/projects"
          else
            socket.assigns.live_action |> destination_for_action(socket.assigns.selected_project)
          end

        {:noreply,
         socket
         |> put_flash(:info, "Project deleted")
         |> push_navigate(to: next_path)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete project")}
    end
  end

  @impl true
  def handle_info(:projects_updated, socket) do
    {:noreply, assign(socket, :projects, Projects.list_projects())}
  end

  @impl true
  def handle_info({:projects_updated, _project_id}, socket) do
    {:noreply, assign(socket, :projects, Projects.list_projects())}
  end

  defp destination_for_action(:show, selected_project) when not is_nil(selected_project),
    do: ~p"/projects/#{selected_project.id}"

  defp destination_for_action(_action, _selected_project), do: ~p"/projects"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 class="text-4xl font-semibold tracking-[-0.03em]">Projects</h1>
          <p class="mt-1 text-sm text-[color:var(--text-muted)]">
            Create, modify, delete, and inspect projects.
          </p>
        </div>
        <.link navigate={~p"/"} class="dna-button dna-button-secondary">Back to Dashboard</.link>
      </div>

      <div class="mt-6 grid grid-cols-1 gap-6 xl:grid-cols-[360px_minmax(0,1fr)]">
        <section class="surface-panel rounded-3xl p-5">
          <h2 class="text-xl font-semibold">
            {if @selected_project, do: "Edit project", else: "Create project"}
          </h2>

          <.form
            for={@project_form}
            id="project-form"
            phx-submit={if @selected_project, do: "update_project", else: "create_project"}
            class="mt-4"
          >
            <.input
              field={@project_form[:name]}
              type="text"
              label="Name"
              placeholder="Energy Transition Hearing"
            />
            <.input
              field={@project_form[:description]}
              type="textarea"
              label="Description"
              placeholder="What corpus belongs in this project?"
            />

            <button type="submit" class="dna-button dna-button-primary mt-3 w-full">
              {if @selected_project, do: "Save changes", else: "Create project"}
            </button>
          </.form>
        </section>

        <section class="surface-panel rounded-3xl p-5">
          <h2 class="text-xl font-semibold">Project list</h2>

          <div class="project-rail mt-4 max-h-[70vh] space-y-3 overflow-y-auto pr-2">
            <%= if @projects == [] do %>
              <div
                class="rounded-2xl border border-dashed px-4 py-8 text-sm text-[color:var(--text-muted)]"
                style="border-color: var(--line);"
              >
                No projects created yet.
              </div>
            <% end %>

            <%= for project <- @projects do %>
              <article
                class="rounded-2xl border px-4 py-4"
                style="border-color: var(--line); background: var(--surface-strong);"
              >
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 class="text-lg font-semibold">{project.name}</h3>
                    <p class="text-sm text-[color:var(--text-muted)]">{project.current_step}</p>
                  </div>

                  <span class="dna-badge">{project.status}</span>
                </div>

                <p class="mt-3 text-sm text-[color:var(--text-muted)]">
                  {project.description || "No description"}
                </p>

                <div class="mt-4 flex flex-wrap gap-2">
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
                    navigate={~p"/projects/#{project.id}/graph"}
                    class="dna-button dna-button-secondary"
                  >
                    Graph
                  </.link>
                  <button
                    type="button"
                    phx-click="delete_project"
                    phx-value-id={project.id}
                    data-confirm="Delete this project and all related data?"
                    class="dna-button dna-button-ghost"
                  >
                    Delete
                  </button>
                </div>
              </article>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
