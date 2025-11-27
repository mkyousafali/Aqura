# Aqura-tunnel Deployment Guide

## 🚀 Features

### Core Functionality
- ✅ **Secure Login**: Access code-based authentication
- 🔒 **Logout Protection**: Requires access code to close/logout
- 🔄 **Real-time Sync**: Syncs sales data every 10 seconds
- 📊 **Yesterday + Today**: Captures late entries by syncing both days
- 📦 **Historical Data**: One-click sync of all past sales records

### Offline Support (NEW!)
- 🌐 **Automatic Detection**: Detects when internet is unavailable
- 💾 **Local Queue**: Saves data to SQLite database when offline
- 🔄 **Auto-Retry**: Automatically syncs queued data when internet returns
- 📊 **Status Display**: Shows real-time online/offline status
- 🗄️ **Smart Storage**: Queues data locally, auto-cleans after 7 days
- ⏰ **Continuous Operation**: Keeps syncing from ERP even without internet

---

## 📋 Prerequisites

### Server Requirements
- Windows Server 2016 or later / Windows 10/11
- Node.js 18.x or higher
- SQL Server with URBAN2_2025 database
- Network access to 192.168.0.3 (SQL Server)
- Internet connection (for Supabase sync - works offline too!)

### Branch Setup
- Each branch needs their own installation
- SQL Server must be accessible from the server
- Branch must be configured in Supabase `branches` table
- User with access code in Supabase `users` table

---

## 🛠️ Installation Steps

### 1. Copy Files to Server
Copy the entire `AquraTunnel-Deployment` folder to the branch server:
```
C:\AquraTunnel\
```

### 2. Install Dependencies
Open PowerShell **as Administrator** and run:
```powershell
cd C:\AquraTunnel
npm install
```

This will install:
- `mssql` - SQL Server connector
- `@supabase/supabase-js` - Cloud database client
- `better-sqlite3` - Local offline database
- `electron` - Desktop app framework

### 3. Test the Application
```powershell
npm start
```

---

## 🔐 First-Time Configuration

### 1. Login
- Launch the app
- Enter access code: **697073** (or your assigned code)
- Click "Login"

### 2. Configure Connection
- **Branch**: Select your branch from dropdown
- **Server IP**: `192.168.0.3` (or your SQL Server IP)
- **Server Name**: `WIN-D1D6ENB240A` (optional)
- **Database**: `URBAN2_2025`
- **Username**: `sa`
- **Password**: `Polosys*123`

### 3. Test Connection
- Click "🔌 Test Connection"
- Wait for success message
- Click "💾 Save & Continue"

### 4. Sync Historical Data (Optional)
- Click "📦 Sync Historical Data"
- This will import all past sales records
- Takes 5-10 minutes depending on data volume
- Only needed once per installation

### 5. Start Sync Service
- Click "▶️ Start Sync"
- Service will sync every 10 seconds
- Monitor logs at bottom of window

### 6. Enable Auto-Start (Important!)
To ensure the app runs automatically when the server restarts:

**Option 1 - Using UI (Recommended)**:
1. Check the box: "🚀 Start automatically when Windows starts"
2. Confirmation message will appear in logs
3. Done! App will start with Windows

**Option 2 - Using Batch Script**:
1. Right-click `setup-autostart.bat`
2. Select "Run as administrator"
3. Follow on-screen instructions
4. Shortcut created in Windows Startup folder

**Option 3 - Already Enabled**:
- The app automatically enables auto-start on first run
- Verify by checking the checkbox in the UI

**To Disable Auto-Start**:
- Uncheck the box in app UI, OR
- Run `remove-autostart.bat`

---

## 📡 Offline Mode

### How It Works
1. **Normal Operation**: Syncs data from SQL Server → Supabase every 10 seconds
2. **Internet Lost**: Automatically detects and saves data to local SQLite database
3. **Offline Status**: Shows "📡 Offline - Data saved locally" in yellow
4. **Internet Restored**: Automatically processes all queued data and syncs to cloud
5. **Clean Up**: Removes synced records older than 7 days automatically

### Local Database Location
Offline queue stored at:
```
C:\Users\<YourUser>\AppData\Roaming\Aqura-tunnel\aqura-offline.db
```

### Monitoring Queue
The sync logs show:
```
📡 Offline - Syncing... [5 queued]
```
The number shows how many records are waiting to sync.

---

## 🔄 Daily Operations

### Normal Usage
1. **Start App**: Double-click Aqura-tunnel.exe
2. **Login**: Enter your access code
3. **Start Sync**: Click start button (if not auto-started)
4. **Monitor**: Watch sync logs
5. **Leave Running**: Keep app open 24/7

### What Gets Synced
- **Sales Invoices** (VoucherType: SI)
- **Sales Returns** (VoucherType: SR)
- **Net Sales** (Sales - Returns)
- **Bills Count**, **Tax**, **Discounts**

### Sync Frequency
- Every **10 seconds**
- Syncs **today** and **yesterday**
- Catches late entries and corrections

