<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';

	interface LockGuardDevice {
		id: string;
		device_id: string;
		branch_id: string;
		counter_name: string;
		device_name: string;
		hostname: string;
		ip_address: string;
		protection_state: string;
		maintenance_mode: boolean;
		os_version: string;
		app_version: string;
		last_seen: string;
		branches?: { name_en: string; name_ar: string };
	}

	interface LockGuardEvent {
		id: number;
		device_id: string;
		severity: string;
		category: string;
		message: string;
		timestamp: string;
		details: any;
	}

	let supabase: any = null;
	let devices: LockGuardDevice[] = [];
	let events: LockGuardEvent[] = [];
	let selectedDevice: LockGuardDevice | null = null;
	let loading = true;
	let activeTab: 'overview' | 'devices' | 'events' | 'apps' | 'actions' = 'overview';

	// Stats
	let stats = {
		total: 0,
		online: 0,
		offline: 0,
		protected: 0,
		problems: 0,
		maintenance: 0,
		critical: 0
	};

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadDevices();
		await loadRecentEvents();
		loading = false;
	});

	async function loadDevices() {
		let { data, error } = await supabase
			.from('lockguard_devices')
			.select('*, branches(name_en, name_ar)')
			.order('last_seen', { ascending: false });

		// Fallback without join if relationship query fails
		if (error) {
			console.warn('Lock Guard devices query with join failed, retrying without:', error.message);
			const res = await supabase
				.from('lockguard_devices')
				.select('*')
				.order('last_seen', { ascending: false });
			data = res.data;
			error = res.error;
		}

		if (!error && data) {
			devices = data;
			computeStats();
		} else if (error) {
			console.error('Lock Guard devices load failed:', error.message);
		}
	}

	async function loadRecentEvents() {
		const { data, error } = await supabase
			.from('lockguard_events')
			.select('*')
			.order('created_at', { ascending: false })
			.limit(100);

		if (!error && data) {
			events = data;
		}
	}

	function computeStats() {
		const now = Date.now();
		const OFFLINE_THRESHOLD = 5 * 60 * 1000; // 5 minutes

		stats.total = devices.length;
		stats.online = 0;
		stats.offline = 0;
		stats.protected = 0;
		stats.problems = 0;
		stats.maintenance = 0;
		stats.critical = 0;

		for (const d of devices) {
			const lastSeen = new Date(d.last_seen).getTime();
			const isOnline = (now - lastSeen) < OFFLINE_THRESHOLD;

			if (isOnline) stats.online++;
			else stats.offline++;

			if (d.protection_state === 'protected') stats.protected++;
			else if (d.protection_state === 'problem') stats.problems++;
			if (d.maintenance_mode) stats.maintenance++;
		}

		stats.critical = events.filter(e => e.severity === 'CRITICAL').length;
	}

	function getStateColor(state: string): string {
		switch (state) {
			case 'protected': return '#10b981';
			case 'problem': return '#ef4444';
			case 'maintenance': return '#f59e0b';
			default: return '#64748b';
		}
	}

	function getStateBadge(state: string): string {
		switch (state) {
			case 'protected': return '🛡️ Protected';
			case 'problem': return '⚠️ Problem';
			case 'maintenance': return '🔧 Maintenance';
			default: return '○ Unknown';
		}
	}

	function isOnline(lastSeen: string): boolean {
		return (Date.now() - new Date(lastSeen).getTime()) < 5 * 60 * 1000;
	}

	function timeSince(dateStr: string): string {
		const seconds = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
		if (seconds < 60) return `${seconds}s ago`;
		if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
		if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
		return `${Math.floor(seconds / 86400)}d ago`;
	}

	function selectDevice(device: LockGuardDevice) {
		selectedDevice = device;
	}

	async function sendRemoteAction(action: string) {
		if (!selectedDevice) return;
		const { error } = await supabase
			.from('lockguard_remote_actions')
			.insert({
				device_id: selectedDevice.device_id,
				action,
				priority: 'normal',
				expires_at: new Date(Date.now() + 3600000).toISOString()
			});
		if (!error) {
			alert(`Action "${action}" sent to device`);
		}
	}

	async function refresh() {
		loading = true;
		await loadDevices();
		await loadRecentEvents();
		loading = false;
	}
