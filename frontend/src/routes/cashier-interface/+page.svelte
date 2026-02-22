<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import CashierLogin from '$lib/components/cashier-interface/CashierLogin.svelte';
	import CashierInterface from '$lib/components/cashier-interface/CashierInterface.svelte';
	import { 
		initCashierSession, 
		setCashierAuth, 
		clearCashierSession,
		isCashierAuthenticated 
	} from '$lib/stores/cashierAuth';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	let isLoggedIn = false;
	let cashierUser: any = null;
	let selectedBranch: any = null;

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
	});

	function handleLoginSuccess(event: CustomEvent) {
		cashierUser = event.detail.user;
		selectedBranch = event.detail.branch;
		isLoggedIn = true;
		
		// Save to cashier auth stores and sessionStorage
		setCashierAuth(cashierUser, selectedBranch);
	}

	function handleLogout() {
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
		<CashierLogin on:loginSuccess={handleLoginSuccess} />
	{:else}
		<CashierInterface 
			user={cashierUser}
			branch={selectedBranch}
			on:logout={handleLogout}
		/>
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
