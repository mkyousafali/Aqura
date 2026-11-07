export interface StoreOpeningHours {
	id: number;
	name_en?: string;
	name_ar?: string;
	location_en?: string;
	location_ar?: string;
	location_url?: string | null;
	is_24_hours: boolean;
	operating_start_time?: string | null;
	operating_end_time?: string | null;
}

export const storeOpeningHoursFields = 'id,name_en,name_ar,location_en,location_ar,location_url,is_24_hours,operating_start_time,operating_end_time';

/** Store opening hours are separate from delivery, pickup and human support. */
export function formatStoreOpeningHours(branch: StoreOpeningHours, language = 'en'): string {
	const arabic = language === 'ar';
	if (branch.is_24_hours === true) return arabic ? 'مفتوح ٢٤ ساعة يوميًا' : 'Open 24 hours daily';
	const parse = (value?: string | null) => {
		const match = /^(\d{2}):(\d{2})(?::\d{2})?$/.exec(value || '');
		if (!match || +match[1] > 23 || +match[2] > 59) return null;
		return +match[1] * 60 + +match[2];
	};
	const start = parse(branch.operating_start_time);
	const end = parse(branch.operating_end_time);
	if (start === null || end === null || start === end) return '';
	const format = (minutes: number) => {
		const hour = Math.floor(minutes / 60);
		const period = arabic ? (hour >= 12 ? 'م' : 'ص') : (hour >= 12 ? 'PM' : 'AM');
		const time = `${hour % 12 || 12}:${String(minutes % 60).padStart(2, '0')} ${period}`;
		return arabic ? time.replace(/\d/g, digit => '٠١٢٣٤٥٦٧٨٩'[Number(digit)]) : time;
	};
	return `${format(start)} – ${format(end)}${end < start ? (arabic ? ' (اليوم التالي)' : ' (next day)') : ''}`;
}

export function storeOpeningHoursSummary(branches: StoreOpeningHours[], language = 'en'): string {
	return branches.map(branch => {
		const name = language === 'ar'
			? branch.location_ar || branch.name_ar || branch.location_en || branch.name_en
			: branch.location_en || branch.name_en || branch.location_ar || branch.name_ar;
		const hours = formatStoreOpeningHours(branch, language);
		return name && hours ? `${name}: ${hours}` : '';
	}).filter(Boolean).join('\n');
}

export async function loadStoreOpeningHours(client: any): Promise<StoreOpeningHours[]> {
	const { data, error } = await client.from('branches').select(storeOpeningHoursFields)
		.eq('is_active', true).not('location_url', 'is', null).order('id');
	if (error) throw error;
	return (data || []).filter((branch: StoreOpeningHours) => branch.location_url?.trim());
}
