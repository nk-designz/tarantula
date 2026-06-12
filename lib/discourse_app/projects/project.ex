defmodule DiscourseApp.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias DiscourseApp.Projects.{Actor, Concept, Document, Stance}

  schema "projects" do
    field(:name, :string)
    field(:description, :string)
    field(:status, :string, default: "draft")
    field(:current_step, :string, default: "idle")
    field(:progress, :integer, default: 0)
    field(:eta_seconds, :integer)
    field(:network_snapshot, :map, default: %{"nodes" => [], "links" => []})
    field(:last_error, :string)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    has_many(:documents, Document)
    has_many(:actors, Actor)
    has_many(:concepts, Concept)
    has_many(:stances, Stance)

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description])
    |> update_change(:name, &normalize_text/1)
    |> update_change(:description, &normalize_text/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 3, max: 120)
  end

  def analysis_changeset(project, attrs) do
    project
    |> cast(attrs, [
      :status,
      :current_step,
      :progress,
      :eta_seconds,
      :network_snapshot,
      :last_error,
      :started_at,
      :completed_at
    ])
    |> validate_number(:progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  defp normalize_text(nil), do: nil

  defp normalize_text(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end
end
