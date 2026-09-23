<script>
	import ApprovalCenter from '$lib/components/desktop-interface/master/finance/ApprovalCenter.svelte';
</script>

<svelte:head>
	<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
</svelte:head>

<div class="mobile-approval-page">
	<ApprovalCenter layoutMode="mobile" />
</div>

<style>
	.mobile-approval-page {
		box-sizing: border-box;
		width: 100%;
		min-width: 0;
		min-height: 100%;
		overflow-x: hidden;
	}
</style>
