<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let logsData: any = { total: 0, logs: [] };
	let page = 1;
	let eventTypeFilter = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadLogs();
	});

	async function loadLogs() {
		loading = true;
		const { data } = await supabase.rpc('get_email_logs_report', {
			p_event_type: eventTypeFilter || null,
			p_page: page, p_page_size: 50
		});
		if (data) logsData = data;
		loading = false;
	}

	function formatTime(ts: string): string { return ts ? new Date(ts).toLocaleString() : ''; }
	function onFilterChange() { page = 1; loadLogs(); }
</script>

<div class="email-logs-view">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="header"><h3>📄 Email Logs</h3><button class="glass-btn primary" on:click={loadLogs}>🔄</button></div>
		<div class="filter-row">
			<select bind:value={eventTypeFilter} on:change={onFilterChange}>
				<option value="">All Events</option>
				<option value="account_created">Account Created</option>
				<option value="account_updated">Account Updated</option>
				<option value="message_queued">Message Queued</option>
				<option value="message_sent">Message Sent</option>
				<option value="message_failed">Message Failed</option>
				<option value="setting_changed">Setting Changed</option>
			</select>
			<span class="total">Total: {logsData.total}</span>
		</div>
		<table>
			<thead><tr><th>Time</th><th>Event</th><th>Account</th><th>Message</th></tr></thead>
			<tbody>
				{#each logsData.logs as log}
					<tr>
						<td class="time">{formatTime(log.created_at)}</td>
						<td><span class="event-badge">{log.event_type}</span></td>
						<td>{log.account_name || '—'}</td>
						<td>{log.safe_message || '—'}</td>
					</tr>
				{/each}
				{#if logsData.logs.length === 0}<tr><td colspan="4" class="empty">No logs found</td></tr>{/if}
			</tbody>
		</table>
		{#if logsData.total > 50}
			<div class="pagination">
				<button on:click={() => { page--; loadLogs(); }} disabled={page <= 1}>← Prev</button>
				<span>Page {page}</span>
				<button on:click={() => { page++; loadLogs(); }} disabled={page * 50 >= logsData.total}>Next →</button>
			</div>
		{/if}
	{/if}
</div>

<style>
	.email-logs-view { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
	.header h3 { font-size: 16px; font-weight: 600; }
	.filter-row { display: flex; gap: 12px; align-items: center; margin-bottom: 12px; }
	.filter-row select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.total { font-size: 12px; color: #64748b; }
	table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
	th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	td { padding: 8px 12px; font-size: 12px; border-bottom: 1px solid #f1f5f9; }
	.time { white-space: nowrap; color: #64748b; font-size: 11px; }
	.event-badge { font-size: 11px; background: #e0e7ff; color: #3730a3; padding: 2px 6px; border-radius: 3px; }
	.empty { text-align: center; color: #94a3b8; padding: 40px !important; }
	.pagination { display: flex; justify-content: center; gap: 10px; align-items: center; padding: 12px; font-size: 12px; }
	.pagination button { padding: 4px 12px; border: 1px solid #e2e8f0; border-radius: 4px; background: white; cursor: pointer; }
	.pagination button:disabled { opacity: 0.4; }
	.glass-btn { padding: 6px 14px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); color: #334155; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
</style>
