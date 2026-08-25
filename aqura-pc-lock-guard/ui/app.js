// Aqura PC Lock Guard - UI Application Logic

let currentUserId = null;
let currentStep = 0;
let selectedBranch = null;
let counterName = '';
let deviceName = '';
let isUnlocked = false;

// ---------- Initialization ----------

document.addEventListener('DOMContentLoaded', async () => {
	const cfg = await window.lockguard.getConfig();

	// Check admin status
	if (!cfg.isAdmin) {
		document.getElementById('admin-warning').classList.remove('hidden');
	}

	if (cfg.setupComplete) {
		// Show auth screen (locked by default)
		showScreen('auth-screen');
		setupDigitInputs('code-digits', 6, onAccessCodeComplete);
	} else {
		showScreen('auth-screen');
		setupDigitInputs('code-digits', 6, onAccessCodeComplete);
	}
});

// ---------- Screen Management ----------

function showScreen(id) {
	document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
	document.getElementById(id).classList.add('active');
}

function switchSection(section) {
	document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
	document.getElementById(`section-${section}`).classList.add('active');
	document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
	document.querySelector(`.nav-item[data-section="${section}"]`).classList.add('active');

	if (section === 'events') refreshEvents();
	if (section === 'connection') testConnections();
	if (section === 'protection') loadPolicies();
}

// ---------- Auth: Access Code ----------

function setupDigitInputs(containerId, count, onComplete) {
	const container = document.getElementById(containerId);
	const inputs = container.querySelectorAll('.digit');

	inputs.forEach((input, idx) => {
		input.addEventListener('input', (e) => {
			const val = e.target.value.replace(/\D/g, '');
			e.target.value = val;
			if (val && idx < count - 1) inputs[idx + 1].focus();
			// Check if all filled
			const code = Array.from(inputs).map(i => i.value).join('');
			if (code.length === count) onComplete(code);
		});

		input.addEventListener('keydown', (e) => {
			if (e.key === 'Backspace' && !e.target.value && idx > 0) {
				inputs[idx - 1].focus();
				inputs[idx - 1].value = '';
			}
		});

		input.addEventListener('paste', (e) => {
			e.preventDefault();
			const text = (e.clipboardData || window.clipboardData).getData('text').replace(/\D/g, '');
			for (let i = 0; i < Math.min(text.length, count); i++) {
				inputs[i].value = text[i];
			}
			if (text.length >= count) {
				inputs[count - 1].focus();
				onComplete(text.slice(0, count));
			} else if (text.length > 0) {
				inputs[Math.min(text.length, count - 1)].focus();
			}
		});
	});
}

async function onAccessCodeComplete(code) {
	const errorEl = document.getElementById('code-error');
	const loadingEl = document.getElementById('code-loading');
	errorEl.textContent = '';
	loadingEl.classList.remove('hidden');

	const result = await window.lockguard.verifyAccessCode(code);
	loadingEl.classList.add('hidden');

	if (!result.success) {
		errorEl.textContent = result.error || 'Invalid code';
		clearDigitInputs('code-digits');
		return;
	}

	currentUserId = result.userId;
	// Send OTP
	const otpResult = await window.lockguard.sendOtp({ userId: currentUserId, purpose: 'login' });
	if (!otpResult.success) {
		errorEl.textContent = otpResult.error || 'Failed to send OTP';
		return;
	}

	document.getElementById('masked-email').textContent = otpResult.maskedEmail || '***';
	document.getElementById('access-code-step').classList.add('hidden');
	document.getElementById('otp-step').classList.remove('hidden');
	setupDigitInputs('otp-digits', 6, onOtpComplete);

	// Countdown
	startOtpCountdown(otpResult.expiresIn || 300);
}

