/**
 * Cashier device detection & ID helpers.
 *
 * The Windows Electron app injects `window.aquraDevice` via preload.js with:
 *   { id: <hardware machine id>, name: <hostname>, appKind: 'windows' }
 *
 * PWA / web browsers will not have this object — `isWindowsApp()` returns false
 * and the single-device login restriction is skipped.
 */

declare global {
	interface Window {
		aquraDevice?: {
			id: string;
			name?: string;
			appKind: string;
		};
	}
}

const DEVICE_ID_FALLBACK_KEY = 'aqura-cashier-device-id';

export function isWindowsApp(): boolean {
	if (typeof window === 'undefined') return false;
	return window.aquraDevice?.appKind === 'windows';
}

export function getDeviceId(): string {
	if (typeof window === 'undefined') return 'ssr';

	// Prefer hardware machine-id from Electron preload
	const hw = window.aquraDevice?.id;
	if (hw && hw.length > 0) return hw;

	// Fallback: random UUID stored in localStorage (web only)
	let id = '';
	try {
		id = localStorage.getItem(DEVICE_ID_FALLBACK_KEY) || '';
		if (!id) {
			id = `web-${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
			localStorage.setItem(DEVICE_ID_FALLBACK_KEY, id);
		}
	} catch {
		id = `mem-${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
	}
	return id;
}

export function getDeviceName(): string {
	if (typeof window === 'undefined') return 'unknown';
	return window.aquraDevice?.name || navigator.userAgent.slice(0, 80);
}
