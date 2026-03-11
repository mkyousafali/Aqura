import { writable, get } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';

export interface MobileThemeColors {
	// Header/Top Bar
	header_bg: string;
	header_text: string;
	header_icon: string;
	header_border: string;

	// Navigation/Bottom Bar
	navbar_bg: string;
	navbar_border: string;
	navbar_btn_active_bg: string;
	navbar_btn_active_text: string;
	navbar_btn_inactive_bg: string;
	navbar_btn_inactive_text: string;
	navbar_btn_hover_bg: string;

	// Cards
	card_bg: string;
	card_text: string;
	card_border: string;
	card_shadow: string;

	// Buttons
	button_primary_bg: string;
	button_primary_text: string;
	button_primary_hover: string;
	button_secondary_bg: string;
	button_secondary_text: string;
	button_secondary_hover: string;

	// Input fields
	input_bg: string;
	input_border: string;
	input_text: string;
	input_focus_border: string;
	input_placeholder: string;

	// Badges and Status
	badge_primary_bg: string;
	badge_primary_text: string;
	badge_success_bg: string;
	badge_success_text: string;
	badge_warning_bg: string;
	badge_warning_text: string;
	badge_error_bg: string;
	badge_error_text: string;

	// Backgrounds
	bg_primary: string;
	bg_secondary: string;
	bg_tertiary: string;

	// Text
	text_primary: string;
	text_secondary: string;
	text_tertiary: string;

	// Accents
	accent_primary: string;
	accent_secondary: string;

	// Divider
	divider_color: string;
}

export interface MobileTheme {
	id: number;
	name: string;
	description: string;
	is_default: boolean;
	colors: MobileThemeColors;
	created_at?: string;
	updated_at?: string;
	created_by?: string;
}

// Default (Standard) mobile theme
export const DEFAULT_MOBILE_THEME: MobileThemeColors = {
	header_bg: '#0066b2',
	header_text: '#FFFFFF',
	header_icon: '#FFFFFF',
	header_border: 'rgba(255, 255, 255, 0.2)',

	navbar_bg: '#F9FAFB',
	navbar_border: 'rgba(0, 0, 0, 0.1)',
	navbar_btn_active_bg: '#0066b2',
	navbar_btn_active_text: '#FFFFFF',
	navbar_btn_inactive_bg: 'transparent',
	navbar_btn_inactive_text: '#6B7280',
	navbar_btn_hover_bg: '#E5E7EB',

	card_bg: '#FFFFFF',
	card_text: '#1F2937',
	card_border: 'rgba(0, 0, 0, 0.1)',
	card_shadow: '0 1px 3px rgba(0, 0, 0, 0.1)',

	button_primary_bg: '#0066b2',
	button_primary_text: '#FFFFFF',
	button_primary_hover: '#004d8c',
	button_secondary_bg: '#E5E7EB',
	button_secondary_text: '#1F2937',
	button_secondary_hover: '#D1D5DB',

	input_bg: '#FFFFFF',
	input_border: 'rgba(0, 0, 0, 0.15)',
	input_text: '#1F2937',
	input_focus_border: '#0066b2',
	input_placeholder: '#9CA3AF',

	badge_primary_bg: '#0066b2',
	badge_primary_text: '#FFFFFF',
	badge_success_bg: '#10B981',
	badge_success_text: '#FFFFFF',
	badge_warning_bg: '#F59E0B',
	badge_warning_text: '#FFFFFF',
	badge_error_bg: '#EF4444',
	badge_error_text: '#FFFFFF',

	bg_primary: '#FFFFFF',
	bg_secondary: '#F9FAFB',
	bg_tertiary: '#F3F4F6',

	text_primary: '#1F2937',
	text_secondary: '#6B7280',
	text_tertiary: '#9CA3AF',

	accent_primary: '#0066b2',
	accent_secondary: '#1DBC83',

	divider_color: 'rgba(0, 0, 0, 0.1)'
};

