/**
 * Interface Session Guard — up to two active tab sessions per interface.
 *
 * Generalizes the Cashier interface's device-binding pattern
 * (`cashier_device_bindings` / `claim_cashier_session` / see
 * `$lib/stores/cashierAuth.ts`) to the Mobile and Desktop interfaces, backed
 * by `user_device_sessions` + `claim_interface_session` /
 * `heartbeat_interface_session` / `release_interface_session`.
 *
 * Each tab has its own sessionStorage identity. A refresh keeps the session;
 * a third tab for the same interface rotates the oldest token. The evicted
 * tab is detected via Realtime with a heartbeat fallback (~20s).
 *
 * Applies to ALL users, including Master Admin — no exemptions.
 */

import { supabase } from './supabase';

export type InterfaceType = 'mobile' | 'desktop';

const HEARTBEAT_INTERVAL_MS = 20_000;
const TAB_ID_KEY = 'aqura-interface-tab-id';
const TOKEN_KEY_PREFIX = 'aqura-interface-session-token';

let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
let initialCheckTimeout: ReturnType<typeof setTimeout> | null = null;
let bindingChannel: any = null;
let onForcedLogout: (() => void) | null = null;
let activeUserId: string | null = null;
let activeInterfaceType: InterfaceType | null = null;
let activeToken: string | null = null;
let identityChannel: BroadcastChannel | null = null;

function ensureIdentityResponder(): void {
  if (typeof BroadcastChannel === 'undefined' || identityChannel) return;
  identityChannel = new BroadcastChannel('aqura-interface-tab-identities');
  identityChannel.onmessage = (event) => {
    if (event.data?.type === 'probe' && event.data?.id === getDeviceId()) {
      identityChannel?.postMessage({ type: 'occupied', id: event.data.id, nonce: event.data.nonce });
    }
  };
}

