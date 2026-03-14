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

    test "get_user/1 returns the user with given id" do
      user = user_fixture()
      assert {:ok, found} = UserManagement.get_user(user.id)
      assert found == user
    end

    test "get_user/1 returns error when user does not exist" do
      assert {:error, :not_found} = UserManagement.get_user(0)
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        email: "valid@example.com",
        first_name: "John",
        last_name: "Doe",
        birth_date: ~D[1990-05-15],
        biological_sex: :male,
        weight: "75.0",
        weight_unit: :kg,
        height: "175.0",
        height_unit: :cm
      }

      assert {:ok, %User{} = user} = UserManagement.create_user(valid_attrs)
      assert user.email == "valid@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.birth_date == ~D[1990-05-15]
      assert user.biological_sex == :male
      assert user.weight == Decimal.new("75.0")
      assert user.weight_unit == :kg
      assert user.height == Decimal.new("175.0")
      assert user.height_unit == :cm
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserManagement.create_user(@invalid_attrs)
    end

    test "create_user/1 with duplicate email returns error changeset" do
      user = user_fixture()

      duplicate_attrs = %{
        email: user.email,
        first_name: "Ana",
        last_name: "Silva",
        birth_date: ~D[1995-01-01],
        biological_sex: :female,
        weight: "60.0",
        weight_unit: :kg,
        height: "165.0",
        height_unit: :cm
      }

      assert {:error, changeset} = UserManagement.create_user(duplicate_attrs)
      assert {"has already been taken", _} = changeset.errors[:email]
    end

    test "create_user/1 rejects birth_date under minimum age" do
      attrs = %{
        email: "young@example.com",
        first_name: "Young",
        last_name: "User",
        birth_date: Date.utc_today(),
        biological_sex: :male,
        weight: "50.0",
        weight_unit: :kg,
        height: "160.0",
        height_unit: :cm
      }

      assert {:error, changeset} = UserManagement.create_user(attrs)
      assert {"user must be at least 13 years old", _} = changeset.errors[:birth_date]
    end

    test "create_user/1 rejects weight out of range" do
      attrs = %{
        email: "heavy@example.com",
        first_name: "Heavy",
        last_name: "User",
        birth_date: ~D[1990-01-01],
        biological_sex: :male,
        weight: "501.0",
        weight_unit: :kg,
        height: "175.0",
        height_unit: :cm
      }

      assert {:error, changeset} = UserManagement.create_user(attrs)
      assert changeset.errors[:weight]
    end

    test "create_user/1 rejects height out of range" do
      attrs = %{
        email: "tall@example.com",
        first_name: "Tall",
        last_name: "User",
        birth_date: ~D[1990-01-01],
        biological_sex: :male,
        weight: "75.0",
        weight_unit: :kg,
        height: "251.0",
        height_unit: :cm
      }

      assert {:error, changeset} = UserManagement.create_user(attrs)
      assert changeset.errors[:height]
    end

    test "create_user/1 rejects short names" do
      attrs = %{
        email: "short@example.com",
        first_name: "A",
        last_name: "B",
        birth_date: ~D[1990-01-01],
        biological_sex: :male,
        weight: "75.0",
        weight_unit: :kg,
        height: "175.0",
        height_unit: :cm
      }

      assert {:error, changeset} = UserManagement.create_user(attrs)
      assert changeset.errors[:first_name]
      assert changeset.errors[:last_name]
    end

    test "create_user/1 rejects invalid email format" do
      attrs = %{
        email: "not-an-email",
        first_name: "Bad",
        last_name: "Email",
        birth_date: ~D[1990-01-01],
        biological_sex: :male,
        weight: "75.0",
        weight_unit: :kg,
        height: "175.0",
        height_unit: :cm
      }

      assert {:error, changeset} = UserManagement.create_user(attrs)
      assert changeset.errors[:email]
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        email: "updated@example.com",
        first_name: "Jane",
        last_name: "Doe",
        birth_date: ~D[1992-08-20],
        biological_sex: :female,
        weight: "65.0",
        weight_unit: :kg,
        height: "168.0",
        height_unit: :cm
      }

      assert {:ok, %User{} = user} = UserManagement.update_user(user, update_attrs)
      assert user.email == "updated@example.com"
      assert user.first_name == "Jane"
      assert user.last_name == "Doe"
      assert user.birth_date == ~D[1992-08-20]
      assert user.biological_sex == :female
      assert user.weight == Decimal.new("65.0")
      assert user.weight_unit == :kg
      assert user.height == Decimal.new("168.0")
      assert user.height_unit == :cm
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = UserManagement.update_user(user, @invalid_attrs)
      assert {:ok, ^user} = UserManagement.get_user(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = UserManagement.delete_user(user)
      assert {:error, :not_found} = UserManagement.get_user(user.id)
    end

    test "create_user/1 rejects invalid enum values" do
      attrs = %{
        email: "enum@example.com",
        first_name: "John",
        last_name: "Doe",
        birth_date: ~D[1990-01-01],
        biological_sex: "invalid",
        weight: "75.0",
        weight_unit: "miles",
        height: "175.0",
        height_unit: "feet"
      }

      assert {:error, changeset} = UserManagement.create_user(attrs)
      assert changeset.errors[:biological_sex]
      assert changeset.errors[:weight_unit]
      assert changeset.errors[:height_unit]
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = UserManagement.change_user(user)
    end
  end
end
