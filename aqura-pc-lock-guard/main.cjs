// Aqura PC Lock Guard — Electron main process
// Hosts the management UI and orchestrates all protection services.

const { app, BrowserWindow, ipcMain, globalShortcut, dialog } = require('electron');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');

const { loadConfig, saveConfig } = require('./src/config');
const { getSupabaseClient } = require('./src/supabaseClient');
const protectionService = require('./src/protectionService');
const printerProtection = require('./src/printerProtection');
const appControl = require('./src/appControl');
const heartbeat = require('./src/heartbeat');
const watchdog = require('./src/watchdog');
const recoveryAgent = require('./src/recoveryAgent');
const localDb = require('./src/localDb');
const logger = require('./src/logger');

// Check admin privileges
function isAdmin() {
	try {
		execSync('net session', { windowsHide: true, timeout: 3000 });
		return true;
	} catch (_) {
		return false;
	}
}

// Re-launch as admin if not elevated (only for packaged builds)
if (!isAdmin() && app.isPackaged) {
	const { shell } = require('electron');
	shell.openPath(app.getPath('exe')); // triggers UAC via manifest
	app.quit();
}

let mainWindow;

function createWindow() {
	mainWindow = new BrowserWindow({
		width: 1100,
		height: 750,
		resizable: true,
		minimizable: true,
		maximizable: true,
		closable: false,
		icon: path.join(__dirname, 'Logo.png'),
		title: 'Aqura PC Lock Guard',
		skipTaskbar: true,
		show: false,
		webPreferences: {
			preload: path.join(__dirname, 'preload.cjs'),
			contextIsolation: true,
			nodeIntegration: false,
			sandbox: true
		}
	});
	mainWindow.setMenuBarVisibility(false);
	mainWindow.on('close', (event) => {
		event.preventDefault();
		mainWindow.hide();
	});
	mainWindow.loadFile(path.join(__dirname, 'ui', 'index.html'));
}

function toggleWindow() {
	if (!mainWindow) return;
	if (mainWindow.isVisible()) {
		mainWindow.hide();
	} else {
		mainWindow.show();
		mainWindow.focus();
	}
}

function setMachineAutoStart(enable) {
	const exePath = app.getPath('exe');
	const keyPath = 'HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run';
	try {
		if (enable) {
			execSync(`reg add "${keyPath}" /v "AquraPCLockGuard" /t REG_SZ /d "\\"${exePath}\\"" /f`, { windowsHide: true });
		} else {
			execSync(`reg delete "${keyPath}" /v "AquraPCLockGuard" /f`, { windowsHide: true });
		}
	} catch (_) {}
}

app.whenReady().then(() => {
	createWindow();
	const cfg = loadConfig();

	// Register hotkey
	globalShortcut.register('Ctrl+Shift+B', toggleWindow);

	// Ensure auto-start
	setMachineAutoStart(true);

	if (cfg.setupComplete) {
		// Already configured — start protection silently (only if admin)
		if (isAdmin()) {
			protectionService.startProtection();
			watchdog.startWatchdog();
		}
		recoveryAgent.startRecoveryAgent();
	} else {
		// First run — show setup wizard
		mainWindow.show();
	}

	// Generate device ID if not set — use Windows Machine GUID for deterministic ID
	if (!cfg.deviceId) {
		let machineId;
		try {
			const guid = execSync('reg query "HKLM\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid', { encoding: 'utf8', windowsHide: true });
			const match = guid.match(/MachineGuid\s+REG_SZ\s+(.+)/);
			machineId = match ? match[1].trim().replace(/-/g, '').slice(0, 16) : crypto.randomBytes(8).toString('hex');
		} catch (_) {
			machineId = crypto.randomBytes(8).toString('hex');
		}
		saveConfig({ deviceId: `lg_${machineId}` });
	}
});

app.on('window-all-closed', () => {
	if (process.platform !== 'darwin') app.quit();
});

app.on('will-quit', () => {
	globalShortcut.unregisterAll();
	heartbeat.stopHeartbeat();
	localDb.close();
});

// ---------- IPC Handlers ----------

// --- Auth ---

ipcMain.handle('auth:verify-access-code', async (_event, code) => {
	try {
		const supabase = getSupabaseClient();
		const { data, error } = await supabase.rpc('verify_quick_access_code', { p_code: code });
		if (error) return { success: false, error: error.message };
		if (!data || !data.success) return { success: false, error: data?.error || 'Invalid access code' };
		return { success: true, userId: data.user.id, username: data.user.username };
	} catch (err) {
		return { success: false, error: err.message };
	}
});

