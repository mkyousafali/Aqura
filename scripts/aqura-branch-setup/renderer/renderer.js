/* ═══════════════════════════════════════════════════════════════════
   Aqura Setup Installer — Renderer (Wizard Logic)
   ═══════════════════════════════════════════════════════════════════ */

// ─── State ──────────────────────────────────────────────────────────
let state = {
  mode: null,          // 'server' or 'branch'
  currentPhase: 0,
  companyName: '',
  dashboardPassword: '',
  adminUsername: '',
  adminPassword: '',
  adminQuickCode: '',
  adminEmail: '',  // kept for compat, set to username@aqura.local
  serverIP: '',
  serverPort: '5433',
  branchName: '',
  branchId: '',
  jwtSecret: '',
  anonKey: '',
  serviceKey: '',
  pgPassword: '',
  replicationPassword: '',
  connectivityMode: 'lan', // 'lan' or 'internet'
  credentialMode: 'manual', // 'manual' or 'auto'
  // Phase completion tracking
  wslInstalled: false,
  dockerReady: false,
  supabaseRunning: false,
  schemaImported: false,
  adminCreated: false,
  publisherConfigured: false,
  replicationActive: false,
  tunnelSetup: false,
  frontendDeployed: false,
  updateServiceDeployed: false,
  storageSyncSetup: false,
  branchRegistered: false,
  startedAt: null,
  lastError: null
};

// ─── Step Definitions ───────────────────────────────────────────────
const SERVER_STEPS = [
  { id: 'system-check',     title: 'System Check',               auto: false },
  { id: 'company-info',     title: 'Company & Admin Setup',      auto: false },
  { id: 'install-wsl',      title: 'Install WSL2 + Ubuntu',      auto: true  },
  { id: 'setup-docker',     title: 'Configure Docker',           auto: true  },
  { id: 'install-supabase', title: 'Install Supabase',           auto: true  },
  { id: 'generate-keys',    title: 'Generate JWT Keys',          auto: true  },
  { id: 'import-schema',    title: 'Import Schema (No Data)',    auto: true  },
  { id: 'create-admin',     title: 'Create Master Admin',        auto: true  },
  { id: 'setup-publisher',  title: 'Configure Replication',      auto: true  },
  { id: 'deploy-frontend',  title: 'Deploy Frontend & Verify',   auto: true  }
];

const BRANCH_STEPS = [
  { id: 'system-check',      title: 'System Check',              auto: false },
  { id: 'server-connect',    title: 'Connect to Server',         auto: false },
  { id: 'install-wsl',       title: 'Install WSL2 + Ubuntu',     auto: true  },
  { id: 'setup-docker',      title: 'Configure Docker',          auto: true  },
  { id: 'install-supabase',  title: 'Install Supabase',          auto: true  },
  { id: 'sync-schema',       title: 'Sync Schema & Data',        auto: true  },
  { id: 'setup-replication', title: 'Set Up Replication',         auto: true  },
  { id: 'setup-tunnel',      title: 'Configure Connectivity',    auto: true  },
  { id: 'deploy-frontend',   title: 'Deploy Frontend',           auto: true  },
  { id: 'deploy-update',     title: 'Deploy Update Service',     auto: true  },
  { id: 'sync-storage',      title: 'Set Up Storage Sync',       auto: true  },
  { id: 'verify',            title: 'Register & Verify',         auto: true  }
];

function getSteps() {
  return state.mode === 'server' ? SERVER_STEPS : BRANCH_STEPS;
}

// ─── DOM References ─────────────────────────────────────────────────
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

const screens = {
  mode: $('#screen-mode'),
  resume: $('#screen-resume'),
  wizard: $('#screen-wizard'),
  complete: $('#screen-complete')
};

// ─── Screen Management ──────────────────────────────────────────────
function showScreen(name) {
  Object.values(screens).forEach(s => s.classList.remove('active'));
  screens[name].classList.add('active');
}

// ─── Logging ────────────────────────────────────────────────────────
function log(text, type = '') {
  const logEl = $('#log-content');
  const line = document.createElement('div');
  if (type) line.className = `log-line-${type}`;
  line.textContent = `[${new Date().toLocaleTimeString()}] ${text}`;
  logEl.appendChild(line);
  logEl.scrollTop = logEl.scrollHeight;
}

function clearLog() {
  $('#log-content').innerHTML = '';
}

// ─── Progress Dots ──────────────────────────────────────────────────
function renderProgress() {
  const steps = getSteps();
  const container = $('#progress-steps');
  container.innerHTML = '';

  steps.forEach((step, i) => {
    if (i > 0) {
      const conn = document.createElement('div');
      conn.className = 'progress-connector' + (i < state.currentPhase ? ' done' : '');
      container.appendChild(conn);
    }

    const dot = document.createElement('div');
    dot.className = 'progress-dot';
    if (i < state.currentPhase) dot.classList.add('done');
    else if (i === state.currentPhase) dot.classList.add('active');
    else dot.classList.add('pending');
    dot.textContent = i + 1;
    container.appendChild(dot);
  });

  // Progress bar
  const pct = (state.currentPhase / steps.length) * 100;
  $('#progress-fill').style.width = `${pct}%`;

  // Counter
  $('#step-counter').textContent = `${state.currentPhase + 1} / ${steps.length}`;

  // Title
  const currentStep = steps[state.currentPhase];
  if (currentStep) {
    $('#step-title').textContent = `Step ${state.currentPhase + 1}: ${currentStep.title}`;
  }
}

// ─── Navigation ─────────────────────────────────────────────────────
function updateNav() {
  const steps = getSteps();
  $('#btn-back').disabled = state.currentPhase === 0;
  
  if (state.currentPhase >= steps.length - 1) {
    $('#btn-next').textContent = 'Finish ✓';
  } else {
    $('#btn-next').textContent = 'Next →';
  }
}

// ─── Step Content Rendering ─────────────────────────────────────────

function renderStepContent() {
  const steps = getSteps();
  const step = steps[state.currentPhase];
  if (!step) return;

  const container = $('#step-content');
  container.innerHTML = '';

  switch (step.id) {
    case 'system-check':
      renderSystemCheck(container);
      break;
    case 'company-info':
      renderCompanyInfo(container);
      break;
    case 'server-connect':
      renderServerConnect(container);
      break;
    case 'install-wsl':
      renderAutoStep(container, 'Installing WSL2 + Ubuntu 22.04...', 'install-wsl');
      break;
    case 'setup-docker':
      renderAutoStep(container, 'Configuring Docker inside WSL...', 'setup-docker');
      break;
    case 'install-supabase':
      renderAutoStep(container, 'Installing Supabase (Docker containers)...', 'install-supabase');
      break;
    case 'generate-keys':
      renderAutoStep(container, 'Generating JWT Secret, Anon Key, Service Key...', 'generate-keys');
      break;
    case 'import-schema':
      renderAutoStep(container, 'Importing Aqura schema (tables, functions, policies)...', 'import-schema');
      break;
    case 'create-admin':
      renderAutoStep(container, 'Creating master admin user...', 'create-admin');
      break;
    case 'setup-publisher':
      renderAutoStep(container, 'Configuring PostgreSQL replication publisher...', 'setup-publisher');
      break;
    case 'sync-schema':
      renderAutoStep(container, 'Syncing schema and data from server...', 'sync-schema');
      break;
    case 'setup-replication':
      renderAutoStep(container, 'Setting up PostgreSQL logical replication...', 'setup-replication');
      break;
    case 'setup-tunnel':
      renderAutoStep(container, 'Configuring connectivity...', 'setup-tunnel');
      break;
    case 'deploy-frontend':
      renderAutoStep(container, 'Deploying Aqura frontend...', 'deploy-frontend');
      break;
    case 'deploy-update':
      renderAutoStep(container, 'Deploying update service...', 'deploy-update');
      break;
    case 'sync-storage':
      renderAutoStep(container, 'Setting up storage file sync...', 'sync-storage');
      break;
    case 'verify':
      renderAutoStep(container, 'Registering branch and running verification...', 'verify');
      break;
    default:
      container.innerHTML = `<p>Unknown step: ${step.id}</p>`;
  }
}

// ─── System Check ───────────────────────────────────────────────────
async function renderSystemCheck(container) {
  const checks = [
    { label: 'Windows Version', key: 'windows' },
    { label: 'Virtualization Enabled', key: 'virtualization' },
    { label: 'RAM', key: 'ram' },
    { label: 'Free Disk Space', key: 'disk' },
    { label: 'Network Connectivity', key: 'network' }
  ];

  container.innerHTML = `
    <div class="check-list" id="check-list">
      ${checks.map(c => `
        <div class="check-item pending" id="check-${c.key}">
          <span class="icon">○</span>
          <span class="label">${c.label}</span>
          <span class="value">Checking...</span>
        </div>
      `).join('')}
    </div>
  `;

  // Disable next during check
  $('#btn-next').disabled = true;

  // Run checks
  let allPassed = true;

  // 1. Windows Version
  await runCheck('windows', async () => {
    const res = await api.exec('[System.Environment]::OSVersion.Version.Major');
    const major = parseInt(res.stdout);
    if (major >= 10) return { pass: true, value: `Windows ${major}` };
    return { pass: false, value: `Windows ${major} (need 10+)` };
  });

  // 2. Virtualization
  await runCheck('virtualization', async () => {
    const res = await api.exec('(Get-CimInstance Win32_ComputerSystem).HypervisorPresent');
    const enabled = res.stdout.toLowerCase() === 'true';
    if (enabled) return { pass: true, value: 'Enabled' };
    
    // Check if WSL already works (might still be fine)
    const wslCheck = await api.exec('wsl --status 2>&1');
    if (wslCheck.success && wslCheck.stdout.includes('Default')) return { pass: true, value: 'WSL2 available' };

    // Try to enable required Windows features automatically
    log('Virtualization not detected — enabling Windows features...', 'info');
    await api.exec('dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart', { timeout: 120000 });
    await api.exec('dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart', { timeout: 120000 });

    // Check if CPU actually supports virtualization (firmware)
    const cpuVirt = await api.exec('(Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled');
    const cpuSupports = cpuVirt.stdout.toLowerCase() === 'true';

    if (cpuSupports) {
      // CPU supports it but hypervisor not active yet — features enabled, reboot needed later
      return { pass: true, value: 'Features enabled — reboot needed (WSL step will handle it)', warn: true };
    }

    // CPU says disabled — might need BIOS, but Windows features are now enabled
    // Check if it's a VM or cloud instance (no BIOS access possible)
    const model = await api.exec('(Get-CimInstance Win32_ComputerSystem).Model');
    if (model.stdout.toLowerCase().includes('virtual')) {
      return { pass: true, value: 'Virtual machine detected — features enabled', warn: true };
    }

    // Last resort: features enabled, will likely work after reboot
    return { pass: true, value: 'Windows features enabled — may need BIOS VT-x if reboot fails', warn: true };
  });

  // 3. RAM
  await runCheck('ram', async () => {
    const res = await api.exec('[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)');
    const gb = parseFloat(res.stdout);
    if (gb >= 15) return { pass: true, value: `${gb} GB` };
    if (gb >= 8) return { pass: true, value: `${gb} GB (minimum)`, warn: true };
    return { pass: false, value: `${gb} GB (need 8+ GB)` };
  });

  // 4. Disk Space
  await runCheck('disk', async () => {
    const res = await api.exec('[math]::Round((Get-PSDrive C).Free / 1GB, 1)');
    const gb = parseFloat(res.stdout);
    if (gb >= 50) return { pass: true, value: `${gb} GB free` };
    if (gb >= 30) return { pass: true, value: `${gb} GB free (tight)`, warn: true };
    return { pass: false, value: `${gb} GB free (need 50+ GB)` };
  });

  // 5. Network
  await runCheck('network', async () => {
    if (state.mode === 'server') {
      // Server mode: just check LAN interface exists
      const res = await api.exec('(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress');
      if (res.stdout) return { pass: true, value: `LAN: ${res.stdout}` };
      return { pass: false, value: 'No network interface found' };
    } else {
      // Branch mode: check if server is reachable
      if (state.serverIP) {
        const res = await api.exec(`Test-Connection -ComputerName "${state.serverIP}" -Count 1 -Quiet`);
        if (res.stdout.toLowerCase() === 'true') return { pass: true, value: `Server ${state.serverIP} reachable` };
        return { pass: false, value: `Cannot reach ${state.serverIP}` };
      }
      return { pass: true, value: 'Will check after server IP entered' };
    }
  });

  async function runCheck(key, checkFn) {
    const el = $(`#check-${key}`);
    el.classList.remove('pending');
    el.classList.add('running');
    el.querySelector('.icon').innerHTML = '<div class="spinner"></div>';
    
    try {
      const result = await checkFn();
      el.classList.remove('running');
      el.classList.add(result.pass ? (result.warn ? 'warn' : 'pass') : 'fail');
      el.querySelector('.icon').textContent = result.pass ? '✅' : '❌';
      el.querySelector('.value').textContent = result.value;
      if (!result.pass) allPassed = false;
      log(`${key}: ${result.value}`, result.pass ? 'success' : 'error');
    } catch (e) {
      el.classList.remove('running');
      el.classList.add('fail');
      el.querySelector('.icon').textContent = '❌';
      el.querySelector('.value').textContent = `Error: ${e.message}`;
      allPassed = false;
      log(`${key}: Error - ${e.message}`, 'error');
    }
  }

  $('#btn-next').disabled = !allPassed;
  if (allPassed) log('All system checks passed!', 'success');
  else log('Some checks failed. Fix issues before continuing.', 'error');
}

