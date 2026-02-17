<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';

	interface Product {
		id: string;
		barcode: string;
		product_name_en: string;
		product_name_ar: string;
		category_id: string | null;
		category_name_en: string | null;
		category_name_ar: string | null;
		unit_id: string | null;
		unit_name_en: string | null;
		unit_name_ar: string | null;
	}

	interface Category {
		id: string;
		name_en: string;
		name_ar: string;
	}

	interface Unit {
		id: string;
		name_en: string;
		name_ar: string;
	}

	let products: Product[] = [];
	let categories: Map<string, Category> = new Map();
	let units: Map<string, Unit> = new Map();
	let isLoading = true;
	let error: string | null = null;
	let loadedCount = 0;
	let totalCount = 0;

	let editingProductId: string | null = null;
	let editingProductName_en = '';
	let editingProductName_ar = '';
	let isSaving = false;

	let categoryModalProductId: string | null = null;
	let categorySearchQuery = '';
	let isSavingCategory = false;

	let unitModalProductId: string | null = null;
	let unitSearchQuery = '';
	let isSavingUnit = false;

	let barcodeSearchQuery = '';
	let nameSearchQuery = '';

	const BATCH_SIZE = 500;
	const PAGE_SIZE = 500;
	let currentPage = 1;

	// Reactive: get products for display (paginated or search results)
	$: isSearching = barcodeSearchQuery.trim() !== '' || nameSearchQuery.trim() !== '';
	$: searchResults = isSearching ? getSearchResults() : [];
	$: totalPages = Math.ceil(products.length / PAGE_SIZE);
	$: displayProducts = isSearching 
		? searchResults 
		: products.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);

	function getSearchResults(): Product[] {
		const bq = barcodeSearchQuery.toLowerCase().trim();
		const nq = nameSearchQuery.toLowerCase().trim();
		return products.filter((product) => {
			const barcodeMatch = !bq || product.barcode.toLowerCase().includes(bq);
			const nameMatch = !nq || 
				(product.product_name_en.toLowerCase().includes(nq) ||
				 product.product_name_ar.toLowerCase().includes(nq));
			return barcodeMatch && nameMatch;
		});
	}

	function goToPage(page: number) {
		if (page >= 1 && page <= totalPages) {
			currentPage = page;
		}
	}

	async function loadProducts() {
		isLoading = true;
		error = null;
		products = [];
		loadedCount = 0;

		try {
			// First call to get total_count + categories + units + first batch
			const { data: firstBatch, error: firstError } = await supabase.rpc('get_products_dashboard_data', {
				p_limit: BATCH_SIZE,
				p_offset: 0
			});

			if (firstError) throw new Error(firstError.message);

			totalCount = firstBatch?.total_count || 0;
			products = firstBatch?.products || [];
			loadedCount = products.length;

			// Populate categories and units maps (from first batch, same for all)
			(firstBatch?.categories || []).forEach((cat: Category) => {
				categories.set(cat.id, cat);
			});
			(firstBatch?.units || []).forEach((unit: Unit) => {
				units.set(unit.id, unit);
			});

			// Load remaining batches in parallel with Promise.all
			if (totalCount > BATCH_SIZE) {
				const remainingBatches = Math.ceil((totalCount - BATCH_SIZE) / BATCH_SIZE);
				const batchPromises = [];

				for (let i = 0; i < remainingBatches; i++) {
					const offset = (i + 1) * BATCH_SIZE;
					batchPromises.push(
						supabase.rpc('get_products_dashboard_data', {
							p_limit: BATCH_SIZE,
							p_offset: offset
						})
					);
				}

				const batchResults = await Promise.all(batchPromises);

				for (const result of batchResults) {
					if (result.error) {
						console.error('Batch error:', result.error);
						continue;
					}
					const batchProducts = result.data?.products || [];
					products = [...products, ...batchProducts];
					loadedCount += batchProducts.length;
				}
			}
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to load products';
			console.error('Error:', err);
		} finally {
			isLoading = false;
		}
	}

	function mapProductDetails(product: any): Product {
		return {
			...product,
			category_name_en: categories.get(product.category_id)?.name_en || null,
			category_name_ar: categories.get(product.category_id)?.name_ar || null,
			unit_name_en: units.get(product.unit_id)?.name_en || null,
			unit_name_ar: units.get(product.unit_id)?.name_ar || null
		};
	}

	function openEditModal(product: Product) {
		editingProductId = product.id;
		editingProductName_en = product.product_name_en;
		editingProductName_ar = product.product_name_ar;
	}

	function closeEditModal() {
		editingProductId = null;
		editingProductName_en = '';
		editingProductName_ar = '';
	}

	async function saveProductName() {
		if (!editingProductId) return;

		isSaving = true;
		try {
			const { error: updateError } = await supabase
				.from('products')
				.update({
					product_name_en: editingProductName_en,
					product_name_ar: editingProductName_ar
				})
				.eq('id', editingProductId);

			if (updateError) {
				throw new Error(updateError.message);
			}

			// Update the product in the local array (only refresh that row)
			const productIndex = products.findIndex((p) => p.id === editingProductId);
			if (productIndex !== -1) {
				products[productIndex].product_name_en = editingProductName_en;
				products[productIndex].product_name_ar = editingProductName_ar;
				products = [...products]; // Trigger reactivity
			}

			closeEditModal();
		} catch (err) {
			console.error('Error saving product:', err);
			alert(err instanceof Error ? err.message : 'Failed to save product');
		} finally {
			isSaving = false;
		}
	}

	function openCategoryModal(product: Product) {
		categoryModalProductId = product.id;
		categorySearchQuery = '';
	}

	function closeCategoryModal() {
		categoryModalProductId = null;
		categorySearchQuery = '';
	}

	async function saveCategorySelection(categoryId: string) {
		if (!categoryModalProductId) return;

		isSavingCategory = true;
		try {
			const { error: updateError } = await supabase
				.from('products')
				.update({
					category_id: categoryId
				})
				.eq('id', categoryModalProductId);

			if (updateError) {
				throw new Error(updateError.message);
			}

			// Update the product in the local array
			const productIndex = products.findIndex((p) => p.id === categoryModalProductId);
			if (productIndex !== -1) {
				const category = categories.get(categoryId);
				products[productIndex].category_id = categoryId;
				products[productIndex].category_name_en = category?.name_en || null;
				products[productIndex].category_name_ar = category?.name_ar || null;
				products = [...products]; // Trigger reactivity
			}

			closeCategoryModal();
		} catch (err) {
			console.error('Error saving category:', err);
			alert(err instanceof Error ? err.message : 'Failed to save category');
		} finally {
			isSavingCategory = false;
		}
	}

	function getFilteredCategories() {
		if (!categorySearchQuery.trim()) {
			return Array.from(categories.values());
		}
		const query = categorySearchQuery.toLowerCase();
		return Array.from(categories.values()).filter(
			(cat) =>
				cat.name_en.toLowerCase().includes(query) || cat.name_ar.toLowerCase().includes(query)
		);
	}

	function openUnitModal(product: Product) {
		unitModalProductId = product.id;
		unitSearchQuery = '';
	}

	function closeUnitModal() {
		unitModalProductId = null;
		unitSearchQuery = '';
	}

	async function saveUnitSelection(unitId: string) {
		if (!unitModalProductId) return;

		isSavingUnit = true;
		try {
			const { error: updateError } = await supabase
				.from('products')
				.update({
					unit_id: unitId
				})
				.eq('id', unitModalProductId);

			if (updateError) {
				throw new Error(updateError.message);
			}

			// Update the product in the local array
			const productIndex = products.findIndex((p) => p.id === unitModalProductId);
			if (productIndex !== -1) {
				const unit = units.get(unitId);
				products[productIndex].unit_id = unitId;
				products[productIndex].unit_name_en = unit?.name_en || null;
				products[productIndex].unit_name_ar = unit?.name_ar || null;
				products = [...products]; // Trigger reactivity
			}

			closeUnitModal();
		} catch (err) {
			console.error('Error saving unit:', err);
			alert(err instanceof Error ? err.message : 'Failed to save unit');
		} finally {
			isSavingUnit = false;
		}
	}

	function getFilteredUnits() {
		if (!unitSearchQuery.trim()) {
			return Array.from(units.values());
		}
		const query = unitSearchQuery.toLowerCase();
		return Array.from(units.values()).filter(
			(unit) =>
				unit.name_en.toLowerCase().includes(query) || unit.name_ar.toLowerCase().includes(query)
		);
	}

	onMount(() => {
		loadProducts();
	});
