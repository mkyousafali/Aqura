# 🔄 Local Branch Sync System - Complete Setup Guide

## Overview

This system enables syncing Aqura branches on your local network without requiring direct cloud-to-local network connectivity. It consists of three components that work together:

1. **Sync Service** (`local-sync-service.js`) - Node.js service running on your PC
2. **Desktop App** (`local-branch-sync/`) - Electron GUI for managing syncs
3. **Frontend Integration** (StorageManager) - Automatic detection and usage

## Architecture

```
┌─────────────────────┐
│   Cloud Server      │
│  8.213.42.21        │
│  (PostgreSQL)       │
└──────────┬──────────┘
           │ (Internet)
           │ SSH/SCP
           │
┌──────────▼──────────┐
│   Your PC (You)     │  ← Runs This System
│  192.168.0.163      │
│  ┌─────────────────┐│
│  │ Node Sync Svc   ││ Listens on localhost:3333
│  │ (IPC Bridge)    ││
│  └─────────────────┘│
│  ┌─────────────────┐│
│  │ Electron App    ││ Manual sync control
│  │ (GUI)           ││
│  └─────────────────┘│
└──────────┬──────────┘
           │ (Local Network)
           │ SSH/SCP 
           │
┌──────────▼──────────┐
│  Branch Server      │
│  192.168.0.101+     │
│  (PostgreSQL)       │
└─────────────────────┘
```

## System Components

### 1. Sync Service (`local-sync-service.js`)

**What it does:**
- Acts as intermediary between cloud and branch servers
- Downloads database dumps from cloud
- Uploads dumps to local branch
- Manages the 6-step sync process
- Streams progress via Server-Sent Events (SSE)

**How to run:**
```bash
cd D:\Aqura\scripts
node local-sync-service.js
```

**Expected output:**
```
[2026-03-05T17:30:45.123Z] 🚀 Local Sync Service started on http://localhost:3333
[2026-03-05T17:30:45.456Z] 📍 This service runs on your PC (192.168.0.163)
[2026-03-05T17:30:45.789Z] 🔄 Syncs between: Cloud (8.213.42.21) → PC → Local Branch (192.168.0.101)
[2026-03-05T17:30:45.890Z] 📡 Endpoint: POST http://localhost:3333/api/sync-branch
```

**API Endpoints:**

- `GET http://localhost:3333/health` - Health check
- `POST http://localhost:3333/api/sync-branch` - Start sync (JSON: `{branchIP}`)

### 2. Desktop App (`local-branch-sync/`)

**What it does:**
- Provides GUI for managing branch syncs
- Auto-detects if sync service is running
- Shows real-time sync progress
- Displays network architecture
- Logs all sync operations

**How to run:**

Option A - Quick Start (Windows):
```bash
cd D:\Aqura\scripts\local-branch-sync
start.bat
```

Option B - Quick Start (macOS/Linux):
```bash
cd D:\Aqura\scripts\local-branch-sync
bash start.sh
```

Option C - Manual:
```bash
cd D:\Aqura\scripts\local-branch-sync
npm install
npm start
```

**Features:**
- Service status indicator (green = ready)
- Branch IP input field
- Real-time progress bar (0-100%)
- Detailed sync log with timestamps
- Network diagram showing data flow

### 3. Frontend Integration (StorageManager.svelte)

**How it works:**
1. User clicks "Syncing..." in StorageManager
2. Frontend checks if local sync service is available (localhost:3333)
3. If **available**: Uses local service (🖥️ faster, no cloud intermediary)
4. If **unavailable**: Falls back to cloud service (☁️ slower)

**Code snippet:**
```typescript
const healthCheck = await fetch('http://localhost:3333/health', { 
  signal: AbortSignal.timeout(3000)
});
if (healthCheck.ok) {
  syncEndpoint = 'http://localhost:3333/api/sync-branch';
  syncMethod = 'local_pc';
}
```

## Complete Setup Walkthrough

### Step 1: Verify SSH Configuration

