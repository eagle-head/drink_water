defmodule DrinkWater.TelemetryEvents do
  @moduledoc """
  Custom telemetry event wrappers using :telemetry.span/3.

  Each span_* function wraps a business operation and automatically emits
  :start, :stop (with duration), and :exception events.

  The wrapped function must return {result, extra_measurements}.
  """

  # Hydration events

  def span_intake_created(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_created], metadata, fun)
  end

  def span_intake_updated(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_updated], metadata, fun)
  end

  def span_intake_deleted(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_deleted], metadata, fun)
  end

  def span_intake_search(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_search], metadata, fun)
  end

  # User management events

  def span_user_created(metadata, fun) do
    :telemetry.span([:drink_water, :users, :user_created], metadata, fun)
  end

  def span_user_updated(metadata, fun) do
    :telemetry.span([:drink_water, :users, :user_updated], metadata, fun)
  end

  def span_user_deleted(metadata, fun) do
    :telemetry.span([:drink_water, :users, :user_deleted], metadata, fun)
  end

  def span_alarm_settings_created(metadata, fun) do
    :telemetry.span([:drink_water, :users, :alarm_settings_created], metadata, fun)
  end

  def span_alarm_settings_updated(metadata, fun) do
    :telemetry.span([:drink_water, :users, :alarm_settings_updated], metadata, fun)
  end

  def span_alarm_settings_deleted(metadata, fun) do
    :telemetry.span([:drink_water, :users, :alarm_settings_deleted], metadata, fun)
  end
end