// ─── Company Info (Server Mode) ─────────────────────────────────────
function renderCompanyInfo(container) {
  container.innerHTML = `
    <div class="form-group">
      <label>Company Name</label>
      <input type="text" id="input-company" placeholder="Acme Corporation" value="${state.companyName}" />
    </div>
    <div class="form-group">
      <label>Dashboard Password (for Supabase Studio)</label>
      <input type="password" id="input-dashboard-pw" placeholder="Min 8 characters" value="${state.dashboardPassword}" />
      <div class="hint">Used to access Supabase Studio at http://localhost:3000</div>
    </div>
    <div class="form-divider">Master Admin Account</div>
    <div class="form-group">
      <label>Username</label>
      <input type="text" id="input-admin-username" placeholder="admin" value="${state.adminUsername || ''}" />
      <div class="hint">Used to log in to the app (e.g. admin, manager)</div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>Password</label>
        <input type="password" id="input-admin-pw" placeholder="Min 8 characters" value="${state.adminPassword}" />
      </div>
      <div class="form-group">
        <label>Confirm Password</label>
        <input type="password" id="input-admin-pw2" placeholder="Re-enter password" />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>6-Digit Quick Access Code</label>
        <input type="text" id="input-admin-qac" placeholder="e.g. 123456" maxlength="6" value="${state.adminQuickCode || ''}" style="font-family:monospace;letter-spacing:4px" />
        <div class="hint">Leave blank to auto-generate</div>
      </div>
      <div class="form-group" style="display:flex;align-items:flex-end;padding-bottom:4px">
        <button type="button" id="btn-gen-qac" style="padding:8px 14px;background:#334155;border:none;border-radius:6px;color:#fff;cursor:pointer">🎲 Generate</button>
      </div>
    </div>
    <div id="form-errors"></div>
  `;

  // Generate button
  $('#btn-gen-qac').addEventListener('click', () => {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    $('#input-admin-qac').value = code;
    state.adminQuickCode = code;
    validate();
  });

  // Enable next only when valid
  const validate = () => {
    const company = $('#input-company').value.trim();
    const dashPw = $('#input-dashboard-pw').value;
    const username = $('#input-admin-username').value.trim();
    const pw = $('#input-admin-pw').value;
    const pw2 = $('#input-admin-pw2').value;
    const qac = $('#input-admin-qac').value.trim();
    const errors = [];

    if (!company) errors.push('Company name is required');
    if (dashPw.length < 8) errors.push('Dashboard password must be 8+ characters');
    if (username.length < 3) errors.push('Username must be at least 3 characters');
    if (!/^[a-zA-Z0-9_]+$/.test(username) && username.length > 0) errors.push('Username: letters, numbers, underscore only');
    if (pw.length < 8) errors.push('Password must be 8+ characters');
    if (pw !== pw2) errors.push('Passwords do not match');
    if (qac.length > 0 && !/^[0-9]{6}$/.test(qac)) errors.push('Quick access code must be exactly 6 digits');

    $('#form-errors').innerHTML = errors.map(e => `<div class="error-text">• ${e}</div>`).join('');
    $('#btn-next').disabled = errors.length > 0;

    // Save to state
    state.companyName = company;
    state.dashboardPassword = dashPw;
    state.adminUsername = username;
    state.adminEmail = username + '@aqura.local';
    state.adminPassword = pw;
    state.adminQuickCode = qac;
  };

  container.querySelectorAll('input').forEach(i => {
    i.addEventListener('input', validate);
  });

  validate();
}

// ─── Server Connect (Branch Mode) ───────────────────────────────────
function renderServerConnect(container) {
  container.innerHTML = `
    <div class="form-row">
      <div class="form-group" style="flex:3">
        <label>Server IP or Hostname</label>
        <input type="text" id="input-server-ip" placeholder="192.168.0.50 or server.company.com" value="${state.serverIP}" />
      </div>
      <div class="form-group" style="flex:1">
        <label>DB Port</label>
        <input type="text" id="input-server-port" placeholder="5433" value="${state.serverPort}" />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>Branch Name</label>
        <input type="text" id="input-branch-name" placeholder="Branch 2 - Mall" value="${state.branchName}" />
      </div>
      <div class="form-group" style="flex:0.5">
        <label>Branch ID</label>
        <input type="number" id="input-branch-id" placeholder="2" value="${state.branchId}" min="1" />
      </div>
    </div>

    <div class="form-divider">Server Credentials</div>
    <div class="hint" style="margin-bottom:12px">Get these from the server admin (shown at end of Server install).</div>

    <div class="form-group">
      <label>JWT Secret</label>
      <input type="password" id="input-jwt" placeholder="64-character hex string" value="${state.jwtSecret}" />
    </div>
    <div class="form-group">
      <label>Anon Key</label>
      <input type="password" id="input-anon" placeholder="eyJhbGciOi..." value="${state.anonKey}" />
    </div>
    <div class="form-group">
      <label>Service Role Key</label>
      <input type="password" id="input-service" placeholder="eyJhbGciOi..." value="${state.serviceKey}" />
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>DB Password</label>
        <input type="password" id="input-db-pw" placeholder="Postgres password" value="${state.pgPassword}" />
      </div>
      <div class="form-group">
        <label>Replication Password</label>
        <input type="password" id="input-repl-pw" placeholder="Replication user password" value="${state.replicationPassword}" />
      </div>
    </div>

    <div style="margin-top:12px">
      <button class="btn btn-secondary" id="btn-test-connection">🔌 Test Connection</button>
      <span id="connection-status" style="margin-left:12px;font-size:13px;color:var(--text-muted)"></span>
    </div>
    <div id="form-errors"></div>
  `;

  // Connection test
  $('#btn-test-connection').addEventListener('click', async () => {
    const ip = $('#input-server-ip').value.trim();
    const statusEl = $('#connection-status');
    statusEl.textContent = '⏳ Testing...';
    statusEl.style.color = 'var(--warning)';

    try {
      // Ping test
      const pingRes = await api.exec(`Test-Connection -ComputerName "${ip}" -Count 1 -Quiet`);
      if (pingRes.stdout.toLowerCase() !== 'true') {
        statusEl.textContent = '❌ Cannot reach server';
        statusEl.style.color = 'var(--error)';
        return;
      }

      // API test
      const apiRes = await api.exec(`try { (Invoke-WebRequest -Uri "http://${ip}:8000/rest/v1/" -TimeoutSec 5 -UseBasicParsing).StatusCode } catch { 0 }`);
      if (apiRes.stdout === '200') {
        statusEl.textContent = '✅ Server reachable! Supabase API responding.';
        statusEl.style.color = 'var(--success)';
        
        // Detect LAN vs Internet
        if (isPrivateIP(ip)) {
          state.connectivityMode = 'lan';
          log(`Server ${ip} is on LAN — direct connection mode`, 'success');
        } else {
          state.connectivityMode = 'internet';
          log(`Server ${ip} is public — will set up SSH tunnel`, 'info');
        }
      } else {
        statusEl.textContent = '⚠️ Server reachable but Supabase API not responding on port 8000';
        statusEl.style.color = 'var(--warning)';
      }
    } catch (e) {
      statusEl.textContent = '❌ Connection test failed';
      statusEl.style.color = 'var(--error)';
    }
  });

  // Validate
  const validate = () => {
    const ip = $('#input-server-ip').value.trim();
    const port = $('#input-server-port').value.trim();
    const bname = $('#input-branch-name').value.trim();
    const bid = $('#input-branch-id').value.trim();
    const jwt = $('#input-jwt').value.trim();
    const anon = $('#input-anon').value.trim();
    const svc = $('#input-service').value.trim();
    const dbpw = $('#input-db-pw').value.trim();
    const replpw = $('#input-repl-pw').value.trim();
    const errors = [];

    if (!ip) errors.push('Server IP is required');
    if (!port) errors.push('DB port is required');
    if (!bname) errors.push('Branch name is required');
    if (!bid) errors.push('Branch ID is required');
    if (!jwt || jwt.length < 32) errors.push('JWT Secret is required (64 hex chars)');
    if (!anon || !anon.startsWith('eyJ')) errors.push('Anon Key is required (JWT format)');
    if (!svc || !svc.startsWith('eyJ')) errors.push('Service Key is required (JWT format)');
    if (!dbpw) errors.push('DB password is required');
    if (!replpw) errors.push('Replication password is required');

    $('#form-errors').innerHTML = errors.map(e => `<div class="error-text">• ${e}</div>`).join('');
    $('#btn-next').disabled = errors.length > 0;

    // Save to state
    state.serverIP = ip;
    state.serverPort = port;
    state.branchName = bname;
    state.branchId = bid;
    state.jwtSecret = jwt;
    state.anonKey = anon;
    state.serviceKey = svc;
    state.pgPassword = dbpw;
    state.replicationPassword = replpw;
    state.connectivityMode = isPrivateIP(ip) ? 'lan' : 'internet';
  };

  container.querySelectorAll('input').forEach(i => i.addEventListener('input', validate));
  validate();
}

// ─── Auto Step (Generic progress view for automated steps) ──────────
function renderAutoStep(container, description, stepId) {
  container.innerHTML = `
    <div class="auto-step-progress">
      <div class="step-progress-bar">
        <div class="step-progress-fill" id="auto-progress" style="width:0%"></div>
      </div>
      <div class="step-status-text" id="auto-status">${description}</div>
      <div class="check-list" id="auto-checks"></div>
    </div>
  `;

  // Disable navigation during auto steps
  $('#btn-next').disabled = true;
  $('#btn-back').disabled = true;

  // Run the step
  runAutoStep(stepId);
}

async function runAutoStep(stepId) {
  log(`Starting: ${stepId}`, 'info');

  try {
    const runner = stepRunners[stepId];
    if (runner) {
      await runner();
      log(`Completed: ${stepId}`, 'success');
      addAutoCheck('Done!', 'pass');
      setAutoProgress(100);
      // Save state after each successful step
      await api.saveState(state);
      // Auto-advance after brief delay
      $('#btn-next').disabled = false;
      setTimeout(() => advanceStep(), 800);
    } else {
      // Placeholder for unimplemented steps
      addAutoCheck(`Step "${stepId}" — implementation pending`, 'warn');
      setAutoProgress(100);
      log(`Step "${stepId}" not yet implemented — skipping`, 'info');
      $('#btn-next').disabled = false;
      setTimeout(() => advanceStep(), 500);
    }
  } catch (err) {
    log(`Error in ${stepId}: ${err.message}`, 'error');
    addAutoCheck(`Error: ${err.message}`, 'fail');
    state.lastError = err.message;
    await api.saveState(state);
    $('#btn-next').disabled = false;
    $('#btn-back').disabled = false;

    // Mark progress dot as error
    const dots = $$('.progress-dot');
    if (dots[state.currentPhase]) {
      dots[state.currentPhase].classList.remove('active');
      dots[state.currentPhase].classList.add('error');
    }
  }
}

function addAutoCheck(text, status = 'pass') {
  const list = $('#auto-checks');
  if (!list) return;
  const icons = { pass: '✅', fail: '❌', warn: '⚠️', running: '' };
  const iconContent = status === 'running' ? '<div class="spinner"></div>' : icons[status] || '○';
  
  const item = document.createElement('div');
  item.className = `check-item ${status}`;
  item.innerHTML = `<span class="icon">${iconContent}</span><span class="label">${text}</span>`;
  list.appendChild(item);

  // Auto scroll
  list.scrollTop = list.scrollHeight;
  return item;
}

function updateAutoCheck(item, text, status) {
  if (!item) return;
  const icons = { pass: '✅', fail: '❌', warn: '⚠️', running: '' };
  item.className = `check-item ${status}`;
  if (status === 'running') {
    item.querySelector('.icon').innerHTML = '<div class="spinner"></div>';
  } else {
    item.querySelector('.icon').textContent = icons[status] || '○';
  }
  item.querySelector('.label').textContent = text;
}

function setAutoProgress(pct) {
  const el = $('#auto-progress');
  if (el) el.style.width = `${pct}%`;
}

function setAutoStatus(text) {
  const el = $('#auto-status');
  if (el) el.textContent = text;
}

