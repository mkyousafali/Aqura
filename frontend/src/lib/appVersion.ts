// This is the single version source for every web interface.
// deployment/bump-version.mjs updates all four numbers together.
export const interfaceVersions = {
  desktop: 48,
  mobile: 46,
  cashier: 46,
  customer: 44,
} as const;

export const appVersion = `AQ${interfaceVersions.desktop}.${interfaceVersions.mobile}.${interfaceVersions.cashier}.${interfaceVersions.customer}`;
export const desktopVersion = `AQ${interfaceVersions.desktop}`;
export const mobileVersion = `AQ${interfaceVersions.mobile}`;
export const cashierVersion = `AQ${interfaceVersions.cashier}`;
export const customerVersion = `AQ${interfaceVersions.customer}`;
