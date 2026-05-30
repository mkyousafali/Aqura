<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { onMount } from 'svelte';

	interface HelperApp {
		id: string;
		app_name: string;
		file_name: string;
		file_path: string;
		file_size: number | null;
		file_type: string | null;
		created_at: string;
		updated_at: string;
	}

	let supabase: any = null;
	let apps: HelperApp[] = [];
	let loading = true;
	let globalError = '';
	let globalSuccess = '';

	// â”€â”€ Add form state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	let showAddForm = false;
	let newAppName = '';
	let newFileInput: HTMLInputElement;
	let newFile: File | null = null;
	let uploading = false;

	// â”€â”€ Per-row update state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	let updatingId: string | null = null;
	let updateFileInput: HTMLInputElement;
	let updateFile: File | null = null;
	let updateUploading = false;

	// â”€â”€ Per-row download state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	let downloadingId: string | null = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadApps();
	});

	// â”€â”€ Data loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	async function loadApps() {
		loading = true;
		globalError = '';
		try {
			const { data, error } = await supabase
				.from('helper_apps')
				.select('*')
				.order('created_at', { ascending: false });
			if (error) throw error;
			apps = data ?? [];
		} catch (e: any) {
			globalError = e.message ?? 'Failed to load helper apps';
		} finally {
			loading = false;
		}
	}

	// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	function formatSize(bytes: number | null): string {
		if (bytes == null) return 'â€”';
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1_048_576) return `${(bytes / 1024).toFixed(1)} KB`;
		if (bytes < 1_073_741_824) return `${(bytes / 1_048_576).toFixed(1)} MB`;
		return `${(bytes / 1_073_741_824).toFixed(2)} GB`;
	}

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString(undefined, {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getFileExt(mimeOrName: string | null): string {
		if (!mimeOrName) return 'â€”';
		// Try to derive a short label from mime type
		const parts = mimeOrName.split('/');
		return parts[parts.length - 1].toUpperCase().slice(0, 8);
	}

	// â”€â”€ Add App â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	async function addApp() {
		if (!newAppName.trim()) { globalError = 'App name is required.'; return; }
		if (!newFile) { globalError = 'Please select a file to upload.'; return; }

		uploading = true;
		globalError = '';
		globalSuccess = '';

		let insertedId: string | null = null;

		try {
			// 1. Insert DB record first (triggers RLS permission check)
			const { data: record, error: insertErr } = await supabase
				.from('helper_apps')
				.insert({
					app_name: newAppName.trim(),
					file_name: newFile.name,
					file_path: 'pending',
					file_size: newFile.size,
					file_type: newFile.type || 'application/octet-stream',
					created_by: $currentUser?.id,
					updated_by: $currentUser?.id
				})
				.select()
				.single();

			if (insertErr) throw insertErr;
			insertedId = record.id;

			const storagePath = `apps/${record.id}/file`;

			// 2. Upload file to private storage bucket
			const { error: uploadErr } = await supabase.storage
				.from('helper-apps')
				.upload(storagePath, newFile, { cacheControl: '3600', upsert: true });

			if (uploadErr) {
				// Rollback DB record
				await supabase.from('helper_apps').delete().eq('id', record.id);
				throw uploadErr;
			}

			// 3. Update file_path now that the upload succeeded
			const { error: patchErr } = await supabase
				.from('helper_apps')
				.update({ file_path: storagePath, updated_at: new Date().toISOString() })
				.eq('id', record.id);

			if (patchErr) throw patchErr;

			globalSuccess = `"${newAppName.trim()}" uploaded successfully.`;
			cancelAdd();
			await loadApps();
		} catch (e: any) {
			globalError = e.message ?? 'Upload failed. Please try again.';
		} finally {
			uploading = false;
		}
	}

	// â”€â”€ Download â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	async function downloadApp(app: HelperApp) {
		downloadingId = app.id;
		globalError = '';
		try {
			const { data, error } = await supabase.storage
				.from('helper-apps')
				.createSignedUrl(app.file_path, 3600, { download: app.file_name });
			if (error) throw error;
			window.open(data.signedUrl, '_blank');
		} catch (e: any) {
			globalError = e.message ?? 'Download failed.';
		} finally {
			downloadingId = null;
		}
	}

	// â”€â”€ Update (replace file) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	function startUpdate(app: HelperApp) {
		updatingId = app.id;
		updateFile = null;
		if (updateFileInput) updateFileInput.value = '';
	}

	async function confirmUpdate(app: HelperApp) {
		if (!updateFile) { globalError = 'Please select a new file.'; return; }

		updateUploading = true;
		globalError = '';
		globalSuccess = '';

		try {
			const storagePath = `apps/${app.id}/file`;

			// Replace file in storage (upsert overwrites)
			const { error: uploadErr } = await supabase.storage
				.from('helper-apps')
				.upload(storagePath, updateFile, { cacheControl: '3600', upsert: true });

			if (uploadErr) throw uploadErr;

			// Update DB metadata
			const { error: updateErr } = await supabase
				.from('helper_apps')
				.update({
					file_name: updateFile.name,
					file_size: updateFile.size,
					file_type: updateFile.type || 'application/octet-stream',
					updated_by: $currentUser?.id,
					updated_at: new Date().toISOString()
				})
				.eq('id', app.id);

			if (updateErr) throw updateErr;

			globalSuccess = `"${app.app_name}" file updated successfully.`;
			cancelUpdate();
			await loadApps();
		} catch (e: any) {
			globalError = e.message ?? 'Update failed. Please try again.';
		} finally {
			updateUploading = false;
		}
	}

	function cancelAdd() {
		showAddForm = false;
		newAppName = '';
		newFile = null;
		if (newFileInput) newFileInput.value = '';
		globalError = '';
	}

	function cancelUpdate() {
		updatingId = null;
		updateFile = null;
		if (updateFileInput) updateFileInput.value = '';
	}

	function toggleAddForm() {
		showAddForm = !showAddForm;
		globalError = '';
		globalSuccess = '';
		if (!showAddForm) { newAppName = ''; newFile = null; }
	}
