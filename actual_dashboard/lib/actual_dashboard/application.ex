defmodule ActualDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      ActualDashboardWeb.Telemetry,
      # ActualDashboard.Repo,  # Disabled - using HTTP API instead
      {DNSCluster, query: Application.get_env(:actual_dashboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ActualDashboard.PubSub},
      # Start HTTP client for Actual Budget API
      {ActualDashboard.HttpClient, get_api_config()},
      # Start data cache
      {ActualDashboard.DataCache, get_account_groups_config()},
      # Start to serve requests, typically the last entry
      ActualDashboardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ActualDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp get_api_config do
    api_key = Application.get_env(:actual_dashboard, :api_key, "demo_key_12345")
    budget_sync_id = Application.get_env(:actual_dashboard, :budget_sync_id, "demo_sync_id")

    # Log warnings if using demo values
    if api_key == "demo_key_12345" do
      Logger.warning("Using demo API key. Set ACTUAL_HTTP_API_KEY environment variable.")
    end

    if budget_sync_id == "demo_sync_id" do
      Logger.warning("Using demo sync ID. Set ACTUAL_BUDGET_SYNC_ID environment variable.")
    end

    [
      base_url: Application.get_env(:actual_dashboard, :api_base_url, "http://localhost:5007"),
      api_key: api_key,
      budget_sync_id: budget_sync_id
    ]
  end

  defp get_account_groups_config do
    account_groups_json = System.get_env("ACCOUNT_GROUPS")

    account_groups =
      case account_groups_json do
        nil ->
          %{
            # Assets
            "assets_liquid" => ["Ally Savings", "Bank of America", "Capital One Checking"],
            "assets_restricted" => ["Roth IRA", "Vanguard 401k"],
            "assets_investment" => [],
            "assets_physical" => ["House Asset"],
            # Liabilities
            "liabilities_installment" => [],
            "liabilities_physical" => ["Mortgage"],
            "liabilities_revolving" => [],
            "liabilities_transacting" => ["HSBC"]
          }

        json ->
          case Jason.decode(json) do
            {:ok, parsed} -> parsed
            {:error, _} -> %{}
          end
      end

    [account_groups: account_groups]
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ActualDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
