import { bakeryDate, BAKERY_REPORT_START_DATE } from '$lib/types/bakery';

/** Manual-entry screens default to today. Historical reports pass their cutoff
 * explicitly so their lists and aggregate totals use the same inclusive date. */
export function counterEntryThroughDate(requested: string | null): string | null {
	const today = bakeryDate();
	if (requested === null) return today;
	if (!/^\d{4}-\d{2}-\d{2}$/.test(requested) || requested < '1753-01-01' || requested > today) return null;
	const parsed = new Date(`${requested}T00:00:00Z`);
	if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== requested) return null;
	return requested;
}

export function counterPostingDate(value: unknown, counter: 'coffee' | 'bakery'): string | null {
	if (value !== undefined && typeof value !== 'string') return null;
	const date = counterEntryThroughDate(value === undefined ? null : value);
	return date && (counter !== 'bakery' || date >= BAKERY_REPORT_START_DATE) ? date : null;
}
