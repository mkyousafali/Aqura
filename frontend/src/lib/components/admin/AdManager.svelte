<script lang="ts">
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import HomePageScreenManager from './customer/HomePageScreenManager.svelte';

	// Generate unique window ID
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Open Home Page Screen Manager window
	function openHomePageScreenManager() {
		const windowId = generateWindowId('home-page-screen-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Home Page Screen Manager #${instanceNumber}`,
			component: HomePageScreenManager,
			icon: '🖼️',
			size: { width: 1400, height: 900 },
			position: { 
				x: 100 + (Math.random() * 50),
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="ad-manager-container">
	<div class="ad-manager-header">
		<h2>📢 Ad Manager</h2>
		<p class="subtitle">Manage customer app advertisements and media content</p>
	</div>
	
	<div class="ad-manager-content">
		<div class="dashboard-grid">
			<!-- Home Page Screen Manager Card -->
			<button class="manager-card" on:click={openHomePageScreenManager}>
				<div class="card-icon">🖼️</div>
				<div class="card-content">
					<h3>Home Page Screen Manager</h3>
					<p>Manage videos and images displayed on the customer app home page</p>
				</div>
				<div class="card-arrow">→</div>
			</button>

			<!-- Future features placeholder -->
			<div class="manager-card disabled">
				<div class="card-icon">🎯</div>
				<div class="card-content">
					<h3>Promotional Banners</h3>
					<p>Coming Soon...</p>
				</div>
			</div>

			<div class="manager-card disabled">
				<div class="card-icon">🎁</div>
				<div class="card-content">
					<h3>Special Offers</h3>
					<p>Coming Soon...</p>
				</div>
			</div>

			<div class="manager-card disabled">
				<div class="card-icon">📊</div>
				<div class="card-content">
					<h3>Ad Analytics</h3>
					<p>Coming Soon...</p>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.ad-manager-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
	}

	.ad-manager-header {
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e2e8f0;
	}

	.ad-manager-header h2 {
		margin: 0 0 0.5rem 0;
		color: #1e293b;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.subtitle {
		margin: 0;
		color: #64748b;
		font-size: 0.875rem;
	}

	.ad-manager-content {
		flex: 1;
		padding: 2rem;
		overflow-y: auto;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 1.5rem;
		max-width: 1200px;
	}

	.manager-card {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
		display: flex;
		align-items: center;
		gap: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
		text-align: left;
	}

	.manager-card:not(.disabled):hover {
		border-color: #3b82f6;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
		transform: translateY(-2px);
	}

	.manager-card:not(.disabled):active {
		transform: translateY(0);
	}

	.manager-card.disabled {
		opacity: 0.5;
		cursor: not-allowed;
		background: #f8fafc;
	}

	.card-icon {
		font-size: 2.5rem;
		flex-shrink: 0;
	}

	.card-content {
		flex: 1;
	}

	.card-content h3 {
		margin: 0 0 0.5rem 0;
		color: #1e293b;
		font-size: 1.125rem;
		font-weight: 600;
	}

	.card-content p {
		margin: 0;
		color: #64748b;
		font-size: 0.875rem;
		line-height: 1.4;
	}

	.card-arrow {
		font-size: 1.5rem;
		color: #3b82f6;
		flex-shrink: 0;
		transition: transform 0.2s ease;
	}

	.manager-card:not(.disabled):hover .card-arrow {
		transform: translateX(4px);
	}
</style>
