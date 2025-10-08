<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { createEventDispatcher } from 'svelte';
	import { startNotificationListener } from '$lib/stores/notifications';

	// Mobile-specific layout state
	let currentUserData = null;
	let isLoading = true;

	// Badge counts
	let taskCount = 0;
	let notificationCount = 0;
	let assignmentCount = 0;
	
	// Global header notification count (separate from bottom nav)
	let headerNotificationCount = 0;
	
	// Refresh state for notifications
	let isRefreshing = false;
	
	// Reactive page title that updates when route changes
	$: pageTitle = getPageTitle($page.url.pathname);

	onMount(async () => {
		console.log('🔍 [Mobile Layout] Starting mobile layout initialization...');
		console.log('🔍 [Mobile Layout] Auth state:', $isAuthenticated);
		console.log('🔍 [Mobile Layout] Current user:', $currentUser);
		
		// Check authentication
		if (!$isAuthenticated) {
			console.log('❌ [Mobile Layout] Not authenticated, redirecting to mobile login');
			goto('/mobile-login');
			return;
		}

		// Ensure mobile preference is maintained for this user
		if ($currentUser) {
			interfacePreferenceService.forceMobileInterface($currentUser.id);
			console.log('� [Mobile Layout] Mobile interface preference enforced for user:', $currentUser.id);
		}

		// Check interface preference to ensure user should be in mobile interface
		const userId = $currentUser?.id;
		if (userId && !interfacePreferenceService.isMobilePreferred(userId)) {
			console.log('⚠️ [Mobile Layout] User does not have mobile preference, redirecting to desktop');
			goto('/');
			return;
		}

		currentUserData = $currentUser;
		isLoading = false;
		console.log('✅ [Mobile Layout] Mobile layout initialization completed');

		// Load badge counts
		await loadBadgeCounts();
		
		// Initialize notification sound system for mobile
		console.log('🔔 [Mobile Layout] Starting notification sound system...');
		startNotificationListener();
		
		// Set up periodic refresh of badge counts
		const interval = setInterval(loadBadgeCounts, 30000); // Refresh every 30 seconds
		return () => clearInterval(interval);
	});

	// Subscribe to auth changes
	$: if (!$isAuthenticated && !isLoading) {
		// If user logs out, redirect to mobile login
		goto('/mobile-login');
	}

	// Ensure mobile preference is maintained when user changes
	$: if ($currentUser && $isAuthenticated) {
		interfacePreferenceService.forceMobileInterface($currentUser.id);
		currentUserData = $currentUser;
		loadBadgeCounts(); // Refresh counts when user changes
		
		// Restart notification sound system for new user
		console.log('🔔 [Mobile Layout] User changed, restarting notification sound system...');
		startNotificationListener();
	}

	async function loadBadgeCounts() {
		if (!currentUserData) return;

		try {
			// Load incomplete task count (tasks assigned TO the user)
			// Include both regular tasks and quick tasks
			const { data: myTasks, error: taskError } = await supabase
				.from('task_assignments')
				.select('id')
				.eq('assigned_to_user_id', currentUserData.id)
				.in('status', ['assigned', 'in_progress']);

			const { data: myQuickTasks, error: quickTaskError } = await supabase
				.from('quick_task_assignments')
				.select('id')
				.eq('assigned_to_user_id', currentUserData.id)
				.in('status', ['assigned', 'in_progress', 'pending']);

			if (!taskError && myTasks && !quickTaskError && myQuickTasks) {
				taskCount = myTasks.length + myQuickTasks.length;
			} else if (!taskError && myTasks) {
				taskCount = myTasks.length;
			} else if (!quickTaskError && myQuickTasks) {
				taskCount = myQuickTasks.length;
			}

		// Load unread notification count
		try {
			const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
			if (userNotifications && userNotifications.length > 0) {
				notificationCount = userNotifications.filter(n => !n.is_read).length;
				headerNotificationCount = notificationCount; // Sync header count
			} else {
				notificationCount = 0;
				headerNotificationCount = 0;
			}
		} catch (error) {
			console.error('Error loading notification count:', error);
			notificationCount = 0;
			headerNotificationCount = 0;
		}			
			// Load incomplete assignment count (tasks assigned BY the user)
			// Include both regular task assignments and quick task assignments
			const { data: myAssignments, error: assignmentError } = await supabase
				.from('task_assignments')
				.select('id')
				.eq('assigned_by', currentUserData.id)
				.in('status', ['assigned', 'in_progress']);

			// For quick tasks, we need to check via the quick_tasks table since 
			// quick_task_assignments doesn't have assigned_by field
			const { data: myQuickTaskAssignments, error: quickAssignmentError } = await supabase
				.from('quick_task_assignments')
				.select(`
					id,
					quick_task:quick_tasks!inner(assigned_by)
				`)
				.eq('quick_task.assigned_by', currentUserData.id)
				.in('status', ['assigned', 'in_progress', 'pending']);

			if (!assignmentError && myAssignments && !quickAssignmentError && myQuickTaskAssignments) {
				assignmentCount = myAssignments.length + myQuickTaskAssignments.length;
			} else if (!assignmentError && myAssignments) {
				assignmentCount = myAssignments.length;
			} else if (!quickAssignmentError && myQuickTaskAssignments) {
				assignmentCount = myQuickTaskAssignments.length;
			}

		} catch (error) {
			console.error('Error loading badge counts:', error);
		}
	}
	
	async function refreshHeaderNotificationCount() {
		try {
			if (!currentUserData) return;
			const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
			if (userNotifications && userNotifications.length > 0) {
				headerNotificationCount = userNotifications.filter(n => !n.is_read).length;
			} else {
				headerNotificationCount = 0;
			}
		} catch (error) {
			console.error('Error refreshing header notification count:', error);
		}
	}
	
	function logout() {
		// Clear interface preference to allow user to choose again
		interfacePreferenceService.clearPreference(currentUserData?.id);
		
		// Logout from persistent auth service
		persistentAuthService.logout().then(() => {
			// Redirect to login page to choose interface again
			goto('/login');
		}).catch((error) => {
			console.error('Logout error:', error);
			// Still redirect even if logout fails
			goto('/login');
		});
	}
	
	function getPageTitle(path) {
		// Main pages
		if (path === '/mobile' || path === '/mobile/') return 'Dashboard';
		if (path === '/mobile/tasks' || path === '/mobile/tasks/') return 'Tasks';
		if (path === '/mobile/notifications' || path === '/mobile/notifications/') return 'Notifications';
		if (path === '/mobile/assignments' || path === '/mobile/assignments/') return 'Assignments';
		if (path === '/mobile/quick-task' || path === '/mobile/quick-task/') return 'Quick Task';
		
		// Sub-pages
		if (path.startsWith('/mobile/tasks/assign')) return 'Assign Tasks';
		if (path.startsWith('/mobile/tasks/create')) return 'Create Task';
		if (path.includes('/complete')) return 'Complete Task';
		if (path.startsWith('/mobile/tasks/')) return 'Task Details';
		if (path.startsWith('/mobile/notifications/')) return 'Notification';
		if (path.startsWith('/mobile/assignments/')) return 'Assignment Details';
		
		// Default fallback
		return 'Aqura';
	}
	
	async function handleNotificationRefresh() {
		isRefreshing = true;
		try {
			// Dispatch a custom event that the NotificationCenter can listen to
			const refreshEvent = new CustomEvent('refreshNotifications');
			window.dispatchEvent(refreshEvent);
			
			// Also refresh the header notification count
			await refreshHeaderNotificationCount();
		} catch (error) {
			console.error('Error refreshing notifications:', error);
		} finally {
			// Add a small delay to show the spinning animation
			setTimeout(() => {
				isRefreshing = false;
			}, 1000);
		}
	}
	
	function goBack() {
		if (window.history.length > 1) {
			window.history.back();
		} else {
			goto('/mobile');
		}
	}
