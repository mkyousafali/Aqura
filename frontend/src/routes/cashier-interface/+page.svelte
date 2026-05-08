<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
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
	import { supabase } from '$lib/utils/supabase';

	let isLoggedIn = false;
	let cashierUser: any = null;
	let selectedBranch: any = null;
	let kickedNotice = '';

	// Break Security QR Code
	let breakQrDataUrl = '';
	let breakQrInterval: ReturnType<typeof setInterval> | null = null;
	let QRCode: any = null;

	async function fetchBreakQr() {
		try {
			const { data, error } = await supabase.rpc('get_break_security_code');
			if (!error && data?.code && QRCode) {
				breakQrDataUrl = await QRCode.toDataURL(data.code, {
					width: 160,
					margin: 1,
					color: { dark: '#1e293b', light: '#ffffff' }
				});
			}
		} catch (e) {
			console.error('Break QR fetch error:', e);
		}
	}

	onMount(() => {
		// Clear any desktop authentication when entering cashier interface
		currentUser.set(null);
		isAuthenticated.set(false);
		
		// Try to restore cashier session from sessionStorage
		const session = initCashierSession();
		
		if (session) {
			cashierUser = session.user;
			selectedBranch = session.branch;
			isLoggedIn = true;
			// Restored a Windows session — re-arm the guard
			startCashierSessionGuard(handleForcedLogout);
		}

		// Initialize Break Security QR Code
		import('qrcode').then(mod => {
			QRCode = mod.default || mod;
			fetchBreakQr();
			breakQrInterval = setInterval(fetchBreakQr, 8000);
		}).catch(e => console.error('QRCode library load error:', e));
	});

	onDestroy(() => {
		if (breakQrInterval) clearInterval(breakQrInterval);
		stopCashierSessionGuard();
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
		<!-- Contact Info Overlay - blocks until WhatsApp & email are provided -->
		<ContactInfoOverlay mode="cashier" employeeId={cashierUser?.id} />
	{/if}

	<!-- Break Security QR Code - Fixed Top Right -->
	{#if breakQrDataUrl}
		<div class="break-qr-fixed">
			<div class="break-qr-container">
				<img src={breakQrDataUrl} alt="Break Security QR" class="break-qr-img" />
				<div class="break-qr-label">🔒 Security Code</div>
			</div>
		</div>
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
