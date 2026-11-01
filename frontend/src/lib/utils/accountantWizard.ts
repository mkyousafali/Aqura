type Flags = Record<string | number, boolean>;
export type AccountantVerification = {
  denominations: Flags; recharge: Flags; vouchers: Flags; bank: Flags; system: Flags;
  loyalty: Flags; charity: Flags;
  purchaseRows: unknown[]; loyaltyRows: { serial: string }[]; charityRows: { serial: string }[];
};

type VerificationGroup = 'denominations' | 'recharge' | 'vouchers' | 'loyalty' | 'charity' | 'bank' | 'system';
function verificationSection(step: number, state: AccountantVerification): { group: VerificationGroup; keys: (string | number)[] } | null {
  switch (step) {
    case 1: return { group: 'denominations', keys: ['d500','d200','d100','d50','d20','d10','d5','d2','d1','d05','d025','coins'] };
    case 2: return { group: 'recharge', keys: ['openingBalance','closeBalance','startDate','startTime','endDate','endTime'] };
    case 3: return { group: 'vouchers', keys: state.purchaseRows.map((_, index) => index) };
    case 4: return { group: 'loyalty', keys: state.loyaltyRows.map(row => row.serial) };
    case 5: return { group: 'charity', keys: state.charityRows.map(row => row.serial) };
    case 6: return { group: 'bank', keys: ['mada','visa','mastercard','googlepay','other'] };
    case 7: return { group: 'system', keys: ['cashSales','cardSales','return'] };
    default: return null;
  }
}

export function accountantStepVerified(step: number, state: AccountantVerification): boolean {
  const section = verificationSection(step, state);
  return section ? section.keys.every(key => state[section.group][key] === true) : [8, 9, 10].includes(step);
}

export function checkAllAccountantStep(step: number, state: AccountantVerification): AccountantVerification {
  const section = verificationSection(step, state);
  if (!section) return state;
  return { ...state, [section.group]: { ...state[section.group], ...Object.fromEntries(section.keys.map(key => [key, true])) } };
}
