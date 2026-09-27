import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const db = vi.hoisted(() => ({ from: vi.fn(), eq: vi.fn(), result: { data: { api_key: 'table-maps-key' }, error: null } as any }));
vi.mock('@supabase/supabase-js', () => ({ createClient: () => db }));
vi.mock('$env/dynamic/private', () => ({ env: {
	VITE_SUPABASE_URL: 'https://database.test', VITE_SUPABASE_SERVICE_KEY: 'test-db-key',
	VITE_GOOGLE_MAPS_API_KEY: 'must-not-be-used', GOOGLE_API_KEY: 'must-not-be-used'
} }));
import { GET } from '../../routes/api/maps-key/+server';
import { fetchGoogleMapsKey } from './googleMapsKey';

const fetchMock = vi.fn();
beforeEach(() => {
	vi.clearAllMocks();
	db.result = { data: { api_key: 'table-maps-key' }, error: null };
	const chain: any = { select: () => chain, single: async () => db.result };
	db.eq.mockImplementation(() => chain);
	chain.eq = db.eq;
	db.from.mockReturnValue(chain);
	fetchMock.mockReset().mockImplementation(() => GET({} as any));
	vi.stubGlobal('fetch', fetchMock);
});
afterEach(() => vi.unstubAllGlobals());

describe('map display key from the database', () => {
	it('loads the active google table key through the existing endpoint', async () => {
		expect(await fetchGoogleMapsKey()).toBe('table-maps-key');
		expect(fetchMock).toHaveBeenCalledWith('/api/maps-key', { cache: 'no-store' });
		expect(db.from).toHaveBeenCalledWith('system_api_keys');
		expect(db.eq).toHaveBeenCalledWith('service_name', 'google');
		expect(db.eq).toHaveBeenCalledWith('is_active', true);
	});
	it('picks up a changed table key without rebuilding', async () => {
		await fetchGoogleMapsKey();
		db.result.data.api_key = 'rotated-table-key';
		expect(await fetchGoogleMapsKey()).toBe('rotated-table-key');
	});
	it.each([{ data: null, error: null }, { data: null, error: { message: 'Database error' } }])('does not fall back to an environment key when the table lookup fails', async result => {
		db.result = result;
		await expect(fetchGoogleMapsKey()).rejects.toThrow('unavailable');
	});
	it.each([{ success: true }, { success: false, apiKey: 'ignored' }, { success: true, apiKey: '  ' }])('rejects a missing or invalid key response', async body => {
		fetchMock.mockResolvedValue(Response.json(body));
		await expect(fetchGoogleMapsKey()).rejects.toThrow('not configured');
	});
	it('propagates network errors for the display to show its error state', async () => {
		fetchMock.mockRejectedValue(new Error('Offline'));
		await expect(fetchGoogleMapsKey()).rejects.toThrow('Offline');
	});
});
