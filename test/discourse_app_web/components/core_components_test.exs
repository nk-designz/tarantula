defmodule DiscourseAppWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DiscourseAppWeb.CoreComponents

  test "button uses primary variant by default" do
    html =
      render_component(&CoreComponents.button/1, %{
        inner_block: [%{inner_block: fn _, _ -> "Run" end}]
      })

    assert html =~ "dna-button"
    assert html =~ "dna-button-primary"
    assert html =~ "Run"
  end

  test "button supports secondary variant" do
    html =
      render_component(&CoreComponents.button/1, %{
        variant: "secondary",
        inner_block: [%{inner_block: fn _, _ -> "Secondary" end}]
      })

    assert html =~ "dna-button-secondary"
  end

  test "flash renders info style when flash message exists" do
    html =
      render_component(&CoreComponents.flash/1, %{
        kind: :info,
        flash: %{},
        inner_block: [%{inner_block: fn _, _ -> "Saved" end}]
      })

    assert html =~ "dna-flash"
    assert html =~ "dna-flash-info"
    assert html =~ "Saved"
  end

  test "input renders dna styles" do
    html =
      render_component(&CoreComponents.input/1, %{
        type: "text",
        id: "project-name",
        name: "project[name]",
        label: "Project name",
        value: "Grid"
      })

    assert html =~ "dna-field"
    assert html =~ "dna-input"
    assert html =~ "Project name"
  end
end
