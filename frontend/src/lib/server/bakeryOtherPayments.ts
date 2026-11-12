import type { SupabaseClient } from '@supabase/supabase-js';
import type { CoffeeOtherPayment } from '$lib/types/coffeeOtherPayments';

export function bakeryOtherPayment(row: Record<string, any>): CoffeeOtherPayment {
	const amount = Number(row.amount);
	const version = Number(row.version);
	if (!Number.isFinite(amount) || amount <= 0 || !Number.isSafeInteger(version) || version < 1) throw new Error('Invalid saved payment amount or version');
	return { id: String(row.id), amount, narration: String(row.narration),
		paymentDate: String(row.payment_date), createdAt: String(row.created_at), updatedAt: String(row.updated_at), version };
}

export async function readBakeryOtherPaymentTotal(db: SupabaseClient, throughDate: string): Promise<number | null> {
	const { data, error } = await db.rpc('bakery_other_payment_total', { p_through: throughDate });
	if (error || data == null) return null;
	const total = Number(data);
	return Number.isFinite(total) && total >= 0 ? total : null;
}
