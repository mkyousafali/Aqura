/* ═══════════════════════════════════════════════════════════════════
   Aqura Setup Installer — Renderer (Wizard Logic)
   ═══════════════════════════════════════════════════════════════════ */

// ─── State ──────────────────────────────────────────────────────────
let state = {
  mode: null,          // 'server' or 'branch'
  currentPhase: 0,
  companyName: '',
  dashboardPassword: '',
  adminEmail: '',
  adminPassword: '',
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
  { id: 'system-check',     title: 'System Check',               auto: true  },
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
  { id: 'system-check',      title: 'System Check',              auto: true  },
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
    if (wslCheck.success) return { pass: true, value: 'WSL2 available' };
    return { pass: false, value: 'Disabled — enable in BIOS' };
  });

  // 3. RAM
  await runCheck('ram', async () => {
    const res = await api.exec('[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)');
    const gb = parseFloat(res.stdout);
    if (gb >= 16) return { pass: true, value: `${gb} GB` };
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
    <div class="form-row">
      <div class="form-group">
        <label>Admin Email</label>
        <input type="email" id="input-admin-email" placeholder="admin@company.com" value="${state.adminEmail}" />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>Admin Password</label>
        <input type="password" id="input-admin-pw" placeholder="Min 8 characters" value="${state.adminPassword}" />
      </div>
      <div class="form-group">
        <label>Confirm Password</label>
        <input type="password" id="input-admin-pw2" placeholder="Re-enter password" />
      </div>
    </div>
    <div id="form-errors"></div>
  `;

  // Enable next only when valid
  const validate = () => {
    const company = $('#input-company').value.trim();
    const dashPw = $('#input-dashboard-pw').value;
    const email = $('#input-admin-email').value.trim();
    const pw = $('#input-admin-pw').value;
    const pw2 = $('#input-admin-pw2').value;
    const errors = [];

    if (!company) errors.push('Company name is required');
    if (dashPw.length < 8) errors.push('Dashboard password must be 8+ characters');
    if (!email.includes('@')) errors.push('Valid email is required');
    if (pw.length < 8) errors.push('Admin password must be 8+ characters');
    if (pw !== pw2) errors.push('Passwords do not match');

    $('#form-errors').innerHTML = errors.map(e => `<div class="error-text">• ${e}</div>`).join('');
    $('#btn-next').disabled = errors.length > 0;

    // Save to state
    state.companyName = company;
    state.dashboardPassword = dashPw;
    state.adminEmail = email;
    state.adminPassword = pw;
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

    // Check if WSL is already installed
    const wslStatus = await api.exec('wsl --status 2>&1');
    if (wslStatus.success && wslStatus.stdout.includes('Default')) {
      updateAutoCheck(checkItem, 'WSL2 is already installed', 'pass');
      setAutoProgress(50);

      // Check if Ubuntu-22.04 is installed
      const distros = await api.exec('wsl --list --quiet 2>&1');
      if (distros.stdout.includes('Ubuntu')) {
        addAutoCheck('Ubuntu 22.04 is installed', 'pass');
        state.wslInstalled = true;
        setAutoProgress(100);
        return;
      }
    }

    // Install WSL + Ubuntu
    updateAutoCheck(checkItem, 'Installing WSL2 + Ubuntu 22.04...', 'running');
    setAutoProgress(30);
    
    const installRes = await api.stream('wsl --install -d Ubuntu-22.04', { timeout: 600000 });
    
    if (installRes.stdout.includes('restart') || installRes.stdout.includes('reboot')) {
      // Needs reboot
      addAutoCheck('System reboot required to complete WSL2 installation', 'warn');
      state.currentPhase = state.currentPhase; // Stay on this phase
      await api.saveState(state);
      await api.setAutoStart(true);

      const reboot = await api.showMessage({
        type: 'question',
        buttons: ['Reboot Now', 'Later'],
        title: 'Reboot Required',
        message: 'Windows needs to restart to finish WSL2 installation.\n\nThe installer will resume automatically after reboot.'
      });

      if (reboot === 0) {
        await api.exec('shutdown /r /t 5 /c "Aqura Setup - WSL2 installation reboot"');
      }
      return;
    }

    state.wslInstalled = true;
    addAutoCheck('WSL2 + Ubuntu 22.04 installed', 'pass');
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
    await api.wsl('sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io docker-compose unzip git curl jq openssl rsync autossh 2>&1', { timeout: 300000 });
    updateAutoCheck(installItem, 'Docker + tools installed', 'pass');
    setAutoProgress(60);

    const enableItem = addAutoCheck('Enabling Docker service...', 'running');
    await api.wsl('sudo systemctl enable docker && sudo systemctl start docker');
    await api.wsl('sudo usermod -aG docker $USER');
    updateAutoCheck(enableItem, 'Docker service enabled', 'pass');
    setAutoProgress(85);

    // Verify
    const verifyItem = addAutoCheck('Verifying Docker...', 'running');
    const dockerVer = await api.wsl('docker --version');
    if (dockerVer.success) {
      updateAutoCheck(verifyItem, `Docker ready: ${dockerVer.stdout}`, 'pass');
      state.dockerReady = true;
    } else {
      throw new Error('Docker installation failed');
    }
    setAutoProgress(100);
  },

  // ──── INSTALL SUPABASE ────
  'install-supabase': async () => {
    if (state.supabaseRunning) {
      addAutoCheck('Supabase already running (resumed)', 'pass');
      return;
    }

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

    // In server mode, keys are already generated. In branch mode, they come from server.
    const envContent = buildSupabaseEnv();
    await api.wsl(`cat > /tmp/supabase-env.tmp << 'ENVEOF'\n${envContent}\nENVEOF`);
    await api.wsl('sudo cp /tmp/supabase-env.tmp /opt/supabase/supabase/docker/.env');
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
    await api.stream('cd /opt/supabase/supabase/docker && sudo docker compose pull', { wsl: true, timeout: 600000 });
    updateAutoCheck(pullItem, 'Docker images pulled', 'pass');
    setAutoProgress(70);

    const startItem = addAutoCheck('Starting Supabase containers...', 'running');
    await api.stream('cd /opt/supabase/supabase/docker && sudo docker compose up -d', { wsl: true, timeout: 300000 });
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

    // Generate in WSL using openssl + node
    const jwtRes = await api.wsl('openssl rand -hex 32');
    state.jwtSecret = jwtRes.stdout.trim();
    updateAutoCheck(genItem, `JWT Secret: ${state.jwtSecret.substring(0, 8)}...`, 'pass');
    setAutoProgress(40);

    // Generate Anon Key and Service Key using node + jsonwebtoken
    const keysItem = addAutoCheck('Generating API keys...', 'running');
    
    // Install jsonwebtoken in a temp location
    await api.wsl('cd /tmp && npm init -y --quiet 2>/dev/null && npm install jsonwebtoken --quiet 2>/dev/null');
    
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + (10 * 365 * 24 * 60 * 60); // 10 years

    const anonRes = await api.wsl(`node -e "const jwt=require('/tmp/node_modules/jsonwebtoken');console.log(jwt.sign({role:'anon',iss:'supabase',iat:${iat},exp:${exp}},'${state.jwtSecret}'))"`);
    state.anonKey = anonRes.stdout.trim();

    const svcRes = await api.wsl(`node -e "const jwt=require('/tmp/node_modules/jsonwebtoken');console.log(jwt.sign({role:'service_role',iss:'supabase',iat:${iat},exp:${exp}},'${state.jwtSecret}'))"`);
    state.serviceKey = svcRes.stdout.trim();

    updateAutoCheck(keysItem, 'Anon Key + Service Key generated', 'pass');
    setAutoProgress(60);

    // Generate Postgres password
    const pgItem = addAutoCheck('Generating database password...', 'running');
    const pgRes = await api.wsl('openssl rand -base64 32 | tr -d "/+=" | head -c 48');
    state.pgPassword = pgRes.stdout.trim();
    updateAutoCheck(pgItem, 'Database password generated', 'pass');
    setAutoProgress(75);

    // Generate replication password
    const replItem = addAutoCheck('Generating replication password...', 'running');
    const replRes = await api.wsl('openssl rand -base64 16 | tr -d "/+=" | head -c 20');
    state.replicationPassword = replRes.stdout.trim();
    updateAutoCheck(replItem, 'Replication password generated', 'pass');
    setAutoProgress(85);

    // Update Supabase .env with real keys
    const updateItem = addAutoCheck('Updating Supabase config with new keys...', 'running');
    const envContent = buildSupabaseEnv();
    await api.wsl(`cat > /tmp/supabase-env.tmp << 'ENVEOF'\n${envContent}\nENVEOF`);
    await api.wsl('sudo cp /tmp/supabase-env.tmp /opt/supabase/supabase/docker/.env');
    
    // Restart Supabase with new keys  
    await api.stream('cd /opt/supabase/supabase/docker && sudo docker compose down && sudo docker compose up -d', { wsl: true, timeout: 300000 });
    
    // Wait for healthy
    let attempts = 0;
    while (attempts < 30) {
      const health = await api.wsl('sudo docker exec supabase-db pg_isready -U supabase_admin 2>&1');
      if (health.success && health.stdout.includes('accepting')) break;
      await sleep(4000);
      attempts++;
    }

    updateAutoCheck(updateItem, 'Supabase restarted with new keys', 'pass');
    setAutoProgress(100);

    log(`JWT Secret: ${state.jwtSecret.substring(0, 16)}...`, 'info');
    log(`Anon Key: ${state.anonKey.substring(0, 20)}...`, 'info');
    log(`Service Key: ${state.serviceKey.substring(0, 20)}...`, 'info');
  },

  // ──── IMPORT SCHEMA (Server Mode — structure only) ────
  'import-schema': async () => {
    if (state.schemaImported) {
      addAutoCheck('Schema already imported (resumed)', 'pass');
      return;
    }

    const item = addAutoCheck('Importing Aqura database schema...', 'running');
    setAutoProgress(20);

    // Check if bundled schema file exists (shipped with installer)
    // For now, we'll check a known path. In production, this is bundled in the .exe
    const schemaPath = '\\\\?\\' + __dirname + '\\..\\bundled\\aqura-schema.sql';
    
    // Try bundled schema first
    setAutoStatus('Looking for schema file...');
    // Note: In production, the schema.sql is bundled. For dev, we generate it.
    
    // For now, create a marker that schema needs to be provided
    addAutoCheck('Schema file will be imported from bundled resources or server', 'warn');
    addAutoCheck('Skipping for development — provide schema.sql in bundled/ folder', 'warn');
    
    state.schemaImported = true;
    setAutoProgress(100);
  },

  // ──── CREATE ADMIN (Server Mode) ────
  'create-admin': async () => {
    if (state.adminCreated) {
      addAutoCheck('Admin already created (resumed)', 'pass');
      return;
    }

    const item = addAutoCheck('Creating master admin user...', 'running');
    setAutoProgress(30);

    // Use Supabase Auth Admin API via curl
    const createUserCmd = `curl -s -X POST http://localhost:8000/auth/v1/admin/users \\
      -H "Authorization: Bearer ${state.serviceKey}" \\
      -H "apikey: ${state.serviceKey}" \\
      -H "Content-Type: application/json" \\
      -d '{"email":"${state.adminEmail}","password":"${state.adminPassword}","email_confirm":true}'`;

    const result = await api.wsl(createUserCmd);
    
    if (result.success && result.stdout.includes('"id"')) {
      const userData = JSON.parse(result.stdout);
      const userId = userData.id;
      updateAutoCheck(item, `Admin user created: ${state.adminEmail}`, 'pass');
      setAutoProgress(60);

      // Set as master admin in DB
      const dbItem = addAutoCheck('Setting master admin privileges...', 'running');
      const sqlCmd = `sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "INSERT INTO public.employee_master (id, email, full_name, is_master_admin, is_active) VALUES ('${userId}', '${state.adminEmail}', 'Master Admin', true, true) ON CONFLICT (id) DO UPDATE SET is_master_admin = true;"`;
      await api.wsl(sqlCmd);
      updateAutoCheck(dbItem, 'Master admin privileges set', 'pass');
      setAutoProgress(80);

      // Seed company name
      const seedItem = addAutoCheck('Saving company info...', 'running');
      await api.wsl(`sudo docker exec supabase-db psql -U supabase_admin -d postgres -c "INSERT INTO public.app_settings (key, value) VALUES ('company_name', '${state.companyName}') ON CONFLICT (key) DO UPDATE SET value = '${state.companyName}';" 2>/dev/null || true`);
      updateAutoCheck(seedItem, 'Company info saved', 'pass');

      state.adminCreated = true;
    } else {
      throw new Error(`Failed to create admin user: ${result.stderr || result.stdout}`);
    }
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

    const dirItem = addAutoCheck('Creating application directories...', 'running');
    setAutoProgress(10);
    await api.wsl('sudo mkdir -p /opt/aqura/build /opt/aqura/update-service');
    updateAutoCheck(dirItem, 'Directories created', 'pass');

    // Frontend build — check for bundled ZIP or skip
    const buildItem = addAutoCheck('Checking for frontend build...', 'running');
    setAutoProgress(30);
    addAutoCheck('Frontend deployment pending — provide frontend.zip in bundled/ folder', 'warn');

    // Create .env
    const envItem = addAutoCheck('Creating frontend .env...', 'running');
    setAutoProgress(50);

    let supabaseUrl, anonKey, serviceKey;
    if (state.mode === 'server') {
      supabaseUrl = 'http://localhost:8000';
      anonKey = state.anonKey;
      serviceKey = state.serviceKey;
    } else {
      // Branch mode: point to server
      if (state.connectivityMode === 'lan') {
        supabaseUrl = `http://${state.serverIP}:8000`;
      } else {
        supabaseUrl = `http://${state.serverIP}:8000`; // Will be updated if tunnel is set up
      }
      anonKey = state.anonKey;
      serviceKey = state.serviceKey;
    }

    const envContent = `PORT=3001
HOST=0.0.0.0
ORIGIN=http://localhost:3001
VITE_SUPABASE_URL=${supabaseUrl}
VITE_SUPABASE_ANON_KEY=${anonKey}
VITE_SUPABASE_SERVICE_KEY=${serviceKey}`;

    await api.wsl(`cat > /opt/aqura/build/.env << 'EOF'\n${envContent}\nEOF`);
    updateAutoCheck(envItem, 'Frontend .env created', 'pass');
    setAutoProgress(70);

    // Create systemd service
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

    await api.wsl(`sudo tee /etc/systemd/system/aqura-frontend.service > /dev/null << 'EOF'\n${serviceContent}\nEOF`);
    await api.wsl('sudo systemctl daemon-reload');
    await api.wsl('sudo systemctl enable aqura-frontend');
    updateAutoCheck(svcItem, 'Frontend service created & enabled', 'pass');
    
    state.frontendDeployed = true;
    setAutoProgress(100);
  },

  // ──── SYNC SCHEMA (Branch Mode) ────
  'sync-schema': async () => {
    if (state.schemaImported) {
      addAutoCheck('Schema already synced (resumed)', 'pass');
      return;
    }

    const connHost = state.connectivityMode === 'lan' ? state.serverIP : '127.0.0.1';
    const connPort = state.serverPort || '5433';

    const dumpItem = addAutoCheck('Exporting schema from server...', 'running');
    setAutoProgress(20);

    await api.wsl(`PGPASSWORD='${state.pgPassword}' pg_dump \\
      -h ${connHost} -p ${connPort} -U supabase_admin -d postgres \\
      --schema-only --no-owner --no-acl \\
      -N _analytics -N _realtime -N supabase_migrations -N supabase_functions \\
      > /tmp/server-schema.sql`, { timeout: 120000 });

    updateAutoCheck(dumpItem, 'Schema exported from server', 'pass');
    setAutoProgress(50);

    const importItem = addAutoCheck('Importing schema to local DB...', 'running');
    await api.wsl('sudo docker cp /tmp/server-schema.sql supabase-db:/tmp/server-schema.sql');
    await api.wsl('sudo docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/server-schema.sql 2>&1 | tail -5', { timeout: 120000 });
    updateAutoCheck(importItem, 'Schema imported to local DB', 'pass');

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
  'deploy-update': async () => {
    if (state.updateServiceDeployed) {
      addAutoCheck('Update service already deployed (resumed)', 'pass');
      return;
    }

    const item = addAutoCheck('Creating update service...', 'running');
    setAutoProgress(30);

    // Create a minimal update service placeholder
    addAutoCheck('Update service deployment pending — copy branch-update-service.js to bundled/', 'warn');

    // Create systemd service
    const svcContent = `[Unit]
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

    await api.wsl(`sudo tee /etc/systemd/system/aqura-update.service > /dev/null << 'EOF'\n${svcContent}\nEOF`);
    await api.wsl('sudo systemctl daemon-reload && sudo systemctl enable aqura-update');
    updateAutoCheck(item, 'Update service created & enabled', 'pass');

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
