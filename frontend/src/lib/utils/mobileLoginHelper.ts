/**
 * Mobile Login Helper
 * Push notification functionality removed
 */

/**
 * Call this function after a successful user login
 */
export async function handleUserLogin(
  userId: string,
  isFirstLogin?: boolean,
): Promise<void> {
  try {
    console.log("🔐 User logged in:", userId);
    // Push notification prompts removed
  } catch (error) {
    console.error("❌ Error in user login handler:", error);
  }
}

/**
 * Manually trigger push notification prompt for current user
 * Push notification functionality removed
 */
export async function manuallyPromptPushNotifications(
  userId: string,
): Promise<boolean> {
  console.log("Push notification functionality removed");
  return false;
}

/**
 * Check if user has already been prompted for push notifications on this device
 */
export function hasBeenPromptedForPushNotifications(): boolean {
  const deviceId = localStorage.getItem("aqura-device-id");
  if (!deviceId) return false;

  const promptKey = `aqura-push-prompted-${deviceId}`;
  return localStorage.getItem(promptKey) !== null;
}

/**
 * Get the push notification prompt status for this device
 */
export function getPushNotificationPromptStatus():
  | "never"
  | "granted"
  | "denied"
  | "declined" {
  const deviceId = localStorage.getItem("aqura-device-id");
  if (!deviceId) return "never";

  const promptKey = `aqura-push-prompted-${deviceId}`;
  const status = localStorage.getItem(promptKey);

  if (!status) return "never";
  return status as "granted" | "denied" | "declined";
}

/**
 * Reset push notification prompt status (for testing or settings reset)
 */
export function resetPushNotificationPromptStatus(): void {
  const deviceId = localStorage.getItem("aqura-device-id");
  if (deviceId) {
    const promptKey = `aqura-push-prompted-${deviceId}`;
    localStorage.removeItem(promptKey);
    console.log("🔄 Push notification prompt status reset");
  }
}