Make sure your SSH keys are configured for both hosts:

```bash
# Test cloud connectivity
ssh root@8.213.42.21 "echo 'Cloud SSH works'"

# Test branch connectivity  
ssh u@192.168.0.101 "echo 'Branch SSH works'"
```

### Step 2: Update .gitignore

✅ Already done - `scripts/local-branch-sync/` is ignored

### Step 3A: Start with Launcher (Easiest for Windows)

Simply double-click one of these files in `scripts/local-branch-sync/`:

**Option 1 - With Console (Good for troubleshooting):**
```
launcher.bat
```

**Option 2 - Without Console (Cleaner):**
```
launcher.vbs
```

Both will automatically:
1. ✅ Check Node.js is installed
2. ✅ Start sync service on localhost:3333
3. ✅ Launch the Electron app
4. ✅ Show progress messages

**Expected output:**
```
🚀 Local Branch Sync Launcher
═════════════════════════════════════
✅ Node.js vX.X.X
✅ Sync service found
✅ Sync service ready
✅ Electron app ready
```

### Step 3B: Or Start Manually (If launcher doesn't work)

**Terminal 1 - Sync Service:**
```bash
cd D:\Aqura\scripts
node local-sync-service.js
```

**Terminal 2 - Desktop App:**
```bash
cd D:\Aqura\scripts\local-branch-sync
npm install  # First time only
npm start
```

## 6-Step Sync Process

When you click sync, here's what happens:

```
[1/6] 📦 Create database dump on cloud
      └─ Cloud creates 68MB .dump file
      
[2/6] ⬇️ Download dump from cloud to PC
      └─ PC downloads 68MB (takes ~1 min)
      
[3/6] ⬆️ Upload dump from PC to branch  
      └─ PC uploads 68MB to 192.168.0.101 (takes ~6 min)
      
[4/6] 🔄 Restore database on branch
      └─ Branch restores into PostgreSQL (takes ~2-5 min)
      
[5/6] 🔧 Reset sequences & reload schema
      └─ Ensures new records get correct IDs
      
[6/6] 🧹 Cleanup temporary files
      └─ All temp files deleted everywhere
```

**Total time: ~10-15 minutes depending on network speed**

## Monitoring & Debugging

### Check Sync Service

```bash
# Health check
curl http://localhost:3333/health

# Expected response:
# {"status":"ok","service":"Local Sync Service","endpoint":"http://localhost:3333/api/sync-branch"}
```

### View Sync Service Logs

Keep the Terminal 1 window open to see all sync operations:
- Connection attempts
- SCP transfers
- SSH commands
- Error messages
- Cleanup operations

### View Desktop App Logs

Press **F12** in the Electron window to open developer console:
- Renderer process logs
- IPC communication
- Network requests
- Frontend errors

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Service not running" | Sync service crashed | Check Terminal 1 for errors, restart with `node local-sync-service.js` |
| "Connection timeout" | Wrong branch IP | Double-check IP, try ping: `ping 192.168.0.101` |
| "Permission denied" | SSH key issues | Verify SSH key works: `ssh u@192.168.0.101 "id"` |
| "Stuck on upload" | Network too slow | Check network speed, close other downloads |
| "Restore failed" | Disk space | Check branch has >100GB free: `df -h` |

## File Structure

```
D:\Aqura\
├── scripts/
│   ├── local-sync-service.js        (← Start this first!)
│   └── local-branch-sync/           (← Then this!)
│       ├── main.js                  (Electron main)
│       ├── preload.js               (IPC bridge)
│       ├── package.json
│       ├── start.bat                (Windows quick start)
│       ├── start.sh                 (Mac/Linux quick start)
│       ├── README.md                (App-specific docs)
│       └── src/
│           ├── index.html
│           ├── renderer.js
│           └── style.css
├── .gitignore                       (includes scripts/local-branch-sync/)
├── frontend/
│   └── src/lib/components/
│       └── desktop-interface/
│           └── settings/
│               └── StorageManager.svelte  (auto-detects local service)
└── ...
```

