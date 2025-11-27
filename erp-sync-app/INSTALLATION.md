# Aqura-tunnel - Installation Instructions

## ✅ Ready to Deploy!

The **Aqura-tunnel** app is ready in the `win-unpacked` folder.

### 📦 Files to Copy

Copy the entire **`win-unpacked`** folder to your server.

### 🚀 Installation Steps

1. **Copy** the `win-unpacked` folder to your SQL Server PC (e.g., `C:\Aqura-tunnel\`)

2. **Run** `Aqura-tunnel.exe` or double-click `Run-Aqura-tunnel.bat`

3. **Login** with your Aqura credentials

4. **Configure**:
   - Select branch
   - Enter server IP (e.g., `192.168.0.3`)
   - Enter server name  
   - Enter database name (e.g., `URBAN2_2025`)
   - Enter SQL Server username/password
   
5. **Test Connection** to verify

6. **Save Configuration** (saves to Supabase)

7. **Start Sync** - automatically syncs every 1 minute

### ✨ What It Does

- Connects to local SQL Server
- Gets sales data every 1 minute
- Pushes to Supabase `erp_daily_sales` table
- Shows real-time sync logs
- Your Aqura PWA reads from Supabase

### 📂 Folder Structure

```
win-unpacked/
├── Aqura-tunnel.exe  ← Main executable
├── Run-Aqura-tunnel.bat  ← Quick launcher
├── resources/
├── locales/
└── ... (electron files)
```

### 💡 Tips

- Keep the app running for continuous sync
- Check the logs to see sync status
- Configure Windows to auto-start the app on boot (optional)

### 🔧 Troubleshooting

If connection fails:
- Check SQL Server is running
- Verify SQL Server allows remote connections
- Check firewall settings
- Confirm server IP is correct (use local IP like 192.168.x.x)
