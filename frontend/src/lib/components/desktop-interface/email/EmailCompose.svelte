<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let loading = true;
	let accounts: any[] = [];
	let signatures: any[] = [];
	let templates: any[] = [];
	let sending = false;
	let savingDraft = false;
	let statusMessage = '';

	let form = {
		email_account_id: '',
		to: '',
		cc: '',
		bcc: '',
		subject: '',
		html_body: '',
		text_body: '',
		signature_id: '',
		template_id: '',
		priority: 'normal',
		scheduled_at: ''
	};

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadData();
	});

	async function loadData() {
		loading = true;
		const [accRes, sigRes, tmplRes] = await Promise.all([
			supabase.rpc('get_email_accounts'),
			supabase.rpc('get_email_signatures'),
			supabase.rpc('get_email_templates')
		]);
		accounts = accRes.data || [];
		signatures = sigRes.data || [];
		templates = tmplRes.data || [];
		// Select default manual account
		const defaultAcc = accounts.find((a: any) => a.default_for_manual);
		if (defaultAcc) form.email_account_id = defaultAcc.id;
		else if (accounts.length > 0) form.email_account_id = accounts[0].id;
		loading = false;
	}

	function parseRecipients(str: string): Array<{type: string; email: string; name: string}> {
		return str.split(/[,;]/).map(s => s.trim()).filter(Boolean).map(email => ({ type: 'to', email, name: '' }));
	}

	async function saveDraft() {
		savingDraft = true;
		try {
			const recipients = [
				...parseRecipients(form.to).map(r => ({...r, type: 'to'})),
				...parseRecipients(form.cc).map(r => ({...r, type: 'cc'})),
				...parseRecipients(form.bcc).map(r => ({...r, type: 'bcc'}))
			];
			const account = accounts.find((a: any) => a.id === form.email_account_id);
			const { data, error } = await supabase.rpc('save_email_draft', { p_data: {
				email_account_id: form.email_account_id,
				subject: form.subject,
				html_body: form.html_body || `<p>${form.text_body}</p>`,
				text_body: form.text_body,
				from_name: account?.from_name || '',
				from_address: account?.email_address || '',
				recipients
			}});
			if (error) throw error;
			statusMessage = '✅ Draft saved';
			setTimeout(() => statusMessage = '', 3000);
		} catch (err: any) { statusMessage = '❌ ' + err.message; }
		finally { savingDraft = false; }
	}

	async function sendEmail() {
		if (!form.to.trim()) { statusMessage = '❌ Please enter at least one recipient'; return; }
		if (!form.subject.trim()) { if (!confirm('Send without subject?')) return; }
		sending = true;
		statusMessage = '';
		try {
			// First save as draft
			const recipients = [
				...parseRecipients(form.to).map(r => ({...r, type: 'to'})),
				...parseRecipients(form.cc).map(r => ({...r, type: 'cc'})),
				...parseRecipients(form.bcc).map(r => ({...r, type: 'bcc'}))
			];
			const account = accounts.find((a: any) => a.id === form.email_account_id);
			const { data: draftData, error: draftError } = await supabase.rpc('save_email_draft', { p_data: {
				email_account_id: form.email_account_id,
				subject: form.subject,
				html_body: form.html_body || `<p>${form.text_body}</p>`,
				text_body: form.text_body,
				from_name: account?.from_name || '',
				from_address: account?.email_address || '',
				recipients
			}});
			if (draftError) throw draftError;

			// Then queue for sending
			const { data: queueData, error: queueError } = await supabase.rpc('queue_email_send', {
				p_message_id: draftData.id,
				p_queue_type: 'normal',
				p_priority: form.priority === 'high' ? 2 : form.priority === 'low' ? 8 : 5
			});
			if (queueError) throw queueError;

			// Trigger the send immediately
			const { data: sendResult, error: sendError } = await supabase.functions.invoke('email-send', {
				body: { queue_id: queueData.queue_id }
			});
			
			if (sendError || !sendResult?.success) {
				statusMessage = '⚠️ Email queued but send attempt failed: ' + (sendResult?.error || sendError?.message || 'Unknown error');
			} else {
				statusMessage = '✅ Email sent successfully';
			}
			// Reset form
			form.to = ''; form.cc = ''; form.bcc = ''; form.subject = ''; form.html_body = ''; form.text_body = '';
		} catch (err: any) { statusMessage = '❌ ' + err.message; }
		finally { sending = false; }
	}

	function onTemplateSelect() {
		const tmpl = templates.find((t: any) => t.id === form.template_id);
		if (tmpl) {
			form.subject = tmpl.subject_template || form.subject;
			form.html_body = tmpl.html_body_template || '';
			form.text_body = tmpl.text_body_template || '';
		}
	}
