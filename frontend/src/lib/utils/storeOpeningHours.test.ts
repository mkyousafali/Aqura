import { describe, expect, it } from 'vitest';
import { formatStoreOpeningHours, storeOpeningHoursSummary } from './storeOpeningHours';

const abuArish = { id: 1, location_en: 'Abu Arish', location_ar: 'أبو عريش', is_24_hours: true, operating_start_time: null, operating_end_time: null };
const alAridhah = { id: 3, location_en: 'Al-Aridhah', location_ar: 'العارضة', is_24_hours: false, operating_start_time: '06:00:00', operating_end_time: '02:00:00' };

describe('public store opening hours', () => {
	it('shows Abu Arish as 24 hours independently of the other branch', () => {
		expect(formatStoreOpeningHours(abuArish)).toBe('Open 24 hours daily');
		expect(formatStoreOpeningHours(alAridhah)).toBe('6:00 AM – 2:00 AM (next day)');
	});
	it('provides bilingual branch-specific summaries', () => {
		expect(storeOpeningHoursSummary([abuArish, alAridhah])).toBe('Abu Arish: Open 24 hours daily\nAl-Aridhah: 6:00 AM – 2:00 AM (next day)');
		expect(storeOpeningHoursSummary([abuArish, alAridhah], 'ar')).toContain('أبو عريش: مفتوح ٢٤ ساعة يوميًا');
		expect(storeOpeningHoursSummary([abuArish, alAridhah], 'ar')).toContain('العارضة: ٦:٠٠ ص – ٢:٠٠ ص (اليوم التالي)');
		expect(storeOpeningHoursSummary([abuArish, alAridhah], 'ar')).not.toMatch(/[A-Za-z0-9]/);
		expect(storeOpeningHoursSummary([abuArish, alAridhah], 'en')).not.toMatch(/\p{Script=Arabic}/u);
	});
	it('does not infer 24-hour opening from invalid or equal times', () => {
		for (const operating_end_time of ['06:00:00', '25:00', null]) {
			expect(formatStoreOpeningHours({ ...alAridhah, operating_end_time })).toBe('');
		}
	});
	it('does not confuse afternoon closing with next-day morning closing', () => {
		expect(formatStoreOpeningHours({ ...alAridhah, operating_end_time: '14:00' })).toBe('6:00 AM – 2:00 PM');
	});
});
