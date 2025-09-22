defmodule ActualDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

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
    [
      base_url: Application.get_env(:actual_dashboard, :api_base_url, "http://localhost:5007"),
      api_key: Application.fetch_env!(:actual_dashboard, :api_key)
    ]
  end

  defp get_account_groups_config do
    [
      account_groups: Application.get_env(:actual_dashboard, :account_groups, %{
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
      })
    ]
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ActualDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
