<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import ExcelJS from 'exceljs';

	let products: any[] = [];
	let loading = true;
	let currentPage = 1;
	let pageSize = 50;
	let totalProducts = 0;
	let totalPages = 0;
	let updatingProductId: string | null = null;
	let showImportPreview = false;
	let importedData: any[] = [];
	let importStats = { matched: 0, unmatched: 0 };

	onMount(async () => {
		await loadProducts();
	});

	async function loadProducts() {
		loading = true;
		
		const offset = (currentPage - 1) * pageSize;
		
		// Parallel queries for data and count
		const [dataResult, countResult] = await Promise.all([
			supabase
				.from('products')
				.select('barcode, product_name_en, product_name_ar, image_url, sale_price, cost, current_stock, minim_qty, minimum_qty_alert, maximum_qty, is_customer_product')
				.range(offset, offset + pageSize - 1)
				.order('barcode'),
			
			supabase
				.from('products')
				.select('*', { count: 'exact', head: true })
		]);
		
		if (dataResult.data) {
			products = dataResult.data;
		}
		
		if (countResult.count !== null) {
			totalProducts = countResult.count;
			totalPages = Math.ceil(totalProducts / pageSize);
		}
		
		loading = false;
	}

	function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
			loadProducts();
		}
	}

	function previousPage() {
		if (currentPage > 1) {
			currentPage--;
			loadProducts();
		}
	}

	function goToPage(page: number) {
		if (page >= 1 && page <= totalPages) {
			currentPage = page;
			loadProducts();
		}
	}

	async function toggleCustomerProduct(product: any) {
		const barcode = product.barcode;
		const newValue = !product.is_customer_product;

		updatingProductId = barcode;

		try {
			// Get current session to ensure auth is set
			const { data: { session }, error: sessionError } = await supabase.auth.getSession();
			
			if (sessionError) {
				console.error('Session error:', sessionError);
			}

			const { error } = await supabase
				.from('products')
				.update({ is_customer_product: newValue })
				.eq('barcode', barcode);

			if (error) {
				console.error('Error updating product:', error);
				console.error('Full error details:', JSON.stringify(error));
				alert('Failed to update product: ' + error.message);
			} else {
				// Update local state
				product.is_customer_product = newValue;
				products = products; // Trigger reactivity
				console.log('Product updated successfully:', barcode);
			}
		} catch (err) {
			console.error('Exception during update:', err);
			alert('Exception occurred during update');
		}

		updatingProductId = null;
	}

	async function exportToExcel() {
		try {
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('Products');

			// Add headers
			worksheet.columns = [
				{ header: 'Barcode', key: 'barcode', width: 15 },
				{ header: 'Name (EN)', key: 'product_name_en', width: 30 },
				{ header: 'Name (AR)', key: 'product_name_ar', width: 30 },
				{ header: 'Price', key: 'sale_price', width: 12 },
				{ header: 'Cost', key: 'cost', width: 12 },
				{ header: 'Stock', key: 'current_stock', width: 12 },
				{ header: 'Stock Min', key: 'minim_qty', width: 12 },
				{ header: 'Min Alert', key: 'minimum_qty_alert', width: 12 },
				{ header: 'Max Stock', key: 'maximum_qty', width: 12 }
			];

			// Style header row
			const headerRow = worksheet.getRow(1);
			headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
			headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1976D2' } };
			headerRow.alignment = { horizontal: 'center', vertical: 'center' };

			// Add all products with is_customer_product = true (fetch all, not just current page)
			let allProducts: any[] = [];
			let offset = 0;
			let hasMore = true;

			while (hasMore) {
				const { data, error } = await supabase
					.from('products')
					.select('barcode, product_name_en, product_name_ar, sale_price, cost, current_stock, minim_qty, minimum_qty_alert, maximum_qty')
					.eq('is_customer_product', true)
					.order('barcode')
					.range(offset, offset + 999);

				if (error) {
					throw error;
				}

				if (data && data.length > 0) {
					allProducts = allProducts.concat(data);
					offset += 1000;
					hasMore = data.length === 1000;
				} else {
					hasMore = false;
				}
			}

			// Add rows
			allProducts.forEach(product => {
				worksheet.addRow({
					barcode: product.barcode,
					product_name_en: product.product_name_en,
					product_name_ar: product.product_name_ar,
					sale_price: product.sale_price,
					cost: product.cost,
					current_stock: product.current_stock,
					minim_qty: product.minim_qty,
					minimum_qty_alert: product.minimum_qty_alert,
					maximum_qty: product.maximum_qty
				});
			});

			// Format number columns
			for (let i = 2; i <= allProducts.length + 1; i++) {
				worksheet.getRow(i).getCell('sale_price').numFmt = '0.00';
				worksheet.getRow(i).getCell('cost').numFmt = '0.00';
				worksheet.getRow(i).getCell('current_stock').numFmt = '0';
				worksheet.getRow(i).getCell('minim_qty').numFmt = '0';
				worksheet.getRow(i).getCell('minimum_qty_alert').numFmt = '0';
				worksheet.getRow(i).getCell('maximum_qty').numFmt = '0';
			}

			// Generate file
			const buffer = await workbook.xlsx.writeBuffer();
			const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = `Products-${new Date().toISOString().split('T')[0]}.xlsx`;
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			URL.revokeObjectURL(url);

			console.log(`Exported ${allProducts.length} products to Excel`);
		} catch (err) {
			console.error('Error exporting to Excel:', err);
			alert('Failed to export to Excel: ' + (err instanceof Error ? err.message : String(err)));
		}
	}

	async function handleImportFile(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];

		if (!file) return;

		try {
			const buffer = await file.arrayBuffer();
			const workbook = new ExcelJS.Workbook();
			await workbook.xlsx.load(buffer);

			const worksheet = workbook.getWorksheet(1);
			if (!worksheet) {
				throw new Error('No worksheet found in file');
			}

			// Parse data
			const importedRows: any[] = [];
			let rowIndex = 2; // Skip header

			worksheet.eachRow((row, index) => {
				if (index === 1) return; // Skip header row

				const barcode = row.getCell('A').value;
				const sale_price = row.getCell('D').value;
				const cost = row.getCell('E').value;
				const current_stock = row.getCell('F').value;
				const minim_qty = row.getCell('G').value;
				const minimum_qty_alert = row.getCell('H').value;
				const maximum_qty = row.getCell('I').value;

				if (barcode) {
					importedRows.push({
						barcode: String(barcode),
						sale_price: Number(sale_price) || 0,
						cost: Number(cost) || 0,
						current_stock: Number(current_stock) || 0,
						minim_qty: Number(minim_qty) || 0,
						minimum_qty_alert: Number(minimum_qty_alert) || 0,
						maximum_qty: Number(maximum_qty) || 0
					});
				}
			});

			// Match with existing products
			const matchedData = importedRows.map(row => {
				const existingProduct = products.find(p => p.barcode === row.barcode);
				return {
					...row,
					matched: !!existingProduct,
					profit: row.sale_price - row.cost,
					profitPercent: row.cost > 0 ? ((row.sale_price - row.cost) / row.cost) * 100 : 0
				};
			});

			importedData = matchedData;
			importStats = {
				matched: matchedData.filter(d => d.matched).length,
				unmatched: matchedData.filter(d => !d.matched).length
			};

			showImportPreview = true;

			// Reset file input
			target.value = '';
		} catch (err) {
			console.error('Error importing from Excel:', err);
			alert('Failed to import from Excel: ' + (err instanceof Error ? err.message : String(err)));
		}
	}

	async function applyImportUpdates() {
		const matchedProducts = importedData.filter(d => d.matched);

		if (matchedProducts.length === 0) {
			alert('No matching products to update');
			return;
		}

		loading = true;

		try {
			// Update each matched product
			const updatePromises = matchedProducts.map(item =>
				supabase
					.from('products')
					.update({
						sale_price: item.sale_price,
						cost: item.cost,
						current_stock: item.current_stock,
						minim_qty: item.minim_qty,
						minimum_qty_alert: item.minimum_qty_alert,
						maximum_qty: item.maximum_qty
					})
					.eq('barcode', item.barcode)
			);

			const results = await Promise.all(updatePromises);

			// Check for errors
			const errors = results.filter(r => r.error);
			if (errors.length > 0) {
				throw new Error(`Failed to update ${errors.length} products`);
			}

			alert(`Successfully updated ${matchedProducts.length} products from Excel`);

			// Reset and reload
			showImportPreview = false;
			importedData = [];
			currentPage = 1;
			await loadProducts();
		} catch (err) {
			console.error('Error applying import updates:', err);
			alert('Failed to apply updates: ' + (err instanceof Error ? err.message : String(err)));
		} finally {
			loading = false;
		}
	}

	function cancelImport() {
		showImportPreview = false;
		importedData = [];
	}
