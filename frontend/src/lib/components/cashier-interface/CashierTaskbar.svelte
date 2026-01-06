<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { _, t, switchLocale, currentLocale } from '$lib/i18n';
	import { notificationCounts, fetchNotificationCounts } from '$lib/stores/notifications';
	import { taskCounts, taskCountService } from '$lib/stores/taskCount';
	import { cashierUser } from '$lib/stores/cashierAuth';
	import { onMount, createEventDispatcher } from 'svelte';
	import NotificationCenter from '$lib/components/desktop-interface/master/communication/NotificationCenter.svelte';

	const dispatch = createEventDispatcher();

	export let user: any;
	export let branch: any;
	export let currentTime: string;

	// Cashier interface version
	let cashierVersion = 'AQ7';

	// Use cashier user from store for authentication context
	$: authenticatedUser = $cashierUser || user;

	// Subscribe to window list for taskbar buttons
	const windowList = windowManager.windowList;
	$: taskbarWindows = $windowList.filter(w => w.state !== 'minimized' && !w.isPoppedOut);

	// Subscribe to notification and task counts
	$: counts = $notificationCounts;
	$: taskCountData = $taskCounts;

	// Menu state
	let showMenu = false;

	function toggleMenu() {
		showMenu = !showMenu;
	}

	function closeMenu() {
		showMenu = false;
	}

	onMount(() => {
		// Fetch initial counts using cashier user
		if (authenticatedUser) {
			fetchNotificationCounts();
			// 🔴 DISABLED: Task count monitoring disabled
		console.warn('⚠️ Task count monitoring disabled');
		// taskCountService.initTaskCountMonitoring();
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
		closeMenu();
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
		closeMenu();
		const windowId = generateWindowId('my-tasks');

		import('$lib/components/desktop-interface/master/tasks/MyTasksView.svelte').then(({ default: MyTasksView }) => {
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

	function openPOSWindow() {
		closeMenu();
		const windowId = generateWindowId('pos');

		import('$lib/components/cashier-interface/POS.svelte').then(({ default: POS }) => {
			openWindow({
				id: windowId,
				title: 'POS',
				component: POS,
				props: { user, branch },
				icon: '🛒',
				size: { width: 1000, height: 700 },
				position: { x: 100, y: 50 },
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		}).catch(error => {
			console.error('Failed to load POS component:', error);
		});
	}

	function openCouponRedemption() {
		closeMenu();
		const windowId = generateWindowId('coupon-redemption');

		import('$lib/components/cashier-interface/CouponRedemption.svelte').then(({ default: CouponRedemption }) => {
			openWindow({
				id: windowId,
				title: t('coupon.redeemCoupon') || 'Redeem Coupon',
				component: CouponRedemption,
				props: { user, branch },
				icon: '🎁',
				size: { width: 700, height: 600 },
				position: { x: 100, y: 50 },
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		}).catch(error => {
			console.error('Failed to load CouponRedemption component:', error);
		});
	}

	function toggleLanguage() {
		closeMenu();
		const newLocale = $currentLocale === 'en' ? 'ar' : 'en';
		switchLocale(newLocale);
		// Reload the page to apply language changes throughout the app
		window.location.reload();
	}

	function handleLogout() {
		closeMenu();
		// Dispatch logout event to parent component
		dispatch('logout');
	}
</script>

<footer class="cashier-taskbar">
	<div class="taskbar-left">
		<!-- Menu Button -->
		<div class="menu-container">
			<button class="menu-btn" on:click={toggleMenu} title="Menu">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="3" y1="12" x2="21" y2="12"/>
					<line x1="3" y1="6" x2="21" y2="6"/>
					<line x1="3" y1="18" x2="21" y2="18"/>
				</svg>
			</button>

			{#if showMenu}
				<!-- svelte-ignore a11y-click-events-have-key-events -->
				<!-- svelte-ignore a11y-no-static-element-interactions -->
				<div class="menu-backdrop" on:click={closeMenu}></div>
				<div class="menu-dropdown">
					<!-- User Info -->
					<div class="menu-header">
						<div class="menu-user-info">
							<div class="menu-user-avatar">
								{user?.username?.charAt(0)?.toUpperCase() || '👤'}
							</div>
							<div class="menu-user-details">
								<div class="menu-user-name">{user?.username || 'User'}</div>
								<div class="menu-branch-name">{$currentLocale === 'ar' ? (branch?.name_ar || branch?.name_en) : (branch?.name_en || branch?.name_ar) || 'Branch'}</div>
							</div>
						</div>
						<div class="menu-version">{cashierVersion}</div>
					</div>
					<div class="menu-divider"></div>

					<!-- Main Actions -->
					<button class="menu-item" on:click={openPOSWindow}>
						<span class="menu-item-icon">🛒</span>
						<span class="menu-item-text">{$_('pos.title') || 'POS'}</span>
					</button>
					<button class="menu-item" on:click={openCouponRedemption}>
						<span class="menu-item-icon">🎁</span>
						<span class="menu-item-text">{$_('coupon.redeemCoupon') || 'Redeem Coupon'}</span>
					</button>
					<div class="menu-divider"></div>

					<!-- Notifications & Tasks -->
					<button class="menu-item" on:click={openTasksWindow}>
						<span class="menu-item-icon">📋</span>
						<span class="menu-item-text">{$_('nav.tasks') || 'My Tasks'}</span>
						{#if taskCountData.total > 0}
							<span class="menu-item-badge">{taskCountData.total}</span>
						{/if}
					</button>
					<button class="menu-item" on:click={openQuickNotifications}>
						<span class="menu-item-icon">🔔</span>
						<span class="menu-item-text">{$_('nav.notification') || 'Notifications'}</span>
						{#if counts.unread > 0}
							<span class="menu-item-badge">{counts.unread}</span>
						{/if}
					</button>
					<div class="menu-divider"></div>

					<!-- Language & Logout -->
					<button class="menu-item" on:click={toggleLanguage}>
						<span class="menu-item-icon">🌐</span>
						<span class="menu-item-text">{$currentLocale === 'ar' ? 'English' : 'العربية'}</span>
					</button>
					<button class="menu-item" on:click={handleLogout}>
						<span class="menu-item-icon">🚪</span>
						<span class="menu-item-text">{$_('auth.logout') || 'Logout'}</span>
					</button>
				</div>
			{/if}
		</div>
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
					title={$_('window.minimize') || 'Minimize'}
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
			<!-- POS -->
			<button 
				class="quick-btn pos-btn"
				on:click={openPOSWindow}
				title="POS"
			>
				<div class="quick-icon">🛒</div>
			</button>

			<!-- Redeem Coupon -->
			<button 
				class="quick-btn coupon-btn"
				on:click={openCouponRedemption}
				title={$_('coupon.redeemCoupon') || 'Redeem Coupon'}
			>
				<div class="quick-icon">🎁</div>
			</button>

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

	/* Menu Button and Dropdown */
	.menu-container {
		position: relative;
	}

	.menu-btn {
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 6px;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.menu-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
		transform: scale(1.05);
	}

	.menu-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 9998;
	}

	.menu-dropdown {
		position: absolute;
		bottom: 50px;
		left: 0;
		min-width: 220px;
		background: linear-gradient(to bottom, #374151, #1f2937);
		border: 1px solid #4b5563;
		border-radius: 8px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
		z-index: 9999;
		overflow: hidden;
		animation: slideUp 0.2s ease-out;
	}

	/* RTL Support for menu dropdown */
	:global([dir="rtl"]) .menu-dropdown {
		left: auto;
		right: 0;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.menu-item {
		width: 100%;
		padding: 0.75rem 1rem;
		background: transparent;
		border: none;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		font-size: 0.875rem;
		transition: all 0.2s;
		text-align: left;
	}

	/* RTL Support for menu items */
	:global([dir="rtl"]) .menu-item {
		text-align: right;
	}

	.menu-item:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.menu-item-icon {
		font-size: 1.25rem;
		width: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.menu-item-text {
		flex: 1;
	}

	.menu-item-badge {
		background: #ef4444;
		color: white;
		font-size: 0.65rem;
		font-weight: 600;
		padding: 2px 6px;
		border-radius: 10px;
		min-width: 18px;
		text-align: center;
	}

	.menu-divider {
		height: 1px;
		background: rgba(255, 255, 255, 0.1);
		margin: 0.25rem 0;
	}

	.menu-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		background: rgba(255, 255, 255, 0.05);
	}

	.menu-user-info {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.menu-user-avatar {
		width: 36px;
		height: 36px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.menu-user-details {
		display: flex;
		flex-direction: column;
		gap: 0.125rem;
	}

	.menu-user-name {
		color: white;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.menu-branch-name {
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.75rem;
	}

	.menu-version {
		background: rgba(59, 130, 246, 0.2);
		color: #60a5fa;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 600;
		border: 1px solid rgba(59, 130, 246, 0.3);
	}

	.logout-item {
		color: #fca5a5;
	}

	.logout-item:hover {
		background: rgba(239, 68, 68, 0.1);
		color: #ef4444;
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

	.quick-btn.pos-btn {
		background: linear-gradient(145deg, rgba(34, 197, 94, 0.3), rgba(22, 163, 74, 0.2));
		border-color: rgba(34, 197, 94, 0.4);
	}

	.quick-btn.pos-btn:hover {
		background: linear-gradient(145deg, rgba(34, 197, 94, 0.5), rgba(22, 163, 74, 0.4));
		border-color: rgba(34, 197, 94, 0.6);
	}

	.quick-btn.coupon-btn {
		background: linear-gradient(145deg, rgba(236, 72, 153, 0.3), rgba(219, 39, 119, 0.2));
		border-color: rgba(236, 72, 153, 0.4);
	}

	.quick-btn.coupon-btn:hover {
		background: linear-gradient(145deg, rgba(236, 72, 153, 0.5), rgba(219, 39, 119, 0.4));
		border-color: rgba(236, 72, 153, 0.6);
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