ipcMain.handle('auth:send-otp', async (_event, { userId, purpose }) => {
	try {
		const supabase = getSupabaseClient();
		const { data, error } = await supabase.rpc('generate_and_send_email_otp', {
			p_user_id: userId,
			p_purpose: purpose || 'login'
		});
		if (error) return { success: false, error: error.message };
		if (!data || !data.success) return { success: false, error: data?.error || 'Failed to generate OTP' };
		const { error: sendError } = await supabase.functions.invoke('email-send', {
			body: { queue_id: data.queue_id }
		});
		if (sendError) console.error('Email send error (OTP still valid):', sendError.message);
		return { success: true, maskedEmail: data.masked_email, expiresIn: data.expires_in_seconds };
	} catch (err) {
		return { success: false, error: err.message };
	}
});

ipcMain.handle('auth:verify-otp', async (_event, { userId, otp, purpose }) => {
	try {
		const supabase = getSupabaseClient();
		const { data, error } = await supabase.rpc('verify_email_otp', {
			p_user_id: userId,
			p_otp: otp,
			p_purpose: purpose || 'login'
		});
		if (error) return { success: false, error: error.message };
		if (!data || !data.success) return { success: false, error: data?.error || 'Verification failed' };
		return { success: true };
	} catch (err) {
		return { success: false, error: err.message };
	}
});

// --- Config ---

ipcMain.handle('config:get', () => {
	const cfg = loadConfig();
	const { supabaseServiceKey, ...safe } = cfg;
	// Check if running as admin
	let isAdmin = false;
	try {
		execSync('net session', { windowsHide: true, timeout: 3000 });
		isAdmin = true;
	} catch (_) {}
	return { ...safe, supabaseServiceKeySet: Boolean(supabaseServiceKey), isAdmin };
});

ipcMain.handle('config:save', (_event, partial) => {
	const merged = saveConfig(partial);
	const { supabaseServiceKey, ...safe } = merged;
	return { ...safe, supabaseServiceKeySet: Boolean(supabaseServiceKey) };
});

// --- Supabase ---

ipcMain.handle('supabase:test-connection', async () => {
	try {
		const supabase = getSupabaseClient();
		const { error } = await supabase.from('branches').select('id').limit(1);
		if (error) throw error;
		return { success: true };
	} catch (err) {
		return { success: false, error: err.message };
	}
});

ipcMain.handle('supabase:load-branches', async () => {
	try {
		const supabase = getSupabaseClient();
		const { data, error } = await supabase
			.from('branches')
			.select('id, name_en, name_ar')
			.eq('is_active', true)
			.order('name_en');
		if (error) throw error;
		return { success: true, branches: data || [] };
	} catch (err) {
		return { success: false, error: err.message, branches: [] };
	}
});

ipcMain.handle('supabase:get-erp-connection', async (_event, branchId) => {
	try {
		const supabase = getSupabaseClient();
		const { data, error } = await supabase
			.from('erp_connections')
			.select('branch_id, branch_name, server_ip, server_name, database_name, username, password, erp_branch_id, tunnel_url')
			.eq('branch_id', branchId)
			.eq('is_active', true)
			.maybeSingle();
		if (error) throw error;
		return { success: true, connection: data || null };
	} catch (err) {
		return { success: false, error: err.message, connection: null };
	}
});

// --- SQL ---

ipcMain.handle('sql:test-connection', async (_event, { sqlServer, sqlDatabase, sqlUser, sqlPassword, tunnelUrl }) => {
	// If tunnel_url is available, use the HTTP bridge
	if (tunnelUrl) {
		try {
			const baseUrl = tunnelUrl.replace(/\/+$/, '');
			const resp = await fetch(`${baseUrl}/query`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-api-secret': 'aqura-erp-bridge-2026' },
				body: JSON.stringify({ sql: 'SELECT @@SERVERNAME AS ServerName' }),
				signal: AbortSignal.timeout(15000)
			});
			const data = await resp.json();
			if (!data.success) return { success: false, error: data.error || 'Bridge query failed' };
			return { success: true, serverName: data.recordset?.[0]?.ServerName || 'Connected' };
		} catch (err) {
			return { success: false, error: err.message };
		}
	}
	// Fallback: direct mssql (when on same LAN)
	const sql = require('mssql');
	const TIMEOUT_MS = 15000;
	const pool = new sql.ConnectionPool({
		server: sqlServer,
		database: sqlDatabase,
		user: sqlUser,
		password: sqlPassword,
		options: { encrypt: false, trustServerCertificate: true },
		connectionTimeout: TIMEOUT_MS,
		requestTimeout: TIMEOUT_MS
	});
	pool.on('error', () => {});
	try {
		await Promise.race([
			pool.connect(),
			new Promise((_, reject) => setTimeout(() => reject(new Error(`Timed out (${TIMEOUT_MS / 1000}s)`)), TIMEOUT_MS))
		]);
		const result = await pool.request().query('SELECT @@SERVERNAME AS ServerName');
		pool.close().catch(() => {});
		return { success: true, serverName: result.recordset[0]?.ServerName };
	} catch (err) {
		pool.close().catch(() => {});
		return { success: false, error: err.message };
	}
});

