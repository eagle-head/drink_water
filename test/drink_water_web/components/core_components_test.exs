defmodule DrinkWaterWeb.CoreComponentsTest do
  use DrinkWaterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [sigil_H: 2]

  alias DrinkWaterWeb.CoreComponents

  describe "table/1" do
    test "renders a table with columns and rows" do
      assigns = %{
        id: "test-table",
        rows: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]
      }

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id={@id} rows={@rows}>
          <:col :let={row} label="ID">{row.id}</:col>
          <:col :let={row} label="Name">{row.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "ID"
      assert html =~ "Name"
    end

    test "renders a table with action slot" do
      assigns = %{
        rows: [%{id: 1, name: "Alice"}]
      }

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={@rows}>
          <:col :let={row} label="Name">{row.name}</:col>
          <:action :let={row}>
            <a href={"/edit/#{row.id}"}>Edit</a>
          </:action>
        </CoreComponents.table>
        """)

      assert html =~ "Edit"
      assert html =~ "Actions"
    end
  end

  describe "list/1" do
    test "renders a data list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.list>
          <:item title="Title">My Title</:item>
          <:item title="Views">100</:item>
        </CoreComponents.list>
        """)

      assert html =~ "Title"
      assert html =~ "My Title"
      assert html =~ "Views"
      assert html =~ "100"
    end
  end

  describe "header/1" do
    test "renders a header with title" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          My Page Title
        </CoreComponents.header>
        """)

      assert html =~ "My Page Title"
    end

    test "renders a header with subtitle and actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Dashboard
          <:subtitle>Welcome back</:subtitle>
          <:actions>
            <button>Action</button>
          </:actions>
        </CoreComponents.header>
        """)

      assert html =~ "Dashboard"
      assert html =~ "Welcome back"
      assert html =~ "Action"
    end
  end

  describe "button/1" do
    test "renders a button element" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button>Click me</CoreComponents.button>
        """)

      assert html =~ "Click me"
      assert html =~ "<button"
    end

    test "renders a link when navigate is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button navigate="/home">Go Home</CoreComponents.button>
        """)

      assert html =~ "Go Home"
      assert html =~ "/home"
    end

    test "renders a link when href is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button href="https://example.com">Link</CoreComponents.button>
        """)

      assert html =~ "Link"
      assert html =~ "https://example.com"
    end

    test "renders with primary variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button variant="primary">Primary</CoreComponents.button>
        """)

      assert html =~ "btn-primary"
      assert html =~ "Primary"
    end
  end

  describe "input/1" do
    test "renders a hidden input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="hidden" name="token" value="abc123" />
        """)

      assert html =~ "type=\"hidden\""
      assert html =~ "abc123"
    end

    test "renders a checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="checkbox" name="accept" label="Accept terms" value="true" />
        """)

      assert html =~ "type=\"checkbox\""
      assert html =~ "Accept terms"
    end

    test "renders a select input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="select"
          name="role"
          label="Role"
          options={[Admin: "admin", User: "user"]}
          value="user"
          prompt="Select a role"
        />
        """)

      assert html =~ "Role"
      assert html =~ "Admin"
      assert html =~ "User"
      assert html =~ "Select a role"
    end

    test "renders a textarea input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="bio" label="Bio" value="Hello world" />
        """)

      assert html =~ "Bio"
      assert html =~ "<textarea"
      assert html =~ "Hello world"
    end

    test "renders a text input with label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="name" label="Full Name" value="John" />
        """)

      assert html =~ "Full Name"
      assert html =~ "John"
    end

    test "renders errors on inputs" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="email" value="" errors={["is required"]} />
        """)

      assert html =~ "is required"
      assert html =~ "input-error"
    end

    test "renders a form field input" do
      changeset =
        DrinkWater.HydrationTracking.WaterIntake.changeset(
          %DrinkWater.HydrationTracking.WaterIntake{},
          %{volume: 0}
        )
        |> Map.put(:action, :validate)

      form = Phoenix.Component.to_form(changeset)
      assigns = %{form: form}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:volume]} type="number" label="Volume" />
        """)

      assert html =~ "Volume"
    end
  end

  describe "translate_errors/2" do
    test "translates errors for a field" do
      errors = [name: {"can't be blank", [validation: :required]}]
      result = CoreComponents.translate_errors(errors, :name)
      assert result == ["can't be blank"]
    end
  end

  describe "translate_error/1" do
    test "translates error with count (dngettext plural branch)" do
      error = {"%{count} items", [count: 5]}
      result = CoreComponents.translate_error(error)
      assert result == "5 items"
    end

    test "translates error with count of 1 (singular)" do
      error = {"%{count} item", [count: 1]}
      result = CoreComponents.translate_error(error)
      assert result == "1 item"
    end
  end

  describe "show/1 and hide/1" do
    test "show returns a JS command" do
      js = CoreComponents.show("#my-element")
      assert %Phoenix.LiveView.JS{} = js
    end

    test "hide returns a JS command" do
      js = CoreComponents.hide("#my-element")
      assert %Phoenix.LiveView.JS{} = js
    end

    test "show chains with existing JS command" do
      js = CoreComponents.show(%Phoenix.LiveView.JS{}, "#el")
      assert %Phoenix.LiveView.JS{} = js
    end

    test "hide chains with existing JS command" do
      js = CoreComponents.hide(%Phoenix.LiveView.JS{}, "#el")
      assert %Phoenix.LiveView.JS{} = js
    end
  end
end