</script>

<div class="compose-email">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div></div>
	{:else}
		<div class="compose-form">
			<!-- From Account -->
			<div class="field-row">
				<label class="field-label">From:</label>
				<select bind:value={form.email_account_id} class="field-input">
					{#each accounts as acc}<option value={acc.id}>{acc.from_name || acc.account_name} &lt;{acc.email_address}&gt;</option>{/each}
				</select>
			</div>

			<!-- To -->
			<div class="field-row">
				<label class="field-label">To:</label>
				<input type="text" bind:value={form.to} placeholder="recipient@example.com, ..." class="field-input" />
			</div>

			<!-- CC -->
			<div class="field-row">
				<label class="field-label">CC:</label>
				<input type="text" bind:value={form.cc} placeholder="cc@example.com" class="field-input" />
			</div>

			<!-- BCC -->
			<div class="field-row">
				<label class="field-label">BCC:</label>
				<input type="text" bind:value={form.bcc} placeholder="bcc@example.com" class="field-input" />
			</div>

			<!-- Subject -->
			<div class="field-row">
				<label class="field-label">Subject:</label>
				<input type="text" bind:value={form.subject} placeholder="Email subject..." class="field-input" />
			</div>

			<!-- Options Row -->
			<div class="options-row">
				<select bind:value={form.template_id} on:change={onTemplateSelect} class="option-select">
					<option value="">No template</option>
					{#each templates as tmpl}<option value={tmpl.id}>{tmpl.template_name}</option>{/each}
				</select>
				<select bind:value={form.priority} class="option-select">
					<option value="low">Low Priority</option>
					<option value="normal">Normal</option>
					<option value="high">High Priority</option>
				</select>
				<input type="datetime-local" bind:value={form.scheduled_at} class="option-select" title="Schedule (optional)" />
			</div>

			<!-- Body -->
			<div class="body-editor">
				<textarea bind:value={form.text_body} placeholder="Type your email here..." rows="14"></textarea>
			</div>

			<!-- Status -->
			{#if statusMessage}
				<div class="status-message" class:success={statusMessage.startsWith('✅')} class:error={statusMessage.startsWith('❌')}>
					{statusMessage}
				</div>
			{/if}

			<!-- Actions -->
			<div class="compose-actions">
				<button class="glass-btn" on:click={saveDraft} disabled={savingDraft}>
					{savingDraft ? 'Saving...' : '💾 Save Draft'}
				</button>
				<button class="glass-btn primary" on:click={sendEmail} disabled={sending || !form.to.trim()}>
					{sending ? 'Sending...' : '📤 Send'}
				</button>
			</div>
		</div>
	{/if}
</div>

<style>
	.compose-email { padding: 16px; height: 100%; overflow-y: auto; background: #f8fafc; display: flex; flex-direction: column; }
	.loading-container { display: flex; align-items: center; justify-content: center; flex: 1; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	.compose-form { display: flex; flex-direction: column; gap: 6px; flex: 1; }
	.field-row { display: flex; align-items: center; gap: 8px; }
	.field-label { font-size: 12px; font-weight: 600; color: #64748b; min-width: 50px; text-align: right; }
	.field-input { flex: 1; padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; background: white; }
	.field-input:focus { border-color: #f08300; outline: none; }

	.options-row { display: flex; gap: 8px; padding: 4px 0; }
	.option-select { padding: 6px 8px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 12px; background: white; }

	.body-editor { flex: 1; display: flex; flex-direction: column; }
	.body-editor textarea { flex: 1; padding: 12px; border: 1px solid #e2e8f0; border-radius: 8px; font-size: 13px; resize: none; font-family: inherit; line-height: 1.5; }
	.body-editor textarea:focus { border-color: #f08300; outline: none; }

	.status-message { padding: 8px 12px; border-radius: 6px; font-size: 12px; }
	.status-message.success { background: #dcfce7; color: #166534; }
	.status-message.error { background: #fee2e2; color: #991b1b; }

	.compose-actions { display: flex; justify-content: flex-end; gap: 10px; padding-top: 10px; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.15); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.25); }
</style>
