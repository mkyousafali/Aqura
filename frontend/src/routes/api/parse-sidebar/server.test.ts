import { beforeEach, expect, it, vi } from 'vitest';

const files = vi.hoisted(() => ({ readFileSync: vi.fn() }));
vi.mock('fs', () => ({ readFileSync: files.readFileSync }));
import { GET } from './+server';

const internalButtons = [
	['INTERNAL_WA_DASHBOARD', 'Dashboard'],
	['INTERNAL_WA_LIVE_CHAT', 'Live Chat'],
	['INTERNAL_WA_CONTACTS', 'Contacts'],
	['INTERNAL_WA_BROADCASTS', 'Broadcasts'],
	['INTERNAL_WA_TEMPLATES', 'Templates'],
	['INTERNAL_WA_AUTO_REPLY', 'Auto Reply & Flows'],
	['INTERNAL_WA_AI_BOT', 'AI Bot'],
	['INTERNAL_WA_CATALOG', 'Catalog'],
	['INTERNAL_WA_ACCOUNTS', 'Account'],
	['INTERNAL_WA_SETTINGS', 'Settings']
].map(([code, name]) => ({ code, name }));

beforeEach(() => {
	vi.clearAllMocks();
	files.readFileSync.mockImplementation(() => { throw new Error('No source files in production bundle'); });
});

it('lists every Internal WhatsApp button without requiring sidebar source at runtime', async () => {
	const response = await GET({} as any);
	const catalog = await response.json();
	expect(response.status).toBe(200);
	const section = catalog.sections.find((section: any) => section.name === 'Internal WhatsApp');
	expect(section.totalButtons).toBe(10);
	expect(section.subsections.flatMap((group: any) => group.buttons)).toEqual(internalButtons);
	for (const button of internalButtons) expect(catalog.catalogButtonCodes).toContain(button.code);
});

it('keeps internal and customer WhatsApp permissions separate and in sidebar section order', async () => {
	const catalog = await (await GET({} as any)).json();
	const names = catalog.sections.map((section: any) => section.name);
	expect(names.indexOf('Internal WhatsApp')).toBe(names.indexOf('WhatsApp') + 1);
	expect(names.indexOf('Email')).toBe(names.indexOf('Internal WhatsApp') + 1);
	const customer = catalog.sections.find((section: any) => section.name === 'WhatsApp');
	const codes = customer.subsections.flatMap((group: any) => group.buttons.map((button: any) => button.code));
	expect(customer.totalButtons).toBe(10);
	expect(codes).toContain('WA_LIVE_CHAT');
	expect(codes.some((code: string) => code.startsWith('INTERNAL_'))).toBe(false);
});

it('no longer diagnoses internal sidebar guards as missing from the catalog', async () => {
	files.readFileSync.mockReturnValue(internalButtons.map(button => `isButtonAllowed('${button.code}')`).join('\n'));
	const catalog = await (await GET({} as any)).json();
	expect(catalog.missingFromCatalog).toEqual([]);
	const codes = catalog.sections.flatMap((section: any) => section.subsections.flatMap((group: any) => group.buttons.map((button: any) => button.code)));
	expect(new Set(codes).size).toBe(codes.length);
});
