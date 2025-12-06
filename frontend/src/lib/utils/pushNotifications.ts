// Import shared supabase clients to avoid multiple instances
import { supabase } from "./supabase";
import { browser } from "$app/environment";
import { currentUser as persistentCurrentUser } from "./persistentAuth";
import { get } from "svelte/store";
import { PushSubscriptionCleanupService } from "./pushSubscriptionCleanup";

// Push notification configuration
const VAPID_PUBLIC_KEY =
  import.meta.env.VITE_VAPID_PUBLIC_KEY || "your-vapid-public-key"; // Will need to be set
const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ||
  "https://supabase.urbanaqura.com";

interface DeviceRegistration {
  user_id: string;
  device_id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  device_type: "mobile" | "desktop";
  browser_name: string;
  user_agent: string;
  is_active: boolean;
  last_seen: string;
}

interface NotificationPayload {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  image?: string;
  data?: any;
  actions?: Array<{
    action: string;
    title: string;
    icon?: string;
  }>;
}

export class PushNotificationService {
  private swRegistration: ServiceWorkerRegistration | null = null;
  private subscription: PushSubscription | null = null;
  private registrationRetries: number = 0;
  private maxRetries: number = 3;
  private retryDelay: number = 5000; // 5 seconds
  private isRegistering: boolean = false;
  
  // Circuit breaker for device registration
  private deviceRegistrationFailures: number = 0;
  private maxConsecutiveFailures: number = 5;
  private isCircuitBreakerOpen: boolean = false;
  private circuitBreakerResetTime: number = 0;
  private circuitBreakerTimeout: number = 300000; // 5 minutes
  
  // Track last registration attempt to prevent rapid retries
  private lastRegistrationAttempt: number = 0;
  private minTimeBetweenRetries: number = 10000; // 10 seconds minimum

  /**
   * Initialize push notification service
   */
  async initialize(): Promise<boolean> {
    if (
      !browser ||
      !("serviceWorker" in navigator) ||
      !("PushManager" in window)
    ) {
      console.warn("Push notifications not supported in this browser");
      return false;
    }

    try {
      // Register service worker for push notifications
      // In development, use custom push service worker
      // In production, use the PWA service worker
      if (import.meta.env.DEV) {
        console.log(
          "🔧 Development mode: Registering custom push service worker",
        );
        this.swRegistration = await navigator.serviceWorker.register(
          "/sw-push.js",
          {
            scope: "/",
          },
        );
        console.log("✅ Custom push service worker registered");

        // Force immediate activation if needed
        if (this.swRegistration.installing) {
          console.log(
            "🔄 Service worker installing, waiting for activation...",
          );
          await new Promise((resolve) => {
            const worker = this.swRegistration!.installing!;
            worker.addEventListener("statechange", () => {
              console.log("🔄 Service worker state changed to:", worker.state);
              if (worker.state === "activated") {
                console.log("🎯 Service worker activated!");
                resolve(true);
              }
            });
          });
        } else if (this.swRegistration.waiting) {
          console.log(
            "🔄 Service worker waiting, sending skip waiting message...",
          );
          this.swRegistration.waiting.postMessage({ type: "SKIP_WAITING" });
          // Wait for control to be taken
          await new Promise((resolve) => {
            navigator.serviceWorker.addEventListener(
              "controllerchange",
              () => {
                console.log("🎯 Service worker controller changed");
                resolve(true);
              },
              { once: true },
            );
          });
        } else if (this.swRegistration.active) {
          console.log("✅ Service worker already active");
        }

        // Ensure we have an active service worker
        console.log("🔄 Waiting for service worker to be ready...");
        await navigator.serviceWorker.ready;
        console.log("🎯 Service worker ready and should be active");

        // Double check if it's actually active
        const finalRegistration = await navigator.serviceWorker.ready;
        if (!finalRegistration.active) {
          console.warn(
            "⚠️ Service worker ready but still not active, this should not happen",
          );
          // Try one more registration
          console.log("🔄 Attempting secondary registration...");
          this.swRegistration = await navigator.serviceWorker.register(
            "/sw-push.js",
            {
              scope: "/",
            },
          );
          await navigator.serviceWorker.ready;
        }
      } else {
        console.log("🏭 Production mode: Using PWA service worker");

        // Wait for any ongoing Service Worker cleanup/updates to complete
        console.log(
          "🔄 Waiting for Service Worker environment to stabilize...",
        );
        await new Promise((resolve) => setTimeout(resolve, 2000));

        // Get the stable Service Worker registration
        this.swRegistration = await navigator.serviceWorker.ready;
        console.log("📋 Got Service Worker registration after stabilization");
      }

      // Ensure Service Worker is actually active before proceeding
      if (this.swRegistration) {
        console.log("🔄 Waiting for Service Worker to become active...");
        let attempts = 0;
        const maxAttempts = 50; // 5 seconds max wait

        while (!this.swRegistration.active && attempts < maxAttempts) {
          await new Promise((resolve) => setTimeout(resolve, 100));
          attempts++;

          // Refresh registration state
          this.swRegistration = await navigator.serviceWorker.ready;
        }

        if (this.swRegistration.active) {
          console.log("✅ Service Worker is now active");
        } else {
          console.warn(
            "⚠️ Service Worker did not become active within timeout",
          );
        }
      }

      console.log("Service Worker registered successfully");

      // Request notification permission
      const permission = await this.requestPermission();
      if (permission !== "granted") {
        console.warn("Notification permission not granted");
        return false;
      }

      // Add stabilization delay to ensure Service Worker is fully settled
      console.log("⏳ Waiting for Service Worker to stabilize...");
      await new Promise((resolve) => setTimeout(resolve, 2000)); // Increased to 2 seconds

      // Push notifications subscription disabled

      return true;
    } catch (error) {
      console.error("Failed to initialize push notifications:", error);

      // Provide user feedback for initialization errors
      if (typeof window !== "undefined") {
        const { notifications } = await import("$lib/stores/notifications");
        notifications.add({
          type: "error",
          message:
            "❌ Failed to initialize push notifications. Please try refreshing the page.",
          duration: 6000,
        });
      }
      return false;
    }
  }

