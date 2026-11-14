<script>
	import { onDestroy, tick } from 'svelte';
	import { _ as t } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import PurchaseBillAIResult from './PurchaseBillAIResult.svelte';

	export let record = {};
	export let branchName = '';

	const entryTabs = [
		{ id: 'ai', label: 'purchaseAiEntry' },
		{ id: 'manual', label: 'purchaseManualEntry' }
	];
	let activeEntryTab = 'manual';

	function handleEntryTabKeydown(event) {
		let nextTab;
		if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
			nextTab = activeEntryTab === 'ai' ? 'manual' : 'ai';
		} else if (event.key === 'Home') {
			nextTab = 'ai';
		} else if (event.key === 'End') {
			nextTab = 'manual';
		} else {
			return;
		}
		event.preventDefault();
		activeEntryTab = nextTab;
		event.currentTarget.parentElement.querySelector(`[data-entry-tab="${nextTab}"]`)?.focus();
	}

	let products = [];
	let showProductPopup = false;
	let barcode = '';
	let lookupLoading = false;
	let lookupError = '';
	let barcodeInput;
	let quantityInput;
	let rowNumberInput;
	let costInput;
	let addButton;
	let lookupController = null;
	let pendingProduct = null;
	let editingProductId = null;
	let quantity;
	let cost;
	let costIncludesVat = false;
	const vatPercent = 15;
	let rowNumber = 1;
	let nextProductId = 1;
	let entryError = '';
	let tableError = '';
	let aiBill = null;
	let aiReading = false;
	let aiError = '';
	let showAiBill = false;
	let aiController = null;

	async function readOriginalBill() {
		if (aiReading) return;
		showAiBill = true;
		aiBill = null;
		aiError = '';
		if (!record.id || !record.original_bill_url) {
			aiError = $t('receiving.records.purchaseAiMissingBill');
			return;
		}
		const controller = new AbortController();
		aiController = controller;
		aiReading = true;
		try {
			const response = await authenticatedFetch('/api/receiving-records/extract-items', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ recordId: record.id }),
				signal: controller.signal
			});
			const result = await response.json();
			if (aiController !== controller) return;
			if (!response.ok || !result.success) {
				throw new Error(result.error || $t('receiving.records.purchaseAiFailed'));
			}
			aiBill = result.bill;
		} catch (error) {
			if (aiController !== controller || controller.signal.aborted) return;
			aiError = error.message || $t('receiving.records.purchaseAiFailed');
		} finally {
			if (aiController === controller) {
				aiController = null;
				aiReading = false;
			}
		}
	}

	function closeAiBill() {
		aiController?.abort();
		aiController = null;
		aiReading = false;
		showAiBill = false;
	}

	function resetProduct() {
		pendingProduct = null;
		entryError = '';
		lookupError = '';
	}

	function focusBarcode(node) {
		node.focus();
	}

	function closeProductPopup() {
		lookupController?.abort();
		lookupController = null;
		lookupLoading = false;
		showProductPopup = false;
		editingProductId = null;
		barcode = '';
		resetProduct();
		addButton?.focus();
	}

	async function lookupProduct() {
		const scannedBarcode = barcode.trim();
		if (lookupLoading || !scannedBarcode) return;
		resetProduct();
		if (scannedBarcode.length > 100 || /[\u0000-\u001f\u007f]/.test(scannedBarcode)) {
			lookupError = $t('receiving.records.purchaseInvalidBarcode');
			return;
		}
		if (!record.branch_id) {
			lookupError = $t('receiving.records.purchaseBranchRequired');
			return;
		}

		const controller = new AbortController();
		lookupController = controller;
		lookupLoading = true;
		try {
			const response = await authenticatedFetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'purchase-product', branchId: record.branch_id, barcode: scannedBarcode }),
				signal: controller.signal
			});
			const result = await response.json();
			if (lookupController !== controller) return;
			if (!response.ok || !result.success) {
				throw new Error(result.error || result.message || $t('receiving.records.purchaseLookupFailed'));
			}
			if (!result.product?.name || !result.product.barcodes?.length) {
				throw new Error($t('receiving.records.purchaseProductNotFound'));
			}

			pendingProduct = result.product;
			if (editingProductId === null) {
				quantity = undefined;
				cost = undefined;
				const usedRowNumbers = new Set(products.map((item) => item.rowNumber));
				rowNumber = 1;
				while (usedRowNumbers.has(rowNumber)) {
					rowNumber += 1;
				}
			}
		} catch (error) {
			if (lookupController !== controller || controller.signal.aborted) return;
			lookupError = error.message || $t('receiving.records.purchaseLookupFailed');
		} finally {
			if (lookupController === controller) {
				lookupController = null;
				lookupLoading = false;
				// Wait for Svelte to re-enable the field before focusing it.
				await tick();
				if (!pendingProduct) {
					barcodeInput?.focus();
					barcodeInput?.select();
				}
			}
		}
	}

	function rowNumberError(value, exceptId) {
		const number = Number(value);
		if (!Number.isSafeInteger(number) || number < 1) return $t('receiving.records.purchaseInvalidRow');
		if (products.some((item) => item.id !== exceptId && item.rowNumber === number)) {
			return $t('receiving.records.purchaseDuplicateRow');
		}
		return '';
	}

	function quantityError() {
		const value = Number(quantity);
		return Number.isFinite(value) && value > 0
			? ''
			: $t('receiving.records.purchaseInvalidQuantity');
	}

	function focusRowNumber(event) {
		if (event.key !== 'Enter' || event.isComposing) return;
		event.preventDefault();
		event.stopPropagation();
		entryError = quantityError();
		if (entryError) return;
		rowNumberInput?.focus();
		rowNumberInput?.select();
	}

	function focusCost(event) {
		if (event.key !== 'Enter' || event.isComposing) return;
		event.preventDefault();
		event.stopPropagation();
		entryError = rowNumberError(rowNumber, editingProductId);
		if (entryError) return;
		costInput?.focus();
	}

	function calculateLineAmounts(product, includesVat) {
		if (product.cost == null) return null;
		const enteredCents = Math.round((product.cost * product.quantity + Number.EPSILON) * 100);
		const beforeVatCents = includesVat
			? Math.round(enteredCents / (1 + vatPercent / 100))
			: enteredCents;
		const vatCents = includesVat
			? enteredCents - beforeVatCents
			: Math.round(beforeVatCents * vatPercent / 100);
		return {
			beforeVat: beforeVatCents / 100,
			vat: vatCents / 100,
			total: (beforeVatCents + vatCents) / 100
		};
	}

	async function addProduct() {
		if (!pendingProduct || lookupLoading) return;
		entryError = rowNumberError(rowNumber, editingProductId);
		if (entryError) return;
		entryError = quantityError();
		if (entryError) return;
		const enteredCost = cost == null || cost === '' ? null : Number(cost);
		if (enteredCost !== null && (!Number.isFinite(enteredCost) || enteredCost < 0
			|| !Number.isSafeInteger(Math.round(enteredCost * Number(quantity) * 100 * (1 + vatPercent / 100))))) {
			entryError = $t('receiving.records.purchaseInvalidCost');
			return;
		}
		const updatedProduct = {
			id: editingProductId ?? nextProductId++,
			rowNumber: Number(rowNumber),
			quantity: Number(quantity),
			cost: enteredCost,
			barcode: pendingProduct.scannedBarcode,
			name: pendingProduct.name,
			unit: scannedCode?.unit || '',
			multiFactor: scannedCode?.multiFactor ?? null,
			erpProduct: pendingProduct
		};
		if (editingProductId === null) {
			products = [...products, updatedProduct];
		} else {
			products = products.map((item) => item.id === editingProductId ? updatedProduct : item);
		}
		products = products.sort((first, second) => first.rowNumber - second.rowNumber);
		editingProductId = null;
		tableError = '';
		barcode = '';
		resetProduct();
		await tick();
		barcodeInput?.focus();
	}

	async function editProduct(product) {
		lookupController?.abort();
		lookupController = null;
		lookupLoading = false;
		resetProduct();
		tableError = '';
		editingProductId = product.id;
		showProductPopup = true;
		barcode = product.barcode;
		pendingProduct = product.erpProduct || {
			name: product.name,
			scannedBarcode: product.barcode,
			barcodes: [{ barcode: product.barcode, unit: product.unit, multiFactor: product.multiFactor }]
		};
		quantity = product.quantity;
		rowNumber = product.rowNumber;
		cost = product.cost ?? undefined;
		await tick();
		quantityInput?.focus();
	}

	function removeProduct(productId) {
		if (editingProductId === productId) closeProductPopup();
		products = products.filter((item) => item.id !== productId);
		tableError = '';
	}

	function changeRowNumber(event, product) {
		const input = event.currentTarget;
		tableError = rowNumberError(input.value, product.id);
		if (tableError) {
			input.value = String(product.rowNumber);
			return;
		}
		products = products.map((item) => item.id === product.id ? { ...item, rowNumber: Number(input.value) } : item)
			.sort((first, second) => first.rowNumber - second.rowNumber);
	}

	onDestroy(() => {
		lookupController?.abort();
		lookupController = null;
		aiController?.abort();
		aiController = null;
	});

	$: scannedCode = pendingProduct?.barcodes.find((item) => item.barcode === pendingProduct.scannedBarcode);

	$: billAmount = record.bill_amount == null || record.bill_amount === ''
		? NaN
		: Number(record.bill_amount);
	$: formattedBillAmount = Number.isFinite(billAmount)
		? billAmount.toFixed(2)
		: $t('receiving.records.naText');
