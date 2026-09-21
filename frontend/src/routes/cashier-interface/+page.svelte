<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { beforeNavigate } from '$app/navigation';
	import CashierLogin from '$lib/components/cashier-interface/CashierLogin.svelte';
	import CashierInterface from '$lib/components/cashier-interface/CashierInterface.svelte';
	import { 
		initCashierSession, 
		setCashierAuth, 
		clearCashierSession,
		isCashierAuthenticated,
		startCashierSessionGuard,
		stopCashierSessionGuard,
		releaseWindowsCashierSession
	} from '$lib/stores/cashierAuth';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import ContactInfoOverlay from '$lib/components/common/ContactInfoOverlay.svelte';
	import LanguagePickerOverlay from '$lib/components/common/LanguagePickerOverlay.svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale, switchLocale, hasManualLocaleOverride } from '$lib/i18n';
	import { onNativeLogout } from '$lib/utils/nativeShell';
	import { get } from 'svelte/store';

	function syncAccountLanguage(user: any) {
		if (hasManualLocaleOverride()) return;
		if (user?.default_language && user.default_language !== get(currentLocale)) {
			switchLocale(user.default_language);
		}
	}

	let isLoggedIn = false;
	let cashierUser: any = null;
	let selectedBranch: any = null;
	let kickedNotice = '';
	let removeNativeLogout: (() => void) | null = null;

	onMount(() => {
		// The Windows Cashier app asks for a logout when its window is closed: reuse the normal
		// handleLogout() so the device binding is released and the session is cleared.
		removeNativeLogout = onNativeLogout(handleLogout);

		// Clear any desktop authentication when entering cashier interface
		currentUser.set(null);
		isAuthenticated.set(false);
		
		// Try to restore cashier session from sessionStorage
		const session = initCashierSession();
		
		if (session) {
			cashierUser = session.user;
			selectedBranch = session.branch;
			isLoggedIn = true;
			syncAccountLanguage(cashierUser);
			// Restored a Windows session — re-arm the guard
			startCashierSessionGuard(handleForcedLogout);
		}

	});

	onDestroy(() => {
		if (removeNativeLogout) removeNativeLogout();
		stopCashierSessionGuard();
	});

	// Leaving the cashier interface (back to interface selection, main login, etc.)
	// must end the session — otherwise it silently restores from sessionStorage
	// if the user returns to /cashier-interface without logging in again.
	//
	// beforeNavigate also fires for a plain page reload / tab close (type 'leave', since the
	// browser is about to unload the document) — that is NOT the user leaving the cashier
	// interface, it's how the language toggle applies its change, so `to` won't resolve to an
	// in-app route and must not be treated as "navigating away".
	beforeNavigate(({ to, type }) => {
		if (type === 'leave' || !to) return;
		const stayingInCashier = to.url.pathname.startsWith('/cashier-interface');
		if (isLoggedIn && !stayingInCashier) {
			releaseWindowsCashierSession();
			stopCashierSessionGuard();
			clearCashierSession();
			isLoggedIn = false;
			cashierUser = null;
			selectedBranch = null;
			currentUser.set(null);
			isAuthenticated.set(false);
		}
	});

	function handleForcedLogout() {
		kickedNotice = 'You have been signed out: this account was just used to log in on another Windows device.';
		clearCashierSession();
		isLoggedIn = false;
		cashierUser = null;
		selectedBranch = null;
		currentUser.set(null);
		isAuthenticated.set(false);
	}

	function handleLoginSuccess(event: CustomEvent) {
		cashierUser = event.detail.user;
		selectedBranch = event.detail.branch;
		const sessionToken = event.detail.sessionToken ?? null;
		isLoggedIn = true;
		kickedNotice = '';

		// Save to cashier auth stores and sessionStorage
		setCashierAuth(cashierUser, selectedBranch, sessionToken);
		syncAccountLanguage(cashierUser);

		// Start single-device guard (no-op outside the Windows app)
		startCashierSessionGuard(handleForcedLogout);
	}

	async function handleLogout() {
		// Best-effort: release the Windows binding so the slot is freed
		await releaseWindowsCashierSession();

		stopCashierSessionGuard();
		isLoggedIn = false;
		cashierUser = null;
		selectedBranch = null;

		// Clear cashier session
		clearCashierSession();

		// Also ensure desktop auth is cleared
		currentUser.set(null);
		isAuthenticated.set(false);
	}
</script>

<svelte:head>
	<title>Cashier Interface - Coupon System</title>
</svelte:head>

<div class="cashier-page">
	{#if !isLoggedIn}
		{#if kickedNotice}
			<div class="kicked-banner">
				<span>⚠️ {kickedNotice}</span>
				<button type="button" on:click={() => (kickedNotice = '')} aria-label="Dismiss">✕</button>
			</div>
		{/if}
		<CashierLogin on:loginSuccess={handleLoginSuccess} />
	{:else}
		<CashierInterface 
			user={cashierUser}
			branch={selectedBranch}
			on:logout={handleLogout}
		/>
		<!-- Language Picker - blocks once until a default language is chosen -->
		<LanguagePickerOverlay mode="cashier" employeeId={cashierUser?.id} />
		<!-- Contact Info Overlay - blocks until WhatsApp & email are provided -->
		<ContactInfoOverlay mode="cashier" employeeId={cashierUser?.id} />
	{/if}

</div>

<style>
	.cashier-page {
		width: 100%;
		min-height: 100vh;
	}

	.kicked-banner {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 200;
		background: #b91c1c;
		color: #fff;
		padding: 10px 16px;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		font-size: 14px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
	}
	.kicked-banner button {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.5);
		color: #fff;
		padding: 2px 10px;
		border-radius: 4px;
		cursor: pointer;
	}

	.break-qr-fixed {
		position: fixed;
		top: 12px;
		right: 12px;
		z-index: 100;
	}

	.break-qr-container {
		background: white;
		border-radius: 14px;
		padding: 10px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 5px;
		animation: qrPulse 10s ease-in-out infinite;
	}

	.break-qr-img {
		width: 140px;
		height: 140px;
		border-radius: 6px;
		display: block;
	}

	.break-qr-label {
		font-size: 0.6rem;
		color: #64748b;
		font-weight: 500;
		letter-spacing: 0.3px;
	}

	@keyframes qrPulse {
		0%, 100% { box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2); }
		50% { box-shadow: 0 4px 25px rgba(34, 197, 94, 0.35); }
	}
</style>