## Running the Complete System

### Quick Start (All steps)

**Single Click (Recommended):**
```bash
# In Windows Explorer, navigate to:
D:\Aqura\scripts\local-branch-sync\

# Double-click one of:
launcher.vbs    (no console window - cleaner)
  OR
launcher.bat    (shows console - good for debugging)
```

**From Command Line:**
```bash
cd D:\Aqura\scripts\local-branch-sync
npm start
```

Now you have:
- ✅ Sync service listening on localhost:3333
- ✅ Desktop app showing status
- ✅ Ready to sync branches

### Accessing Different Ways

1. **Desktop App Launcher (Recommended)**
   - Double-click `launcher.vbs` (no console) or `launcher.bat` (with console)
   - Automatically starts both sync service and app
   - GUI-based, easy to use
   - Keeps history in logs

2. **Command Line**
   - `npm start` (from local-branch-sync folder)
   - Shows full progress output
   - Good for automation/debugging

3. **Frontend Integration (Optional)**
   - http://localhost:5173
   - STORAGE tab → BRANCH SYNC section
   - Auto-detects local service
   - Shows within Aqura admin interface

4. **Desktop Shortcut**
   - Run `create-shortcut.bat` to create a desktop icon
   - Pin to Start Menu or Taskbar
   - Share via network

## Creating a Windows .EXE Executable

If you want a standalone `.exe` file to distribute:

### Method 1: Using Electron Builder (Recommended)

Creates a full installer and portable executable:

```bash
cd D:\Aqura\scripts\local-branch-sync
npm run build
```

Creates:
- `dist/Local Branch Sync Setup.exe` - NSIS installer (~200MB)
- `dist/Local Branch Sync.exe` - Portable executable

### Method 2: Using pkg (Lightweight Launcher)

Creates a smaller standalone launcher exe:

```bash
# Install pkg globally (one time)
npm install -g pkg

# Build exe from launcher.js
pkg launcher.js --output Local-Branch-Sync.exe
```

Results:
- Single executable (~40MB)
- No installation needed
- Works on any Windows machine with Node.js

### Method 3: VBS Online Converter

Convert `launcher.vbs` to exe without installing tools:

1. Go to https://www.vb2exe.com/
2. Upload `scripts/local-branch-sync/launcher.vbs`
3. Download the generated `.exe`
4. Place back in `scripts/local-branch-sync/`

### Method 4: Create Desktop Shortcut

Simplest option - create a shortcut without exe:

```bash
cd D:\Aqura\scripts\local-branch-sync
create-shortcut.bat
```

Automatically creates: `C:\Users\<YourName>\Desktop\Local Branch Sync.lnk`

You can then:
- Pin to Start Menu (right-click → Pin to Start)
- Pin to Taskbar (right-click → Pin to Taskbar)
- Share the shortcut file via network
- Double-click to run anytime

## Important Notes

⚠️ **CRITICAL:**
- `scripts/local-branch-sync/` is in `.gitignore` - **Don't commit it**
- Keep the folder on your PC only (contains node_modules)
- SSH keys must be configured locally
- Sync service must be running before starting sync

✅ **SAFE TO DO:**
- Rename branch IPs in inputs
- Stop app anytime (doesn't corrupt data)
- Run multiple branch syncs (one at a time)
- Keep terminal windows open to monitor

## Next Steps

1. ✅ Verify SSH configuration works
2. ✅ Start sync service: `node local-sync-service.js`
3. ✅ Start desktop app: `npm start` (from local-branch-sync/)
4. ✅ Test with one branch first
5. ✅ Check logs for any issues
6. ✅ Once working, you can build installer
7. ✅ Distribute installer to other team members

## Support

For issues:
- **Sync service errors**: Check Terminal 1 output
- **App UI issues**: Press F12, check console
- **SSH/SCP issues**: Test manually with OpenSSH
- **Network issues**: Check firewall, antivirus blocking ports
