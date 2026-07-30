<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';

	let supabase: any = null;
	let loading = true;
	let saving = false;
	let globalError = '';
	let saveSuccess = false;

	let statusRows: Array<{ secret_name: string; is_set: boolean; updated_at: string | null }> = [];

	// Write-only fields — never pre-filled from the server
	let supabaseUrl = '';
	let anonKey = '';
	let serviceRoleKey = '';
	let revealServiceRole = false;
	let revealAnon = false;

	const labels: Record<string, string> = {
		supabase_url: 'Supabase URL',
		anon_key: 'Anon Key',
		service_role_key: 'Service Role Key'
	};

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadStatus();
	});

	async function loadStatus() {
		loading = true;
		globalError = '';
		try {
			const { data, error } = await supabase.functions.invoke('admin-secrets-manager', {
				body: { action: 'status', user_id: $currentUser?.id }
			});
			if (error) throw error;
			if (data?.error) throw new Error(data.error);
			statusRows = data?.secrets || [];
		} catch (e: any) {
			globalError = e.message || 'Failed to load secret status';
		} finally {
			loading = false;
		}
	}

	async function saveSecrets() {
		saving = true;
		globalError = '';
		saveSuccess = false;
		try {
			const secrets: Record<string, string> = {};
			if (supabaseUrl.trim()) secrets.supabase_url = supabaseUrl.trim();
			if (anonKey.trim()) secrets.anon_key = anonKey.trim();
			if (serviceRoleKey.trim()) secrets.service_role_key = serviceRoleKey.trim();

			if (Object.keys(secrets).length === 0) {
				globalError = 'Enter at least one value to save';
				return;
			}

			const { data, error } = await supabase.functions.invoke('admin-secrets-manager', {
				body: { action: 'save', user_id: $currentUser?.id, secrets }
			});
			if (error) throw error;
			if (data?.error) throw new Error(data.error);

			// Clear fields immediately — nothing is kept in the UI after saving
			supabaseUrl = '';
			anonKey = '';
			serviceRoleKey = '';
			saveSuccess = true;
			setTimeout(() => { saveSuccess = false; }, 2500);
			await loadStatus();
		} catch (e: any) {
			globalError = e.message || 'Save failed';
		} finally {
			saving = false;
		}
	}

	function statusFor(name: string) {
		return statusRows.find((r) => r.secret_name === name);
	}
</script>

