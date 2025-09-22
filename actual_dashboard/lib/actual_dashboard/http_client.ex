defmodule ActualDashboard.HttpClient do
  @moduledoc """
  HTTP client for the Actual Budget HTTP API
  """

  use GenServer
  require Logger

  defstruct [:base_url, :api_key, :client]

  @refresh_interval :timer.minutes(5)

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_accounts do
    GenServer.call(__MODULE__, {:get, "/accounts"})
  end

  def get_categories do
    GenServer.call(__MODULE__, {:get, "/categories"})
  end

  def get_payees do
    GenServer.call(__MODULE__, {:get, "/payees"})
  end

  def get_transactions(opts \\ []) do
    params = build_query_params(opts)
    endpoint = if params == "", do: "/transactions", else: "/transactions?" <> params
    GenServer.call(__MODULE__, {:get, endpoint})
  end

  def get_budget_month(month) do
    GenServer.call(__MODULE__, {:get, "/budget/#{month}"})
  end

  def get_net_worth do
    GenServer.call(__MODULE__, {:get, "/net-worth"})
  end

  ## Server Callbacks

  def init(opts) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:5007")
    api_key = Keyword.fetch!(opts, :api_key)

    client = Req.new(
      base_url: base_url,
      headers: [
        {"authorization", "Bearer #{api_key}"},
        {"content-type", "application/json"}
      ]
    )

    Process.send_after(self(), :health_check, 1000)
    
    state = %__MODULE__{
      base_url: base_url,
      api_key: api_key,
      client: client
    }

    {:ok, state}
  end

  def handle_call({:get, endpoint}, _from, state) do
    case Req.get(state.client, url: endpoint) do
      {:ok, %{status: 200, body: body}} ->
        {:reply, {:ok, body}, state}
      
      {:ok, %{status: status, body: body}} ->
        Logger.warning("API request failed: #{status} - #{inspect(body)}")
        {:reply, {:error, {status, body}}, state}
      
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(:health_check, state) do
    case Req.get(state.client, url: "/health") do
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

  defp build_query_params(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end
end
