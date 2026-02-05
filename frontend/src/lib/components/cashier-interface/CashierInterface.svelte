<script lang="ts">
	import { onMount, createEventDispatcher } from 'svelte';
	import { goto } from '$app/navigation';
	import { t, switchLocale, currentLocale } from '$lib/i18n';
	import WindowManager from '$lib/components/common/WindowManager.svelte';
	import CashierTaskbar from '$lib/components/cashier-interface/CashierTaskbar.svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CouponRedemption from '$lib/components/cashier-interface/CouponRedemption.svelte';
	import POS from '$lib/components/cashier-interface/POS.svelte';

	const dispatch = createEventDispatcher();

	export let user: any;
	export let branch: any;

	let currentTime = '';
	
	// Cashier interface version
	let cashierVersion = 'AQ9';

	function updateTime() {
		const locale = $currentLocale === 'ar' ? 'ar-SA' : 'en-US';
		currentTime = new Date().toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit' });
	}

	// Initial time update
	updateTime();

	// Update time every minute
	setInterval(() => {
		updateTime();
	}, 60000);

	// Update time when locale changes
	$: if ($currentLocale) {
		updateTime();
	}

	function openCouponRedemption() {
		const windowId = `coupon-redemption-${Date.now()}`;
		
		openWindow({
			id: windowId,
			title: t('coupon.redeemCoupon') || 'Redeem Coupon',
			component: CouponRedemption,
			props: { user, branch },
			icon: '🎁',
			size: { width: 700, height: 600 },
			position: { x: 100, y: 50 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openPOS() {
		const windowId = `pos-${Date.now()}`;
		
		openWindow({
			id: windowId,
			title: t('pos.title') || 'POS',
			component: POS,
			props: { user, branch },
			icon: '🛒',
			size: { width: 1000, height: 700 },
			position: { x: 100, y: 50 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function toggleLanguage() {
		const newLocale = $currentLocale === 'en' ? 'ar' : 'en';
		switchLocale(newLocale);
		// Reload the page to apply language changes throughout the app
		window.location.reload();
	}

	function handleLogout() {
		// Dispatch logout event to parent component
		dispatch('logout');
	}
</script>

<div class="cashier-desktop">
	<!-- Main Desktop Area -->
	<main class="cashier-main">
		<!-- Welcome Screen Background -->
		<div class="desktop-background">
			<div class="welcome-screen">
				<div class="app-branding">
					<div class="app-logo">
						<img src="/icons/Aqura logo.png" alt="Aqura Logo" />
					</div>
					<p class="app-tagline">{t('app.description') || 'AI-powered management system'}</p>
				</div>
			</div>
		</div>

		<!-- Window System -->
		<WindowManager />
	</main>

	<!-- Cashier Taskbar -->
	<CashierTaskbar 
		{user} 
		{branch}
		{currentTime}
		on:logout={handleLogout}
	/>
</div>

<style>
	.cashier-desktop {
		min-height: 100vh;
		background: #fafaf8;
		position: relative;
		display: flex;
		flex-direction: column;
	}

	/* Main Area */
	.cashier-main {
		flex: 1;
		height: calc(100vh - 56px); /* Taskbar height */
		position: relative;
		overflow: hidden;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	/* Ensure windows stay within main area and respect boundaries */
	.cashier-main :global(.window-manager) {
		left: 0 !important;
		width: 100% !important;
		height: calc(100vh - 56px) !important;
		bottom: 0 !important;
		max-height: calc(100vh - 56px) !important;
		overflow: hidden !important;
	}

	.cashier-main :global(.window.window-maximized),
	.cashier-main :global(.window.maximized) {
		left: 0 !important;
		top: 0 !important;
		width: 100% !important;
		height: calc(100vh - 56px) !important;
		max-height: calc(100vh - 56px) !important;
		border-radius: 0 !important;
	}

	.cashier-main :global(.window) {
		max-height: calc(100vh - 56px) !important;
		bottom: auto !important;
	}

	/* Prevent any window from going below the taskbar */
	.cashier-main :global(.window:not(.minimized)) {
		max-height: calc(100vh - 56px) !important;
	}

	/* Allow minimized windows to move freely anywhere */
	.cashier-main :global(.window.minimized) {
		max-height: none !important;
		max-width: none !important;
		bottom: auto !important;
	}

	.desktop-background {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		position: absolute;
		top: 0;
		left: 0;
		z-index: 1;
		padding: 2rem;
	}

	.welcome-screen {
		max-width: 800px;
		width: 100%;
	}

	.app-branding {
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0;
		padding: 3rem 2rem 2rem;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-radius: 16px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1), 0 8px 32px rgba(107, 114, 128, 0.08);
		border: 1px solid rgba(229, 231, 235, 0.8);
		position: relative;
		overflow: hidden;
	}

	.app-branding::after {
		content: '';
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, #F59E0B 0%, #FBBF24 100%);
	}

	.app-logo {
		width: 200px;
		height: 120px;
		margin: 0 auto 1.5rem;
		background: #FFFFFF;
		border: 6px solid #F59E0B;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 25px rgba(245, 158, 11, 0.5),
			0 0 50px rgba(245, 158, 11, 0.3),
			inset 0 0 15px rgba(245, 158, 11, 0.15);
		animation: ledGlow 2s ease-in-out infinite alternate;
		overflow: hidden;
	}

	@keyframes ledGlow {
		from {
			box-shadow: 
				0 0 25px rgba(245, 158, 11, 0.5),
				0 0 50px rgba(245, 158, 11, 0.3),
				inset 0 0 15px rgba(245, 158, 11, 0.15);
		}
		to {
			box-shadow: 
				0 0 40px rgba(245, 158, 11, 0.7),
				0 0 80px rgba(245, 158, 11, 0.4),
				inset 0 0 25px rgba(245, 158, 11, 0.25);
		}
	}

	.app-logo img {
		width: 840px;
		height: 450px;
		border-radius: 12px;
		object-fit: contain;
		margin-top: 20px;
	}

	.app-name {
		font-size: 2.5rem;
		font-weight: 700;
		color: white;
		margin: 0 0 0.5rem 0;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
		letter-spacing: -0.02em;
	}

	.app-tagline {
		font-size: 1.1rem;
		color: white;
		opacity: 0.9;
		font-weight: 300;
		margin: 0;
	}
</style>
