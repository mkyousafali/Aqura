<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { mobileThemeStore, extractColors, type MobileTheme, type MobileThemeColors } from '$lib/stores/mobileThemeStore';
	import { localeData } from '$lib/i18n';

	let themes: MobileTheme[] = [];
	let currentUserThemeId: number | null = null;
	let loading = true;
	let selectedTheme: MobileTheme | null = null;
	let editingTheme: any = null;
	let editingColors: any = null;
	let showColorEditor = false;
	let isSaving = false;
	let toastMessage = '';
	let toastVisible = false;

	const isRTL = $localeData.code === 'ar';

	function getTranslation(key: string): string {
		const data = $localeData;
		if (!data?.translations) return key;
		const keys = key.split('.');
		let current: any = data.translations;
		for (const k of keys) {
			if (current && typeof current === 'object' && k in current) {
				current = current[k];
			} else {
				return key;
			}
		}
		return typeof current === 'string' ? current : key;
	}

	onMount(async () => {
		await loadThemes();
		await loadUserThemeAssignment();
	});

	async function loadThemes() {
		try {
			const { data, error } = await supabase
				.from('mobile_themes')
				.select('*')
				.order('is_default', { ascending: false })
				.order('name');

			if (error) throw error;

			themes = (data || []).map(theme => ({
				...theme,
				colors: typeof theme.colors === 'string' ? JSON.parse(theme.colors) : theme.colors
			}));

			loading = false;
		} catch (error) {
			console.error('❌ Error loading themes:', error);
			showToastMessage(isRTL ? 'خطأ في تحميل المواضيع' : 'Error loading themes');
			loading = false;
		}
	}

	async function loadUserThemeAssignment() {
		try {
			const userId = $currentUser?.id;
			if (!userId) return;

			const { data, error } = await supabase
				.from('user_mobile_theme_assignments')
				.select('theme_id')
				.eq('user_id', userId)
				.maybeSingle();

			if (error && error.code !== 'PGRST116') throw error;
			currentUserThemeId = data?.theme_id || null;
		} catch (error) {
			console.error('❌ Error loading user theme assignment:', error);
		}
	}

	function showToastMessage(msg: string) {
		toastMessage = msg;
		toastVisible = true;
		setTimeout(() => {
			toastVisible = false;
		}, 3000);
	}

	async function saveTheme(theme: MobileTheme) {
		try {
			isSaving = true;
			const userId = $currentUser?.id;
			if (!userId) {
				showToastMessage(isRTL ? 'يجب أن تكون مسجل الدخول' : 'You must be logged in');
				return;
			}

			// Use upsert for safer insert/update
			const { error } = await supabase
				.from('user_mobile_theme_assignments')
				.upsert(
					{ user_id: userId, theme_id: theme.id },
					{ onConflict: 'user_id' }
				);

			if (error) throw error;

			currentUserThemeId = theme.id;
			mobileThemeStore.preview(theme.colors);

			showToastMessage(isRTL ? 'تم حفظ المظهر بنجاح' : 'Theme saved successfully');
		} catch (error) {
			console.error('❌ Error saving theme:', error);
			showToastMessage(isRTL ? 'خطأ في حفظ المظهر' : 'Error saving theme');
		} finally {
			isSaving = false;
		}
	}

	function openColorEditor(theme: MobileTheme) {
		selectedTheme = theme;
		editingTheme = JSON.parse(JSON.stringify(theme));
		editingColors = JSON.parse(JSON.stringify(theme.colors));
		showColorEditor = true;
		// Apply preview immediately
		mobileThemeStore.preview(editingColors);
	}

	function closeColorEditor() {
		showColorEditor = false;
		selectedTheme = null;
		editingTheme = null;
		editingColors = null;
		// Reset to current user theme if not saved
		if (currentUserThemeId) {
			const currentTheme = themes.find(t => t.id === currentUserThemeId);
			if (currentTheme) {
				mobileThemeStore.preview(currentTheme.colors);
			}
		}
	}

	async function saveEditedTheme() {
		try {
			isSaving = true;
			if (!editingTheme || !editingColors) return;

			const { error } = await supabase
				.from('mobile_themes')
				.update({
					colors: editingColors,
					updated_at: new Date().toISOString()
				})
				.eq('id', editingTheme.id);

			if (error) throw error;

			// Reload themes
			await loadThemes();
			
			// If this is user's current theme, apply it
			if (currentUserThemeId === editingTheme.id) {
				mobileThemeStore.preview(editingColors);
			}

			showToastMessage(isRTL ? 'تم حفظ المظهر بنجاح' : 'Theme saved successfully');
			closeColorEditor();
		} catch (error) {
			console.error('❌ Error saving edited theme:', error);
			showToastMessage(isRTL ? 'خطأ في حفظ التغييرات' : 'Error saving changes');
		} finally {
			isSaving = false;
		}
	}

	function updateColor(key: string, value: string) {
		if (editingColors) {
			editingColors[key] = value;
			// Live preview
			mobileThemeStore.preview(editingColors);
		}
	}
