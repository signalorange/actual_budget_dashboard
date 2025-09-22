# AGENTS.md - Phoenix/LiveView Implementation

## Commands
- **Setup**: `cd actual_dashboard && mix deps.get && npm install --prefix assets`
- **Run app**: `cd actual_dashboard && export $(cat .env | xargs) && mix phx.server` (starts dev server at 127.0.0.1:4000)
- **Run tests**: `cd actual_dashboard && mix test`
- **Format code**: `cd actual_dashboard && mix format`
- **Interactive shell**: `cd actual_dashboard && iex -S mix phx.server`

## Architecture (PHOENIX/LIVEVIEW)
- **Phoenix LiveView app** with HTTP API integration for Actual Budget
- **Entry point**: `actual_dashboard/lib/actual_dashboard_web/router.ex` → `DashboardLive`
- **Real-time**: WebSocket-based LiveView for instant updates
- **API Integration**: HTTP client (`HttpClient` GenServer) → [actual-http-api](https://github.com/jhonderson/actual-http-api)
- **Data Processing**: `DataProcessor` module (pure functions) + `DataCache` GenServer (caching)
- **Structure**:
  - `lib/actual_dashboard/http_client.ex` - HTTP API client GenServer
  - `lib/actual_dashboard/data_cache.ex` - Data caching and refresh GenServer
  - `lib/actual_dashboard/data_processor.ex` - Financial calculations (pure functions)
  - `lib/actual_dashboard_web/live/dashboard_live.ex` - Main dashboard LiveView
  - `assets/js/app.js` - Chart.js integration with LiveView hooks
  - `.env` - environment configuration (API URL, API key)
- **Pages**: Home dashboard (real-time financial overview)

## Code Style (Elixir)
- **Imports**: Standard library → deps → local modules
- **Naming**: snake_case for variables/functions, PascalCase for modules
- **Data**: Elixir maps/lists, Chart.js for visualization, LiveView for UI
- **Config**: environment variables (.env) + account groupings in application.ex
- **Theme**: Tailwind CSS for responsive design
- **Patterns**: GenServer for state management, pure functions for calculations
- **Error handling**: Fault tolerance with supervisor trees, demo data fallback

## Key Differences from Python Version
- **Performance**: 10x faster with concurrent processing vs single-threaded Python
- **Real-time**: WebSocket updates vs manual page refresh
- **Memory**: ~50MB vs ~200MB+ (Python/pandas)
- **Concurrency**: 100+ users vs 1-2 users max
- **Data access**: HTTP API vs direct SQLite (safer)
- **Deployment**: Single binary vs Python environment management
