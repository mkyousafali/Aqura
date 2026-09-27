import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const db = vi.hoisted(() => ({ from: vi.fn(), eq: vi.fn(), result: { data: { api_key: 'test-openai-key' }, error: null } as any }));
vi.mock('@supabase/supabase-js', () => ({ createClient: () => db }));
vi.mock('$env/dynamic/private', () => ({ env: { VITE_SUPABASE_URL: 'https://database.test', VITE_SUPABASE_SERVICE_KEY: 'test-db-key' } }));

import { generateOpenAIText } from './openaiText';
import { POST as transform } from '../../routes/api/transform-text/+server';
import { POST as groupName } from '../../routes/api/generate-group-name/+server';
import { POST as warning } from '../../routes/api/generate-warning/+server';
import { POST as incident } from '../../routes/api/generate-incident-warning/+server';
import { POST as scan } from '../../routes/api/scan-request-extract/+server';
import { POST as bill } from '../../routes/api/check-original-bill/+server';
import { POST as buttons } from '../../routes/api/detect-buttons-ai/+server';
import { POST as textEndpoint } from '../../routes/api/openai-text/+server';
import { POST as googleProxy } from '../../routes/api/google-ai-proxy/+server';

const fetchMock = vi.fn();
const completion = (content: string, extra = {}) => Response.json({ choices: [{ message: { content }, finish_reason: 'stop', ...extra }] });
const call = (handler: any, body: any) => handler({ request: new Request('http://localhost/api/test', {
	method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
}) });
const sent = () => JSON.parse(fetchMock.mock.calls.at(-1)![1].body);

beforeEach(() => {
	vi.clearAllMocks();
	db.result = { data: { api_key: 'test-openai-key' }, error: null };
	const chain: any = { select: () => chain, limit: () => chain, maybeSingle: async () => db.result, single: async () => db.result };
	db.eq.mockImplementation(() => chain);
	chain.eq = db.eq;
	db.from.mockReturnValue(chain);
	fetchMock.mockReset().mockImplementation(async () => completion('Generated text'));
	vi.stubGlobal('fetch', fetchMock);
	vi.spyOn(console, 'log').mockImplementation(() => {});
	vi.spyOn(console, 'error').mockImplementation(() => {});
});
afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks(); });

describe('OpenAI migration: keys and provider failures', () => {
	it('reads the active OpenAI table row on each call, including key rotation', async () => {
		expect(await generateOpenAIText({ prompt: 'Rewrite this' })).toBe('Generated text');
		expect(db.from).toHaveBeenCalledWith('system_api_keys');
		expect(db.eq).toHaveBeenCalledWith('service_name', 'openai');
		expect(db.eq).toHaveBeenCalledWith('is_active', true);
		expect(fetchMock.mock.calls[0][0]).toBe('https://api.openai.com/v1/chat/completions');
		expect(fetchMock.mock.calls[0][1].headers.Authorization).toBe('Bearer test-openai-key');
		db.result.data.api_key = 'rotated-key';
		await generateOpenAIText({ prompt: 'Translate this' });
		expect(fetchMock.mock.calls[1][1].headers.Authorization).toBe('Bearer rotated-key');
		expect(db.eq).not.toHaveBeenCalledWith('service_name', 'google_gemini');
	});
	it.each([{ data: null, error: null }, { data: null, error: { message: 'Database unavailable' } }])('fails without an active table key and never falls back to Gemini', async result => {
		db.result = result;
		await expect(generateOpenAIText({ prompt: 'Rewrite' })).rejects.toThrow('active OpenAI key');
		expect(fetchMock).not.toHaveBeenCalled();
	});
	it('redacts the key from upstream failures', async () => {
		fetchMock.mockResolvedValue(Response.json({ error: { message: 'Invalid key test-openai-key' } }, { status: 401 }));
		await expect(generateOpenAIText({ prompt: 'Rewrite' })).rejects.toThrow('OpenAI API error 401: Invalid key [redacted]');
	});
	it.each([
		['truncated', () => completion('partial', { finish_reason: 'length' }), 'incomplete'],
		['refused', () => completion('', { message: { refusal: 'Cannot comply' } }), 'could not process'],
		['empty', () => completion(''), 'empty response'],
		['malformed', () => new Response('not JSON'), 'empty response']
	])('rejects %s output', async (_name, response, message) => {
		fetchMock.mockResolvedValue((response as () => Response)());
		await expect(generateOpenAIText({ prompt: 'Extract' })).rejects.toThrow(message as string);
	});
	it('reports timeouts clearly', async () => {
		fetchMock.mockRejectedValue(new DOMException('Timeout', 'TimeoutError'));
		await expect(generateOpenAIText({ prompt: 'Extract' })).rejects.toThrow('timed out');
	});
});

