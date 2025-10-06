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
	modal?: boolean;
	zIndex: number;
	state: 'normal' | 'minimized' | 'maximized';
	isActive: boolean;
	isDragging: boolean;
	isResizing: boolean;
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
			isResizing: false
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
