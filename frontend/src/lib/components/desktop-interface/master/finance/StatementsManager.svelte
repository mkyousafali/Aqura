<script lang="ts">
	import * as XLSX from 'xlsx';

	type StatementRow = {
		rowNumber: number; date: unknown; description: string; details: string; reference: string;
		terminalId: string; debit: string; credit: string; balance: string; code: string; children: StatementRow[];
	};

	let bank = '';
	let fileInput: HTMLInputElement;
	let fileName = '';
	let errorMessage = '';
	let isImporting = false;
	let statementRows: StatementRow[] = [];
	let rawTransactionCount = 0;
	let processingFeeCount = 0;
	let vatCount = 0;
	let terminalFilter = '';
	let terminalOptions: string[] = [];
	let filteredStatementRows: StatementRow[] = [];

	$: terminalOptions = Array.from(new Set(statementRows
		.map((row) => bank === 'riyad' ? row.terminalId.slice(0, 8) : row.terminalId)
		.filter(Boolean))).sort((left, right) => left.localeCompare(right, undefined, { numeric: true }));
	$: filteredStatementRows = terminalFilter
		? statementRows.filter((row) => (bank === 'riyad' ? row.terminalId.slice(0, 8) : row.terminalId) === terminalFilter)
		: statementRows;

	const clean = (value: unknown) => String(value ?? '').trim();
	const normalized = (value: unknown) => clean(value).toLowerCase().replace(/\s+/g, ' ');
	const findCode = (details: string) => details.match(/\b([A-Z]{2}\d{6})\s*$/)?.[1] ?? '';
	function findTerminalId(details: string, selectedBank: string): string {
		if (selectedBank === 'al-ahli') return details.match(/REFERENCE\s*:\s*(\d+)/i)?.[1] ?? '';
		return details.match(/TERM\.\s*ID:\s*(\d+)/i)?.[1]
			?? details.match(/FEE\s*[\d,.]+\s*SAR,(\d+),\d+/i)?.[1]
			?? '';
	}

	function findPosKey(row: StatementRow): string | null {
		const identity = row.details.match(/RECON NO:\s*(\d+)\s+(?:000000\s+)?REFERENCE\s*:\s*(\d+)/i);
		if (!identity || !row.code) return null;
		const suffix = row.code.slice(0, 2).toUpperCase();
		const network = row.description === 'POS Retailer Acc. Bulk credit' ? suffix[0] : suffix[1];
		return `${identity[1].replace(/^0+/, '')}|${identity[2]}|${network}|${row.code.slice(2)}`;
	}

	const transactionNumber = (index: number) => `T-${String(index + 1).padStart(3, '0')}`;

	function childKind(row: StatementRow): 'fee' | 'vat' | null {
		if (row.code === 'FEE') return 'fee';
		if (row.code === 'VAT') return 'vat';
		if (row.description === 'Transfer Fees') return 'fee';
		if (row.description === 'VAT Charge') return 'vat';
		if (row.description !== 'POS and E-payment Fee') return null;
		if (row.code.startsWith('F')) return 'fee';
		if (row.code.startsWith('V')) return 'vat';
		return null;
	}

	function referenceKey(value: string): string {
		return value.match(/REF\s+([A-Z0-9]+)/i)?.[1] ?? '';
	}

	function riyadChild(parent: StatementRow, kind: 'fee' | 'vat', value: number, details: string): StatementRow {
		return {
			rowNumber: parent.rowNumber,
			date: parent.date,
			description: kind === 'fee' ? 'Processing fee' : 'VAT on processing fee',
			details,
			reference: parent.reference,
			terminalId: parent.terminalId,
			debit: amount(value),
			credit: '',
			balance: '',
			code: kind === 'fee' ? 'FEE' : 'VAT',
			children: []
		};
	}

	function groupRiyadTransactions(rows: StatementRow[]): StatementRow[] {
		const attachedSourceRows = new Set<number>();
		const transferParents = new Map<string, StatementRow>();

		for (const row of rows) {
			if (row.description === 'ONLINE POS CREDIT') {
				const values = row.details.match(/PURCHASE AMT:\s*([\d,.]+)\s*SAR,REFUND AMOUNT:\s*([\d,.]+)\s*SAR,FEE\s*([\d,.]+)\s*SAR,VAT Amount:\s*([\d,.]+)\s*SAR/i);
				if (values) {
					const fee = Number(values[3].replace(/,/g, ''));
					const vat = Number(values[4].replace(/,/g, ''));
					row.children = [
						riyadChild(row, 'fee', fee, 'Fee extracted from the Mada POS settlement details'),
						riyadChild(row, 'vat', vat, 'VAT extracted from the Mada POS settlement details')
					];
				}
				row.description = 'Mada POS Credit';
			} else if (row.description === 'POS SETTLEMENT') {
				const values = row.details.match(/VAT AMOUNT\s*([\d,.]+)\s*SAR.*?FEE\s*([\d,.]+)\s*SAR/i);
				if (values) {
					const vat = Number(values[1].replace(/,/g, ''));
					const fee = Number(values[2].replace(/,/g, ''));
					row.children = [
						riyadChild(row, 'fee', fee, 'Fee extracted from the Visa POS settlement details'),
						riyadChild(row, 'vat', vat, 'VAT extracted from the Visa POS settlement details')
					];
				}
				const settlementDetails = row.details.toUpperCase();
				row.description = settlementDetails.includes('VISA')
					? 'Visa POS Credit'
					: settlementDetails.includes('MASTER')
						? 'Mastercard POS Credit'
						: 'Other Card POS Credit';
			}

			if (row.description === 'OUTGOING INSTANT PAYMENT' || row.description === 'OUTGOING TRANSF') {
				const key = referenceKey(row.reference);
				if (key) transferParents.set(key, row);
			}
		}

		for (const feeRow of rows) {
			if (feeRow.description !== 'INSTANT PAYMENT FEES' && feeRow.description !== 'BANK FEES/COMMISSIONS') continue;
			const parent = transferParents.get(referenceKey(feeRow.reference));
			const values = feeRow.details.match(/FEE\s*0*([\d,.]+)\s*SAR,VAT AMOUNT\s*0*([\d,.]+)\s*SAR/i);
			if (!parent || !values) continue;
			const fee = Number(values[1].replace(/,/g, ''));
			const vat = Number(values[2].replace(/,/g, ''));
			parent.children = [
				riyadChild(feeRow, 'fee', fee, `Connected ${feeRow.description.toLowerCase()} row`),
				riyadChild(feeRow, 'vat', vat, `VAT extracted from the connected ${feeRow.description.toLowerCase()} row`)
			];
			attachedSourceRows.add(feeRow.rowNumber);
		}

		const posNetworks = new Set(['Mada POS Credit', 'Visa POS Credit', 'Mastercard POS Credit', 'Other Card POS Credit']);
		const networkPriority: Record<string, number> = {
			'Mada POS Credit': 0,
			'Visa POS Credit': 1,
			'Mastercard POS Credit': 2,
			'Other Card POS Credit': 3
		};
		const priority: Record<string, number> = {
			'OUTGOING INSTANT PAYMENT': 1,
			'OUTGOING TRANSF': 2,
			'POS DEBIT': 3,
			'UTILITY BILL PAYMENT': 4,
			'Outgoing Transfer': 5,
			'ATM DEBIT': 6,
			'INCOMING TRANSFER': 7,
			'TRNSFR FROM C/A TO C/A': 8,
			'--': 9
		};

		return rows
			.filter((row) => !attachedSourceRows.has(row.rowNumber))
			.sort((left, right) => {
				const leftIsPos = posNetworks.has(left.description);
				const rightIsPos = posNetworks.has(right.description);
				if (leftIsPos && rightIsPos) {
					const terminalDifference = left.terminalId.slice(0, 8).localeCompare(right.terminalId.slice(0, 8));
					return terminalDifference || (networkPriority[left.description] ?? 9) - (networkPriority[right.description] ?? 9) || left.rowNumber - right.rowNumber;
				}
				if (leftIsPos !== rightIsPos) return leftIsPos ? -1 : 1;
				return (priority[left.description] ?? 99) - (priority[right.description] ?? 99) || left.description.localeCompare(right.description) || left.rowNumber - right.rowNumber;
			});
	}

	function groupTransactions(rows: StatementRow[]): StatementRow[] {
		const posParents = new Map<string, StatementRow>();
		const transferParents = new Map<string, StatementRow>();
		const attachedRows = new Set<number>();

		for (const row of rows) {
			if (row.description === 'POS Retailer Acc. Bulk credit') {
				const key = findPosKey(row);
				if (key) posParents.set(key, row);
			}
			if (row.description === 'Outgoing IPS local transfer' || row.description === 'Outgoing Local Transfer') {
				if (row.reference) transferParents.set(row.reference, row);
			}
		}

		for (const row of rows) {
			if (!childKind(row)) continue;
			let parent: StatementRow | undefined;
			if (row.description === 'POS and E-payment Fee') {
				const key = findPosKey(row);
				parent = key ? posParents.get(key) : undefined;
			} else if (row.reference) parent = transferParents.get(row.reference);
			if (parent) {
				parent.children.push(row);
				attachedRows.add(row.rowNumber);
			}
		}

		for (const row of rows) {
			row.children.sort((left, right) => childKind(left) === childKind(right) ? left.rowNumber - right.rowNumber : childKind(left) === 'fee' ? -1 : 1);
			if (row.description === 'POS Retailer Acc. Bulk credit') {
				const networkCode = row.code.slice(0, 1).toUpperCase();
				row.description = networkCode === 'V'
					? 'Visa POS Bulk Credit'
					: networkCode === 'M'
						? 'Mastercard POS Bulk Credit'
						: networkCode === 'S'
							? 'Mada POS Bulk Credit'
							: 'Other POS Bulk Credit';
			}
		}
		return rows
			.filter((row) => !attachedRows.has(row.rowNumber))
			.sort((left, right) => {
				const priority = (row: StatementRow) => {
					if (row.description === 'Mada POS Bulk Credit') return 0;
					if (row.description === 'Visa POS Bulk Credit') return 1;
					if (row.description === 'Mastercard POS Bulk Credit') return 2;
					if (row.description === 'Other POS Bulk Credit') return 3;
					if (row.description === 'Outgoing IPS local transfer' || row.description === 'Outgoing Local Transfer') return 4;
					if (row.description === 'SADAD Payment') return 5;
					if (row.description === 'Outgoing internal transfer') return 6;
					if (row.description === 'Incoming internal transfer') return 7;
					return 8;
				};
				const priorityDifference = priority(left) - priority(right);
				if (priorityDifference) return priorityDifference;
				const descriptionDifference = left.description.localeCompare(right.description);
				return descriptionDifference || left.rowNumber - right.rowNumber;
			});
	}

	function displayDate(value: unknown): string {
		if (value instanceof Date && !Number.isNaN(value.getTime())) return value.toLocaleDateString('en-GB');
		if (typeof value === 'number') {
			const parsed = XLSX.SSF.parse_date_code(value);
			if (parsed) return `${String(parsed.d).padStart(2, '0')}/${String(parsed.m).padStart(2, '0')}/${parsed.y}`;
		}
		return clean(value);
	}

	function amount(value: unknown): string {
		const text = clean(value);
		if (!text) return '';
		const number = Number(text.replace(/,/g, ''));
		return Number.isFinite(number) ? number.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : text;
	}

	function chooseFile() {
		if (bank && !isImporting) fileInput?.click();
	}

	function resetStatement() {
		fileName = '';
		errorMessage = '';
		statementRows = [];
		rawTransactionCount = 0;
		processingFeeCount = 0;
		vatCount = 0;
		terminalFilter = '';
	}

	async function importStatement(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		isImporting = true;
		errorMessage = '';
		statementRows = [];
		terminalFilter = '';
		fileName = file.name;
		try {
			const workbook = XLSX.read(await file.arrayBuffer(), { type: 'array', cellDates: true });
			const worksheet = workbook.Sheets[workbook.SheetNames[0]];
			const rows = XLSX.utils.sheet_to_json<unknown[]>(worksheet, { header: 1, raw: true, defval: '' });
			const expectedHeader = bank === 'riyad' ? 'transaction type' : 'transaction description';
			const headerIndex = rows.findIndex((row) => row.some((cell) => normalized(cell) === expectedHeader));
			if (headerIndex < 0) throw new Error(`The selected file does not match the expected ${bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli'} statement format.`);

			const headers = rows[headerIndex].map(normalized);
			const column = (name: string) => headers.indexOf(name);
			const dateColumn = column(bank === 'riyad' ? 'value date' : 'processing date');
			const descriptionColumn = column(bank === 'riyad' ? 'transaction type' : 'transaction description');
			const detailsColumn = column(bank === 'riyad' ? 'details' : 'description');
			const referenceColumn = column(bank === 'riyad' ? 'reference no' : 'reference');
			const debitColumn = column(bank === 'riyad' ? 'debit amount' : 'debit');
			const creditColumn = column(bank === 'riyad' ? 'credit amount' : 'credit');
			const balanceColumn = column('balance');

			const parsedRows: StatementRow[] = rows.slice(headerIndex + 1).map((cells, offset) => {
				const details = clean(cells[detailsColumn]);
				return {
					rowNumber: headerIndex + offset + 2,
					date: cells[dateColumn], description: clean(cells[descriptionColumn]), details,
					reference: clean(cells[referenceColumn]), terminalId: findTerminalId(details, bank), debit: amount(cells[debitColumn]),
					credit: amount(cells[creditColumn]), balance: amount(cells[balanceColumn]),
					code: findCode(details), children: []
				};
			}).filter((row) => row.description);

			rawTransactionCount = parsedRows.length;
			if (bank === 'riyad') {
				statementRows = groupRiyadTransactions(parsedRows);
				processingFeeCount = statementRows.reduce((total, row) => total + row.children.filter((child) => childKind(child) === 'fee').length, 0);
				vatCount = statementRows.reduce((total, row) => total + row.children.filter((child) => childKind(child) === 'vat').length, 0);
			} else {
				processingFeeCount = parsedRows.filter((row) => childKind(row) === 'fee').length;
				vatCount = parsedRows.filter((row) => childKind(row) === 'vat').length;
				statementRows = groupTransactions(parsedRows);
			}
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Unable to import the selected statement.';
			fileName = '';
		} finally {
			isImporting = false;
			input.value = '';
		}
	}
