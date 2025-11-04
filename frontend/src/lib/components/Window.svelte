<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { windowManager, type WindowConfig } from '$lib/stores/windowManager';
	import { sidebar } from '$lib/stores/sidebar';
	
	export let window: WindowConfig;
	
	let windowElement: HTMLDivElement;
	let titleBarElement: HTMLDivElement;
	let isDragging = false;
	let isResizing = false;
	let dragStart = { x: 0, y: 0 };
	let resizeStart = { x: 0, y: 0, width: 0, height: 0 };
	let resizeDirection = '';
	let refreshing = false;

	// Reactive variables for window state
	$: isMaximized = window.state === 'maximized';
	$: isMinimized = window.state === 'minimized';
	$: isActive = window.isActive;
	
	// Check if we're in a popout iframe
	$: isInPopout = typeof globalThis !== 'undefined' && globalThis.window && globalThis.window.location.hash.includes('#popout=');
	
	// Debug reactive statement
	$: {
		console.log('Window state changed:', {
			id: window.id,
			state: window.state,
			isMaximized,
			position: window.position,
			size: window.size
		});
	}

	// Window bounds
	$: windowStyle = `
		left: ${isMaximized ? '0px !important' : window.position.x + 'px'};
		top: ${isMaximized ? '0px !important' : window.position.y + 'px'};
		width: ${isMaximized ? '100% !important' : window.size.width + 'px'};
		height: ${isMaximized ? 'calc(100vh - 48px) !important' : window.size.height + 'px'};
		z-index: ${window.zIndex};
		display: ${isMinimized ? 'none' : 'flex'};
	`;

	onMount(() => {
		// Add event listeners for dragging and resizing
		document.addEventListener('mousemove', handleMouseMove);
		document.addEventListener('mouseup', handleMouseUp);
	});

	onDestroy(() => {
		document.removeEventListener('mousemove', handleMouseMove);
		document.removeEventListener('mouseup', handleMouseUp);
	});

	function handleTitleBarMouseDown(event: MouseEvent) {
		if (window.state === 'maximized') return;
		
		isDragging = true;
		windowManager.setWindowDragging(window.id, true);
		windowManager.activateWindow(window.id);
		
		const rect = windowElement.getBoundingClientRect();
		dragStart = {
			x: event.clientX - rect.left,
			y: event.clientY - rect.top
		};
		
		event.preventDefault();
	}

	function handleResizeMouseDown(event: MouseEvent, direction: string) {
		if (!window.resizable || window.state === 'maximized') return;
		
		isResizing = true;
		resizeDirection = direction;
		windowManager.setWindowResizing(window.id, true);
		windowManager.activateWindow(window.id);
		
		resizeStart = {
			x: event.clientX,
			y: event.clientY,
			width: window.size.width,
			height: window.size.height
		};
		
		event.preventDefault();
		event.stopPropagation();
	}

	function handleMouseMove(event: MouseEvent) {
		if (isDragging) {
			const newX = event.clientX - dragStart.x;
			const newY = Math.max(0, event.clientY - dragStart.y); // Prevent dragging above viewport
			
			windowManager.updateWindowPosition(window.id, { x: newX, y: newY });
		} else if (isResizing) {
			const deltaX = event.clientX - resizeStart.x;
			const deltaY = event.clientY - resizeStart.y;
			
			let newWidth = resizeStart.width;
			let newHeight = resizeStart.height;
			let newX = window.position.x;
			let newY = window.position.y;
			
			// Calculate new dimensions based on resize direction
			if (resizeDirection.includes('e')) {
				newWidth = Math.max(window.minSize?.width || 200, resizeStart.width + deltaX);
			}
			if (resizeDirection.includes('w')) {
				newWidth = Math.max(window.minSize?.width || 200, resizeStart.width - deltaX);
				newX = window.position.x + (resizeStart.width - newWidth);
			}
			if (resizeDirection.includes('s')) {
				newHeight = Math.max(window.minSize?.height || 150, resizeStart.height + deltaY);
			}
			if (resizeDirection.includes('n')) {
				newHeight = Math.max(window.minSize?.height || 150, resizeStart.height - deltaY);
				newY = window.position.y + (resizeStart.height - newHeight);
			}
			
			// Apply max size constraints
			if (window.maxSize) {
				newWidth = Math.min(newWidth, window.maxSize.width);
				newHeight = Math.min(newHeight, window.maxSize.height);
			}
			
			windowManager.updateWindowSize(window.id, { width: newWidth, height: newHeight });
			if (resizeDirection.includes('w') || resizeDirection.includes('n')) {
				windowManager.updateWindowPosition(window.id, { x: newX, y: newY });
			}
		}
	}

	function handleMouseUp() {
		if (isDragging) {
			isDragging = false;
			windowManager.setWindowDragging(window.id, false);
		}
		if (isResizing) {
			isResizing = false;
			resizeDirection = '';
			windowManager.setWindowResizing(window.id, false);
		}
	}

	function handleWindowClick() {
		if (!isActive) {
			windowManager.activateWindow(window.id);
		}
	}

	function handleTitleBarDoubleClick() {
		if (window.maximizable) {
			windowManager.toggleMaximizeWindow(window.id);
		}
	}

	function minimize() {
		if (window.minimizable) {
			windowManager.minimizeWindow(window.id);
		}
	}

	function toggleMaximize() {
		if (window.maximizable) {
			console.log('Toggling maximize for window:', window.id, 'current state:', window.state);
			windowManager.toggleMaximizeWindow(window.id);
		}
	}

	function close() {
		if (window.closable) {
			windowManager.closeWindow(window.id);
		}
	}

	function popOut() {
		if (window.popOutEnabled && !window.isPoppedOut) {
			windowManager.popOutWindow(window.id);
		}
	}

	function popIn() {
		if (window.isPoppedOut) {
			windowManager.popInWindow(window.id);
		}
	}

	async function refresh() {
		if (refreshing) return; // Prevent multiple simultaneous refreshes
		
		try {
			refreshing = true;
			console.log('🔄 [Window] Starting window refresh for:', window.title);
			console.log('🔍 [Window] Window props:', window.props);
			
			// Try multiple approaches to find and call refresh function
			let refreshExecuted = false;
			
			// Method 1: Call component's onRefresh if available
			if (window.props?.onRefresh) {
				console.log('✅ [Window] Found onRefresh prop, calling it...');
				try {
					await window.props.onRefresh();
					refreshExecuted = true;
				} catch (error) {
					console.error('❌ [Window] onRefresh failed:', error);
				}
			}
			
			// Method 2: Try to find data-refresh-target element
			if (!refreshExecuted) {
				const componentElement = windowElement?.querySelector('[data-refresh-target]');
				if (componentElement && componentElement.refreshData) {
					console.log('✅ [Window] Found data-refresh-target element, calling refreshData...');
					try {
						await componentElement.refreshData();
						refreshExecuted = true;
					} catch (error) {
						console.error('❌ [Window] refreshData failed:', error);
					}
				}
			}
			
			// Method 3: Fallback to window manager refresh
			if (!refreshExecuted) {
				console.log('❌ [Window] No refresh methods found, using fallback remount');
				windowManager.refreshWindow(window.id);
				refreshExecuted = true;
			}
			
			if (refreshExecuted) {
				console.log('✅ [Window] Window refresh successful for:', window.title);
			}
		} catch (error) {
			console.error('❌ [Window] Error during window refresh:', error);
		} finally {
			refreshing = false;
		}
	}
