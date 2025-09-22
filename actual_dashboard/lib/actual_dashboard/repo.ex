defmodule ActualDashboard.Repo do
  use Ecto.Repo,
    otp_app: :actual_dashboard,
    adapter: Ecto.Adapters.Postgres
end
