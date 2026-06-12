defmodule DiscourseAppWeb.PageControllerTest do
  use DiscourseAppWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Dashboard"
    assert response =~ "Discourse program status at a glance"
    assert response =~ "Theme selection"
    assert response =~ "Projects"
  end
end
