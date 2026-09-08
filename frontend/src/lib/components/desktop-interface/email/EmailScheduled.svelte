<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let scheduledEmails: any[] = [];

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadScheduled();
	});

	async function loadScheduled() {
		loading = true;
		const { data } = await supabase.from('email_messages')
			.select('id, subject, from_address, scheduled_at, status, created_at')
			.not('scheduled_at', 'is', null)
			.order('scheduled_at', { ascending: true })
			.limit(100);
		scheduledEmails = data || [];
		loading = false;
	}

	async function cancelScheduled(id: string) {
		if (!confirm('Cancel this scheduled email?')) return;
		await supabase.from('email_messages').update({ status: 'cancelled', scheduled_at: null }).eq('id', id);
		await loadScheduled();
	}

	function formatTime(ts: string): string { return ts ? new Date(ts).toLocaleString() : '—'; }
</script>

<div class="scheduled-view">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="header"><h3>🕐 Scheduled Emails</h3><button class="glass-btn primary" on:click={loadScheduled}>🔄 Refresh</button></div>
		<table>
			<thead><tr><th>Subject</th><th>From</th><th>Scheduled For</th><th>Status</th><th>Actions</th></tr></thead>
			<tbody>
				{#each scheduledEmails as email}
					<tr>
						<td>{email.subject || '(no subject)'}</td>
						<td>{email.from_address}</td>
						<td>{formatTime(email.scheduled_at)}</td>
						<td><span class="badge">{email.status}</span></td>
						<td>
							{#if email.status === 'queued' || email.status === 'draft'}
								<button class="action-btn" on:click={() => cancelScheduled(email.id)}>❌ Cancel</button>
							{/if}
						</td>
					</tr>
				{/each}
				{#if scheduledEmails.length === 0}<tr><td colspan="5" class="empty">No scheduled emails</td></tr>{/if}
			</tbody>
		</table>
	{/if}
</div>

<style>
	.scheduled-view { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.header h3 { font-size: 16px; font-weight: 600; }
	table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
	th { padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	td { padding: 10px 12px; font-size: 13px; border-bottom: 1px solid #f1f5f9; }
	.badge { font-size: 11px; background: #f1f5f9; padding: 2px 8px; border-radius: 4px; }
	.action-btn { background: none; border: 1px solid #e2e8f0; border-radius: 6px; padding: 4px 10px; font-size: 12px; cursor: pointer; }
	.action-btn:hover { background: #fee2e2; }
	.empty { text-align: center; color: #94a3b8; padding: 40px !important; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
</style>
