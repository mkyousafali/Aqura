import { BAKERY_PRODUCT_GROUP, BAKERY_REPORT_START_DATE } from './bakery';

/** Public reporting configuration; ERP credentials stay on the server. */
export interface BusinessCounterProfile {
	id: 'bakery' | 'coffee-counter';
	localeKey: 'bakery' | 'coffeeCounter';
	titleKey: string;
	icon: string;
	productGroup: string;
	reportStartDate: string;
	rentPercent: number;
	rentIncreaseDate?: string;
	laterRentPercent?: number;
}

export const BAKERY_COUNTER: BusinessCounterProfile = {
	id: 'bakery', localeKey: 'bakery', titleKey: 'nav.bakery', icon: '🥐',
	productGroup: BAKERY_PRODUCT_GROUP, reportStartDate: BAKERY_REPORT_START_DATE,
	rentPercent: 10, rentIncreaseDate: '2027-05-12', laterRentPercent: 15
};

export const COFFEE_COUNTER: BusinessCounterProfile = {
	id: 'coffee-counter', localeKey: 'coffeeCounter', titleKey: 'nav.coffeeCounter', icon: '☕',
	productGroup: 'coffee products',
	// Allow the ERP's entire supported history, independent of the bakery agreement.
	reportStartDate: '1753-01-01', rentPercent: 0,
	rentIncreaseDate: '2026-01-15', laterRentPercent: 15
};

/** Aqura branch ID for Arda; its ERP branch mapping is resolved separately. */
export const COFFEE_PURCHASE_BRANCH_ID = '3';

/** One-time capital addition to the combined all-time operators' payable. */
export const COFFEE_INITIAL_CAPITAL = 7434.50;

export function counterRentPercentage(profile: BusinessCounterProfile, date: string): number {
	return profile.rentIncreaseDate && date >= profile.rentIncreaseDate
		? profile.laterRentPercent ?? profile.rentPercent : profile.rentPercent;
}

export function counterReportDates(month: string, startDate: string): string[] {
	if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month) || month < startDate.slice(0, 7)) return [];
	const [year, monthNumber] = month.split('-').map(Number);
	const days = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
	return Array.from({ length: days }, (_, index) => `${month}-${String(index + 1).padStart(2, '0')}`)
		.filter(date => date >= startDate);
}
