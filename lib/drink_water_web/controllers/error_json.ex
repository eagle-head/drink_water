defmodule DrinkWaterWeb.ErrorJSON do
  alias DrinkWaterWeb.ProblemDetail

  def render(template, _assigns) do
    status = status_from_template(template)
    ProblemDetail.build(status)
  end

  defp status_from_template(template) do
    case template |> String.split(".") |> hd() |> Integer.parse() do
      {status, ""} -> status
      _ -> 500
    end
  end
end
