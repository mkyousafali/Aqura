import type { BusinessCounterProfile } from '$lib/types/businessCounter';

/** SQL scope for the existing p (Products) and g (ProductGroups) aliases. */
export function counterSalesScope(profile: BusinessCounterProfile): string {
	const group = profile.productGroup.replace(/'/g, "''");
	return `(LTRIM(RTRIM(g.GroupName)) = N'${group}')`;
}
