defmodule DrinkWater.UserManagementTest do
  use DrinkWater.DataCase

  alias DrinkWater.UserManagement

  describe "users" do
    alias DrinkWater.UserManagement.User

    import DrinkWater.UserManagementFixtures

    @invalid_attrs %{
      email: nil,
      first_name: nil,
      last_name: nil,
      birth_date: nil,
      biological_sex: nil,
      weight: nil,
      weight_unit: nil,
      height: nil,
      height_unit: nil
    }

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert UserManagement.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert UserManagement.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        email: "some email",
        first_name: "some first_name",
        last_name: "some last_name",
        birth_date: ~D[2026-03-13],
        biological_sex: 42,
        weight: "120.5",
        weight_unit: 42,
        height: "120.5",
        height_unit: 42
      }

      assert {:ok, %User{} = user} = UserManagement.create_user(valid_attrs)
      assert user.email == "some email"
      assert user.first_name == "some first_name"
      assert user.last_name == "some last_name"
      assert user.birth_date == ~D[2026-03-13]
      assert user.biological_sex == 42
      assert user.weight == Decimal.new("120.5")
      assert user.weight_unit == 42
      assert user.height == Decimal.new("120.5")
      assert user.height_unit == 42
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserManagement.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        email: "some updated email",
        first_name: "some updated first_name",
        last_name: "some updated last_name",
        birth_date: ~D[2026-03-14],
        biological_sex: 43,
        weight: "456.7",
        weight_unit: 43,
        height: "456.7",
        height_unit: 43
      }

      assert {:ok, %User{} = user} = UserManagement.update_user(user, update_attrs)
      assert user.email == "some updated email"
      assert user.first_name == "some updated first_name"
      assert user.last_name == "some updated last_name"
      assert user.birth_date == ~D[2026-03-14]
      assert user.biological_sex == 43
      assert user.weight == Decimal.new("456.7")
      assert user.weight_unit == 43
      assert user.height == Decimal.new("456.7")
      assert user.height_unit == 43
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = UserManagement.update_user(user, @invalid_attrs)
      assert user == UserManagement.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = UserManagement.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> UserManagement.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = UserManagement.change_user(user)
    end
  end
end
