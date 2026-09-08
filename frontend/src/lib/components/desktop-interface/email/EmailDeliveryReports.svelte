<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let events: any[] = [];

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadEvents();
	});

	async function loadEvents() {
		loading = true;
		const { data } = await supabase.from('email_delivery_events')
			.select('*, email_messages(subject, from_address)')
			.order('event_at', { ascending: false }).limit(100);
		events = data || [];
		loading = false;
	}

	function formatTime(ts: string): string { return ts ? new Date(ts).toLocaleString() : ''; }
	function getEventIcon(type: string): string {
		const map: Record<string, string> = { delivered: '✅', bounced: '🔴', complained: '⚠️', opened: '👁️', clicked: '🔗', unsubscribed: '🚫' };
		return map[type] || '📧';
	}
</script>

<div class="delivery-reports">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="header"><h3>✅ Delivery Reports</h3><button class="glass-btn primary" on:click={loadEvents}>🔄</button></div>
		<table>
			<thead><tr><th>Time</th><th>Event</th><th>Subject</th><th>From</th></tr></thead>
			<tbody>
				{#each events as ev}
					<tr>
						<td class="time">{formatTime(ev.event_at)}</td>
						<td><span class="event-type">{getEventIcon(ev.event_type)} {ev.event_type}</span></td>
						<td>{ev.email_messages?.subject || '—'}</td>
						<td>{ev.email_messages?.from_address || '—'}</td>
					</tr>
				{/each}
				{#if events.length === 0}<tr><td colspan="4" class="empty">No delivery events recorded yet</td></tr>{/if}
			</tbody>
		</table>
	{/if}
</div>

<style>
	.delivery-reports { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.header h3 { font-size: 16px; font-weight: 600; }
	table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
	th { padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	td { padding: 10px 12px; font-size: 13px; border-bottom: 1px solid #f1f5f9; }
	.time { white-space: nowrap; font-size: 12px; color: #64748b; }
	.event-type { font-size: 12px; text-transform: capitalize; }
	.empty { text-align: center; color: #94a3b8; padding: 40px !important; }
	.glass-btn { padding: 6px 14px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); color: #334155; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
</style>
