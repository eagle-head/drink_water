defmodule DrinkWaterWeb.DashboardComponents do
  @moduledoc """
  Function components for the hydration dashboard.
  Stateless rendering only — zero logic, zero side effects.
  """
  use Phoenix.Component

  use Gettext, backend: DrinkWaterWeb.Gettext

  attr :days, :list, required: true
  attr :selected_date, :any, default: nil
  attr :target, :any, default: nil

  def weekly_chart(assigns) do
    max_ml =
      Enum.map(assigns.days, fn d -> max(d.total_ml, d.goal) end) |> Enum.max(fn -> 1 end)

    assigns = assign(assigns, max_ml: max_ml)

    ~H"""
    <div class="flex items-end justify-between gap-1 h-32">
      <div :for={day <- @days} class="flex flex-col items-center flex-1">
        <div
          class="tooltip tooltip-top w-full flex flex-col justify-end h-24"
          data-tip={"#{day.total_ml}ml / #{day.goal}ml"}
        >
          <div
            class={"rounded-t w-full transition-all duration-500 cursor-pointer #{if @selected_date == day.date, do: "bg-primary", else: "bg-primary/40"}"}
            style={"height: #{day.total_ml / @max_ml * 100}%"}
            phx-click="select-day"
            phx-value-date={day.date}
            phx-target={@target}
          >
          </div>
        </div>
        <span class={"text-xs mt-1 #{if @selected_date == day.date, do: "text-primary font-bold", else: "text-base-content/60"}"}>
          {Calendar.strftime(day.date, "%a")}
        </span>
      </div>
    </div>
    """
  end
end