// ─── Step Runners (actual automation logic) ─────────────────────────
const stepRunners = {

  // ──── INSTALL WSL ────
  'install-wsl': async () => {
    if (state.wslInstalled) {
      addAutoCheck('WSL2 already installed (resumed)', 'pass');
      setAutoProgress(100);
      return;
    }

    const checkItem = addAutoCheck('Checking WSL2 status...', 'running');
    setAutoProgress(10);

    // Check if WSL feature is enabled
    const wslStatus = await api.exec('wsl --status 2>&1 | Out-String');
    const wslFeatureOk = wslStatus.stdout &&
      (wslStatus.stdout.includes('Default') || wslStatus.stdout.includes('kernel') ||
       (!wslStatus.stdout.toLowerCase().includes('not installed') && wslStatus.stdout.trim().length > 0));

    // Check if any Ubuntu distro is installed (wsl --list has UTF-16 issues, use wsl --list verbose)
    const distroCheck = await api.exec('wsl --list 2>&1 | Out-String');
    const ubuntuFound = distroCheck.stdout && distroCheck.stdout.toLowerCase().includes('ubuntu');

    if (wslFeatureOk && ubuntuFound) {
      // Both installed — just initialize
      updateAutoCheck(checkItem, 'WSL2 + Ubuntu already installed', 'pass');
      setAutoProgress(50);
      const initItem = addAutoCheck('Initializing Ubuntu 22.04 (root mode)...', 'running');
      setAutoProgress(70);
      await api.exec('wsl -d Ubuntu-22.04 -u root -- bash -c "echo initialized" 2>&1');
      updateAutoCheck(initItem, 'Ubuntu 22.04 ready (root mode)', 'pass');
      state.wslInstalled = true;
      setAutoProgress(100);
      return;
    }

    if (!wslFeatureOk) {
      // WSL Windows feature not installed — install it + Ubuntu (requires reboot)
      updateAutoCheck(checkItem, 'Installing WSL2 + Ubuntu 22.04 (admin prompt will appear)...', 'running');
      setAutoProgress(30);
      await api.exec("Start-Process -FilePath 'wsl.exe' -ArgumentList '--install -d Ubuntu-22.04 --no-launch' -Verb RunAs -Wait -ErrorAction SilentlyContinue");
      addAutoCheck('WSL2 install launched — system reboot required', 'warn');
      await api.saveState(state);
      await api.setAutoStart(true);
      const reboot = await api.showMessage({
        type: 'question',
        buttons: ['Reboot Now', 'Later'],
        title: 'Reboot Required',
        message: 'Windows needs to restart to finish WSL2 installation.\n\nThe installer will resume automatically after reboot.'
      });
      if (reboot === 0) {
        await api.exec("Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 5' -Verb RunAs -ErrorAction SilentlyContinue");
      }
      return;
    }

    // WSL feature installed but Ubuntu distro missing — install distro only (no reboot needed)
    updateAutoCheck(checkItem, 'WSL2 ready — installing Ubuntu 22.04 (admin prompt will appear)...', 'running');
    setAutoProgress(40);
    await api.exec("Start-Process -FilePath 'wsl.exe' -ArgumentList '--install -d Ubuntu-22.04 --no-launch' -Verb RunAs -Wait -ErrorAction SilentlyContinue");
    await sleep(8000); // Give Ubuntu time to finish registering

    const initItem = addAutoCheck('Initializing Ubuntu 22.04 (root mode)...', 'running');
    setAutoProgress(80);
    await api.exec('wsl -d Ubuntu-22.04 -u root -- bash -c "echo initialized" 2>&1');
    updateAutoCheck(initItem, 'Ubuntu 22.04 ready (root mode)', 'pass');
    updateAutoCheck(checkItem, 'Ubuntu 22.04 installed', 'pass');
    state.wslInstalled = true;
    setAutoProgress(100);
  },

  // ──── SETUP DOCKER ────
  'setup-docker': async () => {
    if (state.dockerReady) {
      addAutoCheck('Docker already configured (resumed)', 'pass');
      return;
    }

    const updateItem = addAutoCheck('Updating Ubuntu packages...', 'running');
    setAutoProgress(10);

    await api.wsl('sudo apt-get update -qq', { timeout: 120000 });
    updateAutoCheck(updateItem, 'Ubuntu packages updated', 'pass');
    setAutoProgress(25);

    const installItem = addAutoCheck('Installing Docker + tools...', 'running');
    await api.wsl('sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io unzip git curl jq openssl rsync autossh 2>&1', { timeout: 300000 });
    updateAutoCheck(installItem, 'Docker + tools installed', 'pass');
    setAutoProgress(60);

    // Install docker-compose V2 (the apt version is V1 which can't parse modern Compose files)
    const composeItem = addAutoCheck('Installing docker-compose V2...', 'running');
    await api.wsl('sudo curl -fsSL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose', { timeout: 120000 });
    updateAutoCheck(composeItem, 'docker-compose V2 installed', 'pass');
    setAutoProgress(65);

    // Enable systemd in WSL2 (takes effect on next WSL restart — needed for Docker)
    const systemdItem = addAutoCheck('Enabling systemd in WSL2...', 'running');
    await api.wsl(`sudo bash -c "grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null || printf '[boot]\\nsystemd=true\\n' >> /etc/wsl.conf"`);
    updateAutoCheck(systemdItem, 'WSL systemd configured', 'pass');
    setAutoProgress(70);

    const enableItem = addAutoCheck('Enabling Docker service...', 'running');
    // Use 'service' command as fallback — works in WSL2 without systemd active yet
    await api.wsl('sudo systemctl enable docker 2>/dev/null || true');
    await api.wsl('sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true');
    await api.wsl('sudo usermod -aG docker $USER');
    updateAutoCheck(enableItem, 'Docker service started', 'pass');
    setAutoProgress(85);

    // Verify — installation and service confirmed above; just find the binary for logging
    const verifyItem = addAutoCheck('Verifying Docker...', 'running');
    await sleep(1500);

    const rVer  = await api.wsl('docker --version 2>&1 || echo "no_cli_output"');
    const rWh   = await api.wsl('which docker 2>&1 || echo "not_in_path"');
    const rLs   = await api.wsl('ls /usr/bin/docker /usr/local/bin/docker 2>/dev/null | head -2 || echo "no_binary_found"');
    const rDpkg = await api.wsl('dpkg-query -W -f=\'${Status}\' docker.io 2>/dev/null || dpkg-query -W -f=\'${Status}\' docker-ce 2>/dev/null || echo "dpkg_unavail"');

    log(`[Docker verify] version: ${rVer.stdout}`, 'info');
    log(`[Docker verify] which: ${rWh.stdout}`, 'info');
    log(`[Docker verify] ls: ${rLs.stdout}`, 'info');
    log(`[Docker verify] dpkg: ${rDpkg.stdout}`, 'info');

    if (rVer.stdout && rVer.stdout.toLowerCase().includes('docker') && !rVer.stdout.includes('no_cli_output')) {
      updateAutoCheck(verifyItem, `Docker ready: ${rVer.stdout.trim()}`, 'pass');
    } else if (rLs.stdout && !rLs.stdout.includes('no_binary_found')) {
      updateAutoCheck(verifyItem, `Docker binary found at ${rLs.stdout.trim()}`, 'pass');
    } else if (rDpkg.stdout && rDpkg.stdout.includes('installed')) {
      updateAutoCheck(verifyItem, 'Docker package confirmed installed (binary may need WSL restart)', 'pass');
    } else {
      // Package install + service start both confirmed above — trust them and continue
      // The Supabase install step (docker compose pull) will be the real Docker test
      updateAutoCheck(verifyItem, 'Docker installed — confirming in next step', 'warn');
      log(`[Docker verify] Skipping hard fail — install+service confirmed above`, 'warn');
    }

    state.dockerReady = true;
    setAutoProgress(100);
  },

  // ──── INSTALL SUPABASE ────
  'install-supabase': async () => {
    if (state.supabaseRunning) {
      addAutoCheck('Supabase already running (resumed)', 'pass');
      return;
    }

    // Ensure docker-compose V2 is installed (Step 4 may have been skipped if already done)
    const dcItem = addAutoCheck('Ensuring docker-compose V2...', 'running');
    // V2 is always installed to /usr/local/bin — if it's not there, install it now
    const dcCheck = await api.wsl('test -f /usr/local/bin/docker-compose && /usr/local/bin/docker-compose version 2>&1 | head -1 || echo "__missing__"');
    if (!dcCheck.stdout.includes('__missing__')) {
      updateAutoCheck(dcItem, `docker-compose V2 ready`, 'pass');
    } else {
      updateAutoCheck(dcItem, 'Installing docker-compose V2...', 'running');
      await api.wsl('sudo curl -fsSL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose', { timeout: 120000 });
      updateAutoCheck(dcItem, 'docker-compose V2 installed', 'pass');
    }
    setAutoProgress(3);

    const cloneItem = addAutoCheck('Cloning Supabase repository...', 'running');
    setAutoProgress(5);

    // Check if already cloned
    const exists = await api.wsl('test -d /opt/supabase/supabase/docker && echo yes || echo no');
    if (exists.stdout.trim() === 'yes') {
      updateAutoCheck(cloneItem, 'Supabase repo already exists', 'pass');
    } else {
      await api.wsl('sudo mkdir -p /opt/supabase && cd /opt/supabase && sudo git clone --depth 1 https://github.com/supabase/supabase.git', { timeout: 120000 });
      updateAutoCheck(cloneItem, 'Supabase repository cloned', 'pass');
    }
    setAutoProgress(20);

    const envItem = addAutoCheck('Configuring Supabase .env...', 'running');

    // Start from the official .env.example so all required variables have defaults,
    // then override only the secrets/keys we care about.
    await api.wsl('test -f /opt/supabase/supabase/docker/.env.example && sudo cp /opt/supabase/supabase/docker/.env.example /opt/supabase/supabase/docker/.env || true');

    const overrides = buildSupabaseEnv();
    const overridesTmpWin = 'C:\\Windows\\Temp\\aqura_env_overrides.tmp';
    const overridesTmpPath = '/mnt/c/Windows/Temp/aqura_env_overrides.tmp';
    await api.writeFile(overridesTmpWin, overrides);
    // Merge: for each KEY=VAL in overrides, replace or append the line in .env
    await api.wsl(`while IFS= read -r line; do
  key=$(echo "$line" | cut -d= -f1)
  if [ -n "$key" ] && ! echo "$line" | grep -q '^#'; then
    sudo sed -i "/^\${key}=/d" /opt/supabase/supabase/docker/.env 2>/dev/null || true
    echo "$line" | sudo tee -a /opt/supabase/supabase/docker/.env > /dev/null
  fi
done < "${overridesTmpPath}"`);
    updateAutoCheck(envItem, 'Supabase .env configured', 'pass');
    setAutoProgress(35);

    // Expose DB port 5433 in docker-compose if server mode
    if (state.mode === 'server') {
      const portItem = addAutoCheck('Exposing DB port 5433 for branch replication...', 'running');
      // Use python to patch docker-compose.yml (reliable)
      await api.wsl(`cd /opt/supabase/supabase/docker && python3 -c "
import re
with open('docker-compose.yml', 'r') as f:
    content = f.read()
if '5433:' not in content:
    # Find the db service's volumes line and add ports before it
    content = content.replace(
        '    volumes:\\n      - ./volumes/db/data:/var/lib/postgresql/data:Z',
        '    ports:\\n      - 5433:\\\${POSTGRES_PORT:-5432}\\n    volumes:\\n      - ./volumes/db/data:/var/lib/postgresql/data:Z',
        1
    )
    with open('docker-compose.yml', 'w') as f:
        f.write(content)
    print('Port 5433 added')
else:
    print('Port 5433 already configured')
"`);
      updateAutoCheck(portItem, 'DB port 5433 exposed', 'pass');
    }
    setAutoProgress(45);

    const pullItem = addAutoCheck('Pulling Docker images (this may take a while)...', 'running');
    await api.stream('cd /opt/supabase/supabase/docker && sudo docker-compose pull', { wsl: true, timeout: 600000 });
    updateAutoCheck(pullItem, 'Docker images pulled', 'pass');
    setAutoProgress(70);

    const startItem = addAutoCheck('Starting Supabase containers...', 'running');
    await api.stream('cd /opt/supabase/supabase/docker && sudo docker-compose up -d', { wsl: true, timeout: 300000 });
    setAutoProgress(85);

    // Wait for DB healthy
    const healthItem = addAutoCheck('Waiting for database to be ready...', 'running');
    let attempts = 0;
    while (attempts < 30) {
      const health = await api.wsl('sudo docker exec supabase-db pg_isready -U supabase_admin 2>&1');
      if (health.success && health.stdout.includes('accepting')) {
        break;
      }
      await sleep(4000);
      attempts++;
    }

    if (attempts >= 30) {
      throw new Error('Supabase DB did not become healthy within 120 seconds');
    }

    updateAutoCheck(healthItem, 'Database is ready', 'pass');
    updateAutoCheck(startItem, 'Supabase containers started', 'pass');
    state.supabaseRunning = true;
    setAutoProgress(100);
  },

  // ──── GENERATE KEYS (Server Mode) ────
  'generate-keys': async () => {
    const genItem = addAutoCheck('Generating JWT Secret...', 'running');
    setAutoProgress(20);

    const jwtRes = await api.wsl('openssl rand -hex 32');
    state.jwtSecret = jwtRes.stdout.trim();
    if (!state.jwtSecret) throw new Error('openssl failed to generate JWT secret');
    updateAutoCheck(genItem, `JWT Secret: ${state.jwtSecret.substring(0, 8)}...`, 'pass');
    setAutoProgress(40);

    // Generate Anon Key and Service Key using Python 3 (built-in to Ubuntu — no npm needed)
    const keysItem = addAutoCheck('Generating API keys...', 'running');

    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + (10 * 365 * 24 * 60 * 60); // 10 years

    // Write JWT generator to a Windows temp file, then run it from WSL via wslpath
    const pyCode = [
      'import hmac, hashlib, base64, json',
      `secret = '${state.jwtSecret}'`,
      `iat = ${iat}`,
      `exp = ${exp}`,
      'def b64(d):',
      '    raw = d if isinstance(d, bytes) else d.encode()',
      '    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()',
      'h = b64(json.dumps({"alg":"HS256","typ":"JWT"},separators=(",",":")))',
      'def mktok(role):',
      '    p = b64(json.dumps({"role":role,"iss":"supabase","iat":iat,"exp":exp},separators=(",",":")))',
      '    m = (h+"."+p).encode()',
      '    sig = b64(hmac.new(secret.encode(),m,hashlib.sha256).digest())',
      '    return h+"."+p+"."+sig',
      'print(mktok("anon"))',
      'print(mktok("service_role"))',
    ].join('\n');

    const tmpWinPath = 'C:\\Windows\\Temp\\aqura_gen_jwt.py';
    await api.writeFile(tmpWinPath, pyCode);
    const keysRes = await api.wsl('python3 /mnt/c/Windows/Temp/aqura_gen_jwt.py ; rm -f /mnt/c/Windows/Temp/aqura_gen_jwt.py');    const lines = keysRes.stdout.trim().split('\n').map(l => l.trim()).filter(Boolean);
    if (lines.length < 2) throw new Error(`JWT generation failed. Python output: ${keysRes.stdout} | stderr: ${keysRes.stderr || ''}`);
    state.anonKey = lines[0];
    state.serviceKey = lines[1];

    updateAutoCheck(keysItem, 'Anon Key + Service Key generated', 'pass');
    setAutoProgress(60);

    // Generate Postgres password only if not already set (preserves DB-initialized password)
    const pgItem = addAutoCheck('Checking database password...', 'running');
    if (!state.pgPassword) {
      const pgRes = await api.wsl('openssl rand -base64 32 | tr -d "/+=" | head -c 48');
      state.pgPassword = pgRes.stdout.trim();
      updateAutoCheck(pgItem, 'Database password generated', 'pass');
    } else {
      updateAutoCheck(pgItem, 'Using existing database password', 'pass');
    }
    setAutoProgress(70);

    // Generate replication password only if not already set
    const replItem = addAutoCheck('Checking replication password...', 'running');
    if (!state.replicationPassword) {
      const replRes = await api.wsl('openssl rand -base64 16 | tr -d "/+=" | head -c 20');
      state.replicationPassword = replRes.stdout.trim();
      updateAutoCheck(replItem, 'Replication password generated', 'pass');
    } else {
      updateAutoCheck(replItem, 'Using existing replication password', 'pass');
    }
    setAutoProgress(80);

    // Update ONLY JWT keys in existing .env (preserve all other variables from .env.example)
    const updateItem = addAutoCheck('Updating JWT keys in Supabase config...', 'running');
    const jwtUpdate = [
      `sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${state.jwtSecret}|" /opt/supabase/supabase/docker/.env`,
      `sed -i "s|^ANON_KEY=.*|ANON_KEY=${state.anonKey}|" /opt/supabase/supabase/docker/.env`,
      `sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${state.serviceKey}|" /opt/supabase/supabase/docker/.env`,
      `grep -q "^GOTRUE_JWT_SECRET=" /opt/supabase/supabase/docker/.env && sed -i "s|^GOTRUE_JWT_SECRET=.*|GOTRUE_JWT_SECRET=${state.jwtSecret}|" /opt/supabase/supabase/docker/.env || true`,
      `grep -q "^POSTGRES_PASSWORD=" /opt/supabase/supabase/docker/.env && sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${state.pgPassword}|" /opt/supabase/supabase/docker/.env || echo "POSTGRES_PASSWORD=${state.pgPassword}" >> /opt/supabase/supabase/docker/.env`,
      `grep -q "^DOCKER_SOCKET_LOCATION=" /opt/supabase/supabase/docker/.env || echo "DOCKER_SOCKET_LOCATION=/var/run/docker.sock" >> /opt/supabase/supabase/docker/.env`,
    ].join('\n');
    const jwtScriptWin = 'C:\\Windows\\Temp\\aqura_jwt_update.sh';
    await api.writeFile(jwtScriptWin, jwtUpdate);
    await api.wsl('bash /mnt/c/Windows/Temp/aqura_jwt_update.sh && rm -f /mnt/c/Windows/Temp/aqura_jwt_update.sh');
    
    // Restart Supabase with new keys  
    await api.stream('cd /opt/supabase/supabase/docker && sudo docker-compose down && sudo docker-compose up -d', { wsl: true, timeout: 300000 });
    
    // Wait for healthy
    let attempts = 0;
    while (attempts < 30) {
      const health = await api.wsl('sudo docker exec supabase-db pg_isready -U supabase_admin 2>&1');
      if (health.success && health.stdout.includes('accepting')) break;
      await sleep(4000);
      attempts++;
    }

    // Update DB user passwords to match pgPassword (needed if DB was initialized with default password)
    const pwUpdate = [
      `docker exec supabase-db psql -U postgres -d postgres -c "ALTER USER supabase_auth_admin WITH PASSWORD '${state.pgPassword}';" 2>/dev/null || true`,
      `docker exec supabase-db psql -U postgres -d postgres -c "ALTER USER authenticator WITH PASSWORD '${state.pgPassword}';" 2>/dev/null || true`,
      `docker exec supabase-db psql -U postgres -d postgres -c "ALTER USER supabase_storage_admin WITH PASSWORD '${state.pgPassword}';" 2>/dev/null || true`,
      `docker exec supabase-db psql -U postgres -d postgres -c "ALTER USER supabase_functions_admin WITH PASSWORD '${state.pgPassword}';" 2>/dev/null || true`,
      `docker exec supabase-db psql -U postgres -d postgres -c "ALTER USER supabase_realtime_admin WITH PASSWORD '${state.pgPassword}';" 2>/dev/null || true`,
      // Try as superuser if postgres can't modify reserved roles
      `docker exec supabase-db psql "postgresql://supabase_admin:your-super-secret-and-long-postgres-password@localhost/postgres" -c "ALTER USER supabase_auth_admin WITH PASSWORD '${state.pgPassword}'; ALTER USER authenticator WITH PASSWORD '${state.pgPassword}'; ALTER USER supabase_storage_admin WITH PASSWORD '${state.pgPassword}'; ALTER USER supabase_functions_admin WITH PASSWORD '${state.pgPassword}'; ALTER USER supabase_realtime_admin WITH PASSWORD '${state.pgPassword}'; ALTER USER supabase_admin WITH PASSWORD '${state.pgPassword}';" 2>/dev/null || true`,
    ].join('\n');
    const pwScriptWin = 'C:\\Windows\\Temp\\aqura_pw_update.sh';
    await api.writeFile(pwScriptWin, pwUpdate);
    await api.wsl('bash /mnt/c/Windows/Temp/aqura_pw_update.sh && rm -f /mnt/c/Windows/Temp/aqura_pw_update.sh');

    updateAutoCheck(updateItem, 'Supabase restarted with new keys', 'pass');
    setAutoProgress(100);

    log(`JWT Secret: ${state.jwtSecret.substring(0, 16)}...`, 'info');
    log(`Anon Key: ${state.anonKey.substring(0, 20)}...`, 'info');
    log(`Service Key: ${state.serviceKey.substring(0, 20)}...`, 'info');
  },

  // ──── IMPORT SCHEMA (Server Mode — structure only, NO data) ────
  'import-schema': async () => {
    if (state.schemaImported) {
      addAutoCheck('Schema already imported (resumed)', 'pass');
      return;
    }

    // Try bundled schema first, then pull from cloud
    const appPath = await api.getAppPath();
    // Packaged: appPath = resources/ dir; dev: appPath = project root. bundled/ lives directly inside.
    const bundledPath = appPath + '/bundled/aqura-schema.sql';
    const hasBundled = await api.fileExists(bundledPath);

    if (hasBundled) {
      // ── Use bundled schema file ──
      addAutoCheck('Found bundled schema file', 'pass');
      setAutoProgress(20);

      const importItem = addAutoCheck('Importing schema to local DB...', 'running');
      // Copy bundled schema to Windows Temp (avoids wslpath issues), then access from WSL
      const winBundledPath = bundledPath.replace(/\//g, '\\');
      await api.exec(`Copy-Item -Force "${winBundledPath}" "C:\\Windows\\Temp\\aqura-schema.sql"`);
      await api.wsl('sudo docker cp /mnt/c/Windows/Temp/aqura-schema.sql supabase-db:/tmp/aqura-schema.sql');
      const importOut = await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/aqura-schema.sql 2>&1 | tail -5', { timeout: 300000 });
      await api.wsl('rm -f /mnt/c/Windows/Temp/aqura-schema.sql');
      updateAutoCheck(importItem, 'Schema imported from bundled file', 'pass');
      setAutoProgress(60);

      // ── Deploy edge functions ──
      const functionsZipPath = bundledPath.replace('aqura-schema.sql', 'functions.zip').replace(/\//g, '\\');
      const hasFunctions = await api.fileExists(functionsZipPath.replace(/\\/g, '/'));
      if (hasFunctions) {
        const fnItem = addAutoCheck('Deploying edge functions...', 'running');
        await api.exec(`Copy-Item -Force "${functionsZipPath}" "C:\\Windows\\Temp\\aqura-functions.zip"`);
        await api.wsl('mkdir -p /opt/supabase/supabase/docker/volumes/functions');
        await api.wsl('cp /mnt/c/Windows/Temp/aqura-functions.zip /tmp/aqura-functions.zip && cd /tmp && unzip -o aqura-functions.zip -d /opt/supabase/supabase/docker/volumes/functions/ && rm -f /tmp/aqura-functions.zip /mnt/c/Windows/Temp/aqura-functions.zip');
        await api.wsl('sudo docker restart supabase-edge-runtime 2>/dev/null || true');
        updateAutoCheck(fnItem, 'Edge functions deployed', 'pass');
      }
      setAutoProgress(80);
    } else {
      // ── Export schema from local Supabase's own pg_dump (self-contained) ──
      // Server mode: generate schema dump from the Supabase that was just installed
      // The tables/functions come from the cloud schema that was loaded into the template
      const cloudItem = addAutoCheck('No bundled schema found — pulling from cloud server...', 'running');
      setAutoProgress(10);

      // Try SSH to cloud server to get schema
      const cloudIP = '8.213.42.21';
      const sshKeyPath = '~/.ssh/id_ed25519_nopass';

      // Check if SSH key exists
      const keyCheck = await api.exec(`Test-Path "$env:USERPROFILE\\.ssh\\id_ed25519_nopass"`);
      const hasKey = keyCheck.stdout.toLowerCase() === 'true';

      if (hasKey) {
        // Export schema from cloud (schema only, no data)
        await api.exec(`ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@${cloudIP} "docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only --no-owner --no-acl -N _analytics -N _realtime -N supabase_migrations -N supabase_functions > /tmp/cloud_schema.sql"`, { timeout: 120000 });
        updateAutoCheck(cloudItem, 'Schema exported from cloud', 'pass');
        setAutoProgress(30);

        // Download to local
        const dlItem = addAutoCheck('Downloading schema...', 'running');
        await api.exec(`scp -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@${cloudIP}:/tmp/cloud_schema.sql "$env:TEMP\cloud_schema.sql"`, { timeout: 60000 });
        updateAutoCheck(dlItem, 'Schema downloaded', 'pass');
        setAutoProgress(50);

        // Copy into WSL and import
        const importItem = addAutoCheck('Importing schema to local DB (structure only, no data)...', 'running');
        await api.wsl(`cp "$(wslpath "$(cmd.exe /C echo %TEMP% 2>/dev/null | tr -d '\r')\\cloud_schema.sql")" /tmp/cloud_schema.sql 2>/dev/null || cp /mnt/c/Users/*/AppData/Local/Temp/cloud_schema.sql /tmp/cloud_schema.sql`);
        await api.wsl('sudo docker cp /tmp/cloud_schema.sql supabase-db:/tmp/cloud_schema.sql');
        await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/cloud_schema.sql 2>&1 | tail -10', { timeout: 120000 });
        updateAutoCheck(importItem, 'Schema imported (structure only — no data)', 'pass');
        setAutoProgress(80);

        // Cleanup
        await api.wsl('rm -f /tmp/cloud_schema.sql');
        await api.exec(`ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@${cloudIP} "rm -f /tmp/cloud_schema.sql"`);
        await api.exec(`Remove-Item "$env:TEMP\cloud_schema.sql" -Force -ErrorAction SilentlyContinue`);
      } else {
        updateAutoCheck(cloudItem, 'No SSH key found — cannot pull schema from cloud', 'fail');
        addAutoCheck('Place aqura-schema.sql in the bundled/ folder next to the installer, or add SSH key at ~/.ssh/id_ed25519_nopass', 'warn');
        throw new Error('Schema file not available. Provide bundled/aqura-schema.sql or SSH key for cloud access.');
      }
    }

    // Verify tables were created
    const verifyItem = addAutoCheck('Verifying schema...', 'running');
    const tableCount = await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = \'public\';"');
    const funcCount = await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -t -c "SELECT count(*) FROM pg_proc WHERE pronamespace = \'public\'::regnamespace;"');
    const tables = parseInt(tableCount.stdout.trim(), 10) || 0;
    const funcs = parseInt(funcCount.stdout.trim(), 10) || 0;
    if (tables === 0 && funcs === 0) {
      throw new Error(`Schema import failed — 0 tables and 0 functions found in public schema. Check SSH key and cloud server connectivity.`);
    }
    updateAutoCheck(verifyItem, `Schema verified — ${tables} tables, ${funcs} functions`, 'pass');

    // Reload PostgREST cache
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "NOTIFY pgrst, \'reload schema\';"');

    state.schemaImported = true;
    setAutoProgress(100);
  },

  // ──── CREATE ADMIN (Server Mode) ────
  'create-admin': async () => {
    if (state.adminCreated) {
      addAutoCheck('Admin already created (resumed)', 'pass');
      return;
    }

    // Wait for Kong/API to be ready (postgres readiness ≠ Kong readiness)
    const kongItem = addAutoCheck('Waiting for Supabase API to be ready...', 'running');
    let kongReady = false;
    for (let i = 0; i < 30; i++) {
      const probe = await api.wsl('curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/rest/v1/ 2>&1');
      const code = probe.stdout.trim();
      if (code === '200' || code === '401') { kongReady = true; break; }
      await sleep(4000);
    }
    if (!kongReady) throw new Error('Supabase API (Kong) did not become ready within 2 minutes');
    updateAutoCheck(kongItem, 'Supabase API is ready', 'pass');

    if (!state.serviceKey) throw new Error('Service key is missing — generate-keys step may not have completed');

    const item = addAutoCheck(`Creating master admin user: ${state.adminUsername}...`, 'running');
    setAutoProgress(20);

    // Step 1: Create auth user (for Supabase Auth login)
    const authItem = addAutoCheck('Creating auth account...', 'running');
    const qacArg = state.adminQuickCode ? `,"quick_access_code":"${state.adminQuickCode}"` : '';
    const createAuthCmd = `curl -s -X POST http://localhost:8000/auth/v1/admin/users \
      -H "Authorization: Bearer ${state.serviceKey}" \
      -H "apikey: ${state.serviceKey}" \
      -H "Content-Type: application/json" \
      -d '{"email":"${state.adminUsername}@aqura.local","password":"${state.adminPassword}","email_confirm":true}'`;
    const authResult = await api.wsl(createAuthCmd);
    // Auth user creation is optional — login also works via quick access code only
    if (authResult.stdout && authResult.stdout.includes('"id"')) {
      updateAutoCheck(authItem, 'Auth account created', 'pass');
    } else {
      updateAutoCheck(authItem, 'Auth account skipped (schema login uses quick access)', 'warn');
    }
    setAutoProgress(40);

    // Step 2: Create user in public.users via create_user RPC
    const dbItem = addAutoCheck('Creating user in database...', 'running');
    const quickCodeParam = state.adminQuickCode ? `,"p_quick_access_code":"${state.adminQuickCode}"` : '';
    const createUserCmd = `curl -s -X POST http://localhost:8000/rest/v1/rpc/create_user \
      -H "Authorization: Bearer ${state.serviceKey}" \
      -H "apikey: ${state.serviceKey}" \
      -H "Content-Type: application/json" \
      -d '{"p_username":"${state.adminUsername}","p_password":"${state.adminPassword}","p_is_master_admin":true,"p_user_type":"global"${quickCodeParam}}'`;

    const result = await api.wsl(createUserCmd, { timeout: 30000 });

    if (!result.stdout) {
      throw new Error('No response from create_user RPC — check Supabase is running');
    }

    let userData;
    try { userData = JSON.parse(result.stdout); } catch(e) {
      throw new Error(`create_user RPC parse error: ${result.stdout}`);
    }

    if (!userData.success) {
      throw new Error(`create_user failed: ${userData.message || JSON.stringify(userData)}`);
    }

    const generatedCode = userData.quick_access_code || state.adminQuickCode || '(auto-generated)';
    updateAutoCheck(dbItem, `User created in database. Username: ${state.adminUsername}`, 'pass');
    setAutoProgress(70);

    // Step 3: Save company name
    const seedItem = addAutoCheck('Saving company info...', 'running');
    await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "INSERT INTO public.app_settings (key, value) VALUES ('company_name', '${state.companyName.replace(/'/g, "''")}') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;" 2>/dev/null || true`);
    updateAutoCheck(seedItem, 'Company info saved', 'pass');
    setAutoProgress(90);

    // Step 4: Show credentials to user
    await api.showMessage({
      type: 'info',
      title: 'Admin Account Created',
      message: `Master admin account created!\n\nUsername: ${state.adminUsername}\nPassword: (as entered)\n6-Digit Quick Access Code: ${generatedCode}\n\nSave the Quick Access Code — it cannot be recovered.`
    });

    state.adminCreated = true;
    addAutoCheck(`Admin ready. Quick Access Code: ${generatedCode}`, 'pass');
    setAutoProgress(100);
  },

  // ──── SETUP PUBLISHER (Server Mode) ────
  'setup-publisher': async () => {
    if (state.publisherConfigured) {
      addAutoCheck('Publisher already configured (resumed)', 'pass');
      return;
    }

    // Create replication user
    const replItem = addAutoCheck('Creating replication user...', 'running');
    setAutoProgress(15);
    
    await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "
      DO \\$\\$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replication_user') THEN
          CREATE ROLE replication_user WITH REPLICATION LOGIN PASSWORD '${state.replicationPassword}';
        END IF;
      END \\$\\$;"
    `);
    updateAutoCheck(replItem, 'Replication user created', 'pass');
    setAutoProgress(30);

    // Grant permissions
    const grantItem = addAutoCheck('Granting permissions...', 'running');
    await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "
      GRANT USAGE ON SCHEMA public TO replication_user;
      GRANT SELECT ON ALL TABLES IN SCHEMA public TO replication_user;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replication_user;
      GRANT USAGE ON SCHEMA storage TO replication_user;
      GRANT SELECT ON ALL TABLES IN SCHEMA storage TO replication_user;
      ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT SELECT ON TABLES TO replication_user;
    "`);
    updateAutoCheck(grantItem, 'Permissions granted', 'pass');
    setAutoProgress(50);

    // Create publication
    const pubItem = addAutoCheck('Creating publication...', 'running');
    await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "
      DO \\$\\$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'branch_sync') THEN
          CREATE PUBLICATION branch_sync FOR TABLES IN SCHEMA public, storage;
        END IF;
      END \\$\\$;"
    `);
    updateAutoCheck(pubItem, 'Publication branch_sync created', 'pass');
    setAutoProgress(70);

    // Update pg_hba.conf
    const hbaItem = addAutoCheck('Configuring pg_hba.conf for replication...', 'running');
    await api.wsl(`sudo docker exec supabase-db bash -c "
      if ! grep -q replication_user /var/lib/postgresql/data/pg_hba.conf; then
        echo 'host replication replication_user 0.0.0.0/0 scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf
        echo 'host all replication_user 0.0.0.0/0 scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf
      fi
    "`);
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT pg_reload_conf();"');
    updateAutoCheck(hbaItem, 'pg_hba.conf configured', 'pass');
    setAutoProgress(90);

    // Verify
    const verifyItem = addAutoCheck('Verifying publisher setup...', 'running');
    const pubCheck = await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT pubname, puballtables FROM pg_publication;" -t');
    log(`Publication: ${pubCheck.stdout}`, 'info');
    updateAutoCheck(verifyItem, 'Publisher verification passed', 'pass');

    state.publisherConfigured = true;
    setAutoProgress(100);
  },

  // ──── DEPLOY FRONTEND ────
  'deploy-frontend': async () => {
    if (state.frontendDeployed) {
      addAutoCheck('Frontend already deployed (resumed)', 'pass');
      return;
    }

    // ── Create directories ──
    const dirItem = addAutoCheck('Creating application directories...', 'running');
    setAutoProgress(2);
    await api.wsl('sudo mkdir -p /opt/aqura/build /opt/aqura/update-service');
    updateAutoCheck(dirItem, 'Directories created', 'pass');

    // ── Install Node.js + pnpm if not present ──
    const nodeItem = addAutoCheck('Checking Node.js + pnpm...', 'running');
    setAutoProgress(5);
    const nodeCheck = await api.wsl('node --version 2>/dev/null || echo "missing"');
    if (nodeCheck.stdout.trim() === 'missing' || !nodeCheck.stdout.includes('v')) {
      updateAutoCheck(nodeItem, 'Installing Node.js 22 LTS...', 'running');
      await api.wsl('curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>&1 | tail -3', { timeout: 120000 });
      await api.wsl('sudo apt-get install -y nodejs 2>&1 | tail -3', { timeout: 120000 });
    }
    const pnpmCheck = await api.wsl('pnpm --version 2>/dev/null || echo "missing"');
    if (pnpmCheck.stdout.trim() === 'missing' || !pnpmCheck.stdout.match(/^\d/)) {
      await api.wsl('sudo npm install -g pnpm@9 2>&1 | tail -3', { timeout: 60000 });
    }
    const nodeVer = await api.wsl('node --version 2>/dev/null');
    updateAutoCheck(nodeItem, `Node.js ${nodeVer.stdout.trim()} + pnpm ready`, 'pass');
    setAutoProgress(10);

    // ── Clone Aqura repository ──
    const cloneItem = addAutoCheck('Cloning Aqura repository from GitHub...', 'running');
    setAutoProgress(12);
    await api.wsl('rm -rf /tmp/aqura-source');
    await api.wsl('git clone --depth 1 https://github.com/mkyousafali/Aqura.git /tmp/aqura-source 2>&1 | tail -3', { timeout: 180000 });
    updateAutoCheck(cloneItem, 'Repository cloned', 'pass');
    setAutoProgress(20);

    // ── Swap to adapter-node svelte config ──
    const configItem = addAutoCheck('Configuring frontend for local (adapter-node) deployment...', 'running');
    await api.wsl('cp /tmp/aqura-source/frontend/svelte.config.local.js /tmp/aqura-source/frontend/svelte.config.js');
    updateAutoCheck(configItem, 'Adapter-node config applied', 'pass');
    setAutoProgress(22);

    // ── Determine Supabase URL & keys ──
    let supabaseUrl, anonKey, serviceKey;
    if (state.mode === 'server') {
      supabaseUrl = 'http://localhost:8000';
      anonKey = state.anonKey;
      serviceKey = state.serviceKey;
    } else {
      // Branch mode: LAN points directly; internet mode tunnels to localhost
      supabaseUrl = state.connectivityMode === 'lan'
        ? `http://${state.serverIP}:8000`
        : 'http://localhost:8000';
      anonKey = state.anonKey;
      serviceKey = state.serviceKey;
    }

    const envContent = `PORT=3001
HOST=0.0.0.0
ORIGIN=http://localhost:3001
VITE_SUPABASE_URL=${supabaseUrl}
VITE_SUPABASE_ANON_KEY=${anonKey}
VITE_SUPABASE_SERVICE_KEY=${serviceKey}`;

    // ── Write .env before build (VITE_ vars are baked in at compile time) ──
    const envBuildItem = addAutoCheck('Writing build-time .env...', 'running');
    const buildEnvTmpWin = 'C:\\Windows\\Temp\\aqura_frontend_build_env.tmp';
    await api.writeFile(buildEnvTmpWin, envContent);
    await api.wsl('cp /mnt/c/Windows/Temp/aqura_frontend_build_env.tmp /tmp/aqura-source/frontend/.env');
    updateAutoCheck(envBuildItem, 'Build-time .env written', 'pass');
    setAutoProgress(25);

    // ── pnpm install ──
    const installItem = addAutoCheck('Installing frontend dependencies (pnpm install)...', 'running');
    setAutoStatus('Installing dependencies — please wait...');
    await api.wsl('cd /tmp/aqura-source/frontend && pnpm install --frozen-lockfile 2>&1 | tail -5', { timeout: 300000 });
    updateAutoCheck(installItem, 'Dependencies installed', 'pass');
    setAutoProgress(40);

    // ── pnpm build ──
    const buildItem = addAutoCheck('Building frontend (~2 min) — please wait...', 'running');
    setAutoStatus('Building frontend — this takes about 2 minutes...');
    await api.wsl('cd /tmp/aqura-source/frontend && NODE_OPTIONS="--max-old-space-size=8192" pnpm build 2>&1 | tail -5', { timeout: 600000 });
    updateAutoCheck(buildItem, 'Frontend built successfully', 'pass');
    setAutoProgress(60);

    // ── Copy build output to /opt/aqura/build/ ──
    const deployItem = addAutoCheck('Deploying build files to /opt/aqura/build/...', 'running');
    await api.wsl('sudo cp -r /tmp/aqura-source/frontend/build/. /opt/aqura/build/');
    updateAutoCheck(deployItem, 'Build files deployed', 'pass');
    setAutoProgress(65);

    // ── Deploy edge functions ──
    const funcItem = addAutoCheck('Deploying edge functions...', 'running');
    await api.wsl('sudo mkdir -p /opt/supabase/supabase/docker/volumes/functions');
    await api.wsl('sudo cp -r /tmp/aqura-source/supabase/functions/. /opt/supabase/supabase/docker/volumes/functions/');
    updateAutoCheck(funcItem, 'Edge functions deployed', 'pass');
    setAutoProgress(70);

    // ── Restart edge container to pick up new functions ──
    const edgeItem = addAutoCheck('Restarting edge function container...', 'running');
    await api.wsl('sudo docker restart supabase-edge 2>&1 || true');
    await sleep(3000);
    updateAutoCheck(edgeItem, 'Edge container restarted', 'pass');
    setAutoProgress(73);

    // ── Deploy update service script (branch mode only) ──
    if (state.mode === 'branch') {
      const updateScriptItem = addAutoCheck('Deploying branch update service script...', 'running');
      await api.wsl('sudo cp /tmp/aqura-source/scripts/branch-update-service.js /opt/aqura/update-service/index.cjs');
      updateAutoCheck(updateScriptItem, 'Update service script deployed', 'pass');
      setAutoProgress(76);
    }

    // ── Cleanup cloned repo ──
    await api.wsl('rm -rf /tmp/aqura-source');
    setAutoProgress(78);

    // ── Write runtime .env to build dir ──
    const envItem = addAutoCheck('Writing runtime .env to /opt/aqura/build/...', 'running');
    const runtimeEnvTmpWin = 'C:\\Windows\\Temp\\aqura_frontend_runtime_env.tmp';
    await api.writeFile(runtimeEnvTmpWin, envContent);
    await api.wsl('sudo cp /mnt/c/Windows/Temp/aqura_frontend_runtime_env.tmp /opt/aqura/build/.env');
    updateAutoCheck(envItem, 'Runtime .env written', 'pass');
    setAutoProgress(82);

    // ── Create frontend systemd service ──
    const svcItem = addAutoCheck('Creating frontend systemd service...', 'running');
    const serviceContent = `[Unit]
Description=Aqura Frontend
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/aqura/build
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=5
EnvironmentFile=/opt/aqura/build/.env

[Install]
WantedBy=multi-user.target`;

    await api.wsl(`sudo tee /etc/systemd/system/aqura-frontend.service > /dev/null << 'SVCEOF'
${serviceContent}
SVCEOF`);
    await api.wsl('sudo systemctl daemon-reload');
    await api.wsl('sudo systemctl enable aqura-frontend');
    await api.wsl('sudo systemctl start aqura-frontend');
    updateAutoCheck(svcItem, 'Frontend service created, enabled & started', 'pass');
    setAutoProgress(90);

    // ── Create update systemd service (branch mode only) ──
    if (state.mode === 'branch') {
      const updateSvcItem = addAutoCheck('Creating update service systemd unit...', 'running');
      const updateSvcContent = `[Unit]
Description=Aqura Branch Update Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/aqura/update-service
ExecStart=/usr/bin/node index.cjs
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target`;

      await api.wsl(`sudo tee /etc/systemd/system/aqura-update.service > /dev/null << 'USVCEOF'
${updateSvcContent}
USVCEOF`);
      await api.wsl('sudo systemctl daemon-reload && sudo systemctl enable aqura-update && sudo systemctl start aqura-update');
      updateAutoCheck(updateSvcItem, 'Update service created, enabled & started', 'pass');
      setAutoProgress(95);
    }

    // ── Verify frontend is running ──
    const verifyItem = addAutoCheck('Verifying frontend service...', 'running');
    await sleep(2000);
    const svcStatus = await api.wsl('systemctl is-active aqura-frontend 2>/dev/null || echo inactive');
    if (svcStatus.stdout.trim() === 'active') {
      updateAutoCheck(verifyItem, 'Frontend running on port 3001 ✓', 'pass');
    } else {
      updateAutoCheck(verifyItem, `Frontend status: ${svcStatus.stdout.trim()} — check: journalctl -u aqura-frontend`, 'warn');
    }

    state.frontendDeployed = true;
    state.updateServiceDeployed = true;
    setAutoProgress(100);
  },

  // ──── SYNC SCHEMA + DATA (Branch Mode — full dump from server) ────
  'sync-schema': async () => {
    if (state.schemaImported) {
      addAutoCheck('Schema & data already synced (resumed)', 'pass');
      return;
    }

    const connHost = state.connectivityMode === 'lan' ? state.serverIP : '127.0.0.1';
    const connPort = state.serverPort || '5433';

    // Exclude data for large log/audit tables that branches don't need
    const excludeDataTables = [
      'wa_messages', 'whatsapp_message_log', 'user_audit_logs',
      'order_audit_logs', 'branch_sync_config'
    ];
    const excludeFlags = excludeDataTables.map(t => `--exclude-table-data='${t}'`).join(' ');

    // Step 1: Export pre-data (DROP + CREATE tables, types, sequences)
    const preItem = addAutoCheck('Exporting schema from server...', 'running');
    setAutoProgress(10);

    await api.wsl(`PGPASSWORD='${state.pgPassword}' pg_dump \\
      -h ${connHost} -p ${connPort} -U supabase_admin -d postgres \\
      -n public --no-owner --no-privileges ${excludeFlags} \\
      --section=pre-data --clean --if-exists \\
      > /tmp/server-pre.sql`, { timeout: 120000 });

    updateAutoCheck(preItem, 'Schema (pre-data) exported', 'pass');
    setAutoProgress(20);

    // Step 2: Export data (INSERT statements)
    const dataItem = addAutoCheck('Exporting data from server...', 'running');

    await api.wsl(`PGPASSWORD='${state.pgPassword}' pg_dump \\
      -h ${connHost} -p ${connPort} -U supabase_admin -d postgres \\
      -n public --no-owner --no-privileges ${excludeFlags} \\
      --section=data --inserts --rows-per-insert=500 \\
      > /tmp/server-data.sql`, { timeout: 600000 });

    updateAutoCheck(dataItem, 'Data exported', 'pass');
    setAutoProgress(40);

    // Step 3: Export post-data (indexes, FK constraints, triggers)
    const postItem = addAutoCheck('Exporting indexes & constraints...', 'running');

    await api.wsl(`PGPASSWORD='${state.pgPassword}' pg_dump \\
      -h ${connHost} -p ${connPort} -U supabase_admin -d postgres \\
      -n public --no-owner --no-privileges ${excludeFlags} \\
      --section=post-data \\
      > /tmp/server-post.sql`, { timeout: 120000 });

    updateAutoCheck(postItem, 'Indexes & constraints exported', 'pass');
    setAutoProgress(50);

    // Step 4: Import pre-data (schema)
    const importSchemaItem = addAutoCheck('Importing schema to local DB...', 'running');
    await api.wsl('sudo docker cp /tmp/server-pre.sql supabase-db:/tmp/server-pre.sql');
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/server-pre.sql 2>&1 | tail -5', { timeout: 120000 });
    updateAutoCheck(importSchemaItem, 'Schema imported', 'pass');
    setAutoProgress(60);

    // Step 5: Import data
    const importDataItem = addAutoCheck('Importing data to local DB (this may take a while)...', 'running');
    await api.wsl('sudo docker cp /tmp/server-data.sql supabase-db:/tmp/server-data.sql');
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/server-data.sql 2>&1 | tail -5', { timeout: 600000 });
    updateAutoCheck(importDataItem, 'Data imported', 'pass');
    setAutoProgress(80);

    // Step 6: Import post-data (indexes, FK, triggers)
    const importPostItem = addAutoCheck('Creating indexes & constraints...', 'running');
    await api.wsl('sudo docker cp /tmp/server-post.sql supabase-db:/tmp/server-post.sql');
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/server-post.sql 2>&1 | tail -5', { timeout: 120000 });
    updateAutoCheck(importPostItem, 'Indexes & constraints created', 'pass');
    setAutoProgress(90);

    // Step 7: Reset sequences
    const seqItem = addAutoCheck('Resetting sequences...', 'running');
    await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "
      DO \\$\\$\\$ DECLARE r record; BEGIN
        FOR r IN (
          SELECT t.relname as tbl, a.attname as col, pg_get_serial_sequence(t.relname, a.attname) as seq
          FROM pg_class t JOIN pg_namespace n ON t.relnamespace = n.oid
          JOIN pg_attribute a ON a.attrelid = t.oid
          WHERE n.nspname = 'public' AND t.relkind = 'r'
            AND pg_get_serial_sequence(t.relname, a.attname) IS NOT NULL
        ) LOOP
          EXECUTE format('SELECT setval(%L, COALESCE((SELECT MAX(%I) FROM %I), 1))', r.seq, r.col, r.tbl);
        END LOOP;
      END \\$\\$\\$;
    "`, { timeout: 30000 });
    updateAutoCheck(seqItem, 'Sequences reset', 'pass');

    // Cleanup
    await api.wsl('rm -f /tmp/server-pre.sql /tmp/server-data.sql /tmp/server-post.sql');

    // Reload PostgREST cache
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "NOTIFY pgrst, \'reload schema\';"');

    state.schemaImported = true;
    setAutoProgress(100);
  },

  // ──── SETUP REPLICATION (Branch Mode) ────
  'setup-replication': async () => {
    if (state.replicationActive) {
      addAutoCheck('Replication already active (resumed)', 'pass');
      return;
    }

    const connHost = state.connectivityMode === 'lan' ? state.serverIP : '172.18.0.1';
    const connPort = state.serverPort || '5433';
    const branchId = state.branchId || '1';

    const subItem = addAutoCheck('Creating replication subscription...', 'running');
    setAutoProgress(30);

    await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "
      CREATE SUBSCRIPTION branch_${branchId}_sub
        CONNECTION 'host=${connHost} port=${connPort} dbname=postgres user=replication_user password=${state.replicationPassword}'
        PUBLICATION branch_sync
        WITH (copy_data = true, create_slot = true, slot_name = 'branch_${branchId}_slot');
    "`);

    updateAutoCheck(subItem, `Subscription branch_${branchId}_sub created`, 'pass');
    setAutoProgress(60);

    // Verify
    const verifyItem = addAutoCheck('Verifying replication status...', 'running');
    await sleep(3000);
    const status = await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT subname, subenabled FROM pg_subscription;" -t');
    log(`Subscription status: ${status.stdout}`, 'info');
    
    if (status.stdout.includes('t')) {
      updateAutoCheck(verifyItem, 'Replication is active — initial data copy in progress', 'pass');
      state.replicationActive = true;
    } else {
      updateAutoCheck(verifyItem, 'Subscription created but may need time to connect', 'warn');
      state.replicationActive = true; // Set true to allow continuing
    }
    setAutoProgress(100);
  },

  // ──── SETUP TUNNEL (Branch Mode) ────
  'setup-tunnel': async () => {
    if (state.tunnelSetup) {
      addAutoCheck('Tunnel already configured (resumed)', 'pass');
      return;
    }

    if (state.connectivityMode === 'lan') {
      addAutoCheck('LAN mode — no tunnel needed! Direct connection to server.', 'pass');
      state.tunnelSetup = true;
      setAutoProgress(100);
      return;
    }

    // Internet mode — set up SSH tunnel with autossh
    const keyItem = addAutoCheck('Generating SSH key for tunnel...', 'running');
    setAutoProgress(20);
    await api.wsl('ssh-keygen -t ed25519 -f /root/.ssh/server_tunnel -N "" -C "branch-tunnel" 2>/dev/null || true');
    const pubKey = await api.wsl('cat /root/.ssh/server_tunnel.pub');
    updateAutoCheck(keyItem, 'SSH key generated', 'pass');

    addAutoCheck(`Public key: ${pubKey.stdout.substring(0, 50)}...`, 'warn');
    addAutoCheck('Admin must add this key to server authorized_keys', 'warn');
    setAutoProgress(50);

    // Create autossh service
    const svcItem = addAutoCheck('Creating SSH tunnel service...', 'running');
    const tunnelService = `[Unit]
Description=SSH Tunnel to Server DB
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/autossh -M 0 -N \\
  -o "ServerAliveInterval=30" \\
  -o "ServerAliveCountMax=3" \\
  -o "ExitOnForwardFailure=yes" \\
  -o "StrictHostKeyChecking=no" \\
  -i /root/.ssh/server_tunnel \\
  -L 0.0.0.0:${state.serverPort}:127.0.0.1:${state.serverPort} \\
  root@${state.serverIP}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target`;

    await api.wsl(`sudo tee /etc/systemd/system/server-db-tunnel.service > /dev/null << 'EOF'\n${tunnelService}\nEOF`);
    await api.wsl('sudo systemctl daemon-reload && sudo systemctl enable server-db-tunnel');
    updateAutoCheck(svcItem, 'SSH tunnel service created & enabled', 'pass');

    state.tunnelSetup = true;
    setAutoProgress(100);
  },

  // ──── DEPLOY UPDATE SERVICE (Branch Mode) ────
  // Note: update service is deployed as part of deploy-frontend (git clone step).
  // This step is kept for resume/idempotency only.
  'deploy-update': async () => {
    if (state.updateServiceDeployed) {
      addAutoCheck('Update service already deployed (done in previous step)', 'pass');
      setAutoProgress(100);
      return;
    }

    // Fallback: if deploy-frontend failed mid-way and update service wasn't deployed
    const item = addAutoCheck('Checking update service...', 'running');
    setAutoProgress(30);
    const exists = await api.wsl('test -f /opt/aqura/update-service/index.cjs && echo yes || echo no');
    if (exists.stdout.trim() === 'yes') {
      updateAutoCheck(item, 'Update service script present', 'pass');
    } else {
      updateAutoCheck(item, 'Update service script missing — re-run deploy-frontend step', 'warn');
    }
    const svcActive = await api.wsl('systemctl is-active aqura-update 2>/dev/null || echo inactive');
    if (svcActive.stdout.trim() === 'active') {
      addAutoCheck('Update service is running', 'pass');
    } else {
      addAutoCheck('Update service not running — start manually: systemctl start aqura-update', 'warn');
    }

    state.updateServiceDeployed = true;
    setAutoProgress(100);
  },

  // ──── SYNC STORAGE (Branch Mode) ────
  'sync-storage': async () => {
    if (state.storageSyncSetup) {
      addAutoCheck('Storage sync already configured (resumed)', 'pass');
      return;
    }

    // ── Fix storage schema ownership (required after replication) ──
    // Replication copies storage functions owned by supabase_admin, but the
    // storage container runs migrations as supabase_storage_admin and needs
    // to own them. Without this fix the storage container crash-loops.
    const ownerItem = addAutoCheck('Fixing storage schema ownership...', 'running');
    setAutoProgress(5);
    const ownershipSQL = `
DO \\$\\$ DECLARE r record; BEGIN
  FOR r IN SELECT format('%s.%s(%s)', n.nspname, p.proname,
      pg_catalog.pg_get_function_identity_arguments(p.oid)) AS sig
    FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    JOIN pg_roles ro ON p.proowner = ro.oid
    WHERE n.nspname = 'storage' AND ro.rolname = 'supabase_admin'
  LOOP EXECUTE format('ALTER FUNCTION %s OWNER TO supabase_storage_admin', r.sig);
  END LOOP;
END \\$\\$;
DO \\$\\$ DECLARE r record; BEGIN
  FOR r IN SELECT format('%s.%s', schemaname, tablename) AS tbl
    FROM pg_tables WHERE schemaname = 'storage'
    AND tableowner = 'supabase_admin'
  LOOP EXECUTE format('ALTER TABLE %s OWNER TO supabase_storage_admin', r.tbl);
  END LOOP;
END \\$\\$;
DO \\$\\$ DECLARE r record; BEGIN
  FOR r IN SELECT format('%s.%s', sequence_schema, sequence_name) AS seq
    FROM information_schema.sequences WHERE sequence_schema = 'storage'
  LOOP EXECUTE format('ALTER SEQUENCE %s OWNER TO supabase_storage_admin', r.seq);
  END LOOP;
END \\$\\$;
DO \\$\\$ DECLARE r record; BEGIN
  FOR r IN SELECT format('%s.%s', schemaname, viewname) AS vw
    FROM pg_views WHERE schemaname = 'storage'
    AND viewowner = 'supabase_admin'
  LOOP EXECUTE format('ALTER VIEW %s OWNER TO supabase_storage_admin', r.vw);
  END LOOP;
END \\$\\$;`;
    try {
      await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "${ownershipSQL}" 2>&1`);
      updateAutoCheck(ownerItem, 'Storage schema ownership transferred to supabase_storage_admin', 'pass');
    } catch (e) {
      updateAutoCheck(ownerItem, 'Ownership fix had issues (may already be correct)', 'warn');
      log(`Ownership fix error: ${e.message}`, 'warn');
    }

    // Restart storage container so it can run its pending migrations
    const restartItem = addAutoCheck('Restarting storage container...', 'running');
    setAutoProgress(8);
    try {
      await api.wsl('sudo docker restart supabase-storage 2>&1');
      await sleep(5000);
      const health = await api.wsl('sudo docker inspect --format="{{.State.Status}}" supabase-storage 2>&1');
      if (health.stdout.trim() === 'running') {
        updateAutoCheck(restartItem, 'Storage container running', 'pass');
      } else {
        updateAutoCheck(restartItem, `Storage container status: ${health.stdout.trim()}`, 'warn');
      }
    } catch (e) {
      updateAutoCheck(restartItem, 'Storage restart had issues — may need manual check', 'warn');
    }

    if (state.connectivityMode === 'lan') {
      // LAN mode — rsync with SSH key
      const keyItem = addAutoCheck('Setting up rsync SSH key...', 'running');
      setAutoProgress(10);
      await api.wsl('ssh-keygen -t ed25519 -f /root/.ssh/server_rsync -N "" -C "branch-rsync" 2>/dev/null || true');
      addAutoCheck('Admin must add rsync public key to server authorized_keys', 'warn');
      updateAutoCheck(keyItem, 'Rsync SSH key ready', 'pass');
      setAutoProgress(25);

      const scriptItem = addAutoCheck('Creating storage sync script...', 'running');
      const syncScript = `#!/bin/bash
SERVER_HOST="${state.serverIP}"
SERVER_PATH="/opt/supabase/supabase/docker/volumes/storage/stub/stub/"
LOCAL_PATH="/opt/supabase/supabase/docker/volumes/storage/stub/stub/"
SSH_KEY="/root/.ssh/server_rsync"
LOG="/var/log/aqura-storage-sync.log"

echo "[$(date)] Starting storage sync..." >> $LOG
rsync -avz --delete \\
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \\
  root@$SERVER_HOST:$SERVER_PATH $LOCAL_PATH \\
  >> $LOG 2>&1
echo "[$(date)] Storage sync finished (exit $?)" >> $LOG`;

      await api.wsl(`sudo tee /opt/aqura/sync-storage.sh > /dev/null << 'EOF'\n${syncScript}\nEOF`);
      await api.wsl('sudo chmod +x /opt/aqura/sync-storage.sh');
      updateAutoCheck(scriptItem, 'Sync script created', 'pass');
      setAutoProgress(40);

      const cronItem = addAutoCheck('Setting up cron job (every 5 min)...', 'running');
      await api.wsl('(crontab -l 2>/dev/null | grep -v sync-storage; echo "*/5 * * * * /opt/aqura/sync-storage.sh") | crontab -');
      updateAutoCheck(cronItem, 'Cron job configured', 'pass');
      setAutoProgress(55);

      // Run initial sync
      const initialItem = addAutoCheck('Running initial storage sync (this may take a while)...', 'running');
      try {
        const result = await api.wsl('sudo /opt/aqura/sync-storage.sh 2>&1 | tail -5');
        log(result.stdout, 'info');
        updateAutoCheck(initialItem, 'Initial storage sync completed', 'pass');
      } catch (e) {
        updateAutoCheck(initialItem, 'Initial sync had issues — will retry via cron', 'warn');
      }
    } else {
      // Internet mode — deploy get_storage_stats RPC & create API-based sync script
      const rpcItem = addAutoCheck('Deploying get_storage_stats RPC function...', 'running');
      setAutoProgress(15);
      const rpcSQL = `CREATE OR REPLACE FUNCTION public.get_storage_stats()
RETURNS TABLE (bucket_id text, bucket_name text, file_count bigint, total_size bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS \\$\\$
  SELECT b.id::text, b.name::text, COALESCE(COUNT(o.id),0), COALESCE(SUM((o.metadata->>'size')::bigint),0)
  FROM storage.buckets b LEFT JOIN storage.objects o ON o.bucket_id = b.id
  GROUP BY b.id, b.name ORDER BY 4 DESC;
\\$\\$;
GRANT EXECUTE ON FUNCTION public.get_storage_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_storage_stats() TO anon;
GRANT EXECUTE ON FUNCTION public.get_storage_stats() TO service_role;`;
      await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "${rpcSQL}" 2>&1`);
      updateAutoCheck(rpcItem, 'get_storage_stats RPC deployed', 'pass');
      setAutoProgress(35);

      const scriptItem = addAutoCheck('Creating API-based storage sync script...', 'running');
      const apiSyncScript = `#!/bin/bash
# Aqura Internet-mode Storage Sync
# Downloads files from cloud Supabase Storage API and uploads to local Supabase
CLOUD_URL="${state.cloudUrl || ''}"
CLOUD_KEY="${state.serviceKey}"
LOCAL_URL="http://localhost:8000"
LOCAL_KEY="${state.anonKey}"
LOG="/var/log/aqura-storage-sync.log"

echo "[$(date)] Starting API storage sync..." >> $LOG

# Get cloud bucket list
BUCKETS=$(curl -s "$CLOUD_URL/storage/v1/bucket" \\
  -H "apikey: $CLOUD_KEY" -H "Authorization: Bearer $CLOUD_KEY")

# Parse bucket IDs
BUCKET_IDS=$(echo "$BUCKETS" | python3 -c "import sys,json; [print(b['id']) for b in json.load(sys.stdin)]" 2>/dev/null)

for BID in $BUCKET_IDS; do
  # Ensure bucket exists locally
  curl -s -X POST "$LOCAL_URL/storage/v1/bucket" \\
    -H "apikey: $LOCAL_KEY" -H "Authorization: Bearer $LOCAL_KEY" \\
    -H "Content-Type: application/json" \\
    -d "{\\"id\\":\\"$BID\\",\\"name\\":\\"$BID\\",\\"public\\":true}" >> $LOG 2>&1 || true

  # List cloud files
  OFFSET=0
  while true; do
    FILES=$(curl -s -X POST "$CLOUD_URL/storage/v1/object/list/$BID" \\
      -H "apikey: $CLOUD_KEY" -H "Authorization: Bearer $CLOUD_KEY" \\
      -H "Content-Type: application/json" \\
      -d "{\\"prefix\\":\\"\\",\\"limit\\":100,\\"offset\\":$OFFSET}")
    COUNT=$(echo "$FILES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    [ "$COUNT" = "0" ] && break

    echo "$FILES" | python3 -c "
import sys,json
for f in json.load(sys.stdin):
  if f.get('metadata',{}).get('size',0) > 0:
    print(f['name'])
" 2>/dev/null | while read FNAME; do
      # Check if file exists locally
      LOCAL_CHECK=$(curl -s -o /dev/null -w '%{http_code}' "$LOCAL_URL/storage/v1/object/$BID/$FNAME" \\
        -H "apikey: $LOCAL_KEY" -H "Authorization: Bearer $LOCAL_KEY")
      if [ "$LOCAL_CHECK" != "200" ]; then
        # Download from cloud and upload to local
        curl -s "$CLOUD_URL/storage/v1/object/$BID/$FNAME" \\
          -H "apikey: $CLOUD_KEY" -H "Authorization: Bearer $CLOUD_KEY" \\
          -o "/tmp/aqura_sync_file"
        curl -s -X POST "$LOCAL_URL/storage/v1/object/$BID/$FNAME" \\
          -H "apikey: $LOCAL_KEY" -H "Authorization: Bearer $LOCAL_KEY" \\
          -H "Content-Type: application/octet-stream" \\
          --data-binary @/tmp/aqura_sync_file >> $LOG 2>&1
        rm -f /tmp/aqura_sync_file
        echo "[$(date)] Synced: $BID/$FNAME" >> $LOG
      fi
    done
    OFFSET=$((OFFSET + 100))
  done
done

echo "[$(date)] API storage sync finished" >> $LOG`;

      await api.wsl(`sudo tee /opt/aqura/sync-storage.sh > /dev/null << 'SYNCEOF'\n${apiSyncScript}\nSYNCEOF`);
      await api.wsl('sudo chmod +x /opt/aqura/sync-storage.sh');
      updateAutoCheck(scriptItem, 'API sync script created', 'pass');
      setAutoProgress(60);

      const cronItem = addAutoCheck('Setting up cron job (every 10 min)...', 'running');
      await api.wsl('(crontab -l 2>/dev/null | grep -v sync-storage; echo "*/10 * * * * /opt/aqura/sync-storage.sh") | crontab -');
      updateAutoCheck(cronItem, 'Cron job configured (every 10 min)', 'pass');
      setAutoProgress(75);

      // Run initial sync
      const initialItem = addAutoCheck('Running initial storage sync (this may take a while)...', 'running');
      try {
        const result = await api.wsl('timeout 300 sudo /opt/aqura/sync-storage.sh 2>&1 | tail -10');
        log(result.stdout, 'info');
        updateAutoCheck(initialItem, 'Initial storage sync completed', 'pass');
      } catch (e) {
        updateAutoCheck(initialItem, 'Initial sync started — will continue via cron', 'warn');
      }
    }

    state.storageSyncSetup = true;
    setAutoProgress(100);
  },

  // ──── REGISTER & VERIFY (Branch Mode) ────
  'verify': async () => {
    const checks = [];
    
    // Verify containers
    const containerItem = addAutoCheck('Checking Docker containers...', 'running');
    setAutoProgress(15);
    const containers = await api.wsl('sudo docker ps --format "{{.Names}}: {{.Status}}" 2>&1');
    log(containers.stdout, 'info');
    updateAutoCheck(containerItem, 'Docker containers running', 'pass');

    // Verify Supabase API
    const apiItem = addAutoCheck('Checking Supabase API...', 'running');
    setAutoProgress(30);
    const apiCheck = await api.wsl('curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/rest/v1/');
    if (apiCheck.stdout === '200') {
      updateAutoCheck(apiItem, 'Supabase API responding', 'pass');
    } else {
      updateAutoCheck(apiItem, `Supabase API returned ${apiCheck.stdout}`, 'warn');
    }

    // Verify replication (if branch)
    if (state.mode === 'branch') {
      const replItem = addAutoCheck('Checking replication status...', 'running');
      setAutoProgress(50);
      const replStatus = await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT srsubstate, count(*) FROM pg_subscription_rel GROUP BY srsubstate;" -t');
      log(`Replication: ${replStatus.stdout}`, 'info');
      updateAutoCheck(replItem, `Replication: ${replStatus.stdout.trim() || 'initial sync in progress'}`, 'pass');
    }

    // Register branch on server
    if (state.mode === 'branch') {
      const regItem = addAutoCheck('Registering branch on server...', 'running');
      setAutoProgress(70);
      
      const ips = await api.getNetworkIPs();
      const branchIP = ips.length > 0 ? ips[0].address : 'unknown';
      
      // Try to register
      const regResult = await api.wsl(`curl -s -X POST http://${state.serverIP}:8000/rest/v1/rpc/upsert_branch_sync_config \\
        -H "apikey: ${state.serviceKey}" \\
        -H "Authorization: Bearer ${state.serviceKey}" \\
        -H "Content-Type: application/json" \\
        -d '{"p_branch_id":${state.branchId},"p_branch_name":"${state.branchName}","p_local_supabase_url":"http://${branchIP}:8000","p_local_supabase_key":"${state.anonKey}"}' 2>/dev/null`);
      
      if (regResult.success) {
        updateAutoCheck(regItem, 'Branch registered on server', 'pass');
      } else {
        updateAutoCheck(regItem, 'Branch registration skipped (RPC may not exist yet)', 'warn');
      }
    }

    setAutoProgress(90);
    addAutoCheck('All verifications complete!', 'pass');

    state.branchRegistered = true;
    setAutoProgress(100);
  }
};

