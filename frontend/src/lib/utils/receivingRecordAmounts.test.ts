import { expect, it } from 'vitest';
import { calculateReceivingRecordAmounts } from './receivingRecordAmounts';

it('includes all four return categories and calculates the final bill', () => {
	expect(calculateReceivingRecordAmounts({
		bill_amount: '1000', expired_return_amount: '100', near_expiry_return_amount: '50',
		over_stock_return_amount: '20', damage_return_amount: '30'
	})).toEqual({
		bill_amount: 1000, expired_return_amount: 100, near_expiry_return_amount: 50,
		over_stock_return_amount: 20, damage_return_amount: 30,
		total_return_amount: 200, final_bill_amount: 800
	});
});

it('recalculates totals when a return is cleared without losing the other returns', () => {
	const result = calculateReceivingRecordAmounts({
		bill_amount: 100, expired_return_amount: 10, near_expiry_return_amount: '',
		over_stock_return_amount: 5, damage_return_amount: 20
	});
	expect(result?.total_return_amount).toBe(35);
	expect(result?.final_bill_amount).toBe(65);
});

it('handles currency arithmetic without floating-point totals', () => {
	const result = calculateReceivingRecordAmounts({ bill_amount: '1.00', expired_return_amount: '0.10', damage_return_amount: '0.20' });
	expect(result?.total_return_amount).toBe(0.3);
	expect(result?.final_bill_amount).toBe(0.7);
});

it('matches the existing database zero floor when returns exceed the bill', () => {
	const result = calculateReceivingRecordAmounts({ bill_amount: 50, damage_return_amount: 60 });
	expect(result?.total_return_amount).toBe(60);
	expect(result?.final_bill_amount).toBe(0);
});

it.each(['', null, undefined, 'invalid', -1, Infinity, NaN])('rejects invalid bill amount %s', bill_amount => {
	expect(calculateReceivingRecordAmounts({ bill_amount })).toBeNull();
});

it.each(['expired_return_amount', 'near_expiry_return_amount', 'over_stock_return_amount', 'damage_return_amount'])('validates %s', field => {
	expect(calculateReceivingRecordAmounts({ bill_amount: 100, [field]: -1 })).toBeNull();
	expect(calculateReceivingRecordAmounts({ bill_amount: 100, [field]: 'invalid' })).toBeNull();
});