</script>

<!-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• TEMPLATE â•â•â•â•â•â•â•â•â•â• -->
<div class="ha-root">

	<!-- â”€â”€ Header â”€â”€ -->
	<div class="ha-header">
		<div class="ha-title">
			<span class="ha-icon">ðŸ§©</span>
			<h2>{$t('nav.helperApps') || 'Helper Apps'}</h2>
		</div>
		<div class="ha-header-actions">
			<button class="ha-btn-refresh" on:click={loadApps} title="Refresh" disabled={loading}>
				<span class:spin={loading}>â†»</span>
			</button>
			<button class="ha-btn-add" on:click={toggleAddForm}>
				{showAddForm ? 'âœ• Cancel' : '+ Add App'}
			</button>
		</div>
	</div>

	<!-- â”€â”€ Global notices â”€â”€ -->
	{#if globalSuccess}
		<div class="ha-notice success">
			<span>âœ… {globalSuccess}</span>
			<button on:click={() => (globalSuccess = '')} aria-label="Dismiss">âœ•</button>
		</div>
	{/if}
	{#if globalError}
		<div class="ha-notice error">
			<span>âš ï¸ {globalError}</span>
			<button on:click={() => (globalError = '')} aria-label="Dismiss">âœ•</button>
		</div>
	{/if}

	<!-- â”€â”€ Add form â”€â”€ -->
	{#if showAddForm}
		<div class="ha-form-card">
			<div class="ha-form-header">
				<span class="ha-form-title">Upload New App / File</span>
			</div>
			<div class="ha-form-row">
				<div class="ha-field">
					<label for="ha-app-name">App / File Label</label>
					<input
						id="ha-app-name"
						type="text"
						bind:value={newAppName}
						placeholder="e.g. Branch Installer v2.1"
						disabled={uploading}
						maxlength="120"
					/>
				</div>
				<div class="ha-field">
					<label for="ha-file-input">Select File</label>
					<input
						id="ha-file-input"
						type="file"
						bind:this={newFileInput}
						on:change={(e) => {
							const inp = e.target as HTMLInputElement;
							newFile = inp.files?.[0] ?? null;
						}}
						disabled={uploading}
					/>
				</div>
			</div>

			{#if newFile}
				<div class="ha-file-preview">
					ðŸ“„ <strong>{newFile.name}</strong>
					<span class="ha-file-meta">â€” {formatSize(newFile.size)}</span>
					{#if newFile.type}
						<span class="ha-file-type">{newFile.type}</span>
					{/if}
				</div>
			{/if}

			<div class="ha-form-actions">
				<button class="ha-btn-upload" on:click={addApp} disabled={uploading}>
					{#if uploading}
						<span class="ha-spinner small"></span> Uploadingâ€¦
					{:else}
						â¬† Upload
					{/if}
				</button>
				<button class="ha-btn-cancel" on:click={cancelAdd} disabled={uploading}>
					Cancel
				</button>
			</div>
		</div>
	{/if}

	<!-- â”€â”€ Table â”€â”€ -->
	<div class="ha-table-wrap">
		{#if loading}
			<div class="ha-center-state">
				<span class="ha-spinner large"></span>
				<span>Loading helper appsâ€¦</span>
			</div>
		{:else if apps.length === 0}
			<div class="ha-center-state">
				<span class="ha-empty-icon">ðŸ—‚ï¸</span>
				<p>No helper apps yet.</p>
				<p class="ha-empty-sub">Click <strong>+ Add App</strong> to upload the first one.</p>
			</div>
		{:else}
			<table class="ha-table">
				<thead>
					<tr>
						<th>#</th>
						<th>App Name</th>
						<th>File Name</th>
						<th>Size</th>
						<th>Type</th>
						<th>Last Updated</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each apps as app, i}
						<tr class:ha-row-updating={updatingId === app.id}>
							<!-- # -->
							<td class="ha-cell-num">{i + 1}</td>

							<!-- App name -->
							<td class="ha-cell-name">{app.app_name}</td>

							<!-- File name -->
							<td class="ha-cell-filename" title={app.file_name}>{app.file_name}</td>

							<!-- Size -->
							<td class="ha-cell-size">{formatSize(app.file_size)}</td>

							<!-- Type -->
							<td class="ha-cell-type">{getFileExt(app.file_type)}</td>

							<!-- Date -->
							<td class="ha-cell-date">{formatDate(app.updated_at)}</td>

							<!-- Actions -->
							<td class="ha-cell-actions">
								{#if updatingId === app.id}
									<!-- Inline update row -->
									<div class="ha-update-inline">
										<input
											type="file"
											bind:this={updateFileInput}
											on:change={(e) => {
												const inp = e.target as HTMLInputElement;
												updateFile = inp.files?.[0] ?? null;
											}}
											disabled={updateUploading}
											class="ha-update-file-input"
										/>
										<button
											class="ha-btn-confirm"
											on:click={() => confirmUpdate(app)}
											disabled={updateUploading}
										>
											{#if updateUploading}
												<span class="ha-spinner small"></span>
											{:else}
												âœ“ Save
											{/if}
										</button>
										<button
											class="ha-btn-cancel-sm"
											on:click={cancelUpdate}
											disabled={updateUploading}
										>
											âœ•
										</button>
									</div>
								{:else}
									<button
										class="ha-btn-download"
										on:click={() => downloadApp(app)}
										disabled={downloadingId === app.id}
										title="Download latest file"
									>
										{#if downloadingId === app.id}
											<span class="ha-spinner small"></span>
										{:else}
											â¬‡ Download
										{/if}
									</button>
									<button
										class="ha-btn-update"
										on:click={() => startUpdate(app)}
										title="Replace with a new file"
									>
										ðŸ”„ Update
									</button>
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<!-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• STYLES â•â•â•â•â•â•â•â•â•â•â• -->
<style>
	/* â”€â”€ Root â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-root {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: linear-gradient(140deg, #f0f4ff 0%, #f5f0ff 45%, #fff0f8 100%);
		color: #1e293b;
		font-family: inherit;
		overflow: hidden;
	}

	/* â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 18px 24px 14px;
		background: rgba(255, 255, 255, 0.65);
		backdrop-filter: blur(14px);
		border-bottom: 1px solid rgba(139, 92, 246, 0.18);
		flex-shrink: 0;
	}

	.ha-title {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.ha-icon {
		font-size: 22px;
	}

	.ha-title h2 {
		margin: 0;
		font-size: 1.2rem;
		font-weight: 700;
		background: linear-gradient(90deg, #7c3aed 0%, #2563eb 50%, #db2777 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	.ha-header-actions {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.ha-btn-refresh {
		width: 34px;
		height: 34px;
		border-radius: 7px;
		border: 1px solid rgba(100, 116, 139, 0.2);
		background: rgba(241, 245, 249, 0.7);
		color: #64748b;
		font-size: 16px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}
	.ha-btn-refresh:hover:not(:disabled) {
		background: rgba(226, 232, 240, 0.9);
		color: #334155;
	}
	.ha-btn-refresh:disabled { opacity: 0.5; cursor: not-allowed; }

	.ha-btn-add {
		padding: 8px 18px;
		border-radius: 8px;
		border: 1px solid rgba(99, 102, 241, 0.4);
		background: linear-gradient(135deg, rgba(99, 102, 241, 0.12), rgba(139, 92, 246, 0.1));
		color: #4f46e5;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}
	.ha-btn-add:hover {
		background: linear-gradient(135deg, rgba(99, 102, 241, 0.22), rgba(139, 92, 246, 0.18));
		border-color: rgba(99, 102, 241, 0.65);
		color: #3730a3;
	}

	.spin {
		display: inline-block;
		animation: ha-spin 0.8s linear infinite;
	}

	/* â”€â”€ Notices â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-notice {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 9px 20px;
		margin: 12px 20px 0;
		border-radius: 8px;
		font-size: 0.875rem;
		flex-shrink: 0;
	}
	.ha-notice.success {
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.3);
		color: #047857;
	}
	.ha-notice.error {
		background: rgba(239, 68, 68, 0.08);
		border: 1px solid rgba(239, 68, 68, 0.25);
		color: #dc2626;
	}
	.ha-notice button {
		background: none;
		border: none;
		color: inherit;
		cursor: pointer;
		opacity: 0.55;
		padding: 0 4px;
		font-size: 13px;
		line-height: 1;
		flex-shrink: 0;
	}
	.ha-notice button:hover { opacity: 1; }

	/* â”€â”€ Add Form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-form-card {
		margin: 14px 20px 0;
		padding: 18px 20px;
		background: rgba(255, 255, 255, 0.75);
		backdrop-filter: blur(14px);
		border: 1px solid rgba(139, 92, 246, 0.2);
		border-radius: 12px;
		flex-shrink: 0;
		box-shadow: 0 2px 16px rgba(139, 92, 246, 0.08);
	}

	.ha-form-header {
		margin-bottom: 14px;
	}

	.ha-form-title {
		font-size: 0.85rem;
		font-weight: 600;
		color: #7c3aed;
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	.ha-form-row {
		display: flex;
		gap: 16px;
		flex-wrap: wrap;
	}

	.ha-field {
		display: flex;
		flex-direction: column;
		gap: 6px;
		flex: 1;
		min-width: 210px;
	}

	.ha-field label {
		font-size: 0.78rem;
		color: #64748b;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.ha-field input[type='text'] {
		padding: 9px 12px;
		border-radius: 7px;
		border: 1px solid rgba(100, 116, 139, 0.25);
		background: rgba(255, 255, 255, 0.85);
		color: #1e293b;
		font-size: 0.9rem;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
	}
	.ha-field input[type='text']:focus {
		border-color: rgba(99, 102, 241, 0.5);
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}
	.ha-field input[type='text']:disabled { opacity: 0.55; }

	.ha-field input[type='file'] {
		padding: 7px 10px;
		border-radius: 7px;
		border: 1px dashed rgba(139, 92, 246, 0.35);
		background: rgba(245, 243, 255, 0.6);
		color: #64748b;
		font-size: 0.85rem;
		cursor: pointer;
	}
	.ha-field input[type='file']::file-selector-button {
		background: rgba(99, 102, 241, 0.12);
		border: 1px solid rgba(99, 102, 241, 0.3);
		color: #4f46e5;
		border-radius: 5px;
		padding: 4px 10px;
		cursor: pointer;
		font-size: 0.8rem;
		margin-right: 8px;
		transition: background 0.2s;
	}
	.ha-field input[type='file']::file-selector-button:hover {
		background: rgba(99, 102, 241, 0.22);
	}
	.ha-field input[type='file']:disabled { opacity: 0.55; }

	.ha-file-preview {
		margin-top: 10px;
		padding: 8px 14px;
		background: rgba(245, 243, 255, 0.7);
		border-radius: 7px;
		font-size: 0.85rem;
		border: 1px solid rgba(139, 92, 246, 0.15);
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 8px;
		color: #6d28d9;
	}
	.ha-file-preview strong { color: #4f46e5; }
	.ha-file-meta { color: #94a3b8; }
	.ha-file-type {
		font-size: 0.75rem;
		padding: 2px 7px;
		border-radius: 4px;
		background: rgba(37, 99, 235, 0.08);
		border: 1px solid rgba(37, 99, 235, 0.2);
		color: #2563eb;
	}

	.ha-form-actions {
		display: flex;
		gap: 10px;
		margin-top: 14px;
	}

	.ha-btn-upload {
		padding: 8px 22px;
		border-radius: 7px;
		border: 1px solid rgba(219, 39, 119, 0.3);
		background: linear-gradient(135deg, rgba(219, 39, 119, 0.12), rgba(139, 92, 246, 0.1));
		color: #be185d;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		gap: 7px;
		transition: all 0.2s;
	}
	.ha-btn-upload:hover:not(:disabled) {
		background: linear-gradient(135deg, rgba(219, 39, 119, 0.2), rgba(139, 92, 246, 0.16));
		border-color: rgba(219, 39, 119, 0.5);
	}
	.ha-btn-upload:disabled { opacity: 0.5; cursor: not-allowed; }

	.ha-btn-cancel {
		padding: 8px 16px;
		border-radius: 7px;
		border: 1px solid rgba(100, 116, 139, 0.22);
		background: rgba(241, 245, 249, 0.7);
		color: #64748b;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
	}
	.ha-btn-cancel:hover:not(:disabled) { background: rgba(226, 232, 240, 0.9); color: #334155; }
	.ha-btn-cancel:disabled { opacity: 0.5; cursor: not-allowed; }

	/* â”€â”€ Table wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-table-wrap {
		flex: 1;
		overflow-y: auto;
		margin: 14px 20px 20px;
		border-radius: 12px;
		border: 1px solid rgba(100, 116, 139, 0.14);
		background: rgba(255, 255, 255, 0.6);
		backdrop-filter: blur(8px);
		box-shadow: 0 2px 16px rgba(99, 102, 241, 0.06);
	}

	/* â”€â”€ Table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.ha-table thead {
		position: sticky;
		top: 0;
		z-index: 2;
		background: rgba(248, 250, 252, 0.97);
		backdrop-filter: blur(10px);
	}

	.ha-table th {
		padding: 11px 14px;
		text-align: left;
		font-size: 0.73rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #94a3b8;
		border-bottom: 1px solid rgba(139, 92, 246, 0.14);
		white-space: nowrap;
	}

	.ha-table tbody tr {
		border-bottom: 1px solid rgba(226, 232, 240, 0.8);
		transition: background 0.15s;
	}
	.ha-table tbody tr:last-child { border-bottom: none; }
	.ha-table tbody tr:hover { background: rgba(239, 246, 255, 0.6); }
	.ha-table tbody tr.ha-row-updating { background: rgba(245, 243, 255, 0.7); }

	.ha-table td {
		padding: 11px 14px;
		vertical-align: middle;
	}

	.ha-cell-num {
		color: #cbd5e1;
		font-size: 0.78rem;
		width: 38px;
	}
	.ha-cell-name {
		font-weight: 600;
		color: #1e293b;
	}
	.ha-cell-filename {
		color: #64748b;
		font-family: monospace;
		font-size: 0.82rem;
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.ha-cell-size {
		color: #7c3aed;
		white-space: nowrap;
		font-weight: 500;
	}
	.ha-cell-type {
		font-family: monospace;
		font-size: 0.8rem;
		color: #2563eb;
		font-weight: 500;
	}
	.ha-cell-date {
		color: #94a3b8;
		font-size: 0.81rem;
		white-space: nowrap;
	}
	.ha-cell-actions {
		white-space: nowrap;
	}

	/* â”€â”€ Row action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-btn-download {
		padding: 5px 13px;
		border-radius: 6px;
		border: 1px solid rgba(37, 99, 235, 0.28);
		background: rgba(37, 99, 235, 0.07);
		color: #1d4ed8;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		margin-right: 6px;
		display: inline-flex;
		align-items: center;
		gap: 4px;
		transition: all 0.2s;
	}
	.ha-btn-download:hover:not(:disabled) {
		background: rgba(37, 99, 235, 0.14);
		border-color: rgba(37, 99, 235, 0.5);
	}
	.ha-btn-download:disabled { opacity: 0.5; cursor: not-allowed; }

	.ha-btn-update {
		padding: 5px 12px;
		border-radius: 6px;
		border: 1px solid rgba(219, 39, 119, 0.25);
		background: rgba(219, 39, 119, 0.07);
		color: #be185d;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		gap: 4px;
		transition: all 0.2s;
	}
	.ha-btn-update:hover {
		background: rgba(219, 39, 119, 0.14);
		border-color: rgba(219, 39, 119, 0.45);
	}

	/* â”€â”€ Inline update row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-update-inline {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-wrap: wrap;
	}

	.ha-update-file-input {
		padding: 4px 8px;
		border-radius: 6px;
		border: 1px dashed rgba(139, 92, 246, 0.35);
		background: rgba(245, 243, 255, 0.6);
		color: #64748b;
		font-size: 0.8rem;
		max-width: 220px;
	}
	.ha-update-file-input::file-selector-button {
		background: rgba(139, 92, 246, 0.1);
		border: 1px solid rgba(139, 92, 246, 0.3);
		color: #6d28d9;
		border-radius: 4px;
		padding: 3px 8px;
		font-size: 0.75rem;
		cursor: pointer;
		margin-right: 6px;
	}
	.ha-update-file-input:disabled { opacity: 0.5; }

	.ha-btn-confirm {
		padding: 5px 13px;
		border-radius: 6px;
		border: 1px solid rgba(5, 150, 105, 0.3);
		background: rgba(5, 150, 105, 0.08);
		color: #047857;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		gap: 4px;
		transition: all 0.2s;
	}
	.ha-btn-confirm:hover:not(:disabled) { background: rgba(5, 150, 105, 0.16); }
	.ha-btn-confirm:disabled { opacity: 0.5; cursor: not-allowed; }

	.ha-btn-cancel-sm {
		padding: 5px 10px;
		border-radius: 6px;
		border: 1px solid rgba(100, 116, 139, 0.2);
		background: rgba(241, 245, 249, 0.7);
		color: #64748b;
		font-size: 0.8rem;
		cursor: pointer;
		transition: all 0.2s;
	}
	.ha-btn-cancel-sm:hover:not(:disabled) { background: rgba(226, 232, 240, 0.9); color: #334155; }
	.ha-btn-cancel-sm:disabled { opacity: 0.5; cursor: not-allowed; }

	/* â”€â”€ Loading / Empty states â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-center-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 70px 20px;
		gap: 14px;
		text-align: center;
		color: #94a3b8;
	}

	.ha-empty-icon {
		font-size: 3rem;
		line-height: 1;
	}

	.ha-center-state p {
		margin: 0;
		font-size: 0.95rem;
		color: #94a3b8;
	}

	.ha-empty-sub {
		font-size: 0.85rem !important;
		color: #cbd5e1 !important;
	}
	.ha-empty-sub strong { color: #64748b; }

	/* â”€â”€ Spinner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-spinner {
		display: inline-block;
		border-radius: 50%;
		border: 2px solid rgba(139, 92, 246, 0.2);
		border-top-color: #7c3aed;
		animation: ha-spin 0.7s linear infinite;
		width: 16px;
		height: 16px;
		flex-shrink: 0;
	}
	.ha-spinner.large {
		width: 32px;
		height: 32px;
		border-width: 3px;
	}
	.ha-spinner.small {
		width: 12px;
		height: 12px;
	}

	@keyframes ha-spin {
		to { transform: rotate(360deg); }
	}

	/* â”€â”€ Custom scrollbar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */
	.ha-table-wrap::-webkit-scrollbar { width: 6px; }
	.ha-table-wrap::-webkit-scrollbar-track { background: transparent; }
	.ha-table-wrap::-webkit-scrollbar-thumb {
		background: rgba(139, 92, 246, 0.18);
		border-radius: 3px;
	}
	.ha-table-wrap::-webkit-scrollbar-thumb:hover {
		background: rgba(139, 92, 246, 0.32);
	}
</style>
