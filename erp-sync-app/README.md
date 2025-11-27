# Aqura-tunnel - Windows Desktop App

This is a standalone Windows desktop application that syncs sales data from SQL Server to Supabase.

## Features

✅ Login with Aqura credentials
✅ Select branch from Supabase
✅ Configure SQL Server connection (IP, database, credentials)
✅ Test SQL Server connection
✅ Auto-sync every 1 minute
✅ Save configuration to Supabase `erp_connections` table
✅ Update `erp_daily_sales` table in Supabase
✅ Real-time sync logs
✅ Start/Stop sync service

## Installation

### For Development:

```bash
cd erp-sync-app
npm install
npm start
```

### Build Installer:

```bash
npm run build
```

This will create an installer in `dist/` folder.

## Usage

1. **Install the app** on the Windows PC where SQL Server is running
2. **Login** with your Aqura credentials
3. **Configure** the ERP connection:
   - Select branch
   - Enter server IP (local IP like 192.168.0.3)
   - Enter server name
   - Enter database name
   - Enter SQL Server username/password
4. **Test connection** to verify
5. **Save** configuration (saves to Supabase)
6. **Start sync** - runs every 1 minute automatically
7. **Check logs** to see sync status

## How It Works

1. App connects to local SQL Server
2. Queries sales data (SI vouchers) and returns (SR vouchers)
3. Calculates net sales
4. Pushes to Supabase `erp_daily_sales` table
5. Aqura frontend reads from this table

## Requirements

- Windows 10/11
- SQL Server with network access enabled
- Internet connection to reach Supabase
- Aqura user account
