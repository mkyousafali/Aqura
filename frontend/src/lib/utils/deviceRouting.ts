export const MOBILE_BREAKPOINT_PX = 768;

export interface DeviceSignals {
  userAgent?: string;
  userAgentDataMobile?: boolean;
  viewportWidth?: number;
  coarsePointer?: boolean;
}

/** Detect phones/tablets as well as narrow responsive browser windows. */
export function isMobileDevice(signals?: DeviceSignals): boolean {
  if (!signals && typeof window === "undefined") return false;

  const userAgent = signals?.userAgent ?? (typeof navigator !== "undefined" ? navigator.userAgent : "");
  const userAgentDataMobile = signals?.userAgentDataMobile ??
    (typeof navigator !== "undefined"
      ? (navigator as Navigator & { userAgentData?: { mobile?: boolean } }).userAgentData?.mobile
      : false);
  const viewportWidth = signals?.viewportWidth ?? (typeof window !== "undefined" ? window.innerWidth : undefined);
  const coarsePointer = signals?.coarsePointer ??
    (typeof window !== "undefined" && typeof window.matchMedia === "function" && window.matchMedia("(pointer: coarse)").matches);

  const mobileUserAgent = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(userAgent);
  const narrowViewport = typeof viewportWidth === "number" && viewportWidth <= MOBILE_BREAKPOINT_PX;
  const touchSizedViewport = Boolean(coarsePointer && typeof viewportWidth === "number" && viewportWidth <= 1024);
  return Boolean(userAgentDataMobile || mobileUserAgent || narrowViewport || touchSizedViewport);
}

export function getDeviceLoginRoute(pathname: string, signals?: DeviceSignals): string {
  if (!isMobileDevice(signals)) {
    return pathname.startsWith("/desktop-interface") ? "/login/employee?mode=desktop" : "/login";
  }

  // Existing mobile sessions stay in their login flow. Desktop deep links go
  // to the public page so Team Login remains the only mobile entry point.
  return pathname.startsWith("/mobile-interface") ? "/mobile-interface/login" : "/login";
}

export function getMobileRouteGuardTarget(pathname: string, authenticated: boolean, signals?: DeviceSignals): string | null {
  if (!isMobileDevice(signals)) return null;
  if (pathname.startsWith("/desktop-interface")) return authenticated ? "/mobile-interface" : "/login";
  if (pathname.startsWith("/login/employee")) return "/login";
  return null;
}
