import { beforeEach, expect, it, vi } from 'vitest';
const db = vi.hoisted(() => ({ from: vi.fn(), update: vi.fn(), insert: vi.fn(), delete: vi.fn(), result: { data: { id: 1, service_name: 'openai', api_key: 'new' }, error: null } as any }));
vi.mock('@supabase/supabase-js', () => ({ createClient: () => db }));
vi.mock('$env/dynamic/private', () => ({ env: { VITE_SUPABASE_URL: 'https://database.test', VITE_SUPABASE_SERVICE_KEY: 'test' } }));
import { GET, POST } from './+server';
const call = (body: unknown) => POST({ request: new Request('http://localhost/api/system-api-keys', { method: 'POST', body: JSON.stringify(body) }) } as any);
beforeEach(() => {
 vi.clearAllMocks();
 db.result = { data: { id: 1, service_name: 'openai', api_key: 'new' }, error: null };
 const chain: any = { eq: () => chain, select: () => chain, maybeSingle: async () => db.result, order: async () => db.result };
 for (const method of [db.from, db.update, db.insert, db.delete]) method.mockReturnValue(chain);
 Object.assign(chain, { update: db.update, insert: db.insert, delete: db.delete });
});
it('rotates only the key, preserving activation and description', async () => {
 const res = await call({ action: 'rotate', id: 1, api_key: ' new ', is_active: true, description: 'ignored' });
 expect(res.status).toBe(200);
 expect(db.update).toHaveBeenCalledWith({ api_key: 'new' });
 expect((await res.json()).key.api_key).toBe('new');
 expect(res.headers.get('cache-control')).toBe('no-store');
});
it.each(['', '  ', null, 12])('rejects invalid replacement %s', async api_key => {
 expect((await call({ action: 'rotate', id: 1, api_key })).status).toBe(400);
 expect(db.update).not.toHaveBeenCalled();
});
it.each(['pixabay', 'google_search_engine_id'])('blocks retired service %s', async service_name => {
 expect((await call({ action: 'insert', service_name, api_key: 'new' })).status).toBe(400);
 expect(db.insert).not.toHaveBeenCalled();
});
it('adds a missing service with current usage description', async () => {
 expect((await call({ action: 'insert', service_name: ' google_gemini ', api_key: ' new ' })).status).toBe(200);
 expect(db.insert).toHaveBeenCalledWith({ service_name: 'google_gemini', api_key: 'new', is_active: true, description: 'Google Gemini: WhatsApp automatic AI replies only.' });
});
it('reports duplicate service instead of claiming success', async () => {
 db.result = { data: null, error: { code: '23505' } };
 expect((await call({ action: 'insert', service_name: 'openai', api_key: 'new' })).status).toBe(409);
});
it.each(['delete', 'toggle', 'rotate'])('reports a missing row for %s', async action => {
 db.result.data = null;
 expect((await call({ action, id: 99, api_key: 'new', is_active: false })).status).toBe(404);
});
it('deletes an existing row', async () => {
 expect((await call({ action: 'delete', id: 1 })).status).toBe(200);
 expect(db.delete).toHaveBeenCalledOnce();
});
it('disables a key', async () => {
 expect((await call({ action: 'toggle', id: 1, is_active: false })).status).toBe(200);
 expect(db.update).toHaveBeenCalledWith({ is_active: false });
});
it('rejects invalid active state', async () => {
 expect((await call({ action: 'toggle', id: 1, is_active: 'false' })).status).toBe(400);
});
it('does not leak database error details', async () => {
 db.result = { data: null, error: { message: 'sensitive-key-value' } };
 const res = await call({ action: 'delete', id: 1 });
 expect(res.status).toBe(500);
 expect(await res.text()).not.toContain('sensitive-key-value');
});
it('does not cache the key list', async () => {
 expect((await GET({} as any)).headers.get('cache-control')).toBe('no-store');
});
