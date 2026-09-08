<script>
	// Mobile wrapper for the desktop Scheduler — reuses the exact same
	// component/logic as the desktop Finance > Expense Manager > Scheduler.
	import Scheduler from '$lib/components/desktop-interface/master/finance/Scheduler.svelte';
</script>

<div class="mobile-scheduler">
	<Scheduler />
</div>

<style>
	.mobile-scheduler {
		min-height: 100%;
		background: #f8fafc;
	}

	/* These overrides apply to Scheduler.svelte and everything it opens inline
	   (SingleBillScheduling, MultipleBillScheduling, RecurringExpenseScheduler) —
	   they all share the same class names, so one set of rules covers all four. */

	/* Desktop-window paddings (2rem outer + 2rem card) eat most of a phone screen */
	.mobile-scheduler :global(.scheduler),
	.mobile-scheduler :global(.single-bill-scheduling),
	.mobile-scheduler :global(.multiple-bill-scheduling),
	.mobile-scheduler :global(.recurring-expense-scheduler) {
		padding: 0.75rem !important;
	}

	.mobile-scheduler :global(.content) {
		padding: 1rem !important;
		min-height: auto !important;
	}

	.mobile-scheduler :global(.step-title) {
		font-size: 1.1rem !important;
		margin-bottom: 1rem !important;
	}

	/* Fixed 2-column form grids -> stack on mobile */
	.mobile-scheduler :global(.form-row),
	.mobile-scheduler :global(.filter-row) {
		grid-template-columns: 1fr !important;
	}

	.mobile-scheduler :global(.amount-input-large) {
		font-size: 17px !important;
		padding: 12px !important;
	}

	/* Existing-request date filter row (fixed 180px select + inline date range) */
	.mobile-scheduler :global(.filter-controls),
	.mobile-scheduler :global(.date-range-inputs) {
		flex-wrap: wrap !important;
	}

	.mobile-scheduler :global(.date-filter-select) {
		width: 100% !important;
	}

	/* Glassmorphic tab bar — shrink to fit 3 tabs comfortably on a phone width */
	.mobile-scheduler :global(.scheduler-tabs) {
		padding: 0.3rem !important;
		gap: 0.25rem !important;
	}

	.mobile-scheduler :global(.tab-btn) {
		flex-direction: column !important;
		gap: 0.2rem !important;
		padding: 0.6rem 0.3rem !important;
	}

	.mobile-scheduler :global(.tab-icon) {
		font-size: 1.2rem !important;
	}

	.mobile-scheduler :global(.tab-label) {
		font-size: 0.68rem !important;
		white-space: normal !important;
		line-height: 1.2 !important;
		text-align: center !important;
	}
</style>
