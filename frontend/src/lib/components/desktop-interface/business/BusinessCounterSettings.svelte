<script lang="ts">
	import { onDestroy, onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';
	import { iconUrlMap, icons, loading, error as iconError, loadIcons } from '$lib/stores/iconStore';
	import { supabase } from '$lib/utils/supabase';
	import { COFFEE_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';

	export let windowId: string;
	export let profile: BusinessCounterProfile = COFFEE_COUNTER;
	const logoKey = `${profile.id}-logo`;
	const localeKey = `${profile.localeKey}.logoSettings`;
	const imageTypes: Record<string, string> = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' };
	let selectedFile: File | null = null;
	let previewUrl = '';
	let saving = false;
	let message = '';
	let saved = false;
	let fileInput: HTMLInputElement;
	onMount(() => { void loadIcons(true); });
	onDestroy(() => { if (previewUrl) URL.revokeObjectURL(previewUrl); });

	function selectLogo(event: Event) {
		const file = (event.currentTarget as HTMLInputElement).files?.[0];
		if (previewUrl) URL.revokeObjectURL(previewUrl);
		previewUrl = '';
		selectedFile = null;
		message = '';
		saved = false;
		if (!file) return;
		if (!imageTypes[file.type] || file.size === 0 || file.size > 5 * 1024 * 1024) {
			message = $t(`${localeKey}.invalidFile`);
			return;
		}
		selectedFile = file;
		previewUrl = URL.createObjectURL(file);
	}

	async function saveLogo() {
		if (!selectedFile || saving || $loading) return;
		const file = selectedFile;
		const previousPath = $icons.find(icon => icon.icon_key === logoKey)?.storage_path;
		const path = `${logoKey}-${crypto.randomUUID()}.${imageTypes[file.type]}`;
		let uploaded = false;
		let committed = false;
		let phase: 'image' | 'upload' | 'save' = 'image';
		saving = true;
		message = '';
		saved = false;
		try {
			// Validate that the selected file can actually be displayed before saving it.
			const image = new Image();
			image.src = previewUrl;
			await image.decode();
			phase = 'upload';
			const { error: uploadError } = await supabase.storage.from('app-icons').upload(path, file, { contentType: file.type, upsert: false });
			if (uploadError) throw uploadError;
			uploaded = true;
			phase = 'save';
			const { error: saveError } = await supabase.rpc('upsert_app_icon', {
				p_icon_key: logoKey, p_name: $t(`${localeKey}.title`), p_category: 'logo',
				p_storage_path: path, p_mime_type: file.type, p_file_size: file.size,
				p_description: `Logo for the ${profile.id} window and launch button`
			});
			if (saveError) throw saveError;
			committed = true;
			await loadIcons(true);
			if ($iconError) {
				message = $t(`${localeKey}.savedReload`);
			} else {
				saved = true;
				selectedFile = null;
				if (previewUrl) URL.revokeObjectURL(previewUrl);
				previewUrl = '';
				if (fileInput) fileInput.value = '';
			}
			if (previousPath && previousPath !== path) {
				try { await supabase.storage.from('app-icons').remove([previousPath]); } catch { /* The new logo is already saved. */ }
			}
		} catch (error) {
			if (uploaded && !committed) {
				try { await supabase.storage.from('app-icons').remove([path]); } catch { /* Preserve the original save error. */ }
			}
			const status = Number((error as { status?: number; statusCode?: number })?.status || (error as { statusCode?: number })?.statusCode);
			message = $t(`${localeKey}.${status === 401 || status === 403 ? 'sessionFailed' : phase === 'image' ? 'invalidImage' : phase === 'upload' ? 'uploadFailed' : 'saveFailed'}`);
		} finally {
			saving = false;
		}
	}
</script>

<div class="settings">
	<h2>{$t(`${profile.localeKey}.settings`)}</h2>
	<h3>{$t(`${localeKey}.title`)}</h3>
	<p>{$t(`${localeKey}.description`)}</p>
	<div class="logo-preview">
		{#if previewUrl || $iconUrlMap[logoKey]}
			<img src={previewUrl || $iconUrlMap[logoKey]} alt={$t(`${localeKey}.title`)} />
		{:else}<span aria-hidden="true">{profile.icon}</span>{/if}
	</div>
	<input id={`${windowId}-counter-logo-file`} bind:this={fileInput} type="file" accept="image/png,image/jpeg,image/webp,image/gif" on:change={selectLogo} disabled={saving} />
	<div class="actions">
		<button type="button" on:click={() => fileInput?.click()} disabled={saving}>{$t(`${localeKey}.add`)}</button>
		<button type="button" class="save" on:click={saveLogo} disabled={!selectedFile || saving || $loading}>{$t(`${localeKey}.${saving ? 'saving' : 'save'}`)}</button>
	</div>
	<p class="hint">{$t(`${localeKey}.formats`)}</p>
	{#if saved}<p class="success" role="status">{$t(`${localeKey}.saved`)}</p>{/if}
	{#if message}<p class="error" role="alert">{message}</p>{/if}
	{#if $iconError && !message}<p class="error" role="alert">{$t(`${localeKey}.loadFailed`)} <button type="button" disabled={saving || $loading} on:click={() => loadIcons(true)}>{$t(`${localeKey}.retry`)}</button></p>{/if}
</div>

<style>
	.settings { height: 100%; overflow: auto; }
	h2 { margin: 0 0 24px; font-size: 20px; }
	h3 { margin: 0 0 8px; font-size: 16px; }
	p { color: #64748b; }
	.logo-preview { width: 160px; height: 160px; display: flex; align-items: center; justify-content: center; border: 1px solid #cbd5e1; border-radius: 12px; background: #f8fafc; margin: 20px 0; }
	.logo-preview img { max-width: 140px; max-height: 140px; object-fit: contain; }
	.logo-preview span { font-size: 64px; }
	input[type='file'] { display: none; }
	.actions { display: flex; flex-wrap: wrap; gap: 12px; }
	button { padding: 10px 16px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; color: #047857; cursor: pointer; font: inherit; }
	button.save { color: white; background: #047857; border-color: #047857; }
	button:disabled { opacity: .5; cursor: default; }
	button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.hint { font-size: 12px; }
	.success { color: #047857; }
	.error { color: #b91c1c; }
</style>
