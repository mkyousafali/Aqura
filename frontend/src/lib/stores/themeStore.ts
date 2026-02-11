import { writable, get } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';

export interface ThemeColors {
	// Taskbar
	taskbar_bg: string;
	taskbar_border: string;
	taskbar_btn_active_bg: string;
	taskbar_btn_active_text: string;
	taskbar_btn_inactive_bg: string;
	taskbar_btn_inactive_text: string;
	taskbar_btn_hover_border: string;
	taskbar_quick_access_bg: string;

	// Sidebar
	sidebar_bg: string;
	sidebar_text: string;
	sidebar_border: string;
	sidebar_favorites_bg: string;
	sidebar_favorites_text: string;

	// Section & subsection buttons
	section_btn_bg: string;
	section_btn_text: string;
	section_btn_hover_bg: string;
	section_btn_hover_text: string;
	subsection_btn_bg: string;
	subsection_btn_text: string;
	subsection_btn_hover_bg: string;
	subsection_btn_hover_text: string;

	// Submenu items
	submenu_item_bg: string;
	submenu_item_text: string;
	submenu_item_hover_bg: string;
	submenu_item_hover_text: string;

	// Logo bar
	logo_bar_bg: string;
	logo_bar_text: string;
	logo_border: string;

	// Window title bars
	window_title_active_bg: string;
	window_title_active_text: string;
	window_title_inactive_bg: string;
	window_title_inactive_text: string;
	window_border_active: string;

	// Desktop background
	desktop_bg: string;
	desktop_pattern_opacity: string;

	// Interface switch
	interface_switch_bg: string;
	interface_switch_hover_bg: string;
}

export interface Theme {
	id: number;
	name: string;
	description: string;
	is_default: boolean;
	colors: ThemeColors;
	created_at?: string;
	updated_at?: string;
	created_by?: string;
}

// Default (Standard) theme — matches current hardcoded colors
export const DEFAULT_THEME: ThemeColors = {
	taskbar_bg: 'rgba(0, 102, 178, 0.75)',
	taskbar_border: 'rgba(255, 255, 255, 0.2)',
	taskbar_btn_active_bg: 'linear-gradient(135deg, #4F46E5, #6366F1)',
	taskbar_btn_active_text: '#FFFFFF',
	taskbar_btn_inactive_bg: 'rgba(255, 255, 255, 0.95)',
	taskbar_btn_inactive_text: '#0B1220',
	taskbar_btn_hover_border: '#4F46E5',
	taskbar_quick_access_bg: 'rgba(255, 255, 255, 0.1)',

	sidebar_bg: '#374151',
	sidebar_text: '#e5e7eb',
	sidebar_border: '#1f2937',
	sidebar_favorites_bg: '#1d2c5e',
	sidebar_favorites_text: '#fcd34d',

	section_btn_bg: '#1DBC83',
	section_btn_text: '#FFFFFF',
	section_btn_hover_bg: '#3b82f6',
	section_btn_hover_text: '#FFFFFF',
	subsection_btn_bg: '#1DBC83',
	subsection_btn_text: '#FFFFFF',
	subsection_btn_hover_bg: '#3b82f6',
	subsection_btn_hover_text: '#FFFFFF',

	submenu_item_bg: '#FFFFFF',
	submenu_item_text: '#f97316',
	submenu_item_hover_bg: '#3b82f6',
	submenu_item_hover_text: '#FFFFFF',

	logo_bar_bg: 'linear-gradient(135deg, #15A34A 0%, #22C55E 100%)',
	logo_bar_text: '#FFFFFF',
	logo_border: '#F59E0B',

	window_title_active_bg: '#0066b2',
	window_title_active_text: '#FFFFFF',
	window_title_inactive_bg: 'linear-gradient(135deg, #F9FAFB, #E5E7EB)',
	window_title_inactive_text: '#374151',
	window_border_active: '#4F46E5',

	desktop_bg: '#F9FAFB',
	desktop_pattern_opacity: '0.4',

	interface_switch_bg: 'linear-gradient(145deg, #3b82f6, #2563eb)',
	interface_switch_hover_bg: 'linear-gradient(145deg, #2563eb, #1d4ed8)'
};

