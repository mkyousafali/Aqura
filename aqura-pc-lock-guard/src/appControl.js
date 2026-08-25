// Aqura PC Lock Guard — Application Control
// Scans installed applications, manages allow/block lists, enforces app execution policies.

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const logger = require('./logger');
const localDb = require('./localDb');

function scanInstalledApps() {
	const apps = [];

	// Scan from Windows Registry (64-bit + 32-bit)
	const regPaths = [
		'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall',
		'HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall'
	];

	for (const regPath of regPaths) {
		try {
			const output = execSync(
				`powershell -NoProfile -Command "Get-ItemProperty '${regPath}\\*' | Where-Object { $_.DisplayName } | Select-Object DisplayName, InstallLocation, Publisher, DisplayVersion | ConvertTo-Json"`,
				{ encoding: 'utf8', timeout: 30000, windowsHide: true }
			);
			const parsed = JSON.parse(output || '[]');
			const list = Array.isArray(parsed) ? parsed : [parsed];
			for (const item of list) {
				if (!item.DisplayName) continue;
				apps.push({
					name: item.DisplayName,
					path: item.InstallLocation || '',
					publisher: item.Publisher || '',
					version: item.DisplayVersion || '',
					hash: null,
					status: 'unknown'
				});
			}
		} catch (_) {}
	}

	// Scan Store apps
	try {
		const output = execSync(
			'powershell -NoProfile -Command "Get-AppxPackage | Select-Object Name, Publisher, Version, InstallLocation | ConvertTo-Json"',
			{ encoding: 'utf8', timeout: 30000, windowsHide: true }
		);
		const parsed = JSON.parse(output || '[]');
		const list = Array.isArray(parsed) ? parsed : [parsed];
		for (const item of list) {
			if (!item.Name) continue;
			apps.push({
				name: item.Name,
				path: item.InstallLocation || '',
				publisher: item.Publisher || '',
				version: item.Version || '',
				hash: null,
				status: 'unknown'
			});
		}
	} catch (_) {}

	return apps;
}

function scanRunningProcesses() {
	try {
		const output = execSync(
			'powershell -NoProfile -Command "Get-Process | Where-Object { $_.Path } | Select-Object ProcessName, Path, Company | Sort-Object Path -Unique | ConvertTo-Json"',
			{ encoding: 'utf8', timeout: 15000, windowsHide: true }
		);
		const parsed = JSON.parse(output || '[]');
		return Array.isArray(parsed) ? parsed : [parsed];
	} catch (_) {
		return [];
	}
}

function hashFile(filePath) {
	try {
		if (!fs.existsSync(filePath)) return null;
		const content = fs.readFileSync(filePath);
		return crypto.createHash('sha256').update(content).digest('hex');
	} catch (_) {
		return null;
	}
}

function buildInventory() {
	const apps = scanInstalledApps();
	for (const app of apps) {
		localDb.upsertApp(app);
	}
	logger.info(`App inventory built: ${apps.length} applications`);
	return apps;
}

function isAppApproved(exePath) {
	const allApps = localDb.getAllApps();
	const normalized = exePath.toLowerCase();

	// Check if the exe path matches any approved app's install location
	for (const app of allApps) {
		if (app.status === 'approved' && app.path) {
			if (normalized.startsWith(app.path.toLowerCase())) {
				return true;
			}
		}
	}

	// Check known Windows system paths (always allowed)
	const systemPaths = [
		'c:\\windows\\',
		'c:\\windows\\system32\\',
		'c:\\windows\\syswow64\\'
	];
	for (const sp of systemPaths) {
		if (normalized.startsWith(sp)) return true;
	}

	return false;
}

function blockInstallers() {
	// Use Software Restriction Policies to block common installer extensions
	const extensions = ['.msi', '.msix', '.appx', '.appxbundle'];
	try {
		for (const ext of extensions) {
			execSync(
				`reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Safer\\CodeIdentifiers\\0\\Paths\\{lockguard-block-${ext.slice(1)}}" /v "ItemData" /t REG_SZ /d "*${ext}" /f`,
				{ encoding: 'utf8', timeout: 5000, windowsHide: true }
			);
		}
		// Block Windows Store
		execSync(
			'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\WindowsStore" /v "RemoveWindowsStore" /t REG_DWORD /d 1 /f',
			{ encoding: 'utf8', timeout: 5000, windowsHide: true }
		);
		logger.info('Installer blocking enabled');
		return true;
	} catch (err) {
		logger.error(`Installer blocking failed: ${err.message}`);
		return false;
	}
}

function unblockInstallers() {
	const extensions = ['.msi', '.msix', '.appx', '.appxbundle'];
	try {
		for (const ext of extensions) {
			execSync(
				`reg delete "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Safer\\CodeIdentifiers\\0\\Paths\\{lockguard-block-${ext.slice(1)}}" /f`,
				{ encoding: 'utf8', timeout: 5000, windowsHide: true }
			);
		}
		execSync(
			'reg delete "HKLM\\SOFTWARE\\Policies\\Microsoft\\WindowsStore" /v "RemoveWindowsStore" /f',
			{ encoding: 'utf8', timeout: 5000, windowsHide: true }
		);
		logger.info('Installer blocking disabled');
	} catch (_) {}
}

function detectNewExecutables() {
	const processes = scanRunningProcesses();
	const blocked = [];

	for (const proc of processes) {
		if (!proc.Path) continue;
		if (!isAppApproved(proc.Path)) {
			blocked.push({
				name: proc.ProcessName,
				path: proc.Path,
				company: proc.Company
			});
			localDb.recordEvent('WARNING', 'app_control', `Unapproved process: ${proc.ProcessName}`, { path: proc.Path });
		}
	}

	return blocked;
}

module.exports = {
	scanInstalledApps,
	scanRunningProcesses,
	buildInventory,
	isAppApproved,
	blockInstallers,
	unblockInstallers,
	detectNewExecutables,
	hashFile
};
