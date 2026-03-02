<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { page } from '$app/stores';
	import { _, switchLocale, currentLocale } from '$lib/i18n';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import CustomerLogin from '$lib/components/customer-interface/common/CustomerLogin.svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let maskPollInterval: any = null;
	let autoLoginActive = false;

	let mounted = false;
	let showContent = false;
	// NOTE: showMask controls the blur overlay on customer login section
	// Value loaded from DB (delivery_service_settings.customer_login_mask_enabled)
	let showMask = true;

	// Auto-login code from URL ?code=123456
	let autoLoginCode: string | null = null;

	// Secret dev unmask: click 15 times to dismiss
	let maskClicks = 0;
	let maskTimer: any = null;
	function handleMaskClick() {
		maskClicks++;
		clearTimeout(maskTimer);
		maskTimer = setTimeout(() => { maskClicks = 0; }, 3000);
		if (maskClicks >= 15) {
			showMask = false;
			maskClicks = 0;
		}
	}

	onMount(async () => {
		mounted = true;
		setTimeout(() => {
			showContent = true;
		}, 300);

		if ($isAuthenticated && $currentUser) {
			window.location.href = '/customer-interface';
			return;
		}

		// Check if already logged in as customer
		try {
			const customerSession = localStorage.getItem('customer_session');
			if (customerSession) {
				const data = JSON.parse(customerSession);
				if (data?.customer_id && data?.registration_status === 'approved') {
					window.location.href = '/customer-interface';
					return;
				}
			}
		} catch {}

		// Load mask setting from DB
		try {
			const { data } = await supabase
				.from('delivery_service_settings')
				.select('customer_login_mask_enabled')
				.single();
			if (data) showMask = data.customer_login_mask_enabled;
		} catch {}

		// Poll for mask setting changes every 3 seconds
		maskPollInterval = setInterval(async () => {
			if (autoLoginActive) return; // Don't override mask during auto-login
			try {
				const { data } = await supabase
					.from('delivery_service_settings')
					.select('customer_login_mask_enabled')
					.single();
				if (data) showMask = data.customer_login_mask_enabled;
			} catch {}
		}, 3000);

		// Check for ?code= parameter in URL (from WhatsApp login button)
		const codeParam = $page.url.searchParams.get('code');
		if (codeParam && /^\d{6}$/.test(codeParam)) {
			autoLoginCode = codeParam;
			autoLoginActive = true;
			// Unlock the mask so auto-login can proceed
			showMask = false;
		}
	});

	onDestroy(() => {
		if (maskPollInterval) clearInterval(maskPollInterval);
	});

	function handleCustomerSuccess(event) {
		const { detail } = event;
		if (detail.type === 'customer_login') {
			// Use window.location.href instead of goto() to ensure a full page load
			// This prevents redirect loops when navigating across route trees
			window.location.href = '/customer-interface';
		}
	}
</script>

<svelte:head>
	<title>Customer Login - Aqura Management System</title>
	<meta name="description" content="Access your Aqura Customer Portal" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
	<meta name="google" content="notranslate" />
	<meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="login-page" class:mounted>
	{#if showContent}
		<div class="login-content">
			<div class="customer-login-card">
				<div class="logo-section">
					<div class="logo">
						<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Aqura Logo" class="logo-image" />
					</div>
					<button 
						class="language-toggle-main" 
						on:click={() => {
							switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
						}}
						title={$_('nav.languageToggle')}
					>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<path d="M8 12h8"/>
							<path d="M12 8v8"/>
						</svg>
						{$currentLocale === 'ar' ? 'English' : 'العربية'}
					</button>
				</div>

				<div class="auth-section">
					<div class="customer-login-wrapper">

						<CustomerLogin showMask={showMask} autoLoginCode={autoLoginCode} on:success={handleCustomerSuccess} />
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	:global(html) {
		touch-action: manipulation;
		-webkit-text-size-adjust: 100%;
		overflow-x: hidden;
		height: 100%;
	}

	:global(body) {
		margin: 0;
		padding: 0;
		overflow-x: hidden;
		min-height: 100vh;
		min-height: 100dvh;
		height: 100%;
		-webkit-overflow-scrolling: touch;
		position: relative;
	}

	:global(input, select, textarea) {
		font-size: 16px !important;
	}

	.login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 1rem;
		padding-top: 2rem;
		background: linear-gradient(135deg, #FF8C00 0%, #22C55E 50%, #FFFFFF 100%);
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	.login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(255, 255, 255, 0.1) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(255, 255, 255, 0.08) 0%, transparent 50%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23FFFFFF' fill-opacity='0.04'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 500px;
		position: relative;
		z-index: 1;
		margin: 1rem 0;
		min-height: 0;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.customer-login-card {
		background: rgba(255, 255, 255, 0.95);
		backdrop-filter: blur(20px);
		border-radius: 20px;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.2);
		overflow: hidden;
		animation: slideInUp 0.8s ease-out;
	}

	@keyframes slideInUp {
		from {
			opacity: 0;
			transform: translateY(40px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.logo-section {
		text-align: center;
		padding: 2.5rem 2rem;
		background: linear-gradient(135deg, #FF8C00 0%, #22C55E 100%);
		color: white;
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
	}

	.logo-section::after {
		content: '';
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, #F59E0B 0%, #FBBF24 100%);
	}

	.logo {
		width: 160px;
		height: 100px;
		background: white;
		border: 5px solid #F59E0B;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 20px rgba(245, 158, 11, 0.6),
			0 0 40px rgba(245, 158, 11, 0.4);
	}

	.logo-image {
		width: 120px;
		height: 70px;
		border-radius: 12px;
		object-fit: contain;
	}

	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.15);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.4);
	}

	.auth-section {
		padding: 2rem;
	}

	.auth-section :global(.customer-login-container) {
		padding: 0;
		margin: 0;
		background: transparent;
		border: none;
		box-shadow: none;
	}

	.customer-login-wrapper {
		position: relative;
		width: 100%;
	}

	.login-mask {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(255, 255, 255, 0.3);
		backdrop-filter: blur(0px);
		pointer-events: auto;
		border-radius: 12px;
		z-index: 100;
		display: flex;
		align-items: flex-end;
		justify-content: flex-end;
	}

	.mask-click-counter {
		font-size: 0.7rem;
		color: #9ca3af;
		font-weight: 600;
		padding: 6px 10px;
		pointer-events: none;
		opacity: 0.6;
	}

	@media (max-width: 768px) {
		.login-page {
			padding: 1rem;
			padding-top: 1rem;
			padding-bottom: 3rem;
		}

		.login-content {
			max-width: 100%;
		}

		.customer-login-card {
			border-radius: 16px;
		}

		.logo-section {
			padding: 2rem 1.5rem;
		}

		.logo {
			width: 140px;
			height: 85px;
		}

		.logo-image {
			width: 95px;
			height: 55px;
		}

		.language-toggle-main {
			padding: 0.5rem 1rem;
			font-size: 0.875rem;
		}

		.auth-section {
			padding: 1.5rem;
		}
	}

	@media (max-width: 480px) {
		.login-page {
			padding: 1rem;
			padding-top: 1rem;
			padding-bottom: 2rem;
		}

		.logo-section {
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 120px;
			height: 70px;
		}

		.logo-image {
			width: 80px;
			height: 45px;
		}

		.language-toggle-main {
			padding: 0.4rem 0.75rem;
			font-size: 0.75rem;
		}

		.auth-section {
			padding: 1rem;
		}
	}
</style>
