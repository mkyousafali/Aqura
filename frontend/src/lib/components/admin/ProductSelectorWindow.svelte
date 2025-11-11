<script lang="ts">
	export let products: any[] = [];
	export let selectedProducts: any[] = [];
	export let isRTL: boolean = false;
	export let onSelect: (selected: any[]) => void;

	let searchTerm = '';
	let localSelected = [...selectedProducts];

	// Split products into selected and unselected, with selected at top
	$: filteredProducts = (() => {
		const filtered = products.filter(p => 
			p.name_ar.toLowerCase().includes(searchTerm.toLowerCase()) ||
			p.name_en.toLowerCase().includes(searchTerm.toLowerCase()) ||
			p.barcode?.includes(searchTerm) ||
			p.serial?.includes(searchTerm)
		);

		// Separate into selected and unselected
		const selected = filtered.filter(p => isSelected(p.id));
		const unselected = filtered.filter(p => !isSelected(p.id));

		// Return selected first, then unselected
		return [...selected, ...unselected];
	})();

	$: availableProducts = products.filter(p => !isSelected(p.id));

	function isSelected(productId: string): boolean {
		return localSelected.some(p => p.id === productId);
	}

	function toggleSelection(product: any) {
		if (isSelected(product.id)) {
			localSelected = localSelected.filter(p => p.id !== product.id);
		} else {
			localSelected = [...localSelected, product];
		}
	}

	function removeProduct(productId: string, event: Event) {
		event.stopPropagation();
		localSelected = localSelected.filter(p => p.id !== productId);
	}

	function selectAll() {
		localSelected = [...filteredProducts];
	}

	function clearAll() {
		localSelected = [];
	}

	function applySelection() {
		onSelect(localSelected);
	}
</script>

