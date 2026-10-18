export const receivingReturnAmountFields = [
	'expired_return_amount',
	'near_expiry_return_amount',
	'over_stock_return_amount',
	'damage_return_amount'
] as const;

/** Match calculate_receiving_amounts(): final = max(bill - returns, 0). */
export function calculateReceivingRecordAmounts(values: Record<string, unknown>) {
	const fields = ['bill_amount', ...receivingReturnAmountFields] as const;
	const cents: Record<string, number> = {};
	for (const field of fields) {
		const value = values[field];
		// An empty return box means zero; a bill amount is still required.
		if (field === 'bill_amount' && (value === '' || value == null)) return null;
		const amount = value === '' || value == null ? 0 : Number(value);
		if (!Number.isFinite(amount) || amount < 0) return null;
		cents[field] = Math.round((amount + Number.EPSILON) * 100);
	}
	const totalCents = receivingReturnAmountFields.reduce((total, field) => total + cents[field], 0);
	return {
		bill_amount: cents.bill_amount / 100,
		expired_return_amount: cents.expired_return_amount / 100,
		near_expiry_return_amount: cents.near_expiry_return_amount / 100,
		over_stock_return_amount: cents.over_stock_return_amount / 100,
		damage_return_amount: cents.damage_return_amount / 100,
		total_return_amount: totalCents / 100,
		final_bill_amount: Math.max(cents.bill_amount - totalCents, 0) / 100
	};
}
