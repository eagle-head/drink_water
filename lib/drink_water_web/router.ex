defmodule DrinkWaterWeb.Router do
  use DrinkWaterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DrinkWaterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug DrinkWaterWeb.Plugs.InputSanitizer
    plug DrinkWaterWeb.Plugs.LogMetadata
  end

  pipeline :rate_limit_user_api do
    plug DrinkWaterWeb.Plugs.RateLimiter,
      key_prefix: "user-api",
      limit: 30,
      key_params: ["user_id", "id"]
  end

  pipeline :rate_limit_water_intake_api do
    plug DrinkWaterWeb.Plugs.RateLimiter, key_prefix: "waterintake-api", limit: 60
  end

  pipeline :rate_limit_water_intake_search do
    plug DrinkWaterWeb.Plugs.RateLimiter,
      key_prefix: "waterintake-search",
      limit: 20
  end

  scope "/", DrinkWaterWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/dashboard", DashboardLive
  end

  scope "/api", DrinkWaterWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", DrinkWaterWeb do
    pipe_through :api

    scope "/users" do
      pipe_through :rate_limit_user_api

      resources "/", UserController, except: [:new, :edit, :index] do
        get "/alarm_settings", AlarmSettingsController, :show
        post "/alarm_settings", AlarmSettingsController, :create
        put "/alarm_settings", AlarmSettingsController, :update
        delete "/alarm_settings", AlarmSettingsController, :delete
      end
    end

    scope "/users/:user_id" do
      pipe_through :rate_limit_water_intake_api

      resources "/water_intakes", WaterIntakeController, except: [:new, :edit, :index]
    end

    scope "/users/:user_id" do
      pipe_through :rate_limit_water_intake_search

      get "/water_intakes", WaterIntakeController, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:drink_water, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DrinkWaterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
