defmodule DiscourseApp.Projects.Document do
  use Ecto.Schema
  import Ecto.Changeset

  alias DiscourseApp.Projects.{Project, Stance}

  @statuses ~w(uploaded extracting analyzed failed)

  schema "documents" do
    field(:name, :string)
    field(:original_filename, :string)
    field(:content_type, :string)
    field(:storage_path, :string)
    field(:source_type, :string, default: "upload")
    field(:status, :string, default: "uploaded")
    field(:extracted_text, :string)
    field(:last_error, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:project, Project)
    has_many(:stances, Stance)

    timestamps()
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :project_id,
      :name,
      :original_filename,
      :content_type,
      :storage_path,
      :source_type,
      :status,
      :extracted_text,
      :last_error,
      :metadata
    ])
    |> validate_required([:project_id, :name, :original_filename, :storage_path, :status])
    |> validate_inclusion(:status, @statuses)
  end
end
