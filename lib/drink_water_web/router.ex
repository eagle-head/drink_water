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
  end

  scope "/", DrinkWaterWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", DrinkWaterWeb do
    pipe_through :api

    resources "/users", UserController, except: [:new, :edit] do
      get "/alarm_settings", AlarmSettingsController, :show
      post "/alarm_settings", AlarmSettingsController, :create
      put "/alarm_settings", AlarmSettingsController, :update
      delete "/alarm_settings", AlarmSettingsController, :delete

      resources "/water_intakes", WaterIntakeController, except: [:new, :edit]
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
