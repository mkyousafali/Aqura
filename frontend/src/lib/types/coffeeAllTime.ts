import type { BakeryBranch, BakeryExpenseBranch } from './bakery';
import type { CoffeeBranchStockValue } from './coffeeStock';
import type { CoffeeOtherExpenseTotals } from './coffeeOtherExpenses';

export interface CoffeeAllTimeSale {
	branchId: string;
	date: string;
	salesIncludingVat: number;
	outputVat: number;
}

export interface CoffeeAllTimeInputVat {
	branchId?: string;
	date: string;
	inputVat: number;
	expensesExcludingVat: number;
}

export interface CoffeeVendorPayments {
	asOfDate: string;
	branch: BakeryBranch;
	cashAndBankAmount: number | null;
	journalAmount: number | null;
	total: number | null;
}

export interface CoffeeAllTimeResponse {
	success: boolean;
	asOfDate: string;
	branches: BakeryBranch[];
	inputVatBranch: BakeryBranch | null;
	expenseBranches?: BakeryExpenseBranch[];
	dailySales: CoffeeAllTimeSale[];
	dailyInputVat: CoffeeAllTimeInputVat[];
	vendorPayments: CoffeeVendorPayments | null;
	otherPaymentsTotal: number | null;
	otherExpenseTotals: CoffeeOtherExpenseTotals | null;
	stockValues: CoffeeBranchStockValue[];
}
