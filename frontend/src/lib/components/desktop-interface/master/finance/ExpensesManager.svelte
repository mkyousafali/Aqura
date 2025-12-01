<script>
	// Expenses Manager Component
	// This will manage all expenses tracking and reporting
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import RequestGenerator from '$lib/components/desktop-interface/master/finance/RequestGenerator.svelte';
	import CategoryManager from '$lib/components/desktop-interface/master/finance/CategoryManager.svelte';
	import Scheduler from '$lib/components/desktop-interface/master/finance/Scheduler.svelte';
	import ApprovalCenter from '$lib/components/desktop-interface/master/finance/ApprovalCenter.svelte';
	import RequestsManager from '$lib/components/desktop-interface/master/finance/RequestsManager.svelte';

	function openRequestGenerator() {
		openWindow({
			id: `request-generator-${Date.now()}`,
			title: 'Request Generator',
			component: RequestGenerator,
			props: {},
			icon: '📝',
			size: { width: 1000, height: 700 },
			minSize: { width: 600, height: 400 },
			position: { x: 100, y: 100 }
		});
	}

	function openCategoryManager() {
		openWindow({
			id: `category-manager-${Date.now()}`,
			title: 'Category Manager',
			component: CategoryManager,
			props: {},
			icon: '📁',
			size: { width: 1000, height: 700 },
			minSize: { width: 600, height: 400 },
			position: { x: 120, y: 120 }
		});
	}

	function openScheduler() {
		openWindow({
			id: `scheduler-${Date.now()}`,
			title: 'Scheduler',
			component: Scheduler,
			props: {},
			icon: '📅',
			size: { width: 1000, height: 700 },
			minSize: { width: 600, height: 400 },
			position: { x: 140, y: 140 }
		});
	}

	function openApprovalCenter() {
		openWindow({
			id: `approval-center-${Date.now()}`,
			title: 'Approval Center',
			component: ApprovalCenter,
			props: {},
			icon: '✅',
			size: { width: 1000, height: 700 },
			minSize: { width: 600, height: 400 },
			position: { x: 160, y: 160 }
		});
	}

	function openRequestsManager() {
		openWindow({
			id: `requests-manager-${Date.now()}`,
			title: 'Requests',
			component: RequestsManager,
			props: {},
			icon: '📋',
			size: { width: 1200, height: 800 },
			minSize: { width: 800, height: 600 },
			position: { x: 180, y: 180 }
		});
	}
</script>

<div class="expenses-manager">
	<div class="header">
		<h1 class="title">💸 Expenses Manager</h1>
		<p class="subtitle">Track and manage all business expenses</p>
	</div>

	<div class="content">
		<!-- Status Cards Section -->
		<div class="status-section">
			<div class="status-grid">
				<div class="status-card clickable" on:click={openRequestGenerator}>
					<div class="card-icon">📝</div>
					<div class="card-content">
						<h3>Request Generator</h3>
						<p class="click-hint">Click to open</p>
					</div>
				</div>
				
				<div class="status-card clickable" on:click={openCategoryManager}>
					<div class="card-icon">📁</div>
					<div class="card-content">
						<h3>Category Manager</h3>
						<p class="click-hint">Click to open</p>
					</div>
				</div>
				
				<div class="status-card clickable" on:click={openScheduler}>
					<div class="card-icon">📅</div>
					<div class="card-content">
						<h3>Scheduler</h3>
						<p class="click-hint">Click to open</p>
					</div>
				</div>
				
				<div class="status-card clickable" on:click={openApprovalCenter}>
					<div class="card-icon">✅</div>
					<div class="card-content">
						<h3>Approval Center</h3>
						<p class="click-hint">Click to open</p>
					</div>
				</div>
				
				<div class="status-card clickable" on:click={openRequestsManager}>
					<div class="card-icon">📋</div>
					<div class="card-content">
						<h3>Requests</h3>
						<p class="click-hint">Click to open</p>
					</div>
				</div>
				
				<div class="status-card">
					<p class="status-value">6</p>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.expenses-manager {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.header {
		margin-bottom: 2rem;
		text-align: center;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
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
		display: flex;
		flex-direction: column;
	}

	.status-section {
		margin-bottom: 32px;
	}

	.status-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 24px;
	}

	.status-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 16px;
		padding: 32px 24px;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		transition: all 0.3s ease;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
		min-height: 200px;
		justify-content: center;
	}

	.status-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
		border-color: #d1d5db;
	}

	.status-card.clickable {
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.status-card.clickable:hover {
		background: #f0f9ff;
		border-color: #3b82f6;
	}

	.card-icon {
		font-size: 32px;
		background: #3b82f6;
		color: white;
		width: 56px;
		height: 56px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		margin-bottom: 12px;
	}

	.card-content {
		text-align: center;
	}

	.card-content h3 {
		margin: 0 0 8px 0;
		font-size: 16px;
		font-weight: 600;
		color: #1f2937;
	}

	.click-hint {
		margin: 0;
		font-size: 12px;
		color: #9ca3af;
		font-style: italic;
	}

	.status-value {
		font-size: 42px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
		line-height: 1;
	}
</style>
