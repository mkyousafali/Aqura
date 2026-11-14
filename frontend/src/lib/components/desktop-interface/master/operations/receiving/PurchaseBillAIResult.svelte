<script>
	import { onDestroy } from 'svelte';
	import { _ as t } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { isAlmaraiSupplier } from '$lib/utils/purchaseSupplier';

	export let bill;
	export let idPrefix = 'purchase-bill';
	export let branchId;
	export let vendorId;
	export let vendorName = '';
	let activeResultTab = 'sales';
	let processingByTab = {
		sales: { rows: null, busy: false, count: 0, error: '', controller: null },
		returns: { rows: null, busy: false, count: 0, error: '', controller: null }
	};

	function handleResultTabKeydown(event) {
		let nextTab;
		if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
			nextTab = activeResultTab === 'sales' ? 'returns' : 'sales';
		} else if (event.key === 'Home') {
			nextTab = 'sales';
		} else if (event.key === 'End') {
			nextTab = 'returns';
		} else {
			return;
		}
		event.preventDefault();
		activeResultTab = nextTab;
		event.currentTarget.parentElement.querySelector(`[data-result-tab="${nextTab}"]`)?.focus();
	}

	const summaryFields = [
		{ field: 'vendorName', label: 'editVendor' },
		{ field: 'billNumber', label: 'editBillNumber' },
		{ field: 'billDate', label: 'editBillDate' },
		{ field: 'currency', label: 'purchaseAiCurrency' },
		{ field: 'totalQuantity', label: 'purchaseAiTotalQuantity' },
		{ field: 'costVatBasis', label: 'purchaseAiCostVatBasis' },
		{ field: 'subtotal', label: 'purchaseAiSubtotal' },
		{ field: 'vatAmount', label: 'purchaseAiVatAmount' },
		{ field: 'total', label: 'purchaseAiDocumentTotal' },
		{ field: 'creditNoteTotal', label: 'purchaseAiCreditTotal' },
		{ field: 'invoiceGrossTotal', label: 'purchaseAiGrossAfterCredits' },
		{ field: 'roundingAmount', label: 'purchaseAiRounding' },
		{ field: 'netPayable', label: 'purchaseAiNetPayable' }
	];
	const vatBasisLabels = {
		excluding_vat: 'purchaseVatExcluded',
		including_vat: 'purchaseVatIncluded',
		unclear: 'purchaseAiVatUnclear'
	};
	const itemColumns = [
		{ field: 'rowNumber', label: 'purchaseRowNumber' },
		{ field: 'name', label: 'purchaseProduct' },
		{ field: 'barcode', label: 'purchaseBarcode' },
		{ field: 'unit', label: 'purchaseUnit' },
		{ field: 'quantityPrinted', label: 'purchaseAiPrintedQuantity' },
		{ field: 'unitsPerCase', label: 'purchaseAiUnitsPerCase' },
		{ field: 'quantity', label: 'purchaseQuantity' },
		{ field: 'unitCost', label: 'purchaseUnitCost' },
		{ field: 'discount', label: 'purchaseAiDiscount' },
		{ field: 'amountBeforeVat', label: 'purchaseCostBeforeVat' },
		{ field: 'vatRate', label: 'purchaseAiVatRate' },
		{ field: 'vatAmount', label: 'purchaseAiVatAmount' },
		{ field: 'total', label: 'purchaseAiLineTotal' }
	];
	const processedColumns = [
		{ field: 'rowNumber', label: 'purchaseRowNumber' },
		{ field: 'name', label: 'purchaseAiBillProduct' },
		{ field: 'erpBarcode', label: 'purchaseAiErpBarcode' },
		{ field: 'erpName', label: 'purchaseAiErpProduct' },
		{ field: 'erpUnit', label: 'purchaseAiErpUnit' },
		{ field: 'conversionFactor', label: 'purchaseConversionFactor' },
		{ field: 'quantity', label: 'purchaseAiBillQuantity' },
		{ field: 'unitCost', label: 'purchaseAiBillUnitCost' },
		{ field: 'vatAmount', label: 'purchaseAiVatAmount' },
		{ field: 'total', label: 'purchaseAiLineTotal' },
		{ field: 'status', label: 'purchaseAiErpStatus' }
	];

	async function lookupErpProduct(barcode, signal) {
		const response = await authenticatedFetch('/api/erp-products', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'purchase-product', branchId, barcode }),
			signal
		});
		const result = await response.json();
		if (!response.ok || !result.success) {
			throw new Error(result.error || $t('receiving.records.purchaseLookupFailed'));
		}
		const product = result.product;
		const unit = product?.barcodes?.find((code) => String(code.barcode || '').trim().toLowerCase() === barcode.toLowerCase());
		if (!product?.name || !unit) {
			throw new Error($t('receiving.records.purchaseAiExactBarcodeMissing'));
		}
		return { name: product.name, barcode: unit.barcode, unit: unit.unit, conversionFactor: unit.multiFactor };
	}

	function nameMatchRow(item, candidates, productId = candidates[0]?.id) {
		const product = candidates.find((candidate) => candidate.id === productId);
		const unit = product?.barcodes.find((code) => code.multiFactor === 1 && code.unit)
			|| product?.barcodes.find((code) => code.multiFactor > 0 && code.unit)
			|| product?.barcodes[0];
		return {
			...item, candidates, selectedProductId: product?.id || '',
			erpName: product?.name || '', erpBarcode: unit?.barcode || '',
			erpUnit: unit?.unit || '', conversionFactor: unit?.multiFactor ?? null,
			processError: !product ? $t('receiving.records.purchaseAiNoNameMatches')
				: unit?.unit && unit.multiFactor > 0 ? '' : $t('receiving.records.purchaseAiErpUnitMissing')
		};
	}

	function selectNameMatch(tableId, rowIndex, productId) {
		const row = processingByTab[tableId].rows[rowIndex];
		processingByTab[tableId].rows[rowIndex] = nameMatchRow(row, row.candidates, productId);
	}

	function selectNameUnit(tableId, rowIndex, barcode) {
		const row = processingByTab[tableId].rows[rowIndex];
		const product = row.candidates.find((candidate) => candidate.id === row.selectedProductId);
		const unit = product?.barcodes.find((code) => code.barcode === barcode);
		processingByTab[tableId].rows[rowIndex] = {
			...row, erpBarcode: unit?.barcode || '', erpUnit: unit?.unit || '',
			conversionFactor: unit?.multiFactor ?? null,
			processError: unit?.unit && unit.multiFactor > 0 ? '' : $t('receiving.records.purchaseAiErpUnitMissing')
		};
	}

	async function processItems(tableId) {
		if (processingByTab[tableId].busy) return;
		processingByTab[tableId].error = '';
		if (!branchId) {
			processingByTab[tableId].error = $t('receiving.records.purchaseBranchRequired');
			return;
		}
		if (!barcodeMatching && !vendorId) {
			processingByTab[tableId].error = $t('receiving.records.purchaseAiVendorRequired');
			return;
		}
		const items = resultTables.find((table) => table.id === tableId).items;
		const controller = new AbortController();
		processingByTab[tableId] = { rows: null, busy: true, count: 0, error: '', controller };
		const lookups = new Map();
		const rows = [];
		try {
			if (!barcodeMatching) {
				const response = await authenticatedFetch('/api/erp-products', {
					method: 'POST', headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ action: 'purchase-name-matches', branchId, vendorId, names: items.map((item) => item.name || '') }),
					signal: controller.signal
				});
				const result = await response.json();
				if (processingByTab[tableId].controller !== controller) return;
				if (!response.ok || !result.success || !Array.isArray(result.matches) || result.matches.length !== items.length) {
					throw new Error(result.error || $t('receiving.records.purchaseLookupFailed'));
				}
				processingByTab[tableId].rows = items.map((item, index) => nameMatchRow(item, result.matches[index]));
				processingByTab[tableId].count = items.length;
				return;
			}
			for (let offset = 0; offset < items.length; offset += 4) {
				const batch = await Promise.all(items.slice(offset, offset + 4).map(async (item) => {
					const row = { ...item, erpName: '', erpUnit: '', conversionFactor: null, processError: '' };
					const barcode = String(item.barcode || '').trim();
					if (!barcode) {
						return { ...row, processError: $t('receiving.records.purchaseAiBarcodeRequired') };
					}
					try {
						const key = barcode.toLowerCase();
						if (!lookups.has(key)) lookups.set(key, lookupErpProduct(barcode, controller.signal));
						const product = await lookups.get(key);
						return {
							...row,
							erpName: product.name,
							erpBarcode: product.barcode,
							erpUnit: product.unit || '',
							conversionFactor: product.conversionFactor,
							processError: product.unit && product.conversionFactor > 0
								? '' : $t('receiving.records.purchaseAiErpUnitMissing')
						};
					} catch (error) {
						if (controller.signal.aborted) throw error;
						return { ...row, processError: error.message || $t('receiving.records.purchaseLookupFailed') };
					}
				}));
				if (processingByTab[tableId].controller !== controller) return;
				rows.push(...batch);
				processingByTab[tableId].rows = [...rows];
				processingByTab[tableId].count = rows.length;
			}
		} catch (error) {
			if (processingByTab[tableId].controller !== controller || controller.signal.aborted) return;
			processingByTab[tableId].error = error.message || $t('receiving.records.purchaseLookupFailed');
		} finally {
			if (processingByTab[tableId].controller === controller) {
				processingByTab[tableId].controller = null;
				processingByTab[tableId].busy = false;
			}
		}
	}

	onDestroy(() => {
		for (const state of Object.values(processingByTab)) {
			state.controller?.abort();
			state.controller = null;
		}
	});

	function groupItemsByEntryType(sourceBill) {
		const sales = { id: 'sales', label: 'purchaseAiSales', documents: [], items: [], notes: [] };
		const returns = { id: 'returns', label: 'purchaseAiReturns', documents: [], items: [], notes: [] };
		const documents = [sourceBill, ...(sourceBill.creditNotes || [])];
		for (const [documentIndex, document] of documents.entries()) {
			const sections = document.sections || [{
				kind: documentIndex === 0 ? 'purchases' : 'returns',
				items: document.items || []
			}];
			for (const section of sections) {
				const isReturn = documentIndex > 0 || section.kind === 'returns' || section.kind === 'buyback';
				const table = isReturn ? returns : sales;
				if (!table.documents.includes(document)) table.documents.push(document);
				const rowOffset = table.items.length;
				table.items.push(...section.items);
				if (section.notes) {
					table.notes.push(section.notes.replace(/\bRow (\d+):/g, (_, row) => `Row ${rowOffset + Number(row)}:`));
				}
			}
		}
		return [sales, returns];
	}

	$: resultTables = groupItemsByEntryType(bill);
	$: barcodeMatching = isAlmaraiSupplier(vendorName, bill.vendorName);
