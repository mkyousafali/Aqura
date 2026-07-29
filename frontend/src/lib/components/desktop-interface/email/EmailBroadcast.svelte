<script lang="ts">
	import { onMount } from 'svelte';
	let supabase: any = null;
	let loading = true;
	let campaigns: any[] = [];
	let showForm = false;
	let accounts: any[] = [];
	let templates: any[] = [];
	let saving = false;
	let form = { campaign_name: '', email_account_id: '', email_template_id: '', subject_override: '', batch_size_override: 10, delay_override_seconds: 2 };

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadData();
	});

	async function loadData() {
		loading = true;
		const [cRes, aRes, tRes] = await Promise.all([
			supabase.rpc('get_email_campaigns'),
			supabase.rpc('get_email_accounts'),
			supabase.rpc('get_email_templates')
		]);
		campaigns = cRes.data || [];
		accounts = aRes.data || [];
		templates = tRes.data || [];
		loading = false;
	}

	async function createCampaign() {
		saving = true;
		try {
			const { error } = await supabase.rpc('create_email_campaign', { p_data: form });
			if (error) throw error;
			showForm = false;
			await loadData();
		} catch (err: any) { alert(err.message); }
		finally { saving = false; }
	}

	function getStatusColor(status: string): string {
		const map: Record<string, string> = { draft: '#64748b', running: '#22c55e', paused: '#f59e0b', completed: '#3b82f6', failed: '#ef4444', cancelled: '#94a3b8' };
		return map[status] || '#64748b';
	}
</script>

<div class="email-broadcast">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else if showForm}
		<div class="form-container">
			<div class="form-header"><h3>Create Campaign</h3><button class="glass-btn" on:click={() => showForm = false}>← Back</button></div>
			<div class="form-body">
				<label><span>Campaign Name *</span><input type="text" bind:value={form.campaign_name} /></label>
				<label><span>Sending Account *</span>
					<select bind:value={form.email_account_id}>
						<option value="">Select...</option>
						{#each accounts as acc}<option value={acc.id}>{acc.account_name}</option>{/each}
					</select>
				</label>
				<label><span>Template</span>
					<select bind:value={form.email_template_id}>
						<option value="">None</option>
						{#each templates as tmpl}<option value={tmpl.id}>{tmpl.template_name}</option>{/each}
					</select>
				</label>
				<label><span>Subject Override</span><input type="text" bind:value={form.subject_override} /></label>
				<label><span>Batch Size</span><input type="number" bind:value={form.batch_size_override} /></label>
				<label><span>Delay Between Sends (sec)</span><input type="number" bind:value={form.delay_override_seconds} /></label>
			</div>
			<div class="form-actions">
				<button class="glass-btn" on:click={() => showForm = false}>Cancel</button>
				<button class="glass-btn primary" on:click={createCampaign} disabled={saving || !form.campaign_name}>{saving ? 'Creating...' : 'Create Campaign'}</button>
			</div>
		</div>
	{:else}
		<div class="list-header">
			<h3>📣 Email Broadcasts</h3>
			<button class="glass-btn primary" on:click={() => showForm = true}>+ New Campaign</button>
		</div>
		<div class="campaigns-table">
			<table>
				<thead><tr><th>Campaign</th><th>Status</th><th>Recipients</th><th>Sent</th><th>Failed</th><th>Progress</th><th>Created</th></tr></thead>
				<tbody>
					{#each campaigns as c}
						<tr>
							<td class="name">{c.campaign_name}</td>
							<td><span class="status-badge" style="color:{getStatusColor(c.status)}">{c.status}</span></td>
							<td>{c.total_recipients}</td>
							<td>{c.sent_count}</td>
							<td>{c.failed_count}</td>
							<td>
								{#if c.total_recipients > 0}
									<div class="progress-bar"><div class="progress-fill" style="width:{Math.round((c.sent_count/c.total_recipients)*100)}%"></div></div>
								{:else}—{/if}
							</td>
							<td>{new Date(c.created_at).toLocaleDateString()}</td>
						</tr>
					{/each}
					{#if campaigns.length === 0}<tr><td colspan="7" class="empty">No campaigns yet</td></tr>{/if}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<style>
	.email-broadcast { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; align-items: center; justify-content: center; height: 200px; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.list-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.list-header h3 { font-size: 16px; font-weight: 600; }
	.campaigns-table { overflow-x: auto; }
	table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
	th { padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	td { padding: 10px 12px; font-size: 13px; border-bottom: 1px solid #f1f5f9; }
	.name { font-weight: 600; }
	.status-badge { font-weight: 600; font-size: 12px; text-transform: capitalize; }
	.progress-bar { width: 80px; height: 6px; background: #e2e8f0; border-radius: 3px; overflow: hidden; }
	.progress-fill { height: 100%; background: #22c55e; border-radius: 3px; transition: width 0.3s; }
	.empty { text-align: center; color: #94a3b8; padding: 40px !important; }
	.form-container { max-width: 600px; }
	.form-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.form-header h3 { font-size: 16px; font-weight: 600; }
	.form-body { display: flex; flex-direction: column; gap: 12px; background: white; padding: 16px; border-radius: 10px; border: 1px solid #e2e8f0; }
	.form-body label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: #64748b; }
	.form-body label span { font-weight: 500; }
	.form-body input, .form-body select { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 16px; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.2); }
</style>
