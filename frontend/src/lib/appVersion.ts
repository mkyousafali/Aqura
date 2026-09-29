// This is the single version source for every web interface.
// deployment/bump-version.mjs updates all four numbers together.
export const interfaceVersions = {
  desktop: 20,
  mobile: 18,
  cashier: 18,
  customer: 16,
} as const;

export const appVersion = `AQ${interfaceVersions.desktop}.${interfaceVersions.mobile}.${interfaceVersions.cashier}.${interfaceVersions.customer}`;
export const desktopVersion = `AQ${interfaceVersions.desktop}`;
export const mobileVersion = `AQ${interfaceVersions.mobile}`;
export const cashierVersion = `AQ${interfaceVersions.cashier}`;
export const customerVersion = `AQ${interfaceVersions.customer}`;
