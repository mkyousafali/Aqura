import { describe, expect, it } from 'vitest';
import { closingCashSales } from './closingSales';

describe('counter cash sales', () => {
  it('includes charity sales with purchase and loyalty vouchers', () => {
    expect(closingCashSales(500, 50, 101.45, 20, 75.25)).toBe(706.7);
    expect(closingCashSales(500, 50, 101.45, 20, 0)).toBe(631.45);
  });
  it('counts loyalty coupons in the same cash total as purchase vouchers', () => {
    expect(closingCashSales(500, 50, 101.45, 20)).toBe(631.45);
  });
  it('preserves existing closing behavior without loyalty vouchers', () => {
    expect(closingCashSales(500, 50, 0, 20)).toBe(530);
  });
  it('keeps currency precision and handles legacy absent totals', () => {
    expect(closingCashSales(0.1, 0.2, 0.3, 0.1)).toBe(0.5);
    expect(closingCashSales(500, undefined, undefined, undefined)).toBe(500);
  });
});
