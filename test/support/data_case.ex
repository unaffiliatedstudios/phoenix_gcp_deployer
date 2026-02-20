defmodule PhoenixGcpDeployer.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias PhoenixGcpDeployer.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import PhoenixGcpDeployer.DataCase
    end
  end

  setup tags do
    PhoenixGcpDeployer.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PhoenixGcpDeployer.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
