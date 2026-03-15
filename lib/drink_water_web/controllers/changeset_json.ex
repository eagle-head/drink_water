defmodule DrinkWaterWeb.ChangesetJSON do
  alias DrinkWaterWeb.ProblemDetail

  @doc """
  Renders changeset errors in RFC 7807 format.
  """
  def error(%{changeset: changeset}) do
    ProblemDetail.from_changeset(changeset)
  end
end
