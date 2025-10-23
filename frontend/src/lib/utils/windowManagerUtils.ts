import { windowManager } from '$lib/stores/windowManager';
import type { WindowConfig } from '$lib/stores/windowManager';

/**
 * Utility to get the appropriate window manager based on context
 * Returns proxy for popout windows or real manager for main app
 */
export function getWindowManager() {
	// Check if we're in a popout window (iframe context)
	const isInPopout = typeof window !== 'undefined' && 
		window.parent !== window && 
		window.location.search.includes('component=');
	
	if (isInPopout && typeof window !== 'undefined' && window.windowManagerProxy) {
		console.log('🪟 Using window manager proxy for popout');
		return window.windowManagerProxy;
	}
	
	console.log('🪟 Using main window manager');
	return windowManager;
}

/**
 * Safe window opener that works in both main app and popout contexts
 */
export function openWindow(config: Partial<WindowConfig> & { title: string; component: any }) {
	const manager = getWindowManager();
	return manager.openWindow(config);
}

// Type declaration for the global windowManagerProxy
declare global {
	interface Window {
		windowManagerProxy?: {
			openWindow: (config: Partial<WindowConfig> & { title: string; component: any }) => string;
		};
	}
}