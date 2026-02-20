defmodule PhoenixGcpDeployer.GithubAnalyzer.ReqClient do
  @moduledoc """
  Production GitHub API client using the Req HTTP library.

  Fetches files and repository metadata from the GitHub REST API.
  Supports optional token authentication via the GITHUB_TOKEN environment variable.
  """

  @behaviour PhoenixGcpDeployer.GithubAnalyzer.Client

  @api_base "https://api.github.com"

  @impl true
  def fetch_file(%{owner: owner, repo: repo, default_branch: branch}, path) do
    url = "#{@api_base}/repos/#{owner}/#{repo}/contents/#{path}"

    case request(:get, url, ref: branch) do
      {:ok, %{status: 200, body: %{"content" => content, "encoding" => "base64"}}} ->
        decoded =
          content
          |> String.replace("\n", "")
          |> Base.decode64!()

        {:ok, decoded}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 403, headers: headers}} ->
        if get_header(headers, "x-ratelimit-remaining") == "0" do
          {:error, :rate_limited}
        else
          {:error, :forbidden}
        end

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def fetch_repo_info(owner, repo) do
    url = "#{@api_base}/repos/#{owner}/#{repo}"

    case request(:get, url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(method, url, params \\ []) do
    req =
      Req.new(
        method: method,
        url: url,
        headers: build_headers(),
        params: params
      )

    Req.request(req)
  end

  defp build_headers do
    base = [
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"}
    ]

    case System.get_env("GITHUB_TOKEN") do
      nil -> base
      token -> [{"authorization", "Bearer #{token}"} | base]
    end
  end

  defp get_header(headers, name) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> nil
    end
  end
end
