// Aqura PC Lock Guard — Local JSON-based Database
// Stores events, app inventory, printer inventory, and pending actions offline.
// Uses simple JSON files to avoid native module compilation requirements.

const path = require('path');
const fs = require('fs');
const logger = require('./logger');

const DB_DIR = path.join(__dirname, '..', 'data');
const EVENTS_FILE = path.join(DB_DIR, 'events.json');
const APPS_FILE = path.join(DB_DIR, 'apps.json');
const PRINTERS_FILE = path.join(DB_DIR, 'printers.json');
const COMMANDS_FILE = path.join(DB_DIR, 'commands.json');
const POLICY_FILE = path.join(DB_DIR, 'policy_cache.json');

const MAX_EVENTS = 5000;

function ensureDir() {
	if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR, { recursive: true });
}

function readJson(filePath, defaultVal = []) {
	try {
		if (!fs.existsSync(filePath)) return defaultVal;
		return JSON.parse(fs.readFileSync(filePath, 'utf8'));
	} catch (_) {
		return defaultVal;
	}
}

function writeJson(filePath, data) {
	ensureDir();
	fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
}

let nextEventId = 0;

function getNextEventId() {
	const events = readJson(EVENTS_FILE, []);
	if (events.length && nextEventId === 0) {
		nextEventId = Math.max(...events.map(e => e.id || 0)) + 1;
	}
	return ++nextEventId;
}

// --- Events ---

function recordEvent(severity, category, message, details = null) {
	ensureDir();
	const events = readJson(EVENTS_FILE, []);
	events.push({
		id: getNextEventId(),
		timestamp: new Date().toISOString(),
		severity,
		category,
		message,
		details: details || null,
		synced: 0
	});
	// Trim old events
	if (events.length > MAX_EVENTS) events.splice(0, events.length - MAX_EVENTS);
	writeJson(EVENTS_FILE, events);
}

function getUnsyncedEvents(limit = 100) {
	const events = readJson(EVENTS_FILE, []);
	return events.filter(e => !e.synced).slice(0, limit);
}

function markEventsSynced(ids) {
	if (!ids.length) return;
	const events = readJson(EVENTS_FILE, []);
	const idSet = new Set(ids);
	for (const e of events) {
		if (idSet.has(e.id)) e.synced = 1;
	}
	writeJson(EVENTS_FILE, events);
}

function getRecentEvents(limit = 50) {
	const events = readJson(EVENTS_FILE, []);
	return events.slice(-limit).reverse();
}

// --- App Inventory ---

function upsertApp(app) {
	const apps = readJson(APPS_FILE, []);
	const idx = apps.findIndex(a => a.path === app.path);
	if (idx >= 0) {
		apps[idx] = { ...apps[idx], ...app, last_seen: new Date().toISOString(), synced: 0 };
	} else {
		apps.push({ ...app, id: apps.length + 1, first_seen: new Date().toISOString(), last_seen: new Date().toISOString(), synced: 0 });
	}
	writeJson(APPS_FILE, apps);
}

function getAllApps() {
	return readJson(APPS_FILE, []).sort((a, b) => (a.name || '').localeCompare(b.name || ''));
}

function setAppStatus(id, status) {
	const apps = readJson(APPS_FILE, []);
	const app = apps.find(a => a.id === id);
	if (app) {
		app.status = status;
		app.synced = 0;
		writeJson(APPS_FILE, apps);
	}
}

// --- Printer Inventory ---

function upsertPrinter(printer) {
	const printers = readJson(PRINTERS_FILE, []);
	const idx = printers.findIndex(p => p.name === printer.name);
	if (idx >= 0) {
		printers[idx] = { ...printers[idx], ...printer, last_seen: new Date().toISOString(), synced: 0 };
	} else {
		printers.push({ ...printer, id: printers.length + 1, first_seen: new Date().toISOString(), last_seen: new Date().toISOString(), synced: 0 });
	}
	writeJson(PRINTERS_FILE, printers);
}

function getAllPrinters() {
	return readJson(PRINTERS_FILE, []).sort((a, b) => (a.name || '').localeCompare(b.name || ''));
}

// --- Pending Commands ---

function addPendingCommand(commandId, action, params) {
	const commands = readJson(COMMANDS_FILE, []);
	if (commands.find(c => c.command_id === commandId)) return;
	commands.push({
		command_id: commandId,
		action,
		params: params || null,
		received_at: new Date().toISOString(),
		executed_at: null,
		result: null,
		status: 'pending'
	});
	writeJson(COMMANDS_FILE, commands);
}

function getPendingCommands() {
	return readJson(COMMANDS_FILE, []).filter(c => c.status === 'pending');
}

function markCommandExecuted(commandId, result, status = 'completed') {
	const commands = readJson(COMMANDS_FILE, []);
	const cmd = commands.find(c => c.command_id === commandId);
	if (cmd) {
		cmd.executed_at = new Date().toISOString();
		cmd.result = result;
		cmd.status = status;
		writeJson(COMMANDS_FILE, commands);
	}
}

// --- Policy Cache ---

function cachePolicy(policyJson, version) {
	writeJson(POLICY_FILE, { policy: policyJson, version, updated_at: new Date().toISOString() });
}

function getCachedPolicy() {
	const data = readJson(POLICY_FILE, null);
	return data;
}

function close() {
	// No-op for JSON store
}

module.exports = {
	recordEvent,
	getUnsyncedEvents,
	markEventsSynced,
	getRecentEvents,
	upsertApp,
	getAllApps,
	setAppStatus,
	upsertPrinter,
	getAllPrinters,
	addPendingCommand,
	getPendingCommands,
	markCommandExecuted,
	cachePolicy,
	getCachedPolicy,
	close
};