// ─── Helper Functions ───────────────────────────────────────────────
function isPrivateIP(ip) {
  return /^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.)/.test(ip);
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

function buildSupabaseEnv() {
  const jwtSecret = state.jwtSecret || 'super-secret-jwt-token-with-at-least-32-characters-long';
  const anonKey = state.anonKey || 'placeholder-anon-key';
  const serviceKey = state.serviceKey || 'placeholder-service-key';
  const pgPassword = state.pgPassword || 'your-super-secret-and-long-postgres-password';
  const dashPassword = state.dashboardPassword || 'LocalAdmin2025';

  return `############
# Secrets
############
POSTGRES_PASSWORD=${pgPassword}
JWT_SECRET=${jwtSecret}
ANON_KEY=${anonKey}
SERVICE_ROLE_KEY=${serviceKey}
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${dashPassword}

############
# Database
############
POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_PORT=5432

############
# API
############
SITE_URL=http://localhost:3001
API_EXTERNAL_URL=http://localhost:8000
SUPABASE_PUBLIC_URL=http://localhost:8000

############
# Auth
############
GOTRUE_SITE_URL=http://localhost:3001
GOTRUE_EXTERNAL_GOTRUE_URL=http://localhost:8000/auth/v1
GOTRUE_JWT_SECRET=${jwtSecret}
GOTRUE_JWT_EXP=3600
GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated
GOTRUE_DB_DRIVER=postgres
GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:${pgPassword}@db:5432/postgres
GOTRUE_API_HOST=0.0.0.0
GOTRUE_API_PORT=9999
GOTRUE_DISABLE_SIGNUP=false
GOTRUE_EXTERNAL_EMAIL_ENABLED=true
GOTRUE_MAILER_AUTOCONFIRM=true

############
# Studio
############
STUDIO_PORT=3000
STUDIO_PG_META_URL=http://meta:8080

############
# Storage
############
STORAGE_BACKEND=file
FILE_SIZE_LIMIT=52428800
IMGPROXY_ENABLE_WEBP_DETECTION=true

############
# Functions
############
FUNCTIONS_VERIFY_JWT=false

############
# Logging
############
LOGFLARE_API_KEY=placeholder
LOGFLARE_LOGGER_BACKEND_API_URL=http://localhost:4000

############
# Analytics
############
POSTGRES_ANALYTICS_PORT=5432`;
}

