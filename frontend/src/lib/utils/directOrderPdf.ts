import { tFor } from '$lib/i18n';
import { directOrderRpc } from '$lib/utils/directOrderApi';
import type { DirectOrder, DirectOrderTemplate } from '$lib/types/directOrder';

interface DownloadOptions {
	signal?: AbortSignal;
	onProgress?: (done: number, total: number) => void;
}

interface TextLine {
	text: string;
	size: number;
	bold: boolean;
	color: string;
	height: number;
}

function ensureActive(signal?: AbortSignal) {
	if (signal?.aborted) throw new DOMException('Download cancelled', 'AbortError');
}

function loadPhoto(source: string, signal?: AbortSignal): Promise<HTMLImageElement> {
	return new Promise((resolve, reject) => {
		ensureActive(signal);
		const photo = new Image();
		const cleanup = () => {
			photo.onload = null;
			photo.onerror = null;
			signal?.removeEventListener('abort', cancel);
		};
		const cancel = () => {
			cleanup();
			photo.src = '';
			reject(new DOMException('Download cancelled', 'AbortError'));
		};
		photo.onload = () => { cleanup(); resolve(photo); };
		photo.onerror = () => { cleanup(); reject(new Error('Product photo unavailable')); };
		signal?.addEventListener('abort', cancel, { once: true });
		photo.src = source;
	});
}

/** A4 pages are drawn locally so Arabic and English use the browser's font shaping.
 * Metadata and private photos are loaded exclusively through the existing RPCs. */
