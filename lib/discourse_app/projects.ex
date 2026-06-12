defmodule DiscourseApp.Projects do
  import Ecto.Query

  alias DiscourseApp.{Analyzer, Repo, TextExtractor}
  alias DiscourseApp.Projects.{Actor, Concept, Document, Project, Stance}

  @projects_topic "projects"

  def subscribe_projects do
    Phoenix.PubSub.subscribe(DiscourseApp.PubSub, @projects_topic)
  end

  def subscribe_project(project_id) do
    Phoenix.PubSub.subscribe(DiscourseApp.PubSub, project_topic(project_id))
  end

  def list_projects do
    Project
    |> order_by([project], desc: project.updated_at, desc: project.inserted_at)
    |> Repo.all()
  end

  def get_project(project_id) do
    case Repo.get(Project, project_id) do
      nil -> nil
      project -> preload_project(project)
    end
  end

  def get_project!(project_id) do
    Project
    |> Repo.get!(project_id)
    |> preload_project()
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
    |> broadcast_after_write()
  end

  def add_uploaded_document(%Project{} = project, upload) do
    destination_dir = upload_dir(project.id)
    File.mkdir_p!(destination_dir)

    safe_name = sanitize_filename(upload.client_name)

    relative_path =
      Path.join([
        "uploads",
        "projects",
        Integer.to_string(project.id),
        "documents",
        "#{Ecto.UUID.generate()}-#{safe_name}"
      ])

    absolute_path = Path.join([File.cwd!(), "priv/static", relative_path])

    File.cp!(upload.path, absolute_path)

    attrs = %{
      project_id: project.id,
      name: Path.rootname(upload.client_name),
      original_filename: upload.client_name,
      content_type: upload.client_type || MIME.from_path(upload.client_name),
      storage_path: relative_path,
      source_type: "upload",
      status: "uploaded",
      metadata: %{"size_bytes" => file_size(absolute_path)}
    }

    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
    |> broadcast_after_write()
  end

  def enqueue_analysis(%Project{} = project) do
    project = get_project!(project.id)

    cond do
      Enum.empty?(project.documents) ->
        {:error, :no_documents}

      project.status in ["queued", "processing"] ->
        {:ok, project}

      true ->
        {:ok, project} =
          project
          |> Project.analysis_changeset(%{
            status: "queued",
            current_step: "Queued for analysis",
            progress: 0,
            eta_seconds: nil,
            last_error: nil,
            started_at: DateTime.utc_now(),
            completed_at: nil
          })
          |> Repo.update()

        broadcast_project(project.id)
        broadcast_projects()

        Task.Supervisor.start_child(DiscourseApp.AnalysisTaskSupervisor, fn ->
          run_project_analysis(project.id)
        end)

        {:ok, project}
    end
  end

  def project_topic(project_id), do: "projects:#{project_id}"

  def supported_extensions, do: ~w(.md .txt .pdf)

  def status_tone("completed"), do: "bg-emerald-100 text-emerald-700 ring-emerald-200"
  def status_tone("failed"), do: "bg-rose-100 text-rose-700 ring-rose-200"
  def status_tone("processing"), do: "bg-amber-100 text-amber-800 ring-amber-200"
  def status_tone("queued"), do: "bg-sky-100 text-sky-700 ring-sky-200"
  def status_tone(_status), do: "bg-slate-100 text-slate-700 ring-slate-200"

  def format_eta(nil), do: "Pending"

  def format_eta(seconds) when seconds <= 0, do: "<1 min"

  def format_eta(seconds) do
    minutes = div(seconds, 60)
    remainder = rem(seconds, 60)

    cond do
      minutes == 0 -> "#{remainder}s"
      remainder == 0 -> "#{minutes}m"
      true -> "#{minutes}m #{remainder}s"
    end
  end

  def network_snapshot(nil), do: %{"nodes" => [], "links" => []}

  def network_snapshot(%Project{} = project) do
    project.network_snapshot || %{"nodes" => [], "links" => []}
  end

  defp run_project_analysis(project_id) do
    started_ms = System.monotonic_time(:millisecond)
    project = get_project!(project_id)
    documents = project.documents
    total_steps = max(length(documents) * 3 + 1, 1)

    reset_project_analysis!(project_id)
    update_progress!(project_id, 1, total_steps, started_ms, "Extracting documents")

    errors =
      documents
      |> Enum.with_index(1)
      |> Enum.reduce([], fn {document, index}, acc ->
        case analyze_document(project_id, document, index, total_steps, started_ms) do
          :ok -> acc
          {:error, message} -> [message | acc]
        end
      end)

    normalize_and_converge_project_network(project_id)

    final_attrs =
      if length(errors) == length(documents) do
        %{
          status: "failed",
          current_step: "Analysis failed",
          progress: 100,
          eta_seconds: 0,
          last_error: Enum.join(Enum.reverse(errors), " | "),
          completed_at: DateTime.utc_now()
        }
      else
        %{
          status: "completed",
          current_step: "Network converged",
          progress: 100,
          eta_seconds: 0,
          last_error: if(errors == [], do: nil, else: Enum.join(Enum.reverse(errors), " | ")),
          completed_at: DateTime.utc_now()
        }
      end

    Project
    |> Repo.get!(project_id)
    |> Project.analysis_changeset(final_attrs)
    |> Repo.update!()

    broadcast_project(project_id)
    broadcast_projects()
  end

  defp analyze_document(project_id, document, index, total_steps, started_ms) do
    update_document!(document.id, %{status: "extracting", last_error: nil})

    update_progress!(
      project_id,
      (index - 1) * 3 + 1,
      total_steps,
      started_ms,
      "Extracting #{document.name}"
    )

    with {:ok, text} <- TextExtractor.extract(document),
         :ok <- ensure_text_present(text),
         {:ok, statements} <- Analyzer.analyze_text(text) do
      update_document!(document.id, %{
        status: "analyzed",
        extracted_text: text,
        last_error: nil,
        metadata: %{"line_count" => line_count(text), "statement_count" => length(statements)}
      })

      persist_document_statements(project_id, document.id, text, statements)

      update_progress!(
        project_id,
        (index - 1) * 3 + 2,
        total_steps,
        started_ms,
        "Normalizing #{document.name}"
      )

      normalize_and_converge_project_network(project_id)

      update_progress!(
        project_id,
        index * 3,
        total_steps,
        started_ms,
        "Converging #{document.name}"
      )

      :ok
    else
      {:error, message} ->
        update_document!(document.id, %{status: "failed", last_error: message})
        broadcast_project(project_id)
        {:error, "#{document.original_filename}: #{message}"}
    end
  end

  defp ensure_text_present(text) do
    if String.trim(text) == "" do
      {:error, "Dokument enthaelt keinen auswertbaren Text."}
    else
      :ok
    end
  end

  defp persist_document_statements(project_id, document_id, text, statements) do
    from(stance in Stance, where: stance.document_id == ^document_id) |> Repo.delete_all()

    Enum.each(statements, fn statement ->
      reference = statement_reference(text, statement["evidence"])

      %Stance{}
      |> Stance.changeset(%{
        project_id: project_id,
        document_id: document_id,
        actor_name: statement["actor"],
        concept_name: statement["concept"],
        stance: statement["stance"],
        excerpt: reference.excerpt,
        line_start: reference.line_start,
        line_end: reference.line_end,
        metadata: %{"origin" => "ollama"}
      })
      |> Repo.insert!()
    end)
  end

  defp normalize_and_converge_project_network(project_id) do
    stances =
      Stance
      |> where([stance], stance.project_id == ^project_id)
      |> Repo.all()

    Repo.transaction(fn ->
      from(actor in Actor, where: actor.project_id == ^project_id) |> Repo.delete_all()
      from(concept in Concept, where: concept.project_id == ^project_id) |> Repo.delete_all()

      actor_lookup = rebuild_entities(project_id, stances, :actor_name, Actor)
      concept_lookup = rebuild_entities(project_id, stances, :concept_name, Concept)

      Enum.each(stances, fn stance ->
        actor_key = normalize_slug(stance.actor_name)
        concept_key = normalize_slug(stance.concept_name)

        actor = Map.fetch!(actor_lookup, actor_key)
        concept = Map.fetch!(concept_lookup, concept_key)

        stance
        |> Stance.changeset(%{
          actor_id: actor.id,
          concept_id: concept.id,
          actor_name: actor.name,
          concept_name: concept.name
        })
        |> Repo.update!()
      end)

      snapshot = build_network_snapshot(project_id)

      Project
      |> Repo.get!(project_id)
      |> Project.analysis_changeset(%{network_snapshot: snapshot})
      |> Repo.update!()
    end)

    broadcast_project(project_id)
  end

  defp rebuild_entities(project_id, stances, field, schema) do
    stances
    |> Enum.group_by(fn stance -> normalize_slug(Map.fetch!(stance, field)) end)
    |> Enum.reject(fn {slug, _group} -> slug == "unknown" end)
    |> Enum.map(fn {slug, grouped_stances} ->
      name = grouped_stances |> Enum.map(&Map.fetch!(&1, field)) |> canonical_name()

      attrs = %{
        project_id: project_id,
        name: name,
        slug: slug,
        occurrences_count: length(grouped_stances),
        document_count: grouped_stances |> Enum.map(& &1.document_id) |> Enum.uniq() |> length(),
        metadata: %{"origins" => grouped_stances |> Enum.map(& &1.document_id) |> Enum.uniq()}
      }

      entity =
        schema
        |> struct()
        |> schema.changeset(attrs)
        |> Repo.insert!()

      {slug, entity}
    end)
    |> Map.new()
  end

  defp build_network_snapshot(project_id) do
    project = get_project!(project_id)

    nodes =
      Enum.map(project.actors, fn actor ->
        %{
          id: "actor:#{actor.id}",
          label: actor.name,
          group: "actor",
          weight: actor.occurrences_count,
          documents: actor.document_count
        }
      end) ++
        Enum.map(project.concepts, fn concept ->
          %{
            id: "concept:#{concept.id}",
            label: concept.name,
            group: "concept",
            weight: concept.occurrences_count,
            documents: concept.document_count
          }
        end)

    links =
      project.stances
      |> Enum.filter(&(&1.actor_id && &1.concept_id))
      |> Enum.group_by(fn stance -> {stance.actor_id, stance.concept_id, stance.stance} end)
      |> Enum.map(fn {{actor_id, concept_id, stance_kind}, grouped_stances} ->
        %{
          source: "actor:#{actor_id}",
          target: "concept:#{concept_id}",
          stance: stance_kind,
          weight: length(grouped_stances),
          references: length(grouped_stances)
        }
      end)

    %{"nodes" => nodes, "links" => links}
  end

  defp statement_reference(_text, nil) do
    %{excerpt: nil, line_start: nil, line_end: nil}
  end

  defp statement_reference(text, excerpt) do
    normalized_text = String.downcase(text)
    normalized_excerpt = String.downcase(excerpt)

    case :binary.match(normalized_text, normalized_excerpt) do
      {position, length} ->
        prefix = binary_part(text, 0, position)
        match = binary_part(text, position, length)
        line_start = 1 + newline_count(prefix)
        line_end = line_start + newline_count(match)

        %{excerpt: excerpt, line_start: line_start, line_end: line_end}

      :nomatch ->
        %{excerpt: excerpt, line_start: nil, line_end: nil}
    end
  end

  defp newline_count(value) do
    value
    |> String.split("\n")
    |> length()
    |> Kernel.-(1)
  end

  defp update_progress!(project_id, completed_steps, total_steps, started_ms, step_name) do
    progress = (completed_steps / total_steps * 100) |> round() |> min(99)
    eta_seconds = estimate_eta_seconds(progress, started_ms)

    Project
    |> Repo.get!(project_id)
    |> Project.analysis_changeset(%{
      status: "processing",
      current_step: step_name,
      progress: progress,
      eta_seconds: eta_seconds
    })
    |> Repo.update!()

    broadcast_project(project_id)
    broadcast_projects()
  end

  defp estimate_eta_seconds(progress, _started_ms) when progress <= 0, do: nil

  defp estimate_eta_seconds(progress, started_ms) do
    elapsed_ms = System.monotonic_time(:millisecond) - started_ms
    total_estimate_ms = round(elapsed_ms / (progress / 100))
    remaining_ms = max(total_estimate_ms - elapsed_ms, 0)
    div(remaining_ms, 1_000)
  end

  defp reset_project_analysis!(project_id) do
    from(stance in Stance, where: stance.project_id == ^project_id) |> Repo.delete_all()
    from(actor in Actor, where: actor.project_id == ^project_id) |> Repo.delete_all()
    from(concept in Concept, where: concept.project_id == ^project_id) |> Repo.delete_all()

    from(document in Document, where: document.project_id == ^project_id)
    |> Repo.update_all(set: [status: "uploaded", last_error: nil, extracted_text: nil])

    Project
    |> Repo.get!(project_id)
    |> Project.analysis_changeset(%{network_snapshot: %{"nodes" => [], "links" => []}})
    |> Repo.update!()

    broadcast_project(project_id)
  end

  defp update_document!(document_id, attrs) do
    Document
    |> Repo.get!(document_id)
    |> Document.changeset(attrs)
    |> Repo.update!()
  end

  defp preload_project(project) do
    project
    |> Repo.preload(
      documents: from(document in Document, order_by: [desc: document.inserted_at]),
      actors: from(actor in Actor, order_by: [desc: actor.occurrences_count, asc: actor.name]),
      concepts:
        from(concept in Concept, order_by: [desc: concept.occurrences_count, asc: concept.name]),
      stances:
        from(stance in Stance,
          order_by: [desc: stance.inserted_at],
          preload: [:document, :actor, :concept]
        )
    )
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9._-]+/, "-")
    |> String.trim("-")
  end

  defp upload_dir(project_id) do
    Path.join([
      File.cwd!(),
      "priv/static/uploads/projects",
      Integer.to_string(project_id),
      "documents"
    ])
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.size
      {:error, _reason} -> 0
    end
  end

  defp normalize_slug(nil), do: "unknown"

  defp normalize_slug(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "unknown"
      slug -> slug
    end
  end

  defp canonical_name(names) do
    names
    |> Enum.frequencies()
    |> Enum.max_by(fn {name, count} -> {count, String.length(name)} end, fn -> {"Unknown", 0} end)
    |> elem(0)
  end

  defp line_count(text) do
    text
    |> String.split("\n")
    |> length()
  end

  defp broadcast_after_write({:ok, record}) do
    project_id = project_id_for(record)

    if project_id do
      broadcast_project(project_id)
    end

    broadcast_projects()
    {:ok, record}
  end

  defp broadcast_after_write(other), do: other

  defp broadcast_project(project_id) do
    Phoenix.PubSub.broadcast(
      DiscourseApp.PubSub,
      project_topic(project_id),
      {:project_updated, project_id}
    )
  end

  defp broadcast_projects do
    Phoenix.PubSub.broadcast(DiscourseApp.PubSub, @projects_topic, :projects_updated)
  end

  defp project_id_for(%Project{id: id}), do: id
  defp project_id_for(%Document{project_id: project_id}), do: project_id
  defp project_id_for(%Actor{project_id: project_id}), do: project_id
  defp project_id_for(%Concept{project_id: project_id}), do: project_id
  defp project_id_for(%Stance{project_id: project_id}), do: project_id
end
