<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { t } from '$lib/i18n';
	import { notificationCounts, fetchNotificationCounts } from '$lib/stores/notifications';
	import { taskCounts, taskCountService } from '$lib/stores/taskCount';
	import { cashierUser } from '$lib/stores/cashierAuth';
	import { onMount } from 'svelte';
	import NotificationCenter from '$lib/components/admin/communication/NotificationCenter.svelte';

	export let user: any;
	export let branch: any;
	export let currentTime: string;

	// Use cashier user from store for authentication context
	$: authenticatedUser = $cashierUser || user;

	// Subscribe to window list for taskbar buttons
	const windowList = windowManager.windowList;
	$: taskbarWindows = $windowList.filter(w => w.state !== 'minimized' && !w.isPoppedOut);

	// Subscribe to notification and task counts
	$: counts = $notificationCounts;
	$: taskCountData = $taskCounts;

	onMount(() => {
		// Fetch initial counts using cashier user
		if (authenticatedUser) {
			fetchNotificationCounts();
			taskCountService.initTaskCountMonitoring();
		}
		
		// Refresh counts periodically
		const notificationInterval = setInterval(() => {
			if ($cashierUser) {
				fetchNotificationCounts();
			}
		}, 30000);
		
		return () => {
			if (notificationInterval) clearInterval(notificationInterval);
		};
	});

	function activateWindow(windowId: string) {
		windowManager.activateWindow(windowId);
	}

	function minimizeWindow(windowId: string) {
		windowManager.minimizeWindow(windowId);
	}

	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openQuickNotifications() {
		const windowId = generateWindowId('quick-notifications');
		
		openWindow({
			id: windowId,
			title: 'My Notifications',
			component: NotificationCenter,
			props: {
				// Pass user context if needed
			},
			icon: '🔔',
			size: { width: 800, height: 500 },
			position: { x: 150, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Refresh count after opening
		setTimeout(fetchNotificationCounts, 1000);
	}

	function openTasksWindow() {
		const windowId = generateWindowId('my-tasks');
		
		import('$lib/components/admin/tasks/MyTasksView.svelte').then(({ default: MyTasksView }) => {
			openWindow({
				id: windowId,
				title: `My Tasks (${taskCountData.total})`,
				component: MyTasksView,
				props: {
					// Pass user context if needed
				},
				icon: '📋',
				size: { width: 1200, height: 700 },
				position: { x: 100, y: 50 },
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		}).catch(error => {
			console.error('Failed to load MyTasksView component:', error);
		});

		// Refresh task counts after opening
		setTimeout(() => taskCountService.refreshTaskCounts(), 1000);
	}
</script>

<footer class="cashier-taskbar">
	<div class="taskbar-left">
	</div>

	<div class="taskbar-center">
		{#each taskbarWindows as window (window.id)}
			<button
				class="window-button"
				class:active={window.isActive}
				on:click={() => activateWindow(window.id)}
				title={window.title}
			>
				<span class="window-icon">{window.icon || '📄'}</span>
				<span class="window-title">{window.title}</span>
				<span
					class="minimize-btn"
					role="button"
					tabindex="0"
					on:click|stopPropagation={() => minimizeWindow(window.id)}
					on:keydown={(e) => e.key === 'Enter' && minimizeWindow(window.id)}
					title={t('window.minimize') || 'Minimize'}
				>
					<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="5" y1="12" x2="19" y2="12"/>
					</svg>
				</span>
			</button>
		{/each}
	</div>

	<div class="taskbar-right">
		<!-- Quick Access Buttons -->
		<div class="quick-access">
			<!-- My Tasks -->
			<button 
				class="quick-btn tasks-btn"
				on:click={openTasksWindow}
				title="My Tasks ({taskCountData.total} total{taskCountData.overdue > 0 ? `, ${taskCountData.overdue} overdue` : ''})"
			>
				<div class="quick-icon">📋</div>
				{#if taskCountData.total > 0}
					<div class="quick-badge {taskCountData.overdue > 0 ? 'overdue' : ''}">{taskCountData.total > 99 ? '99+' : taskCountData.total}</div>
				{/if}
			</button>
			
			<!-- Quick Notifications -->
			<button 
				class="quick-btn notifications-btn"
				on:click={openQuickNotifications}
				title="My Notifications ({counts.unread} unread)"
			>
				<div class="quick-icon">🔔</div>
				{#if counts.unread > 0}
					<div class="quick-badge">{counts.unread > 99 ? '99+' : counts.unread}</div>
				{/if}
			</button>
		</div>
		
		<div class="taskbar-time">
			{currentTime}
		</div>
	</div>
</footer>

<style>
	.cashier-taskbar {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		height: 56px;
		background: linear-gradient(to bottom, #374151, #1f2937);
		border-top: 1px solid #4b5563;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 1rem;
		z-index: 9999;
		box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.2);
		pointer-events: all;
	}

	.taskbar-left {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.taskbar-toggle {
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
		border: none;
		border-radius: 6px;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.taskbar-toggle:hover {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
	}

	.taskbar-title {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: white;
		font-weight: 600;
	}

	.taskbar-icon {
		font-size: 1.25rem;
	}

	.taskbar-center {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: flex-start;
		gap: 0.5rem;
		padding: 0 0;
		overflow-x: auto;
		overflow-y: hidden;
	}

	.taskbar-center::-webkit-scrollbar {
		height: 4px;
	}

	.taskbar-center::-webkit-scrollbar-track {
		background: rgba(255, 255, 255, 0.05);
	}

	.taskbar-center::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.2);
		border-radius: 2px;
	}

	.window-button {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 6px;
		color: white;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 120px;
		max-width: 200px;
		position: relative;
	}

	.window-button:hover {
		background: rgba(255, 255, 255, 0.15);
		border-color: rgba(255, 255, 255, 0.25);
		transform: translateY(-1px);
	}

	.window-button.active {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
		box-shadow: 0 0 8px rgba(255, 255, 255, 0.2);
	}

	.window-icon {
		font-size: 1rem;
		flex-shrink: 0;
	}

	.window-title {
		flex: 1;
		font-size: 0.875rem;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.minimize-btn {
		width: 20px;
		height: 20px;
		background: rgba(255, 255, 255, 0.1);
		border: none;
		border-radius: 4px;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
		flex-shrink: 0;
		opacity: 0;
	}

	.window-button:hover .minimize-btn {
		opacity: 1;
	}

	.minimize-btn:hover {
		background: rgba(255, 255, 255, 0.25);
		transform: scale(1.1);
	}

	.taskbar-right {
		display: flex;
		align-items: center;
		gap: 1rem;
		min-width: 250px;
		justify-content: flex-end;
	}

	.taskbar-user {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.user-badge,
	.branch-badge {
		padding: 0.375rem 0.75rem;
		background: rgba(255, 255, 255, 0.15);
		border-radius: 6px;
		color: white;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.taskbar-time {
		padding: 0.375rem 0.75rem;
		background: rgba(255, 255, 255, 0.1);
		border-radius: 6px;
		color: white;
		font-size: 0.875rem;
		font-weight: 500;
		font-family: 'Courier New', monospace;
	}

	/* Quick Access Buttons */
	.quick-access {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0 0.5rem;
	}

	.quick-btn {
		position: relative;
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 6px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.quick-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-2px);
	}

	.quick-icon {
		font-size: 1.25rem;
	}

	.quick-badge {
		position: absolute;
		top: -4px;
		right: -4px;
		background: #ef4444;
		color: white;
		font-size: 0.65rem;
		font-weight: 600;
		padding: 2px 5px;
		border-radius: 10px;
		min-width: 18px;
		text-align: center;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
		animation: pulse 2s infinite;
	}

	.quick-badge.overdue {
		background: #dc2626;
		animation: urgent-pulse 1s infinite;
	}

	@keyframes pulse {
		0%, 100% {
			transform: scale(1);
		}
		50% {
			transform: scale(1.1);
		}
	}

	@keyframes urgent-pulse {
		0%, 100% {
			transform: scale(1);
			box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
		}
		50% {
			transform: scale(1.15);
			box-shadow: 0 2px 8px rgba(220, 38, 38, 0.6);
		}
	}

	@media (max-width: 768px) {
		.taskbar-user {
			display: none;
		}

		.taskbar-left,
		.taskbar-right {
			min-width: auto;
		}

		.taskbar-center {
			max-width: none;
		}
		
		.quick-access {
			padding: 0 0.25rem;
		}
	}
</style>
