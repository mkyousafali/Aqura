<script lang="ts">
	import { onMount, createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { t } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { themeStore, DEFAULT_THEME, extractColors, type ThemeColors, type Theme } from '$lib/stores/themeStore';

	const dispatch = createEventDispatcher();

	// State
	let themes: Theme[] = [];
	let currentThemeId: number | null = null; // current user's active theme
	let loading = true;
	let saving = false;
	let message = '';
	let messageType: 'success' | 'error' | 'info' = 'info';

	// Editor state
	let editingTheme: Theme | null = null;
	let isCreating = false;
	let editName = '';
	let editDescription = '';
	let editColors: ThemeColors = { ...DEFAULT_THEME };
	let previewActive = false;
	let originalColors: ThemeColors | null = null;

	// Color group labels for organizing the editor
	const colorGroups = [
		{
			key: 'taskbar',
			emoji: '📊',
			fields: [
				{ key: 'taskbar_bg', label: 'Background' },
				{ key: 'taskbar_border', label: 'Border' },
				{ key: 'taskbar_btn_active_bg', label: 'Active Button BG' },
				{ key: 'taskbar_btn_active_text', label: 'Active Button Text' },
				{ key: 'taskbar_btn_inactive_bg', label: 'Inactive Button BG' },
				{ key: 'taskbar_btn_inactive_text', label: 'Inactive Button Text' },
				{ key: 'taskbar_btn_hover_border', label: 'Hover Border' },
				{ key: 'taskbar_quick_access_bg', label: 'Quick Access BG' }
			]
		},
		{
			key: 'sidebar',
			emoji: '📋',
			fields: [
				{ key: 'sidebar_bg', label: 'Background' },
				{ key: 'sidebar_text', label: 'Text Color' },
				{ key: 'sidebar_border', label: 'Border' },
				{ key: 'sidebar_favorites_bg', label: 'Favorites BG' },
				{ key: 'sidebar_favorites_text', label: 'Favorites Text' }
			]
		},
		{
			key: 'sectionButtons',
			emoji: '🔘',
			fields: [
				{ key: 'section_btn_bg', label: 'Section BG' },
				{ key: 'section_btn_text', label: 'Section Text' },
				{ key: 'section_btn_hover_bg', label: 'Section Hover BG' },
				{ key: 'section_btn_hover_text', label: 'Section Hover Text' },
				{ key: 'subsection_btn_bg', label: 'Subsection BG' },
				{ key: 'subsection_btn_text', label: 'Subsection Text' },
				{ key: 'subsection_btn_hover_bg', label: 'Subsection Hover BG' },
				{ key: 'subsection_btn_hover_text', label: 'Subsection Hover Text' }
			]
		},
		{
			key: 'submenu',
			emoji: '📑',
			fields: [
				{ key: 'submenu_item_bg', label: 'Item BG' },
				{ key: 'submenu_item_text', label: 'Item Text' },
				{ key: 'submenu_item_hover_bg', label: 'Item Hover BG' },
				{ key: 'submenu_item_hover_text', label: 'Item Hover Text' }
			]
		},
		{
			key: 'logoBar',
			emoji: '🏢',
			fields: [
				{ key: 'logo_bar_bg', label: 'Background' },
				{ key: 'logo_bar_text', label: 'Text Color' },
				{ key: 'logo_border', label: 'Logo Border' }
			]
		},
		{
			key: 'windowTitleBars',
			emoji: '🪟',
			fields: [
				{ key: 'window_title_active_bg', label: 'Active BG' },
				{ key: 'window_title_active_text', label: 'Active Text' },
				{ key: 'window_title_inactive_bg', label: 'Inactive BG' },
				{ key: 'window_title_inactive_text', label: 'Inactive Text' },
				{ key: 'window_border_active', label: 'Active Border' }
			]
		},
		{
			key: 'desktop',
			emoji: '🖥️',
			fields: [
				{ key: 'desktop_bg', label: 'Background' },
				{ key: 'desktop_pattern_opacity', label: 'Pattern Opacity' }
			]
		},
		{
			key: 'interfaceSwitch',
			emoji: '🔄',
			fields: [
				{ key: 'interface_switch_bg', label: 'Button BG' },
				{ key: 'interface_switch_hover_bg', label: 'Button Hover BG' }
			]
		}
	];

	// Expanded groups
	let expandedGroups: Record<string, boolean> = {};

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		try {
			await loadThemes();
			await loadCurrentUserTheme();
		} catch (err) {
			showMessage('Failed to load data', 'error');
		}
		loading = false;
	}

	async function loadThemes() {
		const { data, error } = await supabase
			.from('desktop_themes')
			.select('*')
			.order('is_default', { ascending: false })
			.order('name');

		if (error) throw error;
		themes = (data || []).map((row: any) => ({
			id: row.id,
			name: row.name,
			description: row.description || '',
			is_default: row.is_default,
			colors: extractColors(row),
			created_at: row.created_at,
			updated_at: row.updated_at,
			created_by: row.created_by
		}));
	}

	async function loadCurrentUserTheme() {
		if (!$currentUser?.id) return;
		const { data } = await supabase
			.from('user_theme_assignments')
			.select('theme_id')
			.eq('user_id', $currentUser.id)
			.single();
		currentThemeId = data?.theme_id || null;
	}

	function startCreate() {
		isCreating = true;
		editingTheme = null;
		editName = '';
		editDescription = '';
		editColors = { ...DEFAULT_THEME };
		expandedGroups = {};
	}

	function startEdit(theme: Theme) {
		isCreating = false;
		editingTheme = theme;
		editName = theme.name;
		editDescription = theme.description;
		editColors = { ...theme.colors };
		expandedGroups = {};
	}

	function cancelEdit() {
		if (previewActive && originalColors) {
			themeStore.preview(originalColors);
			previewActive = false;
			originalColors = null;
		}
		editingTheme = null;
		isCreating = false;
	}

	function togglePreview() {
		if (!previewActive) {
			// Save current colors before preview
			originalColors = { ...$themeStore };
			themeStore.preview(editColors);
			previewActive = true;
		} else {
			// Restore original
			if (originalColors) {
				themeStore.preview(originalColors);
			}
			previewActive = false;
			originalColors = null;
		}
	}

	function updatePreviewIfActive() {
		if (previewActive) {
			themeStore.preview(editColors);
		}
	}

	/** Extract a hex color from any CSS color value (hex, rgba, linear-gradient, etc.) */
	function extractHexColor(val: string): string {
		if (!val) return '#000000';
		val = val.trim();
		// Already hex6
		if (/^#[0-9a-fA-F]{6}$/i.test(val)) return val;
		// hex3 → hex6
		const hex3 = val.match(/^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/i);
		if (hex3) return `#${hex3[1]}${hex3[1]}${hex3[2]}${hex3[2]}${hex3[3]}${hex3[3]}`;
		// rgba(r, g, b, a) or rgb(r, g, b)
		const rgbMatch = val.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);
		if (rgbMatch) {
			const r = Math.min(255, parseInt(rgbMatch[1])).toString(16).padStart(2, '0');
			const g = Math.min(255, parseInt(rgbMatch[2])).toString(16).padStart(2, '0');
			const b = Math.min(255, parseInt(rgbMatch[3])).toString(16).padStart(2, '0');
			return `#${r}${g}${b}`;
		}
		// linear-gradient: extract first hex color
		const gradHex = val.match(/#[0-9a-fA-F]{6}/i);
		if (gradHex) return gradHex[0];
		const gradHex3 = val.match(/#([0-9a-fA-F]{3})(?![0-9a-fA-F])/i);
		if (gradHex3) {
			const h = gradHex3[1];
			return `#${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}`;
		}
		return '#000000';
	}

	/** Check if a value is a complex color (gradient/rgba) vs simple hex */
	function isComplexColor(val: string): boolean {
		if (!val) return false;
		return /^(linear-gradient|radial-gradient|rgba)\(/i.test(val.trim());
	}

	/** When user picks a color via picker, smartly update the value */
	function applyPickedColor(field: string, hexColor: string) {
		const current = editColors[field as keyof ThemeColors];
		if (!current) {
			editColors[field as keyof ThemeColors] = hexColor;
		} else if (/^rgba\(/i.test(current.trim())) {
			// Preserve alpha, replace RGB
			const r = parseInt(hexColor.slice(1, 3), 16);
			const g = parseInt(hexColor.slice(3, 5), 16);
			const b = parseInt(hexColor.slice(5, 7), 16);
			const alphaMatch = current.match(/,\s*([\d.]+)\s*\)$/);
			const alpha = alphaMatch ? alphaMatch[1] : '1';
			editColors[field as keyof ThemeColors] = `rgba(${r}, ${g}, ${b}, ${alpha})`;
		} else if (/^linear-gradient/i.test(current.trim())) {
			// Replace ALL hex colors in gradient with the picked color
			editColors[field as keyof ThemeColors] = current.replace(/#[0-9a-fA-F]{3,6}/gi, () => hexColor);
		} else {
			editColors[field as keyof ThemeColors] = hexColor;
		}
		editColors = editColors;
		updatePreviewIfActive();
	}

	async function saveTheme() {
		if (!editName.trim()) {
			showMessage('Theme name is required', 'error');
			return;
		}

		saving = true;

		// Build the row data (flatten colors into top-level columns)
		const rowData: Record<string, any> = {
			name: editName.trim(),
			description: editDescription.trim(),
			...editColors
		};

		try {
			let savedThemeId: number | null = null;

			if (isCreating) {
				rowData.created_by = $currentUser?.id || null;
				const { data, error } = await supabase.from('desktop_themes').insert(rowData).select('id').single();
				if (error) throw error;
				savedThemeId = data?.id || null;
				showMessage('Theme created & applied!', 'success');
			} else if (editingTheme) {
				const { error } = await supabase.from('desktop_themes').update(rowData).eq('id', editingTheme.id);
				if (error) throw error;
				savedThemeId = editingTheme.id;
				showMessage('Theme saved & applied!', 'success');
			}

			// Auto-assign saved theme to current user
			if (savedThemeId && $currentUser?.id) {
				await applyThemeToCurrentUser(savedThemeId);
			}

			// Stop preview
			previewActive = false;
			originalColors = null;

			await loadThemes();
			editingTheme = null;
			isCreating = false;
		} catch (err: any) {
			showMessage(`Save failed: ${err.message}`, 'error');
		}
		saving = false;
	}

	async function deleteTheme(theme: Theme) {
		if (theme.is_default) {
			showMessage('Cannot delete the default theme', 'error');
			return;
		}
		if (!confirm(`Delete theme "${theme.name}"? Users assigned to this theme will revert to the default.`)) return;

		try {
			// Remove assignments first
			await supabase.from('user_theme_assignments').delete().eq('theme_id', theme.id);
			const { error } = await supabase.from('desktop_themes').delete().eq('id', theme.id);
			if (error) throw error;

			showMessage('Theme deleted', 'success');
			await loadData();
		} catch (err: any) {
			showMessage(`Delete failed: ${err.message}`, 'error');
		}
	}

	async function duplicateTheme(theme: Theme) {
		const rowData: Record<string, any> = {
			name: `${theme.name} (Copy)`,
			description: theme.description,
			is_default: false,
			created_by: $currentUser?.id || null,
			...theme.colors
		};

		try {
			const { error } = await supabase.from('desktop_themes').insert(rowData);
			if (error) throw error;
			showMessage('Theme duplicated!', 'success');
			await loadThemes();
		} catch (err: any) {
			showMessage(`Duplicate failed: ${err.message}`, 'error');
		}
	}

	/** Apply a theme to the current logged-in user */
	async function applyThemeToCurrentUser(themeId: number) {
		if (!$currentUser?.id) return;
		try {
			await supabase.from('user_theme_assignments').upsert(
				{
					user_id: $currentUser.id,
					theme_id: themeId,
					assigned_by: $currentUser.id
				},
				{ onConflict: 'user_id' }
			);
			currentThemeId = themeId;
			await themeStore.loadUserTheme($currentUser.id);
		} catch (err: any) {
			showMessage(`Apply failed: ${err.message}`, 'error');
		}
	}

	async function applyTheme(theme: Theme) {
		await applyThemeToCurrentUser(theme.id);
		showMessage(`"${theme.name}" applied!`, 'success');
	}

	function showMessage(msg: string, type: 'success' | 'error' | 'info') {
		message = msg;
		messageType = type;
		setTimeout(() => { message = ''; }, 4000);
	}

	function toggleGroup(key: string) {
		expandedGroups[key] = !expandedGroups[key];
		expandedGroups = { ...expandedGroups };
	}

	const groupLabels: Record<string, string> = {
		taskbar: t('theme.taskbar'),
		sidebar: t('theme.sidebar'),
		sectionButtons: t('theme.sectionButtons'),
		submenu: t('theme.submenuItems'),
		logoBar: t('theme.logoBar'),
		windowTitleBars: t('theme.windowTitleBars'),
		desktop: t('theme.desktop'),
		interfaceSwitch: t('theme.interfaceSwitch')
	};
</script>

<div class="theme-manager">
	<!-- Header -->
	<div class="tm-header">
		<h2>🎨 {t('nav.themeManager')}</h2>
		{#if message}
			<div class="tm-message" class:success={messageType === 'success'} class:error={messageType === 'error'} class:info={messageType === 'info'}>
				{message}
			</div>
		{/if}
	</div>

	{#if loading}
		<div class="tm-loading">⏳ {t('common.loading')}...</div>
	{:else}
			<div class="tm-content">
				{#if editingTheme || isCreating}
					<!-- EDITOR -->
					<div class="tm-editor">
						<div class="tm-editor-header">
							<h3>{isCreating ? `➕ ${t('theme.createTheme')}` : `✏️ ${t('theme.editTheme')}: ${editingTheme?.name}`}</h3>
							<div class="tm-editor-actions">
								<button class="tm-btn preview" class:active={previewActive} on:click={togglePreview}>
								{previewActive ? '👁️‍🗨️' : '👁️'} {t('theme.preview')}
							</button>
							<button class="tm-btn save" on:click={saveTheme} disabled={saving}>
								💾 {saving ? '...' : t('common.save')}
							</button>
							<button class="tm-btn cancel" on:click={cancelEdit}>
								❌ {t('common.cancel')}
								</button>
							</div>
						</div>

						<!-- Name & Description -->
						<div class="tm-field-row">
							<label>{t('theme.themeName')}</label>
							<input type="text" bind:value={editName} placeholder="e.g. Dark Mode, Ocean Blue..." class="tm-input" />
						</div>
						<div class="tm-field-row">
							<label>{t('theme.description')}</label>
							<input type="text" bind:value={editDescription} placeholder="Optional description..." class="tm-input" />
						</div>

						<!-- Color Groups -->
						<div class="tm-color-groups">
							{#each colorGroups as group}
								<div class="tm-group">
									<button class="tm-group-header" on:click={() => toggleGroup(group.key)}>
										<span>{group.emoji} {groupLabels[group.key] || group.key}</span>
										<span class="tm-chevron" class:open={expandedGroups[group.key]}>▶</span>
									</button>
									{#if expandedGroups[group.key]}
										<div class="tm-group-fields">
											{#each group.fields as field}
												<div class="tm-color-field">
													<label>{field.label}</label>
													<div class="tm-color-input-row">
														<div class="tm-picker-wrapper">
															<input
																type="color"
																value={extractHexColor(editColors[field.key as keyof ThemeColors])}
																on:input={(e) => applyPickedColor(field.key, e.currentTarget.value)}
																class="tm-color-picker"
															/>
															{#if isComplexColor(editColors[field.key as keyof ThemeColors])}
																<span class="tm-complex-badge" title="Complex color (gradient/alpha) — picker edits primary color">⚙</span>
															{/if}
														</div>
														<input
															type="text"
															value={editColors[field.key as keyof ThemeColors]}
															on:input={(e) => {
																editColors[field.key as keyof ThemeColors] = e.currentTarget.value;
																editColors = editColors;
																updatePreviewIfActive();
															}}
															class="tm-text-input"
														/>
														<div
															class="tm-color-swatch"
															style="background: {editColors[field.key as keyof ThemeColors]};"
														></div>
													</div>
												</div>
											{/each}
										</div>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{:else}
					<!-- THEME LIST -->
					<div class="tm-toolbar">
						<button class="tm-btn create" on:click={startCreate}>
						➕ {t('theme.createTheme')}
						</button>
					</div>

					<div class="tm-theme-list">
						{#each themes as theme}
							<div class="tm-theme-card" class:default={theme.is_default}>
								<div class="tm-theme-card-header">
									<div class="tm-theme-info">
										<h4>
											{theme.name}
											{#if theme.is_default}
												<span class="tm-badge default">Default</span>
											{/if}
										</h4>
										{#if theme.description}
											<p class="tm-theme-desc">{theme.description}</p>
										{/if}
									</div>
									<div class="tm-theme-actions">
										<button class="tm-btn-sm edit" on:click={() => startEdit(theme)} title={t('common.edit')}>✏️</button>
										<button class="tm-btn-sm duplicate" on:click={() => duplicateTheme(theme)} title={t('theme.duplicate')}>📋</button>
										{#if !theme.is_default}
											<button class="tm-btn-sm delete" on:click={() => deleteTheme(theme)} title={t('common.delete')}>🗑️</button>
										{/if}
									</div>
								</div>
								<!-- Color preview strip -->
								<div class="tm-color-strip">
									<div class="tm-strip-swatch" style="background: {theme.colors.taskbar_bg};" title="Taskbar"></div>
									<div class="tm-strip-swatch" style="background: {theme.colors.sidebar_bg};" title="Sidebar"></div>
									<div class="tm-strip-swatch" style="background: {theme.colors.section_btn_bg};" title="Section Btn"></div>
									<div class="tm-strip-swatch" style="background: {theme.colors.submenu_item_text};" title="Submenu"></div>
									<div class="tm-strip-swatch" style="background: {theme.colors.logo_bar_bg};" title="Logo Bar"></div>
									<div class="tm-strip-swatch" style="background: {theme.colors.window_title_active_bg};" title="Window Bar"></div>
									<div class="tm-strip-swatch" style="background: {theme.colors.desktop_bg};" title="Desktop"></div>
								</div>
												<div class="tm-theme-meta">
									{#if currentThemeId === theme.id}
										<span class="tm-active-badge">✅ Active</span>
									{:else}
										<button class="tm-btn apply" on:click={() => applyTheme(theme)}>
											🎯 Apply
										</button>
									{/if}
								</div>
							</div>
						{/each}

						{#if themes.length === 0}
							<div class="tm-empty">
						<p>{t('theme.noThemes')}</p>
						<button class="tm-btn create" on:click={startCreate}>➕ {t('theme.createTheme')}</button>
							</div>
						{/if}
					</div>
				{/if}
			</div>
	{/if}
</div>

<style>
	.theme-manager {
		display: flex;
		flex-direction: column;
		height: 100%;
		font-family: 'Segoe UI', system-ui, sans-serif;
		background: #f8fafc;
		color: #1e293b;
	}

	/* Header */
	.tm-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 20px;
		background: linear-gradient(135deg, #6366f1, #8b5cf6);
		color: white;
		flex-shrink: 0;
	}
	.tm-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 700;
	}

	/* Message */
	.tm-message {
		padding: 6px 14px;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 500;
	}
	.tm-message.success { background: rgba(16, 185, 129, 0.2); color: #ecfdf5; }
	.tm-message.error { background: rgba(239, 68, 68, 0.2); color: #fef2f2; }
	.tm-message.info { background: rgba(59, 130, 246, 0.2); color: #eff6ff; }

	/* Content */
	.tm-content {
		flex: 1;
		overflow-y: auto;
		padding: 16px;
	}

	/* Loading */
	.tm-loading {
		display: flex;
		justify-content: center;
		align-items: center;
		height: 200px;
		font-size: 16px;
		color: #94a3b8;
	}

	/* Toolbar */
	.tm-toolbar {
		display: flex;
		justify-content: flex-end;
		margin-bottom: 12px;
	}

	/* Buttons */
	.tm-btn {
		padding: 8px 16px;
		border: none;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}
	.tm-btn.create { background: #6366f1; color: white; }
	.tm-btn.create:hover { background: #4f46e5; }
	.tm-btn.save { background: #10b981; color: white; }
	.tm-btn.save:hover { background: #059669; }
	.tm-btn.save:disabled { opacity: 0.6; cursor: not-allowed; }
	.tm-btn.cancel { background: #94a3b8; color: white; }
	.tm-btn.cancel:hover { background: #64748b; }
	.tm-btn.preview { background: #f59e0b; color: white; }
	.tm-btn.preview:hover { background: #d97706; }
	.tm-btn.preview.active { background: #059669; box-shadow: 0 0 0 2px #10b981; }
	.tm-btn.apply { background: #3b82f6; color: white; padding: 6px 14px; font-size: 12px; }
	.tm-btn.apply:hover { background: #2563eb; }

	.tm-btn-sm {
		padding: 4px 8px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		background: #f1f5f9;
		transition: all 0.2s;
	}
	.tm-btn-sm:hover { background: #e2e8f0; }
	.tm-btn-sm.delete:hover { background: #fecaca; }

	/* Theme Cards */
	.tm-theme-list {
		display: grid;
		gap: 12px;
	}
	.tm-theme-card {
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
		transition: all 0.2s;
	}
	.tm-theme-card:hover { border-color: #6366f1; box-shadow: 0 2px 8px rgba(99, 102, 241, 0.1); }
	.tm-theme-card.default { border-color: #6366f1; border-width: 2px; }
	.tm-theme-card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		padding: 12px 16px;
	}
	.tm-theme-info h4 {
		margin: 0 0 4px;
		font-size: 15px;
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.tm-theme-desc {
		margin: 0;
		font-size: 12px;
		color: #94a3b8;
	}
	.tm-badge {
		font-size: 10px;
		padding: 2px 8px;
		border-radius: 10px;
		font-weight: 600;
	}
	.tm-badge.default { background: #ede9fe; color: #6366f1; }
	.tm-theme-actions {
		display: flex;
		gap: 4px;
	}

	/* Color Strip */
	.tm-color-strip {
		display: flex;
		height: 24px;
		margin: 0 16px;
		border-radius: 6px;
		overflow: hidden;
		border: 1px solid #e2e8f0;
	}
	.tm-strip-swatch {
		flex: 1;
		cursor: help;
	}
	.tm-theme-meta {
		display: flex;
		justify-content: flex-end;
		align-items: center;
		padding: 8px 16px;
		font-size: 12px;
		color: #94a3b8;
	}
	.tm-active-badge {
		font-size: 12px;
		font-weight: 600;
		color: #059669;
		padding: 4px 12px;
		background: #ecfdf5;
		border-radius: 6px;
	}

	/* Editor */
	.tm-editor {
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
	}
	.tm-editor-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		flex-wrap: wrap;
		gap: 8px;
	}
	.tm-editor-header h3 {
		margin: 0;
		font-size: 15px;
	}
	.tm-editor-actions {
		display: flex;
		gap: 8px;
	}
	.tm-field-row {
		display: flex;
		align-items: center;
		padding: 8px 16px;
		gap: 12px;
		border-bottom: 1px solid #f1f5f9;
	}
	.tm-field-row label {
		width: 100px;
		font-size: 13px;
		font-weight: 600;
		color: #475569;
		flex-shrink: 0;
	}
	.tm-input {
		flex: 1;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 13px;
		outline: none;
	}
	.tm-input:focus { border-color: #6366f1; box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.1); }

	/* Color Groups */
	.tm-color-groups {
		padding: 0 16px 16px;
	}
	.tm-group {
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		margin-top: 8px;
		overflow: hidden;
	}
	.tm-group-header {
		width: 100%;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 10px 14px;
		background: #f8fafc;
		border: none;
		font-size: 13px;
		font-weight: 600;
		color: #334155;
		cursor: pointer;
		transition: background 0.2s;
	}
	.tm-group-header:hover { background: #f1f5f9; }
	.tm-chevron {
		font-size: 11px;
		transition: transform 0.2s;
	}
	.tm-chevron.open { transform: rotate(90deg); }
	.tm-group-fields {
		padding: 8px 14px 14px;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 8px;
	}
	.tm-color-field {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.tm-color-field label {
		font-size: 11px;
		font-weight: 600;
		color: #64748b;
	}
	.tm-color-input-row {
		display: flex;
		gap: 6px;
		align-items: center;
	}
	.tm-picker-wrapper {
		position: relative;
		flex-shrink: 0;
	}
	.tm-color-picker {
		width: 44px;
		height: 36px;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		padding: 2px;
		background: none;
		transition: border-color 0.2s;
	}
	.tm-color-picker:hover {
		border-color: #6366f1;
		box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.2);
	}
	.tm-complex-badge {
		position: absolute;
		top: -4px;
		right: -4px;
		font-size: 10px;
		background: #fbbf24;
		color: #78350f;
		border-radius: 50%;
		width: 14px;
		height: 14px;
		display: flex;
		align-items: center;
		justify-content: center;
		line-height: 1;
		pointer-events: none;
	}
	.tm-text-input {
		flex: 1;
		padding: 6px 8px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 12px;
		font-family: 'Consolas', monospace;
		outline: none;
		min-width: 0;
	}
	.tm-text-input:focus { border-color: #6366f1; }
	.tm-color-swatch {
		width: 30px;
		height: 30px;
		border-radius: 6px;
		border: 1px solid #d1d5db;
		flex-shrink: 0;
	}

	/* Empty */
	.tm-empty {
		text-align: center;
		padding: 40px;
		color: #94a3b8;
	}
</style>
