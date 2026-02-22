<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let apiKeys: any[] = [];
	let loading = true;
	let saving: Record<number, boolean> = {};
	let revealed: Record<number, boolean> = {};
	let editing: Record<number, string> = {};
	let addingNew = false;
	let newService = { service_name: '', api_key: '', description: '' };
	let saveError: Record<number, string> = {};
	let saveSuccess: Record<number, boolean> = {};
	let globalError = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadKeys();
	});

	async function loadKeys() {
		loading = true;
		globalError = '';
		try {
			const { data, error } = await supabase
				.from('system_api_keys')
				.select('*')
				.order('service_name');
			if (error) throw error;
			apiKeys = data || [];
			// Init editing values
			apiKeys.forEach((k: any) => { editing[k.id] = k.api_key; });
		} catch (e: any) {
			globalError = e.message || 'Failed to load API keys';
		} finally {
			loading = false;
		}
	}

	async function saveKey(key: any) {
		saving[key.id] = true;
		saveError[key.id] = '';
		saveSuccess[key.id] = false;
		try {
			const { error } = await supabase
				.from('system_api_keys')
				.update({ api_key: editing[key.id], description: key.description, is_active: key.is_active })
				.eq('id', key.id);
			if (error) throw error;
			key.api_key = editing[key.id];
			saveSuccess[key.id] = true;
			setTimeout(() => { saveSuccess[key.id] = false; }, 2000);
		} catch (e: any) {
			saveError[key.id] = e.message || 'Save failed';
		} finally {
			saving[key.id] = false;
		}
	}

	async function toggleActive(key: any) {
		const { error } = await supabase
			.from('system_api_keys')
			.update({ is_active: !key.is_active })
			.eq('id', key.id);
		if (!error) key.is_active = !key.is_active;
		apiKeys = [...apiKeys];
	}

	async function addNewKey() {
		if (!newService.service_name.trim() || !newService.api_key.trim()) return;
		const { error } = await supabase
			.from('system_api_keys')
			.insert({ ...newService });
		if (!error) {
			newService = { service_name: '', api_key: '', description: '' };
			addingNew = false;
			await loadKeys();
		}
	}

	async function deleteKey(key: any) {
		if (!confirm(`Delete "${key.service_name}"?`)) return;
		await supabase.from('system_api_keys').delete().eq('id', key.id);
		await loadKeys();
	}

	function maskKey(key: string): string {
		if (!key) return '(empty)';
		if (key.length <= 8) return '●'.repeat(key.length);
		return key.substring(0, 4) + '●'.repeat(Math.min(key.length - 8, 20)) + key.substring(key.length - 4);
	}

	const serviceIcons: Record<string, string> = {
		google: '🌐',
		google_search_engine_id: '🔍',
		openai: '🤖',
	};
</script>

