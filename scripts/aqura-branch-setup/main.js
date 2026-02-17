const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const { execSync, exec, spawn } = require('child_process');

let mainWindow;
let installerState = null;

// Paths
const SERVER_STATE_DIR = 'C:\\AquraServer';
const BRANCH_STATE_DIR = 'C:\\AquraBranch';

function getStateDir(mode) {
  return mode === 'server' ? SERVER_STATE_DIR : BRANCH_STATE_DIR;
}

function getStatePath(mode) {
  return path.join(getStateDir(mode), 'installer-state.json');
}

// ─── Load or create installer state ─────────────────────────────────────────
function loadState() {
  // Check both paths for a resume
  for (const dir of [SERVER_STATE_DIR, BRANCH_STATE_DIR]) {
    const statePath = path.join(dir, 'installer-state.json');
    if (fs.existsSync(statePath)) {
      try {
        const data = JSON.parse(fs.readFileSync(statePath, 'utf-8'));
        if (data && data.mode && data.currentPhase > 0) {
          console.log(`Resuming ${data.mode} install from phase ${data.currentPhase}`);
          return data;
        }
      } catch (e) {
        console.error('Failed to read state file:', e.message);
      }
    }
  }
  return null;
}

function saveState(state) {
  const dir = getStateDir(state.mode);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(path.join(dir, 'installer-state.json'), JSON.stringify(state, null, 2));
  installerState = state;
}

// ─── Auto-start registry (for reboot resume) ───────────────────────────────
function setAutoStart(enable) {
  const regKey = 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run';
  const valueName = 'AquraSetup';
  try {
    if (enable) {
      const exePath = process.execPath;
      execSync(`reg add "${regKey}" /v "${valueName}" /t REG_SZ /d "${exePath}" /f`, { stdio: 'ignore' });
    } else {
      execSync(`reg delete "${regKey}" /v "${valueName}" /f`, { stdio: 'ignore' });
    }
  } catch (e) {
    console.error('Registry auto-start error:', e.message);
  }
}

// ─── Create main window ─────────────────────────────────────────────────────
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 650,
    minWidth: 800,
    minHeight: 600,
    resizable: true,
    frame: false,
    transparent: false,
    backgroundColor: '#0f172a',
    icon: path.join(__dirname, 'assets', 'icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  // Dev tools in development
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  }
}

// ─── IPC Handlers ───────────────────────────────────────────────────────────

// Window controls
ipcMain.on('window:minimize', () => mainWindow?.minimize());
ipcMain.on('window:maximize', () => {
  if (mainWindow?.isMaximized()) mainWindow.unmaximize();
  else mainWindow?.maximize();
});
ipcMain.on('window:close', () => mainWindow?.close());

// Check for resume state
ipcMain.handle('state:check-resume', () => {
  const state = loadState();
  return state;
});

// Save state
ipcMain.handle('state:save', (_, state) => {
  saveState(state);
  return true;
});

// Set auto-start for reboot resume
ipcMain.handle('state:set-autostart', (_, enable) => {
  setAutoStart(enable);
  return true;
});

// Run PowerShell command (returns stdout)
ipcMain.handle('shell:exec', async (_, command, options = {}) => {
  return new Promise((resolve) => {
    const timeout = options.timeout || 120000;
    exec(`powershell -NoProfile -NonInteractive -Command "${command.replace(/"/g, '\\"')}"`, 
      { timeout, maxBuffer: 10 * 1024 * 1024 },
      (error, stdout, stderr) => {
        resolve({
          success: !error,
          stdout: stdout?.trim() || '',
          stderr: stderr?.trim() || '',
          code: error?.code || 0
        });
      }
    );
  });
});

// Run WSL command
ipcMain.handle('shell:wsl', async (_, command, options = {}) => {
  return new Promise((resolve) => {
    const timeout = options.timeout || 120000;
    exec(`wsl -d Ubuntu-22.04 -- bash -c "${command.replace(/"/g, '\\"')}"`,
      { timeout, maxBuffer: 10 * 1024 * 1024 },
      (error, stdout, stderr) => {
        resolve({
          success: !error,
          stdout: stdout?.trim() || '',
          stderr: stderr?.trim() || '',
          code: error?.code || 0
        });
      }
    );
  });
});

// Run command with streaming output (for long operations)
ipcMain.handle('shell:stream', async (_, command, options = {}) => {
  return new Promise((resolve) => {
    const isWsl = options.wsl === true;
    let cmd, args;

    if (isWsl) {
      cmd = 'wsl';
      args = ['-d', 'Ubuntu-22.04', '--', 'bash', '-c', command];
    } else {
      cmd = 'powershell';
      args = ['-NoProfile', '-NonInteractive', '-Command', command];
    }

    const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      const text = data.toString();
      stdout += text;
      mainWindow?.webContents.send('shell:output', text);
    });

    child.stderr.on('data', (data) => {
      const text = data.toString();
      stderr += text;
      mainWindow?.webContents.send('shell:output', text);
    });

    child.on('close', (code) => {
      resolve({ success: code === 0, stdout, stderr, code });
    });

    child.on('error', (err) => {
      resolve({ success: false, stdout, stderr: err.message, code: -1 });
    });

    // Timeout
    if (options.timeout) {
      setTimeout(() => {
        child.kill();
        resolve({ success: false, stdout, stderr: 'Command timed out', code: -2 });
      }, options.timeout);
    }
  });
});

// SSH command to remote server
ipcMain.handle('shell:ssh', async (_, host, command, options = {}) => {
  return new Promise((resolve) => {
    const timeout = options.timeout || 30000;
    const sshKey = options.sshKey || '';
    const keyArg = sshKey ? `-i "${sshKey}"` : '';
    
    exec(`ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${keyArg} ${host} "${command.replace(/"/g, '\\"')}"`,
      { timeout, maxBuffer: 10 * 1024 * 1024 },
      (error, stdout, stderr) => {
        resolve({
          success: !error,
          stdout: stdout?.trim() || '',
          stderr: stderr?.trim() || '',
          code: error?.code || 0
        });
      }
    );
  });
});

// File operations
ipcMain.handle('fs:write', (_, filePath, content) => {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(filePath, content, 'utf-8');
  return true;
});

ipcMain.handle('fs:read', (_, filePath) => {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, 'utf-8');
});

ipcMain.handle('fs:exists', (_, filePath) => {
  return fs.existsSync(filePath);
});

// Dialog
ipcMain.handle('dialog:message', async (_, options) => {
  const result = await dialog.showMessageBox(mainWindow, options);
  return result.response;
});

// Get network info
ipcMain.handle('system:get-ip', () => {
  try {
    const os = require('os');
    const interfaces = os.networkInterfaces();
    const addresses = [];
    for (const name of Object.keys(interfaces)) {
      for (const iface of interfaces[name]) {
        if (iface.family === 'IPv4' && !iface.internal) {
          addresses.push({ name, address: iface.address });
        }
      }
    }
    return addresses;
  } catch (e) {
    return [];
  }
});

// ─── App lifecycle ──────────────────────────────────────────────────────────
app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  // Remove auto-start on clean close (not during reboot phase)
  setAutoStart(false);
  app.quit();
});
