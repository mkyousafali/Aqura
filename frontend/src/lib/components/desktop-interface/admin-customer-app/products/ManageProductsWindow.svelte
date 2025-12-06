<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ProductFormWindow from '$lib/components/desktop-interface/admin-customer-app/products/ProductFormWindow.svelte';

	// Props
	let { selectedProductIds = [] }: { selectedProductIds?: string[] } = $props();

	let products: any[] = [];
	let loading = true;
	let error = '';

	// Computed property to get sorted products (selected first)
	$effect(() => {
		if (selectedProductIds && selectedProductIds.length > 0) {
			products = sortProductsBySelection(products, selectedProductIds);
		}
	});

	onMount(async () => {
		await loadProducts();
		
		// Listen for product saves to auto-refresh
		window.addEventListener('product-saved', handleProductSaved);
		
		return () => {
			window.removeEventListener('product-saved', handleProductSaved);
		};
	});
	
	function handleProductSaved() {
		loadProducts();
	}

	function sortProductsBySelection(products: any[], selectedIds: string[]): any[] {
		if (!selectedIds || selectedIds.length === 0) return products;
		
		const selectedSet = new Set(selectedIds);
		const selected = products.filter(p => selectedSet.has(p.id));
		const unselected = products.filter(p => !selectedSet.has(p.id));
		
		return [...selected, ...unselected];
	}

	async function loadProducts() {
		loading = true;
		error = '';
		try {
			const { data, error: fetchError } = await supabase
				.from('products')
				.select('*')
				.order('created_at', { ascending: false });

			if (fetchError) throw fetchError;
			
			let loadedProducts = data || [];
			
			// Sort to show selected products first
			if (selectedProductIds && selectedProductIds.length > 0) {
				loadedProducts = sortProductsBySelection(loadedProducts, selectedProductIds);
			}
			
			products = loadedProducts;
		} catch (err: any) {
			error = 'Failed to load products: ' + err.message;
			console.error('Error loading products:', err);
		} finally {
			loading = false;
		}
	}

	function editProduct(product: any) {
		const windowId = `edit-product-${product.id}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Edit: ${product.product_name_en} #${instanceNumber}`,
			component: ProductFormWindow,
			icon: '✏️',
			size: { width: 800, height: 700 },
			position: { 
				x: 120 + (Math.random() * 50),
				y: 120 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: { productData: product }
		});
	}

	async function deleteProduct(productId: string) {
		if (!confirm('Are you sure you want to delete this product?')) return;
		
		try {
			const { error: deleteError } = await supabase
				.from('products')
				.delete()
				.eq('id', productId);

			if (deleteError) throw deleteError;
			await loadProducts();
		} catch (err: any) {
			alert('Failed to delete product: ' + err.message);
		}
	}

	async function toggleActive(productId: string, currentStatus: boolean) {
		try {
			const { error: updateError } = await supabase
				.from('products')
				.update({ is_active: !currentStatus })
				.eq('id', productId);

			if (updateError) throw updateError;
			await loadProducts();
		} catch (err: any) {
			alert('Failed to update product status: ' + err.message);
		}
	}
</script>

