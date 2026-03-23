defmodule DrinkWaterWeb.CspReportController do
  use DrinkWaterWeb, :controller

  require Logger

  @log_file "logs/csp_violations.log"

  def create(conn, params) do
    report = parse_report(params)

    Logger.warning("CSP violation: #{inspect(report)}")
    write_to_file(report)

    send_resp(conn, 204, "")
  end

  defp parse_report(%{"csp-report" => report}), do: report
  defp parse_report(params), do: params

  defp write_to_file(report) do
    File.mkdir_p!(Path.dirname(@log_file))

    entry = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      report: report
    }

    File.write!(@log_file, JSON.encode!(entry) <> "\n", [:append])
  end
end
