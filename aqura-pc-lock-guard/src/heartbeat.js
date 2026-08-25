// Aqura PC Lock Guard — Heartbeat & Cloud Sync
// Sends periodic heartbeat to Supabase, uploads pending events, fetches remote commands.

const { getSupabaseClient } = require('./supabaseClient');
const { loadConfig } = require('./config');
const localDb = require('./localDb');
const logger = require('./logger');
const os = require('os');

let heartbeatTimer = null;

function getDeviceInfo() {
	const cfg = loadConfig();
	return {
		device_id: cfg.deviceId,
		branch_id: cfg.branchId,
		branch_name: cfg.branchName,
		counter_id: cfg.counterId,
		counter_name: cfg.counterName,
		device_name: cfg.deviceName,
		hostname: os.hostname(),
		os_version: `${os.type()} ${os.release()}`,
		ip_address: getLocalIp(),
		protection_state: cfg.protectionState,
		maintenance_mode: cfg.maintenanceMode,
		app_version: require('../package.json').version
	};
}

function getLocalIp() {
	const interfaces = os.networkInterfaces();
	for (const iface of Object.values(interfaces)) {
		for (const addr of iface) {
			if (addr.family === 'IPv4' && !addr.internal) return addr.address;
		}
	}
	return '127.0.0.1';
}

async function sendHeartbeat() {
	try {
		const supabase = getSupabaseClient();
		const info = getDeviceInfo();
		const { error } = await supabase.rpc('lockguard_heartbeat', {
			p_device_id: info.device_id,
			p_branch_id: info.branch_id,
			p_hostname: info.hostname,
			p_ip_address: info.ip_address,
			p_protection_state: info.protection_state,
			p_maintenance_mode: info.maintenance_mode,
			p_os_version: info.os_version,
			p_app_version: info.app_version,
			p_counter_name: info.counter_name,
			p_device_name: info.device_name
		});
		if (error) throw error;
		logger.info('Heartbeat sent successfully');
	} catch (err) {
		logger.error(`Heartbeat failed: ${err.message}`);
	}
}

async function uploadPendingEvents() {
	try {
		const events = localDb.getUnsyncedEvents(100);
		if (!events.length) return;

		const supabase = getSupabaseClient();
		const cfg = loadConfig();

		const rows = events.map(e => ({
			device_id: cfg.deviceId,
			branch_id: cfg.branchId,
			timestamp: e.timestamp,
			severity: e.severity,
			category: e.category,
			message: e.message,
			details: typeof e.details === 'string' ? JSON.parse(e.details) : (e.details || null)
		}));

		const { error } = await supabase
			.from('lockguard_events')
			.insert(rows);

		if (error) throw error;

		localDb.markEventsSynced(events.map(e => e.id));
		logger.info(`Uploaded ${events.length} events to cloud`);
	} catch (err) {
		logger.error(`Event upload failed: ${err.message}`);
	}
}

async function fetchRemoteCommands() {
	try {
		const supabase = getSupabaseClient();
		const cfg = loadConfig();

		const { data, error } = await supabase
			.from('lockguard_remote_actions')
			.select('*')
			.eq('device_id', cfg.deviceId)
			.eq('status', 'pending')
			.gt('expires_at', new Date().toISOString())
			.order('created_at', { ascending: true });

		if (error) throw error;
		if (!data || !data.length) return [];

		for (const cmd of data) {
			localDb.addPendingCommand(cmd.id, cmd.action, cmd.params);
			// Mark as received in cloud
			await supabase
				.from('lockguard_remote_actions')
				.update({ status: 'received', received_at: new Date().toISOString() })
				.eq('id', cmd.id);
		}

		logger.info(`Fetched ${data.length} remote commands`);
		return data;
	} catch (err) {
		logger.error(`Remote command fetch failed: ${err.message}`);
		return [];
	}
}

async function syncCycle() {
	await sendHeartbeat();
	await uploadPendingEvents();
	await fetchRemoteCommands();
	// Execute any pending commands that were fetched
	try {
		const protectionService = require('./protectionService');
		protectionService.processPendingCommands();
	} catch (_) {}
}

function startHeartbeat() {
	const cfg = loadConfig();
	const intervalMs = (cfg.heartbeatIntervalSeconds || 60) * 1000;

	if (heartbeatTimer) clearInterval(heartbeatTimer);

	// Initial sync
	syncCycle().catch(() => {});

	heartbeatTimer = setInterval(() => {
		syncCycle().catch(() => {});
	}, intervalMs);

	logger.info(`Heartbeat started (interval: ${intervalMs / 1000}s)`);
}

function stopHeartbeat() {
	if (heartbeatTimer) {
		clearInterval(heartbeatTimer);
		heartbeatTimer = null;
		logger.info('Heartbeat stopped');
	}
}

module.exports = { sendHeartbeat, uploadPendingEvents, fetchRemoteCommands, syncCycle, startHeartbeat, stopHeartbeat };
