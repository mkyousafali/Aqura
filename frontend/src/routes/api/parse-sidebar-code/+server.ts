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
		WA_AI_BOT: 'WhatsApp AI Bot',
		WA_AUTO_REPLY: 'WhatsApp Auto Reply',
		WA_LIVE_CHAT: 'WhatsApp Live Chat',
		WA_BROADCASTS: 'WhatsApp Broadcasts',
		WA_TEMPLATES: 'WhatsApp Templates',
		WA_CONTACTS: 'WhatsApp Contacts',
		WA_SETTINGS: 'WhatsApp Settings',
		WA_CATALOG: 'WhatsApp Catalog',
		WA_ACCOUNTS: 'WhatsApp Accounts',
		WA_DASHBOARD: 'WhatsApp Dashboard'
	};
	if (specialNames[code]) return specialNames[code];

	return code
		.toLowerCase()
		.split('_')
		.map((part) => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ');
}

export const GET: RequestHandler = async () => {
	try {
		const sidebarPath = resolve('src/lib/components/desktop-interface/common/Sidebar.svelte');
		const sidebarCode = readFileSync(sidebarPath, 'utf-8');

		const buttonCodeRegex = /isButtonAllowed\(['"]([A-Z_]+)['"]\)/g;
		const detectedButtonCodes = new Set<string>();
		let match: RegExpExecArray | null;
		while ((match = buttonCodeRegex.exec(sidebarCode)) !== null) {
			detectedButtonCodes.add(match[1]);
		}

		// Hardcoded canonical sidebar structure (kept explicit by request)
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
				OPERATIONS: ['START_RECEIVING', 'RECEIVING_RECORDS'],
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
				DASHBOARD: ['APPROVAL_CENTER'],
				MANAGE: ['CATEGORY_MANAGER', 'PURCHASE_VOUCHER_MANAGER', 'BANK_RECONCILIATION', 'MANAGE_RECONCILIATIONS', 'ASSET_MANAGER', 'LEASE_AND_RENT'],
				OPERATIONS: ['MANUAL_SCHEDULING', 'DAY_BUDGET_PLANNER', 'MONTHLY_MANAGER', 'EXPENSE_MANAGER', 'PAID_MANAGER', 'DENOMINATION', 'PETTY_CASH'],
				REPORTS: ['EXPENSE_TRACKER', 'SALES_REPORT', 'MONTHLY_BREAKDOWN', 'OVERDUES_REPORT', 'VENDOR_PAYMENTS', 'POS_REPORT']
			},
			HR: {
				DASHBOARD: ['SECURITY_CODE'],
				MANAGE: ['EMPLOYEE_MASTER', 'LINK_ID', 'HR_SERVICES'],
				OPERATIONS: ['EMPLOYEE_FILES', 'PROCESS_FINGERPRINT', 'SALARY_AND_WAGE', 'SHIFT_AND_DAY_OFF', 'DISCIPLINE', 'INCIDENT_MANAGER', 'REPORT_INCIDENT', 'DAILY_CHECKLIST_MANAGER', 'BREAK_REGISTER'],
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
				MANAGE: ['BRANCHES', 'SETTINGS', 'E_R_P_CONNECTIONS', 'CLEAR_TABLES', 'BUTTON_ACCESS_CONTROL', 'BUTTON_GENERATOR', 'THEME_MANAGER', 'AI_CHAT_GUIDE', 'ERP_PRODUCT_MANAGER', 'STORAGE_MANAGER', 'ICON_MANAGER', 'API_KEYS_MANAGER'],
				OPERATIONS: ['PUSH_NOTIFICATION_SETTINGS', 'LOCAL_UPDATE'],
				REPORTS: ['CENTRAL_PERFORMANCE']
			},
			WHATSAPP: {
				DASHBOARD: ['WA_DASHBOARD'],
				MANAGE: ['WA_ACCOUNTS', 'WA_TEMPLATES', 'WA_CONTACTS', 'WA_CATALOG', 'WA_SETTINGS'],
				OPERATIONS: ['WA_LIVE_CHAT', 'WA_BROADCASTS', 'WA_AUTO_REPLY', 'WA_AI_BOT'],
				REPORTS: []
			}
		};

		const sections: SectionStructure[] = [];
		const hardcodedCodes = new Set<string>();

		for (const [sectionCode, subsectionMap] of Object.entries(structure)) {
			const sectionName = sectionCode === 'WHATSAPP'
				? 'WhatsApp'
				: sectionCode === 'NOTIFICATIONS'
					? 'Outreach'
					: sectionCode.charAt(0) + sectionCode.slice(1).toLowerCase();
			const subsectionNames = ['DASHBOARD', 'MANAGE', 'OPERATIONS', 'REPORTS'];
			const subsections = subsectionNames.map((subCode) => {
				const codes = subsectionMap[subCode] || [];
				codes.forEach((code) => hardcodedCodes.add(code));
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

		const missingFromHardcoded = Array.from(detectedButtonCodes).filter((code) => !hardcodedCodes.has(code)).sort();
		const extraInHardcoded = Array.from(hardcodedCodes).filter((code) => !detectedButtonCodes.has(code)).sort();

		return json({
			success: true,
			sections,
			totalSections: sections.length,
			totalButtons: sections.reduce((sum, section) => sum + section.totalButtons, 0),
			detectedButtonCodes: Array.from(detectedButtonCodes).sort(),
			hardcodedButtonCodes: Array.from(hardcodedCodes).sort(),
			missingFromHardcoded,
			extraInHardcoded
		});
	} catch (error) {
		console.error('Error parsing sidebar:', error);
		return json(
			{
				error: 'Failed to parse sidebar',
				details: error instanceof Error ? error.message : 'Unknown error'
			},
			{ status: 500 }
		);
	}
};
