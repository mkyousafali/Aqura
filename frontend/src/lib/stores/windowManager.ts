import { writable, derived, get } from 'svelte/store';
import type { Writable, Readable } from 'svelte/store';

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
	state: 'normal' | 'minimized' | 'maximized';
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
		if (typeof window !== 'undefined') {
			window.addEventListener('message', (event) => {
				if (event.data && event.data.type === 'pop-in-window') {
					this.popInWindow(event.data.windowId);
				}
			});
		}
	}

	// Derived stores
	public readonly windowList: Readable<WindowConfig[]> = derived(
		this.windows,
		($windows) => Array.from($windows.values()).sort((a, b) => a.zIndex - b.zIndex)
	);

	public readonly taskbarItems: Readable<TaskbarItem[]> = derived(
		this.windows,
		($windows) => Array.from($windows.values())
			.map(w => ({
				windowId: w.id,
				title: w.title,
				icon: w.icon,
				isActive: w.isActive,
				isMinimized: w.state === 'minimized'
			}))
			.sort((a, b) => (a.title || '').localeCompare(b.title || ''))
	);

	public readonly activeWindow: Readable<WindowConfig | null> = derived(
		[this.windows, this.activeWindowId],
		([$windows, $activeId]) => $activeId ? $windows.get($activeId) || null : null
	);

	/**
	 * Open a new window
	 */
	public openWindow(config: Partial<WindowConfig> & { title: string; component: any }): string {
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
			state: 'normal',
			isActive: true,
			isDragging: false,
			isResizing: false,
			popOutEnabled: config.popOutEnabled !== false, // Enable pop-out by default
			isPoppedOut: false,
			popOutWindow: undefined
		};

		this.windows.update(windows => {
			// Deactivate all other windows
			windows.forEach(w => w.isActive = false);
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
		this.windows.update(windows => {
			const window = windows.get(windowId);
			if (!window) return windows;

			windows.delete(windowId);

			// If this was the active window, activate another one
			if (window.isActive && windows.size > 0) {
				const nextWindow = Array.from(windows.values())
					.filter(w => w.state !== 'minimized')
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
		this.windows.update(windows => {
			const window = windows.get(windowId);
			if (!window) return windows;

			// Deactivate all windows
			windows.forEach(w => w.isActive = false);

			// Activate and bring to front
			window.isActive = true;
			window.zIndex = this.nextZIndex++;
			
			// If minimized, restore it
			if (window.state === 'minimized') {
				window.state = 'normal';
			}

			this.activeWindowId.set(windowId);
			return windows;
		});
	}

	/**
	 * Minimize a window
	 */
	public minimizeWindow(windowId: string): void {
		this.windows.update(windows => {
			const window = windows.get(windowId);
			if (!window) return windows;

			window.state = 'minimized';
			window.isActive = false;

			// Activate another window if this was active
			if (get(this.activeWindowId) === windowId) {
				const nextWindow = Array.from(windows.values())
					.filter(w => w.id !== windowId && w.state !== 'minimized')
					.sort((a, b) => b.zIndex - a.zIndex)[0];
				
				if (nextWindow) {
					nextWindow.isActive = true;
					this.activeWindowId.set(nextWindow.id);
				} else {
					this.activeWindowId.set(null);
				}
			}

			return windows;
		});
	}

	/**
	 * Maximize/restore a window
	 */
	public toggleMaximizeWindow(windowId: string): void {
		this.windows.update(windows => {
			const window = windows.get(windowId);
			if (!window) return windows;

			if (window.state === 'maximized') {
				window.state = 'normal';
			} else {
				window.state = 'maximized';
				// Bring maximized window to front
				window.zIndex = this.nextZIndex++;
				// Ensure window is active when maximizing
				windows.forEach(w => w.isActive = false);
				window.isActive = true;
			}

			return windows;
		});

		// Update active window ID if maximizing
		const windows = get(this.windows);
		const window = windows.get(windowId);
		if (window && window.state === 'maximized') {
			this.activeWindowId.set(windowId);
		}
	}

	/**
	 * Update window position
	 */
	public updateWindowPosition(windowId: string, position: { x: number; y: number }): void {
		this.windows.update(windows => {
			const window = windows.get(windowId);
			if (window) {
				window.position = position;
			}
			return windows;
		});
	}

	/**
	 * Update window size
	 */
	public updateWindowSize(windowId: string, size: { width: number; height: number }): void {
		this.windows.update(windows => {
			const window = windows.get(windowId);
			if (window) {
				window.size = size;
			}
			return windows;
		});
	}

	/**
	 * Set window dragging state
	 */
	public setWindowDragging(windowId: string, isDragging: boolean): void {
		this.windows.update(windows => {
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
		this.windows.update(windows => {
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

		// Create a new browser window
		const popOutFeatures = [
			`width=${windowConfig.size.width}`,
			`height=${windowConfig.size.height}`,
			`left=${windowConfig.position.x}`,
			`top=${windowConfig.position.y}`,
			'menubar=no',
			'toolbar=no',
			'location=no',
			'status=no',
			'scrollbars=yes',
			'resizable=yes'
		].join(',');

		const popOutWindow = globalThis.window.open('', `popout_${windowId}`, popOutFeatures);
		
		if (!popOutWindow) {
			console.error('Failed to open pop-out window. Pop-ups may be blocked.');
			return;
		}

		// Get current app URL
		const currentUrl = globalThis.window.location.href;
		const baseUrl = currentUrl.split('#')[0].split('?')[0]; // Remove any hash and query params
		
		// Serialize the window data to pass to iframe
		// Try to get a better component name
		let componentName = windowConfig.component.name || 'UnknownComponent';
		
		// Map known components to their proper names
		if (componentName === 'wrapper' || !componentName || componentName === 'UnknownComponent') {
			// Try to infer from the window title
			if (windowConfig.title.includes('Branches Master')) {
				componentName = 'BranchMaster';
			} else if (windowConfig.title.includes('Start Receiving')) {
				componentName = 'StartReceiving';
			} else if (windowConfig.title.includes('Receiving Records') || windowConfig.title.includes('📋 Receiving Records')) {
				componentName = 'ReceivingRecords';
			} else if (windowConfig.title.includes('Receiving Tasks')) {
				componentName = 'ReceivingTasksDashboard';
			} else if (windowConfig.title.includes('Receiving Data')) {
				componentName = 'ReceivingDataWindow';
			} else if (windowConfig.title.match(/^Receiving #\d+$/)) {
				// This is the main Receiving dashboard from Operations Master
				componentName = 'Receiving';
			} else if (windowConfig.title.includes('Upload Vendor')) {
				componentName = 'UploadVendor';
			} else if (windowConfig.title.includes('Manage Vendor')) {
				componentName = 'ManageVendor';
			} else if (windowConfig.title.includes('Payment Manager') || windowConfig.title.includes('Scheduled Payments')) {
				componentName = 'PaymentManager';
			} else if (windowConfig.title.includes('Task Status')) {
				componentName = 'TaskStatusView';
			} else if (windowConfig.title.includes('View Task Templates')) {
				componentName = 'TaskTemplateView';
			} else if (windowConfig.title.includes('Assign Tasks')) {
				componentName = 'TaskAssignView';
			} else if (windowConfig.title.includes('My Tasks')) {
				componentName = 'MyTasksView';
			} else if (windowConfig.title.includes('My Assignments')) {
				componentName = 'MyAssignmentsView';
			} else if (windowConfig.title.includes('Edit User')) {
				componentName = 'EditUser';
			} else if (windowConfig.title.includes('Notification Center')) {
				componentName = 'NotificationCenter';
			} else if (windowConfig.title.includes('Document Management')) {
				componentName = 'DocumentManagement';
			} else if (windowConfig.title.includes('Scheduled Payments')) {
				componentName = 'ScheduledPayments';
			} else if (windowConfig.title.includes('Task Master')) {
				componentName = 'TaskMaster';
			} else if (windowConfig.title.includes('HR Master')) {
				componentName = 'HRMaster';
			} else if (windowConfig.title.includes('Operations Master')) {
				componentName = 'OperationsMaster';
			} else if (windowConfig.title.includes('Vendor Master')) {
				componentName = 'VendorMaster';
			} else if (windowConfig.title.includes('Finance Master')) {
				componentName = 'FinanceMaster';
			} else if (windowConfig.title.includes('User Management')) {
				componentName = 'UserManagement';
			} else if (windowConfig.title.includes('Communication Center')) {
				componentName = 'CommunicationCenter';
			} else if (windowConfig.title.includes('Settings')) {
				componentName = 'Settings';
			}
		}
		
		const windowData = encodeURIComponent(JSON.stringify({
			id: windowConfig.id,
			title: windowConfig.title,
			component: componentName,
			icon: windowConfig.icon,
			size: windowConfig.size,
			props: windowConfig.props || {}
		}));
		
		// Construct the iframe URL with popout parameter and window data
		const iframeUrl = `${baseUrl}?popout=${windowId}&windowData=${windowData}`;

		// Set up the pop-out window with iframe containing the app
		popOutWindow.document.title = windowConfig.title;
		popOutWindow.document.head.innerHTML = `
			<meta charset="utf-8">
			<meta name="viewport" content="width=device-width, initial-scale=1">
			<title>${windowConfig.title}</title>
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
				}
			</style>
		`;

		// Create the pop-out window content with iframe
		popOutWindow.document.body.innerHTML = `
			<div class="popout-header" id="popout-header">
				<div class="popout-title">
					<span>${windowConfig.icon || '📱'}</span>
					<span>${windowConfig.title}</span>
				</div>
				<div class="popout-controls">
					<button class="popout-btn" onclick="returnToApp()">↩️ Return to App</button>
					<button class="popout-btn" onclick="window.close()">✕ Close</button>
				</div>
			</div>
			<div class="loading-message" id="loading">
				<p>Loading window content...</p>
				<small>Loading: ${windowConfig.title}</small>
			</div>
			<iframe 
				class="popout-iframe" 
				src="${iframeUrl}"
				title="${windowConfig.title}"
				onload="
					document.getElementById('loading').style.display='none';
				"
				onerror="document.getElementById('loading').innerHTML='<p>Error loading content</p><small>Component: ${componentName}</small>'"
			></iframe>
			<script>
				function returnToApp() {
					// Notify parent window to pop this window back in
					if (window.opener && !window.opener.closed) {
						window.opener.postMessage({
							type: 'pop-in-window',
							windowId: '${windowId}'
						}, '*');
						window.close();
					}
				}
			</script>
		`;

		// Update window state
		this.windows.update(windows => {
			const windowConfig = windows.get(windowId);
			if (windowConfig) {
				windowConfig.isPoppedOut = true;
				windowConfig.popOutWindow = popOutWindow;
				windowConfig.state = 'minimized'; // Hide in main app
			}
			return windows;
		});

		// Handle pop-out window close
		popOutWindow.addEventListener('beforeunload', () => {
			this.popInWindow(windowId);
		});

		// Focus the pop-out window
		popOutWindow.focus();
	}

	/**
	 * Pop in a window back to the main application
	 */
	public popInWindow(windowId: string): void {
		this.windows.update(windows => {
			const windowConfig = windows.get(windowId);
			if (windowConfig && windowConfig.isPoppedOut) {
				// Close the pop-out window if it exists
				if (windowConfig.popOutWindow && !windowConfig.popOutWindow.closed) {
					windowConfig.popOutWindow.close();
				}

				// Reset window state
				windowConfig.isPoppedOut = false;
				windowConfig.popOutWindow = undefined;
				windowConfig.state = 'normal';
				
				// Activate the window
				windows.forEach(w => w.isActive = false);
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
		this.windows.update(windows => {
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
		this.windows.update(windows => {
			windows.forEach(window => {
				window.state = 'minimized';
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
			y: 100 + (offset % 200)
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
		return Array.from(get(this.windows).values()).some(w => w.modal && w.state !== 'minimized');
	}

	// Store getters for reactive subscriptions
	public get windows$() { return this.windows; }
	public get activeWindowId$() { return this.activeWindowId; }
}

// Export singleton instance
export const windowManager = new WindowManager();
