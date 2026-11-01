import { describe, expect, it } from 'vitest';
import { accountantStepVerified, checkAllAccountantStep, type AccountantVerification } from './accountantWizard';
const empty = (): AccountantVerification => ({ denominations: {}, recharge: {}, vouchers: {}, bank: {}, system: {}, loyalty: {}, charity: {}, purchaseRows: [], loyaltyRows: [], charityRows: [] });
describe('accountant wizard verification', () => {
  it('Check All verifies only the chosen section and does not change saved amounts or other checks', () => {
    const state = empty();
    state.loyaltyRows = [{ serial: 'LYL-00000001' }, { serial: 'LYL-00000002' }];
    const checked = checkAllAccountantStep(4, state);
    expect(accountantStepVerified(4, checked)).toBe(true);
    expect(accountantStepVerified(1, checked)).toBe(false);
    expect(checked.loyaltyRows).toBe(state.loyaltyRows);
    expect(checked.denominations).toBe(state.denominations);
    expect(state.loyalty).toEqual({});
  });
  it('supports all seven verification sections without changing posting or finalization steps', () => {
    const state = empty();
    state.purchaseRows = [{}]; state.loyaltyRows = [{ serial: 'L1' }]; state.charityRows = [{ serial: 'C1' }];
    for (let step = 1; step <= 7; step++) expect(accountantStepVerified(step, checkAllAccountantStep(step, state))).toBe(true);
    expect(checkAllAccountantStep(9, state)).toBe(state);
    expect(checkAllAccountantStep(10, state)).toBe(state);
  });
  it('requires every denomination, including zero counts, to be checked', () => {
    const state = empty();
    for (const key of ['d500','d200','d100','d50','d20','d10','d5','d2','d1','d05','d025']) state.denominations[key] = true;
    expect(accountantStepVerified(1, state)).toBe(false);
    state.denominations.coins = true;
    expect(accountantStepVerified(1, state)).toBe(true);
  });
  it('allows empty voucher sections but requires every saved loyalty and charity row', () => {
    const state = empty();
    expect(accountantStepVerified(4, state)).toBe(true);
    state.loyaltyRows = [{ serial: 'LYL-00000001' }, { serial: 'LYL-00000002' }];
    state.loyalty['LYL-00000001'] = true;
    expect(accountantStepVerified(4, state)).toBe(false);
    state.loyalty['LYL-00000002'] = true;
    expect(accountantStepVerified(4, state)).toBe(true);
    state.charityRows = [{ serial: 'CH-1' }];
    expect(accountantStepVerified(5, state)).toBe(false);
    state.charity['CH-1'] = true;
    expect(accountantStepVerified(5, state)).toBe(true);
  });
  it('keeps recharge, bank, and ERP verification independent', () => {
    const state = empty();
    state.bank = { mada: true, visa: true, mastercard: true, googlepay: true, other: true };
    expect(accountantStepVerified(6, state)).toBe(true);
    expect(accountantStepVerified(2, state)).toBe(false);
    expect(accountantStepVerified(7, state)).toBe(false);
  });
});
