<script lang="ts">
	import { onMount, onDestroy, tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { localeData, t, currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser, persistentAuthService } from '$lib/utils/persistentAuth';
	import { iconUrlMap } from '$lib/stores/iconStore';
	import { favoritesStore, favoriteButtonCodes, favoritesPanelOpen } from '$lib/stores/favorites';
	import type { FavoriteButton } from '$lib/stores/favorites';
	import BranchMaster from '$lib/components/desktop-interface/master/BranchMaster.svelte';
	import WelcomeWindow from '$lib/components/common/WelcomeWindow.svelte';
	import VersionChangelog from '$lib/components/desktop-interface/common/VersionChangelog.svelte';
	import { updateAvailable, triggerUpdate } from '$lib/stores/appUpdate';

	async function handleUpdateClick() {
		const fn = $triggerUpdate;
		if (fn) await fn();
	}

	// Icon mapping for sidebar buttons (used when saving favorites)
	const buttonIconMap: Record<string, string> = {
		'CUSTOMER_MASTER': '🤝', 'AD_MANAGER': '📢', 'PRODUCTS_MANAGER': '🛍️',
		'DELIVERY_SETTINGS': '📦', 'ORDERS_MANAGER': '🛒', 'OFFER_MANAGEMENT': '🎁',
		'RECEIVING': '📦', 'UPLOAD_VENDOR': '📤', 'CREATE_VENDOR': '➕',
		'MANAGE_VENDOR': '📋', 'START_RECEIVING': '🚀', 'RECEIVING_RECORDS': '📋',
		'VENDOR_RECORDS': '📋', 'FLYER_MASTER': '🏷️', 'PRODUCTS_DASHBOARD': '📦', 'PRODUCT_MASTER': '📦',
		'VARIATION_MANAGER': '🔗', 'OFFER_MANAGER': '🎯', 'FLYER_TEMPLATES': '🎨',
		'FLYER_SETTINGS': '⚙️', 'NORMAL_PAPER_MANAGER': '📄', 'ONE_DAY_OFFER_MANAGER': '📅', 'SOCIAL_LINK_MANAGER': '🔗',
		'OFFER_PRODUCT_EDITOR': '✅', 'CREATE_NEW_OFFER': '🏷️', 'PRICING_MANAGER': '💵',
		'ERP_ENTRY_MANAGER': '📊', 'GENERATE_FLYERS': '📄', 'SHELF_PAPER_MANAGER': '🏷️', 'SHELF_PAPER_TEMPLATE_DESIGNER': '📐',
		'NEAR_EXPIRY_MANAGER': '⏰', 'COUPON_DASHBOARD_PROMO': '🎁', 'CAMPAIGN_MANAGER': '📋',
		'VIEW_OFFER_MANAGER': '📊', 'CUSTOMER_IMPORTER': '👥', 'PRODUCT_MANAGER_PROMO': '🎁',
		'COUPON_REPORTS': '📊', 'APPROVAL_CENTER': '✓', 'PURCHASE_VOUCHER_MANAGER': '📄',
		'MANAGE_RECONCILIATIONS': '📋', 'MANUAL_SCHEDULING': '📅', 'DAY_BUDGET_PLANNER': '📊',
		'MONTHLY_MANAGER': '📅', 'EXPENSE_MANAGER': '💸', 'PAID_MANAGER': '💳',
		'DENOMINATION': '💵', 'PETTY_CASH': '💰', 'EXPENSE_TRACKER': '💰',
		'SALES_REPORT': '📊', 'MONTHLY_BREAKDOWN': '📅', 'OVERDUES_REPORT': '⏰',
		'VENDOR_PAYMENTS': '💳', 'POS_REPORT': '🏪', 'CREATE_DEPARTMENT': '🏢',
		'CREATE_LEVEL': '📊', 'CREATE_POSITION': '💼', 'REPORTING_MAP': '📈',
		'ASSIGN_POSITIONS': '🎯', 'LINK_ID': '🔗', 'EMPLOYEE_FILES': '📁', 'EMPLOYEE_DASHBOARD': '📊',
		'PROCESS_FINGERPRINT': '📂', 'SALARY_AND_WAGE': '💰', 'SHIFTS': '⏰', 'SHIFT_AND_DAY_OFF': '🏖️',
		'DISCIPLINE': '⚖️', 'INCIDENT_MANAGER': '🚨', 'REPORT_INCIDENT': '📝',
		'FINGERPRINT_TRANSACTIONS': '👆', 'EXPORT_BIOMETRIC_DATA': '📊',
		'DAILY_CHECKLIST_MANAGER': '📋', 'MY_DAILY_CHECKLIST': '✅',
		'TASK_MASTER': '✅', 'CREATE_TASK': '✨', 'VIEW_TASKS': '📋',
		'ASSIGN_TASKS': '👥', 'VIEW_MY_TASKS': '📝', 'VIEW_MY_ASSIGNMENTS': '👨‍💼',
		'TASK_STATUS': '📊', 'BRANCH_PERFORMANCE': '📊', 'COMMUNICATION_CENTER': '📞',
		'CREATE_NOTIFICATION': '📝', 'USER_MANAGEMENT': '👤', 'CREATE_USER': '👤',
		'MANAGE_ADMIN_USERS': '👥', 'MANAGE_MASTER_ADMIN': '🔐',
		'INTERFACE_ACCESS_MANAGER': '🔧', 'APPROVAL_PERMISSIONS': '🔐',
		'BRANCHES': '🏢', 'SETTINGS': '🔊', 'E_R_P_CONNECTIONS': '🔌',
		'CLEAR_TABLES': '🗑️', 'BUTTON_ACCESS_CONTROL': '🎛️',
		'APP_PERMISSIONS': '🛡️',
		'LEAVES_AND_VACATIONS': '🏖️', 'LEAVE_REQUEST': '📋',
		'ERP_PRODUCT_MANAGER': '🏭', 'ERP_CREDENTIALS': '🏭',
		// Additional DB button codes
		'UPLOAD_EMPLOYEES': '📤', 'WARNING_MASTER': '⚠️', 'SALARY_WAGE_MANAGEMENT': '💰',
		'CONTACT_MANAGEMENT': '📇', 'DOCUMENT_MANAGEMENT': '📑', 'BIOMETRIC_DATA': '👆',
		'BRANCH_MASTER': '🏢', 'SOUND_SETTINGS': '🔊', 'CATEGORY_MANAGER': '📂', 'ASSET_MANAGER': '🏗️', 'LEASE_AND_RENT': '🏠',
		'REPORTS_STATS': '📊', 'COUPON_DASHBOARD': '🎁', 'MANAGE_CAMPAIGNS': '📋',
		'IMPORT_CUSTOMERS': '👥', 'MANAGE_PRODUCTS': '🎁', 'OVER_DUES': '⏰',
		'USER_PERMISSIONS': '🔐', 'USERS': '👤', 'CREATE_USER_ROLES': '👥',
		'ASSIGN_ROLES': '🎯', 'ERP_CONNECTIONS': '🔌', 'INTERFACE_ACCESS': '🔧',
		'CREATE_TASK_TEMPLATE': '✨', 'VIEW_TASK_TEMPLATES': '📋',
		'STOCK_PRODUCT_REQUEST': '📋',
		'STOCK_PO_REQUESTS': '🛒', 'STOCK_STOCK_REQUESTS': '📦', 'STOCK_BT_REQUESTS': '🔄',
		'STOCK_NEAR_EXPIRY_REQUESTS': '⏰',
		'STOCK_CUSTOMER_PRODUCT_REQUESTS': '🛍️',
		'STOCK_ERP_PRODUCTS': '🏭',
		'STOCK_OFFER_COST_MANAGER': '',
		'STOCK_PRODUCT_CLAIM_MANAGER': '👤',
		'STOCK_EXPIRY_CONTROL': '📅',
		'WA_DASHBOARD': '📊',
		'WA_LIVE_CHAT': '💬',
		'WA_BROADCASTS': '📣',
		'WA_TEMPLATES': '📝',
		'WA_CONTACTS': '👥',
		'WA_AUTO_REPLY': '🔧',
		'WA_AI_BOT': '💬',
		'WA_ACCOUNTS': '📱',
		'WA_SETTINGS': '⚙️',
		'WA_CATALOG': '📦',
		'BREAK_REGISTER': '☕',
		'STORAGE_MANAGER': '🗄️',
		'API_KEYS_MANAGER': '🔑',
		// Email Module
		'EMAIL_DASHBOARD': '📊',
		'EMAIL_ACCOUNTS': '📱',
		'EMAIL_TEMPLATES': '📝',
		'EMAIL_SIGNATURES': '✍️',
		'EMAIL_GROUPS': '👥',
		'EMAIL_SETTINGS': '⚙️',
		'EMAIL_AI_SETTINGS': '🤖',
		'EMAIL_CENTRE': '📬',
		'EMAIL_COMPOSE': '✉️',
		'EMAIL_BROADCAST': '📣',
		'EMAIL_QUEUE': '📋',
		'EMAIL_SCHEDULED': '🕐',
		'EMAIL_LOGS': '📄',
		'EMAIL_DELIVERY_REPORTS': '✅',
		'EMAIL_CAMPAIGN_REPORTS': '📈',
		'EMAIL_FAILED': '❌'
	};

	let mounted = false;
	let permittedButtons: Array<{
		id: string;
		button_code: string;
		button_name_en: string;
		section_name: string;
		subsection_name: string;
		section_order: number;
		subsection_order: number;
		button_order: number;
		checked: boolean;
	}> = [];
	let loadingButtons = false;
	let savingFavorites = false;
	let saveDebounceTimer: ReturnType<typeof setTimeout> | null = null;
	let logoClickCount = 0;
	let logoClickTimeout: ReturnType<typeof setTimeout> | null = null;
	const INACTIVITY_TIMEOUT_MS = 3 * 60 * 1000;
	let inactivityTimer: ReturnType<typeof setTimeout> | null = null;
	let lastActivityReset = 0;
	let showInactivityPrompt = false;
	let showReauthentication = false;
	let reauthDigits = ['', '', '', '', '', ''];
	let reauthError = '';
	let reauthLoading = false;

	function activateInactivityModal(node: HTMLDialogElement) {
		if (!node.open) node.showModal();
		return {
			destroy() {
				if (node.open) node.close();
			}
		};
	}

	function containLockedKeyboardEvent(event: KeyboardEvent) {
		// Keep keyboard shortcuts inside the native modal while the desktop is locked.
		if (event.key === 'Escape') event.preventDefault();
		event.stopPropagation();
	}

	function clearInactivityTimer() {
		if (inactivityTimer) clearTimeout(inactivityTimer);
		inactivityTimer = null;
	}

	function scheduleInactivityPrompt() {
		clearInactivityTimer();
		if (!$currentUser || showInactivityPrompt) return;
		lastActivityReset = Date.now();
		inactivityTimer = setTimeout(() => {
			showInactivityPrompt = true;
			showReauthentication = false;
			reauthDigits = ['', '', '', '', '', ''];
			reauthError = '';
		}, INACTIVITY_TIMEOUT_MS);
	}

	function recordDesktopActivity() {
		if (!$currentUser || showInactivityPrompt || Date.now() - lastActivityReset < 1000) return;
		scheduleInactivityPrompt();
	}

	// Map button_code → i18n translation key for showing translated button names
	const buttonCodeTranslationMap: Record<string, string> = {
		'CUSTOMER_MASTER': 'admin.customerMaster',
		'AD_MANAGER': 'admin.adManager',
		'PRODUCTS_MANAGER': 'admin.productsManager',
		'DELIVERY_SETTINGS': 'admin.deliverySettings',
		'ORDERS_MANAGER': 'admin.ordersManager',
		'OFFER_MANAGEMENT': 'admin.offerManagement',
		'RECEIVING': 'nav.receiving',
		'UPLOAD_VENDOR': 'admin.uploadVendor',
		'CREATE_VENDOR': 'admin.createVendor',
		'MANAGE_VENDOR': 'admin.manageVendor',
		'START_RECEIVING': 'nav.startReceiving',
		'RECEIVING_RECORDS': 'nav.receivingRecords',
		'VENDOR_RECORDS': 'reports.vendorRecords',
		'FLYER_MASTER': 'nav.flyerMaster',
		'PRODUCTS_DASHBOARD': 'nav.productsDashboard',
		'PRODUCT_MASTER': 'nav.productMaster',
		'VARIATION_MANAGER': 'nav.variationManager',
		'OFFER_MANAGER': 'nav.offerManager',
		'FLYER_TEMPLATES': 'nav.flyerTemplates',
		'FLYER_SETTINGS': 'nav.flyerSettings',
		'NORMAL_PAPER_MANAGER': 'nav.normalPaperManager',
		'ONE_DAY_OFFER_MANAGER': 'nav.oneDayOfferManager',
		'SOCIAL_LINK_MANAGER': 'nav.socialLinkManager',
		'OFFER_PRODUCT_EDITOR': 'nav.offerProductEditor',
		'CREATE_NEW_OFFER': 'nav.createNewOffer',
		'PRICING_MANAGER': 'nav.pricingManager',
		'ERP_ENTRY_MANAGER': 'nav.erpEntryManager',
		'GENERATE_FLYERS': 'nav.generateFlyers',
		'SHELF_PAPER_MANAGER': 'nav.shelfPaperManager',
		'SHELF_PAPER_TEMPLATE_DESIGNER': 'nav.shelfPaperTemplateDesigner',
		'NEAR_EXPIRY_MANAGER': 'nav.nearExpiryManager',
		'COUPON_DASHBOARD_PROMO': 'nav.couponDashboard',
		'CAMPAIGN_MANAGER': 'nav.manageCampaigns',
		'VIEW_OFFER_MANAGER': 'nav.viewOfferManager',
		'CUSTOMER_IMPORTER': 'nav.importCustomers',
		'PRODUCT_MANAGER_PROMO': 'nav.manageProducts',
		'COUPON_REPORTS': 'nav.reportsAndStats',
		'APPROVAL_CENTER': 'nav.approvalCenter',
		'PURCHASE_VOUCHER_MANAGER': 'nav.purchaseVoucherManager',
		'MANAGE_RECONCILIATIONS': 'nav.manageReconciliations',
		'MANUAL_SCHEDULING': 'nav.manualScheduling',
		'DAY_BUDGET_PLANNER': 'nav.dayBudgetPlanner',
		'MONTHLY_MANAGER': 'nav.monthlyManager',
		'EXPENSE_MANAGER': 'nav.expenseManager',
		'PAID_MANAGER': 'nav.paidManager',
		'DENOMINATION': 'nav.denomination',
		'PETTY_CASH': 'nav.pettyCash',
		'EXPENSE_TRACKER': 'reports.expenseTracker',
		'SALES_REPORT': 'reports.salesReport',
		'MONTHLY_BREAKDOWN': 'nav.monthlyBreakdown',
		'OVERDUES_REPORT': 'nav.overdues',
		'VENDOR_PAYMENTS': 'reports.vendorPayments',
		'POS_REPORT': 'nav.pos',
		'CREATE_DEPARTMENT': 'nav.createDepartment',
		'CREATE_LEVEL': 'nav.createLevel',
		'CREATE_POSITION': 'nav.createPosition',
		'REPORTING_MAP': 'nav.reportingMap',
		'ASSIGN_POSITIONS': 'nav.assignPositions',
		'LINK_ID': 'nav.linkID',
		'EMPLOYEE_FILES': 'nav.employeeFiles', 'EMPLOYEE_DASHBOARD': 'nav.employeeDashboard',
		'PROCESS_FINGERPRINT': 'nav.processFingerprint',
		'SALARY_AND_WAGE': 'nav.salaryAndWage',
		'SHIFTS': 'nav.shifts',
		'SHIFT_AND_DAY_OFF': 'nav.shiftAndLeave',
		'DISCIPLINE': 'nav.discipline',
		'INCIDENT_MANAGER': 'nav.incidentManager',
		'REPORT_INCIDENT': 'nav.reportIncident',
		'DAILY_CHECKLIST_MANAGER': 'nav.dailyChecklistManager',
		'MY_DAILY_CHECKLIST': 'hr.dailyChecklist.myDailyChecklist',
		'FINGERPRINT_TRANSACTIONS': 'nav.fingerprintTransactions',
		'EXPORT_BIOMETRIC_DATA': 'nav.exportBiometricData',
		'TASK_MASTER': 'admin.taskMaster',
		'CREATE_TASK': 'nav.createTaskTemplate',
		'VIEW_TASKS': 'nav.viewTaskTemplates',
		'ASSIGN_TASKS': 'nav.assignTasks',
		'VIEW_MY_TASKS': 'nav.viewMyTasks',
		'VIEW_MY_ASSIGNMENTS': 'nav.viewMyAssignments',
		'TASK_STATUS': 'nav.taskStatus',
		'BRANCH_PERFORMANCE': 'nav.branchPerformance',
		'COMMUNICATION_CENTER': 'admin.communicationCenter',
		'CREATE_NOTIFICATION': 'mobile.createNotification',
		'USER_MANAGEMENT': 'nav.usersList',
		'CREATE_USER': 'nav.createUser',
		'MANAGE_ADMIN_USERS': 'nav.manageAdminUsers',
		'MANAGE_MASTER_ADMIN': 'nav.manageMasterAdmin',
		'INTERFACE_ACCESS_MANAGER': 'nav.interfaceAccess',
		'APPROVAL_PERMISSIONS': 'nav.approvalPermissions',
		'BRANCHES': 'admin.branchesMaster',
		'SETTINGS': 'nav.soundSettings',
		'E_R_P_CONNECTIONS': 'nav.erpConnections',
		'CLEAR_TABLES': 'nav.clearTables',
		'BUTTON_ACCESS_CONTROL': 'nav.buttonAccessControl',
		'APP_PERMISSIONS': 'nav.appPermissions',
		'AI_CHAT_GUIDE': 'nav.aiChatGuide',
		'LEAVES_AND_VACATIONS': 'nav.leavesAndVacations',
		'LEAVE_REQUEST': 'nav.leaveRequest',
		'ERP_PRODUCT_MANAGER': 'nav.erpProductManager',
		'ERP_CREDENTIALS': 'nav.erpCredentials',
		// Additional DB button codes (aliases / alternate codes)
		'UPLOAD_EMPLOYEES': 'hr.masterUploadEmployees',
		'WARNING_MASTER': 'nav.warningMaster',
		'SALARY_WAGE_MANAGEMENT': 'hr.masterSalaryManagement',
		'CONTACT_MANAGEMENT': 'hr.masterContactManagement',
		'DOCUMENT_MANAGEMENT': 'hr.masterDocumentManagement',
		'BIOMETRIC_DATA': 'hr.biometricData',
		'BRANCH_MASTER': 'admin.branchesMaster',
		'SOUND_SETTINGS': 'nav.soundSettings',
		'CATEGORY_MANAGER': 'nav.categoryManager',
		'ASSET_MANAGER': 'nav.assetManager',
		'LEASE_AND_RENT': 'nav.leaseAndRent',
		'REPORTS_STATS': 'nav.reportsAndStats',
		'COUPON_DASHBOARD': 'nav.couponDashboard',
		'MANAGE_CAMPAIGNS': 'nav.manageCampaigns',
		'IMPORT_CUSTOMERS': 'nav.importCustomers',
		'MANAGE_PRODUCTS': 'nav.manageProducts',
		'OVER_DUES': 'nav.overdues',
		'USER_PERMISSIONS': 'nav.userPermissions',
		'USERS': 'nav.users',
		'CREATE_USER_ROLES': 'nav.createUserRoles',
		'ASSIGN_ROLES': 'nav.assignRoles',
		'ERP_CONNECTIONS': 'nav.erpConnections',
		'INTERFACE_ACCESS': 'nav.interfaceAccess',
		'CREATE_TASK_TEMPLATE': 'nav.createTaskTemplate',
		'VIEW_TASK_TEMPLATES': 'nav.viewTaskTemplates',
		'STOCK_PRODUCT_REQUEST': 'nav.productRequest',
		'STOCK_PO_REQUESTS': 'nav.poRequests',
		'STOCK_STOCK_REQUESTS': 'nav.stockRequests',
		'STOCK_BT_REQUESTS': 'nav.btRequests',
		'STOCK_NEAR_EXPIRY_REQUESTS': 'nav.nearExpiryRequests',
		'STOCK_CUSTOMER_PRODUCT_REQUESTS': 'nav.customerProductRequests',
		'STOCK_ERP_PRODUCTS': 'nav.erpProducts',
		'STOCK_OFFER_COST_MANAGER': 'nav.offerCostManager',
		'STOCK_PRODUCT_CLAIM_MANAGER': 'nav.productClaimManager',
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
		'BREAK_REGISTER': 'nav.breakRegister',
		'STORAGE_MANAGER': 'nav.storageManager',
		'API_KEYS_MANAGER': 'nav.apiKeysManager'
	};

	function getButtonLabel(buttonCode: string, fallback: string): string {
		const key = buttonCodeTranslationMap[buttonCode];
		if (key) {
			const translated = t(key);
			if (translated && translated !== key) return translated;
		}
		return fallback;
	}

	// Map DB section_name_en → i18n key for section headers
	const sectionTranslationMap: Record<string, string> = {
		'CONTROLS': 'nav.controls',
		'SYSTEM': 'nav.system',
		'DELIVERY': 'nav.delivery',
		'VENDOR': 'nav.vendor',
		'MEDIA': 'nav.media',
		'PROMO': 'nav.promo',
		'FINANCE': 'nav.finance',
		'HR': 'nav.hr',
		'TASKS': 'nav.tasks',
		'NOTIFICATIONS': 'nav.notification',
		'USERS': 'nav.users',
		'USER': 'nav.users',
		'Controls': 'nav.controls',
		'System': 'nav.system',
		'Delivery': 'nav.delivery',
		'Vendor': 'nav.vendor',
		'Media': 'nav.media',
		'Promo': 'nav.promo',
		'Finance': 'nav.finance',
		'Hr': 'nav.hr',
		'Tasks': 'nav.tasks',
		'Notifications': 'nav.notification',
		'Users': 'nav.users',
		'Other': 'nav.other',
	};

	function getSectionLabel(sectionName: string): string {
		const key = sectionTranslationMap[sectionName] || sectionTranslationMap[sectionName.toUpperCase()];
		if (key) {
			const translated = t(key);
			if (translated && translated !== key) return translated;
		}
		return sectionName;
	}

	function getSubsectionLabel(subsectionName: string): string {
		const key = `nav.${subsectionName.toLowerCase()}`;
		const translated = t(key);
		return translated && translated !== key ? translated : subsectionName;
	}

	onMount(async () => {
		mounted = true;
		scheduleInactivityPrompt();
		window.addEventListener('pointerdown', recordDesktopActivity, true);
		window.addEventListener('pointermove', recordDesktopActivity, true);
		window.addEventListener('keydown', recordDesktopActivity, true);
		window.addEventListener('touchstart', recordDesktopActivity, true);
		window.addEventListener('scroll', recordDesktopActivity, true);
		
		// Load favorites for current user
		if ($currentUser) {
			await favoritesStore.load($currentUser.id, $currentUser.employee_id || null);
		}
		
		// Auto-open welcome window on first visit
		const hasVisited = localStorage.getItem('aqura-visited');
		if (!hasVisited) {
			setTimeout(() => {
				openWelcomeWindow();
				localStorage.setItem('aqura-visited', 'true');
			}, 1000);
		}

	});

	onDestroy(() => {
		clearInactivityTimer();
		if (typeof window !== 'undefined') {
			window.removeEventListener('pointerdown', recordDesktopActivity, true);
			window.removeEventListener('pointermove', recordDesktopActivity, true);
			window.removeEventListener('keydown', recordDesktopActivity, true);
			window.removeEventListener('touchstart', recordDesktopActivity, true);
			window.removeEventListener('scroll', recordDesktopActivity, true);
		}
	});

	async function beginReauthentication() {
		showReauthentication = true;
		reauthDigits = ['', '', '', '', '', ''];
		reauthError = '';
		await tick();
		(document.getElementById('desktop-reauth-digit-0') as HTMLInputElement | null)?.focus();
	}

	async function verifyReauthentication() {
		const code = reauthDigits.join('');
		if (code.length !== 6 || reauthLoading || !$currentUser) return;
		reauthLoading = true;
		reauthError = '';
		try {
			const { data, error } = await supabase.rpc('verify_quick_access_code', { p_code: code });
			if (error || !data?.success || String(data.user?.id) !== String($currentUser.id)) throw new Error('invalid');
			showInactivityPrompt = false;
			showReauthentication = false;
			reauthDigits = ['', '', '', '', '', ''];
			scheduleInactivityPrompt();
		} catch {
			reauthError = $currentLocale === 'ar' ? 'رمز الوصول غير صحيح لهذا المستخدم.' : 'The access code does not match this user.';
			reauthDigits = ['', '', '', '', '', ''];
			await tick();
			(document.getElementById('desktop-reauth-digit-0') as HTMLInputElement | null)?.focus();
		} finally {
			reauthLoading = false;
		}
	}

	function handleReauthInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const digit = input.value.replace(/\D/g, '').slice(-1);
		reauthDigits[index] = digit;
		input.value = digit;
		if (digit && index < 5) (document.getElementById(`desktop-reauth-digit-${index + 1}`) as HTMLInputElement | null)?.focus();
		if (reauthDigits.every(value => value !== '')) void verifyReauthentication();
	}

	function handleReauthKeydown(event: KeyboardEvent, index: number) {
		if (event.key === 'Enter') {
			event.preventDefault();
			void verifyReauthentication();
			return;
		}
		if (event.key === 'Backspace' && !reauthDigits[index] && index > 0) {
			(document.getElementById(`desktop-reauth-digit-${index - 1}`) as HTMLInputElement | null)?.focus();
		}
	}

	function handleReauthPaste(event: ClipboardEvent) {
		event.preventDefault();
		const digits = (event.clipboardData?.getData('text') || '').replace(/\D/g, '').slice(0, 6);
		reauthDigits = Array.from({ length: 6 }, (_, index) => digits[index] || '');
		if (digits.length === 6) void verifyReauthentication();
	}

	async function logoutFromInactivityPrompt() {
		clearInactivityTimer();
		showInactivityPrompt = false;
		await persistentAuthService.logout();
		goto('/login/employee?mode=desktop', { replaceState: true });
	}

	// Reload favorites when user changes
	$: if ($currentUser && mounted) {
		favoritesStore.load($currentUser.id, $currentUser.employee_id || null);
	}

	// Start the inactivity timer if authentication finishes after this page mounts.
	$: if ($currentUser && mounted && !showInactivityPrompt && !inactivityTimer) {
		scheduleInactivityPrompt();
	}

	// Refresh every time the panel opens so removed buttons and permission
	// changes never remain cached in the manager.
	$: if ($favoritesPanelOpen) {
		loadPermittedButtons();
	}

	async function toggleFavoritesPanel() {
		const isOpen = !$favoritesPanelOpen;
		favoritesPanelOpen.set(isOpen);
	}

	function handleLogoClick() {
		logoClickCount++;
		if (logoClickTimeout) clearTimeout(logoClickTimeout);
		
		// Reset click count after 1 second
		logoClickTimeout = setTimeout(() => {
			logoClickCount = 0;
		}, 1000);
		
		// Show manage favorites when triple-clicked
		if (logoClickCount >= 3) {
			logoClickCount = 0;
			toggleFavoritesPanel();
		}
	}

	async function loadPermittedButtons() {
		if (!$currentUser) return;
		loadingButtons = true;
		try {
			// Catalog is the button/section source of truth — see
			// [[button-permission-system-rewrite]].
			const catalogRes = await fetch('/api/parse-sidebar');
			const catalog = await catalogRes.json();
			const catalogButtons: Array<{
				code: string;
				name: string;
				section: string;
				subsection: string;
				sectionOrder: number;
				subsectionOrder: number;
				buttonOrder: number;
			}> = [];
			for (const [sectionOrder, section] of (catalog.sections || []).entries()) {
				for (const [subsectionOrder, subsection] of (section.subsections || []).entries()) {
					for (const [buttonOrder, button] of (subsection.buttons || []).entries()) {
						catalogButtons.push({
							code: button.code,
							name: button.name,
							section: section.name,
							subsection: subsection.name,
							sectionOrder,
							subsectionOrder,
							buttonOrder
						});
					}
				}
			}

			let allowedCodes: Set<string>;
			if ($currentUser.isMasterAdmin) {
				// Master admin gets every button in the catalog
				allowedCodes = new Set(catalogButtons.map(b => b.code));
			} else {
				const { data: permissions } = await supabase
					.from('button_permissions')
					.select('button_code')
					.eq('user_id', $currentUser.id)
					.eq('is_enabled', true);
				allowedCodes = new Set((permissions || []).map(p => p.button_code));
			}

			// Pre-check buttons that are already favorites
			const favCodes = $favoriteButtonCodes;

			permittedButtons = catalogButtons
				.filter(b => allowedCodes.has(b.code))
				.map(b => ({
					id: b.code,
					button_code: b.code,
					button_name_en: b.name,
					section_name: b.section,
					subsection_name: b.subsection,
					section_order: b.sectionOrder,
					subsection_order: b.subsectionOrder,
					button_order: b.buttonOrder,
					checked: favCodes.has(b.code)
				}))
				.sort((a, b) => a.section_order - b.section_order || a.subsection_order - b.subsection_order || a.button_order - b.button_order);
		} catch (err) {
			console.error('Error loading permitted buttons:', err);
		} finally {
			loadingButtons = false;
		}
	}

	/** Auto-save favorites whenever a checkbox is toggled (debounced) */
	function onFavoriteToggle() {
		if (saveDebounceTimer) clearTimeout(saveDebounceTimer);
		saveDebounceTimer = setTimeout(async () => {
			savingFavorites = true;
			const selectedFavorites: FavoriteButton[] = permittedButtons
				.filter(b => b.checked)
				.map(b => ({
					button_code: b.button_code,
					button_name_en: b.button_name_en,
					icon: buttonIconMap[b.button_code] || '📌'
				}));
			await favoritesStore.save(selectedFavorites);
			savingFavorites = false;
		}, 500);
	}

	function showVersionInfo() {
		openWindow({
			id: 'version-changelog-' + Date.now(),
			title: 'Version Changelog',
			component: VersionChangelog,
			size: { width: 800, height: 600 },
			position: { x: 100, y: 50 },
			resizable: true,
			minimizable: true,
			maximizable: true
		});
	}

	// Sample windows for demonstration
	function openWelcomeWindow() {
		openWindow({
			id: 'welcome',
			title: $localeData ? t('welcome.title') : 'Welcome to Aqura',
			component: WelcomeWindow,
			size: { width: 600, height: 400 },
			icon: '🎉',
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<svelte:head>
	<title>{$localeData ? t('app.name') : 'Aqura Management System'}</title>
	<meta name="description" content={$localeData ? t('app.description') : 'PWA-first windowed management platform'} />
</svelte:head>

<div class="desktop-content">
	{#if mounted}
		<!-- Favorites Panel -->
		{#if $favoritesPanelOpen}
			<div class="favorites-overlay" on:click={toggleFavoritesPanel} on:keydown={() => {}}></div>
			<div class="favorites-panel">
				<div class="favorites-header">
					<h3>⭐ {t('nav.manageFavorites') || 'Manage Favorites'}</h3>
					<div class="header-right">
						{#if savingFavorites}
							<span class="saving-indicator">{t('nav.savingFavorites') || 'Saving...'}</span>
						{/if}
						<button class="close-btn" on:click={toggleFavoritesPanel}>✕</button>
					</div>
				</div>
				<div class="favorites-list">
					{#if loadingButtons}
						<div class="loading-msg">{t('nav.loadingButtons') || 'Loading buttons...'}</div>
					{:else if permittedButtons.length === 0}
						<div class="empty-msg">{t('nav.noPermittedButtons') || 'No permitted buttons found.'}</div>
					{:else}
						{@const groupedButtons = permittedButtons.reduce((acc, btn) => {
							if (!acc[btn.section_name]) acc[btn.section_name] = {};
							if (!acc[btn.section_name][btn.subsection_name]) acc[btn.section_name][btn.subsection_name] = [];
							acc[btn.section_name][btn.subsection_name].push(btn);
							return acc;
						}, {} as Record<string, Record<string, typeof permittedButtons>>)}
						{#each Object.entries(groupedButtons) as [section, subsections]}
							<div class="section-group">
								<div class="section-title">{getSectionLabel(section)}</div>
								{#each Object.entries(subsections) as [subsection, buttons]}
									<div class="subsection-title">{getSubsectionLabel(subsection)}</div>
									{#each buttons as btn}
										<label class="favorite-item">
											<input type="checkbox" bind:checked={btn.checked} on:change={onFavoriteToggle} />
											<span class="btn-icon">{buttonIconMap[btn.button_code] || '📌'}</span>
											<span class="btn-name">{getButtonLabel(btn.button_code, btn.button_name_en)}</span>
										</label>
									{/each}
								{/each}
							</div>
						{/each}
					{/if}
				</div>
			</div>
		{/if}

		<!-- Welcome Screen -->
		<div class="welcome-screen">
			<div class="welcome-container">
				<div class="card-qr-row">
					<div class="welcome-card">
						<div class="welcome-meta-bar">
							{#if $updateAvailable}
								<button class="update-badge update-available" on:click={handleUpdateClick} title={$currentLocale === 'ar' ? 'تحديث متاح - انقر للتحديث' : 'Update Available - Click to update'}>
									🔄 {$currentLocale === 'ar' ? 'تحديث متاح' : 'Update Available'}
								</button>
							{:else}
								<span class="update-badge up-to-date">
									✅ {$currentLocale === 'ar' ? 'محدّث' : 'Up to Date'}
								</span>
							{/if}
							{#if $currentUser?.isMasterAdmin}
								<button class="version-badge" on:click={showVersionInfo} title="Version Changelog">AQ14.12.12.10</button>
							{/if}
						</div>
						<div class="logo-section">
							<div class="logo" on:click={handleLogoClick} role="button" tabindex="0" on:keydown={(e) => e.key === 'Enter' && handleLogoClick()}>
								<img src={$iconUrlMap['aqura-logo'] || '/icons/Aqura logo.png'} alt="Aqura Logo" class="logo-image" />
							</div>
							<div class="aqura-brand-logo" aria-label="Aqura">
								<img src="/icons/Aqura logo.png" alt="Original Aqura Logo" class="aqura-brand-logo-image" />
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

	{/if}
</div>

{#if showInactivityPrompt}
	<dialog class="desktop-inactivity-backdrop" use:activateInactivityModal on:cancel|preventDefault on:keydown={containLockedKeyboardEvent}>
		<div class="desktop-inactivity-dialog" role="dialog" tabindex="-1" aria-modal="true" aria-labelledby="desktop-inactivity-title" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
			<div class="desktop-inactivity-icon" aria-hidden="true">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
			</div>
			<h2 id="desktop-inactivity-title">{$currentLocale === 'ar' ? 'تم إيقاف الجلسة مؤقتاً' : 'Session paused'}</h2>
			<p>{$currentLocale === 'ar' ? 'لم يتم رصد أي نشاط لمدة 3 دقائق. اختر المتابعة أو تسجيل الخروج.' : 'No activity was detected for 3 minutes. Continue securely or log out.'}</p>

			{#if showReauthentication}
				<div class="desktop-reauth-section">
					<div class="desktop-reauth-label">{$currentLocale === 'ar' ? 'أدخل رمز الوصول المكوّن من 6 أرقام' : 'Enter your 6-digit access code'}</div>
					<div class="desktop-reauth-digits" dir="ltr">
						{#each reauthDigits as digit, index}
							<input id="desktop-reauth-digit-{index}" type="password" value={digit} maxlength="1" inputmode="numeric" pattern="[0-9]*" autocomplete="off" disabled={reauthLoading} on:input={(event) => handleReauthInput(event, index)} on:keydown={(event) => handleReauthKeydown(event, index)} on:paste={handleReauthPaste} />
						{/each}
					</div>
					{#if reauthError}<div class="desktop-reauth-error" role="alert">{reauthError}</div>{/if}
					<button class="desktop-unlock-btn" type="button" on:click={verifyReauthentication} disabled={reauthLoading || reauthDigits.some(value => value === '')}>
						{reauthLoading ? ($currentLocale === 'ar' ? 'جارٍ التحقق…' : 'Verifying…') : ($currentLocale === 'ar' ? 'فتح الجلسة' : 'Unlock session')}
					</button>
				</div>
			{:else}
				<div class="desktop-inactivity-actions">
					<button class="desktop-continue-btn" type="button" on:click={beginReauthentication}>{$currentLocale === 'ar' ? 'متابعة الجلسة' : 'Continue session'}</button>
					<button class="desktop-inactivity-logout-btn" type="button" on:click={logoutFromInactivityPrompt}>{$currentLocale === 'ar' ? 'تسجيل الخروج' : 'Log out'}</button>
				</div>
			{/if}
		</div>
	</dialog>
{/if}

<style>
	.desktop-inactivity-backdrop { position: fixed; inset: 0; width: 100vw; height: 100vh; max-width: none; max-height: none; margin: 0; box-sizing: border-box; border: 0; display: grid; place-items: center; padding: 1.25rem; background: rgba(4,22,39,.72); backdrop-filter: blur(10px); }
	.desktop-inactivity-backdrop::backdrop { background: rgba(4,22,39,.72); backdrop-filter: blur(10px); }
	.desktop-inactivity-dialog { width: min(100%,480px); padding: 2.2rem; box-sizing: border-box; border: 1px solid rgba(255,255,255,.8); border-radius: 24px; background: #fff; box-shadow: 0 28px 80px rgba(0,20,38,.35); text-align: center; }
	.desktop-inactivity-icon { display: grid; place-items: center; width: 62px; height: 62px; margin: 0 auto 1.1rem; border-radius: 18px; color: #087ca5; background: #e9f8fb; border: 1px solid #c4e9f0; }
	.desktop-inactivity-icon svg { width: 31px; height: 31px; }
	.desktop-inactivity-dialog h2 { margin: 0 0 .65rem; color: #102f49; font-size: 1.65rem; }
	.desktop-inactivity-dialog > p { margin: 0 auto 1.5rem; max-width: 390px; color: #60798b; line-height: 1.6; }
	.desktop-inactivity-actions { display: grid; grid-template-columns: 1fr 1fr; gap: .8rem; }
	.desktop-inactivity-actions button, .desktop-unlock-btn { min-height: 48px; padding: .8rem 1rem; border-radius: 12px; font-size: .95rem; font-weight: 750; cursor: pointer; }
	.desktop-continue-btn, .desktop-unlock-btn { border: 0; color: #fff; background: linear-gradient(115deg,#087ca5,#075b91); }
	.desktop-inactivity-logout-btn { border: 1px solid #d8e3e9; color: #40596c; background: #f7fafb; }
	.desktop-reauth-section { display: grid; gap: 1rem; }
	.desktop-reauth-label { color: #405c71; font-size: .85rem; font-weight: 700; }
	.desktop-reauth-digits { display: flex; justify-content: center; gap: .55rem; }
	.desktop-reauth-digits input { width: 50px; height: 58px; box-sizing: border-box; border: 1px solid #cbdce5; border-radius: 13px; background: #f8fbfc; text-align: center; font-size: 1.5rem; font-weight: 750; outline: none; }
	.desktop-reauth-digits input:focus { border-color: #0aa8c4; background: #fff; box-shadow: 0 0 0 4px rgba(10,168,196,.13); }
	.desktop-reauth-error { color: #b42318; font-size: .84rem; }
	.desktop-unlock-btn:disabled { opacity: .5; cursor: not-allowed; }
	@media (max-width: 560px) { .desktop-inactivity-dialog { padding: 1.5rem; } .desktop-inactivity-actions { grid-template-columns: 1fr; } .desktop-reauth-digits { gap: .35rem; } .desktop-reauth-digits input { width: 42px; height: 52px; } }

	:global(.desktop) {
		background: transparent !important;
	}
	
	.manage-favorites-star {
		background: rgba(255, 255, 255, 0.2);
		border: 2px solid rgba(255, 255, 255, 0.4);
		width: 32px;
		height: 32px;
		border-radius: 50%;
		font-size: 1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-top: 4px;
		margin-bottom: 8px;
		transition: all 0.2s ease;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.manage-favorites-star:hover {
		background: rgba(255, 255, 255, 0.35);
		transform: scale(1.1);
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.4);
	}

	.manage-favorites-star:active {
		transform: scale(0.95);
	}

	.manage-favorites-bar {
		display: none;
	}

	.manage-favorites-btn {
		display: none;
	}

	.favorites-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.3);
		z-index: 99;
	}

	.favorites-panel {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 480px;
		max-width: 90vw;
		max-height: 70vh;
		background: #fff;
		border-radius: 16px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
		z-index: 100;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.favorites-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px;
		background: linear-gradient(135deg, #15A34A, #22C55E);
		color: white;
	}

	.favorites-header h3 {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		width: 32px;
		height: 32px;
		border-radius: 8px;
		font-size: 1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;
	}

	.close-btn:hover {
		background: rgba(255, 255, 255, 0.35);
	}

	.favorites-list {
		overflow-y: auto;
		padding: 12px 16px;
		flex: 1;
	}

	.loading-msg, .empty-msg {
		text-align: center;
		padding: 2rem;
		color: #888;
		font-size: 0.95rem;
	}

	.section-group {
		margin-bottom: 12px;
	}

	.section-title {
		font-size: 0.8rem;
		font-weight: 700;
		text-transform: uppercase;
		color: #15A34A;
		padding: 6px 0;
		border-bottom: 1px solid #e5e7eb;
		margin-bottom: 4px;
		letter-spacing: 0.5px;
	}

	.subsection-title {
		margin: 8px 4px 3px 28px;
		color: #64748b;
		font-size: 0.68rem;
		font-weight: 700;
		letter-spacing: 0.45px;
		text-transform: uppercase;
	}

	.favorite-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 8px 8px;
		border-radius: 8px;
		cursor: pointer;
		transition: background 0.15s;
	}

	.favorite-item:hover {
		background: #f0fdf4;
	}

	.favorite-item input[type="checkbox"] {
		width: 18px;
		height: 18px;
		accent-color: #15A34A;
		cursor: pointer;
		flex-shrink: 0;
	}

	.btn-name {
		font-size: 0.9rem;
		color: #374151;
	}

	.btn-icon {
		font-size: 1rem;
		flex-shrink: 0;
		width: 20px;
		text-align: center;
	}

	.header-right {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.saving-indicator {
		font-size: 0.75rem;
		background: rgba(255, 255, 255, 0.25);
		padding: 4px 10px;
		border-radius: 12px;
		animation: pulse 1s ease-in-out infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	.desktop-content {
		position: fixed;
		left: var(--sidebar-width, 86px);
		right: 0;
		top: 0;
		bottom: 56px;
		padding: 0;
		margin: 0;
		z-index: 10;
	}

	.welcome-screen {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 0;
		margin: 0;
	}

	.welcome-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
		max-height: 95vh;
		padding: 64px 20px 20px;
	}

	.welcome-card {
		background: transparent;
		width: 0;
		max-width: none;
		height: 0;
		display: block;
		padding: 0;
		margin: 0;
		border: 0;
		box-shadow: none;
		overflow: visible;
		position: relative;
	}

	.welcome-meta-bar {
		position: fixed;
		top: 20px;
		right: 20px;
		z-index: 100;
		height: 44px;
		width: auto;
		min-width: 0;
		padding: 0;
		background: transparent;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		border: 0;
		border-radius: 0;
		box-shadow: none;
	}

	.welcome-meta-bar .update-badge,
	.welcome-meta-bar .version-badge {
		position: static;
	}

	.logo-section {
		text-align: center;
		padding: 0;
		background: transparent;
		color: #111827;
		position: relative;
		width: 0;
		height: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}

	.logo {
		position: fixed;
		right: 20px;
		bottom: 74px;
		z-index: 100;
		width: 200px;
		height: 120px;
		margin: 0;
		background: #F5FAFC;
		border: 6px solid #0798AE;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		box-shadow:
			0 0 8px rgba(7, 152, 174, 0.18),
			0 4px 12px rgba(3, 76, 140, 0.08);
		animation: logoContainerFadeOne 16s ease-in-out infinite;
		cursor: pointer;
		transition: transform 0.1s ease;
	}

	.logo:hover {
		transform: scale(1.02);
	}

	.aqura-brand-logo {
		position: fixed;
		right: 20px;
		bottom: 74px;
		z-index: 100;
		width: 200px;
		height: 120px;
		padding: 0;
		background: #F5FAFC;
		border: 6px solid #0798AE;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		box-shadow:
			0 0 8px rgba(7, 152, 174, 0.18),
			0 4px 12px rgba(3, 76, 140, 0.08);
		animation: logoContainerFadeTwo 16s ease-in-out infinite;
	}

	@keyframes logoContainerFadeOne {
		0%, 42% { opacity: 1; filter: blur(0); visibility: visible; }
		50%, 92% { opacity: 0; filter: blur(5px); visibility: hidden; }
		100% { opacity: 1; filter: blur(0); visibility: visible; }
	}

	@keyframes logoContainerFadeTwo {
		0%, 42% { opacity: 0; filter: blur(5px); visibility: hidden; }
		50%, 92% { opacity: 1; filter: blur(0); visibility: visible; }
		100% { opacity: 0; filter: blur(5px); visibility: hidden; }
	}

	@media (prefers-reduced-motion: reduce) {
		.logo,
		.aqura-brand-logo {
			animation: none;
			opacity: 1;
			filter: none;
		}

		.aqura-brand-logo {
			opacity: 0;
			visibility: hidden;
		}
	}

	.aqura-brand-logo-image {
		width: 100%;
		height: 100%;
		object-fit: contain;
	}

	@keyframes ledGlow {
		from {
			box-shadow: 
				0 0 25px rgba(16, 220, 229, 0.46),
				0 0 50px rgba(7, 159, 208, 0.26),
				inset 0 0 15px rgba(16, 220, 229, 0.14);
		}
		to {
			box-shadow: 
				0 0 40px rgba(16, 220, 229, 0.62),
				0 0 80px rgba(7, 159, 208, 0.34),
				inset 0 0 25px rgba(16, 220, 229, 0.20);
		}
	}

	.logo-image {
		width: 840px;
		height: 450px;
		border-radius: 12px;
		object-fit: contain;
		display: block;
		margin: 20px auto 0;
	}

	.app-title {
		font-size: 2.5rem;
		font-weight: 700;
		margin-bottom: 0.5rem;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.app-subtitle {
		font-size: 1.1rem;
		color: #0B2B50;
		opacity: 1;
		font-weight: 500;
		margin: 0;
	}

	.version-badge {
		position: absolute;
		top: 10px;
		right: 12px;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: 1px solid rgba(255, 255, 255, 0.35);
		border-radius: 12px;
		padding: 3px 10px;
		font-size: 0.7rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		z-index: 2;
		letter-spacing: 0.5px;
	}

	.version-badge:hover {
		background: rgba(255, 255, 255, 0.35);
	}

	.update-badge {
		position: absolute;
		top: 10px;
		left: 12px;
		border-radius: 12px;
		padding: 3px 10px;
		font-size: 0.7rem;
		font-weight: 600;
		transition: all 0.3s;
		z-index: 2;
		letter-spacing: 0.5px;
		border: none;
	}

	.update-badge.update-available {
		background: rgba(34, 197, 94, 0.25);
		color: #bbf7d0;
		border: 1px solid rgba(34, 197, 94, 0.5);
		cursor: pointer;
		animation: pulse-update 2s ease-in-out infinite;
	}

	.update-badge.update-available:hover {
		background: rgba(34, 197, 94, 0.45);
		transform: scale(1.05);
	}

	.update-badge.up-to-date {
		background: rgba(255, 255, 255, 0.15);
		color: rgba(255, 255, 255, 0.7);
		border: 1px solid rgba(255, 255, 255, 0.2);
		cursor: default;
	}

	/* Separate fixed-theme containers for update status and version. */
	.welcome-meta-bar .update-badge,
	.welcome-meta-bar .version-badge {
		position: static;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		height: 44px;
		min-width: 132px;
		padding: 0 14px;
		background: #F5FAFC;
		color: #0B2B50;
		border: 6px solid #0798AE;
		border-radius: 8px;
		box-shadow:
			0 0 8px rgba(7, 152, 174, 0.18),
			0 4px 12px rgba(3, 76, 140, 0.08);
		font-size: 0.72rem;
		font-weight: 700;
		letter-spacing: 0.2px;
	}

	.welcome-meta-bar .update-badge.update-available:hover,
	.welcome-meta-bar .version-badge:hover {
		background: #E8FBFD;
		color: #034C8C;
		border-color: #0798AE;
	}

	@keyframes pulse-update {
		0%, 100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.4); }
		50% { box-shadow: 0 0 8px 2px rgba(34, 197, 94, 0.3); }
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
			transform: translateY(20px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	/* Break QR Code - Centered above the welcome card */
	.qr-toggle-btn {
		position: absolute;
		bottom: 10px;
		right: 10px;
		background: rgba(255, 255, 255, 0.15);
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 50%;
		width: 36px;
		height: 36px;
		font-size: 1.1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
	}

	.qr-toggle-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.1);
	}

	.card-qr-row {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 12px;
	}

	.break-qr-popup {
		background: white;
		border-radius: 14px;
		padding: 0;
		box-shadow: 0 8px 30px rgba(0, 0, 0, 0.25);
		display: flex;
		flex-direction: column;
		align-items: center;
		z-index: 50;
		animation: qrPulse 10s ease-in-out infinite;
		overflow: hidden;
		align-self: center;
	}

	.qr-popup-header {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 10px;
		background: #f1f5f9;
		border-bottom: 1px solid #e2e8f0;
		box-sizing: border-box;
	}

	.qr-popup-title {
		font-size: 0.75rem;
		font-weight: 600;
		color: #475569;
	}

	.qr-popup-close {
		background: #e2e8f0;
		border: none;
		border-radius: 50%;
		width: 22px;
		height: 22px;
		font-size: 0.7rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #64748b;
		transition: background 0.2s;
		flex-shrink: 0;
	}

	.qr-popup-close:hover {
		background: #e2e8f0;
	}

	.break-qr-img {
		width: 150px;
		height: 150px;
		border-radius: 0 0 14px 14px;
		display: block;
	}

	.break-qr-label {
		display: flex;
		align-items: center;
		gap: 4px;
		font-size: 0.75rem;
		color: #475569;
		font-weight: 600;
		letter-spacing: 0.3px;
	}

	@keyframes qrPulse {
		0%, 100% { box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2); }
		50% { box-shadow: 0 4px 25px rgba(34, 197, 94, 0.35); }
	}

	/* Responsive design */
	@media (max-width: 768px) {
		.desktop-content {
			padding: 1rem;
		}

		.logo-section {
			padding: 2rem 1rem 1.5rem;
		}

		.app-title {
			font-size: 2rem;
		}
	}
</style>
