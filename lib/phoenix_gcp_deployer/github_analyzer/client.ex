defmodule PhoenixGcpDeployer.GithubAnalyzer.Client do
  @moduledoc """
  Behaviour for the GitHub API client.

  Defines the contract for fetching repository data. In production, the
  `ReqClient` implementation is used. In tests, a Mox mock is used.
  """

  @type repo_info :: %{
          owner: String.t(),
          repo: String.t(),
          default_branch: String.t()
        }

  @type file_result :: {:ok, String.t()} | {:error, :not_found | :unauthorized | :rate_limited | term()}

  @callback fetch_file(repo_info(), path :: String.t()) :: file_result()
  @callback fetch_repo_info(owner :: String.t(), repo :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc "Returns the configured client implementation."
  def impl do
    Application.get_env(:phoenix_gcp_deployer, :github_client, PhoenixGcpDeployer.GithubAnalyzer.ReqClient)
  end

  @doc "Delegates `fetch_file/2` to the configured implementation."
  def fetch_file(repo_info, path), do: impl().fetch_file(repo_info, path)

  @doc "Delegates `fetch_repo_info/2` to the configured implementation."
  def fetch_repo_info(owner, repo), do: impl().fetch_repo_info(owner, repo)
end
