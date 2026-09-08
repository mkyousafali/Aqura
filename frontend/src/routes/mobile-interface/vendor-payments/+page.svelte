<script>
	// Mobile wrapper for the desktop Vendor Payments report — reuses the exact
	// same component/logic as desktop Finance > Reports > Vendor Payments.
	import VendorPendingPayments from '$lib/components/desktop-interface/master/finance/reports/VendorPendingPayments.svelte';
</script>

<div class="mobile-vendor-payments">
	<VendorPendingPayments />
</div>

<style>
	.mobile-vendor-payments {
		height: 100%;
		background: #f8fafc;
	}
</style>
