import { addMoney, subtractMoney } from './money';

export function closingCashSales(cash: unknown, purchaseVouchers: unknown, loyaltyVouchers: unknown, recharge: unknown, charitySales: unknown = 0): number {
  return subtractMoney(addMoney(cash, purchaseVouchers, loyaltyVouchers, charitySales), recharge);
}