</script>

<div class="window">
	<div class="header">
		<h2>📦 Products</h2>
		<div class="stats">
			<span class="badge">Total: {totalProducts}</span>
			<span class="badge">Page {currentPage} of {totalPages}</span>
		</div>
		<div class="header-buttons">
			<button class="btn-export" on:click={exportToExcel} disabled={loading || products.length === 0} title="Export all products to Excel">
				📥 Export to Excel
			</button>
			<label class="btn-import" title="Import products from Excel">
				📤 Import from Excel
				<input type="file" accept=".xlsx,.xls" on:change={handleImportFile} style="display: none;" />
			</label>
		</div>
	</div>
	
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading products...</p>
		</div>
	{:else if products.length === 0}
		<p>No products found</p>
	{:else}
		<div class="table-container">
			<table>
				<thead>
					<tr>
						<th class="col-image">Image</th>
						<th class="col-barcode">Barcode</th>
						<th class="col-name">Name En</th>
						<th class="col-name">Name Ar</th>
						<th class="col-price">Price</th>
						<th class="col-price">Cost</th>
						<th class="col-price">Profit</th>
						<th class="col-number">Profit %</th>
						<th class="col-number">Stock</th>
						<th class="col-number">Min Stock</th>
						<th class="col-number">Min Alert</th>
						<th class="col-number">Max Stock</th>
						<th class="col-customer">Customer</th>
					</tr>
				</thead>
				<tbody>
					{#each products as product}
						<tr>
							<td class="image-cell">
								{#if product.image_url}
									<img src={product.image_url} alt={product.product_name_en} class="product-img" />
								{:else}
									<div class="no-img">📦</div>
								{/if}
							</td>
						<td class="barcode">{product.barcode}</td>
						<td class="name-cell">{product.product_name_en || '-'}</td>
						<td class="name-cell arabic">{product.product_name_ar || '-'}</td>
						<td class="price">{product.sale_price.toFixed(2)}</td>
						<td class="price">{product.cost.toFixed(2)}</td>
						<td class="price">{(product.sale_price - product.cost).toFixed(2)}</td>
						<td class="number">{product.cost > 0 ? (((product.sale_price - product.cost) / product.cost) * 100).toFixed(2) : '0.00'}%</td>
						<td class="number">{product.current_stock}</td>
						<td class="number">{product.minim_qty}</td>
						<td class="number">{product.minimum_qty_alert}</td>
						<td class="number">{product.maximum_qty}</td>
					<td class="center">
						<button 
							class="toggle-btn {product.is_customer_product ? 'active' : 'inactive'}"
							on:click={() => toggleCustomerProduct(product)}
							disabled={updatingProductId === product.barcode}
							title={product.is_customer_product ? 'Click to disable' : 'Click to enable'}
						>
							<span class="toggle-indicator"></span>
						</button>
					</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<div class="pagination">
			<button on:click={previousPage} disabled={currentPage === 1 || loading}>
				← Previous
			</button>
			
			<div class="page-numbers">
				{#each Array(Math.min(5, totalPages)) as _, i}
					{@const page = currentPage - 2 + i}
					{#if page > 0 && page <= totalPages}
						<button 
							class:active={page === currentPage}
							on:click={() => goToPage(page)}
							disabled={loading}
						>
							{page}
						</button>
					{/if}
				{/each}
			</div>
			
			<button on:click={nextPage} disabled={currentPage === totalPages || loading}>
				Next →
			</button>
		</div>
	{/if}

	<!-- Import Preview Modal -->
	{#if showImportPreview}
		<div class="modal-overlay" on:click={cancelImport}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
					<h3>Import Preview</h3>
					<button class="close-btn" on:click={cancelImport}>✕</button>
				</div>

				<div class="modal-stats">
					<div class="stat-item matched">
						<span class="stat-label">Matched Products:</span>
						<span class="stat-value">{importStats.matched}</span>
					</div>
					<div class="stat-item unmatched">
						<span class="stat-label">Unmatched Products:</span>
						<span class="stat-value">{importStats.unmatched}</span>
					</div>
				</div>

				<div class="preview-table-container">
					<table class="preview-table">
						<thead>
							<tr>
								<th>Status</th>
								<th>Barcode</th>
								<th>Price</th>
								<th>Cost</th>
								<th>Profit</th>
								<th>Profit %</th>
								<th>Stock</th>
								<th>Stock Min</th>
								<th>Min Alert</th>
								<th>Max Stock</th>
							</tr>
						</thead>
						<tbody>
							{#each importedData as item}
								<tr class={item.matched ? 'matched-row' : 'unmatched-row'}>
									<td class="status-cell">
										<span class={`status-badge ${item.matched ? 'matched' : 'unmatched'}`}>
											{item.matched ? '✓' : '✗'}
										</span>
									</td>
									<td class="barcode">{item.barcode}</td>
									<td>{item.sale_price.toFixed(2)}</td>
									<td>{item.cost.toFixed(2)}</td>
									<td>{item.profit.toFixed(2)}</td>
									<td>{item.profitPercent.toFixed(2)}%</td>
									<td>{item.current_stock}</td>
									<td>{item.minim_qty}</td>
									<td>{item.minimum_qty_alert}</td>
									<td>{item.maximum_qty}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>

				<div class="modal-actions">
					<button class="btn-cancel" on:click={cancelImport}>Cancel</button>
					<button class="btn-confirm" on:click={applyImportUpdates} disabled={importStats.matched === 0}>
						Apply Updates ({importStats.matched})
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.window {
		padding: 20px;
		background: white;
		height: 100%;
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
	}

	h2 {
		margin: 0;
		font-size: 24px;
		font-weight: 600;
	}

	.stats {
		display: flex;
		gap: 12px;
	}

	.badge {
		background: #e3f2fd;
		color: #1976d2;
		padding: 6px 12px;
		border-radius: 16px;
		font-size: 14px;
		font-weight: 500;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		gap: 16px;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-top: 4px solid #1976d2;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.table-container {
		flex: 1;
		overflow: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		table-layout: fixed;
	}

	th, td {
		padding: 10px 12px;
		border-bottom: 1px solid #f3f4f6;
		font-size: 14px;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	th {
		background: #f9fafb;
		font-weight: 600;
		position: sticky;
		top: 0;
		color: #374151;
		text-transform: capitalize;
		z-index: 10;
		white-space: nowrap;
		text-align: left;
	}

	th.col-price,
	th.col-number {
		text-align: right;
	}

	th.col-customer,
	th.col-image {
		text-align: center;
	}

	.col-barcode {
		width: 140px;
	}

	.col-name {
		width: 250px;
	}

	.col-image {
		width: 90px;
	}

	.col-price {
		width: 90px;
	}

	.col-number {
		width: 100px;
	}

	.col-customer {
		width: 120px;
	}

	tbody tr:hover {
		background: #f9fafb;
	}

	.barcode {
		font-family: monospace;
		font-weight: 500;
		color: #1976d2;
		text-align: left;
	}

	.image-cell {
		padding: 4px !important;
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.product-img {
		width: 60px;
		height: 60px;
		object-fit: contain;
		border-radius: 4px;
		border: 1px solid #e5e7eb;
		display: block;
		margin: 0 auto;
	}

	.no-img {
		width: 60px;
		height: 60px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
		border-radius: 4px;
		font-size: 24px;
		margin: 0 auto;
	}

	.price {
		text-align: right;
		font-family: monospace;
		font-weight: 500;
	}

	.number {
		text-align: right;
		font-weight: 500;
	}

	.name-cell {
		text-align: left;
	}

	.center {
		text-align: center;
	}

	.arabic {
		font-family: 'Tajawal', 'Cairo', Arial, sans-serif;
		direction: rtl;
		text-align: right;
	}

	.badge-yes {
		display: inline-block;
		padding: 4px 8px;
		background: #d1fae5;
		color: #065f46;
		border-radius: 12px;
		font-weight: 600;
		font-size: 12px;
	}

	.badge-no {
		display: inline-block;
		padding: 4px 8px;
		background: #fee2e2;
		color: #991b1b;
		border-radius: 12px;
		font-weight: 600;
		font-size: 12px;
	}

	.toggle-btn {
		position: relative;
		width: 50px;
		height: 28px;
		padding: 0;
		border: none;
		border-radius: 14px;
		cursor: pointer;
		transition: background-color 0.3s ease, box-shadow 0.3s ease;
		background-color: #e5e7eb;
		display: flex;
		align-items: center;
		justify-content: flex-start;
	}

	.toggle-btn.active {
		background-color: #10b981;
		justify-content: flex-end;
		box-shadow: 0 0 8px rgba(16, 185, 129, 0.5);
	}

	.toggle-btn.inactive {
		background-color: #d1d5db;
		box-shadow: 0 0 4px rgba(107, 114, 128, 0.3);
	}

	.toggle-indicator {
		display: block;
		width: 24px;
		height: 24px;
		background-color: white;
		border-radius: 50%;
		transition: transform 0.3s ease;
		margin: 0 2px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.toggle-btn:hover:not(:disabled) {
		opacity: 0.9;
		transform: scale(1.05);
	}

	.toggle-btn:active:not(:disabled) .toggle-indicator {
		transform: scale(0.95);
	}

	.toggle-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.pagination {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 8px;
		padding: 16px;
		border-top: 1px solid #e5e7eb;
	}

	.pagination button {
		padding: 8px 16px;
		border: 1px solid #d1d5db;
		background: white;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		transition: all 0.2s;
	}

	.pagination button:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #1976d2;
		color: #1976d2;
	}

	.pagination button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.pagination button.active {
		background: #1976d2;
		color: white;
		border-color: #1976d2;
	}

	.page-numbers {
		display: flex;
		gap: 4px;
	}

	.header-buttons {
		display: flex;
		gap: 8px;
	}

	.btn-export,
	.btn-import {
		padding: 8px 16px;
		background: #1976d2;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.btn-import {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.btn-export:hover:not(:disabled),
	.btn-import:hover:not(:disabled) {
		background: #1565c0;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(25, 118, 210, 0.3);
	}

	.btn-export:disabled,
	.btn-import:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 2px solid #e5e7eb;
		flex-shrink: 0;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 20px;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		cursor: pointer;
		color: #6b7280;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: color 0.2s;
	}

	.close-btn:hover {
		color: #111827;
	}

	.modal-stats {
		display: flex;
		gap: 16px;
		padding: 16px 20px;
		background: #f9fafb;
		flex-shrink: 0;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		border-radius: 8px;
	}

	.stat-item.matched {
		background: #d1fae5;
		color: #065f46;
	}

	.stat-item.unmatched {
		background: #fee2e2;
		color: #991b1b;
	}

	.stat-label {
		font-weight: 500;
		font-size: 14px;
	}

	.stat-value {
		font-size: 18px;
		font-weight: 700;
	}

	.preview-table-container {
		flex: 1;
		overflow: auto;
		border-bottom: 1px solid #e5e7eb;
	}

	.preview-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.preview-table th {
		background: #f3f4f6;
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		position: sticky;
		top: 0;
		border-bottom: 1px solid #d1d5db;
		white-space: nowrap;
	}

	.preview-table td {
		padding: 10px 8px;
		border-bottom: 1px solid #f3f4f6;
	}

	.preview-table .matched-row {
		background: #f0fdf4;
	}

	.preview-table .unmatched-row {
		background: #fef2f2;
		opacity: 0.7;
	}

	.status-cell {
		text-align: center;
	}

	.status-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		font-weight: 700;
		font-size: 12px;
	}

	.status-badge.matched {
		background: #10b981;
		color: white;
	}

	.status-badge.unmatched {
		background: #ef4444;
		color: white;
	}

	.modal-actions {
		display: flex;
		gap: 12px;
		padding: 16px 20px;
		justify-content: flex-end;
		flex-shrink: 0;
	}

	.btn-cancel,
	.btn-confirm {
		padding: 10px 20px;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		transition: all 0.2s;
	}

	.btn-cancel {
		background: #e5e7eb;
		color: #374151;
	}

	.btn-cancel:hover {
		background: #d1d5db;
	}

	.btn-confirm {
		background: #10b981;
		color: white;
	}

	.btn-confirm:hover:not(:disabled) {
		background: #059669;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.btn-confirm:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
</style>