async function onOtpComplete(otp) {
	const errorEl = document.getElementById('otp-error');
	const loadingEl = document.getElementById('otp-loading');
	errorEl.textContent = '';
	loadingEl.classList.remove('hidden');

	const result = await window.lockguard.verifyOtp({ userId: currentUserId, otp, purpose: 'login' });
	loadingEl.classList.add('hidden');

	if (!result.success) {
		errorEl.textContent = result.error || 'Invalid OTP';
		clearDigitInputs('otp-digits');
		return;
	}

	// Check if setup is needed
	const cfg = await window.lockguard.getConfig();
	if (cfg.setupComplete) {
		isUnlocked = true;
		showScreen('dashboard-screen');
		loadDashboard();
	} else {
		showScreen('wizard-screen');
		loadBranches();
	}
}

function clearDigitInputs(containerId) {
	const inputs = document.getElementById(containerId).querySelectorAll('.digit');
	inputs.forEach(i => { i.value = ''; });
	inputs[0].focus();
}

let otpCountdownTimer = null;
function startOtpCountdown(seconds) {
	if (otpCountdownTimer) clearInterval(otpCountdownTimer);
	let remaining = seconds;
	const el = document.getElementById('otp-countdown');
	el.textContent = `Expires in ${formatTime(remaining)}`;
	otpCountdownTimer = setInterval(() => {
		remaining--;
		if (remaining <= 0) {
			clearInterval(otpCountdownTimer);
			el.textContent = 'OTP expired - please try again';
		} else {
			el.textContent = `Expires in ${formatTime(remaining)}`;
		}
	}, 1000);
}

function formatTime(s) {
	const m = Math.floor(s / 60);
	const sec = s % 60;
	return `${m}:${sec.toString().padStart(2, '0')}`;
}

// ---------- Wizard ----------

async function loadBranches() {
	const result = await window.lockguard.loadBranches();
	const select = document.getElementById('branch-select');
	select.innerHTML = '<option value="">-- Select Branch --</option>';
	if (result.success && result.branches.length) {
		for (const b of result.branches) {
			const opt = document.createElement('option');
			opt.value = b.id;
			opt.textContent = `${b.name_en} / ${b.name_ar}`;
			opt.dataset.nameEn = b.name_en;
			select.appendChild(opt);
		}
	}
	select.addEventListener('change', () => {
		const btn = document.getElementById('branch-next-btn');
		btn.disabled = !select.value;
		if (select.value) {
			selectedBranch = { id: select.value, name: select.options[select.selectedIndex].dataset.nameEn };
		}
	});
}

function wizardNext() {
	const steps = document.querySelectorAll('.wizard-step');
	const progress = document.querySelectorAll('.progress-step');

	steps[currentStep].classList.remove('active');
	if (progress[currentStep]) progress[currentStep].classList.remove('active');
	if (progress[currentStep]) progress[currentStep].classList.add('done');

	currentStep++;
	steps[currentStep].classList.add('active');
	if (progress[currentStep]) progress[currentStep].classList.add('active');

	// Step-specific init
	if (currentStep === 2) initDeviceStep();
	if (currentStep === 3) populateReview();
}

function wizardPrev() {
	const steps = document.querySelectorAll('.wizard-step');
	const progress = document.querySelectorAll('.progress-step');

	steps[currentStep].classList.remove('active');
	if (progress[currentStep]) progress[currentStep].classList.remove('active');

	currentStep--;
	steps[currentStep].classList.add('active');
	if (progress[currentStep]) progress[currentStep].classList.add('active');
	if (progress[currentStep]) progress[currentStep].classList.remove('done');
}

function initDeviceStep() {
	var counterInput = document.getElementById('counter-name-input');
	var deviceInput = document.getElementById('device-name-input');
	counterInput.addEventListener('input', function() { counterName = counterInput.value.trim(); });
	deviceInput.addEventListener('input', function() { deviceName = deviceInput.value.trim(); });
}

function populateReview() {
	document.getElementById('review-branch').textContent = selectedBranch ? selectedBranch.name : '-';
	document.getElementById('review-counter').textContent = counterName || '-';
	document.getElementById('review-device-name').textContent = deviceName || counterName || '-';
}

