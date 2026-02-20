defmodule PhoenixGcpDeployerWeb.PageControllerTest do
  use PhoenixGcpDeployerWeb.ConnCase

  test "GET / redirects to LiveView", %{conn: conn} do
    conn = get(conn, ~p"/")
    # The root route is now a LiveView - it returns a 200 with the LiveView HTML
    assert html_response(conn, 200) =~ "Phoenix GCP Deployer"
  end
end
