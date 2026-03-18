defmodule DrinkWaterWeb.LiveRateLimitTest do
  use DrinkWater.DataCase, async: false

  alias DrinkWaterWeb.LiveRateLimit

  defp socket_with_user(user_id) do
    %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, user_id: user_id, flash: %{}}
    }
  end

  setup do
    Application.put_env(:drink_water, :rate_limiting_enabled, true)

    on_exit(fn ->
      Application.put_env(:drink_water, :rate_limiting_enabled, false)
    end)
  end

  describe "check/3" do
    test "allows requests within limit" do
      socket = socket_with_user(99_001)
      assert {:allow, _} = LiveRateLimit.check(socket, "test", 5)
    end

    test "denies requests over limit" do
      socket = socket_with_user(99_002)

      for _ <- 1..5 do
        assert {:allow, _} = LiveRateLimit.check(socket, "test-deny", 5)
      end

      assert {:deny, denied_socket} = LiveRateLimit.check(socket, "test-deny", 5)
      assert denied_socket.assigns.flash["error"] =~ "Too many requests"
    end

    test "different action groups have independent limits" do
      socket = socket_with_user(99_003)

      for _ <- 1..3 do
        assert {:allow, _} = LiveRateLimit.check(socket, "group-a", 3)
      end

      assert {:deny, _} = LiveRateLimit.check(socket, "group-a", 3)
      assert {:allow, _} = LiveRateLimit.check(socket, "group-b", 3)
    end
  end
end