// All CSS variable names mapped from theme keys
const CSS_VAR_MAP: Record<keyof ThemeColors, string> = {
	taskbar_bg: '--theme-taskbar-bg',
	taskbar_border: '--theme-taskbar-border',
	taskbar_btn_active_bg: '--theme-taskbar-btn-active-bg',
	taskbar_btn_active_text: '--theme-taskbar-btn-active-text',
	taskbar_btn_inactive_bg: '--theme-taskbar-btn-inactive-bg',
	taskbar_btn_inactive_text: '--theme-taskbar-btn-inactive-text',
	taskbar_btn_hover_border: '--theme-taskbar-btn-hover-border',
	taskbar_quick_access_bg: '--theme-taskbar-quick-access-bg',

	sidebar_bg: '--theme-sidebar-bg',
	sidebar_text: '--theme-sidebar-text',
	sidebar_border: '--theme-sidebar-border',
	sidebar_favorites_bg: '--theme-sidebar-favorites-bg',
	sidebar_favorites_text: '--theme-sidebar-favorites-text',

	section_btn_bg: '--theme-section-btn-bg',
	section_btn_text: '--theme-section-btn-text',
	section_btn_hover_bg: '--theme-section-btn-hover-bg',
	section_btn_hover_text: '--theme-section-btn-hover-text',
	subsection_btn_bg: '--theme-subsection-btn-bg',
	subsection_btn_text: '--theme-subsection-btn-text',
	subsection_btn_hover_bg: '--theme-subsection-btn-hover-bg',
	subsection_btn_hover_text: '--theme-subsection-btn-hover-text',

	submenu_item_bg: '--theme-submenu-item-bg',
	submenu_item_text: '--theme-submenu-item-text',
	submenu_item_hover_bg: '--theme-submenu-item-hover-bg',
	submenu_item_hover_text: '--theme-submenu-item-hover-text',

	logo_bar_bg: '--theme-logo-bar-bg',
	logo_bar_text: '--theme-logo-bar-text',
	logo_border: '--theme-logo-border',

	window_title_active_bg: '--theme-window-title-active-bg',
	window_title_active_text: '--theme-window-title-active-text',
	window_title_inactive_bg: '--theme-window-title-inactive-bg',
	window_title_inactive_text: '--theme-window-title-inactive-text',
	window_border_active: '--theme-window-border-active',

	desktop_bg: '--theme-desktop-bg',
	desktop_pattern_opacity: '--theme-desktop-pattern-opacity',

	interface_switch_bg: '--theme-interface-switch-bg',
	interface_switch_hover_bg: '--theme-interface-switch-hover-bg'
};

function createThemeStore() {
	const { subscribe, set, update } = writable<ThemeColors>(DEFAULT_THEME);

	function applyToDOM(colors: ThemeColors) {
		if (typeof document === 'undefined') return;
		const root = document.documentElement;
		for (const [key, cssVar] of Object.entries(CSS_VAR_MAP)) {
			const value = colors[key as keyof ThemeColors];
			if (value) {
				root.style.setProperty(cssVar, value);
			}
		}
	}

	return {
		subscribe,

		/** Load the current user's theme from the database and apply it */
		async loadUserTheme(userId: string) {
			try {
				// First check if user has an assigned theme
				const { data: assignment } = await supabase
					.from('user_theme_assignments')
					.select('theme_id')
					.eq('user_id', userId)
					.single();

				let themeData: any = null;

				if (assignment?.theme_id) {
					const { data } = await supabase
						.from('desktop_themes')
						.select('*')
						.eq('id', assignment.theme_id)
						.single();
					themeData = data;
				}

				if (!themeData) {
					// Fall back to default theme
					const { data } = await supabase
						.from('desktop_themes')
						.select('*')
						.eq('is_default', true)
						.single();
					themeData = data;
				}

				if (themeData) {
					const colors = extractColors(themeData);
					set(colors);
					applyToDOM(colors);
				} else {
					// No themes in DB yet, use hardcoded defaults
					set(DEFAULT_THEME);
					applyToDOM(DEFAULT_THEME);
				}
			} catch (err) {
				console.warn('Failed to load user theme, using defaults:', err);
				set(DEFAULT_THEME);
				applyToDOM(DEFAULT_THEME);
			}
		},

		/** Apply a theme's colors to the DOM (for live preview) */
		preview(colors: ThemeColors) {
			set(colors);
			applyToDOM(colors);
		},

		/** Reset to default theme */
		resetToDefault() {
			set(DEFAULT_THEME);
			applyToDOM(DEFAULT_THEME);
		},

		/** Apply current store colors to DOM (useful on mount) */
		applyCurrentToDOM() {
			const current = get({ subscribe });
			applyToDOM(current);
		}
	};
}

/** Extract ThemeColors from a database row */
export function extractColors(row: Record<string, any>): ThemeColors {
	const colors: Partial<ThemeColors> = {};
	for (const key of Object.keys(DEFAULT_THEME) as (keyof ThemeColors)[]) {
		colors[key] = row[key] ?? DEFAULT_THEME[key];
	}
	return colors as ThemeColors;
}

export const themeStore = createThemeStore();