async function activateProtection() {
	await window.lockguard.saveConfig({
		counterName: counterName || 'Unnamed',
		deviceName: deviceName || counterName || 'Unnamed',
		branchId: selectedBranch ? selectedBranch.id : null,
		branchName: selectedBranch ? selectedBranch.name : null,
		setupComplete: true,
		protectionState: 'protected'
	});
	await window.lockguard.startProtection();
	// Send initial registration heartbeat immediately
	await window.lockguard.runVerification();
	document.getElementById('complete-branch').textContent = selectedBranch ? selectedBranch.name : '';
	document.getElementById('complete-counter').textContent = counterName || '';
	var steps = document.querySelectorAll('.wizard-step');
	steps[currentStep].classList.remove('active');
	currentStep = 4;
	steps[currentStep].classList.add('active');
}

function showDashboard() {
	showScreen('dashboard-screen');
	loadDashboard();
}

// ---------- Dashboard ----------

async function loadDashboard() {
	const status = await window.lockguard.getStatus();
	const cfg = await window.lockguard.getConfig();

	// Protection badge
	const badge = document.getElementById('protection-badge');
	badge.className = `protection-badge ${status.protectionState}`;
	const badgeTexts = { protected: 'PROTECTED', problem: 'PROBLEM', maintenance: 'MAINTENANCE MODE' };
	badge.querySelector('.badge-text').textContent = badgeTexts[status.protectionState] || 'UNKNOWN';

	// Status cards
	document.getElementById('dash-branch').textContent = status.branchName || '-';
	document.getElementById('dash-counter').textContent = status.counterName || '-';

	// Live cloud check
	window.lockguard.testConnection().then(function(r) {
		document.getElementById('dash-cloud').textContent = r.success ? 'Connected' : 'Disconnected';
		document.getElementById('dash-cloud').style.color = r.success ? 'var(--success)' : 'var(--danger)';
	});

	// Service status
	var isAdmin = cfg.isAdmin;
	document.getElementById('dash-main-service').textContent = isAdmin ? 'Running' : 'No Admin';
	document.getElementById('dash-main-service').style.color = isAdmin ? 'var(--success)' : 'var(--warning)';
	document.getElementById('dash-watchdog').textContent = isAdmin ? 'Running' : 'No Admin';
	document.getElementById('dash-watchdog').style.color = isAdmin ? 'var(--success)' : 'var(--warning)';
	document.getElementById('dash-recovery').textContent = 'Running';
	document.getElementById('dash-recovery').style.color = 'var(--success)';
	document.getElementById('dash-heartbeat').textContent = new Date().toLocaleTimeString();

	// Settings
	document.getElementById('settings-device-id').textContent = cfg.deviceId || '-';
	document.getElementById('settings-branch').textContent = cfg.branchName || '-';
	document.getElementById('settings-counter').textContent = cfg.counterName || '-';
	document.getElementById('settings-device-name').textContent = cfg.deviceName || '-';

	// Maintenance
	if (status.maintenanceMode) {
		document.getElementById('maintenance-active').classList.remove('hidden');
		document.getElementById('maintenance-form').classList.add('hidden');
		startMaintenanceCountdown();
	}
}

// ---------- Protection ----------

async function loadPolicies() {
	const status = await window.lockguard.getStatus();
	const verifyResult = await window.lockguard.verifyPolicies();
	const violations = verifyResult.violations || [];

	const list = document.getElementById('policy-list');
	const policyNames = {
		blockShutdown: 'Block Shutdown',
		blockRestart: 'Block Restart',
		blockSignOut: 'Block Sign Out',
		blockSwitchUser: 'Block Switch User',
		blockSleep: 'Block Sleep',
		blockHibernate: 'Block Hibernate',
		blockControlPanel: 'Block Control Panel',
		blockTaskManager: 'Block Task Manager',
		blockRegistryEditor: 'Block Registry Editor',
		blockCmd: 'Block CMD',
		blockPowershell: 'Block PowerShell',
		blockDateTimeChange: 'Block Date/Time Change',
		blockNetworkChange: 'Block Network Changes',
		powerButtonDoNothing: 'Power Button: Do Nothing'
	};

	list.innerHTML = '';
	for (const [key, label] of Object.entries(policyNames)) {
		const enabled = status.policies?.[key];
		const isViolated = violations.includes(key);
		const item = document.createElement('div');
		item.className = 'policy-item';
		let statusText, statusColor;
		if (!enabled) {
			statusText = 'Disabled';
			statusColor = 'var(--text-muted)';
		} else if (isViolated) {
			statusText = 'NOT Enforced';
			statusColor = 'var(--danger)';
		} else {
			statusText = 'Enforced';
			statusColor = 'var(--success)';
		}
		item.innerHTML = `
			<span class="policy-name">${label}</span>
			<span class="policy-status" style="color: ${statusColor}">${statusText}</span>
		`;
		list.appendChild(item);
	}
}

