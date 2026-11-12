import type { BakeryBranch } from './bakery';

export interface CoffeeSupplier {
	key: string;
	name: string;
	ledgerCode: string;
	/** Arda ledger debit minus credit through the report date. */
	balance: number;
}

export interface CoffeeSuppliersResponse {
	success: boolean;
	asOfDate: string;
	branches: BakeryBranch[];
	suppliers: CoffeeSupplier[];
}
