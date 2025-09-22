defmodule ActualDashboardWeb.ErrorJSONTest do
  use ActualDashboardWeb.ConnCase, async: true

  test "renders 404" do
    assert ActualDashboardWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ActualDashboardWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
