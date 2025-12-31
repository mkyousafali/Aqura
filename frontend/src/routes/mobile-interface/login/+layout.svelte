<script lang="ts">
	// This layout ensures mobile-login doesn't inherit desktop styling
</script>

<svelte:head>
	<title>Aqura Mobile Login</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#3B82F6" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<div class="mobile-login-layout">
	<slot />
</div>

<style>
	/* Complete CSS reset for mobile login */
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

	.mobile-login-layout {
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
