export const BAKERY_PRODUCT_GROUP = 'Z-BAKERY URBAN';
export const BAKERY_REPORT_START_DATE = '2026-11-12';
export const BAKERY_REPORT_START_MONTH = BAKERY_REPORT_START_DATE.slice(0, 7);

/** Calendar rows for the arrangement, excluding all earlier dates. */
export function bakeryReportDates(month: string): string[] {
	if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month) || month < BAKERY_REPORT_START_MONTH) return [];
	const [year, monthNumber] = month.split('-').map(Number);
	const days = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
	return Array.from({ length: days }, (_, index) => `${month}-${String(index + 1).padStart(2, '0')}`)
		.filter(date => date >= BAKERY_REPORT_START_DATE);
}
export const BAKERY_EXPENSE_LEDGER_NAME = 'BAKERY EXPENSES';
export const BAKERY_EXPENSE_LEDGER_REFERENCE = '2252';

export interface BakeryProduct {
	branchId: string;
	productId: string;
	barcode: string;
	nameEn: string;
	nameAr: string;
	unitName: string;
	salesPrice: number | null;
	cost: number | null;
}

export interface BakeryBranch {
	id: string;
	nameEn: string;
	nameAr: string;
	status: 'loaded' | 'unavailable' | 'timeout' | 'failed';
}

export interface BakeryProductsResponse {
	success: boolean;
	branches: BakeryBranch[];
	products: BakeryProduct[];
}

export interface BakerySale {
	branchId: string;
	productId: string;
	unitId: string;
	nameEn: string;
	nameAr: string;
	unitName: string;
	quantity: number;
	salesAmount: number;
	returnAmount: number;
	outputVat: number;
}

export interface BakerySalesResponse {
	success: boolean;
	date: string;
	branches: BakeryBranch[];
	sales: BakerySale[];
}

export interface BakeryDailySale {
	branchId: string;
	date: string;
	salesAmount: number;
	returnAmount: number;
	outputVat: number;
}

export interface BakeryMonthlySalesResponse {
	success: boolean;
	month: string;
	branches: BakeryBranch[];
	dailySales: BakeryDailySale[];
}

export interface BakeryExpenseBranch extends Omit<BakeryBranch, 'status'> {
	status: BakeryBranch['status'] | 'ledgerMissing' | 'ledgerAmbiguous';
}

export interface BakeryExpense {
	branchId: string;
	id: string;
	date: string;
	voucher: string;
	formType: string;
	formName: string;
	vendorName?: string;
	narration: string;
	debit: number;
	credit: number;
	inputVat: number | null;
}

export interface BakeryExpensesResponse {
	success: boolean;
	date: string;
	month: string | null;
	branches: BakeryExpenseBranch[];
	expenses: BakeryExpense[];
}

export function bakeryDate(offsetDays = 0): string {
	const parts = new Intl.DateTimeFormat('en-GB', {
		timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit'
	}).formatToParts(new Date(Date.now() + offsetDays * 86400000));
	const part = (type: string) => parts.find(value => value.type === type)?.value;
	return `${part('year')}-${part('month')}-${part('day')}`;
}
