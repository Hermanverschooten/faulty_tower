defmodule FaultyTowerWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import FaultyTowerWeb.CoreComponents

  test "button renders the primary variant by default" do
    html =
      render_component(&button/1, %{
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Go" end}]
      })

    assert html =~ "bg-zinc-900"
    refute html =~ "bg-red-700"
  end

  test "button renders the danger variant without the primary background" do
    html =
      render_component(&button/1, %{
        variant: "danger",
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Delete" end}]
      })

    assert html =~ "bg-red-700"
    refute html =~ "bg-zinc-900"
  end

  test "checkgroup renders native checkboxes with accent-zinc-900, one per option" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.input
        type="checkgroup"
        name="u[orgs][]"
        id="orgs"
        label="Organizations"
        options={[{"A", 1}, {"B", 2}]}
        value={[1]}
      />
      """)

    doc = Floki.parse_fragment!(html)
    boxes = Floki.find(doc, ~s(input[type=checkbox]))
    assert length(boxes) == 2

    for box <- boxes do
      [class] = Floki.attribute(box, "class")
      assert class =~ "accent-zinc-900"
      assert class =~ "appearance-auto"
    end
  end
end
