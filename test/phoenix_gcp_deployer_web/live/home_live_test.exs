defmodule PhoenixGcpDeployerWeb.HomeLiveTest do
  use PhoenixGcpDeployerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders home page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Phoenix GCP Deployer"
      assert html =~ "Start Deploying"
    end

    test "has link to deploy page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert has_element?(lv, "a[href='/deploy']")
    end

    test "shows feature cards", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Auto-Analyze"
      assert html =~ "Configure"
      assert html =~ "Generate"
    end

    test "shows artifacts section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Dockerfile"
      assert html =~ "Terraform"
      assert html =~ "Cloud Build"
    end
  end
end
