import { tFor } from '$lib/i18n';
import type { BusinessCounterProfile } from '$lib/types/businessCounter';
import { bakeryDate } from '$lib/types/bakery';
import type { CoffeeOtherPayment } from '$lib/types/coffeeOtherPayments';
import type { CoffeeOtherExpense } from '$lib/types/coffeeOtherExpenses';

export interface CounterPdfTotals {
	salesIncludingVat: number | null;
	salesExcludingVat: number | null;
	outputVat: number | null;
	rent: number | null;
	inputVat: number | null;
	initialCapital: number;
	payableBeforePayments: number | null;
	vendorPayments: number | null;
	otherPayments: number | null;
	salesPaidExpenses: number | null;
	operatorPaidExpenses: number | null;
	expensesIncludingVat: number | null;
	operatorsProfit: number | null;
	netPayable: number | null;
}

export interface CounterPdfPeriod {
	date: string;
	percentage: number | null;
	salesIncludingVat: number;
	salesExcludingVat: number;
	rent: number;
	inputVat: number;
	expensesIncludingVat: number;
	receivable: number;
	profit: number;
}

export interface CounterPdfReport {
	profile: BusinessCounterProfile;
	locale: 'en' | 'ar';
	logoUrl?: string;
	startDate: string;
	asOfDate: string;
	loadedAt: string;
	generatedAt: string;
	scope: string;
	combined: boolean;
	totals: CounterPdfTotals;
	daily: CounterPdfPeriod[];
	monthly: CounterPdfPeriod[];
	branches: { name: string; sales: number; salesExcludingVat: number; outputVat: number; stock: number | null }[];
	stockValue: number | null;
	cashAndBank: number | null;
	journalPayments: number | null;
	withdrawals: CoffeeOtherPayment[];
	otherExpenses: CoffeeOtherExpense[];
}

interface PdfColumn { label: string; width: number; numeric?: boolean }
interface PdfRow { cells: string[]; total?: boolean }

/** Browser canvas preserves native Arabic shaping and embeds the result in A4
 * pages. A fresh canvas is reused per page, rather than slicing a huge screenshot. */