async function verifyProtection() {
	await window.lockguard.runVerification();
	loadDashboard();
	loadPolicies();
}

async function repairProtection() {
	await window.lockguard.repairProtection();
	loadDashboard();
	loadPolicies();
}

// ---------- App Management ----------

async function scanApps() {
	const result = await window.lockguard.scanApps();
	if (result.success) {
		loadAppList();
	}
}

async function loadAppList() {
	const result = await window.lockguard.getApps();
	const list = document.getElementById('app-list');
	if (!result.success || !result.apps.length) {
		list.innerHTML = '<p class="empty-state">No applications found</p>';
		return;
	}

	list.innerHTML = '';
	for (const app of result.apps) {
		const item = document.createElement('div');
		item.className = 'app-item';
		const statusColor = app.status === 'approved' ? 'var(--success)' : app.status === 'blocked' ? 'var(--danger)' : 'var(--text-muted)';
		item.innerHTML = `
			<div>
				<div style="font-weight:500">${app.name}</div>
				<div style="font-size:11px;color:var(--text-muted)">${app.publisher || ''}</div>
			</div>
			<div style="display:flex;gap:6px;align-items:center">
				<span style="color:${statusColor};font-size:11px">${app.status}</span>
				<button class="btn btn-sm" style="background:var(--success);color:#fff" onclick="setAppApproved(${app.id})"></button>
				<button class="btn btn-sm" style="background:var(--danger);color:#fff" onclick="setAppBlocked(${app.id})">X </button>
			</div>
		`;
		list.appendChild(item);
	}
}

async function setAppApproved(id) {
	await window.lockguard.setAppStatus(id, 'approved');
	loadAppList();
}

async function setAppBlocked(id) {
	await window.lockguard.setAppStatus(id, 'blocked');
	loadAppList();
}

// ---------- Printers ----------

async function scanPrinters() {
	const result = await window.lockguard.scanPrinters();
	const list = document.getElementById('printer-list');
	if (!result.success || !result.printers.length) {
		list.innerHTML = '<p class="empty-state">No printers found</p>';
		return;
	}

	list.innerHTML = '';
	for (const p of result.printers) {
		const item = document.createElement('div');
		item.className = 'printer-item';
		item.innerHTML = `
			<div>
				<div style="font-weight:500">${p.name}</div>
				<div style="font-size:11px;color:var(--text-muted)">${p.driver || ''} - ${p.port || ''}</div>
			</div>
			<span style="color:var(--success)">Protected</span>
		`;
		list.appendChild(item);
	}
}

// ---------- Maintenance ----------

async function startMaintenanceMode() {
	const reason = document.getElementById('maintenance-reason').value;
	const duration = parseInt(document.getElementById('maintenance-duration').value) || 30;

	// TODO: Add OTP verification before starting maintenance
	const result = await window.lockguard.startMaintenance({ reason, durationMinutes: duration });
	if (result.success) {
		document.getElementById('maintenance-active').classList.remove('hidden');
		document.getElementById('maintenance-form').classList.add('hidden');
		startMaintenanceCountdown();
		loadDashboard();
	}
}

async function endMaintenanceNow() {
	await window.lockguard.endMaintenance();
	document.getElementById('maintenance-active').classList.add('hidden');
	document.getElementById('maintenance-form').classList.remove('hidden');
	loadDashboard();
}