</script>

<svelte:head>
	<title>{isRTL ? 'مدير المواضيع' : 'Theme Manager'} - Aqura</title>
</svelte:head>

<div class="theme-manager-page" dir={isRTL ? 'rtl' : 'ltr'}>
	{#if loading}
		<div class="loading-container">
			<div class="spinner"></div>
			<p>{isRTL ? 'جاري التحميل...' : 'Loading...'}</p>
		</div>
	{:else}
		<div class="content">
			<div class="themes-list">
				{#each themes as theme (theme.id)}
					<div class="theme-item" class:active={currentUserThemeId === theme.id}>
						<div class="theme-header">
							<div class="theme-name-section">
								<h3 class="theme-name">{theme.name}</h3>
								{#if theme.is_default}
									<span class="badge-default">{isRTL ? 'افتراضي' : 'Default'}</span>
								{/if}
							</div>
							{#if currentUserThemeId === theme.id}
								<span class="badge-active">{isRTL ? 'مفعل' : 'Active'}</span>
							{/if}
						</div>

						{#if theme.description}
							<p class="theme-description">{theme.description}</p>
						{/if}

						<div class="theme-colors">
							<div class="color-row">
								{#each Object.entries(theme.colors).slice(0, 4) as [key, value]}
									<div class="color-box" style="background-color: {value};" title={key}></div>
								{/each}
							</div>
						</div>

						<div class="theme-actions">
							<button 
								class="btn-edit" 
								on:click={() => openColorEditor(theme)}
								disabled={isSaving}
								title={isRTL ? 'تعديل الألوان' : 'Edit Colors'}>
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M12 20h9M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19H4v-3L16.5 3.5z"/>
								</svg>
								{isRTL ? 'تعديل' : 'Edit'}
							</button>
							<button 
								class="btn-use" 
								class:active={currentUserThemeId === theme.id}
								on:click={() => saveTheme(theme)}
								disabled={isSaving || currentUserThemeId === theme.id}
								title={isRTL ? 'استخدام' : 'Use'}>
								{#if isSaving}
									<span class="spinner-mini"></span>
								{:else}
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<polyline points="20 6 9 17 4 12"/>
									</svg>
								{/if}
								{currentUserThemeId === theme.id 
									? (isRTL ? 'قيد الاستخدام' : 'In Use')
									: (isRTL ? 'استخدم' : 'Use')}
							</button>
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Color Editor Modal -->
	{#if showColorEditor && editingTheme}
		<div class="modal-overlay" on:click={closeColorEditor}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
					<h2>{editingTheme.name}</h2>
					<button class="close-btn" on:click={closeColorEditor} title={isRTL ? 'إغلاق' : 'Close'}>
						<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<line x1="18" y1="6" x2="6" y2="18"/>
							<line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
					</button>
				</div>

				<div class="modal-body">
					<div class="color-grid">
						{#each Object.entries(editingColors) as [key, value]}
							<div class="color-input-item">
								<label for="color-{key}">{key.replace(/_/g, ' ')}</label>
								<input 
									id="color-{key}"
									type="color" 
									value={value}
									on:input={(e) => updateColor(key, e.target.value)}
									on:change={(e) => updateColor(key, e.target.value)}
									class="color-input"
								/>
								<code>{value}</code>
							</div>
						{/each}
					</div>
				</div>

				<div class="modal-footer">
					<button 
						class="btn-save" 
						on:click={saveEditedTheme}
						disabled={isSaving}>
						{isRTL ? 'حفظ التغييرات' : 'Save Changes'}
					</button>
					<button 
						class="btn-cancel" 
						on:click={closeColorEditor}>
						{isRTL ? 'إغلاق' : 'Close'}
					</button>
				</div>
			</div>
		</div>
	{/if}

	{#if toastVisible}
		<div class="toast" class:visible={toastVisible}>
			{toastMessage}
		</div>
	{/if}
</div>

<style>
	.theme-manager-page {
		display: flex;
		flex-direction: column;
		height: 100vh;
		background: var(--theme-bg-primary, #ffffff);
		overflow: auto;
	}

	.content {
		flex: 1;
		overflow-y: auto;
		padding: 1rem;
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 1rem;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid rgba(0, 0, 0, 0.1);
		border-top-color: var(--theme-accent-primary, #0066b2);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.themes-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.theme-item {
		background: var(--theme-card-bg, #ffffff);
		border: 1px solid var(--theme-card-border, #e5e7eb);
		border-radius: 0.5rem;
		padding: 1rem;
		transition: all 0.2s ease;
	}

	.theme-item:active {
		background: rgba(0, 102, 178, 0.05);
	}

	.theme-item.active {
		border-color: var(--theme-accent-primary, #0066b2);
		border-width: 2px;
	}

	.theme-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.5rem;
		gap: 0.75rem;
	}

	.theme-name-section {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		min-width: 0;
	}

	.theme-name {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: var(--theme-text-primary, #0b1220);
	}

	.badge-default,
	.badge-active {
		display: inline-flex;
		align-items: center;
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.badge-default {
		background: rgba(0, 102, 178, 0.1);
		color: var(--theme-accent-primary, #0066b2);
	}

	.badge-active {
		background: rgba(16, 185, 129, 0.1);
		color: #10b981;
	}

	.theme-description {
		margin: 0.5rem 0;
		font-size: 0.85rem;
		color: var(--theme-text-secondary, #6b7280);
		line-height: 1.4;
	}

	.theme-colors {
		margin: 0.75rem 0;
	}

	.color-row {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.color-box {
		width: 32px;
		height: 32px;
		border-radius: 0.375rem;
		border: 1px solid rgba(0, 0, 0, 0.1);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
	}

	.theme-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 1rem;
	}

	.btn-edit,
	.btn-use {
		flex: 1;
		padding: 0.5rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.8rem;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		transition: all 0.2s ease;
	}

	.btn-edit {
		background: var(--theme-button-secondary-bg, #e5e7eb);
		color: var(--theme-text-primary, #0b1220);
	}

	.btn-edit:active {
		background: var(--theme-button-secondary-hover, #d1d5db);
	}

	.btn-use {
		background: var(--theme-accent-primary, #0066b2);
		color: #ffffff;
	}

	.btn-use:active {
		background: #004d8c;
	}

	.btn-use.active,
	.btn-edit:disabled,
	.btn-use:disabled {
		opacity: 0.5;
	}

	.spinner-mini {
		display: inline-block;
		width: 12px;
		height: 12px;
		border: 2px solid currentColor;
		border-top-color: transparent;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	/* Modal */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: calc(100vh - 60px);
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: flex-end;
		z-index: 50000;
		animation: fadeIn 0.2s ease;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.modal-content {
		background: var(--theme-card-bg, #ffffff);
		width: 100%;
		max-height: calc(100vh - 220px);
		overflow-y: auto;
		border-radius: 1rem 1rem 0 0;
		display: flex;
		flex-direction: column;
		box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.15);
		padding-bottom: 1rem;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		border-bottom: 1px solid var(--theme-card-border, #e5e7eb);
		flex-shrink: 0;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.125rem;
		color: var(--theme-text-primary, #0b1220);
	}

	.close-btn {
		background: none;
		border: none;
		color: var(--theme-text-primary, #0b1220);
		cursor: pointer;
		padding: 0.5rem;
		display: flex;
		align-items: center;
	}

	.modal-body {
		flex: 1;
		overflow-y: auto;
		padding: 1rem;
	}

	.color-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 1rem;
	}

	.color-input-item {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.color-input-item label {
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--theme-text-primary, #0b1220);
		text-transform: capitalize;
	}

	.color-input {
		width: 100%;
		height: 40px;
		border: 1px solid var(--theme-card-border, #e5e7eb);
		border-radius: 0.375rem;
		cursor: pointer;
	}

	.color-input-item code {
		font-size: 0.7rem;
		color: var(--theme-text-secondary, #6b7280);
		font-family: monospace;
		word-break: break-all;
	}

	.modal-footer {
		display: flex;
		gap: 0.75rem;
		padding: 1rem;
		border-top: 1px solid var(--theme-card-border, #e5e7eb);
		flex-shrink: 0;
		position: sticky;
		bottom: 0;
		background: var(--theme-card-bg, #ffffff);
		z-index: 100;
	}

	.btn-save,
	.btn-cancel {
		flex: 1;
		padding: 0.75rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.9rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-save {
		background: var(--theme-accent-primary, #0066b2);
		color: #ffffff;
	}

	.btn-save:active {
		background: #004d8c;
	}

	.btn-save:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-cancel {
		background: var(--theme-button-secondary-bg, #e5e7eb);
		color: var(--theme-text-primary, #0b1220);
	}

	.btn-cancel:active {
		background: var(--theme-button-secondary-hover, #d1d5db);
	}

	/* Toast */
	.toast {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%) scale(0.8);
		background: #10b981;
		color: #ffffff;
		padding: 0.2rem 0.4rem;
		border-radius: 0.2rem;
		font-size: 0.65rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
		transition: transform 0.2s ease;
		z-index: 49999;
		white-space: nowrap;
		line-height: 1;
		min-height: auto;
		height: 16px;
	}

	.toast.visible {
		transform: translate(-50%, -50%) scale(1);
	}

	/* RTL */
	[dir='rtl'] .color-grid {
		direction: rtl;
	}

	[dir='rtl'] .modal-footer {
		direction: rtl;
	}
</style>
