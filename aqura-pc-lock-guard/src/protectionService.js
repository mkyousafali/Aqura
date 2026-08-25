// Aqura PC Lock Guard — Main Protection Service
// Orchestrates policy enforcement, printer protection, app control, and self-healing.

const { loadConfig, saveConfig } = require('./config');
const windowsPolicies = require('./windowsPolicies');
const printerProtection = require('./printerProtection');
const appControl = require('./appControl');
const heartbeat = require('./heartbeat');
const localDb = require('./localDb');
const logger = require('./logger');

let verificationTimer = null;
let maintenanceTimer = null;

function startProtection() {
	const cfg = loadConfig();
	if (!cfg.setupComplete) {
		logger.warn('Cannot start protection — setup not complete');
		return false;
	}

	logger.info('Starting protection...');
	localDb.recordEvent('INFO', 'service', 'Protection starting');

	// Apply Windows policies
	windowsPolicies.applyAllPolicies(cfg.policies);

	// Set printer baseline and apply restrictions
	if (cfg.printerProtectionEnabled) {
		const printers = printerProtection.scanPrinters();
		printerProtection.setBaseline(printers);
		printerProtection.restrictPrinterManagement();
	}

	// Apply app control
	if (cfg.appControlMode === 'enforcement') {
		appControl.blockInstallers();
	}

	// Start periodic verification
	startVerificationLoop();

	// Start heartbeat
	heartbeat.startHeartbeat();

	// Update state
	saveConfig({ protectionState: 'protected' });
	localDb.recordEvent('INFO', 'service', 'Protection active');
	logger.info('Protection active');

	return true;
}

function stopProtection(reason = 'manual') {
	logger.info(`Stopping protection: ${reason}`);
	localDb.recordEvent('WARNING', 'service', `Protection stopped: ${reason}`);

	// Remove policies
	const cfg = loadConfig();
	windowsPolicies.removeAllPolicies(cfg.policies);
	printerProtection.removePrinterRestrictions();
	appControl.unblockInstallers();

	// Stop timers
	stopVerificationLoop();

	saveConfig({ protectionState: 'unconfigured' });
}

function startVerificationLoop() {
	const cfg = loadConfig();
	const intervalMs = (cfg.policyCheckIntervalMinutes || 3) * 60 * 1000;

	if (verificationTimer) clearInterval(verificationTimer);

	verificationTimer = setInterval(() => {
		runVerification();
	}, intervalMs);

	// Run initial verification
	runVerification();
}

function stopVerificationLoop() {
	if (verificationTimer) {
		clearInterval(verificationTimer);
		verificationTimer = null;
	}
}

function runVerification() {
	const cfg = loadConfig();
	if (cfg.maintenanceMode) return;

	let issues = 0;

	// Verify Windows policies
	const violations = windowsPolicies.verifyAllPolicies(cfg.policies);
	if (violations.length > 0) {
		logger.warn(`Policy violations: ${violations.join(', ')}`);
		const repair = windowsPolicies.repairPolicies(cfg.policies);
		if (repair.status !== 'ok') issues++;
	}

	// Verify printer protection
	if (cfg.printerProtectionEnabled) {
		const printerStatus = printerProtection.verifyPrinterProtection();
		if (!printerStatus.protected) {
			printerProtection.restorePrinterBaseline();
			issues++;
		}
	}

	// Check for unapproved processes (audit or enforcement)
	if (cfg.appControlMode !== 'disabled') {
		const unapproved = appControl.detectNewExecutables();
		if (unapproved.length > 0) {
			logger.warn(`Unapproved processes detected: ${unapproved.length}`);
		}
	}

	if (issues > 0) {
		saveConfig({ protectionState: 'problem' });
		localDb.recordEvent('HIGH', 'service', `Verification found ${issues} issue(s), repairs attempted`);
	} else {
		if (cfg.protectionState === 'problem') {
			saveConfig({ protectionState: 'protected' });
			localDb.recordEvent('INFO', 'service', 'All issues resolved, protection restored');
		}
	}
}

// --- Maintenance Mode ---