</script>

<div class="lockguard-container">
	<!-- Header -->
	<div class="lg-header">
		<h2>🛡️ PC Lock Guard</h2>
		<button class="lg-btn lg-btn-refresh" on:click={refresh}>🔄 Refresh</button>
	</div>

	<!-- Tabs -->
	<div class="lg-tabs">
		<button class="lg-tab" class:active={activeTab === 'overview'} on:click={() => activeTab = 'overview'}>Overview</button>
		<button class="lg-tab" class:active={activeTab === 'devices'} on:click={() => activeTab = 'devices'}>Devices</button>
		<button class="lg-tab" class:active={activeTab === 'events'} on:click={() => activeTab = 'events'}>Events</button>
		<button class="lg-tab" class:active={activeTab === 'actions'} on:click={() => activeTab = 'actions'}>Remote Actions</button>
	</div>

	{#if loading}
		<div class="lg-loading">Loading...</div>
	{:else}

	<!-- Overview Tab -->
	{#if activeTab === 'overview'}
		<div class="lg-stats-grid">
			<div class="lg-stat-card">
				<div class="lg-stat-value">{stats.total}</div>
				<div class="lg-stat-label">Total PCs</div>
			</div>
			<div class="lg-stat-card lg-stat-success">
				<div class="lg-stat-value">{stats.online}</div>
				<div class="lg-stat-label">Online</div>
			</div>
			<div class="lg-stat-card lg-stat-muted">
				<div class="lg-stat-value">{stats.offline}</div>
				<div class="lg-stat-label">Offline</div>
			</div>
			<div class="lg-stat-card lg-stat-success">
				<div class="lg-stat-value">{stats.protected}</div>
				<div class="lg-stat-label">Protected</div>
			</div>
			<div class="lg-stat-card lg-stat-danger">
				<div class="lg-stat-value">{stats.problems}</div>
				<div class="lg-stat-label">Problems</div>
			</div>
			<div class="lg-stat-card lg-stat-warning">
				<div class="lg-stat-value">{stats.maintenance}</div>
				<div class="lg-stat-label">Maintenance</div>
			</div>
		</div>

		<!-- Recent Critical Events -->
		{#if events.filter(e => e.severity === 'CRITICAL' || e.severity === 'HIGH').length > 0}
			<div class="lg-section">
				<h3>⚠️ Recent Alerts</h3>
				<div class="lg-event-list">
					{#each events.filter(e => e.severity === 'CRITICAL' || e.severity === 'HIGH').slice(0, 10) as event}
						<div class="lg-event-item lg-event-{event.severity.toLowerCase()}">
							<span class="lg-event-badge {event.severity.toLowerCase()}">{event.severity}</span>
							<span class="lg-event-time">{timeSince(event.timestamp)}</span>
							<span class="lg-event-msg">{event.message}</span>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	{/if}

	<!-- Devices Tab -->
	{#if activeTab === 'devices'}
		<div class="lg-devices-layout">
			<div class="lg-device-list">
				<table class="lg-table">
					<thead>
						<tr>
							<th>Branch</th>
							<th>Counter</th>
							<th>Device Name</th>
							<th>Protection</th>
							<th>Connection</th>
							<th>Last Seen</th>
						</tr>
					</thead>
					<tbody>
						{#each devices as device}
							<tr class="lg-device-row" class:selected={selectedDevice?.id === device.id} on:click={() => selectDevice(device)}>
								<td>{device.branches?.name_en || '—'}</td>
								<td>{device.counter_name || '—'}</td>
								<td>{device.device_name || '—'}</td>
								<td><span style="color: {getStateColor(device.protection_state)}">{getStateBadge(device.protection_state)}</span></td>
								<td>
									{#if isOnline(device.last_seen)}
										<span style="color: #10b981">● Online</span>
									{:else}
										<span style="color: #64748b">○ Offline</span>
									{/if}
								</td>
								<td>{timeSince(device.last_seen)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if selectedDevice}
				<div class="lg-device-detail">
					<h3>{selectedDevice.branches?.name_en || '—'} • {selectedDevice.counter_name || '—'}</h3>
					<div class="lg-detail-grid">
						<div class="lg-detail-item"><label>Device ID:</label><span>{selectedDevice.device_id}</span></div>
						<div class="lg-detail-item"><label>Hostname:</label><span>{selectedDevice.hostname || '—'}</span></div>
						<div class="lg-detail-item"><label>IP Address:</label><span>{selectedDevice.ip_address || '—'}</span></div>
						<div class="lg-detail-item"><label>OS:</label><span>{selectedDevice.os_version || '—'}</span></div>
						<div class="lg-detail-item"><label>App Version:</label><span>{selectedDevice.app_version || '—'}</span></div>
						<div class="lg-detail-item"><label>Protection:</label><span style="color: {getStateColor(selectedDevice.protection_state)}">{getStateBadge(selectedDevice.protection_state)}</span></div>
						<div class="lg-detail-item"><label>Maintenance:</label><span>{selectedDevice.maintenance_mode ? '🔧 Active' : 'None'}</span></div>
					</div>

					<div class="lg-detail-actions">
						<h4>Remote Actions</h4>
						<div class="lg-action-buttons">
							<button class="lg-btn lg-btn-sm" on:click={() => sendRemoteAction('check_protection')}>Check Protection</button>
							<button class="lg-btn lg-btn-sm" on:click={() => sendRemoteAction('repair_protection')}>Repair Protection</button>
							<button class="lg-btn lg-btn-sm" on:click={() => sendRemoteAction('restart_main_service')}>Restart Service</button>
							<button class="lg-btn lg-btn-sm" on:click={() => sendRemoteAction('sync_policy')}>Sync Policy</button>
							<button class="lg-btn lg-btn-sm" on:click={() => sendRemoteAction('refresh_app_inventory')}>Refresh Apps</button>
							<button class="lg-btn lg-btn-sm" on:click={() => sendRemoteAction('refresh_printer_inventory')}>Refresh Printers</button>
						</div>
					</div>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Events Tab -->
	{#if activeTab === 'events'}
		<div class="lg-event-list">
			{#each events as event}
				<div class="lg-event-item">
					<span class="lg-event-badge {event.severity.toLowerCase()}">{event.severity}</span>
					<span class="lg-event-cat">{event.category}</span>
					<span class="lg-event-time">{new Date(event.timestamp).toLocaleString()}</span>
					<span class="lg-event-msg">{event.message}</span>
				</div>
			{:else}
				<div class="lg-empty">No events recorded</div>
			{/each}
		</div>
	{/if}

	<!-- Remote Actions Tab -->
	{#if activeTab === 'actions'}
		<div class="lg-section">
			<p class="lg-info-text">Select a device from the Devices tab to send remote actions. Actions are delivered on the next heartbeat cycle (60s).</p>
		</div>
	{/if}

	{/if}
</div>

<style>
	.lockguard-container {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #0f172a;
		color: #f1f5f9;
		padding: 20px;
		overflow: hidden;
	}

	.lg-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 16px;
	}

	.lg-header h2 { font-size: 18px; margin: 0; }

	.lg-tabs {
		display: flex;
		gap: 4px;
		margin-bottom: 16px;
		border-bottom: 1px solid #334155;
		padding-bottom: 8px;
	}

	.lg-tab {
		padding: 8px 16px;
		background: transparent;
		border: none;
		color: #94a3b8;
		font-size: 13px;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.lg-tab:hover { background: #1e293b; color: #f1f5f9; }
	.lg-tab.active { background: #3b82f6; color: white; }

	.lg-loading { text-align: center; padding: 40px; color: #64748b; }
	.lg-empty { text-align: center; padding: 40px; color: #64748b; }

	.lg-stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
		gap: 12px;
		margin-bottom: 24px;
	}

	.lg-stat-card {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 8px;
		padding: 16px;
		text-align: center;
	}

	.lg-stat-value { font-size: 28px; font-weight: 700; }
	.lg-stat-label { font-size: 12px; color: #94a3b8; margin-top: 4px; }
	.lg-stat-success .lg-stat-value { color: #10b981; }
	.lg-stat-danger .lg-stat-value { color: #ef4444; }
	.lg-stat-warning .lg-stat-value { color: #f59e0b; }
	.lg-stat-muted .lg-stat-value { color: #64748b; }

	.lg-section { margin-bottom: 20px; }
	.lg-section h3 { font-size: 14px; margin-bottom: 12px; }

	.lg-event-list {
		display: flex;
		flex-direction: column;
		gap: 4px;
		overflow-y: auto;
		max-height: 400px;
	}

	.lg-event-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 8px 12px;
		background: #1e293b;
		border-radius: 6px;
		font-size: 12px;
	}

	.lg-event-badge {
		padding: 2px 6px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		flex-shrink: 0;
	}

	.lg-event-badge.info { background: rgba(59, 130, 246, 0.2); color: #3b82f6; }
	.lg-event-badge.warning { background: rgba(245, 158, 11, 0.2); color: #f59e0b; }
	.lg-event-badge.high { background: rgba(239, 68, 68, 0.2); color: #ef4444; }
	.lg-event-badge.critical { background: rgba(220, 38, 38, 0.3); color: #dc2626; }

	.lg-event-time { color: #64748b; flex-shrink: 0; width: 80px; }
	.lg-event-cat { color: #94a3b8; flex-shrink: 0; width: 80px; }
	.lg-event-msg { color: #cbd5e1; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

	.lg-devices-layout {
		display: flex;
		gap: 16px;
		flex: 1;
		overflow: hidden;
	}

	.lg-device-list {
		flex: 1;
		overflow-y: auto;
	}

	.lg-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
	}

	.lg-table th {
		text-align: left;
		padding: 8px 12px;
		background: #1e293b;
		color: #94a3b8;
		font-weight: 500;
		position: sticky;
		top: 0;
	}

	.lg-table td {
		padding: 8px 12px;
		border-bottom: 1px solid #1e293b;
	}

	.lg-device-row { cursor: pointer; transition: background 0.15s; }
	.lg-device-row:hover { background: #1e293b; }
	.lg-device-row.selected { background: #1e3a5f; }

	.lg-device-detail {
		width: 320px;
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 8px;
		padding: 16px;
		overflow-y: auto;
	}

	.lg-device-detail h3 { font-size: 14px; margin-bottom: 16px; }

	.lg-detail-grid {
		display: grid;
		gap: 8px;
		margin-bottom: 16px;
	}

	.lg-detail-item {
		display: flex;
		justify-content: space-between;
		font-size: 12px;
		padding: 4px 0;
		border-bottom: 1px solid #334155;
	}

	.lg-detail-item label { color: #94a3b8; }

	.lg-detail-actions { margin-top: 16px; }
	.lg-detail-actions h4 { font-size: 12px; color: #94a3b8; margin-bottom: 8px; }

	.lg-action-buttons {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
	}

	.lg-btn {
		padding: 8px 14px;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		cursor: pointer;
		background: #334155;
		color: #f1f5f9;
		transition: background 0.2s;
	}

	.lg-btn:hover { background: #475569; }
	.lg-btn-refresh { background: #3b82f6; color: white; }
	.lg-btn-refresh:hover { background: #2563eb; }
	.lg-btn-sm { padding: 5px 10px; font-size: 11px; }

	.lg-info-text { color: #94a3b8; font-size: 13px; }
</style>
