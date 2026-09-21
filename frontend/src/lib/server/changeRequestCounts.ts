export const changeValues: Record<string, number> = {
  d500: 50000, d200: 20000, d100: 10000, d50: 5000, d20: 2000,
  d10: 1000, d5: 500, d2: 200, d1: 100, d05: 50, d025: 25
};

export function checkedCounts(input: unknown): { counts: Record<string, number>; total: number } {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('Invalid denomination quantities.');
  const raw = input as Record<string, unknown>;
  if (Object.keys(raw).some(key => !(key in changeValues))) throw new Error('Unsupported denomination.');
  const counts: Record<string, number> = {};
  let cents = 0;
  for (const [key, value] of Object.entries(changeValues)) {
    const count = raw[key] ?? 0;
    if (!Number.isSafeInteger(count) || (count as number) < 0 || (count as number) > 100000) {
      throw new Error(`Invalid quantity for ${value / 100} SAR.`);
    }
    counts[key] = count as number;
    cents += (count as number) * value;
  }
  if (!Number.isSafeInteger(cents) || cents <= 0) throw new Error('Enter at least one denomination.');
  return { counts, total: cents / 100 };
}
