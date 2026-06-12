defmodule DiscourseApp.Projects.Concept do
  use Ecto.Schema
  import Ecto.Changeset

  alias DiscourseApp.Projects.{Project, Stance}

  schema "concepts" do
    field(:name, :string)
    field(:slug, :string)
    field(:occurrences_count, :integer, default: 0)
    field(:document_count, :integer, default: 0)
    field(:metadata, :map, default: %{})

    belongs_to(:project, Project)
    has_many(:stances, Stance)

    timestamps()
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [:project_id, :name, :slug, :occurrences_count, :document_count, :metadata])
    |> validate_required([:project_id, :name, :slug])
    |> unique_constraint([:project_id, :slug])
  end
end
