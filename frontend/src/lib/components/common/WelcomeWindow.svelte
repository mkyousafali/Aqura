<script lang="ts">
	import { t } from '$lib/i18n';
	import { iconUrlMap } from '$lib/stores/iconStore';
	// Welcome window component
</script>

<div class="h-full bg-gradient-to-br from-slate-50 via-white to-slate-100 overflow-y-auto">
	<!-- Header Section - Sticky with proper clipping -->
	<div class="sticky top-0 z-50 bg-white border-b-2 border-slate-300 shadow-lg py-6 px-8" style="position: sticky; top: 0; clip-path: polygon(0 0, 100% 0, 100% 101%, 0 101%); margin-top: -8px; padding-top: 2rem;">
		<div class="text-center">
			<img src={$iconUrlMap['aqura-logo'] || '/icons/Aqura logo.png'} alt="Aqura Logo" class="w-32 h-32 mx-auto mb-6 object-contain drop-shadow-lg" />
			<h1 class="text-4xl font-bold text-slate-900 mb-3">{t('welcome.title') || 'Welcome to Aqura'}</h1>
			<p class="text-lg text-slate-600 font-medium">{t('welcome.subtitle') || 'Advanced Business Management Platform'}</p>
			<div class="flex gap-2 justify-center mt-4">
				<div class="h-1 w-12 bg-gradient-to-r from-blue-500 to-blue-600 rounded-full"></div>
				<div class="h-1 w-12 bg-gradient-to-r from-indigo-500 to-indigo-600 rounded-full"></div>
				<div class="h-1 w-12 bg-gradient-to-r from-purple-500 to-purple-600 rounded-full"></div>
			</div>
		</div>
	</div>
	
	<!-- Content starts with proper spacing -->
	<div class="p-8">

	<!-- Core Features - Premium Card -->
	<div class="mb-6 bg-gradient-to-br from-blue-50 to-indigo-50 rounded-xl border border-blue-200 shadow-md p-6">
		<h3 class="text-sm font-bold text-blue-900 mb-5 uppercase tracking-widest flex items-center gap-3">
			<span class="text-2xl">✨</span> 
			{t('welcome.coreFeatures') || 'Core Features'}
		</h3>
		<div class="space-y-3">
			<div class="flex items-start gap-3">
				<span class="text-green-500 font-bold text-lg mt-0.5 leading-none">✓</span>
				<span class="text-sm text-slate-800 leading-snug">{t('welcome.features.multiWindow') || 'Multi-window interface for enhanced productivity'}</span>
			</div>
			<div class="flex items-start gap-3">
				<span class="text-green-500 font-bold text-lg mt-0.5 leading-none">✓</span>
				<span class="text-sm text-slate-800 leading-snug">{t('welcome.features.responsive') || 'Responsive design for all devices'}</span>
			</div>
			<div class="flex items-start gap-3">
				<span class="text-green-500 font-bold text-lg mt-0.5 leading-none">✓</span>
				<span class="text-sm text-slate-800 leading-snug">{t('welcome.features.bilingual') || 'Full bilingual support (English & Arabic)'}</span>
			</div>
			<div class="flex items-start gap-3">
				<span class="text-emerald-500 font-bold text-lg mt-0.5 leading-none">✓</span>
				<span class="text-sm text-slate-800 leading-snug">{t('welcome.features.permissions') || 'Advanced role-based access control'}</span>
			</div>
			<div class="flex items-start gap-3">
				<span class="text-emerald-500 font-bold text-lg mt-0.5 leading-none">✓</span>
				<span class="text-sm text-slate-800 leading-snug">{t('welcome.features.aiIntegration') || 'AI-powered chat assistant and automation'}</span>
			</div>
		</div>
	</div>

	<!-- Business Modules Grid -->
	<div class="grid gap-4">
		<!-- Delivery -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">🚚</span>
				{t('welcome.delivery') || 'Delivery & Customer Management'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.deliveryItems.customerMaster') || 'Customer Master'}</div>
				<div>• {t('welcome.deliveryItems.adManager') || 'Ad Manager'} • {t('welcome.deliveryItems.productsManager') || 'Products Manager'}</div>
				<div>• {t('welcome.deliveryItems.ordersManager') || 'Orders Manager'}</div>
			</div>
		</div>

		<!-- Vendor -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">📦</span>
				{t('welcome.vendor') || 'Vendor Management'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.vendorItems.receiving') || 'Receiving & Stock In'} • {t('welcome.vendorItems.upload') || 'Upload Vendors'}</div>
				<div>• {t('welcome.vendorItems.manage') || 'Manage Vendors'} • {t('welcome.vendorItems.positions') || 'Default Positions'}</div>
				<div>• {t('welcome.vendorItems.reports') || 'Vendor Reports & Records'}</div>
			</div>
		</div>

		<!-- Marketing -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">🎨</span>
				{t('welcome.marketing') || 'Marketing & Promotions'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.marketingItems.flyers') || 'Flyer Management & Design'} • {t('welcome.marketingItems.coupons') || 'Coupons & Campaigns'}</div>
				<div>• {t('welcome.marketingItems.offers') || 'Offers & Promotions'} • {t('welcome.marketingItems.pricing') || 'Pricing Manager'}</div>
				<div>• {t('welcome.marketingItems.catalog') || 'Product Catalog & Variations'}</div>
			</div>
		</div>

		<!-- Finance -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">💰</span>
				{t('welcome.finance') || 'Finance & Accounting'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.financeItems.approvals') || 'Approval Center & Requisitions'} • {t('welcome.financeItems.categories') || 'Expense Categories'}</div>
				<div>• {t('welcome.financeItems.budgeting') || 'Budget Planning & Day Budgets'} • {t('welcome.financeItems.scheduling') || 'Manual Payment Scheduling'}</div>
				<div>• {t('welcome.financeItems.payments') || 'Paid Invoices & Payments'} • {t('welcome.financeItems.pettyCash') || 'Petty Cash Management'}</div>
				<div>• {t('welcome.financeItems.reconciliation') || 'Bank Reconciliation'} • {t('welcome.financeItems.assets') || 'Asset Management'}</div>
				<div>• {t('welcome.financeItems.leases') || 'Lease & Rental Management'}</div>
			</div>
		</div>

		<!-- HR -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">👥</span>
				{t('welcome.hr') || 'Human Resources'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.hrItems.employees') || 'Employee Management & Departments'} • {t('welcome.hrItems.positions') || 'Positions & Assignments'}</div>
				<div>• {t('welcome.hrItems.shifts') || 'Shifts & Day-Off Management'} • {t('welcome.hrItems.salary') || 'Salary & Wage Management'}</div>
				<div>• {t('welcome.hrItems.discipline') || 'Discipline & Incidents'} • {t('welcome.hrItems.incidents') || 'Incident Reporting'}</div>
				<div>• {t('welcome.hrItems.checklists') || 'Daily Checklists'} • {t('welcome.hrItems.breaks') || 'Break Register'}</div>
				<div>• {t('welcome.hrItems.biometrics') || 'Biometric & Fingerprint Integration'}</div>
			</div>
		</div>

		<!-- Stock -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">📦</span>
				{t('welcome.stock') || 'Stock & Inventory'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.stockItems.requests') || 'Product & Stock Requests'} • {t('welcome.stockItems.transfers') || 'Branch Transfers'}</div>
				<div>• {t('welcome.stockItems.purchaseOrders') || 'Purchase Orders (PO)'} • {t('welcome.stockItems.erpProducts') || 'ERP Products'}</div>
				<div>• {t('welcome.stockItems.expiry') || 'Expiry Control & Near-Expiry Reports'} • {t('welcome.stockItems.claims') || 'Product Claims & Cost Management'}</div>
			</div>
		</div>

		<!-- Tasks -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">📋</span>
				{t('welcome.tasks') || 'Tasks & Assignments'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.tasksItems.createTasks') || 'Create Task Templates'} • {t('welcome.tasksItems.assignTasks') || 'Assign to Employees'}</div>
				<div>• {t('welcome.tasksItems.myTasks') || 'My Tasks & Assignments'} • {t('welcome.tasksItems.status') || 'Task Status & Tracking'}</div>
				<div>• {t('welcome.tasksItems.branchPerformance') || 'Branch Performance Dashboard'}</div>
			</div>
		</div>

		<!-- WhatsApp -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">💬</span>
				{t('welcome.whatsapp') || 'WhatsApp Integration'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.whatsappItems.liveChat') || 'Live Chat Management'} • {t('welcome.whatsappItems.broadcasts') || 'Bulk Broadcasts'}</div>
				<div>• {t('welcome.whatsappItems.templates') || 'Message Templates'} • {t('welcome.whatsappItems.contacts') || 'Contact Management'}</div>
				<div>• {t('welcome.whatsappItems.autoReply') || 'Auto-Reply Bot'} • {t('welcome.whatsappItems.aiBot') || 'AI-Powered Bot'}</div>
				<div>• {t('welcome.whatsappItems.catalog') || 'Product Catalog'} • {t('welcome.whatsappItems.accounts') || 'Multiple Account Management'}</div>
			</div>
		</div>

		<!-- Communications -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">🔔</span>
				{t('welcome.communications') || 'Communications & Notifications'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.commItems.communicationCenter') || 'Communication Center'} • {t('welcome.commItems.createNotifications') || 'Create Notifications'}</div>
				<div>• {t('welcome.commItems.pushNotifications') || 'Push Notifications'} • {t('welcome.commItems.announcements') || 'Announcements'}</div>
			</div>
		</div>

		<!-- AI Agent -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">🤖</span>
				{t('welcome.aiAgent') || 'AI Agent & Automation'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.aiAgentItems.chatAssistant') || 'AI Chat Assistant'} • {t('welcome.aiAgentItems.knowledge') || 'Knowledge Base Integration'}</div>
				<div>• {t('welcome.aiAgentItems.automation') || 'Intelligent Automation'} • {t('welcome.aiAgentItems.search') || 'Smart Search & Suggestions'}</div>
				<div>• {t('welcome.aiAgentItems.analytics') || 'AI-Powered Analytics'} • {t('welcome.aiAgentItems.recommendations') || 'Smart Recommendations'}</div>
			</div>
		</div>

		<!-- Admin -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">⚙️</span>
				{t('welcome.admin') || 'Administration & Settings'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.adminItems.userManagement') || 'User Management & Roles'} • {t('welcome.adminItems.masterAdmin') || 'Master Admin Panel'}</div>
				<div>• {t('welcome.adminItems.permissions') || 'Approval Permissions'} • {t('welcome.adminItems.buttonAccessControl') || 'Button Access Control'}</div>
				<div>• {t('welcome.adminItems.storage') || 'Storage Manager'} • {t('welcome.adminItems.apiKeys') || 'API Keys Management'}</div>
				<div>• {t('welcome.adminItems.theme') || 'Theme Manager'} • {t('welcome.adminItems.iconManager') || 'Icon Manager'}</div>
				<div>• {t('welcome.adminItems.buttonGenerator') || 'Button Generator'} • {t('welcome.adminItems.aiGuide') || 'AI Chat Guide'}</div>
				<div>• {t('welcome.adminItems.erpConnections') || 'ERP Connections & Product Sync'} • {t('welcome.adminItems.clearTables') || 'Data Management'}</div>
			</div>
		</div>

		<!-- Mobile App -->
		<div class="bg-white rounded-lg border border-slate-200 shadow-sm hover:shadow-md transition p-5">
			<h3 class="text-xs font-bold text-slate-900 mb-4 uppercase tracking-wide flex items-center gap-2">
				<span class="text-lg">📱</span>
				{t('welcome.mobileApp') || 'Mobile Employee App'}
			</h3>
			<div class="text-sm text-slate-700 space-y-1.5 ml-6">
				<div>• {t('welcome.mobileItems.tasks') || 'Task Management'} • {t('welcome.mobileItems.approvals') || 'Approvals & Requisitions'}</div>
				<div>• {t('welcome.mobileItems.attendance') || 'Attendance & Leave Requests'} • {t('welcome.mobileItems.pricing') || 'Price Checker'}</div>
				<div>• {t('welcome.mobileItems.inventory') || 'Inventory & Stock Lookup'} • {t('welcome.mobileItems.incidents') || 'Incident Reporting'}</div>
				<div>• {t('welcome.mobileItems.aiChat') || 'AI Chat Assistant'}</div>
			</div>
		</div>
	</div>

	<!-- Footer -->
	<div class="mt-8 pt-6 border-t border-slate-200 text-center">
		<p class="text-sm text-slate-600 leading-relaxed">
			{t('welcome.instructions') || 'All modules are fully functional with complete English & Arabic support. Permissions are managed per user role.'}
		</p>
	</div>
	</div>
</div>

<style>
	::-webkit-scrollbar {
		width: 6px;
	}
	::-webkit-scrollbar-track {
		background: rgba(226, 232, 240, 0.3);
		border-radius: 10px;
	}
	::-webkit-scrollbar-thumb {
		background: rgba(100, 116, 139, 0.4);
		border-radius: 10px;
	}
	::-webkit-scrollbar-thumb:hover {
		background: rgba(71, 85, 105, 0.6);
	}
	
	/* Ensure sticky header clips content properly */
	:global(.sticky) {
		position: sticky;
		min-height: auto;
	}
</style>
