import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';
import { readFileSync } from 'fs';
import { resolve } from 'path';

interface ButtonInfo {
	code: string;
	name: string;
}

interface SectionStructure {
	name: string;
	subsections: {
		name: string;
		buttons: ButtonInfo[];
		buttonCount: number;
	}[];
	totalButtons: number;
}

function prettyButtonName(code: string): string {
	const specialNames: Record<string, string> = {
		E_R_P_CONNECTIONS: 'ERP Connections',
		API_KEYS_MANAGER: 'API Keys Manager',
		HR_SERVICES: 'HR Services',
		EMPLOYEE_MASTER: 'Employee Master',
		WA_AI_BOT: 'AI Reply',
		WA_AUTO_REPLY: 'WhatsApp Auto Reply',
		WA_LIVE_CHAT: 'WhatsApp Live Chat',
		WA_BROADCASTS: 'WhatsApp Broadcasts',
		WA_TEMPLATES: 'WhatsApp Templates',
		WA_CONTACTS: 'WhatsApp Contacts',
		WA_SETTINGS: 'WhatsApp Settings',
		WA_CATALOG: 'WhatsApp Catalog',
		WA_ACCOUNTS: 'WhatsApp Accounts',
		WA_DASHBOARD: 'WhatsApp Dashboard',
		LC_PLANNER: 'LC Planner',
		USER_ACTION_REPORTS: 'User Action Reports',
		ACTION_FOLLOW_UPS: 'Action Follow-Ups',
		PC_LOCK_GUARD: 'PC Lock Guard'
	};
	if (specialNames[code]) return specialNames[code];

	return code
		.toLowerCase()
		.split('_')
		.map((part) => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ');
}

// ─────────────────────────────────────────────────────────────────────────
// SOURCE OF TRUTH for the sidebar button catalog.
//
// This structure is the single place to register a new button. It must be
// kept in sync by hand with the `isButtonAllowed('CODE')` guards in
// Sidebar.svelte — add the button here (in the right SECTION/SUBSECTION),
// then gate it in Sidebar.svelte with the same code.
//
// Button Access Control reads this endpoint to build its permission-toggle
// list, so a code added here appears there automatically, in the right
// section, with no separate sync step.
// ─────────────────────────────────────────────────────────────────────────
const structure: Record<string, Record<string, string[]>> = {
	DELIVERY: {
		DASHBOARD: [],
		MANAGE: ['CUSTOMER_MASTER', 'AD_MANAGER', 'PRODUCTS_MANAGER', 'DELIVERY_MANAGE_PRODUCTS', 'DELIVERY_SETTINGS'],
		OPERATIONS: ['ORDERS_MANAGER', 'OFFER_MANAGEMENT'],
		REPORTS: []
	},
	VENDOR: {
		DASHBOARD: ['RECEIVING'],
		MANAGE: ['UPLOAD_VENDOR', 'CREATE_VENDOR', 'MANAGE_VENDOR', 'DEFAULT_POSITIONS'],
		OPERATIONS: ['START_RECEIVING', 'RECEIVING_RECORDS', 'ACTION_FOLLOW_UPS'],
		REPORTS: ['VENDOR_RECORDS']
	},
	MEDIA: {
		DASHBOARD: [], // FLYER_MASTER and PRODUCTS_DASHBOARD removed
		MANAGE: [
			'PRODUCT_MASTER',
			'VARIATION_MANAGER',
			'OFFER_MANAGER',
			'FLYER_TEMPLATES',
			'FLYER_SETTINGS',
			'NORMAL_PAPER_MANAGER',
			'ONE_DAY_OFFER_MANAGER',
			'SOCIAL_LINK_MANAGER',
			'SHELF_PAPER_TEMPLATE_DESIGNER'
		],
		OPERATIONS: [
			'OFFER_PRODUCT_EDITOR',
			'CREATE_NEW_OFFER',
			'PRICING_MANAGER',
			'ERP_ENTRY_MANAGER',
			'GENERATE_FLYERS',
			'SHELF_PAPER_MANAGER',
			'NEAR_EXPIRY_MANAGER'
		],
		REPORTS: []
	},
	PROMO: {
		DASHBOARD: ['COUPON_DASHBOARD_PROMO'],
		MANAGE: ['CAMPAIGN_MANAGER', 'GIFT_WHEEL_MANAGER', 'SURPRISE_BOX_MANAGER', 'VIP_CAMPAIGN'],
		OPERATIONS: ['VIEW_OFFER_MANAGER', 'CUSTOMER_IMPORTER', 'PRODUCT_MANAGER_PROMO'],
		REPORTS: ['COUPON_REPORTS']
	},
	FINANCE: {
		DASHBOARD: ['APPROVAL_CENTER', 'LC_PLANNER'],
		MANAGE: ['CATEGORY_MANAGER', 'PURCHASE_VOUCHER_MANAGER', 'MANAGE_RECONCILIATIONS', 'ASSET_MANAGER', 'LEASE_AND_RENT'],
		OPERATIONS: ['MANUAL_SCHEDULING', 'DAY_BUDGET_PLANNER', 'MONTHLY_MANAGER', 'EXPENSE_MANAGER', 'PAID_MANAGER', 'DENOMINATION', 'PETTY_CASH'],
		REPORTS: ['EXPENSE_TRACKER', 'SALES_REPORT', 'MONTHLY_BREAKDOWN', 'OVERDUES_REPORT', 'VENDOR_PAYMENTS', 'POS_REPORT']
	},
	HR: {
		DASHBOARD: ['SECURITY_CODE', 'FINGERPRINT_DASHBOARD', 'QUICK_DASHBOARD'],
		MANAGE: ['EMPLOYEE_MASTER', 'LINK_ID', 'HR_SERVICES'],
		OPERATIONS: ['EMPLOYEE_FILES', 'PROCESS_FINGERPRINT', 'SALARY_AND_WAGE', 'SHIFTS', 'SHIFT_AND_DAY_OFF', 'DISCIPLINE', 'INCIDENT_MANAGER', 'REPORT_INCIDENT', 'DAILY_CHECKLIST_MANAGER', 'BREAK_REGISTER'],
		REPORTS: ['FINGERPRINT_TRANSACTIONS', 'EXPORT_BIOMETRIC_DATA']
	},
	STOCK: {
		DASHBOARD: [],
		MANAGE: ['STOCK_PO_REQUESTS', 'STOCK_STOCK_REQUESTS', 'STOCK_BT_REQUESTS', 'STOCK_NEAR_EXPIRY_REQUESTS', 'STOCK_CUSTOMER_PRODUCT_REQUESTS', 'STOCK_OFFER_COST_MANAGER'],
		OPERATIONS: ['STOCK_PRODUCT_REQUEST', 'STOCK_ERP_PRODUCTS', 'STOCK_PRODUCT_CLAIM_MANAGER', 'STOCK_EXPIRY_CONTROL'],
		REPORTS: []
	},
	TASKS: {
		DASHBOARD: ['TASK_MASTER'],
		MANAGE: ['CREATE_TASK', 'VIEW_TASKS'],
		OPERATIONS: ['ASSIGN_TASKS', 'MY_DAILY_CHECKLIST'],
		REPORTS: ['VIEW_MY_TASKS', 'VIEW_MY_ASSIGNMENTS', 'TASK_STATUS', 'BRANCH_PERFORMANCE']
	},
	NOTIFICATIONS: {
		DASHBOARD: ['COMMUNICATION_CENTER'],
		MANAGE: [],
		OPERATIONS: ['CREATE_NOTIFICATION'],
		REPORTS: []
	},
	USERS: {
		DASHBOARD: ['USER_MANAGEMENT'],
		MANAGE: ['CREATE_USER', 'MANAGE_ADMIN_USERS', 'MANAGE_MASTER_ADMIN', 'INTERFACE_ACCESS_MANAGER', 'APPROVAL_PERMISSIONS'],
		OPERATIONS: [],
		REPORTS: []
	},
	LOYALTY: {
		DASHBOARD: ['LOYALTY_DASHBOARD', 'CUSTOMER_APP'],
		MANAGE: ['MANAGE_TIERS'],
		OPERATIONS: [],
		REPORTS: []
	},
	CONTROLS: {
		DASHBOARD: [],
		MANAGE: ['BRANCHES', 'SETTINGS', 'E_R_P_CONNECTIONS', 'CLEAR_TABLES', 'BUTTON_ACCESS_CONTROL', 'THEME_MANAGER', 'AI_CHAT_GUIDE', 'ERP_PRODUCT_MANAGER', 'STORAGE_MANAGER', 'ICON_MANAGER', 'API_KEYS_MANAGER', 'BRANDING', 'SUPABASE_SECRETS'],
		OPERATIONS: ['PUSH_NOTIFICATION_SETTINGS', 'LOCAL_UPDATE', 'HELPER_APPS', 'SIDEBAR_ANIMATION'],
		REPORTS: ['CENTRAL_PERFORMANCE', 'USER_ACTION_REPORTS', 'DRAWER_ACTION_MONITOR', 'PC_LOCK_GUARD']
	},
	WHATSAPP: {
		DASHBOARD: ['WA_DASHBOARD'],
		MANAGE: ['WA_ACCOUNTS', 'WA_TEMPLATES', 'WA_CONTACTS', 'WA_CATALOG', 'WA_SETTINGS'],
		OPERATIONS: ['WA_LIVE_CHAT', 'WA_BROADCASTS', 'WA_AUTO_REPLY', 'WA_AI_BOT'],
		REPORTS: []
	},
	EMAIL: {
		DASHBOARD: ['EMAIL_DASHBOARD'],
		MANAGE: ['EMAIL_ACCOUNTS', 'EMAIL_TEMPLATES', 'EMAIL_SIGNATURES', 'EMAIL_GROUPS', 'EMAIL_SETTINGS', 'EMAIL_AI_SETTINGS', 'EMAIL_SETUP_GUIDE'],
		OPERATIONS: ['EMAIL_CENTRE', 'EMAIL_COMPOSE', 'EMAIL_BROADCAST', 'EMAIL_QUEUE', 'EMAIL_SCHEDULED'],
		REPORTS: ['EMAIL_LOGS', 'EMAIL_DELIVERY_REPORTS', 'EMAIL_CAMPAIGN_REPORTS', 'EMAIL_FAILED']
	}
};

export const GET: RequestHandler = async () => {
	try {
		// Best-effort detection of codes actually gated in Sidebar.svelte, for
		// the missing/extra diagnostics below. Not fatal if unavailable
		// (e.g. certain serverless bundling setups).
		let detectedButtonCodes = new Set<string>();
		try {
			const sidebarPath = resolve('src/lib/components/desktop-interface/common/Sidebar.svelte');
			const sidebarCode = readFileSync(sidebarPath, 'utf-8');
			const buttonCodeRegex = /isButtonAllowed\(['"]([A-Z_]+)['"]\)/g;
			let match: RegExpExecArray | null;
			while ((match = buttonCodeRegex.exec(sidebarCode)) !== null) {
				detectedButtonCodes.add(match[1]);
			}
		} catch {
			// Source file not readable at runtime — skip diagnostics.
		}

		const sections: SectionStructure[] = [];
		const catalogCodes = new Set<string>();

		for (const [sectionCode, subsectionMap] of Object.entries(structure)) {
			const sectionName = sectionCode === 'WHATSAPP'
				? 'WhatsApp'
				: sectionCode === 'NOTIFICATIONS'
					? 'Outreach'
					: sectionCode.charAt(0) + sectionCode.slice(1).toLowerCase();
			const subsectionNames = ['DASHBOARD', 'MANAGE', 'OPERATIONS', 'REPORTS'];
			const subsections = subsectionNames.map((subCode) => {
				const codes = subsectionMap[subCode] || [];
				codes.forEach((code) => catalogCodes.add(code));
				const buttons = codes.map((code) => ({
					code,
					name: prettyButtonName(code)
				}));

				return {
					name: subCode.charAt(0) + subCode.slice(1).toLowerCase(),
					buttons,
					buttonCount: buttons.length
				};
			});

			sections.push({
				name: sectionName,
				subsections,
				totalButtons: subsections.reduce((sum, sub) => sum + sub.buttonCount, 0)
			});
		}

		const missingFromCatalog = detectedButtonCodes.size
			? Array.from(detectedButtonCodes).filter((code) => !catalogCodes.has(code)).sort()
			: [];
		const extraInCatalog = detectedButtonCodes.size
			? Array.from(catalogCodes).filter((code) => !detectedButtonCodes.has(code)).sort()
			: [];

		return json({
			success: true,
			sections,
			totalSections: sections.length,
			totalButtons: sections.reduce((sum, section) => sum + section.totalButtons, 0),
			catalogButtonCodes: Array.from(catalogCodes).sort(),
			detectedButtonCodes: Array.from(detectedButtonCodes).sort(),
			missingFromCatalog,
			extraInCatalog
		});
	} catch (error) {
		console.error('Error building sidebar button catalog:', error);
		return json(
			{
				error: 'Failed to build sidebar button catalog',
				details: error instanceof Error ? error.message : 'Unknown error'
			},
			{ status: 500 }
		);
	}
};
