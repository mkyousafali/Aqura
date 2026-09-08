/**
 * Cashier Authentication Store
 *
 * Separate authentication system for cashier interface to avoid conflicts
 * with the main desktop authentication system.
 *
 * Windows-app only: enforces single-device login per cashier user via the
 * `cashier_device_bindings` table + `claim_cashier_session`,
 * `heartbeat_cashier_session`, `release_cashier_session` RPCs. PWA / web
 * users are unrestricted (the helpers below short-circuit when
 * `isWindowsApp()` returns false).
 */

import { writable, get } from 'svelte/store';
import { isWindowsApp, getDeviceId, getDeviceName } from '$lib/utils/cashierDevice';

export interface CashierUser {
	id: string;
	username: string;
	employee_id?: string;
	branch_id?: string;
	full_name: string;
	employeeName: string;
	name: string;
	role: string;
}

export interface CashierBranch {
	id: string;
	name_ar: string;
	name_en: string;
}

// Cashier-specific authentication stores (separate from main auth)
export const cashierUser = writable<CashierUser | null>(null);
export const cashierBranch = writable<CashierBranch | null>(null);
export const isCashierAuthenticated = writable<boolean>(false);
export const cashierSessionToken = writable<string | null>(null);

// Session storage keys
const CASHIER_USER_KEY = 'cashier_user';
const CASHIER_BRANCH_KEY = 'cashier_branch';
const CASHIER_TOKEN_KEY = 'cashier_session_token';

// Module-level guards for heartbeat / realtime
let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
let bindingChannel: any = null;
let onForcedLogout: (() => void) | null = null;
const HEARTBEAT_INTERVAL_MS = 20_000;

/**
 * Initialize cashier session from sessionStorage
 */
export function initCashierSession() {
	if (typeof window === 'undefined') return;

	try {
		const savedUser = sessionStorage.getItem(CASHIER_USER_KEY);
		const savedBranch = sessionStorage.getItem(CASHIER_BRANCH_KEY);
		const savedToken = sessionStorage.getItem(CASHIER_TOKEN_KEY);

		if (savedUser && savedBranch) {
			const user = JSON.parse(savedUser) as CashierUser;
			const branch = JSON.parse(savedBranch) as CashierBranch;

			cashierUser.set(user);
			cashierBranch.set(branch);
			cashierSessionToken.set(savedToken || null);
			isCashierAuthenticated.set(true);

			return { user, branch, token: savedToken || null };
		}
	} catch (error) {
		console.error('Failed to restore cashier session:', error);
		clearCashierSession();
	}

	return null;
}

/**
 * Set cashier authentication
 */
export function setCashierAuth(
	user: CashierUser,
	branch: CashierBranch,
	sessionToken?: string | null
) {
	if (typeof window === 'undefined') return;

	try {
		// Save to stores
		cashierUser.set(user);
		cashierBranch.set(branch);
		cashierSessionToken.set(sessionToken || null);
		isCashierAuthenticated.set(true);

		// Save to sessionStorage
		sessionStorage.setItem(CASHIER_USER_KEY, JSON.stringify(user));
		sessionStorage.setItem(CASHIER_BRANCH_KEY, JSON.stringify(branch));
		if (sessionToken) {
			sessionStorage.setItem(CASHIER_TOKEN_KEY, sessionToken);
		} else {
			sessionStorage.removeItem(CASHIER_TOKEN_KEY);
		}
	} catch (error) {
		console.error('Failed to set cashier authentication:', error);
	}
}

/**
 * Clear cashier authentication
 */
export function clearCashierSession() {
	if (typeof window === 'undefined') return;

	stopCashierSessionGuard();

	// Clear stores
	cashierUser.set(null);
	cashierBranch.set(null);
	cashierSessionToken.set(null);
	isCashierAuthenticated.set(false);

	// Clear sessionStorage
	try {
		sessionStorage.removeItem(CASHIER_USER_KEY);
		sessionStorage.removeItem(CASHIER_BRANCH_KEY);
		sessionStorage.removeItem(CASHIER_TOKEN_KEY);
	} catch (error) {
		console.error('Failed to clear cashier session:', error);
	}
}

