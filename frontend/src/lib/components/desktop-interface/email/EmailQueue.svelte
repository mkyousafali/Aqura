<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let queueData: any = { summary: {}, items: [] };
	let statusFilter = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadQueue();
	});

	async function loadQueue() {
		loading = true;
		const { data, error } = await supabase.rpc('get_email_queue', { p_status: statusFilter || null });
		if (data) queueData = data;
		loading = false;
	}

	function formatTime(ts: string): string { return ts ? new Date(ts).toLocaleString() : '—'; }
</script>

<div class="email-queue-view">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="queue-header"><h3>📋 Email Queue</h3><button class="glass-btn primary" on:click={loadQueue}>🔄 Refresh</button></div>

		<div class="summary-cards">
			<div class="card"><span class="val">{queueData.summary?.waiting || 0}</span><span class="lbl">Waiting</span></div>
			<div class="card"><span class="val">{queueData.summary?.processing || 0}</span><span class="lbl">Processing</span></div>
			<div class="card success"><span class="val">{queueData.summary?.sent || 0}</span><span class="lbl">Sent (24h)</span></div>
			<div class="card warn"><span class="val">{queueData.summary?.temporary_failed || 0}</span><span class="lbl">Temp Failed</span></div>
			<div class="card error"><span class="val">{queueData.summary?.permanent_failed || 0}</span><span class="lbl">Perm Failed</span></div>
			<div class="card"><span class="val">{queueData.summary?.paused || 0}</span><span class="lbl">Paused</span></div>
		</div>

		<div class="filter-row">
			<select bind:value={statusFilter} on:change={loadQueue}>
				<option value="">All Statuses</option>
				<option value="waiting">Waiting</option>
				<option value="processing">Processing</option>
				<option value="sent">Sent</option>
				<option value="temporary_failed">Temp Failed</option>
				<option value="permanent_failed">Perm Failed</option>
				<option value="paused">Paused</option>
				<option value="cancelled">Cancelled</option>
			</select>
		</div>

		<table class="queue-table">
			<thead><tr><th>Type</th><th>Priority</th><th>Account</th><th>Subject</th><th>Status</th><th>Attempts</th><th>Next Retry</th><th>Error</th></tr></thead>
			<tbody>
				{#each queueData.items as item}
					<tr>
						<td>{item.queue_type}</td>
						<td>{item.priority}</td>
						<td>{item.account_name || '—'}</td>
						<td class="subject">{item.subject || '—'}</td>
						<td><span class="status-badge {item.status}">{item.status}</span></td>
						<td>{item.attempt_count}/{item.maximum_attempts}</td>
						<td>{formatTime(item.next_retry_at)}</td>
						<td class="error-cell">{item.last_error_message || '—'}</td>
					</tr>
				{/each}
				{#if queueData.items.length === 0}<tr><td colspan="8" class="empty">Queue is empty</td></tr>{/if}
			</tbody>
		</table>
	{/if}
</div>

<style>
	.email-queue-view { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.queue-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.queue-header h3 { font-size: 16px; font-weight: 600; }
	.summary-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: 10px; margin-bottom: 16px; }
	.card { background: white; padding: 12px; border-radius: 8px; border: 1px solid #e2e8f0; text-align: center; }
	.card .val { display: block; font-size: 20px; font-weight: 700; color: #1e293b; }
	.card .lbl { font-size: 11px; color: #64748b; }
	.card.success .val { color: #16a34a; }
	.card.warn .val { color: #d97706; }
	.card.error .val { color: #dc2626; }
	.filter-row { margin-bottom: 12px; }
	.filter-row select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.queue-table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
	.queue-table th { padding: 8px 10px; text-align: left; font-size: 11px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	.queue-table td { padding: 8px 10px; font-size: 12px; border-bottom: 1px solid #f1f5f9; }
	.subject { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.error-cell { max-width: 150px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; color: #dc2626; }
	.status-badge { font-size: 11px; font-weight: 500; padding: 2px 6px; border-radius: 4px; }
	.status-badge.waiting { background: #f1f5f9; color: #475569; }
	.status-badge.processing { background: #dbeafe; color: #1d4ed8; }
	.status-badge.sent { background: #dcfce7; color: #166534; }
	.status-badge.temporary_failed { background: #fef3c7; color: #92400e; }
	.status-badge.permanent_failed { background: #fee2e2; color: #991b1b; }
	.status-badge.paused { background: #f5f5f4; color: #57534e; }
	.empty { text-align: center; color: #94a3b8; padding: 40px !important; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
</style>
