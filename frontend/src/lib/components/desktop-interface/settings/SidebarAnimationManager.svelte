<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount, afterUpdate } from 'svelte';
	import { DotLottie } from '@lottiefiles/dotlottie-web';

	let supabase: any = null;
	let animations: any[] = [];
	let loading = true;
	let uploading = false;
	let error = '';
	let success = '';
	let previewUrl = '';
	let previewName = '';
	let previewCanvasEl: HTMLCanvasElement | null = null;
	let previewDotLottie: any = null;

	const BUCKET = 'sidebar-animations';
	const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadAnimations();
	});

	async function loadAnimations() {
		loading = true;
		error = '';
		try {
			const { data, error: err } = await supabase.rpc('list_sidebar_animations');
			if (err) throw err;
			animations = data || [];
		} catch (e: any) {
			error = e.message || 'Failed to load animations';
		} finally {
			loading = false;
		}
	}

	async function handleFileUpload(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;

		if (!file.name.endsWith('.lottie') && !file.name.endsWith('.json')) {
			error = 'Only .lottie or .json files are allowed';
			return;
		}

		uploading = true;
		error = '';
		success = '';

		try {
			const safeName = file.name.replace(/[^a-z0-9._-]/gi, '_');
			const filePath = `${Date.now()}_${safeName}`;

			const { error: uploadErr } = await supabase.storage
				.from(BUCKET)
				.upload(filePath, file, { upsert: false });

			if (uploadErr) throw uploadErr;

			const fileUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${filePath}`;
			const animName = file.name.replace(/\.(lottie|json)$/i, '');

			const { error: insertErr } = await supabase.rpc('insert_sidebar_animation', {
				anim_name: animName,
				anim_url: fileUrl
			});

			if (insertErr) throw insertErr;

			success = $t('animManager.uploadSuccess') || 'Animation uploaded successfully!';
			await loadAnimations();
		} catch (e: any) {
			error = e.message || 'Upload failed';
		} finally {
			uploading = false;
			input.value = '';
		}
	}

	async function setActive(id: string) {
		error = '';
		success = '';
		try {
			const { error: err } = await supabase.rpc('set_active_sidebar_animation', { animation_id: id });
			if (err) throw err;
			success = $t('animManager.setActiveSuccess') || 'Animation activated! Reload sidebar to apply.';
			await loadAnimations();
		} catch (e: any) {
			error = e.message || 'Failed to set active';
		}
	}

	async function deactivateAnimation(id: string) {
		error = '';
		success = '';
		try {
			const { error: err } = await supabase.rpc('deactivate_sidebar_animation', { animation_id: id });
			if (err) throw err;
			success = 'Animation deactivated.';
			await loadAnimations();
		} catch (e: any) {
			error = e.message || 'Failed to deactivate';
		}
	}

	async function deleteAnimation(anim: any) {
		if (!confirm(`Delete "${anim.name}"?`)) return;
		if (anim.is_active) {
			error = 'Cannot delete the active animation. Activate another first.';
			return;
		}
		error = '';
		success = '';
		try {
			// Extract storage path from URL
			const urlParts = anim.file_url.split(`/object/public/${BUCKET}/`);
			if (urlParts[1]) {
				await supabase.storage.from(BUCKET).remove([urlParts[1]]);
			}
			const { error: err } = await supabase.rpc('delete_sidebar_animation', { animation_id: anim.id });
			if (err) throw err;
			success = 'Animation deleted.';
			if (previewUrl === anim.file_url) previewUrl = '';
			await loadAnimations();
		} catch (e: any) {
			error = e.message || 'Delete failed';
		}
	}

	function showPreview(anim: any) {
		previewUrl = anim.file_url;
		previewName = anim.name;
		previewDotLottie?.destroy();
		previewDotLottie = null;
	}

	afterUpdate(() => {
		if (previewCanvasEl && previewUrl && !previewDotLottie) {
			try {
				previewDotLottie = new DotLottie({
					canvas: previewCanvasEl,
					src: previewUrl,
					loop: true,
					autoplay: true,
				});
			} catch (e) {
				console.error('Preview DotLottie error:', e);
			}
		}
		if (!previewUrl && previewDotLottie) {
			previewDotLottie.destroy();
			previewDotLottie = null;
		}
	});
</script>

<div class="anim-manager">
	<div class="manager-header">
		<div class="header-icon">🎭</div>
		<div>
			<h2 class="header-title">{$t('animManager.title') || 'Sidebar Animation Manager'}</h2>
			<p class="header-sub">{$t('animManager.subtitle') || 'Upload and manage the sidebar dancing character animation'}</p>
		</div>
	</div>

	{#if error}
		<div class="alert alert-error">{error}</div>
	{/if}
	{#if success}
		<div class="alert alert-success">{success}</div>
	{/if}

	<!-- Upload Section -->
	<div class="upload-section">
		<h3 class="section-title">{$t('animManager.uploadNew') || 'Upload New Animation'}</h3>
		<label class="upload-label" class:disabled={uploading}>
			<div class="upload-icon">📂</div>
			<div class="upload-text">
				{#if uploading}
					{$t('animManager.uploading') || 'Uploading...'}
				{:else}
					{$t('animManager.dropHere') || 'Click to select a .lottie or .json animation file'}
				{/if}
			</div>
			<input type="file" accept=".lottie,.json" on:change={handleFileUpload} disabled={uploading} />
		</label>
	</div>

	<!-- Animations List -->
	<div class="list-section">
		<h3 class="section-title">{$t('animManager.animations') || 'Animations'} ({animations.length})</h3>

		{#if loading}
			<div class="loading-state">Loading...</div>
		{:else if animations.length === 0}
			<div class="empty-state">{$t('animManager.noAnimations') || 'No animations uploaded yet.'}</div>
		{:else}
			<div class="anim-list">
				{#each animations as anim}
					<div class="anim-card" class:active-card={anim.is_active}>
						<div class="anim-info">
							<div class="anim-name">
								{anim.name}
								{#if anim.is_active}
									<span class="active-badge">{$t('animManager.active') || 'Active'}</span>
								{/if}
							</div>
							<div class="anim-date">
								{new Date(anim.uploaded_at).toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
							</div>
						</div>
						<div class="anim-actions">
							<button class="btn-preview" on:click={() => showPreview(anim)} title="Preview">
								👁️        
							</button>
							{#if anim.is_active}
								<button class="btn-deactivate" on:click={() => deactivateAnimation(anim.id)}>
									{$t('animManager.deactivate') || 'Deactivate'}
								</button>
							{:else}
								<button class="btn-activate" on:click={() => setActive(anim.id)}>
									{$t('animManager.activate') || 'Activate'}
								</button>
							{/if}
							<button class="btn-delete" on:click={() => deleteAnimation(anim)} title="Delete">🗑️</button>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Preview Panel -->
	{#if previewUrl}
		<div class="preview-panel">
			<div class="preview-header">
				<span>{$t('animManager.preview') || 'Preview'}: {previewName}</span>
				<button class="close-preview" on:click={() => { previewUrl = ''; previewName = ''; }}>✕</button>
			</div>
			<div class="preview-body">
				<canvas bind:this={previewCanvasEl} width="180" height="180" style="width:180px;height:180px;"></canvas>
			</div>
		</div>
	{/if}
</div>

<style>
	.anim-manager {
		padding: 24px;
		background: linear-gradient(135deg, #fdf4ff 0%, #fef9ff 40%, #f0fdf4 100%);
		min-height: 100%;
		color: #3b1f4e;
		font-family: 'Segoe UI', sans-serif;
	}

	.manager-header {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e9d5f7;
	}

	.header-icon {
		font-size: 2.5rem;
	}

	.header-title {
		font-size: 1.4rem;
		font-weight: 700;
		color: #7c3aed;
		margin: 0 0 4px;
	}

	.header-sub {
		font-size: 0.85rem;
		color: #9d6ec7;
		margin: 0;
	}

	.alert {
		padding: 10px 16px;
		border-radius: 8px;
		margin-bottom: 16px;
		font-size: 0.9rem;
	}

	.alert-error {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid rgba(239, 68, 68, 0.35);
		color: #b91c1c;
	}

	.alert-success {
		background: rgba(34, 197, 94, 0.1);
		border: 1px solid rgba(34, 197, 94, 0.4);
		color: #15803d;
	}

	.section-title {
		font-size: 1rem;
		font-weight: 700;
		color: #7c3aed;
		margin: 0 0 12px;
	}

	.upload-section {
		background: rgba(255, 255, 255, 0.75);
		border: 1px solid #e9d5f7;
		border-radius: 14px;
		padding: 20px;
		margin-bottom: 24px;
		box-shadow: 0 2px 12px rgba(167, 139, 250, 0.1);
	}

	.upload-label {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 10px;
		padding: 32px;
		border: 2px dashed #c4b5fd;
		border-radius: 10px;
		cursor: pointer;
		transition: border-color 0.2s, background 0.2s;
	}

	.upload-label:hover:not(.disabled) {
		border-color: #7c3aed;
		background: rgba(167, 139, 250, 0.08);
	}

	.upload-label.disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.upload-icon {
		font-size: 2rem;
	}

	.upload-text {
		color: #9d6ec7;
		font-size: 0.9rem;
		text-align: center;
	}

	.upload-label input[type="file"] {
		display: none;
	}

	.list-section {
		background: rgba(255, 255, 255, 0.75);
		border: 1px solid #e9d5f7;
		border-radius: 14px;
		padding: 20px;
		margin-bottom: 24px;
		box-shadow: 0 2px 12px rgba(167, 139, 250, 0.1);
	}

	.loading-state,
	.empty-state {
		text-align: center;
		color: #a78bca;
		padding: 32px;
		font-size: 0.9rem;
	}

	.anim-list {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.anim-card {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #faf5ff;
		border: 1px solid #ddd6fe;
		border-radius: 10px;
		padding: 14px 16px;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.anim-card:hover {
		box-shadow: 0 2px 10px rgba(139, 92, 246, 0.12);
	}

	.anim-card.active-card {
		border-color: #4ade80;
		background: rgba(240, 253, 244, 0.9);
		box-shadow: 0 2px 12px rgba(74, 222, 128, 0.15);
	}

	.anim-info {
		flex: 1;
	}

	.anim-name {
		font-size: 0.95rem;
		font-weight: 600;
		color: #4c1d95;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.active-badge {
		background: rgba(74, 222, 128, 0.2);
		color: #15803d;
		font-size: 0.7rem;
		font-weight: 700;
		padding: 2px 8px;
		border-radius: 20px;
		border: 1px solid rgba(74, 222, 128, 0.5);
	}

	.anim-date {
		font-size: 0.75rem;
		color: #a78bca;
		margin-top: 4px;
	}

	.anim-actions {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn-preview {
		background: #ede9fe;
		border: 1px solid #c4b5fd;
		border-radius: 6px;
		padding: 6px 10px;
		cursor: pointer;
		font-size: 1rem;
		transition: background 0.2s;
	}

	.btn-preview:hover {
		background: #ddd6fe;
	}

	.btn-activate {
		background: rgba(167, 139, 250, 0.15);
		border: 1px solid rgba(139, 92, 246, 0.4);
		color: #6d28d9;
		border-radius: 6px;
		padding: 6px 14px;
		font-size: 0.82rem;
		font-weight: 700;
		cursor: pointer;
		transition: background 0.2s;
	}

	.btn-activate:hover {
		background: rgba(139, 92, 246, 0.25);
	}

	.btn-deactivate {
		background: rgba(251, 191, 210, 0.25);
		border: 1px solid rgba(244, 114, 182, 0.45);
		color: #be185d;
		border-radius: 6px;
		padding: 6px 14px;
		font-size: 0.82rem;
		font-weight: 700;
		cursor: pointer;
		transition: background 0.2s;
	}

	.btn-deactivate:hover {
		background: rgba(244, 114, 182, 0.3);
	}

	.btn-delete {
		background: rgba(254, 202, 202, 0.3);
		border: 1px solid rgba(239, 68, 68, 0.3);
		border-radius: 6px;
		padding: 6px 10px;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.btn-delete:hover {
		background: rgba(239, 68, 68, 0.2);
	}

	.preview-panel {
		background: rgba(255, 255, 255, 0.8);
		border: 1px solid #e9d5f7;
		border-radius: 14px;
		overflow: hidden;
		box-shadow: 0 2px 12px rgba(167, 139, 250, 0.1);
	}

	.preview-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		background: linear-gradient(90deg, #ede9fe, #fce7f3);
		font-size: 0.9rem;
		color: #6d28d9;
		font-weight: 700;
	}

	.close-preview {
		background: none;
		border: none;
		color: #a78bca;
		cursor: pointer;
		font-size: 1rem;
		padding: 2px 6px;
	}

	.close-preview:hover {
		color: #7c3aed;
	}

	.preview-body {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 24px;
		gap: 16px;
	}

	.preview-note {
		font-size: 0.75rem;
		color: #a78bca;
		text-align: center;
		max-width: 400px;
	}
</style>
