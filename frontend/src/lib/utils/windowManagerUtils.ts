import { windowManager } from "$lib/stores/windowManager";
import type { WindowConfig } from "$lib/stores/windowManager";

/**
 * Check if we're running inside a popout iframe
 */
function isInPopoutContext(): boolean {
  return (
    typeof window !== "undefined" &&
    window.parent !== window &&
    (window.location.search.includes("popout=") ||
      window.location.search.includes("windowData=") ||
      window.location.search.includes("component=") ||
      window.location.hash.includes("#popout="))
  );
}

/**
 * Utility to get the appropriate window manager based on context
 * Returns proxy for popout windows or real manager for main app
 */
export function getWindowManager() {
  if (isInPopoutContext() && typeof window !== "undefined" && window.windowManagerProxy) {
    console.log("🪟 Using window manager proxy for popout");
    return window.windowManagerProxy;
  }

  console.log("🪟 Using main window manager");
  return windowManager;
}

/**
 * Safe window opener that works in both main app and popout contexts.
 * When in a popout iframe, sends a message to the main app via BroadcastChannel
 * to open the window there, since Svelte components can't be serialized across windows.
 */
export function openWindow(
  config: Partial<WindowConfig> & { title: string; component: any },
) {
  // If we're in a popout iframe, send the request to the main app
  if (isInPopoutContext()) {
    const componentName = (config as any).componentName || config.component?.name || "";
    console.log("🪟 Popout context detected - sending open-window request:", componentName);

    // Strip non-serializable component reference
    const { component, ...serializableConfig } = config;
    const message = {
      type: "open-window-from-popout",
      windowConfig: serializableConfig,
      componentName: componentName,
      timestamp: Date.now(),
    };

    // Method 1: postMessage to parent (popup window) which relays to opener (main app)
    // This works now that the popup's script is properly initialized via createElement
    try {
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(message, "*");
        console.log("🪟 postMessage sent to parent popup window for relay");
        return "popout-" + Date.now();
      }
    } catch (e) {
      console.error("🪟 postMessage to parent failed:", e);
    }

    // Method 2: localStorage event (reliable cross-tab communication)
    // The 'storage' event fires in ALL other same-origin tabs/windows
    try {
      const key = "aqura-open-window-" + Date.now();
      localStorage.setItem(key, JSON.stringify(message));
      // Clean up after a short delay
      setTimeout(() => {
        try { localStorage.removeItem(key); } catch (e) {}
      }, 2000);
      console.log("🪟 localStorage message sent successfully");
      return "popout-" + Date.now();
    } catch (e) {
      console.error("🪟 localStorage approach failed:", e);
    }

    // Method 3: BroadcastChannel fallback
    try {
      const bc = new BroadcastChannel("aqura-window-manager");
      bc.postMessage(message);
      bc.close();
      console.log("🪟 BroadcastChannel message sent as fallback");
      return "popout-" + Date.now();
    } catch (e) {
      console.error("🪟 BroadcastChannel also failed:", e);
    }

    // Method 3: proxy fallback
    if (window.windowManagerProxy) {
      return window.windowManagerProxy.openWindow(config);
    }

    console.error("🪟 No communication channel available to open window from popout");
    return "";
  }

  // Normal context - use main window manager directly
  return windowManager.openWindow(config);
}

// Type declaration for the global windowManagerProxy
declare global {
  interface Window {
    windowManagerProxy?: {
      openWindow: (
        config: Partial<WindowConfig> & { title: string; component: any },
      ) => string;
    };
  }
}
