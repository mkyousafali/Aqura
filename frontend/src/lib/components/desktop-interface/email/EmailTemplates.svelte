<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	interface Template {
		id: string;
		template_name: string;
		template_code: string;
		category: string;
		subject_template: string;
		html_body_template: string;
		text_body_template: string;
		available_placeholders_json: string[];
		version: number;
		is_system_template: boolean;
		is_active: boolean;
		created_at: string;
	}

	let supabase: any = null;
	let loading = true;
	let templates: Template[] = [];
	let showForm = false;
	let editingTemplate: Template | null = null;
	let saving = false;
	let searchQuery = '';
	let categoryFilter = '';

	let form = { template_name: '', template_code: '', category: '', subject_template: '', html_body_template: '', text_body_template: '' };

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadTemplates();
	});

	async function loadTemplates() {
		loading = true;
		try {
			const { data, error } = await supabase.rpc('get_email_templates');
			if (error) throw error;
			templates = data || [];
		} catch (err) { console.error(err); }
		finally { loading = false; }
	}

	$: filteredTemplates = templates.filter(t => {
		if (searchQuery && !t.template_name.toLowerCase().includes(searchQuery.toLowerCase()) && !t.template_code?.toLowerCase().includes(searchQuery.toLowerCase())) return false;
		if (categoryFilter && t.category !== categoryFilter) return false;
		return true;
	});

	$: categories = [...new Set(templates.map(t => t.category).filter(Boolean))];

	function openCreate() { form = { template_name: '', template_code: '', category: '', subject_template: '', html_body_template: '', text_body_template: '' }; editingTemplate = null; showForm = true; }
	function openEdit(tmpl: Template) { editingTemplate = tmpl; form = { template_name: tmpl.template_name, template_code: tmpl.template_code || '', category: tmpl.category || '', subject_template: tmpl.subject_template || '', html_body_template: tmpl.html_body_template || '', text_body_template: tmpl.text_body_template || '' }; showForm = true; }

	async function saveTemplate() {
		saving = true;
		try {
			if (editingTemplate) {
				const { error } = await supabase.rpc('update_email_template', { p_id: editingTemplate.id, p_data: form });
				if (error) throw error;
			} else {
				const { error } = await supabase.rpc('create_email_template', { p_data: form });
				if (error) throw error;
			}
			showForm = false;
			await loadTemplates();
		} catch (err: any) { alert('Error: ' + err.message); }
		finally { saving = false; }
	}

	async function deleteTemplate(id: string) {
		if (!confirm('Deactivate this template?')) return;
		const { error } = await supabase.rpc('delete_email_template', { p_id: id });
		if (!error) await loadTemplates();
	}
</script>

<div class="email-templates">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div><p>Loading templates...</p></div>
	{:else if showForm}
		<div class="form-container">
			<div class="form-header">
				<h3>{editingTemplate ? 'Edit' : 'Create'} Template</h3>
				<button class="glass-btn" on:click={() => showForm = false}>← Back</button>
			</div>
			<div class="form-body">
				<label><span>Template Name *</span><input type="text" bind:value={form.template_name} /></label>
				<label><span>Template Code</span><input type="text" bind:value={form.template_code} placeholder="e.g. welcome_email" /></label>
				<label><span>Category</span><input type="text" bind:value={form.category} placeholder="e.g. transactional" /></label>
				<label><span>Subject</span><input type="text" bind:value={form.subject_template} placeholder="Email subject with {{placeholders}}" /></label>
				<label><span>HTML Body</span><textarea bind:value={form.html_body_template} rows="10" placeholder="<html>...</html>"></textarea></label>
				<label><span>Plain Text Body</span><textarea bind:value={form.text_body_template} rows="5" placeholder="Plain text version..."></textarea></label>
			</div>
			<div class="form-actions">
				<button class="glass-btn" on:click={() => showForm = false}>Cancel</button>
				<button class="glass-btn primary" on:click={saveTemplate} disabled={saving || !form.template_name}>{saving ? 'Saving...' : 'Save'}</button>
			</div>
		</div>
	{:else}
		<div class="list-header">
			<h3>📝 Email Templates</h3>
			<div class="header-actions">
				<input type="text" placeholder="Search..." bind:value={searchQuery} class="search-input" />
				<select bind:value={categoryFilter} class="filter-select">
					<option value="">All Categories</option>
					{#each categories as cat}<option value={cat}>{cat}</option>{/each}
				</select>
				<button class="glass-btn primary" on:click={openCreate}>+ Create</button>
			</div>
		</div>
		<div class="template-grid">
			{#each filteredTemplates as tmpl}
				<div class="template-card">
					<div class="card-header">
						<strong>{tmpl.template_name}</strong>
						{#if tmpl.is_system_template}<span class="sys-badge">System</span>{/if}
					</div>
					<div class="card-meta">
						{#if tmpl.template_code}<span class="code">{tmpl.template_code}</span>{/if}
						{#if tmpl.category}<span class="category">{tmpl.category}</span>{/if}
						<span class="version">v{tmpl.version}</span>
					</div>
					{#if tmpl.subject_template}<div class="card-subject">{tmpl.subject_template}</div>{/if}
					<div class="card-actions">
						<button class="action-btn" on:click={() => openEdit(tmpl)}>✏️ Edit</button>
						<button class="action-btn danger" on:click={() => deleteTemplate(tmpl.id)}>🗑️</button>
					</div>
				</div>
			{/each}
			{#if filteredTemplates.length === 0}
				<div class="empty-state">No templates found.</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.email-templates { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 200px; gap: 12px; color: #64748b; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.list-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 10px; }
	.list-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.header-actions { display: flex; gap: 8px; align-items: center; }
	.search-input, .filter-select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; background: white; }
	.template-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 12px; }
	.template-card { background: white; border-radius: 10px; padding: 14px; border: 1px solid #e2e8f0; }
	.card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
	.sys-badge { font-size: 10px; background: #dbeafe; color: #1d4ed8; padding: 2px 6px; border-radius: 4px; }
	.card-meta { display: flex; gap: 6px; margin-bottom: 6px; flex-wrap: wrap; }
	.code { font-size: 11px; background: #f1f5f9; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
	.category { font-size: 11px; background: #fef3c7; color: #92400e; padding: 2px 6px; border-radius: 3px; }
	.version { font-size: 11px; color: #94a3b8; }
	.card-subject { font-size: 12px; color: #64748b; margin-bottom: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.card-actions { display: flex; gap: 6px; }
	.action-btn { background: none; border: 1px solid #e2e8f0; border-radius: 6px; padding: 4px 10px; font-size: 12px; cursor: pointer; }
	.action-btn:hover { background: #f8fafc; }
	.action-btn.danger:hover { background: #fee2e2; border-color: #fecaca; }
	.empty-state { text-align: center; color: #94a3b8; padding: 40px; grid-column: 1/-1; }
	.form-container { max-width: 700px; }
	.form-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.form-header h3 { font-size: 16px; font-weight: 600; }
	.form-body { display: flex; flex-direction: column; gap: 12px; background: white; padding: 16px; border-radius: 10px; border: 1px solid #e2e8f0; }
	.form-body label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: #64748b; }
	.form-body label span { font-weight: 500; }
	.form-body input, .form-body textarea { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.form-body input:focus, .form-body textarea:focus { border-color: #f08300; outline: none; }
	.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 16px; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.2); }
</style>
