<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { notificationCounts, fetchNotificationCounts, refreshNotificationCounts } from '$lib/stores/notifications';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import NotificationCenter from '$lib/components/desktop-interface/master/communication/NotificationCenter.svelte';
	import AdminReadStatusModal from '$lib/components/desktop-interface/master/communication/AdminReadStatusModal.svelte';

	// Subscribe to notification counts store
	$: counts = $notificationCounts;

	// Current user for role-based access
	$: userRole = $currentUser?.role || 'Position-based';
	$: isMasterAdmin = userRole === 'Master Admin';

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	onMount(() => {
		// Initial fetch
		fetchNotificationCounts();
		// Refresh counts every 30 seconds
		const interval = setInterval(fetchNotificationCounts, 30000);
		return () => clearInterval(interval);
	});

	function openNotificationCenter() {
		const windowId = generateWindowId('notification-center');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Notification Center #${instanceNumber}`,
			component: NotificationCenter,
			icon: '🔔',
			size: { width: 900, height: 600 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Refresh counts after opening (in case user reads notifications)
		setTimeout(refreshNotificationCounts, 1000);
	}

	function openAdminReadStatus() {
		const windowId = `admin-read-status-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		
		openWindow({
			id: windowId,
			title: 'Admin: Read Status Per User',
			component: AdminReadStatusModal,
			icon: '👥',
			size: { width: 800, height: 600 },
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

<div class="communication-center">
	<!-- Header -->
	<div class="header">
		<h1 class="title">Communication Center</h1>
	</div>

	<div class="dashboard-content">
		<div class="dashboard-grid">
			<!-- Notification Center Card -->
			<div class="dashboard-card primary">
				<div class="card-header">
					<div class="card-icon">🔔</div>
					<div class="card-title">
						<h3>Notification Center</h3>
						<p>Manage alerts and notifications</p>
					</div>
				</div>
				<div class="card-content">
					<div class="stats">
						<div class="stat-item">
							<span class="stat-number">{counts.loading ? '...' : counts.unread}</span>
							<span class="stat-label">Unread</span>
						</div>
						<div class="stat-item">
							<span class="stat-number">{counts.loading ? '...' : counts.total}</span>
							<span class="stat-label">Total</span>
						</div>
					</div>
				</div>
				<div class="card-footer">
					<button class="action-btn primary" on:click={openNotificationCenter}>
						Open Notification Center
					</button>
					{#if isMasterAdmin}
						<button class="action-btn secondary" on:click={openAdminReadStatus}>
							<span class="btn-icon">👥</span>
							Read Status
						</button>
					{/if}
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.communication-center {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		overflow: hidden;
		padding: 20px;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
		margin-bottom: 20px;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.dashboard-content {
		flex: 1;
		overflow-y: auto;
	}

	.dashboard-grid {
		display: flex;
		justify-content: center;
		max-width: 1200px;
		margin: 0 auto;
	}

	.dashboard-card {
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		transition: all 0.3s ease;
		border: 1px solid #e5e7eb;
		width: 400px;
		max-width: 100%;
	}

	.dashboard-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
	}

	.dashboard-card.primary {
		border-color: #10b981;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.15);
	}

	.dashboard-card.primary:hover {
		box-shadow: 0 4px 16px rgba(16, 185, 129, 0.25);
	}

	.card-header {
		display: flex;
		align-items: flex-start;
		gap: 15px;
		padding: 20px 20px 15px 20px;
		border-bottom: 1px solid #f1f5f9;
	}

	.card-icon {
		font-size: 32px;
		width: 50px;
		height: 50px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
		border-radius: 8px;
		flex-shrink: 0;
	}

	.primary .card-icon {
		background: #10b981;
		color: white;
	}

	.card-title h3 {
		margin: 0 0 5px 0;
		font-size: 18px;
		font-weight: 600;
		color: #1e293b;
	}

	.card-title p {
		margin: 0;
		font-size: 14px;
		color: #64748b;
		line-height: 1.4;
	}

	.card-content {
		padding: 0 20px 15px 20px;
	}

	.stats {
		display: flex;
		gap: 30px;
	}

	.stat-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
	}

	.stat-number {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
	}

	.stat-label {
		font-size: 12px;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		font-weight: 500;
	}

	.card-footer {
		padding: 15px 20px 20px 20px;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.action-btn {
		width: 100%;
		padding: 12px 20px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		background: #f9fafb;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.action-btn:hover {
		background: #f3f4f6;
		transform: translateY(-1px);
	}

	.action-btn.primary {
		background: #10b981;
		color: white;
		border: none;
	}

	.action-btn.primary:hover {
		background: #059669;
	}

	.action-btn.secondary {
		background: #3b82f6;
		color: white;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
	}

	.action-btn.secondary:hover {
		background: #2563eb;
	}

	.btn-icon {
		font-size: 14px;
	}

	.action-btn:active {
		transform: translateY(0);
	}

	/* Scrollbar styling */
	.dashboard-content::-webkit-scrollbar {
		width: 8px;
	}

	.dashboard-content::-webkit-scrollbar-track {
		background: transparent;
	}

	.dashboard-content::-webkit-scrollbar-thumb {
		background: rgba(0, 0, 0, 0.1);
		border-radius: 4px;
	}

	.dashboard-content::-webkit-scrollbar-thumb:hover {
		background: rgba(0, 0, 0, 0.2);
	}
</style>