describe('migrated feature response contracts', () => {
	it('rewrites text with the original language and response field', async () => {
		const response = await call(transform, { text: 'Original wording', language: 'ar' });
		expect(await response.json()).toEqual({ success: true, transformedText: 'Generated text' });
		expect(sent().messages[0].content).toContain('Arabic');
		expect(sent().messages.at(-1).content[0].text).toContain('Original wording');
	});
	it('returns bilingual group names as JSON', async () => {
		fetchMock.mockResolvedValue(completion(JSON.stringify({ nameEn: 'Assorted Drinks', nameAr: 'مشروبات متنوعة' })));
		expect(await (await call(groupName, { productNames: ['Orange drink', 'Lemon drink'] })).json())
			.toEqual({ success: true, nameEn: 'Assorted Drinks', nameAr: 'مشروبات متنوعة' });
		expect(sent().response_format.type).toBe('json_object');
	});
	it('preserves both HR warning response fields', async () => {
		const taskResponse = await call(warning, { assignment: { assigned_to: 'Test Employee', task_title: 'Test Task' }, language: 'en' });
		expect(taskResponse.status).toBe(200);
		expect(await taskResponse.json()).toMatchObject({ warning: 'Generated text' });
		const incidentResponse = await call(incident, { languages: ['ar', 'en'], whatHappened: 'Test incident', recourseType: 'warning' });
		expect(incidentResponse.status).toBe(200);
		expect(await incidentResponse.json()).toEqual({ success: true, generatedText: 'Generated text' });
	});
	it('scans an image with strict fields and returns the ISO date and terminal ID', async () => {
		fetchMock.mockResolvedValue(completion(JSON.stringify({ date: '27/09/2026', date_iso: '2026-09-27', time: '10:30', terminal_id: '001234', statement_match_number: '0005' })));
		expect(await (await call(scan, { imageBase64: 'aW1hZ2U=', mimeType: 'image/jpeg' })).json())
			.toEqual({ success: true, date: '2026-09-27', time: '10:30', terminalId: '001234', statementMatchNumber: '0005' });
		expect(sent().messages.at(-1).content[1]).toEqual({ type: 'image_url', image_url: { url: 'data:image/jpeg;base64,aW1hZ2U=', detail: 'high' } });
		expect(sent().response_format.json_schema).toMatchObject({ strict: true, schema: { type: 'object', additionalProperties: false } });
	});
	it('keeps the payment-network amount scan mode', async () => {
		fetchMock.mockResolvedValue(completion('{"amount":"1,639.02 SAR"}'));
		expect(await (await call(scan, { imageBase64: 'aW1hZ2U=', mode: 'amount' })).json()).toEqual({ success: true, amount: '1639.02' });
		expect(sent().response_format.json_schema.schema.required).toEqual(['amount']);
	});
	it.each(['application/pdf', 'image/png'])('checks %s bills and preserves deterministic VAT/date matching', async mimeType => {
		fetchMock.mockResolvedValueOnce(new Response('document bytes', { headers: { 'Content-Type': mimeType } }))
			.mockResolvedValueOnce(completion(JSON.stringify({ vendor_name: 'Supplier LLC', vendor_vat_number: '300123', bill_amount_including_vat: '115', bill_date: '27/09/2026', bill_date_iso: '2026-09-27', vendor_name_matches: false, vendor_vat_matches: true, bill_amount_matches: true })));
		const response = await call(bill, { url: 'https://storage.test/bill', localVendorName: 'Supplier', localVendorVat: '300123', localBillAmount: 115, localBillDate: '2026-09-27' });
		expect(response.status).toBe(200);
		expect(await response.json()).toMatchObject({ success: true, vendorNameMatches: false, vendorVatMatches: true, vendorMatches: true, billDateMatches: true });
		const attachment = sent().messages.at(-1).content[1];
		if (mimeType === 'application/pdf') expect(attachment.file.file_data).toMatch(/^data:application\/pdf;base64,/);
		else expect(attachment.image_url.url).toMatch(/^data:image\/png;base64,/);
	});
	it('normalizes detected sidebar buttons', async () => {
		fetchMock.mockResolvedValue(completion('{"sections":[{"name":"HR","subsections":[{"name":"Staff","buttons":[{"code":"employee","name":"Employees"}]}]}]}'));
		const response = await call(buttons, { sidebarStructure: '<button>Employees</button>' });
		const result = await response.json();
		expect(result.success).toBe(true);
		expect(result.sections[0].totalButtons).toBe(1);
		expect(result.sections[0].subsections[0]).toMatchObject({ buttonCount: 1, buttons: [{ code: 'EMPLOYEE', name: 'Employees' }] });
	});
	it('serves receipt/product text callers without exposing credentials', async () => {
		fetchMock.mockResolvedValue(completion('{"billNumber":"1234"}'));
		const response = await call(textEndpoint, { prompt: 'Extract receipt JSON', jsonMode: true });
		expect(await response.json()).toEqual({ text: '{"billNumber":"1234"}' });
		expect(sent().response_format.type).toBe('json_object');
	});
	it('rejects empty or invalid requests before calling a provider', async () => {
		for (const [handler, input] of [[textEndpoint, { prompt: '' }], [textEndpoint, { prompt: 'Hi', systemPrompt: {} }], [scan, {}], [transform, { text: '' }], [groupName, { productNames: [] }], [buttons, {}]] as const) {
			expect((await call(handler, input)).status).toBe(400);
		}
		expect(fetchMock).not.toHaveBeenCalled();
	});
	it('keeps Google Vision separate and rejects the removed generic Gemini service', async () => {
		fetchMock.mockResolvedValue(Response.json({ responses: [{ fullTextAnnotation: { text: 'Receipt' } }] }));
		const response = await call(googleProxy, { service: 'vision', body: { requests: [] } });
		expect((await response.json()).responses[0].fullTextAnnotation.text).toBe('Receipt');
		expect(db.eq).toHaveBeenCalledWith('service_name', 'google');
		expect(fetchMock.mock.calls[0][0]).toContain('vision.googleapis.com');
		expect((await call(googleProxy, { service: 'gemini', body: {} })).status).toBe(400);
		expect(fetchMock).toHaveBeenCalledTimes(1);
	});
});
