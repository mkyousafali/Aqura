<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { mobileThemeStore, extractColors, DEFAULT_MOBILE_THEME, type MobileTheme, type MobileThemeColors } from '$lib/stores/mobileThemeStore';
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
	let userThemeOverrides: Record<number, any> = {}; // Track per-theme user overrides
	let selectedThemeHasOverrides = false; // Does current theme have user customizations?

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
				.select('theme_id, color_overrides')
				.eq('user_id', userId)
				.maybeSingle();

			if (error && error.code !== 'PGRST116') throw error;
			currentUserThemeId = data?.theme_id || null;
			
			// Store user's overrides for each theme
			if (data?.theme_id && data?.color_overrides) {
				userThemeOverrides[data.theme_id] = data.color_overrides;
				selectedThemeHasOverrides = !!data.color_overrides;
			}
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
			
			// Check if this theme has any user customizations
			selectedThemeHasOverrides = !!userThemeOverrides[theme.id];
			
			// Apply theme colors (with overrides if they exist)
			let colorsToApply = theme.colors;
			if (userThemeOverrides[theme.id]) {
				colorsToApply = { ...theme.colors, ...userThemeOverrides[theme.id] };
			}
			mobileThemeStore.preview(colorsToApply);

			showToastMessage(isRTL ? 'تم حفظ المظهر بنجاح' : 'Theme saved successfully');
		} catch (error) {
			console.error('❌ Error saving theme:', error);
			showToastMessage(isRTL ? 'خطأ في حفظ المظهر' : 'Error saving theme');
		} finally {
			isSaving = false;
		}
	}

	async function openColorEditor(theme: MobileTheme) {
		selectedTheme = theme;
		editingTheme = JSON.parse(JSON.stringify(theme));
		
		// Load user's current overrides for this theme
		const userId = $currentUser?.id;
		if (userId && currentUserThemeId === theme.id) {
			try {
				const { data, error } = await supabase
					.from('user_mobile_theme_assignments')
					.select('color_overrides')
					.eq('user_id', userId)
					.single();

				if (!error && data?.color_overrides) {
					editingColors = JSON.parse(JSON.stringify(data.color_overrides));
				} else {
					editingColors = JSON.parse(JSON.stringify(theme.colors));
				}
			} catch (e) {
				editingColors = JSON.parse(JSON.stringify(theme.colors));
			}
		} else {
			// Starting fresh customization
			editingColors = JSON.parse(JSON.stringify(theme.colors));
		}
		
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

	async function resetToOriginalColors() {
		try {
			isSaving = true;
			const userId = $currentUser?.id;
			if (!userId) {
				showToastMessage(isRTL ? 'يجب أن تكون مسجل الدخول' : 'You must be logged in');
				return;
			}

			// Clear color overrides for this theme
			const result = await mobileThemeStore.clearUserColorOverrides(userId);

			if (!result.success) {
				showToastMessage(isRTL ? 'خطأ في إعادة تعيين الألوان' : 'Error resetting colors');
				throw result.error;
			}

			// Remove from tracking
			if (currentUserThemeId) {
				delete userThemeOverrides[currentUserThemeId];
			}
			selectedThemeHasOverrides = false;

			// Reload current theme
			if (currentUserThemeId) {
				const currentTheme = themes.find(t => t.id === currentUserThemeId);
				if (currentTheme) {
					mobileThemeStore.preview(currentTheme.colors);
				}
			}

			showToastMessage(isRTL ? 'تم إعادة تعيين الألوان إلى الأصلية' : 'Colors reset to original');
		} catch (error) {
			console.error('❌ Error resetting colors:', error);
			showToastMessage(isRTL ? 'خطأ في إعادة التعيين' : 'Error resetting');
		} finally {
			isSaving = false;
		}
	}

	async function saveEditedTheme() {
		try {
			isSaving = true;
			if (!editingTheme || !editingColors) return;

			const userId = $currentUser?.id;
			if (!userId) {
				showToastMessage(isRTL ? 'يجب أن تكون مسجل الدخول' : 'You must be logged in');
				return;
			}

			// Only save to user's color overrides - NOT to shared theme!
			// This ensures each user can customize their assigned theme independently
			const result = await mobileThemeStore.saveUserColorOverrides(userId, editingColors);

			if (!result.success) {
				showToastMessage(isRTL ? 'خطأ في حفظ التخصيص' : 'Error saving customization');
				throw result.error;
			}

			// Update state to track that this theme has been customized
			if (currentUserThemeId) {
				userThemeOverrides[currentUserThemeId] = editingColors;
				selectedThemeHasOverrides = true;
			}

			// Apply the customizations immediately
			mobileThemeStore.preview(editingColors);

			showToastMessage(isRTL ? 'تم حفظ التخصيص بنجاح' : 'Customization saved successfully');
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
			<!-- Section 1: Available Standard Themes -->
			<div class="standard-themes-section">
				<h2 class="section-title">{isRTL ? 'المواضيع المتاحة' : 'Available Themes'}</h2>
				<p class="section-subtitle">{isRTL ? 'اختر مظهراً لاستخدامه مباشرة' : 'Select a theme to use'}</p>
				
				<div class="themes-cards-grid">
					{#each themes as theme (theme.id)}
						<div class="theme-card">
							<div class="theme-card-header">
								<h3 class="theme-card-title">{theme.name}</h3>
								{#if theme.is_default}
									<span class="badge-default">{isRTL ? 'افتراضي' : 'Default'}</span>
								{/if}
							</div>

							{#if theme.description}
								<p class="theme-card-description">{theme.description}</p>
							{/if}

							<div class="colors-preview">
								<div class="color-row">
									{#each Object.entries(theme.colors).slice(0, 8) as [key, value]}
										<div class="color-preview-box" style="background-color: {value};" title={key}></div>
									{/each}
								</div>
							</div>

							<button 
								class="btn-use-theme"
								class:active={currentUserThemeId === theme.id}
								on:click={() => saveTheme(theme)}
								disabled={isSaving}
								title={isRTL ? 'استخدم هذا المظهر' : 'Use this theme'}
							>
								{#if isSaving}
									<span class="spinner-mini"></span>
								{:else if currentUserThemeId === theme.id}
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<polyline points="20 6 9 17 4 12"/>
									</svg>
								{:else}
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="11" cy="11" r="8"/>
										<path d="M21 21l-4.35-4.35"/>
									</svg>
								{/if}
								{currentUserThemeId === theme.id 
									? (isRTL ? 'قيد الاستخدام' : 'In Use')
									: (isRTL ? 'استخدم' : 'Use Theme')}
							</button>
						</div>
					{/each}
				</div>
			</div>

			<!-- Section 2: Color Options (Original vs Theme vs Customizations) -->
			{#if currentUserThemeId}
				{@const selectedTheme = themes.find(t => t.id === currentUserThemeId)}
				{@const hasCustomizations = !!userThemeOverrides[currentUserThemeId]}
				
				<div class="color-options-section">
					<h2 class="section-title">{isRTL ? 'خيارات الألوان' : 'Color Options'}</h2>
					<p class="section-subtitle">{isRTL ? 'اختر إصدار الألوان' : 'Choose your color version'}</p>

					<div class="color-cards-section">
						<!-- Card 1: Original Mobile Interface Colors -->
						<div class="color-card original-card">
							<div class="card-header">
								<h3>{isRTL ? 'الألوان الأصلية (الافتراضية)' : 'Original Colors'}</h3>
								<span class="card-badge original">{isRTL ? 'أصلي' : 'Default'}</span>
							</div>

							<div class="colors-preview">
								<div class="color-row">
									{#each Object.entries(DEFAULT_MOBILE_THEME).slice(0, 8) as [key, value]}
										<div class="color-preview-box" style="background-color: {value};" title={key}></div>
									{/each}
								</div>
							</div>

							<button 
								class="btn-use-original"
								on:click={() => {
									mobileThemeStore.preview(DEFAULT_MOBILE_THEME);
									showToastMessage(isRTL ? 'تم تفعيل الألوان الأصلية' : 'Original colors activated');
								}}
								disabled={isSaving}
								title={isRTL ? 'استخدم الألوان الأصلية' : 'Use original colors'}
							>
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polyline points="20 6 9 17 4 12"/>
								</svg>
								{isRTL ? 'استخدم الأصلي' : 'Use Original'}
							</button>
						</div>

						<!-- Card 2: Standard Theme Colors -->
						<div class="color-card theme-card">
							<div class="card-header">
								<h3>{isRTL ? 'ألوان المظهر' : 'Theme Standard'}</h3>
								{#if selectedTheme}
									<span class="card-badge theme">{isRTL ? 'المظهر' : 'Theme'}</span>
								{/if}
							</div>

							{#if selectedTheme}
								<div class="colors-preview">
									<div class="color-row">
										{#each Object.entries(selectedTheme.colors).slice(0, 8) as [key, value]}
											<div class="color-preview-box" style="background-color: {value};" title={key}></div>
										{/each}
									</div>
								</div>
							{/if}

							<button 
								class="btn-use-theme-colors"
								on:click={() => {
									if (selectedTheme) {
										mobileThemeStore.preview(selectedTheme.colors);
										showToastMessage(isRTL ? 'تم تفعيل ألوان المظهر' : 'Theme colors activated');
									}
								}}
								disabled={isSaving}
								title={isRTL ? 'استخدم ألوان المظهر' : 'Use theme colors'}
							>
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polyline points="20 6 9 17 4 12"/>
								</svg>
								{isRTL ? 'استخدم المظهر' : 'Use Theme'}
							</button>
						</div>

						<!-- Card 3: Your Customizations (if exists) -->
						{#if hasCustomizations}
							<div class="color-card custom-card">
								<div class="card-header">
									<h3>{isRTL ? 'تخصيصاتك' : 'Your Customizations'}</h3>
									<span class="card-badge custom">{isRTL ? 'مخصص' : 'Custom'}</span>
								</div>

								<div class="colors-preview">
									<div class="color-row">
										{#each Object.entries(userThemeOverrides[currentUserThemeId]).slice(0, 8) as [key, value]}
											<div class="color-preview-box" style="background-color: {value};" title={key}></div>
										{/each}
									</div>
								</div>

								<div class="custom-card-actions">
									<button 
										class="btn-use-custom"
										on:click={() => {
											if (selectedTheme) {
												const customColors = { ...selectedTheme.colors, ...userThemeOverrides[currentUserThemeId] };
												mobileThemeStore.preview(customColors);
												showToastMessage(isRTL ? 'تم تفعيل التخصيصات' : 'Custom colors activated');
											}
										}}
										disabled={isSaving}
										title={isRTL ? 'استخدم تخصيصاتك' : 'Use your customizations'}
									>
										<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<polyline points="20 6 9 17 4 12"/>
										</svg>
										{isRTL ? 'استخدم' : 'Use Custom'}
									</button>
									<button 
										class="btn-edit-custom"
										on:click={() => {
											if (selectedTheme) {
												openColorEditor(selectedTheme);
											}
										}}
										disabled={isSaving}
										title={isRTL ? 'عدل التخصيصات' : 'Edit customizations'}
									>
										<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M12 20h9M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19H4v-3L16.5 3.5z"/>
										</svg>
										{isRTL ? 'تعديل' : 'Edit'}
									</button>
								</div>
							</div>
						{:else}
							<!-- No Customizations Card -->
							<div class="color-card no-custom-card">
								<div class="card-header">
									<h3>{isRTL ? 'تخصيصاتك' : 'Your Customizations'}</h3>
									<span class="card-badge empty">{isRTL ? 'لا يوجد' : 'None'}</span>
								</div>

								<div class="no-customizations">
									<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<polyline points="12 6 12 12 16 14"/>
									</svg>
									<p>{isRTL ? 'لم تقم بأي تخصيصات حتى الآن' : 'No customizations yet'}</p>
									<p class="hint">{isRTL ? 'اضغط "تخصيص" للبدء' : 'Click "Customize" to get started'}</p>
								</div>

								<button 
									class="btn-create-custom"
									on:click={() => {
										if (selectedTheme) {
											openColorEditor(selectedTheme);
										}
									}}
									disabled={isSaving}
								>
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M12 20h9M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19H4v-3L16.5 3.5z"/>
									</svg>
									{isRTL ? 'تخصيص' : 'Customize'}
								</button>
							</div>
						{/if}
					</div>
				</div>
			{/if}
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

				<div class="modal-info-banner">
					<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/>
						<line x1="12" y1="16" x2="12" y2="12"/>
						<line x1="12" y1="8" x2="12.01" y2="8"/>
					</svg>
					<span>{isRTL ? 'هذه التخصيصات شخصية لك فقط وتطبق على استخدامك الخاص' : 'These customizations are personal to your account only'}</span>
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
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	/* STANDARD THEMES SECTION */
	.standard-themes-section {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.section-title {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: var(--theme-text-primary, #0b1220);
	}

	.section-subtitle {
		margin: 0;
		font-size: 0.85rem;
		color: var(--theme-text-secondary, #6b7280);
	}

	.themes-cards-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
		gap: 1rem;
	}

	.theme-card {
		background: var(--theme-card-bg, #ffffff);
		border: 2px solid var(--theme-card-border, #e5e7eb);
		border-radius: 0.75rem;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		transition: all 0.2s ease;
		cursor: pointer;
	}

	.theme-card:hover {
		border-color: var(--theme-accent-primary, #0066b2);
		box-shadow: 0 2px 8px rgba(0, 102, 178, 0.1);
	}

	.theme-card-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		justify-content: space-between;
	}

	.theme-card-title {
		margin: 0;
		font-size: 0.95rem;
		font-weight: 600;
		color: var(--theme-text-primary, #0b1220);
		flex: 1;
	}

	.theme-card-description {
		margin: 0;
		font-size: 0.75rem;
		color: var(--theme-text-secondary, #6b7280);
		line-height: 1.3;
	}

	.btn-use-theme {
		padding: 0.625rem 0.75rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.8rem;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		transition: all 0.2s ease;
		background: var(--theme-button-secondary-bg, #e5e7eb);
		color: var(--theme-text-primary, #0b1220);
		white-space: nowrap;
	}

	.btn-use-theme:hover:not(:disabled) {
		background: var(--theme-button-secondary-hover, #d1d5db);
	}

	.btn-use-theme:disabled {
		background: rgba(229, 231, 235, 0.5);
		cursor: not-allowed;
		opacity: 0.6;
	}

	.btn-use-theme.active {
		background: var(--theme-accent-primary, #0066b2);
		color: #ffffff;
	}

	.btn-use-theme.active:hover {
		background: #004d8c;
	}

	/* COLOR OPTIONS SECTION */
	.color-options-section {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding-top: 1rem;
		border-top: 2px solid var(--theme-card-border, #e5e7eb);
	}

	/* COLOR CARDS SECTION */
	.color-cards-section {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.color-card {
		background: var(--theme-card-bg, #ffffff);
		border: 1px solid var(--theme-card-border, #e5e7eb);
		border-radius: 0.75rem;
		padding: 1.25rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		transition: all 0.3s ease;
	}

	.color-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.original-card {
		border-left: 4px solid #8b5cf6;
	}

	.original-card:hover {
		border-left-color: #a78bfa;
	}

	.theme-card {
		border-left: 4px solid #06b6d4;
	}

	.theme-card:hover {
		border-left-color: #22d3ee;
	}

	.standard-card {
		border-left: 4px solid #0066b2;
	}

	.custom-card {
		border-left: 4px solid #a855f7;
	}

	.no-custom-card {
		border-left: 4px solid #9ca3af;
		align-items: center;
		justify-content: center;
		text-align: center;
		min-height: 180px;
	}

	.card-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
	}

	.card-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: var(--theme-text-primary, #0b1220);
		flex: 1;
	}

	.card-badge {
		display: inline-flex;
		align-items: center;
		padding: 0.3rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.7rem;
		font-weight: 600;
		white-space: nowrap;
		background: rgba(0, 102, 178, 0.1);
		color: #0066b2;
	}

	.card-badge.custom {
		background: rgba(168, 85, 247, 0.1);
		color: #a855f7;
	}

	.card-badge.empty {
		background: rgba(156, 163, 175, 0.1);
		color: #9ca3af;
	}

	.colors-preview {
		flex: 1;
		min-height: 60px;
		display: flex;
		align-items: center;
	}

	.color-row {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		width: 100%;
	}

	.color-preview-box {
		width: 40px;
		height: 40px;
		border-radius: 0.375rem;
		border: 1px solid rgba(0, 0, 0, 0.2);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
		flex-shrink: 0;
	}

	.no-customizations {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
		color: var(--theme-text-secondary, #6b7280);
		flex: 1;
		justify-content: center;
	}

	.no-customizations svg {
		opacity: 0.4;
		color: var(--theme-text-tertiary, #9ca3af);
	}

	.no-customizations p {
		margin: 0;
		font-size: 0.9rem;
	}

	.no-customizations .hint {
		font-size: 0.8rem;
		color: var(--theme-text-tertiary, #9ca3af);
	}

	/* BUTTON STYLES */
	.btn-use-standard,
	.btn-use-original,
	.btn-use-theme-colors,
	.btn-use-custom,
	.btn-edit-custom,
	.btn-create-custom {
		padding: 0.75rem 1rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.85rem;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: all 0.2s ease;
	}

	.btn-use-original {
		background: #8b5cf6;
		color: white;
		width: 100%;
	}

	.btn-use-original:hover:not(:disabled) {
		background: #7c3aed;
	}

	.btn-use-original:disabled {
		background: rgba(139, 92, 246, 0.3);
		cursor: not-allowed;
		color: rgba(0, 0, 0, 0.3);
	}

	.btn-use-theme-colors {
		background: #06b6d4;
		color: white;
		width: 100%;
	}

	.btn-use-theme-colors:hover:not(:disabled) {
		background: #0891b2;
	}

	.btn-use-theme-colors:disabled {
		background: rgba(6, 182, 212, 0.3);
		cursor: not-allowed;
		color: rgba(0, 0, 0, 0.3);
	}

	.btn-use-standard {
		background: #0066b2;
		color: white;
		width: 100%;
	}

	.btn-use-standard:hover:not(:disabled) {
		background: #004d8c;
	}

	.btn-use-standard:disabled {
		background: rgba(0, 102, 178, 0.3);
		cursor: not-allowed;
		color: rgba(0, 0, 0, 0.3);
	}

	.custom-card-actions {
		display: flex;
		gap: 0.75rem;
		width: 100%;
	}

	.btn-use-custom {
		flex: 1;
		background: #a855f7;
		color: white;
	}

	.btn-use-custom:hover:not(:disabled) {
		background: #9333ea;
	}

	.btn-use-custom:disabled {
		background: rgba(168, 85, 247, 0.3);
		cursor: not-allowed;
		color: rgba(0, 0, 0, 0.3);
	}

	.btn-edit-custom {
		flex: 1;
		background: var(--theme-button-secondary-bg, #e5e7eb);
		color: var(--theme-text-primary, #0b1220);
	}

	.btn-edit-custom:hover:not(:disabled) {
		background: var(--theme-button-secondary-hover, #d1d5db);
	}

	.btn-edit-custom:disabled {
		background: rgba(229, 231, 235, 0.5);
		cursor: not-allowed;
		color: rgba(0, 0, 0, 0.3);
	}

	.btn-create-custom {
		background: #a855f7;
		color: white;
		width: 100%;
		margin-top: 0.5rem;
	}

	.btn-create-custom:hover:not(:disabled) {
		background: #9333ea;
	}

	.btn-create-custom:disabled {
		background: rgba(168, 85, 247, 0.3);
		cursor: not-allowed;
		color: rgba(0, 0, 0, 0.3);
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

	.modal-info-banner {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		background: rgba(59, 130, 246, 0.05);
		border: 1px solid rgba(59, 130, 246, 0.2);
		border-left: 3px solid #3b82f6;
		font-size: 0.85rem;
		color: var(--theme-text-secondary, #6b7280);
		flex-shrink: 0;
	}

	.modal-info-banner svg {
		flex-shrink: 0;
		color: #3b82f6;
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
