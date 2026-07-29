<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	interface DashboardData {
		sent_today: number;
		received_today: number;
		failed_today: number;
		pending_queue: number;
		scheduled: number;
		unread: number;
		active_campaigns: number;
		accounts: any[];
		recent_activity: any[];
	}

	let supabase: any = null;
	let loading = true;
	let data: DashboardData = {
		sent_today: 0, received_today: 0, failed_today: 0,
		pending_queue: 0, scheduled: 0, unread: 0, active_campaigns: 0,
		accounts: [], recent_activity: []
	};

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadDashboard();
	});

	async function loadDashboard() {
		loading = true;
		try {
			const { data: result, error } = await supabase.rpc('get_email_dashboard');
			if (error) throw error;
			if (result) data = result;
		} catch (err) {
			console.error('Failed to load email dashboard:', err);
		} finally {
			loading = false;
		}
	}

	function formatTime(ts: string): string {
		if (!ts) return '—';
		return new Date(ts).toLocaleString();
	}
</script>

<div class="email-dashboard">
	{#if loading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading dashboard...</p>
		</div>
	{:else}
		<!-- Stats Cards -->
		<div class="stats-grid">
			<div class="stat-card sent">
				<div class="stat-icon">📤</div>
				<div class="stat-info">
					<span class="stat-value">{data.sent_today}</span>
					<span class="stat-label">Sent Today</span>
				</div>
			</div>
			<div class="stat-card received">
				<div class="stat-icon">📥</div>
				<div class="stat-info">
					<span class="stat-value">{data.received_today}</span>
					<span class="stat-label">Received Today</span>
				</div>
			</div>
			<div class="stat-card failed">
				<div class="stat-icon">❌</div>
				<div class="stat-info">
					<span class="stat-value">{data.failed_today}</span>
					<span class="stat-label">Failed Today</span>
				</div>
			</div>
			<div class="stat-card queue">
				<div class="stat-icon">📋</div>
				<div class="stat-info">
					<span class="stat-value">{data.pending_queue}</span>
					<span class="stat-label">Pending Queue</span>
				</div>
			</div>
			<div class="stat-card scheduled">
				<div class="stat-icon">🕐</div>
				<div class="stat-info">
					<span class="stat-value">{data.scheduled}</span>
					<span class="stat-label">Scheduled</span>
				</div>
			</div>
			<div class="stat-card unread">
				<div class="stat-icon">📬</div>
				<div class="stat-info">
					<span class="stat-value">{data.unread}</span>
					<span class="stat-label">Unread</span>
				</div>
			</div>
			<div class="stat-card campaigns">
				<div class="stat-icon">📣</div>
				<div class="stat-info">
					<span class="stat-value">{data.active_campaigns}</span>
					<span class="stat-label">Active Campaigns</span>
				</div>
			</div>
		</div>

		<!-- Accounts Health -->
		<div class="section">
			<h3>📱 Account Health</h3>
			<div class="accounts-grid">
				{#each data.accounts as account}
					<div class="account-card">
						<div class="account-header">
							<strong>{account.name}</strong>
							<span class="account-email">{account.email}</span>
						</div>
						<div class="account-status">
							<span class="status-badge" class:ok={account.smtp_status === 'success'} class:error={account.smtp_status === 'failed'}>
								SMTP: {account.smtp_status || 'Not tested'}
							</span>
							<span class="status-badge" class:ok={account.imap_status === 'success'} class:error={account.imap_status === 'failed'}>
								IMAP: {account.imap_status || 'Not tested'}
							</span>
						</div>
						<div class="account-meta">
							{#if account.last_sync}
								<span>Last sync: {formatTime(account.last_sync)}</span>
							{/if}
						</div>
					</div>
				{/each}
				{#if data.accounts.length === 0}
					<div class="empty-state">No email accounts configured. Add one in Email Accounts.</div>
				{/if}
			</div>
		</div>

		<!-- Recent Activity -->
		<div class="section">
			<h3>📋 Recent Activity</h3>
			<div class="activity-list">
				{#each data.recent_activity as activity}
					<div class="activity-item">
						<span class="activity-type">{activity.event_type}</span>
						<span class="activity-message">{activity.safe_message}</span>
						<span class="activity-time">{formatTime(activity.created_at)}</span>
					</div>
				{/each}
				{#if data.recent_activity.length === 0}
					<div class="empty-state">No recent activity</div>
				{/if}
			</div>
		</div>

		<!-- Refresh Button -->
		<div class="actions-bar">
			<button class="glass-btn primary" on:click={loadDashboard}>
				🔄 Refresh
			</button>
		</div>
	{/if}
</div>

<style>
	.email-dashboard {
		padding: 20px;
		height: 100%;
		overflow-y: auto;
		background: #f8fafc;
	}
	.loading-container {
		display: flex; flex-direction: column; align-items: center; justify-content: center;
		height: 300px; gap: 12px; color: #64748b;
	}
	.loading-spinner {
		width: 36px; height: 36px; border: 3px solid #e2e8f0; border-top-color: #f08300;
		border-radius: 50%; animation: spin 0.8s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	.stats-grid {
		display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		gap: 14px; margin-bottom: 24px;
	}
	.stat-card {
		background: white; border-radius: 12px; padding: 16px;
		display: flex; align-items: center; gap: 12px;
		box-shadow: 0 1px 3px rgba(0,0,0,0.06); border: 1px solid #e2e8f0;
	}
	.stat-icon { font-size: 24px; }
	.stat-info { display: flex; flex-direction: column; }
	.stat-value { font-size: 22px; font-weight: 700; color: #1e293b; }
	.stat-label { font-size: 12px; color: #64748b; }

	.section { margin-bottom: 24px; }
	.section h3 { font-size: 15px; font-weight: 600; color: #334155; margin-bottom: 12px; }

	.accounts-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }
	.account-card {
		background: white; border-radius: 10px; padding: 14px;
		border: 1px solid #e2e8f0; box-shadow: 0 1px 2px rgba(0,0,0,0.04);
	}
	.account-header { display: flex; flex-direction: column; gap: 2px; margin-bottom: 8px; }
	.account-email { font-size: 12px; color: #64748b; }
	.account-status { display: flex; gap: 8px; margin-bottom: 6px; }
	.status-badge {
		font-size: 11px; padding: 2px 8px; border-radius: 4px;
		background: #f1f5f9; color: #64748b;
	}
	.status-badge.ok { background: #dcfce7; color: #166534; }
	.status-badge.error { background: #fee2e2; color: #991b1b; }
	.account-meta { font-size: 11px; color: #94a3b8; }

	.activity-list { display: flex; flex-direction: column; gap: 8px; }
	.activity-item {
		display: flex; align-items: center; gap: 12px; padding: 10px 14px;
		background: white; border-radius: 8px; border: 1px solid #e2e8f0; font-size: 13px;
	}
	.activity-type { font-weight: 600; color: #475569; min-width: 120px; }
	.activity-message { flex: 1; color: #64748b; }
	.activity-time { font-size: 11px; color: #94a3b8; white-space: nowrap; }

	.empty-state { padding: 20px; text-align: center; color: #94a3b8; font-size: 13px; }

	.actions-bar { display: flex; justify-content: flex-end; padding-top: 12px; }
	.glass-btn {
		padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500;
		border: 1px solid rgba(255,255,255,0.3); cursor: pointer;
		background: rgba(255,255,255,0.7); backdrop-filter: blur(8px);
		box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s;
	}
	.glass-btn:hover { background: rgba(255,255,255,0.9); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.2); }
</style>