export async function downloadDirectOrderPdf(
	template: DirectOrderTemplate,
	mobile: boolean,
	locale: string,
	{ signal, onProgress }: DownloadOptions = {}
): Promise<void> {
	const label = (key: string) => tFor(locale, `directOrder.${key}`);
	const rtl = locale === 'ar';
	const products: DirectOrder[] = [];
	let before: number | null = null;
	let order = template;
	// The list UI is paginated; a download must include every product in the order.
	while (true) {
		ensureActive(signal);
		const result = await directOrderRpc(mobile, 'direct_order_get_products', {
			p_template_id: template.id, p_before: before, p_limit: 50
		}, signal);
		if (!Array.isArray(result.orders) || !result.template?.id) throw new Error('Order unavailable');
		if (before === null) order = result.template;
		const page: DirectOrder[] = result.orders;
		products.push(...page);
		if (!result.hasMore) break;
		const next = page[page.length - 1]?.order_number;
		if (!next || (before !== null && next >= before)) throw new Error('Order pagination failed');
		before = next;
	}
	onProgress?.(0, products.length);
	const { jsPDF } = await import('jspdf');
	await document.fonts.ready;
	ensureActive(signal);
	const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4', compress: true });
	pdf.setProperties({ title: `Direct Order #${order.order_number}`, author: 'Aqura' });
	const canvas = document.createElement('canvas');
	const scale = 300 / 25.4;
	canvas.width = Math.round(210 * scale);
	canvas.height = Math.round(297 * scale);
	const ctx = canvas.getContext('2d');
	if (!ctx) throw new Error('PDF rendering unavailable');
	const margin = 12;
	const width = 186;
	const bottom = 280;
	let y = margin;
	let pageCount = 0;

	function font(size: number, bold = false) {
		ctx!.font = `${bold ? 700 : 400} ${size}px Arial, Tahoma, sans-serif`;
	}

	function wrap(value: string, maxWidth: number, size: number, bold = false): string[] {
		font(size, bold);
		const lines: string[] = [];
		for (const paragraph of value.split(/\r?\n/)) {
			let line = '';
			for (const word of paragraph.split(/\s+/).filter(Boolean)) {
				const candidate = line ? `${line} ${word}` : word;
				if (ctx!.measureText(candidate).width <= maxWidth) { line = candidate; continue; }
				if (line) { lines.push(line); line = ''; }
				// Codes and barcodes may have no spaces. Preserve every character.
				for (const character of word) {
					if (line && ctx!.measureText(line + character).width > maxWidth) {
						lines.push(line);
						line = '';
					}
					line += character;
				}
			}
			lines.push(line);
		}
		return lines;
	}

	function drawText(text: string, x: number, top: number, maxWidth: number, size = 3.4, bold = false, color = '#1f2937') {
		font(size, bold);
		ctx!.fillStyle = color;
		ctx!.textBaseline = 'top';
		ctx!.textAlign = rtl ? 'right' : 'left';
		ctx!.direction = /[\u0600-\u06ff]/.test(text) ? 'rtl' : 'ltr';
		ctx!.fillText(text, rtl ? x + maxWidth : x, top);
	}

	function finishPage() {
		ensureActive(signal);
		if (pageCount > 0) pdf.addPage('a4', 'portrait');
		pdf.addImage(canvas.toDataURL('image/jpeg', 0.93), 'JPEG', 0, 0, 210, 297);
		pageCount++;
	}

	function startPage(first = false) {
		ctx!.setTransform(1, 0, 0, 1, 0, 0);
		ctx!.fillStyle = '#ffffff';
		ctx!.fillRect(0, 0, canvas.width, canvas.height);
		ctx!.scale(scale, scale);
		y = margin;
		drawText('AQURA', margin, y, width, 3.2, true, '#2563eb');
		y += 7;
		drawText(`${label('orderNumber')} ${order.order_number}`, margin, y, width, 5.5, true, '#0f172a');
		y += 11;
		if (first) {
			const branch = (rtl ? order.branch_name_ar || order.branch_name_en : order.branch_name_en || order.branch_name_ar) || '—';
			const date = new Date(order.created_at).toLocaleString(rtl ? 'ar-SA' : 'en-GB', {
				dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Riyadh'
			});
			for (const [key, value] of [
				['shopName', order.shop_name || label('legacyOrder')],
				['shopLocation', order.shop_location || '—'],
				['branch', branch], ['createdAt', date], ['products', String(products.length)]
			]) {
				for (const line of wrap(`${label(key)}: ${value}`, width, 3.4)) {
					if (y + 5 > bottom) { finishPage(); startPage(); }
					drawText(line, margin, y, width);
					y += 5;
				}
				y += 1;
			}
		}
		ctx!.strokeStyle = '#cbd5e1';
		ctx!.lineWidth = 0.25;
		ctx!.beginPath(); ctx!.moveTo(margin, y); ctx!.lineTo(198, y); ctx!.stroke();
		y += 5;
	}

	try {
		startPage(true);
		if (products.length === 0) drawText(label('pdfNoProducts'), margin, y + 5, width);
		for (let index = 0; index < products.length; index++) {
			ensureActive(signal);
			const product = products[index];
			const data = await directOrderRpc(mobile, 'direct_order_get_photo', {
				p_template_id: order.id, p_product_id: product.id
			}, signal);
			if (Number(data.revision) !== Number(product.revision)) throw new Error('Order changed during download');
			if (!['image/jpeg', 'image/png', 'image/webp'].includes(data.mimeType) || typeof data.photoBase64 !== 'string' || !data.photoBase64) {
				throw new Error('Product photo unavailable');
			}
			const photo = await loadPhoto(`data:${data.mimeType};base64,${data.photoBase64.replace(/\s/g, '')}`, signal);
			try {
				const photoSize = 40;
				const textWidth = width - photoSize - 15;
				const lines: TextLine[] = [];
				function append(text: string, size = 3.4, bold = false, color = '#1f2937') {
					for (const line of wrap(text, textWidth, size, bold)) {
						lines.push({ text: line, size, bold, color, height: size * 1.5 });
					}
				}
				if (product.product_name_en) append(product.product_name_en, 3.8, true);
				for (const [key, value] of [
					['quantity', String(product.quantity)], ['productCode', product.product_code || '—'], ['barcode', product.barcode || '—']
				]) append(`${label(key)}: ${value}`, 3.4, key === 'quantity');
				// Very long names/codes continue on the next page without clipping.
				let offset = 0;
				while (offset < lines.length) {
					ensureActive(signal);
					const remainingHeight = lines.slice(offset).reduce((total, line) => total + line.height, 0);
					const fullHeight = Math.max(photoSize, 7 + remainingHeight) + 10;
					if (y + Math.min(fullHeight, 65) > bottom) { finishPage(); startPage(); }
					const available = bottom - y - 17;
					let end = offset;
					let textHeight = 0;
					while (end < lines.length && textHeight + lines[end].height <= available) {
						textHeight += lines[end++].height;
					}
					const height = Math.max(photoSize, 7 + textHeight) + 10;
					ctx!.fillStyle = '#f8fafc';
					ctx!.fillRect(margin, y, width, height);
					ctx!.strokeStyle = '#e2e8f0';
					ctx!.strokeRect(margin, y, width, height);
					const photoX = rtl ? 198 - 5 - photoSize : margin + 5;
					const textX = rtl ? margin + 5 : margin + photoSize + 10;
					const ratio = Math.min(photoSize / photo.naturalWidth, photoSize / photo.naturalHeight);
					const imageWidth = photo.naturalWidth * ratio;
					const imageHeight = photo.naturalHeight * ratio;
					ctx!.drawImage(photo, photoX + (photoSize - imageWidth) / 2, y + 5 + (photoSize - imageHeight) / 2, imageWidth, imageHeight);
					drawText(`${label('productNumber')} ${product.order_number}`, textX, y + 5, textWidth, 3.2, true, '#2563eb');
					let lineY = y + 12;
					for (const line of lines.slice(offset, end)) {
						drawText(line.text, textX, lineY, textWidth, line.size, line.bold, line.color);
						lineY += line.height;
					}
					y += height + 4;
					offset = end;
					if (offset < lines.length) { finishPage(); startPage(); }
				}
			} finally { photo.src = ''; }
			onProgress?.(index + 1, products.length);
			// Let mobile browsers paint progress between products.
			await new Promise<void>((resolve) => setTimeout(resolve, 0));
		}
		finishPage();
		for (let page = 1; page <= pageCount; page++) {
			pdf.setPage(page);
			pdf.setFont('helvetica', 'normal');
			pdf.setFontSize(9);
			pdf.setTextColor('#64748b');
			pdf.text(`AQURA | #${order.order_number}`, margin, 289);
			pdf.text(`${page} / ${pageCount}`, 198, 289, { align: 'right' });
		}
		ensureActive(signal);
		const shop = (order.shop_name || '').replace(/[<>:"/\\|?*\u0000-\u001f]/g, '').trim().slice(0, 80);
		await pdf.save(`Direct_Order_${order.order_number}${shop ? `_${shop}` : ''}.pdf`, { returnPromise: true });
	} finally {
		canvas.width = 0;
		canvas.height = 0;
	}
}