  /**
   * Request notification permission
   */
  async requestPermission(): Promise<NotificationPermission> {
    if (!browser || !("Notification" in window)) {
      return "denied";
    }

    let permission = Notification.permission;

    if (permission === "default") {
      permission = await Notification.requestPermission();
    }

    // Provide user feedback based on permission result
    if (typeof window !== "undefined") {
      // Dynamically import to avoid SSR issues
      const { notifications } = await import("$lib/stores/notifications");

      switch (permission) {
        case "granted":
          notifications.add({
            type: "success",
            message:
              "🔔 Push notifications enabled! You'll receive notifications when the app is closed.",
            duration: 4000,
          });
          break;
        case "denied":
          notifications.add({
            type: "warning",
            message:
              "🔕 Push notifications blocked. You can enable them in your browser settings under Site Settings > Notifications.",
            duration: 8000,
          });
          break;
        case "default":
          // User dismissed without choosing
          notifications.add({
            type: "info",
            message:
              "📱 You can enable push notifications later in your browser settings.",
            duration: 5000,
          });
          break;
      }
    }

    return permission;
  }

  /**
   * Subscribe to push notifications
   * 🔴 DISABLED: Push notifications causing rate limit warnings
   */
  // async subscribeToPush(): Promise<PushSubscription | null> {
  //   console.warn('⚠️ [PushNotifications] subscribeToPush disabled');
  //   return null;
  // }

  /**
   * Register device with backend
   * 🔴 DISABLED: Push notifications causing rate limit warnings
   */
  async registerDevice(): Promise<void> {
    console.warn('⚠️ [PushNotifications] registerDevice disabled');
    return;
  }

  /**
   * Unregister device (on logout)
   */
  async unregisterDevice(): Promise<void> {
    const deviceId = localStorage.getItem("aqura-device-id");
    if (!deviceId) return;

    try {
      // Use shared supabase admin client
      // Mark device as inactive
      const { error } = await supabase
        .from("push_subscriptions")
        .update({ is_active: false })
        .eq("device_id", deviceId);

      if (error) {
        throw error;
      }

      // Unsubscribe from push
      if (this.subscription) {
        await this.subscription.unsubscribe();
        this.subscription = null;
      }

      // Remove local storage
      localStorage.removeItem("aqura-device-id");

      console.log("Device unregistered from push notifications");
    } catch (error) {
      console.error("Failed to unregister device:", error);
    }
  }

