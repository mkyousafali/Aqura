<script>
	// Scheduler Component
	import SingleBillScheduling from '$lib/components/desktop-interface/master/finance/SingleBillScheduling.svelte';
	import MultipleBillScheduling from '$lib/components/desktop-interface/master/finance/MultipleBillScheduling.svelte';
	import RecurringExpenseScheduler from '$lib/components/desktop-interface/master/finance/RecurringExpenseScheduler.svelte';

	const tabs = [
		{ id: 'single', icon: '📄', label: 'Single Bill Scheduling' },
		{ id: 'multiple', icon: '📋', label: 'Multiple Bill Scheduling' },
		{ id: 'recurring', icon: '🔄', label: 'Recurring Expense Scheduler' }
	];

	let activeTab = 'single';
</script>

<div class="scheduler">
	<div class="scheduler-tabs">
		{#each tabs as tab}
			<button
				type="button"
				class="tab-btn"
				class:active={activeTab === tab.id}
				on:click={() => activeTab = tab.id}
			>
				<span class="tab-icon">{tab.icon}</span>
				<span class="tab-label">{tab.label}</span>
			</button>
		{/each}
	</div>

	<div class="scheduler-content">
		{#if activeTab === 'single'}
			<SingleBillScheduling />
		{:else if activeTab === 'multiple'}
			<MultipleBillScheduling />
		{:else if activeTab === 'recurring'}
			<RecurringExpenseScheduler />
		{/if}
	</div>
</div>

<style>
	.scheduler {
		height: 100%;
		padding: 1.25rem;
		background: #f1f5f9;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		overflow: hidden;
	}

	/* Glassmorphic tab bar */
	.scheduler-tabs {
		display: flex;
		gap: 0.4rem;
		padding: 0.4rem;
		margin-bottom: 1.1rem;
		background: rgba(255, 255, 255, 0.55);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(255, 255, 255, 0.7);
		border-radius: 16px;
		box-shadow: 0 8px 24px rgba(15, 23, 42, 0.07), inset 0 1px 0 rgba(255, 255, 255, 0.8);
		flex-shrink: 0;
	}

	.tab-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.85rem 0.75rem;
		background: transparent;
		border: none;
		border-radius: 12px;
		font-size: 0.85rem;
		font-weight: 600;
		color: #64748b;
		cursor: pointer;
		transition: all 0.25s ease;
		white-space: nowrap;
	}

	.tab-btn:hover {
		background: rgba(255, 255, 255, 0.55);
		color: #334155;
	}

	.tab-btn.active {
		background: rgba(255, 255, 255, 0.92);
		color: #4c1d95;
		box-shadow: 0 4px 14px rgba(139, 92, 246, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.9);
	}

	.tab-icon {
		font-size: 1.1rem;
		line-height: 1;
	}

	.tab-label {
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* Content area */
	.scheduler-content {
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		background: white;
		border-radius: 16px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		overflow: hidden;
	}

	.scheduler-content > :global(*) {
		flex: 1;
		min-height: 0;
	}

	@media (max-width: 640px) {
		.tab-label {
			font-size: 0.72rem;
		}

		.tab-btn {
			padding: 0.7rem 0.4rem;
			gap: 0.3rem;
		}
	}
</style>
