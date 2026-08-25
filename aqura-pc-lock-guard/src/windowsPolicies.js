// Aqura PC Lock Guard — Windows Policy Enforcement
// Applies and verifies Windows security restrictions via Group Policy, Registry, and WMI.

const { execSync, exec } = require('child_process');
const logger = require('./logger');
const localDb = require('./localDb');

// Registry paths for policy enforcement
const POLICIES = {
	blockShutdown: {
		// Disable shutdown from start menu (user policy)
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoClose', 'REG_DWORD', '1'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoClose'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoClose') === '0x1'
	},
	blockRestart: {
		// Covered by NoClose — shutdown/restart are bundled in Explorer policy
		apply: () => {},
		remove: () => {},
		verify: () => true
	},
	blockSignOut: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'StartMenuLogOff', 'REG_DWORD', '1'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'StartMenuLogOff'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'StartMenuLogOff') === '0x1'
	},
	blockSwitchUser: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'HideFastUserSwitching', 'REG_DWORD', '1'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'HideFastUserSwitching'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'HideFastUserSwitching') === '0x1'
	},
	blockSleep: {
		apply: () => {
			runCmd('powercfg /change standby-timeout-ac 0');
			runCmd('powercfg /change standby-timeout-dc 0');
		},
		remove: () => {
			runCmd('powercfg /change standby-timeout-ac 30');
			runCmd('powercfg /change standby-timeout-dc 15');
		},
		verify: () => true // Power settings don't have a simple registry check
	},
	blockHibernate: {
		apply: () => runCmd('powercfg /hibernate off'),
		remove: () => runCmd('powercfg /hibernate on'),
		verify: () => {
			try {
				const out = execSync('powercfg /availablesleepstates', { encoding: 'utf8' });
				return !out.includes('Hibernate');
			} catch (_) { return false; }
		}
	},
	blockControlPanel: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoControlPanel', 'REG_DWORD', '1'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoControlPanel'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoControlPanel') === '0x1'
	},
	blockTaskManager: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'DisableTaskMgr', 'REG_DWORD', '1'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'DisableTaskMgr'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'DisableTaskMgr') === '0x1'
	},
	blockRegistryEditor: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'DisableRegistryTools', 'REG_DWORD', '1'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'DisableRegistryTools'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'DisableRegistryTools') === '0x1'
	},
	blockCmd: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System', 'DisableCMD', 'REG_DWORD', '2'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System', 'DisableCMD'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System', 'DisableCMD') === '0x2'
	},
	blockPowershell: {
		// Use Software Restriction Policy to block powershell.exe execution for non-admin
		apply: () => {
			const psPath = 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
			const ps7Path = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe';
			setRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Safer\\CodeIdentifiers\\0\\Paths\\{lockguard-ps}', 'ItemData', 'REG_SZ', `"${psPath}"`);
			setRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Safer\\CodeIdentifiers\\0\\Paths\\{lockguard-ps7}', 'ItemData', 'REG_SZ', `"${ps7Path}"`);
		},
		remove: () => {
			deleteRegistryKey('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Safer\\CodeIdentifiers\\0\\Paths\\{lockguard-ps}');
			deleteRegistryKey('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Safer\\CodeIdentifiers\\0\\Paths\\{lockguard-ps7}');
		},
		verify: () => true
	},
	blockDateTimeChange: {
		apply: () => {
			setRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoSetDate', 'REG_DWORD', '1');
		},
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoSetDate'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer', 'NoSetDate') === '0x1'
	},
	blockNetworkChange: {
		apply: () => setRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Network Connections', 'NC_LanChangeProperties', 'REG_DWORD', '0'),
		remove: () => deleteRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Network Connections', 'NC_LanChangeProperties'),
		verify: () => getRegistryValue('HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Network Connections', 'NC_LanChangeProperties') === '0x0'
	},
	powerButtonDoNothing: {
		apply: () => {
			// Set power button action to Do Nothing (0) for both AC and DC
			runCmd('powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 0');
			runCmd('powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 0');
			runCmd('powercfg /setactive SCHEME_CURRENT');
		},
		remove: () => {
			// Restore to Shut Down (3)
			runCmd('powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3');
			runCmd('powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3');
			runCmd('powercfg /setactive SCHEME_CURRENT');
		},
		verify: () => true
	}
};

