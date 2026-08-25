// Aqura PC Lock Guard — Watchdog
// Monitors the Main Service and automatically restarts it if stopped/crashed.
// Designed to run as a separate Windows Service.

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const logger = require('./logger');
const localDb = require('./localDb');

const SERVICE_NAME = 'AquraPCLockGuard';
const CHECK_INTERVAL_MS = 30000; // 30 seconds
const MAX_RESTART_ATTEMPTS = 5;
const RESTART_BACKOFF_MS = 10000;

let watchdogTimer = null;
let restartAttempts = 0;
let lastRestartTime = 0;

function isMainServiceRunning() {
	try {
		const output = execSync(`sc query "${SERVICE_NAME}"`, { encoding: 'utf8', timeout: 5000, windowsHide: true });
		return output.includes('RUNNING');
	} catch (_) {
		return false;
	}
}

function startMainService() {
	try {
		execSync(`sc start "${SERVICE_NAME}"`, { encoding: 'utf8', timeout: 15000, windowsHide: true });
		logger.info('Watchdog: Main service started');
		return true;
	} catch (err) {
		logger.error(`Watchdog: Failed to start main service: ${err.message}`);
		return false;
	}
}

function checkAndRecover() {
	if (isMainServiceRunning()) {
		restartAttempts = 0;
		return;
	}

	// Service is not running
	const now = Date.now();
	const timeSinceLastRestart = now - lastRestartTime;

	// Backoff: don't restart too frequently
	if (timeSinceLastRestart < RESTART_BACKOFF_MS * restartAttempts) {
		return;
	}

	if (restartAttempts >= MAX_RESTART_ATTEMPTS) {
		logger.critical('Watchdog: Max restart attempts reached — service may require manual intervention');
		localDb.recordEvent('CRITICAL', 'watchdog', 'Max restart attempts reached', { attempts: restartAttempts });
		// Reset counter after a cooling period (10 minutes)
		if (timeSinceLastRestart > 600000) {
			restartAttempts = 0;
		}
		return;
	}

	logger.warn(`Watchdog: Main service not running (attempt ${restartAttempts + 1}/${MAX_RESTART_ATTEMPTS})`);
	localDb.recordEvent('HIGH', 'watchdog', `Service down, restarting (attempt ${restartAttempts + 1})`);

	if (startMainService()) {
		restartAttempts++;
		lastRestartTime = now;
	} else {
		restartAttempts++;
		lastRestartTime = now;
	}
}

function verifyServiceIntegrity() {
	// Check if the service executable hasn't been tampered with
	const exePath = getServiceExePath();
	if (!exePath) return true;

	try {
		if (!fs.existsSync(exePath)) {
			logger.critical('Watchdog: Service executable missing');
			localDb.recordEvent('CRITICAL', 'watchdog', 'Service executable missing', { path: exePath });
			return false;
		}
		return true;
	} catch (_) {
		return true;
	}
}

function getServiceExePath() {
	try {
		const output = execSync(`sc qc "${SERVICE_NAME}"`, { encoding: 'utf8', timeout: 5000, windowsHide: true });
		const match = output.match(/BINARY_PATH_NAME\s*:\s*(.+)/);
		return match ? match[1].trim().replace(/"/g, '') : null;
	} catch (_) {
		return null;
	}
}

function startWatchdog() {
	if (watchdogTimer) return;
	logger.info('Watchdog started');

	watchdogTimer = setInterval(() => {
		verifyServiceIntegrity();
		checkAndRecover();
	}, CHECK_INTERVAL_MS);

	// Initial check
	checkAndRecover();
}

function stopWatchdog() {
	if (watchdogTimer) {
		clearInterval(watchdogTimer);
		watchdogTimer = null;
		logger.info('Watchdog stopped');
	}
}

module.exports = { startWatchdog, stopWatchdog, isMainServiceRunning, checkAndRecover };