</script>

<div class="statement-manager">
	<section class="import-panel">
		<div class="field"><label for="statement-bank">Bank</label><select id="statement-bank" bind:value={bank} on:change={resetStatement}><option value="">Choose a bank</option><option value="al-ahli">Al Ahli (SNB)</option><option value="riyad">Riyad Bank</option></select></div>
		{#if bank}
			<button class="import-button" type="button" disabled={isImporting} on:click={chooseFile}>{isImporting ? 'Importing…' : 'Import Excel file'}</button>
			<input bind:this={fileInput} class="file-input" type="file" accept=".xlsx,.xls" on:change={importStatement} />
		{/if}
		{#if fileName}<div class="file-name" title={fileName}>{fileName}</div>{/if}
	</section>
	{#if errorMessage}<div class="error-message">{errorMessage}</div>{/if}

	{#if statementRows.length > 0}
		<section class="summary-grid" aria-label="Statement summary">
			<div><span>Excel source rows</span><strong>{rawTransactionCount}</strong></div><div><span>Main transactions</span><strong>{statementRows.length}</strong></div>
			<div><span>Processing fees</span><strong>{processingFeeCount}</strong></div><div><span>VAT entries</span><strong>{vatCount}</strong></div>
		</section>
		{#if bank === 'riyad'}<div class="source-note">Riyad stores some processing fees and VAT inside the same Excel row. They are extracted below for clear grouping without changing the source-row count.</div>{/if}
		<div class="table-filters">
			<div class="filter-field"><label for="terminal-filter">Terminal ID</label><select id="terminal-filter" bind:value={terminalFilter}><option value="">All terminals</option>{#each terminalOptions as terminalId}<option value={terminalId}>{terminalId}</option>{/each}</select></div>
			{#if terminalFilter}<span>{filteredStatementRows.length} matching transactions</span>{/if}
		</div>
		<div class="table-shell"><table>
			<thead><tr><th>Group</th><th>Date</th><th>Transaction description</th><th>Details</th><th>Reference</th><th>Terminal ID</th><th class="number">Debit</th><th class="number">Credit</th><th class="number">Balance</th></tr></thead>
			{#each filteredStatementRows as row, transactionIndex}
				<tbody class:linked-group={row.children.length > 0} class:standalone-group={row.children.length === 0} class:group-alt={transactionIndex % 2 === 1}>
					<tr class="main-row">
						<td class="group-cell" rowspan={row.children.length + 1}>
							<strong>{transactionNumber(transactionIndex)}</strong>
							<span>{row.children.length ? `${row.children.length + 1} grouped items` : '1 standalone row'}</span>
						</td>
						<td>{displayDate(row.date)}</td><td><span class="row-type main-type">Main</span><strong>{row.description}</strong></td><td>{row.details}</td><td>{row.reference}</td><td class="terminal-id">{row.terminalId}</td><td class="number debit">{row.debit}</td><td class="number credit">{row.credit}</td><td class="number">{row.balance}</td>
					</tr>
					{#each row.children as child}
						<tr class="child-row"><td>{displayDate(child.date)}</td><td><span class:vat-type={childKind(child) === 'vat'} class="row-type">{childKind(child) === 'vat' ? 'VAT' : 'Fee'}</span><strong>{childKind(child) === 'vat' ? 'VAT on processing fee' : 'Processing fee'}</strong></td><td>{child.details}</td><td>{child.reference}</td><td class="terminal-id">{child.terminalId}</td><td class="number debit">{child.debit}</td><td class="number credit">{child.credit}</td><td class="number">{child.balance}</td></tr>
					{/each}
				</tbody>
			{/each}
		</table></div>
	{:else if !errorMessage}
		<div class="empty-state"><div class="empty-icon">▤</div><h2>No statement imported</h2><p>Choose a bank, then import its Excel statement to arrange transactions with their fees and VAT.</p></div>
	{/if}
</div>

<style>
	.statement-manager{height:100%;overflow:hidden;padding:18px 24px 24px;background:#f4f7fb;color:#172033;font-family:'Segoe UI',sans-serif;box-sizing:border-box;display:flex;flex-direction:column}.import-panel{display:flex;align-items:flex-end;gap:12px;padding:18px;background:#fff;border:1px solid #dbe3ef;border-radius:14px;box-shadow:0 8px 22px rgba(15,23,42,.05);flex-shrink:0}.field{min-width:260px}label{display:block;margin-bottom:7px;color:#475569;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.04em}select{width:100%;height:42px;padding:0 12px;border:1px solid #cbd5e1;border-radius:9px;background:#fff;color:#172033;font-size:14px}.import-button{height:42px;padding:0 18px;border:0;border-radius:9px;background:#0f766e;color:#fff;font-weight:700;cursor:pointer}.import-button:hover:not(:disabled){background:#115e59}.import-button:disabled{opacity:.45;cursor:not-allowed}.file-input{display:none}.file-name{min-width:0;padding-bottom:11px;overflow:hidden;color:#475569;font-size:13px;text-overflow:ellipsis;white-space:nowrap}.error-message{margin-top:14px;padding:12px 14px;border:1px solid #fecaca;border-radius:10px;background:#fef2f2;color:#b91c1c;flex-shrink:0}.summary-grid{display:grid;grid-template-columns:repeat(4,minmax(140px,1fr));gap:12px;margin:14px 0;flex-shrink:0}.summary-grid div{padding:14px 16px;border:1px solid #dbe3ef;border-radius:12px;background:#fff}.summary-grid span{display:block;color:#64748b;font-size:12px;font-weight:700}.summary-grid strong{display:block;margin-top:5px;font-size:23px}.source-note{flex-shrink:0;margin:-3px 0 10px;padding:8px 12px;border:1px solid #bfdbfe;border-radius:8px;background:#eff6ff;color:#1e40af;font-size:11px;font-weight:600}.table-shell{flex:1;min-height:0;overflow:auto;border:1px solid #dbe3ef;border-radius:13px;background:#fff;box-shadow:0 8px 22px rgba(15,23,42,.05)}table{width:100%;min-width:1360px;border-collapse:separate;border-spacing:0;font-size:12px}thead{position:sticky;top:0;z-index:2;background:#172033;color:#fff}th,td{padding:10px 12px;border-bottom:1px solid #dce5ef;text-align:left;vertical-align:top}th{font-size:11px;letter-spacing:.03em;text-transform:uppercase}.linked-group td{background:#eef7ff}.linked-group.group-alt td{background:#f2f1ff}.linked-group tr:first-child td{border-top:3px solid #3b82f6}.linked-group.group-alt tr:first-child td{border-top-color:#7c3aed}.linked-group tr:last-child td{border-bottom:3px solid #3b82f6}.linked-group.group-alt tr:last-child td{border-bottom-color:#7c3aed}.linked-group .group-cell{border-left:7px solid #3b82f6;background:#dbeafe}.linked-group.group-alt .group-cell{border-left-color:#7c3aed;background:#e8e5ff}.standalone-group .group-cell{border-left:7px solid #cbd5e1;background:#f8fafc}.standalone-group tr:hover td{background:#f8fafc}.group-cell{width:105px;vertical-align:middle;text-align:center}.group-cell strong{display:block;color:#172033;font-size:14px}.group-cell span{display:block;margin-top:5px;color:#64748b;font-size:10px;font-weight:700;line-height:1.25}.child-row td{border-top:1px dashed #a9bed5}.row-type{display:inline-flex;min-width:36px;justify-content:center;margin-right:8px;padding:3px 7px;border-radius:5px;background:#d1fae5;color:#047857;font-size:9px;font-weight:900;letter-spacing:.04em;text-transform:uppercase}.row-type.vat-type{background:#fef3c7;color:#a16207}.row-type.main-type{background:#dbeafe;color:#1d4ed8}.terminal-id{font-weight:700;white-space:nowrap;font-variant-numeric:tabular-nums}.number{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}.debit{color:#b42318}.credit{color:#087443}.empty-state{display:grid;place-items:center;min-height:0;flex:1;margin-top:18px;padding:30px;border:1px dashed #b7c4d6;border-radius:14px;background:rgba(255,255,255,.65);text-align:center}.empty-state>*{margin:0}.empty-state h2{margin-top:10px;font-size:18px}.empty-state p{max-width:520px;margin-top:7px;color:#64748b}.empty-icon{color:#0f766e;font-size:42px}@media(max-width:850px){.summary-grid{grid-template-columns:repeat(2,1fr)}.import-panel{align-items:stretch;flex-direction:column}.field{min-width:0}.file-name{padding:0}}
	.table-filters{display:flex;align-items:flex-end;gap:12px;margin:0 0 10px;flex-shrink:0}.filter-field{width:260px}.table-filters span{padding-bottom:11px;color:#475569;font-size:12px;font-weight:700}
</style>
