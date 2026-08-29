/**
 * Interface Session Guard — single active session per (user, interface).
 *
 * Generalizes the Cashier interface's device-binding pattern
 * (`cashier_device_bindings` / `claim_cashier_session` / see
 * `$lib/stores/cashierAuth.ts`) to the Mobile and Desktop interfaces, backed
 * by `user_device_sessions` + `claim_interface_session` /
 * `heartbeat_interface_session` / `release_interface_session`.
 *
 * Logging in on a new device for the same interface overwrites the single
 * binding row for that (user_id, device_type); the previous device is
 * detected via Realtime (instant) with a heartbeat fallback (~20s) and is
 * force-logged-out silently, no warning message.
 *
 * Applies to ALL users, including Master Admin — no exemptions.
 */

import { supabase } from './supabase';

export type InterfaceType = 'mobile' | 'desktop';

const HEARTBEAT_INTERVAL_MS = 20_000;
const DEVICE_ID_KEY = 'aqura-device-id';

let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
let bindingChannel: any = null;
let onForcedLogout: (() => void) | null = null;
let activeUserId: string | null = null;
let activeInterfaceType: InterfaceType | null = null;
let activeToken: string | null = null;

function getDeviceId(): string {
  if (typeof window === 'undefined') return 'server';
  try {
    let id = localStorage.getItem(DEVICE_ID_KEY);
    if (!id) {
      id = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      localStorage.setItem(DEVICE_ID_KEY, id);
    }
    return id;
  } catch {
    return 'unknown-device';
  }
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
 * Claim the single active session slot for this interface. Any other device
 * currently holding this user's session for the same interface will be
 * force-logged-out once its guard detects the rotation.
 */
export async function claimInterfaceSession(
  userId: string,
  interfaceType: InterfaceType
): Promise<string | null> {
  try {
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
    return data.session_token as string;
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
  // Initial check shortly after mount (gives realtime a moment too)
  setTimeout(checkOnce, 1000);

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
          if (!newRow || newRow.device_type !== interfaceType) return;
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
  } catch (e) {
    console.warn('releaseInterfaceSession failed:', e);
  }
}
