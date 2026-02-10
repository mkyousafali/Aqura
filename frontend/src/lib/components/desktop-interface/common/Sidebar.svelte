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
	import { favoritesStore, favoritesPanelOpen } from '$lib/stores/favorites';
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
	import BankReconciliation from '$lib/components/desktop-interface/master/finance/BankReconciliation.svelte';
	import Denomination from '$lib/components/desktop-interface/master/finance/Denomination.svelte';
	import PettyCash from '$lib/components/desktop-interface/master/finance/PettyCash.svelte';
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
	import ErpEntryManager from '$lib/components/desktop-interface/marketing/flyer/ErpEntryManager.svelte';
	import FlyerGenerator from '$lib/components/desktop-interface/marketing/flyer/FlyerGenerator.svelte';
	import FlyerTemplates from '$lib/components/desktop-interface/marketing/flyer/FlyerTemplates.svelte';
	import FlyerSettings from '$lib/components/desktop-interface/marketing/flyer/FlyerSettings.svelte';
	import DesignPlanner from '$lib/components/desktop-interface/marketing/flyer/DesignPlanner.svelte';
	import NearExpiryManager from '$lib/components/desktop-interface/marketing/flyer/NearExpiryManager.svelte';
	import NormalPaperManager from '$lib/components/desktop-interface/marketing/flyer/NormalPaperManager.svelte';
	import OneDayOfferManager from '$lib/components/desktop-interface/marketing/flyer/OneDayOfferManager.svelte';
	import ExpenseTracker from '$lib/components/desktop-interface/master/finance/reports/ExpenseTracker.svelte';
	import SalesReport from '$lib/components/desktop-interface/master/finance/reports/SalesReport.svelte';
	import VendorPendingPayments from '$lib/components/desktop-interface/master/finance/reports/VendorPendingPayments.svelte';
	import VendorRecords from '$lib/components/desktop-interface/master/finance/reports/VendorRecords.svelte';
	import OverduesReport from '$lib/components/desktop-interface/master/finance/reports/OverduesReport.svelte';
	import POSReport from '$lib/components/desktop-interface/master/finance/reports/POSReport.svelte';
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
	import CreateDepartment from '$lib/components/desktop-interface/master/hr/CreateDepartment.svelte';
	import CreateLevel from '$lib/components/desktop-interface/master/hr/CreateLevel.svelte';
	import CreatePosition from '$lib/components/desktop-interface/master/hr/CreatePosition.svelte';
	import ReportingMap from '$lib/components/desktop-interface/master/hr/ReportingMap.svelte';
	import AssignPositions from '$lib/components/desktop-interface/master/hr/AssignPositions.svelte';
	import BiometricExport from '$lib/components/desktop-interface/master/hr/BiometricExport.svelte';
	import LinkID from '$lib/components/desktop-interface/master/hr/LinkID.svelte';
	import FingerprintTransactions from '$lib/components/desktop-interface/master/hr/FingerprintTransactions.svelte';
	import ProcessFingerprint from '$lib/components/desktop-interface/master/hr/ProcessFingerprint.svelte';
	import EmployeeFiles from '$lib/components/desktop-interface/master/hr/EmployeeFiles.svelte';
	import SalaryAndWage from '$lib/components/desktop-interface/master/hr/SalaryAndWage.svelte';
	import ShiftAndDayOff from '$lib/components/desktop-interface/master/hr/ShiftAndDayOff.svelte';
	import LeavesAndVacations from '$lib/components/desktop-interface/master/hr/LeavesAndVacations.svelte';
	import Discipline from '$lib/components/desktop-interface/master/hr/Discipline.svelte';
	import IncidentManager from '$lib/components/desktop-interface/master/hr/IncidentManager.svelte';
	import ReportIncident from '$lib/components/desktop-interface/master/hr/ReportIncident.svelte';
	import DailyChecklistManager from '$lib/components/desktop-interface/master/hr/DailyChecklistManager.svelte';
	import LeaveRequest from '$lib/components/desktop-interface/master/hr/LeaveRequest.svelte';
	import TaskCreateForm from '$lib/components/desktop-interface/master/tasks/TaskCreateForm.svelte';
	import TaskViewTable from '$lib/components/desktop-interface/master/tasks/TaskViewTable.svelte';
	import TaskAssignmentView from '$lib/components/desktop-interface/master/tasks/TaskAssignmentView.svelte';
	import MyTasksView from '$lib/components/desktop-interface/master/tasks/MyTasksView.svelte';
	import MyAssignmentsView from '$lib/components/desktop-interface/master/tasks/MyAssignmentsView.svelte';
	import TaskStatusView from '$lib/components/desktop-interface/master/tasks/TaskStatusView.svelte';
	import BranchPerformanceWindow from '$lib/components/desktop-interface/master/tasks/BranchPerformanceWindow.svelte';
	import PushNotificationSettings from '$lib/components/common/PushNotificationSettings.svelte';
	import CreateNotification from '$lib/components/desktop-interface/master/communication/CreateNotification.svelte';

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
	let showFinancePettyCashWindow = false;
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

	// Sidebar view mode: 'standard' or 'favorites'
	let sidebarViewMode: 'standard' | 'favorites' = 'standard';

	// Subscribe to favorites store
	$: userFavorites = $favoritesStore;

	// Map button_code to translation key for multilingual support
	const buttonCodeTranslationMap: Record<string, string> = {
		'CUSTOMER_MASTER': 'admin.customerMaster', 'AD_MANAGER': 'admin.adManager',
		'PRODUCTS_MANAGER': 'admin.productsManager', 'DELIVERY_SETTINGS': 'admin.deliverySettings',
		'ORDERS_MANAGER': 'admin.ordersManager', 'OFFER_MANAGEMENT': 'admin.offerManagement',
		'RECEIVING': 'nav.receiving', 'UPLOAD_VENDOR': 'admin.uploadVendor',
		'CREATE_VENDOR': 'admin.createVendor', 'MANAGE_VENDOR': 'admin.manageVendor',
		'START_RECEIVING': 'nav.startReceiving', 'RECEIVING_RECORDS': 'nav.receivingRecords',
		'VENDOR_RECORDS': 'reports.vendorRecords', 'FLYER_MASTER': 'nav.flyerMaster',
		'PRODUCT_MASTER': 'nav.productMaster', 'VARIATION_MANAGER': 'nav.variationManager',
		'OFFER_MANAGER': 'nav.offerManager', 'FLYER_TEMPLATES': 'nav.flyerTemplates',
		'FLYER_SETTINGS': 'nav.flyerSettings', 'NORMAL_PAPER_MANAGER': 'nav.normalPaperManager',
		'ONE_DAY_OFFER_MANAGER': 'nav.oneDayOfferManager',
		'SOCIAL_LINK_MANAGER': 'nav.socialLinkManager', 'OFFER_PRODUCT_EDITOR': 'nav.offerProductEditor',
		'CREATE_NEW_OFFER': 'nav.createNewOffer', 'PRICING_MANAGER': 'nav.pricingManager',
		'ERP_ENTRY_MANAGER': 'nav.erpEntryManager', 'GENERATE_FLYERS': 'nav.generateFlyers',
		'SHELF_PAPER_MANAGER': 'nav.shelfPaperManager', 'NEAR_EXPIRY_MANAGER': 'nav.nearExpiryManager',
		'COUPON_DASHBOARD_PROMO': 'nav.couponDashboard', 'CAMPAIGN_MANAGER': 'nav.manageCampaigns',
		'VIEW_OFFER_MANAGER': 'nav.viewOfferManager', 'CUSTOMER_IMPORTER': 'nav.importCustomers',
		'PRODUCT_MANAGER_PROMO': 'nav.manageProducts', 'COUPON_REPORTS': 'nav.reportsAndStats',
		'APPROVAL_CENTER': 'nav.approvalCenter', 'PURCHASE_VOUCHER_MANAGER': 'nav.purchaseVoucherManager',
		'BANK_RECONCILIATION': 'nav.bankReconciliation', 'MANUAL_SCHEDULING': 'nav.manualScheduling',
		'DAY_BUDGET_PLANNER': 'nav.dayBudgetPlanner', 'MONTHLY_MANAGER': 'nav.monthlyManager',
		'EXPENSE_MANAGER': 'nav.expenseManager', 'PAID_MANAGER': 'nav.paidManager',
		'DENOMINATION': 'nav.denomination', 'PETTY_CASH': 'nav.pettyCash',
		'EXPENSE_TRACKER': 'reports.expenseTracker', 'SALES_REPORT': 'reports.salesReport',
		'MONTHLY_BREAKDOWN': 'nav.monthlyBreakdown', 'OVERDUES_REPORT': 'nav.overdues',
		'VENDOR_PAYMENTS': 'reports.vendorPayments', 'POS_REPORT': 'nav.pos',
		'CREATE_DEPARTMENT': 'nav.createDepartment', 'CREATE_LEVEL': 'nav.createLevel',
		'CREATE_POSITION': 'nav.createPosition', 'REPORTING_MAP': 'nav.reportingMap',
		'ASSIGN_POSITIONS': 'nav.assignPositions', 'LINK_ID': 'nav.linkID',
		'EMPLOYEE_FILES': 'nav.employeeFiles', 'PROCESS_FINGERPRINT': 'nav.processFingerprint',
		'SALARY_AND_WAGE': 'nav.salaryAndWage', 'SHIFT_AND_DAY_OFF': 'nav.shiftAndLeave',
		'DISCIPLINE': 'nav.discipline', 'INCIDENT_MANAGER': 'nav.incidentManager',
		'REPORT_INCIDENT': 'nav.reportIncident', 'DAILY_CHECKLIST_MANAGER': 'nav.dailyChecklistManager', 'FINGERPRINT_TRANSACTIONS': 'nav.fingerprintTransactions',
		'EXPORT_BIOMETRIC_DATA': 'nav.exportBiometricData', 'TASK_MASTER': 'admin.taskMaster',
		'CREATE_TASK': 'nav.createTaskTemplate', 'VIEW_TASKS': 'nav.viewTaskTemplates',
		'ASSIGN_TASKS': 'nav.assignTasks', 'VIEW_MY_TASKS': 'nav.viewMyTasks',
		'VIEW_MY_ASSIGNMENTS': 'nav.viewMyAssignments', 'TASK_STATUS': 'nav.taskStatus',
		'BRANCH_PERFORMANCE': 'nav.branchPerformance', 'COMMUNICATION_CENTER': 'admin.communicationCenter',
		'CREATE_NOTIFICATION': 'mobile.createNotification', 'USER_MANAGEMENT': 'nav.usersList',
		'CREATE_USER': 'nav.createUser', 'MANAGE_ADMIN_USERS': 'nav.manageAdminUsers',
		'MANAGE_MASTER_ADMIN': 'nav.manageMasterAdmin', 'INTERFACE_ACCESS_MANAGER': 'nav.interfaceAccess',
		'APPROVAL_PERMISSIONS': 'nav.approvalPermissions', 'BRANCHES': 'admin.branchesMaster',
		'SETTINGS': 'nav.soundSettings', 'E_R_P_CONNECTIONS': 'nav.erpConnections',
		'CLEAR_TABLES': 'nav.clearTables', 'BUTTON_ACCESS_CONTROL': 'nav.buttonAccessControl',
		'BUTTON_GENERATOR': 'nav.buttonGenerator',
		// Additional DB button codes (aliases / alternate codes)
		'UPLOAD_EMPLOYEES': 'hr.masterUploadEmployees', 'WARNING_MASTER': 'nav.warningMaster',
		'SALARY_WAGE_MANAGEMENT': 'hr.masterSalaryManagement', 'CONTACT_MANAGEMENT': 'hr.masterContactManagement',
		'DOCUMENT_MANAGEMENT': 'hr.masterDocumentManagement', 'BIOMETRIC_DATA': 'hr.biometricData',
		'BRANCH_MASTER': 'admin.branchesMaster', 'SOUND_SETTINGS': 'nav.soundSettings',
		'CATEGORY_MANAGER': 'nav.categoryManager', 'REPORTS_STATS': 'nav.reportsAndStats',
		'COUPON_DASHBOARD': 'nav.couponDashboard', 'MANAGE_CAMPAIGNS': 'nav.manageCampaigns',
		'IMPORT_CUSTOMERS': 'nav.importCustomers', 'MANAGE_PRODUCTS': 'nav.manageProducts',
		'OVER_DUES': 'nav.overdues', 'USER_PERMISSIONS': 'nav.userPermissions',
		'USERS': 'nav.users', 'CREATE_USER_ROLES': 'nav.createUserRoles',
		'ASSIGN_ROLES': 'nav.assignRoles', 'ERP_CONNECTIONS': 'nav.erpConnections',
		'INTERFACE_ACCESS': 'nav.interfaceAccess', 'CREATE_TASK_TEMPLATE': 'nav.createTaskTemplate',
		'VIEW_TASK_TEMPLATES': 'nav.viewTaskTemplates',
	};

	/** Get translated button name from button_code */
	function getButtonLabel(buttonCode: string, fallback: string): string {
		const key = buttonCodeTranslationMap[buttonCode];
		if (key) {
			const translated = t(key);
			if (translated && translated !== key) return translated;
		}
		return fallback;
	}
	
	// Force reactivity when locale changes
	$: locale = $currentLocale;

	// Initialize PWA install detection
	onMount(async () => {
		initPWAInstall();
		await checkApprovalPermission();
		
		// Load user favorites
		if ($currentUser) {
			await favoritesStore.load($currentUser.id, $currentUser.employee_id || null);
		}
		
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

	// Reload favorites when user changes
	$: if ($currentUser) {
		favoritesStore.load($currentUser.id, $currentUser.employee_id || null);
	}

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

	function openLinkID() {
		collapseAllMenus();
		const windowId = generateWindowId('link-id');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Link ID #${instanceNumber}`,
			component: LinkID,
			icon: '🔗',
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

	function openFingerprintTransactions() {
		collapseAllMenus();
		const windowId = generateWindowId('fingerprint-transactions');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Fingerprint Transactions #${instanceNumber}`,
			component: FingerprintTransactions,
			icon: '👆',
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
		showHRSubmenu = false;
	}

	function openProcessFingerprint() {
		collapseAllMenus();
		const windowId = generateWindowId('process-fingerprint');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Process Fingerprint #${instanceNumber}`,
			component: ProcessFingerprint,
			icon: '📂',
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
		showHRSubmenu = false;
	}

	function openEmployeeFiles() {
		collapseAllMenus();
		const windowId = generateWindowId('employee-files');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Employee Files #${instanceNumber}`,
			component: EmployeeFiles,
			icon: '📁',
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
		showHRSubmenu = false;
	}

	function openSalaryAndWage() {
		collapseAllMenus();
		const windowId = generateWindowId('salary-and-wage');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Salary and Wage #${instanceNumber}`,
			component: SalaryAndWage,
			icon: '💰',
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
		showHRSubmenu = false;
	}

	function openShiftAndDayOff() {
		collapseAllMenus();
		const windowId = generateWindowId('shift-and-day-off');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Shift and Day Off #${instanceNumber}`,
			component: ShiftAndDayOff,
			icon: '⌚',
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
		showHRSubmenu = false;
	}

	function openLeavesAndVacations() {
		collapseAllMenus();
		const windowId = generateWindowId('leaves-and-vacations');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Leaves and Vacations #${instanceNumber}`,
			component: LeavesAndVacations,
			icon: '🌴',
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
		showHRSubmenu = false;
	}

	function openDiscipline() {
		collapseAllMenus();
		const windowId = generateWindowId('discipline');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Discipline #${instanceNumber}`,
			component: Discipline,
			icon: '⚖️',
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
		showHRSubmenu = false;
	}

	function openIncidentManager() {
		collapseAllMenus();
		const windowId = generateWindowId('incident-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Incident Manager #${instanceNumber}`,
			component: IncidentManager,
			icon: '🚨',
			size: { width: 1200, height: 750 },
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

	function openDailyChecklistManager() {
		collapseAllMenus();
		const windowId = generateWindowId('daily-checklist-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Daily Checklist Manager #${instanceNumber}`,
			component: DailyChecklistManager,
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
		showHRSubmenu = false;
	}

	function openReportIncident() {
		collapseAllMenus();
		const windowId = generateWindowId('report-incident');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Report Incident #${instanceNumber}`,
			component: ReportIncident,
			icon: '📝',
			size: { width: 900, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				violation: null,
				employees: [],
				branches: []
			}
		});
		showHRSubmenu = false;
	}

	function openLeaveRequest() {
		collapseAllMenus();
		const windowId = generateWindowId('leave-request');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Leave Request #${instanceNumber}`,
			component: LeaveRequest,
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

	function openPushNotificationSettings() {
		const windowId = generateWindowId('push-notifications');
		
		openWindow({
			id: windowId,
			title: 'Push Notification Settings',
			component: PushNotificationSettings,
			icon: '🔔',
			size: { width: 650, height: 550 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 80 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		collapseAllSubsections();
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

	// Map button_code to open function for favorites sidebar
	function openFavoriteButton(buttonCode: string) {
		const actionMap: Record<string, () => void> = {
			'CUSTOMER_MASTER': openCustomerMaster,
			'AD_MANAGER': openAdManager,
			'PRODUCTS_MANAGER': openProductsManager,
			'DELIVERY_SETTINGS': openDeliverySettings,
			'ORDERS_MANAGER': openOrdersManager,
			'OFFER_MANAGEMENT': openOfferManagement,
			'UPLOAD_VENDOR': openUploadVendor,
			'CREATE_VENDOR': openCreateVendor,
			'MANAGE_VENDOR': openManageVendor,
			'RECEIVING': openReceiving,
			'START_RECEIVING': openStartReceiving,
			'RECEIVING_RECORDS': openReceivingRecords,
			'VENDOR_RECORDS': openVendorRecords,
			'FLYER_MASTER': openFlyerMaster,
			'PRODUCT_MASTER': openProductMaster,
			'VARIATION_MANAGER': openVariationManager,
			'OFFER_MANAGER': openOfferManager,
			'FLYER_TEMPLATES': openFlyerTemplates,
			'FLYER_SETTINGS': openFlyerSettings,
			'NORMAL_PAPER_MANAGER': openNormalPaperManager,
			'ONE_DAY_OFFER_MANAGER': openOneDayOfferManager,
			'SOCIAL_LINK_MANAGER': openSocialLinkManager,
			'OFFER_PRODUCT_EDITOR': openOfferProductEditor,
			'CREATE_NEW_OFFER': openCreateNewOffer,
			'PRICING_MANAGER': openPricingManager,
			'ERP_ENTRY_MANAGER': openErpEntryManager,
			'GENERATE_FLYERS': openGenerateFlyers,
			'SHELF_PAPER_MANAGER': openShelfPaperManager,
			'NEAR_EXPIRY_MANAGER': openNearExpiryManager,
			'COUPON_DASHBOARD_PROMO': openCouponDashboardPromo,
			'CAMPAIGN_MANAGER': openCampaignManager,
			'VIEW_OFFER_MANAGER': openViewOfferManager,
			'CUSTOMER_IMPORTER': openCustomerImporter,
			'PRODUCT_MANAGER_PROMO': openProductManagerPromo,
			'COUPON_REPORTS': openCouponReports,
			'APPROVAL_CENTER': openApprovalCenter,
			'PURCHASE_VOUCHER_MANAGER': openPurchaseVoucherManager,
			'BANK_RECONCILIATION': openBankReconciliation,
			'MANUAL_SCHEDULING': openManualScheduling,
			'DAY_BUDGET_PLANNER': openDayBudgetPlanner,
			'MONTHLY_MANAGER': openMonthlyManager,
			'EXPENSE_MANAGER': openExpenseManager,
			'PAID_MANAGER': openPaidManager,
			'DENOMINATION': openDenomination,
			'PETTY_CASH': openPettyCash,
			'EXPENSE_TRACKER': openExpenseTracker,
			'SALES_REPORT': openSalesReport,
			'MONTHLY_BREAKDOWN': openMonthlyBreakdown,
			'OVERDUES_REPORT': openOverduesReport,
			'VENDOR_PAYMENTS': openVendorPendingPayments,
			'POS_REPORT': openPOSReport,
			'CREATE_DEPARTMENT': openCreateDepartment,
			'CREATE_LEVEL': openCreateLevel,
			'CREATE_POSITION': openCreatePosition,
			'REPORTING_MAP': openReportingMap,
			'ASSIGN_POSITIONS': openAssignPositions,
			'LINK_ID': openLinkID,
			'EMPLOYEE_FILES': openEmployeeFiles,
			'PROCESS_FINGERPRINT': openProcessFingerprint,
			'SALARY_AND_WAGE': openSalaryAndWage,
			'SHIFT_AND_DAY_OFF': openShiftAndDayOff,
			'DISCIPLINE': openDiscipline,
			'INCIDENT_MANAGER': openIncidentManager,
			'REPORT_INCIDENT': openReportIncident,
			'DAILY_CHECKLIST_MANAGER': openDailyChecklistManager,
			'FINGERPRINT_TRANSACTIONS': openFingerprintTransactions,
			'EXPORT_BIOMETRIC_DATA': openExportBiometricData,
			'TASK_MASTER': openTaskMaster,
			'CREATE_TASK': openCreateTask,
			'VIEW_TASKS': openViewTasks,
			'ASSIGN_TASKS': openAssignTasks,
			'VIEW_MY_TASKS': openMyTasks,
			'VIEW_MY_ASSIGNMENTS': openMyAssignments,
			'TASK_STATUS': openTaskStatus,
			'BRANCH_PERFORMANCE': openBranchPerformanceWindow,
			'COMMUNICATION_CENTER': openCommunicationCenter,
			'CREATE_NOTIFICATION': openCreateNotification,
			'USER_MANAGEMENT': openUserManagement,
			'CREATE_USER': openCreateUser,
			'MANAGE_ADMIN_USERS': openManageAdminUsers,
			'MANAGE_MASTER_ADMIN': openManageMasterAdmin,
			'INTERFACE_ACCESS_MANAGER': openInterfaceAccessManager,
			'APPROVAL_PERMISSIONS': openApprovalPermissions,
			'BRANCHES': openBranches,
			'SETTINGS': openSettings,
			'E_R_P_CONNECTIONS': openERPConnections,
			'CLEAR_TABLES': openClearTables,
			'BUTTON_ACCESS_CONTROL': openButtonAccessControl,
			'BUTTON_GENERATOR': openButtonGenerator,
			'PUSH_NOTIFICATION_SETTINGS': openPushNotificationSettings,
		};

		const action = actionMap[buttonCode];
		if (action) {
			action();
		} else {
			console.warn('⚠️ No action mapped for button code:', buttonCode);
		}
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

	// Open Petty Cash window
	function openPettyCash() {
		collapseAllMenus();
		const windowId = generateWindowId('petty-cash');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Petty Cash #${instanceNumber}`,
			component: PettyCash,
			icon: '💰',
			size: { width: 1000, height: 700 },
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

	// Open Bank Reconciliation window
	function openBankReconciliation() {
		collapseAllMenus();
		
		// Use fixed window ID to prevent duplicates
		const windowId = 'bank-reconciliation-main';
		
		openWindow({
			id: windowId,
			title: `Bank Reconciliation`,
			component: BankReconciliation,
			icon: '🏦',
			size: { width: 1200, height: 750 },
			position: { 
				x: 170 + (Math.random() * 100),
				y: 170 + (Math.random() * 100) 
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

	// Open POS Report window
	function openPOSReport() {
		const windowId = generateWindowId('pos-report');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `POS Report #${instanceNumber}`,
			component: POSReport,
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

	function openErpEntryManager() {
		const windowId = generateWindowId('erp-entry-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `ERP Entry Manager #${instanceNumber}`,
			component: ErpEntryManager,
			icon: '📊',
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

	function openNormalPaperManager() {
		const windowId = generateWindowId('normal-paper-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Normal Paper Manager #${instanceNumber}`,
			component: NormalPaperManager,
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

	function openOneDayOfferManager() {
		const windowId = generateWindowId('one-day-offer-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `One Day Offer Manager #${instanceNumber}`,
			component: OneDayOfferManager,
			icon: '📅',
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

	function openNearExpiryManager() {
		const windowId = generateWindowId('near-expiry-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Near Expiry Manager #${instanceNumber}`,
			component: NearExpiryManager,
			icon: '⏰',
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

	// Notification Management - Create Notification
	function openCreateNotification() {
		collapseAllMenus();
		const windowId = generateWindowId('create-notification');
		
		openWindow({
			id: windowId,
			title: 'Create Notification',
			component: CreateNotification,
			icon: '📝',
			size: { width: 600, height: 700 },
			position: { 
				x: 150 + (Math.random() * 100), 
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

<div class="sidebar" class:favorites-mode={sidebarViewMode === 'favorites'}>
	<div class="sidebar-content">
	<!-- Online/Offline Indicator -->
	<div class="connection-indicator {isOnline ? 'online' : 'offline'}">
		<div class="status-light"></div>
		<span class="status-text">{isOnline ? t('nav.online') : t('nav.offline')}</span>
	</div>
	
	<!-- Standard / Favorites Toggle -->
	<div class="view-mode-toggle">
		<div
			class="electric-switch"
			class:on={sidebarViewMode === 'favorites'}
			on:click={() => sidebarViewMode = sidebarViewMode === 'standard' ? 'favorites' : 'standard'}
			on:keydown={(e) => e.key === 'Enter' && (sidebarViewMode = sidebarViewMode === 'standard' ? 'favorites' : 'standard')}
			role="switch"
			aria-checked={sidebarViewMode === 'favorites'}
			tabindex="0"
		>
			<div class="switch-track">
				<div class="switch-knob">
					<span class="knob-icon" class:off={sidebarViewMode === 'standard'}>⭐</span>
				</div>
			</div>
		</div>
		<button class="link-button" title="Link" on:click={() => favoritesPanelOpen.set(!$favoritesPanelOpen)}>
			⭐
		</button>
	</div>

	<!-- Separator Line -->
	<div class="speed-separator"></div>

	{#if sidebarViewMode === 'standard'}
	<!-- ============ STANDARD SIDEBAR ============ -->
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showVendorDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('RECEIVING')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openReceiving}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">{t('nav.receiving')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
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
								<span class="menu-text">{t('nav.receivingRecords')}</span>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
				</button>
			</div>

		<!-- Dashboard Subsection Items -->
		{#if showMediaDashboardSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('FLYER_MASTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openFlyerMaster}>
							<span class="menu-icon">🏷️</span>
							<span class="menu-text">{t('nav.flyerMaster')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>

			<!-- Manager Subsection Items -->
			{#if showMediaManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('PRODUCT_MASTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openProductMaster}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">{t('nav.productMaster')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('VARIATION_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openVariationManager}>
								<span class="menu-icon">🔗</span>
								<span class="menu-text">{t('nav.variationManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('OFFER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOfferManager}>
								<span class="menu-icon">🎯</span>
								<span class="menu-text">{t('nav.offerManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('FLYER_TEMPLATES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openFlyerTemplates}>
								<span class="menu-icon">🎨</span>
								<span class="menu-text">{t('nav.flyerTemplates')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('FLYER_SETTINGS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openFlyerSettings}>
								<span class="menu-icon">⚙️</span>
								<span class="menu-text">{t('nav.flyerSettings')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('NORMAL_PAPER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openNormalPaperManager}>
								<span class="menu-icon">📄</span>
								<span class="menu-text">{t('nav.normalPaperManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('ONE_DAY_OFFER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOneDayOfferManager}>
								<span class="menu-icon">📅</span>
								<span class="menu-text">{t('nav.oneDayOfferManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SOCIAL_LINK_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSocialLinkManager}>
								<span class="menu-icon">🔗</span>
								<span class="menu-text">{t('nav.socialLinkManager')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showMediaOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('OFFER_PRODUCT_EDITOR')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOfferProductEditor}>
								<span class="menu-icon">✅</span>
								<span class="menu-text">{t('nav.offerProductEditor')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_NEW_OFFER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateNewOffer}>
								<span class="menu-icon">🏷️</span>
								<span class="menu-text">{t('nav.createNewOffer')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('PRICING_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPricingManager}>
								<span class="menu-icon">💵</span>
								<span class="menu-text">{t('nav.pricingManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('ERP_ENTRY_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openErpEntryManager}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.erpEntryManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('GENERATE_FLYERS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openGenerateFlyers}>
								<span class="menu-icon">📄</span>
								<span class="menu-text">{t('nav.generateFlyers')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SHELF_PAPER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openShelfPaperManager}>
								<span class="menu-icon">🏷️</span>
								<span class="menu-text">{t('nav.shelfPaperManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('NEAR_EXPIRY_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openNearExpiryManager}>
								<span class="menu-icon">⏰</span>
								<span class="menu-text">{t('nav.nearExpiryManager')}</span>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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
					title={t('nav.dashboard')}
				>
					
				
				<span class="menu-text">{t('nav.dashboard')}</span>
			</button>
		</div>

		<!-- Dashboard Subsection Items -->
		{#if showPromoDashboardSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('COUPON_DASHBOARD_PROMO')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCouponDashboardPromo}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">{t('nav.couponDashboard')}</span>
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
				title={t('nav.manage')}
			>
				
				<span class="menu-text">{t('nav.manage')}</span>
			</button>
		</div>

		<!-- Manage Subsection Items -->
		{#if showPromoManageSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('CAMPAIGN_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCampaignManager}>
							<span class="menu-icon">📋</span>
							<span class="menu-text">{t('nav.manageCampaigns')}</span>
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
				title={t('nav.operations')}
			>
				
				<span class="menu-text">{t('nav.operations')}</span>
			</button>
		</div>

		<!-- Operations Subsection Items -->
		{#if showPromoOperationsSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('VIEW_OFFER_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openViewOfferManager}>
							<span class="menu-icon">📊</span>
							<span class="menu-text">{t('nav.viewOfferManager')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('CUSTOMER_IMPORTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCustomerImporter}>
							<span class="menu-icon">👥</span>
							<span class="menu-text">{t('nav.importCustomers')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('PRODUCT_MANAGER_PROMO')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openProductManagerPromo}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">{t('nav.manageProducts')}</span>
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
				title={t('nav.reports')}
			>
				
				<span class="menu-text">{t('nav.reports')}</span>
			</button>
		</div>

		<!-- Reports Subsection Items -->
		{#if showPromoReportsSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('COUPON_REPORTS')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCouponReports}>
							<span class="menu-icon">📊</span>
							<span class="menu-text">{t('nav.reportsAndStats')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showFinanceDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('APPROVAL_CENTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openApprovalCenter}>
								<span class="menu-icon">✓</span>
								<span class="menu-text">{t('nav.approvalCenter')}</span>
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
						if (showFinanceManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showFinanceManageSubmenu = true;
						}
					}}
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showFinanceManageSubmenu}
				<div class="submenu-subitem-container">
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCategoryManager}>
							<span class="menu-icon">📁</span>
							<span class="menu-text">{t('nav.categoryManager')}</span>
						</button>
					</div>
					{#if isButtonAllowed('PURCHASE_VOUCHER_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPurchaseVoucherManager}>
								<span class="menu-icon">📄</span>
								<span class="menu-text">{t('nav.purchaseVoucherManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('BANK_RECONCILIATION')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openBankReconciliation}>
								<span class="menu-icon">🏦</span>
								<span class="menu-text">{t('nav.bankReconciliation')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showFinanceOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('MANUAL_SCHEDULING')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManualScheduling}>
								<span class="menu-icon">📅</span>
								<span class="menu-text">{t('nav.manualScheduling')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DAY_BUDGET_PLANNER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDayBudgetPlanner}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.dayBudgetPlanner')}</span>
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
								<span class="menu-text">{t('nav.denomination')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('PETTY_CASH')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPettyCash}>
								<span class="menu-icon">💰</span>
								<span class="menu-text">{t('nav.pettyCash')}</span>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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
								<span class="menu-text">{t('nav.overdues')}</span>
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
					{#if isButtonAllowed('POS_REPORT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPOSReport}>
								<span class="menu-icon">🏪</span>
								<span class="menu-text">{t('nav.pos')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showHRManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CREATE_DEPARTMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateDepartment}>
								<span class="menu-icon">🏢</span>
								<span class="menu-text">{t('nav.createDepartment')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_LEVEL')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateLevel}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.createLevel')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CREATE_POSITION')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreatePosition}>
								<span class="menu-icon">💼</span>
								<span class="menu-text">{t('nav.createPosition')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('REPORTING_MAP')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openReportingMap}>
								<span class="menu-icon">📈</span>
								<span class="menu-text">{t('nav.reportingMap')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('ASSIGN_POSITIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openAssignPositions}>
								<span class="menu-icon">🎯</span>
								<span class="menu-text">{t('nav.assignPositions')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('LINK_ID')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openLinkID}>
								<span class="menu-icon">🔗</span>
								<span class="menu-text">{t('nav.linkID')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showHROperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('EMPLOYEE_FILES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openEmployeeFiles}>
								<span class="menu-icon">📁</span>
								<span class="menu-text">{t('nav.employeeFiles')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('PROCESS_FINGERPRINT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openProcessFingerprint}>
								<span class="menu-icon">📂</span>
								<span class="menu-text">{t('nav.processFingerprint')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SALARY_AND_WAGE')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSalaryAndWage}>
								<span class="menu-icon">💰</span>
								<span class="menu-text">{t('nav.salaryAndWage')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SHIFT_AND_DAY_OFF')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openShiftAndDayOff}>
								<span class="menu-icon">⌚</span>
								<span class="menu-text">{t('nav.shiftAndLeave')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DISCIPLINE')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDiscipline}>
								<span class="menu-icon">⚖️</span>
								<span class="menu-text">{t('nav.discipline')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('INCIDENT_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openIncidentManager}>
								<span class="menu-icon">🚨</span>
								<span class="menu-text">{t('nav.incidentManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('REPORT_INCIDENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openReportIncident}>
								<span class="menu-icon">📝</span>
								<span class="menu-text">{t('nav.reportIncident')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('DAILY_CHECKLIST_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDailyChecklistManager}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">{t('nav.dailyChecklistManager')}</span>
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
						if (showHRReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showHRReportsSubmenu = true;
						}
					}}
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showHRReportsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('FINGERPRINT_TRANSACTIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openFingerprintTransactions}>
								<span class="menu-icon">👆</span>
								<span class="menu-text">{t('nav.fingerprintTransactions')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('EXPORT_BIOMETRIC_DATA')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openExportBiometricData}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.exportBiometricData')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showTasksManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CREATE_TASK')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateTask}>
								<span class="menu-icon">✨</span>
								<span class="menu-text">{t('nav.createTaskTemplate')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('VIEW_TASKS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openViewTasks}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">{t('nav.viewTaskTemplates')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showTasksOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('ASSIGN_TASKS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openAssignTasks}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">{t('nav.assignTasks')}</span>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showTasksReportsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('VIEW_MY_TASKS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openMyTasks}>
								<span class="menu-icon">📝</span>
								<span class="menu-text">{t('nav.viewMyTasks')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('VIEW_MY_ASSIGNMENTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openMyAssignments}>
								<span class="menu-icon">👨‍💼</span>
								<span class="menu-text">{t('nav.viewMyAssignments')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('TASK_STATUS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openTaskStatus}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.taskStatus')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('BRANCH_PERFORMANCE')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openBranchPerformanceWindow}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.branchPerformance')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showNotificationsOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CREATE_NOTIFICATION')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateNotification}>
								<span class="menu-icon">📝</span>
								<span class="menu-text">{t('nav.createNotification') || 'Create Notification'}</span>
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
						if (showNotificationsReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showNotificationsReportsSubmenu = true;
						}
					}}
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showUserDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('USER_MANAGEMENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openUserManagement}>
								<span class="menu-icon">👤</span>
								<span class="menu-text">{t('nav.usersList')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>

			<!-- Manager Subsection Items -->
			{#if showUserManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('CREATE_USER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCreateUser}>
								<span class="menu-icon">👤</span>
								<span class="menu-text">{t('nav.createUser')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MANAGE_ADMIN_USERS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageAdminUsers}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">{t('nav.manageAdminUsers')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('MANAGE_MASTER_ADMIN')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageMasterAdmin}>
								<span class="menu-icon">🔐</span>
								<span class="menu-text">{t('nav.manageMasterAdmin')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('INTERFACE_ACCESS_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openInterfaceAccessManager}>
								<span class="menu-icon">🔧</span>
								<span class="menu-text">{t('nav.interfaceAccess')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('APPROVAL_PERMISSIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openApprovalPermissions}>
								<span class="menu-icon">🔐</span>
								<span class="menu-text">{t('nav.approvalPermissions')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
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
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
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
								<span class="menu-text">{t('nav.buttonAccessControl')}</span>
							</button>
						</div>
					{/if}
				{#if isButtonAllowed('BUTTON_GENERATOR')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openButtonGenerator}>
							<span class="menu-icon">🔨</span>
							<span class="menu-text">{t('nav.buttonGenerator')}</span>
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
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showControlsOperationsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Push Notification Settings -->
					<button 
						class="submenu-subitem-button" 
						on:click={openPushNotificationSettings}
						title="Push Notification Settings"
					>
						<span class="menu-icon">🔔</span>
						<span class="menu-text">Push Notifications</span>
					</button>
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
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
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

	{:else}
	<!-- ============ FAVORITES SIDEBAR ============ -->
	<div class="favorites-sidebar-view">
		{#if userFavorites.loading}
			<div class="fav-loading">
				<span class="fav-spinner"></span>
				<span>{t('nav.loadingFavorites') || 'Loading favorites...'}</span>
			</div>
		{:else if userFavorites.favorites.length === 0}
			<div class="fav-empty">
				<span class="fav-empty-icon">⭐</span>
				<p>{t('nav.noFavoritesYet') || 'No favorites yet'}</p>
				<p class="fav-empty-hint">{t('nav.noFavoritesHint') || 'Use "Manage Favorites" on the desktop to add buttons here.'}</p>
			</div>
		{:else}
			{#each userFavorites.favorites as fav}
				<button
					class="favorite-sidebar-btn"
					on:click={() => openFavoriteButton(fav.button_code)}
					title={getButtonLabel(fav.button_code, fav.button_name_en)}
				>
					<span class="fav-btn-icon">{fav.icon || '📌'}</span>
					<span class="fav-btn-text">{getButtonLabel(fav.button_code, fav.button_name_en)}</span>
				</button>
			{/each}
		{/if}
	</div>
	{/if}

	</div>
	<!-- Sidebar Footer -->
	<div class="sidebar-footer">
		<!-- Version Information -->
		<div class="version-info">
			<button class="version-text" on:click={showVersionInfo} title={t('nav.whatsNew')}>
				AQ40.14.9.9
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
		transition: all 0.3s ease;
	}

	.sidebar.favorites-mode {
		background: #1d2c5e;
		border-right-color: #1d2c5e;
	}

	.sidebar.favorites-mode .sidebar-content {
		color: #fcd34d;
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

	/* View Mode Toggle - Electric Switch */
	.view-mode-toggle {
		padding: 0;
		margin-top: -8px;
		margin-bottom: -16px;
		margin-left: -8px;
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 10px;
	}

	.electric-switch {
		position: relative;
		width: 56px;
		height: 28px;
		cursor: pointer;
		outline: none;
	}

	.switch-track {
		width: 100%;
		height: 100%;
		background: #4a4a4a;
		border-radius: 14px;
		position: relative;
		border: 2px solid #333;
		box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.5), 0 1px 2px rgba(0, 0, 0, 0.3);
		transition: all 0.3s ease;
	}

	.electric-switch.on .switch-track {
		background: #3d3520;
		border-color: #8B6914;
		box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.4), 0 0 8px rgba(245, 158, 11, 0.3);
	}

	.switch-knob {
		position: absolute;
		top: 1px;
		left: 1px;
		width: 22px;
		height: 22px;
		background: linear-gradient(145deg, #888, #666);
		border-radius: 50%;
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.4), inset 0 1px 1px rgba(255, 255, 255, 0.2);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.electric-switch.on .switch-knob {
		left: 29px;
		background: linear-gradient(145deg, #F59E0B, #D97706);
		box-shadow: 0 2px 8px rgba(245, 158, 11, 0.6), inset 0 1px 1px rgba(255, 255, 255, 0.3);
	}

	.knob-icon {
		font-size: 0.65rem;
		line-height: 1;
		filter: saturate(1);
		transition: filter 0.3s ease;
	}

	.knob-icon.off {
		filter: saturate(0) brightness(0.6) sepia(1) hue-rotate(-30deg) saturate(5) brightness(0.7);
	}

	.electric-switch:hover .switch-track {
		border-color: #555;
	}

	.electric-switch.on:hover .switch-track {
		border-color: #B8860B;
	}

	.electric-switch:focus-visible .switch-track {
		border-color: #F59E0B;
	}

	.link-button {
		width: 32px;
		height: 32px;
		border-radius: 8px;
		background: rgba(34, 197, 94, 0.1);
		border: 1px solid rgba(34, 197, 94, 0.3);
		font-size: 1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
		color: #22c55e;
		filter: hue-rotate(90deg);
	}

	.link-button:hover {
		background: rgba(34, 197, 94, 0.2);
		border-color: rgba(34, 197, 94, 0.5);
		transform: scale(1.05);
	}

	.link-button:active {
		transform: scale(0.95);
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

	/* ============ Favorites Sidebar View Styles ============ */
	.favorites-sidebar-view {
		display: flex;
		flex-direction: column;
		gap: 4px;
		padding: 4px 0;
	}

	.favorite-sidebar-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 9px 8px;
		background: rgba(21, 163, 74, 0.08);
		border: 1px solid rgba(21, 163, 74, 0.15);
		border-radius: 8px;
		color: #e5e7eb;
		cursor: pointer;
		font-size: 11px;
		font-weight: 500;
		text-align: left;
		width: 100%;
		transition: all 0.15s ease;
		line-height: 1.3;
	}

	.favorite-sidebar-btn:hover {
		background: rgba(21, 163, 74, 0.2);
		border-color: rgba(21, 163, 74, 0.4);
		transform: translateX(2px);
		color: #34d399;
	}

	.favorite-sidebar-btn:active {
		transform: translateX(2px) scale(0.98);
	}

	.fav-btn-icon {
		font-size: 14px;
		flex-shrink: 0;
		width: 18px;
		text-align: center;
	}

	.fav-btn-text {
		flex: 1;
		white-space: normal;
		word-wrap: break-word;
		word-break: break-word;
	}

	.fav-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 2rem 1rem;
		color: #9ca3af;
		font-size: 0.8rem;
	}

	.fav-spinner {
		width: 24px;
		height: 24px;
		border: 3px solid rgba(21, 163, 74, 0.2);
		border-top-color: #15A34A;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.fav-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		padding: 2rem 0.5rem;
		color: #9ca3af;
	}

	.fav-empty-icon {
		font-size: 2rem;
		margin-bottom: 8px;
		opacity: 0.5;
	}

	.fav-empty p {
		margin: 0;
		font-size: 0.8rem;
		line-height: 1.4;
	}

	.fav-empty-hint {
		margin-top: 6px !important;
		font-size: 0.7rem !important;
		opacity: 0.7;
	}
</style>