// CSS variable names mapped from theme keys
const CSS_VAR_MAP: Record<keyof MobileThemeColors, string> = {
	header_bg: '--theme-header-bg',
	header_text: '--theme-header-text',
	header_icon: '--theme-header-icon',
	header_border: '--theme-header-border',

	navbar_bg: '--theme-navbar-bg',
	navbar_border: '--theme-navbar-border',
	navbar_btn_active_bg: '--theme-navbar-btn-active-bg',
	navbar_btn_active_text: '--theme-navbar-btn-active-text',
	navbar_btn_inactive_bg: '--theme-navbar-btn-inactive-bg',
	navbar_btn_inactive_text: '--theme-navbar-btn-inactive-text',
	navbar_btn_hover_bg: '--theme-navbar-btn-hover-bg',

	card_bg: '--theme-card-bg',
	card_text: '--theme-card-text',
	card_border: '--theme-card-border',
	card_shadow: '--theme-card-shadow',

	button_primary_bg: '--theme-button-primary-bg',
	button_primary_text: '--theme-button-primary-text',
	button_primary_hover: '--theme-button-primary-hover',
	button_secondary_bg: '--theme-button-secondary-bg',
	button_secondary_text: '--theme-button-secondary-text',
	button_secondary_hover: '--theme-button-secondary-hover',

	input_bg: '--theme-input-bg',
	input_border: '--theme-input-border',
	input_text: '--theme-input-text',
	input_focus_border: '--theme-input-focus-border',
	input_placeholder: '--theme-input-placeholder',

	badge_primary_bg: '--theme-badge-primary-bg',
	badge_primary_text: '--theme-badge-primary-text',
	badge_success_bg: '--theme-badge-success-bg',
	badge_success_text: '--theme-badge-success-text',
	badge_warning_bg: '--theme-badge-warning-bg',
	badge_warning_text: '--theme-badge-warning-text',
	badge_error_bg: '--theme-badge-error-bg',
	badge_error_text: '--theme-badge-error-text',

	bg_primary: '--theme-bg-primary',
	bg_secondary: '--theme-bg-secondary',
	bg_tertiary: '--theme-bg-tertiary',

	text_primary: '--theme-text-primary',
	text_secondary: '--theme-text-secondary',
	text_tertiary: '--theme-text-tertiary',

	accent_primary: '--theme-accent-primary',
	accent_secondary: '--theme-accent-secondary',

	divider_color: '--theme-divider-color'
};

function createMobileThemeStore() {
	const { subscribe, set, update } = writable<MobileThemeColors>(DEFAULT_MOBILE_THEME);

	function applyToDOM(colors: MobileThemeColors) {
		if (typeof document === 'undefined') return;
		const root = document.documentElement;
		for (const [key, cssVar] of Object.entries(CSS_VAR_MAP)) {
			const value = colors[key as keyof MobileThemeColors];
			if (value) {
				root.style.setProperty(cssVar, value);
			}
		}
	}

	return {
		subscribe,

		/** Load the current user's mobile theme from the database and apply it */
		async loadUserTheme(userId: string) {
			try {
				// First check if user has an assigned mobile theme
				const { data: assignment } = await supabase
					.from('user_mobile_theme_assignments')
					.select('theme_id')
					.eq('user_id', userId)
					.maybeSingle();

				let themeData: any = null;

				if (assignment?.theme_id) {
					const { data } = await supabase
						.from('mobile_themes')
						.select('*')
						.eq('id', assignment.theme_id)
						.single();
					themeData = data;
				}

				if (!themeData) {
					// Fall back to default theme
					const { data } = await supabase
						.from('mobile_themes')
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
					set(DEFAULT_MOBILE_THEME);
					applyToDOM(DEFAULT_MOBILE_THEME);
				}
			} catch (err) {
				console.warn('Failed to load mobile user theme, using defaults:', err);
				set(DEFAULT_MOBILE_THEME);
				applyToDOM(DEFAULT_MOBILE_THEME);
			}
		},

		/** Apply a theme's colors to the DOM (for live preview) */
		preview(colors: MobileThemeColors) {
			set(colors);
			applyToDOM(colors);
		},

		/** Reset to default theme */
		resetToDefault() {
			set(DEFAULT_MOBILE_THEME);
			applyToDOM(DEFAULT_MOBILE_THEME);
		},

		/** Apply current store colors to DOM (useful on mount) */
		applyCurrentToDOM() {
			const current = get({ subscribe });
			applyToDOM(current);
		}
	};
}

/** Extract MobileThemeColors from a database row */
export function extractColors(row: any): MobileThemeColors {
	const colors: MobileThemeColors = { ...DEFAULT_MOBILE_THEME };
	// Colors are stored in a JSONB 'colors' column, or may be top-level
	const source = row.colors && typeof row.colors === 'object' ? row.colors : row;
	const parsed = typeof source === 'string' ? JSON.parse(source) : source;
	for (const [key] of Object.entries(CSS_VAR_MAP)) {
		if (parsed[key] !== undefined && parsed[key] !== null) {
			colors[key as keyof MobileThemeColors] = parsed[key];
		}
	}
	return colors;
}

// Export the store instance
export const mobileThemeStore = createMobileThemeStore();
