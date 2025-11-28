<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase, supabaseAdmin } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { createEventDispatcher } from 'svelte';
	import { startNotificationListener } from '$lib/stores/notifications';
	import { initI18n, currentLocale, localeData } from '$lib/i18n';
	import LanguageToggle from '$lib/components/mobile/LanguageToggle.svelte';

	// Mobile-specific layout state
	let currentUserData = null;
	let isLoading = true;
	let hasApprovalPermission = false;

	// Badge counts
	let taskCount = 0;
	let notificationCount = 0;
	let assignmentCount = 0;
	let approvalCount = 0;
	
	// Global header notification count (separate from bottom nav)
	let headerNotificationCount = 0;
	
	// Previous notification count for sound detection
	let previousNotificationCount = 0;
	let isInitialLoad = true; // Flag to prevent sounds on initial page load
	
	// Refresh state for notifications
	let isRefreshing = false;
	
	// Menu state
	let showMenu = false;
	
	// Reactive page title that updates when route changes or locale changes
	$: pageTitle = getPageTitle($page.url.pathname, $currentLocale);

	onMount(() => {
		// Initialize i18n system
		initI18n();
		
		// Check authentication
		if (!$isAuthenticated) {
			goto('/mobile-login');
			return;
		}

		// Ensure mobile preference is maintained for this user
		if ($currentUser) {
			interfacePreferenceService.forceMobileInterface($currentUser.id);
		}

		// Check interface preference to ensure user should be in mobile interface
		const userId = $currentUser?.id;
		if (userId && !interfacePreferenceService.isMobilePreferred(userId)) {
			goto('/');
			return;
		}

		currentUserData = $currentUser;
		isLoading = false;

		// Load badge counts
		loadBadgeCounts();
		
		// Initialize notification sound system for mobile
		startNotificationListener();
		
		// Set up mobile audio unlock on first user interaction
		setupMobileAudioUnlock();
		
		// Set up periodic refresh of badge counts
		const interval = setInterval(() => loadBadgeCounts(true), 30000); // Silent refresh every 30 seconds
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
		loadBadgeCounts(true); // Silent refresh counts when user changes
		
		// Restart notification sound system for new user
		startNotificationListener();
	}

	// Reactive statement to play sound when notification count increases
	$: if (notificationCount > previousNotificationCount && previousNotificationCount >= 0 && !isInitialLoad) {
		(async () => {
			try {
				const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
				if (notificationSoundManager) {
					// Create a proper notification object for the sound
					const countChangeNotification = {
						id: 'count-change-' + Date.now(),
						title: 'New Notification',
						message: `You have ${notificationCount} new notification${notificationCount !== 1 ? 's' : ''}`,
						type: 'info' as const,
						priority: 'medium' as const,
						timestamp: new Date(),
						read: false,
						soundEnabled: true
					};
					await notificationSoundManager.playNotificationSound(countChangeNotification);
					console.log('🔊 [Mobile Layout] Notification sound played via reactive statement');
				}
			} catch (error) {
				console.error('❌ [Mobile Layout] Failed to play reactive notification sound:', error);
			}
		})();
	}

	async function loadBadgeCounts(silent = false) {
		if (!currentUserData) return;

		try {
			// Parallel loading for better performance
			const [tasksResult, quickTasksResult, receivingTasksResult, userDataResult] = await Promise.all([
				// Load incomplete regular task count
				supabase
					.from('task_assignments')
					.select('id, status', { count: 'exact', head: true })
					.eq('assigned_to_user_id', currentUserData.id)
					.neq('status', 'completed')
					.neq('status', 'cancelled'),

				// Load incomplete quick task count
				supabase
					.from('quick_task_assignments')
					.select('id, status', { count: 'exact', head: true })
					.eq('assigned_to_user_id', currentUserData.id)
					.neq('status', 'completed')
					.neq('status', 'cancelled'),

				// Load pending receiving task count
				supabase
					.from('receiving_tasks')
					.select('id, task_status', { count: 'exact', head: true })
					.eq('assigned_user_id', currentUserData.id)
					.eq('task_status', 'pending'),

			// Load user approval permissions
			supabase
				.from('approval_permissions')
				.select('*')
				.eq('user_id', currentUserData.id)
				.eq('is_active', true)
				.maybeSingle() // Use maybeSingle instead of single to handle zero results gracefully
		]);

		// Set task count (include receiving tasks)
		taskCount = (tasksResult.count || 0) + (quickTasksResult.count || 0) + (receivingTasksResult.count || 0);

		// Handle approval permissions and counts
		if (!userDataResult.error && userDataResult.data) {
			// User has approval permission if ANY permission type is enabled
			hasApprovalPermission = 
				userDataResult.data.can_approve_requisitions ||
				userDataResult.data.can_approve_single_bill ||
				userDataResult.data.can_approve_multiple_bill ||
				userDataResult.data.can_approve_recurring_bill ||
				userDataResult.data.can_approve_vendor_payments ||
				userDataResult.data.can_approve_leave_requests;				if (hasApprovalPermission) {
					// Parallel load approval counts
					const twoDaysFromNow = new Date();
					twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
					const twoDaysDate = twoDaysFromNow.toISOString().split('T')[0];

					const [reqResult, scheduleResult] = await Promise.all([
						supabaseAdmin
							.from('expense_requisitions')
							.select('*', { count: 'exact', head: true })
							.eq('approver_id', currentUserData.id)
							.eq('status', 'pending'),

						supabaseAdmin
							.from('non_approved_payment_scheduler')
							.select('*', { count: 'exact', head: true })
							.eq('approver_id', currentUserData.id)
							.eq('approval_status', 'pending')
							.or('schedule_type.eq.multiple_bill,and(schedule_type.eq.single_bill,due_date.lte.' + twoDaysDate + ')')
					]);

					approvalCount = (reqResult.count || 0) + (scheduleResult.count || 0);
				} else {
					approvalCount = 0;
				}
			}

		} catch (error) {
			if (!silent) {
				console.error('Error loading task counts:', error);
			}
		}

		// Load unread notification count and assignment counts in parallel
		try {
			const [notificationsResult, assignmentsResult, quickAssignmentsResult] = await Promise.all([
				notificationManagement.getUserNotifications(currentUserData.id),
				
				// Load incomplete assignment count (tasks assigned BY the user)
				supabase
					.from('task_assignments')
					.select('id', { count: 'exact', head: true })
					.eq('assigned_by', currentUserData.id)
					.in('status', ['assigned', 'in_progress', 'pending'])
					.neq('status', 'completed')
					.neq('status', 'cancelled'),
				
				// Quick task assignments
				supabase
					.from('quick_task_assignments')
					.select(`
						id,
						quick_task:quick_tasks!inner(assigned_by)
					`, { count: 'exact', head: true })
					.eq('quick_task.assigned_by', currentUserData.id)
					.in('status', ['assigned', 'in_progress', 'pending'])
					.neq('status', 'completed')
					.neq('status', 'cancelled')
			]);

			// Handle notifications
			if (notificationsResult && notificationsResult.length > 0) {
				const newNotificationCount = notificationsResult.filter(n => !n.is_read).length;
				
				// Check if notification count increased (new notifications)
				if (newNotificationCount > previousNotificationCount && previousNotificationCount > 0) {
					// Play notification sound
					try {
						const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
						if (notificationSoundManager) {
							const newNotification = {
								id: 'badge-update-' + Date.now(),
								title: 'New Notification',
								message: `Notification count updated to ${newNotificationCount}`,
								type: 'info' as const,
								priority: 'medium' as const,
								timestamp: new Date(),
								read: false,
								soundEnabled: true
							};
							await notificationSoundManager.playNotificationSound(newNotification);
						}
					} catch (error) {
						console.error('❌ [Mobile Layout] Failed to play notification sound:', error);
					}
				}
				
				// Update counts
				previousNotificationCount = notificationCount;
				notificationCount = newNotificationCount;
				headerNotificationCount = newNotificationCount;
			} else {
				previousNotificationCount = notificationCount;
				notificationCount = 0;
				headerNotificationCount = 0;
			}

			// Handle assignment counts
			assignmentCount = (assignmentsResult.count || 0) + (quickAssignmentsResult.count || 0);

		} catch (error) {
			if (!silent) {
				console.error('Error loading notification and assignment counts:', error);
			}
			previousNotificationCount = notificationCount;
			notificationCount = 0;
			headerNotificationCount = 0;
		}
		
		// After the first load, allow sound notifications for future changes
		if (isInitialLoad) {
			isInitialLoad = false;
		}
	}
	
	async function refreshHeaderNotificationCount() {
		try {
			if (!currentUserData) return;
			const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
			if (userNotifications && userNotifications.length > 0) {
				const newHeaderCount = userNotifications.filter(n => !n.is_read).length;
				
				// Check if notification count increased during header refresh
				if (newHeaderCount > headerNotificationCount && headerNotificationCount >= 0) {
					// Play notification sound
					try {
						const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
						if (notificationSoundManager) {
							const headerRefreshNotification = {
								id: 'header-refresh-' + Date.now(),
								title: 'New Notification',
								message: `Header refresh detected new notifications`,
								type: 'info' as const,
								priority: 'medium' as const,
								timestamp: new Date(),
								read: false,
								soundEnabled: true
							};
							await notificationSoundManager.playNotificationSound(headerRefreshNotification);
						}
					} catch (error) {
						console.error('❌ [Mobile Layout] Failed to play notification sound during header refresh:', error);
					}
				}
				
				headerNotificationCount = newHeaderCount;
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
	
	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath; // Return key path if translation not found
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}
	
	function getPageTitle(path, locale = null) {
		// Main pages
		if (path === '/mobile' || path === '/mobile/') return getTranslation('mobile.dashboard');
		if (path === '/mobile/tasks' || path === '/mobile/tasks/') return getTranslation('mobile.tasks');
		if (path === '/mobile/notifications' || path === '/mobile/notifications/') return getTranslation('mobile.notifications');
		if (path === '/mobile/assignments' || path === '/mobile/assignments/') return getTranslation('mobile.assignments');
		if (path === '/mobile/approval-center' || path === '/mobile/approval-center/') return getTranslation('mobile.approvals');
		if (path === '/mobile/quick-task' || path === '/mobile/quick-task/') return getTranslation('mobile.quickTask');
		
		// Sub-pages
		if (path.startsWith('/mobile/tasks/assign')) return getTranslation('mobile.assignTasks');
		if (path.startsWith('/mobile/tasks/create')) return getTranslation('mobile.createTask');
		if (path.includes('/complete')) return getTranslation('mobile.completeTask');
		if (path.startsWith('/mobile/tasks/')) return getTranslation('mobile.taskDetails');
		if (path.startsWith('/mobile/notifications/create')) return getTranslation('mobile.createNotification');
		if (path.startsWith('/mobile/notifications/')) return getTranslation('mobile.notification');
		if (path.startsWith('/mobile/assignments/')) return getTranslation('mobile.assignmentDetails');
		
		// Default fallback
		return getTranslation('app.shortName');
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
	
	function setupMobileAudioUnlock() {
		// Import and unlock mobile audio on first touch interaction
		// Force audio unlock for mobile interface even on desktop
		const unlockAudio = async () => {
			try {
				// Dynamically import the sound manager
				const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
				if (notificationSoundManager) {
					await notificationSoundManager.unlockMobileAudio();
					console.log('📱 [Mobile Layout] Audio unlocked via user interaction (mobile interface on any device)');
				}
			} catch (error) {
				console.error('❌ [Mobile Layout] Failed to unlock mobile audio:', error);
			}
			
			// Remove listeners after first interaction
			document.removeEventListener('touchstart', unlockAudio, { capture: true });
			document.removeEventListener('click', unlockAudio, { capture: true });
		};

		// Add event listeners for first user interaction
		// Use both touch and click to support desktop users on mobile interface
		document.addEventListener('touchstart', unlockAudio, { capture: true, once: true });
		document.addEventListener('click', unlockAudio, { capture: true, once: true });
	}

	// Debug function for testing notification sounds
	if (typeof window !== 'undefined') {
		(window as any).testMobileNotificationSound = async () => {
			try {
				const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
				if (notificationSoundManager) {
					// Create a proper test notification object
					const testNotification = {
						id: 'test-' + Date.now(),
						title: 'Test Notification',
						message: 'This is a test notification sound from mobile layout',
						type: 'info' as const,
						priority: 'medium' as const,
						timestamp: new Date(),
						read: false,
						soundEnabled: true
					};
					await notificationSoundManager.playNotificationSound(testNotification);
				} else {
					console.error('❌ [Mobile Layout] Sound manager not available');
				}
			} catch (error) {
				console.error('❌ [Mobile Layout] Failed to play test notification sound:', error);
			}
		};
		
		(window as any).simulateNotificationIncrease = () => {
			previousNotificationCount = notificationCount;
			notificationCount = notificationCount + 1;
		};
		
		// Add a function to re-unlock audio if it gets suspended
		(window as any).unlockNotificationAudio = async () => {
			try {
				const { notificationSoundManager } = await import('$lib/utils/inAppNotificationSounds');
				if (notificationSoundManager) {
					await notificationSoundManager.unlockMobileAudio(true); // Force unlock
					return true;
				}
			} catch (error) {
				console.error('❌ [Mobile Layout] Failed to unlock audio:', error);
				return false;
			}
		};
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
						<button class="back-btn" on:click={goBack} aria-label={getTranslation('nav.goBack')}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="m15 18-6-6 6-6"/>
							</svg>
						</button>
					{/if}
					<button class="menu-btn" on:click={() => showMenu = !showMenu} aria-label="Menu">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<line x1="3" y1="6" x2="21" y2="6"/>
							<line x1="3" y1="12" x2="21" y2="12"/>
							<line x1="3" y1="18" x2="21" y2="18"/>
						</svg>
					</button>
					<div class="user-details">
						<h1>{pageTitle}</h1>
						<p>{currentUserData?.name || currentUserData?.username || 'User'}</p>
					</div>
				</div>
				<div class="header-actions">
					<a href="/mobile/notifications" class="header-nav-btn" class:active={$page.url.pathname.startsWith('/mobile/notifications')} aria-label={getTranslation('nav.viewNotifications')}>
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
						<button class="header-nav-btn refresh-btn" on:click={handleNotificationRefresh} aria-label={getTranslation('nav.refreshNotifications')}>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class:spinning={isRefreshing}>
								<polyline points="23,4 23,10 17,10"/>
								<polyline points="1,20 1,14 7,14"/>
								<path d="M20.49,9A9,9,0,0,0,5.64,5.64L1,10m22,4-4.64,4.36A9,9,0,0,1,3.51,15"/>
							</svg>
						</button>
					{/if}
				</div>
			</div>
		</header>
		
		<!-- Menu Dropdown -->
	{#if showMenu}
		<div class="menu-overlay" on:click={() => showMenu = false}></div>
		<div class="menu-dropdown">
			<a href="/mobile" class="menu-item" on:click={() => showMenu = false} title={getTranslation('mobile.home')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
					<polyline points="9 22 9 12 15 12 15 22"/>
				</svg>
			</a>
			{#if currentUserData?.roleType === 'Master Admin' || currentUserData?.roleType === 'Admin'}
				<a href="/mobile/reports" class="menu-item" on:click={() => showMenu = false} title={getTranslation('reports.salesReport') || 'Sales Report'}>
					<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M9 2v4"/>
						<path d="M15 2v4"/>
						<rect width="18" height="18" x="3" y="4" rx="2"/>
						<path d="M3 10h18"/>
						<path d="M8 14h.01"/>
						<path d="M12 14h.01"/>
						<path d="M16 14h.01"/>
						<path d="M8 18h.01"/>
						<path d="M12 18h.01"/>
						<path d="M16 18h.01"/>
					</svg>
				</a>
			{/if}
			<div class="menu-item menu-language" title={getTranslation('mobile.language')}>
				<LanguageToggle />
			</div>
			<button class="menu-item" on:click={() => { logout(); showMenu = false; }} title={getTranslation('mobile.logout')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
					<polyline points="16 17 21 12 16 7"/>
					<line x1="21" y1="12" x2="9" y2="12"/>
				</svg>
			</button>
		</div>
	{/if}
	
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
				<span class="nav-label">{getTranslation('mobile.bottomNav.tasks')}</span>
			</a>
			
			<a href="/mobile/quick-task" class="nav-item quick-task-btn" class:active={$page.url.pathname.startsWith('/mobile/quick-task')}>
				<div class="nav-icon quick-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
						<circle cx="12" cy="12" r="3"/>
					</svg>
				</div>
				<span class="nav-label">{getTranslation('mobile.quickTask')}</span>
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
				<span class="nav-label">{getTranslation('mobile.bottomNav.assignments')}</span>
			</a>
			
			<!-- Approval Center - Visible to all users -->
			<a href="/mobile/approval-center" class="nav-item approval-btn" class:active={$page.url.pathname.startsWith('/mobile/approval-center')}>
				<div class="nav-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
					</svg>
					{#if approvalCount > 0}
						<span class="nav-badge approval-badge">{approvalCount > 99 ? '99+' : approvalCount}</span>
					{/if}
				</div>
				<span class="nav-label">Approvals</span>
			</a>
		</nav>
	</div>
{:else}
	<div class="mobile-error">
		<h2>{getTranslation('mobile.error.accessRequired')}</h2>
		<p>{getTranslation('mobile.error.loginRequired')}</p>
		<button on:click={() => goto('/mobile-login')} class="error-btn">
			{getTranslation('mobile.error.goToLogin')}
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

	/* Version Badge */
	.version-badge {
		position: absolute;
		left: 50%;
		transform: translateX(-50%);
		pointer-events: none;
	}

	.version-text {
		font-size: 0.7rem;
		font-weight: 500;
		opacity: 0.7;
		color: white;
		background: rgba(255, 255, 255, 0.1);
		padding: 0.15rem 0.5rem;
		border-radius: 12px;
		backdrop-filter: blur(10px);
		white-space: nowrap;
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

	.menu-btn {
		width: 30px;
		height: 30px;
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		backdrop-filter: blur(10px);
		transition: all 0.2s ease;
		flex-shrink: 0;
		color: white;
	}

	.menu-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		border-color: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
	}

	.menu-btn:active {
		transform: scale(0.95);
		background: rgba(255, 255, 255, 0.25);
	}

	/* Menu Dropdown */
	.menu-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 999;
		animation: fadeIn 0.2s ease;
	}

	.menu-dropdown {
		position: fixed;
		top: 60px;
		left: 10px;
		background: transparent;
		z-index: 1000;
		animation: slideDown 0.2s ease;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.menu-item {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		background: #3B82F6;
		border: none;
		width: 48px;
		height: 48px;
		border-radius: 50%;
		color: white;
		cursor: pointer;
		transition: all 0.25s ease;
		text-decoration: none;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.menu-item:last-child {
		border-bottom: none;
	}

	.menu-item:hover {
		background: #2563EB;
		transform: scale(1.1);
		box-shadow: 0 6px 20px rgba(37, 99, 235, 0.5);
	}

	.menu-item:active {
		transform: scale(0.95);
	}

	.menu-item svg {
		color: white;
		transition: all 0.25s ease;
	}

	.menu-item:hover svg {
		color: white;
	}

	.menu-language {
		padding: 0;
		background: #3B82F6;
		width: 48px;
		height: 48px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.menu-language:hover {
		background: #2563EB;
		transform: scale(1.1);
		box-shadow: 0 6px 20px rgba(37, 99, 235, 0.5);
	}

	/* RTL Support for Menu */
	:global([dir="rtl"]) .menu-dropdown {
		left: auto;
		right: 10px;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
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

	.nav-badge.approval-badge {
		background: #10B981;
		box-shadow: 0 2px 4px rgba(16, 185, 129, 0.3);
	}

	.nav-label {
		font-size: 0.6rem; /* Reduced from 0.75rem (20% smaller) */
		font-weight: 500;
		text-align: center;
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

	/* Special styling for approval button */
	.nav-item.approval-btn {
		color: #6B7280;
		text-decoration: none;
	}

	.nav-item.approval-btn:hover {
		color: #10B981;
		background: rgba(16, 185, 129, 0.05);
	}

	.nav-item.approval-btn.active {
		color: #10B981;
	}

	.nav-item.approval-btn.active .nav-icon {
		background: rgba(16, 185, 129, 0.1);
		color: #10B981;
	}

	.nav-item.approval-btn .nav-label {
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

	/* RTL Support */
	:global([dir="rtl"]) {
		direction: rtl;
	}

	:global([dir="rtl"] .header-content) {
		direction: rtl;
	}

	:global([dir="rtl"] .user-info) {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"] .header-actions) {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"] .bottom-nav) {
		direction: rtl;
	}

	:global([dir="rtl"] .nav-item) {
		direction: rtl;
	}

	:global([dir="rtl"] .mobile-content) {
		direction: rtl;
	}

	/* Arabic font support */
	:global(.font-arabic) {
		font-family: 'Noto Sans Arabic', 'Tajawal', 'Amiri', 'Cairo', sans-serif !important;
	}

	:global(.font-arabic .global-mobile-header) {
		font-family: 'Noto Sans Arabic', 'Tajawal', 'Amiri', 'Cairo', sans-serif !important;
	}

	:global(.font-arabic .bottom-nav) {
		font-family: 'Noto Sans Arabic', 'Tajawal', 'Amiri', 'Cairo', sans-serif !important;
	}

	:global(.font-arabic .nav-label) {
		font-family: 'Noto Sans Arabic', 'Tajawal', 'Amiri', 'Cairo', sans-serif !important;
	}

	/* Responsive adjustments for RTL */
	@media (max-width: 768px) {
		:global([dir="rtl"] .header-content) {
			text-align: right;
		}
		
		:global([dir="rtl"] .user-details h1) {
			text-align: right;
		}
		
		:global([dir="rtl"] .user-details p) {
			text-align: right;
		}
	}
</style>