<div class="product-selector-window" class:rtl={isRTL}>
	<!-- Header with Search and Actions -->
	<div class="header">
		<div class="search-section">
			<input 
				type="text" 
				bind:value={searchTerm}
				placeholder={isRTL ? 'بحث بالاسم، الباركود، أو الرقم التسلسلي...' : 'Search by name, barcode, or serial...'}
				class="search-input"
			/>
			<div class="selection-count">
				{isRTL ? 'المحدد' : 'Selected'}: <strong>{localSelected.length}</strong> / {products.length}
			</div>
		</div>
		<div class="action-buttons">
			<button type="button" class="btn-secondary" on:click={selectAll}>
				{isRTL ? 'تحديد الكل' : 'Select All'}
			</button>
			<button type="button" class="btn-secondary" on:click={clearAll}>
				{isRTL ? 'إلغاء الكل' : 'Clear All'}
			</button>
			<button type="button" class="btn-primary" on:click={applySelection}>
				{isRTL ? 'تطبيق' : 'Apply'} ({localSelected.length})
			</button>
		</div>
	</div>

	<!-- Selected Products Summary (shown when products are selected) -->
	{#if localSelected.length > 0}
		<div class="selected-summary">
			<div class="summary-header">
				<span class="summary-title">
					{isRTL ? 'المنتجات المحددة' : 'Selected Products'} ({localSelected.length})
				</span>
				<span class="summary-hint">
					{isRTL ? 'هذه المنتجات معروضة في الأعلى' : 'These products are shown at the top'}
				</span>
			</div>
		</div>
	{/if}

	<!-- Products Table -->
	<div class="table-container">
		<table class="products-table">
			<thead>
				<tr>
					<th style="width: 50px;">
						<input 
							type="checkbox" 
							checked={localSelected.length === filteredProducts.length && filteredProducts.length > 0}
							on:change={(e) => e.target.checked ? selectAll() : clearAll()}
						/>
					</th>
					<th style="width: 80px;">{isRTL ? 'الصورة' : 'Image'}</th>
					<th style="width: 100px;">{isRTL ? 'الرقم' : 'Serial'}</th>
					<th>{isRTL ? 'اسم المنتج' : 'Product Name'}</th>
					<th style="width: 150px;">{isRTL ? 'الباركود' : 'Barcode'}</th>
					<th style="width: 120px;">{isRTL ? 'السعر' : 'Price'}</th>
					<th style="width: 80px;">{isRTL ? 'إجراء' : 'Action'}</th>
				</tr>
			</thead>
			<tbody>
				{#each filteredProducts as product}
					<tr 
						class:selected={isSelected(product.id)}
						on:click={() => toggleSelection(product)}
						role="button"
						tabindex="0"
						on:keydown={(e) => e.key === 'Enter' && toggleSelection(product)}
					>
						<td>
							<input 
								type="checkbox" 
								checked={isSelected(product.id)}
								on:change={() => toggleSelection(product)}
								on:click={(e) => e.stopPropagation()}
							/>
						</td>
						<td>
							<div class="product-image">
								{#if product.image_url}
									<img src={product.image_url} alt={isRTL ? product.name_ar : product.name_en} />
								{:else}
									<div class="no-image">📦</div>
								{/if}
							</div>
						</td>
						<td class="serial">{product.serial || '-'}</td>
						<td class="product-name">
							<div class="name-primary">
								{isRTL ? product.name_ar : product.name_en}
								{#if isSelected(product.id)}
									<span class="selected-badge">{isRTL ? '✓ محدد' : '✓ Selected'}</span>
								{/if}
							</div>
							<div class="name-secondary">{isRTL ? product.name_en : product.name_ar}</div>
						</td>
						<td class="barcode">{product.barcode || '-'}</td>
						<td class="price">{product.price} {isRTL ? 'ريال' : 'SAR'}</td>
						<td>
							{#if isSelected(product.id)}
								<button 
									type="button"
									class="remove-btn"
									on:click={(e) => removeProduct(product.id, e)}
									title={isRTL ? 'إزالة' : 'Remove'}
								>
									✕
								</button>
							{/if}
						</td>
					</tr>
				{/each}
				{#if filteredProducts.length === 0}
					<tr>
						<td colspan="7" class="no-results">
							{isRTL ? 'لا توجد منتجات' : 'No products found'}
						</td>
					</tr>
				{/if}
			</tbody>
		</table>
	</div>
</div>

<style>
	.product-selector-window {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f9fafb;
		overflow: hidden;
	}

	.product-selector-window.rtl {
		direction: rtl;
		text-align: right;
	}

	.header {
		background: white;
		padding: 1.5rem;
		border-bottom: 2px solid #e5e7eb;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.selected-summary {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		padding: 1rem 1.5rem;
		border-bottom: 2px solid #93c5fd;
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.summary-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		gap: 1rem;
	}

	.summary-title {
		font-weight: 700;
		color: #1e40af;
		font-size: 1rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.summary-hint {
		font-size: 0.85rem;
		color: #3b82f6;
		font-weight: 500;
	}

	.search-section {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.search-input {
		flex: 1;
		padding: 0.75rem 1rem;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		font-size: 1rem;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.selection-count {
		color: #6b7280;
		font-size: 0.95rem;
		white-space: nowrap;
	}

	.selection-count strong {
		color: #3b82f6;
		font-weight: 700;
		font-size: 1.1rem;
	}

	.action-buttons {
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
	}

	.btn-primary,
	.btn-secondary {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.btn-secondary {
		background: #e5e7eb;
		color: #374151;
	}

	.btn-secondary:hover {
		background: #d1d5db;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
		margin: 1rem;
		border-radius: 12px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.products-table {
		width: 100%;
		border-collapse: collapse;
	}

	.products-table thead {
		position: sticky;
		top: 0;
		background: #f9fafb;
		z-index: 10;
	}

	.products-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.rtl .products-table th {
		text-align: right;
	}

	.products-table tbody tr {
		cursor: pointer;
		transition: all 0.15s;
		border-bottom: 1px solid #f3f4f6;
	}

	.products-table tbody tr:hover {
		background: #f9fafb;
	}

	.products-table tbody tr.selected {
		background: #dbeafe;
	}

	.products-table tbody tr.selected:hover {
		background: #bfdbfe;
	}

	.products-table td {
		padding: 0.75rem 1rem;
		vertical-align: middle;
		color: #1f2937;
	}

	.product-image {
		width: 60px;
		height: 60px;
		border-radius: 8px;
		overflow: hidden;
		background: #f3f4f6;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.product-image img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.no-image {
		font-size: 1.5rem;
		color: #9ca3af;
	}

	.serial {
		font-family: 'Courier New', monospace;
		color: #6b7280;
		font-weight: 500;
	}

	.product-name {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.name-primary {
		font-weight: 600;
		color: #1f2937;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.name-secondary {
		font-size: 0.85rem;
		color: #6b7280;
	}

	.selected-badge {
		display: inline-flex;
		align-items: center;
		padding: 0.15rem 0.5rem;
		background: #10b981;
		color: white;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 700;
		letter-spacing: 0.02em;
		white-space: nowrap;
	}

	.remove-btn {
		background: #ef4444;
		color: white;
		border: none;
		width: 32px;
		height: 32px;
		border-radius: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 1.2rem;
		font-weight: 700;
		transition: all 0.2s;
		line-height: 1;
	}

	.remove-btn:hover {
		background: #dc2626;
		transform: scale(1.1);
		box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
	}

	.remove-btn:active {
		transform: scale(0.95);
	}

	.barcode {
		font-family: 'Courier New', monospace;
		color: #374151;
		font-size: 0.9rem;
	}

	.price {
		font-weight: 700;
		color: #059669;
		font-size: 1rem;
	}

	.no-results {
		text-align: center;
		padding: 3rem !important;
		color: #9ca3af;
		font-size: 1rem;
	}

	input[type="checkbox"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
		accent-color: #3b82f6;
	}

	/* Scrollbar Styling */
	.table-container::-webkit-scrollbar {
		width: 10px;
		height: 10px;
	}

	.table-container::-webkit-scrollbar-track {
		background: #f3f4f6;
		border-radius: 5px;
	}

	.table-container::-webkit-scrollbar-thumb {
		background: #d1d5db;
		border-radius: 5px;
	}

	.table-container::-webkit-scrollbar-thumb:hover {
		background: #9ca3af;
	}
</style>