let maintenanceCountdownTimer = null;
function startMaintenanceCountdown() {
	if (maintenanceCountdownTimer) clearInterval(maintenanceCountdownTimer);
	maintenanceCountdownTimer = setInterval(async () => {
		const result = await window.lockguard.getMaintenanceTime();
		const s = result.seconds || 0;
		if (s <= 0) {
			clearInterval(maintenanceCountdownTimer);
			document.getElementById('maintenance-active').classList.add('hidden');
			document.getElementById('maintenance-form').classList.remove('hidden');
			loadDashboard();
			return;
		}
		const m = Math.floor(s / 60);
		const sec = s % 60;
		document.getElementById('maintenance-countdown').textContent = `${m}:${sec.toString().padStart(2, '0')}`;
	}, 1000);
}

// ---------- Events ----------

async function refreshEvents() {
	const result = await window.lockguard.getRecentEvents(100);
	const list = document.getElementById('event-list');
	if (!result.success || !result.events.length) {
		list.innerHTML = '<p class="empty-state">No events recorded</p>';
		return;
	}

	list.innerHTML = '';
	for (const ev of result.events) {
		const item = document.createElement('div');
		item.className = 'event-item';
		item.innerHTML = `
			<span class="event-severity ${ev.severity}">${ev.severity}</span>
			<span class="event-time">${ev.timestamp}</span>
			<span class="event-message">${ev.message}</span>
		`;
		list.appendChild(item);
	}
}

function filterEvents(severity) {
	const items = document.querySelectorAll('.event-item');
	items.forEach(item => {
		if (severity === 'all') {
			item.style.display = '';
		} else {
			const sev = item.querySelector('.event-severity').textContent;
			item.style.display = sev === severity ? '' : 'none';
		}
	});
}

// ---------- Connection ----------

async function testConnections() {
	testCloudConnection();
	testSqlConnectionDash();
}

async function testCloudConnection() {
	const el = document.getElementById('conn-cloud-status');
	el.textContent = 'Testing...';
	const result = await window.lockguard.testConnection();
	el.textContent = result.success ? 'Connected' : result.error;
	el.style.color = result.success ? 'var(--success)' : 'var(--danger)';
}

async function testSqlConnectionDash() {
	const el = document.getElementById('conn-sql-status');
	el.textContent = 'Testing...';
	const cfg = await window.lockguard.getConfig();
	if (!cfg.sqlServer) {
		el.textContent = 'Not configured';
		el.style.color = 'var(--text-muted)';
		return;
	}
	const result = await window.lockguard.testSqlConnection({
		sqlServer: cfg.sqlServer,
		sqlDatabase: cfg.sqlDatabase,
		sqlUser: cfg.sqlUser,
		sqlPassword: cfg.sqlPassword
	});
	el.textContent = result.success ? 'Connected' : result.error;
	el.style.color = result.success ? 'var(--success)' : 'var(--danger)';
}

// ---------- Settings ----------

async function reconfigureDevice() {
	if (!confirm('This will reset the device configuration. Are you sure?')) return;
	await window.lockguard.stopProtection();
	await window.lockguard.saveConfig({ setupComplete: false, protectionState: 'unconfigured' });
	showScreen('wizard-screen');
	currentStep = 0;
	counterName = '';
	deviceName = '';
	document.querySelectorAll('.wizard-step').forEach((s, i) => s.classList.toggle('active', i === 0));
	document.querySelectorAll('.progress-step').forEach((s, i) => {
		s.classList.toggle('active', i === 0);
		s.classList.remove('done');
	});
	loadBranches();
}

// ---------- Lock ----------

function lockUI() {
	isUnlocked = false;
	currentUserId = null;
	// Reset auth screen
	document.getElementById('access-code-step').classList.remove('hidden');
	document.getElementById('otp-step').classList.add('hidden');
	clearDigitInputs('code-digits');
	showScreen('auth-screen');
	// Hide the window
	window.lockguard.lockUI();
}

function setAppControlMode(mode) {
	window.lockguard.saveConfig({ appControlMode: mode });
}

