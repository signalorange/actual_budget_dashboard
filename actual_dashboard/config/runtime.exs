import Config

# Runtime configuration - this is evaluated when the app starts
if config_env() == :dev do
  config :actual_dashboard,
    api_base_url: System.get_env("ACTUAL_HTTP_API_URL", "http://localhost:5007"),
    api_key: System.get_env("ACTUAL_HTTP_API_KEY", "demo_key_12345"),
    budget_sync_id: System.get_env("ACTUAL_BUDGET_SYNC_ID", "demo_sync_id")
end
