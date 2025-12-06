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
	import HRMaster from '$lib/components/desktop-interface/master/HRMaster.svelte';
	import OperationsMaster from '$lib/components/desktop-interface/master/OperationsMaster.svelte';
	import VendorMaster from '$lib/components/desktop-interface/master/VendorMaster.svelte';
	import FinanceMaster from '$lib/components/desktop-interface/master/FinanceMaster.svelte';
	import ApprovalCenter from '$lib/components/desktop-interface/master/finance/ApprovalCenter.svelte';
	import UserManagement from '$lib/components/desktop-interface/settings/UserManagement.svelte';
	import Settings from '$lib/components/desktop-interface/settings/Settings.svelte';
	import ApprovalPermissionsManager from '$lib/components/desktop-interface/settings/ApprovalPermissionsManager.svelte';
	import CommunicationCenter from '$lib/components/desktop-interface/master/CommunicationCenter.svelte';
	import StartReceiving from '$lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte';
	import ScheduledPayments from '$lib/components/desktop-interface/master/finance/ScheduledPayments.svelte';
	import MonthlyManager from '$lib/components/desktop-interface/master/finance/MonthlyManager.svelte';
	import MonthlyBreakdown from '$lib/components/desktop-interface/master/finance/MonthlyBreakdown.svelte';
	import ExpensesManager from '$lib/components/desktop-interface/master/finance/ExpensesManager.svelte';
	import DayBudgetPlanner from '$lib/components/desktop-interface/master/finance/DayBudgetPlanner.svelte';
	import CustomerMaster from '$lib/components/desktop-interface/admin-customer-app/CustomerMaster.svelte';
	import InterfaceAccessManager from '$lib/components/desktop-interface/settings/InterfaceAccessManager.svelte';
	import AdManager from '$lib/components/desktop-interface/admin-customer-app/AdManager.svelte';
	import DeliverySettings from '$lib/components/desktop-interface/admin-customer-app/DeliverySettings.svelte';
	import ProductsManager from '$lib/components/desktop-interface/admin-customer-app/ProductsManager.svelte';
	import OfferManagement from '$lib/components/desktop-interface/admin-customer-app/OfferManagement.svelte';
	import ProductSelectorWindow from '$lib/components/desktop-interface/admin-customer-app/offers/ProductSelectorWindow.svelte';
	import OrdersManager from '$lib/components/desktop-interface/admin-customer-app/OrdersManager.svelte';
	import FlyerMasterDashboard from '$lib/components/desktop-interface/marketing/flyer/FlyerMasterDashboard.svelte';
	import ExpenseTracker from '$lib/components/desktop-interface/master/finance/reports/ExpenseTracker.svelte';
	import SalesReport from '$lib/components/desktop-interface/master/finance/reports/SalesReport.svelte';
	import VendorPendingPayments from '$lib/components/desktop-interface/master/finance/reports/VendorPendingPayments.svelte';
	import VendorRecords from '$lib/components/desktop-interface/master/finance/reports/VendorRecords.svelte';
	import CouponDashboard from '$lib/components/desktop-interface/marketing/coupon/CouponDashboard.svelte';
	import ERPConnections from '$lib/components/desktop-interface/settings/ERPConnections.svelte';
	import ClearTables from '$lib/components/desktop-interface/settings/ClearTables.svelte';
	import UserPermissionsWindow from '$lib/components/desktop-interface/settings/user/UserPermissionsWindow.svelte';
	import VersionChangelog from '$lib/components/desktop-interface/common/VersionChangelog.svelte';

	let showSettingsSubmenu = false;
	let showMasterSubmenu = false;
	let showWorkSubmenu = false;
	let showCustomerAppSubmenu = false;
	let showMarketingSubmenu = false;
	let showReportsSubmenu = false;
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
		showMasterSubmenu = false;
	}

	function openHRMaster() {
		const windowId = generateWindowId('hr-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `HR Master #${instanceNumber}`,
			component: HRMaster,
			icon: '👥',
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

	function openVendorMaster() {
		const windowId = generateWindowId('vendor-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Vendor Master #${instanceNumber}`,
			component: VendorMaster,
			icon: '🏪',
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

	function openFinanceMaster() {
		const windowId = generateWindowId('finance-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Finance Master #${instanceNumber}`,
			component: FinanceMaster,
			icon: '💰',
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

	function openCustomerMaster() {
		const windowId = generateWindowId('customer-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Customer Master #${instanceNumber}`,
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
		showCustomerAppSubmenu = false;
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
		showCustomerAppSubmenu = false;
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
		showCustomerAppSubmenu = false;
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
		showCustomerAppSubmenu = false;
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
	showCustomerAppSubmenu = false;
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

	function openUserPermissions() {
		const windowId = generateWindowId('user-permissions');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `User Permissions Manager #${instanceNumber}`,
			component: UserPermissionsWindow,
			icon: '👥',
			size: { width: 1500, height: 900 },
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
		showMasterSubmenu = false;
	}

	// Open Start Receiving window
	function openStartReceiving() {
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

	// Open Scheduled Payments window
	function openScheduledPayments() {
		const windowId = generateWindowId('scheduled-payments');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		let scheduledPaymentsRefreshFunction = null;
		
		openWindow({
			id: windowId,
			title: `Scheduled Payments #${instanceNumber}`,
			component: ScheduledPayments,
			props: {
				setRefreshCallback: (fn) => {
					console.log('📝 [Sidebar] Refresh function registered from ScheduledPayments');
					scheduledPaymentsRefreshFunction = fn;
				},
				onRefresh: async () => {
					console.log('🔄 [Sidebar] onRefresh called from window');
					console.log('🔍 [Sidebar] scheduledPaymentsRefreshFunction:', scheduledPaymentsRefreshFunction);
					if (scheduledPaymentsRefreshFunction) {
						console.log('✅ [Sidebar] Calling ScheduledPayments refresh function');
						return await scheduledPaymentsRefreshFunction();
					} else {
						console.log('❌ [Sidebar] No refresh function available');
					}
				}
			},
			icon: '💰',
			size: { width: 1400, height: 900 },
			position: { 
				x: 120 + (Math.random() * 100),
				y: 120 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Monthly Manager window
	function openMonthlyManager() {
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

	// Open Expense Manager window
	function openExpenseManager() {
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

	// Open Day Budget Planner window
	function openDayBudgetPlanner() {
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
		showReportsSubmenu = false;
	}

	// Open Vendor Records window
	function openVendorRecords() {
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
		showReportsSubmenu = false;
	}

	// Open Flyer Master window
	function openFlyerMaster() {
		const windowId = generateWindowId('flyer-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Flyer Master #${instanceNumber}`,
			component: FlyerMasterDashboard,
			icon: '🏷️',
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
		showMarketingSubmenu = false;
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
		showMarketingSubmenu = false;
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

	<!-- Master Section -->
	<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showMasterSubmenu = !showMasterSubmenu}
			>
				<span class="section-icon">📁</span>
				<span class="section-text">{t('nav.master') || 'Master'}</span>
				<span class="arrow" class:expanded={showMasterSubmenu}>▼</span>
			</button>
		</div>

		<!-- Master Submenu - Inline below Master button -->
		{#if showMasterSubmenu}
			<div class="submenu-inline">
				{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openBranches}>
							<span class="menu-icon">🏢</span>
							<span class="menu-text">{t('admin.branchesMaster') || 'Branch Master'}</span>
						</button>
					</div>
				{/if}
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openVendorMaster}>
						<span class="menu-icon">🏪</span>
						<span class="menu-text">{t('admin.vendorMaster') || 'Vendor Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openFinanceMaster}>
						<span class="menu-icon">💰</span>
						<span class="menu-text">{t('admin.financeMaster') || 'Finance Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openHRMaster}>
						<span class="menu-icon">👥</span>
						<span class="menu-text">{t('admin.hrMaster') || 'HR Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openOperationsMaster}>
						<span class="menu-icon">⚙️</span>
						<span class="menu-text">{t('admin.operationsMaster') || 'Operations Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openTaskMaster}>
						<span class="menu-icon">✅</span>
						<span class="menu-text">{t('admin.taskMaster') || 'Task Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openCommunicationCenter}>
						<span class="menu-icon">📞</span>
						<span class="menu-text">{t('admin.communicationCenter') || 'Com Center'}</span>
					</button>
				</div>
			</div>
		{/if}

		<!-- Work Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showWorkSubmenu = !showWorkSubmenu}
			>
				<span class="section-icon">💼</span>
				<span class="section-text">{t('nav.work') || 'Work'}</span>
				<span class="arrow" class:expanded={showWorkSubmenu}>▼</span>
			</button>
		</div>

		<!-- Work Submenu - Inline below Work button -->
		{#if showWorkSubmenu}
			<div class="submenu-inline">
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openStartReceiving}>
						<span class="menu-icon">📦</span>
						<span class="menu-text">{t('nav.startReceiving') || 'Start Receiving'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openScheduledPayments}>
						<span class="menu-icon">💰</span>
						<span class="menu-text">{t('nav.scheduledPayments') || 'Scheduled Payments'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openMonthlyManager}>
						<span class="menu-icon">📅</span>
						<span class="menu-text">{t('nav.monthlyManager') || 'Monthly Manager'}</span>
					</button>
				</div>
			<div class="submenu-item-container">
				<button class="submenu-item" on:click={openExpenseManager}>
					<span class="menu-icon">💸</span>
					<span class="menu-text">{t('nav.expenseManager') || 'Expense Manager'}</span>
				</button>
			</div>
			<div class="submenu-item-container">
				<button class="submenu-item" on:click={openDayBudgetPlanner}>
					<span class="menu-icon">📊</span>
					<span class="menu-text">{t('nav.dayBudgetPlanner') || 'Day Budget Planner'}</span>
				</button>
			</div>
		</div>
	{/if}		<!-- Customer App Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showCustomerAppSubmenu = !showCustomerAppSubmenu}
			>
				<span class="section-icon">📱</span>
				<span class="section-text">{t('nav.customerApp') || 'Customer App'}</span>
				<span class="arrow" class:expanded={showCustomerAppSubmenu}>▼</span>
			</button>
		</div>

		<!-- Customer App Submenu - Inline below Customer App button -->
		{#if showCustomerAppSubmenu}
			<div class="submenu-inline">
				{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCustomerMaster}>
							<span class="menu-icon">🤝</span>
							<span class="menu-text">{t('admin.customerMaster') || 'Customer Master'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openOrdersManager}>
							<span class="menu-icon">🛒</span>
							<span class="menu-text">{t('admin.ordersManager') || 'Orders Manager'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openOfferManagement}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">{t('admin.offerManagement') || 'Offer Management'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openAdManager}>
							<span class="menu-icon">📢</span>
							<span class="menu-text">{t('admin.adManager') || 'Ad Manager'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openProductsManager}>
							<span class="menu-icon">🛍️</span>
							<span class="menu-text">{t('admin.productsManager') || 'Products Manager'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openDeliverySettings}>
							<span class="menu-icon">📦</span>
							<span class="menu-text">{t('admin.deliverySettings') || 'Delivery Settings'}</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Marketing Master Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showMarketingSubmenu = !showMarketingSubmenu}
			>
				<span class="section-icon">📢</span>
				<span class="section-text">{t('nav.marketingMaster') || 'Marketing'}</span>
				<span class="arrow" class:expanded={showMarketingSubmenu}>▼</span>
			</button>
		</div>

		<!-- Marketing Submenu - Inline below Marketing button -->
		{#if showMarketingSubmenu}
			<div class="submenu-inline">
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openFlyerMaster}>
						<span class="menu-icon">🏷️</span>
						<span class="menu-text">{t('admin.flyerMaster') || 'Flyer Master'}</span>
					</button>
				</div>
				{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCouponManagement}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">{t('coupon.title') || 'Coupon Management'}</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Reports Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showReportsSubmenu = !showReportsSubmenu}
			>
				<span class="section-icon">📊</span>
				<span class="section-text">{t('nav.reports') || 'Reports'}</span>
				<span class="arrow" class:expanded={showReportsSubmenu}>▼</span>
			</button>
		</div>

		<!-- Reports Submenu - Inline below Reports button -->
		{#if showReportsSubmenu}
			<div class="submenu-inline">
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openExpenseTracker}>
						<span class="menu-icon">💰</span>
						<span class="menu-text">{t('reports.expenseTracker') || 'Expense Tracker'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openSalesReport}>
						<span class="menu-icon">📊</span>
						<span class="menu-text">{t('reports.salesReport') || 'Sales Report'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openVendorPendingPayments}>
						<span class="menu-icon">💳</span>
						<span class="menu-text">{t('reports.vendorPayments') || 'Vendor Payments'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openVendorRecords}>
						<span class="menu-icon">📋</span>
						<span class="menu-text">{t('reports.vendorRecords') || 'Vendor Records'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openMonthlyBreakdown}>
						<span class="menu-icon">📅</span>
					<span class="menu-text">{t('nav.monthlyBreakdown') || 'Monthly Breakdown'}</span>
				</button>
			</div>
		</div>
	{/if}		<!-- Settings Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showSettingsSubmenu = !showSettingsSubmenu}
			>
				<span class="section-icon">⚙️</span>
				<span class="section-text">{t('nav.settings') || 'Settings'}</span>
				<span class="arrow" class:expanded={showSettingsSubmenu}>▼</span>
			</button>
		</div>

		<!-- Settings Submenu - Inline below Settings button -->
		{#if showSettingsSubmenu}
			<div class="submenu-inline">
				{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openUserManagement}>
							<span class="menu-icon">👤</span>
							<span class="menu-text">{t('nav.users') || 'Users'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openSettings}>
							<span class="menu-icon">🔊</span>
							<span class="menu-text">{t('nav.soundSettings') || 'Sound Settings'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openERPConnections}>
							<span class="menu-icon">🔌</span>
							<span class="menu-text">{t('nav.erpConnections') || 'ERP Connections'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openInterfaceAccessManager}>
							<span class="menu-icon">🔧</span>
							<span class="menu-text">{t('nav.interfaceAccess') || 'Interface Access'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openApprovalPermissions}>
							<span class="menu-icon">🔐</span>
							<span class="menu-text">{t('nav.approvalPermissions') || 'Approval Permissions'}</span>
						</button>
					</div>
				{/if}
				{#if $currentUser?.roleType === 'Master Admin'}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openUserPermissions}>
							<span class="menu-icon">👥</span>
							<span class="menu-text">{t('nav.userPermissions') || 'User Permissions'}</span>
						</button>
					</div>
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openClearTables}>
							<span class="menu-icon">🗑️</span>
							<span class="menu-text">{t('nav.clearTables') || 'Clear Tables'}</span>
						</button>
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
				AQ23.8.3.3
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
		background: linear-gradient(180deg, #2d3748 0%, #1a202c 100%);
		color: white;
		display: flex;
		flex-direction: column;
		box-shadow: 2px 0 10px rgba(0, 0, 0, 0.3);
		z-index: 1200;
		border-right: 1px solid #4a5568;
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
		background: none;
		border: none;
		color: #e2e8f0;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
	}

	.section-button:hover {
		background: rgba(255, 255, 255, 0.1);
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
		align-items: center;
		gap: 10px;
		padding: 10px 12px;
		background: none;
		border: none;
		color: #e2e8f0;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s ease;
		font-size: 13px;
		width: 100%;
		height: 40px; /* Fixed height for submenu items */
		text-align: left;
		margin-bottom: 2px;
	}

	.submenu-item:hover {
		background: rgba(255, 255, 255, 0.15);
		color: white;
		transform: translateX(2px);
	}

	.submenu-item:last-child {
		margin-bottom: 0;
	}

	/* Inline submenu below Work button */
	.submenu-inline {
		padding: 8px 0 8px 4px;
		margin-bottom: 8px;
		background: transparent; /* Changed from rgba(0, 0, 0, 0.2) to transparent */
		border-radius: 8px;
		animation: slideDown 0.2s ease;
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
		background: rgba(255, 255, 255, 0.05);
		border-radius: 6px;
		margin-bottom: 6px;
		padding: 2px;
		border: 1px solid rgba(255, 255, 255, 0.1);
	}

	.submenu-item-container:last-child {
		margin-bottom: 0;
	}

	.submenu-item-container:hover {
		background: rgba(255, 255, 255, 0.1);
		border-color: rgba(255, 255, 255, 0.2);
	}

	.submenu-inline .submenu-item {
		font-size: 11px;
		padding: 7px 6px 7px 5px;
		height: auto;
		min-height: 32px;
		width: 100%;
		background: transparent;
		align-items: flex-start;
	}

	.submenu-inline .submenu-item:hover {
		background: transparent;
		transform: none;
	}

	.menu-icon {
		font-size: 13px;
		flex-shrink: 0;
		width: 16px;
		text-align: center;
		align-self: flex-start;
		margin-top: 2px;
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
		border-top: 1px solid #4a5568;
		background: rgba(0, 0, 0, 0.3);
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
		border-top: 1px solid rgba(74, 85, 104, 0.5);
		padding-top: 6px;
	}

	.version-text {
		background: linear-gradient(135deg, #4f46e5 0%, #3b82f6 100%);
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
		height: 1px;
		background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
		margin: 12px 0;
	}
</style>