export async function downloadBusinessCounterReportPdf(report: CounterPdfReport, signal?: AbortSignal): Promise<void> {
	if (report.asOfDate > bakeryDate() || report.startDate > report.asOfDate) throw new Error('Invalid reporting period');
	const { jsPDF } = await import('jspdf');
	const rtl = report.locale === 'ar';
	const label = (key: string) => tFor(report.locale, `businessReportPdf.${key}`);
	const counterLabel = (key: string) => tFor(report.locale, `${report.profile.localeKey}.${key}`);
	const title = tFor(report.locale, report.profile.titleKey);
	const isCoffee = report.profile.id === 'coffee-counter';
	const formatter = new Intl.NumberFormat(rtl ? 'ar-SA' : 'en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	const amount = (value: number | null) => value === null ? label('unavailable') : formatter.format(value);
	const integer = new Intl.NumberFormat(rtl ? 'ar-SA' : 'en-GB');
	const date = (value: string) => value.split('-').reverse().join('/');
	const timestamp = (value: string) => new Intl.DateTimeFormat(rtl ? 'ar-SA-u-ca-gregory' : 'en-GB', {
		dateStyle: 'medium', timeStyle: 'medium', timeZone: 'Asia/Riyadh'
	}).format(new Date(value));
	const loadedDateParts = new Intl.DateTimeFormat('en-GB', {
		year: 'numeric', month: '2-digit', day: '2-digit', timeZone: 'Asia/Riyadh'
	}).formatToParts(new Date(report.loadedAt));
	const loadedDate = ['year', 'month', 'day'].map(type => loadedDateParts.find(part => part.type === type)?.value).join('-');
	const cutoff = loadedDate === report.asOfDate ? timestamp(report.loadedAt) : `${date(report.asOfDate)} 23:59:59`;
	function active() { if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError'); }
	active();
	await document.fonts.ready;
	let logo: HTMLImageElement | null = null;
	let logoObjectUrl = '';
	if (report.logoUrl) {
		// Fetch as a blob so drawing the uploaded logo cannot taint the PDF canvas.
		const response = await fetch(report.logoUrl, { signal });
		if (!response.ok) throw new Error('Report logo unavailable');
		logoObjectUrl = URL.createObjectURL(await response.blob());
		try {
			logo = new Image();
			logo.src = logoObjectUrl;
			await logo.decode();
		} catch (error) { URL.revokeObjectURL(logoObjectUrl); throw error; }
	}
	const pdf = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4', compress: true });
	pdf.setProperties({ title: `${title} - ${counterLabel('allTimeReport')} - ${report.asOfDate}`, author: title });
	const canvas = document.createElement('canvas');
	const scale = 240 / 25.4;
	canvas.width = Math.round(297 * scale);
	canvas.height = Math.round(210 * scale);
	const ctx = canvas.getContext('2d');
	if (!ctx) { if (logoObjectUrl) URL.revokeObjectURL(logoObjectUrl); throw new Error('PDF canvas unavailable'); }
	const ink = '#183b35', green = '#087c68', muted = '#62766f', gold = '#bc9152';
	const margin = 14, width = 269, bottom = 190;
	let y = 0, pageCount = 0;
	const leading = 4.6;
	function font(size: number, bold = false) { ctx!.font = `${bold ? 700 : 400} ${size}px Arial, Tahoma, sans-serif`; }
	function wrap(value: string, max: number, size = 3.2, bold = false): string[] {
		font(size, bold);
		const lines: string[] = [];
		for (const paragraph of value.split(/\r?\n/)) {
			let line = '';
			for (const word of paragraph.split(/\s+/).filter(Boolean)) {
				const next = line ? `${line} ${word}` : word;
				if (ctx!.measureText(next).width <= max) { line = next; continue; }
				if (line) lines.push(line);
				line = '';
				for (const character of word) {
					if (line && ctx!.measureText(line + character).width > max) { lines.push(line); line = ''; }
					line += character;
				}
			}
			lines.push(line);
		}
		return lines;
	}
	function text(value: string, x: number, top: number, w: number, size = 3.2, bold = false, color = ink, numeric = false) {
		font(size, bold);
		ctx!.fillStyle = color;
		ctx!.textBaseline = 'top';
		ctx!.textAlign = numeric || rtl ? 'right' : 'left';
		ctx!.direction = /[\u0600-\u06ff]/.test(value) && !numeric ? 'rtl' : 'ltr';
		ctx!.fillText(value, numeric || rtl ? x + w : x, top);
	}
	function box(x: number, top: number, w: number, h: number, color: string) { ctx!.fillStyle = color; ctx!.fillRect(x, top, w, h); }
	function line(top: number) { box(margin, top, width, .25, '#dce7e2'); }
	function finish() {
		active();
		line(195);
		text(`${label('currency')} | ${label('riyadhTime')}`, margin, 198, width, 2.6, false, muted);
		if (pageCount > 0) pdf.addPage('a4', 'landscape');
		pdf.addImage(canvas.toDataURL('image/jpeg', .94), 'JPEG', 0, 0, 297, 210);
		pageCount++;
	}
	function start(section: string, first = false) {
		active();
		ctx!.setTransform(1, 0, 0, 1, 0, 0);
		box(0, 0, canvas.width, canvas.height, '#ffffff');
		ctx!.scale(scale, scale);
		box(0, 0, 297, 2.5, green);
		const logoX = rtl ? 261 : margin;
		if (logo) {
			const ratio = Math.min(22 / logo.naturalWidth, 22 / logo.naturalHeight);
			const w = logo.naturalWidth * ratio, h = logo.naturalHeight * ratio;
			ctx!.drawImage(logo, logoX + (22 - w) / 2, 9 + (22 - h) / 2, w, h);
		}
		const titleX = !rtl && logo ? margin + 29 : margin;
		const titleWidth = width - (logo ? 29 : 0);
		text(title, titleX, 10, titleWidth, first ? 7 : 5.5, true);
		text(counterLabel('allTimeReport'), titleX, 20, titleWidth, 3.5, false, green);
		text(`${date(report.startDate)} - ${date(report.asOfDate)} | ${report.scope}`, margin, 34, width, 3, false, muted);
		line(41);
		text(section, margin, 46, width, 4.5, true);
		y = 57;
	}
	function newSection(section: string) { finish(); start(section); }
	function paragraph(value: string, size = 3.1, color = muted) {
		for (const row of wrap(value, width, size)) {
			if (y + leading > bottom) { finish(); start(label('notes')); }
			text(row, margin, y, width, size, false, color);
			y += leading;
		}
		y += 2;
	}
	async function table(section: string, columns: PdfColumn[], rows: PdfRow[]) {
		newSection(section);
		const coordinates = columns.map((column, index) => {
			const before = columns.slice(0, index).reduce((sum, item) => sum + item.width, 0);
			return rtl ? margin + width - before - column.width : margin + before;
		});
		function heading() {
			const wrapped = columns.map(column => wrap(column.label, column.width - 5, 2.9, true));
			const height = Math.max(...wrapped.map(value => value.length)) * 4.2 + 6;
			box(margin, y, width, height, ink);
			wrapped.forEach((lines, index) => lines.forEach((value, offset) => text(value, coordinates[index] + 2.5, y + 3 + offset * 4.2, columns[index].width - 5, 2.9, true, '#ffffff')));
			y += height;
		}
		heading();
		if (!rows.length) { y += 8; paragraph(label('noEntries')); return; }
		for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
			active();
			const row = rows[rowIndex];
			const cells = row.cells.map((value, index) => wrap(value, columns[index].width - 5, 3, row.total));
			const maxLines = Math.max(...cells.map(value => value.length));
			let offset = 0;
			while (offset < maxLines) {
				const fullHeight = (maxLines - offset) * leading + 5;
				if (y + Math.min(fullHeight, 22) > bottom) { finish(); start(section); heading(); }
				const take = Math.min(maxLines - offset, Math.floor((bottom - y - 5) / leading));
				if (take < 1) { finish(); start(section); heading(); continue; }
				const height = take * leading + 5;
				box(margin, y, width, height, row.total ? '#e5f4ed' : rowIndex % 2 ? '#f5f8f6' : '#ffffff');
				cells.forEach((lines, index) => lines.slice(offset, offset + take).forEach((value, lineIndex) => text(value, coordinates[index] + 2.5, y + 2.5 + lineIndex * leading, columns[index].width - 5, 3, row.total, ink, columns[index].numeric)));
				y += height;
				line(y);
				offset += take;
			}
			if (rowIndex % 25 === 0) await new Promise<void>(resolve => setTimeout(resolve, 0));
		}
	}
	try {
		start(label('overview'), true);
		paragraph(`${label('periodStart')}: ${date(report.startDate)} 00:00 | ${label('periodEnd')}: ${cutoff}`);
		paragraph(`${label('dataLoaded')}: ${timestamp(report.loadedAt)} | ${label('generated')}: ${timestamp(report.generatedAt)}`);
		if (isCoffee) {
			box(margin, y, width, 9, '#f0f6f2');
			box(margin, y, 1, 9, gold);
			text(label('capital'), rtl ? margin + 80 : margin + 4, y + 2.5, width - 84, 3.2, true);
			text(amount(report.totals.initialCapital), rtl ? margin + 4 : margin + width - 74, y + 2, 70, 4.8, true, ink, true);
			y += 12;
		}
		const cards: [string, number | null][] = [
			[label('salesIncludingVat'), report.totals.salesIncludingVat], [label('salesExcludingVat'), report.totals.salesExcludingVat],
			[label('rent'), report.totals.rent], [label('inputVat'), report.totals.inputVat],
			[label('beforePayments'), report.totals.payableBeforePayments], [label(isCoffee ? 'vendorPayments' : 'outputVat'), isCoffee ? report.totals.vendorPayments : report.totals.outputVat],
			[label('withdrawals'), report.totals.otherPayments], [label('salesPaidExpenses'), report.totals.salesPaidExpenses],
			[label('operatorPaidExpenses'), report.totals.operatorPaidExpenses], [label('erpExpenses'), report.totals.expensesIncludingVat],
			[label('netPayable'), report.totals.netPayable], [label('profit'), report.totals.operatorsProfit]
		];
		const gap = 4, cardWidth = (width - gap * 3) / 4;
		const cardHeight = isCoffee ? 22 : 24;
		const rowGap = isCoffee ? 3 : 4;
		const cardTop = y + 2;
		cards.forEach(([heading, value], index) => {
			const column = rtl ? 3 - index % 4 : index % 4;
			const x = margin + column * (cardWidth + gap), top = cardTop + Math.floor(index / 4) * (cardHeight + rowGap);
			const highlight = index >= 10;
			box(x, top, cardWidth, cardHeight, highlight ? ink : '#f0f6f2');
			box(x, top, 1, cardHeight, highlight ? gold : '#cce3d7');
			wrap(heading, cardWidth - 8, 2.8).forEach((value, n) => text(value, x + 4, top + 3 + n * 3.7, cardWidth - 8, 2.8, false, highlight ? '#d8eadd' : muted));
			// Fit unusually large totals within their card rather than clipping.
			let size = 5.8;
			font(size, true);
			while (ctx!.measureText(amount(value)).width > cardWidth - 8 && size > 3) font(size -= .2, true);
			text(amount(value), x + 4, top + cardHeight - 10, cardWidth - 8, size, true, highlight ? '#ffffff' : ink, true);
		});
		y = cardTop + Math.ceil(cards.length / 4) * (cardHeight + rowGap) - rowGap + 5;
		paragraph(`${label('rentStart')}: ${date((isCoffee ? report.profile.rentIncreaseDate : report.profile.reportStartDate) || report.startDate)}`);
		paragraph(label('snapshotNote'));
		const reconciliation: [string, number | null][] = [
			[label('salesIncludingVat'), report.totals.salesIncludingVat], [label('outputVat'), report.totals.outputVat],
			[label('salesExcludingVat'), report.totals.salesExcludingVat], [label('rent'), report.totals.rent],
			[label('inputVat'), report.totals.inputVat],
			...(isCoffee ? [[label('capital'), report.totals.initialCapital] as [string, number]] : []),
			[label('beforePayments'), report.totals.payableBeforePayments],
			...(isCoffee ? [[label('cashBank'), report.cashAndBank], [label('journals'), report.journalPayments], [label('vendorPayments'), report.totals.vendorPayments]] as [string, number | null][] : []),
			[label('withdrawals'), report.totals.otherPayments], [label('salesPaidExpenses'), report.totals.salesPaidExpenses],
			[label('netPayable'), report.totals.netPayable], [label('erpExpenses'), report.totals.expensesIncludingVat],
			[label('operatorPaidExpenses'), report.totals.operatorPaidExpenses], [label('profit'), report.totals.operatorsProfit]
		];
		await table(label('reconciliation'), [{ label: label('description'), width: 192 }, { label: label('amount'), width: 77, numeric: true }],
			reconciliation.map(([name, value]) => ({ cells: [name, amount(value)], total: [label('beforePayments'), label('netPayable'), label('profit')].includes(name) })));
		await table(label(isCoffee ? 'branchBreakdown' : 'branchSales'), [
			{ label: label('branch'), width: 75 }, { label: label('salesIncludingVat'), width: 50, numeric: true },
			{ label: label('salesExcludingVat'), width: 50, numeric: true }, { label: label('outputVat'), width: 44, numeric: true },
			...(isCoffee ? [{ label: label('stock'), width: 50, numeric: true }] : [])
		].map((column, index) => !isCoffee && index === 0 ? { ...column, width: column.width + 50 } : column),
			report.branches.map(branch => ({ cells: [branch.name, amount(branch.sales), amount(branch.salesExcludingVat), amount(branch.outputVat), ...(isCoffee ? [amount(branch.stock)] : [])] })));
		if (isCoffee) { y += 7; paragraph(`${label('stock')}: ${amount(report.stockValue)}`); paragraph(counterLabel('allTime.stockBasis')); }
		const periodColumns: PdfColumn[] = [
			{ label: label('date'), width: 28 }, { label: label('salesIncludingVat'), width: 33, numeric: true },
			{ label: label('salesExcludingVat'), width: 33, numeric: true }, { label: label('rent'), width: 28, numeric: true },
			{ label: label('inputVat'), width: 26, numeric: true }, { label: label('erpExpenses'), width: 37, numeric: true },
			{ label: label('receivable'), width: 45, numeric: true }, { label: label('profit'), width: 39, numeric: true }
		];
		const periodRow = (row: CounterPdfPeriod, monthly = false): PdfRow => ({ cells: [monthly ? row.date : date(row.date), amount(row.salesIncludingVat), amount(row.salesExcludingVat), amount(row.rent), amount(row.inputVat), amount(row.expensesIncludingVat), amount(row.receivable), amount(row.profit)] });
		const totalPeriod: CounterPdfPeriod = { date: label('total'), percentage: null, salesIncludingVat: report.totals.salesIncludingVat!, salesExcludingVat: report.totals.salesExcludingVat!, rent: report.totals.rent!, inputVat: report.totals.inputVat!, expensesIncludingVat: report.totals.expensesIncludingVat!, receivable: report.totals.payableBeforePayments! - report.totals.initialCapital, profit: report.totals.operatorsProfit! };
		await table(label('monthly'), periodColumns, [...report.monthly.map(row => periodRow(row, true)), { ...periodRow(totalPeriod, true), total: true }]);
		y += 5; paragraph(label('periodNote'));
		await table(label('daily'), periodColumns, report.daily.map(row => periodRow(row)));
		y += 5; paragraph(label('dailyNote'));
		await table(label('dailyRent'), [{ label: label('date'), width: 69 }, { label: label('rentPercent'), width: 60, numeric: true }, { label: label('salesExcludingVat'), width: 70, numeric: true }, { label: label('rent'), width: 70, numeric: true }],
			report.daily.map(row => ({ cells: [date(row.date), row.percentage === null ? label('unavailable') : `${integer.format(row.percentage)}%`, amount(row.salesExcludingVat), amount(row.rent)] })));
		await table(label('withdrawalsDetail'), [{ label: label('date'), width: 38 }, { label: label('narration'), width: 181 }, { label: label('amount'), width: 50, numeric: true }], report.withdrawals.map(row => ({ cells: [date(row.paymentDate), row.narration, amount(row.amount)] })));
		await table(label('otherExpensesDetail'), [{ label: label('date'), width: 38 }, { label: label('narration'), width: 141 }, { label: label('source'), width: 40 }, { label: label('amount'), width: 50, numeric: true }], report.otherExpenses.map(row => ({ cells: [date(row.paymentDate), row.narration, label(row.paidFrom === 'sales' ? 'fromSales' : 'byOperator'), amount(row.amount)] })));
		newSection(label('notes'));
		for (const note of [
			counterLabel('allTime.note'), counterLabel('rentReport.schedule'), counterLabel('allTime.formula'),
			counterLabel('allTime.operatorsProfitNote'), label('periodNote'), label('dailyNote'),
			report.combined ? label('combinedNote') : label('branchNote'), label('negativeNote'),
			...(isCoffee ? [counterLabel('allTime.capitalNote'), tFor(report.locale, `${report.profile.localeKey}.allTime.paymentsNote`, { date: date(report.asOfDate) })] : [])
		]) paragraph(note);
		finish();
		for (let page = 1; page <= pageCount; page++) {
			pdf.setPage(page);
			pdf.setFont('helvetica', 'normal');
			pdf.setFontSize(8);
			pdf.setTextColor('#62766f');
			pdf.text(`${page} / ${pageCount}`, rtl ? margin : 283, 203, { align: rtl ? 'left' : 'right' });
		}
		active();
		await pdf.save(`${report.profile.id}_all-time_${report.asOfDate}_${report.locale}.pdf`, { returnPromise: true });
	} finally {
		if (logoObjectUrl) URL.revokeObjectURL(logoObjectUrl);
		canvas.width = 0; canvas.height = 0;
	}
}
