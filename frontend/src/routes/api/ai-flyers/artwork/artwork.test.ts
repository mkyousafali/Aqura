import { beforeEach, describe, expect, it, vi } from 'vitest';
const db = vi.hoisted(() => ({ from: vi.fn() }));
vi.mock('@supabase/supabase-js', () => ({ createClient: () => db }));
vi.mock('$env/dynamic/private', () => ({ env: { VITE_SUPABASE_URL: 'https://db.test', SUPABASE_SERVICE_ROLE_KEY: 'db-key' } }));
import { POST } from './+server';
const offerId = 'a6eac951-857b-403d-a5ed-21c39c28de87';
function call(fetch: any, origin = 'http://localhost', body: any = { offerId, offerName: 'Week 2' }) {
  return POST({ request: new Request('http://localhost/api/ai-flyers/artwork', { method: 'POST', headers: { origin, 'Content-Type': 'application/json' }, body: JSON.stringify(body) }), url: new URL('http://localhost/api/ai-flyers/artwork'), fetch } as any);
}
beforeEach(() => {
  db.from.mockReset();
  db.from.mockImplementation((table: string) => {
    if (!['flyer_offers', 'system_api_keys'].includes(table)) throw new Error('Unexpected table');
    const data = table === 'flyer_offers' ? { id: offerId } : { api_key: 'secret-test' };
    const chain: any = { then: (resolve: any) => Promise.resolve({ data }).then(resolve) };
    for (const method of ['select', 'eq', 'single', 'limit', 'maybeSingle']) chain[method] = () => chain;
    return chain;
  });
});
describe('reference-guided OpenAI artwork', () => {
  it('sends a single multipart style reference and returns binary artwork, without product/template queries', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(new Response('reference', { headers: { 'Content-Type': 'image/jpeg' } })).mockResolvedValueOnce(Response.json({ data: [{ b64_json: Buffer.from('artwork').toString('base64') }] }));
    const response = await call(fetch);
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('image/jpeg');
    expect(await response.text()).toBe('artwork');
    const [endpoint, options] = fetch.mock.calls[1];
    expect(endpoint).toBe('https://api.openai.com/v1/images/edits');
    expect(options.body).toBeInstanceOf(FormData);
    expect(options.body.get('model')).toBe('gpt-image-2');
    expect(options.body.getAll('image[]')).toHaveLength(1);
    expect(options.body.get('prompt')).toContain('NO letters, numbers');
    expect(options.headers['Content-Type']).toBeUndefined();
  });
  it('rejects cross-origin requests and unexpected image/template payloads before calling the provider', async () => {
    const fetch = vi.fn();
    expect((await call(fetch, 'https://elsewhere.test')).status).toBe(403);
    expect((await call(fetch, 'http://localhost', { offerId, offerName: 'Sale', template: 'large payload' })).status).toBe(400);
    expect(fetch).not.toHaveBeenCalled();
  });
  it('redacts provider credentials and never substitutes a flat design on failure', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(new Response('reference')).mockResolvedValueOnce(Response.json({ error: { message: 'Denied secret-test' } }, { status: 403 }));
    const response = await call(fetch);
    expect(response.status).toBe(502);
    expect((await response.json()).error).toBe('OpenAI artwork service 403: Denied [redacted]');
  });
});