---

## 🛡️ Security Features

### Logout Protection
- Cannot close app by clicking X button
- Must enter access code to logout
- Prevents accidental closure
- Ensures continuous sync operation

### Access Control
- Only authorized users with valid access codes
- Must be active in Supabase users table
- Role-based access (Master Admin, Manager, etc.)

---

## 🐛 Troubleshooting

### Cannot Login
**Error**: "Invalid access code"
- Verify code is correct (697073)
- Check user is active in Supabase
- Verify internet connection

### Cannot Connect to SQL Server
**Error**: "Connection failed"
- Check SQL Server is running
- Verify IP address: `192.168.0.3`
- Ping server: `ping 192.168.0.3`
- Check firewall allows SQL Server port (1433)
- Verify credentials: sa/Polosys*123

### Sync Errors
**Error**: "Sync failed"
- Check internet connection
- If offline: Data saved locally, will sync later
- Check SQL Server accessibility
- Review error message in logs

### Offline Mode Not Working
**Issue**: Data not syncing when internet returns
- Check offline database at: `%APPDATA%\Aqura-tunnel\aqura-offline.db`
- Check logs for "Processing queued records"
- Restart app if stuck
- Check Supabase connection

### App Crashes
- Check Node.js is installed
- Run `npm install` again
- Check error logs
- Restart application

### Auto-Start Not Working
**Issue**: App doesn't start with Windows
- Check the checkbox in app UI
- Verify checkbox is checked
- Run `setup-autostart.bat` as administrator
- Check Windows Startup folder: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`
- Look for `Aqura-tunnel.lnk` shortcut

**Issue**: App starts but doesn't login automatically
- Auto-start only launches the app
- You still need to login with access code
- This is intentional for security

---

## 📊 Monitoring

### Log Messages

**✅ Success**:
```
🌐 Online - Synced in 245ms - Today: 45 bills (12,456.78), Yesterday: 38 bills
```

**📡 Offline**:
```
📡 Offline - Syncing... [3 queued]
📥 Offline mode - data saved locally
```

**🌐 Reconnected**:
```
🌐 Internet restored! Processing queued data...
📤 Processing 15 queued records...
✅ Synced 15/15 queued records
```

### Health Check
- Logs should update every 10 seconds
- Status should show "🌐 Online" when connected
- Queue count should decrease when back online
- No continuous errors

---

## 🔧 Maintenance

### Weekly Tasks
- Check app is running
- Review sync logs for errors
- Verify data is reaching Supabase
- Check offline queue is empty (when online)

### Monthly Tasks
- Check for app updates
- Review error patterns
- Verify historical data is complete
- Clean up old log files

### Backup
- Configuration stored in Supabase
- Offline queue at: `%APPDATA%\Aqura-tunnel\aqura-offline.db`
- Backup offline DB if needed

---

## 🆘 Support

### Contact
- **Developer**: Your IT Department
- **Database**: URBAN2_2025 on 192.168.0.3
- **Cloud**: Supabase (vmypotfsyrvuublyddyt.supabase.co)

### Emergency Recovery
1. Stop the app
2. Delete offline database: `%APPDATA%\Aqura-tunnel\aqura-offline.db`
3. Restart app
4. Run historical sync again

---

## 📝 Notes

### Multiple Branches
- Each branch runs its own instance
- Same access code works for all branches
- Each syncs to its own branch_id
- Data segregated by branch in Supabase

### Network Requirements
- **SQL Server**: Local network (192.168.0.x)
- **Supabase**: Internet (HTTPS)
- **Offline Mode**: Works without internet
- **Auto-Retry**: Reconnects automatically

### Performance
- Uses connection pooling
- Batched updates
- Efficient date-based queries
- Local queue for offline resilience

---

## ✅ Deployment Checklist

- [ ] Node.js installed on server
- [ ] Files copied to C:\AquraTunnel
- [ ] Dependencies installed (`npm install`)
- [ ] SQL Server accessible (ping + test)
- [ ] Branch configured in Supabase
- [ ] Access code verified
- [ ] Test connection successful
- [ ] Historical data synced
- [ ] Sync service started
- [ ] Auto-start enabled (checkbox checked)
- [ ] Logs showing success
- [ ] Offline mode tested (disconnect internet)
- [ ] Auto-reconnect verified
- [ ] Server restart tested (app auto-starts)
- [ ] App stays open 24/7

---

## 🎯 Success Criteria

✅ **App Running**: Process shows in Task Manager
✅ **Auto-Start Enabled**: Checkbox is checked in UI
✅ **Survives Restart**: App launches after Windows reboot
✅ **Logs Active**: Updates every 10 seconds
✅ **Data Flowing**: Bills count changing in Supabase
✅ **Offline Ready**: Queue working when internet down
✅ **Auto-Recovery**: Syncs queued data when reconnected
✅ **Secure**: Cannot close without access code

**Your branch is now connected to Aqura cloud system! 🎉**
