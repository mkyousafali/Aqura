// RFC 2047 encoded words are used in display names and subjects, not addresses.
export function decodeMimeHeader(value: string | null | undefined): string {
	const input = (value || '').replace(/\r?\n[ \t]+/g, ' ');
	const words = /=\?([^?\s]+)\?([bq])\?([^?\r\n]*)\?=/gi;
	let result = '';
	let end = 0;
	let previousDecoded = false;
	for (const match of input.matchAll(words)) {
		const gap = input.slice(end, match.index);
		let decoded: string;
		try {
			let bytes: Uint8Array;
			if (match[2].toLowerCase() === 'b') {
				if (!/^[A-Za-z0-9+/]*={0,2}$/.test(match[3])) throw new Error('Invalid base64');
				bytes = Uint8Array.from(atob(match[3]), c => c.charCodeAt(0));
			} else {
				const encoded = match[3].replace(/_/g, ' ');
				if (/=(?![\da-f]{2})/i.test(encoded) || /[^\x20-\x7e]/.test(encoded)) {
					throw new Error('Invalid quoted printable');
				}
				const octets = encoded.replace(/=([\da-f]{2})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
				bytes = Uint8Array.from(octets, c => c.charCodeAt(0));
			}
			decoded = new TextDecoder(match[1], { fatal: true }).decode(bytes);
		} catch {
			result += gap + match[0];
			end = match.index! + match[0].length;
			previousDecoded = false;
			continue;
		}
		// Whitespace between successfully decoded adjacent words is not displayed.
		result += (previousDecoded && /^[ \t]*$/.test(gap) ? '' : gap) + decoded;
		end = match.index! + match[0].length;
		previousDecoded = true;
	}
	return result + input.slice(end);
}

export function parseEmailHeaders(fetchData: string) {
	const block = fetchData.split(/\r?\n\r?\n/, 1)[0].replace(/\r?\n[ \t]+/g, ' ');
	const header = (name: string) => block.match(new RegExp(`^${name}:[ \\t]*([^\\r\\n]*)`, 'im'))?.[1].trim() || '';
	const from = header('From');
	const address = from.match(/<([^<>]+)>/);
	const name = address ? from.slice(0, address.index).trim().replace(/^"(.*)"$/, '$1').replace(/\\(["\\])/g, '$1') : '';
	return {
		subject: decodeMimeHeader(header('Subject')),
		from: address ? address[1].trim() : from,
		fromName: decodeMimeHeader(name),
		date: header('Date'),
		messageId: header('Message-ID'),
		inReplyTo: header('In-Reply-To'),
		references: header('References')
	};
}
