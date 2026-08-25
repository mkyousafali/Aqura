<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	// Reuses the full desktop Shifts component (Regular / Day-Wise / Date-Wise
	// tabs). The `mobile` prop switches all three tabs from wide tables to
	// stacked cards; the wrapper below adapts the rest.
	import Shifts from '$lib/components/desktop-interface/master/hr/Shifts.svelte';
	import { localeData } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	let isAuthorized = false;
	let checkingAccess = true;

	// Mirrors the desktop sidebar's isButtonAllowed('SHIFTS'): master admins
	// always pass, everyone else needs the SHIFTS button permission.
	async function hasShiftsAccess(): Promise<boolean> {
		if ($currentUser?.isMasterAdmin) return true;
		if (!$currentUser?.id) return false;

		try {
			const { data: permissions, error } = await supabase
				.from('button_permissions')
				.select('button_code')
				.eq('user_id', $currentUser.id)
				.eq('is_enabled', true)
				.eq('button_code', 'SHIFTS');

			if (error) return false;

			return (permissions?.length ?? 0) > 0;
		} catch (err) {
			console.error('Error checking shifts permission:', err);
			return false;
		}
	}

	onMount(async () => {
		const allowed = await hasShiftsAccess();
		checkingAccess = false;

		if (!allowed) {
			goto('/mobile-interface');
			return;
		}

		isAuthorized = true;

		if (typeof document !== 'undefined') {
			document.title = 'Shifts - Aqura Mobile';
		}
	});
</script>

<svelte:head>
	<title>Shifts - Aqura Mobile</title>
	<meta name="description" content="Shift Management - Mobile Dashboard" />
</svelte:head>

<div class="mobile-shifts">
	{#if checkingAccess}
		<div class="access-denied"><p>{getTranslation('common.loading') || 'Loading…'}</p></div>
	{:else if isAuthorized}
		<div class="shifts-container">
			<Shifts mobile={true} />
		</div>
	{:else}
		<div class="access-denied">
			<div class="access-denied-icon">🚫</div>
			<h2>{getTranslation('common.accessDenied') || 'Access Denied'}</h2>
			<p>{getTranslation('common.insufficientPermissions') || 'You do not have permission to access this page.'}</p>
		</div>
	{/if}
</div>

<style>
	.mobile-shifts {
		min-height: 100%;
		background: #f8fafc;
	}

	.shifts-container {
		width: 100%;
		height: calc(100vh - 8rem);
	}

	/*
	 * Shifts.svelte assumes a fixed-height desktop window (h-full flex
	 * flex-col). On mobile the page itself scrolls (see main.mobile-content
	 * in the layout), so give the component a bounded height here instead —
	 * its own internal "Content Area" already scrolls independently, which
	 * keeps the tab bar/filters pinned while the cards scroll beneath them.
	 */

	.access-denied {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 60vh;
		padding: 2rem;
		text-align: center;
		color: #6b7280;
	}

	.access-denied-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
	}

	.access-denied h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #374151;
		margin: 0 0 0.5rem;
	}

	.access-denied p {
		margin: 0;
		font-size: 0.9rem;
	}
</style>
