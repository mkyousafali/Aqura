<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let loading = true;
	let signatures: any[] = [];
	let showForm = false;
	let editing: any = null;
	let saving = false;
	let form = { signature_name: '', html_signature: '', text_signature: '', department: '', is_default: false };

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadSignatures();
	});

	async function loadSignatures() {
		loading = true;
		try {
			const { data, error } = await supabase.rpc('get_email_signatures');
			if (error) throw error;
			signatures = data || [];
		} catch (err) { console.error(err); }
		finally { loading = false; }
	}

	function openCreate() { form = { signature_name: '', html_signature: '', text_signature: '', department: '', is_default: false }; editing = null; showForm = true; }
	function openEdit(sig: any) { editing = sig; form = { signature_name: sig.signature_name, html_signature: sig.html_signature || '', text_signature: sig.text_signature || '', department: sig.department || '', is_default: sig.is_default }; showForm = true; }

	async function save() {
		saving = true;
		try {
			if (editing) {
				const { error } = await supabase.rpc('update_email_signature', { p_id: editing.id, p_data: form });
				if (error) throw error;
			} else {
				const { error } = await supabase.rpc('create_email_signature', { p_data: form });
				if (error) throw error;
			}
			showForm = false;
			await loadSignatures();
		} catch (err: any) { alert('Error: ' + err.message); }
		finally { saving = false; }
	}

	async function deleteSignature(id: string) {
		if (!confirm('Deactivate this signature?')) return;
		await supabase.rpc('delete_email_signature', { p_id: id });
		await loadSignatures();
	}
</script>

<div class="email-signatures">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div><p>Loading...</p></div>
	{:else if showForm}
		<div class="form-container">
			<div class="form-header">
				<h3>{editing ? 'Edit' : 'Create'} Signature</h3>
				<button class="glass-btn" on:click={() => showForm = false}>← Back</button>
			</div>
			<div class="form-body">
				<label><span>Name *</span><input type="text" bind:value={form.signature_name} /></label>
				<label><span>Department</span>
					<select bind:value={form.department}>
						<option value="">None</option>
						<option value="General">General</option>
						<option value="Support">Support</option>
						<option value="Sales">Sales</option>
						<option value="Finance">Finance</option>
						<option value="HR">HR</option>
						<option value="Marketing">Marketing</option>
					</select>
				</label>
				<label><span>HTML Signature</span><textarea bind:value={form.html_signature} rows="6" placeholder="<p>Best regards,<br>Name</p>"></textarea></label>
				<label><span>Plain Text</span><textarea bind:value={form.text_signature} rows="4" placeholder="Best regards,&#10;Name"></textarea></label>
				<label class="checkbox-label"><input type="checkbox" bind:checked={form.is_default} /><span>Default Signature</span></label>
			</div>
			<div class="form-actions">
				<button class="glass-btn" on:click={() => showForm = false}>Cancel</button>
				<button class="glass-btn primary" on:click={save} disabled={saving || !form.signature_name}>{saving ? 'Saving...' : 'Save'}</button>
			</div>
		</div>
	{:else}
		<div class="list-header">
			<h3>✍️ Email Signatures</h3>
			<button class="glass-btn primary" on:click={openCreate}>+ Create</button>
		</div>
		<div class="sig-grid">
			{#each signatures as sig}
				<div class="sig-card">
					<div class="sig-header">
						<strong>{sig.signature_name}</strong>
						{#if sig.is_default}<span class="default-badge">Default</span>{/if}
					</div>
					{#if sig.department}<span class="dept">{sig.department}</span>{/if}
					<div class="sig-preview">{@html sig.html_signature || sig.text_signature || '<em>Empty</em>'}</div>
					<div class="sig-actions">
						<button class="action-btn" on:click={() => openEdit(sig)}>✏️ Edit</button>
						<button class="action-btn danger" on:click={() => deleteSignature(sig.id)}>🗑️</button>
					</div>
				</div>
			{/each}
			{#if signatures.length === 0}
				<div class="empty-state">No signatures yet.</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.email-signatures { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 200px; gap: 12px; color: #64748b; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.list-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.list-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.sig-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 12px; }
	.sig-card { background: white; border-radius: 10px; padding: 14px; border: 1px solid #e2e8f0; }
	.sig-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
	.default-badge { font-size: 10px; background: #dcfce7; color: #166534; padding: 2px 6px; border-radius: 4px; }
	.dept { font-size: 11px; color: #64748b; }
	.sig-preview { font-size: 12px; color: #475569; margin: 8px 0; padding: 8px; background: #f8fafc; border-radius: 6px; max-height: 80px; overflow: hidden; }
	.sig-actions { display: flex; gap: 6px; }
	.action-btn { background: none; border: 1px solid #e2e8f0; border-radius: 6px; padding: 4px 10px; font-size: 12px; cursor: pointer; }
	.action-btn:hover { background: #f8fafc; }
	.action-btn.danger:hover { background: #fee2e2; }
	.empty-state { text-align: center; color: #94a3b8; padding: 40px; grid-column: 1/-1; }
	.form-container { max-width: 600px; }
	.form-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.form-header h3 { font-size: 16px; font-weight: 600; }
	.form-body { display: flex; flex-direction: column; gap: 12px; background: white; padding: 16px; border-radius: 10px; border: 1px solid #e2e8f0; }
	.form-body label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: #64748b; }
	.form-body label span { font-weight: 500; }
	.form-body input, .form-body select, .form-body textarea { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.form-body input:focus, .form-body textarea:focus { border-color: #f08300; outline: none; }
	.checkbox-label { flex-direction: row !important; align-items: center; gap: 8px !important; }
	.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 16px; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.2); }
</style>
