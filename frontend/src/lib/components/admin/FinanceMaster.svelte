<script>
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import PaymentManager from './vendor/PaymentManager.svelte';
	import ManualScheduling from './finance/ManualScheduling.svelte';

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Finance Master dashboard buttons
	const financeButtons = [
		{
			id: 'payment-manager',
			title: 'Payment Manager',
			description: 'Manage vendor payments and financial records',
			icon: '💳',
			color: 'purple'
		},
		{
			id: 'manual-scheduling',
			title: 'Manual Scheduling',
			description: 'Schedule payments manually for unscheduled records',
			icon: '📅',
			color: 'blue'
		}
	];

	function openFinanceWindow(financeOperation) {
		const windowId = generateWindowId(financeOperation.id);
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		if (financeOperation.id === 'payment-manager') {
			// Open Payment Manager component
			openWindow({
				id: windowId,
				title: `Payment Manager #${instanceNumber}`,
				component: PaymentManager,
				icon: financeOperation.icon,
				size: { width: 1200, height: 800 },
				position: { 
					x: 120 + (Math.random() * 100),
					y: 120 + (Math.random() * 100) 
				},
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		} else if (financeOperation.id === 'manual-scheduling') {
			// Open Manual Scheduling component
			openWindow({
				id: windowId,
				title: `Manual Scheduling #${instanceNumber}`,
				component: ManualScheduling,
				icon: financeOperation.icon,
				size: { width: 1200, height: 800 },
				position: { 
					x: 140 + (Math.random() * 100),
					y: 140 + (Math.random() * 100) 
				},
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		}
	}
</script>

<div class="finance-master">
	<div class="header">
		<h1 class="title">💰 Finance Master</h1>
		<p class="subtitle">Financial management and configuration</p>
	</div>

	<div class="content">
		<div class="dashboard-grid">
			{#each financeButtons as financeOperation}
				<div class="finance-card {financeOperation.color}" on:click={() => openFinanceWindow(financeOperation)}>
					<div class="card-icon">{financeOperation.icon}</div>
					<div class="card-content">
						<h3 class="card-title">{financeOperation.title}</h3>
						<p class="card-description">{financeOperation.description}</p>
					</div>
					<div class="card-arrow">→</div>
				</div>
			{/each}
		</div>
	</div>
</div>

<style>
	.finance-master {
		padding: 2rem;
		background: #f8fafc;
		height: 100vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.header {
		margin-bottom: 2rem;
		text-align: center;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
	}

	.content {
		flex: 1;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 2rem;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
		max-width: 1200px;
		margin: 0 auto;
	}

	.finance-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		gap: 1rem;
		position: relative;
		overflow: hidden;
	}

	.finance-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 12px 24px rgba(0, 0, 0, 0.15);
	}

	.finance-card.purple {
		border-color: #8b5cf6;
		background: linear-gradient(135deg, #f3f4f6 0%, #faf5ff 100%);
	}

	.finance-card.purple:hover {
		border-color: #7c3aed;
		background: linear-gradient(135deg, #faf5ff 0%, #f3e8ff 100%);
	}

	.finance-card.blue {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #f3f4f6 0%, #eff6ff 100%);
	}

	.finance-card.blue:hover {
		border-color: #2563eb;
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
	}

	.card-icon {
		font-size: 2.5rem;
		flex-shrink: 0;
	}

	.card-content {
		flex: 1;
	}

	.card-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 0.5rem 0;
	}

	.card-description {
		color: #64748b;
		font-size: 0.9rem;
		margin: 0;
		line-height: 1.4;
	}

	.card-arrow {
		font-size: 1.5rem;
		color: #64748b;
		flex-shrink: 0;
		transition: transform 0.3s ease;
	}

	.finance-card:hover .card-arrow {
		transform: translateX(4px);
		color: #1e293b;
	}
</style>