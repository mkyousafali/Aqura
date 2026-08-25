// Aqura PC Lock Guard — Configuration
// Mirrors the pattern from Aqura Action Sync.

const fs = require('fs');
const path = require('path');

const DEFAULTS = {
	supabaseUrl: 'https://supabase.urbanaqura.com',
	supabaseAnonKey:
		'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448',
	supabaseServiceKey:
		'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0',

	// Device identity (set during first-time setup)
	deviceId: null,
	deviceName: null,
	branchId: null,
	branchName: null,
	erpBranchId: null,
	counterId: null,
	counterName: null,

	// SQL Server (from erp_connections)
	sqlServer: null,
	sqlDatabase: null,
	sqlUser: null,
	sqlPassword: null,

	// Protection state
	protectionState: 'unconfigured', // unconfigured | protected | maintenance | problem
	setupComplete: false,

	// Services
	mainServiceInstalled: false,
	watchdogInstalled: false,
	recoveryAgentInstalled: false,

	// Heartbeat
	heartbeatIntervalSeconds: 60,
	policyCheckIntervalMinutes: 3,

	// Maintenance
	maintenanceMode: false,
	maintenanceReason: null,
	maintenanceEndTime: null,

	// App control
	appControlMode: 'audit', // audit | enforcement
	approvedApps: [],

	// Windows policies
	policies: {
		blockShutdown: true,
		blockRestart: true,
		blockSignOut: true,
		blockSwitchUser: true,
		blockSleep: true,
		blockHibernate: true,
		blockControlPanel: true,
		blockTaskManager: true,
		blockRegistryEditor: true,
		blockCmd: true,
		blockPowershell: true,
		blockDateTimeChange: true,
		blockNetworkChange: true,
		powerButtonDoNothing: true
	},

	// Printer protection
	printerProtectionEnabled: true,
	protectedPrinters: []
};

const LOCAL_CONFIG_PATH = path.join(__dirname, '..', 'config.local.json');

function loadConfig() {
	let overrides = {};
	if (fs.existsSync(LOCAL_CONFIG_PATH)) {
		try {
			overrides = JSON.parse(fs.readFileSync(LOCAL_CONFIG_PATH, 'utf8'));
		} catch (err) {
			console.error('[config] Invalid config.local.json, ignoring overrides:', err.message);
		}
	}
	return { ...DEFAULTS, ...overrides };
}

function saveConfig(partial) {
	const current = loadConfig();
	const merged = { ...current, ...partial };
	fs.writeFileSync(LOCAL_CONFIG_PATH, JSON.stringify(merged, null, 2), 'utf8');
	return merged;
}

module.exports = { loadConfig, saveConfig, DEFAULTS };
