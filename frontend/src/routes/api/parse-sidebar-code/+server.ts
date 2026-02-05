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

export const GET: RequestHandler = async () => {
	try {
		// Read the Sidebar.svelte component
		const sidebarPath = resolve('src/lib/components/desktop-interface/common/Sidebar.svelte');
		const sidebarCode = readFileSync(sidebarPath, 'utf-8');

		// Extract all button codes from isButtonAllowed() calls
		const buttonCodeRegex = /isButtonAllowed\(['"]([A-Z_]+)['"]\)/g;
		const allButtonCodes = new Set<string>();

		let match;
		while ((match = buttonCodeRegex.exec(sidebarCode)) !== null) {
			allButtonCodes.add(match[1]);
		}

		// Extract button names from onclick handlers and menu-text spans
		const sections: Record<string, SectionStructure> = {};

		// Define the structure based on sidebar analysis
		const structure = {
			DELIVERY: {
				DASHBOARD: [],
				MANAGE: ['CUSTOMER_MASTER', 'AD_MANAGER', 'PRODUCTS_MANAGER', 'DELIVERY_SETTINGS'],
				OPERATIONS: ['ORDERS_MANAGER', 'OFFER_MANAGEMENT'],
				REPORTS: []
			},
			VENDOR: {
				DASHBOARD: ['RECEIVING'],
				MANAGE: ['UPLOAD_VENDOR', 'CREATE_VENDOR', 'MANAGE_VENDOR'],
				OPERATIONS: ['START_RECEIVING', 'RECEIVING_RECORDS'],
				REPORTS: ['VENDOR_RECORDS']
			},
			MEDIA: {
				DASHBOARD: ['FLYER_MASTER'],
				MANAGE: ['PRODUCT_MASTER', 'VARIATION_MANAGER', 'OFFER_MANAGER', 'FLYER_TEMPLATES', 'FLYER_SETTINGS', 'SOCIAL_LINK_MANAGER'],
				OPERATIONS: ['OFFER_PRODUCT_EDITOR', 'CREATE_NEW_OFFER', 'PRICING_MANAGER', 'ERP_ENTRY_MANAGER', 'GENERATE_FLYERS', 'SHELF_PAPER_MANAGER'],
				REPORTS: []
			},
			PROMO: {
				DASHBOARD: ['COUPON_DASHBOARD_PROMO'],
				MANAGE: ['CAMPAIGN_MANAGER'],
				OPERATIONS: ['VIEW_OFFER_MANAGER', 'CUSTOMER_IMPORTER', 'PRODUCT_MANAGER_PROMO'],
				REPORTS: ['COUPON_REPORTS']
			},
			FINANCE: {
				DASHBOARD: ['APPROVAL_CENTER'],
				MANAGE: ['CATEGORY_MANAGER', 'PURCHASE_VOUCHER_MANAGER', 'BANK_RECONCILIATION'],
				OPERATIONS: ['MANUAL_SCHEDULING', 'DAY_BUDGET_PLANNER', 'MONTHLY_MANAGER', 'EXPENSE_MANAGER', 'PAID_MANAGER', 'DENOMINATION', 'PETTY_CASH'],
				REPORTS: ['EXPENSE_TRACKER', 'SALES_REPORT', 'MONTHLY_BREAKDOWN', 'OVERDUES_REPORT', 'VENDOR_PAYMENTS', 'POS_REPORT']
			},
			HR: {
				DASHBOARD: [],
				MANAGE: ['UPLOAD_EMPLOYEES', 'CREATE_DEPARTMENT', 'CREATE_LEVEL', 'CREATE_POSITION', 'REPORTING_MAP', 'ASSIGN_POSITIONS', 'CONTACT_MANAGEMENT', 'DOCUMENT_MANAGEMENT', 'SALARY_WAGE_MANAGEMENT', 'WARNING_MASTER', 'LINK_ID'],
				OPERATIONS: ['EMPLOYEE_FILES', 'FINGERPRINT_TRANSACTIONS', 'PROCESS_FINGERPRINT', 'SALARY_AND_WAGE', 'SHIFT_AND_DAY_OFF', 'LEAVES_AND_VACATIONS', 'DISCIPLINE', 'INCIDENT_MANAGER', 'REPORT_INCIDENT', 'LEAVE_REQUEST'],
				REPORTS: ['BIOMETRIC_DATA', 'EXPORT_BIOMETRIC_DATA']
			},
			TASKS: {
				DASHBOARD: ['TASK_MASTER'],
				MANAGE: ['CREATE_TASK', 'VIEW_TASKS'],
				OPERATIONS: ['ASSIGN_TASKS'],
				REPORTS: ['VIEW_MY_TASKS', 'VIEW_MY_ASSIGNMENTS', 'TASK_STATUS', 'BRANCH_PERFORMANCE']
			},
			NOTIFICATIONS: {
				DASHBOARD: ['COMMUNICATION_CENTER'],
				MANAGE: [],
				OPERATIONS: [],
				REPORTS: []
			},
			USERS: {
				DASHBOARD: ['USER_MANAGEMENT'],
				MANAGE: ['CREATE_USER', 'MANAGE_ADMIN_USERS', 'MANAGE_MASTER_ADMIN', 'INTERFACE_ACCESS_MANAGER', 'APPROVAL_PERMISSIONS'],
				OPERATIONS: [],
				REPORTS: []
			},
			CONTROLS: {
				DASHBOARD: [],
				MANAGE: ['BRANCHES', 'SETTINGS', 'E_R_P_CONNECTIONS', 'CLEAR_TABLES', 'BUTTON_ACCESS_CONTROL', 'BUTTON_GENERATOR'],
				OPERATIONS: [],
				REPORTS: []
			}
		};

		// Map button codes to friendly names
		const buttonNames: Record<string, string> = {
			CUSTOMER_MASTER: 'Customer Master',
			AD_MANAGER: 'Ad Manager',
			PRODUCTS_MANAGER: 'Products Manager',
			DELIVERY_SETTINGS: 'Delivery Settings',
			ORDERS_MANAGER: 'Orders Manager',
			OFFER_MANAGEMENT: 'Offer Management',
			RECEIVING: 'Receiving',
			UPLOAD_VENDOR: 'Upload Vendor',
			CREATE_VENDOR: 'Create Vendor',
			MANAGE_VENDOR: 'Manage Vendor',
			START_RECEIVING: 'Start Receiving',
			RECEIVING_RECORDS: 'Receiving Records',
			VENDOR_RECORDS: 'Vendor Records',
			PRODUCT_MASTER: 'Product Master',
			VARIATION_MANAGER: 'Variation Manager',
			OFFER_MANAGER: 'Offer Manager',
			FLYER_TEMPLATES: 'Flyer Templates',
			SETTINGS: 'Settings',
			OFFER_PRODUCT_EDITOR: 'Offer Product Editor',
			CREATE_NEW_OFFER: 'Create New Offer',
			PRICING_MANAGER: 'Pricing Manager',
			ERP_ENTRY_MANAGER: 'ERP Entry Manager',
			GENERATE_FLYERS: 'Generate Flyers',
			SHELF_PAPER_MANAGER: 'Shelf Paper Manager',
			COUPON_DASHBOARD_PROMO: 'Coupon Dashboard',
			CAMPAIGN_MANAGER: 'Manage Campaigns',
			VIEW_OFFER_MANAGER: 'View Offer Manager',
			CUSTOMER_IMPORTER: 'Import Customers',
			PRODUCT_MANAGER_PROMO: 'Manage Products',
			COUPON_REPORTS: 'Reports & Stats',
			CATEGORY_MANAGER: 'Category Manager',
			PURCHASE_VOUCHER_MANAGER: 'Purchase Voucher Manager',
			MANUAL_SCHEDULING: 'Manual Scheduling',
			DAY_BUDGET_PLANNER: 'Day Budget Planner',
			MONTHLY_MANAGER: 'Monthly Manager',
			EXPENSE_MANAGER: 'Expense Manager',
			PAID_MANAGER: 'Paid Manager',
			EXPENSE_TRACKER: 'Expense Tracker',
			SALES_REPORT: 'Sales Report',
			MONTHLY_BREAKDOWN: 'Monthly Breakdown',
			OVERDUES_REPORT: 'Overdues Report',
			VENDOR_PAYMENTS: 'Vendor Payments',
			POS_REPORT: 'POS Report',
			UPLOAD_EMPLOYEES: 'Upload Employees',
			CREATE_DEPARTMENT: 'Create Department',
			CREATE_LEVEL: 'Create Level',
			CREATE_POSITION: 'Create Position',
			REPORTING_MAP: 'Reporting Map',
			ASSIGN_POSITIONS: 'Assign Positions',
			CONTACT_MANAGEMENT: 'Contact Management',
			DOCUMENT_MANAGEMENT: 'Document Management',
			SALARY_WAGE_MANAGEMENT: 'Salary & Wage Management',
			EMPLOYEE_FILES: 'Employee Files',
			FINGERPRINT_TRANSACTIONS: 'Fingerprint Transactions',
			PROCESS_FINGERPRINT: 'Process Fingerprint',
			SALARY_AND_WAGE: 'Salary and Wage',
			SHIFT_AND_DAY_OFF: 'Shift and Day Off',
			LEAVES_AND_VACATIONS: 'Leaves and Vacations',
			DISCIPLINE: 'Discipline',
			INCIDENT_MANAGER: 'Incident Manager',
			REPORT_INCIDENT: 'Report Incident',
			LEAVE_REQUEST: 'Leave Request',
			BIOMETRIC_DATA: 'Biometric Data',
			EXPORT_BIOMETRIC_DATA: 'Export Biometric Data',
			TASK_MASTER: 'Task Master',
			CREATE_TASK: 'Create Task Template',
			VIEW_TASKS: 'View Task Templates',
			ASSIGN_TASKS: 'Assign Tasks',
			VIEW_MY_TASKS: 'View My Tasks',
			VIEW_MY_ASSIGNMENTS: 'View My Assignments',
			TASK_STATUS: 'Task Status',
			BRANCH_PERFORMANCE: 'Branch Performance',
			COMMUNICATION_CENTER: 'Communication Center',
			USER_MANAGEMENT: 'Users',
			CREATE_USER: 'Create User',
			MANAGE_ADMIN_USERS: 'Manage Admin Users',
			MANAGE_MASTER_ADMIN: 'Manage Master Admin',
			INTERFACE_ACCESS_MANAGER: 'Interface Access',
			APPROVAL_PERMISSIONS: 'Approval Permissions',
			BRANCH_MASTER: 'Branch Master',
			SOUND_SETTINGS: 'Sound Settings',
			ERP_CONNECTIONS: 'ERP Connections',
			FLYER_MASTER: 'Flyer Master',
			FLYER_SETTINGS: 'Settings'
		};

		// Actual button code mappings (for Controls section)
		const controlsButtonNames: Record<string, string> = {
			BRANCHES: 'Branch Master',
			SETTINGS: 'Sound Settings',
			E_R_P_CONNECTIONS: 'ERP Connections',
			CLEAR_TABLES: 'Clear Tables',
			BUTTON_ACCESS_CONTROL: 'Button Access Control',
			BUTTON_GENERATOR: 'Button Generator'
		};

		// Merge both mappings
		const allButtonNames = { ...buttonNames, ...controlsButtonNames };

		// Build sections with detected buttons
		Object.entries(structure).forEach(([sectionCode, subsections]) => {
			const sectionName = sectionCode.charAt(0) + sectionCode.slice(1).toLowerCase();
			const sectionData: SectionStructure = {
				name: sectionName,
				subsections: [],
				totalButtons: 0
			};

			Object.entries(subsections).forEach(([subsectionCode, buttonCodes]) => {
				const subsectionName = subsectionCode.charAt(0) + subsectionCode.slice(1).toLowerCase();
				const buttons = buttonCodes
					.map(code => ({
						code: code,
						name: allButtonNames[code] || code.replace(/_/g, ' ').toLowerCase()
					}));

				sectionData.subsections.push({
					name: subsectionName,
					buttons: buttons,
					buttonCount: buttons.length
				});

				sectionData.totalButtons += buttons.length;
			});

			sections[sectionName] = sectionData;
		});

		const result = Object.values(sections);

		return json({
			success: true,
			sections: result,
			totalSections: result.length,
			totalButtons: result.reduce((sum, s) => sum + s.totalButtons, 0),
			detectedButtonCodes: Array.from(allButtonCodes).sort()
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