function startMaintenance(reason, durationMinutes) {
	const cfg = loadConfig();
	const endTime = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();

	logger.info(`Maintenance mode started: ${reason} (${durationMinutes} min)`);
	localDb.recordEvent('WARNING', 'maintenance', `Maintenance started: ${reason}`, { duration: durationMinutes });

	// Relax protections
	windowsPolicies.removeAllPolicies(cfg.policies);
	printerProtection.removePrinterRestrictions();
	appControl.unblockInstallers();

	saveConfig({
		maintenanceMode: true,
		maintenanceReason: reason,
		maintenanceEndTime: endTime,
		protectionState: 'maintenance'
	});

	// Set timer for auto-end
	if (maintenanceTimer) clearTimeout(maintenanceTimer);
	maintenanceTimer = setTimeout(() => {
		endMaintenance('timer_expired');
	}, durationMinutes * 60 * 1000);

	return { endTime, reason };
}

function endMaintenance(trigger = 'manual') {
	if (maintenanceTimer) {
		clearTimeout(maintenanceTimer);
		maintenanceTimer = null;
	}

	logger.info(`Maintenance ending (trigger: ${trigger})`);
	localDb.recordEvent('INFO', 'maintenance', `Maintenance ended: ${trigger}`);

	// Rescan and restore
	const apps = appControl.buildInventory();
	logger.info(`Post-maintenance app scan: ${apps.length} apps`);

	const printers = printerProtection.scanPrinters();
	printerProtection.setBaseline(printers);

	saveConfig({
		maintenanceMode: false,
		maintenanceReason: null,
		maintenanceEndTime: null
	});

	// Re-apply all protections
	startProtection();
}

function getMaintenanceTimeRemaining() {
	const cfg = loadConfig();
	if (!cfg.maintenanceMode || !cfg.maintenanceEndTime) return 0;
	const remaining = new Date(cfg.maintenanceEndTime).getTime() - Date.now();
	return Math.max(0, Math.floor(remaining / 1000));
}

// --- Remote Command Execution ---

function executeRemoteCommand(action, params) {
	logger.info(`Executing remote command: ${action}`);
	localDb.recordEvent('INFO', 'remote', `Executing: ${action}`, params);

	switch (action) {
		case 'check_protection':
			runVerification();
			return { status: 'ok', message: 'Verification complete' };

		case 'repair_protection':
			const cfg = loadConfig();
			windowsPolicies.repairPolicies(cfg.policies);
			printerProtection.restorePrinterBaseline();
			return { status: 'ok', message: 'Repair attempted' };

		case 'sync_policy':
			// Will be handled by heartbeat cycle
			return { status: 'ok', message: 'Policy sync requested' };

		case 'refresh_app_inventory':
			const apps = appControl.buildInventory();
			return { status: 'ok', count: apps.length };

		case 'refresh_printer_inventory':
			const printers = printerProtection.scanPrinters();
			printerProtection.setBaseline(printers);
			return { status: 'ok', count: printers.length };

		case 'sync_logs':
			return { status: 'ok', message: 'Log sync triggered' };

		default:
			return { status: 'error', message: `Unknown action: ${action}` };
	}
}

function processPendingCommands() {
	const commands = localDb.getPendingCommands();
	for (const cmd of commands) {
		try {
			const params = cmd.params ? JSON.parse(cmd.params) : null;
			const result = executeRemoteCommand(cmd.action, params);
			localDb.markCommandExecuted(cmd.command_id, result, 'completed');
		} catch (err) {
			localDb.markCommandExecuted(cmd.command_id, { error: err.message }, 'failed');
		}
	}
}

// --- Status ---

function getStatus() {
	const cfg = loadConfig();
	return {
		protectionState: cfg.protectionState,
		maintenanceMode: cfg.maintenanceMode,
		maintenanceReason: cfg.maintenanceReason,
		maintenanceTimeRemaining: getMaintenanceTimeRemaining(),
		branchName: cfg.branchName,
		counterName: cfg.counterName,
		setupComplete: cfg.setupComplete,
		appControlMode: cfg.appControlMode,
		printerProtectionEnabled: cfg.printerProtectionEnabled,
		policies: cfg.policies
	};
}

module.exports = {
	startProtection,
	stopProtection,
	runVerification,
	startMaintenance,
	endMaintenance,
	getMaintenanceTimeRemaining,
	executeRemoteCommand,
	processPendingCommands,
	getStatus
};