<div class="manage-products-container">
	<div class="header">
		<h2>📦 Manage Products</h2>
		<button class="refresh-btn" on:click={loadProducts}>
			<span class="btn-icon">🔄</span>
			Refresh
		</button>
	</div>

	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading products...</p>
		</div>
	{:else if error}
		<div class="error-state">
			<p class="error-message">{error}</p>
			<button class="retry-btn" on:click={loadProducts}>Retry</button>
		</div>
	{:else if products.length === 0}
		<div class="empty-state">
			<p class="empty-icon">📦</p>
			<p class="empty-message">No products found</p>
			<p class="empty-hint">Create your first product to get started</p>
		</div>
	{:else}
		<div class="table-container">
			<table class="products-table">
				<thead>
					<tr>
						<th>Serial</th>
						<th>Image</th>
						<th>Product Name (EN)</th>
						<th>Product Name (AR)</th>
						<th>Category</th>
						<th>Unit</th>
						<th>Unit Qty</th>
						<th>Barcode</th>
						<th>Sale Price</th>
						<th>Cost</th>
						<th>Profit %</th>
						<th>Stock</th>
						<th>Status</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each products as product (product.id)}
						<tr 
							class:inactive={!product.is_active}
							class:selected={selectedProductIds && selectedProductIds.includes(product.id)}
						>
							<td class="serial">
								{#if selectedProductIds && selectedProductIds.includes(product.id)}
									<span class="selected-badge">✓</span>
								{/if}
								{product.product_serial}
							</td>
							<td class="image-cell">
								{#if product.image_url}
									<img src={product.image_url} alt={product.product_name_en} class="product-thumbnail" />
								{:else}
									<div class="no-image">📦</div>
								{/if}
							</td>
							<td>{product.product_name_en}</td>
							<td class="arabic">{product.product_name_ar}</td>
							<td>{product.category_name_en}</td>
							<td>{product.unit_name_en}</td>
							<td class="qty">{product.unit_qty}</td>
							<td class="barcode">{product.barcode || 'N/A'}</td>
							<td class="price">{product.sale_price} SAR</td>
							<td class="cost">{product.cost} SAR</td>
							<td class="profit">{product.profit_percentage.toFixed(2)}%</td>
							<td class="stock" class:low-stock={product.current_stock < product.minim_qty}>
								{product.current_stock}
							</td>
							<td>
								<button 
									class="status-toggle"
									class:active={product.is_active}
									on:click={() => toggleActive(product.id, product.is_active)}
								>
									{product.is_active ? '✓ Active' : '✗ Inactive'}
								</button>
							</td>
							<td class="actions">
								<button class="action-btn edit-btn" on:click={() => editProduct(product)} title="Edit">
									✏️
								</button>
								<button class="action-btn delete-btn" on:click={() => deleteProduct(product.id)} title="Delete">
									🗑️
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<div class="footer">
			<p class="total-count">Total Products: <strong>{products.length}</strong></p>
		</div>
	{/if}
</div>

<style>
	.manage-products-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e2e8f0;
	}

	.header h2 {
		margin: 0;
		color: #1e293b;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.refresh-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.btn-icon {
		font-size: 1rem;
	}

	.loading-state,
	.error-state,
	.empty-state {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		text-align: center;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.error-message {
		color: #dc2626;
		margin-bottom: 1rem;
		font-size: 1rem;
	}

	.retry-btn {
		padding: 0.5rem 1.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.empty-message {
		font-size: 1.25rem;
		font-weight: 600;
		color: #64748b;
		margin-bottom: 0.5rem;
	}

	.empty-hint {
		color: #94a3b8;
		font-size: 0.875rem;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		padding: 1.5rem;
	}

	.products-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
		border-radius: 0.5rem;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.products-table thead {
		background: #f1f5f9;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.products-table th {
		padding: 0.75rem;
		text-align: left;
		font-size: 0.75rem;
		font-weight: 600;
		color: #475569;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		border-bottom: 2px solid #e2e8f0;
		white-space: nowrap;
	}

	.products-table td {
		padding: 0.75rem;
		font-size: 0.875rem;
		color: #334155;
		border-bottom: 1px solid #f1f5f9;
	}

	.products-table tr:hover {
		background: #f8fafc;
	}

	.products-table tr.inactive {
		opacity: 0.6;
		background: #fef2f2;
	}

	.products-table tr.selected {
		background: #dbeafe;
		border-left: 4px solid #3b82f6;
	}

	.products-table tr.selected:hover {
		background: #bfdbfe;
	}

	.selected-badge {
		display: inline-block;
		background: #3b82f6;
		color: white;
		font-size: 0.7rem;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
		margin-right: 0.5rem;
		font-weight: 600;
	}

	.serial {
		font-weight: 600;
		color: #3b82f6;
		font-family: monospace;
	}

	.image-cell {
		text-align: center;
	}

	.product-thumbnail {
		width: 40px;
		height: 40px;
		object-fit: cover;
		border-radius: 0.375rem;
		border: 1px solid #e2e8f0;
	}

	.no-image {
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f1f5f9;
		border-radius: 0.375rem;
		font-size: 1.25rem;
	}

	.arabic {
		direction: rtl;
		text-align: right;
	}

	.qty,
	.price,
	.cost,
	.profit,
	.stock {
		text-align: right;
		font-weight: 500;
		font-family: monospace;
	}

	.barcode {
		font-family: monospace;
		font-size: 0.75rem;
		color: #64748b;
	}

	.profit {
		color: #10b981;
	}

	.stock.low-stock {
		color: #dc2626;
		font-weight: 600;
	}

	.status-toggle {
		padding: 0.25rem 0.75rem;
		border: none;
		border-radius: 0.25rem;
		font-size: 0.75rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.status-toggle.active {
		background: #d1fae5;
		color: #065f46;
	}

	.status-toggle:not(.active) {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-toggle:hover {
		transform: scale(1.05);
	}

	.actions {
		display: flex;
		gap: 0.5rem;
		justify-content: center;
	}

	.action-btn {
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border: none;
		border-radius: 0.25rem;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.edit-btn {
		background: #dbeafe;
	}

	.edit-btn:hover {
		background: #3b82f6;
		transform: scale(1.1);
	}

	.delete-btn {
		background: #fee2e2;
	}

	.delete-btn:hover {
		background: #dc2626;
		transform: scale(1.1);
	}

	.footer {
		padding: 1rem 1.5rem;
		background: white;
		border-top: 2px solid #e2e8f0;
		text-align: right;
	}

	.total-count {
		margin: 0;
		color: #64748b;
		font-size: 0.875rem;
	}

	.total-count strong {
		color: #1e293b;
		font-size: 1rem;
	}
</style>
