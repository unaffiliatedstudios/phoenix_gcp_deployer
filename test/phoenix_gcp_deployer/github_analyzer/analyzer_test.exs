defmodule PhoenixGcpDeployer.GithubAnalyzer.AnalyzerTest do
  use ExUnit.Case, async: true

  import Mox

  alias PhoenixGcpDeployer.GithubAnalyzer.{Analyzer, MockClient}

  setup :verify_on_exit!

  @sample_mix_exs """
  defmodule MyApp.MixProject do
    use Mix.Project

    def project do
      [
        app: :my_app,
        version: "0.1.0",
        elixir: "~> 1.17",
        deps: deps()
      ]
    end

    defp deps do
      [
        {:phoenix, "~> 1.7.0"},
        {:phoenix_live_view, "~> 1.0"},
        {:ecto_sql, "~> 3.11"},
        {:postgrex, ">= 0.0.0"},
        {:oban, "~> 2.17"},
        {:swoosh, "~> 1.5"},
        {:gettext, "~> 0.26"}
      ]
    end
  end
  """

  describe "parse_github_url/1" do
    test "parses a standard GitHub URL" do
      assert {:ok, %{owner: "elixir-lang", repo: "elixir"}} =
               Analyzer.parse_github_url("https://github.com/elixir-lang/elixir")
    end

    test "parses URL with www prefix" do
      assert {:ok, %{owner: "owner", repo: "repo"}} =
               Analyzer.parse_github_url("https://www.github.com/owner/repo")
    end

    test "strips .git suffix" do
      assert {:ok, %{owner: "owner", repo: "myapp"}} =
               Analyzer.parse_github_url("https://github.com/owner/myapp.git")
    end

    test "parses URL with tree/branch path" do
      assert {:ok, %{owner: "owner", repo: "myapp"}} =
               Analyzer.parse_github_url("https://github.com/owner/myapp/tree/develop")
    end

    test "returns error for non-GitHub URL" do
      assert {:error, :invalid_github_url} =
               Analyzer.parse_github_url("https://gitlab.com/owner/repo")
    end

    test "returns error for missing repo" do
      assert {:error, :invalid_github_url} =
               Analyzer.parse_github_url("https://github.com/owner")
    end

    test "returns error for empty string" do
      assert {:error, :invalid_github_url} = Analyzer.parse_github_url("")
    end

    test "returns error for nil" do
      assert {:error, :invalid_github_url} = Analyzer.parse_github_url(nil)
    end

    test "returns error for plain string" do
      assert {:error, :invalid_github_url} = Analyzer.parse_github_url("not-a-url")
    end
  end

  describe "parse_mix_exs/1" do
    test "extracts app name" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.name == "my_app"
    end

    test "extracts elixir version" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.elixir_version == "1.17"
    end

    test "extracts phoenix version" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.phoenix_version == "1.7.0"
    end

    test "extracts live_view version" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.live_view_version == "1.0"
    end

    test "detects ecto dependency" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.has_ecto == true
    end

    test "detects live_view dependency" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.has_live_view == true
    end

    test "detects oban dependency" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.has_oban == true
    end

    test "detects swoosh dependency" do
      result = Analyzer.parse_mix_exs(@sample_mix_exs)
      assert result.has_swoosh == true
    end

    test "handles missing optional deps" do
      minimal = """
      defmodule App.MixProject do
        def project, do: [app: :app, elixir: "~> 1.14"]
        defp deps, do: [{:phoenix, "~> 1.7.0"}]
      end
      """

      result = Analyzer.parse_mix_exs(minimal)
      assert result.has_ecto == false
      assert result.has_oban == false
      assert result.has_live_view == false
    end

    test "returns nil for missing fields gracefully" do
      result = Analyzer.parse_mix_exs("")
      assert result.name == nil
      assert result.elixir_version == nil
      assert result.phoenix_version == nil
    end
  end

  describe "analyze/1" do
    test "successfully analyzes a public repository" do
      expect(MockClient, :fetch_repo_info, fn "owner", "myapp" ->
        {:ok, %{"default_branch" => "main"}}
      end)

      expect(MockClient, :fetch_file, fn
        %{owner: "owner", repo: "myapp", default_branch: "main"}, "mix.exs" ->
          {:ok, @sample_mix_exs}
      end)

      assert {:ok, result} = Analyzer.analyze("https://github.com/owner/myapp")
      assert result.name == "my_app"
      assert result.phoenix_version == "1.7.0"
      assert result.has_ecto == true
      assert result.repo_url == "https://github.com/owner/myapp"
      assert result.default_branch == "main"
    end

    test "returns error when repo not found" do
      expect(MockClient, :fetch_repo_info, fn "owner", "missing" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Analyzer.analyze("https://github.com/owner/missing")
    end

    test "returns error when mix.exs not found" do
      expect(MockClient, :fetch_repo_info, fn "owner", "repo" ->
        {:ok, %{"default_branch" => "main"}}
      end)

      expect(MockClient, :fetch_file, fn _, "mix.exs" -> {:error, :not_found} end)

      assert {:error, :not_found} = Analyzer.analyze("https://github.com/owner/repo")
    end

    test "returns error for invalid URL" do
      assert {:error, :invalid_github_url} = Analyzer.analyze("not-a-url")
    end

    test "returns error for unauthorized access" do
      expect(MockClient, :fetch_repo_info, fn "owner", "private" ->
        {:error, :unauthorized}
      end)

      assert {:error, :unauthorized} = Analyzer.analyze("https://github.com/owner/private")
    end
  end
end