<div class="secrets-manager">
	<div class="header">
		<div class="header-left">
			<span class="header-icon">🔐</span>
			<div>
				<h2 class="header-title">Supabase Secrets Manager</h2>
				<p class="header-subtitle">Stores values only in Supabase Vault (encrypted) — never in a plain table</p>
			</div>
		</div>
	</div>

	{#if globalError}
		<div class="error-banner">{globalError}</div>
	{/if}
	{#if saveSuccess}
		<div class="success-banner">✅ Saved to Vault successfully</div>
	{/if}

	<!-- Status -->
	<div class="status-card">
		<h3 class="section-title">Current Status</h3>
		{#if loading}
			<div class="loading">Loading status...</div>
		{:else}
			<div class="status-list">
				{#each ['supabase_url', 'anon_key', 'service_role_key'] as name}
					{@const row = statusFor(name)}
					<div class="status-row">
						<span class="status-name">{labels[name]}</span>
						<span class="status-badge" class:set={row?.is_set}>
							{row?.is_set ? '✅ Set' : '⛔ Not set'}
						</span>
						{#if row?.is_set && row?.updated_at}
							<span class="status-time">Updated: {new Date(row.updated_at).toLocaleString()}</span>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Update form -->
	<div class="form-card">
		<h3 class="section-title">Update Secrets</h3>
		<p class="form-hint">Leave a field blank to keep its current value unchanged. Values are write-only and are never displayed after saving.</p>

		<div class="field">
			<label>Supabase URL</label>
			<input class="input" bind:value={supabaseUrl} placeholder="https://your-project.supabase.co or internal URL" />
		</div>

		<div class="field">
			<label>Anon Key</label>
			<div class="input-row">
				{#if revealAnon}
					<input class="input" bind:value={anonKey} placeholder="Enter anon key..." />
				{:else}
					<input class="input" type="password" bind:value={anonKey} placeholder="Enter anon key..." />
				{/if}
				<button class="btn-icon" on:click={() => revealAnon = !revealAnon} title={revealAnon ? 'Hide' : 'Reveal'}>
					{revealAnon ? '🙈' : '👁️'}
				</button>
			</div>
		</div>

		<div class="field">
			<label>Service Role Key</label>
			<div class="input-row">
				{#if revealServiceRole}
					<input class="input" bind:value={serviceRoleKey} placeholder="Enter service role key..." />
				{:else}
					<input class="input" type="password" bind:value={serviceRoleKey} placeholder="Enter service role key..." />
				{/if}
				<button class="btn-icon" on:click={() => revealServiceRole = !revealServiceRole} title={revealServiceRole ? 'Hide' : 'Reveal'}>
					{revealServiceRole ? '🙈' : '👁️'}
				</button>
			</div>
		</div>

		<div class="form-actions">
			<button class="btn-save" on:click={saveSecrets} disabled={saving}>
				{saving ? 'Saving...' : '💾 Save to Vault'}
			</button>
		</div>
	</div>
</div>

<style>
	.secrets-manager {
		padding: 1.5rem;
		background: #f8fafc;
		min-height: 100%;
		color: #1e293b;
		font-family: inherit;
	}

	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.5rem;
		padding-bottom: 1rem;
		border-bottom: 1px solid #e2e8f0;
	}
	.header-left { display: flex; align-items: center; gap: 0.75rem; }
	.header-icon { font-size: 2rem; }
	.header-title { margin: 0; font-size: 1.25rem; font-weight: 700; color: #0f172a; }
	.header-subtitle { margin: 0; font-size: 0.8rem; color: #64748b; }

	.error-banner {
		background: #fee2e2;
		color: #991b1b;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		margin-bottom: 1rem;
		font-size: 0.85rem;
		border: 1px solid #fecaca;
	}
	.success-banner {
		background: #dcfce7;
		color: #166534;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		margin-bottom: 1rem;
		font-size: 0.85rem;
		border: 1px solid #bbf7d0;
	}

	.status-card, .form-card {
		background: #ffffff;
		border: 1px solid #e2e8f0;
		border-radius: 10px;
		padding: 1.25rem;
		margin-bottom: 1.25rem;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
	}

	.section-title {
		margin: 0 0 0.75rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #0f172a;
	}

	.form-hint {
		margin: 0 0 1rem 0;
		font-size: 0.8rem;
		color: #64748b;
	}

	.loading { color: #64748b; font-size: 0.85rem; }

	.status-list { display: flex; flex-direction: column; gap: 0.5rem; }
	.status-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.5rem 0.75rem;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
	}
	.status-name { flex: 1; font-size: 0.85rem; font-weight: 500; color: #1e293b; }
	.status-badge {
		font-size: 0.75rem;
		padding: 0.2rem 0.6rem;
		border-radius: 999px;
		background: #fee2e2;
		color: #991b1b;
	}
	.status-badge.set { background: #dcfce7; color: #166534; }
	.status-time { font-size: 0.7rem; color: #94a3b8; }

	.field { margin-bottom: 1rem; }
	.field label {
		display: block;
		font-size: 0.8rem;
		font-weight: 500;
		color: #475569;
		margin-bottom: 0.35rem;
	}
	.input {
		width: 100%;
		box-sizing: border-box;
		background: #ffffff;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		padding: 0.55rem 0.75rem;
		color: #1e293b;
		font-size: 0.85rem;
	}
	.input:focus { outline: none; border-color: #3b82f6; }

	.input-row { display: flex; gap: 0.5rem; align-items: center; }
	.input-row .input { flex: 1; }

	.btn-icon {
		background: #f1f5f9;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		padding: 0.5rem 0.7rem;
		cursor: pointer;
		font-size: 0.9rem;
	}
	.btn-icon:hover { background: #e2e8f0; }

	.form-actions { margin-top: 1.25rem; }
	.btn-save {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.6rem 1.25rem;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
	}
	.btn-save:hover { background: #2563eb; }
	.btn-save:disabled { background: #cbd5e1; cursor: not-allowed; }
</style>
