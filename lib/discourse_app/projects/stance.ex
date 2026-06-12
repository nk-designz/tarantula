defmodule DiscourseApp.Projects.Stance do
  use Ecto.Schema
  import Ecto.Changeset

  alias DiscourseApp.Projects.{Actor, Concept, Document, Project}

  @stances ~w(pro contra neutral)

  schema "stances" do
    field(:actor_name, :string)
    field(:concept_name, :string)
    field(:stance, :string)
    field(:excerpt, :string)
    field(:line_start, :integer)
    field(:line_end, :integer)
    field(:metadata, :map, default: %{})

    belongs_to(:project, Project)
    belongs_to(:document, Document)
    belongs_to(:actor, Actor)
    belongs_to(:concept, Concept)

    timestamps()
  end

  def changeset(stance, attrs) do
    stance
    |> cast(attrs, [
      :project_id,
      :document_id,
      :actor_id,
      :concept_id,
      :actor_name,
      :concept_name,
      :stance,
      :excerpt,
      :line_start,
      :line_end,
      :metadata
    ])
    |> validate_required([:project_id, :document_id, :actor_name, :concept_name, :stance])
    |> validate_inclusion(:stance, @stances)
  end
end