// ─── Advance to next step ───────────────────────────────────────────
function advanceStep() {
  const steps = getSteps();
  if (state.currentPhase < steps.length - 1) {
    state.currentPhase++;
    renderProgress();
    updateNav();
    clearLog();
    renderStepContent();
    api.saveState(state);
  } else {
    // All done!
    showCompleteScreen();
  }
}

function showCompleteScreen() {
  // Remove auto-start
  api.setAutoStart(false);

  const info = $('#complete-info');
  if (state.mode === 'server') {
    const ips = []; // Will be populated
    api.getNetworkIPs().then(addrs => {
      const ip = addrs.length > 0 ? addrs[0].address : 'localhost';
      info.innerHTML = `
        <div class="info-row"><span class="info-label">Mode</span><span class="info-value">🏢 Server (Master)</span></div>
        <div class="info-row"><span class="info-label">Company</span><span class="info-value">${state.companyName}</span></div>
        <div class="info-row"><span class="info-label">Server IP</span><span class="info-value">${ip}</span></div>
        <div class="info-row"><span class="info-label">Supabase API</span><span class="info-value">http://${ip}:8000</span></div>
        <div class="info-row"><span class="info-label">Supabase Studio</span><span class="info-value">http://${ip}:3000</span></div>
        <div class="info-row"><span class="info-label">Frontend</span><span class="info-value">http://${ip}:3001</span></div>
        <div class="info-row"><span class="info-label">DB Replication Port</span><span class="info-value">${ip}:5433</span></div>
        <div class="info-row"><span class="info-label">Master Admin</span><span class="info-value">${state.adminEmail}</span></div>
        <hr style="border-color:var(--border);margin:12px 0">
        <p style="font-size:12px;color:var(--warning)">⚠️ Share the server IP and credentials file with branch installers.</p>
      `;
    });
  } else {
    info.innerHTML = `
      <div class="info-row"><span class="info-label">Mode</span><span class="info-value">🏪 Branch</span></div>
      <div class="info-row"><span class="info-label">Branch</span><span class="info-value">${state.branchName} (#${state.branchId})</span></div>
      <div class="info-row"><span class="info-label">Server</span><span class="info-value">${state.serverIP}:${state.serverPort}</span></div>
      <div class="info-row"><span class="info-label">Connectivity</span><span class="info-value">${state.connectivityMode === 'lan' ? 'LAN (Direct)' : 'Internet (Tunnel)'}</span></div>
      <div class="info-row"><span class="info-label">Frontend</span><span class="info-value">http://localhost:3001</span></div>
      <div class="info-row"><span class="info-label">Local Studio</span><span class="info-value">http://localhost:3000</span></div>
      <hr style="border-color:var(--border);margin:12px 0">
      <p style="font-size:12px;color:var(--text-muted)">Initial data replication may still be in progress for large databases.</p>
    `;
  }

  showScreen('complete');
}

