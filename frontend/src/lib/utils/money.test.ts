import { describe, expect, it } from "vitest";
import { addMoney, money, multiplyMoney, subtractMoney } from "./money";

describe("money helpers", () => {
  it("normalizes floating-point artifacts to two decimals", () => {
    expect(money(356.40999999999997)).toBe(356.41);
    expect(money(904.5999999999999)).toBe(904.6);
  });

  it("adds and subtracts using integer halalas", () => {
    expect(addMoney(3395.18, 356.4, 64.95)).toBe(3816.53);
    expect(subtractMoney(356.4, 0.1, 0.2)).toBe(356.1);
  });

  it("normalizes currency multiplication", () => {
    expect(multiplyMoney(0.1, 3)).toBe(0.3);
  });

  it("converts blank and invalid inputs to zero", () => {
    expect(money("")).toBe(0);
    expect(money(undefined)).toBe(0);
  });
});
