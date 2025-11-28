<script lang="ts">
	import { onMount, createEventDispatcher } from 'svelte';
	import { goto } from '$app/navigation';
	import { t, switchLocale, currentLocale } from '$lib/i18n';
	import WindowManager from '$lib/components/WindowManager.svelte';
	import CashierTaskbar from './CashierTaskbar.svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CouponRedemption from './CouponRedemption.svelte';

	const dispatch = createEventDispatcher();

	export let user: any;
	export let branch: any;

	let currentTime = '';

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
	<!-- Cashier Sidebar -->
	<aside class="cashier-sidebar">
		<div class="user-info">
			<div class="user-avatar">
				{user.username?.charAt(0)?.toUpperCase() || '👤'}
			</div>
			<div class="user-details">
				<div class="user-name">{user.username || 'Cashier'}</div>
				<div class="branch-name">{branch.name_en} • {branch.name_ar}</div>
			</div>
		</div>

		<nav class="sidebar-menu">
			<button class="menu-item" on:click={openCouponRedemption}>
				<span class="menu-icon">🎁</span>
				<span class="menu-label">{t('coupon.redeemCoupon') || 'Redeem Coupon'}</span>
			</button>
		</nav>

		<div class="sidebar-footer">
			<button class="lang-btn" on:click={toggleLanguage}>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="12" cy="12" r="10"/>
					<line x1="2" y1="12" x2="22" y2="12"/>
					<path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
				</svg>
				{$currentLocale === 'en' ? 'العربية' : 'English'}
			</button>
			<button class="logout-btn" on:click={handleLogout}>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
					<polyline points="16 17 21 12 16 7"/>
					<line x1="21" y1="12" x2="9" y2="12"/>
				</svg>
				{t('auth.logout') || 'Logout'}
			</button>
		</div>
	</aside>

	<!-- Main Desktop Area -->
	<main class="cashier-main" style="margin-left: 195px">
		<!-- Welcome Screen Background -->
		<div class="desktop-background">
			<div class="welcome-screen">
				<div class="app-branding">
					<div class="app-logo">
						<img src="/icons/logo.png" alt="Aqura Logo" />
					</div>
					<h1 class="app-name">Aqura</h1>
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

	/* Sidebar */
	.cashier-sidebar {
		position: fixed;
		left: 0;
		top: 0;
		bottom: 56px; /* Taskbar height */
		width: 195px;
		background: linear-gradient(180deg, #22c55e 0%, #16a34a 100%);
		border-right: 1px solid #16a34a;
		display: flex;
		flex-direction: column;
		transition: transform 0.3s ease;
		z-index: 100;
		box-shadow: 2px 0 8px rgba(0, 0, 0, 0.1);
	}

	.cashier-sidebar.hidden {
		transform: translateX(-100%);
	}

	.sidebar-header {
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.logo-section {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.logo-icon {
		font-size: 2rem;
	}

	.logo-text {
		font-size: 1.25rem;
		font-weight: 700;
		color: #111827;
	}

	.user-info {
		padding: 1.125rem;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		background: rgba(255, 255, 255, 0.15);
		border-bottom: 1px solid rgba(255, 255, 255, 0.2);
	}

	.user-avatar {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		background: white;
		color: #16a34a;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.94rem;
		font-weight: 600;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
	}

	.user-details {
		flex: 1;
	}

	.user-name {
		font-weight: 600;
		color: white;
		margin-bottom: 0.25rem;
		font-size: 0.75rem;
	}

	.branch-name {
		font-size: 0.66rem;
		color: rgba(255, 255, 255, 0.9);
	}

	.sidebar-menu {
		flex: 1;
		padding: 0.75rem;
		overflow-y: auto;
	}

	.menu-item {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 0.56rem;
		padding: 0.66rem 0.75rem;
		background: rgba(255, 255, 255, 0.2);
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 500;
		color: white;
		cursor: pointer;
		transition: all 0.2s;
		margin-bottom: 0.38rem;
	}

	.menu-item:hover {
		background: white;
		color: #16a34a;
		border-color: white;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(255, 255, 255, 0.3);
	}

	.menu-icon {
		font-size: 1.13rem;
	}

	.menu-label {
		flex: 1;
		text-align: left;
	}

	.sidebar-footer {
		padding: 0.75rem;
		border-top: 1px solid rgba(255, 255, 255, 0.2);
		display: flex;
		flex-direction: column;
		gap: 0.38rem;
	}

	.lang-btn {
		width: 100%;
		padding: 0.66rem 0.75rem;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.38rem;
		transition: all 0.2s;
	}

	.lang-btn:hover {
		background: white;
		color: #16a34a;
		border-color: white;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(255, 255, 255, 0.3);
	}

	.logout-btn {
		width: 100%;
		padding: 0.66rem 0.75rem;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.38rem;
		transition: all 0.2s;
	}

	.logout-btn:hover {
		background: #dc2626;
		color: white;
		border-color: #dc2626;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
	}

	/* Main Area */
	.cashier-main {
		flex: 1;
		height: calc(100vh - 56px); /* Taskbar height */
		position: relative;
		overflow: hidden;
		transition: margin-left 0.3s ease;
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
		width: 140px;
		height: 80px;
		border-radius: 12px;
		object-fit: contain;
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

	@media (max-width: 768px) {
		.cashier-sidebar {
			width: 100%;
		}

		.cashier-main {
			margin-left: 0 !important;
		}
	}
</style>
