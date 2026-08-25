// Aqura PC Lock Guard — Printer Protection
// Monitors and protects printer configurations from unauthorized changes.

const { execSync } = require('child_process');
const logger = require('./logger');
const localDb = require('./localDb');

let printerBaseline = [];

function scanPrinters() {
	try {
		const output = execSync(
			'powershell -NoProfile -Command "Get-Printer | Select-Object Name, PortName, DriverName, Shared, PrinterStatus | ConvertTo-Json"',
			{ encoding: 'utf8', timeout: 15000, windowsHide: true }
		);
		const printers = JSON.parse(output || '[]');
		const list = Array.isArray(printers) ? printers : [printers];
		return list.map(p => ({
			name: p.Name,
			port: p.PortName,
			driver: p.DriverName,
			shared: p.Shared,
			status: p.PrinterStatus
		}));
	} catch (err) {
		logger.error(`Printer scan failed: ${err.message}`);
		return [];
	}
}

function setBaseline(printers) {
	printerBaseline = printers.map(p => ({ ...p }));
	for (const printer of printers) {
		localDb.upsertPrinter(printer);
	}
	logger.info(`Printer baseline set: ${printers.length} printers`);
}

function detectChanges() {
	const current = scanPrinters();
	const changes = [];

	// Check for removed printers
	for (const baseline of printerBaseline) {
		const found = current.find(c => c.name === baseline.name);
		if (!found) {
			changes.push({ type: 'removed', printer: baseline.name, details: baseline });
		}
	}

	// Check for added printers
	for (const curr of current) {
		const found = printerBaseline.find(b => b.name === curr.name);
		if (!found) {
			changes.push({ type: 'added', printer: curr.name, details: curr });
		}
	}

	// Check for modified printers
	for (const curr of current) {
		const baseline = printerBaseline.find(b => b.name === curr.name);
		if (baseline) {
			if (baseline.port !== curr.port || baseline.driver !== curr.driver) {
				changes.push({
					type: 'modified',
					printer: curr.name,
					details: { before: baseline, after: curr }
				});
			}
		}
	}

	return changes;
}

function restrictPrinterManagement() {
	try {
		// Remove Print Management snap-in access for non-admins
		execSync(
			'reg add "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Printers" /v "DisableWebPnPDownload" /t REG_DWORD /d 1 /f',
			{ encoding: 'utf8', timeout: 5000, windowsHide: true }
		);
		// Prevent adding printers
		execSync(
			'reg add "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" /v "NoAddPrinter" /t REG_DWORD /d 1 /f',
			{ encoding: 'utf8', timeout: 5000, windowsHide: true }
		);
		// Prevent deleting printers
		execSync(
			'reg add "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" /v "NoDeletePrinter" /t REG_DWORD /d 1 /f',
			{ encoding: 'utf8', timeout: 5000, windowsHide: true }
		);
		logger.info('Printer management restrictions applied');
		return true;
	} catch (err) {
		logger.error(`Printer restriction failed: ${err.message}`);
		return false;
	}
}

function removePrinterRestrictions() {
	try {
		execSync('reg delete "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Printers" /v "DisableWebPnPDownload" /f', { encoding: 'utf8', timeout: 5000, windowsHide: true });
		execSync('reg delete "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" /v "NoAddPrinter" /f', { encoding: 'utf8', timeout: 5000, windowsHide: true });
		execSync('reg delete "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" /v "NoDeletePrinter" /f', { encoding: 'utf8', timeout: 5000, windowsHide: true });
		logger.info('Printer management restrictions removed');
	} catch (_) {}
}

function verifyPrinterProtection() {
	const changes = detectChanges();
	if (changes.length > 0) {
		logger.warn(`Printer changes detected: ${JSON.stringify(changes)}`);
		for (const change of changes) {
			localDb.recordEvent('HIGH', 'printer', `Printer ${change.type}: ${change.printer}`, change.details);
		}
		return { protected: false, changes };
	}
	return { protected: true, changes: [] };
}

function restorePrinterBaseline() {
	// Re-apply restrictions
	restrictPrinterManagement();
	// Log restoration attempt
	const verification = verifyPrinterProtection();
	if (!verification.protected) {
		logger.warn('Printer baseline could not be fully restored — manual intervention may be needed');
		localDb.recordEvent('CRITICAL', 'printer', 'Printer baseline restoration incomplete', verification.changes);
	}
	return verification;
}

module.exports = {
	scanPrinters,
	setBaseline,
	detectChanges,
	restrictPrinterManagement,
	removePrinterRestrictions,
	verifyPrinterProtection,
	restorePrinterBaseline
};