</script>

<div
	bind:this={windowElement}
	class="window"
	class:active={isActive}
	class:maximized={isMaximized}
	class:modal={window.modal}
	class:window-maximized={isMaximized}
	style={windowStyle}
	on:mousedown={handleWindowClick}
	role="dialog"
	aria-label={window.title}
	aria-modal={window.modal ? 'true' : 'false'}
>
	<!-- Title Bar -->
	<div
		bind:this={titleBarElement}
		class="title-bar"
		on:mousedown={handleTitleBarMouseDown}
		on:dblclick={handleTitleBarDoubleClick}
		role="banner"
		aria-label="Window title bar"
	>
		<div class="title-bar-content">
			{#if window.icon}
				{#if window.icon.startsWith('http') || window.icon.startsWith('/') || window.icon.includes('.')}
					<img src={window.icon} alt="" class="window-icon" />
				{:else}
					<span class="window-icon-emoji">{window.icon}</span>
				{/if}
			{/if}
			<span class="window-title">{window.title}</span>
		</div>
		
		<div class="title-bar-controls">
			<!-- Refresh button enabled -->
			{#if true}
				<button
					class="control-button refresh"
					disabled={refreshing}
					on:click|stopPropagation={refresh}
					title={refreshing ? "Refreshing..." : "Refresh"}
					aria-label="Refresh window content"
				>
					{#if refreshing}
						⏳
					{:else}
						🔄
					{/if}
				</button>
			{/if}
			
			{#if window.popOutEnabled && !window.modal && !isInPopout}
				<button
					class="control-button popout"
					on:click|stopPropagation={window.isPoppedOut ? popIn : popOut}
					title={window.isPoppedOut ? 'Pop In' : 'Pop Out'}
					aria-label={window.isPoppedOut ? 'Pop window back into application' : 'Pop window out to new browser window'}
				>
					{#if window.isPoppedOut}
						<svg viewBox="0 0 16 16" width="14" height="14">
							<!-- Single screen (popped in state) -->
							<rect x="3" y="4" width="10" height="6" stroke="currentColor" stroke-width="1" fill="none" />
							<rect x="7" y="10" width="2" height="1" fill="currentColor" />
							<line x1="4" y1="12" x2="12" y2="12" stroke="currentColor" stroke-width="1" />
						</svg>
					{:else}
						<svg viewBox="0 0 16 16" width="14" height="14">
							<!-- Two screens side by side -->
							<rect x="1" y="3" width="5" height="4" stroke="currentColor" stroke-width="1" fill="none" />
							<rect x="10" y="3" width="5" height="4" stroke="currentColor" stroke-width="1" fill="none" />
							<!-- Monitor stands -->
							<rect x="3" y="7" width="1" height="1.5" fill="currentColor" />
							<rect x="12" y="7" width="1" height="1.5" fill="currentColor" />
							<!-- Monitor bases -->
							<line x1="2" y1="9" x2="5" y2="9" stroke="currentColor" stroke-width="1" />
							<line x1="11" y1="9" x2="14" y2="9" stroke="currentColor" stroke-width="1" />
						</svg>
					{/if}
				</button>
			{/if}
			
			{#if window.minimizable}
				<button
					class="control-button minimize"
					on:click|stopPropagation={minimize}
					title="Minimize"
					aria-label="Minimize window"
				>
					<svg viewBox="0 0 12 12" width="12" height="12">
						<rect x="2" y="5" width="8" height="2" fill="currentColor" />
					</svg>
				</button>
			{/if}
			
			{#if window.maximizable}
				<button
					class="control-button maximize"
					on:click|stopPropagation={toggleMaximize}
					title={isMaximized ? 'Restore' : 'Maximize'}
					aria-label={isMaximized ? 'Restore window' : 'Maximize window'}
				>
					{#if isMaximized}
						<svg viewBox="0 0 12 12" width="12" height="12">
							<rect x="1" y="3" width="7" height="7" stroke="currentColor" stroke-width="1" fill="none" />
							<rect x="3" y="1" width="7" height="7" stroke="currentColor" stroke-width="1" fill="none" />
						</svg>
					{:else}
						<svg viewBox="0 0 12 12" width="12" height="12">
							<rect x="2" y="2" width="8" height="8" stroke="currentColor" stroke-width="1" fill="none" />
						</svg>
					{/if}
				</button>
			{/if}
			
			{#if window.closable}
				<button
					class="control-button close"
					on:click|stopPropagation={close}
					title="Close"
					aria-label="Close window"
				>
					<svg viewBox="0 0 12 12" width="12" height="12">
						<path d="M2,2 L10,10 M10,2 L2,10" stroke="currentColor" stroke-width="1.5" />
					</svg>
				</button>
			{/if}
		</div>
	</div>

	<!-- Window Content -->
	<div class="window-content">
		<svelte:component this={window.component} {...window.props} />
	</div>

	<!-- Resize Handles -->
	{#if window.resizable && !isMaximized}
		<!-- Edges -->
		<div
			class="resize-handle resize-n"
			on:mousedown={(e) => handleResizeMouseDown(e, 'n')}
			role="separator"
			aria-label="Resize window north"
		></div>
		<div
			class="resize-handle resize-s"
			on:mousedown={(e) => handleResizeMouseDown(e, 's')}
			role="separator"
			aria-label="Resize window south"
		></div>
		<div
			class="resize-handle resize-e"
			on:mousedown={(e) => handleResizeMouseDown(e, 'e')}
			role="separator"
			aria-label="Resize window east"
		></div>
		<div
			class="resize-handle resize-w"
			on:mousedown={(e) => handleResizeMouseDown(e, 'w')}
			role="separator"
			aria-label="Resize window west"
		></div>
		
		<!-- Corners -->
		<div
			class="resize-handle resize-nw"
			on:mousedown={(e) => handleResizeMouseDown(e, 'nw')}
			role="separator"
			aria-label="Resize window northwest"
		></div>
		<div
			class="resize-handle resize-ne"
			on:mousedown={(e) => handleResizeMouseDown(e, 'ne')}
			role="separator"
			aria-label="Resize window northeast"
		></div>
		<div
			class="resize-handle resize-sw"
			on:mousedown={(e) => handleResizeMouseDown(e, 'sw')}
			role="separator"
			aria-label="Resize window southwest"
		></div>
		<div
			class="resize-handle resize-se"
			on:mousedown={(e) => handleResizeMouseDown(e, 'se')}
			role="separator"
			aria-label="Resize window southeast"
		></div>
	{/if}
</div>

<style>
	.window {
		position: fixed;
		background: #FFFFFF;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		box-shadow: 0 10px 25px rgba(11, 18, 32, 0.15);
		display: flex;
		flex-direction: column;
		overflow: hidden;
		user-select: none;
		transition: box-shadow 0.2s ease;
		pointer-events: all;
	}

	.window.active {
		box-shadow: 0 20px 40px rgba(11, 18, 32, 0.25);
		border-color: #4F46E5;
	}

	.window.modal {
		border-color: #15A34A;
		box-shadow: 0 20px 40px rgba(21, 163, 74, 0.3);
	}

	.window.maximized,
	.window-maximized {
		border-radius: 0 !important;
		border: none !important;
		left: 0 !important;
		top: 0 !important;
		width: 100% !important;
		height: 100vh !important;
		position: absolute !important;
		max-width: 100% !important;
		max-height: 100vh !important;
	}

	.title-bar {
		background: linear-gradient(135deg, #F9FAFB 0%, #E5E7EB 100%);
		border-bottom: 1px solid rgba(21, 163, 74, 0.2);
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 12px;
		cursor: move;
		pointer-events: all;
		color: #374151;
	}

	.window.active .title-bar {
		background: linear-gradient(135deg, #4F46E5 0%, #6366F1 100%);
		color: white;
		border-bottom-color: #4338CA;
	}

	.window.modal .title-bar {
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		border-bottom-color: #16A34A;
	}

	.title-bar-content {
		display: flex;
		align-items: center;
		gap: 8px;
		flex: 1;
		min-width: 0;
	}

	.window-icon {
		width: 16px;
		height: 16px;
		flex-shrink: 0;
	}

	.window-icon-emoji {
		font-size: 16px;
		flex-shrink: 0;
		line-height: 1;
	}

	.window-title {
		font-weight: 500;
		font-size: 14px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.title-bar-controls {
		display: flex;
		gap: 2px;
		flex-shrink: 0;
	}

	.control-button {
		width: 32px;
		height: 28px;
		border: none;
		background: transparent;
		color: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: background-color 0.15s ease;
		pointer-events: all;
	}

	.control-button:hover {
		background: rgba(0, 0, 0, 0.1);
	}

	.control-button.close:hover {
		background: #ef4444;
		color: white;
	}

	.control-button.refresh:hover {
		background: #10b981;
		color: white;
	}

	.control-button.refresh:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		pointer-events: none;
		background: rgba(0, 0, 0, 0.1);
	}

	.control-button.popout:hover {
		background: #3b82f6;
		color: white;
	}

	.window-content {
		flex: 1;
		overflow: auto;
		background: white;
	}

	.window-maximized .window-content {
		height: calc(100vh - 40px) !important;
		width: 100% !important;
	}

	/* Resize Handles */
	.resize-handle {
		position: absolute;
		background: transparent;
	}

	.resize-n, .resize-s {
		left: 8px;
		right: 8px;
		height: 4px;
		cursor: ns-resize;
	}

	.resize-n { top: -2px; }
	.resize-s { bottom: -2px; }

	.resize-e, .resize-w {
		top: 8px;
		bottom: 8px;
		width: 4px;
		cursor: ew-resize;
	}

	.resize-e { right: -2px; }
	.resize-w { left: -2px; }

	.resize-nw, .resize-ne, .resize-sw, .resize-se {
		width: 8px;
		height: 8px;
	}

	.resize-nw {
		top: -2px;
		left: -2px;
		cursor: nw-resize;
	}

	.resize-ne {
		top: -2px;
		right: -2px;
		cursor: ne-resize;
	}

	.resize-sw {
		bottom: -2px;
		left: -2px;
		cursor: sw-resize;
	}

	.resize-se {
		bottom: -2px;
		right: -2px;
		cursor: se-resize;
	}

	/* Disable text selection during drag */
	.window:global(.dragging *) {
		user-select: none !important;
		pointer-events: none !important;
	}
</style>
