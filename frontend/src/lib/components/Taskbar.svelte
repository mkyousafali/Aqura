<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { auth } from '$lib/stores/auth';
	import { currentLocale, switchLocale, getAvailableLocales } from '$lib/i18n';
	import { t } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { notificationCounts, fetchNotificationCounts, refreshNotificationCounts } from '$lib/stores/notifications';
	import NotificationCenter from './admin/communication/NotificationCenter.svelte';

	// Subscribe to taskbar items and auth state
	$: taskbarItems = windowManager.taskbarItems;
	$: activeWindow = windowManager.activeWindow;
	$: currentUser = $auth?.user;

	// Subscribe to notification counts store
	$: counts = $notificationCounts;

	// Language data
	$: availableLocales = getAvailableLocales();
	$: currentLang = $currentLocale;

	// Taskbar expansion state
	let isExpanded = false;
	let showUserMenu = false;
	let showLogoutConfirm = false;

	// Show current time and date
	let currentTime = '';
	let currentDate = '';
	let timeInterval: NodeJS.Timeout;

	onMount(() => {
		updateTime();
		timeInterval = setInterval(updateTime, 1000);
		
		// Fetch initial notification count
		fetchNotificationCounts();
		// Refresh count every 30 seconds
		const notificationInterval = setInterval(fetchNotificationCounts, 30000);
		
		return () => {
			if (timeInterval) clearInterval(timeInterval);
			if (notificationInterval) clearInterval(notificationInterval);
		};
	});

	function updateTime() {
		const now = new Date();
		currentTime = now.toLocaleTimeString([], { 
			hour: '2-digit', 
			minute: '2-digit',
			hour12: true 
		});
		currentDate = now.toLocaleDateString('en-GB', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
	}

	function activateWindow(windowId: string) {
		const window = windowManager.getWindow(windowId);
		if (!window) return;

		if (window.state === 'minimized' || !window.isActive) {
			windowManager.activateWindow(windowId);
		} else {
			// If window is already active, minimize it
			windowManager.minimizeWindow(windowId);
		}
	}

	function showDesktop() {
		// Toggle expansion instead of just minimizing windows
		isExpanded = !isExpanded;
		
		// If expanding, also minimize all windows
		if (isExpanded) {
			const windows = windowManager.windowList;
			windows.forEach(window => {
				if (window.state !== 'minimized') {
					windowManager.minimizeWindow(window.id);
				}
			});
		}
	}

	function toggleLanguage() {
		// Switch between English and Arabic
		const nextLocale = currentLang === 'en' ? 'ar' : 'en';
		switchLocale(nextLocale);
	}

	function getLanguageDisplayName(locale: string): string {
		const localeData = availableLocales.find(l => l.code === locale);
		return localeData?.name || locale.toUpperCase();
	}

	function handleLogout() {
		console.log('Handle logout clicked');
		showLogoutConfirm = true;
		showUserMenu = false;
	}

	function confirmLogout() {
		console.log('Confirming logout...');
		try {
			auth.logout();
			showLogoutConfirm = false;
			showUserMenu = false;
			console.log('Logout successful, redirecting to login...');
			goto('/login');
		} catch (error) {
			console.error('Logout error:', error);
			// Still try to redirect even if there's an error
			goto('/login');
		}
	}

	function cancelLogout() {
		showLogoutConfirm = false;
	}

	// Quick access functions
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openQuickNotifications() {
		const windowId = generateWindowId('quick-notifications');
		
		windowManager.openWindow({
			id: windowId,
			title: 'My Notifications',
			component: NotificationCenter,
			icon: '🔔',
			size: { width: 800, height: 500 },
			position: { x: 150, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Refresh count after opening (in case user reads notifications)
		setTimeout(refreshNotificationCounts, 1000);
	}

	function openQuickAnnouncements() {
		const windowId = generateWindowId('quick-announcements');
		
		// For now, show a placeholder - can be replaced with actual component
		windowManager.openWindow({
			id: windowId,
			title: 'My Announcements',
			component: null,
			icon: '📢',
			size: { width: 700, height: 500 },
			position: { x: 200, y: 150 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openQuickCalendar() {
		const windowId = generateWindowId('quick-calendar');
		
		// For now, show a placeholder - can be replaced with actual component
		windowManager.openWindow({
			id: windowId,
			title: 'My Calendar Events',
			component: null,
			icon: '📅',
			size: { width: 800, height: 600 },
			position: { x: 250, y: 200 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function toggleUserMenu() {
		showUserMenu = !showUserMenu;
	}

	function handleClickOutside(event: MouseEvent) {
		if (showUserMenu) {
			const target = event.target as Element;
			const userInfo = target.closest('.user-info-taskbar');
			if (!userInfo) {
				showUserMenu = false;
			}
		}
		if (showLogoutConfirm) {
			const target = event.target as Element;
			const confirmDialog = target.closest('.logout-confirm-dialog');
			if (!confirmDialog) {
				showLogoutConfirm = false;
			}
		}
	}
</script>

<svelte:window on:click={handleClickOutside} />

<div class="taskbar">
	<!-- Window Tasks -->
	<div class="task-list">
		{#each $taskbarItems as item (item.windowId)}
			<button
				class="task-button"
				class:active={item.isActive}
				class:minimized={item.isMinimized}
				on:click={() => activateWindow(item.windowId)}
				title={item.title}
			>
				{#if item.icon}
					{#if item.icon.startsWith('http') || item.icon.startsWith('/') || item.icon.includes('.')}
						<img src={item.icon} alt="" class="task-icon" />
					{:else}
						<span class="task-icon-emoji">{item.icon}</span>
					{/if}
				{/if}
				<span class="task-title">{item.title}</span>
			</button>
		{/each}
	</div>

	<!-- Quick Access Buttons -->
	<div class="quick-access">
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

		<!-- Quick Announcements -->
		<button 
			class="quick-btn announcements-btn"
			on:click={openQuickAnnouncements}
			title="My Announcements (2 active)"
		>
			<div class="quick-icon">📢</div>
			<div class="quick-badge">2</div>
		</button>

		<!-- Quick Calendar -->
		<button 
			class="quick-btn calendar-btn"
			on:click={openQuickCalendar}
			title="My Calendar Events (4 today)"
		>
			<div class="quick-icon">📅</div>
			<div class="quick-badge">4</div>
		</button>
	</div>

	<!-- System Tray -->
	<div class="system-tray">
		<!-- Logout Button -->
		{#if currentUser}
			<button 
				class="tray-button logout-button" 
				on:click|stopPropagation={handleLogout}
				title="Logout ({currentUser.username})"
				aria-label="Logout from system"
				type="button"
			>
				<svg viewBox="0 0 16 16" width="16" height="16">
					<!-- Door with arrow icon -->
					<rect x="2" y="2" width="8" height="12" rx="1" stroke="currentColor" stroke-width="1" fill="none" />
					<rect x="4" y="6" width="1" height="1" fill="currentColor" />
					<path d="M11 5 L14 8 L11 11 M14 8 L7 8" stroke="currentColor" stroke-width="1" fill="none" />
				</svg>
			</button>
		{/if}

		<!-- Show Desktop Button -->
		<button 
			class="tray-button desktop-button" 
			class:active={isExpanded}
			on:click={showDesktop} 
			title={isExpanded ? "Hide Extended View" : "Show Desktop & Extend"}
			aria-label={isExpanded ? "Hide extended view" : "Show desktop and extend taskbar"}
		>
			<svg viewBox="0 0 16 16" width="16" height="16">
				<rect x="2" y="3" width="12" height="9" stroke="currentColor" stroke-width="1" fill="none" />
				<rect x="4" y="5" width="8" height="1" fill="currentColor" />
				{#if isExpanded}
					<path d="M6 6 L10 6 M8 4 L8 8" stroke="currentColor" stroke-width="1"/>
				{/if}
			</svg>
		</button>
	</div>
</div>

<!-- Extended System Tray Overlay - positioned above taskbar -->
{#if isExpanded}
	<div class="extended-overlay">
		<div class="extended-menu">
			<!-- Language Toggle -->
			<button 
				class="language-toggle" 
				on:click={toggleLanguage}
				title="Switch Language / تبديل اللغة"
				aria-label="Switch language"
			>
				<span class="language-text">{getLanguageDisplayName(currentLang)}</span>
			</button>

			<!-- User Information -->
			<div class="user-info-taskbar" class:has-menu={showUserMenu}>
				<button 
					class="user-button"
					on:click={toggleUserMenu}
					title="User Menu"
				>
					<div class="user-avatar-taskbar">
						<span>{currentUser?.username?.charAt(0)?.toUpperCase() || 'U'}</span>
					</div>
					<div class="user-details-taskbar">
						<div class="user-name-taskbar">{currentUser?.username || 'User'}</div>
						<div class="user-role-taskbar">{currentUser?.role || 'Role'}</div>
					</div>
					<span class="dropdown-arrow">▼</span>
				</button>
				
				{#if showUserMenu}
					<div class="user-menu">
						<div class="user-menu-header">
							<div class="user-avatar-large">
								<span>{currentUser?.username?.charAt(0)?.toUpperCase() || 'U'}</span>
							</div>
							<div class="user-info">
								<div class="user-name">{currentUser?.employeeName || currentUser?.username || 'User'}</div>
								<div class="user-role">{currentUser?.role || 'Role'}</div>
								<div class="user-branch">{currentUser?.branchName || 'Main Branch'}</div>
							</div>
						</div>
						
						<div class="menu-divider"></div>
						
						<div class="user-menu-actions">
							<button class="menu-action" on:click={() => showUserMenu = false}>
								<span class="action-icon">👤</span>
								Profile
							</button>
							<button class="menu-action" on:click={() => showUserMenu = false}>
								<span class="action-icon">⚙️</span>
								Settings
							</button>
							<button class="menu-action logout" on:click={() => { 
								console.log('User menu logout clicked'); 
								showUserMenu = false; 
								handleLogout(); 
							}}>
								<span class="action-icon">🚪</span>
								Logout
							</button>
						</div>
					</div>
				{/if}
			</div>

			<!-- Clock -->
			<div class="clock" title={new Date().toLocaleDateString()}>
				{currentTime}
			</div>

			<!-- Date -->
			<div class="date" title="Current date">
				{currentDate}
			</div>
		</div>
	</div>
{/if}

<!-- Logout Confirmation Dialog -->
{#if showLogoutConfirm}
	<div class="logout-overlay">
		<div class="logout-confirm-dialog">
			<div class="dialog-header">
				<h3>Confirm Logout</h3>
			</div>
			<div class="dialog-body">
				<p>Are you sure you want to logout from your account?</p>
				<div class="current-user-info">
					<div class="user-avatar-dialog">
						<span>{currentUser?.username?.charAt(0)?.toUpperCase() || 'U'}</span>
					</div>
					<div class="user-details-dialog">
						<div class="username">{currentUser?.username || 'User'}</div>
						<div class="role">{currentUser?.role || 'Role'}</div>
					</div>
				</div>
			</div>
			<div class="dialog-actions">
				<button class="cancel-button" on:click={cancelLogout}>Cancel</button>
				<button class="confirm-button" on:click={confirmLogout}>Logout</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.taskbar {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		height: 56px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-top: 2px solid rgba(245, 158, 11, 0.3);
		display: flex;
		align-items: center;
		padding: 0 8px;
		gap: 8px;
		z-index: 2000;
		box-shadow: 
			0 -4px 20px rgba(11, 18, 32, 0.2),
			0 -1px 3px rgba(245, 158, 11, 0.2);
		backdrop-filter: blur(10px);
	}

	.task-list {
		display: flex;
		gap: 4px;
		flex: 1;
		overflow-x: auto;
		padding: 0 8px;
	}

	.task-list::-webkit-scrollbar {
		display: none;
	}

	.task-button {
		display: flex;
		align-items: center;
		gap: 6px;
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		border: 1px solid rgba(229, 231, 235, 0.8);
		border-radius: 4px;
		padding: 6px 8px;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s ease;
		min-width: 100px;
		max-width: 180px;
		flex-shrink: 0;
	}

	.task-button:hover {
		background: #FFFFFF;
		border-color: #4F46E5;
		color: #4F46E5;
	}

	.task-button.active {
		background: linear-gradient(135deg, #4F46E5 0%, #6366F1 100%);
		color: white;
		border-color: #4338CA;
	}

	.task-button.minimized {
		background: rgba(255, 255, 255, 0.6);
		color: #6B7280;
		font-style: italic;
	}

	.task-icon {
		width: 16px;
		height: 16px;
		flex-shrink: 0;
	}

	.task-icon-emoji {
		font-size: 16px;
		width: 16px;
		height: 16px;
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.task-title {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	/* Quick Access Buttons */
	.quick-access {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: 12px;
		padding-left: 12px;
		border-left: 1px solid #4a5568;
	}

	.quick-btn {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
		border: none;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		backdrop-filter: blur(10px);
	}

	.quick-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
	}

	.quick-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
	}

	.quick-icon {
		font-size: 18px;
		filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));
	}

	.quick-badge {
		position: absolute;
		top: -4px;
		right: -4px;
		background: #ef4444;
		color: white;
		font-size: 10px;
		font-weight: 600;
		padding: 2px 5px;
		border-radius: 8px;
		line-height: 1;
		min-width: 16px;
		text-align: center;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.notifications-btn .quick-badge {
		background: #10b981;
	}

	.announcements-btn .quick-badge {
		background: #f59e0b;
	}

	.calendar-btn .quick-badge {
		background: #3b82f6;
	}

	.system-tray {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-shrink: 0;
	}

	.desktop-button {
		opacity: 1; /* Always visible */
	}

	.desktop-button.active {
		background: rgba(255, 255, 255, 0.4);
		color: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
	}

	/* Extended Overlay Menu */
	.extended-overlay {
		position: fixed;
		bottom: 56px; /* Position above taskbar */
		right: 8px; /* Align with system tray area */
		z-index: 3000; /* Above taskbar */
		animation: slideUp 0.3s ease;
	}

	.extended-menu {
		background: linear-gradient(135deg, #374151 0%, #1f2937 100%);
		border: 1px solid #4b5563;
		border-radius: 12px 12px 12px 4px; /* Rounded except bottom-right */
		box-shadow: 0 -8px 32px rgba(0, 0, 0, 0.4);
		padding: 8px;
		display: flex;
		flex-direction: column;
		gap: 6px;
		width: 120px; /* Fixed width to accommodate all elements */
		backdrop-filter: blur(10px);
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.tray-button {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.tray-button:hover {
		background: rgba(255, 255, 255, 0.3);
		color: white;
	}

	.logout-button {
		background: rgba(255, 87, 87, 0.2);
	}

	.logout-button:hover {
		background: rgba(255, 87, 87, 0.4);
		color: white;
		transform: scale(1.05);
	}

	.language-toggle {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 32px;
		padding: 0 8px;
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		border: 1px solid rgba(229, 231, 235, 0.5);
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 12px;
		font-weight: 500;
		width: 100px; /* Fixed width for consistency */
	}

	.language-toggle:hover {
		background: #FFFFFF;
		border-color: #4F46E5;
		color: #4F46E5;
	}

	.language-text {
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.user-info-taskbar {
		display: flex;
		align-items: center;
		gap: 8px;
		background: rgba(255, 255, 255, 0.95);
		border: 1px solid rgba(229, 231, 235, 0.5);
		border-radius: 4px;
		padding: 0;
		height: 32px; /* Same height as language toggle */
		width: 100px; /* Fixed width same as language toggle */
		position: relative;
	}

	.user-button {
		display: flex;
		align-items: center;
		gap: 4px;
		background: none;
		border: none;
		padding: 0 8px;
		height: 100%;
		width: 100%;
		cursor: pointer;
		border-radius: 4px;
		transition: all 0.2s ease;
	}

	.user-button:hover {
		background: rgba(79, 70, 229, 0.1);
	}

	.dropdown-arrow {
		font-size: 8px;
		color: #6B7280;
		margin-left: auto;
		transition: transform 0.2s ease;
	}

	.user-info-taskbar.has-menu .dropdown-arrow {
		transform: rotate(180deg);
	}

	.user-menu {
		position: absolute;
		bottom: 100%;
		right: 0;
		margin-bottom: 8px;
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		box-shadow: 
			0 10px 25px rgba(0, 0, 0, 0.15),
			0 4px 12px rgba(0, 0, 0, 0.1);
		min-width: 280px;
		z-index: 1000;
		animation: slideUp 0.2s ease;
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

	.user-menu-header {
		padding: 1rem;
		display: flex;
		align-items: center;
		gap: 12px;
		border-bottom: 1px solid #F3F4F6;
	}

	.user-avatar-large {
		width: 48px;
		height: 48px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 18px;
		color: white;
		flex-shrink: 0;
	}

	.user-info .user-name {
		font-weight: 600;
		color: #1F2937;
		font-size: 14px;
		margin-bottom: 2px;
	}

	.user-info .user-role {
		color: #6B7280;
		font-size: 12px;
		margin-bottom: 2px;
	}

	.user-info .user-branch {
		color: #9CA3AF;
		font-size: 11px;
	}

	.menu-divider {
		height: 1px;
		background: #F3F4F6;
		margin: 0.5rem 0;
	}

	.user-menu-actions {
		padding: 0.5rem 0;
	}

	.menu-action {
		display: flex;
		align-items: center;
		gap: 12px;
		width: 100%;
		padding: 0.75rem 1rem;
		border: none;
		background: none;
		color: #374151;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s ease;
		text-align: left;
	}

	.menu-action:hover {
		background: #F9FAFB;
		color: #1F2937;
	}

	.menu-action.logout:hover {
		background: #FEF2F2;
		color: #DC2626;
	}

	.action-icon {
		font-size: 16px;
		width: 20px;
		text-align: center;
	}

	.user-avatar-taskbar {
		width: 24px;
		height: 24px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 10px;
		color: white;
		flex-shrink: 0;
	}

	.user-details-taskbar {
		min-width: 0;
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.user-name-taskbar {
		font-weight: 500;
		font-size: 11px;
		color: #0B1220;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		line-height: 1.2;
	}

	.user-role-taskbar {
		font-size: 9px;
		color: #6B7280;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		line-height: 1.2;
	}

	.clock {
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		padding: 0 8px;
		border-radius: 4px; /* Full border radius for independent element */
		font-family: 'Segoe UI', monospace;
		font-size: 12px;
		font-weight: 500;
		height: 32px; /* Full height like other elements */
		text-align: center;
		border: 1px solid rgba(229, 231, 235, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100px; /* Same width as other elements */
	}

	.date {
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		padding: 0 8px;
		border-radius: 4px; /* Full border radius for independent element */
		font-family: 'Segoe UI', monospace;
		font-size: 11px;
		font-weight: 500;
		height: 32px; /* Same height as other elements */
		text-align: center;
		border: 1px solid rgba(229, 231, 235, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100px; /* Same width as other elements */
	}

	/* Responsive design */
	@media (max-width: 768px) {
		.taskbar {
			height: 44px;
			padding: 0 4px;
			gap: 4px;
		}

		.task-button {
			min-width: 100px;
			max-width: 150px;
			padding: 4px 8px;
		}

		.extended-overlay {
			bottom: 44px; /* Mobile taskbar height */
			right: 4px;
		}

		.extended-menu {
			width: 100px; /* Smaller width for mobile to accommodate 80px elements + padding */
			padding: 6px;
			gap: 4px;
		}

		.clock {
			padding: 0 4px;
			font-size: 10px;
			height: 28px; /* Consistent mobile height */
			width: 80px; /* Mobile width */
		}

		.date {
			padding: 0 4px;
			font-size: 9px;
			height: 28px; /* Same as other elements on mobile */
			width: 80px; /* Mobile width */
		}

		.user-info-taskbar {
			width: 80px; /* Same as clock-section on mobile */
			height: 28px; /* Same as clock on mobile */
		}

		.language-toggle {
			width: 80px; /* Same as other elements on mobile */
			height: 28px; /* Consistent mobile height */
		}
	}

	/* Logout Confirmation Dialog */
	.logout-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 5000;
		backdrop-filter: blur(4px);
		animation: fadeIn 0.2s ease;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.logout-confirm-dialog {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		max-width: 400px;
		width: 90%;
		animation: slideInScale 0.3s ease;
	}

	@keyframes slideInScale {
		from {
			opacity: 0;
			transform: scale(0.9) translateY(20px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	.dialog-header {
		padding: 1.5rem 1.5rem 1rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.dialog-header h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.dialog-body {
		padding: 1rem 1.5rem;
	}

	.dialog-body p {
		margin: 0 0 1rem;
		color: #6B7280;
		font-size: 0.9rem;
		line-height: 1.5;
	}

	.current-user-info {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 0.75rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
	}

	.user-avatar-dialog {
		width: 40px;
		height: 40px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 16px;
		color: white;
		flex-shrink: 0;
	}

	.user-details-dialog .username {
		font-weight: 600;
		color: #1F2937;
		font-size: 0.9rem;
		margin-bottom: 2px;
	}

	.user-details-dialog .role {
		color: #6B7280;
		font-size: 0.8rem;
	}

	.dialog-actions {
		display: flex;
		gap: 8px;
		padding: 1rem 1.5rem 1.5rem;
		justify-content: flex-end;
	}

	.cancel-button, .confirm-button {
		padding: 0.5rem 1rem;
		border-radius: 6px;
		border: none;
		font-size: 0.9rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.cancel-button {
		background: #F3F4F6;
		color: #6B7280;
	}

	.cancel-button:hover {
		background: #E5E7EB;
		color: #4B5563;
	}

	.confirm-button {
		background: #DC2626;
		color: white;
	}

	.confirm-button:hover {
		background: #B91C1C;
		transform: translateY(-1px);
	}
</style>
