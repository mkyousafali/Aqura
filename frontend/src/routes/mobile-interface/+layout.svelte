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
	import { initI18n, currentLocale, localeData, switchLocale } from '$lib/i18n';
	import LanguageToggle from '$lib/components/mobile-interface/common/LanguageToggle.svelte';
	import IncomingCallOverlay from '$lib/components/common/IncomingCallOverlay.svelte';
	import { updateAvailable, triggerUpdate } from '$lib/stores/appUpdate';
	import { waUnreadCounts, initWAUnreadMonitoring, stopWAUnreadMonitoring } from '$lib/stores/waUnreadCount';

	async function handleUpdateClick() {
		const fn = $triggerUpdate;
		if (fn) await fn();
	}

	// Mobile-specific layout state
	let currentUserData = null;
	let isLoading = true;
	let hasApprovalPermission = false;
	let hasPVPermission = false;
	let hasReportsPermission = false;
	let hasBranchPerformancePermission = false;
	let hasIncidentManagerPermission = false;
	let hasLiveChatPermission = false;

	// Badge counts
	let taskCount = 0;
	let notificationCount = 0;
	let assignmentCount = 0;
	let approvalCount = 0;
	let incidentCount = 0;
	let teamReceivingTaskCount = 0;
	
	// Employee display name from hr_employee_master
	let employeeName = '';
	
	// Global header notification count (separate from bottom nav)
	let headerNotificationCount = 0;
	
	// Previous notification count for sound detection
	let previousNotificationCount = 0;
	let isInitialLoad = true; // Flag to prevent sounds on initial page load
	
	// Refresh state for notifications
	let isRefreshing = false;
	
	// Menu state
	let showMenu = false;
	
	// HR Menu state
	let showHRMenu = false;
	
	// Tasks Menu state
	let showTasksMenu = false;
	
	// Emergencies Menu state
	let showEmergenciesMenu = false;
	
	// Stock Menu state
	let showStockMenu = false;
	
	// Orders Menu state
	let showOrdersMenu = false;
	
	// Orders count for badge
	let newOrdersCount = 0;
	
	// Mobile version - will be extracted from full version
	let mobileVersion = 'AQ28';
	
	// Reactive page title that updates when route changes or locale changes
	$: pageTitle = getPageTitle($page.url.pathname, $currentLocale);

	// Reset employee name when locale changes so it re-fetches with correct language
	$: if ($currentLocale) {
		employeeName = '';
		if (currentUserData) loadBadgeCounts(true);
	}

	onMount(() => {
		// CRITICAL: Set maximum timeout to prevent infinite loading
		const maxLoadingTimeout = setTimeout(() => {
			console.warn('⚠️ Mobile: Maximum loading timeout (3s) reached, forcing app to load');
			isLoading = false;
		}, 3000); // 3 seconds maximum
		
		// Initialize i18n system (will load from localStorage or use default 'ar')
		initI18n();
		
		// If no locale is set yet, default to Arabic
		const storedLocale = typeof window !== 'undefined' ? localStorage.getItem('aqura-locale') : null;
		if (!storedLocale) {
			switchLocale('ar');
			console.log('🌐 Mobile: Locale defaulted to Arabic (ar)');
		} else {
			console.log('🌐 Mobile: Locale loaded from storage:', storedLocale);
		}
		
		// Skip authentication check if on login page
		const isLoginPage = $page.url.pathname === '/mobile-interface/login';
		if (isLoginPage) {
			clearTimeout(maxLoadingTimeout);
			isLoading = false;
			return;
		}
		
		// Check authentication with timeout protection
		const checkAuth = async () => {
			try {
				// Wait for auth to initialize with 2 second timeout
				const authPromise = persistentAuthService.initializeAuth();
				const timeoutPromise = new Promise((_, reject) => 
					setTimeout(() => reject(new Error('Auth timeout')), 2000)
				);
				
				await Promise.race([authPromise, timeoutPromise]);
				console.log('✅ Mobile: Auth initialization completed');
			} catch (error) {
				console.error('❌ Mobile: Auth initialization failed:', error);
			}
			
			// Check authentication state
			if (!$isAuthenticated) {
				clearTimeout(maxLoadingTimeout);
				isLoading = false;
				goto('/mobile-interface/login');
				return;
			}

			// Ensure mobile preference is maintained for this user
			if ($currentUser) {
				interfacePreferenceService.forceMobileInterface($currentUser.id);
			}

			// Check interface preference to ensure user should be in mobile interface
			const userId = $currentUser?.id;
			if (userId && !interfacePreferenceService.isMobilePreferred(userId)) {
				clearTimeout(maxLoadingTimeout);
				isLoading = false;
				goto('/');
				return;
			}

			currentUserData = $currentUser;
			clearTimeout(maxLoadingTimeout);
			isLoading = false;

			// Load badge counts
			loadBadgeCounts();
			
			// Load button permissions
			loadButtonPermissions();
			
			// Initialize WA unread count monitoring
			initWAUnreadMonitoring();
			
			// Initialize notification sound system for mobile
			// 🔴 DISABLED: Real-time notification listener disabled
			// startNotificationListener();
			
			// Set up mobile audio unlock on first user interaction
			setupMobileAudioUnlock();
			
			// Set up periodic refresh of badge counts
			const interval = setInterval(() => loadBadgeCounts(true), 30000); // Silent refresh every 30 seconds
			return () => clearInterval(interval);
		};
		
		checkAuth();
	});

	// Subscribe to auth changes
	$: if (!$isAuthenticated && !isLoading && $page.url.pathname !== '/mobile-interface/login') {
		// If user logs out, redirect to mobile login (but not if already on login page)
		console.log('🔐 Mobile: Auth state changed to false, redirecting to login');
		isLoading = false; // Ensure loading is false before redirect
		goto('/mobile-interface/login');
	}

	// Ensure mobile preference is maintained when user changes
	$: if ($currentUser && $isAuthenticated) {
		console.log('🔐 Mobile: User authenticated, maintaining mobile preference');
		interfacePreferenceService.forceMobileInterface($currentUser.id);
		currentUserData = $currentUser;
		
		// Ensure loading is false when authenticated
		if (isLoading) {
			console.log('✅ Mobile: Auth confirmed, setting loading to false');
			isLoading = false;
		}
		
		loadBadgeCounts(true); // Silent refresh counts when user changes
		loadButtonPermissions(); // Load button permissions when user changes
		
		// Restart notification sound system for new user
		// 🔴 DISABLED: Real-time notification listener disabled
		// startNotificationListener();
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
			// Load employee display name from hr_employee_master
			if (!employeeName) {
				const { data: empData } = await supabase
					.from('hr_employee_master')
					.select('name_en, name_ar')
					.eq('user_id', currentUserData.id)
					.maybeSingle();
				if (empData) {
					const isArabic = $currentLocale === 'ar';
					employeeName = isArabic
						? (empData.name_ar || empData.name_en || '')
						: (empData.name_en || empData.name_ar || '');
				}
			}

			// Check PV Manager permission
			const { data: pvPermissions } = await supabase
				.from('button_permissions')
				.select(`
					button_id,
					sidebar_buttons!inner(button_code)
				`)
				.eq('user_id', currentUserData.id)
				.eq('is_enabled', true)
				.eq('sidebar_buttons.button_code', 'PURCHASE_VOUCHER_MANAGER');
			
			hasPVPermission = currentUserData.isMasterAdmin || (pvPermissions && pvPermissions.length > 0);

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

		// Load team receiving task pending count via RPC
		try {
			const { data: rpcData } = await supabase.rpc('get_receiving_tasks_for_user', {
				p_user_id: currentUserData.id,
				p_completed_days: 0
			});
			if (rpcData?.team_tasks) {
				teamReceivingTaskCount = rpcData.team_tasks.filter((t: any) => t.task_status !== 'completed').length;
			}
		} catch (e) {
			console.warn('Could not load team receiving task count:', e);
		}

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
					supabase
						.from('expense_requisitions')
						.select('*', { count: 'exact', head: true })
						.eq('approver_id', currentUserData.id)
						.eq('status', 'pending'),

					supabase
						.from('non_approved_payment_scheduler')
						.select('*', { count: 'exact', head: true })
						.eq('approver_id', currentUserData.id)
						.eq('approval_status', 'pending')
						.or('schedule_type.eq.multiple_bill,and(schedule_type.eq.single_bill,due_date.lte.' + twoDaysDate + ')')
				]);					approvalCount = (reqResult.count || 0) + (scheduleResult.count || 0);
				} else {
					approvalCount = 0;
				}
			}
			
			// Load unresolved incident count - check permission directly
			try {
				// First check if user has any incident receive permission
				const { data: incidentPerms } = await supabase
					.from('approval_permissions')
					.select('can_receive_customer_incidents, can_receive_employee_incidents, can_receive_maintenance_incidents, can_receive_vendor_incidents, can_receive_vehicle_incidents, can_receive_government_incidents, can_receive_other_incidents, can_receive_finance_incidents, can_receive_pos_incidents')
					.eq('user_id', currentUserData.id)
					.eq('is_active', true)
					.single();
				
				const hasAnyIncidentPerm = incidentPerms && (
					incidentPerms.can_receive_customer_incidents ||
					incidentPerms.can_receive_employee_incidents ||
					incidentPerms.can_receive_maintenance_incidents ||
					incidentPerms.can_receive_vendor_incidents ||
					incidentPerms.can_receive_vehicle_incidents ||
					incidentPerms.can_receive_government_incidents ||
					incidentPerms.can_receive_other_incidents ||
					incidentPerms.can_receive_finance_incidents ||
					incidentPerms.can_receive_pos_incidents
				);
				
				if (hasAnyIncidentPerm) {
					hasIncidentManagerPermission = true;
					const { count: incCount } = await supabase
						.from('incidents')
						.select('id', { count: 'exact', head: true })
						.contains('reports_to_user_ids', [currentUserData.id])
						.neq('resolution_status', 'resolved');
					incidentCount = incCount || 0;
				} else {
					hasIncidentManagerPermission = false;
					incidentCount = 0;
				}
			} catch (incErr) {
				console.warn('Error loading incident count:', incErr);
				incidentCount = 0;
			}

			// Load new orders count for badge
			try {
				const { count: ordCount } = await supabase
					.from('orders')
					.select('id', { count: 'exact', head: true })
					.eq('order_status', 'new');
				newOrdersCount = ordCount || 0;
			} catch (e) {
				console.warn('Error loading new orders count:', e);
			}

		} catch (error) {
			if (!silent) {
				console.error('Error loading task counts:', error);
			}
		}

		// Load assignment counts (tasks assigned BY the user to others)
		try {
			const { count: regularCount } = await supabase
				.from('task_assignments')
				.select('id', { count: 'exact', head: true })
				.eq('assigned_by', currentUserData.id)
				.neq('status', 'completed')
				.neq('status', 'cancelled');

			// Get quick tasks created/assigned by this user
			const { data: myQuickTasks } = await supabase
				.from('quick_tasks')
				.select('id')
				.eq('assigned_by', currentUserData.id);

			let quickCount = 0;
			if (myQuickTasks && myQuickTasks.length > 0) {
				const quickTaskIds = myQuickTasks.map(qt => qt.id);
				const { count } = await supabase
					.from('quick_task_assignments')
					.select('id', { count: 'exact', head: true })
					.in('quick_task_id', quickTaskIds)
					.neq('status', 'completed')
					.neq('status', 'cancelled');
				quickCount = count || 0;
			}

			assignmentCount = (regularCount || 0) + quickCount;
		} catch (e) {
			console.warn('Error loading assignment counts:', e);
		}

		// Load unread notification count
		try {
			const notificationsResult = await notificationManagement.getUserNotifications(currentUserData.id);

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

		} catch (error) {
			if (!silent) {
				console.error('Error loading notification counts:', error);
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
	
	async function loadButtonPermissions() {
		if (!currentUserData?.id) {
			hasReportsPermission = false;
			hasBranchPerformancePermission = false;
			hasLiveChatPermission = false;
			return;
		}

		try {
			// Load button permissions from database
			const { data: permissions, error } = await supabase
				.from('button_permissions')
				.select('button_id, is_enabled')
				.eq('user_id', currentUserData.id)
				.eq('is_enabled', true);

			if (error) {
				console.error('Error loading button permissions:', error);
				hasReportsPermission = false;
				hasBranchPerformancePermission = false;
				hasLiveChatPermission = false;
				return;
			}

			if (permissions && permissions.length > 0) {
				const buttonIds = permissions.map(p => p.button_id);
				console.log('📋 Mobile: Button IDs from permissions:', buttonIds);

				// Fetch button codes for enabled buttons
				const { data: buttons, error: btnError } = await supabase
					.from('sidebar_buttons')
					.select('id, button_code')
					.in('id', buttonIds);

				if (btnError) {
					console.error('Error fetching button codes:', btnError);
					hasReportsPermission = false;
					hasBranchPerformancePermission = false;
					hasLiveChatPermission = false;
				} else if (buttons) {
					console.log('📋 Mobile: All button codes from database:', buttons.map(b => b.button_code));
					const buttonCodes = new Set(buttons.map(b => b.button_code));
					
					// Check for specific button permissions
					hasReportsPermission = buttonCodes.has('SALES_REPORT');
					hasBranchPerformancePermission = buttonCodes.has('BRANCH_PERFORMANCE');
					hasLiveChatPermission = buttonCodes.has('WA_LIVE_CHAT');
					
					console.log('✅ Mobile button permissions:', {
						reports: hasReportsPermission,
						branchPerformance: hasBranchPerformancePermission,
						allCodes: Array.from(buttonCodes)
					});
				}
			} else {
				hasReportsPermission = false;
				hasBranchPerformancePermission = false;
				hasLiveChatPermission = false;
			}
			
			// Check for incident manager permission from approval_permissions
			await loadIncidentManagerPermission();
		} catch (err) {
			console.error('Error loading button permissions:', err);
			hasReportsPermission = false;
			hasBranchPerformancePermission = false;
			hasLiveChatPermission = false;
		}
	}
	
	async function loadIncidentManagerPermission() {
		if (!currentUserData?.id) {
			hasIncidentManagerPermission = false;
			return;
		}
		
		try {
			// Check if user has any incident receive permission
			const { data, error } = await supabase
				.from('approval_permissions')
				.select('can_receive_customer_incidents, can_receive_employee_incidents, can_receive_maintenance_incidents, can_receive_vendor_incidents, can_receive_vehicle_incidents, can_receive_government_incidents, can_receive_other_incidents, can_receive_finance_incidents, can_receive_pos_incidents')
				.eq('user_id', currentUserData.id)
				.eq('is_active', true)
				.single();
			
			if (error || !data) {
				hasIncidentManagerPermission = false;
				return;
			}
			
			// Check if any incident permission is true
			hasIncidentManagerPermission = (
				data.can_receive_customer_incidents ||
				data.can_receive_employee_incidents ||
				data.can_receive_maintenance_incidents ||
				data.can_receive_vendor_incidents ||
				data.can_receive_vehicle_incidents ||
				data.can_receive_government_incidents ||
				data.can_receive_other_incidents ||
				data.can_receive_finance_incidents ||
				data.can_receive_pos_incidents
			);
			
			console.log('✅ Mobile incident manager permission:', hasIncidentManagerPermission);
		} catch (err) {
			console.error('Error checking incident manager permission:', err);
			hasIncidentManagerPermission = false;
		}
	}

	function getPageTitle(path, locale = null) {
		// Main pages
		if (path === '/mobile-interface' || path === '/mobile-interface/') return getTranslation('mobile.dashboard');
		if (path === '/mobile-interface/tasks' || path === '/mobile-interface/tasks/') return getTranslation('mobile.tasks');
		if (path === '/mobile-interface/notifications' || path === '/mobile-interface/notifications/') return getTranslation('mobile.notifications');
		if (path === '/mobile-interface/assignments' || path === '/mobile-interface/assignments/') return getTranslation('mobile.assignments');
		if (path === '/mobile-interface/approval-center' || path === '/mobile-interface/approval-center/') return getTranslation('mobile.approvals');
		if (path === '/mobile-interface/quick-task' || path === '/mobile-interface/quick-task/') return getTranslation('mobile.quickTask');
		if (path === '/mobile-interface/day-off-request' || path === '/mobile-interface/day-off-request/') return getTranslation('mobile.leaveRequest');
		if (path === '/mobile-interface/fingerprint-analysis' || path === '/mobile-interface/fingerprint-analysis/') return getTranslation('mobile.fingerprintAnalysis');
		if (path === '/mobile-interface/purchase-voucher' || path === '/mobile-interface/purchase-voucher/') return getTranslation('mobile.purchaseVoucher.title');
		if (path === '/mobile-interface/my-checklist' || path === '/mobile-interface/my-checklist/') return getTranslation('hr.dailyChecklist.myDailyChecklist');
		if (path === '/mobile-interface/ai-chat' || path === '/mobile-interface/ai-chat/') return getTranslation('mobile.bottomNav.aiChat');
		if (path === '/mobile-interface/product-request' || path === '/mobile-interface/product-request/') return getTranslation('mobile.productRequest');
		if (path === '/mobile-interface/near-expiry' || path === '/mobile-interface/near-expiry/') return getTranslation('mobile.nearExpiry');
		if (path === '/mobile-interface/expiry-manager' || path === '/mobile-interface/expiry-manager/') return locale === 'ar' ? 'إدارة الصلاحية' : 'Expiry Manager';
		if (path === '/mobile-interface/price-checker' || path === '/mobile-interface/price-checker/') return locale === 'ar' ? 'فحص الأسعار' : 'Price Checker';
		if (path === '/mobile-interface/my-products' || path === '/mobile-interface/my-products/') return locale === 'ar' ? 'منتجاتي' : 'My Products';
		if (path === '/mobile-interface/communication' || path === '/mobile-interface/communication/') return locale === 'ar' ? 'اتصال ورسائل' : 'Call & Message';
		if (path === '/mobile-interface/live-chat' || path === '/mobile-interface/live-chat/') return locale === 'ar' ? 'دعم برنامج الولاء' : 'Loyalty Program Support';
		if (path === '/mobile-interface/break-register' || path === '/mobile-interface/break-register/') return locale === 'ar' ? 'سجل الاستراحة' : 'Break Register';
		
		// Sub-pages
		if (path.startsWith('/mobile-interface/tasks/assign')) return getTranslation('mobile.assignTasks');
		if (path.startsWith('/mobile-interface/tasks/create')) return getTranslation('mobile.createTask');
		if (path.includes('/complete')) return getTranslation('mobile.completeTask');
		if (path.startsWith('/mobile-interface/tasks/')) return getTranslation('mobile.taskDetails');
		if (path.startsWith('/mobile-interface/notifications/create')) return getTranslation('mobile.createNotification');
		if (path.startsWith('/mobile-interface/notifications/')) return getTranslation('mobile.notification');
		if (path === '/mobile-interface/assignments/completed' || path === '/mobile-interface/assignments/completed/') return getTranslation('mobile.completedAssignments.title');
		if (path.startsWith('/mobile-interface/assignments/')) return getTranslation('mobile.assignmentDetails');
		
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
			goto('/mobile-interface');
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
{:else if $page.url.pathname === '/mobile-interface/login'}
	<!-- Login page: render without layout chrome -->
	<slot />
{:else if $isAuthenticated}
	<div class="mobile-layout">
		<!-- Global Mobile Header -->
		<header class="global-mobile-header">
			<div class="header-content">
				<div class="user-info">
					<button class="menu-btn" on:click={() => showMenu = !showMenu} aria-label="Menu">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<line x1="3" y1="6" x2="21" y2="6"/>
							<line x1="3" y1="12" x2="21" y2="12"/>
							<line x1="3" y1="18" x2="21" y2="18"/>
						</svg>
					</button>
					<div class="user-details">
						<h1>{pageTitle}</h1>
						<p>{employeeName || currentUserData?.name || currentUserData?.username || 'User'}</p>
					</div>
				</div>
				<div class="header-actions">
					{#if $updateAvailable}
						<button class="header-nav-btn update-btn" on:click={handleUpdateClick} aria-label={$currentLocale === 'ar' ? 'تحديث متاح' : 'Update Available'} title={$currentLocale === 'ar' ? 'تحديث متاح' : 'Update Available'}>
							<div class="nav-icon-container">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
									<path d="M3 3v5h5"/>
									<path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/>
									<path d="M16 16h5v5"/>
								</svg>
								<span class="update-dot"></span>
							</div>
						</button>
					{:else}
						<span class="header-nav-btn uptodate-btn" title={$currentLocale === 'ar' ? 'محدّث' : 'Up to Date'}>
							<div class="nav-icon-container">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 6L9 17l-5-5"/>
								</svg>
							</div>
						</span>
					{/if}
					<a href="/mobile-interface" class="header-nav-btn" class:active={$page.url.pathname === '/mobile-interface'} aria-label={getTranslation('mobile.home')}>
						<div class="nav-icon-container">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
								<polyline points="9 22 9 12 15 12 15 22"/>
							</svg>
						</div>
					</a>
					<a href="/mobile-interface/notifications" class="header-nav-btn" class:active={$page.url.pathname.startsWith('/mobile-interface/notifications')} aria-label={getTranslation('nav.viewNotifications')}>
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
					{#if $page.url.pathname.startsWith('/mobile-interface/notifications')}
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
			{#if hasReportsPermission}
				<a href="/mobile-interface/reports" class="menu-item" on:click={() => showMenu = false} title={getTranslation('reports.salesReport')}>
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
					<span class="menu-item-text">{getTranslation('reports.salesReport')}</span>
				</a>
			{/if}
			<a href="/mobile-interface/approval-center" class="menu-item" on:click={() => showMenu = false} title={getTranslation('mobile.approvals')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
				<span class="menu-item-text">{getTranslation('mobile.approvals')}</span>
				{#if approvalCount > 0}
					<span class="menu-badge">{approvalCount > 99 ? '99+' : approvalCount}</span>
				{/if}
			</a>
			{#if hasPVPermission}
				<a href="/mobile-interface/purchase-voucher" class="menu-item" on:click={() => showMenu = false} title={getTranslation('mobile.bottomNav.purchaseVoucher')}>
					<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<rect x="2" y="4" width="20" height="16" rx="2"/>
						<path d="M7 9h10M7 13h6M7 17h4"/>
						<circle cx="17" cy="15" r="2"/>
					</svg>
					<span class="menu-item-text">{getTranslation('mobile.bottomNav.purchaseVoucher')}</span>
				</a>
			{/if}
			<div class="menu-item menu-language" title={getTranslation('mobile.language')} on:click={(e) => {
				const languageBtn = e.currentTarget.querySelector('.language-btn');
				if (languageBtn) languageBtn.click();
			}}>
				<LanguageToggle />
				<span class="menu-item-text">{getTranslation('mobile.language')}</span>
			</div>
			<div class="menu-item menu-version-item">
				<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<circle cx="12" cy="12" r="10"/>
					<line x1="12" y1="16" x2="12" y2="12"/>
					<line x1="12" y1="8" x2="12.01" y2="8"/>
				</svg>
				<span class="menu-item-text">{mobileVersion}</span>
			</div>
			<div class="menu-spacer"></div>
			<button class="menu-item menu-logout" on:click={() => { logout(); showMenu = false; }} title={getTranslation('mobile.logout')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
					<polyline points="16 17 21 12 16 7"/>
					<line x1="21" y1="12" x2="9" y2="12"/>
				</svg>
				<span class="menu-item-text">{getTranslation('mobile.logout')}</span>
			</button>
		</div>
	{/if}
	
	<!-- Mobile content goes here -->
	<main class="mobile-content">
			<slot />
		</main>
		
		<!-- Global Bottom Navigation Bar -->
		<nav class="bottom-nav">
			<!-- Orders / Delivery Menu Button (FIRST) -->
			<div class="nav-item-menu-container">
				<button class="nav-item orders-btn" on:click={() => { showOrdersMenu = !showOrdersMenu; showTasksMenu = false; showEmergenciesMenu = false; showHRMenu = false; showStockMenu = false; }} class:active={showOrdersMenu || $page.url.pathname.startsWith('/mobile-interface/orders-manager')}>
					{#if newOrdersCount > 0}
						<span class="nav-badge">{newOrdersCount > 99 ? '99+' : newOrdersCount}</span>
					{/if}
					<div class="nav-icon">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<rect x="1" y="3" width="15" height="13" rx="2"/>
							<path d="M16 8h4l3 3v5a2 2 0 0 1-2 2h-1"/>
							<circle cx="5.5" cy="18.5" r="2.5"/>
							<circle cx="18.5" cy="18.5" r="2.5"/>
						</svg>
					</div>
					<span class="nav-label">{$currentLocale === 'ar' ? 'الطلبات' : 'Orders'}</span>
				</button>
				
				<!-- Orders Submenu -->
				{#if showOrdersMenu}
					<!-- svelte-ignore a11y_click_events_have_key_events -->
					<!-- svelte-ignore a11y_no_static_element_interactions -->
					<div class="orders-submenu-overlay" on:click={() => showOrdersMenu = false}></div>
					<div class="orders-submenu">
						<a href="/mobile-interface/orders-manager" class="orders-submenu-item" on:click={() => showOrdersMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/orders-manager')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<rect x="1" y="3" width="15" height="13" rx="2"/>
								<path d="M16 8h4l3 3v5a2 2 0 0 1-2 2h-1"/>
								<circle cx="5.5" cy="18.5" r="2.5"/>
								<circle cx="18.5" cy="18.5" r="2.5"/>
							</svg>
							<span>{$currentLocale === 'ar' ? 'إدارة الطلبات' : 'Orders Manager'}</span>
							{#if newOrdersCount > 0}
								<span class="submenu-badge">{newOrdersCount > 99 ? '99+' : newOrdersCount}</span>
							{/if}
						</a>
					</div>
				{/if}
			</div>

			<!-- Tasks Menu Button -->
			<div class="nav-item-menu-container">
				<button class="nav-item tasks-btn" on:click={() => { showTasksMenu = !showTasksMenu; showOrdersMenu = false; showHRMenu = false; showEmergenciesMenu = false; showStockMenu = false; }} class:active={showTasksMenu || $page.url.pathname.startsWith('/mobile-interface/tasks') || $page.url.pathname.startsWith('/mobile-interface/assignments') || $page.url.pathname.startsWith('/mobile-interface/branch-performance') || $page.url.pathname.startsWith('/mobile-interface/team-receiving-tasks')}>
					{#if taskCount > 0}
						<span class="nav-badge">{taskCount > 99 ? '99+' : taskCount}</span>
					{/if}
					<div class="nav-icon">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
							<rect x="9" y="7" width="6" height="5"/>
						</svg>
					</div>
					<span class="nav-label">{getTranslation('mobile.bottomNav.tasks')}</span>
				</button>
				
				<!-- Tasks Submenu -->
				{#if showTasksMenu}
					<div class="tasks-submenu-overlay" on:click={() => showTasksMenu = false}></div>
					<div class="tasks-submenu">
						<a href="/mobile-interface/tasks" class="tasks-submenu-item" on:click={() => showTasksMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/tasks')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
								<rect x="9" y="7" width="6" height="5"/>
							</svg>
							<span>{getTranslation('mobile.bottomNav.tasks')}</span>
							{#if taskCount > 0}
								<span class="submenu-badge">{taskCount > 99 ? '99+' : taskCount}</span>
							{/if}
						</a>
						<a href="/mobile-interface/assignments" class="tasks-submenu-item" on:click={() => showTasksMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/assignments')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
							</svg>
							<span>{getTranslation('mobile.assignments')}</span>
							{#if assignmentCount > 0}
								<span class="submenu-badge">{assignmentCount > 99 ? '99+' : assignmentCount}</span>
							{/if}
						</a>
						<a href="/mobile-interface/team-receiving-tasks" class="tasks-submenu-item" on:click={() => showTasksMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/team-receiving-tasks')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
								<circle cx="9" cy="7" r="4"/>
								<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
								<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
							</svg>
							<span>{$localeData.code === 'ar' ? 'مهام فريق الاستلام' : 'Team Receiving Tasks'}</span>
							{#if teamReceivingTaskCount > 0}
								<span class="submenu-badge">{teamReceivingTaskCount > 99 ? '99+' : teamReceivingTaskCount}</span>
							{/if}
						</a>
						{#if hasBranchPerformancePermission}
							<a href="/mobile-interface/branch-performance" class="tasks-submenu-item" on:click={() => showTasksMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/branch-performance')}>
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M12 2v20M2 12h20M3 6h18M3 18h18"/>
									<rect width="6" height="8" x="3" y="12" rx="1"/>
									<rect width="6" height="12" x="9" y="8" rx="1"/>
									<rect width="6" height="6" x="15" y="14" rx="1"/>
								</svg>
								<span>{getTranslation('mobile.dashboardContent.branchPerformance.title')}</span>
							</a>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Emergencies Menu Button -->
			<div class="nav-item-menu-container">
				<button class="nav-item emergencies-btn" on:click={() => { showEmergenciesMenu = !showEmergenciesMenu; showOrdersMenu = false; showHRMenu = false; showTasksMenu = false; showStockMenu = false; }} class:active={showEmergenciesMenu || $page.url.pathname.startsWith('/mobile-interface/report-incident') || $page.url.pathname.startsWith('/mobile-interface/incident-manager') || $page.url.pathname.startsWith('/mobile-interface/live-chat')}>
					{#if incidentCount > 0}
						<span class="nav-badge incident-badge">{incidentCount > 99 ? '99+' : incidentCount}</span>
					{/if}
					<div class="nav-icon">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
							<line x1="12" y1="9" x2="12" y2="13"/>
							<line x1="12" y1="17" x2="12.01" y2="17"/>
						</svg>
					</div>
					<span class="nav-label">{getTranslation('mobile.emergencies')}</span>
				</button>
				
				<!-- Emergencies Submenu -->
				{#if showEmergenciesMenu}
					<div class="emergencies-submenu-overlay" on:click={() => showEmergenciesMenu = false}></div>
					<div class="emergencies-submenu">
						<a href="/mobile-interface/report-incident" class="emergencies-submenu-item" on:click={() => showEmergenciesMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/report-incident')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
								<polyline points="14 2 14 8 20 8"/>
								<line x1="12" y1="18" x2="12" y2="12"/>
								<line x1="9" y1="15" x2="15" y2="15"/>
							</svg>
							<span>{getTranslation('mobile.reportIncident')}</span>
						</a>
						{#if hasIncidentManagerPermission}
							<a href="/mobile-interface/incident-manager" class="emergencies-submenu-item" on:click={() => showEmergenciesMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/incident-manager')}>
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
									<rect x="9" y="3" width="6" height="4" rx="1"/>
									<path d="M9 12h6"/>
									<path d="M9 16h6"/>
								</svg>
								<span>{getTranslation('mobile.incidentManager')}</span>
							</a>
						{/if}
						<!-- Communication (Call & Message) -->
						<a href="/mobile-interface/communication" class="emergencies-submenu-item" on:click={() => showEmergenciesMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/communication')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
							</svg>
							<span>{$currentLocale === 'ar' ? 'اتصال ورسائل' : 'Call & Message'}</span>
						</a>
						{#if hasLiveChatPermission}
							<!-- Loyalty Program Support -->
							<a href="/mobile-interface/live-chat" class="emergencies-submenu-item" on:click={() => showEmergenciesMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/live-chat')}>
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M21 11.5a8.38 8.38 0 01-.9 3.8 8.5 8.5 0 01-7.6 4.7 8.38 8.38 0 01-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 01-.9-3.8 8.5 8.5 0 014.7-7.6 8.38 8.38 0 013.8-.9h.5a8.48 8.48 0 018 8v.5z"/>
								</svg>
								<span>{$currentLocale === 'ar' ? 'دعم برنامج الولاء' : 'Loyalty Program Support'}</span>
								{#if $waUnreadCounts.total > 0}
									<span class="wa-unread-badge">{$waUnreadCounts.total > 99 ? '99+' : $waUnreadCounts.total}</span>
								{/if}
							</a>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Human Resources Menu Button -->
			<div class="nav-item-menu-container">
				<button class="nav-item hr-menu-btn" on:click={() => { showHRMenu = !showHRMenu; showOrdersMenu = false; showTasksMenu = false; showEmergenciesMenu = false; showStockMenu = false; }} class:active={showHRMenu || $page.url.pathname.startsWith('/mobile-interface/day-off-request')}>
					<div class="nav-icon">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
							<circle cx="9" cy="7" r="4"/>
							<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
							<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
						</svg>
					</div>
					<span class="nav-label">{getTranslation('mobile.humanResources')}</span>
				</button>
				
				<!-- HR Submenu -->
				{#if showHRMenu}
					<div class="hr-submenu-overlay" on:click={() => showHRMenu = false}></div>
					<div class="hr-submenu">
						<a href="/mobile-interface/day-off-request" class="hr-submenu-item" on:click={() => showHRMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/day-off-request')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M8 2v4m8-4v4M4 4h16a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"/>
								<path d="M3 10h18"/>
								<path d="M12 14v4m-3-2h6"/>
							</svg>
							<span>{getTranslation('mobile.leaveRequest')}</span>
						</a>
						<a href="/mobile-interface/fingerprint-analysis" class="hr-submenu-item" on:click={() => showHRMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/fingerprint-analysis')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M12 19.5C16.97 19.5 21 15.47 21 10.5S16.97 1.5 12 1.5 3 5.53 3 10.5 7.03 19.5 12 19.5Z"/>
								<path d="M12 3v14M7.5 8h9"/>
								<path d="M10 13h4"/>
							</svg>
							<span>{getTranslation('mobile.fingerprintAnalysis')}</span>
						</a>
					</div>
				{/if}
			</div>

			<!-- Stock Menu Button -->
			<div class="nav-item-menu-container">
				<button class="nav-item stock-menu-btn" on:click={() => { showStockMenu = !showStockMenu; showOrdersMenu = false; showTasksMenu = false; showEmergenciesMenu = false; showHRMenu = false; }} class:active={showStockMenu || $page.url.pathname.startsWith('/mobile-interface/product-request') || $page.url.pathname.startsWith('/mobile-interface/near-expiry') || $page.url.pathname.startsWith('/mobile-interface/expiry-manager') || $page.url.pathname.startsWith('/mobile-interface/price-checker') || $page.url.pathname.startsWith('/mobile-interface/my-products') }>
					<div class="nav-icon">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
						</svg>
					</div>
					<span class="nav-label">{getTranslation('mobile.bottomNav.stock')}</span>
				</button>
				
				<!-- Stock Submenu -->
				{#if showStockMenu}
					<div class="stock-submenu-overlay" on:click={() => showStockMenu = false}></div>
					<div class="stock-submenu">
						<a href="/mobile-interface/product-request" class="stock-submenu-item" on:click={() => showStockMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/product-request')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
								<polyline points="14 2 14 8 20 8"/>
								<line x1="12" y1="18" x2="12" y2="12"/>
								<line x1="9" y1="15" x2="15" y2="15"/>
							</svg>
							<span>{getTranslation('mobile.productRequest')}</span>
						</a>
						<a href="/mobile-interface/near-expiry" class="stock-submenu-item" on:click={() => showStockMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/near-expiry')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<circle cx="12" cy="12" r="10"/>
								<polyline points="12 6 12 12 16 14"/>
							</svg>
							<span>{getTranslation('mobile.nearExpiry')}</span>
						</a>
						<a href="/mobile-interface/expiry-manager" class="stock-submenu-item" on:click={() => showStockMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/expiry-manager')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
								<line x1="16" y1="2" x2="16" y2="6"/>
								<line x1="8" y1="2" x2="8" y2="6"/>
								<line x1="3" y1="10" x2="21" y2="10"/>
								<path d="M15 15l2 2 4-4"/>
							</svg>
							<span>{$currentLocale === 'ar' ? 'إدارة الصلاحية' : 'Expiry Manager'}</span>
						</a>
						<a href="/mobile-interface/price-checker" class="stock-submenu-item" on:click={() => showStockMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/price-checker')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/>
								<line x1="7" y1="7" x2="7.01" y2="7"/>
							</svg>
							<span>{$currentLocale === 'ar' ? 'فحص الأسعار' : 'Price Checker'}</span>
						</a>
						<a href="/mobile-interface/my-products" class="stock-submenu-item" on:click={() => showStockMenu = false} class:active={$page.url.pathname.startsWith('/mobile-interface/my-products')}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
								<circle cx="12" cy="7" r="4"/>
							</svg>
							<span>{$currentLocale === 'ar' ? 'منتجاتي' : 'My Products'}</span>
						</a>
	
					</div>
				{/if}
			</div>

			<!-- AI Chat Button -->
			<a href="/mobile-interface/ai-chat" class="nav-item ai-chat-btn" class:active={$page.url.pathname.startsWith('/mobile-interface/ai-chat')} on:click={() => { showOrdersMenu = false; showTasksMenu = false; showEmergenciesMenu = false; showHRMenu = false; showStockMenu = false; }}>
				<div class="nav-icon ai-chat-icon">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
						<path d="M8 10h.01M12 10h.01M16 10h.01"/>
					</svg>
				</div>
				<span class="nav-label">{getTranslation('mobile.bottomNav.aiChat')}</span>
			</a>
		</nav>
	</div>

	<!-- Incoming Call Overlay -->
	<IncomingCallOverlay />
{:else}
	<div class="mobile-error">
		<h2>{getTranslation('mobile.error.accessRequired')}</h2>
		<p>{getTranslation('mobile.error.loginRequired')}</p>
		<button on:click={() => goto('/mobile-interface/login')} class="error-btn">
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

	.menu-version-item {
		background: rgba(59, 130, 246, 0.6) !important;
		cursor: default !important;
		pointer-events: none;
		font-family: 'Courier New', monospace;
		letter-spacing: 0.5px;
	}

	.menu-version-item:hover {
		transform: none !important;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3) !important;
	}

	.menu-spacer {
		flex: 1;
		min-height: 8px;
	}

	.menu-logout {
		background: #EF4444 !important;
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3) !important;
	}

	.menu-logout:hover {
		background: #DC2626 !important;
		box-shadow: 0 6px 20px rgba(220, 38, 38, 0.5) !important;
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
		width: 50px;
		height: 40px;
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
		bottom: 70px;
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
		justify-content: flex-start;
		padding: 0 16px;
		background: #3B82F6;
		border: none;
		min-width: 48px;
		height: 48px;
		border-radius: 24px;
		color: white;
		cursor: pointer;
		transition: all 0.25s ease;
		text-decoration: none;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
		gap: 12px;
		white-space: nowrap;
	}

	.menu-item:last-child {
		border-bottom: none;
	}

	.menu-item:hover {
		background: #2563EB;
		transform: scale(1.05);
		box-shadow: 0 6px 20px rgba(37, 99, 235, 0.5);
	}

	.menu-item:active {
		transform: scale(0.95);
	}

	.menu-item svg {
		color: white;
		transition: all 0.25s ease;
		flex-shrink: 0;
	}

	.menu-item:hover svg {
		color: white;
	}

	.menu-item-text {
		font-size: 0.9rem;
		font-weight: 500;
		color: white;
		padding-right: 8px;
		pointer-events: none;
	}

	.menu-language {
		padding: 0 16px;
		background: #3B82F6;
		min-width: 48px;
		height: 48px;
		border-radius: 24px;
		display: flex;
		align-items: center;
		justify-content: flex-start;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
		gap: 12px;
		cursor: pointer;
	}

	.menu-language:hover {
		background: #2563EB;
		transform: scale(1.05);
		box-shadow: 0 6px 20px rgba(37, 99, 235, 0.5);
	}

	.menu-language :global(*) {
		pointer-events: auto;
	}

	.menu-language .menu-item-text {
		pointer-events: none;
	}

	.menu-badge {
		background: #EF4444;
		color: white;
		font-size: 0.7rem;
		font-weight: 600;
		padding: 2px 6px;
		border-radius: 10px;
		min-width: 20px;
		text-align: center;
		margin-left: auto;
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

	.update-btn {
		background: rgba(34, 197, 94, 0.25) !important;
		border-color: rgba(34, 197, 94, 0.5) !important;
		animation: pulse-update 2s ease-in-out infinite;
	}

	.uptodate-btn {
		background: rgba(255, 255, 255, 0.08) !important;
		border-color: rgba(255, 255, 255, 0.15) !important;
		opacity: 0.6;
		cursor: default;
	}

	.update-dot {
		position: absolute;
		top: -2px;
		right: -2px;
		width: 6px;
		height: 6px;
		background: #22c55e;
		border-radius: 50%;
		border: 1px solid rgba(0, 0, 0, 0.3);
	}

	@keyframes pulse-update {
		0%, 100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.4); }
		50% { box-shadow: 0 0 6px 2px rgba(34, 197, 94, 0.3); }
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
		padding-bottom: calc(4rem + env(safe-area-inset-bottom, 0px)); /* Space for bottom nav + safe area (PWA) */
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

	.nav-badge.incident-badge {
		background: #DC2626;
		box-shadow: 0 2px 4px rgba(220, 38, 38, 0.4);
	}

	.nav-label {
		display: none;
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

	/* Special styling for PV button */
	.nav-item.pv-btn {
		color: #6B7280;
		text-decoration: none;
	}

	.nav-item.pv-btn:hover {
		color: #8B5CF6;
		background: rgba(139, 92, 246, 0.05);
	}

	.nav-item.pv-btn.active {
		color: #8B5CF6;
	}

	.nav-item.pv-btn.active .nav-icon {
		background: rgba(139, 92, 246, 0.1);
		color: #8B5CF6;
	}

	.nav-item.pv-btn .nav-label {
		font-weight: 600;
	}

	/* Human Resources Menu Styles */
	.nav-item-menu-container {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	/* Emergencies Button Styles */
	.nav-item.emergencies-btn {
		color: #DC2626;
	}

	.nav-item.emergencies-btn {
		border: none;
		background: none;
		cursor: pointer;
	}

	.nav-item.emergencies-btn:hover {
		color: #B91C1C;
		background: rgba(220, 38, 38, 0.05);
	}

	.nav-item.emergencies-btn.active {
		color: #DC2626;
	}

	.nav-item.emergencies-btn.active .nav-icon {
		background: rgba(220, 38, 38, 0.1);
		color: #DC2626;
	}

	.nav-item.emergencies-btn .nav-icon {
		color: #DC2626;
	}

	.nav-item.emergencies-btn .nav-label {
		font-weight: 600;
		color: #DC2626;
	}

	.nav-item.hr-menu-btn {
		border: none;
		background: none;
		cursor: pointer;
	}

	.nav-item.hr-menu-btn:hover {
		color: #EC4899;
		background: rgba(236, 72, 153, 0.05);
	}

	.nav-item.hr-menu-btn.active {
		color: #EC4899;
	}

	.nav-item.hr-menu-btn.active .nav-icon {
		background: rgba(236, 72, 153, 0.1);
		color: #EC4899;
	}

	.nav-item.hr-menu-btn .nav-label {
		font-weight: 600;
	}

	/* AI Chat Button styles */
	.nav-item.ai-chat-btn {
		border: none;
		background: none;
		cursor: pointer;
		position: relative;
	}

	.nav-item.ai-chat-btn:hover {
		color: #6366F1;
		background: rgba(99, 102, 241, 0.05);
	}

	.nav-item.ai-chat-btn.active {
		color: #6366F1;
	}

	.nav-item.ai-chat-btn.active .nav-icon {
		background: rgba(99, 102, 241, 0.1);
		color: #6366F1;
	}

	.nav-item.ai-chat-btn .nav-label {
		font-weight: 600;
		color: #6366F1;
	}

	.ai-chat-icon {
		position: relative;
	}

	.ai-chat-icon::after {
		content: '';
		position: absolute;
		top: 2px;
		right: 2px;
		width: 6px;
		height: 6px;
		background: #4ade80;
		border-radius: 50%;
		box-shadow: 0 0 6px rgba(74, 222, 128, 0.6);
		animation: ai-pulse 2s infinite;
	}

	@keyframes ai-pulse {
		0%, 100% { opacity: 1; box-shadow: 0 0 6px rgba(74, 222, 128, 0.6); }
		50% { opacity: 0.6; box-shadow: 0 0 10px rgba(74, 222, 128, 0.9); }
	}

	/* HR Submenu Styles */
	.hr-submenu-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 95;
	}

	.hr-submenu {
		position: fixed;
		bottom: 3.8rem;
		left: 50%;
		transform: translateX(-50%);
		background: white;
		border-radius: 12px;
		box-shadow: 0 -2px 16px rgba(0, 0, 0, 0.15);
		min-width: 180px;
		max-width: calc(100vw - 32px);
		z-index: 100;
		overflow: hidden;
		animation: slideUp 0.2s ease;
	}

	@supports selector(:dir(rtl)) {
		:dir(rtl) .hr-submenu {
			left: 50%;
			transform: translateX(-50%);
		}
	}

	/* Fallback for RTL using locale */
	:global([dir="rtl"]) .hr-submenu {
		left: 50%;
		transform: translateX(-50%);
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

	.hr-submenu-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		color: #374151;
		text-decoration: none;
		border: none;
		background: none;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
		text-align: left;
		border-bottom: 1px solid #E5E7EB;
	}

	.hr-submenu-item:last-child {
		border-bottom: none;
	}

	.hr-submenu-item:hover {
		background: #F3F4F6;
		color: #EC4899;
	}

	.hr-submenu-item.active {
		background: rgba(236, 72, 153, 0.1);
		color: #EC4899;
		font-weight: 600;
	}

	.hr-submenu-item svg {
		flex-shrink: 0;
	}

	/* Emergencies Submenu Styles */
	.emergencies-submenu-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 95;
	}

	.emergencies-submenu {
		position: fixed;
		bottom: 3.8rem;
		left: 50%;
		transform: translateX(-50%);
		background: white;
		border-radius: 12px;
		box-shadow: 0 -2px 16px rgba(220, 38, 38, 0.2);
		min-width: 180px;
		max-width: calc(100vw - 32px);
		z-index: 100;
		overflow: hidden;
		animation: slideUp 0.2s ease;
		border: 1px solid rgba(220, 38, 38, 0.2);
	}

	:global([dir="rtl"]) .emergencies-submenu {
		left: 50%;
		transform: translateX(-50%);
	}

	.emergencies-submenu-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		color: #374151;
		text-decoration: none;
		border: none;
		background: none;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
		text-align: left;
		border-bottom: 1px solid #E5E7EB;
	}

	.emergencies-submenu-item:last-child {
		border-bottom: none;
	}

	.emergencies-submenu-item:hover {
		background: rgba(220, 38, 38, 0.05);
		color: #DC2626;
	}

	.wa-unread-badge {
		background: #25D366;
		color: white;
		font-size: 11px;
		font-weight: 700;
		padding: 1px 6px;
		border-radius: 10px;
		margin-left: auto;
		min-width: 18px;
		text-align: center;
		line-height: 16px;
	}

	.emergencies-submenu-item.active {
		background: rgba(220, 38, 38, 0.1);
		color: #DC2626;
		font-weight: 600;
	}

	.emergencies-submenu-item svg {
		flex-shrink: 0;
		color: #DC2626;
	}

	/* Tasks Submenu Styles */
	.tasks-submenu-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 95;
	}

	.tasks-submenu {
		position: fixed;
		bottom: 3.8rem;
		left: 50%;
		transform: translateX(-50%);
		background: white;
		border-radius: 12px;
		box-shadow: 0 -2px 16px rgba(59, 130, 246, 0.2);
		min-width: 180px;
		max-width: calc(100vw - 32px);
		z-index: 100;
		overflow: hidden;
		animation: slideUp 0.2s ease;
		border: 1px solid rgba(59, 130, 246, 0.2);
	}

	:global([dir="rtl"]) .tasks-submenu {
		left: 50%;
		transform: translateX(-50%);
	}

	.tasks-submenu-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		color: #374151;
		text-decoration: none;
		border: none;
		background: none;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
		text-align: left;
		border-bottom: 1px solid #E5E7EB;
	}

	.tasks-submenu-item:last-child {
		border-bottom: none;
	}

	.tasks-submenu-item:hover {
		background: rgba(59, 130, 246, 0.05);
		color: #3B82F6;
	}

	.tasks-submenu-item.active {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
		font-weight: 600;
	}

	.tasks-submenu-item svg {
		flex-shrink: 0;
		color: #3B82F6;
	}

	.submenu-badge {
		background: #EF4444;
		color: white;
		font-size: 0.65rem;
		font-weight: 600;
		padding: 2px 6px;
		border-radius: 10px;
		min-width: 18px;
		height: 18px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-left: auto;
	}

	.nav-item.tasks-btn {
		color: #6B7280;
	}

	.nav-item.tasks-btn:hover {
		color: #3B82F6;
		background: rgba(59, 130, 246, 0.05);
	}

	.nav-item.tasks-btn.active {
		color: #3B82F6;
	}

	.nav-item.tasks-btn.active .nav-icon {
		color: #3B82F6;
	}

	/* Orders Button & Submenu Styles */
	.nav-item.orders-btn {
		color: #6B7280;
	}
	.nav-item.orders-btn:hover {
		color: #059669;
		background: rgba(5, 150, 105, 0.05);
	}
	.nav-item.orders-btn.active {
		color: #059669;
	}
	.nav-item.orders-btn.active .nav-icon {
		color: #059669;
	}

	.orders-submenu-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 95;
	}

	.orders-submenu {
		position: fixed;
		bottom: 3.8rem;
		left: 50%;
		transform: translateX(-50%);
		background: white;
		border-radius: 12px;
		box-shadow: 0 -2px 16px rgba(5, 150, 105, 0.2);
		min-width: 180px;
		max-width: calc(100vw - 32px);
		z-index: 100;
		overflow: hidden;
		animation: slideUp 0.2s ease;
		border: 1px solid rgba(5, 150, 105, 0.2);
	}

	:global([dir="rtl"]) .orders-submenu {
		left: 50%;
		transform: translateX(-50%);
	}

	.orders-submenu-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		color: #374151;
		text-decoration: none;
		border: none;
		background: none;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
		text-align: left;
		border-bottom: 1px solid #E5E7EB;
	}

	.orders-submenu-item:last-child {
		border-bottom: none;
	}

	.orders-submenu-item:hover {
		background: rgba(5, 150, 105, 0.05);
		color: #059669;
	}

	.orders-submenu-item.active {
		background: rgba(5, 150, 105, 0.1);
		color: #059669;
		font-weight: 600;
	}

	.orders-submenu-item svg {
		flex-shrink: 0;
		color: #059669;
	}

	/* Stock Submenu Styles */
	.stock-submenu-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 95;
	}

	.stock-submenu {
		position: fixed;
		bottom: 3.8rem;
		left: 50%;
		transform: translateX(-50%);
		background: white;
		border-radius: 12px;
		box-shadow: 0 -2px 16px rgba(245, 158, 11, 0.2);
		min-width: 180px;
		max-width: calc(100vw - 32px);
		z-index: 100;
		overflow: hidden;
		animation: slideUp 0.2s ease;
		border: 1px solid rgba(245, 158, 11, 0.2);
	}

	:global([dir="rtl"]) .stock-submenu {
		left: 50%;
		transform: translateX(-50%);
	}

	.stock-submenu-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		color: #374151;
		text-decoration: none;
		border: none;
		background: none;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
		text-align: left;
		border-bottom: 1px solid #E5E7EB;
	}

	.stock-submenu-item:last-child {
		border-bottom: none;
	}

	.stock-submenu-item:hover {
		background: rgba(245, 158, 11, 0.05);
		color: #F59E0B;
	}

	.stock-submenu-item.active {
		background: rgba(245, 158, 11, 0.1);
		color: #D97706;
		font-weight: 600;
	}

	.stock-submenu-item svg {
		flex-shrink: 0;
		color: #F59E0B;
	}

	.nav-item.stock-menu-btn {
		color: #6B7280;
	}

	.nav-item.stock-menu-btn:hover {
		color: #F59E0B;
		background: rgba(245, 158, 11, 0.05);
	}

	.nav-item.stock-menu-btn.active {
		color: #F59E0B;
	}

	.nav-item.stock-menu-btn.active .nav-icon {
		color: #F59E0B;
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

	:global([dir="rtl"] .user-info .back-btn) {
		order: 3;
	}

	:global([dir="rtl"] .user-info .menu-btn) {
		order: 2;
	}

	:global([dir="rtl"] .user-info .user-details) {
		order: 1;
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

