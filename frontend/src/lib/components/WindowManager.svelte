<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { sidebar } from '$lib/stores/sidebar';
	import Window from '$lib/components/Window.svelte';

	// Export prop for popout mode
	export let popoutOnly: string = '';

	// Subscribe to window list
	$: windows = windowManager.windowList;
	
	// Filter windows based on mode
	$: filteredWindows = popoutOnly 
		? $windows.filter(w => w.id === popoutOnly)
		: $windows.filter(w => !w.isPoppedOut);
		
	// Debug logging for popout mode
	$: if (popoutOnly) {
		console.log('🪟 WindowManager in popout mode for:', popoutOnly);
		console.log('🪟 Available windows:', $windows.map(w => w.id));
		console.log('🪟 Filtered windows:', filteredWindows.map(w => w.id));
	}
</script>

<!-- Window Container -->
<div class="window-manager" class:popout-mode={!!popoutOnly} style="left: {popoutOnly ? '0px' : $sidebar.width + 'px'}; width: {popoutOnly ? '100vw' : `calc(100vw - ${$sidebar.width}px)`};">
	{#each filteredWindows as window (window.id)}
		<Window {window} />
	{/each}
	
	<!-- Modal Backdrop -->
	{#if filteredWindows.some(w => w.modal && w.state !== 'minimized')}
		<div class="modal-backdrop"></div>
	{/if}
</div>

<style>
	.window-manager {
		position: fixed;
		top: 0;
		height: 100vh;
		pointer-events: none;
		z-index: 1000;
		transition: left 0.3s ease, width 0.3s ease;
	}

	.window-manager.popout-mode {
		left: 0 !important;
		width: 100vw !important;
		transition: none;
	}

	.window-manager.popout-mode :global(.window) {
		position: static !important;
		width: 100% !important;
		height: 100vh !important;
		border-radius: 0 !important;
		box-shadow: none !important;
		border: none !important;
	}

	.window-manager :global(.window) {
		pointer-events: all;
	}

	.window-placeholder {
		position: fixed;
		background: white;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
		overflow: hidden;
	}

	.window-header {
		background: linear-gradient(135deg, #f08300 0%, #e97c00 100%);
		color: white;
		padding: 8px 16px;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.window-title {
		font-weight: 500;
		font-size: 14px;
	}

	.window-header button {
		background: none;
		border: none;
		color: white;
		cursor: pointer;
		padding: 4px 8px;
		border-radius: 4px;
	}

	.window-header button:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.window-content {
		height: calc(100% - 40px);
		overflow: auto;
	}

	.modal-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		background: rgba(0, 0, 0, 0.3);
		z-index: 999;
		pointer-events: all;
	}
</style>
