import { writable, get } from 'svelte/store';

// Persisted order flow context: selected branch and fulfillment method
const initial = (() => {
  if (typeof window === 'undefined') return { branchId: null, fulfillment: null };
  try {
    const raw = localStorage.getItem('orderFlow');
    if (!raw) return { branchId: null, fulfillment: null };
    const parsed = JSON.parse(raw);
    return {
      branchId: parsed.branchId ?? null,
      fulfillment: parsed.fulfillment ?? null,
    };
  } catch {
    return { branchId: null, fulfillment: null };
  }
})();

export const orderFlow = writable(initial);

function persist() {
  if (typeof window === 'undefined') return;
  const value = get(orderFlow);
  localStorage.setItem('orderFlow', JSON.stringify(value));
}

orderFlow.subscribe(() => {
  try { persist(); } catch { /* noop */ }
});

export const orderFlowActions = {
  setSelection(branchId, fulfillment) {
    orderFlow.set({ branchId, fulfillment });
  },
  clear() {
    orderFlow.set({ branchId: null, fulfillment: null });
  },
  get() {
    return get(orderFlow);
  }
};
