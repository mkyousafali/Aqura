<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let loading = true;
	let aiSettings: any[] = [];
	let saving = false;
	let saveMessage = '';

	const featureDescriptions: Record<string, string> = {
		email_summary: 'Automatically generate summaries of long emails',
		translation: 'Translate emails between languages',
		reply_suggestion: 'Suggest reply drafts based on context',
		auto_categorisation: 'Auto-categorize emails by topic/department',
		sentiment_detection: 'Detect sentiment (positive/negative/neutral)',
		spam_detection: 'Detect spam and phishing attempts',
		priority_detection: 'Auto-detect email priority level',
		auto_draft: 'Generate draft replies automatically',
		ticket_suggestion: 'Suggest creating support tickets from emails',
		auto_reply: 'Automatically reply to emails (requires approval)'
	};

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadSettings();
	});

	async function loadSettings() {
		loading = true;
		try {
			const { data, error } = await supabase.rpc('get_email_ai_settings');
			if (error) throw error;
			aiSettings = data || [];
		} catch (err) { console.error(err); }
		finally { loading = false; }
	}

	async function toggleFeature(feature: any) {
		saving = true;
		try {
			const { error } = await supabase.rpc('update_email_ai_setting', {
				p_feature_name: feature.feature_name,
				p_data: { is_enabled: !feature.is_enabled }
			});
			if (error) throw error;
			feature.is_enabled = !feature.is_enabled;
			aiSettings = [...aiSettings];
			saveMessage = '✅ Updated';
			setTimeout(() => saveMessage = '', 2000);
		} catch (err: any) { saveMessage = '❌ ' + err.message; }
		finally { saving = false; }
	}

	async function updateSetting(feature: any, field: string, value: any) {
		try {
			const { error } = await supabase.rpc('update_email_ai_setting', {
				p_feature_name: feature.feature_name,
				p_data: { [field]: value }
			});
			if (error) throw error;
		} catch (err) { console.error(err); }
	}
</script>

<div class="ai-settings">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div><p>Loading AI settings...</p></div>
	{:else}
		<div class="settings-header">
			<h3>🤖 AI Email Settings</h3>
			{#if saveMessage}<span class="save-msg">{saveMessage}</span>{/if}
		</div>

		<div class="warning-banner">
			⚠️ AI features process email content through external AI providers. Ensure compliance with your data policies before enabling.
		</div>

		<div class="features-list">
			{#each aiSettings as feature}
				<div class="feature-card" class:enabled={feature.is_enabled}>
					<div class="feature-header">
						<div class="feature-title">
							<span class="feature-name">{feature.feature_name.replace(/_/g, ' ')}</span>
							<span class="feature-desc">{featureDescriptions[feature.feature_name] || ''}</span>
						</div>
						<button class="toggle-btn" class:on={feature.is_enabled} on:click={() => toggleFeature(feature)} disabled={saving}>
							{feature.is_enabled ? 'ON' : 'OFF'}
						</button>
					</div>
					{#if feature.is_enabled}
						<div class="feature-config">
							<label>
								<span>Provider</span>
								<input type="text" value={feature.provider_reference || ''} on:blur={(e) => updateSetting(feature, 'provider_reference', e.currentTarget.value)} placeholder="e.g. openai" />
							</label>
							<label>
								<span>Model</span>
								<input type="text" value={feature.model_reference || ''} on:blur={(e) => updateSetting(feature, 'model_reference', e.currentTarget.value)} placeholder="e.g. gpt-4" />
							</label>
							<label>
								<span>Max Tokens</span>
								<input type="number" value={feature.maximum_tokens} on:blur={(e) => updateSetting(feature, 'maximum_tokens', parseInt(e.currentTarget.value))} />
							</label>
							<label class="checkbox-label">
								<input type="checkbox" checked={feature.approval_required} on:change={(e) => updateSetting(feature, 'approval_required', e.currentTarget.checked)} />
								<span>Requires Human Approval</span>
							</label>
							<label class="checkbox-label">
								<input type="checkbox" checked={feature.auto_send_allowed} on:change={(e) => updateSetting(feature, 'auto_send_allowed', e.currentTarget.checked)} />
								<span>Auto-Send Allowed</span>
							</label>
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.ai-settings { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 200px; gap: 12px; color: #64748b; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.settings-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.settings-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.save-msg { font-size: 12px; color: #166534; }
	.warning-banner { padding: 10px 14px; background: #fef3c7; border: 1px solid #fde68a; border-radius: 8px; font-size: 12px; color: #92400e; margin-bottom: 16px; }
	.features-list { display: flex; flex-direction: column; gap: 10px; }
	.feature-card { background: white; border-radius: 10px; padding: 14px; border: 1px solid #e2e8f0; transition: border-color 0.15s; }
	.feature-card.enabled { border-color: #86efac; }
	.feature-header { display: flex; justify-content: space-between; align-items: center; }
	.feature-title { display: flex; flex-direction: column; gap: 2px; }
	.feature-name { font-size: 14px; font-weight: 600; color: #1e293b; text-transform: capitalize; }
	.feature-desc { font-size: 11px; color: #64748b; }
	.toggle-btn { padding: 4px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid #e2e8f0; background: #f1f5f9; color: #64748b; }
	.toggle-btn.on { background: #dcfce7; color: #166534; border-color: #86efac; }
	.toggle-btn:disabled { opacity: 0.5; }
	.feature-config { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 10px; margin-top: 12px; padding-top: 12px; border-top: 1px solid #f1f5f9; }
	.feature-config label { display: flex; flex-direction: column; gap: 4px; font-size: 11px; color: #64748b; }
	.feature-config label span { font-weight: 500; }
	.feature-config input[type="text"], .feature-config input[type="number"] { padding: 6px 8px; border: 1px solid #e2e8f0; border-radius: 5px; font-size: 12px; }
	.feature-config input:focus { border-color: #f08300; outline: none; }
	.checkbox-label { flex-direction: row !important; align-items: center; gap: 6px !important; }
</style>
