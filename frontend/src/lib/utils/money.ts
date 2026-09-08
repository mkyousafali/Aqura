const MONEY_SCALE = 100;

/** Convert an input to a finite, two-decimal currency value. */
export function money(value: unknown): number {
  const numericValue = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(numericValue)) return 0;
  return (
    Math.round((numericValue + Number.EPSILON) * MONEY_SCALE) / MONEY_SCALE
  );
}

/** Add currency values as integer halalas to avoid binary floating-point drift. */
export function addMoney(...values: unknown[]): number {
  const halalas = values.reduce<number>(
    (total, value) => total + Math.round(money(value) * MONEY_SCALE),
    0,
  );
  return halalas / MONEY_SCALE;
}

/** Subtract currency values as integer halalas. */
export function subtractMoney(
  minuend: unknown,
  ...subtrahends: unknown[]
): number {
  const result = subtrahends.reduce(
    (total, value) => total - Math.round(money(value) * MONEY_SCALE),
    Math.round(money(minuend) * MONEY_SCALE),
  );
  return result / MONEY_SCALE;
}

/** Multiply a currency value and normalize the result to two decimals. */
export function multiplyMoney(value: unknown, multiplier: unknown): number {
  const numericMultiplier = Number(multiplier);
  if (!Number.isFinite(numericMultiplier)) return 0;
  return money(money(value) * numericMultiplier);
}