  /**
   * Send a test notification specifically designed for locked phone testing
   */
  async sendTestNotificationForLockedPhone(): Promise<void> {
    if (!browser || Notification.permission !== "granted") {
      console.warn("Cannot send notification - permission not granted");
      return;
    }

    // Enhanced test notification specifically for locked phone scenarios
    const isMobile = this.getDeviceType() === "mobile";
    console.log(
      "📱 Sending locked phone test notification for:",
      isMobile ? "mobile" : "desktop",
    );

    // Use Service Worker registration for locked phone compatibility
    if (this.swRegistration) {
      const enhancedOptions = {
        body: `🔒 LOCKED PHONE TEST: This notification should appear even when your ${isMobile ? "phone is locked" : "computer is locked"}!`,
        icon: "/icons/icon-192x192.png",
        badge: "/icons/icon-96x96.png",
        tag: "locked-phone-test-notification",
        // Critical settings for locked phone notifications
        requireInteraction: true, // REQUIRED: Forces notification to persist until user interacts
        silent: false, // Ensure sound plays even when phone is locked
        renotify: true, // Allow renotifying with same tag
        persistent: true, // Keep notification visible until user dismisses
        // Enhanced vibration for locked devices
        vibrate: isMobile
          ? [300, 100, 300, 100, 300, 100, 300]
          : [200, 100, 200],
        timestamp: Date.now(),
        // Data to track locked phone delivery
        data: {
          testType: "locked-phone-test",
          isMobileDevice: isMobile,
          deviceType: this.getDeviceType(),
          testTimestamp: Date.now(),
          instructions:
            "Lock your device and check if this notification appears",
          priority: "high",
          wakeScreen: true,
        },
        // Enhanced actions for locked phone testing
        actions: [
          {
            action: "success",
            title: "✅ It Worked!",
            icon: "/icons/checkmark.png",
          },
          {
            action: "failed",
            title: "❌ Didn't Work",
            icon: "/icons/xmark.png",
          },
          {
            action: "open",
            title: "🚀 Open App",
            icon: "/icons/icon-96x96.png",
          },
        ],
      };

      try {
        await this.swRegistration.showNotification(
          "🔒 Locked Phone Test - Aqura Management",
          enhancedOptions,
        );

        console.log("✅ Locked phone test notification sent successfully");
        console.log(
          "📱 Instructions: Lock your device and check if the notification appears",
        );

        // Show success message to user
        console.log(
          "� Instructions: Lock your device and check if the notification appears",
        );
      } catch (error) {
        console.error("❌ Locked phone test notification failed:", error);
        throw error;
      }
    } else {
      console.warn(
        "Service Worker not available for locked phone notifications",
      );
      throw new Error("Service Worker not available");
    }
  }

  /**
   * Send a test notification
   */
  async sendTestNotification(): Promise<void> {
    if (!browser || Notification.permission !== "granted") {
      console.warn("Cannot send notification - permission not granted");
      return;
    }

    // Mobile-optimized test notification
    const isMobile = this.getDeviceType() === "mobile";
    console.log("📱 Sending test notification for mobile:", isMobile);

    // Use Service Worker registration for mobile compatibility
    if (this.swRegistration) {
      const options = {
        body: `Push notifications are working on ${isMobile ? "mobile" : "desktop"}!`,
        icon: "/icons/icon-192x192.png",
        badge: "/icons/icon-96x96.png",
        tag: "test-notification",
        requireInteraction: isMobile, // Force interaction on mobile
        silent: false,
        vibrate: isMobile ? [200, 100, 200, 100, 200] : [200, 100, 200],
        data: {
          isMobile: isMobile,
          testNotification: true,
          timestamp: Date.now(),
        },
        actions: isMobile
          ? [
              {
                action: "ok",
                title: "OK",
              },
            ]
          : [
              {
                action: "ok",
                title: "OK",
              },
              {
                action: "close",
                title: "Close",
              },
            ],
      };

      try {
        await this.swRegistration.showNotification(
          "🔔 Aqura Test Notification",
          options,
        );
        console.log("✅ Test notification sent successfully");

        // For mobile, also try sending a message to Service Worker
        if (isMobile && this.swRegistration.active) {
          console.log(
            "📱 Sending backup test notification message to Service Worker",
          );
          this.swRegistration.active.postMessage({
            type: "FORCE_SHOW_NOTIFICATION",
            title: "📱 Mobile Test Notification",
            options: {
              ...options,
              body: "Mobile notification test - this should show!",
              tag: "mobile-test-notification",
            },
            isMobile: true,
          });
        }
      } catch (error) {
        console.error("❌ Test notification failed:", error);
        throw error;
      }
    } else {
      console.warn("Service Worker not available for notifications");
      throw new Error("Service Worker not available");
    }
  }

