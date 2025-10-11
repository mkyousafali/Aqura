<script>
	import { windowManager } from '$lib/stores/windowManager';
	import StartReceiving from './receiving/StartReceiving.svelte';

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Dashboard placeholder cards
	const dashboardCards = [
		{
			id: 'card1',
			title: 'Placeholder 1',
			description: 'Dashboard section placeholder',
			icon: '📊',
			color: 'blue'
		},
		{
			id: 'card2',
			title: 'Placeholder 2',
			description: 'Dashboard section placeholder',
			icon: '📈',
			color: 'green'
		},
		{
			id: 'card3',
			title: 'Placeholder 3',
			description: 'Dashboard section placeholder',
			icon: '📉',
			color: 'purple'
		},
		{
			id: 'card4',
			title: 'Placeholder 4',
			description: 'Dashboard section placeholder',
			icon: '📋',
			color: 'orange'
		},
		{
			id: 'card5',
			title: 'Placeholder 5',
			description: 'Dashboard section placeholder',
			icon: '📄',
			color: 'teal'
		}
	];

	function openStartReceiving() {
		const windowId = generateWindowId('start-receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `Start Receiving #${instanceNumber}`,
			component: StartReceiving,
			icon: '📦',
			size: { width: 1000, height: 700 },
			position: { 
				x: 100 + (Math.random() * 100),
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<!-- Receiving Dashboard -->
<div class="receiving-window">
	<div class="header">
		<div class="title-section">
			<h1 class="title">📦 Receiving</h1>
			<p class="subtitle">Manage incoming inventory and deliveries</p>
		</div>
	</div>

	<!-- Top Dashboard Section with 5 Placeholders -->
	<div class="dashboard-section">
		<h2 class="section-title">Dashboard Overview</h2>
		<div class="dashboard-grid">
			{#each dashboardCards as card}
				<div class="dashboard-card {card.color}">
					<div class="card-icon">
						<span class="icon">{card.icon}</span>
					</div>
					<div class="card-content">
						<h3 class="card-title">{card.title}</h3>
						<p class="card-description">{card.description}</p>
					</div>
				</div>
			{/each}
		</div>
	</div>

	<!-- Start Receiving Button Section -->
	<div class="action-section">
		<button class="start-receiving-btn" on:click={openStartReceiving}>
			<span class="btn-icon">🚀</span>
			<span class="btn-text">Start Receiving</span>
		</button>
	</div>
</div>

<style>
	.receiving-window {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.header {
		margin-bottom: 32px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
		text-align: center;
	}

	.title-section .title {
		font-size: 32px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.title-section .subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.dashboard-section {
		margin-bottom: 40px;
	}

	.section-title {
		font-size: 24px;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 24px 0;
		text-align: center;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 20px;
		margin-bottom: 32px;
	}

	.dashboard-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 16px;
		padding: 24px 20px;
		text-align: center;
		transition: all 0.3s ease;
		position: relative;
		overflow: hidden;
	}

	.dashboard-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.dashboard-card.blue:hover {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
	}

	.dashboard-card.green:hover {
		border-color: #10b981;
		background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
	}

	.dashboard-card.purple:hover {
		border-color: #8b5cf6;
		background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%);
	}

	.dashboard-card.orange:hover {
		border-color: #f59e0b;
		background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%);
	}

	.dashboard-card.teal:hover {
		border-color: #14b8a6;
		background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
	}

	.card-icon {
		width: 64px;
		height: 64px;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 16px auto;
		flex-shrink: 0;
	}

	.dashboard-card.blue .card-icon {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
	}

	.dashboard-card.green .card-icon {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.dashboard-card.purple .card-icon {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
	}

	.dashboard-card.orange .card-icon {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
	}

	.dashboard-card.teal .card-icon {
		background: linear-gradient(135deg, #14b8a6 0%, #0f766e 100%);
	}

	.card-icon .icon {
		font-size: 28px;
		color: white;
	}

	.card-title {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.5;
	}

	.action-section {
		text-align: center;
		padding: 40px 0;
	}

	.start-receiving-btn {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		color: white;
		border: none;
		border-radius: 16px;
		padding: 20px 40px;
		font-size: 18px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: inline-flex;
		align-items: center;
		gap: 12px;
		box-shadow: 0 10px 25px rgba(5, 150, 105, 0.3);
		min-width: 200px;
	}

	.start-receiving-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 15px 35px rgba(5, 150, 105, 0.4);
		background: linear-gradient(135deg, #047857 0%, #065f46 100%);
	}

	.start-receiving-btn:active {
		transform: translateY(0);
	}

	.btn-icon {
		font-size: 20px;
	}

	.btn-text {
		font-size: 18px;
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.dashboard-grid {
			grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
			gap: 16px;
		}
		
		.dashboard-card {
			padding: 20px 16px;
		}

		.card-icon {
			width: 48px;
			height: 48px;
		}

		.card-icon .icon {
			font-size: 24px;
		}

		.start-receiving-btn {
			padding: 16px 32px;
			font-size: 16px;
		}
	}
</style>