</script>

<svelte:head>
	<title>Aqura Mobile Dashboard</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#3B82F6" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

{#if isLoading}
	<div class="mobile-loading">
		<div class="loading-spinner"></div>
		<p>Loading Mobile Dashboard...</p>
	</div>
{:else if $isAuthenticated}
	<div class="mobile-layout">
		<!-- Global Mobile Header -->
		<header class="global-mobile-header">
			<div class="header-content">
				<div class="user-info">
					{#if $page.url.pathname !== '/mobile'}
						<button class="back-btn" on:click={goBack} aria-label="Go back">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="m15 18-6-6 6-6"/>
							</svg>
						</button>
					{/if}
					<div class="user-avatar">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
							<circle cx="12" cy="7" r="4"/>
						</svg>
					</div>
					<div class="user-details">
						<h1>{pageTitle}</h1>
						<p>{currentUserData?.name || currentUserData?.username || 'User'}</p>
					</div>
				</div>
				<div class="header-actions">
					<a href="/mobile" class="header-nav-btn" class:active={$page.url.pathname === '/mobile'} aria-label="Go to dashboard">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
							<polyline points="9,22 9,12 15,12 15,22"/>
						</svg>
					</a>
					<a href="/mobile/notifications" class="header-nav-btn" class:active={$page.url.pathname.startsWith('/mobile/notifications')} aria-label="View notifications">
						<div class="nav-icon-container">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
								<path d="M13.73 21a2 2 0 0 1-3.46 0"/>
							</svg>
							{#if headerNotificationCount > 0}
								<span class="header-notification-badge">{headerNotificationCount > 99 ? '99+' : headerNotificationCount}</span>
							{/if}
						</div>
					</a>
					{#if $page.url.pathname.startsWith('/mobile/notifications')}
						<button class="header-nav-btn refresh-btn" on:click={handleNotificationRefresh} aria-label="Refresh notifications">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class:spinning={isRefreshing}>
								<polyline points="23,4 23,10 17,10"/>
								<polyline points="1,20 1,14 7,14"/>
								<path d="M20.49,9A9,9,0,0,0,5.64,5.64L1,10m22,4-4.64,4.36A9,9,0,0,1,3.51,15"/>
							</svg>
						</button>
					{/if}
					<button class="logout-btn" on:click={logout} aria-label="Logout">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
							<polyline points="16,17 21,12 16,7"/>
							<line x1="21" y1="12" x2="9" y2="12"/>
						</svg>
					</button>
				</div>
			</div>
		</header>
		
		<!-- Mobile content goes here -->
		<main class="mobile-content">
			<slot />
		</main>
		
		<!-- Global Bottom Navigation Bar -->
		<nav class="bottom-nav">
			<a href="/mobile/tasks" class="nav-item" class:active={$page.url.pathname.startsWith('/mobile/tasks')}>
				<div class="nav-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
						<rect x="9" y="7" width="6" height="5"/>
					</svg>
					{#if taskCount > 0}
						<span class="nav-badge">{taskCount > 99 ? '99+' : taskCount}</span>
					{/if}
				</div>
				<span class="nav-label">Tasks</span>
			</a>
			
			<a href="/mobile/tasks/assign" class="nav-item create-btn" class:active={$page.url.pathname.startsWith('/mobile/tasks/assign')}>
				<div class="nav-icon create-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
						<circle cx="8.5" cy="7" r="4"/>
						<line x1="20" y1="8" x2="20" y2="14"/>
						<line x1="23" y1="11" x2="17" y2="11"/>
					</svg>
				</div>
				<span class="nav-label">Assign</span>
			</a>
			
			<a href="/mobile/quick-task" class="nav-item quick-task-btn" class:active={$page.url.pathname.startsWith('/mobile/quick-task')}>
				<div class="nav-icon quick-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
						<circle cx="12" cy="12" r="3"/>
					</svg>
				</div>
				<span class="nav-label">Quick Task</span>
			</a>
			
			<a href="/mobile/assignments" class="nav-item" class:active={$page.url.pathname.startsWith('/mobile/assignments')}>
				<div class="nav-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
					</svg>
					{#if assignmentCount > 0}
						<span class="nav-badge">{assignmentCount > 99 ? '99+' : assignmentCount}</span>
					{/if}
				</div>
				<span class="nav-label">Assignments</span>
			</a>
		</nav>
	</div>
{:else}
	<div class="mobile-error">
		<h2>Access Required</h2>
		<p>Please log in to access the mobile interface.</p>
		<button on:click={() => goto('/mobile-login')} class="error-btn">
			Go to Mobile Login
		</button>
	</div>
{/if}

<style>
	/* Complete CSS reset and mobile-specific styling */
	:global(*) {
		box-sizing: border-box;
		margin: 0;
		padding: 0;
	}

	:global(html) {
		height: 100%;
		height: 100dvh;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		-webkit-text-size-adjust: 100%;
		-webkit-tap-highlight-color: transparent;
	}

	:global(body) {
		height: 100%;
		height: 100dvh;
		margin: 0 !important;
		padding: 0 !important;
		overflow: auto !important;
		-webkit-overflow-scrolling: touch;
		background: #F8FAFC !important;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif !important;
		line-height: 1.5;
		color: #1F2937;
	}

	:global(#app),
	:global(#svelte) {
		height: 100%;
		height: 100dvh;
		width: 100%;
		margin: 0 !important;
		padding: 0 !important;
		background: transparent !important;
	}

	/* Override any desktop layout styles */
	:global(.layout-container),
	:global(.main-layout),
	:global(.sidebar),
	:global(.navbar),
	:global(.header),
	:global(.desktop-*) {
		display: none !important;
	}

	/* Ensure mobile layout takes full screen */
	:global(.mobile-layout) {
		position: fixed !important;
		top: 0 !important;
		left: 0 !important;
		right: 0 !important;
		bottom: 0 !important;
		width: 100vw !important;
		height: 100vh !important;
		height: 100dvh !important;
		z-index: 9999 !important;
		background: #F8FAFC !important;
		overflow-x: hidden !important;
		overflow-y: auto !important;
	}

	.mobile-loading {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		width: 100vw;
		height: 100vh;
		height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		color: white;
		font-family: 'Inter', 'Segoe UI', sans-serif;
		text-align: center;
		padding: 2rem;
		z-index: 10000;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid rgba(255, 255, 255, 0.3);
		border-top: 3px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.mobile-loading p {
		font-size: 1.1rem;
		opacity: 0.9;
		margin: 0;
	}

	.mobile-layout {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		width: 100vw;
		height: 100vh;
		height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		font-family: 'Inter', 'Segoe UI', sans-serif;
		z-index: 9999;
		display: flex;
		flex-direction: column;
	}

	/* Global Mobile Header */
	.global-mobile-header {
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		color: white;
		padding: 0.8rem 1.2rem;
		padding-top: calc(0.8rem + env(safe-area-inset-top));
		box-shadow: 0 2px 10px rgba(59, 130, 246, 0.2);
		position: sticky;
		top: 0;
		z-index: 100;
	}

	.header-content {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 0.8rem;
	}

	.back-btn {
		width: 28px;
		height: 28px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 6px;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		text-decoration: none;
		backdrop-filter: blur(10px);
		transition: all 0.2s ease;
		flex-shrink: 0;
	}

	.back-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
	}

	.back-btn:active {
		transform: translateY(0);
		background: rgba(255, 255, 255, 0.15);
	}

	.user-avatar {
		width: 30px;
		height: 30px;
		background: rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		backdrop-filter: blur(10px);
	}

	.user-details h1 {
		font-size: 0.9rem;
		font-weight: 600;
		margin: 0 0 0.1rem 0;
	}

	.user-details p {
		font-size: 0.65rem;
		opacity: 0.8;
		margin: 0;
	}

	.header-actions {
		display: flex;
		align-items: center;
		gap: 0.4rem;
	}

	.header-nav-btn {
		width: 28px;
		height: 28px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 6px;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		text-decoration: none;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		backdrop-filter: blur(10px);
	}

	.header-nav-btn:hover,
	.header-nav-btn.active {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
		color: white;
	}

	.nav-icon-container {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.header-notification-badge {
		position: absolute;
		top: -4px;
		right: -4px;
		background: #EF4444;
		color: white;
		font-size: 0.45rem;
		font-weight: 600;
		padding: 1px 4px;
		border-radius: 6px;
		min-width: 12px;
		height: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		line-height: 1;
		box-shadow: 0 2px 4px rgba(239, 68, 68, 0.2);
		z-index: 1;
	}

	.spinning {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	.logout-btn {
		width: 28px;
		height: 28px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 6px;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		backdrop-filter: blur(10px);
	}

	.logout-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
	}

	.mobile-content {
		flex: 1;
		overflow-y: auto;
		overflow-x: hidden;
		-webkit-overflow-scrolling: touch;
		padding-bottom: 4rem; /* Space for bottom nav - reduced from 5rem */
	}

	/* Bottom Navigation */
	.bottom-nav {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		height: 3.6rem; /* Reduced from 4.5rem (20% smaller) */
		background: white;
		border-top: 1px solid #E5E7EB;
		display: flex;
		align-items: center;
		justify-content: space-around;
		padding: 0.4rem; /* Reduced from 0.5rem */
		padding-bottom: calc(0.4rem + env(safe-area-inset-bottom));
		box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
		z-index: 1000;
	}

	.nav-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-decoration: none;
		color: #6B7280;
		transition: all 0.2s ease;
		padding: 0.2rem; /* Reduced from 0.25rem */
		border-radius: 6px; /* Reduced from 8px */
		min-width: 3rem;
		touch-action: manipulation;
	}

	.nav-item:hover {
		color: #3B82F6;
		background: rgba(59, 130, 246, 0.05);
	}

	.nav-item.active {
		color: #3B82F6;
	}

	.nav-item.active .nav-icon {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
	}

	.nav-icon {
		width: 2rem; /* Reduced from 2.5rem (20% smaller) */
		height: 2rem; /* Reduced from 2.5rem (20% smaller) */
		border-radius: 6px; /* Reduced from 8px */
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 0.2rem; /* Reduced from 0.25rem */
		transition: all 0.2s ease;
		position: relative;
	}

	.nav-badge {
		position: absolute;
		top: -5px; /* Reduced from -6px */
		right: -5px; /* Reduced from -6px */
		background: #EF4444;
		color: white;
		font-size: 0.5rem; /* Reduced from 0.625rem */
		font-weight: 600;
		padding: 1px 5px; /* Reduced from 2px 6px */
		border-radius: 8px; /* Reduced from 10px */
		min-width: 14px; /* Reduced from 18px */
		height: 14px; /* Reduced from 18px */
		display: flex;
		align-items: center;
		justify-content: center;
		line-height: 1;
		box-shadow: 0 2px 4px rgba(239, 68, 68, 0.2);
		z-index: 1;
	}

	.nav-label {
		font-size: 0.6rem; /* Reduced from 0.75rem (20% smaller) */
		font-weight: 500;
		text-align: center;
	}

	/* Special styling for create button */
	.nav-item.create-btn {
		color: white;
	}

	.nav-item.create-btn .create-icon {
		background: linear-gradient(135deg, #3B82F6, #1D4ED8);
		color: white;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.nav-item.create-btn:hover .create-icon {
		transform: scale(1.05);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.nav-item.create-btn .nav-label {
		color: #3B82F6;
		font-weight: 600;
	}

	/* Special styling for quick task button */
	.nav-item.quick-task-btn {
		color: #6B7280;
		text-decoration: none;
	}

	.nav-item.quick-task-btn:hover {
		color: #F59E0B;
		background: rgba(245, 158, 11, 0.05);
	}

	.nav-item.quick-task-btn.active {
		color: #F59E0B;
	}

	.nav-item.quick-task-btn .quick-icon {
		background: linear-gradient(135deg, #F59E0B, #D97706);
		color: white;
		box-shadow: 0 2px 8px rgba(245, 158, 11, 0.3);
	}

	.nav-item.quick-task-btn:hover .quick-icon,
	.nav-item.quick-task-btn.active .quick-icon {
		transform: scale(1.05);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.nav-item.quick-task-btn .nav-label {
		color: #F59E0B;
		font-weight: 600;
	}

	.mobile-error {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		width: 100vw;
		height: 100vh;
		height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: #F8FAFC;
		padding: 2rem;
		text-align: center;
		color: #374151;
		z-index: 10000;
	}

	.mobile-error h2 {
		font-size: 1.5rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
		color: #1F2937;
	}

	.mobile-error p {
		font-size: 1rem;
		margin-bottom: 2rem;
		opacity: 0.8;
	}

	.error-btn {
		padding: 0.75rem 1.5rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.error-btn:hover {
		background: #2563EB;
		transform: translateY(-1px);
	}

	/* Mobile-specific global styles */
	:global(button) {
		border: none;
		outline: none;
		cursor: pointer;
		touch-action: manipulation;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
	}

	:global(input),
	:global(textarea),
	:global(select) {
		border: none;
		outline: none;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		font-family: inherit;
	}

	:global(a) {
		text-decoration: none;
		color: inherit;
	}

	/* Ensure no desktop styles leak through */
	:global(.svelte-*) {
		font-family: 'Inter', 'Segoe UI', sans-serif !important;
	}
</style>