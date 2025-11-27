let branches = [];
let currentConfig = null;

// Show section
function showSection(sectionId) {
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  document.getElementById(sectionId).classList.add('active');
}

// Login
async function login() {
  const accessCode = document.getElementById('accessCode').value.trim();

  if (!accessCode) {
    alert('Please enter access code');
    return;
  }

  console.log('Attempting login with code:', accessCode);

  try {
    const result = await window.electronAPI.login(accessCode);
    console.log('Login result:', result);

    if (result.success) {
      console.log('Login successful, loading branches...');
      await loadBranches();
      showSection('configSection');
    } else {
      console.error('Login failed:', result.error);
      alert('Login failed: ' + result.error);
    }
  } catch (error) {
    console.error('Login error:', error);
    alert('Login error: ' + error.message);
  }
}

// Load branches
async function loadBranches() {
  const result = await window.electronAPI.loadBranches();
  
  if (result.success) {
    branches = result.branches;
    const select = document.getElementById('branchSelect');
    select.innerHTML = '<option value="">Select Branch...</option>';
    
    branches.forEach(branch => {
      const option = document.createElement('option');
      option.value = branch.id;
      option.textContent = `${branch.name_en} - ${branch.name_ar}`;
      select.appendChild(option);
    });
  }
}

// Test connection
async function testConnection() {
  const config = getConfigFromForm();
  
  if (!validateConfig(config)) {
    alert('Please fill in all fields');
    return;
  }

  const result = await window.electronAPI.testConnection(config);

  if (result.success) {
    alert('✅ Connection successful!');
  } else {
    alert('❌ Connection failed: ' + result.error);
  }
}

// Save config
async function saveConfig() {
  const config = getConfigFromForm();
  
  if (!validateConfig(config)) {
    alert('Please fill in all fields');
    return;
  }

  // Generate device ID
  config.device_id = generateDeviceId();

  const result = await window.electronAPI.saveConfig(config);

  if (result.success) {
    currentConfig = config;
    updateConfigDisplay();
    showSection('syncSection');
    
    // Show historical data sync button
    document.getElementById('syncHistoryBtn').style.display = 'block';
    addLog('info', '💡 Tip: Click "Sync Historical Data" to import all past sales records');
  } else {
    alert('Failed to save config: ' + result.error);
  }
}

// Get config from form
function getConfigFromForm() {
  const branchId = document.getElementById('branchSelect').value;
  const branch = branches.find(b => b.id == branchId);

  return {
    branch_id: parseInt(branchId),
    branch_name: branch ? branch.name_en : '',
    server_ip: document.getElementById('serverIp').value,
    server_name: document.getElementById('serverName').value,
    database_name: document.getElementById('databaseName').value,
    username: document.getElementById('sqlUsername').value,
    password: document.getElementById('sqlPassword').value
  };
}

// Validate config
function validateConfig(config) {
  return config.branch_id && config.server_ip && config.database_name && 
         config.username && config.password;
}

// Generate device ID
function generateDeviceId() {
  return 'desktop-' + Date.now() + '-' + Math.random().toString(36).substring(7);
}

// Update config display
function updateConfigDisplay() {
  if (currentConfig) {
    document.getElementById('displayBranch').textContent = currentConfig.branch_name;
    document.getElementById('displayServer').textContent = currentConfig.server_ip;
    document.getElementById('displayDatabase').textContent = currentConfig.database_name;
  }
}

// Sync historical data
async function syncHistoricalData() {
  if (!confirm('This will sync all historical sales data from your ERP system. This may take several minutes depending on the amount of data. Continue?')) {
    return;
  }

  const btn = document.getElementById('syncHistoryBtn');
  btn.disabled = true;
  btn.textContent = '⏳ Syncing Historical Data...';
  addLog('info', 'Starting historical data sync...');

  const result = await window.electronAPI.syncHistoricalData();

  if (result.success) {
    addLog('success', `✅ Synced ${result.daysProcessed} days of historical data (${result.recordsProcessed} records)`);
    btn.textContent = '✅ Historical Data Synced';
    setTimeout(() => {
      btn.style.display = 'none';
    }, 3000);
  } else {
    addLog('error', 'Failed to sync historical data: ' + result.error);
    btn.disabled = false;
    btn.textContent = '📦 Sync Historical Data';
  }
}

