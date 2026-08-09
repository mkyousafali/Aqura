<script>
	// Mobile wrapper for the desktop Request Generator — reuses the exact same
	// component/logic as the desktop Finance > Expense Manager > Request Generator.
	import RequestGenerator from '$lib/components/desktop-interface/master/finance/RequestGenerator.svelte';
</script>

<div class="mobile-request-generator">
	<RequestGenerator />
</div>

<style>
	.mobile-request-generator {
		min-height: 100%;
		background: #f8fafc;
	}

	/* The mobile header already shows "Request Generator" as the page title —
	   hide the component's own repeated title/subtitle so it isn't duplicated. */
	.mobile-request-generator :global(.header-main) {
		display: none;
	}

	/* The desktop component is built for a ~1400px window (2rem outer padding +
	   2rem card padding + a fixed two-column grid). Shrink all of that down so
	   the form actually uses the full mobile width instead of a narrow column. */
	.mobile-request-generator :global(.request-generator) {
		padding: 0.75rem !important;
	}

	.mobile-request-generator :global(.content) {
		padding: 1rem !important;
		min-height: auto !important;
	}

	.mobile-request-generator :global(.progress-steps) {
		margin-bottom: 1.5rem !important;
	}

	.mobile-request-generator :global(.step-number) {
		width: 36px !important;
		height: 36px !important;
		font-size: 14px !important;
	}

	.mobile-request-generator :global(.step-line) {
		width: 40px !important;
	}

	.mobile-request-generator :global(.step-title) {
		font-size: 1.15rem !important;
		margin-bottom: 1.25rem !important;
	}

	.mobile-request-generator :global(.form-row),
	.mobile-request-generator :global(.filter-row) {
		grid-template-columns: 1fr !important;
	}

	.mobile-request-generator :global(.amount-input-large) {
		font-size: 17px !important;
		padding: 12px !important;
	}

	.mobile-request-generator :global(.selection-table) {
		overflow-x: auto !important;
	}

	.mobile-request-generator :global(.selection-table table) {
		width: max-content !important;
		min-width: 100% !important;
	}
</style>
