import { writable } from 'svelte/store';
import { browser } from '$app/environment';

// Interface preference types
export type InterfaceType = 'mobile' | 'desktop' | null;

// Interface preference store
export const interfacePreference = writable<InterfaceType>(null);

export class InterfacePreferenceService {
	private readonly PREFERENCE_KEY = 'aqura-interface-preference';
	private readonly USER_PREFERENCE_KEY = 'aqura-user-interface-preference';

	/**
	 * Initialize the interface preference service
	 */
	initialize(): void {
		if (!browser) return;

		const savedPreference = this.getStoredPreference();
		interfacePreference.set(savedPreference);
		
		
	}

	/**
	 * Set interface preference for the current user
	 */
	setPreference(preference: InterfaceType, userId?: string): void {
		if (!browser) return;

		

		// Store global preference
		if (preference) {
			localStorage.setItem(this.PREFERENCE_KEY, preference);
		} else {
			localStorage.removeItem(this.PREFERENCE_KEY);
		}

		// Store user-specific preference if userId provided
		if (userId) {
			const userPreferences = this.getUserPreferences();
			if (preference) {
				userPreferences[userId] = preference;
			} else {
				delete userPreferences[userId];
			}
			localStorage.setItem(this.USER_PREFERENCE_KEY, JSON.stringify(userPreferences));
		}

		// Update store
		interfacePreference.set(preference);
	}

	/**
	 * Get current interface preference
	 */
	getPreference(userId?: string): InterfaceType {
		if (!browser) return null;

		// First check user-specific preference
		if (userId) {
			const userPreferences = this.getUserPreferences();
			const userPreference = userPreferences[userId];
			if (userPreference) {
				
				return userPreference;
			}
		}

		// Fall back to global preference
		const globalPreference = this.getStoredPreference();
		
		return globalPreference;
	}

	/**
	 * Check if user has mobile preference
	 */
	isMobilePreferred(userId?: string): boolean {
		return this.getPreference(userId) === 'mobile';
	}

	/**
	 * Check if user has desktop preference
	 */
	isDesktopPreferred(userId?: string): boolean {
		return this.getPreference(userId) === 'desktop';
	}

	/**
	 * Clear preference for user (forces them to choose again)
	 */
	clearPreference(userId?: string): void {
		if (!browser) return;

		

		if (userId) {
			// Clear user-specific preference
			const userPreferences = this.getUserPreferences();
			delete userPreferences[userId];
			localStorage.setItem(this.USER_PREFERENCE_KEY, JSON.stringify(userPreferences));
		}

		// Clear global preference
		localStorage.removeItem(this.PREFERENCE_KEY);
		interfacePreference.set(null);
	}

	/**
	 * Force mobile interface for current session (stronger than preference)
	 */
	forceMobileInterface(userId?: string): void {
		
		this.setPreference('mobile', userId);
		
		// Set additional flags for extra persistence
		if (browser) {
			sessionStorage.setItem('aqura-force-mobile', 'true');
			localStorage.setItem('aqura-last-interface', 'mobile');
		}
	}

	/**
	 * Check if mobile interface is forced
	 */
	isMobileForced(): boolean {
		if (!browser) return false;
		
		const isForced = sessionStorage.getItem('aqura-force-mobile') === 'true';
		const lastInterface = localStorage.getItem('aqura-last-interface') === 'mobile';
		
		return isForced || lastInterface;
	}

	/**
	 * Get the appropriate route based on preference
	 */
	getAppropriateRoute(userId?: string, defaultRoute: string = '/'): string {
		const preference = this.getPreference(userId);
		
		if (preference === 'mobile' || this.isMobileForced()) {
			return '/mobile';
		}
		
		return defaultRoute;
	}

	/**
	 * Get the appropriate login route based on preference
	 */
	getAppropriateLoginRoute(userId?: string): string {
		const preference = this.getPreference(userId);
		
		if (preference === 'mobile' || this.isMobileForced()) {
			return '/mobile-login';
		}
		
		return '/login';
	}

	/**
	 * Handle notification click routing
	 */
	getNotificationRoute(notificationPath: string, userId?: string): string {
		const preference = this.getPreference(userId);
		
		// If user prefers mobile, ensure they stay in mobile interface
		if (preference === 'mobile' || this.isMobileForced()) {
			// Convert desktop routes to mobile routes
			if (notificationPath.startsWith('/tasks/')) {
				return notificationPath.replace('/tasks/', '/mobile/tasks/');
			}
			if (notificationPath.startsWith('/notifications/')) {
				return notificationPath.replace('/notifications/', '/mobile/notifications/');
			}
			// Default to mobile dashboard for unknown routes
			return '/mobile';
		}
		
		// Desktop users get the original route
		return notificationPath;
	}

	/**
	 * Private helper methods
	 */
	private getStoredPreference(): InterfaceType {
		try {
			const stored = localStorage.getItem(this.PREFERENCE_KEY);
			return stored === 'mobile' || stored === 'desktop' ? stored : null;
		} catch (error) {
			console.warn('🖥️ [InterfacePreference] Error reading stored preference:', error);
			return null;
		}
	}

	private getUserPreferences(): Record<string, InterfaceType> {
		try {
			const stored = localStorage.getItem(this.USER_PREFERENCE_KEY);
			return stored ? JSON.parse(stored) : {};
		} catch (error) {
			console.warn('🖥️ [InterfacePreference] Error reading user preferences:', error);
			return {};
		}
	}
}

// Singleton instance
export const interfacePreferenceService = new InterfacePreferenceService();

// Initialize when browser is available
if (browser) {
	interfacePreferenceService.initialize();
}
