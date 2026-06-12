defmodule DiscourseAppWeb.PageControllerTest do
  use DiscourseAppWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Discourse Network Platform"
    assert response =~ "Create project"
    assert response =~ "Theme selection"
    assert response =~ "data-phx-theme=\"system\""
    assert response =~ "data-phx-theme=\"paper\""
    assert response =~ "data-phx-theme=\"reef\""
    assert response =~ "data-phx-theme=\"midnight\""
  end
end
