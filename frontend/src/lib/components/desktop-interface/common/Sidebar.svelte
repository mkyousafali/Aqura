<script lang="ts">
	// IMPORTANT: When adding new menu items or UI text, ALWAYS update translations:
	// - frontend/src/lib/i18n/locales/en.ts (English)
	// - frontend/src/lib/i18n/locales/ar.ts (Arabic)
	
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { sidebar } from '$lib/stores/sidebar';
	import { currentLocale, t } from '$lib/i18n';
	import {
		showInstallPrompt,
		isInstalled,
		initPWAInstall,
		installPWA
	} from '$lib/stores/pwaInstall';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { approvalCounts } from '$lib/stores/approvalCounts';
	
	// Component imports
	import BranchMaster from '$lib/components/desktop-interface/master/BranchMaster.svelte';
	import TaskMaster from '$lib/components/desktop-interface/master/TaskMaster.svelte';
	import OperationsMaster from '$lib/components/desktop-interface/master/OperationsMaster.svelte';
	import ManageVendor from '$lib/components/desktop-interface/master/vendor/ManageVendor.svelte';
	import EditVendor from '$lib/components/desktop-interface/master/vendor/EditVendor.svelte';
	import UploadVendor from '$lib/components/desktop-interface/master/vendor/UploadVendor.svelte';
	import ApprovalCenter from '$lib/components/desktop-interface/master/finance/ApprovalCenter.svelte';
	import UserManagement from '$lib/components/desktop-interface/settings/UserManagement.svelte';
	import Settings from '$lib/components/desktop-interface/settings/Settings.svelte';
	import ApprovalPermissionsManager from '$lib/components/desktop-interface/settings/ApprovalPermissionsManager.svelte';
	import CommunicationCenter from '$lib/components/desktop-interface/master/CommunicationCenter.svelte';
	import StartReceiving from '$lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte';
	import MonthlyManager from '$lib/components/desktop-interface/master/finance/MonthlyManager.svelte';
	import MonthlyBreakdown from '$lib/components/desktop-interface/master/finance/MonthlyBreakdown.svelte';
	import ExpensesManager from '$lib/components/desktop-interface/master/finance/ExpensesManager.svelte';
	import DayBudgetPlanner from '$lib/components/desktop-interface/master/finance/DayBudgetPlanner.svelte';
	import ManualScheduling from '$lib/components/desktop-interface/master/finance/ManualScheduling.svelte';
	import PaidManager from '$lib/components/desktop-interface/master/finance/PaidManager.svelte';
	import CategoryManager from '$lib/components/desktop-interface/master/finance/CategoryManager.svelte';
	import PurchaseVoucherManager from '$lib/components/desktop-interface/master/finance/PurchaseVoucherManager.svelte';
	import Denomination from '$lib/components/desktop-interface/master/finance/Denomination.svelte';
	import CustomerMaster from '$lib/components/desktop-interface/admin-customer-app/CustomerMaster.svelte';
	import InterfaceAccessManager from '$lib/components/desktop-interface/settings/InterfaceAccessManager.svelte';
	import AdManager from '$lib/components/desktop-interface/admin-customer-app/AdManager.svelte';
	import SocialLinkManager from '$lib/components/desktop-interface/admin-customer-app/SocialLinkManager.svelte';
	import DeliverySettings from '$lib/components/desktop-interface/admin-customer-app/DeliverySettings.svelte';
	import ProductsManager from '$lib/components/desktop-interface/admin-customer-app/ProductsManager.svelte';
	import OfferManagement from '$lib/components/desktop-interface/admin-customer-app/OfferManagement.svelte';
	import ProductSelectorWindow from '$lib/components/desktop-interface/admin-customer-app/offers/ProductSelectorWindow.svelte';
	import OrdersManager from '$lib/components/desktop-interface/admin-customer-app/OrdersManager.svelte';
	import FlyerMasterDashboard from '$lib/components/desktop-interface/marketing/flyer/FlyerMasterDashboard.svelte';
	import ProductMaster from '$lib/components/desktop-interface/marketing/flyer/ProductMaster.svelte';
	import VariationManager from '$lib/components/desktop-interface/marketing/flyer/VariationManager.svelte';
	import OfferTemplates from '$lib/components/desktop-interface/marketing/flyer/OfferTemplates.svelte';
	import OfferProductSelector from '$lib/components/desktop-interface/marketing/flyer/OfferProductSelector.svelte';
	import OfferManager from '$lib/components/desktop-interface/marketing/flyer/OfferManager.svelte';
	import PricingManager from '$lib/components/desktop-interface/marketing/flyer/PricingManager.svelte';
	import FlyerGenerator from '$lib/components/desktop-interface/marketing/flyer/FlyerGenerator.svelte';
	import FlyerTemplates from '$lib/components/desktop-interface/marketing/flyer/FlyerTemplates.svelte';
	import FlyerSettings from '$lib/components/desktop-interface/marketing/flyer/FlyerSettings.svelte';
	import DesignPlanner from '$lib/components/desktop-interface/marketing/flyer/DesignPlanner.svelte';
	import ExpenseTracker from '$lib/components/desktop-interface/master/finance/reports/ExpenseTracker.svelte';
	import SalesReport from '$lib/components/desktop-interface/master/finance/reports/SalesReport.svelte';
	import VendorPendingPayments from '$lib/components/desktop-interface/master/finance/reports/VendorPendingPayments.svelte';
	import VendorRecords from '$lib/components/desktop-interface/master/finance/reports/VendorRecords.svelte';
	import OverduesReport from '$lib/components/desktop-interface/master/finance/reports/OverduesReport.svelte';
	import ReceivingRecords from '$lib/components/desktop-interface/master/operations/receiving/ReceivingRecords.svelte';
	import Receiving from '$lib/components/desktop-interface/master/operations/Receiving.svelte';
	import CouponDashboard from '$lib/components/desktop-interface/marketing/coupon/CouponDashboard.svelte';
	import CampaignManager from '$lib/components/desktop-interface/marketing/coupon/CampaignManager.svelte';
	import ViewOfferManager from '$lib/components/desktop-interface/marketing/coupon/ViewOfferManager.svelte';
	import CustomerImporter from '$lib/components/desktop-interface/marketing/coupon/CustomerImporter.svelte';
	import ProductManager from '$lib/components/desktop-interface/marketing/coupon/ProductManager.svelte';
	import CouponReports from '$lib/components/desktop-interface/marketing/coupon/CouponReports.svelte';
	import ERPConnections from '$lib/components/desktop-interface/settings/ERPConnections.svelte';
	import ClearTables from '$lib/components/desktop-interface/settings/ClearTables.svelte';
	import ButtonAccessControl from '$lib/components/desktop-interface/settings/ButtonAccessControl.svelte';
	import ButtonGenerator from '$lib/components/desktop-interface/settings/ButtonGenerator.svelte';
	import VersionChangelog from '$lib/components/desktop-interface/common/VersionChangelog.svelte';
	import CreateUser from '$lib/components/desktop-interface/settings/user/CreateUser.svelte';
	import ManageAdminUsers from '$lib/components/desktop-interface/settings/user/ManageAdminUsers.svelte';
	import ManageMasterAdmin from '$lib/components/desktop-interface/settings/user/ManageMasterAdmin.svelte';
	import UploadEmployees from '$lib/components/desktop-interface/master/hr/UploadEmployees.svelte';
	import CreateDepartment from '$lib/components/desktop-interface/master/hr/CreateDepartment.svelte';
	import CreateLevel from '$lib/components/desktop-interface/master/hr/CreateLevel.svelte';
	import CreatePosition from '$lib/components/desktop-interface/master/hr/CreatePosition.svelte';
	import ReportingMap from '$lib/components/desktop-interface/master/hr/ReportingMap.svelte';
	import AssignPositions from '$lib/components/desktop-interface/master/hr/AssignPositions.svelte';
	import BiometricExport from '$lib/components/desktop-interface/master/hr/BiometricExport.svelte';
	import BiometricData from '$lib/components/desktop-interface/master/hr/BiometricData.svelte';
	import DocumentManagement from '$lib/components/desktop-interface/master/hr/DocumentManagement.svelte';
	import SalaryManagement from '$lib/components/desktop-interface/master/hr/SalaryManagement.svelte';
	import WarningMaster from '$lib/components/desktop-interface/master/warnings/WarningMaster.svelte';
	import TaskCreateForm from '$lib/components/desktop-interface/master/tasks/TaskCreateForm.svelte';
	import TaskViewTable from '$lib/components/desktop-interface/master/tasks/TaskViewTable.svelte';
	import TaskAssignmentView from '$lib/components/desktop-interface/master/tasks/TaskAssignmentView.svelte';
	import MyTasksView from '$lib/components/desktop-interface/master/tasks/MyTasksView.svelte';
	import MyAssignmentsView from '$lib/components/desktop-interface/master/tasks/MyAssignmentsView.svelte';
	import TaskStatusView from '$lib/components/desktop-interface/master/tasks/TaskStatusView.svelte';
	import BranchPerformanceWindow from '$lib/components/desktop-interface/master/tasks/BranchPerformanceWindow.svelte';

	let showSettingsSubmenu = false;
	let showCustomerAppSubmenu = false;

	let showDeliverySubmenu = false;
	let showDeliveryDashboardSubmenu = false;
	let showDeliveryManageSubmenu = false;
	let showDeliveryOperationsSubmenu = false;
	let showDeliveryReportsSubmenu = false;
	let showVendorSubmenu = false;
	let showVendorManagerSubmenu = false;
	let showVendorOperationsSubmenu = false;
	let showVendorReportsSubmenu = false;
	let showVendorDashboardSubmenu = false;
	let showFinanceSubmenu = false;
	let showFinanceDashboardSubmenu = false;
	let showFinanceManageSubmenu = false;
	let showFinanceOperationsSubmenu = false;
	let showFinanceReportsSubmenu = false;
	let showReportsSubmenu = false;
	let showHRSubmenu = false;
	let showHRDashboardSubmenu = false;
	let showHRManageSubmenu = false;
	let showHROperationsSubmenu = false;
	let showHRReportsSubmenu = false;
	let showTasksSubmenu = false;
	let showTasksDashboardSubmenu = false;
	let showTasksManageSubmenu = false;
	let showTasksOperationsSubmenu = false;
	let showTasksReportsSubmenu = false;
	let showNotificationsSubmenu = false;
	let showNotificationsDashboardSubmenu = false;
	let showNotificationsManageSubmenu = false;
	let showNotificationsOperationsSubmenu = false;
	let showNotificationsReportsSubmenu = false;
	let showControlsSubmenu = false;
	let showControlsDashboardSubmenu = false;
	let showControlsManageSubmenu = false;
	let showControlsOperationsSubmenu = false;
	let showControlsReportsSubmenu = false;
	let showMediaSubmenu = false;
	let showMediaDashboardSubmenu = false;
	let showMediaManageSubmenu = false;
	let showMediaOperationsSubmenu = false;
	let showMediaReportsSubmenu = false;
	let showPromoSubmenu = false;
	let showPromoDashboardSubmenu = false;
	let showPromoManageSubmenu = false;
	let showPromoOperationsSubmenu = false;
	let showPromoReportsSubmenu = false;
	let showUserSubmenu = false;
	let showUserDashboardSubmenu = false;
	let showUserManageSubmenu = false;
	let showUserOperationsSubmenu = false;
	let showUserReportsSubmenu = false;
	let hasApprovalPermission = false;
	
	// Get pending approvals count from store
	$: pendingApprovalsCount = $approvalCounts.pending;

	// Online/Offline state
	let isOnline = true;
	
	// Force reactivity when locale changes
	$: locale = $currentLocale;

	// Initialize PWA install detection
	onMount(async () => {
		initPWAInstall();
		await checkApprovalPermission();
		
		// Monitor online/offline status
		isOnline = navigator.onLine;
		
		const handleOnline = () => { isOnline = true; };
		const handleOffline = () => { isOnline = false; };
		
		window.addEventListener('online', handleOnline);
		window.addEventListener('offline', handleOffline);
		
		// Cleanup on unmount
		return () => {
			window.removeEventListener('online', handleOnline);
			window.removeEventListener('offline', handleOffline);
		};
	});

	// Check if current user has approval permissions
	async function checkApprovalPermission() {
		if (!$currentUser?.id) {
			hasApprovalPermission = false;
			return;
		}

		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('approval_permissions')
				.select('*')
				.eq('user_id', $currentUser.id)
				.eq('is_active', true)
				.maybeSingle(); // Use maybeSingle to handle cases where user has no approval permissions

			if (!error && data) {
				// User has approval permission if ANY permission type is enabled
				hasApprovalPermission = 
					data.can_approve_requisitions ||
					data.can_approve_single_bill ||
					data.can_approve_multiple_bill ||
					data.can_approve_recurring_bill ||
					data.can_approve_vendor_payments ||
					data.can_approve_leave_requests;
			} else {
				hasApprovalPermission = false;
			}
		} catch (err) {
			console.error('Error checking approval permission:', err);
			hasApprovalPermission = false;
		}
	}

	// Re-check approval permission when user changes
	$: if ($currentUser) {
		checkApprovalPermission();
		loadButtonPermissions();
	}

	// Button permissions state
	let allowedButtonCodes: Set<string> = new Set();
	let buttonPermissionsLoaded = false;

	// Load button permissions for current user
	async function loadButtonPermissions() {
		if (!$currentUser?.id) {
			allowedButtonCodes = new Set();
			buttonPermissionsLoaded = false;
			return;
		}

		console.log('🔍 [Sidebar] Loading button permissions for user:', $currentUser.id);

		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: permissions, error } = await supabase
				.from('button_permissions')
				.select('button_id')
				.eq('user_id', $currentUser.id)
				.eq('is_enabled', true);

			console.log('🔍 [Sidebar] Button permissions:', permissions?.length, 'enabled');

			if (error) {
				console.error('❌ [Sidebar] Error fetching button permissions:', error);
				allowedButtonCodes = new Set();
			} else if (permissions && permissions.length > 0) {
				// Map button_ids to button codes
				const buttonIds = permissions.map(p => p.button_id);
				const { data: buttons, error: btnError } = await supabase
					.from('sidebar_buttons')
					.select('id, button_code')
					.in('id', buttonIds);

				if (btnError) {
					console.error('❌ [Sidebar] Error fetching button codes:', btnError);
					allowedButtonCodes = new Set();
				} else if (buttons) {
					allowedButtonCodes = new Set(buttons.map(b => b.button_code));
					console.log('✅ [Sidebar] Loaded', allowedButtonCodes.size, 'allowed button codes');
				}
			} else {
				console.warn('⚠️  [Sidebar] No button permissions found');
				allowedButtonCodes = new Set();
			}
			buttonPermissionsLoaded = true;
		} catch (err) {
			console.error('❌ [Sidebar] Error loading button permissions:', err);
			allowedButtonCodes = new Set();
			buttonPermissionsLoaded = true;
		}
	}

	// Helper function to check if a button is allowed
	function isButtonAllowed(buttonCode: string): boolean {
		// If permissions not loaded yet, don't show buttons (wait for loading)
		if (!buttonPermissionsLoaded) return false;
		
		// If master admin, show all buttons
		if ($currentUser?.isMasterAdmin) return true;
		
		// If permissions loaded but set is empty, user has no permissions
		if (allowedButtonCodes.size === 0) return false;
		
		// Check if button code is in allowed set
		return allowedButtonCodes.has(buttonCode);
	}

	// Switch to mobile interface
	function switchToMobileInterface() {
		if ($currentUser) {
			// Set mobile preference for this user
			interfacePreferenceService.forceMobileInterface($currentUser.id);
			console.log('🔄 Switching to mobile interface for user:', $currentUser.id);
			// Navigate to mobile interface
			goto('/mobile-interface');
		}
	}

	// Handle PWA installation
	async function handlePWAInstall() {
		try {
			const success = await installPWA();
			if (success) {
				console.log('PWA installed successfully');
			} else {
				console.log('PWA installation instructions shown');
			}
		} catch (error) {
			console.error('Error installing PWA:', error);
			// The installPWA function already handles showing appropriate instructions
		}
	}

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openBranches() {
		const windowId = generateWindowId('branch-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('admin.branchesMaster') || 'Branch Master'} #${instanceNumber}`,
			component: BranchMaster,
			icon: '🏢',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function openTaskMaster() {
		const windowId = generateWindowId('task-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('admin.taskMaster') || 'Task Master'} #${instanceNumber}`,
			component: TaskMaster,
			icon: '📋',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksDashboardSubmenu = false;
	}

	function openCreateTask() {
		const windowId = generateWindowId('create-task');
		
		openWindow({
			id: windowId,
			title: 'Create New Task Template',
			component: TaskCreateForm,
			icon: '📝',
			size: { width: 600, height: 500 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksManageSubmenu = false;
	}

	function openViewTasks() {
		const windowId = generateWindowId('view-tasks');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `View Task Templates #${instanceNumber}`,
			component: TaskViewTable,
			icon: '📋',
			size: { width: 1200, height: 600 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksManageSubmenu = false;
	}

	function openMyTasks() {
		const windowId = generateWindowId('my-tasks');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `My Tasks #${instanceNumber}`,
			component: MyTasksView,
			icon: '📋',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksReportsSubmenu = false;
	}

	function openMyAssignments() {
		const windowId = generateWindowId('my-assignments');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `My Assignments #${instanceNumber}`,
			component: MyAssignmentsView,
			icon: '👨‍💼',
			size: { width: 1200, height: 800 },
			position: { 
				x: 75 + (Math.random() * 100), 
				y: 75 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksReportsSubmenu = false;
	}

	function openTaskStatus() {
		const windowId = generateWindowId('task-status');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Task Status #${instanceNumber}`,
			component: TaskStatusView,
			icon: '📊',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksReportsSubmenu = false;
	}

	function openAssignTasks() {
		const windowId = generateWindowId('assign-tasks');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Assign Tasks #${instanceNumber}`,
			component: TaskAssignmentView,
			icon: '👥',
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
		showTasksSubmenu = false;
		showTasksOperationsSubmenu = false;
	}

	function openBranchPerformanceWindow() {
		const windowId = generateWindowId('branch-performance');
		openWindow({
			id: windowId,
			title: 'Branch Performance',
			component: BranchPerformanceWindow,
			icon: '📊',
			size: { width: 1000, height: 700 },
			position: {
				x: 60 + (Math.random() * 80),
				y: 60 + (Math.random() * 80)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showTasksSubmenu = false;
		showTasksReportsSubmenu = false;
	}

	function openUploadEmployees() {
		collapseAllMenus();
		const windowId = generateWindowId('upload-employees');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Upload Employees #${instanceNumber}`,
			component: UploadEmployees,
			icon: '👥',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openCreateDepartment() {
		collapseAllMenus();
		const windowId = generateWindowId('create-department');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Department #${instanceNumber}`,
			component: CreateDepartment,
			icon: '🏢',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openCreateLevel() {
		collapseAllMenus();
		const windowId = generateWindowId('create-level');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Level #${instanceNumber}`,
			component: CreateLevel,
			icon: '📊',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openCreatePosition() {
		collapseAllMenus();
		const windowId = generateWindowId('create-position');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Position #${instanceNumber}`,
			component: CreatePosition,
			icon: '💼',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openReportingMap() {
		collapseAllMenus();
		const windowId = generateWindowId('reporting-map');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Reporting Map #${instanceNumber}`,
			component: ReportingMap,
			icon: '📈',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openAssignPositions() {
		collapseAllMenus();
		const windowId = generateWindowId('assign-positions');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Assign Positions #${instanceNumber}`,
			component: AssignPositions,
			icon: '🎯',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openContactManagement() {
		collapseAllMenus();
		const windowId = generateWindowId('contact-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Contact Management #${instanceNumber}`,
			component: ContactManagement,
			icon: '📞',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openDocumentManagement() {
		collapseAllMenus();
		const windowId = generateWindowId('document-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Document Management #${instanceNumber}`,
			component: DocumentManagement,
			icon: '📄',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openSalaryManagement() {
		collapseAllMenus();
		const windowId = generateWindowId('salary-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Salary & Wage Management #${instanceNumber}`,
			component: SalaryManagement,
			icon: '💰',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openWarningMaster() {
		collapseAllMenus();
		const windowId = generateWindowId('warning-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Warning Master #${instanceNumber}`,
			component: WarningMaster,
			icon: '⚠️',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openBiometricData() {
		collapseAllMenus();
		const windowId = generateWindowId('biometric-data');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Biometric Data #${instanceNumber}`,
			component: BiometricData,
			icon: '👆',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openExportBiometricData() {
		collapseAllMenus();
		const windowId = generateWindowId('export-biometric-data');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Export Biometric Data #${instanceNumber}`,
			component: BiometricExport,
			icon: '📊',
			size: { width: 800, height: 600 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showHRSubmenu = false;
	}

	function openOperationsMaster() {
		const windowId = generateWindowId('operations-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Operations Master #${instanceNumber}`,
			component: OperationsMaster,
			icon: '⚙️',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function openManageVendor() {
		collapseAllMenus();
		const windowId = generateWindowId('manage-vendor');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manage Vendor #${instanceNumber}`,
			component: ManageVendor,
			icon: '📋',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showVendorSubmenu = false;
	}

	function openCreateVendor() {
		collapseAllMenus();
		const windowId = generateWindowId('create-vendor');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Vendor #${instanceNumber}`,
			component: EditVendor,
			icon: '➕',
			size: { width: 800, height: 600 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				vendor: {
					erp_vendor_id: '',
					vendor_name: '',
					salesman_name: '',
					salesman_contact: '',
					supervisor_name: '',
					supervisor_contact: '',
					vendor_contact: '',
					payment_method: '',
					payment_priority: '',
					status: 'Active'
				}
			}
		});
		showVendorSubmenu = false;
	}

	function openUploadVendor() {
		collapseAllMenus();
		const windowId = generateWindowId('upload-vendor');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Upload Vendor #${instanceNumber}`,
			component: UploadVendor,
			icon: '📤',
			size: { width: 900, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showVendorSubmenu = false;
	}

	function openCustomerMaster() {
		const windowId = generateWindowId('customer-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('admin.customerMaster') || 'Customer'} #${instanceNumber}`,
			component: CustomerMaster,
			icon: '👥',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showCustomerAppSubmenu = false;
	}

	function openAdManager() {
		const windowId = generateWindowId('ad-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Ad Manager #${instanceNumber}`,
			component: AdManager,
			icon: '📢',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showDeliveryManageSubmenu = false;
	}

	function openDeliverySettings() {
		const windowId = generateWindowId('delivery-settings');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Delivery Settings #${instanceNumber}`,
			component: DeliverySettings,
			icon: '📦',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showDeliveryManageSubmenu = false;
	}

	function openProductsManager() {
		const windowId = generateWindowId('products-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Products Manager #${instanceNumber}`,
			component: ProductsManager,
			icon: '🛍️',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showDeliveryManageSubmenu = false;
	}

	function openProductsManagerNew() {
		const windowId = generateWindowId('products-manager-new');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Products Manager New #${instanceNumber}`,
			component: ProductsManager,
			icon: '🛍️',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showDeliveryManageSubmenu = false;
	}

	function openOfferManagement() {
		const windowId = generateWindowId('offer-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: t('admin.offerManagement') || `Offer Management #${instanceNumber}`,
			component: OfferManagement,
			icon: '🎁',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showDeliveryOperationsSubmenu = false;
	}

	function openOrdersManager() {
		const windowId = generateWindowId('orders-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Orders Manager #${instanceNumber}`,
			component: OrdersManager,
			icon: '🛒',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
		closable: true
	});
	showDeliveryOperationsSubmenu = false;
}

function openApprovalCenter() {
	const windowId = generateWindowId('approval-center');
	const instanceNumber = Math.floor(Math.random() * 1000) + 1;		openWindow({
			id: windowId,
			title: `Approval Center #${instanceNumber}`,
			component: ApprovalCenter,
			icon: '✅',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function showComingSoon(section: string) {
		// You can implement a toast notification or modal here
		alert(`${section} - ${t('status.pending') || 'pending'}...`);
	}

	function openUserManagement() {
		const windowId = generateWindowId('user-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `User Management #${instanceNumber}`,
			component: UserManagement,
			icon: '👤',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}

	function openInterfaceAccessManager() {
		const windowId = generateWindowId('interface-access');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Interface Access Manager #${instanceNumber}`,
			component: InterfaceAccessManager,
			icon: '🔧',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}

	function openSettings() {
		const windowId = generateWindowId('settings');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Sound Settings #${instanceNumber}`,
			component: Settings,
			icon: '🔊',
			size: { width: 1000, height: 700 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}

	function openApprovalPermissions() {
		const windowId = generateWindowId('approval-permissions');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Approval Permissions #${instanceNumber}`,
			component: ApprovalPermissionsManager,
			icon: '🔐',
			size: { width: 950, height: 750 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}



	function openClearTables() {
		const windowId = generateWindowId('clear-tables');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Clear Tables #${instanceNumber}`,
			component: ClearTables,
			icon: '🗑️',
			size: { width: 900, height: 650 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 80 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}

	function openButtonAccessControl() {
		const windowId = generateWindowId('button-access-control');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Button Access Control #${instanceNumber}`,
			component: ButtonAccessControl,
			icon: '🎛️',
			size: { width: 1400, height: 900 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 80 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showControlsSubmenu = false;
		showControlsManageSubmenu = false;
	}

	function openButtonGenerator() {
		const windowId = generateWindowId('button-generator');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Button Generator #${instanceNumber}`,
			component: ButtonGenerator,
			icon: '🔨',
			size: { width: 1400, height: 900 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 80 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showControlsSubmenu = false;
		showControlsManageSubmenu = false;
	}

	function openCommunicationCenter() {
		const windowId = generateWindowId('communication-center');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Communication Center #${instanceNumber}`,
			component: CommunicationCenter,
			icon: '📞',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showNotificationsSubmenu = false;
		showNotificationsDashboardSubmenu = false;
	}

	// Open Start Receiving window
	function openStartReceiving() {
		collapseAllMenus();
		const windowId = generateWindowId('start-receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Start Receiving #${instanceNumber}`,
			component: StartReceiving,
			icon: '📦',
			size: { width: 1200, height: 800 },
			position: { 
				x: 100 + (Math.random() * 100),
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Receiving window
	function collapseAllSubsections() {
		showDeliveryDashboardSubmenu = false;
		showDeliveryManageSubmenu = false;
		showDeliveryOperationsSubmenu = false;
		showDeliveryReportsSubmenu = false;
		showVendorDashboardSubmenu = false;
		showVendorManagerSubmenu = false;
		showVendorOperationsSubmenu = false;
		showVendorReportsSubmenu = false;
		showMediaDashboardSubmenu = false;
		showMediaManageSubmenu = false;
		showMediaOperationsSubmenu = false;
		showMediaReportsSubmenu = false;
		showPromoDashboardSubmenu = false;
		showPromoManageSubmenu = false;
		showPromoOperationsSubmenu = false;
		showPromoReportsSubmenu = false;
		showFinanceDashboardSubmenu = false;
		showFinanceManageSubmenu = false;
		showFinanceOperationsSubmenu = false;
		showFinanceReportsSubmenu = false;
		showHRDashboardSubmenu = false;
		showHRManageSubmenu = false;
		showHROperationsSubmenu = false;
		showHRReportsSubmenu = false;
		showTasksDashboardSubmenu = false;
		showTasksManageSubmenu = false;
		showTasksOperationsSubmenu = false;
		showTasksReportsSubmenu = false;
		showNotificationsDashboardSubmenu = false;
		showNotificationsManageSubmenu = false;
		showNotificationsOperationsSubmenu = false;
		showNotificationsReportsSubmenu = false;
		showControlsDashboardSubmenu = false;
		showControlsManageSubmenu = false;
		showControlsOperationsSubmenu = false;
		showControlsReportsSubmenu = false;
		showUserDashboardSubmenu = false;
		showUserManageSubmenu = false;
		showUserOperationsSubmenu = false;
		showUserReportsSubmenu = false;
	}

	function collapseAllMenus() {
		collapseAllSubsections();
		showVendorSubmenu = false;
		showMediaSubmenu = false;
		showPromoSubmenu = false;
		showFinanceSubmenu = false;
		showHRSubmenu = false;
		showTasksSubmenu = false;
		showNotificationsSubmenu = false;
		showUserSubmenu = false;
	}

	function openReceiving() {
		collapseAllMenus();
		const windowId = generateWindowId('receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Receiving #${instanceNumber}`,
			component: Receiving,
			icon: '📦',
			size: { width: 1200, height: 800 },
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

	// Open Paid Manager window
	function openPaidManager() {
		collapseAllMenus();
		const windowId = generateWindowId('paid-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Paid Manager #${instanceNumber}`,
			component: PaidManager,
			icon: '💳',
			size: { width: 1200, height: 800 },
			position: { 
				x: 110 + (Math.random() * 100),
				y: 110 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Denomination window
	function openDenomination() {
		collapseAllMenus();
		const windowId = generateWindowId('denomination');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Denomination #${instanceNumber}`,
			component: Denomination,
			icon: '💵',
			size: { width: 900, height: 600 },
			position: { 
				x: 110 + (Math.random() * 100),
				y: 110 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Monthly Manager window
	function openMonthlyManager() {
		collapseAllMenus();
		const windowId = generateWindowId('monthly-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		let monthlyManagerRefreshFunction = null;
		
		openWindow({
			id: windowId,
			title: `Monthly Manager #${instanceNumber}`,
			component: MonthlyManager,
			props: {
				setRefreshCallback: (fn) => {
					monthlyManagerRefreshFunction = fn;
				},
				onRefresh: async () => {
					if (monthlyManagerRefreshFunction) {
						return await monthlyManagerRefreshFunction();
					}
				}
			},
			icon: '📅',
			size: { width: 1400, height: 900 },
			position: { 
				x: 130 + (Math.random() * 100),
				y: 130 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Monthly Breakdown window
	function openMonthlyBreakdown() {
		const windowId = generateWindowId('monthly-breakdown');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Monthly Breakdown #${instanceNumber}`,
			component: MonthlyBreakdown,
			props: {},
			icon: '📊',
			size: { width: 1400, height: 900 },
			position: { 
				x: 130 + (Math.random() * 100),
				y: 130 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Overdues Report window
	function openOverduesReport() {
		const windowId = generateWindowId('overdues-report');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Over dues #${instanceNumber}`,
			component: OverduesReport,
			icon: '⏰',
			size: { width: 1600, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showReportsSubmenu = false;
	}

	// Open Expense Manager window
	function openExpenseManager() {
		collapseAllMenus();
		const windowId = generateWindowId('expense-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Expenses Manager #${instanceNumber}`,
			component: ExpensesManager,
			icon: '�',
			size: { width: 1400, height: 900 },
			position: { 
				x: 140 + (Math.random() * 100),
				y: 140 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Category Manager window
	function openCategoryManager() {
		collapseAllMenus();
		const windowId = generateWindowId('category-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Category Manager #${instanceNumber}`,
			component: CategoryManager,
			icon: '📁',
			size: { width: 1000, height: 700 },
			position: { 
				x: 150 + (Math.random() * 100),
				y: 150 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Purchase Voucher Manager window
	function openPurchaseVoucherManager() {
		collapseAllMenus();
		
		// Use fixed window ID to prevent duplicates
		const windowId = 'purchase-voucher-manager-main';
		
		openWindow({
			id: windowId,
			title: `Purchase Voucher Manager`,
			component: PurchaseVoucherManager,
			icon: '📄',
			size: { width: 1100, height: 750 },
			position: { 
				x: 160 + (Math.random() * 100),
				y: 160 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Day Budget Planner window
	function openDayBudgetPlanner() {
		collapseAllMenus();
		const windowId = generateWindowId('day-budget-planner');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Day Budget Planner #${instanceNumber}`,
			component: DayBudgetPlanner,
			icon: '📊',
			size: { width: 1400, height: 900 },
			position: { 
				x: 160 + (Math.random() * 100),
				y: 160 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Manual Scheduling window
	function openManualScheduling() {
		collapseAllMenus();
		const windowId = generateWindowId('manual-scheduling');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manual Scheduling #${instanceNumber}`,
			component: ManualScheduling,
			icon: '📅',
			size: { width: 1200, height: 800 },
			position: { 
				x: 140 + (Math.random() * 100),
				y: 140 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Expense Tracker window
	function openExpenseTracker() {
		const windowId = generateWindowId('expense-tracker');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `💰 Expense Tracker #${instanceNumber}`,
			component: ExpenseTracker,
			icon: '💰',
			size: { width: 1600, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showReportsSubmenu = false;
	}

	// Open Sales Report window
	function openSalesReport() {
		const windowId = generateWindowId('sales-report');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Sales Report #${instanceNumber}`,
			component: SalesReport,
			icon: '📊',
			size: { width: 1600, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		maximizable: true,
		closable: true
	});
	showReportsSubmenu = false;
}

	// Open Vendor Pending Payments window
	function openVendorPendingPayments() {
		const windowId = generateWindowId('vendor-pending-payments');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Vendor Payments #${instanceNumber}`,
			component: VendorPendingPayments,
			icon: '💳',
			size: { width: 1600, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Vendor Records window
	function openVendorRecords() {
		collapseAllMenus();
		const windowId = generateWindowId('vendor-records');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Vendor Records #${instanceNumber}`,
			component: VendorRecords,
			icon: '📋',
			size: { width: 1600, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openReceivingRecords() {
		collapseAllMenus();
		const windowId = generateWindowId('receiving-records');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Receiving Records #${instanceNumber}`,
			component: ReceivingRecords,
			icon: '📋',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showVendorSubmenu = false;
	}

	// Media section functions
	function openFlyerMaster() {
		const windowId = generateWindowId('flyer-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Flyer Master #${instanceNumber}`,
			component: FlyerMasterDashboard,
			icon: '🏷️',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openProductMaster() {
		const windowId = generateWindowId('product-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Product Master #${instanceNumber}`,
			component: ProductMaster,
			icon: '📦',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openVariationManager() {
		const windowId = generateWindowId('variation-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Variation Manager #${instanceNumber}`,
			component: VariationManager,
			icon: '🔗',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openOfferProductEditor() {
		const windowId = generateWindowId('offer-product-editor');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Offer Product Editor #${instanceNumber}`,
			component: OfferTemplates,
			icon: '✅',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openCreateNewOffer() {
		const windowId = generateWindowId('create-new-offer');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Create New Offer #${instanceNumber}`,
			component: OfferProductSelector,
			icon: '🏷️',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openOfferManager() {
		const windowId = generateWindowId('offer-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Offer Manager #${instanceNumber}`,
			component: OfferManager,
			icon: '🎯',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openPricingManager() {
		const windowId = generateWindowId('pricing-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Pricing Manager #${instanceNumber}`,
			component: PricingManager,
			icon: '💵',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openGenerateFlyers() {
		const windowId = generateWindowId('generate-flyers');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Generate Flyers #${instanceNumber}`,
			component: FlyerGenerator,
			icon: '📄',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openFlyerTemplates() {
		const windowId = generateWindowId('flyer-templates');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Flyer Templates #${instanceNumber}`,
			component: FlyerTemplates,
			icon: '🎨',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openFlyerSettings() {
		const windowId = generateWindowId('flyer-settings');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Flyer Settings #${instanceNumber}`,
			component: FlyerSettings,
			icon: '⚙️',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openSocialLinkManager() {
		const windowId = generateWindowId('social-link-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Social Link Manager #${instanceNumber}`,
			component: SocialLinkManager,
			icon: '🔗',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openShelfPaperManager() {
		const windowId = generateWindowId('shelf-paper-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Shelf Paper Manager #${instanceNumber}`,
			component: DesignPlanner,
			icon: '🏷️',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMediaSubmenu = false;
	}

	function openCouponManagement() {
		const windowId = generateWindowId('coupon-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Coupon Management #${instanceNumber}`,
			component: CouponDashboard,
			icon: '🎁',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

	}

	// Promo section functions
	function openCouponDashboardPromo() {
		const windowId = generateWindowId('coupon-dashboard-promo');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Coupon Dashboard #${instanceNumber}`,
			component: CouponDashboard,
			icon: '🎁',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openCampaignManager() {
		const windowId = generateWindowId('campaign-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Campaign Manager #${instanceNumber}`,
			component: CampaignManager,
			icon: '📋',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openViewOfferManager() {
		const windowId = generateWindowId('view-offer-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `View Offer Manager #${instanceNumber}`,
			component: ViewOfferManager,
			icon: '📊',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openCustomerImporter() {
		const windowId = generateWindowId('customer-importer');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Import Customers #${instanceNumber}`,
			component: CustomerImporter,
			icon: '👥',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openProductManagerPromo() {
		const windowId = generateWindowId('product-manager-promo');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Product Manager #${instanceNumber}`,
			component: ProductManager,
			icon: '🎁',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openCouponReports() {
		const windowId = generateWindowId('coupon-reports');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Coupon Reports #${instanceNumber}`,
			component: CouponReports,
			icon: '📊',
			size: { width: 1400, height: 900 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openERPConnections() {
		const windowId = generateWindowId('erp-connections');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `ERP Connections #${instanceNumber}`,
			component: ERPConnections,
			icon: '🔌',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}

	// Show version changelog window
	function showVersionInfo() {
		const windowId = generateWindowId('version-changelog');
		
		openWindow({
			id: windowId,
			title: 'Version Changelog',
			component: VersionChangelog,
			size: { width: 800, height: 600 },
			position: { 
				x: 100, 
				y: 50 
			},
			resizable: true,
			minimizable: true,
			maximizable: true
		});
	}

	// User Section Functions (Placeholder)
	function openUserDashboard() {
		collapseAllMenus();
		// TODO: Add User Dashboard component
	}

	function openUserManage() {
		collapseAllMenus();
		// TODO: Add User Management component
	}

	function openUserOperations() {
		collapseAllMenus();
		// TODO: Add User Operations component
	}

	function openUserReports() {
		collapseAllMenus();
		// TODO: Add User Reports component
	}

	// User Management - Create User
	function openCreateUser() {
		collapseAllMenus();
		const windowId = generateWindowId('create-user');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create User #${instanceNumber}`,
			component: CreateUser,
			icon: '👤',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// User Management - Manage Admin Users
	function openManageAdminUsers() {
		collapseAllMenus();
		const windowId = generateWindowId('manage-admin-users');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manage Admin Users #${instanceNumber}`,
			component: ManageAdminUsers,
			icon: '👥',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// User Management - Manage Master Admin
	function openManageMasterAdmin() {
		collapseAllMenus();
		const windowId = generateWindowId('manage-master-admin');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manage Master Admin #${instanceNumber}`,
			component: ManageMasterAdmin,
			icon: '🔐',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}


</script>

<div class="sidebar">
	<div class="sidebar-content">
	<!-- Online/Offline Indicator -->
	<div class="connection-indicator {isOnline ? 'online' : 'offline'}">
		<div class="status-light"></div>
		<span class="status-text">{isOnline ? 'Online' : 'Offline'}</span>
	</div>
	
	<!-- Separator Line -->
	<div class="speed-separator"></div>

	<!-- Delivery Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showDeliverySubmenu = !showDeliverySubmenu}
		>
			<span class="section-icon">🚚</span>
			<span class="section-text">{t('nav.delivery') || 'Delivery'}</span>
			<span class="arrow" class:expanded={showDeliverySubmenu}>▼</span>
		</button>
	</div>

	<!-- Delivery Submenu - Inline below Delivery button -->
	{#if showDeliverySubmenu}
		<div class="submenu-inline delivery-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showDeliveryDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showDeliveryDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showDeliveryDashboardSubmenu}
				<div class="submenu-subitem-container">
					<!-- Dashboard items will be added here -->
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showDeliveryManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showDeliveryManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showDeliveryManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CUSTOMER_MASTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCustomerMaster}>
								<span class="menu-icon">🤝</span>
								<span class="menu-text">{t('admin.customerMaster') || 'Customer Master'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('AD_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openAdManager}>
								<span class="menu-icon">📢</span>
								<span class="menu-text">{t('admin.adManager') || 'Ad Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('PRODUCTS_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openProductsManager}>
								<span class="menu-icon">🛍️</span>
								<span class="menu-text">{t('admin.productsManager') || 'Products Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DELIVERY_SETTINGS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDeliverySettings}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">{t('admin.deliverySettings') || 'Delivery Settings'}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showDeliveryOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showDeliveryOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showDeliveryOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('ORDERS_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOrdersManager}>
								<span class="menu-icon">🛒</span>
								<span class="menu-text">{t('admin.ordersManager') || 'Orders Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('OFFER_MANAGEMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOfferManagement}>
								<span class="menu-icon">🎁</span>
								<span class="menu-text">{t('admin.offerManagement') || 'Offer Management'}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showDeliveryReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showDeliveryReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showDeliveryReportsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Reports items will be added here -->
				</div>
			{/if}
		</div>
	{/if}

	<!-- Vendor Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showVendorSubmenu = !showVendorSubmenu}
		>
			<span class="section-icon">📦</span>
			<span class="section-text">{t('nav.vendor') || 'Vendor'}</span>
			<span class="arrow" class:expanded={showVendorSubmenu}>▼</span>
		</button>
	</div>

	<!-- Vendor Submenu - Inline below Vendor button -->
	{#if showVendorSubmenu}
		<div class="submenu-inline vendor-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showVendorDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showVendorDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showVendorDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('RECEIVING')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openReceiving}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">Receiving</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showVendorManagerSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showVendorManagerSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manager Subsection Items -->
			{#if showVendorManagerSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('UPLOAD_VENDOR')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openUploadVendor}>
								<span class="menu-icon">📤</span>
								<span class="menu-text">{t('admin.uploadVendor') || 'Upload Vendor'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_VENDOR')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateVendor}>
								<span class="menu-icon">➕</span>
								<span class="menu-text">{t('admin.createVendor') || 'Create Vendor'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MANAGE_VENDOR')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageVendor}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">{t('admin.manageVendor') || 'Manage Vendor'}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showVendorOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showVendorOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showVendorOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('START_RECEIVING')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openStartReceiving}>
								<span class="menu-icon">🚀</span>
								<span class="menu-text">{t('nav.startReceiving') || 'Start Receiving'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('RECEIVING_RECORDS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openReceivingRecords}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">Receiving Records</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showVendorReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showVendorReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showVendorReportsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('VENDOR_RECORDS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openVendorRecords}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">{t('reports.vendorRecords') || 'Vendor Records'}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}

	<!-- Media Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showMediaSubmenu = !showMediaSubmenu}
		>
			<span class="section-icon">🎬</span>
			<span class="section-text">{t('nav.media') || 'Media'}</span>
			<span class="arrow" class:expanded={showMediaSubmenu}>▼</span>
		</button>
	</div>

	<!-- Media Submenu - Inline below Media button -->
	{#if showMediaSubmenu}
		<div class="submenu-inline media-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showMediaDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showMediaDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

		<!-- Dashboard Subsection Items -->
		{#if showMediaDashboardSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('FLYER_MASTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openFlyerMaster}>
							<span class="menu-icon">🏷️</span>
							<span class="menu-text">Flyer Master</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showMediaManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showMediaManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manager Subsection Items -->
			{#if showMediaManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('PRODUCT_MASTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openProductMaster}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">Product Master</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('VARIATION_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openVariationManager}>
								<span class="menu-icon">🔗</span>
								<span class="menu-text">Variation Manager</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('OFFER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOfferManager}>
								<span class="menu-icon">🎯</span>
								<span class="menu-text">Offer Manager</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('FLYER_TEMPLATES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openFlyerTemplates}>
								<span class="menu-icon">🎨</span>
								<span class="menu-text">Flyer Templates</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('FLYER_SETTINGS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openFlyerSettings}>
								<span class="menu-icon">⚙️</span>
								<span class="menu-text">Settings</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SOCIAL_LINK_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSocialLinkManager}>
								<span class="menu-icon">🔗</span>
								<span class="menu-text">Social Link Manager</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showMediaOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showMediaOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showMediaOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('OFFER_PRODUCT_EDITOR')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOfferProductEditor}>
								<span class="menu-icon">✅</span>
								<span class="menu-text">Offer Product Editor</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_NEW_OFFER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateNewOffer}>
								<span class="menu-icon">🏷️</span>
								<span class="menu-text">Create New Offer</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('PRICING_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPricingManager}>
								<span class="menu-icon">💵</span>
								<span class="menu-text">Pricing Manager</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('GENERATE_FLYERS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openGenerateFlyers}>
								<span class="menu-icon">📄</span>
								<span class="menu-text">Generate Flyers</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SHELF_PAPER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openShelfPaperManager}>
								<span class="menu-icon">🏷️</span>
								<span class="menu-text">Shelf Paper Manager</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showMediaReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showMediaReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>
		</div>
	{/if}

	<!-- Promo Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showPromoSubmenu = !showPromoSubmenu}
		>
			<span class="section-icon">🎁</span>
			<span class="section-text">{t('nav.promo') || 'Promo'}</span>
			<span class="arrow" class:expanded={showPromoSubmenu}>▼</span>
		</button>
	</div>

	<!-- Promo Submenu - Inline below Promo button -->
	{#if showPromoSubmenu}
		<div class="submenu-inline promo-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showPromoDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showPromoDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
				
				<span class="menu-text">Dashboard</span>
			</button>
		</div>

		<!-- Dashboard Subsection Items -->
		{#if showPromoDashboardSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('COUPON_DASHBOARD_PROMO')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCouponDashboardPromo}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">Coupon Dashboard</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Manage Subsection -->
		<div class="submenu-item-container">
			<button 
				class="submenu-subsection-button icon-only"
				on:click={() => {
					if (showPromoManageSubmenu) {
						collapseAllSubsections();
					} else {
						collapseAllSubsections();
						showPromoManageSubmenu = true;
					}
				}}
				title="Manage"
			>
				
				<span class="menu-text">Manage</span>
			</button>
		</div>

		<!-- Manage Subsection Items -->
		{#if showPromoManageSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('CAMPAIGN_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCampaignManager}>
							<span class="menu-icon">📋</span>
							<span class="menu-text">Manage Campaigns</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Operations Subsection -->
		<div class="submenu-item-container">
			<button 
				class="submenu-subsection-button icon-only"
				on:click={() => {
					if (showPromoOperationsSubmenu) {
						collapseAllSubsections();
					} else {
						collapseAllSubsections();
						showPromoOperationsSubmenu = true;
					}
				}}
				title="Operations"
			>
				
				<span class="menu-text">Operations</span>
			</button>
		</div>

		<!-- Operations Subsection Items -->
		{#if showPromoOperationsSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('VIEW_OFFER_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openViewOfferManager}>
							<span class="menu-icon">📊</span>
							<span class="menu-text">View Offer Manager</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('CUSTOMER_IMPORTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCustomerImporter}>
							<span class="menu-icon">👥</span>
							<span class="menu-text">Import Customers</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('PRODUCT_MANAGER_PROMO')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openProductManagerPromo}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">Manage Products</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Reports Subsection -->
		<div class="submenu-item-container">
			<button 
				class="submenu-subsection-button icon-only"
				on:click={() => {
					if (showPromoReportsSubmenu) {
						collapseAllSubsections();
					} else {
						collapseAllSubsections();
						showPromoReportsSubmenu = true;
					}
				}}
				title="Reports"
			>
				
				<span class="menu-text">Reports</span>
			</button>
		</div>

		<!-- Reports Subsection Items -->
		{#if showPromoReportsSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('COUPON_REPORTS')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCouponReports}>
							<span class="menu-icon">📊</span>
							<span class="menu-text">Reports & Stats</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}
	</div>
{/if}	<!-- Finance Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showFinanceSubmenu = !showFinanceSubmenu}
		>
			<span class="section-icon">💰</span>
			<span class="section-text">{t('nav.finance') || 'Finance'}</span>
			<span class="arrow" class:expanded={showFinanceSubmenu}>▼</span>
		</button>
	</div>

	<!-- Finance Submenu - Inline below Finance button -->
	{#if showFinanceSubmenu}
		<div class="submenu-inline finance-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showFinanceDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showFinanceDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showFinanceDashboardSubmenu}
				<div class="submenu-subitem-container">
					<!-- Dashboard items will be added here -->
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showFinanceManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showFinanceManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showFinanceManageSubmenu}
				<div class="submenu-subitem-container">
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCategoryManager}>
							<span class="menu-icon">📁</span>
							<span class="menu-text">Category Manager</span>
						</button>
					</div>
					{#if isButtonAllowed('PURCHASE_VOUCHER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPurchaseVoucherManager}>
								<span class="menu-icon">📄</span>
								<span class="menu-text">Purchase Voucher Manager</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showFinanceOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showFinanceOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showFinanceOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('MANUAL_SCHEDULING')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManualScheduling}>
								<span class="menu-icon">📅</span>
								<span class="menu-text">Manual Scheduling</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DAY_BUDGET_PLANNER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDayBudgetPlanner}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">Day Budget Planner</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MONTHLY_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openMonthlyManager}>
								<span class="menu-icon">📅</span>
								<span class="menu-text">{t('nav.monthlyManager') || 'Monthly Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('EXPENSE_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openExpenseManager}>
								<span class="menu-icon">💸</span>
								<span class="menu-text">{t('nav.expenseManager') || 'Expense Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('PAID_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPaidManager}>
								<span class="menu-icon">💳</span>
								<span class="menu-text">{t('nav.paidManager') || 'Paid Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DENOMINATION')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDenomination}>
								<span class="menu-icon">💵</span>
								<span class="menu-text">Denomination</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						collapseAllSubsections();
						showFinanceReportsSubmenu = true;
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showFinanceReportsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('EXPENSE_TRACKER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openExpenseTracker}>
								<span class="menu-icon">💰</span>
								<span class="menu-text">{t('reports.expenseTracker') || 'Expense Tracker'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SALES_REPORT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSalesReport}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('reports.salesReport') || 'Sales Report'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MONTHLY_BREAKDOWN')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openMonthlyBreakdown}>
								<span class="menu-icon">📅</span>
								<span class="menu-text">{t('nav.monthlyBreakdown') || 'Monthly Breakdown'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('OVERDUES_REPORT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOverduesReport}>
								<span class="menu-icon">⏰</span>
								<span class="menu-text">Over dues</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('VENDOR_PAYMENTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openVendorPendingPayments}>
								<span class="menu-icon">💳</span>
								<span class="menu-text">{t('reports.vendorPayments') || 'Vendor Payments'}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}

	<!-- HR Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showHRSubmenu = !showHRSubmenu}
		>
			<span class="section-icon">👥</span>
			<span class="section-text">{t('nav.hr') || 'HR'}</span>
			<span class="arrow" class:expanded={showHRSubmenu}>▼</span>
		</button>
	</div>

	<!-- HR Submenu - Inline below HR button -->
	{#if showHRSubmenu}
		<div class="submenu-inline hr-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showHRDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showHRDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showHRDashboardSubmenu}
				<div class="submenu-subitem-container">
					<!-- Dashboard items will be added here -->
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showHRManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showHRManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showHRManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('UPLOAD_EMPLOYEES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openUploadEmployees}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">Upload Employees</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_DEPARTMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateDepartment}>
								<span class="menu-icon">🏢</span>
								<span class="menu-text">Create Department</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_LEVEL')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateLevel}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">Create Level</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_POSITION')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreatePosition}>
								<span class="menu-icon">💼</span>
								<span class="menu-text">Create Position</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('REPORTING_MAP')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openReportingMap}>
								<span class="menu-icon">📈</span>
								<span class="menu-text">Reporting Map</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('ASSIGN_POSITIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openAssignPositions}>
								<span class="menu-icon">🎯</span>
								<span class="menu-text">Assign Positions</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CONTACT_MANAGEMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openContactManagement}>
								<span class="menu-icon">📞</span>
								<span class="menu-text">Contact Management</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DOCUMENT_MANAGEMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDocumentManagement}>
								<span class="menu-icon">📄</span>
								<span class="menu-text">Document Management</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SALARY_MANAGEMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSalaryManagement}>
								<span class="menu-icon">💰</span>
								<span class="menu-text">Salary & Wage Management</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WARNING_MASTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWarningMaster}>
								<span class="menu-icon">⚠️</span>
								<span class="menu-text">Warning Master</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showHROperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showHROperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showHROperationsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Operations items will be added here -->
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showHRReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showHRReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showHRReportsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('BIOMETRIC_DATA')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openBiometricData}>
								<span class="menu-icon">👆</span>
								<span class="menu-text">Biometric Data</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('EXPORT_BIOMETRIC_DATA')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openExportBiometricData}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">Export Biometric Data</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}

	<!-- Tasks Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showTasksSubmenu = !showTasksSubmenu}
		>
			<span class="section-icon">✅</span>
			<span class="section-text">{t('nav.tasks') || 'Tasks'}</span>
			<span class="arrow" class:expanded={showTasksSubmenu}>▼</span>
		</button>
	</div>

	<!-- Tasks Submenu - Inline below Tasks button -->
	{#if showTasksSubmenu}
		<div class="submenu-inline tasks-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showTasksDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showTasksDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

		<!-- Dashboard Subsection Items -->
		{#if showTasksDashboardSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('TASK_MASTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openTaskMaster}>
							<span class="menu-icon">✅</span>
							<span class="menu-text">{t('admin.taskMaster') || 'Task Master'}</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showTasksManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showTasksManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showTasksManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CREATE_TASK')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateTask}>
								<span class="menu-icon">✨</span>
								<span class="menu-text">Create Task Template</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('VIEW_TASKS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openViewTasks}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">View Task Templates</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showTasksOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showTasksOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showTasksOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('ASSIGN_TASKS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openAssignTasks}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">Assign Tasks</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						collapseAllSubsections();
						showTasksReportsSubmenu = true;
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showTasksReportsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('MY_TASKS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openMyTasks}>
								<span class="menu-icon">📝</span>
								<span class="menu-text">View My Tasks</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MY_ASSIGNMENTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openMyAssignments}>
								<span class="menu-icon">👨‍💼</span>
								<span class="menu-text">View My Assignments</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('TASK_STATUS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openTaskStatus}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">Task Status</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('BRANCH_PERFORMANCE_WINDOW')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openBranchPerformanceWindow}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">Branch Performance</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}

	<!-- Notifications Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showNotificationsSubmenu = !showNotificationsSubmenu}
		>
			<span class="section-icon">🔔</span>
			<span class="section-text">{t('nav.notification') || 'Notification'}</span>
			<span class="arrow" class:expanded={showNotificationsSubmenu}>▼</span>
		</button>
	</div>

	<!-- Notifications Submenu -->
	{#if showNotificationsSubmenu}
		<div class="submenu-inline">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showNotificationsDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showNotificationsDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showNotificationsDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('COMMUNICATION_CENTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCommunicationCenter}>
								<span class="menu-icon">📞</span>
								<span class="menu-text">{t('admin.communicationCenter') || 'Com Center'}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showNotificationsManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showNotificationsManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showNotificationsManageSubmenu}
				<div class="submenu-subitem-container">
					<!-- Manage items will be added here -->
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showNotificationsOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showNotificationsOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showNotificationsOperationsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Operations items will be added here -->
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showNotificationsReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showNotificationsReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showNotificationsReportsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Reports items will be added here -->
				</div>
			{/if}
		</div>
	{/if}

	<!-- User Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showUserSubmenu = !showUserSubmenu}
		>
			<span class="section-icon">👤</span>
			<span class="section-text">{t('nav.users') || 'Users'}</span>
			<span class="arrow" class:expanded={showUserSubmenu}>▼</span>
		</button>
	</div>

	<!-- User Submenu - Inline below User button -->
	{#if showUserSubmenu}
		<div class="submenu-inline user-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showUserDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showUserDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showUserDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('USER_MANAGEMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openUserManagement}>
								<span class="menu-icon">👤</span>
								<span class="menu-text">Users</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showUserManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showUserManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manager Subsection Items -->
			{#if showUserManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CREATE_USER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateUser}>
								<span class="menu-icon">👤</span>
								<span class="menu-text">Create User</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MANAGE_ADMIN_USERS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageAdminUsers}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">Manage Admin Users</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MANAGE_MASTER_ADMIN')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageMasterAdmin}>
								<span class="menu-icon">🔐</span>
								<span class="menu-text">Manage Master Admin</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('INTERFACE_ACCESS_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openInterfaceAccessManager}>
								<span class="menu-icon">🔧</span>
								<span class="menu-text">Interface Access</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('APPROVAL_PERMISSIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openApprovalPermissions}>
								<span class="menu-icon">🔐</span>
								<span class="menu-text">Approval Permissions</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showUserOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showUserOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showUserOperationsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Operations items will be added here -->
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showUserReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showUserReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showUserReportsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Reports items will be added here -->
				</div>
			{/if}
		</div>
	{/if}

	<!-- Controls Section -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showControlsSubmenu = !showControlsSubmenu}
		>
			<span class="section-icon">⚙️</span>
			<span class="section-text">{t('nav.controls') || 'Controls'}</span>
			<span class="arrow" class:expanded={showControlsSubmenu}>▼</span>
		</button>
	</div>

	<!-- Controls Submenu - Inline below Controls button -->
	{#if showControlsSubmenu}
		<div class="submenu-inline controls-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showControlsDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showControlsDashboardSubmenu = true;
						}
					}}
					title="Dashboard"
				>
					
					<span class="menu-text">Dashboard</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showControlsDashboardSubmenu}
				<div class="submenu-subitem-container">
					<!-- Dashboard items will be added here -->
				</div>
			{/if}

			<!-- Manage Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showControlsManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showControlsManageSubmenu = true;
						}
					}}
					title="Manage"
				>
					
					<span class="menu-text">Manage</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showControlsManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('BRANCHES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openBranches}>
								<span class="menu-icon">🏢</span>
								<span class="menu-text">{t('admin.branchesMaster') || 'Branch Master'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SETTINGS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSettings}>
								<span class="menu-icon">🔊</span>
								<span class="menu-text">{t('nav.soundSettings') || 'Sound Settings'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('E_R_P_CONNECTIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openERPConnections}>
								<span class="menu-icon">🔌</span>
								<span class="menu-text">{t('nav.erpConnections') || 'ERP Connections'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CLEAR_TABLES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openClearTables}>
								<span class="menu-icon">🗑️</span>
								<span class="menu-text">{t('nav.clearTables') || 'Clear Tables'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('BUTTON_ACCESS_CONTROL')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openButtonAccessControl}>
								<span class="menu-icon">🎛️</span>
								<span class="menu-text">Button Access Control</span>
							</button>
						</div>
					{/if}
				{#if isButtonAllowed('BUTTON_GENERATOR')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openButtonGenerator}>
							<span class="menu-icon">🔨</span>
							<span class="menu-text">Button Generator</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}			<!-- Operations Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showControlsOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showControlsOperationsSubmenu = true;
						}
					}}
					title="Operations"
				>
					
					<span class="menu-text">Operations</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showControlsOperationsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Operations items will be added here -->
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showControlsReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showControlsReportsSubmenu = true;
						}
					}}
					title="Reports"
				>
					
					<span class="menu-text">Reports</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showControlsReportsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Reports items will be added here -->
				</div>
			{/if}
		</div>
	{/if}

	</div>
	<!-- Sidebar Footer -->
	<div class="sidebar-footer">
		<!-- Version Information -->
		<div class="version-info">
			<button class="version-text" on:click={showVersionInfo} title="Click to see what's new">
				AQ32.12.7.7
			</button>
		</div>
	</div>
</div>

<style>
	.sidebar-header {
		padding: 0.75rem;
		margin-bottom: 0.5rem;
	}

	.interface-switch-btn {
		width: 100%;
		padding: 0.5rem 1rem;
		background: linear-gradient(145deg, #3b82f6, #2563eb);
		border: none;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		box-shadow: 
			0 2px 4px rgba(59, 130, 246, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.2),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
		text-shadow: 0 1px 1px rgba(0, 0, 0, 0.3);
	}

	.interface-switch-btn:hover {
		background: linear-gradient(145deg, #2563eb, #1d4ed8);
		transform: translateY(-1px);
		box-shadow: 
			0 3px 6px rgba(59, 130, 246, 0.4),
			inset 0 1px 0 rgba(255, 255, 255, 0.2),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
	}

	.interface-switch-btn:active {
		transform: translateY(1px);
		box-shadow: 
			0 1px 2px rgba(59, 130, 246, 0.3),
			inset 0 1px 3px rgba(0, 0, 0, 0.2);
	}

	.interface-switch-btn:active {
		transform: translateY(1px);
		box-shadow: 
			0 1px 2px rgba(59, 130, 246, 0.3),
			inset 0 1px 3px rgba(0, 0, 0, 0.2);
	}

	.sidebar {
		position: fixed;
		left: 0;
		top: 0;
		bottom: 56px; /* Fixed taskbar height */
		width: 154px;
		background: #374151;
		color: #e5e7eb;
		display: flex;
		flex-direction: column;
		box-shadow: 2px 0 10px rgba(0, 0, 0, 0.3);
		z-index: 1200;
		border-right: 1px solid #1f2937;
	}

	.sidebar-content {
		flex: 1;
		padding: 15px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 15px;
		/* Reserve space for footer */
		padding-bottom: 70px;
	}

	.menu-section {
		display: flex;
		flex-direction: column;
		position: relative;
		margin-bottom: 8px; /* Consistent spacing between sections */
	}

	.section-button {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 10px 8px;
		background: #1DBC83;
		border: none;
		color: white;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
	}

	.section-button:hover {
		background: #3b82f6;
		color: white;
		transform: translateX(2px);
	}

	.section-button:active {
		transform: translateX(2px) scale(0.98);
	}

	/* Special styling for Approval Center button */
	.approval-button {
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.3);
	}

	.approval-button:hover {
		background: rgba(16, 185, 129, 0.2);
		border-color: rgba(16, 185, 129, 0.5);
		color: #10B981;
	}

	.approval-button .section-icon {
		filter: drop-shadow(0 0 4px rgba(16, 185, 129, 0.5));
	}

	.section-icon {
		font-size: 16px;
		flex-shrink: 0;
		width: 20px; /* Fixed width for consistent alignment */
		height: 16px; /* Fixed height */
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
	}

	.section-text {
		flex: 1;
		white-space: normal;
		overflow: visible;
		text-overflow: clip;
		font-weight: 500;
		line-height: 1.3;
		word-wrap: break-word;
		word-break: break-word;
		max-width: 100%;
	}

	.arrow {
		font-size: 10px;
		opacity: 0.7;
		transition: transform 0.2s ease;
		flex-shrink: 0;
	}

	.arrow.expanded {
		transform: rotate(180deg);
	}

	.submenu-item {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 10px 8px;
		background: white;
		border: none;
		color: #f97316;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
		font-weight: 500;
		margin-bottom: 2px;
	}

	.submenu-item:hover {
		background: #3b82f6;
		color: white;
		transform: translateX(2px);
	}

	.submenu-item:active {
		transform: translateX(2px) scale(0.98);
	}

	.submenu-item:last-child {
		margin-bottom: 0;
	}

	/* Inline submenu below Work button */
	.submenu-inline {
		padding: 0px 0 0px 0;
		margin-bottom: 0px;
		background: transparent;
		border-radius: 8px;
		animation: slideDown 0.2s ease;
		display: flex;
		flex-direction: column;
		align-items: center;
		position: relative;
	}

	.submenu-inline.vendor-submenu {
		padding: 0px 0 0px 4px;
		margin-bottom: 0px;
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			max-height: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			max-height: 200px;
			transform: translateY(0);
		}
	}

	/* Individual container for each submenu button */
	.submenu-item-container {
		background: transparent;
		border-radius: 0;
		margin-bottom: 6px;
		padding: 0;
		border: none;
		display: flex;
		justify-content: center;
		width: 100%;
	}

	.submenu-item-container:last-child {
		margin-bottom: 0;
	}

	.submenu-item-container:hover {
		background: transparent;
		border-color: transparent;
	}

	/* No margin bottom for manage subsection first item */
	.submenu-inline.vendor-submenu > .submenu-item-container:first-child {
		margin-bottom: 6px;
	}

	.submenu-inline .submenu-item {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 10px 8px;
		background: white;
		border: none;
		color: #f97316;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
		font-weight: 500;
		margin-bottom: 4px;
	}

	.submenu-inline .submenu-item:hover {
		background: #3b82f6;
		color: white;
		transform: translateX(2px);
	}

	.menu-icon {
		font-size: 16px;
		flex-shrink: 0;
		width: 20px;
		height: 16px;
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
		color: inherit;
	}

	.menu-icon-img {
		width: 32px;
		height: 32px;
		flex-shrink: 0;
		object-fit: contain;
		filter: brightness(0) saturate(100%) invert(85%) sepia(74%) saturate(487%) hue-rotate(169deg);
	}

	.menu-text {
		flex: 1;
		white-space: normal;
		overflow: visible;
		text-overflow: clip;
		font-weight: 500;
		word-wrap: break-word;
		word-break: break-word;
		line-height: 1.3;
		max-width: 100%;
		color: inherit;
	}

	/* Subsection styling - Matching main section button style */
	.submenu-subsection-button {
		width: 100%;
		margin: 0;
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 10px 8px;
		background: #1DBC83;
		border: none;
		color: white;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 11px;
		min-height: 40px;
		text-align: left;
		font-weight: 500;
	}

	.submenu-subsection-button:hover {
		background: #3b82f6;
		color: white;
		transform: translateX(2px);
	}

	.submenu-subsection-button:active {
		transform: translateX(2px) scale(0.98);
	}

	.submenu-subsection-button .menu-icon {
		font-size: 16px;
		margin: 0;
		flex-shrink: 0;
		width: 20px;
		height: 16px;
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
	}

	.submenu-subsection-button .menu-text {
		flex: 1;
		white-space: normal;
		overflow: visible;
		text-overflow: clip;
		font-weight: 500;
		line-height: 1.3;
		word-wrap: break-word;
		word-break: break-word;
		max-width: 100%;
	}

	.submenu-subsection-button .arrow {
		font-size: 10px;
		opacity: 0.7;
		transition: transform 0.2s ease;
		flex-shrink: 0;
	}

	.submenu-subsection-button.icon-only {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 10px 8px;
		background: #1DBC83;
		border: none;
		color: white;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
		margin: 0;
	}

	.submenu-subsection-button.icon-only .menu-icon-img {
		margin: 0;
		width: 20px;
		height: 16px;
		flex-shrink: 0;
		object-fit: contain;
		filter: brightness(0) saturate(100%) invert(85%) sepia(74%) saturate(487%) hue-rotate(169deg);
	}

	.submenu-subsection-button.icon-only .menu-text {
		flex: 1;
		white-space: normal;
		overflow: visible;
		text-overflow: clip;
		font-weight: 500;
		line-height: 1.3;
		word-wrap: break-word;
		word-break: break-word;
		max-width: 100%;
		font-size: 11px;
	}

	.submenu-subsection-button.icon-only .arrow {
		display: inline-block;
		font-size: 10px;
		opacity: 0.7;
	}

	.submenu-subsection-button .arrow.expanded {
		transform: rotate(180deg);
	}

	/* Nested submenu items container */
	.submenu-subitem-container {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-left: 12px;
		padding: 4px 0;
		border-left: none;
		padding-left: 8px;
	}

	.submenu-subitem-container .submenu-item-container {
		margin-bottom: 0;
	}

	.submenu-subitem-container .submenu-item-container:hover {
		background: transparent;
		border-color: transparent;
	}

	/* Scrollbar styling */
	.sidebar-content::-webkit-scrollbar {
		width: 6px;
	}

	.sidebar-content::-webkit-scrollbar-track {
		background: transparent;
	}

	.sidebar-content::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.2);
		border-radius: 3px;
	}

	.sidebar-content::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	/* Sidebar Footer */
	.sidebar-footer {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		padding: 10px 15px;
		border-top: 1px solid #1f2937;
		background: #374151;
		backdrop-filter: blur(10px);
	}

	.pwa-install-button {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 12px;
		background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
		border: none;
		color: white;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		height: 36px;
		text-align: center;
		font-weight: 500;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.pwa-install-button:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
	}

	.pwa-install-button:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.pwa-not-supported {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		opacity: 0.7;
	}

	.pwa-not-supported:hover {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		opacity: 0.8;
	}

	.pwa-installed {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 12px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		border-radius: 6px;
		color: white;
		font-size: 11px;
		font-weight: 500;
		opacity: 0.8;
	}

	.pwa-icon {
		font-size: 14px;
		flex-shrink: 0;
	}

	.pwa-text {
		font-weight: 500;
		white-space: nowrap;
	}

	/* Version Information */
	.version-info {
		margin-top: 8px;
		text-align: center;
		border-top: 1px solid rgba(107, 114, 128, 0.3);
		padding-top: 6px;
	}

	.version-text {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		border: 1px solid rgba(255, 255, 255, 0.2);
		color: white;
		font-size: 11px;
		font-weight: 600;
		font-family: monospace;
		letter-spacing: 0.5px;
		cursor: pointer;
		padding: 6px 12px;
		border-radius: 6px;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
		text-transform: uppercase;
		width: 100%;
		text-align: center;
	}

	.version-text:hover {
		background: linear-gradient(135deg, #5b21b6 0%, #7c3aed 100%);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
	}

	.version-text:active {
		transform: translateY(0);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	/* Connection Indicator Styles */
	.connection-indicator {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 12px;
		border-radius: 8px;
		margin-bottom: 8px;
		transition: all 0.3s ease;
	}

	.connection-indicator.online {
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.3);
	}

	.connection-indicator.offline {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid rgba(239, 68, 68, 0.3);
	}

	.status-light {
		width: 12px;
		height: 12px;
		border-radius: 50%;
		flex-shrink: 0;
		transition: all 0.3s ease;
		box-shadow: 0 0 8px currentColor;
	}

	.connection-indicator.online .status-light {
		background: #10b981;
		animation: pulseGreen 2s ease-in-out infinite;
	}

	.connection-indicator.offline .status-light {
		background: #ef4444;
		animation: pulseRed 2s ease-in-out infinite;
	}

	@keyframes pulseGreen {
		0%, 100% {
			box-shadow: 0 0 8px #10b981;
			opacity: 1;
		}
		50% {
			box-shadow: 0 0 16px #10b981;
			opacity: 0.8;
		}
	}

	@keyframes pulseRed {
		0%, 100% {
			box-shadow: 0 0 8px #ef4444;
			opacity: 1;
		}
		50% {
			box-shadow: 0 0 16px #ef4444;
			opacity: 0.8;
		}
	}

	.status-text {
		font-size: 13px;
		font-weight: 600;
		color: white;
		flex: 1;
	}

	.connection-indicator.online .status-text {
		color: #34d399;
	}

	.connection-indicator.offline .status-text {
		color: #f87171;
	}

	.speed-separator {
		height: 2px;
		background: linear-gradient(90deg, transparent, rgba(156, 163, 175, 0.5), transparent);
		margin: 12px 0;
		border-top: 1px solid rgba(107, 114, 128, 0.3);
	}
</style>




