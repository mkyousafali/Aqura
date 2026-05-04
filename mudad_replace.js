const fs = require('fs');
const path = 'D:/Aqura/frontend/src/lib/components/desktop-interface/master/hr/PrepareSalaryStatementWindow.svelte';

const lines = fs.readFileSync(path, 'utf8').split('\n');
console.log('Total lines:', lines.length);
console.log('L487:', lines[486].substring(0, 80));
console.log('L638:', lines[637].substring(0, 80));

const newCode = `/** Convert Excel column letters to 1-based column number: A=1, Z=26, AA=27 */
function mudadColToNum(ref) {
	const letters = ref.match(/^([A-Z]+)/)?.[1] || '';
	let n = 0;
	for (const ch of letters) n = n * 26 + ch.charCodeAt(0) - 64;
	return n;
}

/** Parse xl/sharedStrings.xml into an array of plain strings */
async function parseMudadSharedStrings(zip) {
	const file = zip.file('xl/sharedStrings.xml');
	if (!file) return [];
	const xml = await file.async('string');
	const parser = new DOMParser();
	const doc = parser.parseFromString(xml, 'application/xml');
	const sis = doc.getElementsByTagName('si');
	const result = [];
	for (let i = 0; i < sis.length; i++) {
		const tEls = sis[i].getElementsByTagName('t');
		let text = '';
		for (let j = 0; j < tEls.length; j++) text += tEls[j].textContent || '';
		result.push(text);
	}
	return result;
}

/** Update specific cells in a sheet XML string — only <v> values change, all other XML is untouched */
function updateMudadCells(xml, updates) {
	let result = xml;
	for (const [cellRef, newValue] of updates) {
		const esc = cellRef.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
		const fullRe = new RegExp('(<c\\\\b[^>]*\\\\br="' + esc + '"[^>]*>)[\\\\s\\\\S]*?<\\/c>', 'g');
		const selfRe = new RegExp('<c\\\\b[^>]*\\\\br="' + esc + '"[^>]*/>', 'g');
		let hit = false;
		result = result.replace(fullRe, function(_m, openTag) {
			hit = true;
			const clean = openTag.replace(/\\s+t="[^"]*"/g, '').replace(/\\s+t='[^']*'/g, '');
			return clean + '<v>' + newValue + '</v></c>';
		});
		if (!hit) {
			result = result.replace(selfRe, function(m) {
				const clean = m.slice(0, -2).replace(/\\s+t="[^"]*"/g, '').replace(/\\s+t='[^']*'/g, '');
				return clean + '><v>' + newValue + '</v></c>';
			});
		}
	}
	return result;
}

/** Find header row, match Legal Ids, return updated sheet XML and match count */
function processMudadSheetXml(xml, sharedStrings, mudadMap) {
	const HEADERS = ['Legal Id', 'Other Allowances (Amount)', 'Leave of Absence (Amount)', 'Other Deductions (Amount)'];
	const parser = new DOMParser();
	const doc = parser.parseFromString(xml, 'application/xml');
	const rows = Array.from(doc.getElementsByTagName('row'));

	let headerRowNum = -1;
	let legalIdCol = 0, otherAllowCol = 0, leaveAbsenceCol = 0, otherDedCol = 0;
	for (const row of rows) {
		if (headerRowNum !== -1) break;
		const colMap = {};
		for (const cell of Array.from(row.getElementsByTagName('c'))) {
			if (cell.getAttribute('t') !== 's') continue;
			const vEl = cell.querySelector('v');
			if (!vEl?.textContent) continue;
			const idx = parseInt(vEl.textContent);
			if (isNaN(idx)) continue;
			const str = sharedStrings[idx]?.trim();
			if (str) colMap[str] = mudadColToNum(cell.getAttribute('r') || '');
		}
		if (HEADERS.every(h => colMap[h])) {
			headerRowNum    = parseInt(row.getAttribute('r') || '0');
			legalIdCol      = colMap['Legal Id'];
			otherAllowCol   = colMap['Other Allowances (Amount)'];
			leaveAbsenceCol = colMap['Leave of Absence (Amount)'];
			otherDedCol     = colMap['Other Deductions (Amount)'];
		}
	}
	if (headerRowNum === -1) return { result: xml, matchCount: 0 };

	const updates = new Map();
	for (const row of rows) {
		const rowNum = parseInt(row.getAttribute('r') || '0');
		if (rowNum <= headerRowNum) continue;
		let legalId = '';
		for (const cell of Array.from(row.getElementsByTagName('c'))) {
			if (mudadColToNum(cell.getAttribute('r') || '') !== legalIdCol) continue;
			const vEl = cell.querySelector('v');
			if (!vEl) break;
			const rawVal = cell.getAttribute('t') === 's'
				? sharedStrings[parseInt(vEl.textContent || '0')]
				: vEl.textContent;
			legalId = normalizeLegalId(rawVal);
			break;
		}
		if (!legalId) continue;
		const vals = mudadMap.get(legalId);
		if (!vals) continue;
		for (const cell of Array.from(row.getElementsByTagName('c'))) {
			const ref = cell.getAttribute('r') || '';
			const col = mudadColToNum(ref);
			if (col === otherAllowCol)       updates.set(ref, parseFloat(vals.otherAllowances.toFixed(2)));
			else if (col === leaveAbsenceCol) updates.set(ref, parseFloat(vals.leaveOfAbsence.toFixed(2)));
			else if (col === otherDedCol)     updates.set(ref, parseFloat(vals.otherDeductions.toFixed(2)));
		}
	}
	if (updates.size === 0) return { result: xml, matchCount: 0 };
	return { result: updateMudadCells(xml, updates), matchCount: Math.round(updates.size / 3) };
}

async function exportMudadExcel() {
	if (!mudadTemplateFile) { mudadError = 'Please upload a Mudad template file first.'; return; }
	if (!filteredAnalysisData.length) { mudadError = 'No salary data loaded. Load a salary statement first.'; return; }
	mudadProcessing = true; mudadError = ''; mudadSuccess = '';
	try {
		// JSZip opens the XLSX as a raw ZIP — ALL parts (tables, drawings, autofilter) are preserved intact
		const JSZipMod = await import('jszip');
		const JSZip = JSZipMod.default ?? JSZipMod;
		const arrayBuffer = await mudadTemplateFile.arrayBuffer();
		const zip = await JSZip.loadAsync(arrayBuffer);

		const sharedStrings = await parseMudadSharedStrings(zip);
		const mudadMap = buildMudadRowMap();

		let totalMatched = 0;
		const sheetPaths = Object.keys(zip.files).filter(f =>
			/^xl\/worksheets\/sheet\d+\.xml$/i.test(f)
		);
		for (const sheetPath of sheetPaths) {
			const xml = await zip.file(sheetPath).async('string');
			const { result, matchCount } = processMudadSheetXml(xml, sharedStrings, mudadMap);
			if (matchCount > 0) { zip.file(sheetPath, result); totalMatched += matchCount; }
		}

		const blob = await zip.generateAsync({
			type: 'blob',
			mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
			compression: 'DEFLATE',
			compressionOptions: { level: 6 }
		});
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		const today = new Date();
		const stamp = today.getFullYear() + String(today.getMonth() + 1).padStart(2, '0') + String(today.getDate()).padStart(2, '0');
		a.href = url; a.download = 'Mudad_' + stamp + '.xlsx';
		document.body.appendChild(a); a.click();
		setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1500);
		mudadSuccess = totalMatched > 0
			? 'Done — ' + totalMatched + ' employee(s) matched and exported.'
			: 'Warning: No employees matched. Check that Legal Id values in the template match the salary data.';
	} catch (err) {
		console.error('Mudad export error:', err);
		mudadError = 'Export failed: ' + (err?.message || 'Unknown error');
	} finally {
		mudadProcessing = false;
	}
}`;

// Replace lines 487-637 (0-indexed 486-636)
const before = lines.slice(0, 486).join('\n');
const after = lines.slice(637).join('\n');
const newContent = before + '\n' + newCode + '\n' + after;

fs.writeFileSync(path, newContent, 'utf8');
const check = fs.readFileSync(path, 'utf8');
console.log('Written. Total lines now:', check.split('\n').length);
console.log('mudadColToNum found:', check.includes('mudadColToNum'));
console.log('ExcelJS found (should be false):', check.includes('ExcelJS'));
