import { writable, derived, get } from "svelte/store";
import type { Writable, Readable } from "svelte/store";

export interface WindowConfig {
  id: string;
  title: string;
  component: any; // Svelte component
  props?: Record<string, any>;
  icon?: string;
  position: { x: number; y: number };
  size: { width: number; height: number };
  minSize?: { width: number; height: number };
  maxSize?: { width: number; height: number };
  resizable?: boolean;
  minimizable?: boolean;
  maximizable?: boolean;
  closable?: boolean;
  refreshable?: boolean; // New property for refresh button
  modal?: boolean;
  zIndex: number;
  state: "normal" | "minimized" | "maximized";
  isActive: boolean;
  isDragging: boolean;
  isResizing: boolean;
  popOutEnabled?: boolean; // New property for pop-out functionality
  isPoppedOut?: boolean; // Track if window is currently popped out
  popOutWindow?: Window; // Reference to the popped out window
}

export interface TaskbarItem {
  windowId: string;
  title: string;
  icon?: string;
  isActive: boolean;
  isMinimized: boolean;
}

// Window Manager Store
class WindowManager {
  private windows: Writable<Map<string, WindowConfig>> = writable(new Map());
  private activeWindowId: Writable<string | null> = writable(null);
  private nextZIndex = 1001;
  private windowCounter = 0;

  constructor() {
    // Set up message listener for pop-in requests from pop-out windows
    if (typeof window !== "undefined") {
      window.addEventListener("message", (event) => {
        if (event.data && event.data.type === "pop-in-window") {
          this.popInWindow(event.data.windowId);
        }
      });
    }
  }

  // Derived stores
  public readonly windowList: Readable<WindowConfig[]> = derived(
    this.windows,
    ($windows) =>
      Array.from($windows.values()).sort((a, b) => a.zIndex - b.zIndex),
  );

  public readonly taskbarItems: Readable<TaskbarItem[]> = derived(
    this.windows,
    ($windows) =>
      Array.from($windows.values())
        .map((w) => ({
          windowId: w.id,
          title: w.title,
          icon: w.icon,
          isActive: w.isActive,
          isMinimized: w.state === "minimized",
        }))
        .sort((a, b) => (a.title || "").localeCompare(b.title || "")),
  );

  public readonly activeWindow: Readable<WindowConfig | null> = derived(
    [this.windows, this.activeWindowId],
    ([$windows, $activeId]) =>
      $activeId ? $windows.get($activeId) || null : null,
  );

  /**
   * Open a new window
   */
  public openWindow(
    config: Partial<WindowConfig> & { title: string; component: any },
  ): string {
    const windowId = config.id || `window-${++this.windowCounter}`;

    // Check if window already exists
    const existingWindows = get(this.windows);
    if (existingWindows.has(windowId)) {
      this.activateWindow(windowId);
      return windowId;
    }

    const defaultPosition = this.calculateDefaultPosition();
    const newWindow: WindowConfig = {
      id: windowId,
      title: config.title,
      component: config.component,
      props: config.props || {},
      icon: config.icon,
      position: config.position || defaultPosition,
      size: config.size || { width: 800, height: 600 },
      minSize: config.minSize || { width: 400, height: 300 },
      maxSize: config.maxSize,
      resizable: config.resizable !== false,
      minimizable: config.minimizable !== false,
      maximizable: config.maximizable !== false,
      closable: config.closable !== false,
      modal: config.modal || false,
      zIndex: this.nextZIndex++,
      state: "normal",
      isActive: true,
      isDragging: false,
      isResizing: false,
      popOutEnabled: config.popOutEnabled !== false, // Enable pop-out by default
      isPoppedOut: false,
      popOutWindow: undefined,
    };

    this.windows.update((windows) => {
      // Deactivate all other windows
      windows.forEach((w) => (w.isActive = false));
      windows.set(windowId, newWindow);
      return windows;
    });

    this.activeWindowId.set(windowId);
    return windowId;
  }

  /**
   * Close a window
   */
  public closeWindow(windowId: string): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (!window) return windows;

      windows.delete(windowId);

