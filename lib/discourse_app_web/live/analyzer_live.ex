defmodule DiscourseAppWeb.AnalyzerLive do
  use DiscourseAppWeb, :live_view

  alias DiscourseApp.Projects

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Projects.subscribe_projects()
    end

    projects = Projects.list_projects()
    selected_project = List.first(projects) && Projects.get_project!(List.first(projects).id)

    socket =
      socket
      |> allow_upload(:documents,
        accept: Projects.supported_extensions(),
        max_entries: 10,
        max_file_size: 20_000_000
      )
      |> assign(:projects, projects)
      |> assign(:selected_project, selected_project)
      |> assign(:project_form, to_form(%{"name" => "", "description" => ""}, as: :project))
      |> maybe_subscribe_selected_project(selected_project)
      |> maybe_push_network(selected_project)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={%{}}
      current_project={@selected_project}
      nav_section={:analyzer}
    >
      <section class="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-[0_24px_80px_rgba(148,163,184,0.18)] backdrop-blur xl:p-8">
        <div class="flex flex-col gap-6 xl:flex-row xl:items-end xl:justify-between">
          <div class="max-w-3xl space-y-4">
            <div class="inline-flex items-center gap-2 rounded-full bg-orange-100 px-3 py-1 text-xs font-semibold uppercase tracking-[0.24em] text-orange-700">
              <span class="h-2 w-2 rounded-full bg-orange-500"></span> Discourse Network Platform
            </div>
            <div class="space-y-3">
              <h1 class="max-w-4xl text-4xl font-semibold tracking-[-0.04em] text-slate-950 sm:text-5xl">
                Project-backed discourse maps with uploaded evidence, converged actors, and live job progress.
              </h1>
              <p class="max-w-2xl text-sm leading-7 text-slate-600 sm:text-base">
                Create projects, upload markdown, text, or PDF documents, run background analysis, and inspect the converged actor-concept network with stance references anchored to document lines.
              </p>
            </div>
          </div>

          <div class="grid w-full max-w-xl grid-cols-3 gap-3 text-left text-sm xl:w-auto xl:min-w-[28rem]">
            <div class="rounded-2xl border border-orange-200 bg-orange-50 px-4 py-3">
              <div class="text-xs uppercase tracking-[0.2em] text-orange-700">Projects</div>
              <div class="mt-2 text-2xl font-semibold text-slate-900">{length(@projects)}</div>
            </div>
            <div class="rounded-2xl border border-teal-200 bg-teal-50 px-4 py-3">
              <div class="text-xs uppercase tracking-[0.2em] text-teal-700">Documents</div>
              <div class="mt-2 text-2xl font-semibold text-slate-900">
                {documents_count(@selected_project)}
              </div>
            </div>
            <div class="rounded-2xl border border-sky-200 bg-sky-50 px-4 py-3">
              <div class="text-xs uppercase tracking-[0.2em] text-sky-700">Stances</div>
              <div class="mt-2 text-2xl font-semibold text-slate-900">
                {stances_count(@selected_project)}
              </div>
            </div>
          </div>
        </div>
      </section>

      <div class="mt-6 grid grid-cols-1 gap-6 xl:grid-cols-[340px_minmax(0,1fr)]">
        <aside class="space-y-6">
          <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
            <div class="mb-4 space-y-1">
              <h2 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">Create project</h2>
              <p class="text-sm text-slate-500">
                Each project keeps its own actor, concept, document, and stance evidence graph in SQLite.
              </p>
            </div>

            <.form for={@project_form} id="project-form" phx-submit="create_project" class="space-y-3">
              <.input
                field={@project_form[:name]}
                type="text"
                label="Project name"
                placeholder="Energy Transition Hearing"
              />
              <.input
                field={@project_form[:description]}
                type="textarea"
                label="Brief"
                placeholder="What policy field or discourse corpus belongs in this project?"
              />

              <button
                type="submit"
                class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                Add project
              </button>
            </.form>
          </section>

          <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
            <div class="mb-4 flex items-center justify-between">
              <div>
                <h2 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">Projects</h2>
                <p class="text-sm text-slate-500">Switch the active graph context.</p>
              </div>
            </div>

            <div class="space-y-3">
              <%= if @projects == [] do %>
                <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-500">
                  No projects yet. Create one to start ingesting documents.
                </div>
              <% end %>

              <%= for project <- @projects do %>
                <button
                  id={"project-#{project.id}"}
                  type="button"
                  phx-click="select_project"
                  phx-value-id={project.id}
                  class={[
                    "w-full rounded-2xl border px-4 py-3 text-left transition",
                    if(active_project?(@selected_project, project),
                      do: "border-slate-950 bg-slate-950 text-white shadow-lg shadow-slate-950/10",
                      else: "border-slate-200 bg-white hover:border-orange-300 hover:bg-orange-50"
                    )
                  ]}
                >
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <div class="font-semibold tracking-[-0.02em]">{project.name}</div>
                      <div class={
                        if(active_project?(@selected_project, project),
                          do: "mt-1 text-xs text-slate-300",
                          else: "mt-1 text-xs text-slate-500"
                        )
                      }>
                        {project.current_step}
                      </div>
                    </div>
                    <span class={[
                      "rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] ring-1",
                      if(active_project?(@selected_project, project),
                        do: "bg-white/10 text-white ring-white/20",
                        else: Projects.status_tone(project.status)
                      )
                    ]}>
                      {project.status}
                    </span>
                  </div>
                </button>
              <% end %>
            </div>
          </section>
        </aside>

        <section>
          <%= if @selected_project do %>
            <div class="space-y-6">
              <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-6 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                <div class="flex flex-col gap-6 2xl:flex-row 2xl:items-start 2xl:justify-between">
                  <div class="space-y-4">
                    <div class="flex flex-wrap items-center gap-3">
                      <h2 class="text-3xl font-semibold tracking-[-0.04em] text-slate-950">
                        {@selected_project.name}
                      </h2>
                      <span class={[
                        "rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] ring-1",
                        Projects.status_tone(@selected_project.status)
                      ]}>
                        {@selected_project.status}
                      </span>
                    </div>

                    <p class="max-w-3xl text-sm leading-7 text-slate-600">
                      {project_description(@selected_project)}
                    </p>

                    <div class="space-y-3">
                      <div class="flex flex-wrap items-center justify-between gap-3 text-sm">
                        <div>
                          <div class="font-semibold text-slate-800">
                            {@selected_project.current_step}
                          </div>
                          <div class="text-slate-500">
                            ETA: {Projects.format_eta(@selected_project.eta_seconds)}
                          </div>
                        </div>
                        <div class="text-right">
                          <div class="text-xs uppercase tracking-[0.2em] text-slate-400">
                            Progress
                          </div>
                          <div class="text-2xl font-semibold text-slate-950">
                            {@selected_project.progress}%
                          </div>
                        </div>
                      </div>

                      <div class="h-3 overflow-hidden rounded-full bg-slate-200">
                        <div
                          class="h-full rounded-full bg-[linear-gradient(90deg,#0f766e_0%,#f97316_100%)] transition-all duration-500"
                          style={"width: #{@selected_project.progress}%"}
                        >
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="flex w-full max-w-md flex-col gap-3">
                    <button
                      id="analyze-project"
                      type="button"
                      phx-click="analyze_project"
                      disabled={project_busy?(@selected_project) or @selected_project.documents == []}
                      class="inline-flex items-center justify-center rounded-2xl bg-orange-500 px-4 py-3 text-sm font-semibold text-white transition hover:bg-orange-600 disabled:cursor-not-allowed disabled:bg-orange-300"
                    >
                      {if project_busy?(@selected_project),
                        do: "Analysis running",
                        else: "Run background analysis"}
                    </button>

                    <div class="grid grid-cols-3 gap-3 text-sm">
                      <div class="rounded-2xl border border-slate-200 bg-slate-50 px-3 py-3">
                        <div class="text-xs uppercase tracking-[0.18em] text-slate-500">Actors</div>
                        <div class="mt-1 text-xl font-semibold text-slate-900">
                          {length(@selected_project.actors)}
                        </div>
                      </div>
                      <div class="rounded-2xl border border-slate-200 bg-slate-50 px-3 py-3">
                        <div class="text-xs uppercase tracking-[0.18em] text-slate-500">Concepts</div>
                        <div class="mt-1 text-xl font-semibold text-slate-900">
                          {length(@selected_project.concepts)}
                        </div>
                      </div>
                      <div class="rounded-2xl border border-slate-200 bg-slate-50 px-3 py-3">
                        <div class="text-xs uppercase tracking-[0.18em] text-slate-500">Docs</div>
                        <div class="mt-1 text-xl font-semibold text-slate-900">
                          {length(@selected_project.documents)}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <%= if @selected_project.last_error do %>
                  <div class="mt-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
                    {@selected_project.last_error}
                  </div>
                <% end %>
              </section>

              <div class="grid grid-cols-1 gap-6 2xl:grid-cols-[420px_minmax(0,1fr)]">
                <section class="space-y-6">
                  <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                    <div class="mb-4 space-y-1">
                      <h3 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">
                        Upload documents
                      </h3>
                      <p class="text-sm text-slate-500">
                        Supported formats: markdown, plain text, and PDF.
                      </p>
                    </div>

                    <.form
                      for={%{}}
                      id="document-upload-form"
                      phx-submit="save_documents"
                      class="space-y-4"
                    >
                      <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-4">
                        <label
                          for={@uploads.documents.ref}
                          class="flex cursor-pointer flex-col items-center justify-center gap-3 rounded-2xl border border-white bg-white px-4 py-8 text-center shadow-sm transition hover:border-orange-300 hover:bg-orange-50"
                        >
                          <.icon name="hero-arrow-up-tray" class="size-8 text-orange-500" />
                          <div class="space-y-1">
                            <div class="text-sm font-semibold text-slate-900">
                              Drop files here or browse from disk
                            </div>
                            <div class="text-xs text-slate-500">
                              Each file is stored under this project and analyzed as a background job step.
                            </div>
                          </div>
                          <.live_file_input upload={@uploads.documents} class="hidden" />
                        </label>
                      </div>

                      <%= if @uploads.documents.entries != [] do %>
                        <div class="space-y-2">
                          <%= for entry <- @uploads.documents.entries do %>
                            <div class="rounded-2xl border border-slate-200 bg-white px-3 py-3 text-sm">
                              <div class="flex items-center justify-between gap-3">
                                <div class="font-medium text-slate-900">{entry.client_name}</div>
                                <div class="text-xs text-slate-500">{entry.progress}%</div>
                              </div>
                              <div class="mt-2 h-2 overflow-hidden rounded-full bg-slate-200">
                                <div
                                  class="h-full rounded-full bg-sky-500 transition-all"
                                  style={"width: #{entry.progress}%"}
                                >
                                </div>
                              </div>
                              <%= for error <- upload_errors(@uploads.documents, entry) do %>
                                <div class="mt-2 text-xs text-rose-600">
                                  {upload_error_to_string(error)}
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>

                      <button
                        type="submit"
                        class="inline-flex w-full items-center justify-center rounded-2xl border border-slate-950 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-slate-950 hover:text-white"
                      >
                        Save uploaded documents
                      </button>
                    </.form>
                  </section>

                  <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                    <div class="mb-4 space-y-1">
                      <h3 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">
                        Documents
                      </h3>
                      <p class="text-sm text-slate-500">
                        Origins, extraction state, and analysis status per file.
                      </p>
                    </div>

                    <div class="space-y-3">
                      <%= if @selected_project.documents == [] do %>
                        <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-500">
                          Upload one or more documents to seed the project graph.
                        </div>
                      <% end %>

                      <%= for document <- @selected_project.documents do %>
                        <div class="rounded-2xl border border-slate-200 bg-white px-4 py-4">
                          <div class="flex items-start justify-between gap-3">
                            <div>
                              <div class="font-semibold text-slate-950">
                                {document.original_filename}
                              </div>
                              <div class="mt-1 text-xs text-slate-500">{document.content_type}</div>
                            </div>
                            <span class={[
                              "rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] ring-1",
                              document_status_tone(document.status)
                            ]}>
                              {document.status}
                            </span>
                          </div>

                          <div class="mt-3 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                            <a
                              href={"/" <> document.storage_path}
                              class="font-medium text-slate-700 underline decoration-slate-300 underline-offset-4 transition hover:text-orange-600"
                            >
                              Open source file
                            </a>
                            <span>{document_line_count(document)} lines extracted</span>
                          </div>

                          <%= if document.last_error do %>
                            <div class="mt-3 rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-xs text-rose-700">
                              {document.last_error}
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </section>
                </section>

                <section class="space-y-6">
                  <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                    <div class="mb-4 flex flex-col gap-3 border-b border-slate-200 pb-4 sm:flex-row sm:items-center sm:justify-between">
                      <div>
                        <h3 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">
                          Converged network
                        </h3>
                        <p class="text-sm text-slate-500">
                          Actor and concept nodes are rebuilt after each analysis step.
                        </p>
                      </div>

                      <div class="flex flex-wrap gap-3 text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                        <span class="flex items-center gap-2">
                          <span class="h-2.5 w-2.5 rounded-full bg-teal-700"></span>Actor
                        </span>
                        <span class="flex items-center gap-2">
                          <span class="h-2.5 w-2.5 rounded-full bg-orange-600"></span>Concept
                        </span>
                        <span class="flex items-center gap-2">
                          <span class="h-1 w-6 rounded bg-teal-700"></span>Pro
                        </span>
                        <span class="flex items-center gap-2">
                          <span class="h-1 w-6 rounded bg-red-700"></span>Contra
                        </span>
                      </div>
                    </div>

                    <div
                      id="network-container"
                      phx-hook="DiscourseNetwork"
                      phx-update="ignore"
                      class="h-[460px] rounded-[1.5rem] bg-[linear-gradient(180deg,#fff7ed_0%,#ffffff_100%)]"
                    >
                    </div>
                  </section>

                  <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
                    <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                      <div class="mb-4 space-y-1">
                        <h3 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">
                          Actor registry
                        </h3>
                        <p class="text-sm text-slate-500">
                          Per-project actors with occurrence rollups across uploaded documents.
                        </p>
                      </div>

                      <div class="space-y-3">
                        <%= for actor <- Enum.take(@selected_project.actors, 8) do %>
                          <div class="flex items-center justify-between rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm">
                            <div>
                              <div class="font-semibold text-slate-900">{actor.name}</div>
                              <div class="text-xs text-slate-500">
                                {actor.document_count} documents
                              </div>
                            </div>
                            <div class="text-right">
                              <div class="text-xs uppercase tracking-[0.18em] text-slate-400">
                                Occurrences
                              </div>
                              <div class="text-lg font-semibold text-slate-900">
                                {actor.occurrences_count}
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </section>

                    <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                      <div class="mb-4 space-y-1">
                        <h3 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">
                          Concept registry
                        </h3>
                        <p class="text-sm text-slate-500">
                          Converged concepts tracked by their cross-document footprint.
                        </p>
                      </div>

                      <div class="space-y-3">
                        <%= for concept <- Enum.take(@selected_project.concepts, 8) do %>
                          <div class="flex items-center justify-between rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm">
                            <div>
                              <div class="font-semibold text-slate-900">{concept.name}</div>
                              <div class="text-xs text-slate-500">
                                {concept.document_count} documents
                              </div>
                            </div>
                            <div class="text-right">
                              <div class="text-xs uppercase tracking-[0.18em] text-slate-400">
                                Occurrences
                              </div>
                              <div class="text-lg font-semibold text-slate-900">
                                {concept.occurrences_count}
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </section>
                  </div>

                  <section class="rounded-[1.75rem] border border-slate-200/80 bg-white/85 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.08)] backdrop-blur">
                    <div class="mb-4 space-y-1">
                      <h3 class="text-lg font-semibold tracking-[-0.02em] text-slate-950">
                        Stance references
                      </h3>
                      <p class="text-sm text-slate-500">
                        Evidence snippets and their anchored line ranges in the source document.
                      </p>
                    </div>

                    <div class="space-y-3">
                      <%= if @selected_project.stances == [] do %>
                        <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-4 py-6 text-sm text-slate-500">
                          References appear here once the first background analysis finishes.
                        </div>
                      <% end %>

                      <%= for stance <- Enum.take(@selected_project.stances, 12) do %>
                        <article class="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4">
                          <div class="flex flex-wrap items-center gap-2 text-sm">
                            <span class="font-semibold text-slate-950">{stance.actor_name}</span>
                            <span class="rounded-full bg-slate-200 px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-700">
                              {stance.stance}
                            </span>
                            <span class="text-slate-400">on</span>
                            <span class="font-medium text-slate-800">{stance.concept_name}</span>
                          </div>

                          <%= if stance.excerpt do %>
                            <blockquote class="mt-3 border-l-2 border-orange-300 pl-4 text-sm leading-7 text-slate-600">
                              {stance.excerpt}
                            </blockquote>
                          <% end %>

                          <div class="mt-3 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                            <span>{stance.document && stance.document.original_filename}</span>
                            <%= if stance.line_start do %>
                              <span>
                                Lines {stance.line_start}-{stance.line_end || stance.line_start}
                              </span>
                            <% end %>
                          </div>
                        </article>
                      <% end %>
                    </div>
                  </section>
                </section>
              </div>
            </div>
          <% else %>
            <section class="rounded-[1.75rem] border border-dashed border-slate-300 bg-white/75 px-6 py-16 text-center text-slate-500 shadow-[0_18px_50px_rgba(15,23,42,0.05)]">
              Create your first project to start uploading documents and building a discourse network.
            </section>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("create_project", %{"project" => params}, socket) do
    case Projects.create_project(params) do
      {:ok, project} ->
        selected_project = Projects.get_project!(project.id)

        {:noreply,
         socket
         |> put_flash(:info, "Project created")
         |> assign(:project_form, to_form(%{"name" => "", "description" => ""}, as: :project))
         |> assign(:projects, Projects.list_projects())
         |> assign(:selected_project, selected_project)
         |> maybe_subscribe_selected_project(selected_project)
         |> maybe_push_network(selected_project)}

      {:error, changeset} ->
        {:noreply, assign(socket, :project_form, to_form(changeset, as: :project))}
    end
  end

  @impl true
  def handle_event("select_project", %{"id" => id}, socket) do
    selected_project = Projects.get_project!(id)

    {:noreply,
     socket
     |> assign(:selected_project, selected_project)
     |> maybe_subscribe_selected_project(selected_project)
     |> maybe_push_network(selected_project)}
  end

  @impl true
  def handle_event("save_documents", _params, socket) do
    case socket.assigns.selected_project do
      nil ->
        {:noreply, put_flash(socket, :error, "Create or select a project first")}

      project ->
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
        selected_project = Projects.get_project!(project.id)

        socket =
          socket
          |> assign(:projects, Projects.list_projects())
          |> assign(:selected_project, selected_project)
          |> maybe_push_network(selected_project)

        if had_error? do
          {:noreply, put_flash(socket, :error, "One or more uploads failed")}
        else
          {:noreply, put_flash(socket, :info, "Documents saved to project")}
        end
    end
  end

  @impl true
  def handle_event("analyze_project", _params, socket) do
    case socket.assigns.selected_project do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a project first")}

      project ->
        case Projects.enqueue_analysis(project) do
          {:ok, _project} ->
            {:noreply, put_flash(socket, :info, "Background analysis started")}

          {:error, :no_documents} ->
            {:noreply, put_flash(socket, :error, "Upload at least one document before analyzing")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, inspect(reason))}
        end
    end
  end

  @impl true
  def handle_info(:projects_updated, socket) do
    {:noreply, refresh_socket(socket)}
  end

  @impl true
  def handle_info({:projects_updated, _project_id}, socket) do
    {:noreply, refresh_socket(socket)}
  end

  @impl true
  def handle_info({:project_updated, _project_id}, socket) do
    {:noreply, refresh_socket(socket)}
  end

  defp refresh_socket(socket) do
    selected_project =
      case socket.assigns.selected_project do
        nil -> nil
        project -> Projects.get_project(project.id)
      end

    socket
    |> assign(:projects, Projects.list_projects())
    |> assign(:selected_project, selected_project)
    |> maybe_push_network(selected_project)
  end

  defp maybe_subscribe_selected_project(socket, nil), do: socket

  defp maybe_subscribe_selected_project(socket, project) do
    if connected?(socket) do
      Projects.subscribe_project(project.id)
    end

    socket
  end

  defp maybe_push_network(socket, nil) do
    if connected?(socket),
      do: push_event(socket, "render_network", %{"nodes" => [], "links" => []}),
      else: socket
  end

  defp maybe_push_network(socket, project) do
    if connected?(socket),
      do: push_event(socket, "render_network", Projects.network_snapshot(project)),
      else: socket
  end

  defp active_project?(nil, _project), do: false
  defp active_project?(selected_project, project), do: selected_project.id == project.id

  defp project_busy?(project), do: project.status in ["queued", "processing"]

  defp project_description(project),
    do:
      project.description ||
        "No project brief yet. Use the brief to capture corpus scope, stakeholders, or policy domain."

  defp documents_count(nil), do: 0
  defp documents_count(project), do: length(project.documents)
  defp stances_count(nil), do: 0
  defp stances_count(project), do: length(project.stances)

  defp document_status_tone("analyzed"), do: "bg-emerald-100 text-emerald-700 ring-emerald-200"
  defp document_status_tone("extracting"), do: "bg-sky-100 text-sky-700 ring-sky-200"
  defp document_status_tone("failed"), do: "bg-rose-100 text-rose-700 ring-rose-200"
  defp document_status_tone(_), do: "bg-slate-100 text-slate-700 ring-slate-200"

  defp document_line_count(document) do
    (document.metadata && document.metadata["line_count"]) || 0
  end

  defp upload_error_to_string(:too_large), do: "File is too large"
  defp upload_error_to_string(:not_accepted), do: "Unsupported file type"
  defp upload_error_to_string(:too_many_files), do: "Too many files selected"
  defp upload_error_to_string(other), do: inspect(other)
end
