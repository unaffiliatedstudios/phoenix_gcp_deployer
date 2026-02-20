defmodule PhoenixGcpDeployer.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_gcp_deployer,
    adapter: Ecto.Adapters.Postgres
end
