# Python Version Archive

This directory contains the original Python/Dash implementation of the Actual Budget Dashboard.

## Migration Status

✅ **MIGRATED TO PHOENIX/LIVEVIEW**

This Python version has been replaced by a modern Phoenix/LiveView implementation with:

- **Real-time updates** via WebSocket
- **Better performance** with concurrent processing  
- **HTTP API integration** (safer than direct SQLite access)
- **Built-in fault tolerance** with demo data fallback
- **Mobile-responsive design** with Tailwind CSS

## Using This Archive

If you need to reference the original Python implementation:

1. **For comparison**: See `MIGRATION_GUIDE.md` in the root directory
2. **For rollback**: This version can still be run independently
3. **For learning**: Compare financial calculation approaches

## Running the Archived Python Version

```bash
cd archive/python_version
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

**Note**: This requires a SQLite export from Actual Budget in the `data/` directory.

## Key Differences

| Python Version | Phoenix Version |
|---------------|----------------|
| SQLite file access | HTTP API |
| Manual refresh | Real-time updates |
| Single-threaded | Concurrent |
| ~200MB memory | ~50MB memory |
| Page reloads | WebSocket updates |

## Files in Archive

- `app.py` - Entry point
- `requirements.txt` - Python dependencies
- `dashboard/` - Dashboard pages and layouts
- `utils/` - Helper functions and settings
- `data/` - SQLite database location
- `README.md` - Original documentation

## Current Status

**Archived on**: $(date)
**Reason**: Replaced by Phoenix/LiveView implementation
**Recommendation**: Use the Phoenix version in `/actual_dashboard/`

For the modern implementation, see the main Phoenix application.
