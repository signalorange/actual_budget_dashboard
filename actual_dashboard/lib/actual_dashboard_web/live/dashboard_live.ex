defmodule ActualDashboardWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView showing financial overview
  """
  use ActualDashboardWeb, :live_view
  
  alias ActualDashboard.DataCache
  require Logger

  @refresh_interval :timer.seconds(30)

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Set up automatic refresh
      :timer.send_interval(@refresh_interval, self(), :refresh_data)
    end

    {:ok, load_dashboard_data(socket)}
  end

  def handle_info(:refresh_data, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  def handle_event("refresh", _params, socket) do
    DataCache.refresh_data()
    {:noreply, put_flash(socket, :info, "Data refreshed successfully")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white shadow">
        <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center">
            <h1 class="text-3xl font-bold text-gray-900">
              Financial Dashboard
            </h1>
            <div class="flex items-center space-x-4">
              <span class="text-sm text-gray-500">
                Last updated: <%= format_datetime(@last_updated) %>
              </span>
              <button
                phx-click="refresh"
                class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
              >
                Refresh
              </button>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div class="px-4 py-6 sm:px-0">
          
          <!-- Summary Cards -->
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
            <.summary_card 
              title="Total Assets" 
              value={@current_assets} 
              change={@assets_change}
              color="green"
              is_percentage={false}
            />
            <.summary_card 
              title="Total Debts" 
              value={@current_debts} 
              change={@debts_change}
              color="red"
              is_percentage={false}
            />
            <.summary_card 
              title="Net Worth" 
              value={@current_net_worth} 
              change={@net_worth_change}
              color="blue"
              is_percentage={false}
            />
            <.summary_card 
              title="Savings Rate" 
              value={@current_savings_rate} 
              change={@savings_rate_change}
              color="purple"
              is_percentage={true}
            />
          </div>

          <!-- Charts Row -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Net Worth Chart -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-6">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Net Worth Over Time</h3>
                <div id="net-worth-chart" phx-hook="NetWorthChart" data-chart-data={Jason.encode!(@net_worth_chart_data)} style="height: 400px;"></div>
              </div>
            </div>

            <!-- Cash Flow Chart -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-6">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Monthly Cash Flow</h3>
                <div id="cashflow-chart" phx-hook="CashFlowChart" data-chart-data={Jason.encode!(@cashflow_chart_data)} style="height: 400px;"></div>
              </div>
            </div>
          </div>

          <!-- Account Groups -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Account Groups</h3>
              <.account_groups_table account_groups={@account_group_balances} />
            </div>
          </div>

        </div>
      </main>
    </div>
    """
  end

  # Summary Card Component
  defp summary_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class={[
              "w-8 h-8 rounded-full flex items-center justify-center",
              get_color_classes(@color)
            ]}>
              <.icon name={get_icon_name(@title)} class="h-5 w-5 text-white" />
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                <%= @title %>
              </dt>
              <dd class="flex items-baseline">
                <div class="text-2xl font-semibold text-gray-900">
                  <%= if @is_percentage do %>
                    <%= format_percentage(@value) %>
                  <% else %>
                    <%= format_currency(@value) %>
                  <% end %>
                </div>
                <%= if @change do %>
                  <div class={[
                    "ml-2 flex items-baseline text-sm font-semibold",
                    if(@change >= 0, do: "text-green-600", else: "text-red-600")
                  ]}>
                    <%= if @change >= 0, do: "+", else: "" %><%= format_currency(@change) %>
                  </div>
                <% end %>
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Account Groups Table Component
  defp account_groups_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Account Group
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Current Balance
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Monthly Change
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for {group_name, balance} <- @account_groups do %>
            <tr>
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                <%= humanize_group_name(group_name) %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <%= format_currency(balance) %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <!-- TODO: Add monthly change calculation -->
                --
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  ## Private Functions

  defp load_dashboard_data(socket) do
    data = DataCache.get_dashboard_data()
    
    # Calculate current values from latest month
    latest_net_worth = get_latest_month_data(data.net_worth_by_month)
    latest_cashflow = get_latest_month_data(data.cashflow_by_month)
    
    current_assets = calculate_total_assets(latest_net_worth)
    current_debts = calculate_total_debts(latest_net_worth) 
    current_net_worth = current_assets + current_debts
    current_savings_rate = Map.get(latest_cashflow, "income", 0) |> calculate_current_savings_rate(Map.get(latest_cashflow, "expenses", 0))

    # Prepare chart data
    net_worth_chart_data = prepare_net_worth_chart_data(data.net_worth_by_month)
    cashflow_chart_data = prepare_cashflow_chart_data(data.cashflow_by_month)
    
    # Account group balances
    account_group_balances = latest_net_worth || %{}

    socket
    |> assign(:last_updated, data.last_updated)
    |> assign(:current_assets, current_assets)
    |> assign(:current_debts, current_debts)  
    |> assign(:current_net_worth, current_net_worth)
    |> assign(:current_savings_rate, current_savings_rate)
    |> assign(:assets_change, nil)  # TODO: Calculate changes
    |> assign(:debts_change, nil)
    |> assign(:net_worth_change, nil)
    |> assign(:savings_rate_change, nil)
    |> assign(:net_worth_chart_data, net_worth_chart_data)
    |> assign(:cashflow_chart_data, cashflow_chart_data)
    |> assign(:account_group_balances, account_group_balances)
  end

  defp get_latest_month_data(data) when is_map(data) do
    data
    |> Map.keys()
    |> Enum.sort(:desc)
    |> List.first()
    |> then(fn month -> if month, do: Map.get(data, month), else: %{} end)
  end
  defp get_latest_month_data(_), do: %{}

  defp calculate_total_assets(net_worth_month) when is_map(net_worth_month) do
    net_worth_month
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "assets_") end)
    |> Enum.reduce(0, fn {_key, value}, acc -> acc + (value || 0) end)
  end
  defp calculate_total_assets(_), do: 0

  defp calculate_total_debts(net_worth_month) when is_map(net_worth_month) do
    net_worth_month
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "liabilities_") end)
    |> Enum.reduce(0, fn {_key, value}, acc -> acc + (value || 0) end)
  end
  defp calculate_total_debts(_), do: 0

  defp calculate_current_savings_rate(income, expenses) when income > 0 do
    (income - expenses) / income
  end
  defp calculate_current_savings_rate(_, _), do: 0.0

  defp prepare_net_worth_chart_data(net_worth_by_month) when is_map(net_worth_by_month) do
    months = Map.keys(net_worth_by_month) |> Enum.sort()
    
    %{
      labels: months,
      datasets: [
        %{
          label: "Assets",
          data: Enum.map(months, fn month ->
            calculate_total_assets(Map.get(net_worth_by_month, month, %{}))
          end),
          backgroundColor: "rgba(34, 197, 94, 0.8)",
          borderColor: "rgba(34, 197, 94, 1)"
        },
        %{
          label: "Debts",  
          data: Enum.map(months, fn month ->
            calculate_total_debts(Map.get(net_worth_by_month, month, %{}))
          end),
          backgroundColor: "rgba(239, 68, 68, 0.8)",
          borderColor: "rgba(239, 68, 68, 1)"
        }
      ]
    }
  end
  defp prepare_net_worth_chart_data(_), do: %{labels: [], datasets: []}

  defp prepare_cashflow_chart_data(cashflow_by_month) when is_map(cashflow_by_month) do
    months = Map.keys(cashflow_by_month) |> Enum.sort()
    
    %{
      labels: months,
      datasets: [
        %{
          label: "Income",
          data: Enum.map(months, fn month ->
            Map.get(cashflow_by_month, month, %{}) |> Map.get("income", 0)
          end),
          backgroundColor: "rgba(34, 197, 94, 0.8)"
        },
        %{
          label: "Expenses",
          data: Enum.map(months, fn month ->
            Map.get(cashflow_by_month, month, %{}) |> Map.get("expenses", 0)
          end),
          backgroundColor: "rgba(239, 68, 68, 0.8)"
        }
      ]
    }
  end
  defp prepare_cashflow_chart_data(_), do: %{labels: [], datasets: []}

  defp format_currency(amount) when is_number(amount) do
    # Convert to float if it's an integer
    float_amount = if is_integer(amount), do: amount / 1.0, else: amount
    
    :erlang.float_to_binary(float_amount, decimals: 2)
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
    |> then(fn str -> "$#{str}" end)
  end
  defp format_currency(_), do: "$0.00"

  defp format_percentage(rate) when is_number(rate) do
    percentage = rate * 100
    :erlang.float_to_binary(percentage, decimals: 1) <> "%"
  end
  defp format_percentage(_), do: "0.0%"

  defp format_datetime(nil), do: "Never"
  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp humanize_group_name(group_name) do
    group_name
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_color_classes("green"), do: "bg-green-500"
  defp get_color_classes("red"), do: "bg-red-500" 
  defp get_color_classes("blue"), do: "bg-blue-500"
  defp get_color_classes("purple"), do: "bg-purple-500"
  defp get_color_classes(_), do: "bg-gray-500"

  defp get_icon_name("Total Assets"), do: "hero-banknotes"
  defp get_icon_name("Total Debts"), do: "hero-credit-card"
  defp get_icon_name("Net Worth"), do: "hero-chart-bar"
  defp get_icon_name("Savings Rate"), do: "hero-arrow-trending-up"
  defp get_icon_name(_), do: "hero-currency-dollar"
end
