<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	// Reuses the full desktop Offer Product Editor (offer template picker +
	// product selection). The `mobile` prop switches its product list from a
	// wide table to a stacked card list; the wrapper below adapts the rest.
	import OfferTemplates from '$lib/components/desktop-interface/marketing/flyer/OfferTemplates.svelte';
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

	// Mirrors the desktop sidebar's isButtonAllowed('OFFER_PRODUCT_EDITOR'):
	// master admins always pass, everyone else needs the OFFER_PRODUCT_EDITOR
	// button permission. The mobile menu card uses the same rule, so the
	// button and this page agree.
	async function hasOfferProductEditorAccess(): Promise<boolean> {
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

			return buttons.some(b => b.button_code === 'OFFER_PRODUCT_EDITOR');
		} catch (err) {
			console.error('Error checking offer product editor permission:', err);
			return false;
		}
	}

	onMount(async () => {
		const allowed = await hasOfferProductEditorAccess();
		checkingAccess = false;

		if (!allowed) {
			goto('/mobile-interface');
			return;
		}

		isAuthorized = true;

		if (typeof document !== 'undefined') {
			document.title = 'Offer Selector - Aqura Mobile';
		}
	});
</script>

<svelte:head>
	<title>Offer Selector - Aqura Mobile</title>
	<meta name="description" content="Offer Product Editor - Mobile Dashboard" />
</svelte:head>

<div class="mobile-offer-selector">
	{#if checkingAccess}
		<div class="access-denied"><p>{getTranslation('common.loading') || 'Loading…'}</p></div>
	{:else if isAuthorized}
		<div class="editor-container">
			<OfferTemplates mobile={true} />
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
	.mobile-offer-selector {
		min-height: 100%;
		background: #f8f9fa;
	}

	.editor-container {
		width: 100%;
	}

	/*
	 * Mobile adaptation for the desktop Offer Product Editor.
	 * The component assumes a fixed-height desktop window: it fills 100%
	 * height and manages its own inner scrolling. On mobile the page itself
	 * scrolls (see main.mobile-content in the layout), so the inner scroll
	 * container is released and the sticky header sticks to the page instead.
	 */
	.editor-container :global(.h-full) {
		height: auto;
		min-height: 0;
	}

	.editor-container :global(.flex-1.overflow-auto) {
		overflow: visible;
	}

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
