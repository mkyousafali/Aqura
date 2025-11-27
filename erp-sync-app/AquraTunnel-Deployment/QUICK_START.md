# 🚀 Aqura-tunnel Quick Start Guide

## 📥 Installation (5 minutes)

1. **Copy folder** to server: `C:\AquraTunnel`
2. **Install dependencies**:
   ```
   cd C:\AquraTunnel
   npm install
   ```
3. **Launch**: `npm start` or double-click `Aqura-tunnel.exe`

---

## 🔐 First Login

1. Enter access code: **697073**
2. Click "Login"

---

## ⚙️ Configuration

**SQL Server Settings:**
- Server IP: `192.168.0.3`
- Database: `URBAN2_2025`
- Username: `sa`
- Password: `Polosys*123`

**Steps:**
1. Select your branch
2. Enter SQL Server details
3. Click "Test Connection" ✅
4. Click "Save & Continue"

---

## 🔄 Start Syncing

1. **(Optional)** Click "Sync Historical Data" - imports all past sales
2. Click "▶️ Start Sync"
3. **✅ Check the box**: "Start automatically when Windows starts"
4. Monitor logs at bottom

---

## 🎯 What Gets Synced

✅ Sales Invoices (SI)
✅ Sales Returns (SR)  
✅ Net Sales (Sales - Returns)
✅ Every **10 seconds**
✅ Today + Yesterday

---

## 📡 Offline Mode

**Internet Down?** No problem!
- Status shows: "📡 Offline"
- Data saved locally
- Auto-syncs when internet returns
- Shows queue count: `[5 queued]`

---

## 🚀 Auto-Start Setup

**Why?** App must run 24/7 for real-time sync

**How to Enable:**
1. ☑️ Check the box in app UI, OR
2. Run `setup-autostart.bat`

**How to Disable:**
1. ☐ Uncheck the box in app UI, OR
2. Run `remove-autostart.bat`

**Test:**
- Restart server
- App should auto-launch
- Login with access code
- Start sync again

---

## 🔒 Security

**Logout Protection:**
- Cannot close with X button
- Must enter access code to logout
- Prevents accidental closure
- Keeps sync running 24/7

---

## 🐛 Quick Troubleshooting

### Cannot Login
- Check access code is correct
- Verify internet connection
- Check user is active in system

### Cannot Connect to SQL Server
```
ping 192.168.0.3
```
- Check server is running
- Verify IP address
- Check firewall settings

### Sync Not Starting
- Check SQL Server connection
- Verify branch selected
- Check internet for cloud sync
- Review error logs

### Auto-Start Not Working
- Check the checkbox is ✅
- Run `setup-autostart.bat`
- Check Startup folder:
  ```
  %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
  ```

---

## 📊 Monitoring

**Healthy Operation:**
```
[10:15:23] 🌐 Online - Syncing 2025-11-27 and 2025-11-26...
[10:15:23] ✅ Synced in 234ms - Today: 45 bills (12,456.78)
```

**Offline Operation:**
```
[10:15:33] 📡 Offline - Syncing... [3 queued]
[10:15:33] 📥 Offline mode - data saved locally
```

**Recovery:**
```
[10:16:15] 🌐 Internet restored! Processing queued data...
[10:16:16] ✅ Synced 15/15 queued records
```

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `Aqura-tunnel.exe` | Main application |
| `setup-autostart.bat` | Enable auto-start |
| `remove-autostart.bat` | Disable auto-start |
| `DEPLOYMENT_GUIDE.md` | Full documentation |

**Offline Database:**
```
%APPDATA%\Aqura-tunnel\aqura-offline.db
```

---

## ✅ Daily Checklist

- [ ] App is running (check Task Manager)
- [ ] Status shows "🌐 Online"
- [ ] Logs updating every 10 seconds
- [ ] No error messages
- [ ] Queue count is 0 (when online)

---

## 🆘 Emergency Reset

1. Stop the app
2. Delete offline database:
   ```
   %APPDATA%\Aqura-tunnel\aqura-offline.db
   ```
3. Restart app
4. Re-login
5. Reconfigure
6. Start sync
7. Enable auto-start

---

## 📞 Support

**Common Issues:**
- ❌ Can't login → Check access code
- ❌ Can't connect → Check SQL Server
- ❌ Won't close → Enter access code
- ❌ Won't auto-start → Check checkbox

**Need Help?**
- Review full guide: `DEPLOYMENT_GUIDE.md`
- Check error logs in app
- Verify all settings

---

## 🎯 Remember

1. ✅ App runs on **Windows startup** (if enabled)
2. ✅ Syncs **every 10 seconds**
3. ✅ Works **offline** (saves to queue)
4. ✅ Requires **access code** to close
5. ✅ Syncs **today + yesterday**
6. ✅ Must **login after auto-start**

---

**Your branch is now syncing to Aqura cloud! 🎉**

*For detailed information, see DEPLOYMENT_GUIDE.md*
