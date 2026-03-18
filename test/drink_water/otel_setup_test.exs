defmodule DrinkWater.OtelSetupTest do
  use ExUnit.Case, async: true

  alias DrinkWater.OtelSetup

  describe "setup/0" do
    test "does not raise" do
      assert :ok == OtelSetup.setup()
    end

    test "is idempotent — calling twice does not crash" do
      OtelSetup.setup()
      assert :ok == OtelSetup.setup()
    end
  end
end
