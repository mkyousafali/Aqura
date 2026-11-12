import type { SupabaseClient } from '@supabase/supabase-js';
import type { CoffeeOtherExpense, CoffeeOtherExpenseTotals } from '$lib/types/coffeeOtherExpenses';

export function coffeeOtherExpense(row: Record<string, any>): CoffeeOtherExpense {
	const amount = Number(row.amount);
	const version = Number(row.version);
	if (!Number.isFinite(amount) || amount <= 0 || !Number.isSafeInteger(version) || version < 1 || !['sales', 'operator'].includes(row.paid_from)) throw new Error('Invalid saved expense');
	return { id: String(row.id), amount, narration: String(row.narration), paidFrom: row.paid_from,
		paymentDate: String(row.expense_date), createdAt: String(row.created_at), updatedAt: String(row.updated_at), version };
}

export async function readCoffeeOtherExpenseTotals(db: SupabaseClient, throughDate: string): Promise<CoffeeOtherExpenseTotals | null> {
	const { data, error } = await db.rpc('coffee_other_expense_totals', { p_through: throughDate });
	if (error || data?.sales == null || data?.operator == null) return null;
	const sales = Number(data.sales), operator = Number(data.operator);
	return [sales, operator].every(value => Number.isFinite(value) && value >= 0) ? { sales, operator } : null;
}
