<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { sidebar } from '$lib/stores/sidebar';
	import Window from '$lib/components/Window.svelte';

	// Subscribe to window list
	$: windows = windowManager.windowList;
</script>

<!-- Window Container -->
<div class="window-manager" style="left: {$sidebar.width}px; width: calc(100vw - {$sidebar.width}px);">
	{#each $windows as window (window.id)}
		<Window {window} />
	{/each}
	
	<!-- Modal Backdrop -->
	{#if $windows.some(w => w.modal && w.state !== 'minimized')}
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
