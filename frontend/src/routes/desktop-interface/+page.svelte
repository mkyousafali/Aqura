<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { localeData, t, currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
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
		'BANK_RECONCILIATION': '🏦', 'MANUAL_SCHEDULING': '📅', 'DAY_BUDGET_PLANNER': '📊',
		'MONTHLY_MANAGER': '📅', 'EXPENSE_MANAGER': '💸', 'PAID_MANAGER': '💳',
		'DENOMINATION': '💵', 'PETTY_CASH': '💰', 'EXPENSE_TRACKER': '💰',
		'SALES_REPORT': '📊', 'MONTHLY_BREAKDOWN': '📅', 'OVERDUES_REPORT': '⏰',
		'VENDOR_PAYMENTS': '💳', 'POS_REPORT': '🏪', 'CREATE_DEPARTMENT': '🏢',
		'CREATE_LEVEL': '📊', 'CREATE_POSITION': '💼', 'REPORTING_MAP': '📈',
		'ASSIGN_POSITIONS': '🎯', 'LINK_ID': '🔗', 'EMPLOYEE_FILES': '📁',
		'PROCESS_FINGERPRINT': '📂', 'SALARY_AND_WAGE': '💰', 'SHIFT_AND_DAY_OFF': '⌚',
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
		'CLEAR_TABLES': '🗑️', 'BUTTON_ACCESS_CONTROL': '🎛️', 'BUTTON_GENERATOR': '🔨', 'THEME_MANAGER': '🎨',
		'LEAVES_AND_VACATIONS': '🏖️', 'LEAVE_REQUEST': '📋',
		'ERP_PRODUCT_MANAGER': '🏭',
		// Additional DB button codes
		'UPLOAD_EMPLOYEES': '📤', 'WARNING_MASTER': '⚠️', 'SALARY_WAGE_MANAGEMENT': '💰',
		'CONTACT_MANAGEMENT': '📇', 'DOCUMENT_MANAGEMENT': '📑', 'BIOMETRIC_DATA': '👆',
		'BRANCH_MASTER': '🏢', 'SOUND_SETTINGS': '🔊', 'CATEGORY_MANAGER': '📂', 'ASSET_MANAGER': '🏗️',
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
		'STOCK_PRODUCT_CLAIM_MANAGER': '👤'
	};

	let mounted = false;
	let permittedButtons: Array<{ id: string; button_code: string; button_name_en: string; section_name: string; checked: boolean }> = [];
	let loadingButtons = false;
	let savingFavorites = false;
	let saveDebounceTimer: ReturnType<typeof setTimeout> | null = null;
	let logoClickCount = 0;
	let logoClickTimeout: ReturnType<typeof setTimeout> | null = null;

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
		'BANK_RECONCILIATION': 'nav.bankReconciliation',
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
		'EMPLOYEE_FILES': 'nav.employeeFiles',
		'PROCESS_FINGERPRINT': 'nav.processFingerprint',
		'SALARY_AND_WAGE': 'nav.salaryAndWage',
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
		'BUTTON_GENERATOR': 'nav.buttonGenerator',
		'AI_CHAT_GUIDE': 'nav.aiChatGuide',
		'THEME_MANAGER': 'nav.themeManager',
		'LEAVES_AND_VACATIONS': 'nav.leavesAndVacations',
		'LEAVE_REQUEST': 'nav.leaveRequest',
		'ERP_PRODUCT_MANAGER': 'nav.erpProductManager',
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
		'STOCK_PRODUCT_CLAIM_MANAGER': 'nav.productClaimManager'
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

	onMount(async () => {
		mounted = true;
		
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

	// Reload favorites when user changes
	$: if ($currentUser && mounted) {
		favoritesStore.load($currentUser.id, $currentUser.employee_id || null);
	}

	// Load buttons when favorites panel opens
	$: if ($favoritesPanelOpen && permittedButtons.length === 0) {
		loadPermittedButtons();
	}

	async function toggleFavoritesPanel() {
		const isOpen = !$favoritesPanelOpen;
		favoritesPanelOpen.set(isOpen);
		if (isOpen && permittedButtons.length === 0) {
			await loadPermittedButtons();
		}
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
			let buttonIds: string[] = [];

			if ($currentUser.isMasterAdmin) {
				// Master admin gets all buttons
				const { data: allButtons } = await supabase
					.from('sidebar_buttons')
					.select('id');
				buttonIds = allButtons?.map(b => b.id) || [];
			} else {
				// Regular user: get enabled permissions
				const { data: permissions } = await supabase
					.from('button_permissions')
					.select('button_id')
					.eq('user_id', $currentUser.id)
					.eq('is_enabled', true);
				buttonIds = permissions?.map(p => p.button_id) || [];
			}

			if (buttonIds.length > 0) {
				const { data: buttons } = await supabase
					.from('sidebar_buttons')
					.select('id, button_code, button_name_en, main_section_id')
					.in('id', buttonIds);

				// Get section names
				const sectionIds = [...new Set(buttons?.map(b => b.main_section_id).filter(Boolean) || [])];
				let sectionMap: Record<string, string> = {};
				if (sectionIds.length > 0) {
					const { data: sections } = await supabase
						.from('button_main_sections')
						.select('id, section_name_en')
						.in('id', sectionIds);
					sectionMap = Object.fromEntries(sections?.map(s => [s.id, s.section_name_en]) || []);
				}

				// Pre-check buttons that are already favorites
				const favCodes = $favoriteButtonCodes;

				permittedButtons = (buttons || []).map(b => ({
					id: b.id,
					button_code: b.button_code,
					button_name_en: b.button_name_en,
					section_name: sectionMap[b.main_section_id] || 'Other',
					checked: favCodes.has(b.button_code)
				})).sort((a, b) => a.section_name.localeCompare(b.section_name) || a.button_name_en.localeCompare(b.button_name_en));
			}
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
							if (!acc[btn.section_name]) acc[btn.section_name] = [];
							acc[btn.section_name].push(btn);
							return acc;
						}, {} as Record<string, typeof permittedButtons>)}
						{#each Object.entries(groupedButtons) as [section, buttons]}
							<div class="section-group">
								<div class="section-title">{getSectionLabel(section)}</div>
								{#each buttons as btn}
									<label class="favorite-item">
									<input type="checkbox" bind:checked={btn.checked} on:change={onFavoriteToggle} />
									<span class="btn-icon">{buttonIconMap[btn.button_code] || '📌'}</span>
										<span class="btn-name">{getButtonLabel(btn.button_code, btn.button_name_en)}</span>
									</label>
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
				<div class="welcome-card">
					<div class="logo-section">
						{#if $updateAvailable}
							<button class="update-badge update-available" on:click={handleUpdateClick} title={$currentLocale === 'ar' ? 'تحديث متاح - انقر للتحديث' : 'Update Available - Click to update'}>
								🔄 {$currentLocale === 'ar' ? 'تحديث متاح' : 'Update Available'}
							</button>
						{:else}
							<span class="update-badge up-to-date">
								✅ {$currentLocale === 'ar' ? 'محدّث' : 'Up to Date'}
							</span>
						{/if}
						<button class="version-badge" on:click={showVersionInfo} title="Version Changelog">AQ48.22.14.15</button>
						<div class="logo" on:click={handleLogoClick} role="button" tabindex="0" on:keydown={(e) => e.key === 'Enter' && handleLogoClick()}>
							<img src="/icons/Aqura logo.png" alt="Aqura Logo" class="logo-image" />
						</div>
						<p class="app-subtitle">{$localeData ? t('app.description') : 'AI-powered management system'}</p>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	:global(.desktop) {
		background: transparent !important;
	}
	
	:global(.app::before) {
		display: none !important;
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
		align-items: center;
		justify-content: center;
		padding: 0;
		margin: 0;
	}

	.welcome-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
		max-height: 95%;
		overflow-y: auto;
	}

	.welcome-card {
		background: #FFFFFF;
		width: 600px;
		max-width: 90%;
		height: auto;
		display: block;
		padding: 0;
		margin: 0;
		border-radius: 24px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1);
		overflow: hidden;
	}

	.logo-section {
		text-align: center;
		padding: 3rem 2rem 2rem;
		background: var(--theme-logo-bar-bg, linear-gradient(135deg, #15A34A 0%, #22C55E 100%));
		color: var(--theme-logo-bar-text, white);
		position: relative;
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}

	.logo {
		width: 200px;
		height: 120px;
		margin: 0 auto 1.5rem;
		background: #FFFFFF;
		border: 6px solid var(--theme-logo-border, #F59E0B);
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		box-shadow: 
			0 0 25px rgba(245, 158, 11, 0.5),
			0 0 50px rgba(245, 158, 11, 0.3),
			inset 0 0 15px rgba(245, 158, 11, 0.15);
		animation: ledGlow 2s ease-in-out infinite alternate;
		cursor: pointer;
		transition: transform 0.1s ease;
	}

	.logo:hover {
		transform: scale(1.02);
	}

	@keyframes ledGlow {
		from {
			box-shadow: 
				0 0 25px rgba(245, 158, 11, 0.5),
				0 0 50px rgba(245, 158, 11, 0.3),
				inset 0 0 15px rgba(245, 158, 11, 0.15);
		}
		to {
			box-shadow: 
				0 0 40px rgba(245, 158, 11, 0.7),
				0 0 80px rgba(245, 158, 11, 0.4),
				inset 0 0 25px rgba(245, 158, 11, 0.25);
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
		opacity: 0.9;
		font-weight: 300;
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
