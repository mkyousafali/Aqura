import { describe, expect, it } from 'vitest';
import { decodeMessageHeaders, decodeMimeHeader, emailSenderLabel } from './emailHeaders';
import { parseEmailHeaders } from '../../../../database/edge-functions/_shared/emailHeaders';

const encoded = (text: string) => `=?UTF-8?B?${btoa(String.fromCharCode(...new TextEncoder().encode(text)))}?=`;

describe('email header decoding', () => {
	it('decodes UTF-8 base64 names, including Arabic, without corrupting characters', () => {
		for (const name of ['Santos Júnior', 'أحمد علي', '日本語']) {
			expect(decodeMimeHeader(encoded(name))).toBe(name);
		}
	});

	it('decodes quoted printable names with their declared character set', () => {
		expect(decodeMimeHeader('=?utf-8?q?Santos_J=C3=BAnior?=')).toBe('Santos Júnior');
		expect(decodeMimeHeader('=?ISO-8859-1?Q?Andr=E9?=')).toBe('André');
	});

	it('joins adjacent encoded words across folded header lines', () => {
		expect(decodeMimeHeader(`${encoded('أحمد ')}\r\n\t${encoded('علي')}`)).toBe('أحمد علي');
		expect(decodeMimeHeader(`From ${encoded('أحمد')} via Support`)).toBe('From أحمد via Support');
	});

	it('leaves plain text and unsupported or damaged encoded words intact', () => {
		for (const text of ['Plain Sender', '=?UTF-8?B?%%%?=', '=?UTF-8?Q?bad=ZZ?=', '=?unknown-charset?B?QQ==?=', '=?UTF-8?B?/w==?=']) {
			expect(decodeMimeHeader(text)).toBe(text);
		}
		expect(decodeMimeHeader(null)).toBe('');
	});

	it('parses folded sender and subject headers without decoding routing addresses', () => {
		const result = parseEmailHeaders(`* 1 FETCH (BODY[HEADER] {300}\r\nFrom: ${encoded('Santos ')}\r\n ${encoded('Júnior')} <sender@example.com>\r\nSubject: ${encoded('مرحبا')}\r\nMessage-ID: <message@example.com>\r\nIn-Reply-To: <parent@example.com>\r\nReferences: <first@example.com>\r\n <parent@example.com>\r\n\r\nFrom: forged@example.com`);
		expect(result).toMatchObject({
			fromName: 'Santos Júnior', from: 'sender@example.com', subject: 'مرحبا',
			messageId: '<message@example.com>', inReplyTo: '<parent@example.com>',
			references: '<first@example.com> <parent@example.com>'
		});
	});

	it('handles quoted, empty and address-only sender names', () => {
		expect(parseEmailHeaders('From: "Doe, Jane" <jane@example.com>\r\n\r\n')).toMatchObject({ fromName: 'Doe, Jane', from: 'jane@example.com' });
		expect(parseEmailHeaders('From: "" <jane@example.com>\r\n\r\n')).toMatchObject({ fromName: '', from: 'jane@example.com' });
		expect(parseEmailHeaders('From: jane@example.com\r\n\r\n')).toMatchObject({ fromName: '', from: 'jane@example.com' });
	});

	it('keeps address-looking text inside encoded names out of the routing address', () => {
		expect(parseEmailHeaders(`From: ${encoded('Support <other@example.com>')} <sender@example.com>\r\n\r\n`).from).toBe('sender@example.com');
	});

	it('shows the actual address alongside a decoded name, with safe fallbacks', () => {
		expect(emailSenderLabel(encoded('Santos Júnior'), 'sender@example.com')).toBe('Santos Júnior <sender@example.com>');
		expect(emailSenderLabel('=?UTF-8?B?%%%?=', 'sender@example.com')).toBe('sender@example.com');
		expect(emailSenderLabel('sender@example.com', 'sender@example.com')).toBe('sender@example.com');
		expect(emailSenderLabel('', 'sender@example.com')).toBe('sender@example.com');
		expect(emailSenderLabel(null, null)).toBe('Unknown sender');
	});

	it('decodes saved message headers without altering addresses, bodies or identifiers', () => {
		const message = { id: 'message-id', from_name: encoded('أحمد'), from_address: 'sender@example.com', subject: encoded('مرحبا'), text_body: 'Original body' };
		expect(decodeMessageHeaders(message)).toEqual({ ...message, from_name: 'أحمد', subject: 'مرحبا' });
		expect(message.from_name).toBe(encoded('أحمد'));
	});
});
