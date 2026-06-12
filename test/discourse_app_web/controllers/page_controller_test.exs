defmodule DiscourseAppWeb.PageControllerTest do
  use DiscourseAppWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Discourse Network Platform"
    assert response =~ "Create project"
  end
end