async function ensureUniqueTabIdentity(): Promise<void> {
  ensureIdentityResponder();
  if (!identityChannel) return;
  const id = getDeviceId();
  const nonce = crypto.randomUUID?.() || Math.random().toString(36).slice(2);
  let occupied = false;
  const listener = (event: MessageEvent) => {
    if (event.data?.type === 'occupied' && event.data?.id === id && event.data?.nonce === nonce) occupied = true;
  };
  identityChannel.addEventListener('message', listener);
  identityChannel.postMessage({ type: 'probe', id, nonce });
  await new Promise((resolve) => setTimeout(resolve, 80));
  identityChannel.removeEventListener('message', listener);
  if (occupied) {
    sessionStorage.setItem(TAB_ID_KEY, crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`);
    for (let i = sessionStorage.length - 1; i >= 0; i -= 1) {
      const key = sessionStorage.key(i);
      if (key?.startsWith(`${TOKEN_KEY_PREFIX}:`)) sessionStorage.removeItem(key);
    }
  }
}

function getDeviceId(): string {
  if (typeof window === 'undefined') return 'server';
  try {
    // sessionStorage is intentionally tab-scoped: a refresh retains the ID,
    // while a newly opened tab claims its own session slot.
    let id = sessionStorage.getItem(TAB_ID_KEY);
    if (!id) {
      id = crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
      sessionStorage.setItem(TAB_ID_KEY, id);
    }
    return id;
  } catch {
    return 'unknown-device';
  }
}

function tokenKey(userId: string, interfaceType: InterfaceType): string {
  return `${TOKEN_KEY_PREFIX}:${userId}:${interfaceType}`;
}

export function getCurrentInterfaceSessionToken(
  userId: string,
  interfaceType: InterfaceType
): string | null {
  if (typeof window === 'undefined') return null;
  return sessionStorage.getItem(tokenKey(userId, interfaceType));
}

function getDeviceName(): string {
  if (typeof navigator === 'undefined') return 'Unknown device';
  const ua = navigator.userAgent;
  const browser = /Edg\//.test(ua)
    ? 'Edge'
    : /Chrome\//.test(ua)
      ? 'Chrome'
      : /Firefox\//.test(ua)
        ? 'Firefox'
        : /Safari\//.test(ua)
          ? 'Safari'
          : 'Browser';
  const os = /Windows/.test(ua)
    ? 'Windows'
    : /Mac OS/.test(ua)
      ? 'macOS'
      : /Android/.test(ua)
        ? 'Android'
        : /iPhone|iPad/.test(ua)
          ? 'iOS'
          : /Linux/.test(ua)
            ? 'Linux'
            : '';
  return [browser, os].filter(Boolean).join(' on ');
}

/**
 * Resume this tab's session after refresh, or claim a new slot. The database
 * keeps the newest two sessions and rotates the oldest token when necessary.
 */
export async function claimInterfaceSession(
  userId: string,
  interfaceType: InterfaceType
): Promise<string | null> {
  try {
    await ensureUniqueTabIdentity();
    const savedToken = getCurrentInterfaceSessionToken(userId, interfaceType);
    if (savedToken) {
      const { data, error } = await supabase.rpc('heartbeat_interface_session', {
        p_user_id: userId,
        p_device_type: interfaceType,
        p_session_token: savedToken
      });
      if (!error && data?.valid) return savedToken;
      sessionStorage.removeItem(tokenKey(userId, interfaceType));
    }

    const { data, error } = await supabase.rpc('claim_interface_session', {
      p_user_id: userId,
      p_device_type: interfaceType,
      p_device_id: getDeviceId(),
      p_device_name: getDeviceName(),
      p_user_agent: typeof navigator !== 'undefined' ? navigator.userAgent : null
    });

    if (error || !data?.success || !data?.session_token) {
      console.error('claim_interface_session failed:', error || data);
      return null;
    }
    const token = data.session_token as string;
    sessionStorage.setItem(tokenKey(userId, interfaceType), token);
    return token;
  } catch (e) {
    console.error('claimInterfaceSession exception:', e);
    return null;
  }
}

/**
 * Start heartbeat + Realtime guard that force-logs-out this device the
 * moment another device claims the same (user, interface) slot.
 */
export function startInterfaceSessionGuard(
  userId: string,
  interfaceType: InterfaceType,
  token: string,
  onKicked: () => void
): void {
  stopInterfaceSessionGuard();

  activeUserId = userId;
  activeInterfaceType = interfaceType;
  activeToken = token;
  onForcedLogout = onKicked;

  const checkOnce = async () => {
    try {
      const { data, error } = await supabase.rpc('heartbeat_interface_session', {
        p_user_id: userId,
        p_device_type: interfaceType,
        p_session_token: token
      });
      // Transient network/db errors: do not kick, wait for next tick
      if (error) return;
      if (!data?.valid) {
        console.warn('[InterfaceSessionGuard] Session invalid — logged in on another device');
        const cb = onForcedLogout;
        stopInterfaceSessionGuard();
        cb?.();
      }
    } catch {
      // transient — ignore
    }
  };

  heartbeatTimer = setInterval(checkOnce, HEARTBEAT_INTERVAL_MS);
  // Initial check shortly after mount (gives realtime a moment too). Tracked
  // so a subsequent startInterfaceSessionGuard() call (e.g. initializeAuth()
  // firing twice — once from the root layout, once from an interface layout
  // — both claiming a session for the same login) can cancel it. Left
  // untracked, this stale check fires ~1s later using the OLD token, finds
  // it invalid (correctly — a newer claim from the same login already
  // rotated it) and force-logs-out the device that just legitimately
  // claimed the session, immediately after login.
  initialCheckTimeout = setTimeout(checkOnce, 1000);

  // Realtime — instant kick when another device rotates the binding
  try {
    bindingChannel = supabase
      .channel(`interface-session-${interfaceType}-${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_device_sessions',
          filter: `user_id=eq.${userId}`
        },
        (payload: any) => {
          const newRow = payload.new || payload.record;
          if (!newRow || newRow.device_type !== interfaceType || newRow.device_id !== getDeviceId()) return;
          if (newRow.session_token && newRow.session_token !== token) {
            console.warn('[InterfaceSessionGuard] Realtime: token rotated by another device');
            const cb = onForcedLogout;
            stopInterfaceSessionGuard();
            cb?.();
          }
        }
      )
      .subscribe();
  } catch (e) {
    console.warn('[InterfaceSessionGuard] Realtime subscribe failed (heartbeat will cover):', e);
  }
}

export function stopInterfaceSessionGuard(): void {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
  if (initialCheckTimeout) {
    clearTimeout(initialCheckTimeout);
    initialCheckTimeout = null;
  }
  if (bindingChannel) {
    try {
      bindingChannel.unsubscribe?.();
    } catch {
      // ignore
    }
    bindingChannel = null;
  }
  onForcedLogout = null;
  activeUserId = null;
  activeInterfaceType = null;
  activeToken = null;
}

/**
 * Release the binding on explicit logout (best-effort, non-blocking). Only
 * releases if this call matches the guard's currently tracked session, so a
 * stale logout call can't clobber a newer device's claim.
 */
export async function releaseInterfaceSession(
  userId: string,
  interfaceType: InterfaceType
): Promise<void> {
  if (activeUserId !== userId || activeInterfaceType !== interfaceType || !activeToken) return;
  const token = activeToken;
  try {
    await supabase.rpc('release_interface_session', {
      p_user_id: userId,
      p_device_type: interfaceType,
      p_session_token: token
    });
    if (typeof window !== 'undefined') {
      sessionStorage.removeItem(tokenKey(userId, interfaceType));
    }
  } catch (e) {
    console.warn('releaseInterfaceSession failed:', e);
  }
}
