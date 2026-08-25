// Aqura PC Lock Guard — Logger
// File-based logging with auto-truncation.

const fs = require('fs');
const path = require('path');

const LOG_PATH = path.join(__dirname, '..', 'lockguard.log');
const MAX_SIZE = 2 * 1024 * 1024; // 2 MB
const KEEP_SIZE = 1 * 1024 * 1024; // keep last 1 MB

function truncateIfNeeded() {
	try {
		const stat = fs.statSync(LOG_PATH);
		if (stat.size > MAX_SIZE) {
			const buf = fs.readFileSync(LOG_PATH);
			const trimmed = buf.slice(buf.length - KEEP_SIZE);
			const newlineIdx = trimmed.indexOf(10); // first newline
			fs.writeFileSync(LOG_PATH, newlineIdx > 0 ? trimmed.slice(newlineIdx + 1) : trimmed);
		}
	} catch (_) {}
}

function log(level, message) {
	const ts = new Date().toISOString();
	const line = `[${ts}] [${level}] ${message}\n`;
	try {
		fs.appendFileSync(LOG_PATH, line);
		truncateIfNeeded();
	} catch (_) {}
	if (level === 'ERROR' || level === 'CRITICAL') {
		console.error(line.trim());
	}
}

function info(msg) { log('INFO', msg); }
function warn(msg) { log('WARNING', msg); }
function error(msg) { log('ERROR', msg); }
function critical(msg) { log('CRITICAL', msg); }

function readTail(lines = 300) {
	try {
		const content = fs.readFileSync(LOG_PATH, 'utf8');
		const all = content.split('\n');
		return all.slice(-lines).join('\n');
	} catch (_) {
		return '';
	}
}

module.exports = { info, warn, error, critical, readTail };