ipcMain.handle('sql:load-counters', async (_event, { sqlServer, database, sqlUser, sqlPassword, erpBranchId, tunnelUrl }) => {
	// If tunnel_url is available, use the HTTP bridge
	if (tunnelUrl) {
		try {
			const baseUrl = tunnelUrl.replace(/\/+$/, '');
			const sql = `SELECT CounterID, CounterName FROM Counter WHERE BranchID = ${parseInt(erpBranchId)} ORDER BY CounterName`;
			const resp = await fetch(`${baseUrl}/query`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-api-secret': 'aqura-erp-bridge-2026' },
				body: JSON.stringify({ sql }),
				signal: AbortSignal.timeout(15000)
			});
			const data = await resp.json();
			if (!data.success) return { success: false, error: data.error || 'Bridge query failed', counters: [] };
			return { success: true, counters: data.recordset || [] };
		} catch (err) {
			return { success: false, error: err.message, counters: [] };
		}
	}
	// Fallback: direct mssql
	const sql = require('mssql');
	const TIMEOUT_MS = 15000;
	const pool = new sql.ConnectionPool({
		server: sqlServer,
		database,
		user: sqlUser,
		password: sqlPassword,
		options: { encrypt: false, trustServerCertificate: true },
		connectionTimeout: TIMEOUT_MS,
		requestTimeout: TIMEOUT_MS
	});
	pool.on('error', () => {});
	try {
		await Promise.race([
			pool.connect(),
			new Promise((_, reject) => setTimeout(() => reject(new Error(`Timed out`)), TIMEOUT_MS))
		]);
		const result = await pool.request()
			.input('branchId', sql.Int, erpBranchId)
			.query('SELECT CounterID, CounterName FROM Counter WHERE BranchID = @branchId ORDER BY CounterName');
		pool.close().catch(() => {});
		return { success: true, counters: result.recordset };
	} catch (err) {
		pool.close().catch(() => {});
		return { success: false, error: err.message, counters: [] };
	}
});

// --- Protection ---

ipcMain.handle('protection:start', () => {
	return { success: protectionService.startProtection() };
});

ipcMain.handle('protection:stop', () => {
	protectionService.stopProtection('ui_request');
	return { success: true };
});

ipcMain.handle('protection:status', () => {
	return protectionService.getStatus();
});

ipcMain.handle('protection:verify', () => {
	protectionService.runVerification();
	const cfg = loadConfig();
	const violations = require('./src/windowsPolicies').verifyAllPolicies(cfg.policies);
	return { success: true, violations };
});

ipcMain.handle('protection:repair', () => {
	const cfg = loadConfig();
	const policyResult = require('./src/windowsPolicies').repairPolicies(cfg.policies);
	const printerResult = printerProtection.restorePrinterBaseline();
	return { success: true, policies: policyResult, printers: printerResult };
});

ipcMain.handle('protection:verify-policies', () => {
	const cfg = loadConfig();
	const violations = require('./src/windowsPolicies').verifyAllPolicies(cfg.policies);
	return { success: true, violations };
});

// --- Maintenance ---

ipcMain.handle('maintenance:start', (_event, { reason, durationMinutes }) => {
	const result = protectionService.startMaintenance(reason, durationMinutes);
	return { success: true, ...result };
});

ipcMain.handle('maintenance:end', () => {
	protectionService.endMaintenance('manual');
	return { success: true };
});

ipcMain.handle('maintenance:time-remaining', () => {
	return { seconds: protectionService.getMaintenanceTimeRemaining() };
});

// --- App Control ---

ipcMain.handle('apps:scan', () => {
	const apps = appControl.buildInventory();
	return { success: true, count: apps.length };
});

ipcMain.handle('apps:list', () => {
	return { success: true, apps: localDb.getAllApps() };
});

ipcMain.handle('apps:set-status', (_event, { id, status }) => {
	localDb.setAppStatus(id, status);
	return { success: true };
});

// --- Printers ---

ipcMain.handle('printers:scan', () => {
	const printers = printerProtection.scanPrinters();
	printerProtection.setBaseline(printers);
	return { success: true, printers };
});

ipcMain.handle('printers:list', () => {
	return { success: true, printers: localDb.getAllPrinters() };
});

// --- Events / Logs ---

ipcMain.handle('events:recent', (_event, limit) => {
	return { success: true, events: localDb.getRecentEvents(limit || 50) };
});

ipcMain.handle('logs:read', () => {
	return { success: true, content: logger.readTail(300) };
});

// --- UI ---

ipcMain.handle('ui:lock', () => {
	if (mainWindow) mainWindow.hide();
	return { success: true };
});
