/**
 * Formats admin-authored Privacy Policy content for safe, readable display.
 *
 * If the author already wrote real HTML (contains block-level tags like
 * <p>, <div>, <h1-6>, <ul>, <ol>, <br>), it is trusted and returned as-is.
 *
 * Otherwise the text is treated as plain text: HTML special characters are
 * escaped, blank-line-separated blocks become <p> paragraphs, and single
 * newlines within a block become <br> line breaks - so pasted plain text
 * never renders as one messy run-on block.
 */
export function formatPolicyContent(raw: string): string {
	const text = (raw || '').trim();
	if (!text) return '';

	const looksLikeHtml = /<\s*(p|div|h[1-6]|ul|ol|li|br|section|table|blockquote)[\s>]/i.test(text);
	if (looksLikeHtml) return text;

	const escapeHtml = (s: string) =>
		s
			.replace(/&/g, '&amp;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;');

	return text
		.split(/\n\s*\n/)
		.map((block) => `<p>${escapeHtml(block.trim()).replace(/\n/g, '<br>')}</p>`)
		.join('');
}
