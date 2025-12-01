<script>
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import Receiving from './operations/Receiving.svelte';

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Operations dashboard buttons
	const operationsButtons = [
		{
			id: 'receiving',
			title: 'Receiving',
			description: 'Manage incoming inventory and deliveries',
			icon: '📦',
			color: 'blue'
		}
	];

	function openOperationWindow(operation) {
		const windowId = generateWindowId(operation.id);
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		if (operation.id === 'receiving') {
			// Open Receiving component
			openWindow({
				id: windowId,
				title: `${operation.title} #${instanceNumber}`,
				component: Receiving,
				icon: operation.icon,
				size: { width: 1200, height: 800 },
				position: { 
					x: 50 + (Math.random() * 100),
					y: 50 + (Math.random() * 100) 
				},
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		} else {
			// Open placeholder for other operations
			openWindow({
				id: windowId,
				title: `${operation.title} #${instanceNumber}`,
				component: null, // Blank window for now
				icon: operation.icon,
				size: { width: 1000, height: 700 },
				position: { 
					x: 50 + (Math.random() * 100),
					y: 50 + (Math.random() * 100) 
				},
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true,
				content: `
					<div style="padding: 24px; height: 100%; background: white;">
						<h1 style="color: #1f2937; margin-bottom: 16px;">${operation.title}</h1>
						<p style="color: #6b7280; font-size: 16px;">${operation.description}</p>
						<div style="margin-top: 40px; padding: 40px; background: #f9fafb; border-radius: 12px; text-align: center; border: 2px dashed #d1d5db;">
							<h2 style="color: #374151; margin-bottom: 12px;">Coming Soon</h2>
							<p style="color: #6b7280;">This module will be implemented with full functionality.</p>
						</div>
					</div>
				`
			});
		}
	}
</script>

<!-- Operations Master Dashboard -->
<div class="operations-master">
	<div class="header">
		<div class="title-section">
			<h1 class="title">Operations Master Dashboard</h1>
			<p class="subtitle">Operations Management & Control Center</p>
		</div>
	</div>

	<!-- Dashboard Grid -->
	<div class="dashboard-grid">
		{#each operationsButtons as button}
			<div class="dashboard-card {button.color}" on:click={() => openOperationWindow(button)}>
				<div class="card-icon">
					<span class="icon">{button.icon}</span>
				</div>
				<div class="card-content">
					<h3 class="card-title">{button.title}</h3>
					<p class="card-description">{button.description}</p>
				</div>
				<div class="card-arrow">
					<span>→</span>
				</div>
			</div>
		{/each}
	</div>
</div>

<style>
	.operations-master {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.header {
		margin-bottom: 32px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.title-section {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.title {
		font-size: 28px;
		font-weight: 700;
		color: #1f2937;
		margin: 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 20px;
		margin-top: 24px;
	}

	.dashboard-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 16px;
		position: relative;
		overflow: hidden;
	}

	.dashboard-card:hover {
		border-color: #3b82f6;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
		transform: translateY(-2px);
	}

	.dashboard-card:active {
		transform: translateY(0);
	}

	.card-icon {
		width: 50px;
		height: 50px;
		border-radius: 10px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 24px;
		flex-shrink: 0;
	}

	.dashboard-card.blue .card-icon {
		background: linear-gradient(135deg, #3b82f6, #1d4ed8);
		color: white;
	}

	.dashboard-card.green .card-icon {
		background: linear-gradient(135deg, #10b981, #047857);
		color: white;
	}

	.dashboard-card.orange .card-icon {
		background: linear-gradient(135deg, #f59e0b, #d97706);
		color: white;
	}

	.dashboard-card.purple .card-icon {
		background: linear-gradient(135deg, #8b5cf6, #7c3aed);
		color: white;
	}

	.dashboard-card.red .card-icon {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: white;
	}

	.dashboard-card.teal .card-icon {
		background: linear-gradient(135deg, #14b8a6, #0f766e);
		color: white;
	}

	.card-content {
		flex: 1;
	}

	.card-title {
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 4px 0;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.4;
	}

	.card-arrow {
		font-size: 20px;
		color: #9ca3af;
		transition: all 0.2s ease;
		flex-shrink: 0;
	}

	.dashboard-card:hover .card-arrow {
		color: #3b82f6;
		transform: translateX(4px);
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.dashboard-grid {
			grid-template-columns: 1fr;
		}
		
		.dashboard-card {
			padding: 16px;
		}
	}
</style>