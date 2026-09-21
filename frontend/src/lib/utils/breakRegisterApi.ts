export interface BreakFilters {
	from?: string;
	to?: string;
	branch?: string;
	status?: string;
}

export async function loadBreakRegisterData(view: 'logs' | 'summary' | 'schedule' | 'dashboard', filters: BreakFilters = {}, interfaceType: 'desktop' | 'mobile' = 'desktop'): Promise<any> {
	const params = new URLSearchParams({ view });
	for (const [key, value] of Object.entries(filters)) if (value) params.set(key, value);
	const response = await fetch(`/api/break-register?${params}`, { credentials: 'same-origin', headers: { 'x-aqura-interface': interfaceType } });
	const data = await response.json();
	if (!response.ok) throw new Error(data.error || 'Could not load break data');
	return data;
}
