<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let failedItems: any[] = [];

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadFailed();
	});

	async function loadFailed() {
		loading = true;
		const { data } = await supabase.from('email_queue')
			.select('*, email_messages(subject, from_address), email_accounts(account_name)')
			.in('status', ['temporary_failed', 'permanent_failed'])
			.order('created_at', { ascending: false }).limit(100);
		failedItems = data || [];
		loading = false;
	}

	async function retryItem(id: string) {
		await supabase.from('email_queue').update({ status: 'waiting', attempt_count: 0, next_retry_at: null }).eq('id', id);
		await loadFailed();
	}

	function formatTime(ts: string): string { return ts ? new Date(ts).toLocaleString() : '—'; }
</script>

<div class="failed-emails">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="header"><h3>❌ Failed Emails</h3><button class="glass-btn primary" on:click={loadFailed}>🔄</button></div>
		<table>
			<thead><tr><th>Subject</th><th>Account</th><th>Status</th><th>Attempts</th><th>Error</th><th>Time</th><th>Actions</th></tr></thead>
			<tbody>
				{#each failedItems as item}
					<tr>
						<td>{item.email_messages?.subject || '—'}</td>
						<td>{item.email_accounts?.account_name || '—'}</td>
						<td><span class="badge" class:temp={item.status === 'temporary_failed'} class:perm={item.status === 'permanent_failed'}>{item.status === 'temporary_failed' ? 'Temp' : 'Permanent'}</span></td>
						<td>{item.attempt_count}/{item.maximum_attempts}</td>
						<td class="error-cell">{item.last_error_message || '—'}</td>
						<td class="time">{formatTime(item.created_at)}</td>
						<td>
							{#if item.status === 'temporary_failed'}
								<button class="action-btn" on:click={() => retryItem(item.id)}>🔄 Retry</button>
							{/if}
						</td>
					</tr>
				{/each}
				{#if failedItems.length === 0}<tr><td colspan="7" class="empty">No failed emails</td></tr>{/if}
			</tbody>
		</table>
	{/if}
</div>

<style>
	.failed-emails { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.header h3 { font-size: 16px; font-weight: 600; }
	table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
	th { padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	td { padding: 10px 12px; font-size: 13px; border-bottom: 1px solid #f1f5f9; }
	.badge { font-size: 11px; padding: 2px 6px; border-radius: 4px; }
	.badge.temp { background: #fef3c7; color: #92400e; }
	.badge.perm { background: #fee2e2; color: #991b1b; }
	.error-cell { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; color: #dc2626; }
	.time { font-size: 11px; color: #64748b; white-space: nowrap; }
	.action-btn { background: none; border: 1px solid #e2e8f0; border-radius: 6px; padding: 4px 10px; font-size: 12px; cursor: pointer; }
	.action-btn:hover { background: #f0fdf4; border-color: #86efac; }
	.empty { text-align: center; color: #94a3b8; padding: 40px !important; }
	.glass-btn { padding: 6px 14px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); color: #334155; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
</style>
