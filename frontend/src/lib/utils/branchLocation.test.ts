import { describe, expect, it } from 'vitest';
import { branchMapEmbedUrl } from './branchLocation';

const branch = { name_en: 'Market 01', location_en: 'Abu Arish' };
const query = (url: string) => new URL(url).searchParams.get('q');

describe('branch map preview', () => {
	it('uses the destination coordinates instead of the distant map viewport', () => {
		const url = branchMapEmbedUrl({ ...branch, location_url: 'https://www.google.com/maps/dir//@17.0105822,43.0097713/data=!1d42.829053!2d16.9395332' });
		expect(query(url)).toBe('16.9395332,42.829053');
	});
	it('uses the saved named destination when the URL only has a viewport', () => {
		const url = branchMapEmbedUrl({ ...branch, location_url: 'https://www.google.com/maps/dir//%D8%A7%D9%8A%D8%B1%D8%A8%D9%86+Market,+Al+Aridhah+83311/@17.0105822,43.0097713' });
		expect(query(url)).toBe('ايربن Market, Al Aridhah 83311');
	});
	it('respects explicit destinations and place coordinates', () => {
		expect(query(branchMapEmbedUrl({ ...branch, location_url: 'https://www.google.com/maps/dir/?api=1&destination=Branch+Two' }))).toBe('Branch Two');
		expect(query(branchMapEmbedUrl({ ...branch, location_url: 'https://www.google.com/maps/@17.01,43.00/data=!3d16.9395332!4d42.829053' }))).toBe('16.9395332,42.829053');
	});
	it('keeps the Abu Arish business listing instead of replacing it with a coordinate pin', () => {
		const url = branchMapEmbedUrl({ ...branch, location_url: 'https://www.google.com/maps/dir//%D8%A3%D8%B3%D9%88%D8%A7%D9%82+%D8%A7%D9%8A%D8%B1%D8%A8%D9%86+%D9%85%D8%A7%D8%B1%D9%83%D8%AA,+King+Abdullah+Rd,+Abu+Arish+84526/@17.0105822,43.0097713/data=!1d42.829053!2d16.9395332' });
		expect(query(url)).toBe('أسواق ايربن ماركت, King Abdullah Rd, Abu Arish 84526');
		expect(new URL(url).searchParams.get('output')).toBe('embed');
	});
	it('retains named place-page lookups when coordinates are also present', () => {
		expect(query(branchMapEmbedUrl({ ...branch, location_url: 'https://www.google.com/maps/place/Urban+Market,+Abu+Arish/data=!3d16.9395332!4d42.829053' }))).toBe('Urban Market, Abu Arish');
	});
	it('preserves configured Google embed links', () => {
		const location_url = 'https://www.google.com/maps/embed?pb=existing-map';
		expect(branchMapEmbedUrl({ ...branch, location_url })).toBe(location_url);
	});
	it('falls back to Aqura branch details for short, invalid or unrelated URLs', () => {
		for (const location_url of ['https://maps.app.goo.gl/example', 'invalid', 'https://example.com/maps/embed?pb=example', 'https://google.example.com/maps/embed?pb=example']) {
			expect(query(branchMapEmbedUrl({ ...branch, location_url }))).toBe('Market 01, Abu Arish');
		}
	});
	it('supports Arabic labels and map language without inventing location details', () => {
		const url = new URL(branchMapEmbedUrl({ name_ar: 'الفرع', location_ar: 'العارضة' }, 'ar'));
		expect(url.searchParams.get('q')).toBe('الفرع, العارضة');
		expect(url.searchParams.get('hl')).toBe('ar');
	});
});
