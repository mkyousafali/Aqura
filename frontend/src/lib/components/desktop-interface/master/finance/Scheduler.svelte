<script>
	// Scheduler Component
	import SingleBillScheduling from '$lib/components/desktop-interface/master/finance/SingleBillScheduling.svelte';
	import MultipleBillScheduling from '$lib/components/desktop-interface/master/finance/MultipleBillScheduling.svelte';
	import RecurringExpenseScheduler from '$lib/components/desktop-interface/master/finance/RecurringExpenseScheduler.svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	
	let activeView = 'home'; // 'home', 'single', 'multiple', 'recurring'
	
	function handleSingleBillScheduling() {
		activeView = 'single';
	}
	
	function handleMultipleBillScheduling() {
		activeView = 'multiple';
	}
	
	function handleRecurringExpenseScheduler() {
		console.log('Recurring Expense Scheduler clicked');
		// Open new window for Recurring Expense Scheduler
		openWindow({
			id: `recurring-expense-scheduler-${Date.now()}`,
			title: 'Recurring Expense Scheduler',
			component: RecurringExpenseScheduler,
			icon: '🔄',
			size: { width: 1000, height: 700 },
			minSize: { width: 600, height: 400 },
			position: { x: 160, y: 160 }
		});
	}
	
	function backToHome() {
		activeView = 'home';
	}
</script>

{#if activeView === 'home'}
<div class="scheduler">
	<div class="content">
		<div class="scheduling-options">
			<!-- Single Bill Scheduling -->
			<button class="schedule-card" on:click={handleSingleBillScheduling}>
				<div class="card-icon">📄</div>
				<h3 class="card-title">Single Bill Scheduling</h3>
				<p class="card-description">Schedule a one-time payment for a single bill</p>
			</button>

			<!-- Multiple Bill Scheduling -->
			<button class="schedule-card" on:click={handleMultipleBillScheduling}>
				<div class="card-icon">📋</div>
				<h3 class="card-title">Multiple Bill Scheduling</h3>
				<p class="card-description">Schedule payments for multiple bills at once</p>
			</button>

		<!-- Recurring Expense Scheduler -->
		<button class="schedule-card" on:click={handleRecurringExpenseScheduler}>
			<div class="card-icon">🔄</div>
			<h3 class="card-title">Recurring Expense Scheduler</h3>
			<p class="card-description">Schedule recurring expense payments</p>
		</button>
		</div>
	</div>
</div>
{:else if activeView === 'single'}
	<div class="view-container">
		<button class="btn-back" on:click={backToHome}>← Back to Scheduler</button>
		<SingleBillScheduling />
	</div>
{:else if activeView === 'multiple'}
	<div class="view-container">
		<button class="btn-back" on:click={backToHome}>← Back to Scheduler</button>
		<MultipleBillScheduling />
	</div>
{/if}

<style>
	.scheduler {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.view-container {
		height: 100%;
		display: flex;
		flex-direction: column;
	}

	.btn-back {
		margin: 1rem 1rem 0 1rem;
		padding: 0.75rem 1.5rem;
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		color: #475569;
		cursor: pointer;
		transition: all 0.2s ease;
		align-self: flex-start;
	}

	.btn-back:hover {
		background: #f8fafc;
		border-color: #cbd5e1;
		transform: translateX(-4px);
	}

	.content {
		flex: 1;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 1.5rem;
	}

	.scheduling-options {
		display: flex;
		gap: 0.75rem;
		flex-wrap: wrap;
		margin-bottom: 2rem;
	}

	.schedule-card {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		padding: 0.5rem 0.75rem;
		min-width: 90px;
		text-align: center;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
		flex: 0 0 auto;
	}

	.schedule-card:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
		border-color: #667eea;
	}

	.schedule-card:active {
		transform: translateY(0);
	}

	.schedule-card:nth-child(1):hover {
		border-color: #667eea;
		background: linear-gradient(135deg, rgba(102, 126, 234, 0.02) 0%, rgba(118, 75, 162, 0.02) 100%);
	}

	.schedule-card:nth-child(2):hover {
		border-color: #f093fb;
		background: linear-gradient(135deg, rgba(240, 147, 251, 0.02) 0%, rgba(245, 87, 108, 0.02) 100%);
	}

	.schedule-card:nth-child(3):hover {
		border-color: #4facfe;
		background: linear-gradient(135deg, rgba(79, 172, 254, 0.02) 0%, rgba(0, 242, 254, 0.02) 100%);
	}

	.card-icon {
		font-size: 1rem;
		margin-bottom: 0.25rem;
		opacity: 0.9;
	}

	.card-title {
		font-size: 0.7rem;
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 0.25rem;
	}

	.card-description {
		font-size: 0.6rem;
		color: #64748b;
		margin: 0 0 0.5rem 0;
		line-height: 1.3;
	}

	.card-badge {
		display: inline-block;
		background: #f1f5f9;
		border: 1px solid #e2e8f0;
		color: #64748b;
		padding: 0.15rem 0.4rem;
		border-radius: 6px;
		font-size: 0.55rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}
</style>
