defmodule DiscourseAppWeb.LayoutsTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias DiscourseAppWeb.Layouts

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DiscourseApp.Repo)
    :ok
  end

  test "theme_toggle renders all theme options" do
    html = render_component(&Layouts.theme_toggle/1, %{})

    assert html =~ "Theme selection"
    assert html =~ "data-phx-theme=\"system\""
    assert html =~ "data-phx-theme=\"paper\""
    assert html =~ "data-phx-theme=\"reef\""
    assert html =~ "data-phx-theme=\"midnight\""
  end

  test "app layout includes shell and flash container" do
    html =
      render_component(&Layouts.app/1,
        flash: %{},
        current_scope: %{},
        inner_block: [%{inner_block: fn _, _ -> "inner-content" end}]
      )

    assert html =~ "Intelligence cockpit"
    assert html =~ "inner-content"
    assert html =~ "id=\"flash-group\""
  end
end