  /**
   * Show notification when app is open
   */
  async showNotification(payload: NotificationPayload): Promise<void> {
    if (!browser || Notification.permission !== "granted") {
      return;
    }

    // Use Service Worker registration for mobile compatibility
    if (this.swRegistration) {
      await this.swRegistration.showNotification(payload.title, {
        body: payload.body,
        icon: payload.icon || "/favicon.png",
        badge: payload.badge || "/badge-icon.png",
        data: payload.data,
        tag: payload.data?.notification_id || "aqura-notification",
        requireInteraction: true,
      });
    } else {
      console.warn("Service Worker not available for notifications");
    }
  }

  /**
   * Update device last seen
   * 🔴 DISABLED: Causing 403 Forbidden errors - using default values instead
   */
  async updateLastSeen(): Promise<void> {
    console.warn("⚠️ [PushNotifications] updateLastSeen() temporarily disabled - preventing 403 errors");
    // This method is disabled to prevent 403 Forbidden errors
    return;
  }

  /**
   * Helper methods
   */
  private generateDeviceId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  // Generate a UUID v4 from a string (for consistent user_id mapping)
  private generateUUIDFromString(str: string): string {
    // Simple UUID v4 generation from string hash
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash; // Convert to 32-bit integer
    }

    // Create a proper 32-character hex string from the hash
    const hex = Math.abs(hash).toString(16).padStart(8, "0");
    // Repeat and extend to get 32 chars
    const fullHex = (hex + hex + hex + hex).substring(0, 32);

    // Format as proper UUID
    const uuid = `${fullHex.slice(0, 8)}-${fullHex.slice(8, 12)}-4${fullHex.slice(13, 16)}-a${fullHex.slice(17, 20)}-${fullHex.slice(20, 32)}`;
    return uuid;
  }

  private getDeviceType(): "mobile" | "desktop" {
    if (!browser) return "desktop";

    const userAgent = navigator.userAgent;
    const isMobile =
      /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        userAgent,
      );
    return isMobile ? "mobile" : "desktop";
  }

  private getBrowserName(): string {
    if (!browser) return "unknown";

    const userAgent = navigator.userAgent;

    if (userAgent.includes("Chrome")) return "Chrome";
    if (userAgent.includes("Firefox")) return "Firefox";
    if (userAgent.includes("Safari")) return "Safari";
    if (userAgent.includes("Edge")) return "Edge";

    return "Unknown";
  }

  private urlBase64ToUint8Array(base64String: string): Uint8Array {
    try {
      const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
      const base64 = (base64String + padding)
        .replace(/-/g, "+")
        .replace(/_/g, "/");

      const rawData = window.atob(base64);
      const outputArray = new Uint8Array(rawData.length);

      for (let i = 0; i < rawData.length; ++i) {
        outputArray[i] = rawData.charCodeAt(i);
      }
      return outputArray;
    } catch (error) {
      console.error("Failed to decode VAPID key:", error);
      throw new Error("Invalid VAPID public key format");
    }
  }
}

// Singleton instance
export const pushNotificationService = new PushNotificationService();

