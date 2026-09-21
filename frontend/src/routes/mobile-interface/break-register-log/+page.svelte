<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale } from '$lib/i18n';
	import BreakLog from '$lib/components/common/BreakLog.svelte';
	import BreakTotalSummary from '$lib/components/common/BreakTotalSummary.svelte';

	let tab: 'logs' | 'total' = 'logs';
	$: rtl = $locale === 'ar';
	onMount(() => { if (!$currentUser?.id) goto('/mobile-interface'); });
</script>

<svelte:head><title>{rtl ? '??? ??????????' : 'Break Log'} - Aqura</title></svelte:head>
<div class="page" dir={rtl ? 'rtl' : 'ltr'}>
	<nav aria-label={rtl ? '??? ??????????' : 'Break views'}>
		<button class:active={tab === 'logs'} on:click={() => tab = 'logs'}>{rtl ? '??? ??????????' : 'Break Log'}</button>
		<button class:active={tab === 'total'} on:click={() => tab = 'total'}>{rtl ? '?????? ????????' : 'Total Summary'}</button>
	</nav>
	{#if tab === 'logs'}<BreakLog layout="mobile" />{:else}<BreakTotalSummary layout="mobile" />{/if}
</div>
<style>
	.page{height:100%;min-height:0;display:flex;flex-direction:column;overflow:hidden;background:#f8fafc}nav{display:flex;flex:none;gap:.4rem;padding:.4rem .65rem;background:#f8fafc;border-bottom:1px solid #e2e8f0}nav button{flex:1;min-height:40px;border:1px solid #cbd5e1;border-radius:.65rem;background:white;color:#475569;font-size:.85rem;font-weight:700}nav button.active{background:#059669;color:white;border-color:#059669}
</style>
