<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { currentLocale, switchLocale, getAvailableLocales } from '$lib/i18n';
	import { t } from '$lib/i18n';
	import { onMount, createEventDispatcher, tick } from 'svelte';
	import { get } from 'svelte/store';
	import { goto } from '$app/navigation';
	import { notificationCounts, fetchNotificationCounts, refreshNotificationCounts } from '$lib/stores/notifications';
	import { taskCounts, taskCountService } from '$lib/stores/taskCount';
	import { approvalCounts, initApprovalCountMonitoring, refreshApprovalCounts } from '$lib/stores/approvalCounts';
	import NotificationCenter from '$lib/components/desktop-interface/master/communication/NotificationCenter.svelte';
	import ApprovalCenter from '$lib/components/desktop-interface/master/finance/ApprovalCenter.svelte';
	import DailyChecklistWindow from '$lib/components/desktop-interface/master/tasks/DailyChecklistWindow.svelte';
	import IncidentManager from '$lib/components/desktop-interface/master/hr/IncidentManager.svelte';
	import { getSaudiDayOfWeek, isEmployeeDayOff, isAfterShiftStart, getShiftStartTime } from '$lib/utils/checklistHelpers';
	import { persistentAuthService, currentUser, deviceSessions } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { supabase } from '$lib/utils/supabase';
	import { initiateCall, sendTextMessage } from '$lib/stores/callStore';
	import WALiveChat from '$lib/components/desktop-interface/whatsapp/WALiveChat.svelte';
	import { waUnreadCounts, initWAUnreadMonitoring, stopWAUnreadMonitoring } from '$lib/stores/waUnreadCount';

	// Event dispatcher for communicating with layout
	const dispatch = createEventDispatcher();

	// Subscribe to taskbar items and auth state
	$: taskbarItems = windowManager.taskbarItems;
	$: activeWindow = windowManager.activeWindow;
	
	// Use persistent auth system
	// No need for displayUser variable anymore

	// Subscribe to notification counts store
	$: counts = $notificationCounts;
	
	// Subscribe to task counts store
	$: taskCountData = $taskCounts;

	// Subscribe to approval counts store
	$: approvalCountData = $approvalCounts;

	// Subscribe to WA unread counts store
	$: waUnreadData = $waUnreadCounts;

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

	// Pending checklist count
	let pendingChecklistCount = 0;

	// Unresolved incident count
	let unresolvedIncidentCount = 0;

	// Active orders count
	let activeOrderCount = 0;
	let ordersChannel: any = null;

	// Call popup state
	let showCallPopup = false;
	let callEmployees: any[] = [];
	let callSearchQuery = '';
	let loadingCallEmployees = false;

	// Text message popup state
	let showTextInput = false;
	let textTargetEmployee: any = null;
	let textInputValue = '';
	let textInputRef: HTMLTextAreaElement;

	$: filteredCallEmployees = callSearchQuery.trim()
		? callEmployees.filter(e => 
			(e.name_en || '').toLowerCase().includes(callSearchQuery.toLowerCase()) ||
			(e.name_ar || '').includes(callSearchQuery)
		)
		: callEmployees;

	onMount(() => {
		updateTime();
		timeInterval = setInterval(updateTime, 1000);
		
		// Fetch initial notification count
		fetchNotificationCounts();
		// Refresh count every 30 seconds
		const notificationInterval = setInterval(fetchNotificationCounts, 30000);
		
		// Initialize task count monitoring
		// 🔴 DISABLED: Task count monitoring disabled
		// taskCountService.initTaskCountMonitoring();
		
		// Initialize approval count monitoring
		initApprovalCountMonitoring();

		// Fetch initial pending checklist count
		fetchPendingChecklistCount();
		const checklistInterval = setInterval(fetchPendingChecklistCount, 60000);

		// Fetch initial unresolved incident count
		fetchUnresolvedIncidentCount();
		const incidentInterval = setInterval(fetchUnresolvedIncidentCount, 60000);

		// Fetch initial active orders count
		fetchActiveOrderCount();
		const ordersInterval = setInterval(fetchActiveOrderCount, 30000);
		setupOrdersRealtime();

		// Initialize WA unread count monitoring
		initWAUnreadMonitoring();
		
		return () => {
			if (timeInterval) clearInterval(timeInterval);
			if (notificationInterval) clearInterval(notificationInterval);
			if (checklistInterval) clearInterval(checklistInterval);
			if (incidentInterval) clearInterval(incidentInterval);
			if (ordersInterval) clearInterval(ordersInterval);
			if (ordersChannel) supabase.removeChannel(ordersChannel);
			stopWAUnreadMonitoring();
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
			// Use get() to access the current value of the windowList store
			const windows = get(windowManager.windowList);
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
		
		// Trigger hard refresh after a short delay to allow locale switch to complete
		setTimeout(() => {
			window.location.reload();
		}, 100);
	}

	function getLanguageDisplayName(locale: string): string {
		const localeData = availableLocales.find(l => l.code === locale);
		return localeData?.name || locale.toUpperCase();
	}

	function handleLogout() {
		console.log('🚪 [Taskbar] Handle logout clicked');
		console.log('🚪 [Taskbar] Current user:', $currentUser);
		console.log('🚪 [Taskbar] Current showLogoutConfirm state:', showLogoutConfirm);
		showLogoutConfirm = true;
		showUserMenu = false;
		console.log('🚪 [Taskbar] Logout confirmation dialog should show:', showLogoutConfirm);
		console.log('🚪 [Taskbar] showUserMenu set to:', showUserMenu);
	}

	// New handlers for persistent auth features
	function handleUserSwitchRequest() {
		showUserMenu = false;
		dispatch('user-switch-request');
	}

	function handleNotificationSettingsRequest() {
		showUserMenu = false;
		dispatch('notification-settings-request');
	}

	async function handlePersistentLogout() {
		try {
			await persistentAuthService.logout();
			showLogoutConfirm = false;
			showUserMenu = false;
		} catch (error) {
			console.error('Error during logout:', error);
		}
	}

	async function handleTestNotification() {
		try {
			await notificationService.sendTestNotification();
			showUserMenu = false;
		} catch (error) {
			console.error('Error sending test notification:', error);
		}
	}

	// Check if there are multiple users on device
	let hasMultipleUsers = false;
	$: {
		// Subscribe to device sessions to check for multiple users
		if ($deviceSessions && $deviceSessions.users) {
			hasMultipleUsers = $deviceSessions.users.filter(u => u.isActive).length > 1;
		}
	}

	async function confirmLogout() {
		console.log('🚪 [Taskbar] Confirming logout...');
		console.log('🚪 [Taskbar] Persistent auth user:', $currentUser);
		
		showLogoutConfirm = false;
		showUserMenu = false;
		
		try {
			console.log('🚪 [Taskbar] Calling logout methods...');
			
			// Logout from persistent auth
			if ($currentUser) {
				console.log('🚪 [Taskbar] Logging out from persistent auth...');
				await persistentAuthService.logout();
				console.log('🚪 [Taskbar] Persistent auth logout completed');
			}
			
			// Clear local storage manually as backup
			if (typeof window !== 'undefined' && window.localStorage) {
				console.log('🚪 [Taskbar] Clearing localStorage...');
				localStorage.removeItem('aqura-auth-token');
				localStorage.removeItem('aqura-user');
				localStorage.removeItem('aqura-session');
				localStorage.removeItem('aqura-persistent-sessions');
				localStorage.clear(); // Clear all local storage as extra measure
			}
			
			// Clear session storage too
			if (typeof window !== 'undefined' && window.sessionStorage) {
				console.log('🚪 [Taskbar] Clearing sessionStorage...');
				sessionStorage.clear();
			}
			
			console.log('🚪 [Taskbar] Logout completed, redirecting to login...');
			
			// Use a short delay to ensure cleanup completes
			setTimeout(() => {
				console.log('🚪 [Taskbar] Executing redirect to login...');
				window.location.href = '/login';
			}, 100);
			
		} catch (error) {
			console.error('🚪 [Taskbar] Logout error:', error);
			// Force redirect even if there's an error
			setTimeout(() => {
				console.log('🚪 [Taskbar] Error occurred, forcing redirect...');
				window.location.href = '/login';
			}, 100);
		}
	}

	function cancelLogout() {
		showLogoutConfirm = false;
	}

	// Quick access functions
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openDailyChecklist() {
		const windowId = generateWindowId('daily-checklist');
		openWindow({
			id: windowId,
			title: 'My Daily Checklist',
			component: DailyChecklistWindow,
			icon: '📒',
			size: { width: 800, height: 600 },
			position: { x: 150, y: 80 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function fetchPendingChecklistCount() {
		try {
			if (!$currentUser?.id) return;

			// Get employee ID
			const { data: empData } = await supabase
				.from('hr_employee_master')
				.select('id')
				.eq('user_id', $currentUser.id)
				.single();

			if (!empData) { pendingChecklistCount = 0; return; }

			// Check day off
			const dayOff = await isEmployeeDayOff(empData.id);
			if (dayOff) { pendingChecklistCount = 0; return; }

			// Check shift
			const shiftTime = await getShiftStartTime(empData.id);
			if (!shiftTime) { pendingChecklistCount = 0; return; }
			const shiftStarted = await isAfterShiftStart(empData.id);
			if (!shiftStarted) { pendingChecklistCount = 0; return; }

			// Get all active assignments
			const { data: assignments } = await supabase
				.from('employee_checklist_assignments')
				.select('id, checklist_id, frequency_type, day_of_week')
				.eq('assigned_to_user_id', $currentUser.id)
				.is('deleted_at', null)
				.eq('is_active', true);

			if (!assignments || assignments.length === 0) { pendingChecklistCount = 0; return; }

			// Get today's submissions
			const today = new Date().toISOString().split('T')[0];
			const { data: submissions } = await supabase
				.from('hr_checklist_operations')
				.select('checklist_id')
				.eq('employee_id', empData.id)
				.eq('operation_date', today);

			const submittedIds = new Set((submissions || []).map(s => s.checklist_id));
			const saToday = getSaudiDayOfWeek();

			// Count pending (not submitted, applicable today)
			pendingChecklistCount = assignments.filter(a => {
				if (submittedIds.has(a.checklist_id)) return false;
				if (a.frequency_type === 'daily') return true;
				if (a.frequency_type === 'weekly' && a.day_of_week === saToday) return true;
				return false;
			}).length;
		} catch (err) {
			console.error('Error fetching checklist count:', err);
		}
	}

	async function fetchUnresolvedIncidentCount() {
		try {
			const { count, error: countError } = await supabase
				.from('incidents')
				.select('*', { count: 'exact', head: true })
				.neq('resolution_status', 'resolved');

			if (countError) {
				console.error('Error fetching incident count:', countError);
				return;
			}
			unresolvedIncidentCount = count || 0;
		} catch (err) {
			console.error('Error fetching incident count:', err);
		}
	}

	function openIncidentManagerWindow() {
		const windowId = generateWindowId('incident-manager');
		openWindow({
			id: windowId,
			title: 'Incident Manager',
			component: IncidentManager,
			icon: '⚠️',
			size: { width: 1200, height: 700 },
			position: { x: 100, y: 50 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Refresh count after opening
		setTimeout(fetchUnresolvedIncidentCount, 1000);
	}

	async function fetchActiveOrderCount() {
		try {
			const { count, error } = await supabase
				.from('orders')
				.select('*', { count: 'exact', head: true })
				.not('order_status', 'in', '("delivered","cancelled","picked_up")');

			if (error) {
				console.error('Error fetching active order count:', error);
				return;
			}
			activeOrderCount = count || 0;
		} catch (err) {
			console.error('Error fetching active order count:', err);
		}
	}

	function setupOrdersRealtime() {
		ordersChannel = supabase
			.channel('taskbar-orders')
			.on(
				'postgres_changes',
				{ event: '*', schema: 'public', table: 'orders' },
				() => {
					fetchActiveOrderCount();
				}
			)
			.subscribe();
	}

	function openOrdersWindow() {
		const windowId = generateWindowId('orders');
		import('$lib/components/desktop-interface/admin-customer-app/OrdersManager.svelte').then(({ default: OrdersManager }) => {
			openWindow({
				id: windowId,
				title: `Orders (${activeOrderCount})`,
				component: OrdersManager,
				icon: '🛒',
				size: { width: 1200, height: 700 },
				position: { x: 100, y: 50 },
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		}).catch(error => {
			console.error('Failed to load OrdersManager:', error);
		});

		setTimeout(fetchActiveOrderCount, 1000);
	}

	function openQuickNotifications() {
		const windowId = generateWindowId('quick-notifications');
		
		openWindow({
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

	function openTasksWindow() {
		// Open the My Tasks window using the original MyTasksView component
		const windowId = generateWindowId('my-tasks');
		
		// Import MyTasksView component dynamically
		import('$lib/components/desktop-interface/master/tasks/MyTasksView.svelte').then(({ default: MyTasksView }) => {
			openWindow({
				id: windowId,
				title: `My Tasks (${taskCountData.total})`,
				component: MyTasksView,
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
			// Fallback: navigate to mobile tasks page
			goto('/mobile-interface/tasks');
		});

		// Refresh task counts after opening
		setTimeout(() => taskCountService.refreshTaskCounts(), 1000);
	}

	function openApprovalCenterWindow() {
		// Open the Approval Center window
		const windowId = generateWindowId('approval-center');
		
		openWindow({
			id: windowId,
			title: 'Approval Center',
			component: ApprovalCenter,
			icon: '✅',
			size: { width: 1200, height: 700 },
			position: { x: 100, y: 50 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Refresh approval counts after opening
		setTimeout(refreshApprovalCounts, 1000);
	}

	function openWhatsAppWindow() {
		const windowId = generateWindowId('wa-live-chat');
		openWindow({
			id: windowId,
			title: 'WhatsApp Live Chat',
			component: WALiveChat,
			componentName: 'WALiveChat',
			icon: '💬',
			size: { width: 1400, height: 800 },
			position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			popOutEnabled: true
		});
	}

	function openQuickAnnouncements() {
		const windowId = generateWindowId('quick-announcements');
		
		// For now, show a placeholder - can be replaced with actual component
		openWindow({
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
		openWindow({
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



	async function toggleCallPopup() {
		showCallPopup = !showCallPopup;
		if (showCallPopup && callEmployees.length === 0) {
			await loadCallEmployees();
		}
	}

	async function loadCallEmployees() {
		loadingCallEmployees = true;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, user_id, name_en, name_ar, employment_status')
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job'])
				.order('name_en', { ascending: true });
			if (error) throw error;
			callEmployees = data || [];
		} catch (err) {
			console.error('Failed to load employees for call popup:', err);
		} finally {
			loadingCallEmployees = false;
		}
	}

	async function handleCallEmployee(employee: any) {
		if (!employee.user_id) return;

		// Get caller info
		const caller = $currentUser;
		const callerName = caller?.employeeName || caller?.username || 'Someone';
		const callerEmp = callEmployees.find(e => e.user_id === caller?.id);
		const callerNameAr = callerEmp?.name_ar || '';

		// Initiate call via the call store (IncomingCallOverlay handles WebRTC)
		initiateCall({
			targetUserId: employee.user_id,
			targetName: employee.name_en || employee.name_ar || 'Employee',
			targetNameAr: employee.name_ar || '',
			callerName,
			callerNameAr
		});

		// Close the popup
		showCallPopup = false;
	}

	async function handleTextEmployee(employee: any) {
		if (!employee.user_id) return;
		textTargetEmployee = employee;
		textInputValue = '';
		showTextInput = true;
		showCallPopup = false;
		await tick();
		textInputRef?.focus();
	}

	function sendText() {
		if (!textInputValue.trim() || !textTargetEmployee?.user_id) return;

		const caller = $currentUser;
		const senderName = caller?.employeeName || caller?.username || 'Someone';
		const senderEmp = callEmployees.find(e => e.user_id === caller?.id);
		const senderNameAr = senderEmp?.name_ar || '';

		sendTextMessage({
			targetUserId: textTargetEmployee.user_id,
			targetName: textTargetEmployee.name_en || textTargetEmployee.name_ar || 'Employee',
			targetNameAr: textTargetEmployee.name_ar || '',
			senderName,
			senderNameAr,
			message: textInputValue.trim()
		});

		showTextInput = false;
		textTargetEmployee = null;
		textInputValue = '';
	}

	function cancelText() {
		showTextInput = false;
		textTargetEmployee = null;
		textInputValue = '';
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
		if (showCallPopup) {
			const target = event.target as Element;
			const callPopup = target.closest('.call-popup-wrapper');
			if (!callPopup) {
				showCallPopup = false;
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

		<!-- Approval Center -->
		<button 
			class="quick-btn approvals-btn"
			on:click={openApprovalCenterWindow}
			title="Approval Center ({approvalCountData.pending} pending)"
		>
			<div class="quick-icon">✅</div>
			{#if approvalCountData.pending > 0}
				<div class="quick-badge pending">{approvalCountData.pending > 99 ? '99+' : approvalCountData.pending}</div>
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

		<!-- My Daily Checklist -->
		<button 
			class="quick-btn checklist-btn"
			on:click={openDailyChecklist}
			title="My Daily Checklist ({pendingChecklistCount} pending)"
		>
			<div class="quick-icon">📒</div>
			{#if pendingChecklistCount > 0}
				<div class="quick-badge">{pendingChecklistCount > 99 ? '99+' : pendingChecklistCount}</div>
			{/if}
		</button>

		<!-- Incident Manager -->
		<button 
			class="quick-btn incident-btn"
			on:click={openIncidentManagerWindow}
			title="Incident Manager ({unresolvedIncidentCount} unresolved)"
		>
			<div class="quick-icon">⚠️</div>
			{#if unresolvedIncidentCount > 0}
				<div class="quick-badge">{unresolvedIncidentCount > 99 ? '99+' : unresolvedIncidentCount}</div>
			{/if}
		</button>

		<!-- Active Orders -->
		<button 
			class="quick-btn orders-btn"
			on:click={openOrdersWindow}
			title="Active Orders ({activeOrderCount})"
		>
			<div class="quick-icon">🛒</div>
			{#if activeOrderCount > 0}
				<div class="quick-badge">{activeOrderCount > 99 ? '99+' : activeOrderCount}</div>
			{/if}
		</button>

		<!-- WhatsApp Live Chat -->
		<button 
			class="quick-btn whatsapp-btn"
			on:click={openWhatsAppWindow}
			title="WhatsApp Live Chat ({waUnreadData.total} unread)"
		>
			<div class="quick-icon">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="#25D366" stroke="none">
					<path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
				</svg>
			</div>
			{#if waUnreadData.total > 0}
				<div class="quick-badge">{waUnreadData.total > 99 ? '99+' : waUnreadData.total}</div>
			{/if}
		</button>

		<!-- Call -->
		<div class="call-popup-wrapper">
			<button 
				class="quick-btn call-btn"
				class:active={showCallPopup}
				on:click|stopPropagation={toggleCallPopup}
				title="Call"
			>
				<div class="quick-icon">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" stroke="none">
						<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
					</svg>
				</div>
			</button>

			{#if showCallPopup}
				<div class="call-popup" on:click|stopPropagation>
					<div class="call-popup-header">
						<h3>📞 Employees</h3>
						<button class="call-popup-close" on:click={() => showCallPopup = false}>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M18 6L6 18M6 6l12 12"/>
							</svg>
						</button>
					</div>
					<div class="call-popup-search">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#9ca3af" stroke-width="2">
							<circle cx="11" cy="11" r="8"/>
							<path d="M21 21l-4.35-4.35"/>
						</svg>
						<input 
							type="text" 
							placeholder="Search employee..." 
							bind:value={callSearchQuery}
							class="call-search-input"
						/>
					</div>
					<div class="call-popup-list">
						{#if loadingCallEmployees}
							<div class="call-popup-loading">Loading...</div>
						{:else if filteredCallEmployees.length === 0}
							<div class="call-popup-empty">No employees found</div>
						{:else}
							{#each filteredCallEmployees as emp (emp.id)}
								<div class="call-popup-row">
									<div class="call-emp-name">
										<span class="emp-name-en">{emp.name_en || '—'}</span>
										{#if emp.name_ar}
											<span class="emp-name-ar">{emp.name_ar}</span>
										{/if}
									</div>
									<div class="call-emp-actions">
										<button class="call-action-btn call-phone" on:click={() => handleCallEmployee(emp)} title="Call">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
												<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
											</svg>
										</button>
										<button class="call-action-btn call-text" on:click={() => handleTextEmployee(emp)} title="Text">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
											</svg>
										</button>
									</div>
								</div>
							{/each}
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>

	<!-- System Tray -->
	<div class="system-tray">
		<!-- Logout Button -->
		{#if $currentUser}
			<button 
				class="tray-button logout-button" 
				on:click|stopPropagation={handleLogout}
				title="Logout ({$currentUser?.employeeName || $currentUser?.username})"
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
			<div class="user-info-taskbar">
				<div class="user-display">
					<div class="user-avatar-taskbar">
						<span>{($currentUser?.employeeName || $currentUser?.username)?.charAt(0)?.toUpperCase() || 'U'}</span>
					</div>
					<div class="user-details-taskbar">
						<div class="user-name-taskbar">{$currentUser?.employeeName || $currentUser?.username || 'User'}</div>
						<div class="user-role-taskbar">{$currentUser?.role || 'Role'}</div>
					</div>
				</div>
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
				<h3>{t('auth.confirmLogout')}</h3>
			</div>
			<div class="dialog-body">
				<p>{t('auth.confirmLogoutMessage')}</p>
				<div class="current-user-info">
					<div class="user-avatar-dialog">
						<span>{($currentUser?.employeeName || $currentUser?.username)?.charAt(0)?.toUpperCase() || 'U'}</span>
					</div>
					<div class="user-details-dialog">
						<div class="username">{$currentUser?.employeeName || $currentUser?.username || 'User'}</div>
						<div class="role">{$currentUser?.role || 'Role'}</div>
					</div>
				</div>
			</div>
			<div class="dialog-actions">
				<button class="cancel-button" on:click={cancelLogout}>{t('nav.cancel')}</button>
				<button class="confirm-button" on:click={confirmLogout}>{t('auth.logout')}</button>
			</div>
		</div>
	</div>
{/if}

<!-- Text Input Popup (outside taskbar to avoid stacking context) -->
{#if showTextInput && textTargetEmployee}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="text-input-backdrop" on:click={cancelText}>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="text-input-popup" on:click|stopPropagation>
			<div class="text-input-header">
				<span>💬 Send to {textTargetEmployee.name_en || textTargetEmployee.name_ar}</span>
				<button class="text-input-close" on:click={cancelText} aria-label="Close">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M18 6L6 18M6 6l12 12"/>
					</svg>
				</button>
			</div>
			<textarea
				class="text-input-area"
				placeholder="Type your message..."
				bind:this={textInputRef}
				bind:value={textInputValue}
				on:keydown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendText(); } }}
				rows="3"
			></textarea>
			<div class="text-input-actions">
				<button class="text-cancel-btn" on:click={cancelText}>Cancel</button>
				<button class="text-send-btn" on:click={sendText} disabled={!textInputValue.trim()}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="white" stroke="none">
						<path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
					</svg>
					Send
				</button>
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
		background: var(--theme-taskbar-bg, rgba(0, 102, 178, 0.75));
		border-top: 1px solid var(--theme-taskbar-border, rgba(255, 255, 255, 0.2));
		display: flex;
		align-items: center;
		padding: 0 8px;
		gap: 8px;
		z-index: 2000;
		box-shadow: 
			0 -4px 24px rgba(0, 0, 0, 0.15),
			0 -1px 3px rgba(255, 255, 255, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.1);
		backdrop-filter: blur(20px) saturate(180%);
		-webkit-backdrop-filter: blur(20px) saturate(180%);
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
		background: var(--theme-taskbar-btn-inactive-bg, rgba(255, 255, 255, 0.95));
		color: var(--theme-taskbar-btn-inactive-text, #0B1220);
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
		border-color: var(--theme-taskbar-btn-hover-border, #4F46E5);
		color: var(--theme-taskbar-btn-hover-border, #4F46E5);
	}

	.task-button.active {
		background: var(--theme-taskbar-btn-active-bg, linear-gradient(135deg, #4F46E5 0%, #6366F1 100%));
		color: var(--theme-taskbar-btn-active-text, white);
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
		background: var(--theme-taskbar-quick-access-bg, rgba(255, 255, 255, 0.1));
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

	.tasks-btn .quick-badge {
		background: #3b82f6;
	}

	.tasks-btn .quick-badge.overdue {
		background: #ef4444;
		animation: pulse 2s infinite;
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}

	.approvals-btn .quick-badge {
		background: #f59e0b;
	}

	.approvals-btn .quick-badge.pending {
		background: #f59e0b;
		animation: pulse 2s infinite;
	}

	.notifications-btn .quick-badge {
		background: #10b981;
	}

	.checklist-btn {
		background: rgba(249, 115, 22, 0.15) !important;
	}

	.checklist-btn:hover {
		background: rgba(249, 115, 22, 0.3) !important;
	}

	.checklist-btn .quick-badge {
		background: #f97316;
	}

	.incident-btn {
		background: rgba(239, 68, 68, 0.15) !important;
	}

	.incident-btn:hover {
		background: rgba(239, 68, 68, 0.3) !important;
	}

	.incident-btn .quick-badge {
		background: #ef4444;
		animation: pulse 2s infinite;
	}

	.orders-btn {
		background: rgba(16, 185, 129, 0.15) !important;
	}

	.orders-btn:hover {
		background: rgba(16, 185, 129, 0.3) !important;
	}

	.orders-btn .quick-badge {
		background: #10b981;
		animation: pulse 2s infinite;
	}

	.call-btn {
		background: rgba(34, 197, 94, 0.2) !important;
		color: #16a34a !important;
	}

	.call-btn:hover {
		background: rgba(34, 197, 94, 0.4) !important;
		box-shadow: 0 0 12px rgba(34, 197, 94, 0.3);
	}

	.call-btn .quick-icon {
		color: #16a34a;
	}

	.call-btn.active {
		background: rgba(34, 197, 94, 0.4) !important;
		box-shadow: 0 0 12px rgba(34, 197, 94, 0.3);
	}

	.call-popup-wrapper {
		position: relative;
	}

	.call-popup {
		position: absolute;
		bottom: 50px;
		right: 0;
		width: 320px;
		max-height: 420px;
		background: #1e293b;
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		box-shadow: 0 -8px 30px rgba(0, 0, 0, 0.4);
		z-index: 9999;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		animation: callPopupSlide 0.2s ease-out;
	}

	@keyframes callPopupSlide {
		from { opacity: 0; transform: translateY(10px); }
		to { opacity: 1; transform: translateY(0); }
	}

	.call-popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.08);
		background: rgba(34, 197, 94, 0.1);
	}

	.call-popup-header h3 {
		margin: 0;
		font-size: 0.9rem;
		color: #e2e8f0;
		font-weight: 600;
	}

	.call-popup-close {
		background: none;
		border: none;
		color: #94a3b8;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		display: flex;
		align-items: center;
	}

	.call-popup-close:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
	}

	.call-popup-search {
		padding: 8px 12px;
		display: flex;
		align-items: center;
		gap: 8px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.call-search-input {
		flex: 1;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 6px;
		padding: 6px 10px;
		color: #e2e8f0;
		font-size: 0.8rem;
		outline: none;
	}

	.call-search-input::placeholder {
		color: #64748b;
	}

	.call-search-input:focus {
		border-color: rgba(34, 197, 94, 0.5);
	}

	.call-popup-list {
		overflow-y: auto;
		flex: 1;
		max-height: 320px;
	}

	.call-popup-loading,
	.call-popup-empty {
		padding: 24px;
		text-align: center;
		color: #64748b;
		font-size: 0.85rem;
	}

	.call-popup-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		transition: background 0.15s;
	}

	.call-popup-row:hover {
		background: rgba(255, 255, 255, 0.05);
	}

	.call-emp-name {
		display: flex;
		flex-direction: column;
		gap: 1px;
		flex: 1;
		min-width: 0;
	}

	.emp-name-en {
		color: #e2e8f0;
		font-size: 0.82rem;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.emp-name-ar {
		color: #94a3b8;
		font-size: 0.72rem;
		direction: rtl;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.call-emp-actions {
		display: flex;
		gap: 6px;
		flex-shrink: 0;
		margin-left: 8px;
	}

	.call-action-btn {
		width: 30px;
		height: 30px;
		border-radius: 8px;
		border: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.15s;
	}

	.call-action-btn.call-phone {
		background: rgba(34, 197, 94, 0.2);
		color: #22c55e;
	}

	.call-action-btn.call-phone:hover {
		background: rgba(34, 197, 94, 0.4);
	}

	.call-action-btn.call-text {
		background: rgba(59, 130, 246, 0.2);
		color: #3b82f6;
	}

	.call-action-btn.call-text:hover {
		background: rgba(59, 130, 246, 0.4);
	}

	/* ── Text Input Popup (global - rendered outside taskbar stacking context) ── */
	:global(.text-input-backdrop) {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 10000;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: overlayFadeIn 0.2s ease-out;
	}

	@keyframes overlayFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	:global(.text-input-popup) {
		background: #1e293b;
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 16px;
		padding: 20px;
		width: 380px;
		max-width: 90vw;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}

	:global(.text-input-header) {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 14px;
		color: white;
		font-weight: 600;
		font-size: 0.95rem;
	}

	:global(.text-input-close) {
		background: none;
		border: none;
		color: #9ca3af;
		cursor: pointer;
		padding: 4px;
		border-radius: 6px;
		transition: all 0.15s;
	}

	:global(.text-input-close:hover) {
		color: white;
		background: rgba(255, 255, 255, 0.1);
	}

	:global(.text-input-area) {
		width: 100%;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 10px;
		padding: 12px 14px;
		color: white;
		font-size: 0.9rem;
		resize: none;
		outline: none;
		font-family: inherit;
		line-height: 1.5;
		box-sizing: border-box;
	}

	:global(.text-input-area::placeholder) {
		color: #6b7280;
	}

	:global(.text-input-area:focus) {
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
	}

	:global(.text-input-actions) {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		margin-top: 14px;
	}

	:global(.text-cancel-btn) {
		padding: 8px 18px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.15);
		color: #d1d5db;
		border-radius: 8px;
		font-size: 0.85rem;
		cursor: pointer;
		transition: all 0.15s;
	}

	:global(.text-cancel-btn:hover) {
		background: rgba(255, 255, 255, 0.15);
		color: white;
	}

	:global(.text-send-btn) {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 20px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}

	:global(.text-send-btn:hover:not(:disabled)) {
		background: linear-gradient(135deg, #2563eb, #1d4ed8);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	:global(.text-send-btn:disabled) {
		opacity: 0.4;
		cursor: not-allowed;
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
		padding: 0 8px;
		height: 32px; /* Same height as language toggle */
		width: 100px; /* Fixed width same as language toggle */
	}

	.user-display {
		display: flex;
		align-items: center;
		gap: 4px;
		width: 100%;
		height: 100%;
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