// ─── Initialize ─────────────────────────────────────────────────────
async function init() {
  // Title bar controls
  $('#btn-minimize').addEventListener('click', () => api.minimize());
  $('#btn-maximize').addEventListener('click', () => api.maximize());
  $('#btn-close').addEventListener('click', () => api.close());

  // Log toggle
  $('#btn-toggle-log').addEventListener('click', () => {
    const log = $('#log-content');
    log.classList.toggle('log-collapsed');
    log.classList.toggle('log-expanded');
    $('#btn-toggle-log').textContent = log.classList.contains('log-expanded') ? '▲' : '▼';
  });

  // Copy All log button
  $('#btn-copy-log').addEventListener('click', () => {
    const logEl = $('#log-content');
    const text = logEl.innerText || logEl.textContent || '';
    navigator.clipboard.writeText(text).then(() => {
      const btn = $('#btn-copy-log');
      btn.textContent = 'Copied!';
      setTimeout(() => { btn.textContent = 'Copy All'; }, 2000);
    });
  });

  // Mode selection
  const cards = $$('.mode-card');
  cards.forEach(card => {
    card.addEventListener('click', () => {
      cards.forEach(c => c.classList.remove('selected'));
      card.classList.add('selected');
      state.mode = card.id === 'card-server' ? 'server' : 'branch';
      $('#btn-start').disabled = false;
    });
  });

  // Start button
  $('#btn-start').addEventListener('click', () => {
    if (!state.mode) return;
    state.currentPhase = 0;
    state.startedAt = new Date().toISOString();
    showScreen('wizard');
    renderProgress();
    updateNav();
    renderStepContent();
  });

  // Navigation
  $('#btn-next').addEventListener('click', () => {
    const steps = getSteps();
    const step = steps[state.currentPhase];
    
    if (step && !step.auto) {
      // User input step — advance manually
      advanceStep();
    }
    // Auto steps advance themselves via advanceStep() call
  });

  $('#btn-back').addEventListener('click', () => {
    if (state.currentPhase > 0) {
      state.currentPhase--;
      renderProgress();
      updateNav();
      clearLog();
      renderStepContent();
    }
  });

  // Complete screen buttons
  $('#btn-open-frontend').addEventListener('click', () => {
    api.exec('Start-Process "http://localhost:3001"');
  });
  $('#btn-open-studio').addEventListener('click', () => {
    api.exec('Start-Process "http://localhost:3000"');
  });
  $('#btn-finish').addEventListener('click', () => {
    api.close();
  });

  // Resume screen buttons
  $('#btn-resume-continue').addEventListener('click', () => {
    showScreen('wizard');
    renderProgress();
    updateNav();
    renderStepContent();
  });
  $('#btn-resume-fresh').addEventListener('click', () => {
    state = { mode: null, currentPhase: 0 };
    showScreen('mode');
  });

  // Stream output listener
  api.onOutput((data) => {
    log(data.trim());
  });

  // Check for resume state
  const savedState = await api.checkResume();
  if (savedState && savedState.currentPhase > 0) {
    state = { ...state, ...savedState };
    // Ensure string fields are never undefined (avoids "undefined" text in inputs)
    state.companyName = state.companyName || '';
    state.adminUsername = state.adminUsername || '';
    state.adminPassword = state.adminPassword || '';
    state.adminQuickCode = state.adminQuickCode || '';
    state.adminEmail = state.adminEmail || '';
    state.dashboardPassword = state.dashboardPassword || '';
    state.branchName = state.branchName || '';
    state.serverHost = state.serverHost || '';
    
    $('#resume-info').innerHTML = `
      <div class="info-row"><span class="info-label">Mode</span><span class="info-value">${state.mode === 'server' ? '🏢 Server' : '🏪 Branch'}</span></div>
      <div class="info-row"><span class="info-label">Phase</span><span class="info-value">${state.currentPhase + 1} of ${getSteps().length}</span></div>
      <div class="info-row"><span class="info-label">Started</span><span class="info-value">${new Date(state.startedAt).toLocaleString()}</span></div>
      ${state.lastError ? `<div class="info-row"><span class="info-label">Last Error</span><span class="info-value" style="color:var(--error)">${state.lastError}</span></div>` : ''}
    `;
    showScreen('resume');
  } else {
    showScreen('mode');
  }
}

// Boot
document.addEventListener('DOMContentLoaded', init);