// =====================================================================
// Windows single-device session enforcement
// =====================================================================

/**
 * Claim a Windows-only single-device session for this user. If the same
 * user is already bound to another Windows PC, the binding is replaced
 * and the previous device's heartbeat / realtime listener will force-
 * logout. Returns the new session_token, or null on web/PWA / failure.
 */
export async function claimWindowsCashierSession(userId: string): Promise<string | null> {
	if (!isWindowsApp()) return null;

	try {
		const { supabase } = await import('$lib/utils/supabase');
		const { data, error } = await supabase.rpc('claim_cashier_session', {
			p_user_id: userId,
			p_device_id: getDeviceId(),
			p_device_name: getDeviceName(),
			p_app_kind: 'windows'
		});

		if (error || !data?.success || !data?.session_token) {
			console.error('claim_cashier_session failed:', error || data);
			return null;
		}
		return data.session_token as string;
	} catch (e) {
		console.error('claimWindowsCashierSession exception:', e);
		return null;
	}
}

/**
 * Start heartbeat + realtime subscription that detects when this user
 * has logged in on another Windows device. On detection, invokes
 * `onKicked()`. No-op outside the Windows app.
 */
export async function startCashierSessionGuard(onKicked: () => void): Promise<void> {
	if (!isWindowsApp()) return;

	const userId = get(cashierUser)?.id;
	const token = get(cashierSessionToken);
	if (!userId || !token) return;

	stopCashierSessionGuard();
	onForcedLogout = onKicked;

	const { supabase } = await import('$lib/utils/supabase');

	const checkOnce = async () => {
		try {
			const { data, error } = await supabase.rpc('heartbeat_cashier_session', {
				p_user_id: userId,
				p_session_token: token
			});
			// On transient network/db errors, do not kick — wait for next tick
			if (error) return;
			if (!data?.valid) {
				console.warn('[CashierSessionGuard] Token invalid — another device claimed the session');
				const cb = onForcedLogout;
				stopCashierSessionGuard();
				cb?.();
			}
		} catch {
			// transient — ignore
		}
	};

	heartbeatTimer = setInterval(checkOnce, HEARTBEAT_INTERVAL_MS);
	// Initial check shortly after mount (gives realtime a moment too)
	setTimeout(checkOnce, 1000);

	// Realtime — instant kick when another device rotates the binding
	try {
		bindingChannel = supabase
			.channel(`cashier-binding-${userId}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'cashier_device_bindings',
					filter: `user_id=eq.${userId}`
				},
				(payload: any) => {
					const newRow = payload.new || payload.record;
					if (!newRow) return;
					if (newRow.session_token && newRow.session_token !== token) {
						console.warn('[CashierSessionGuard] Realtime: token rotated by another device');
						const cb = onForcedLogout;
						stopCashierSessionGuard();
						cb?.();
					}
				}
			)
			.subscribe();
	} catch (e) {
		console.warn('[CashierSessionGuard] Realtime subscribe failed (heartbeat will cover):', e);
	}
}

export function stopCashierSessionGuard(): void {
	if (heartbeatTimer) {
		clearInterval(heartbeatTimer);
		heartbeatTimer = null;
	}
	if (bindingChannel) {
		try {
			bindingChannel.unsubscribe?.();
		} catch {}
		bindingChannel = null;
	}
	onForcedLogout = null;
}

/**
 * Release the binding on explicit logout (best-effort, non-blocking).
 */
export async function releaseWindowsCashierSession(): Promise<void> {
	if (!isWindowsApp()) return;
	const userId = get(cashierUser)?.id;
	const token = get(cashierSessionToken);
	if (!userId || !token) return;

	try {
		const { supabase } = await import('$lib/utils/supabase');
		await supabase.rpc('release_cashier_session', {
			p_user_id: userId,
			p_session_token: token
		});
	} catch (e) {
		console.warn('releaseWindowsCashierSession failed:', e);
	}
}