</script>

<div class="products-dashboard">
	{#if isLoading && products.length === 0}
		<div class="loading">
			<div class="spinner"></div>
			<div>Loading products...</div>
		</div>
	{:else if error}
		<div class="error">{error}</div>
	{:else if products.length === 0}
		<div class="no-data">No products found</div>
	{:else}
		{#if isLoading}
			<div class="header-info">
				<span class="loading-indicator">Loading... {loadedCount} of {totalCount}</span>
			</div>
		{/if}

		<div class="search-container">
			<div class="search-group">
				<label for="barcode-search">🔍 Search Barcode (all pages)</label>
				<input
					id="barcode-search"
					type="text"
					placeholder="Enter barcode..."
					bind:value={barcodeSearchQuery}
					class="search-input"
				/>
			</div>
			<div class="search-group">
				<label for="name-search">🔍 Search Name (all pages)</label>
				<input
					id="name-search"
					type="text"
					placeholder="Enter product name..."
					bind:value={nameSearchQuery}
					class="search-input"
				/>
			</div>
			{#if barcodeSearchQuery || nameSearchQuery}
				<button class="btn-clear-search" on:click={() => { barcodeSearchQuery = ''; nameSearchQuery = ''; }}>Clear</button>
			{/if}
		</div>

		<div class="results-info">
			{#if isSearching}
				🔎 Found {searchResults.length} results across all {products.length} products
			{:else}
				📄 Page {currentPage} of {totalPages} — Showing {(currentPage - 1) * PAGE_SIZE + 1}–{Math.min(currentPage * PAGE_SIZE, products.length)} of {products.length} products
			{/if}
		</div>

		<!-- Pagination Controls (hidden during search) -->
		{#if !isSearching && totalPages > 1}
			<div class="pagination-controls">
				<button class="page-btn" disabled={currentPage === 1} on:click={() => goToPage(1)}>⏮ First</button>
				<button class="page-btn" disabled={currentPage === 1} on:click={() => goToPage(currentPage - 1)}>◀ Prev</button>
				{#each Array(totalPages) as _, i}
					<button 
						class="page-btn {currentPage === i + 1 ? 'active' : ''}"
						on:click={() => goToPage(i + 1)}
					>
						{i + 1}
					</button>
				{/each}
				<button class="page-btn" disabled={currentPage === totalPages} on:click={() => goToPage(currentPage + 1)}>Next ▶</button>
				<button class="page-btn" disabled={currentPage === totalPages} on:click={() => goToPage(totalPages)}>Last ⏭</button>
			</div>
		{/if}

		<div class="table-wrapper">
			<table class="products-table">
				<thead>
					<tr>
						<th class="sn-column">S.No</th>
						<th>Barcode</th>
						<th>Category</th>
						<th>Unit</th>
						<th>Name</th>
					</tr>
				</thead>
				<tbody>
					{#each displayProducts as product, index (product.id)}
						<tr>
							<td class="sn-column">{isSearching ? index + 1 : (currentPage - 1) * PAGE_SIZE + index + 1}</td>
							<td>{product.barcode || '-'}</td>
							<td>
								<div 
									class="product-category"
									on:dblclick={() => openCategoryModal(product)}
									role="button"
									tabindex="0"
									title="Double-click to change category"
								>
									<div class="category-name-en">{product.category_name_en || '-'}</div>
									<div class="category-name-ar">{product.category_name_ar || '-'}</div>
								</div>
							</td>
							<td>
								<div 
									class="product-unit"
									on:dblclick={() => openUnitModal(product)}
									role="button"
									tabindex="0"
									title="Double-click to change unit"
								>
									<div class="unit-name-en">{product.unit_name_en || '-'}</div>
									<div class="unit-name-ar">{product.unit_name_ar || '-'}</div>
								</div>
							</td>
							<td>
								<div 
									class="product-name"
									on:dblclick={() => openEditModal(product)}
									role="button"
									tabindex="0"
									title="Double-click to edit"
								>
									<div class="name-en">{product.product_name_en}</div>
									<div class="name-ar">{product.product_name_ar}</div>
								</div>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<!-- Edit Modal -->
{#if editingProductId}
		<div class="modal-overlay" role="presentation" on:click={closeEditModal} on:keydown={(e) => e.key === 'Escape' && closeEditModal()}>
			<div class="modal" role="dialog" tabindex="-1" on:click|stopPropagation on:keydown={(e) => e.key === 'Escape' && closeEditModal()}>
			<div class="modal-header">
				<h2>Edit Product Name</h2>
				<button class="close-btn" on:click={closeEditModal}>✕</button>
			</div>

			<div class="modal-content">
				<div class="form-group">
					<label for="name_en">English Name</label>
					<input
						id="name_en"
						type="text"
						bind:value={editingProductName_en}
						placeholder="Enter product name in English"
						disabled={isSaving}
					/>
				</div>

				<div class="form-group">
					<label for="name_ar">Arabic Name</label>
					<input
						id="name_ar"
						type="text"
						bind:value={editingProductName_ar}
						placeholder="أدخل اسم المنتج باللغة العربية"
						dir="rtl"
						disabled={isSaving}
					/>
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn btn-cancel" on:click={closeEditModal} disabled={isSaving}>
					Cancel
				</button>
				<button class="btn btn-save" on:click={saveProductName} disabled={isSaving}>
					{isSaving ? 'Saving...' : 'Save'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Category Selection Modal -->
{#if categoryModalProductId}
		<div class="modal-overlay" role="presentation" on:click={closeCategoryModal} on:keydown={(e) => e.key === 'Escape' && closeCategoryModal()}>
			<div class="modal" role="dialog" tabindex="-1" on:click|stopPropagation on:keydown={(e) => e.key === 'Escape' && closeCategoryModal()}>
			<div class="modal-header">
				<h2>Select Category</h2>
				<button class="close-btn" on:click={closeCategoryModal}>✕</button>
			</div>

			<div class="modal-content">
				<div class="search-group">
					<input
						type="text"
						placeholder="Search categories..."
						bind:value={categorySearchQuery}
						disabled={isSavingCategory}
						class="search-input"
					/>
				</div>

				<div class="category-list">
					{#each getFilteredCategories() as category (category.id)}
						<button
							class="category-item"
							on:click={() => saveCategorySelection(category.id)}
							disabled={isSavingCategory}
						>
							<div class="category-item-content">
								<div class="category-item-name-en">{category.name_en}</div>
								<div class="category-item-name-ar">{category.name_ar}</div>
							</div>
						</button>
					{/each}
				</div>

				{#if getFilteredCategories().length === 0}
					<div class="no-results">No categories found</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn btn-cancel" on:click={closeCategoryModal} disabled={isSavingCategory}>
					Close
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Unit Selection Modal -->
{#if unitModalProductId}
		<div class="modal-overlay" role="presentation" on:click={closeUnitModal} on:keydown={(e) => e.key === 'Escape' && closeUnitModal()}>
			<div class="modal" role="dialog" tabindex="-1" on:click|stopPropagation on:keydown={(e) => e.key === 'Escape' && closeUnitModal()}>
			<div class="modal-header">
				<h2>Select Unit</h2>
				<button class="close-btn" on:click={closeUnitModal}>✕</button>
			</div>

			<div class="modal-content">
				<div class="search-group">
					<input
						type="text"
						placeholder="Search units..."
						bind:value={unitSearchQuery}
						disabled={isSavingUnit}
						class="search-input"
					/>
				</div>

				<div class="category-list">
					{#each getFilteredUnits() as unit (unit.id)}
						<button
							class="category-item"
							on:click={() => saveUnitSelection(unit.id)}
							disabled={isSavingUnit}
						>
							<div class="category-item-content">
								<div class="category-item-name-en">{unit.name_en}</div>
								<div class="category-item-name-ar">{unit.name_ar}</div>
							</div>
						</button>
					{/each}
				</div>

				{#if getFilteredUnits().length === 0}
					<div class="no-results">No units found</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn btn-cancel" on:click={closeUnitModal} disabled={isSavingUnit}>
					Close
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.products-dashboard {
		padding: 20px;
		display: flex;
		flex-direction: column;
		gap: 20px;
		height: 100%;
		overflow: auto;
	}

	h1 {
		margin: 0;
		font-size: 28px;
		font-weight: 700;
		color: #059669;
	}

	.header-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 12px;
		color: #666;
		padding: 0 5px;
	}

	.search-container {
		display: flex;
		gap: 15px;
		align-items: flex-end;
		padding: 20px;
		background: linear-gradient(135deg, #f0fdf4 0%, #ecfdf5 100%);
		border-radius: 12px;
		border: 2px solid #d1fae5;
	}

	.search-group {
		display: flex;
		flex-direction: column;
		gap: 5px;
		flex: 1;
	}

	.search-group label {
		font-size: 12px;
		font-weight: 600;
		color: #333;
	}

	.search-input {
		padding: 10px 12px;
		border: 2px solid #d1fae5;
		border-radius: 8px;
		font-size: 14px;
		transition: all 0.3s;
	}

	.search-input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 4px rgba(16, 185, 129, 0.1);
		background-color: #f0fdf4;
	}

	.btn-clear-search {
		padding: 10px 20px;
		background-color: #f97316;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s;
	}

	.btn-clear-search:hover {
		background-color: #ea580c;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.3);
	}

	.results-info {
		font-size: 12px;
		color: #666;
		padding: 0 5px;
	}

	.loading-indicator {
		color: #10b981;
		font-weight: 600;
		animation: pulse 1s infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	.loading,
	.error,
	.no-data {
		padding: 40px 20px;
		border-radius: 8px;
		text-align: center;
		font-size: 14px;
	}

	.loading {
		background: linear-gradient(135deg, #ecfdf5 0%, #f0fdf4 100%);
		color: #059669;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 15px;
		border: 2px solid #d1fae5;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #d1fae5;
		border-top-color: #10b981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.error {
		background-color: #ffebee;
		color: #c62828;
	}

	.no-data {
		background-color: #f5f5f5;
		color: #666;
	}

	.table-wrapper {
		flex: 1;
		overflow: auto;
		border: 2px solid #d1fae5;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.1);
	}

	.products-table {
		width: 100%;
		border-collapse: collapse;
		background-color: white;
	}

	.products-table thead {
		background: linear-gradient(90deg, #ecfdf5 0%, #f0fdf4 100%);
		position: sticky;
		top: 0;
		z-index: 1;
		border-bottom: 3px solid #10b981;
	}

	.products-table th {
		padding: 14px 12px;
		text-align: left;
		font-weight: 700;
		border-bottom: 3px solid #10b981;
		border-right: 1px solid #d1fae5;
		font-size: 14px;
		color: #059669;
	}

	.products-table th:last-child {
		border-right: none;
	}

	.sn-column {
		width: 60px;
		text-align: center;
	}

	.products-table td {
		padding: 12px;
		border-bottom: 1px solid #e0e0e0;
		border-right: 1px solid #e0e0e0;
	}

	.products-table td:last-child {
		border-right: none;
	}

	.product-category {
		display: flex;
		flex-direction: column;
		gap: 4px;
		cursor: pointer;
		padding: 4px 0;
		transition: opacity 0.2s;
	}

	.product-category:hover {
		opacity: 0.8;
	}

	.product-category:focus {
		outline: 2px solid #10b981;
		outline-offset: 2px;
		border-radius: 4px;
	}

	.category-name-en {
		font-weight: 500;
		color: #333;
		font-size: 14px;
	}

	.category-name-ar {
		color: #666;
		font-size: 13px;
	}

	.product-unit {
		display: flex;
		flex-direction: column;
		gap: 4px;
		cursor: pointer;
		padding: 4px 0;
		transition: opacity 0.2s;
	}

	.product-unit:hover {
		opacity: 0.8;
	}

	.product-unit:focus {
		outline: 2px solid #10b981;
		outline-offset: 2px;
		border-radius: 4px;
	}

	.unit-name-en {
		font-weight: 500;
		color: #333;
		font-size: 14px;
	}

	.unit-name-ar {
		color: #666;
		font-size: 13px;
	}

	.products-table tbody tr:hover {
		background-color: #f0fdf4;
		border-left: 3px solid #f97316;
		padding-left: 8px;
	}

	.product-name {
		display: flex;
		flex-direction: column;
		gap: 4px;
		cursor: pointer;
		padding: 4px 0;
		transition: opacity 0.2s;
	}

	.product-name:hover {
		opacity: 0.8;
	}

	.product-name:focus {
		outline: 2px solid #10b981;
		outline-offset: 2px;
		border-radius: 4px;
	}

	.name-en {
		font-weight: 500;
		color: #333;
		font-size: 14px;
	}

	.name-ar {
		color: #666;
		font-size: 13px;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background-color: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal {
		background-color: white;
		border-radius: 12px;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		border: 2px solid #d1fae5;
	}

	.modal-header {
		padding: 20px;
		border-bottom: 2px solid #d1fae5;
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: linear-gradient(90deg, #f0fdf4 0%, #ecfdf5 100%);
		border-radius: 10px 10px 0 0;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 700;
		color: #059669;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		cursor: pointer;
		color: #059669;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background-color: rgba(16, 185, 129, 0.1);
	}


	.modal-content {
		padding: 20px;
		overflow-y: auto;
		flex: 1;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-group label {
		display: block;
		margin-bottom: 8px;
		font-weight: 500;
		font-size: 14px;
		color: #333;
	}

	.form-group input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		transition: border-color 0.2s;
	}

	.form-group input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
		background-color: #f0fdf4;
	}

	.form-group input:disabled {
		background-color: #f5f5f5;
		cursor: not-allowed;
	}

	.modal-footer {
		padding: 16px 20px;
		border-top: 2px solid #d1fae5;
		display: flex;
		gap: 10px;
		justify-content: flex-end;
		background-color: #fafafa;
		border-radius: 0 0 10px 10px;
	}

	.btn {
		padding: 10px 20px;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s;
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-cancel {
		background-color: #f3f4f6;
		color: #374151;
		border: 2px solid #e5e7eb;
	}

	.btn-cancel:hover:not(:disabled) {
		background-color: #f9fafb;
		border-color: #d1d5db;
	}

	.btn-save {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		font-weight: 600;
	}

	.btn-save:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.search-group {
		margin-bottom: 16px;
	}

	.search-input {
		width: 100%;
		padding: 10px 12px;
		border: 2px solid #d1fae5;
		border-radius: 8px;
		font-size: 14px;
		font-family: inherit;
		transition: all 0.3s;
		background-color: white;
	}

	.search-input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
		background-color: #f0fdf4;
	}

	.search-input:disabled {
		background-color: #f5f5f5;
		cursor: not-allowed;
	}

	.category-list {
		max-height: 400px;
		overflow-y: auto;
		border: 2px solid #d1fae5;
		border-radius: 8px;
		background-color: white;
	}

	.category-item {
		width: 100%;
		padding: 12px;
		border: none;
		border-bottom: 1px solid #e5e7eb;
		background: white;
		cursor: pointer;
		text-align: left;
		transition: all 0.2s;
	}

	.category-item:last-child {
		border-bottom: none;
	}

	.category-item:hover:not(:disabled) {
		background-color: #f0fdf4;
		border-left: 4px solid #f97316;
		padding-left: 8px;
	}

	.category-item:active:not(:disabled) {
		background-color: #ecfdf5;
	}

	.category-item:disabled {
		cursor: not-allowed;
		opacity: 0.6;
	}

	.category-item-content {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.category-item-name-en {
		font-weight: 600;
		color: #059669;
		font-size: 14px;
	}

	.category-item-name-ar {
		color: #10b981;
		font-size: 13px;
		font-weight: 500;
	}

	.no-results {
		padding: 20px;
		text-align: center;
		color: #059669;
		font-size: 14px;
		font-weight: 500;
		background-color: #f0fdf4;
		border-radius: 8px;
		border: 2px dashed #d1fae5;
	}

	.pagination-controls {
		display: flex;
		gap: 6px;
		align-items: center;
		justify-content: center;
		flex-wrap: wrap;
		padding: 8px 0;
	}

	.page-btn {
		padding: 8px 14px;
		border: 2px solid #d1fae5;
		border-radius: 8px;
		background: white;
		color: #059669;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.page-btn:hover:not(:disabled):not(.active) {
		background-color: #f0fdf4;
		border-color: #10b981;
		transform: translateY(-1px);
		box-shadow: 0 2px 6px rgba(16, 185, 129, 0.15);
	}

	.page-btn.active {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border-color: #059669;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.page-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}
</style>