// Start sync
async function startSync() {
  const result = await window.electronAPI.startSync();

  if (result.success) {
    document.getElementById('statusDisplay').className = 'status running';
    document.getElementById('statusDisplay').textContent = '✅ Service Running (Syncing every 10 seconds)';
    document.getElementById('connectionStatus').style.display = 'block';
    document.getElementById('startBtn').style.display = 'none';
    document.getElementById('stopBtn').style.display = 'block';
    document.getElementById('syncHistoryBtn').style.display = 'none';
    addLog('success', 'Sync service started - checking today and yesterday every 10 seconds');
  } else {
    alert('Failed to start sync: ' + result.error);
  }
}

// Stop sync
async function stopSync() {
  const result = await window.electronAPI.stopSync();

  if (result.success) {
    document.getElementById('statusDisplay').className = 'status stopped';
    document.getElementById('statusDisplay').textContent = '⭕ Service Stopped';
    document.getElementById('connectionStatus').style.display = 'none';
    document.getElementById('startBtn').style.display = 'block';
    document.getElementById('stopBtn').style.display = 'none';
    addLog('info', 'Sync service stopped');
  }
}

// Go to config
function goToConfig() {
  showSection('configSection');
}

// Add log entry
function addLog(type, message) {
  const logContainer = document.getElementById('logContainer');
  const entry = document.createElement('div');
  entry.className = `log-entry ${type}`;
  const timestamp = new Date().toLocaleTimeString();
  entry.textContent = `[${timestamp}] ${message}`;
  logContainer.appendChild(entry);
  logContainer.scrollTop = logContainer.scrollHeight;
  
  // Update connection status based on log messages
  const connectionStatus = document.getElementById('connectionStatus');
  if (connectionStatus && connectionStatus.style.display !== 'none') {
    if (message.includes('🌐 Online')) {
      connectionStatus.className = 'status';
      connectionStatus.style.background = '#d1fae5';
      connectionStatus.style.color = '#065f46';
      connectionStatus.textContent = '🌐 Online - Syncing to cloud';
    } else if (message.includes('📡 Offline') || message.includes('📥 Offline mode')) {
      connectionStatus.className = 'status';
      connectionStatus.style.background = '#fef3c7';
      connectionStatus.style.color = '#92400e';
      connectionStatus.textContent = '📡 Offline - Data saved locally';
    } else if (message.includes('Internet restored')) {
      connectionStatus.className = 'status';
      connectionStatus.style.background = '#d1fae5';
      connectionStatus.style.color = '#065f46';
      connectionStatus.textContent = '🌐 Online - Processing queued data';
    }
  }
}

// Logout function
async function logout() {
  const accessCode = prompt('Enter your access code to logout/close:');
  
  if (!accessCode) {
    return; // User cancelled
  }

  const result = await window.electronAPI.verifyLogout(accessCode);

  if (result.success) {
    await window.electronAPI.forceClose();
  } else {
    alert('❌ Invalid access code. Cannot logout.');
  }
}

// Toggle auto-start
async function toggleAutostart() {
  const checkbox = document.getElementById('autostartCheckbox');
  const result = await window.electronAPI.setAutostart(checkbox.checked);
  
  if (result.success) {
    const status = checkbox.checked ? 'enabled' : 'disabled';
    addLog('success', `✅ Auto-start ${status}`);
  } else {
    checkbox.checked = !checkbox.checked; // Revert
    alert('Failed to update auto-start: ' + result.error);
  }
}

// Load auto-start status
async function loadAutostartStatus() {
  const result = await window.electronAPI.getAutostartStatus();
  if (result.success) {
    document.getElementById('autostartCheckbox').checked = result.enabled;
  }
}

// Listen for window close attempts
window.electronAPI.onRequestLogoutVerification(() => {
  logout();
});

// Listen for sync logs
window.electronAPI.onSyncLog((data) => {
  addLog(data.type, data.message);
});

// Check status on load
window.addEventListener('DOMContentLoaded', async () => {
  // Load auto-start status
  await loadAutostartStatus();
  
  const status = await window.electronAPI.getStatus();
  
  if (status.isRunning && status.config) {
    currentConfig = status.config;
    updateConfigDisplay();
    showSection('syncSection');
    document.getElementById('statusDisplay').className = 'status running';
    document.getElementById('statusDisplay').textContent = '✅ Service Running (Syncing every 1 minute)';
    document.getElementById('startBtn').style.display = 'none';
    document.getElementById('stopBtn').style.display = 'block';
  }
});