<div class="api-keys-manager">
	<!-- Header -->
	<div class="header">
		<div class="header-left">
			<span class="header-icon">🔑</span>
			<div>
				<h2 class="header-title">API Keys Manager</h2>
				<p class="header-subtitle">Manage all external service API keys from one place</p>
			</div>
		</div>
		<button class="btn-add" on:click={() => addingNew = !addingNew}>
			{addingNew ? '✕ Cancel' : '+ Add Key'}
		</button>
	</div>

	{#if globalError}
		<div class="error-banner">{globalError}</div>
	{/if}

	<!-- Add New Form -->
	{#if addingNew}
		<div class="add-form">
			<h3 class="add-form-title">Add New API Key</h3>
			<div class="add-form-grid">
				<div class="field">
					<label>Service Name</label>
					<input bind:value={newService.service_name} placeholder="e.g. stripe" class="input" />
				</div>
				<div class="field">
					<label>API Key / Value</label>
					<input bind:value={newService.api_key} placeholder="Enter key..." class="input" />
				</div>
				<div class="field full-width">
					<label>Description</label>
					<input bind:value={newService.description} placeholder="What is this key used for?" class="input" />
				</div>
			</div>
			<div class="add-form-actions">
				<button class="btn-save" on:click={addNewKey} disabled={!newService.service_name || !newService.api_key}>
					💾 Save New Key
				</button>
			</div>
		</div>
	{/if}

	<!-- Keys List -->
	{#if loading}
		<div class="loading">Loading API keys...</div>
	{:else if apiKeys.length === 0}
		<div class="empty">No API keys found</div>
	{:else}
		<div class="keys-list">
			{#each apiKeys as key (key.id)}
				<div class="key-card" class:inactive={!key.is_active}>
					<!-- Card Header -->
					<div class="card-header">
						<div class="service-info">
							<span class="service-icon">{serviceIcons[key.service_name] || '🔑'}</span>
							<div>
								<div class="service-name">{key.service_name}</div>
								<div class="service-desc">{key.description || 'No description'}</div>
							</div>
						</div>
						<div class="card-actions">
							<!-- Active toggle -->
							<button
								class="toggle-btn"
								class:active={key.is_active}
								on:click={() => toggleActive(key)}
								title={key.is_active ? 'Active — click to disable' : 'Inactive — click to enable'}
							>
								{key.is_active ? '✅ Active' : '⛔ Disabled'}
							</button>
							<button class="btn-delete" on:click={() => deleteKey(key)} title="Delete">🗑️</button>
						</div>
					</div>

					<!-- Key Input -->
					<div class="key-input-row">
						<div class="key-input-wrapper">
							{#if revealed[key.id]}
								<input
									class="key-input revealed"
									bind:value={editing[key.id]}
									placeholder="Enter API key..."
								/>
							{:else}
								<div class="key-masked">{maskKey(editing[key.id])}</div>
							{/if}
						</div>
						<button
							class="btn-icon"
							on:click={() => revealed[key.id] = !revealed[key.id]}
							title={revealed[key.id] ? 'Hide' : 'Reveal'}
						>
							{revealed[key.id] ? '🙈' : '👁️'}
						</button>
						<button
							class="btn-icon"
							on:click={() => { navigator.clipboard.writeText(editing[key.id]); }}
							title="Copy"
						>
							📋
						</button>
						<button
							class="btn-save-key"
							on:click={() => saveKey(key)}
							disabled={saving[key.id]}
						>
							{#if saving[key.id]}
								Saving...
							{:else if saveSuccess[key.id]}
								✅ Saved
							{:else}
								💾 Save
							{/if}
						</button>
					</div>

					{#if saveError[key.id]}
						<div class="save-error">{saveError[key.id]}</div>
					{/if}

					<div class="card-footer">
						Updated: {new Date(key.updated_at).toLocaleString()}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.api-keys-manager {
		padding: 1.5rem;
		background: #0f172a;
		min-height: 100%;
		color: #e2e8f0;
		font-family: inherit;
	}

	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.5rem;
		padding-bottom: 1rem;
		border-bottom: 1px solid #1e293b;
	}
	.header-left { display: flex; align-items: center; gap: 0.75rem; }
	.header-icon { font-size: 2rem; }
	.header-title { margin: 0; font-size: 1.25rem; font-weight: 700; color: #f1f5f9; }
	.header-subtitle { margin: 0; font-size: 0.8rem; color: #64748b; }

	.btn-add {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.5rem 1rem;
		font-size: 0.85rem;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}
	.btn-add:hover { background: #2563eb; }

	.error-banner {
		background: #7f1d1d;
		border: 1px solid #dc2626;
		border-radius: 8px;
		padding: 0.75rem 1rem;
		color: #fca5a5;
		margin-bottom: 1rem;
		font-size: 0.85rem;
	}

	.add-form {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 10px;
		padding: 1.25rem;
		margin-bottom: 1.5rem;
	}
	.add-form-title { margin: 0 0 1rem; font-size: 0.95rem; color: #94a3b8; font-weight: 600; }
	.add-form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
	.field { display: flex; flex-direction: column; gap: 0.35rem; }
	.field.full-width { grid-column: 1 / -1; }
	.field label { font-size: 0.78rem; color: #94a3b8; font-weight: 500; }
	.input {
		background: #0f172a;
		border: 1px solid #334155;
		border-radius: 6px;
		padding: 0.5rem 0.75rem;
		color: #e2e8f0;
		font-size: 0.85rem;
		outline: none;
	}
	.input:focus { border-color: #3b82f6; }
	.add-form-actions { margin-top: 0.75rem; display: flex; justify-content: flex-end; }
	.btn-save {
		background: #059669;
		color: white;
		border: none;
		border-radius: 7px;
		padding: 0.5rem 1.25rem;
		font-size: 0.85rem;
		cursor: pointer;
		font-weight: 600;
	}
	.btn-save:disabled { opacity: 0.5; cursor: not-allowed; }

	.loading, .empty {
		text-align: center;
		color: #64748b;
		padding: 3rem;
		font-size: 0.9rem;
	}

	.keys-list { display: flex; flex-direction: column; gap: 0.875rem; }

	.key-card {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 10px;
		padding: 1rem 1.25rem;
		transition: border-color 0.2s;
	}
	.key-card:hover { border-color: #475569; }
	.key-card.inactive { opacity: 0.6; border-color: #1e293b; }

	.card-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.875rem;
	}
	.service-info { display: flex; align-items: center; gap: 0.75rem; }
	.service-icon { font-size: 1.5rem; }
	.service-name { font-weight: 700; font-size: 0.95rem; color: #f1f5f9; text-transform: capitalize; }
	.service-desc { font-size: 0.78rem; color: #64748b; margin-top: 0.1rem; }

	.card-actions { display: flex; align-items: center; gap: 0.5rem; }

	.toggle-btn {
		background: #1e3a5f;
		color: #60a5fa;
		border: 1px solid #2563eb;
		border-radius: 6px;
		padding: 0.3rem 0.7rem;
		font-size: 0.75rem;
		cursor: pointer;
		font-weight: 600;
		transition: all 0.2s;
	}
	.toggle-btn.active {
		background: #052e16;
		color: #4ade80;
		border-color: #16a34a;
	}

	.btn-delete {
		background: transparent;
		border: 1px solid #7f1d1d;
		border-radius: 6px;
		padding: 0.3rem 0.5rem;
		cursor: pointer;
		font-size: 0.85rem;
		opacity: 0.6;
		transition: opacity 0.2s;
	}
	.btn-delete:hover { opacity: 1; background: #7f1d1d; }

	.key-input-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: #0f172a;
		border: 1px solid #334155;
		border-radius: 8px;
		padding: 0.4rem 0.5rem;
	}
	.key-input-wrapper { flex: 1; overflow: hidden; }
	.key-input {
		width: 100%;
		background: transparent;
		border: none;
		outline: none;
		color: #a3e635;
		font-family: 'Courier New', monospace;
		font-size: 0.85rem;
	}
	.key-masked {
		color: #475569;
		font-family: 'Courier New', monospace;
		font-size: 0.85rem;
		letter-spacing: 2px;
		padding: 0.1rem 0;
	}

	.btn-icon {
		background: transparent;
		border: none;
		cursor: pointer;
		font-size: 1rem;
		padding: 0.2rem;
		opacity: 0.7;
		transition: opacity 0.2s;
		flex-shrink: 0;
	}
	.btn-icon:hover { opacity: 1; }

	.btn-save-key {
		background: #1d4ed8;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.35rem 0.8rem;
		font-size: 0.78rem;
		cursor: pointer;
		font-weight: 600;
		white-space: nowrap;
		flex-shrink: 0;
		transition: background 0.2s;
		min-width: 70px;
	}
	.btn-save-key:hover { background: #1e40af; }
	.btn-save-key:disabled { opacity: 0.5; cursor: not-allowed; }

	.save-error {
		color: #fca5a5;
		font-size: 0.78rem;
		margin-top: 0.4rem;
	}

	.card-footer {
		font-size: 0.72rem;
		color: #334155;
		margin-top: 0.6rem;
		text-align: right;
	}
</style>
