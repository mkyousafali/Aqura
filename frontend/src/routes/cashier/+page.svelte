<script lang="ts">
	import { onMount } from 'svelte';
	import CashierLogin from '$lib/components/admin/coupon/cashier/CashierLogin.svelte';
	import CashierInterface from '$lib/components/admin/coupon/cashier/CashierInterface.svelte';
	import { 
		initCashierSession, 
		setCashierAuth, 
		clearCashierSession,
		isCashierAuthenticated 
	} from '$lib/stores/cashierAuth';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';

	let isLoggedIn = false;
	let cashierUser: any = null;
	let selectedBranch: any = null;

	onMount(() => {
		// Clear any desktop authentication when entering cashier interface
		// This prevents conflicts between desktop and cashier auth
		currentUser.set(null);
		isAuthenticated.set(false);
		
		// Try to restore cashier session from sessionStorage
		const session = initCashierSession();
		
		if (session) {
			cashierUser = session.user;
			selectedBranch = session.branch;
			isLoggedIn = true;
		}
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
</div>

<style>
	.cashier-page {
		width: 100%;
		min-height: 100vh;
	}
</style>
