/**
 * Hook for the Windows wrapper apps (Aqura Desktop / Aqura Cashier, built with Electron).
 *
 * When the user closes one of those apps, the wrapper dispatches `aqura-native-logout` on
 * `window` and waits for every registered handler to settle before it quits. Handlers should
 * run the app's own existing logout (nothing is duplicated here), so the session is ended the
 * same way as pressing Logout. Ordinary browsers / PWA / Android never dispatch the event, so
 * registering a handler has no effect there.
 */
export const NATIVE_LOGOUT_EVENT = 'aqura-native-logout';

type NativeLogoutDetail = { waitUntil?: (task: Promise<unknown>) => void };

export function onNativeLogout(handler: () => Promise<unknown> | unknown): () => void {
	if (typeof window === 'undefined') return () => {};

	const listener = (event: Event) => {
		const detail = (event as CustomEvent<NativeLogoutDetail>).detail;
		detail?.waitUntil?.(Promise.resolve().then(handler));
	};

	window.addEventListener(NATIVE_LOGOUT_EVENT, listener);
	return () => window.removeEventListener(NATIVE_LOGOUT_EVENT, listener);
}
