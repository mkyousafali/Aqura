<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
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

	// Initial view from URL ?view=loyalty
	let initialViewParam: 'login' | 'register' | 'forgot' | 'loyalty' = 'login';

	// Hide nav buttons when ?minimal=true (direct access code entry)
	let hideNavButtons = false;

	// Keep track of the current internal view
	let currentViewMode: 'login' | 'register' | 'forgot' | 'loyalty' = 'login';

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

		// Check for ?view= parameter in URL (e.g., ?view=loyalty or ?view=register)
		const viewParam = $page.url.searchParams.get('view');
		if (viewParam === 'loyalty' || viewParam === 'register' || viewParam === 'forgot') {
			initialViewParam = viewParam;
			currentViewMode = viewParam;
		}

		// Check for ?minimal=true (hide Follow Us/Offers/Loyalty buttons, show only access code)
		if ($page.url.searchParams.get('minimal') === 'true') {
			hideNavButtons = true;
		}

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
	<div class="ambient-bg">
		<div class="ambient-shape shape-1"></div>
		<div class="ambient-shape shape-2"></div>
		<div class="ambient-shape shape-3"></div>
		<div class="ambient-shape shape-4"></div>
	</div>

	{#if showContent}
		<div class="login-content">
			<div class="customer-login-card">
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
				<div class="logo-section">
					<div class="logo">
						<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Aqura Logo" class="logo-image" />
					</div>
				</div>

				<div class="ahl-urban-branding">
					<h2 class="ahl-urban-title alternating-text">
						{#if $currentLocale === 'ar'}
							<span style="color: #13A538">أ</span><span style="color: #f08300">ه</span><span style="color: #13A538">ل</span>&nbsp;<span style="color: #f08300">ا</span><span style="color: #13A538">ي</span><span style="color: #f08300">ر</span><span style="color: #13A538">ب</span><span style="color: #f08300">ن</span>
						{:else}
							<span style="color: #13A538">A</span><span style="color: #f08300">h</span><span style="color: #13A538">l</span>&nbsp;<span style="color: #f08300">U</span><span style="color: #13A538">r</span><span style="color: #f08300">b</span><span style="color: #13A538">a</span><span style="color: #f08300">n</span>
						{/if}
					</h2>
					<p class="ahl-urban-tagline">
						{#if $currentLocale === 'ar'}
							<span style="color: #13A538">أنت</span> <span style="color: #f08300">من</span> <span style="color: #13A538">أهلنا…</span> <span style="color: #f08300">ولك</span> <span style="color: #13A538">امتيازاتك.</span>
						{:else}
							<span style="color: #13A538">You're</span> <span style="color: #f08300">Part</span> <span style="color: #13A538">of</span> <span style="color: #f08300">Our</span> <span style="color: #13A538">Family…</span> <span style="color: #f08300">And</span> <span style="color: #13A538">You</span> <span style="color: #f08300">Deserve</span> <span style="color: #13A538">Exclusive</span> <span style="color: #f08300">Benefits.</span>
						{/if}
					</p>
				</div>

				{#if hideNavButtons}
					<button class="back-to-login" on:click={() => {
						if (currentViewMode !== 'login') {
							currentViewMode = 'login';
						} else {
							goto('/login');
						}
					}}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
						{$currentLocale === 'ar' ? 'العودة' : 'Back'}
					</button>
				{/if}

					<div class="auth-section">
					<div class="customer-login-wrapper">

						<CustomerLogin initialView={initialViewParam} bind:currentView={currentViewMode} {hideNavButtons} showMask={false} autoLoginCode={autoLoginCode} on:success={handleCustomerSuccess} />
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

	.back-to-login {
		position: absolute;
		top: 1rem;
		left: 1rem;
		z-index: 2;
		display: inline-flex;
		align-items: center;
		gap: 4px;
		background: none;
		border: none;
		color: #64748b;
		font-size: 0.9rem;
		font-weight: 500;
		cursor: pointer;
		padding: 6px 10px;
		border-radius: 6px;
		transition: color 0.2s, background 0.2s;
	}
	.back-to-login:hover {
		color: #1e293b;
		background: #f1f5f9;
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
		background: #FAFAFA;
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	:root {
		--brand-green: #10b981;
		--brand-green-light: #34d399;
		--brand-orange: #f97316;
		--brand-orange-light: #fb923c;
		--brand-pink: #ec4899;
		--brand-pink-light: #f472b6;
		--brand-lavender: #8b5cf6;
		--brand-lavender-light: #a78bfa;
	}

	.ambient-bg {
		position: fixed;
		inset: 0;
		pointer-events: none;
		z-index: 0;
		overflow: hidden;
	}

	.ambient-shape {
		position: absolute;
		filter: blur(80px);
		opacity: 0.4;
		border-radius: 50%;
	}

	.shape-1 { width: 350px; height: 350px; background: var(--brand-orange-light); top: -100px; right: -50px; animation: drift 20s ease-in-out infinite alternate; }
	.shape-2 { width: 300px; height: 300px; background: var(--brand-pink-light); top: 30%; left: -100px; animation: drift 25s ease-in-out infinite alternate-reverse; }
	.shape-3 { width: 400px; height: 400px; background: var(--brand-lavender-light); bottom: -100px; right: 10%; animation: drift 22s ease-in-out infinite alternate; }
	.shape-4 { width: 300px; height: 300px; background: var(--brand-green-light); top: 50%; right: -50px; animation: drift 18s ease-in-out infinite alternate-reverse; }

	@keyframes drift {
		0% { transform: translate(0, 0) scale(1) rotate(0deg); }
		100% { transform: translate(50px, 40px) scale(1.1) rotate(15deg); }
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
		background: rgba(255, 255, 255, 0.6);
		backdrop-filter: blur(25px);
		border-radius: 24px;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.8);
		overflow: hidden;
		animation: slideInUp 0.8s ease-out;
		position: relative;
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

	.language-toggle-main {
		position: absolute;
		top: 1rem;
		right: 1rem;
		z-index: 2;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.5);
		border: 1px solid rgba(0, 0, 0, 0.05);
		color: #334155;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.logo-section {
		text-align: center;
		padding: 0.75rem 2rem 0;
		background: transparent;
		color: #1e293b;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0;
	}

	.ahl-urban-branding {
		text-align: center;
		padding: 0 2rem 0;
		margin-top: -0.5rem;
	}

	.ahl-urban-title {
		font-size: 2.2rem;
		font-weight: 700;
		margin: 0 0 0.1rem;
		letter-spacing: -0.01em;
	}

	.ahl-urban-tagline {
		font-size: 0.88rem;
		font-weight: 500;
		margin: 0;
		line-height: 1.3;
	}

	.logo {
		width: 90px;
		height: 90px;
		min-width: 90px;
		min-height: 90px;
		background: #ffffff;
		border: 3px solid rgba(19, 165, 56, 0.2);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12), 0 0 0 6px rgba(19, 165, 56, 0.08);
		overflow: hidden;
		aspect-ratio: 1 / 1;
	}

	.logo-image {
		width: 70px;
		height: 70px;
		border-radius: 0;
		object-fit: contain;
		filter: none;
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.4);
	}

	.auth-section {
		padding: 0.75rem 2rem 1.5rem;
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