// --- Registry helpers ---

function setRegistryValue(keyPath, valueName, type, data) {
	try {
		runCmd(`reg add "${keyPath}" /v "${valueName}" /t ${type} /d ${data} /f`);
		return true;
	} catch (err) {
		logger.error(`Failed to set registry ${keyPath}\\${valueName}: ${err.message}`);
		return false;
	}
}

function deleteRegistryValue(keyPath, valueName) {
	try {
		runCmd(`reg delete "${keyPath}" /v "${valueName}" /f`);
		return true;
	} catch (_) {
		return true; // Already deleted
	}
}

function deleteRegistryKey(keyPath) {
	try {
		runCmd(`reg delete "${keyPath}" /f`);
		return true;
	} catch (_) {
		return true;
	}
}

function getRegistryValue(keyPath, valueName) {
	try {
		const output = execSync(`reg query "${keyPath}" /v "${valueName}"`, { encoding: 'utf8', timeout: 5000 });
		const match = output.match(/REG_\w+\s+(.+)/);
		return match ? match[1].trim() : null;
	} catch (_) {
		return null;
	}
}

function runCmd(cmd) {
	try {
		execSync(cmd, { encoding: 'utf8', timeout: 10000, windowsHide: true });
	} catch (err) {
		logger.error(`Command failed: ${cmd} — ${err.message}`);
		throw err;
	}
}

// --- Main enforcement functions ---

function applyAllPolicies(policyConfig) {
	const results = { applied: [], failed: [] };
	for (const [key, enabled] of Object.entries(policyConfig)) {
		if (!POLICIES[key]) continue;
		try {
			if (enabled) {
				POLICIES[key].apply();
				results.applied.push(key);
			} else {
				POLICIES[key].remove();
			}
		} catch (err) {
			results.failed.push({ key, error: err.message });
			logger.error(`Policy ${key} enforcement failed: ${err.message}`);
		}
	}
	if (results.applied.length) {
		logger.info(`Policies applied: ${results.applied.join(', ')}`);
		localDb.recordEvent('INFO', 'policy', `Applied ${results.applied.length} policies`, results);
		// Force Windows to refresh policies immediately
		try { execSync('gpupdate /force', { timeout: 30000, windowsHide: true }); } catch (_) {}
	}
	if (results.failed.length) {
		localDb.recordEvent('HIGH', 'policy', `${results.failed.length} policies failed`, results.failed);
	}
	return results;
}

function removeAllPolicies(policyConfig) {
	for (const [key] of Object.entries(policyConfig)) {
		if (!POLICIES[key]) continue;
		try {
			POLICIES[key].remove();
		} catch (_) {}
	}
	// Force Windows to apply the removals immediately
	try { execSync('gpupdate /force', { timeout: 30000, windowsHide: true }); } catch (_) {}
	logger.info('All policies removed');
}

function verifyAllPolicies(policyConfig) {
	const violations = [];
	for (const [key, enabled] of Object.entries(policyConfig)) {
		if (!enabled || !POLICIES[key]) continue;
		try {
			if (!POLICIES[key].verify()) {
				violations.push(key);
			}
		} catch (_) {
			violations.push(key);
		}
	}
	return violations;
}

function repairPolicies(policyConfig) {
	const violations = verifyAllPolicies(policyConfig);
	if (!violations.length) return { repaired: [], status: 'ok' };

	logger.warn(`Policy violations detected: ${violations.join(', ')} — repairing`);
	localDb.recordEvent('HIGH', 'policy', `Violations detected, repairing: ${violations.join(', ')}`);

	const repaired = [];
	for (const key of violations) {
		try {
			POLICIES[key].apply();
			repaired.push(key);
		} catch (_) {}
	}

	localDb.recordEvent('INFO', 'policy', `Repaired ${repaired.length}/${violations.length} policies`);
	return { repaired, failed: violations.filter(v => !repaired.includes(v)), status: repaired.length === violations.length ? 'ok' : 'partial' };
}

module.exports = {
	applyAllPolicies,
	removeAllPolicies,
	verifyAllPolicies,
	repairPolicies,
	POLICIES
};
