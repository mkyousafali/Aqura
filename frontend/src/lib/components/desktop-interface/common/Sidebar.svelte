<script lang="ts">
	// IMPORTANT: When adding new menu items or UI text, ALWAYS update translations:
	// - frontend/src/lib/i18n/locales/en.ts (English)
	// - frontend/src/lib/i18n/locales/ar.ts (Arabic)
	
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { sidebar } from '$lib/stores/sidebar';
	import { currentLocale, t, switchLocale } from '$lib/i18n';
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
	import DancingCharacter from './DancingCharacter.svelte';
	
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
	import StorageManager from '$lib/components/desktop-interface/settings/StorageManager.svelte';
	import ApiKeysManager from '$lib/components/desktop-interface/settings/ApiKeysManager.svelte';
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
	import ManageReconciliations from '$lib/components/desktop-interface/master/finance/ManageReconciliations.svelte';
	import AssetManager from '$lib/components/desktop-interface/master/finance/AssetManager.svelte';
	import LeaseAndRent from '$lib/components/desktop-interface/master/finance/LeaseAndRent.svelte';
	import Denomination from '$lib/components/desktop-interface/master/finance/Denomination.svelte';
	import PettyCash from '$lib/components/desktop-interface/master/finance/PettyCash.svelte';
	import CustomerMaster from '$lib/components/desktop-interface/admin-customer-app/CustomerMaster.svelte';
	import CustomerAppManager from '$lib/components/desktop-interface/admin-customer-app/CustomerAppManager.svelte';
	import LoyaltyDashboard from '$lib/components/desktop-interface/master/loyalty/LoyaltyDashboard.svelte';
	import ManageTiers from '$lib/components/desktop-interface/master/loyalty/ManageTiers.svelte';
	import InterfaceAccessManager from '$lib/components/desktop-interface/settings/InterfaceAccessManager.svelte';
	import AdManager from '$lib/components/desktop-interface/admin-customer-app/AdManager.svelte';
	import SocialLinkManager from '$lib/components/desktop-interface/admin-customer-app/SocialLinkManager.svelte';
	import DeliverySettings from '$lib/components/desktop-interface/admin-customer-app/DeliverySettings.svelte';
	import ProductsManager from '$lib/components/desktop-interface/admin-customer-app/ProductsManager.svelte';
	import ManageProductsWindow from '$lib/components/desktop-interface/admin-customer-app/products/ManageProductsWindow.svelte';
	import OfferManagement from '$lib/components/desktop-interface/admin-customer-app/OfferManagement.svelte';
	import ProductSelectorWindow from '$lib/components/desktop-interface/admin-customer-app/offers/ProductSelectorWindow.svelte';
	import OrdersManager from '$lib/components/desktop-interface/admin-customer-app/OrdersManager.svelte';
	import FlyerMasterDashboard from '$lib/components/desktop-interface/marketing/flyer/FlyerMasterDashboard.svelte';
	import ProductsDashboard from '$lib/components/desktop-interface/marketing/products/ProductsDashboard.svelte';
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
	import ShelfPaperTemplateDesigner from '$lib/components/desktop-interface/marketing/flyer/ShelfPaperTemplateDesigner.svelte';
	import NearExpiryManager from '$lib/components/desktop-interface/marketing/flyer/NearExpiryManager.svelte';
	import NormalPaperManager from '$lib/components/desktop-interface/marketing/flyer/NormalPaperManager.svelte';
	import OneDayOfferManager from '$lib/components/desktop-interface/marketing/flyer/OneDayOfferManager.svelte';
	import ExpenseTracker from '$lib/components/desktop-interface/master/finance/reports/ExpenseTracker.svelte';
	import SalesReport from '$lib/components/desktop-interface/master/finance/reports/SalesReport.svelte';
	import VendorPendingPayments from '$lib/components/desktop-interface/master/finance/reports/VendorPendingPayments.svelte';
	import VendorRecords from '$lib/components/desktop-interface/master/finance/reports/VendorRecords.svelte';
	import OverduesReport from '$lib/components/desktop-interface/master/finance/reports/OverduesReport.svelte';
	import POSReport from '$lib/components/desktop-interface/master/finance/reports/POSReport.svelte';
	import CentralPerformance from '$lib/components/desktop-interface/master/reports/CentralPerformance.svelte';
	import ReceivingRecords from '$lib/components/desktop-interface/master/operations/receiving/ReceivingRecords.svelte';
	import Receiving from '$lib/components/desktop-interface/master/operations/Receiving.svelte';
	import BreakRegisterManager from '$lib/components/desktop-interface/master/hr/BreakRegisterManager.svelte';
	import DefaultPositions from '$lib/components/desktop-interface/master/vendor/DefaultPositions.svelte';
	import CouponDashboard from '$lib/components/desktop-interface/marketing/coupon/CouponDashboard.svelte';
	import CampaignManager from '$lib/components/desktop-interface/marketing/coupon/CampaignManager.svelte';
	import ViewOfferManager from '$lib/components/desktop-interface/marketing/coupon/ViewOfferManager.svelte';
	import CustomerImporter from '$lib/components/desktop-interface/marketing/coupon/CustomerImporter.svelte';
	import ProductManager from '$lib/components/desktop-interface/marketing/coupon/ProductManager.svelte';
	import CouponReports from '$lib/components/desktop-interface/marketing/coupon/CouponReports.svelte';
	import GiftWheelManager from '$lib/components/desktop-interface/marketing/gift-wheel/GiftWheelManager.svelte';
	import SurpriseBoxManager from '$lib/components/desktop-interface/marketing/surprise-box/SurpriseBoxManager.svelte';
	import VipCampaignWindow from '$lib/components/desktop-interface/marketing/vip/VipCampaignWindow.svelte';
	import ERPConnections from '$lib/components/desktop-interface/settings/ERPConnections.svelte';
	import ClearTables from '$lib/components/desktop-interface/settings/ClearTables.svelte';
	import ButtonAccessControl from '$lib/components/desktop-interface/settings/ButtonAccessControl.svelte';
	import ButtonGenerator from '$lib/components/desktop-interface/settings/ButtonGenerator.svelte';
	import ThemeManager from '$lib/components/desktop-interface/settings/ThemeManager.svelte';
	import LocalUpdate from '$lib/components/desktop-interface/settings/LocalUpdate.svelte';
	import HelperApps from '$lib/components/desktop-interface/settings/HelperApps.svelte';
	import SidebarAnimationManager from '$lib/components/desktop-interface/settings/SidebarAnimationManager.svelte';
	import AIChatGuide from '$lib/components/desktop-interface/settings/AIChatGuide.svelte';
	import ErpProductManager from '$lib/components/desktop-interface/settings/ErpProductManager.svelte';
	import IconManager from '$lib/components/desktop-interface/settings/IconManager.svelte';
	import CreateUser from '$lib/components/desktop-interface/settings/user/CreateUser.svelte';
	import ManageAdminUsers from '$lib/components/desktop-interface/settings/user/ManageAdminUsers.svelte';
	import ManageMasterAdmin from '$lib/components/desktop-interface/settings/user/ManageMasterAdmin.svelte';
	import EmployeeMaster from '$lib/components/desktop-interface/master/hr/EmployeeMaster.svelte';
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
	import SecurityCodeWindow from '$lib/components/desktop-interface/master/hr/SecurityCodeWindow.svelte';
	import EmployeeDashboard from '$lib/components/desktop-interface/master/hr/EmployeeDashboard.svelte';
	// NOTE: EmployeeDashboard merged into EmployeeMaster tabs
	import AnalyzeAllWindow from '$lib/components/desktop-interface/master/hr/AnalyzeAllWindow.svelte';
	import DailyChecklistManager from '$lib/components/desktop-interface/master/hr/DailyChecklistManager.svelte';
	import LeaveRequest from '$lib/components/desktop-interface/master/hr/LeaveRequest.svelte';
	import HRServices from '$lib/components/desktop-interface/master/hr/HRServices.svelte';
	import TaskCreateForm from '$lib/components/desktop-interface/master/tasks/TaskCreateForm.svelte';
	import TaskViewTable from '$lib/components/desktop-interface/master/tasks/TaskViewTable.svelte';
	import TaskAssignmentView from '$lib/components/desktop-interface/master/tasks/TaskAssignmentView.svelte';
	import MyTasksView from '$lib/components/desktop-interface/master/tasks/MyTasksView.svelte';
	import MyAssignmentsView from '$lib/components/desktop-interface/master/tasks/MyAssignmentsView.svelte';
	import TaskStatusView from '$lib/components/desktop-interface/master/tasks/TaskStatusView.svelte';
	import BranchPerformanceWindow from '$lib/components/desktop-interface/master/tasks/BranchPerformanceWindow.svelte';
	import DailyChecklistWindow from '$lib/components/desktop-interface/master/tasks/DailyChecklistWindow.svelte';
	import PushNotificationSettings from '$lib/components/common/PushNotificationSettings.svelte';
	import CreateNotification from '$lib/components/desktop-interface/master/communication/CreateNotification.svelte';
	import ProductRequestDesktop from '$lib/components/desktop-interface/master/stock/ProductRequestDesktop.svelte';
	import PORequestsList from '$lib/components/desktop-interface/master/stock/PORequestsList.svelte';
	import StockRequestsList from '$lib/components/desktop-interface/master/stock/StockRequestsList.svelte';
	import BTRequestsList from '$lib/components/desktop-interface/master/stock/BTRequestsList.svelte';
	import NearExpiryRequestsList from '$lib/components/desktop-interface/master/stock/NearExpiryRequestsList.svelte';
	import CustomerProductRequestsList from '$lib/components/desktop-interface/master/stock/CustomerProductRequestsList.svelte';
	import ErpProductsList from '$lib/components/desktop-interface/master/stock/ErpProductsList.svelte';
	import OfferCostManager from '$lib/components/desktop-interface/master/stock/OfferCostManager.svelte';
	import ProductClaimManager from '$lib/components/desktop-interface/master/stock/ProductClaimManager.svelte';
	import ExpiryControl from '$lib/components/desktop-interface/master/stock/ExpiryControl.svelte';
	import WADashboard from '$lib/components/desktop-interface/whatsapp/WADashboard.svelte';
	import WALiveChat from '$lib/components/desktop-interface/whatsapp/WALiveChat.svelte';
	import WABroadcasts from '$lib/components/desktop-interface/whatsapp/WABroadcasts.svelte';
	import WATemplates from '$lib/components/desktop-interface/whatsapp/WATemplates.svelte';
	import WAContacts from '$lib/components/desktop-interface/whatsapp/WAContacts.svelte';
	import WAAutoReplyBot from '$lib/components/desktop-interface/whatsapp/WAAutoReplyBot.svelte';
	import WAaiBot from '$lib/components/desktop-interface/whatsapp/WAaiBot.svelte';
	import WAAccounts from '$lib/components/desktop-interface/whatsapp/WAAccounts.svelte';
	import WASettings from '$lib/components/desktop-interface/whatsapp/WASettings.svelte';
	import WACatalog from '$lib/components/desktop-interface/whatsapp/WACatalog.svelte';

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
	let showWhatsAppSubmenu = false;
	let showWhatsAppDashboardSubmenu = false;
	let showWhatsAppManageSubmenu = false;
	let showWhatsAppOperationsSubmenu = false;
	let showWhatsAppReportsSubmenu = false;
	let showLoyaltySubmenu = false;
	let showLoyaltyDashboardSubmenu = false;
	let showLoyaltyManageSubmenu = false;
	let showLoyaltyOperationsSubmenu = false;
	let showLoyaltyReportsSubmenu = false;
	let hasApprovalPermission = false;
	
	// Get pending approvals count from store
	$: pendingApprovalsCount = $approvalCounts.pending;

	// Online/Offline state
	let isOnline = true;

	// Sidebar view mode: 'standard' or 'favorites'
	let sidebarViewMode: 'standard' | 'favorites' = 'standard';

	// Drag-and-drop state for favorites reordering
	let draggedIndex: number | null = null;
	let dragOverIndex: number | null = null;
	let reorderDebounceTimer: NodeJS.Timeout | null = null;

	// Subscribe to favorites store
	$: userFavorites = $favoritesStore;

	// Map button_code to translation key for multilingual support
	const buttonCodeTranslationMap: Record<string, string> = {
		'CUSTOMER_MASTER': 'admin.customerMaster', 'AD_MANAGER': 'admin.adManager',
		'PRODUCTS_MANAGER': 'admin.productsManager', 'DELIVERY_SETTINGS': 'admin.deliverySettings',
		'DELIVERY_MANAGE_PRODUCTS': 'nav.manageProducts',
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
		'SHELF_PAPER_MANAGER': 'nav.shelfPaperManager', 'SHELF_PAPER_TEMPLATE_DESIGNER': 'nav.shelfPaperTemplateDesigner', 'NEAR_EXPIRY_MANAGER': 'nav.nearExpiryManager',
		'COUPON_DASHBOARD_PROMO': 'nav.couponDashboard', 'CAMPAIGN_MANAGER': 'nav.manageCampaigns',
		'VIEW_OFFER_MANAGER': 'nav.viewOfferManager', 'CUSTOMER_IMPORTER': 'nav.importCustomers',
		'PRODUCT_MANAGER_PROMO': 'nav.manageProducts', 'COUPON_REPORTS': 'nav.reportsAndStats',
		'VIP_CAMPAIGN': 'nav.vipCampaign',
		'APPROVAL_CENTER': 'nav.approvalCenter', 'PURCHASE_VOUCHER_MANAGER': 'nav.purchaseVoucherManager',
		'BANK_RECONCILIATION': 'nav.bankReconciliation', 'MANAGE_RECONCILIATIONS': 'nav.manageReconciliations', 'MANUAL_SCHEDULING': 'nav.manualScheduling',
		'DAY_BUDGET_PLANNER': 'nav.dayBudgetPlanner', 'MONTHLY_MANAGER': 'nav.monthlyManager',
		'EXPENSE_MANAGER': 'nav.expenseManager', 'PAID_MANAGER': 'nav.paidManager',
		'DENOMINATION': 'nav.denomination', 'PETTY_CASH': 'nav.pettyCash',
		'EXPENSE_TRACKER': 'reports.expenseTracker', 'SALES_REPORT': 'reports.salesReport',
		'MONTHLY_BREAKDOWN': 'nav.monthlyBreakdown', 'OVERDUES_REPORT': 'nav.overdues',
		'VENDOR_PAYMENTS': 'reports.vendorPayments', 'POS_REPORT': 'nav.pos',
		'EMPLOYEE_MASTER': 'nav.employeeMaster',
		'ASSIGN_POSITIONS': 'nav.assignPositions', 'LINK_ID': 'nav.linkID',
		'EMPLOYEE_FILES': 'nav.employeeFiles', 'PROCESS_FINGERPRINT': 'nav.processFingerprint',
		'SALARY_AND_WAGE': 'nav.salaryAndWage', 'SHIFT_AND_DAY_OFF': 'nav.shiftAndLeave',
		'DISCIPLINE': 'nav.discipline', 'INCIDENT_MANAGER': 'nav.incidentManager',
		'REPORT_INCIDENT': 'nav.reportIncident', 'DAILY_CHECKLIST_MANAGER': 'nav.dailyChecklistManager', 'BREAK_REGISTER': 'nav.breakRegister', 'SECURITY_CODE': 'nav.securityCode', 'FINGERPRINT_DASHBOARD': 'nav.fingerprintDashboard', 'FINGERPRINT_TRANSACTIONS': 'nav.fingerprintTransactions',
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
		'AI_CHAT_GUIDE': 'nav.aiChatGuide',
		'ERP_PRODUCT_MANAGER': 'nav.erpProductManager',
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
		'LOYALTY_DASHBOARD': 'nav.loyaltyProgram', 'CUSTOMER_APP': 'nav.customerApp',
		'MANAGE_TIERS': 'nav.manage',
		'HR_SERVICES': 'nav.services',
		'ASSIGN_ROLES': 'nav.assignRoles', 'ERP_CONNECTIONS': 'nav.erpConnections',
		'INTERFACE_ACCESS': 'nav.interfaceAccess', 'CREATE_TASK_TEMPLATE': 'nav.createTaskTemplate',
		'VIEW_TASK_TEMPLATES': 'nav.viewTaskTemplates',
		'CENTRAL_PERFORMANCE': 'nav.centralPerformance',
		'STOCK_PRODUCT_REQUEST': 'nav.productRequest',
		'STOCK_ERP_PRODUCTS': 'nav.erpProducts',
		'STOCK_OFFER_COST_MANAGER': 'nav.offerCostManager',
		'STOCK_EXPIRY_CONTROL': 'nav.expiryControl',
		'WA_DASHBOARD': 'nav.whatsappDashboard',
		'WA_LIVE_CHAT': 'nav.whatsappLiveChat',
		'WA_BROADCASTS': 'nav.whatsappBroadcasts',
		'WA_TEMPLATES': 'nav.whatsappTemplates',
		'WA_CONTACTS': 'nav.whatsappContacts',
		'WA_AUTO_REPLY': 'nav.whatsappAutoReply',
		'WA_AI_BOT': 'nav.whatsappAIBot',
		'WA_ACCOUNTS': 'nav.whatsappAccounts',
		'WA_SETTINGS': 'nav.whatsappSettings',
		'WA_CATALOG': 'nav.whatsappCatalog',
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

		// Listen for open-near-expiry-requests event from NearExpiryManager
		const handleOpenNearExpiryRequests = () => openNearExpiryRequestsList();
		window.addEventListener('open-near-expiry-requests', handleOpenNearExpiryRequests);
		
		// Cleanup on unmount
		return () => {
			window.removeEventListener('online', handleOnline);
			window.removeEventListener('offline', handleOffline);
			window.removeEventListener('open-near-expiry-requests', handleOpenNearExpiryRequests);
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

	function openManageTiers() {
		collapseAllMenus();
		const windowId = generateWindowId('manage-tiers');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Manage Tiers #${instanceNumber}`,
			component: ManageTiers,
			componentName: 'ManageTiers',
			icon: '🏅',
			size: { width: 1200, height: 680 },
			position: {
				x: 130 + (Math.random() * 100),
				y: 90 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openLoyaltyDashboard() {
		collapseAllMenus();
		const windowId = generateWindowId('loyalty-dashboard');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `${t('nav.loyaltyProgram') || 'Loyalty Program'} #${instanceNumber}`,
			component: LoyaltyDashboard,
			componentName: 'LoyaltyDashboard',
			icon: '🏆',
			size: { width: 1100, height: 700 },
			position: {
				x: 130 + (Math.random() * 100),
				y: 90 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openCustomerApp() {
		collapseAllMenus();
		const windowId = generateWindowId('customer-app');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `${t('nav.customerApp') || 'Customer App'} #${instanceNumber}`,
			component: CustomerAppManager,
			componentName: 'CustomerAppManager',
			icon: '👥',
			size: { width: 1100, height: 700 },
			position: {
				x: 130 + (Math.random() * 100),
				y: 90 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openBranches() {
		const windowId = generateWindowId('branch-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('admin.branchesMaster') || 'Branch Master'} #${instanceNumber}`,
			component: BranchMaster,
			componentName: "BranchMaster",
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
			componentName: "TaskMaster",
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
			componentName: "TaskCreateForm",
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
			componentName: "TaskViewTable",
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
			componentName: 'MyTasksView',
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
			componentName: "MyAssignmentsView",
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
			componentName: "TaskStatusView",
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
			componentName: "TaskAssignmentView",
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
			componentName: "BranchPerformanceWindow",
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

	function openDailyChecklist() {
		const windowId = generateWindowId('daily-checklist');
		openWindow({
			id: windowId,
			title: 'My Daily Checklist',
			component: DailyChecklistWindow,
			componentName: "DailyChecklistWindow",
			icon: '✅',
			size: { width: 800, height: 600 },
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

	function openEmployeeMaster() {
		collapseAllMenus();
		const windowId = generateWindowId('employee-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `${t('nav.employeeMaster')} #${instanceNumber}`,
			component: EmployeeMaster,
			componentName: 'EmployeeMaster',
			icon: '👥',
			size: { width: 1300, height: 760 },
			position: {
				x: 130 + (Math.random() * 100),
				y: 90 + (Math.random() * 100)
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
			componentName: "LinkID",
			icon: '🔗',
			size: { width: 1400, height: 760 },
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

	function openHRServices() {
		collapseAllMenus();
		const windowId = generateWindowId('hr-services');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Services #${instanceNumber}`,
			component: HRServices,
			componentName: "HRServices",
			icon: '🛠️',
			size: { width: 900, height: 600 },
			position: { 
				x: 130 + (Math.random() * 100),
				y: 90 + (Math.random() * 100) 
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
			componentName: "BiometricExport",
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
			componentName: "FingerprintTransactions",
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
			componentName: "ProcessFingerprint",
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
			title: `${t('nav.employeeFiles') || 'Employee Files'} #${instanceNumber}`,
			component: EmployeeFiles,
			componentName: "EmployeeFiles",
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
			componentName: "SalaryAndWage",
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
			componentName: "ShiftAndDayOff",
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
			componentName: "LeavesAndVacations",
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
			componentName: "Discipline",
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
			componentName: "IncidentManager",
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
			componentName: "DailyChecklistManager",
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

	function openBreakRegister() {
		collapseAllMenus();
		const windowId = generateWindowId('break-register');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: t('nav.breakRegister'),
			component: BreakRegisterManager,
			componentName: "BreakRegisterManager",
			icon: '☕',
			size: { width: 1100, height: 700 },
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

	function openFingerprintDashboard() {
		collapseAllMenus();
		const windowId = generateWindowId('fingerprint-dashboard');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.fingerprintDashboard')} #${instanceNumber}`,
			component: AnalyzeAllWindow,
			componentName: "AnalyzeAllWindow",
			icon: '🖐️',
			size: { width: 1300, height: 750 },
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

	function openSecurityCodeWindow() {
		collapseAllMenus();
		const windowId = generateWindowId('security-code');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.securityCode')} #${instanceNumber}`,
			component: SecurityCodeWindow,
			componentName: "SecurityCodeWindow",
			icon: '🔒',
			size: { width: 900, height: 600 },
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
			componentName: "ReportIncident",
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
			componentName: "LeaveRequest",
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
			componentName: "OperationsMaster",
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
			title: `${t('admin.manageVendor')} #${instanceNumber}`,
			component: ManageVendor,
			componentName: "ManageVendor",
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
			title: `${t('admin.createVendor')} #${instanceNumber}`,
			component: EditVendor,
			componentName: "EditVendor",
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
			title: `${t('admin.uploadVendor')} #${instanceNumber}`,
			component: UploadVendor,
			componentName: "UploadVendor",
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
			componentName: 'CustomerMaster',
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
			componentName: 'AdManager',
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

	function openManageProductsWindow() {
		const windowId = generateWindowId('manage-products-window');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manage Products #${instanceNumber}`,
			component: ManageProductsWindow,
			componentName: 'ManageProductsWindow',
			icon: '📦',
			size: { width: 1200, height: 700 },
			position: { 
				x: 100 + (Math.random() * 50),
				y: 100 + (Math.random() * 50) 
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
			componentName: 'DeliverySettings',
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
			componentName: 'ProductsManager',
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
			componentName: 'ProductsManager',
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
			componentName: "OfferManagement",
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
			componentName: "OrdersManager",
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
			title: `${t('nav.approvalCenter') || 'Approval Center'} #${instanceNumber}`,
			component: ApprovalCenter,
			componentName: 'ApprovalCenter',
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
			componentName: "UserManagement",
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
			componentName: "InterfaceAccessManager",
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
			componentName: "Settings",
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
			componentName: "ApprovalPermissionsManager",
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

	function openStorageManager() {
		const windowId = generateWindowId('storage-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Storage Manager #${instanceNumber}`,
			component: StorageManager,
			componentName: "StorageManager",
			icon: '🗄️',
			size: { width: 1100, height: 750 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showControlsManageSubmenu = false;
	}

	function openIconManager() {
		collapseAllMenus();
		const windowId = generateWindowId('icon-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `${t('nav.iconManager')} #${instanceNumber}`,
			component: IconManager,
			componentName: "IconManager",
			icon: '🎨',
			size: { width: 1100, height: 750 },
			position: { 
				x: 110 + (Math.random() * 100), 
				y: 60 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openApiKeysManager() {
		collapseAllMenus();
		const windowId = generateWindowId('api-keys-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `${t('nav.apiKeysManager')} #${instanceNumber}`,
			component: ApiKeysManager,
			componentName: "ApiKeysManager",
			icon: '🔑',
			size: { width: 750, height: 650 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 80 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}



	function openClearTables() {
		const windowId = generateWindowId('clear-tables');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Clear Tables #${instanceNumber}`,
			component: ClearTables,
			componentName: "ClearTables",
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
			componentName: "PushNotificationSettings",
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

	function openLocalUpdate() {
		const windowId = generateWindowId('local-update');
		
		openWindow({
			id: windowId,
			title: 'Local Branch Update',
			component: LocalUpdate,
			componentName: "LocalUpdate",
			icon: '🚀',
			size: { width: 1000, height: 800 },
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

	function openHelperApps() {
		const windowId = generateWindowId('helper-apps');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `${t('nav.helperApps') || 'Helper Apps'} #${instanceNumber}`,
			component: HelperApps,
			componentName: 'HelperApps',
			icon: '🧩',
			size: { width: 1100, height: 680 },
			position: {
				x: 130 + (Math.random() * 100),
				y: 80 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		collapseAllSubsections();
	}

	function openSidebarAnimationManager() {
		const windowId = generateWindowId('sidebar-animation-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `${t('nav.sidebarAnimation') || 'Sidebar Animation'} #${instanceNumber}`,
			component: SidebarAnimationManager,
			componentName: 'SidebarAnimationManager',
			icon: '🎭',
			size: { width: 780, height: 650 },
			position: {
				x: 130 + (Math.random() * 100),
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
			componentName: "ButtonAccessControl",
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
			componentName: "ButtonGenerator",
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

	function openThemeManager() {
		const windowId = generateWindowId('theme-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.themeManager')} #${instanceNumber}`,
			component: ThemeManager,
			componentName: "ThemeManager",
			icon: '🎨',
			size: { width: 1100, height: 700 },
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

	function openAIChatGuide() {
		const windowId = generateWindowId('ai-chat-guide');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `AI Chat Guide #${instanceNumber}`,
			component: AIChatGuide,
			componentName: "AIChatGuide",
			icon: '🤖',
			size: { width: 900, height: 700 },
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

	function openErpProductManager() {
		const windowId = generateWindowId('erp-product-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.erpProductManager')} #${instanceNumber}`,
			component: ErpProductManager,
			componentName: "ErpProductManager",
			icon: '🏭',
			size: { width: 1400, height: 800 },
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
			componentName: "CommunicationCenter",
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
	}

	// Open Start Receiving window
	function openStartReceiving() {
		collapseAllMenus();
		const windowId = generateWindowId('start-receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.startReceiving')} #${instanceNumber}`,
			component: StartReceiving,
			componentName: "StartReceiving",
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

	function openDefaultPositions() {
		collapseAllMenus();
		const windowId = generateWindowId('default-positions');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('defaultPositions.title')} #${instanceNumber}`,
			component: DefaultPositions,
			componentName: "DefaultPositions",
			icon: '👥',
			size: { width: 900, height: 700 },
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
			'DEFAULT_POSITIONS': openDefaultPositions,
			'RECEIVING': openReceiving,
			'START_RECEIVING': openStartReceiving,
			'RECEIVING_RECORDS': openReceivingRecords,
			'VENDOR_RECORDS': openVendorRecords,
			// 'FLYER_MASTER': openFlyerMaster,       // removed from Media > Dashboard
			// 'PRODUCTS_DASHBOARD': openProductsDashboard, // removed from Media > Dashboard
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
			'SHELF_PAPER_TEMPLATE_DESIGNER': openShelfPaperTemplateDesigner,
			'NEAR_EXPIRY_MANAGER': openNearExpiryManager,
			'COUPON_DASHBOARD_PROMO': openCouponDashboardPromo,
			'CAMPAIGN_MANAGER': openCampaignManager,
			'VIEW_OFFER_MANAGER': openViewOfferManager,
			'CUSTOMER_IMPORTER': openCustomerImporter,
			'PRODUCT_MANAGER_PROMO': openProductManagerPromo,
			'COUPON_REPORTS': openCouponReports,
			'GIFT_WHEEL_MANAGER': openGiftWheelManager,
			'SURPRISE_BOX_MANAGER': openSurpriseBoxManager,
			'VIP_CAMPAIGN': openVipCampaign,
			'APPROVAL_CENTER': openApprovalCenter,
			'PURCHASE_VOUCHER_MANAGER': openPurchaseVoucherManager,
			'BANK_RECONCILIATION': openBankReconciliation,
			'MANAGE_RECONCILIATIONS': openManageReconciliations,
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
			'EMPLOYEE_MASTER': openEmployeeMaster,
			'LINK_ID': openLinkID,
			'EMPLOYEE_FILES': openEmployeeFiles,
			'PROCESS_FINGERPRINT': openProcessFingerprint,
			'SALARY_AND_WAGE': openSalaryAndWage,
			'SHIFT_AND_DAY_OFF': openShiftAndDayOff,
			'DISCIPLINE': openDiscipline,
			'INCIDENT_MANAGER': openIncidentManager,
			'REPORT_INCIDENT': openReportIncident,
			'DAILY_CHECKLIST_MANAGER': openDailyChecklistManager,
			'BREAK_REGISTER': openBreakRegister,
			'SECURITY_CODE': openSecurityCodeWindow,
			'FINGERPRINT_DASHBOARD': openFingerprintDashboard,
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
			'THEME_MANAGER': openThemeManager,
			'AI_CHAT_GUIDE': openAIChatGuide,
			'ERP_PRODUCT_MANAGER': openErpProductManager,
			'STORAGE_MANAGER': openStorageManager,
			'ICON_MANAGER': openIconManager,
			'API_KEYS_MANAGER': openApiKeysManager,
			'PUSH_NOTIFICATION_SETTINGS': openPushNotificationSettings,
			'STOCK_ERP_PRODUCTS': openStockErpProducts,
			'STOCK_OFFER_COST_MANAGER': openOfferCostManager,
			'STOCK_EXPIRY_CONTROL': openExpiryControl,
			'WA_DASHBOARD': openWADashboard,
			'WA_LIVE_CHAT': openWALiveChat,
			'WA_BROADCASTS': openWABroadcasts,
			'WA_TEMPLATES': openWATemplates,
			'WA_CONTACTS': openWAContacts,
			'WA_AUTO_REPLY': openWAAutoReplyBot,
			'WA_AI_BOT': openWAAIBot,
			'WA_ACCOUNTS': openWAAccounts,
			'WA_SETTINGS': openWASettings,
			'WA_CATALOG': openWACatalog,
		};

		const action = actionMap[buttonCode];
		if (action) {
			action();
		} else {
			console.warn('⚠️ No action mapped for button code:', buttonCode);
		}
	}

	// Drag-and-drop handlers for reordering favorite buttons
	function handleDragStart(event: DragEvent, index: number) {
		draggedIndex = index;
		if (event.dataTransfer) {
			event.dataTransfer.effectAllowed = 'move';
			event.dataTransfer.setData('text/html', '');
		}
	}

	function handleDragOver(event: DragEvent) {
		event.preventDefault();
		if (event.dataTransfer) {
			event.dataTransfer.dropEffect = 'move';
		}
	}

	function handleDragEnter(event: DragEvent, index: number) {
		dragOverIndex = index;
	}

	function handleDragLeave(event: DragEvent) {
		if (event.target === event.currentTarget) {
			dragOverIndex = null;
		}
	}

	async function handleDrop(event: DragEvent, toIndex: number) {
		event.preventDefault();
		dragOverIndex = null;

		if (draggedIndex === null || draggedIndex === toIndex) {
			draggedIndex = null;
			return;
		}

		// Reorder using the favorites store
		await favoritesStore.reorder(draggedIndex, toIndex);
		draggedIndex = null;
		console.log('✅ [Favorites] Reordered from index', draggedIndex, 'to', toIndex);
	}

	function handleDragEnd() {
		draggedIndex = null;
		dragOverIndex = null;
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
		showControlsDashboardSubmenu = false;
		showControlsManageSubmenu = false;
		showControlsOperationsSubmenu = false;
		showControlsReportsSubmenu = false;
		showUserDashboardSubmenu = false;
		showUserManageSubmenu = false;
		showUserOperationsSubmenu = false;
		showUserReportsSubmenu = false;
		showWhatsAppDashboardSubmenu = false;
		showWhatsAppManageSubmenu = false;
		showWhatsAppOperationsSubmenu = false;
		showWhatsAppReportsSubmenu = false;
		showLoyaltyDashboardSubmenu = false;
		showLoyaltyManageSubmenu = false;
		showLoyaltyOperationsSubmenu = false;
		showLoyaltyReportsSubmenu = false;
	}

	function collapseAllMenus() {
		collapseAllSubsections();
		showVendorSubmenu = false;
		showMediaSubmenu = false;
		showPromoSubmenu = false;
		showFinanceSubmenu = false;
		showHRSubmenu = false;
		showTasksSubmenu = false;
		showUserSubmenu = false;
		showWhatsAppSubmenu = false;
		showLoyaltySubmenu = false;
	}

	// ===== WhatsApp Manager Open Functions =====
	function openWADashboard() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-dashboard');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappDashboard')} #${n}`, component: WADashboard, componentName: 'WADashboard', icon: '📊', size: { width: 1300, height: 750 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWALiveChat() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-live-chat');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappLiveChat')} #${n}`, component: WALiveChat, componentName: 'WALiveChat', icon: '💬', size: { width: 1400, height: 800 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true, popOutEnabled: true });
	}
	function openWABroadcasts() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-broadcasts');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappBroadcasts')} #${n}`, component: WABroadcasts, componentName: 'WABroadcasts', icon: '📣', size: { width: 1300, height: 750 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWATemplates() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-templates');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappTemplates')} #${n}`, component: WATemplates, componentName: 'WATemplates', icon: '📝', size: { width: 1300, height: 750 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWAContacts() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-contacts');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappContacts')} #${n}`, component: WAContacts, componentName: 'WAContacts', icon: '👥', size: { width: 1200, height: 700 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWAAutoReplyBot() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-auto-reply');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappAutoReply')} #${n}`, component: WAAutoReplyBot, componentName: 'WAAutoReplyBot', icon: '🔧', size: { width: 1200, height: 700 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWAAIBot() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-ai-bot');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappAIBot')} #${n}`, component: WAaiBot, componentName: 'WAaiBot', icon: '🤖', size: { width: 1200, height: 700 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWAAccounts() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-accounts');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappAccounts')} #${n}`, component: WAAccounts, componentName: 'WAAccounts', icon: '📱', size: { width: 1200, height: 700 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWASettings() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-settings');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappSettings')} #${n}`, component: WASettings, componentName: 'WASettings', icon: '⚙️', size: { width: 1100, height: 700 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}
	function openWACatalog() {
		collapseAllMenus();
		const windowId = generateWindowId('wa-catalog');
		const n = Math.floor(Math.random() * 1000) + 1;
		openWindow({ id: windowId, title: `${t('nav.whatsappCatalog')} #${n}`, component: WACatalog, componentName: 'WACatalog', icon: '🛍️', size: { width: 1300, height: 750 }, position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) }, resizable: true, minimizable: true, maximizable: true, closable: true });
	}

	// Open ERP Products List window
	function openStockErpProducts() {
		collapseAllMenus();
		const windowId = generateWindowId('erp-products');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `ERP Products #${instanceNumber}`,
			component: ErpProductsList,
			componentName: "ErpProductsList",
			icon: '🏭',
			size: { width: 1400, height: 800 },
			position: { 
				x: 120 + (Math.random() * 100),
				y: 120 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openOfferCostManager() {
		collapseAllMenus();
		const windowId = generateWindowId('offer-cost-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.offerCostManager')} #${instanceNumber}`,
			component: OfferCostManager,
			componentName: "OfferCostManager",
			icon: '💰',
			size: { width: 1400, height: 800 },
			position: { 
				x: 120 + (Math.random() * 100),
				y: 120 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Product Request Desktop window
	function openProductRequestDesktop() {
		collapseAllMenus();
		const windowId = generateWindowId('product-request');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Product Request #${instanceNumber}`,
			component: ProductRequestDesktop,
			componentName: "ProductRequestDesktop",
			icon: '📋',
			size: { width: 1200, height: 800 },
			position: { 
				x: 120 + (Math.random() * 100),
				y: 120 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openPORequestsList() {
		collapseAllMenus();
		const windowId = generateWindowId('po-requests');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.poRequests') || 'PO Requests'} #${instanceNumber}`,
			component: PORequestsList,
			componentName: "PORequestsList",
			icon: '🛒',
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

	function openStockRequestsList() {
		collapseAllMenus();
		const windowId = generateWindowId('stock-requests');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.stockRequests') || 'Stock Requests'} #${instanceNumber}`,
			component: StockRequestsList,
			componentName: "StockRequestsList",
			icon: '📦',
			size: { width: 1200, height: 800 },
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

	function openBTRequestsList() {
		collapseAllMenus();
		const windowId = generateWindowId('bt-requests');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.btRequests') || 'BT Requests'} #${instanceNumber}`,
			component: BTRequestsList,
			componentName: "BTRequestsList",
			icon: '🔄',
			size: { width: 1200, height: 800 },
			position: { 
				x: 180 + (Math.random() * 100),
				y: 180 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openNearExpiryRequestsList() {
		collapseAllMenus();
		const windowId = generateWindowId('near-expiry-requests');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.nearExpiryRequests') || 'Near Expiry Reports'} #${instanceNumber}`,
			component: NearExpiryRequestsList,
			componentName: "NearExpiryRequestsList",
			icon: '⏰',
			size: { width: 1200, height: 800 },
			position: { 
				x: 200 + (Math.random() * 100),
				y: 200 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openCustomerProductRequestsList() {
		collapseAllMenus();
		const windowId = generateWindowId('customer-product-requests');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.customerProductRequests') || 'Customer Requests'} #${instanceNumber}`,
			component: CustomerProductRequestsList,
			componentName: "CustomerProductRequestsList",
			icon: '🛍️',
			size: { width: 1200, height: 800 },
			position: { 
				x: 220 + (Math.random() * 100),
				y: 220 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openProductClaimManager() {
		collapseAllMenus();
		const windowId = generateWindowId('product-claim-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: t('nav.productClaimManager'),
			component: ProductClaimManager,
			componentName: "ProductClaimManager",
			icon: '👤',
			size: { width: 1200, height: 800 },
			position: { 
				x: 220 + (Math.random() * 100),
				y: 220 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openExpiryControl() {
		collapseAllMenus();
		const windowId = generateWindowId('expiry-control');
		
		openWindow({
			id: windowId,
			title: t('nav.expiryControl'),
			component: ExpiryControl,
			componentName: "ExpiryControl",
			icon: '📅',
			size: { width: 1200, height: 800 },
			position: { 
				x: 230 + (Math.random() * 100),
				y: 230 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openReceiving() {
		collapseAllMenus();
		const windowId = generateWindowId('receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.receiving')} #${instanceNumber}`,
			component: Receiving,
			componentName: "Receiving",
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
			componentName: "PaidManager",
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
			componentName: 'Denomination',
			icon: '💵',
			size: { width: 900, height: 600 },
			position: { 
				x: 110 + (Math.random() * 100),
				y: 110 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
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
			componentName: "PettyCash",
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
			componentName: "MonthlyManager",
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
			componentName: "MonthlyBreakdown",
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
			componentName: "OverduesReport",
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
			componentName: "ExpensesManager",
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
			title: `${t('nav.categoryManager') || 'Category Manager'} #${instanceNumber}`,
			component: CategoryManager,
			componentName: "CategoryManager",
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

	// Open Lease and Rent window
	function openLeaseAndRent() {
		collapseAllMenus();
		const windowId = generateWindowId('lease-and-rent');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.leaseAndRent')} #${instanceNumber}`,
			component: LeaseAndRent,
			componentName: "LeaseAndRent",
			icon: '🏠',
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
		const windowId = generateWindowId('purchase-voucher-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.purchaseVoucherManager') || 'Purchase Voucher Manager'} #${instanceNumber}`,
			component: PurchaseVoucherManager,
			componentName: "PurchaseVoucherManager",
			icon: '📄',
			size: { width: 1100, height: 750 },
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

	// Open Bank Reconciliation window
	function openBankReconciliation() {
		collapseAllMenus();
		const windowId = generateWindowId('bank-reconciliation');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Bank Reconciliation #${instanceNumber}`,
			component: BankReconciliation,
			componentName: "BankReconciliation",
			icon: '🏦',
			size: { width: 1200, height: 750 },
			position: { 
				x: 170 + (Math.random() * 100),
				y: 170 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Manage Reconciliations window
	function openManageReconciliations() {
		collapseAllMenus();
		const windowId = generateWindowId('manage-reconciliations');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.manageReconciliations')} #${instanceNumber}`,
			component: ManageReconciliations,
			componentName: "ManageReconciliations",
			icon: '📋',
			size: { width: 1400, height: 750 },
			position: {
				x: 150 + (Math.random() * 100),
				y: 150 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Asset Manager window
	function openAssetManager() {
		collapseAllMenus();
		const windowId = generateWindowId('asset-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `${t('nav.assetManager')} #${instanceNumber}`,
			component: AssetManager,
			componentName: "AssetManager",
			icon: '🏗️',
			size: { width: 1100, height: 700 },
			position: { 
				x: 180 + (Math.random() * 100),
				y: 180 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
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
			componentName: "DayBudgetPlanner",
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
			componentName: "ManualScheduling",
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
			componentName: "ExpenseTracker",
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
			componentName: "SalesReport",
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
			componentName: "VendorPendingPayments",
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
			componentName: "VendorRecords",
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

	// Open Central Performance Dashboard (master admin only)
	function openCentralPerformance() {
		collapseAllMenus();
		const windowId = generateWindowId('central-performance');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `${t('nav.centralPerformance')} #${instanceNumber}`,
			component: CentralPerformance,
			componentName: 'CentralPerformance',
			icon: '📊',
			size: { width: 1400, height: 850 },
			position: { x: 80 + Math.random() * 80, y: 60 + Math.random() * 60 },
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
			componentName: "POSReport",
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
			title: `${t('nav.receivingRecords')} #${instanceNumber}`,
			component: ReceivingRecords,
			componentName: "ReceivingRecords",
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
			componentName: "FlyerMasterDashboard",
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

	function openProductsDashboard() {
		const windowId = generateWindowId('products-dashboard');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Products #${instanceNumber}`,
			component: ProductsDashboard,
			componentName: "ProductsDashboard",
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

	function openProductMaster() {
		const windowId = generateWindowId('product-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Product Master #${instanceNumber}`,
			component: ProductMaster,
			componentName: "ProductMaster",
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
			componentName: "VariationManager",
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
			componentName: "OfferTemplates",
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
			componentName: "OfferProductSelector",
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
			componentName: "OfferManager",
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
			componentName: "PricingManager",
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
			componentName: "ErpEntryManager",
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
			componentName: "FlyerGenerator",
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
			componentName: "FlyerTemplates",
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
			componentName: "NormalPaperManager",
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
			componentName: "OneDayOfferManager",
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
			componentName: "FlyerSettings",
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
			componentName: "SocialLinkManager",
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
			componentName: "DesignPlanner",
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

	function openShelfPaperTemplateDesigner() {
		const windowId = generateWindowId('shelf-paper-template-designer');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Shelf Paper Template Designer #${instanceNumber}`,
			component: ShelfPaperTemplateDesigner,
			componentName: "ShelfPaperTemplateDesigner",
			icon: '📐',
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
			componentName: "NearExpiryManager",
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
			componentName: "CouponDashboard",
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
			componentName: "CouponDashboard",
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
			componentName: "CampaignManager",
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
			componentName: "ViewOfferManager",
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
			componentName: "CustomerImporter",
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
			componentName: "ProductManager",
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
			componentName: "CouponReports",
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

	function openGiftWheelManager() {
		const windowId = generateWindowId('gift-wheel-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Gift Wheel #${instanceNumber}`,
			component: GiftWheelManager,
			componentName: "GiftWheelManager",
			icon: '🎡',
			size: { width: 1200, height: 700 },
			position: { x: 50 + (Math.random() * 100), y: 50 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openSurpriseBoxManager() {
		const windowId = generateWindowId('surprise-box-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `Surprise Box #${instanceNumber}`,
			component: SurpriseBoxManager,
			componentName: 'SurpriseBoxManager',
			icon: '🎁',
			size: { width: 1200, height: 720 },
			position: { x: 60 + (Math.random() * 100), y: 60 + (Math.random() * 100) },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showPromoSubmenu = false;
	}

	function openVipCampaign() {
		const windowId = generateWindowId('vip-campaign');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `VIP Campaign #${instanceNumber}`,
			component: VipCampaignWindow,
			componentName: 'VipCampaignWindow',
			icon: '👑',
			size: { width: 1100, height: 680 },
			position: { x: 60 + (Math.random() * 100), y: 60 + (Math.random() * 100) },
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
			componentName: "ERPConnections",
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
			componentName: "CreateUser",
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
			componentName: "CreateNotification",
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
			componentName: "ManageAdminUsers",
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
			componentName: "ManageMasterAdmin",
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

	<!-- Online/Offline Indicator + Language Switch -->
	<div class="bottom-controls-row">
		<div class="connection-indicator {isOnline ? 'online' : 'offline'}">
			<div class="status-light"></div>
		</div>
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
		<div 
			class="electric-switch lang-electric-switch" 
			class:on={$currentLocale === 'ar'}
			on:click={() => { switchLocale($currentLocale === 'en' ? 'ar' : 'en'); setTimeout(() => window.location.reload(), 100); }}
			title="{$currentLocale === 'en' ? 'Switch to Arabic' : 'Switch to English'}"
		>
			<div class="switch-track">
				<div class="switch-knob">
					<span class="knob-icon" class:off={$currentLocale === 'en'}>{$currentLocale === 'en' ? 'ع' : 'E'}</span>
				</div>
			</div>
		</div>
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
					{#if isButtonAllowed('DELIVERY_MANAGE_PRODUCTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageProductsWindow}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">Manage Products</span>
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
					{#if isButtonAllowed('DEFAULT_POSITIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDefaultPositions}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">{t('defaultPositions.title') || 'Default Positions'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_PO_REQUESTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPORequestsList}>
								<span class="menu-icon">🛒</span>
								<span class="menu-text">{t('nav.poRequests') || 'PO Requests'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_STOCK_REQUESTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openStockRequestsList}>
								<span class="menu-icon">📦</span>
								<span class="menu-text">{t('nav.stockRequests') || 'Stock Requests'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_BT_REQUESTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openBTRequestsList}>
								<span class="menu-icon">🔄</span>
								<span class="menu-text">{t('nav.btRequests') || 'BT Requests'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_NEAR_EXPIRY_REQUESTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openNearExpiryRequestsList}>
								<span class="menu-icon">⏰</span>
								<span class="menu-text">{t('nav.nearExpiryRequests') || 'Near Expiry Reports'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_CUSTOMER_PRODUCT_REQUESTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCustomerProductRequestsList}>
								<span class="menu-icon">🛍️</span>
								<span class="menu-text">{t('nav.customerProductRequests') || 'Customer Requests'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_OFFER_COST_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openOfferCostManager}>
								<span class="menu-icon">💰</span>
								<span class="menu-text">{t('nav.offerCostManager')}</span>
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
					{#if isButtonAllowed('STOCK_PRODUCT_REQUEST')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openProductRequestDesktop}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">{t('nav.productRequest') || 'Product Request'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_ERP_PRODUCTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openStockErpProducts}>
								<span class="menu-icon">🏭</span>
								<span class="menu-text">{t('nav.erpProducts') || 'ERP Products'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_PRODUCT_CLAIM_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openProductClaimManager}>
								<span class="menu-icon">👤</span>
								<span class="menu-text">{t('nav.productClaimManager') || 'Product Claim Manager'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('STOCK_EXPIRY_CONTROL')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openExpiryControl}>
								<span class="menu-icon">📅</span>
								<span class="menu-text">{t('nav.expiryControl') || 'Expiry Control'}</span>
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
		<!-- FLYER_MASTER and PRODUCTS_DASHBOARD removed from Media > Dashboard -->
		<!-- {#if showMediaDashboardSubmenu}
			<div class="submenu-subitem-container">
				{#if isButtonAllowed('FLYER_MASTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openFlyerMaster}>
							<span class="menu-icon">🏷️</span>
							<span class="menu-text">{t('nav.flyerMaster')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('PRODUCTS_DASHBOARD')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openProductsDashboard}>
							<span class="menu-icon">📦</span>
							<span class="menu-text">{t('nav.productsDashboard')}</span>
						</button>
					</div>
				{/if}
			</div>
		{/if} -->			<!-- Manage Subsection -->
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
					{#if isButtonAllowed('SHELF_PAPER_TEMPLATE_DESIGNER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openShelfPaperTemplateDesigner}>
								<span class="menu-icon">📐</span>
								<span class="menu-text">{t('nav.shelfPaperTemplateDesigner')}</span>
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
				{#if isButtonAllowed('GIFT_WHEEL_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openGiftWheelManager}>
							<span class="menu-icon">🎡</span>
							<span class="menu-text">{t('nav.giftWheel')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('SURPRISE_BOX_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openSurpriseBoxManager}>
							<span class="menu-icon">🎁</span>
							<span class="menu-text">{t('nav.surpriseBox')}</span>
						</button>
					</div>
				{/if}
					{#if isButtonAllowed('VIP_CAMPAIGN')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openVipCampaign}>
							<span class="menu-icon">👑</span>
							<span class="menu-text">{t('nav.vipCampaign')}</span>
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
				{#if isButtonAllowed('CREATE_NOTIFICATION')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCreateNotification}>
							<span class="menu-icon">📝</span>
							<span class="menu-text">{t('mobile.createNotification')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('PUSH_NOTIFICATION_SETTINGS')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openPushNotificationSettings}>
							<span class="menu-icon">🔔</span>
							<span class="menu-text">Push Notifications</span>
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
					{#if isButtonAllowed('CATEGORY_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openCategoryManager}>
							<span class="menu-icon">📁</span>
							<span class="menu-text">{t('nav.categoryManager')}</span>
						</button>
					</div>
					{/if}
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
					{#if isButtonAllowed('MANAGE_RECONCILIATIONS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageReconciliations}>
								<span class="menu-icon">📋</span>
								<span class="menu-text">{t('nav.manageReconciliations')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('ASSET_MANAGER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openAssetManager}>
								<span class="menu-icon">🏗️</span>
								<span class="menu-text">{t('nav.assetManager')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('LEASE_AND_RENT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openLeaseAndRent}>
								<span class="menu-icon">🏠</span>
								<span class="menu-text">{t('nav.leaseAndRent')}</span>
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
					{#if isButtonAllowed('SECURITY_CODE')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSecurityCodeWindow}>
								<span class="menu-icon">🔒</span>
								<span class="menu-text">{t('nav.securityCode')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('FINGERPRINT_DASHBOARD')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openFingerprintDashboard}>
								<span class="menu-icon">🖐️</span>
								<span class="menu-text">{t('nav.fingerprintDashboard')}</span>
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
					{#if isButtonAllowed('EMPLOYEE_MASTER')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openEmployeeMaster}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">{t('nav.employeeMaster')}</span>
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
					{#if isButtonAllowed('HR_SERVICES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openHRServices}>
								<span class="menu-icon">🛠️</span>
								<span class="menu-text">{t('nav.services')}</span>
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
					{#if isButtonAllowed('BREAK_REGISTER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openBreakRegister}>
							<span class="menu-icon">☕</span>
							<span class="menu-text">{t('nav.breakRegister')}</span>
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
					{#if isButtonAllowed('MY_DAILY_CHECKLIST')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openDailyChecklist}>
								<span class="menu-icon">✅</span>
								<span class="menu-text">My Daily Checklist</span>
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

	<!-- ============ 🏆 LOYALTY PROGRAM SECTION ============ -->
	<div class="menu-section">
		<button 
			class="section-button"
			on:click={() => showLoyaltySubmenu = !showLoyaltySubmenu}
		>
			<span class="section-icon">🏆</span>
			<span class="section-text">{t('nav.loyaltyProgram') || 'Loyalty Program'}</span>
			<span class="arrow" class:expanded={showLoyaltySubmenu}>▼</span>
		</button>
	</div>

	<!-- Loyalty Program Submenu - Inline below Loyalty Program button -->
	{#if showLoyaltySubmenu}
		<div class="submenu-inline loyalty-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showLoyaltyDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showLoyaltyDashboardSubmenu = true;
						}
					}}
					title={t('nav.dashboard')}
				>
					
					<span class="menu-text">{t('nav.dashboard')}</span>
				</button>
			</div>

			<!-- Dashboard Subsection Items -->
			{#if showLoyaltyDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('LOYALTY_DASHBOARD')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openLoyaltyDashboard}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.loyaltyProgram') || 'Loyalty Program'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('CUSTOMER_APP')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCustomerApp}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">{t('nav.customerApp') || 'Customer App'}</span>
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
						if (showLoyaltyManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showLoyaltyManageSubmenu = true;
						}
					}}
					title={t('nav.manage')}
				>
					
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>

			<!-- Manage Subsection Items -->
			{#if showLoyaltyManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('MANAGE_TIERS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openManageTiers}>
								<span class="menu-icon">🏅</span>
								<span class="menu-text">Manage Tiers</span>
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
						if (showLoyaltyOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showLoyaltyOperationsSubmenu = true;
						}
					}}
					title={t('nav.operations')}
				>
					
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>

			<!-- Operations Subsection Items -->
			{#if showLoyaltyOperationsSubmenu}
				<div class="submenu-subitem-container">
					<!-- Operations items will be added here -->
				</div>
			{/if}

			<!-- Reports Subsection -->
			<div class="submenu-item-container">
				<button 
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showLoyaltyReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showLoyaltyReportsSubmenu = true;
						}
					}}
					title={t('nav.reports')}
				>
					
					<span class="menu-text">{t('nav.reports')}</span>
				</button>
			</div>

			<!-- Reports Subsection Items -->
			{#if showLoyaltyReportsSubmenu}
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
				{#if isButtonAllowed('THEME_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openThemeManager}>
							<span class="menu-icon">🎨</span>
							<span class="menu-text">{t('nav.themeManager')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('AI_CHAT_GUIDE')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openAIChatGuide}>
							<span class="menu-icon">🤖</span>
							<span class="menu-text">{t('nav.aiChatGuide') || 'AI Chat Guide'}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('ERP_PRODUCT_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openErpProductManager}>
							<span class="menu-icon">🏭</span>
							<span class="menu-text">{t('nav.erpProductManager')}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('STORAGE_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openStorageManager}>
							<span class="menu-icon">🗄️</span>
							<span class="menu-text">{t('nav.storageManager') || 'Storage Manager'}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('ICON_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openIconManager}>
							<span class="menu-icon">🎨</span>
							<span class="menu-text">{t('nav.iconManager') || 'Icon Manager'}</span>
						</button>
					</div>
				{/if}
				{#if isButtonAllowed('API_KEYS_MANAGER')}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openApiKeysManager}>
							<span class="menu-icon">🔑</span>
							<span class="menu-text">{t('nav.apiKeysManager') || 'API Keys Manager'}</span>
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
					{#if isButtonAllowed('PUSH_NOTIFICATION_SETTINGS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openPushNotificationSettings}>
								<span class="menu-icon">🔔</span>
								<span class="menu-text">Push Notifications</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('LOCAL_UPDATE') || $currentUser?.isMasterAdmin}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openLocalUpdate}>
								<span class="menu-icon">🚀</span>
								<span class="menu-text">{t('nav.localBranchUpdate')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('HELPER_APPS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openHelperApps}>
								<span class="menu-icon">🧩</span>
								<span class="menu-text">{t('nav.helperApps') || 'Helper Apps'}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('SIDEBAR_ANIMATION')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openSidebarAnimationManager}>
								<span class="menu-icon">🎭</span>
								<span class="menu-text">{t('nav.sidebarAnimation') || 'Sidebar Animation'}</span>
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
					{#if isButtonAllowed('CENTRAL_PERFORMANCE') || $currentUser?.isMasterAdmin}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openCentralPerformance}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.centralPerformance')}</span>
							</button>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}

	<!-- ============ 📱 WHATSAPP SECTION ============ -->
	<div class="menu-section">
		<button class="section-button" on:click={() => showWhatsAppSubmenu = !showWhatsAppSubmenu}
			title={t('nav.whatsapp')}>
			<span class="section-icon whatsapp-icon"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512" width="16" height="16" fill="#25D366"><path d="M380.9 97.1C339 55.1 283.2 32 223.9 32c-122.4 0-222 99.6-222 222 0 39.1 10.2 77.3 29.6 111L0 480l117.7-30.9c32.4 17.7 68.9 27 106.1 27h.1c122.3 0 224.1-99.6 224.1-222 0-59.3-25.2-115-67.1-157zm-157 341.6c-33.2 0-65.7-8.9-94-25.7l-6.7-4-69.8 18.3L72 359.2l-4.4-7c-18.5-29.4-28.2-63.3-28.2-98.2 0-101.7 82.8-184.5 184.6-184.5 49.3 0 95.6 19.2 130.4 54.1 34.8 34.9 56.2 81.2 56.1 130.5 0 101.8-84.9 184.6-186.6 184.6zm101.2-138.2c-5.5-2.8-32.8-16.2-37.9-18-5.1-1.9-8.8-2.8-12.5 2.8-3.7 5.6-14.3 18-17.6 21.8-3.2 3.7-6.5 4.2-12 1.4-32.6-16.3-54-29.1-75.5-66-5.7-9.8 5.7-9.1 16.3-30.3 1.8-3.7.9-6.9-.5-9.7-1.4-2.8-12.5-30.1-17.1-41.2-4.5-10.8-9.1-9.3-12.5-9.5-3.2-.2-6.9-.2-10.6-.2-3.7 0-9.7 1.4-14.8 6.9-5.1 5.6-19.4 19-19.4 46.3 0 27.3 19.9 53.7 22.6 57.4 2.8 3.7 39.1 59.7 94.8 83.8 35.2 15.2 49 16.5 66.6 13.9 10.7-1.6 32.8-13.4 37.4-26.4 4.6-13 4.6-24.1 3.2-26.4-1.3-2.5-5-3.9-10.5-6.6z"/></svg></span>
			<span class="section-text">{t('nav.whatsapp') || 'WhatsApp'}</span>
			<span class="arrow" class:expanded={showWhatsAppSubmenu}>▼</span>
		</button>
	</div>
	{#if showWhatsAppSubmenu}
		<div class="submenu-inline whatsapp-submenu">
			<!-- Dashboard Subsection -->
			<div class="submenu-item-container">
				<button
					class="submenu-subsection-button icon-only"
					on:click={() => {
						if (showWhatsAppDashboardSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showWhatsAppDashboardSubmenu = true;
						}
					}}
					title={t('nav.dashboard')}
				>
					<span class="menu-text">{t('nav.dashboard')}</span>
				</button>
			</div>
			{#if showWhatsAppDashboardSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('WA_DASHBOARD')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWADashboard}>
								<span class="menu-icon">📊</span>
								<span class="menu-text">{t('nav.whatsappDashboard')}</span>
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
						if (showWhatsAppManageSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showWhatsAppManageSubmenu = true;
						}
					}}
					title={t('nav.manage')}
				>
					<span class="menu-text">{t('nav.manage')}</span>
				</button>
			</div>
			{#if showWhatsAppManageSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('WA_ACCOUNTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWAAccounts}>
								<span class="menu-icon">📱</span>
								<span class="menu-text">{t('nav.whatsappAccounts')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_TEMPLATES')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWATemplates}>
								<span class="menu-icon">📝</span>
								<span class="menu-text">{t('nav.whatsappTemplates')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_CONTACTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWAContacts}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">{t('nav.whatsappContacts')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_CATALOG')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWACatalog}>
								<span class="menu-icon">🛍️</span>
								<span class="menu-text">{t('nav.whatsappCatalog')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_SETTINGS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWASettings}>
								<span class="menu-icon">⚙️</span>
								<span class="menu-text">{t('nav.whatsappSettings')}</span>
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
						if (showWhatsAppOperationsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showWhatsAppOperationsSubmenu = true;
						}
					}}
					title={t('nav.operations')}
				>
					<span class="menu-text">{t('nav.operations')}</span>
				</button>
			</div>
			{#if showWhatsAppOperationsSubmenu}
				<div class="submenu-subitem-container">
					{#if isButtonAllowed('WA_LIVE_CHAT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWALiveChat}>
								<span class="menu-icon">💬</span>
								<span class="menu-text">{t('nav.whatsappLiveChat')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_BROADCASTS')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWABroadcasts}>
								<span class="menu-icon">📣</span>
								<span class="menu-text">{t('nav.whatsappBroadcasts')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_AUTO_REPLY')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWAAutoReplyBot}>
								<span class="menu-icon">🔧</span>
								<span class="menu-text">{t('nav.whatsappAutoReply')}</span>
							</button>
						</div>
					{/if}
					{#if isButtonAllowed('WA_AI_BOT')}
						<div class="submenu-item-container">
							<button class="submenu-item" on:click={openWAAIBot}>
								<span class="menu-icon">🤖</span>
								<span class="menu-text">{t('nav.whatsappAIBot')}</span>
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
						if (showWhatsAppReportsSubmenu) {
							collapseAllSubsections();
						} else {
							collapseAllSubsections();
							showWhatsAppReportsSubmenu = true;
						}
					}}
					title={t('nav.reports')}
				>
					<span class="menu-text">{t('nav.reports')}</span>
				</button>
			</div>
			{#if showWhatsAppReportsSubmenu}
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
			{#each userFavorites.favorites as fav, index (fav.button_code)}
				<button
					class="favorite-sidebar-btn"
					class:dragging={draggedIndex === index}
					class:drag-over={dragOverIndex === index}
					draggable="true"
					on:dragstart={(e) => handleDragStart(e, index)}
					on:dragover={handleDragOver}
					on:dragenter={(e) => handleDragEnter(e, index)}
					on:dragleave={handleDragLeave}
					on:drop={(e) => handleDrop(e, index)}
					on:dragend={handleDragEnd}
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

	<!-- AI Chat Character -->
	<div class="sidebar-character">
		<DancingCharacter />
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
		background: linear-gradient(145deg,
			rgba(59, 130, 246, 0.8),
			rgba(37, 99, 235, 0.75)
		);
		border: 1px solid rgba(255, 255, 255, 0.18);
		border-radius: 0.5rem;
		color: white;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		box-shadow:
			0 3px 10px rgba(59, 130, 246, 0.4),
			inset 0 1px 0 rgba(255, 255, 255, 0.22),
			inset 0 -1px 0 rgba(0, 0, 0, 0.12);
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
		backdrop-filter: blur(4px);
	}

	.interface-switch-btn:hover {
		background: linear-gradient(145deg,
			rgba(37, 99, 235, 0.88),
			rgba(29, 78, 216, 0.82)
		);
		transform: translateY(-1px);
		box-shadow:
			0 5px 16px rgba(59, 130, 246, 0.5),
			inset 0 1px 0 rgba(255, 255, 255, 0.25),
			inset 0 -1px 0 rgba(0, 0, 0, 0.12);
		border-color: rgba(255, 255, 255, 0.24);
	}

	.interface-switch-btn:active {
		transform: translateY(1px);
		box-shadow:
			0 1px 4px rgba(59, 130, 246, 0.35),
			inset 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.sidebar {
		position: fixed;
		left: 0;
		top: 0;
		bottom: 56px;
		width: 154px;
		/* Rich glass gradient — visible even on dark desktop */
		background:
			linear-gradient(
				175deg,
				rgba(55, 75, 100, 0.96) 0%,
				rgba(28, 38, 56, 0.98) 40%,
				rgba(18, 26, 42, 0.99) 100%
			);
		backdrop-filter: blur(18px) saturate(160%);
		-webkit-backdrop-filter: blur(18px) saturate(160%);
		color: var(--theme-sidebar-text, #e5e7eb);
		display: flex;
		flex-direction: column;
		/* Layered depth: right-side glow + strong shadow */
		box-shadow:
			4px 0 32px rgba(0, 0, 0, 0.6),
			1px 0 0 rgba(255, 255, 255, 0.1) inset,
			-1px 0 0 rgba(0, 0, 0, 0.3) inset;
		z-index: 1200;
		border-right: 1px solid rgba(255, 255, 255, 0.1);
		transition: all 0.35s cubic-bezier(0.4, 0, 0.2, 1);
		overflow: hidden;
	}

	/* Top glass reflection sheen */
	.sidebar::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 180px;
		background: linear-gradient(
			160deg,
			rgba(255, 255, 255, 0.09) 0%,
			rgba(255, 255, 255, 0.03) 40%,
			transparent 70%
		);
		pointer-events: none;
		z-index: 0;
		border-radius: 0;
	}

	/* Ensure content sits above the reflection */
	.sidebar > * {
		position: relative;
		z-index: 1;
	}

	.sidebar.favorites-mode {
		background:
			linear-gradient(
				175deg,
				rgba(45, 70, 140, 0.96) 0%,
				rgba(22, 35, 80, 0.98) 40%,
				rgba(14, 22, 55, 0.99) 100%
			);
		border-right-color: rgba(99, 150, 255, 0.15);
		box-shadow:
			4px 0 32px rgba(0, 0, 40, 0.65),
			1px 0 0 rgba(120, 170, 255, 0.12) inset;
	}

	.sidebar.favorites-mode .sidebar-content {
		color: var(--theme-sidebar-favorites-text, #fcd34d);
	}

	.sidebar-content {
		flex: 1;
		padding: 12px 10px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding-bottom: 4px;
	}

	.menu-section {
		display: flex;
		flex-direction: column;
		position: relative;
		margin-bottom: 5px;
		border-radius: 9px;
	}

	.section-button {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 9px 8px;
		/* Glass green button: semi-transparent with backdrop */
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-section-btn-bg, #1DBC83) 75%, transparent),
			color-mix(in srgb, var(--theme-section-btn-bg, #17a474) 60%, transparent)
		);
		border: 1px solid rgba(255, 255, 255, 0.14);
		/* Inner highlight for glass depth */
		box-shadow:
			0 2px 8px rgba(0, 0, 0, 0.25),
			inset 0 1px 0 rgba(255, 255, 255, 0.18),
			inset 0 -1px 0 rgba(0, 0, 0, 0.12);
		color: var(--theme-section-btn-text, white);
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
		cursor: pointer;
		border-radius: 9px;
		transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
	}

	.section-button:hover {
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-section-btn-hover-bg, #3b82f6) 80%, transparent),
			color-mix(in srgb, var(--theme-section-btn-hover-bg, #2563eb) 65%, transparent)
		);
		color: var(--theme-section-btn-hover-text, white);
		transform: translateX(2px);
		box-shadow:
			0 4px 12px rgba(59, 130, 246, 0.35),
			inset 0 1px 0 rgba(255, 255, 255, 0.22),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
		border-color: rgba(255, 255, 255, 0.2);
	}

	.section-button:active {
		transform: translateX(2px) scale(0.98);
		box-shadow:
			0 1px 4px rgba(0, 0, 0, 0.3),
			inset 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	/* Special styling for Approval Center button */
	.approval-button {
		background: rgba(16, 185, 129, 0.12);
		border: 1px solid rgba(16, 185, 129, 0.25);
		box-shadow:
			0 2px 8px rgba(16, 185, 129, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.08);
	}

	.approval-button:hover {
		background: rgba(16, 185, 129, 0.22);
		border-color: rgba(16, 185, 129, 0.45);
		color: #34d399;
		box-shadow:
			0 4px 14px rgba(16, 185, 129, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.12);
	}

	.approval-button .section-icon {
		filter: drop-shadow(0 0 5px rgba(16, 185, 129, 0.6));
	}

	.section-icon {
		font-size: 16px;
		flex-shrink: 0;
		width: 20px;
		height: 16px;
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		/* Subtle icon glow for glass luminance */
		filter: drop-shadow(0 0 3px rgba(255, 255, 255, 0.25));
		transition: filter 0.2s ease;
	}

	.section-button:hover .section-icon,
	.submenu-subsection-button:hover .section-icon {
		filter: drop-shadow(0 0 5px rgba(255, 255, 255, 0.4));
	}

	.section-icon.whatsapp-icon :global(svg) {
		width: 16px;
		height: 16px;
		flex-shrink: 0;
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
		padding: 9px 8px;
		/* Glass leaf item: translucent white surface */
		background: rgba(255, 255, 255, 0.07);
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow:
			0 1px 4px rgba(0, 0, 0, 0.15),
			inset 0 1px 0 rgba(255, 255, 255, 0.1);
		color: var(--theme-submenu-item-text, #f97316);
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
		font-weight: 500;
		margin-bottom: 2px;
	}

	.submenu-item:hover {
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-submenu-item-hover-bg, #3b82f6) 75%, transparent),
			color-mix(in srgb, var(--theme-submenu-item-hover-bg, #2563eb) 60%, transparent)
		);
		color: var(--theme-submenu-item-hover-text, white);
		transform: translateX(2px);
		border-color: rgba(255, 255, 255, 0.2);
		box-shadow:
			0 3px 10px rgba(59, 130, 246, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.2);
	}

	.submenu-item:active {
		transform: translateX(2px) scale(0.98);
		box-shadow:
			0 1px 3px rgba(0, 0, 0, 0.25),
			inset 0 1px 3px rgba(0, 0, 0, 0.15);
	}

	.submenu-item:last-child {
		margin-bottom: 0;
	}

	/* Inline submenu below section button */
	.submenu-inline {
		padding: 4px 0 2px;
		margin-bottom: 2px;
		/* Frosted glass submenu container */
		background: rgba(255, 255, 255, 0.03);
		border-radius: 0 0 10px 10px;
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-top: none;
		animation: glassSlideDown 0.22s cubic-bezier(0.4, 0, 0.2, 1);
		display: flex;
		flex-direction: column;
		align-items: center;
		position: relative;
		padding: 4px 4px 4px 4px;
	}

	.submenu-inline.vendor-submenu {
		padding: 4px 4px 4px 8px;
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

	@keyframes glassSlideDown {
		from {
			opacity: 0;
			transform: translateY(-6px) scaleY(0.96);
			filter: blur(2px);
		}
		to {
			opacity: 1;
			transform: translateY(0) scaleY(1);
			filter: blur(0);
		}
	}

	@keyframes glassShimmer {
		0% { background-position: -200% center; }
		100% { background-position: 200% center; }
	}

	/* Individual container for each submenu button */
	.submenu-item-container {
		background: transparent;
		border-radius: 8px;
		margin-bottom: 4px;
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
		padding: 9px 8px;
		background: rgba(255, 255, 255, 0.07);
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.1);
		color: var(--theme-submenu-item-text, #f97316);
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		font-size: 11px;
		width: 100%;
		min-height: 40px;
		text-align: left;
		font-weight: 500;
		margin-bottom: 4px;
	}

	.submenu-inline .submenu-item:hover {
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-submenu-item-hover-bg, #3b82f6) 75%, transparent),
			color-mix(in srgb, var(--theme-submenu-item-hover-bg, #2563eb) 60%, transparent)
		);
		color: var(--theme-submenu-item-hover-text, white);
		transform: translateX(2px);
		border-color: rgba(255, 255, 255, 0.2);
		box-shadow: 0 3px 10px rgba(59, 130, 246, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.2);
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
		/* Subtle icon luminance on hover */
		filter: drop-shadow(0 0 2px rgba(255, 255, 255, 0.15));
		transition: filter 0.2s ease;
	}

	.submenu-item:hover .menu-icon,
	.submenu-subsection-button:hover .menu-icon,
	.section-button:hover .menu-icon {
		filter: drop-shadow(0 0 4px rgba(255, 255, 255, 0.35));
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

	/* Subsection styling - Glass nested section button */
	.submenu-subsection-button {
		width: 100%;
		margin: 0;
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 9px 8px;
		/* Glass green: slightly muted vs top-level */
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-subsection-btn-bg, #1DBC83) 65%, transparent),
			color-mix(in srgb, var(--theme-subsection-btn-bg, #17a474) 52%, transparent)
		);
		border: 1px solid rgba(255, 255, 255, 0.12);
		box-shadow:
			0 1px 6px rgba(0, 0, 0, 0.2),
			inset 0 1px 0 rgba(255, 255, 255, 0.15),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
		color: var(--theme-subsection-btn-text, white);
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
		font-size: 11px;
		min-height: 40px;
		text-align: left;
		font-weight: 500;
	}

	.submenu-subsection-button:hover {
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-subsection-btn-hover-bg, #3b82f6) 78%, transparent),
			color-mix(in srgb, var(--theme-subsection-btn-hover-bg, #2563eb) 63%, transparent)
		);
		color: var(--theme-subsection-btn-hover-text, white);
		transform: translateX(2px);
		border-color: rgba(255, 255, 255, 0.2);
		box-shadow:
			0 3px 10px rgba(59, 130, 246, 0.32),
			inset 0 1px 0 rgba(255, 255, 255, 0.2);
	}

	.submenu-subsection-button:active {
		transform: translateX(2px) scale(0.98);
		box-shadow:
			0 1px 3px rgba(0, 0, 0, 0.3),
			inset 0 1px 3px rgba(0, 0, 0, 0.18);
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
		color: var(--theme-subsection-btn-text, white);
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
		padding: 9px 8px;
		background: linear-gradient(
			135deg,
			color-mix(in srgb, var(--theme-subsection-btn-bg, #1DBC83) 65%, transparent),
			color-mix(in srgb, var(--theme-subsection-btn-bg, #17a474) 52%, transparent)
		);
		border: 1px solid rgba(255, 255, 255, 0.12);
		box-shadow: 0 1px 6px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.15);
		color: var(--theme-subsection-btn-text, white);
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
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

	/* Nested submenu items container - glass inset */
	.submenu-subitem-container {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-left: 8px;
		padding: 4px 0;
		border-left: 2px solid rgba(255, 255, 255, 0.08);
		padding-left: 8px;
		border-radius: 0 0 0 6px;
	}

	.submenu-subitem-container .submenu-item-container {
		margin-bottom: 0;
	}

	.submenu-subitem-container .submenu-item-container:hover {
		background: transparent;
		border-color: transparent;
	}

	/* Glass scrollbar */
	.sidebar-content::-webkit-scrollbar {
		width: 4px;
	}

	.sidebar-content::-webkit-scrollbar-track {
		background: rgba(255, 255, 255, 0.03);
		border-radius: 2px;
	}

	.sidebar-content::-webkit-scrollbar-thumb {
		background: linear-gradient(
			180deg,
			rgba(255, 255, 255, 0.18),
			rgba(255, 255, 255, 0.08)
		);
		border-radius: 2px;
		border: 1px solid rgba(255, 255, 255, 0.06);
	}

	.sidebar-content::-webkit-scrollbar-thumb:hover {
		background: linear-gradient(
			180deg,
			rgba(255, 255, 255, 0.28),
			rgba(255, 255, 255, 0.15)
		);
	}



	.pwa-install-button {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 12px;
		/* Glass blue PWA button */
		background: linear-gradient(135deg, rgba(59, 130, 246, 0.78) 0%, rgba(29, 78, 216, 0.72) 100%);
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
		border: 1px solid rgba(255, 255, 255, 0.16);
		color: white;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
		font-size: 11px;
		width: 100%;
		height: 36px;
		text-align: center;
		font-weight: 500;
		box-shadow:
			0 2px 10px rgba(59, 130, 246, 0.35),
			inset 0 1px 0 rgba(255, 255, 255, 0.2),
			inset 0 -1px 0 rgba(0, 0, 0, 0.12);
	}

	.pwa-install-button:hover {
		background: linear-gradient(135deg, rgba(37, 99, 235, 0.88) 0%, rgba(30, 64, 175, 0.82) 100%);
		transform: translateY(-1px);
		box-shadow:
			0 5px 16px rgba(59, 130, 246, 0.45),
			inset 0 1px 0 rgba(255, 255, 255, 0.25),
			inset 0 -1px 0 rgba(0, 0, 0, 0.12);
		border-color: rgba(255, 255, 255, 0.22);
	}

	.pwa-install-button:active {
		transform: translateY(0);
		box-shadow:
			0 1px 4px rgba(59, 130, 246, 0.3),
			inset 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.pwa-not-supported {
		background: linear-gradient(135deg, rgba(107, 114, 128, 0.6) 0%, rgba(75, 85, 99, 0.55) 100%);
		backdrop-filter: blur(4px);
		border: 1px solid rgba(255, 255, 255, 0.08);
		opacity: 0.75;
	}

	.pwa-not-supported:hover {
		background: linear-gradient(135deg, rgba(107, 114, 128, 0.7) 0%, rgba(75, 85, 99, 0.65) 100%);
		opacity: 0.85;
	}

	.pwa-installed {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 12px;
		/* Glass green installed badge */
		background: linear-gradient(135deg, rgba(16, 185, 129, 0.65) 0%, rgba(5, 150, 105, 0.6) 100%);
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
		border: 1px solid rgba(16, 185, 129, 0.3);
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.12);
		border-radius: 8px;
		color: white;
		font-size: 11px;
		font-weight: 500;
		opacity: 0.9;
	}

	.pwa-icon {
		font-size: 14px;
		flex-shrink: 0;
	}

	.pwa-text {
		font-weight: 500;
		white-space: nowrap;
	}



	/* Connection Indicator Styles */
	.bottom-controls-row {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 10px;
		padding: 6px 8px;
		margin: 0;
		/* Exact same glass card as .view-mode-toggle */
		background: rgba(255, 255, 255, 0.06);
		border-radius: 10px;
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow:
			0 2px 12px rgba(0, 0, 0, 0.25),
			inset 0 1px 0 rgba(255, 255, 255, 0.12),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
		flex-shrink: 0;
	}

	.sidebar-character {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 4px 0;
		margin-top: auto;
		flex-shrink: 0;
		position: relative;
		overflow: visible;
	}

	.sidebar.favorites-mode .bottom-controls-row {
		background: rgba(99, 150, 255, 0.07);
		border-color: rgba(99, 150, 255, 0.15);
		box-shadow:
			0 2px 12px rgba(0, 0, 30, 0.3),
			inset 0 1px 0 rgba(120, 170, 255, 0.14),
			inset 0 -1px 0 rgba(0, 0, 0, 0.12);
	}

	.connection-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		transition: all 0.3s ease;
		flex-shrink: 0;
		/* Glass pill for status indicator */
		backdrop-filter: blur(4px);
	}

	/* Language Switch — glass amber theme */
	.lang-electric-switch {
	}

	.lang-electric-switch.on .switch-knob {
		left: 29px !important;
	}

	.lang-electric-switch .switch-knob {
		/* Amber glass knob */
		background: linear-gradient(145deg, rgba(251, 191, 36, 0.92), rgba(217, 119, 6, 0.88)) !important;
		box-shadow:
			0 2px 10px rgba(245, 158, 11, 0.55),
			inset 0 1px 0 rgba(255, 255, 255, 0.35),
			inset 0 -1px 0 rgba(0, 0, 0, 0.15) !important;
		backdrop-filter: blur(2px);
	}

	.lang-electric-switch .switch-track {
		/* Glass amber track */
		background: rgba(61, 53, 32, 0.72) !important;
		backdrop-filter: blur(6px) !important;
		-webkit-backdrop-filter: blur(6px) !important;
		border-color: rgba(245, 158, 11, 0.35) !important;
		box-shadow:
			inset 0 2px 6px rgba(0, 0, 0, 0.35),
			0 0 12px rgba(245, 158, 11, 0.2),
			inset 0 1px 0 rgba(255, 255, 255, 0.05) !important;
	}

	.lang-electric-switch .switch-knob .knob-icon {
		font-size: 0.7rem;
		font-weight: 700;
		color: white !important;
		filter: none !important;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
	}

	/* View Mode Toggle - glass card container */
	.view-mode-toggle {
		padding: 6px 8px;
		margin-top: 0;
		margin-bottom: 2px;
		margin-left: 0;
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 10px;
		/* Glass card: visible frosted panel */
		background: rgba(255, 255, 255, 0.06);
		border-radius: 10px;
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow:
			0 2px 12px rgba(0, 0, 0, 0.25),
			inset 0 1px 0 rgba(255, 255, 255, 0.12),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
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
		background: rgba(40, 40, 50, 0.75);
		backdrop-filter: blur(4px);
		border-radius: 14px;
		position: relative;
		border: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow:
			inset 0 2px 6px rgba(0, 0, 0, 0.45),
			0 1px 2px rgba(0, 0, 0, 0.25),
			inset 0 1px 0 rgba(255, 255, 255, 0.06);
		transition: all 0.3s ease;
	}

	.electric-switch.on .switch-track {
		/* Glass amber when toggled on */
		background: rgba(61, 53, 32, 0.72);
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
		border-color: rgba(245, 158, 11, 0.38);
		box-shadow:
			inset 0 2px 6px rgba(0, 0, 0, 0.35),
			0 0 12px rgba(245, 158, 11, 0.22),
			inset 0 1px 0 rgba(255, 255, 255, 0.05);
	}

	.switch-knob {
		position: absolute;
		top: 1px;
		left: 1px;
		width: 22px;
		height: 22px;
		/* Glass grey knob (off state) */
		background: linear-gradient(145deg, rgba(160, 160, 170, 0.85), rgba(100, 100, 110, 0.9));
		backdrop-filter: blur(2px);
		border-radius: 50%;
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		box-shadow:
			0 2px 6px rgba(0, 0, 0, 0.4),
			inset 0 1px 0 rgba(255, 255, 255, 0.28),
			inset 0 -1px 0 rgba(0, 0, 0, 0.15);
		display: flex;
		align-items: center;
		justify-content: center;
		border: 1px solid rgba(255, 255, 255, 0.12);
	}

	.electric-switch.on .switch-knob {
		left: 29px;
		/* Glass amber knob (on state) */
		background: linear-gradient(145deg, rgba(251, 191, 36, 0.92), rgba(217, 119, 6, 0.88));
		box-shadow:
			0 2px 10px rgba(245, 158, 11, 0.55),
			inset 0 1px 0 rgba(255, 255, 255, 0.35),
			inset 0 -1px 0 rgba(0, 0, 0, 0.15);
		border-color: rgba(245, 158, 11, 0.3);
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
		border-color: rgba(255, 255, 255, 0.2);
		box-shadow:
			inset 0 2px 6px rgba(0, 0, 0, 0.4),
			0 0 6px rgba(255, 255, 255, 0.06),
			inset 0 1px 0 rgba(255, 255, 255, 0.08);
	}

	.electric-switch.on:hover .switch-track {
		border-color: rgba(245, 158, 11, 0.55);
		box-shadow:
			inset 0 2px 6px rgba(0, 0, 0, 0.35),
			0 0 16px rgba(245, 158, 11, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.06);
	}

	.electric-switch:focus-visible .switch-track {
		border-color: rgba(245, 158, 11, 0.6);
		outline: none;
	}

	.link-button {
		width: 32px;
		height: 32px;
		border-radius: 8px;
		background: rgba(34, 197, 94, 0.1);
		border: 1px solid rgba(34, 197, 94, 0.22);
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.08);
		font-size: 1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		color: #22c55e;
		filter: hue-rotate(90deg);
	}

	.link-button:hover {
		background: rgba(34, 197, 94, 0.2);
		border-color: rgba(34, 197, 94, 0.45);
		transform: scale(1.06);
		box-shadow: 0 3px 10px rgba(34, 197, 94, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.1);
	}

	.link-button:active {
		transform: scale(0.94);
	}

	.connection-indicator.online {
		background: rgba(16, 185, 129, 0.12);
		border: 1px solid rgba(16, 185, 129, 0.28);
		box-shadow: 0 0 8px rgba(16, 185, 129, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.08);
	}

	.connection-indicator.offline {
		background: rgba(239, 68, 68, 0.12);
		border: 1px solid rgba(239, 68, 68, 0.28);
		box-shadow: 0 0 8px rgba(239, 68, 68, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.05);
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
		/* Glass separator with glow */
		background: linear-gradient(
			90deg,
			transparent,
			rgba(255, 255, 255, 0.12) 30%,
			rgba(255, 255, 255, 0.18) 50%,
			rgba(255, 255, 255, 0.12) 70%,
			transparent
		);
		margin: 8px 0;
		border: none;
		box-shadow: 0 0 6px rgba(255, 255, 255, 0.06);
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
		/* Glass favorites button */
		background: rgba(21, 163, 74, 0.1);
		border: 1px solid rgba(21, 163, 74, 0.18);
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.07);
		border-radius: 8px;
		color: #e5e7eb;
		cursor: move;
		font-size: 11px;
		font-weight: 500;
		text-align: left;
		width: 100%;
		transition: all 0.18s cubic-bezier(0.4, 0, 0.2, 1);
		line-height: 1.3;
	}

	.favorite-sidebar-btn:hover {
		background: rgba(21, 163, 74, 0.22);
		border-color: rgba(21, 163, 74, 0.4);
		transform: translateX(2px);
		color: #34d399;
		box-shadow: 0 3px 10px rgba(21, 163, 74, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.1);
	}

	.favorite-sidebar-btn:active {
		transform: translateX(2px) scale(0.98);
	}

	.favorite-sidebar-btn.dragging {
		opacity: 0.45;
		background: rgba(21, 163, 74, 0.05);
		border-color: rgba(21, 163, 74, 0.08);
		cursor: grabbing;
		box-shadow: none;
	}

	.favorite-sidebar-btn.drag-over {
		background: rgba(21, 163, 74, 0.28);
		border-color: rgba(21, 163, 74, 0.6);
		border-top: 2px solid rgba(21, 163, 74, 0.9);
		transform: scale(1.02);
		box-shadow: 0 4px 14px rgba(21, 163, 74, 0.35);
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




