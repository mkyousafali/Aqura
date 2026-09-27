import { afterEach, describe, expect, it, vi } from 'vitest';
import { correctAndTranslateProductName, correctSpelling, translateText } from './translationService';

afterEach(() => vi.unstubAllGlobals());

describe('text tools through OpenAI', () => {
	it('translates through the server endpoint and returns its text', async () => {
		const fetch = vi.fn().mockResolvedValue(Response.json({ text: 'تفاح' }));
		vi.stubGlobal('fetch', fetch);
		expect(await translateText({ text: 'Apple', targetLanguage: 'ar' })).toBe('تفاح');
		expect(fetch.mock.calls[0][0]).toBe('/api/openai-text');
		expect(JSON.parse(fetch.mock.calls[0][1].body).prompt).toContain('Arabic');
	});
	it('corrects and translates product names using JSON output', async () => {
		const fetch = vi.fn().mockResolvedValue(Response.json({ text: '{"corrected_en":"American Apple","arabic":"تفاح أمريكي"}' }));
		vi.stubGlobal('fetch', fetch);
		expect(await correctAndTranslateProductName('apple amerca')).toEqual({ en: 'American Apple', ar: 'تفاح أمريكي' });
		expect(JSON.parse(fetch.mock.calls[0][1].body).jsonMode).toBe(true);
	});
	it.each([
		['ml', 'Malayalam'], ['ur', 'Urdu'], ['hi', 'Hindi'], ['bn', 'Bangla'],
		['ta', 'Tamil'], ['am', 'Amharic'], ['fr', 'French'], ['tl', 'Filipino']
	])('keeps the selected %s language for HR and chat translations', async (code, name) => {
		const fetch = vi.fn().mockResolvedValue(Response.json({ text: 'Translated report' }));
		vi.stubGlobal('fetch', fetch);
		expect(await translateText({ text: 'Employee report\nAmount: 250 SAR', targetLanguage: code })).toBe('Translated report');
		const body = JSON.parse(fetch.mock.calls[0][1].body);
		expect(body.prompt).toContain(`to ${name}.`);
		expect(body.prompt).toContain('Detect the source language');
		expect(body.prompt).toContain('Employee report\nAmount: 250 SAR');
	});
	it('honors an explicit source language and allows full reports beyond the short product-name budget', async () => {
		const fetch = vi.fn().mockResolvedValue(Response.json({ text: 'Full translated report' }));
		vi.stubGlobal('fetch', fetch);
		const text = 'Report paragraph.\n'.repeat(150);
		await translateText({ text, sourceLanguage: 'ur', targetLanguage: 'ml' });
		const body = JSON.parse(fetch.mock.calls[0][1].body);
		expect(body.prompt).toContain('from Urdu to Malayalam');
		expect(body.prompt).toContain(text);
		expect(body.maxTokens).toBeGreaterThan(500);
	});
	it('skips empty input without an API call', async () => {
		const fetch = vi.fn();
		vi.stubGlobal('fetch', fetch);
		expect(await translateText({ text: '  ', targetLanguage: 'ar' })).toBe('');
		expect(fetch).not.toHaveBeenCalled();
	});
	it('preserves spelling fallback while surfacing translation failures', async () => {
		vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => Response.json({ error: 'OpenAI unavailable' }, { status: 503 })));
		expect(await correctSpelling('orig text')).toBe('orig text');
		await expect(translateText({ text: 'Apple', targetLanguage: 'ar' })).rejects.toThrow('OpenAI unavailable');
	});
});
