defmodule ActualDashboard.HttpClient do
  @moduledoc """
  HTTP client for the Actual Budget HTTP API
  """

  use GenServer
  require Logger

  defstruct [:base_url, :api_key, :budget_sync_id, :client]

  @refresh_interval :timer.minutes(5)

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_accounts do
    GenServer.call(__MODULE__, {:get_budget_resource, "accounts"})
  end

  def get_categories do
    GenServer.call(__MODULE__, {:get_budget_resource, "categories"})
  end

  def get_payees do
    GenServer.call(__MODULE__, {:get_budget_resource, "payees"})
  end

  def get_transactions(account_id, opts \\ []) do
    params = build_query_params(opts)
    endpoint = "accounts/#{account_id}/transactions"
    endpoint_with_params = if params == "", do: endpoint, else: endpoint <> "?" <> params
    GenServer.call(__MODULE__, {:get_budget_resource, endpoint_with_params})
  end

  def get_all_transactions do
    # Get all accounts first, then get transactions for each
    GenServer.call(__MODULE__, :get_all_transactions)
  end

  def get_budget_months do
    GenServer.call(__MODULE__, {:get_budget_resource, "months"})
  end

  def get_budget_month(month) do
    GenServer.call(__MODULE__, {:get_budget_resource, "months/#{month}"})
  end

  ## Server Callbacks

  def init(opts) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:5007")
    api_key = Keyword.fetch!(opts, :api_key)
    budget_sync_id = Keyword.fetch!(opts, :budget_sync_id)

    client = Req.new(
      base_url: base_url <> "/v1",
      headers: [
        {"x-api-key", api_key},
        {"content-type", "application/json"}
      ]
    )

    Process.send_after(self(), :health_check, 1000)
    
    state = %__MODULE__{
      base_url: base_url,
      api_key: api_key,
      budget_sync_id: budget_sync_id,
      client: client
    }

    {:ok, state}
  end

  def handle_call({:get_budget_resource, resource}, _from, state) do
    endpoint = "/budgets/#{state.budget_sync_id}/#{resource}"
    
    case Req.get(state.client, url: endpoint) do
      {:ok, %{status: 200, body: body}} ->
        # Extract data from the response wrapper
        data = Map.get(body, "data", body)
        {:reply, {:ok, data}, state}
      
      {:ok, %{status: status, body: body}} ->
        Logger.warning("API request failed: #{status} - #{inspect(body)}")
        {:reply, {:error, {status, body}}, state}
      
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_all_transactions, _from, state) do
    # First get all accounts
    case Req.get(state.client, url: "/budgets/#{state.budget_sync_id}/accounts") do
      {:ok, %{status: 200, body: accounts_response}} ->
        accounts = Map.get(accounts_response, "data", [])
        # Get transactions for each account (we'll get the most recent ones)
        all_transactions = Enum.reduce(accounts, [], fn account, acc ->
          account_id = account["id"]
          case Req.get(state.client, url: "/budgets/#{state.budget_sync_id}/accounts/#{account_id}/transactions?since_date=#{get_since_date()}") do
            {:ok, %{status: 200, body: tx_response}} ->
              transactions = Map.get(tx_response, "data", [])
              # Add account field to each transaction for easier processing
              enriched_transactions = Enum.map(transactions, fn tx ->
                Map.put(tx, "account", account_id)
              end)
              acc ++ enriched_transactions
            
            {:error, _} -> acc
            _ -> acc
          end
        end)
        
        {:reply, {:ok, all_transactions}, state}
        
      {:error, reason} ->
        Logger.error("Failed to get accounts for transactions: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(:health_check, state) do
    # Check if we can access accounts (basic health check)
    case Req.get(state.client, url: "/budgets/#{state.budget_sync_id}/accounts") do
      {:ok, %{status: 200}} ->
        Logger.info("Actual Budget HTTP API is healthy")
      {:ok, %{status: status}} ->
        Logger.warning("Health check returned status: #{status}")
      {:error, reason} ->
        Logger.warning("Health check failed: #{inspect(reason)}")
    end

    Process.send_after(self(), :health_check, @refresh_interval)
    {:noreply, state}
  end

  ## Private Functions

  defp get_since_date do
    # Get transactions from 2 years ago to have enough data for analysis
    Date.utc_today()
    |> Date.add(-365 * 2)
    |> Date.to_string()
  end

  ## Private Functions

  defp build_query_params(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end
end
