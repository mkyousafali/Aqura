<script lang="ts">
	import { onMount } from 'svelte';
	import { initI18n, currentLocale, localeData } from '$lib/i18n';
	import { sidebar } from '$lib/stores/sidebar';
	import { browser } from '$app/environment';
	import '../app.css';
	import WindowManager from '$lib/components/WindowManager.svelte';
	import Taskbar from '$lib/components/Taskbar.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import CommandPalette from '$lib/components/CommandPalette.svelte';
	import PWAInstallPrompt from '$lib/components/PWAInstallPrompt.svelte';

	// Initialize i18n system
	initI18n();

	// Command palette state
	let showCommandPalette = false;

	// Global keyboard shortcuts
	function handleGlobalKeydown(event: KeyboardEvent) {
		// Ctrl+Shift+P or Cmd+Shift+P for command palette
		if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'P') {
			event.preventDefault();
			showCommandPalette = !showCommandPalette;
		}
		
		// Escape to close command palette
		if (event.key === 'Escape' && showCommandPalette) {
			showCommandPalette = false;
		}
	}

	// Direction class for RTL support
	$: directionClass = $localeData?.direction === 'rtl' ? 'rtl' : 'ltr';
</script>

<svelte:window on:keydown={handleGlobalKeydown} />

<div class="app {directionClass}" dir={$localeData?.direction || 'ltr'}>
	<!-- Sidebar Navigation -->
	<Sidebar />
	
	<!-- Desktop Background -->
	<div class="desktop" style="margin-left: {$sidebar.width}px">
		<!-- Main content area -->
		<main class="main-content">
			<slot />
		</main>
		
		<!-- Window Management System -->
		<WindowManager />
		
		<!-- Command Palette -->
		<CommandPalette 
			bind:visible={showCommandPalette}
			on:close={() => showCommandPalette = false}
		/>
	</div>
	
	<!-- Taskbar -->
	<Taskbar />
</div>

<!-- PWA Install Prompt -->
<PWAInstallPrompt />

<style>
	.app {
		min-height: 100vh;
		background: #F9FAFB;
		background-attachment: fixed;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		overflow: hidden;
		position: relative;
	}

	.app::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(107, 114, 128, 0.08) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(156, 163, 175, 0.06) 0%, transparent 50%),
			radial-gradient(circle at 50% 50%, rgba(209, 213, 219, 0.04) 0%, transparent 60%),
			radial-gradient(circle at 80% 20%, rgba(229, 231, 235, 0.08) 0%, transparent 40%),
			radial-gradient(circle at 20% 80%, rgba(243, 244, 246, 0.1) 0%, transparent 45%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%236B7280' fill-opacity='0.02'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.desktop {
		height: calc(100vh - 56px); /* Fixed taskbar height */
		position: relative;
		overflow: hidden;
		z-index: 1;
		transition: margin-left 0.3s ease;
	}

	.main-content {
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
		z-index: 1;
	}

	/* RTL Support */
	.app.rtl {
		direction: rtl;
	}

	/* Global styles for window content */
	:global(.window-content) {
		font-family: inherit;
	}

	:global(.window-content h1) {
		font-size: 1.5rem;
		font-weight: 600;
		margin-bottom: 1rem;
		color: #1e293b;
	}

	:global(.window-content h2) {
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 0.75rem;
		color: #334155;
	}

	:global(.window-content p) {
		color: #64748b;
		line-height: 1.6;
		margin-bottom: 1rem;
	}

	/* Button styles */
	:global(.btn) {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		border: 1px solid transparent;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
		text-decoration: none;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	:global(.btn-primary) {
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		border-color: #15A34A;
	}

	:global(.btn-primary:hover) {
		background: linear-gradient(135deg, #166534 0%, #15A34A 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(21, 163, 74, 0.25);
	}

	:global(.btn-secondary) {
		background: #4F46E5;
		color: white;
		border-color: #4F46E5;
	}

	:global(.btn-secondary:hover) {
		background: #4338CA;
		border-color: #4338CA;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(79, 70, 229, 0.25);
	}

	:global(.btn-accent) {
		background: linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%);
		color: #0B1220;
		border-color: #F59E0B;
	}

	:global(.btn-accent:hover) {
		background: linear-gradient(135deg, #D97706 0%, #F59E0B 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.25);
	}

	:global(.btn-success) {
		background: #10B981;
		color: white;
		border-color: #10B981;
	}

	:global(.btn-success:hover) {
		background: #059669;
		border-color: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.25);
	}

	/* Form styles */
	:global(.form-group) {
		margin-bottom: 1rem;
	}

	:global(.form-label) {
		display: block;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.25rem;
	}

	:global(.form-input) {
		width: 100%;
		padding: 0.5rem 0.75rem;
		border: 1px solid #E5E7EB;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		background: #FFFFFF;
		color: #0B1220;
		transition: border-color 0.15s ease, box-shadow 0.15s ease;
	}

	:global(.form-input:focus) {
		outline: none;
		border-color: #4F46E5;
		box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
	}

	/* Table styles */
	:global(.table) {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	:global(.table th) {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		padding: 0.75rem;
		text-align: left;
		font-weight: 500;
		color: #374151;
	}

	:global(.table td) {
		border: 1px solid #e2e8f0;
		padding: 0.75rem;
		color: #6b7280;
	}

	:global(.table tbody tr:hover) {
		background: #f9fafb;
	}

	/* Utility classes */
	:global(.p-4) { padding: 1rem; }
	:global(.p-6) { padding: 1.5rem; }
	:global(.mb-4) { margin-bottom: 1rem; }
	:global(.text-center) { text-align: center; }
	:global(.text-xl) { font-size: 1.25rem; }
	:global(.font-bold) { font-weight: 700; }
	:global(.opacity-50) { opacity: 0.5; }
</style>
