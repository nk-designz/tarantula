defmodule DiscourseAppWeb.GraphExportController do
  use DiscourseAppWeb, :controller

  alias DiscourseApp.Projects

  def show(conn, %{"id" => id}) do
    project = Projects.get_project!(id)
    snapshot = Projects.network_snapshot(project)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=project-#{project.id}-dna-graph.json"
    )
    |> send_resp(200, Jason.encode!(snapshot))
  end
end
