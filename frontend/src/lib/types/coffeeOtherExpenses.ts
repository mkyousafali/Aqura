import type { CoffeeOtherPayment } from './coffeeOtherPayments';

export type CoffeeExpensePaidFrom = 'sales' | 'operator';

export interface CoffeeOtherExpense extends CoffeeOtherPayment {
	paidFrom: CoffeeExpensePaidFrom;
}

export interface CoffeeOtherExpenseTotals {
	sales: number;
	operator: number;
}

export interface CoffeeOtherExpensesResponse {
	success: boolean;
	asOfDate: string;
	total: number;
	totals: CoffeeOtherExpenseTotals;
	payments?: CoffeeOtherExpense[];
}