      // If this was the active window, activate another one
      if (window.isActive && windows.size > 0) {
        const nextWindow = Array.from(windows.values())
          .filter((w) => w.state !== "minimized")
          .sort((a, b) => b.zIndex - a.zIndex)[0];

        if (nextWindow) {
          nextWindow.isActive = true;
          this.activeWindowId.set(nextWindow.id);
        } else {
          this.activeWindowId.set(null);
        }
      } else if (window.isActive) {
        this.activeWindowId.set(null);
      }

      return windows;
    });
  }

  /**
   * Activate a window (bring to front)
   */
  public activateWindow(windowId: string): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (!window) return windows;

      // Create a new Map to trigger reactivity
      const newWindows = new Map(windows);

      // Deactivate all windows
      newWindows.forEach((w) => {
        if (w.isActive) {
          newWindows.set(w.id, { ...w, isActive: false });
        }
      });

      // Activate and bring to front
      const updatedWindow = { 
        ...window, 
        isActive: true,
        zIndex: this.nextZIndex++
        // Don't auto-restore minimized windows - keep them minimized
        // User must click restore button or double-click title to restore
      };
      newWindows.set(windowId, updatedWindow);

      this.activeWindowId.set(windowId);
      return newWindows;
    });
  }

  /**
   * Minimize a window
   */
  public minimizeWindow(windowId: string): void {
    console.log('🔽 minimizeWindow called for:', windowId);
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (!window) return windows;

      // Create a new Map to trigger reactivity
      const newWindows = new Map(windows);

      // Create updated window object with minimized state
      const updatedWindow = { ...window, state: "minimized" as const, isActive: false };
      newWindows.set(windowId, updatedWindow);
      console.log('🔽 Window minimized:', { windowId, newState: updatedWindow.state });
      if (get(this.activeWindowId) === windowId) {
        const nextWindow = Array.from(newWindows.values())
          .filter((w) => w.id !== windowId && w.state !== "minimized")
          .sort((a, b) => b.zIndex - a.zIndex)[0];

        if (nextWindow) {
          const activatedWindow = { ...nextWindow, isActive: true };
          newWindows.set(nextWindow.id, activatedWindow);
          this.activeWindowId.set(nextWindow.id);
        } else {
          this.activeWindowId.set(null);
        }
      }

      return newWindows;
    });
  }

  /**
   * Maximize/restore a window
   */
  public toggleMaximizeWindow(windowId: string): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (!window) return windows;

      // Create a new Map to trigger reactivity
      const newWindows = new Map(windows);

      const isCurrentlyMaximized = window.state === "maximized";
      const newState = isCurrentlyMaximized ? "normal" : "maximized";

      if (!isCurrentlyMaximized) {
        // When maximizing, deactivate all windows first
        newWindows.forEach((w) => {
          if (w.isActive) {
            newWindows.set(w.id, { ...w, isActive: false });
          }
        });
      }

      // Update the target window
      const updatedWindow = {
        ...window,
        state: newState as "normal" | "maximized",
        zIndex: !isCurrentlyMaximized ? this.nextZIndex++ : window.zIndex,
        isActive: !isCurrentlyMaximized ? true : window.isActive
      };
      newWindows.set(windowId, updatedWindow);

      return newWindows;
    });
  }

  /**
   * Update window position
   */
  public updateWindowPosition(
    windowId: string,
    position: { x: number; y: number },
  ): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (!window) return windows;
      
      // Create a completely new Map to ensure reactivity
      const newWindows = new Map(windows);
      const updatedWindow = { ...window, position };
      newWindows.set(windowId, updatedWindow);
      return newWindows;
    });
  }

  /**
   * Update window size
   */
  public updateWindowSize(
    windowId: string,
    size: { width: number; height: number },
  ): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (!window) return windows;
      
      // Create a completely new Map to ensure reactivity
      const newWindows = new Map(windows);
      const updatedWindow = { ...window, size };
      newWindows.set(windowId, updatedWindow);
      return newWindows;
    });
  }

  /**
   * Update window title
   */
  public updateWindowTitle(windowId: string, title: string): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (window) {
        // Create a new window object with updated title to trigger Svelte reactivity
        const updatedWindow = { ...window, title };
        const newWindows = new Map(windows);
        newWindows.set(windowId, updatedWindow);
        return newWindows;
      }
      return windows;
    });
  }

  /**
   * Set window dragging state
   */
  public setWindowDragging(windowId: string, isDragging: boolean): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (window) {
        window.isDragging = isDragging;
      }
      return windows;
    });
  }

  /**
   * Set window resizing state
   */
  public setWindowResizing(windowId: string, isResizing: boolean): void {
    this.windows.update((windows) => {
      const window = windows.get(windowId);
      if (window) {
        window.isResizing = isResizing;
      }
      return windows;
    });
  }

  /**
   * Close all windows
   */
  public closeAllWindows(): void {
    this.windows.set(new Map());
    this.activeWindowId.set(null);
  }

  /**
   * Pop out a window to a new browser window
   */
  public popOutWindow(windowId: string): void {
    const windows = get(this.windows);
    const windowConfig = windows.get(windowId);
    if (!windowConfig || windowConfig.isPoppedOut) return;

    // Check if we're in a PWA environment
    const isPWA =
      window.matchMedia &&
      window.matchMedia("(display-mode: standalone)").matches;
    const isIOSPWA = (window.navigator as any).standalone === true;
    const isWebView = navigator.userAgent.includes("wv");

    console.log("🪟 Environment check:", { isPWA, isIOSPWA, isWebView });

    // If in PWA mode, use alternative fullscreen approach
    if (isPWA || isIOSPWA || isWebView) {
      console.log(
        "🪟 PWA environment detected, using alternative fullscreen approach",
      );
      this.showWindowFullscreen(windowId);
      return;
    }

    console.log("🪟 Regular browser detected, using pop-out window");

    // Create a new browser window
    const popOutFeatures = [
      `width=${windowConfig.size.width}`,
      `height=${windowConfig.size.height}`,
      `left=${windowConfig.position.x}`,
      `top=${windowConfig.position.y}`,
      "menubar=no",
      "toolbar=no",
      "location=no",
      "status=no",
      "scrollbars=yes",
      "resizable=yes",
    ].join(",");

    const popOutWindow = globalThis.window.open(
      "",
      `popout_${windowId}`,
      popOutFeatures,
    );

    if (!popOutWindow) {
      console.error(
        "🪟 Failed to open pop-out window. Pop-ups may be blocked, trying PWA fullscreen mode instead.",
      );
      this.showWindowFullscreen(windowId);
      return;
    }

    // Get current app URL
    const currentUrl = globalThis.window.location.href;
    const baseUrl = currentUrl.split("#")[0].split("?")[0]; // Remove any hash and query params

    // Serialize the window data to pass to iframe
    // Try to get the real component name, not the wrapper
    let componentName = windowConfig.component?.name;

    // If it's a wrapper, try to get the actual component name from the title or other means
    if (
      componentName === "wrapper" ||
      !componentName ||
      componentName === "UnknownComponent"
    ) {
      // Infer component name from window title (order matters - check more specific first)
      if (windowConfig.title.includes("Upload Vendor")) {
        componentName = "UploadVendor";
      } else if (windowConfig.title.includes("Manage Vendor")) {
        componentName = "ManageVendor";
      } else if (windowConfig.title.includes("Vendor Master")) {
        componentName = "VendorMaster";
      } else if (
        windowConfig.title.includes("Branches Master") ||
        windowConfig.title.includes("Branch Master")
      ) {
        componentName = "BranchMaster";
      } else if (windowConfig.title.includes("Start Receiving")) {
        componentName = "StartReceiving";
      } else if (windowConfig.title.includes("Receiving Records")) {
        componentName = "ReceivingRecords";
      } else if (windowConfig.title.includes("Receiving Tasks")) {
        componentName = "ReceivingTasksDashboard";
      } else if (windowConfig.title.includes("Receiving Data")) {
        componentName = "ReceivingDataWindow";
      } else if (windowConfig.title.match(/^Receiving #\d+$/)) {
        componentName = "Receiving";
      } else if (windowConfig.title.includes("Scheduled Payments")) {
        componentName = "ScheduledPayments";
      } else if (windowConfig.title.includes("Payment Manager")) {
        componentName = "PaymentManager";
      } else if (windowConfig.title.includes("Payment Details")) {
        componentName = "MonthDetails";
      } else if (windowConfig.title.includes("Overdue Payments Details")) {
        componentName = "UnpaidScheduledDetails";
      } else if (windowConfig.title.includes("Task Master")) {
        componentName = "TaskMaster";
      } else if (windowConfig.title.includes("HR Master")) {
        componentName = "HRMaster";
      } else if (windowConfig.title.includes("Operations Master")) {
        componentName = "OperationsMaster";
      } else if (windowConfig.title.includes("Finance Master")) {
        componentName = "FinanceMaster";
      } else if (windowConfig.title.includes("User Management")) {
        componentName = "UserManagement";
      } else if (windowConfig.title.includes("Communication Center")) {
        componentName = "CommunicationCenter";
      } else if (windowConfig.title.includes("Settings")) {
        componentName = "Settings";
      } else if (windowConfig.title.includes("Edit User")) {
        componentName = "EditUser";
      } else if (windowConfig.title.includes("Notification Center")) {
        componentName = "NotificationCenter";
      } else {
        console.warn("🪟 Unknown window title pattern:", windowConfig.title);
        componentName = "UnknownComponent";
      }
    }

    console.log("🪟 Creating popup with component:", componentName);
    console.log("🪟 Original component name:", windowConfig.component?.name);
    console.log("🪟 Window title:", windowConfig.title);

    // Check if props are too large for URL
    const propsSize = JSON.stringify(windowConfig.props || {}).length;
    const usePostMessage = propsSize > 1000; // If props are large, use postMessage

    let iframeUrl;
    if (usePostMessage) {
      // Use postMessage for large data
      iframeUrl = `${baseUrl}?popout=${windowId}`;
      console.log(
        "🪟 Using postMessage approach due to large props:",
        propsSize,
        "characters",
      );
    } else {
      // Use URL parameter for small data
      const windowData = encodeURIComponent(
        JSON.stringify({
          id: windowConfig.id,
          title: windowConfig.title,
          componentName: componentName,
          props: windowConfig.props || {},
          icon: windowConfig.icon,
          size: windowConfig.size,
        }),
      );

      iframeUrl = `${baseUrl}?popout=${windowId}&windowData=${windowData}`;
      console.log("🪟 Using URL parameter approach for small props");
    }

    // Properly escape JSON for template insertion
    const escapedProps = JSON.stringify(windowConfig.props || {})
      .replace(/\\/g, "\\\\")
      .replace(/'/g, "\\'");
    const escapedSize = JSON.stringify(windowConfig.size)
      .replace(/\\/g, "\\\\")
      .replace(/'/g, "\\'");
    const escapedTitle = (windowConfig.title || "").replace(/'/g, "\\'");
    const escapedIcon = (windowConfig.icon || "").replace(/'/g, "\\'");
    const escapedComponentName = componentName.replace(/'/g, "\\'");
    const escapedWindowId = windowId.replace(/'/g, "\\'");

    // Set up the pop-out window with iframe containing the app
    popOutWindow.document.title = windowConfig.title;
    popOutWindow.document.head.innerHTML = `
			<meta charset="utf-8">
			<meta name="viewport" content="width=device-width, initial-scale=1">
			<title>${escapedTitle}</title>
			<style>
				body {
					margin: 0;
					padding: 0;
					font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
					background: #f5f5f5;
					height: 100vh;
					overflow: hidden;
				}
				.popout-header {
					background: linear-gradient(135deg, #4F46E5 0%, #6366F1 100%);
					color: white;
					padding: 8px 16px;
					display: flex;
					align-items: center;
					justify-content: space-between;
					font-weight: 500;
					font-size: 14px;
					border-bottom: 1px solid #4338CA;
					flex-shrink: 0;
					height: 40px;
					box-sizing: border-box;
					position: relative;
					z-index: 1000;
				}
				.popout-header.minimal {
					padding: 4px 16px;
					height: 32px;
					font-size: 12px;
				}
				.popout-title {
					display: flex;
					align-items: center;
					gap: 8px;
				}
				.popout-controls {
					display: flex;
					gap: 8px;
				}
				.popout-btn {
					background: rgba(255, 255, 255, 0.2);
					color: white;
					border: none;
					padding: 4px 8px;
					border-radius: 4px;
					cursor: pointer;
					font-size: 12px;
					font-weight: 500;
					transition: background 0.15s ease;
				}
				.popout-btn:hover {
					background: rgba(255, 255, 255, 0.3);
				}
				.popout-iframe {
					width: 100%;
					height: calc(100vh - 32px);
					border: none;
					background: white;
				}
				.loading-message {
					position: absolute;
					top: 50%;
					left: 50%;
					transform: translate(-50%, -50%);
					text-align: center;
					color: #6B7280;
					z-index: 10;
					background: rgba(255, 255, 255, 0.9);
					padding: 20px;
					border-radius: 8px;
					box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
					display: none; /* Hide by default */
				}
			</style>
		`;

    // Create the pop-out window content with iframe
    popOutWindow.document.body.innerHTML = `
			<div class="popout-header" id="popout-header">
				<div class="popout-title">
					<span>${escapedIcon || "📱"}</span>
					<span>${escapedTitle}</span>
				</div>
				<div class="popout-controls">
					<button class="popout-btn" onclick="returnToApp()">↩️ Return to App</button>
					<button class="popout-btn" onclick="window.close()">✕ Close</button>
				</div>
			</div>
			<div class="loading-message" id="loading">
				<p>Loading window content...</p>
				<small>Loading: ${escapedTitle}</small>
			</div>
			<iframe 
				class="popout-iframe" 
				src="${iframeUrl}"
				title="${escapedTitle}"
				onload="
					console.log('🪟 Iframe loaded, hiding loading message');
					var loadingEl = document.getElementById('loading');
					if (loadingEl) {
						loadingEl.style.display = 'none';
						console.log('🪟 Loading message hidden');
					}
					
					// If using postMessage approach, send window data
					if ('${usePostMessage}' === 'true') {
						console.log('🪟 Sending window data via postMessage');
						var iframe = document.querySelector('.popout-iframe');
						if (iframe && iframe.contentWindow) {
							iframe.contentWindow.postMessage({
								type: 'popout-window-data',
								windowData: {
									id: '${escapedWindowId}',
									title: '${escapedTitle}',
									componentName: '${escapedComponentName}',
									props: ${escapedProps},
									icon: '${escapedIcon}',
									size: ${escapedSize}
								}
							}, '*');
						}
					}
				"
				onerror="
					console.error('🪟 Iframe load error');
					var loadingEl = document.getElementById('loading');
					if (loadingEl) {
						loadingEl.innerHTML = '<p>Error loading content</p>';
					}
				"
			></iframe>
			<script>
				// IMMEDIATE: Hide loading dialog right away
				document.addEventListener('DOMContentLoaded', function() {
					var loadingEl = document.getElementById('loading');
					if (loadingEl) {
						loadingEl.style.display = 'none';
						console.log('🪟 Loading dialog hidden on DOMContentLoaded');
					}
				});
				
				// IMMEDIATE: Hide loading dialog without waiting
				var loadingEl = document.getElementById('loading');
				if (loadingEl) {
					loadingEl.style.display = 'none';
					console.log('🪟 Loading dialog hidden immediately on script execution');
				}
				
				// Backup: Hide loading after a timeout
				setTimeout(function() {
					var loadingEl = document.getElementById('loading');
					if (loadingEl && loadingEl.style.display !== 'none') {
						console.log('🪟 Hiding loading message via timeout backup');
						loadingEl.style.display = 'none';
					}
				}, 3000);
				
				// Immediate check after a short delay
				setTimeout(function() {
					var loadingEl = document.getElementById('loading');
					if (loadingEl) {
						loadingEl.style.display = 'none';
						console.log('🪟 Loading message hidden immediately');
					}
				}, 500);
				
				// More aggressive backup - check multiple times
				var attempts = 0;
				var checkInterval = setInterval(function() {
					attempts++;
					var loadingEl = document.getElementById('loading');
					if (loadingEl && loadingEl.style.display !== 'none') {
						loadingEl.style.display = 'none';
						console.log('🪟 Loading dialog hidden by interval check #' + attempts);
					}
					if (attempts >= 10) { // Stop after 10 attempts (5 seconds)
						clearInterval(checkInterval);
					}
				}, 500);
				
				// Listen for completion message from iframe
				window.addEventListener('message', function(event) {
					console.log('🪟 Received message:', event.data);
					if (event.data && event.data.type === 'popout-loading-complete') {
						console.log('🪟 Received loading complete signal from iframe');
						var loadingEl = document.getElementById('loading');
						if (loadingEl) {
							loadingEl.style.display = 'none';
							console.log('🪟 Loading dialog hidden via iframe signal');
						} else {
							console.log('🪟 Loading element not found');
						}
					}
				});
				
				function returnToApp() {
					// Notify parent window to pop this window back in
					if (window.opener && !window.opener.closed) {
						window.opener.postMessage({
							type: 'pop-in-window',
							windowId: '${escapedWindowId}'
						}, '*');
						window.close();
					}
				}
			</script>
		`;

    // Update window state
    this.windows.update((windows) => {
      const windowConfig = windows.get(windowId);
      if (windowConfig) {
        windowConfig.isPoppedOut = true;
        windowConfig.popOutWindow = popOutWindow;
        windowConfig.state = "minimized"; // Hide in main app
      }
      return windows;
    });

    // Handle pop-out window close
    popOutWindow.addEventListener("beforeunload", () => {
      this.popInWindow(windowId);
    });

    // Focus the pop-out window
    popOutWindow.focus();
  }

  /**
   * Pop in a window back to the main application
   */
  public popInWindow(windowId: string): void {
    this.windows.update((windows) => {
      const windowConfig = windows.get(windowId);
      if (windowConfig && windowConfig.isPoppedOut) {
        // Close the pop-out window if it exists
        if (windowConfig.popOutWindow && !windowConfig.popOutWindow.closed) {
          windowConfig.popOutWindow.close();
        }

        // Reset window state
        windowConfig.isPoppedOut = false;
        windowConfig.popOutWindow = undefined;
        windowConfig.state = "normal";

        // Activate the window
        windows.forEach((w) => (w.isActive = false));
        windowConfig.isActive = true;
        windowConfig.zIndex = this.nextZIndex++;
        this.activeWindowId.set(windowId);
      }
      return windows;
    });
  }

  /**
   * Refresh a window by triggering component remount
   */
  public refreshWindow(windowId: string): void {
    this.windows.update((windows) => {
      const windowConfig = windows.get(windowId);
      if (windowConfig) {
        // Force component re-render by creating new props object
        windowConfig.props = { ...windowConfig.props };
      }
      return windows;
    });
  }

  /**
   * Minimize all windows
   */
  public minimizeAllWindows(): void {
    this.windows.update((windows) => {
      windows.forEach((window) => {
        window.state = "minimized";
        window.isActive = false;
      });
      this.activeWindowId.set(null);
      return windows;
    });
  }

  /**
   * Calculate default position for new windows (cascade)
   */
  private calculateDefaultPosition(): { x: number; y: number } {
    const windows = get(this.windows);
    const offset = windows.size * 30;

    return {
      x: 100 + (offset % 300),
      y: 100 + (offset % 200),
    };
  }

  /**
   * Get window by ID
   */
  public getWindow(windowId: string): WindowConfig | null {
    return get(this.windows).get(windowId) || null;
  }

  /**
   * Check if any modal windows are open
   */
  public hasModalWindows(): boolean {
    return Array.from(get(this.windows).values()).some(
      (w) => w.modal && w.state !== "minimized",
    );
  }

  /**
   * PWA-specific fullscreen mode for windows when pop-out is not available
   */
  private showWindowFullscreen(windowId: string): void {
    const windowConfig = get(this.windows).get(windowId);
    if (!windowConfig) {
      console.error("🪟 Window not found for fullscreen:", windowId);
      return;
    }

    console.log("🪟 Showing window in fullscreen mode (PWA alternative)");

    // Maximize the window and bring it to front
    this.windows.update((windows) => {
      const config = windows.get(windowId);
      if (config) {
        config.state = "maximized";
        config.isActive = true;
        config.position = { x: 0, y: 0 };
        config.size = {
          width: window.innerWidth,
          height: window.innerHeight - 60, // Account for taskbar
        };
        // Mark as "popped out" in PWA mode
        config.isPoppedOut = true;

        // Hide other windows temporarily
        windows.forEach((win, id) => {
          if (id !== windowId) {
            win.state = "minimized";
            win.isActive = false;
          }
        });
      }
      return windows;
    });

    // Add a PWA-specific header with "back" button
    this.addPWAControls(windowId);
  }

  /**
   * Add floating controls for PWA fullscreen mode
   */
  private addPWAControls(windowId: string): void {
    // Add a floating control panel for PWA mode
    const existingControls = document.querySelector(".pwa-window-controls");
    if (existingControls) {
      existingControls.remove();
    }

    const windowConfig = get(this.windows).get(windowId);
    const controls = document.createElement("div");
    controls.className = "pwa-window-controls";
    controls.innerHTML = `
			<div class="pwa-controls-content">
				<button class="pwa-back-btn" onclick="window.aquraPWA.exitFullscreen('${windowId}')">
					← Back to Desktop
				</button>
				<span class="pwa-window-title">${windowConfig?.title || "Window"}</span>
			</div>
		`;

    // Add styles if not already present
    if (!document.querySelector("#pwa-controls-style")) {
      const style = document.createElement("style");
      style.id = "pwa-controls-style";
      style.textContent = `
				.pwa-window-controls {
					position: fixed;
					top: 10px;
					right: 10px;
					z-index: 9999;
					background: rgba(79, 70, 229, 0.95);
					backdrop-filter: blur(10px);
					border-radius: 8px;
					padding: 8px 16px;
					box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
				}
				.pwa-controls-content {
					display: flex;
					align-items: center;
					gap: 12px;
					color: white;
					font-size: 14px;
				}
				.pwa-back-btn {
					background: rgba(255, 255, 255, 0.2);
					color: white;
					border: none;
					padding: 6px 12px;
					border-radius: 6px;
					cursor: pointer;
					font-size: 12px;
					font-weight: 500;
					transition: background 0.15s ease;
				}
				.pwa-back-btn:hover {
					background: rgba(255, 255, 255, 0.3);
				}
				.pwa-window-title {
					font-weight: 500;
					opacity: 0.9;
				}
			`;
      document.head.appendChild(style);
    }

    document.body.appendChild(controls);

    // Setup global PWA functions
    (window as any).aquraPWA = {
      exitFullscreen: (windowId: string) => {
        this.exitPWAFullscreen(windowId);
      },
    };
  }

  /**
   * Exit PWA fullscreen mode and return to normal desktop view
   */
  private exitPWAFullscreen(windowId: string): void {
    console.log("🪟 Exiting PWA fullscreen mode");

    // Remove PWA controls
    const controls = document.querySelector(".pwa-window-controls");
    if (controls) {
      controls.remove();
    }

    // Restore normal window state
    this.windows.update((windows) => {
      const config = windows.get(windowId);
      if (config) {
        config.state = "normal";
        config.size = { width: 1200, height: 800 };
        config.position = { x: 100, y: 100 };
        config.isPoppedOut = false;
      }

      // Restore other windows
      windows.forEach((win) => {
        if (win.state === "minimized") {
          win.state = "normal";
        }
      });

      return windows;
    });

    this.activateWindow(windowId);
  }

  // Store getters for reactive subscriptions
  public get windows$() {
    return this.windows;
  }
  public get activeWindowId$() {
    return this.activeWindowId;
  }
}

// Export singleton instance
export const windowManager = new WindowManager();
