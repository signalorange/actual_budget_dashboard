defmodule ActualDashboard.DataCache do
  @moduledoc """
  GenServer for caching and refreshing financial data
  """

  use GenServer
  alias ActualDashboard.{HttpClient, DataProcessor}
  require Logger

  @refresh_interval :timer.minutes(5)

  defstruct [
    :accounts,
    :categories,
    :payees,
    :transactions,
    :net_worth_by_month,
    :cashflow_by_month,
    :metrics,
    :account_groups,
    :last_updated
  ]

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_dashboard_data do
    GenServer.call(__MODULE__, :get_dashboard_data)
  end

  def refresh_data do
    GenServer.cast(__MODULE__, :refresh_data)
  end

  def get_last_updated do
    GenServer.call(__MODULE__, :get_last_updated)
  end

  ## Server Callbacks

  def init(opts) do
    account_groups = Keyword.get(opts, :account_groups, default_account_groups())
    
    # Load data immediately, then schedule periodic refresh
    send(self(), :load_initial_data)
    Process.send_after(self(), :refresh_data, @refresh_interval)

    state = %__MODULE__{
      account_groups: account_groups,
      last_updated: nil
    }

    {:ok, state}
  end

  def handle_call(:get_dashboard_data, _from, state) do
    data = %{
      accounts: state.accounts || [],
      categories: state.categories || [],
      payees: state.payees || [],
      transactions: state.transactions || [],
      net_worth_by_month: state.net_worth_by_month || %{},
      cashflow_by_month: state.cashflow_by_month || %{},
      metrics: state.metrics || %{},
      account_groups: state.account_groups,
      last_updated: state.last_updated
    }

    {:reply, data, state}
  end

  def handle_call(:get_last_updated, _from, state) do
    {:reply, state.last_updated, state}
  end

  def handle_cast(:refresh_data, state) do
    {:noreply, load_and_process_data(state)}
  end

  def handle_info(:load_initial_data, state) do
    {:noreply, load_and_process_data(state)}
  end

  def handle_info(:refresh_data, state) do
    new_state = load_and_process_data(state)
    Process.send_after(self(), :refresh_data, @refresh_interval)
    {:noreply, new_state}
  end

  ## Private Functions

  defp load_and_process_data(state) do
    Logger.info("Loading financial data from API...")

    try do
      # Load base data from API
      {:ok, accounts} = HttpClient.get_accounts()
      {:ok, categories} = HttpClient.get_categories()
      {:ok, payees} = HttpClient.get_payees()
      {:ok, transactions} = HttpClient.get_all_transactions()

      Logger.info("Loaded #{length(accounts)} accounts, #{length(categories)} categories, #{length(transactions)} transactions")

      # Process data for dashboard
      net_worth_by_month = DataProcessor.calculate_net_worth_by_month(
        transactions, accounts, state.account_groups
      )

      cashflow_by_month = DataProcessor.calculate_cashflow_by_month(
        transactions, categories
      )

      metrics = DataProcessor.calculate_metrics(net_worth_by_month, cashflow_by_month)

      Logger.info("Data processing completed successfully")

      %{state |
        accounts: accounts,
        categories: categories,
        payees: payees,
        transactions: transactions,
        net_worth_by_month: net_worth_by_month,
        cashflow_by_month: cashflow_by_month,
        metrics: metrics,
        last_updated: DateTime.utc_now()
      }

    rescue
      error ->
        Logger.warning("Failed to load data from API, using demo data: #{inspect(error)}")
        # Return demo data if API fails
        load_demo_data(state)
    end
  end

  defp load_demo_data(state) do
    # Sample demo data to show the dashboard structure
    demo_accounts = [
      %{"id" => "1", "name" => "Ally Savings", "balance" => 50000_00},
      %{"id" => "2", "name" => "Capital One Checking", "balance" => 15000_00},
      %{"id" => "3", "name" => "Roth IRA", "balance" => 120000_00},
      %{"id" => "4", "name" => "House Asset", "balance" => 450000_00},
      %{"id" => "5", "name" => "Mortgage", "balance" => -280000_00}
    ]

    demo_categories = [
      %{"id" => "1", "name" => "Salary", "is_income" => true, "group_id" => "income_group"},
      %{"id" => "2", "name" => "Groceries", "is_income" => false, "group_id" => "expense_group"},
      %{"id" => "3", "name" => "Utilities", "is_income" => false, "group_id" => "expense_group"}
    ]

    demo_transactions = [
      %{"id" => "1", "account" => "1", "category" => "1", "amount" => 8000_00, "date" => "2024-01-01"},
      %{"id" => "2", "account" => "2", "category" => "2", "amount" => -800_00, "date" => "2024-01-05"},
      %{"id" => "3", "account" => "2", "category" => "3", "amount" => -300_00, "date" => "2024-01-10"}
    ]

    demo_net_worth = %{
      "2024-01" => %{
        "assets_liquid" => 65000,
        "assets_restricted" => 120000,
        "assets_physical" => 450000,
        "liabilities_physical" => -280000
      },
      "2024-02" => %{
        "assets_liquid" => 66200,
        "assets_restricted" => 122000,
        "assets_physical" => 452000,
        "liabilities_physical" => -278000
      }
    }

    demo_cashflow = %{
      "2024-01" => %{"income" => 8000, "expenses" => 1100, "net" => 6900},
      "2024-02" => %{"income" => 8000, "expenses" => 1050, "net" => 6950}
    }

    Logger.info("Using demo data for dashboard")

    %{state |
      accounts: demo_accounts,
      categories: demo_categories,
      payees: [],
      transactions: demo_transactions,
      net_worth_by_month: demo_net_worth,
      cashflow_by_month: demo_cashflow,
      metrics: %{},
      last_updated: DateTime.utc_now()
    }
  end

  defp default_account_groups do
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
  end
end