</script>


<div class="bill-ai-content">
	<div class="result-tabs" role="tablist" aria-label={$t('receiving.records.purchaseAiResults')}>
		{#each resultTables as resultTable}
			<button
				type="button" role="tab"
				id={`${idPrefix}-${resultTable.id}-tab`}
				aria-controls={`${idPrefix}-${resultTable.id}-panel`}
				aria-selected={activeResultTab === resultTable.id}
				tabindex={activeResultTab === resultTable.id ? 0 : -1}
				data-result-tab={resultTable.id}
				class:active-tab={activeResultTab === resultTable.id}
				on:click={() => activeResultTab = resultTable.id}
				on:keydown={handleResultTabKeydown}
			>{$t(`receiving.records.${resultTable.label}`)}</button>
		{/each}
	</div>

	{#each resultTables as resultTable}
		{@const processing = processingByTab[resultTable.id]}
		{@const showProcessed = processing.rows !== null}
		{@const columns = showProcessed ? processedColumns : itemColumns}
		{@const rows = showProcessed ? processing.rows : resultTable.items}
		<div
			class="bill-table-panel" role="tabpanel"
			id={`${idPrefix}-${resultTable.id}-panel`}
			aria-labelledby={`${idPrefix}-${resultTable.id}-tab`}
			hidden={activeResultTab !== resultTable.id}
			tabindex="0"
		>
			<div class="process-toolbar">
				<button type="button" class="process-button" on:click={() => processItems(resultTable.id)} disabled={processing.busy || !resultTable.items.length}>
					{$t(processing.busy ? 'receiving.records.purchaseAiProcessing' : 'receiving.records.purchaseAiProcess')}
				</button>
				{#if processing.busy}
					<span role="status">{$t('receiving.records.purchaseAiProcessProgress', { done: processing.count, total: resultTable.items.length })}</span>
				{/if}
				{#if processing.error}<span class="processing-error" role="alert">{processing.error}</span>{/if}
			</div>
			<div class="panel-details">
				{#each resultTable.documents as document}
					<div class="bill-document">
						{#if bill.creditNotes?.length}
							<h4>{$t(document === bill ? 'receiving.records.purchaseAiInvoiceDocument' : 'receiving.records.purchaseAiCreditNote')}</h4>
						{/if}
						<dl class="bill-summary">
							{#each summaryFields as field}
								{#if document[field.field]}
									<div>
										<dt>{$t(`receiving.records.${field.label}`)}</dt>
										<dd title={document[field.field]} dir="auto">
											{#if field.field === 'costVatBasis'}
												{$t(`receiving.records.${vatBasisLabels[document.costVatBasis] || 'purchaseAiVatUnclear'}`)}
											{:else}
												{document[field.field]}
											{/if}
										</dd>
									</div>
								{/if}
							{/each}
						</dl>
						{#if document.notes}<p class="bill-message">{document.notes}</p>{/if}
					</div>
				{/each}
				{#each resultTable.notes as note}<p class="bill-message">{note}</p>{/each}
			</div>
			{#if rows.length}
				<div class="table-container" tabindex="0" role="region" aria-label={$t(`receiving.records.${resultTable.label}`)}>
					<table>
						<thead>
							<tr>
								{#each columns as column}
									<th scope="col">{$t(`receiving.records.${column.label}`)}</th>
								{/each}
							</tr>
						</thead>
						<tbody>
							{#each rows as item, itemIndex}
								<tr>
									{#each columns as column}
										<td dir="auto" class:product-cell={column.field === 'name' || column.field === 'erpName'}>
											{#if column.field === 'status'}
												<span class:processing-error={!!item.processError}>{item.processError || $t(item.candidates ? 'receiving.records.purchaseAiSuggestedMatch' : 'receiving.records.purchaseAiErpMatched')}</span>
											{:else if column.field === 'erpName' && item.candidates?.length}
												<select aria-label={$t('receiving.records.purchaseAiClosestMatches')} value={item.selectedProductId}
													on:change={(event) => selectNameMatch(resultTable.id, itemIndex, event.currentTarget.value)}>
													{#each item.candidates as candidate}
														<option value={candidate.id}>{candidate.name}</option>
													{/each}
												</select>
											{:else if column.field === 'erpUnit' && item.candidates?.length}
												{@const product = item.candidates.find((candidate) => candidate.id === item.selectedProductId)}
												<select aria-label={$t('receiving.records.purchaseAiErpUnit')} value={item.erpBarcode}
													disabled={!product?.barcodes.length}
													on:change={(event) => selectNameUnit(resultTable.id, itemIndex, event.currentTarget.value)}>
													{#each product?.barcodes || [] as code}
														<option value={code.barcode}>{code.unit || '—'} · {code.multiFactor ?? '—'} · {code.barcode}</option>
													{/each}
													{#if !product?.barcodes.length}<option value="">—</option>{/if}
												</select>
											{:else}
												{column.field === 'rowNumber' ? itemIndex + 1 : item[column.field] ?? ''}
											{/if}
											{#if column.field === 'name' && item.notes}<small>{item.notes}</small>{/if}
										</td>
									{/each}
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<p class="bill-message">{$t(resultTable.id === 'returns' ? 'receiving.records.purchaseAiNoReturns' : 'receiving.records.purchaseAiNoItems')}</p>
			{/if}
		</div>
	{/each}
</div>

<style>
	.bill-ai-content {
		display: flex;
		flex: 1;
		min-height: 0;
		flex-direction: column;
		overflow: hidden;
	}

	.result-tabs {
		display: flex;
		flex-shrink: 0;
		gap: 4px;
		border-bottom: 1px solid #e2e8f0;
	}

	.result-tabs button {
		padding: 6px 12px;
		border: 0;
		border-bottom: 2px solid transparent;
		background: transparent;
		color: #64748b;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
	}

	.result-tabs button.active-tab {
		border-bottom-color: #4f46e5;
		background: #eef2ff;
		color: #4338ca;
	}

	.bill-table-panel {
		display: flex;
		flex: 1;
		min-height: 0;
		flex-direction: column;
		overflow: hidden;
	}

	.bill-table-panel[hidden] {
		display: none;
	}

	.panel-details {
		flex: 0 1 auto;
		min-height: 0;
		max-height: 38%;
		overflow: auto;
	}

	.process-toolbar {
		display: flex;
		flex-shrink: 0;
		align-items: center;
		gap: 8px;
		padding: 6px 0;
		font-size: 11px;
	}

	.process-button {
		padding: 5px 10px;
		border: 0;
		border-radius: 5px;
		background: #059669;
		color: white;
		font-size: 11px;
		font-weight: 600;
		cursor: pointer;
	}

	.process-button:disabled {
		opacity: 0.6;
		cursor: default;
	}

	.processing-error {
		color: #b91c1c;
	}

	.bill-document + .bill-document {
		margin-top: 12px;
		padding-top: 8px;
		border-top: 1px solid #c7d2fe;
	}

	h4 {
		margin: 4px 0;
		color: #3730a3;
		font-size: 12px;
		font-weight: 600;
	}

	.bill-summary {
		display: flex;
		flex-wrap: wrap;
		gap: 6px 16px;
		margin: 4px 0 8px;
	}

	.bill-summary > div {
		max-width: 240px;
	}

	dt {
		color: #64748b;
		font-size: 10px;
		line-height: 14px;
	}

	dd {
		overflow: hidden;
		margin: 0;
		color: #1e293b;
		font-size: 12px;
		font-weight: 600;
		line-height: 18px;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.bill-message,
	small {
		color: #475569;
		font-size: 11px;
		white-space: pre-wrap;
	}

	.bill-message {
		margin: 6px 0;
	}

	small {
		display: block;
		margin-top: 3px;
	}

	.table-container {
		flex: 1;
		min-height: 0;
		overflow: auto;
		overscroll-behavior: contain;
	}

	table {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		font-size: 12px;
	}

	th,
	td {
		min-width: 60px;
		padding: 5px 10px;
		border-bottom: 1px solid #e2e8f0;
		text-align: start;
	}

	th {
		position: sticky;
		top: 0;
		z-index: 1;
		background: #f8fafc;
		color: #64748b;
		font-size: 10px;
		font-weight: 600;
	}

	.product-cell {
		min-width: 180px;
	}

	select {
		width: 100%;
		min-width: 180px;
		max-width: 340px;
		padding: 4px 6px;
		border: 1px solid #cbd5e1;
		border-radius: 4px;
		background: white;
		color: #1e293b;
		font: inherit;
	}
</style>
