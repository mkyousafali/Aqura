<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	// Reuses the desktop LC Planner (Bank / Cash payment schedules). The wrapper
	// below adapts it to the mobile viewport.
	import LCPlanner from '$lib/components/desktop-interface/master/finance/LCPlanner.svelte';
	import { localeData } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath; // Return key path if translation not found
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	let isAuthorized = false;
	let checkingAccess = true;

	// Mirrors the desktop sidebar's isButtonAllowed('LC_PLANNER'): master admins
	// always pass, everyone else needs the LC_PLANNER button permission. The
	// mobile menu item uses the same rule, so the button and the page agree.
	async function hasLCPlannerAccess(): Promise<boolean> {
		if ($currentUser?.isMasterAdmin) return true;
		if (!$currentUser?.id) return false;

		try {
			const { data: permissions, error } = await supabase
				.from('button_permissions')
				.select('button_id')
				.eq('user_id', $currentUser.id)
				.eq('is_enabled', true);

			if (error || !permissions?.length) return false;

			const { data: buttons, error: btnError } = await supabase
				.from('sidebar_buttons')
				.select('button_code')
				.in('id', permissions.map(p => p.button_id));

			if (btnError || !buttons) return false;

			return buttons.some(b => b.button_code === 'LC_PLANNER');
		} catch (err) {
			console.error('Error checking LC planner permission:', err);
			return false;
		}
	}

	onMount(async () => {
		const allowed = await hasLCPlannerAccess();
		checkingAccess = false;

		if (!allowed) {
			// Redirect to mobile home if not authorized
			goto('/mobile-interface');
			return;
		}

		isAuthorized = true;

		if (typeof document !== 'undefined') {
			document.title = `${getTranslation('nav.lcPlanner')} - Aqura Mobile`;
		}
	});
</script>

<svelte:head>
	<title>{getTranslation('nav.lcPlanner')} - Aqura Mobile</title>
	<meta name="description" content="LC Planner - Mobile Dashboard" />
</svelte:head>

<div class="mobile-lc-planner">
	{#if checkingAccess}
		<div class="access-denied"><p>{getTranslation('common.loading') || 'Loading…'}</p></div>
	{:else if isAuthorized}
		<div class="planner-container">
			<LCPlanner mobile={true} />
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
	.mobile-lc-planner {
		min-height: 100%;
		background: #f8f9fa;
		padding-bottom: 0.5rem;
	}

	.planner-container {
		padding: 0;
		width: 100%;
	}

	.access-denied {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 50vh;
		text-align: center;
		padding: 1rem;
	}

	.access-denied-icon {
		font-size: 2rem;
		margin-bottom: 0.5rem;
	}

	.access-denied h2 {
		color: #dc2626;
		font-size: 1rem;
		margin-bottom: 0.3rem;
	}

	.access-denied p {
		color: #6b7280;
		font-size: 0.76rem;
	}
</style>
