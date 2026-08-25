// Aqura PC Lock Guard — Electron preload script
// Exposes safe IPC bridge to renderer via contextBridge.

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('lockguard', {
	// Auth
	verifyAccessCode: (code) => ipcRenderer.invoke('auth:verify-access-code', code),
	sendOtp: (params) => ipcRenderer.invoke('auth:send-otp', params),
	verifyOtp: (params) => ipcRenderer.invoke('auth:verify-otp', params),

	// Config
	getConfig: () => ipcRenderer.invoke('config:get'),
	saveConfig: (partial) => ipcRenderer.invoke('config:save', partial),

	// Supabase / Cloud
	testConnection: (params) => ipcRenderer.invoke('supabase:test-connection', params),
	loadBranches: () => ipcRenderer.invoke('supabase:load-branches'),
	getErpConnection: (branchId) => ipcRenderer.invoke('supabase:get-erp-connection', branchId),

	// SQL
	testSqlConnection: (params) => ipcRenderer.invoke('sql:test-connection', params),
	loadCounters: (params) => ipcRenderer.invoke('sql:load-counters', params),

	// Protection
	startProtection: () => ipcRenderer.invoke('protection:start'),
	stopProtection: () => ipcRenderer.invoke('protection:stop'),
	getStatus: () => ipcRenderer.invoke('protection:status'),
	runVerification: () => ipcRenderer.invoke('protection:verify'),
	verifyPolicies: () => ipcRenderer.invoke('protection:verify-policies'),
	repairProtection: () => ipcRenderer.invoke('protection:repair'),

	// Maintenance
	startMaintenance: (params) => ipcRenderer.invoke('maintenance:start', params),
	endMaintenance: () => ipcRenderer.invoke('maintenance:end'),
	getMaintenanceTime: () => ipcRenderer.invoke('maintenance:time-remaining'),

	// App Control
	scanApps: () => ipcRenderer.invoke('apps:scan'),
	getApps: () => ipcRenderer.invoke('apps:list'),
	setAppStatus: (id, status) => ipcRenderer.invoke('apps:set-status', { id, status }),

	// Printers
	scanPrinters: () => ipcRenderer.invoke('printers:scan'),
	getPrinters: () => ipcRenderer.invoke('printers:list'),

	// Events / Logs
	getRecentEvents: (limit) => ipcRenderer.invoke('events:recent', limit),
	readLogs: () => ipcRenderer.invoke('logs:read'),

	// Window
	lockUI: () => ipcRenderer.invoke('ui:lock'),

	// Listeners
	onProtectionUpdate: (cb) => {
		ipcRenderer.on('protection:update', (_event, data) => cb(data));
	}
});
