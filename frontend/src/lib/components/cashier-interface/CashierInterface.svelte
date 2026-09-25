<script lang="ts">
	import { onMount, createEventDispatcher } from 'svelte';
	import { goto } from '$app/navigation';
	import { t, switchLocaleManually, currentLocale } from '$lib/i18n';
	import WindowManager from '$lib/components/common/WindowManager.svelte';
	import CashierTaskbar from '$lib/components/cashier-interface/CashierTaskbar.svelte';
	import DancingCharacter from '$lib/components/desktop-interface/common/DancingCharacter.svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CouponRedemption from '$lib/components/cashier-interface/CouponRedemption.svelte';
	import POS from '$lib/components/cashier-interface/POS.svelte';
	import { updateAvailable, triggerUpdate } from '$lib/stores/appUpdate';
	import { iconUrlMap } from '$lib/stores/iconStore';

	async function handleUpdateClick() {
		const fn = $triggerUpdate;
		if (fn) await fn();
	}

	const dispatch = createEventDispatcher();

	export let user: any;
	export let branch: any;

	let currentTime = '';

	// Cashier interface version
	let cashierVersion = 'AQ12';

	// name_en/name_ar are the raw hr_employee_master values (locale-independent) — pick between
	// them reactively so the name follows language switches, rather than trusting user.full_name/
	// .name/.employeeName which were baked in once at login time from whichever locale was active
	// then (see CashierLogin.svelte).
	$: displayUserName = ($currentLocale === 'ar'
		? (user?.name_ar || user?.name_en)
		: (user?.name_en || user?.name_ar))
		|| user?.full_name || user?.name || user?.employeeName || user?.username || '';

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
		switchLocaleManually(newLocale);
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
					{#if $updateAvailable}
						<button class="cashier-update-badge update-available" on:click={handleUpdateClick} title={$currentLocale === 'ar' ? 'تحديث متاح - انقر للتحديث' : 'Update Available - Click to update'}>
							🔄 {$currentLocale === 'ar' ? 'تحديث متاح' : 'Update Available'}
						</button>
					{:else}
						<span class="cashier-update-badge up-to-date">
							✅ {$currentLocale === 'ar' ? 'محدّث' : 'Up to Date'}
						</span>
					{/if}
					<div class="app-logo">
						<img src={$iconUrlMap['aqura-logo'] || '/icons/Aqura logo.png'} alt="Aqura Logo" />
					</div>
					<div class="aqura-brand-logo" aria-label="Aqura">
						<img src="/icons/Aqura logo.png" alt="Original Aqura Logo" />
					</div>
					<span class="version-badge">{cashierVersion}</span>
				</div>
				<div class="logout-container">
					<span class="current-user-name">{displayUserName}</span>
					<span class="user-bar-divider"></span>
					<button class="panel-logout-btn" on:click={handleLogout} title={t('auth.logout') || 'Logout'} aria-label={t('auth.logout') || 'Logout'}>
						<svg class="panel-logout-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round">
							<path d="M12 3v9" />
							<path d="M18.36 6.64a9 9 0 1 1-12.73 0" />
						</svg>
					</button>
				</div>
			</div>
		</div>

		<!-- Window System -->
		<WindowManager />
	</main>

	<!-- Dancing Character -->
	<div class="cashier-dancing-character">
		<DancingCharacter />
	</div>

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
		background:
			radial-gradient(ellipse 48% 38% at 72% 12%, rgba(52, 221, 237, 0.22), transparent 67%),
			radial-gradient(ellipse 36% 54% at 8% 58%, rgba(18, 184, 211, 0.17), transparent 72%),
			radial-gradient(ellipse 46% 42% at 88% 82%, rgba(15, 130, 181, 0.24), transparent 70%),
			linear-gradient(155deg, #051f3f 0%, #053a66 52%, #045b7d 100%);
		position: relative;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.cashier-desktop::before,
	.cashier-desktop::after {
		content: '';
		position: fixed;
		width: 760px;
		height: 760px;
		border-radius: 50%;
		background: radial-gradient(circle, rgba(78, 230, 240, 0.22), rgba(14, 145, 184, 0.10) 46%, transparent 71%);
		filter: blur(6px);
		pointer-events: none;
		z-index: 0;
	}

	.cashier-desktop::before { animation: cashierAuroraOne 24s ease-in-out infinite; }
	.cashier-desktop::after { width: 920px; height: 920px; animation: cashierAuroraTwo 31s ease-in-out infinite; }

	@keyframes cashierAuroraOne {
		0% { left: 12%; top: -34%; opacity: 0; transform: scale(.78); }
		12% { opacity: .82; }
		34% { left: 42%; top: 4%; opacity: .48; transform: scale(1.04); }
		49% { opacity: 0; }
		62% { left: -8%; top: 36%; opacity: 0; transform: scale(.72); }
		74% { opacity: .72; }
		100% { left: 12%; top: -34%; opacity: 0; transform: scale(.78); }
	}

	@keyframes cashierAuroraTwo {
		0% { right: -14%; bottom: -42%; opacity: .65; transform: scale(1); }
		20% { opacity: 0; }
		36% { right: 38%; bottom: 8%; opacity: 0; transform: scale(.72); }
		49% { opacity: .7; }
		68% { right: 4%; bottom: 28%; opacity: .36; transform: scale(.94); }
		80% { opacity: 0; }
		100% { right: -14%; bottom: -42%; opacity: .65; transform: scale(1); }
	}

	.cashier-dancing-character {
		position: fixed;
		bottom: 56px;
		left: 16px;
		z-index: 100;
		pointer-events: auto;
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
		padding: 0;
	}

	.welcome-screen {
		width: 0;
		height: 0;
	}

	.app-branding {
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0;
		padding: 0;
		background: transparent;
		border-radius: 0;
		box-shadow: none;
		position: relative;
		overflow: visible;
	}

	.app-branding::after { display: none; }

	.logout-container {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		position: fixed;
		left: auto;
		top: 20px;
		right: 308px;
		bottom: auto;
		z-index: 100;
		margin: 0;
		height: 44px;
		box-sizing: border-box;
		padding: 0 10px 0 16px;
		background: #F5FAFC;
		border: 6px solid #0798AE;
		border-radius: 10px;
		box-shadow: 0 0 8px rgba(7, 152, 174, .18), 0 4px 12px rgba(3, 76, 140, .08);
		width: fit-content;
	}

	.current-user-name {
		font-size: 0.82rem;
		font-weight: 700;
		color: #0B2B50;
		white-space: nowrap;
	}

	.user-bar-divider {
		width: 1px;
		height: 1.25rem;
		background: rgba(7, 152, 174, 0.28);
	}

	.panel-logout-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 1.55rem;
		height: 1.55rem;
		padding: 0;
		background: #dc2626;
		color: #ffffff;
		border: none;
		border-radius: 50%;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(220, 38, 38, 0.25);
		transition: background 0.15s ease, transform 0.12s ease;
	}
	.panel-logout-btn:hover {
		background: #b91c1c;
		transform: translateY(-1px);
	}
	.panel-logout-btn:active {
		transform: translateY(0);
	}
	.panel-logout-icon {
		width: 0.9rem;
		height: 0.9rem;
	}

	.app-logo {
		position: fixed;
		right: 20px;
		bottom: 74px;
		z-index: 100;
		width: 200px;
		height: 120px;
		margin: 0;
		background: #F5FAFC;
		border: 6px solid #0798AE;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 0 8px rgba(7, 152, 174, .18), 0 4px 12px rgba(3, 76, 140, .08);
		animation: cashierLogoOne 16s ease-in-out infinite;
		overflow: hidden;
	}

	.aqura-brand-logo {
		position: fixed;
		right: 20px;
		bottom: 74px;
		z-index: 100;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 200px;
		height: 120px;
		box-sizing: border-box;
		background: #F5FAFC;
		border: 6px solid #0798AE;
		border-radius: 20px;
		box-shadow: 0 0 8px rgba(7, 152, 174, .18), 0 4px 12px rgba(3, 76, 140, .08);
		overflow: hidden;
		animation: cashierLogoTwo 16s ease-in-out infinite;
	}

	.aqura-brand-logo img { width: 100%; height: 100%; object-fit: contain; }

	@keyframes cashierLogoOne {
		0%, 42% { opacity: 1; filter: blur(0); visibility: visible; }
		50%, 92% { opacity: 0; filter: blur(5px); visibility: hidden; }
		100% { opacity: 1; filter: blur(0); visibility: visible; }
	}

	@keyframes cashierLogoTwo {
		0%, 42% { opacity: 0; filter: blur(5px); visibility: hidden; }
		50%, 92% { opacity: 1; filter: blur(0); visibility: visible; }
		100% { opacity: 0; filter: blur(5px); visibility: hidden; }
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

	.version-badge {
		position: fixed;
		top: 20px;
		right: 20px;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		height: 44px;
		min-width: 132px;
		box-sizing: border-box;
		background: #F5FAFC;
		color: #0B2B50;
		border: 6px solid #0798AE;
		border-radius: 8px;
		padding: 0 14px;
		font-size: 0.7rem;
		font-weight: 500;
		z-index: 2;
		letter-spacing: 0.5px;
	}

	.cashier-update-badge {
		position: fixed;
		top: 20px;
		right: 164px;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		height: 44px;
		min-width: 132px;
		box-sizing: border-box;
		border-radius: 8px;
		padding: 0 14px;
		font-size: 0.7rem;
		font-weight: 600;
		transition: all 0.3s;
		z-index: 2;
		letter-spacing: 0.5px;
		border: 6px solid #0798AE;
		background: #F5FAFC;
		color: #0B2B50;
		box-shadow: 0 0 8px rgba(7, 152, 174, .18), 0 4px 12px rgba(3, 76, 140, .08);
	}

	.cashier-update-badge.update-available {
		background: rgba(34, 197, 94, 0.25);
		color: #bbf7d0;
		border: 1px solid rgba(34, 197, 94, 0.5);
		cursor: pointer;
		animation: pulse-update 2s ease-in-out infinite;
	}

	.cashier-update-badge.update-available:hover {
		background: rgba(34, 197, 94, 0.45);
		transform: scale(1.05);
	}

	.cashier-update-badge.up-to-date {
		background: #F5FAFC;
		color: #0B2B50;
		border: 6px solid #0798AE;
		cursor: default;
	}

	.cashier-update-badge.update-available {
		background: #F5FAFC;
		color: #0B2B50;
		border: 6px solid #0798AE;
	}

	.version-badge {
		box-shadow: 0 0 8px rgba(7, 152, 174, .18), 0 4px 12px rgba(3, 76, 140, .08);
	}

	@media (prefers-reduced-motion: reduce) {
		.cashier-desktop::before,
		.cashier-desktop::after,
		.app-logo,
		.aqura-brand-logo { animation: none; }
		.aqura-brand-logo { opacity: 0; visibility: hidden; }
	}

	@keyframes pulse-update {
		0%, 100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.4); }
		50% { box-shadow: 0 0 8px 2px rgba(34, 197, 94, 0.3); }
	}
</style>