// Enhanced PWA and mobile debugging tools for the browser console
if (browser) {
  (window as any).aquraPushDebug = {
    async testNotification() {
      console.log("🧪 Testing notification with PWA detection...");

      const isMobile =
        /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
          navigator.userAgent,
        );
      const isPWA =
        window.matchMedia("(display-mode: standalone)").matches ||
        (navigator as any).standalone ||
        window.location.search.includes("utm_source=pwa") ||
        document.referrer.includes("android-app://");

      console.log("📱 Environment:", {
        isMobile,
        isPWA,
        displayMode: window.matchMedia("(display-mode: standalone)").matches
          ? "standalone"
          : "browser",
        userAgent: navigator.userAgent,
        standalone: (navigator as any).standalone,
        urlParams: window.location.search,
        referrer: document.referrer,
      });

      if ("serviceWorker" in navigator) {
        const registration = await navigator.serviceWorker.ready;

        const testOptions = {
          body: `Test notification from ${isPWA ? "PWA" : isMobile ? "mobile browser" : "desktop browser"}`,
          icon: "/icons/icon-192x192.png",
          badge: "/icons/icon-96x96.png",
          data: {
            test: true,
            isMobile,
            isPWA,
            displayMode: window.matchMedia("(display-mode: standalone)").matches
              ? "standalone"
              : "browser",
            timestamp: Date.now(),
          },
          tag: "test-notification",
          requireInteraction: isPWA || isMobile,
          vibrate:
            isPWA && isMobile
              ? [300, 100, 300, 100, 300]
              : isMobile
                ? [200, 100, 200, 100, 200]
                : [200, 100, 200],
          actions:
            isPWA && !isMobile
              ? [{ action: "test", title: "Test PWA Action" }]
              : isPWA || isMobile
                ? [{ action: "test", title: "Test" }]
                : [
                    { action: "test", title: "Test" },
                    { action: "close", title: "Close" },
                  ],
        };

        try {
          await registration.showNotification("🧪 Aqura PWA Test", testOptions);
          console.log(
            `✅ Test notification sent for ${isPWA ? "PWA" : isMobile ? "mobile" : "desktop"}`,
          );
        } catch (error) {
          console.error("❌ Test notification failed:", error);
        }
      }
    },

    checkPWAStatus() {
      const isPWA =
        window.matchMedia("(display-mode: standalone)").matches ||
        (navigator as any).standalone ||
        window.location.search.includes("utm_source=pwa") ||
        document.referrer.includes("android-app://");

      const info = {
        isPWA,
        displayMode: window.matchMedia("(display-mode: standalone)").matches
          ? "standalone"
          : "browser",
        standalone: (navigator as any).standalone,
        hasStandaloneQuery: window.location.search.includes("utm_source=pwa"),
        androidApp: document.referrer.includes("android-app://"),
        userAgent: navigator.userAgent,
        viewport: {
          width: window.innerWidth,
          height: window.innerHeight,
        },
        screen: {
          width: screen.width,
          height: screen.height,
          availWidth: screen.availWidth,
          availHeight: screen.availHeight,
        },
        orientation: (screen as any).orientation?.type || "unknown",
      };

      console.log("📱 PWA Status Check:", info);
      return info;
    },

    async testPWAInstallability() {
      console.log("🧪 Testing PWA installability...");

      // Check if app is already installed
      const isInstalled = window.matchMedia(
        "(display-mode: standalone)",
      ).matches;
      console.log("📱 Is app installed as PWA:", isInstalled);

      // Check for beforeinstallprompt event
      let installPromptAvailable = false;

      const beforeInstallPromptHandler = (e: Event) => {
        console.log("📱 PWA install prompt available");
        installPromptAvailable = true;
        e.preventDefault();
      };

      window.addEventListener(
        "beforeinstallprompt",
        beforeInstallPromptHandler,
      );

      setTimeout(() => {
        window.removeEventListener(
          "beforeinstallprompt",
          beforeInstallPromptHandler,
        );
        console.log("📱 PWA Installability Check Results:", {
          isInstalled,
          installPromptAvailable,
          canInstall: !isInstalled && installPromptAvailable,
        });
      }, 1000);
    },

    async testLockedPhoneNotification() {
      console.log("🔒 Testing locked phone notification...");
      try {
        await pushNotificationService.sendTestNotificationForLockedPhone();
      } catch (error) {
        console.error("❌ Locked phone test failed:", error);
      }
    },

    async testRegularNotification() {
      console.log("📱 Testing regular notification...");
      try {
        await pushNotificationService.sendTestNotification();
      } catch (error) {
        console.error("❌ Regular test failed:", error);
      }
    },
  };

  console.log("🧪 PWA Debug tools available:");
  console.log(
    "  - aquraPushDebug.testNotification() - Test notifications with PWA detection",
  );
  console.log(
    "  - aquraPushDebug.checkPWAStatus() - Check current PWA installation status",
  );
  console.log(
    "  - aquraPushDebug.testPWAInstallability() - Test PWA installation readiness",
  );
  console.log(
    "  - aquraPushDebug.testLockedPhoneNotification() - Test notifications for locked phones",
  );
  console.log(
    "  - aquraPushDebug.testRegularNotification() - Test regular notifications",
  );
}
