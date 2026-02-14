/**
 * ERP Bridge Setup Wizard
 * 
 * A self-contained setup wizard that runs on each branch's SQL Server machine.
 * Opens a web-based GUI in the browser to configure everything:
 *   - Bridge API server (Express + mssql)
 *   - Cloudflare Tunnel (cloudflared)
 *   - Windows services for auto-start on reboot
 * 
 * USAGE:
 *   1. Install Node.js on the server (if not already)
 *   2. Copy this file to C:\erp-api\setup-wizard.js
 *   3. Open Admin CMD → cd C:\erp-api → node setup-wizard.js
 *   4. Browser opens automatically with the wizard
 * 
 * NO DEPENDENCIES NEEDED — uses only Node.js built-in modules.
 * It will install everything (npm packages, cloudflared, services) for you.
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { exec, execSync, spawn } = require('child_process');
const os = require('os');

const WIZARD_PORT = 9999;
const INSTALL_DIR = 'C:\\erp-api';
const CLOUDFLARED_PATH = 'C:\\cloudflared.exe';
const BRIDGE_PORT = 3333;
const API_SECRET = 'aqura-erp-bridge-2026';

// ============================================================
// EMBEDDED HTML — Full Setup Wizard UI
// ============================================================
const WIZARD_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aqura ERP Bridge Setup Wizard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', Tahoma, sans-serif; background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #0f172a 100%); color: #e2e8f0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
  .wizard { background: #1e293b; border-radius: 20px; box-shadow: 0 25px 60px rgba(0,0,0,0.5); width: 680px; max-width: 95vw; overflow: hidden; border: 1px solid #334155; }
  .wizard-header { background: linear-gradient(135deg, #059669 0%, #10b981 100%); padding: 28px 32px; text-align: center; }
  .wizard-header h1 { font-size: 24px; font-weight: 700; color: #fff; margin-bottom: 4px; }
  .wizard-header p { font-size: 13px; color: rgba(255,255,255,0.85); }
  .wizard-body { padding: 28px 32px; }
  .wizard-footer { padding: 16px 32px 24px; display: flex; justify-content: space-between; align-items: center; }
  
  /* Steps indicator */
  .steps { display: flex; justify-content: center; gap: 8px; margin-bottom: 24px; }
  .step-dot { width: 10px; height: 10px; border-radius: 50%; background: #334155; transition: all 0.3s; }
  .step-dot.active { background: #10b981; transform: scale(1.3); }
  .step-dot.done { background: #059669; }
  
  /* Form fields */
  .field { margin-bottom: 16px; }
  .field label { display: block; font-size: 12px; font-weight: 600; color: #94a3b8; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px; }
  .field input, .field select, .field textarea { width: 100%; padding: 10px 14px; background: #0f172a; border: 1px solid #334155; border-radius: 10px; color: #e2e8f0; font-size: 14px; font-family: inherit; transition: border-color 0.2s; }
  .field input:focus, .field select:focus, .field textarea:focus { outline: none; border-color: #10b981; }
  .field textarea { resize: vertical; min-height: 60px; font-family: 'Consolas', monospace; font-size: 12px; }
  .field .hint { font-size: 11px; color: #64748b; margin-top: 4px; }
  .field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  
  /* Buttons */
  .btn { padding: 10px 24px; border-radius: 10px; border: none; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.2s; display: inline-flex; align-items: center; gap: 8px; }
  .btn-primary { background: linear-gradient(135deg, #059669, #10b981); color: #fff; }
  .btn-primary:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(16,185,129,0.3); }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
  .btn-secondary { background: #334155; color: #e2e8f0; }
  .btn-secondary:hover { background: #475569; }
  .btn-danger { background: #dc2626; color: #fff; }
  .btn-small { padding: 6px 14px; font-size: 12px; }
  
  /* Progress log */
  .log-box { background: #0f172a; border: 1px solid #334155; border-radius: 12px; padding: 16px; max-height: 350px; overflow-y: auto; font-family: 'Consolas', monospace; font-size: 12px; line-height: 1.8; }
  .log-line { display: flex; align-items: flex-start; gap: 8px; }
  .log-line .icon { flex-shrink: 0; font-size: 14px; }
  .log-line.success { color: #10b981; }
  .log-line.error { color: #ef4444; }
  .log-line.info { color: #38bdf8; }
  .log-line.working { color: #f59e0b; }
  .log-line.dim { color: #64748b; }
  
  /* Status cards */
  .status-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 16px; }
  .status-card { background: #0f172a; border: 1px solid #334155; border-radius: 12px; padding: 14px; text-align: center; }
  .status-card .label { font-size: 11px; color: #94a3b8; text-transform: uppercase; margin-bottom: 6px; }
  .status-card .value { font-size: 16px; font-weight: 700; }
  .status-card .value.green { color: #10b981; }
  .status-card .value.red { color: #ef4444; }
  .status-card .value.yellow { color: #f59e0b; }
  
  .hidden { display: none !important; }
  
  /* Spinner */
  .spinner { display: inline-block; width: 16px; height: 16px; border: 2px solid rgba(255,255,255,0.3); border-top-color: #10b981; border-radius: 50%; animation: spin 0.8s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  
  /* Welcome */
  .features { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin: 16px 0; }
  .feature { background: #0f172a; border-radius: 10px; padding: 12px; display: flex; align-items: center; gap: 10px; }
  .feature .emoji { font-size: 20px; }
  .feature .text { font-size: 13px; color: #cbd5e1; }
  
  .test-result { margin-top: 8px; padding: 8px 12px; border-radius: 8px; font-size: 13px; }
  .test-result.ok { background: rgba(16,185,129,0.1); border: 1px solid #059669; color: #10b981; }
  .test-result.fail { background: rgba(239,68,68,0.1); border: 1px solid #dc2626; color: #ef4444; }
</style>
</head>
<body>
<div class="wizard">
  <div class="wizard-header">
    <h1>🏭 Aqura ERP Bridge Setup</h1>
    <p>Configure Cloudflare Tunnel + Bridge API for this branch server</p>
  </div>
  <div class="wizard-body">
    <div class="steps">
      <div class="step-dot active" id="dot-0"></div>
      <div class="step-dot" id="dot-1"></div>
      <div class="step-dot" id="dot-2"></div>
      <div class="step-dot" id="dot-3"></div>
    </div>

    <!-- STEP 0: Welcome -->
    <div id="step-0">
      <h2 style="margin-bottom:12px; font-size:18px;">Welcome!</h2>
      <p style="color:#94a3b8; font-size:13px; margin-bottom:12px;">This wizard will set up everything needed on this branch server so the Aqura app (hosted on Vercel) can communicate with the local ERP database.</p>
      <div class="features">
        <div class="feature"><span class="emoji">🌐</span><span class="text">Cloudflare Tunnel (auto-download)</span></div>
        <div class="feature"><span class="emoji">🔌</span><span class="text">Bridge API Server (Express + mssql)</span></div>
        <div class="feature"><span class="emoji">🔄</span><span class="text">Auto-start on reboot (Windows Services)</span></div>
        <div class="feature"><span class="emoji">🔒</span><span class="text">Secure API authentication</span></div>
      </div>
      <div style="background:#0f172a; border-radius:10px; padding:14px; margin-top:12px;">
        <p style="font-size:12px; color:#f59e0b;">⚠️ <strong>Requirements:</strong></p>
        <ul style="font-size:12px; color:#94a3b8; margin-top:6px; padding-left:20px;">
          <li>Running as <strong>Administrator</strong> (right-click CMD → Run as admin)</li>
          <li>Internet connection (to download cloudflared &amp; npm packages)</li>
          <li>SQL Server running on this machine</li>
          <li>Cloudflare Tunnel token (from the Cloudflare dashboard)</li>
        </ul>
      </div>
      <div id="existing-config-box" class="hidden" style="background:#0f172a; border-radius:10px; padding:14px; margin-top:12px; border: 1px solid #f59e0b;">
        <p style="font-size:14px; color:#f59e0b; font-weight:600;">&#128295; Existing Configuration Found!</p>
        <div id="existing-config-details" style="margin-top:8px; font-size:12px; color:#94a3b8; line-height:1.8;"></div>
        <div style="margin-top:12px; display:flex; gap:8px;">
          <button class="btn btn-primary btn-small" onclick="loadExistingConfig()">&#9998; Edit &amp; Reinstall</button>
          <button class="btn btn-secondary btn-small" onclick="freshSetup()">&#128310; Fresh Setup</button>
        </div>
      </div>
    </div>

    <!-- STEP 1: Configuration -->
    <div id="step-1" class="hidden">
      <h2 style="margin-bottom:16px; font-size:18px;">⚙️ Configuration</h2>
      <div class="field-row">
        <div class="field">
          <label>Branch Name</label>
          <input type="text" id="cfg-branch-name" placeholder="e.g. Urban Market 02" />
        </div>
        <div class="field">
          <label>App Branch ID</label>
          <input type="number" id="cfg-branch-id" placeholder="e.g. 5" />
          <div class="hint">The branch_id from the Aqura app</div>
        </div>
      </div>
      <div class="field-row">
        <div class="field">
          <label>SQL Server Address</label>
          <input type="text" id="cfg-sql-server" value="localhost" />
          <div class="hint">Usually "localhost" if SQL Server is on this machine</div>
        </div>
        <div class="field">
          <label>Database Name</label>
          <input type="text" id="cfg-db-name" placeholder="e.g. URBAN2_2025" />
        </div>
      </div>
      <div class="field-row">
        <div class="field">
          <label>SQL Username</label>
          <input type="text" id="cfg-sql-user" value="sa" />
        </div>
        <div class="field">
          <label>SQL Password</label>
          <input type="password" id="cfg-sql-pass" placeholder="SQL Server password" />
        </div>
      </div>
      <div class="field">
        <label>Cloudflare Tunnel Token</label>
        <textarea id="cfg-tunnel-token" placeholder="eyJhIjoiMWIx... (paste the token from Cloudflare dashboard)"></textarea>
        <div class="hint">Found in Cloudflare Zero Trust → Networks → Tunnels → your tunnel → Install connector</div>
      </div>
      <div class="field-row">
        <div class="field">
          <label>Bridge API Port</label>
          <input type="number" id="cfg-port" value="3333" />
        </div>
        <div class="field">
          <label>Tunnel Subdomain</label>
          <input type="text" id="cfg-subdomain" placeholder="e.g. erp-branch3" />
          <div class="hint">Must match the route in Cloudflare</div>
        </div>
      </div>
      <div style="margin-top:8px;">
        <button class="btn btn-secondary btn-small" onclick="testSqlConnection()">🔍 Test SQL Connection</button>
        <div id="sql-test-result"></div>
      </div>
    </div>

    <!-- STEP 2: Setup Progress -->
    <div id="step-2" class="hidden">
      <h2 style="margin-bottom:16px; font-size:18px;">🚀 Installing...</h2>
      <div class="log-box" id="log-box"></div>
    </div>

    <!-- STEP 3: Done -->
    <div id="step-3" class="hidden">
      <h2 style="margin-bottom:12px; font-size:18px;">✅ Setup Complete!</h2>
      <p style="color:#94a3b8; font-size:13px; margin-bottom:16px;">Everything is installed and running. Both services will auto-start when the server reboots.</p>
      <div class="status-grid" id="status-grid"></div>
      <div style="background:#0f172a; border-radius:10px; padding:14px; margin-top:16px;">
        <p style="font-size:12px; color:#94a3b8;">🔗 <strong>Test URL:</strong></p>
        <p style="font-size:14px; margin-top:4px;"><a id="test-url-link" href="#" target="_blank" style="color:#10b981; text-decoration:none;"></a></p>
        <p style="font-size:11px; color:#64748b; margin-top:8px;">Now go to Supabase SQL Editor and run:<br>
        <code id="supabase-update-sql" style="color:#f59e0b;"></code></p>
      </div>
    </div>
  </div>

  <div class="wizard-footer">
    <button class="btn btn-secondary" id="btn-back" onclick="prevStep()" style="visibility:hidden;">← Back</button>
    <button class="btn btn-primary" id="btn-next" onclick="nextStep()">Get Started →</button>
  </div>
</div>

<script>
let currentStep = 0;
const totalSteps = 4;
let existingConfig = null;
let isReinstall = false;

function showStep(n) {
  for (let i = 0; i < totalSteps; i++) {
    document.getElementById('step-' + i).classList.toggle('hidden', i !== n);
    const dot = document.getElementById('dot-' + i);
    dot.classList.toggle('active', i === n);
    dot.classList.toggle('done', i < n);
  }
  document.getElementById('btn-back').style.visibility = n > 0 && n < 2 ? 'visible' : 'hidden';
  const btnNext = document.getElementById('btn-next');
  if (n === 0) { btnNext.textContent = 'Get Started →'; btnNext.disabled = false; btnNext.classList.remove('hidden'); }
  else if (n === 1) { btnNext.textContent = isReinstall ? 'Reinstall Everything \u2192' : 'Install Everything \u2192'; btnNext.disabled = false; btnNext.classList.remove('hidden'); }
  else if (n === 2) { btnNext.classList.add('hidden'); }
  else if (n === 3) { btnNext.textContent = '✕ Close Wizard'; btnNext.disabled = false; btnNext.classList.remove('hidden'); }
}

function prevStep() { if (currentStep > 0) { currentStep--; showStep(currentStep); } }

async function nextStep() {
  if (currentStep === 1) {
    // Validate before proceeding
    const fields = ['cfg-branch-name','cfg-branch-id','cfg-db-name','cfg-sql-pass','cfg-tunnel-token','cfg-subdomain'];
    for (const f of fields) {
      if (!document.getElementById(f).value.trim()) {
        document.getElementById(f).style.borderColor = '#ef4444';
        document.getElementById(f).focus();
        return;
      }
      document.getElementById(f).style.borderColor = '#334155';
    }
    currentStep++;
    showStep(currentStep);
    await runSetup();
    return;
  }
  if (currentStep === 3) { window.close(); return; }
  currentStep++;
  showStep(currentStep);
}

function getConfig() {
  return {
    branchName: document.getElementById('cfg-branch-name').value.trim(),
    branchId: parseInt(document.getElementById('cfg-branch-id').value) || 0,
    sqlServer: document.getElementById('cfg-sql-server').value.trim() || 'localhost',
    dbName: document.getElementById('cfg-db-name').value.trim(),
    sqlUser: document.getElementById('cfg-sql-user').value.trim() || 'sa',
    sqlPass: document.getElementById('cfg-sql-pass').value.trim(),
    tunnelToken: document.getElementById('cfg-tunnel-token').value.trim(),
    port: parseInt(document.getElementById('cfg-port').value) || 3333,
    subdomain: document.getElementById('cfg-subdomain').value.trim()
  };
}

function addLog(text, type = 'info') {
  const icons = { info: '🔵', success: '✅', error: '❌', working: '⏳', dim: '   ' };
  const box = document.getElementById('log-box');
  const line = document.createElement('div');
  line.className = 'log-line ' + type;
  line.innerHTML = '<span class="icon">' + (icons[type]||'') + '</span><span>' + text + '</span>';
  box.appendChild(line);
  box.scrollTop = box.scrollHeight;
}

async function api(endpoint, body = {}) {
  const res = await fetch('/api/' + endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  return await res.json();
}

async function testSqlConnection() {
  const cfg = getConfig();
  if (!cfg.dbName || !cfg.sqlPass) { alert('Fill in database name and password first'); return; }
  const el = document.getElementById('sql-test-result');
  el.innerHTML = '<div class="test-result" style="color:#f59e0b;">Testing...</div>';
  const result = await api('test-sql', cfg);
  if (result.success) {
    el.innerHTML = '<div class="test-result ok">✅ Connected! ' + (result.message||'') + '</div>';
  } else {
    el.innerHTML = '<div class="test-result fail">❌ ' + (result.error||'Connection failed') + '</div>';
  }
}

async function runSetup() {
  const cfg = getConfig();
  
  addLog('Starting setup for <strong>' + cfg.branchName + '</strong> (Branch ID: ' + cfg.branchId + ')', 'info');
  addLog('Database: ' + cfg.dbName + ' | Port: ' + cfg.port, 'dim');
  addLog('', 'dim');
  
  // If reinstalling, uninstall old services first
  if (isReinstall) {
    addLog('\ud83d\udd04 <strong>Reinstall mode</strong> \u2014 removing old services first...', 'info');
    addLog('', 'dim');
    
    addLog('Stopping Bridge API service...', 'working');
    let ur = await api('setup-step', { step: 'uninstall-bridge-service', ...cfg });
    addLog(ur.success ? 'Bridge API service removed' : 'Note: ' + ur.error, ur.success ? 'success' : 'dim');
    
    addLog('Stopping Cloudflare Tunnel service...', 'working');
    ur = await api('setup-step', { step: 'uninstall-tunnel', ...cfg });
    addLog(ur.success ? 'Tunnel service removed' : 'Note: ' + ur.error, ur.success ? 'success' : 'dim');
    
    addLog('', 'dim');
    addLog('Old services removed. Starting fresh install...', 'info');
    addLog('', 'dim');
  }
  
  // Step 1: Create install directory
  addLog('Creating install directory...', 'working');
  let r = await api('setup-step', { step: 'create-dir', ...cfg });
  addLog(r.success ? 'Directory ready: ' + r.path : 'Error: ' + r.error, r.success ? 'success' : 'error');
  
  // Step 2: npm init + install deps
  addLog('Installing npm dependencies (express, mssql, cors, node-windows)...', 'working');
  addLog('This may take 1-2 minutes...', 'dim');
  r = await api('setup-step', { step: 'npm-install', ...cfg });
  addLog(r.success ? 'Dependencies installed!' : 'Error: ' + r.error, r.success ? 'success' : 'error');
  if (!r.success) return;
  
  // Step 3: Write server.js
  addLog('Writing bridge API server...', 'working');
  r = await api('setup-step', { step: 'write-server', ...cfg });
  addLog(r.success ? 'server.js created!' : 'Error: ' + r.error, r.success ? 'success' : 'error');
  
  // Step 4: Write service installer
  addLog('Writing service installer scripts...', 'working');
  r = await api('setup-step', { step: 'write-service-scripts', ...cfg });
  addLog(r.success ? 'Service scripts created!' : 'Error: ' + r.error, r.success ? 'success' : 'error');
  
  // Step 5: Download cloudflared
  addLog('Checking cloudflared...', 'working');
  r = await api('setup-step', { step: 'download-cloudflared', ...cfg });
  addLog(r.success ? (r.skipped ? 'cloudflared already exists' : 'cloudflared downloaded!') : 'Error: ' + r.error, r.success ? 'success' : 'error');
  if (!r.success) return;
  
  // Step 6: Install cloudflared service
  addLog('Installing Cloudflare Tunnel service...', 'working');
  r = await api('setup-step', { step: 'install-tunnel', ...cfg });
  addLog(r.success ? (r.skipped ? 'Tunnel service already installed' : 'Tunnel service installed!') : 'Error: ' + r.error, r.success ? 'success' : 'error');
  
  // Step 7: Install bridge API service
  addLog('Installing Bridge API as Windows service...', 'working');
  r = await api('setup-step', { step: 'install-bridge-service', ...cfg });
  addLog(r.success ? 'Bridge API service installed and started!' : 'Warning: ' + r.error, r.success ? 'success' : 'error');
  
  // Step 8: Add firewall rule
  addLog('Adding firewall rule for port ' + cfg.port + '...', 'working');
  r = await api('setup-step', { step: 'firewall', ...cfg });
  addLog(r.success ? 'Firewall rule added!' : 'Warning: ' + r.error, r.success ? 'success' : 'error');
  
  // Step 9: Test health
  addLog('', 'dim');
  addLog('Testing bridge API health...', 'working');
  r = await api('setup-step', { step: 'test-health', ...cfg });
  addLog(r.success ? '🎉 Bridge API is healthy!' : 'Warning: ' + r.error, r.success ? 'success' : 'error');
  
  addLog('', 'dim');
  addLog('<strong>Setup complete!</strong>', 'success');
  
  // Show done
  setTimeout(async () => {
    currentStep = 3;
    showStep(3);
    
    // Populate status
    const status = await api('status', cfg);
    const grid = document.getElementById('status-grid');
    grid.innerHTML = '' +
      statusCard('Bridge API', status.bridgeRunning ? 'Running ✓' : 'Not running', status.bridgeRunning ? 'green' : 'red') +
      statusCard('Tunnel', status.tunnelRunning ? 'Running ✓' : 'Not running', status.tunnelRunning ? 'green' : 'red') +
      statusCard('Port', cfg.port, 'green') +
      statusCard('Database', cfg.dbName, 'green');
    
    const tunnelUrl = 'https://' + cfg.subdomain + '.urbanaqura.com';
    const link = document.getElementById('test-url-link');
    link.href = tunnelUrl + '/health';
    link.textContent = tunnelUrl + '/health';
    document.getElementById('supabase-update-sql').textContent =
      "UPDATE erp_connections SET tunnel_url = '" + tunnelUrl + "' WHERE branch_id = " + cfg.branchId + ";";
  }, 1000);
}

function statusCard(label, value, color) {
  return '<div class="status-card"><div class="label">' + label + '</div><div class="value ' + color + '">' + value + '</div></div>';
}

showStep(0);

// --- Edit/Reinstall support ---
function loadExistingConfig() {
  isReinstall = true;
  currentStep = 1;
  showStep(1);
  if (existingConfig) {
    document.getElementById('cfg-branch-name').value = existingConfig.branchName || '';
    document.getElementById('cfg-branch-id').value = existingConfig.branchId || '';
    document.getElementById('cfg-sql-server').value = existingConfig.sqlServer || 'localhost';
    document.getElementById('cfg-db-name').value = existingConfig.dbName || '';
    document.getElementById('cfg-sql-user').value = existingConfig.sqlUser || 'sa';
    document.getElementById('cfg-sql-pass').value = existingConfig.sqlPass || '';
    document.getElementById('cfg-tunnel-token').value = existingConfig.tunnelToken || '';
    document.getElementById('cfg-port').value = existingConfig.port || 3333;
    document.getElementById('cfg-subdomain').value = existingConfig.subdomain || '';
  }
}

function freshSetup() {
  isReinstall = false;
  existingConfig = null;
  currentStep = 1;
  showStep(1);
}

// Auto-check for existing configuration on page load
(async function() {
  try {
    const res = await fetch('/api/check-config', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    const data = await res.json();
    if (data.exists && data.config) {
      existingConfig = data.config;
      var box = document.getElementById('existing-config-box');
      var details = document.getElementById('existing-config-details');
      box.classList.remove('hidden');
      details.innerHTML =
        '<div>\ud83d\udccc <strong>Branch:</strong> ' + (existingConfig.branchName || 'N/A') + ' (ID: ' + (existingConfig.branchId || 'N/A') + ')</div>' +
        '<div>\ud83d\uddc4\ufe0f <strong>Database:</strong> ' + (existingConfig.dbName || 'N/A') + ' @ ' + (existingConfig.sqlServer || 'localhost') + '</div>' +
        '<div>\ud83c\udf10 <strong>Subdomain:</strong> ' + (existingConfig.subdomain || 'N/A') + '.urbanaqura.com</div>' +
        '<div>\ud83d\udd0c <strong>Port:</strong> ' + (existingConfig.port || 3333) + '</div>' +
        '<div>\ud83d\udcc5 <strong>Setup Date:</strong> ' + (existingConfig.setupDate || 'N/A') + '</div>' +
        '<div style="margin-top:6px;">' +
        '\ud83d\udd0c Bridge: <span style="color:' + (existingConfig.bridgeRunning ? '#10b981' : '#ef4444') + ';">' + (existingConfig.bridgeRunning ? '\u25cf Running' : '\u25cf Stopped') + '</span> | ' +
        '\ud83c\udf10 Tunnel: <span style="color:' + (existingConfig.tunnelRunning ? '#10b981' : '#ef4444') + ';">' + (existingConfig.tunnelRunning ? '\u25cf Running' : '\u25cf Stopped') + '</span>' +
        '</div>';
    }
  } catch (e) { console.log('No existing config:', e); }
})();
</script>
</body>
</html>`;

// ============================================================
// SERVER.JS TEMPLATE — Bridge API that gets written to disk
// ============================================================
function getServerJsContent(cfg) {
  return `const express = require('express');
const sql = require('mssql');
const cors = require('cors');

// ========== CONFIGURATION ==========
const SQL_SERVER = ${JSON.stringify(cfg.sqlServer)};
const SQL_DATABASE = ${JSON.stringify(cfg.dbName)};
const SQL_USER = ${JSON.stringify(cfg.sqlUser)};
const SQL_PASSWORD = ${JSON.stringify(cfg.sqlPass)};
const API_SECRET = ${JSON.stringify(API_SECRET)};
const PORT = ${cfg.port};
// ====================================

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

const sqlConfig = {
  user: SQL_USER, password: SQL_PASSWORD, server: SQL_SERVER, database: SQL_DATABASE,
  options: { encrypt: false, trustServerCertificate: true },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
  connectionTimeout: 15000, requestTimeout: 120000
};

let pool = null;
async function getPool() {
  if (!pool) {
    pool = await sql.connect(sqlConfig);
    pool.on('error', (err) => { console.error('SQL Pool Error:', err); pool = null; });
  }
  return pool;
}

function authenticate(req, res, next) {
  if (req.headers['x-api-secret'] !== API_SECRET) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

app.get('/health', async (req, res) => {
  try {
    const p = await getPool(); await p.request().query('SELECT 1 AS ok');
    res.json({ status: 'healthy', database: SQL_DATABASE });
  } catch (err) { pool = null; res.status(500).json({ status: 'unhealthy', error: err.message }); }
});

app.post('/test', authenticate, async (req, res) => {
  try {
    const p = await getPool();
    const counts = await p.request().query(\`
      SELECT
        (SELECT COUNT(*) FROM ProductBatches WHERE MannualBarcode IS NOT NULL AND MannualBarcode != '') AS ManualBarcodes,
        (SELECT COUNT(*) FROM ProductBatches WHERE AutoBarcode IS NOT NULL AND AutoBarcode != '') AS AutoBarcodes,
        (SELECT COUNT(*) FROM ProductBatches WHERE Unit2Barcode IS NOT NULL AND Unit2Barcode != '') AS Unit2Barcodes,
        (SELECT COUNT(*) FROM ProductBatches WHERE Unit3Barcode IS NOT NULL AND Unit3Barcode != '') AS Unit3Barcodes,
        (SELECT COUNT(*) FROM ProductUnits WHERE BarCode IS NOT NULL AND BarCode != '') AS UnitBarcodes,
        (SELECT COUNT(*) FROM ProductBarcodes WHERE Barcode IS NOT NULL AND Barcode != '') AS ExtraBarcodes,
        (SELECT COUNT(DISTINCT ProductID) FROM Products) AS TotalProducts,
        (SELECT COUNT(*) FROM ProductBatches) AS TotalBatches,
        (SELECT COUNT(*) FROM (
          SELECT CAST(MannualBarcode AS NVARCHAR(100)) as bc FROM ProductBatches WHERE MannualBarcode IS NOT NULL AND MannualBarcode != ''
          UNION SELECT CAST(AutoBarcode AS NVARCHAR(100)) FROM ProductBatches WHERE AutoBarcode IS NOT NULL AND AutoBarcode != ''
          UNION SELECT CAST(Unit2Barcode AS NVARCHAR(100)) FROM ProductBatches WHERE Unit2Barcode IS NOT NULL AND Unit2Barcode != ''
          UNION SELECT CAST(Unit3Barcode AS NVARCHAR(100)) FROM ProductBatches WHERE Unit3Barcode IS NOT NULL AND Unit3Barcode != ''
          UNION SELECT CAST(BarCode AS NVARCHAR(100)) FROM ProductUnits WHERE BarCode IS NOT NULL AND BarCode != ''
          UNION SELECT CAST(Barcode AS NVARCHAR(100)) FROM ProductBarcodes WHERE Barcode IS NOT NULL AND Barcode != ''
        ) u) AS UniqueBarcodes
    \`);
    const c = counts.recordset[0];
    res.json({
      success: true, message: 'Connection successful!',
      counts: {
        manualBarcodes: c.ManualBarcodes, autoBarcodes: c.AutoBarcodes,
        unit2Barcodes: c.Unit2Barcodes, unit3Barcodes: c.Unit3Barcodes,
        unitBarcodes: c.UnitBarcodes, extraBarcodes: c.ExtraBarcodes,
        totalProducts: c.TotalProducts, totalBatches: c.TotalBatches,
        totalAll: c.ManualBarcodes + c.AutoBarcodes + c.Unit2Barcodes + c.Unit3Barcodes + c.UnitBarcodes + c.ExtraBarcodes,
        uniqueBarcodes: c.UniqueBarcodes
      }
    });
  } catch (err) { pool = null; res.json({ success: false, message: 'Connection failed: ' + err.message }); }
});

let syncCache = null; let syncCacheTime = 0; const SYNC_CACHE_TTL = 300000; let syncBuildingPromise = null;

async function buildProductList(erpBranchId, appBranchId, cacheKey) {
    const p = await getPool();
    const branchFilter = erpBranchId ? " AND pb.BranchID = " + parseInt(erpBranchId) : "";
    console.log("[sync-build] erpBranchId=" + (erpBranchId || "ALL") + ", filter:" + (branchFilter || "NONE"));
    const baseProductsResult = await p.request().query("SELECT pb.ProductBatchID, pb.ProductID, pb.AutoBarcode, pb.MannualBarcode, pb.Unit2Barcode, pb.Unit3Barcode, pb.ExpiryDate, pb.BranchID, p.ProductName, p.ItemNameinSecondLanguage FROM ProductBatches pb INNER JOIN Products p ON pb.ProductID = p.ProductID WHERE ((pb.MannualBarcode IS NOT NULL AND pb.MannualBarcode != '') OR (pb.AutoBarcode IS NOT NULL AND pb.AutoBarcode != '') OR (pb.Unit2Barcode IS NOT NULL AND pb.Unit2Barcode != '') OR (pb.Unit3Barcode IS NOT NULL AND pb.Unit3Barcode != ''))" + branchFilter);
    const baseProducts = baseProductsResult.recordset;
    console.log('[sync-build] Got ' + baseProducts.length + ' base products');
    const unitsResult = await p.request().query("SELECT pu.ProductBatchID, pu.UnitID, pu.MultiFactor, ISNULL(pu.BarCode, '') as BarCode, pu.Sprice, u.UnitName FROM ProductUnits pu INNER JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID WHERE 1=1" + branchFilter + " ORDER BY pu.ProductBatchID, pu.MultiFactor");
    const allUnits = unitsResult.recordset;
    const extraBarcodesResult = await p.request().query("SELECT pbc.ProductBatchID, pbc.Barcode, pbc.UnitID, ISNULL(u.UnitName, '') as UnitName, pb.MannualBarcode, pb.AutoBarcode, pb.ExpiryDate, pb.BranchID, p.ProductName, p.ItemNameinSecondLanguage FROM ProductBarcodes pbc INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID INNER JOIN Products p ON pb.ProductID = p.ProductID LEFT JOIN UnitOfMeasures u ON pbc.UnitID = u.UnitID WHERE pbc.Barcode IS NOT NULL AND pbc.Barcode != ''" + branchFilter);
    const extraBarcodes = extraBarcodesResult.recordset;
    const products = []; const addedBarcodes = new Set(); const expiryMap = new Map();
    function addExpiryEntry(barcode, expiryDate, erpBranchIdFromRow) {
      if (!barcode) return;
      const expStr = expiryDate ? new Date(expiryDate).toISOString().split('T')[0] : null;
      if (!expStr || expStr === '1900-01-01' || expStr === '2000-01-01') return;
      const entry = { expiry_date: expStr };
      if (appBranchId) entry.branch_id = appBranchId;
      if (erpBranchId) entry.erp_branch_id = erpBranchId;
      if (erpBranchIdFromRow != null) entry.erp_row_branch_id = Number(erpBranchIdFromRow);
      if (!expiryMap.has(barcode)) expiryMap.set(barcode, []);
      const existing = expiryMap.get(barcode);
      if (!existing.some(e => e.expiry_date === expStr && e.branch_id === entry.branch_id)) existing.push(entry);
    }
    const baseProductByBatchId = new Map();
    for (const bp of baseProducts) { baseProductByBatchId.set(String(bp.ProductBatchID), bp); }
    for (const bp of baseProducts) {
      ['MannualBarcode','AutoBarcode','Unit2Barcode','Unit3Barcode'].forEach(k => {
        const bc = String(bp[k] || '').trim(); if (bc) addExpiryEntry(bc, bp.ExpiryDate, bp.BranchID);
      });
    }
    for (const u of allUnits) {
      const bc = String(u.BarCode || '').trim(); if (!bc) continue;
      const parent = baseProductByBatchId.get(String(u.ProductBatchID));
      if (parent) addExpiryEntry(bc, parent.ExpiryDate, parent.BranchID);
    }
    for (const eb of extraBarcodes) { const bc = String(eb.Barcode || '').trim(); if (bc) addExpiryEntry(bc, eb.ExpiryDate, eb.BranchID); }
    const unitsByBatchId = new Map();
    for (const u of allUnits) { const bid = String(u.ProductBatchID); if (!unitsByBatchId.has(bid)) unitsByBatchId.set(bid, []); unitsByBatchId.get(bid).push(u); }
    for (const bp of baseProducts) {
      const pu = unitsByBatchId.get(String(bp.ProductBatchID)) || [];
      const baseUnit = pu.find(u => parseFloat(u.MultiFactor) === 1) || pu[0];
      const parentBarcode = String(bp.MannualBarcode || bp.AutoBarcode || '').trim();
      const ubm = new Map(); for (const u of pu) { const bc = String(u.BarCode||'').trim(); if (bc) ubm.set(bc, u); }
      const manualBC = String(bp.MannualBarcode || '').trim();
      if (manualBC && !addedBarcodes.has(manualBC)) { const mu = ubm.get(manualBC); products.push({ barcode: manualBC, auto_barcode: String(bp.AutoBarcode||'').trim(), parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : (baseUnit ? baseUnit.UnitName : ''), unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: true, expiry_dates: expiryMap.get(manualBC)||[] }); addedBarcodes.add(manualBC); }
      const autoBC = String(bp.AutoBarcode || '').trim();
      if (autoBC && !addedBarcodes.has(autoBC)) { if (!manualBC) { const mu = ubm.get(autoBC); products.push({ barcode: autoBC, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : (baseUnit ? baseUnit.UnitName : ''), unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: true, expiry_dates: expiryMap.get(autoBC)||[] }); } addedBarcodes.add(autoBC); }
      const unit2BC = String(bp.Unit2Barcode || '').trim();
      if (unit2BC && !addedBarcodes.has(unit2BC)) { const mu = ubm.get(unit2BC); products.push({ barcode: unit2BC, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : '', unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: false, expiry_dates: expiryMap.get(unit2BC)||[] }); addedBarcodes.add(unit2BC); }
      const unit3BC = String(bp.Unit3Barcode || '').trim();
      if (unit3BC && !addedBarcodes.has(unit3BC)) { const mu = ubm.get(unit3BC); products.push({ barcode: unit3BC, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: mu ? mu.UnitName : '', unit_qty: mu ? (parseFloat(mu.MultiFactor)||1) : 1, is_base_unit: false, expiry_dates: expiryMap.get(unit3BC)||[] }); addedBarcodes.add(unit3BC); }
      for (const unit of pu) { const ubc = String(unit.BarCode||'').trim(); if (!ubc || addedBarcodes.has(ubc)) continue; products.push({ barcode: ubc, auto_barcode: autoBC, parent_barcode: parentBarcode, product_name_en: bp.ProductName||'', product_name_ar: bp.ItemNameinSecondLanguage||'', unit_name: unit.UnitName||'', unit_qty: parseFloat(unit.MultiFactor)||1, is_base_unit: parseFloat(unit.MultiFactor)===1, expiry_dates: expiryMap.get(ubc)||[] }); addedBarcodes.add(ubc); }
    }
    for (const eb of extraBarcodes) { const ebc = String(eb.Barcode||'').trim(); if (!ebc || addedBarcodes.has(ebc)) continue; products.push({ barcode: ebc, auto_barcode: String(eb.AutoBarcode||'').trim(), parent_barcode: String(eb.MannualBarcode||'').trim(), product_name_en: eb.ProductName||'', product_name_ar: eb.ItemNameinSecondLanguage||'', unit_name: eb.UnitName||'', unit_qty: 1, is_base_unit: false, expiry_dates: expiryMap.get(ebc)||[] }); addedBarcodes.add(ebc); }
    syncCache = { key: cacheKey, products }; syncCacheTime = Date.now();
    console.log('[sync-build] Built and cached ' + products.length + ' products');
    return products;
}

app.post('/sync', authenticate, async (req, res) => {
  try {
    const { erpBranchId, appBranchId, limit, offset } = req.body;
    const fetchLimit = parseInt(limit) || 0;
    const fetchOffset = parseInt(offset) || 0;
    const cacheKey = (erpBranchId || 'ALL') + '-' + (appBranchId || 'N/A');
    const now = Date.now();
    if (syncCache && syncCache.key === cacheKey && (now - syncCacheTime) < SYNC_CACHE_TTL) {
      const products = syncCache.products;
      const totalCount = products.length;
      if (fetchLimit > 0) {
        const sliced = products.slice(fetchOffset, fetchOffset + fetchLimit);
        const hasMore = (fetchOffset + fetchLimit) < totalCount;
        return res.json({ success: true, products: sliced, totalCount, hasMore, offset: fetchOffset, limit: fetchLimit, message: 'Batch: ' + sliced.length + ' of ' + totalCount });
      } else {
        return res.json({ success: true, products, totalProducts: totalCount, totalCount, hasMore: false, baseProductsCount: totalCount, message: 'Fetched ' + totalCount + ' barcodes' });
      }
    }
    if (syncBuildingPromise) {
      return res.json({ success: true, status: 'building', retry: true, message: 'Building product list from SQL... please wait' });
    }
    syncBuildingPromise = buildProductList(erpBranchId, appBranchId, cacheKey).then(function() { syncBuildingPromise = null; console.log('[sync] Async build complete!'); }).catch(function(err) { syncBuildingPromise = null; console.error('[sync] Build FAILED:', err.message); });
    return res.json({ success: true, status: 'building', retry: true, message: 'Started building product list... retry in a few seconds' });
    const idList = batchIds.map(id => "'" + id + "'").join(',');
    const safeDateStr = newExpiryDate.replace(/-/g, '');
    const updateResult = await p.request().input('newExpiry', sql.NVarChar, safeDateStr).query("UPDATE ProductBatches SET ExpiryDate = CONVERT(datetime, @newExpiry, 112) WHERE ProductBatchID IN (" + idList + ")");
    const verifyResult = await p.request().query("SELECT ProductBatchID, ExpiryDate FROM ProductBatches WHERE ProductBatchID IN (" + idList + ")");
    res.json({ success: true, updatedRows: updateResult.rowsAffected[0], batchIds, verifiedDates: verifyResult.recordset, message: 'Updated ' + updateResult.rowsAffected[0] + ' batch(es) in ERP' });
  } catch (err) { pool = null; console.error('Update expiry error:', err); res.status(500).json({ success: false, error: err.message }); }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('ERP Bridge API running on port ' + PORT + ' | DB: ' + SQL_DATABASE);
});
`;
}

// ============================================================
// SETUP STEP HANDLERS
// ============================================================
function runCmd(cmd, cwd = INSTALL_DIR) {
  return new Promise((resolve) => {
    exec(cmd, { cwd, timeout: 300000, maxBuffer: 10 * 1024 * 1024 }, (err, stdout, stderr) => {
      resolve({ success: !err, stdout: (stdout || '').trim(), stderr: (stderr || '').trim(), error: err ? err.message : null });
    });
  });
}

async function handleSetupStep(cfg) {
  const step = cfg.step;

  if (step === 'create-dir') {
    try {
      if (!fs.existsSync(INSTALL_DIR)) fs.mkdirSync(INSTALL_DIR, { recursive: true });
      return { success: true, path: INSTALL_DIR };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'npm-install') {
    try {
      // npm init if no package.json
      if (!fs.existsSync(path.join(INSTALL_DIR, 'package.json'))) {
        await runCmd('npm init -y');
      }
      const r = await runCmd('npm install express mssql cors node-windows');
      return { success: r.success || fs.existsSync(path.join(INSTALL_DIR, 'node_modules', 'express')), error: r.error };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'write-server') {
    try {
      const content = getServerJsContent(cfg);
      fs.writeFileSync(path.join(INSTALL_DIR, 'server.js'), content, 'utf8');
      return { success: true };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'write-service-scripts') {
    try {
      // Install service script
      const installScript = `const Service = require('node-windows').Service;
const svc = new Service({
  name: 'ERP Bridge API',
  description: 'Aqura ERP Bridge API Server - ${cfg.branchName}',
  script: '${INSTALL_DIR.replace(/\\/g, '\\\\')}\\\\server.js',
  nodeOptions: []
});
svc.on('install', function() { console.log('Service installed! Starting...'); svc.start(); });
svc.on('alreadyinstalled', function() { console.log('Service already installed.'); });
svc.on('start', function() { console.log('Service started!'); process.exit(0); });
svc.on('error', function(e) { console.error('Service error:', e); });
svc.install();
`;
      fs.writeFileSync(path.join(INSTALL_DIR, 'install-service.js'), installScript, 'utf8');

      // Uninstall service script
      const uninstallScript = `const Service = require('node-windows').Service;
const svc = new Service({ name: 'ERP Bridge API', script: '${INSTALL_DIR.replace(/\\/g, '\\\\')}\\\\server.js' });
svc.on('uninstall', function() { console.log('Service uninstalled.'); process.exit(0); });
svc.uninstall();
`;
      fs.writeFileSync(path.join(INSTALL_DIR, 'uninstall-service.js'), uninstallScript, 'utf8');

      // Save config for reference (all fields for edit/reinstall support)
      const configJson = { branchName: cfg.branchName, branchId: cfg.branchId, subdomain: cfg.subdomain, dbName: cfg.dbName, sqlServer: cfg.sqlServer, sqlUser: cfg.sqlUser, sqlPass: cfg.sqlPass, tunnelToken: cfg.tunnelToken, port: cfg.port, setupDate: new Date().toISOString() };
      fs.writeFileSync(path.join(INSTALL_DIR, 'config.json'), JSON.stringify(configJson, null, 2), 'utf8');

      return { success: true };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'download-cloudflared') {
    if (fs.existsSync(CLOUDFLARED_PATH)) {
      return { success: true, skipped: true };
    }
    try {
      const url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe';
      await runCmd(`curl -Lo "${CLOUDFLARED_PATH}" "${url}"`, 'C:\\');
      if (fs.existsSync(CLOUDFLARED_PATH)) {
        return { success: true, skipped: false };
      } else {
        return { success: false, error: 'Download failed. Check internet connection.' };
      }
    } catch (e) {
      return { success: false, error: e.message };
    }
  }

  if (step === 'install-tunnel') {
    try {
      // Check if already installed
      const check = await runCmd('sc query cloudflared', 'C:\\');
      if (check.success && check.stdout.includes('RUNNING')) {
        return { success: true, skipped: true };
      }
      // Install with token
      const r = await runCmd(`"${CLOUDFLARED_PATH}" service install ${cfg.tunnelToken}`, 'C:\\');
      // Verify
      const verify = await runCmd('sc query cloudflared', 'C:\\');
      return { success: verify.stdout.includes('RUNNING') || verify.stdout.includes('START_PENDING'), error: r.error };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'install-bridge-service') {
    try {
      // Kill any existing node server.js on the port first
      await runCmd(`for /f "tokens=5" %a in ('netstat -ano ^| findstr :${cfg.port} ^| findstr LISTENING') do taskkill /PID %a /F`, 'C:\\');
      // Run the install-service script
      const r = await runCmd('node install-service.js');
      // Give it a moment to start
      await new Promise(resolve => setTimeout(resolve, 3000));
      return { success: true, output: r.stdout };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'firewall') {
    try {
      const r = await runCmd(`netsh advfirewall firewall add rule name="ERP Bridge API" dir=in action=allow protocol=TCP localport=${cfg.port}`, 'C:\\');
      return { success: true };
    } catch (e) { return { success: false, error: e.message }; }
  }

  if (step === 'test-health') {
    return new Promise((resolve) => {
      const req = http.get(`http://localhost:${cfg.port}/health`, (res) => {
        let data = '';
        res.on('data', c => data += c);
        res.on('end', () => {
          try {
            const j = JSON.parse(data);
            resolve({ success: j.status === 'healthy', message: data });
          } catch { resolve({ success: false, error: 'Invalid response: ' + data }); }
        });
      });
      req.on('error', (e) => resolve({ success: false, error: e.message }));
      req.setTimeout(5000, () => { req.destroy(); resolve({ success: false, error: 'Timeout' }); });
    });
  }

  if (step === 'uninstall-bridge-service') {
    try {
      // Try node-windows uninstall first
      if (fs.existsSync(path.join(INSTALL_DIR, 'uninstall-service.js'))) {
        await runCmd('node uninstall-service.js');
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
      // Also try sc stop/delete as fallback
      await runCmd('sc stop "ERP Bridge API"', 'C:\\');
      await runCmd('sc delete "ERP Bridge API"', 'C:\\');
      await new Promise(resolve => setTimeout(resolve, 1000));
      return { success: true };
    } catch (e) { return { success: true }; } // Don't fail on uninstall errors
  }

  if (step === 'uninstall-tunnel') {
    try {
      await runCmd('sc stop cloudflared', 'C:\\');
      await runCmd(`"${CLOUDFLARED_PATH}" service uninstall`, 'C:\\');
      await new Promise(resolve => setTimeout(resolve, 2000));
      return { success: true };
    } catch (e) { return { success: true }; } // Don't fail on uninstall errors
  }

  return { success: false, error: 'Unknown step: ' + step };
}

// ============================================================
// TEST SQL CONNECTION (uses temp script since we have no mssql)
// ============================================================
async function handleTestSql(cfg) {
  // Write a temp test script, run it, parse output
  const testScript = `
const sql = require('mssql');
const config = { server: ${JSON.stringify(cfg.sqlServer)}, database: ${JSON.stringify(cfg.dbName)}, user: ${JSON.stringify(cfg.sqlUser)}, password: ${JSON.stringify(cfg.sqlPass)}, options: { encrypt: false, trustServerCertificate: true }, connectionTimeout: 8000 };
(async () => {
  try {
    const pool = await sql.connect(config);
    const r = await pool.request().query('SELECT COUNT(*) as cnt FROM Products');
    console.log(JSON.stringify({ success: true, message: r.recordset[0].cnt + ' products found' }));
    process.exit(0);
  } catch (e) { console.log(JSON.stringify({ success: false, error: e.message })); process.exit(0); }
})();
`;
  // Need mssql installed first
  if (!fs.existsSync(path.join(INSTALL_DIR, 'node_modules', 'mssql'))) {
    // Quick install
    if (!fs.existsSync(INSTALL_DIR)) fs.mkdirSync(INSTALL_DIR, { recursive: true });
    if (!fs.existsSync(path.join(INSTALL_DIR, 'package.json'))) {
      await runCmd('npm init -y');
    }
    await runCmd('npm install mssql');
  }
  const tmpFile = path.join(INSTALL_DIR, '_test_sql.js');
  fs.writeFileSync(tmpFile, testScript, 'utf8');
  const r = await runCmd(`node "${tmpFile}"`);
  try { fs.unlinkSync(tmpFile); } catch {}
  try {
    return JSON.parse(r.stdout);
  } catch {
    return { success: false, error: r.stderr || r.stdout || 'Unknown error' };
  }
}

// ============================================================
// STATUS CHECK
// ============================================================
async function handleStatus(cfg) {
  const bridgeCheck = await runCmd(`sc query "ERP Bridge API"`, 'C:\\');
  const tunnelCheck = await runCmd('sc query cloudflared', 'C:\\');
  return {
    bridgeRunning: bridgeCheck.stdout.includes('RUNNING'),
    tunnelRunning: tunnelCheck.stdout.includes('RUNNING')
  };
}

// ============================================================
// CHECK EXISTING CONFIG
// ============================================================
async function handleCheckConfig() {
  const configPath = path.join(INSTALL_DIR, 'config.json');
  if (!fs.existsSync(configPath)) {
    return { exists: false };
  }
  try {
    const raw = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(raw);
    // Check service statuses too
    const bridgeCheck = await runCmd('sc query "ERP Bridge API"', 'C:\\');
    const tunnelCheck = await runCmd('sc query cloudflared', 'C:\\');
    config.bridgeRunning = bridgeCheck.stdout.includes('RUNNING');
    config.tunnelRunning = tunnelCheck.stdout.includes('RUNNING');
    return { exists: true, config };
  } catch (e) {
    return { exists: false, error: e.message };
  }
}

// ============================================================
// HTTP SERVER — Serves wizard UI + API endpoints
// ============================================================
const server = http.createServer(async (req, res) => {
  // Serve wizard HTML
  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(WIZARD_HTML);
    return;
  }

  // API endpoints
  if (req.method === 'POST' && req.url.startsWith('/api/')) {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', async () => {
      let data = {};
      try { data = JSON.parse(body); } catch {}
      
      let result = {};
      const endpoint = req.url.replace('/api/', '');
      
      if (endpoint === 'test-sql') result = await handleTestSql(data);
      else if (endpoint === 'setup-step') result = await handleSetupStep(data);
      else if (endpoint === 'status') result = await handleStatus(data);
      else if (endpoint === 'check-config') result = await handleCheckConfig();
      else result = { error: 'Unknown endpoint' };
      
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(result));
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(WIZARD_PORT, '127.0.0.1', () => {
  const url = `http://localhost:${WIZARD_PORT}`;
  console.log('');
  console.log('  ╔══════════════════════════════════════════╗');
  console.log('  ║   Aqura ERP Bridge Setup Wizard          ║');
  console.log('  ║                                          ║');
  console.log(`  ║   Open: ${url}              ║`);
  console.log('  ║                                          ║');
  console.log('  ║   Press Ctrl+C to close                  ║');
  console.log('  ╚══════════════════════════════════════════╝');
  console.log('');

  // Auto-open browser
  exec(`start ${url}`);
});
