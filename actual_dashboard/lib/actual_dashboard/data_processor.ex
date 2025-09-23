defmodule ActualDashboard.DataProcessor do
  @moduledoc """
  Data processing for financial calculations and metrics
  """

  require Logger

  @doc """
  Process transactions by month for account groups
  """
  def process_transactions_by_month(transactions, accounts, account_groups) do
    # Convert transactions to a map for easier processing
    account_map = accounts |> Enum.into(%{}, fn acc -> {acc["id"], acc} end)
    
    transactions
    |> Enum.filter(fn tx -> tx["account"] end)
    |> Enum.group_by(fn tx -> 
      date = parse_date(tx["date"])
      "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
    end)
    |> Enum.into(%{}, fn {month, txs} ->
      {month, process_month_transactions(txs, account_map, account_groups)}
    end)
  end

  @doc """
  Calculate net worth by month using account groups
  """
  def calculate_net_worth_by_month(transactions, accounts, account_groups) do
    account_map = accounts |> Enum.into(%{}, fn acc -> {acc["id"], acc} end)
    
    # Get all months from transactions
    months = get_months_from_transactions(transactions)
    
    months
    |> Enum.map(fn month ->
      {month, calculate_month_net_worth(transactions, month, account_map, account_groups)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Calculate cash flow by month
  """
  def calculate_cashflow_by_month(transactions, categories) do
    category_map = categories |> Enum.into(%{}, fn cat -> {cat["id"], cat} end)
    
    transactions
    |> Enum.filter(fn tx -> tx["category"] && is_nil(tx["transfer_id"]) end)
    |> Enum.group_by(fn tx ->
      date = parse_date(tx["date"])
      "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
    end)
    |> Enum.into(%{}, fn {month, txs} ->
      {month, process_cashflow_for_month(txs, category_map)}
    end)
  end

  @doc """
  Calculate financial metrics
  """
  def calculate_metrics(net_worth_data, cashflow_data) do
    months = Map.keys(cashflow_data) |> Enum.sort()
    
    %{
      "savings_rate" => calculate_savings_rate(cashflow_data, months),
      "withdrawal_rate" => calculate_withdrawal_rate(net_worth_data, cashflow_data, months),
      "savings_multiple" => calculate_savings_multiple(net_worth_data, cashflow_data, months)
    }
  end

  ## Private Functions

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> 
        # Try parsing YYYYMMDD format (from direct SQLite)
        case String.length(date_string) do
          8 -> 
            year = String.slice(date_string, 0, 4) |> String.to_integer()
            month = String.slice(date_string, 4, 2) |> String.to_integer()
            day = String.slice(date_string, 6, 2) |> String.to_integer()
            Date.new!(year, month, day)
          _ -> Date.utc_today()
        end
    end
  end

  defp parse_date(_), do: Date.utc_today()

  defp process_month_transactions(transactions, account_map, account_groups) do
    # Group transactions by account groups
    Enum.reduce(account_groups, %{}, fn {group_name, account_names}, acc ->
      group_accounts = get_accounts_by_names(account_map, account_names)
      group_account_ids = MapSet.new(group_accounts, fn acc -> acc["id"] end)
      
      group_transactions = Enum.filter(transactions, fn tx -> 
        MapSet.member?(group_account_ids, tx["account"])
      end)
      
      total_amount = Enum.reduce(group_transactions, 0, fn tx, sum ->
        sum + (tx["amount"] || 0)
      end)
      
      Map.put(acc, group_name, %{
        "transactions" => group_transactions,
        "total" => total_amount / 100  # Convert from cents
      })
    end)
  end

  defp calculate_month_net_worth(transactions, month, account_map, account_groups) do
    # Filter transactions up to this month
    month_date = parse_month(month)
    
    relevant_transactions = Enum.filter(transactions, fn tx ->
      tx_date = parse_date(tx["date"])
      Date.compare(tx_date, month_date) != :gt
    end)
    
    Enum.reduce(account_groups, %{}, fn {group_name, account_names}, acc ->
      group_accounts = get_accounts_by_names(account_map, account_names)
      group_account_ids = MapSet.new(group_accounts, fn acc -> acc["id"] end)
      
      group_balance = Enum.reduce(relevant_transactions, 0, fn tx, sum ->
        if MapSet.member?(group_account_ids, tx["account"]) do
          sum + (tx["amount"] || 0)
        else
          sum
        end
      end)
      
      Map.put(acc, group_name, group_balance / 100)
    end)
  end

  defp process_cashflow_for_month(transactions, category_map) do
    {income, expenses} = Enum.reduce(transactions, {0, 0}, fn tx, {inc_acc, exp_acc} ->
      amount = (tx["amount"] || 0) / 100
      category = Map.get(category_map, tx["category"], %{})
      
      # Skip transfer transactions
      if tx["transfer_id"] do
        {inc_acc, exp_acc}
      else
        if Map.get(category, "is_income", false) do
          {inc_acc + amount, exp_acc}
        else
          {inc_acc, exp_acc + amount}
        end
      end
    end)
    
    %{
      "income" => income,
      "expenses" => abs(expenses),  # Make expenses positive for calculations
      "net" => income + expenses
    }
  end

  defp calculate_savings_rate(cashflow_data, months) do
    months
    |> Enum.map(fn month ->
      case Map.get(cashflow_data, month) do
        %{"income" => income, "expenses" => expenses} when income > 0 ->
          (income - expenses) / income
        _ -> 0.0
      end
    end)
    |> Enum.reverse()  # Most recent first for display
  end

  defp calculate_withdrawal_rate(net_worth_data, cashflow_data, months) do
    months
    |> Enum.map(fn month ->
      case {Map.get(net_worth_data, month), Map.get(cashflow_data, month)} do
        {nw, %{"expenses" => expenses}} when is_map(nw) ->
          total_assets = calculate_total_assets(nw)
          if total_assets > 0, do: expenses / total_assets, else: 0.0
        _ -> 0.0
      end
    end)
    |> Enum.reverse()
  end

  defp calculate_savings_multiple(net_worth_data, cashflow_data, months) do
    months
    |> Enum.map(fn month ->
      case {Map.get(net_worth_data, month), Map.get(cashflow_data, month)} do
        {nw, %{"expenses" => expenses}} when is_map(nw) and expenses > 0 ->
          total_assets = calculate_total_assets(nw)
          total_assets / (expenses * 12)  # Years of expenses covered
        _ -> 0.0
      end
    end)
    |> Enum.reverse()
  end

  defp calculate_total_assets(net_worth_month) do
    net_worth_month
    |> Enum.reduce(0, fn {group_name, value}, acc ->
      if String.starts_with?(group_name, "assets_") do
        acc + value
      else
        acc
      end
    end)
  end

  defp get_accounts_by_names(account_map, account_names) do
    account_map
    |> Map.values()
    |> Enum.filter(fn acc -> 
      Enum.member?(account_names, acc["name"])
    end)
  end

  defp get_months_from_transactions(transactions) do
    transactions
    |> Enum.map(fn tx ->
      date = parse_date(tx["date"])
      "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp parse_month(month_string) do
    [year, month] = String.split(month_string, "-")
    Date.new!(String.to_integer(year), String.to_integer(month), 1)
  end
end
