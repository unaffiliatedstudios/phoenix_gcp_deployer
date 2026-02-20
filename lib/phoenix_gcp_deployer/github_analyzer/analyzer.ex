defmodule PhoenixGcpDeployer.GithubAnalyzer.Analyzer do
  @moduledoc """
  Analyzes a GitHub repository to detect Phoenix application characteristics.

  Parses `mix.exs` and other project files to identify:
  - Phoenix and LiveView versions
  - Elixir and OTP version requirements
  - Key dependencies (Ecto, Oban, etc.)
  - Project structure information
  """

  alias PhoenixGcpDeployer.GithubAnalyzer.Client

  @type analysis_result :: %{
          name: String.t(),
          phoenix_version: String.t() | nil,
          live_view_version: String.t() | nil,
          elixir_version: String.t() | nil,
          has_ecto: boolean(),
          has_live_view: boolean(),
          has_oban: boolean(),
          has_swoosh: boolean(),
          has_gettext: boolean(),
          repo_url: String.t(),
          default_branch: String.t(),
          is_umbrella: boolean()
        }

  @doc """
  Parses a GitHub URL and returns structured owner/repo/branch info.

  ## Examples

      iex> parse_github_url("https://github.com/owner/myapp")
      {:ok, %{owner: "owner", repo: "myapp"}}

      iex> parse_github_url("https://github.com/owner/myapp/tree/develop")
      {:ok, %{owner: "owner", repo: "myapp"}}

      iex> parse_github_url("not-a-url")
      {:error, :invalid_github_url}
  """
  @spec parse_github_url(String.t()) :: {:ok, %{owner: String.t(), repo: String.t()}} | {:error, :invalid_github_url}
  def parse_github_url(url) when is_binary(url) do
    uri = URI.parse(String.trim(url))

    with true <- uri.host in ["github.com", "www.github.com"],
         [owner, repo | _] <- String.split(uri.path || "", "/", trim: true),
         repo <- String.replace_suffix(repo, ".git", ""),
         true <- owner != "" and repo != "" do
      {:ok, %{owner: owner, repo: repo}}
    else
      _ -> {:error, :invalid_github_url}
    end
  end

  def parse_github_url(_), do: {:error, :invalid_github_url}

  @doc """
  Analyzes a GitHub repository and returns information about the Phoenix app.

  Fetches `mix.exs` from the repository and parses it to discover dependencies
  and project configuration.
  """
  @spec analyze(String.t()) :: {:ok, analysis_result()} | {:error, term()}
  def analyze(github_url) do
    with {:ok, %{owner: owner, repo: repo}} <- parse_github_url(github_url),
         {:ok, repo_info} <- Client.fetch_repo_info(owner, repo),
         default_branch = Map.get(repo_info, "default_branch", "main"),
         full_repo = %{owner: owner, repo: repo, default_branch: default_branch},
         {:ok, mix_content} <- Client.fetch_file(full_repo, "mix.exs") do
      result =
        mix_content
        |> parse_mix_exs()
        |> Map.merge(%{
          repo_url: github_url,
          default_branch: default_branch,
          is_umbrella: is_umbrella_app?(mix_content)
        })

      {:ok, result}
    end
  end

  @doc """
  Parses the content of a `mix.exs` file and extracts relevant information.
  """
  @spec parse_mix_exs(String.t()) :: map()
  def parse_mix_exs(content) when is_binary(content) do
    %{
      name: extract_app_name(content),
      elixir_version: extract_elixir_version(content),
      phoenix_version: extract_dep_version(content, "phoenix"),
      live_view_version: extract_dep_version(content, "phoenix_live_view"),
      has_ecto: has_dep?(content, "ecto_sql") or has_dep?(content, "ecto"),
      has_live_view: has_dep?(content, "phoenix_live_view"),
      has_oban: has_dep?(content, "oban"),
      has_swoosh: has_dep?(content, "swoosh"),
      has_gettext: has_dep?(content, "gettext")
    }
  end

  # --- Private helpers ---

  defp extract_app_name(content) do
    case Regex.run(~r/app:\s+:([a-z_]+)/, content) do
      [_, name] -> name
      _ -> nil
    end
  end

  defp extract_elixir_version(content) do
    case Regex.run(~r/elixir:\s+"~>\s*([\d.]+)"/, content) do
      [_, version] -> version
      _ -> nil
    end
  end

  defp extract_dep_version(content, dep_name) do
    escaped = Regex.escape(dep_name)
    pattern = ~r/\{:#{escaped},\s*"~>\s*([\d.]+)"/

    case Regex.run(pattern, content) do
      [_, version] -> version
      _ -> nil
    end
  end

  defp has_dep?(content, dep_name) do
    String.contains?(content, ":#{dep_name}")
  end

  defp is_umbrella_app?(content) do
    String.contains?(content, "in_umbrella") or String.contains?(content, "apps_path:")
  end
end
