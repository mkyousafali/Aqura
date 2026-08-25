// Aqura PC Lock Guard — Recovery Agent
// Minimal independent component for cloud health checks and approved remote recovery actions.
// Runs separately from the main service to ensure recovery is always possible.

const { getSupabaseClient } = require('./supabaseClient');
const { loadConfig } = require('./config');
const logger = require('./logger');
const localDb = require('./localDb');
const { execSync } = require('child_process');

const RECOVERY_CHECK_INTERVAL_MS = 120000; // 2 minutes

let recoveryTimer = null;

async function checkCloudHealth() {
	try {
		const supabase = getSupabaseClient();
		const { error } = await supabase.from('branches').select('id').limit(1);
		if (error) throw error;
		return { connected: true };
	} catch (err) {
		return { connected: false, error: err.message };
	}
}

async function checkForRecoveryActions() {
	try {
		const supabase = getSupabaseClient();
		const cfg = loadConfig();
		if (!cfg.deviceId) return [];

		const { data, error } = await supabase
			.from('lockguard_remote_actions')
			.select('*')
			.eq('device_id', cfg.deviceId)
			.eq('status', 'pending')
			.eq('priority', 'recovery')
			.gt('expires_at', new Date().toISOString())
			.order('created_at', { ascending: true });

		if (error) throw error;
		return data || [];
	} catch (err) {
		logger.error(`Recovery action check failed: ${err.message}`);
		return [];
	}
}

function executeRecoveryAction(action) {
	switch (action.action) {
		case 'restart_main_service':
			try {
				execSync('sc stop AquraPCLockGuard', { timeout: 10000, windowsHide: true });
				execSync('sc start AquraPCLockGuard', { timeout: 10000, windowsHide: true });
				return { success: true };
			} catch (err) {
				return { success: false, error: err.message };
			}

		case 'restart_watchdog':
			try {
				execSync('sc stop AquraPCLockGuardWatchdog', { timeout: 10000, windowsHide: true });
				execSync('sc start AquraPCLockGuardWatchdog', { timeout: 10000, windowsHide: true });
				return { success: true };
			} catch (err) {
				return { success: false, error: err.message };
			}

		case 'force_policy_sync':
			localDb.recordEvent('INFO', 'recovery', 'Force policy sync requested');
			return { success: true, message: 'Policy sync triggered' };

		default:
			return { success: false, error: `Unknown recovery action: ${action.action}` };
	}
}

async function recoveryCheckCycle() {
	const health = await checkCloudHealth();
	if (!health.connected) {
		logger.warn('Recovery Agent: Cloud not reachable');
		return;
	}

	const actions = await checkForRecoveryActions();
	for (const action of actions) {
		const result = executeRecoveryAction(action);
		localDb.recordEvent('INFO', 'recovery', `Recovery action: ${action.action}`, result);

		// Report back
		try {
			const supabase = getSupabaseClient();
			await supabase
				.from('lockguard_remote_actions')
				.update({
					status: result.success ? 'completed' : 'failed',
					executed_at: new Date().toISOString(),
					result: result
				})
				.eq('id', action.id);
		} catch (_) {}
	}
}

function startRecoveryAgent() {
	if (recoveryTimer) return;
	logger.info('Recovery Agent started');

	recoveryTimer = setInterval(() => {
		recoveryCheckCycle().catch(() => {});
	}, RECOVERY_CHECK_INTERVAL_MS);

	// Initial check
	recoveryCheckCycle().catch(() => {});
}

function stopRecoveryAgent() {
	if (recoveryTimer) {
		clearInterval(recoveryTimer);
		recoveryTimer = null;
		logger.info('Recovery Agent stopped');
	}
}

module.exports = { startRecoveryAgent, stopRecoveryAgent, checkCloudHealth, checkForRecoveryActions };
