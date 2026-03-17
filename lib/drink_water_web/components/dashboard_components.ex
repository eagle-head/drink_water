defmodule DrinkWaterWeb.DashboardComponents do
  @moduledoc """
  Function components for the hydration dashboard.
  Stateless rendering only — zero logic, zero side effects.
  """
  use Phoenix.Component

  use Gettext, backend: DrinkWaterWeb.Gettext

  attr :percentage, :float, required: true
  attr :total_ml, :integer, required: true
  attr :goal, :integer, required: true
  attr :intake_count, :integer, required: true

  def progress_ring(assigns) do
    # SVG circle: circumference = 2 * pi * radius
    # radius = 60, circumference ≈ 377
    assigns = assign(assigns, circumference: 377, radius: 60)

    ~H"""
    <div class="flex flex-col items-center">
      <svg class="w-40 h-40 -rotate-90" viewBox="0 0 140 140">
        <circle
          cx="70"
          cy="70"
          r={@radius}
          fill="none"
          stroke="currentColor"
          stroke-width="12"
          class="text-base-300"
        />
        <circle
          cx="70"
          cy="70"
          r={@radius}
          fill="none"
          stroke="currentColor"
          stroke-width="12"
          stroke-dasharray={@circumference}
          stroke-dashoffset={@circumference - @circumference * @percentage / 100}
          stroke-linecap="round"
          class="text-primary transition-all duration-500"
        />
      </svg>
      <p class="text-2xl font-bold mt-2">{@total_ml}ml / {@goal}ml</p>
      <p class="text-base-content/60">
        {@percentage |> Float.round(0) |> trunc()}%
        — {ngettext("1 intake", "%{count} intakes", @intake_count)}
      </p>
    </div>
    """
  end
end
