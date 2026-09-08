<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let loading = true;
	let settings: Record<string, any> = {};
	let saving = false;
	let saveMessage = '';

	const settingLabels: Record<string, { label: string; type: string; description: string }> = {
		sync_interval_seconds: { label: 'Sync Interval (seconds)', type: 'number', description: 'How often to check for new emails' },
		queue_processing_interval_seconds: { label: 'Queue Processing Interval (seconds)', type: 'number', description: 'How often to process the send queue' },
		default_batch_size: { label: 'Default Batch Size', type: 'number', description: 'Emails per batch in queue processing' },
		default_send_delay_seconds: { label: 'Default Send Delay (seconds)', type: 'number', description: 'Minimum delay between sends' },
		default_retry_count: { label: 'Default Retry Count', type: 'number', description: 'Max retries for failed emails' },
		retry_backoff_multiplier: { label: 'Retry Backoff Multiplier', type: 'number', description: 'Exponential backoff multiplier' },
		attachment_max_size_bytes: { label: 'Max Attachment Size (bytes)', type: 'number', description: '25MB = 26214400' },
		auto_save_draft_interval_seconds: { label: 'Auto-Save Draft Interval (seconds)', type: 'number', description: 'Auto-save drafts every N seconds' },
		retention_days: { label: 'Email Retention (days)', type: 'number', description: 'How long to keep email records' },
		default_search_date_range_days: { label: 'Default Search Range (days)', type: 'number', description: 'Default date range for searches' },
		unsubscribe_required_for_broadcast: { label: 'Require Unsubscribe Link in Broadcasts', type: 'boolean', description: 'Force unsubscribe links in campaigns' },
		log_retention_days: { label: 'Log Retention (days)', type: 'number', description: 'How long to keep audit logs' },
	};

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadSettings();
	});

	async function loadSettings() {
		loading = true;
		try {
			const { data, error } = await supabase.rpc('get_email_settings');
			if (error) throw error;
			settings = data || {};
		} catch (err) { console.error(err); }
		finally { loading = false; }
	}

	async function saveSetting(key: string) {
		saving = true;
		saveMessage = '';
		try {
			const value = typeof settings[key] === 'string' ? JSON.parse(settings[key]) : settings[key];
			const { error } = await supabase.rpc('update_email_setting', { p_key: key, p_value: JSON.stringify(value) });
			if (error) throw error;
			saveMessage = `✅ ${key} saved`;
			setTimeout(() => saveMessage = '', 3000);
		} catch (err: any) { saveMessage = `❌ Error: ${err.message}`; }
		finally { saving = false; }
	}

	function getSettingValue(key: string): any {
		const val = settings[key];
		if (val === undefined || val === null) return '';
		if (typeof val === 'string') {
			try { return JSON.parse(val); } catch { return val; }
		}
		return val;
	}
</script>

<div class="email-settings">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div><p>Loading settings...</p></div>
	{:else}
		<div class="settings-header">
			<h3>⚙️ Email Settings</h3>
			{#if saveMessage}<span class="save-msg" class:error={saveMessage.startsWith('❌')}>{saveMessage}</span>{/if}
		</div>

		<div class="settings-list">
			{#each Object.entries(settingLabels) as [key, meta]}
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">{meta.label}</span>
						<span class="setting-desc">{meta.description}</span>
					</div>
					<div class="setting-control">
						{#if meta.type === 'boolean'}
							<select bind:value={settings[key]} on:change={() => saveSetting(key)}>
								<option value="true">Yes</option>
								<option value="false">No</option>
							</select>
						{:else}
							<input type="number" bind:value={settings[key]} on:blur={() => saveSetting(key)} />
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.email-settings { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 200px; gap: 12px; color: #64748b; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.settings-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
	.settings-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.save-msg { font-size: 12px; color: #166534; }
	.save-msg.error { color: #991b1b; }
	.settings-list { display: flex; flex-direction: column; gap: 2px; }
	.setting-row { display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; background: white; border: 1px solid #f1f5f9; border-radius: 8px; }
	.setting-row:hover { background: #f8fafc; }
	.setting-info { display: flex; flex-direction: column; gap: 2px; }
	.setting-label { font-size: 13px; font-weight: 500; color: #334155; }
	.setting-desc { font-size: 11px; color: #94a3b8; }
	.setting-control input, .setting-control select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; width: 140px; text-align: right; }
	.setting-control input:focus, .setting-control select:focus { border-color: #f08300; outline: none; }
</style>
