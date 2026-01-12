<script>
	import { read, utils } from 'xlsx';

	let selectedBank = null;
	let transactions = [];
	let fileInput;
	let showPreview = false;

	function handleFileUpload(event) {
		const file = event.target.files[0];
		if (!file) {
			console.log('No file selected');
			return;
		}

		console.log('File selected:', file.name, file.size, file.type);

		const reader = new FileReader();
		reader.onload = (e) => {
			try {
				console.log('File read, starting parse...');
				const data = new Uint8Array(e.target.result);
				console.log('Data buffer created, size:', data.length);
				
				const workbook = read(data, { type: 'array' });
				console.log('Workbook parsed, sheets:', workbook.SheetNames);
				
				const sheetName = workbook.SheetNames[0];
				const worksheet = workbook.Sheets[sheetName];
				const jsonData = utils.sheet_to_json(worksheet);
				
				console.log('Parsed rows:', jsonData.length);
				console.log('First row:', jsonData[0]);
				
				transactions = parseExcelData(jsonData);
				console.log('Transactions parsed:', transactions.length);
				
				showPreview = true;
			} catch (error) {
				console.error('Error details:', error);
				console.error('Error message:', error.message);
				console.error('Error stack:', error.stack);
				alert('Error parsing file: ' + error.message);
			}
		};

		reader.onerror = (error) => {
			console.error('FileReader error:', error);
			alert('Error reading file');
		};

		console.log('Starting to read file as ArrayBuffer...');
		reader.readAsArrayBuffer(file);
	}

	function proceedToTable() {
		showPreview = false;
	}

	function clearData() {
		transactions = [];
		showPreview = false;
	}

	function parseExcelData(jsonData) {
		if (!Array.isArray(jsonData) || jsonData.length === 0) return [];

		const data = [];

		for (const row of jsonData) {
			// Get column values - handle different possible column names
			const date = row['Value Date'] || row['Date'] || row['date'] || row['DATE'] || '';
			const details = row['Details'] || row['details'] || '';
			const refNoFromExcel = row['Reference No'] || row['Reference Number'] || '';
			const transType = row['Transaction Type'] || row['Type'] || '';

			// Skip empty rows
			if (!date) {
				console.log('Skipping row: no date');
				continue;
			}

			// Extract amounts from correct columns
			let creditStr = row['Credit Amount'] || row['Credit'] || '0';
			let debitStr = row['Debit Amount'] || row['Debit'] || '0';

			const creditAmount = parseAmount(creditStr);
			const debitAmount = parseAmount(debitStr);

			// Extract detailed info from Details column
			const purchaseAmount = extractPurchaseAmount(details) || creditAmount;
			const sysRef = extractSystemReference(details, refNoFromExcel);
			const fee = extractFee(details);
			const vat = extractVAT(details);
			const terminalId = extractTerminalId(details);
			const reconId = extractReconId(details);

			// Build transaction type with card type if available
			let finalTransType = transType;
			if (details.includes('MADA')) {
				finalTransType = 'ONLINE POS CREDIT (MADA)';
			} else if (details.includes('VISA')) {
				finalTransType = 'POS SETTLEMENT (VISA)';
			} else if (details.includes('MASTERCARD')) {
				finalTransType = 'POS SETTLEMENT (MASTERCARD)';
			}

			const row_data = {
				date: date.toString(),
				transactionType: finalTransType,
				amountPurchase: purchaseAmount,
				creditAmount: creditAmount,
				debitAmount: debitAmount,
				fee: fee,
				vat: vat,
				referenceNumber: sysRef,
				terminalId: terminalId,
				reconciliationId: reconId
			};
			console.log('Added transaction:', row_data);
			data.push(row_data);
		}

		return data;
	}

	function extractTransactionType(type) {
		if (!type) return '-';
		if (type.includes('ONLINE POS') || type.includes('MADA')) return 'ONLINE POS CREDIT (MADA)';
		if (type.includes('Outgoing Transfer')) return 'Outgoing Transfer';
		if (type.includes('VISA')) return 'POS SETTLEMENT (VISA)';
		if (type.includes('MASTERCARD')) return 'POS SETTLEMENT (MASTERCARD)';
		if (type.includes('LOW VOLUME')) return 'POS LOW VOLUME FEE';
		if (type.includes('POS TRAN')) return 'POS TRAN. SETTLEMENT';
		return type.substring(0, 40);
	}

	function parseAmount(value) {
		if (value === null || value === undefined || value === '') return 0.00;
		// If already a number, just return it
		if (typeof value === 'number') return value;
		// If string, remove commas and convert
		const num = parseFloat(value.toString().replace(/,/g, ''));
		return isNaN(num) ? 0.00 : num;
	}

	function extractFee(details) {
		const match = details.match(/FEE\s+([\d,\.]+)\s+SAR/i);
		return match ? parseFloat(match[1].replace(/,/g, '')) : 0.00;
	}

	function extractVAT(details) {
		// Try both "VAT Amount:" and "VAT AMOUNT" patterns
		let match = details.match(/VAT\s+Amount:\s+([\d,\.]+)\s+SAR/i);
		if (match) return parseFloat(match[1].replace(/,/g, ''));
		
		match = details.match(/VAT\s+AMOUNT\s+([\d,\.]+)\s+SAR/i);
		if (match) return parseFloat(match[1].replace(/,/g, ''));
		
		return 0.00;
	}

	function extractTerminalId(details) {
		// Try "TERM. ID:" pattern first (for MADA)
		let match = details.match(/TERM\.\s+ID:\s+(\d+)/i);
		if (match) return match[1];
		
		// Try "TERMINAL ID" pattern
		match = details.match(/TERMINAL\s+ID\s+(\d+)/i);
		if (match) return match[1];
		
		// For VISA/MASTERCARD: look for pattern "FEE X.XX SAR,NNNNNNNN,"
		match = details.match(/FEE\s+[\d\.]+\s+SAR,(\d+),/i);
		if (match) return match[1];
		
		return '—';
	}

	function extractReconId(details) {
		const match = details.match(/RECON#:\s+(\d+)/i);
		return match ? match[1] : '—';
	}

	function extractPurchaseAmount(details) {
		const match = details.match(/PURCHASE\s+AMT:\s+([\d,\.]+)\s+SAR/i);
		return match ? parseFloat(match[1].replace(/,/g, '')) : 0.00;
	}

	function extractSystemReference(details, referenceFromExcel) {
		// Use the reference from Excel column first
		if (referenceFromExcel && referenceFromExcel.trim() && referenceFromExcel !== 'Reference No') {
			return referenceFromExcel;
		}
		
		// Look for SYS.REF pattern
		let match = details.match(/SYS\.REF:\s*([^\s,()]+)/i);
		if (match) return match[1];
		
		// Look for REF pattern (for POS LOW VOLUME FEE)
		match = details.match(/REF\s+(\d+)/i);
		if (match) return match[1];
		
		// Look for reference number pattern like "000193142791"
		match = details.match(/(\d{12})\s+\d+\/\d+\/\d+/);
		if (match) return match[1];
		
		return '—';
	}
</script>

<div class="bank-reconciliation-container">
	{#if !selectedBank}
		<div class="banks-grid">
			<button class="bank-button" on:click={() => selectedBank = 'card1'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Card 1</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'card2'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Card 2</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'card3'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Card 3</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'card4'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Card 4</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'riyad'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Riyad Bank</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'ncb'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">NCB</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'rajhi'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Rajhi</span>
			</button>

			<button class="bank-button" on:click={() => selectedBank = 'bilad'}>
				<span class="bank-icon">🏦</span>
				<span class="bank-name">Al Bilad</span>
			</button>
		</div>
	{:else}
		<div class="bank-view">
			<div class="bank-header">
				<button class="btn-back" on:click={() => { selectedBank = null; transactions = []; }}>
					← Back
				</button>
				<h2>
					{selectedBank === 'riyad' ? 'Riyad Bank' : 
					 selectedBank === 'ncb' ? 'NCB' : 
					 selectedBank === 'rajhi' ? 'Rajhi' : 
					 selectedBank === 'bilad' ? 'Al Bilad' :
					 selectedBank === 'card1' ? 'Card 1' :
					 selectedBank === 'card2' ? 'Card 2' :
					 selectedBank === 'card3' ? 'Card 3' :
					 selectedBank === 'card4' ? 'Card 4' : 'Bank'}
				</h2>
			</div>

			{#if transactions.length === 0}
				<div class="import-section">
					<button class="btn-import" on:click={() => fileInput.click()}>
						📥 Import Excel
					</button>
					<input 
						type="file"
						accept=".xlsx,.xls,.csv,.tsv"
						bind:this={fileInput}
						on:change={handleFileUpload}
						style="display: none;"
					/>
				</div>
			{:else if showPreview}
				<div class="preview-section">
					<div class="preview-header">
						<h3>📋 Import Preview</h3>
						<p>{transactions.length} transactions found</p>
					</div>

					<div class="preview-cards">
						{#each transactions.slice(0, 5) as trans, idx}
							<div class="preview-card">
								<div class="card-row">
									<span class="label">Date:</span>
									<span class="value">{trans.date}</span>
								</div>
								<div class="card-row">
									<span class="label">Type:</span>
									<span class="value">{trans.transactionType}</span>
								</div>
								<div class="card-row">
									<span class="label">Amount:</span>
									<span class="value amount">{trans.amountPurchase.toFixed(2)} SAR</span>
								</div>
								<div class="card-row">
									<span class="label">Reference:</span>
									<span class="value">{trans.referenceNumber}</span>
								</div>
							</div>
						{/each}
					</div>

					{#if transactions.length > 5}
						<div class="preview-more">
							<p>... and {transactions.length - 5} more transactions</p>
						</div>
					{/if}

					<div class="preview-actions">
						<button class="btn-cancel" on:click={clearData}>
							← Clear & Import Again
						</button>
						<button class="btn-proceed" on:click={proceedToTable}>
							✓ Proceed to Table
						</button>
					</div>
				</div>
			{:else}
				<div class="table-section">
					<div class="table-wrapper">
						<table>
							<thead>
								<tr>
									<th>Date</th>
									<th>Transaction Type</th>
									<th>Amount (Purchase)</th>
									<th>Credit Amount (SAR)</th>
									<th>Debit Amount (SAR)</th>
									<th>Fee (SAR)</th>
									<th>VAT (SAR)</th>
									<th>Reference Number</th>
									<th>Terminal ID</th>
									<th>Reconciliation ID</th>
								</tr>
							</thead>
							<tbody>
								{#each transactions as trans, idx (idx)}
									<tr>
										<td>{trans.date}</td>
										<td>{trans.transactionType}</td>
										<td>{trans.amountPurchase.toFixed(2)}</td>
										<td>{trans.creditAmount.toFixed(2)}</td>
										<td>{trans.debitAmount.toFixed(2)}</td>
										<td>{trans.fee.toFixed(2)}</td>
										<td>{trans.vat.toFixed(2)}</td>
										<td>{trans.referenceNumber}</td>
										<td>{trans.terminalId}</td>
										<td>{trans.reconciliationId}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.bank-reconciliation-container {
		padding: 2rem;
		background: #f8fafc;
		height: 100vh;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.banks-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 12px;
		flex: 1;
		align-content: start;
	}

	.bank-button {
		padding: 12px 8px;
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.bank-button:hover {
		border-color: #667eea;
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
		transform: translateY(-2px);
	}

	.bank-icon {
		font-size: 1.5rem;
	}

	.bank-name {
		font-size: 0.85rem;
		font-weight: 600;
		color: #1e293b;
	}

	.bank-view {
		display: flex;
		flex-direction: column;
		height: 100%;
		gap: 12px;
	}

	.bank-header {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.bank-header h2 {
		margin: 0;
		font-size: 1.3rem;
		color: #1e293b;
		flex: 1;
	}

	.btn-back {
		padding: 8px 12px;
		background: #f1f5f9;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 600;
		font-size: 14px;
		color: #475569;
		transition: all 0.2s;
	}

	.btn-back:hover {
		background: #e2e8f0;
	}

	.import-section {
		display: flex;
		justify-content: center;
		align-items: center;
		flex: 1;
	}

	.btn-import {
		padding: 16px 32px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-import:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.preview-section {
		padding: 24px;
		display: flex;
		flex-direction: column;
		gap: 20px;
		flex: 1;
		overflow-y: auto;
	}

	.preview-header {
		text-align: center;
	}

	.preview-header h3 {
		margin: 0 0 8px 0;
		font-size: 1.2rem;
		color: #1e293b;
	}

	.preview-header p {
		margin: 0;
		color: #64748b;
		font-size: 14px;
	}

	.preview-cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 16px;
	}

	.preview-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.card-row {
		display: flex;
		justify-content: space-between;
		gap: 12px;
		margin-bottom: 12px;
		font-size: 13px;
	}

	.card-row:last-child {
		margin-bottom: 0;
	}

	.card-row .label {
		font-weight: 600;
		color: #475569;
		min-width: 80px;
	}

	.card-row .value {
		color: #1e293b;
		text-align: right;
		flex: 1;
	}

	.card-row .amount {
		font-weight: 600;
		color: #059669;
	}

	.preview-more {
		text-align: center;
		padding: 16px;
		background: #f8fafc;
		border-radius: 8px;
		color: #64748b;
		font-size: 14px;
	}

	.preview-actions {
		display: flex;
		gap: 12px;
		justify-content: center;
		padding-top: 16px;
		border-top: 2px solid #e5e7eb;
	}

	.btn-cancel {
		padding: 12px 24px;
		background: #f1f5f9;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 14px;
		color: #475569;
		transition: all 0.2s;
	}

	.btn-cancel:hover {
		background: #e2e8f0;
	}

	.btn-proceed {
		padding: 12px 24px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 14px;
		transition: all 0.2s;
	}

	.btn-proceed:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	.table-section {
		flex: 1;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.table-wrapper {
		flex: 1;
		overflow: auto;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
	}

	table thead {
		background: #f8fafc;
		position: sticky;
		top: 0;
		border-bottom: 2px solid #e5e7eb;
	}

	table th {
		padding: 10px 12px;
		text-align: left;
		font-weight: 700;
		color: #374151;
		white-space: nowrap;
		border-right: 1px solid #e5e7eb;
	}

	table th:last-child {
		border-right: none;
	}

	table tbody tr {
		border-bottom: 1px solid #e5e7eb;
	}

	table tbody tr:hover {
		background: #f9fafb;
	}

	table td {
		padding: 10px 12px;
		color: #374151;
		border-right: 1px solid #e5e7eb;
	}

	table td:last-child {
		border-right: none;
	}
</style>
