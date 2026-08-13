<script lang="ts">
	import DailyTempSchedules from './DailyTempSchedules.svelte';

	// Set by the mobile interface wrapper. The desktop window is a fixed-height
	// box that scrolls internally; on a phone the page itself scrolls and the
	// layout collapses to one column.
	export let mobile = false;

	// LC Planner
	let activeTab: 'bank' | 'cash' = 'bank';

	const tabs = [
		{ id: 'bank' as const, label: 'Bank Payments', icon: '🏦' },
		{ id: 'cash' as const, label: 'Cash Payments', icon: '💵' }
	];
</script>

<div class="lc-planner" class:mobile>
	<!-- Glass tab bar -->
	<div class="tab-bar">
		{#each tabs as tab}
			<button
				type="button"
				class="tab-btn"
				class:active={activeTab === tab.id}
				on:click={() => (activeTab = tab.id)}
			>
				<span class="tab-icon">{tab.icon}</span>
				<span class="tab-label">{tab.label}</span>
			</button>
		{/each}
	</div>

	<!-- Content areas — one per button, each with its own schedules -->
	<div class="tab-content">
		{#if activeTab === 'bank'}
			<div class="panel">
				<DailyTempSchedules paymentMode="bank" {mobile} />
			</div>
		{:else if activeTab === 'cash'}
			<div class="panel">
				<DailyTempSchedules paymentMode="cash" {mobile} />
			</div>
		{/if}
	</div>
</div>

<style>
	.lc-planner {
		display: flex;
		flex-direction: column;
		height: 100%;
		width: 100%;
		gap: 0.75rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #f1f5f9 0%, #f8fafc 50%, #e9edf2 100%);
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		overflow: hidden;
		box-sizing: border-box;
	}

	/* ===== Glass tab bar ===== */
	.tab-bar {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		padding: 0.5rem;
		border-radius: 16px;
		background: rgba(255, 255, 255, 0.55);
		backdrop-filter: blur(20px) saturate(180%);
		-webkit-backdrop-filter: blur(20px) saturate(180%);
		border: 1px solid rgba(255, 255, 255, 0.7);
		box-shadow: 0 6px 24px rgba(100, 116, 139, 0.12), 0 1px 3px rgba(0, 0, 0, 0.05);
		flex-shrink: 0;
	}

	.tab-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.45rem;
		padding: 0.55rem 1.1rem;
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.6);
		background: rgba(255, 255, 255, 0.45);
		backdrop-filter: blur(12px) saturate(160%);
		-webkit-backdrop-filter: blur(12px) saturate(160%);
		color: #334155;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.tab-btn:hover {
		background: rgba(255, 255, 255, 0.75);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(100, 116, 139, 0.15);
	}

	.tab-btn.active {
		background: linear-gradient(135deg, rgba(71, 85, 105, 0.92) 0%, rgba(100, 116, 139, 0.92) 100%);
		border-color: rgba(255, 255, 255, 0.5);
		color: #fff;
		box-shadow: 0 6px 18px rgba(100, 116, 139, 0.35);
	}

	.tab-icon {
		font-size: 1rem;
		line-height: 1;
	}

	.tab-label {
		white-space: nowrap;
	}

	/* ===== Content areas ===== */
	.tab-content {
		flex: 1;
		min-height: 0;
		display: flex;
	}

	.panel {
		flex: 1;
		min-height: 0;
		overflow: auto;
		border-radius: 16px;
		background: rgba(255, 255, 255, 0.6);
		backdrop-filter: blur(20px) saturate(180%);
		-webkit-backdrop-filter: blur(20px) saturate(180%);
		border: 1px solid rgba(255, 255, 255, 0.7);
		box-shadow: 0 6px 24px rgba(100, 116, 139, 0.1), 0 1px 3px rgba(0, 0, 0, 0.04);
	}

	/* ===== Mobile ===== */
	/* The page scrolls instead of the panel, so the fixed height and the inner
	   scroll container are both released. */
	.lc-planner.mobile {
		height: auto;
		min-height: 100%;
		overflow: visible;
		padding: 0.5rem;
		gap: 0.5rem;
	}

	.lc-planner.mobile .tab-bar {
		padding: 0.35rem;
		border-radius: 12px;
	}

	.lc-planner.mobile .tab-btn {
		flex: 1;
		justify-content: center;
		min-width: 0;
		padding: 0.5rem 0.4rem;
		font-size: 0.78rem;
		border-radius: 10px;
	}

	.lc-planner.mobile .tab-content {
		display: block;
	}

	.lc-planner.mobile .panel {
		overflow: visible;
		border-radius: 12px;
	}
</style>