</script>

<div class="purchase-entry bg-white">
	<div class="purchase-header">
	<dl class="purchase-summary">
		<div>
			<dt>{$t('receiving.records.editVendor')}</dt>
			<dd title={record.vendors?.vendor_name}>{record.vendors?.vendor_name || $t('receiving.records.naText')}</dd>
		</div>
		<div>
			<dt>{$t('receiving.records.colBranch')}</dt>
			<dd title={branchName}>{branchName || $t('receiving.records.naText')}</dd>
		</div>
		<div>
			<dt>{$t('receiving.records.editBillNumber')}</dt>
			<dd title={record.bill_number}>{record.bill_number || $t('receiving.records.naText')}</dd>
		</div>
		<div>
			<dt>{$t('receiving.records.billAmountBeforeReturns')}</dt>
			<dd class="amount">{formattedBillAmount}</dd>
		</div>
		<div>
			<dt>{$t('receiving.records.purchaseUnitCost')}</dt>
			<dd>
				<label class="vat-toggle">
					<input type="checkbox" role="switch" bind:checked={costIncludesVat} />
					<span>{$t(costIncludesVat ? 'receiving.records.purchaseVatIncluded' : 'receiving.records.purchaseVatExcluded')}</span>
				</label>
			</dd>
		</div>
	</dl>
	</div>

	<div class="entry-tabs" role="tablist" aria-label={$t('receiving.records.purchaseEntryTitle')}>
		{#each entryTabs as tab}
			<button
				type="button"
				role="tab"
				id={`purchase-${record.id}-${tab.id}-tab`}
				aria-controls={`purchase-${record.id}-${tab.id}-panel`}
				aria-selected={activeEntryTab === tab.id}
				tabindex={activeEntryTab === tab.id ? 0 : -1}
				data-entry-tab={tab.id}
				class:active-tab={activeEntryTab === tab.id}
				on:click={() => activeEntryTab = tab.id}
				on:keydown={handleEntryTabKeydown}
			>{$t(`receiving.records.${tab.label}`)}</button>
		{/each}
	</div>

	<div
		class="entry-panel ai-entry-panel"
		role="tabpanel"
		id={`purchase-${record.id}-ai-panel`}
		aria-labelledby={`purchase-${record.id}-ai-tab`}
		hidden={activeEntryTab !== 'ai'}
		tabindex="0"
	>
		<div class="ai-entry-toolbar">
		<button
			type="button"
			class="read-ai-button"
			on:click={readOriginalBill}
			disabled={aiReading || !record.original_bill_url}
			title={$t(record.original_bill_url ? 'receiving.records.purchaseAiRead' : 'receiving.records.purchaseAiMissingBill')}
		>{$t(aiReading ? 'receiving.records.purchaseAiReading' : 'receiving.records.purchaseAiRead')}</button>
		</div>

	{#if showAiBill}
		<section class="bill-ai-results" aria-label={$t('receiving.records.purchaseAiResults')} aria-busy={aiReading}>
			<div class="bill-ai-heading">
				<h3>{$t('receiving.records.purchaseAiResults')}</h3>
				<button type="button" class="close-popup-button" on:click={closeAiBill} aria-label={$t('receiving.records.cancel')}>×</button>
			</div>
			{#if aiReading}
				<p class="bill-ai-message" role="status">{$t('receiving.records.purchaseAiReading')}</p>
			{:else if aiError}
				<p class="lookup-error" role="alert">{aiError}</p>
			{:else if aiBill}
				<PurchaseBillAIResult bill={aiBill} branchId={record.branch_id} vendorId={record.vendor_id}
					vendorName={record.vendors?.vendor_name || ''} idPrefix={`purchase-bill-${record.id}`} />
			{/if}
		</section>
	{/if}
	</div>

	<div
		class="entry-panel manual-entry-panel"
		role="tabpanel"
		id={`purchase-${record.id}-manual-panel`}
		aria-labelledby={`purchase-${record.id}-manual-tab`}
		hidden={activeEntryTab !== 'manual'}
		tabindex="0"
	>
	<div class="product-toolbar">
		<button
			bind:this={addButton}
			type="button"
			class="add-product-button"
			title={$t('receiving.records.purchaseAddProduct')}
			aria-label={$t('receiving.records.purchaseAddProduct')}
			aria-expanded={showProductPopup}
			on:click={() => showProductPopup ? closeProductPopup() : showProductPopup = true}
		>+</button>
		{#if showProductPopup}
			<div class="barcode-popup" on:keydown={(event) => {
				if (event.key === 'Escape') {
					event.stopPropagation();
					closeProductPopup();
				}
			}}>
				<form on:submit|preventDefault={lookupProduct}>
					<label for={`purchase-barcode-${record.id}`}>{$t('receiving.records.purchaseBarcodePrompt')}</label>
					<div class="barcode-controls">
					<input
						id={`purchase-barcode-${record.id}`}
						bind:this={barcodeInput}
						bind:value={barcode}
						use:focusBarcode
						type="text"
						dir="ltr"
						autocomplete="off"
						spellcheck={false}
						maxlength="100"
						required
						disabled={lookupLoading}
						on:input={resetProduct}
					/>
					<button type="submit" class="lookup-button" disabled={lookupLoading || !barcode.trim()}>
						{$t(lookupLoading ? 'receiving.records.purchaseLookingUp' : 'receiving.records.purchaseFindProduct')}
					</button>
					<button type="button" class="close-popup-button" on:click={closeProductPopup} aria-label={$t('receiving.records.cancel')}>×</button>
					</div>
				</form>
				{#if lookupError}<p class="lookup-error" role="alert">{lookupError}</p>{/if}
				{#if pendingProduct}
					<div class="product-preview" aria-live="polite">
						<div class="preview-name" lang="en" dir="ltr">{pendingProduct.name}</div>
						<div class="related-barcodes" aria-label={$t('receiving.records.purchaseRelatedBarcodes')}>
							{#each pendingProduct.barcodes as code (code.barcode)}
								<span class="barcode-chip" class:scanned-barcode={code.barcode === pendingProduct.scannedBarcode}>
									<bdi>{code.barcode}</bdi>
									{#if code.barcode === pendingProduct.scannedBarcode}
										<span>{$t('receiving.records.purchaseScanned')}</span>
									{/if}
								</span>
							{/each}
						</div>
						<dl class="scanned-details">
							<div>
								<dt>{$t('receiving.records.purchaseScannedBarcode')}</dt>
								<dd><bdi>{pendingProduct.scannedBarcode}</bdi></dd>
							</div>
							<div>
								<dt>{$t('receiving.records.purchaseUnit')}</dt>
								<dd>{scannedCode?.unit || $t('receiving.records.naText')}</dd>
							</div>
							<div>
								<dt>{$t('receiving.records.purchaseConversionFactor')}</dt>
								<dd>{scannedCode?.multiFactor ?? $t('receiving.records.naText')}</dd>
							</div>
						</dl>
					</div>
					<form class="entry-controls" on:submit|preventDefault={addProduct}>
						<div>
							<label for={`purchase-quantity-${record.id}`}>{$t('receiving.records.purchaseQuantity')}</label>
							<input
								id={`purchase-quantity-${record.id}`}
								type="number" min="0" step="any" required
								bind:this={quantityInput}
								bind:value={quantity}
								use:focusBarcode
								on:keydown={focusRowNumber}
								on:input={() => entryError = ''}
							/>
						</div>
						<div>
							<label for={`purchase-row-${record.id}`}>{$t('receiving.records.purchaseRowNumber')}</label>
							<input
								id={`purchase-row-${record.id}`}
								type="text" inputmode="numeric" pattern="[0-9]+" required
								bind:this={rowNumberInput}
								bind:value={rowNumber}
								on:keydown={focusCost}
								on:input={() => entryError = ''}
							/>
						</div>
						<div>
							<label for={`purchase-cost-${record.id}`}>{$t('receiving.records.purchaseUnitCost')}</label>
							<input
								id={`purchase-cost-${record.id}`}
								type="number" min="0" step="any"
								bind:this={costInput}
								bind:value={cost}
								on:input={() => entryError = ''}
							/>
						</div>
						<button type="submit" class="lookup-button">{$t(editingProductId === null ? 'receiving.records.purchaseAddProduct' : 'receiving.records.purchaseSaveRow')}</button>
					</form>
					{#if entryError}<p class="lookup-error" role="alert">{entryError}</p>{/if}
				{/if}
			</div>
		{/if}
	</div>

	{#if products.length}
		{#if tableError}<p class="lookup-error table-error" role="alert">{tableError}</p>{/if}
		<div class="overflow-x-auto" aria-live="polite">
			<table class="product-table">
				<thead>
					<tr>
						<th>{$t('receiving.records.purchaseRowNumber')}</th>
						<th>{$t('receiving.records.purchaseBarcode')}</th>
						<th>{$t('receiving.records.purchaseProduct')}</th>
						<th>{$t('receiving.records.purchaseUnit')}</th>
						<th>{$t('receiving.records.purchaseConversionFactor')}</th>
						<th>{$t('receiving.records.purchaseQuantity')}</th>
						<th class="money">{$t('receiving.records.purchaseCostBeforeVat')}</th>
						<th class="money">{$t('receiving.records.purchaseVatAmount', { rate: vatPercent })}</th>
						<th class="money">{$t('receiving.records.purchaseTotal')}</th>
						<th>{$t('receiving.records.colActions')}</th>
					</tr>
				</thead>
				<tbody>
					{#each products as product (product.id)}
						{@const amounts = calculateLineAmounts(product, costIncludesVat)}
						<tr class:editing-row={editingProductId === product.id}>
							<td class="row-number-cell">
								<input
									type="number" min="1" step="1" required
									value={product.rowNumber}
									aria-label={$t('receiving.records.purchaseRowNumber')}
									on:change={(event) => changeRowNumber(event, product)}
								/>
							</td>
							<td class="product-barcode"><bdi>{product.barcode}</bdi></td>
							<td lang="en"><bdi dir="ltr">{product.name}</bdi></td>
							<td>{product.unit || $t('receiving.records.naText')}</td>
							<td>{product.multiFactor ?? $t('receiving.records.naText')}</td>
							<td>{product.quantity}</td>
							<td class="money">{amounts?.beforeVat.toFixed(2) ?? ''}</td>
							<td class="money">{amounts?.vat.toFixed(2) ?? ''}</td>
							<td class="money">{amounts?.total.toFixed(2) ?? ''}</td>
							<td class="row-actions">
								<button
									type="button"
									class="edit-row-button"
									title={$t('receiving.records.purchaseEditRow', { row: product.rowNumber })}
									aria-label={$t('receiving.records.purchaseEditRow', { row: product.rowNumber })}
									on:click={() => editProduct(product)}
								>✏️</button>
								<button
									type="button"
									class="remove-row-button"
									title={$t('receiving.records.purchaseRemoveRow', { row: product.rowNumber })}
									aria-label={$t('receiving.records.purchaseRemoveRow', { row: product.rowNumber })}
									on:click={() => removeProduct(product.id)}
								>×</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
	</div>
</div>

<style>
	.purchase-entry {
		display: flex;
		height: 100%;
		min-height: 0;
		flex-direction: column;
		overflow: hidden;
	}

	.entry-panel {
		flex: 1;
		min-height: 0;
	}

	.ai-entry-panel {
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.manual-entry-panel {
		overflow: auto;
	}

	.entry-panel[hidden] {
		display: none;
	}

	.purchase-header,
	.entry-tabs,
	.ai-entry-toolbar,
	.bill-ai-heading {
		flex-shrink: 0;
	}

	.entry-tabs {
		display: flex;
		gap: 4px;
		padding: 5px 10px 0;
		border-bottom: 1px solid #e2e8f0;
	}

	.entry-tabs button {
		padding: 6px 12px;
		border: 0;
		border-bottom: 2px solid transparent;
		background: transparent;
		color: #64748b;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
	}

	.entry-tabs button.active-tab {
		border-bottom-color: #059669;
		color: #047857;
		background: #ecfdf5;
	}

	.ai-entry-toolbar {
		padding: 6px 10px;
	}

	.purchase-header {
		display: flex;
		align-items: center;
		border-bottom: 1px solid #e2e8f0;
		background: #f8fafc;
	}

	.purchase-summary {
		flex: 1;
		min-width: 0;
		display: grid;
		grid-template-columns: minmax(0, 2fr) minmax(0, 1.2fr) minmax(0, 1fr) minmax(0, 1.3fr) auto;
		gap: 12px;
		margin: 0;
		padding: 6px 10px;
		background: #f8fafc;
	}

	.read-ai-button {
		margin-inline-end: 10px;
		padding: 6px 8px;
		border: 0;
		border-radius: 5px;
		background: #4f46e5;
		color: white;
		font-size: 11px;
		white-space: nowrap;
		cursor: pointer;
	}

	.read-ai-button:disabled {
		opacity: 0.6;
		cursor: default;
	}

	.bill-ai-results {
		display: flex;
		flex: 1;
		min-height: 0;
		flex-direction: column;
		overflow: hidden;
		margin: 6px 10px;
		padding: 8px;
		border: 1px solid #c7d2fe;
		border-radius: 6px;
	}

	.bill-ai-heading {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.bill-ai-heading h3 {
		margin: 0;
		color: #3730a3;
		font-size: 12px;
		font-weight: 600;
	}

	.bill-ai-message {
		margin: 6px 0;
		color: #475569;
		font-size: 11px;
		white-space: pre-wrap;
	}

	.purchase-summary > div {
		min-width: 0;
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

	.amount {
		color: #047857;
		font-variant-numeric: tabular-nums;
	}

	.vat-toggle {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		cursor: pointer;
		font-size: 11px;
	}

	.vat-toggle input {
		appearance: none;
		direction: ltr;
		width: 28px;
		height: 16px;
		margin: 0;
		padding: 2px;
		border-radius: 10px;
		background: #94a3b8;
		cursor: pointer;
	}

	.vat-toggle input::before {
		content: '';
		display: block;
		width: 12px;
		height: 12px;
		border-radius: 50%;
		background: white;
		transition: transform 0.15s;
	}

	.vat-toggle input:checked {
		background: #059669;
	}

	.vat-toggle input:checked::before {
		transform: translateX(12px);
	}

	.product-toolbar {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 6px 10px;
	}

	.add-product-button,
	.lookup-button {
		border: 0;
		border-radius: 5px;
		background: #059669;
		color: white;
		cursor: pointer;
	}

	.add-product-button {
		flex-shrink: 0;
		width: 28px;
		height: 28px;
		font-size: 22px;
		line-height: 1;
	}

	.barcode-popup {
		width: min(620px, calc(100% - 36px));
		padding: 10px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		background: white;
		box-shadow: 0 6px 20px #0f172a26;
	}

	.barcode-popup label {
		display: block;
		margin-bottom: 4px;
		color: #475569;
		font-size: 11px;
	}

	.barcode-controls {
		display: flex;
		gap: 6px;
	}

	.barcode-controls input,
	.entry-controls input,
	.row-number-cell input {
		flex: 1;
		min-width: 0;
		height: 30px;
		padding: 3px 6px;
		border: 1px solid #94a3b8;
		border-radius: 4px;
		font-size: 13px;
	}

	.lookup-button {
		padding: 4px 8px;
		font-size: 11px;
		white-space: nowrap;
	}

	.lookup-button:disabled {
		opacity: 0.6;
		cursor: default;
	}

	.close-popup-button {
		border: 0;
		background: transparent;
		color: #64748b;
		font-size: 20px;
		cursor: pointer;
	}

	.lookup-error {
		margin: 6px 0 0;
		color: #b91c1c;
		font-size: 11px;
	}

	.product-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
		text-align: start;
	}

	.product-table th,
	.product-table td {
		padding: 5px 10px;
		border-bottom: 1px solid #e2e8f0;
		text-align: start;
	}

	.product-table th {
		background: #f8fafc;
		color: #64748b;
		font-size: 10px;
		font-weight: 600;
	}

	.product-table .money {
		text-align: end;
		white-space: nowrap;
		font-variant-numeric: tabular-nums;
	}

	.edit-row-button,
	.remove-row-button {
		width: 26px;
		height: 26px;
		border: 0;
		border-radius: 5px;
		background: #2563eb;
		color: white;
		cursor: pointer;
	}

	.edit-row-button:hover {
		background: #1d4ed8;
	}

	.row-actions {
		white-space: nowrap;
	}

	.remove-row-button {
		margin-inline-start: 4px;
		background: #dc2626;
		font-size: 18px;
	}

	.remove-row-button:hover {
		background: #b91c1c;
	}

	.editing-row {
		background: #ecfdf5;
	}

	.product-barcode {
		width: 160px;
		white-space: nowrap;
	}

	.product-preview {
		margin-top: 8px;
		padding-top: 8px;
		border-top: 1px solid #e2e8f0;
	}

	.preview-name {
		color: #1e293b;
		font-size: 12px;
		font-weight: 600;
		text-align: start;
	}

	.related-barcodes {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
		margin-top: 6px;
	}

	.barcode-chip {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		padding: 3px 6px;
		border: 1px solid #cbd5e1;
		border-radius: 4px;
		color: #475569;
		font-size: 11px;
	}

	.scanned-details {
		display: grid;
		grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr) minmax(0, 1fr);
		gap: 10px;
		margin: 8px 0 0;
	}

	.scanned-barcode {
		border-color: #059669;
		background: #d1fae5;
		color: #065f46;
		font-weight: 700;
	}

	.entry-controls {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: 8px;
		margin-top: 8px;
	}

	.entry-controls input {
		width: 95px;
	}

	.entry-controls button {
		min-height: 30px;
	}

	.row-number-cell {
		width: 85px;
	}

	.row-number-cell input {
		width: 65px;
	}

	.table-error {
		padding: 0 10px 6px;
	}
</style>
