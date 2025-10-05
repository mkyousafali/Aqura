<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';

	// Mobile-specific layout state
	let currentUserData = null;
	let isLoading = true;

	onMount(async () => {
		console.log('🔍 [Mobile Layout] Starting mobile layout initialization...');
		console.log('🔍 [Mobile Layout] Auth state:', $isAuthenticated);
		console.log('🔍 [Mobile Layout] Current user:', $currentUser);
		
		// Check authentication
		if (!$isAuthenticated) {
			console.log('❌ [Mobile Layout] Not authenticated, redirecting to mobile login');
			goto('/mobile-login');
			return;
		}

		// Check interface preference
		const interfacePreference = localStorage.getItem('aqura-interface-preference');
		console.log('🔍 [Mobile Layout] Interface preference:', interfacePreference);
		
		if (interfacePreference !== 'mobile') {
			// If no mobile preference, redirect to main login to choose
			console.log('⚠️ [Mobile Layout] No mobile preference, redirecting to main login');
			goto('/login');
			return;
		}

		currentUserData = $currentUser;
		isLoading = false;
		console.log('✅ [Mobile Layout] Mobile layout initialization completed');
	});

	// Subscribe to auth changes
	$: if (!$isAuthenticated && !isLoading) {
		goto('/mobile-login');
	}

	$: currentUserData = $currentUser;
</script>

<svelte:head>
	<title>Aqura Mobile Dashboard</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#3B82F6" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

{#if isLoading}
	<div class="mobile-loading">
		<div class="loading-spinner"></div>
		<p>Loading Mobile Dashboard...</p>
	</div>
{:else if $isAuthenticated}
	<div class="mobile-layout">
		<!-- Mobile content goes here -->
		<slot />
	</div>
{:else}
	<div class="mobile-error">
		<h2>Access Required</h2>
		<p>Please log in to access the mobile interface.</p>
		<button on:click={() => goto('/mobile-login')} class="error-btn">
			Go to Mobile Login
		</button>
	</div>
{/if}

<style>
	/* Complete CSS reset and mobile-specific styling */
	:global(*) {
		box-sizing: border-box;
		margin: 0;
		padding: 0;
	}

	:global(html) {
		height: 100%;
		height: 100dvh;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		-webkit-text-size-adjust: 100%;
		-webkit-tap-highlight-color: transparent;
	}

	:global(body) {
		height: 100%;
		height: 100dvh;
		margin: 0 !important;
		padding: 0 !important;
		overflow: auto !important;
		-webkit-overflow-scrolling: touch;
		background: #F8FAFC !important;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif !important;
		line-height: 1.5;
		color: #1F2937;
	}

	:global(#app),
	:global(#svelte) {
		height: 100%;
		height: 100dvh;
		width: 100%;
		margin: 0 !important;
		padding: 0 !important;
		background: transparent !important;
	}

	/* Override any desktop layout styles */
	:global(.layout-container),
	:global(.main-layout),
	:global(.sidebar),
	:global(.navbar),
	:global(.header),
	:global(.desktop-*) {
		display: none !important;
	}

	/* Ensure mobile layout takes full screen */
	:global(.mobile-layout) {
		position: fixed !important;
		top: 0 !important;
		left: 0 !important;
		right: 0 !important;
		bottom: 0 !important;
		width: 100vw !important;
		height: 100vh !important;
		height: 100dvh !important;
		z-index: 9999 !important;
		background: #F8FAFC !important;
		overflow-x: hidden !important;
		overflow-y: auto !important;
	}

	.mobile-loading {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		width: 100vw;
		height: 100vh;
		height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		color: white;
		font-family: 'Inter', 'Segoe UI', sans-serif;
		text-align: center;
		padding: 2rem;
		z-index: 10000;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid rgba(255, 255, 255, 0.3);
		border-top: 3px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.mobile-loading p {
		font-size: 1.1rem;
		opacity: 0.9;
		margin: 0;
	}

	.mobile-layout {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		width: 100vw;
		height: 100vh;
		height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		font-family: 'Inter', 'Segoe UI', sans-serif;
		z-index: 9999;
	}

	.mobile-error {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		width: 100vw;
		height: 100vh;
		height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: #F8FAFC;
		padding: 2rem;
		text-align: center;
		color: #374151;
		z-index: 10000;
	}

	.mobile-error h2 {
		font-size: 1.5rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
		color: #1F2937;
	}

	.mobile-error p {
		font-size: 1rem;
		margin-bottom: 2rem;
		opacity: 0.8;
	}

	.error-btn {
		padding: 0.75rem 1.5rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.error-btn:hover {
		background: #2563EB;
		transform: translateY(-1px);
	}

	/* Mobile-specific global styles */
	:global(button) {
		border: none;
		outline: none;
		cursor: pointer;
		touch-action: manipulation;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
	}

	:global(input),
	:global(textarea),
	:global(select) {
		border: none;
		outline: none;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		font-family: inherit;
	}

	:global(a) {
		text-decoration: none;
		color: inherit;
	}

	/* Ensure no desktop styles leak through */
	:global(.svelte-*) {
		font-family: 'Inter', 'Segoe UI', sans-serif !important;
	}
</style>