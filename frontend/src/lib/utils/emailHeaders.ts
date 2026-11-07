import { decodeMimeHeader } from '../../../../database/edge-functions/_shared/emailHeaders';

export { decodeMimeHeader };

export function emailSenderLabel(name: string | null | undefined, address: string | null | undefined): string {
	const decoded = decodeMimeHeader(name).trim();
	const email = address?.trim() || '';
	// Unsupported or damaged names must not hide a usable sender address.
	const readableName = /=\?[^?]*\?/.test(decoded) ? '' : decoded;
	if (!readableName || readableName.toLowerCase() === email.toLowerCase()) return email || 'Unknown sender';
	return email ? `${readableName} <${email}>` : readableName;
}

export function decodeMessageHeaders<T extends { from_name?: string; subject?: string }>(message: T): T {
	return { ...message, from_name: decodeMimeHeader(message.from_name), subject: decodeMimeHeader(message.subject) };
}
