/**
 * Admin utilities for manual database cleanup
 * Push notification cleanup removed
 */

/**
 * Run cleanup for all users - push functionality removed
 */
export async function runGlobalCleanup(): Promise<void> {
  console.log("⚠️ Push subscription cleanup removed");
  return;
}

/**
 * Run cleanup for inactive subscriptions - push functionality removed
 */
export async function cleanupInactive(
  daysInactive: number = 30,
): Promise<void> {
  console.log("⚠️ Push subscription cleanup removed");
  return;
}

/**
 * Get subscription statistics - push functionality removed
 */
export async function getCleanupStats(): Promise<void> {
  console.log("⚠️ Push subscription stats removed");
  return;
}

/**
 * Initialize admin functions on window object for console access
 * Call this in development to add admin utilities to window
 */
export function initAdminCleanupConsole(): void {
  if (typeof window !== "undefined") {
    // Make functions available globally for console access
    (window as any).runGlobalCleanup = runGlobalCleanup;
    (window as any).cleanupInactive = cleanupInactive;
    (window as any).getCleanupStats = getCleanupStats;

    console.log("🔧 Admin cleanup utilities loaded (push functionality removed)");
  }
}
