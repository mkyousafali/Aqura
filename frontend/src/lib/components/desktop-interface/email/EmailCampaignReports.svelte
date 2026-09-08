<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let campaigns: any[] = [];

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadCampaigns();
	});

	async function loadCampaigns() {
		loading = true;
		const { data } = await supabase.rpc('get_email_campaigns');
		campaigns = (data || []).filter((c: any) => c.status !== 'draft');
		loading = false;
	}

	function pct(n: number, total: number): string { return total > 0 ? Math.round((n/total)*100) + '%' : '0%'; }
</script>

<div class="campaign-reports">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="header"><h3>📈 Campaign Reports</h3><button class="glass-btn primary" on:click={loadCampaigns}>🔄</button></div>
		<div class="campaigns-grid">
			{#each campaigns as c}
				<div class="campaign-card">
					<h4>{c.campaign_name}</h4>
					<div class="campaign-status">{c.status}</div>
					<div class="stats-grid">
						<div class="stat"><span class="val">{c.total_recipients}</span><span class="lbl">Total</span></div>
						<div class="stat"><span class="val">{c.sent_count}</span><span class="lbl">Sent</span></div>
						<div class="stat"><span class="val">{c.delivered_count}</span><span class="lbl">Delivered</span></div>
						<div class="stat"><span class="val">{c.failed_count}</span><span class="lbl">Failed</span></div>
						<div class="stat"><span class="val">{c.bounced_count}</span><span class="lbl">Bounced</span></div>
						<div class="stat"><span class="val">{c.opened_count}</span><span class="lbl">Opened</span></div>
					</div>
					{#if c.total_recipients > 0}
						<div class="progress-bar"><div class="fill" style="width:{pct(c.sent_count, c.total_recipients)}"></div></div>
						<div class="progress-label">{pct(c.sent_count, c.total_recipients)} complete</div>
					{/if}
				</div>
			{/each}
			{#if campaigns.length === 0}<div class="empty-state">No campaign data yet</div>{/if}
		</div>
	{/if}
</div>

<style>
	.campaign-reports { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.header h3 { font-size: 16px; font-weight: 600; }
	.campaigns-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px; }
	.campaign-card { background: white; border-radius: 10px; padding: 16px; border: 1px solid #e2e8f0; }
	.campaign-card h4 { font-size: 14px; font-weight: 600; margin-bottom: 4px; }
	.campaign-status { font-size: 11px; color: #64748b; margin-bottom: 10px; text-transform: capitalize; }
	.stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 10px; }
	.stat { text-align: center; }
	.stat .val { display: block; font-size: 16px; font-weight: 700; color: #1e293b; }
	.stat .lbl { font-size: 10px; color: #94a3b8; }
	.progress-bar { height: 6px; background: #e2e8f0; border-radius: 3px; overflow: hidden; }
	.fill { height: 100%; background: #22c55e; border-radius: 3px; }
	.progress-label { font-size: 11px; color: #64748b; margin-top: 4px; }
	.empty-state { text-align: center; color: #94a3b8; padding: 40px; }
	.glass-btn { padding: 6px 14px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); color: #334155; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
</style>
