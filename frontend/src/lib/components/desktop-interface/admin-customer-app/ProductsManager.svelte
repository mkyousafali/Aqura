<script lang="ts">
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { supabase } from '$lib/utils/supabase';
	import CategoriesManager from '$lib/components/desktop-interface/admin-customer-app/products/CategoriesManager.svelte';
	import ManageProductsWindow from '$lib/components/desktop-interface/admin-customer-app/products/ManageProductsWindow.svelte';

	let totalProducts = 0;
	let activeProducts = 0;
	let lowStockItems = 0;
	let minimumAlertProducts = 0;
	let minimumQtyProducts = 0;
	let totalCategories = 0;
	let inventoryValue = 0;
	let avgProfitMargin = 0;
	let loading = true;
	let selectedCardType: string | null = null;
	let allProducts: any[] = [];
	let filteredProducts: any[] = [];

	// Generate unique window ID
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	async function loadDashboardData() {
		try {
			// Parallel load all data at once
			const pageSize = 500;
			let page = 0;
			let hasMore = true;
			const allCustomerProducts: any[] = [];

			// Load all customer products with pagination
			while (hasMore) {
				const { data, error } = await supabase
					.from('products')
					.select('barcode, product_name_en, product_name_ar, is_customer_product, cost, sale_price, current_stock, minimum_qty_alert, minim_qty')
					.eq('is_customer_product', true)
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (error) throw error;

				if (data && data.length > 0) {
					allCustomerProducts.push(...data);
					hasMore = data.length === pageSize;
					page++;
				} else {
					hasMore = false;
				}
			}

			allProducts = allCustomerProducts;
			activeProducts = allProducts?.length || 0;
			lowStockItems = allProducts?.filter(p => p.current_stock < 10)?.length || 0;
			minimumAlertProducts = allProducts?.filter(p => p.minimum_qty_alert && p.current_stock <= p.minimum_qty_alert)?.length || 0;
			minimumQtyProducts = allProducts?.filter(p => p.minim_qty && p.current_stock <= p.minim_qty)?.length || 0;

			// Calculate inventory value and profit margin for customer products
			if (allProducts && allProducts.length > 0) {
				let totalValue = 0;
				let totalProfitMargin = 0;
				let countWithMargin = 0;

				allProducts.forEach(p => {
					const costPrice = parseFloat(p.cost || 0);
					const salePrice = parseFloat(p.sale_price || 0);
					totalValue += costPrice * (p.current_stock || 0);

					if (costPrice > 0 && salePrice > 0) {
						const margin = ((salePrice - costPrice) / costPrice) * 100;
						totalProfitMargin += margin;
						countWithMargin++;
					}
				});

				inventoryValue = totalValue;
				avgProfitMargin = countWithMargin > 0 ? totalProfitMargin / countWithMargin : 0;
			}

			// Parallel load count and categories
			const [countResult, categoriesResult] = await Promise.all([
				supabase
					.from('products')
					.select('id', { count: 'exact', head: true }),
				supabase
					.from('product_categories')
					.select('id')
			]);

			if (countResult.error) throw countResult.error;
			totalProducts = countResult.count || 0;

			if (categoriesResult.error) throw categoriesResult.error;
			totalCategories = categoriesResult.data?.length || 0;

			loading = false;
		} catch (error) {
			console.error('Error loading dashboard data:', error);
			loading = false;
		}
	}

	onMount(() => {
		loadDashboardData();

		// Subscribe to real-time updates
		const productsChannel = supabase
			.channel('products-dashboard')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, () => {
				loadDashboardData();
			})
			.subscribe();

		const categoriesChannel = supabase
			.channel('categories-dashboard')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'product_categories' }, () => {
				loadDashboardData();
			})
			.subscribe();

		return () => {
			supabase.removeChannel(productsChannel);
			supabase.removeChannel(categoriesChannel);
		};
	});

	function openManageProducts() {
		const windowId = generateWindowId('manage-products');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manage Products #${instanceNumber}`,
			component: ManageProductsWindow,
			icon: '📦',
			size: { width: 1200, height: 700 },
			position: { 
				x: 100 + (Math.random() * 50),
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openManageCategories() {
		const windowId = generateWindowId('manage-categories');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Manage Categories #${instanceNumber}`,
			component: CategoriesManager,
			icon: '🏷️',
			size: { width: 1000, height: 700 },
			position: { 
				x: 120 + (Math.random() * 50),
				y: 120 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function selectCardType(type: string) {
		if (selectedCardType === type) {
			selectedCardType = null;
			filteredProducts = [];
		} else {
			selectedCardType = type;
			
			if (type === 'active') {
				filteredProducts = allProducts;
			} else if (type === 'minimumAlert') {
				filteredProducts = allProducts.filter(p => p.minimum_qty_alert && p.current_stock <= p.minimum_qty_alert);
			} else if (type === 'minimumQty') {
				filteredProducts = allProducts.filter(p => p.minim_qty && p.current_stock <= p.minim_qty);
			}
		}
	}

</script>

<div class="products-manager-container">
	<div class="header-section">
		<h2>🛍️ Products Manager</h2>
		<div class="button-group">
			<button class="manage-products-btn" on:click={openManageProducts}>
				<span class="btn-icon">📦</span>
				Manage Products
			</button>
			<button class="manage-btn" on:click={openManageCategories}>
				<span class="btn-icon">🏷️</span>
				Manage Categories
			</button>
		</div>
	</div>
	
	<div class="dashboard-section">
		<h3 class="dashboard-title">📊 Dashboard Overview</h3>
		{#if loading}
			<div class="loading">Loading dashboard data...</div>
		{:else}
			<div class="stats-grid">
				<button class="stat-card" class:active={selectedCardType === 'active'} on:click={() => selectCardType('active')}>
					<div class="stat-icon">✅</div>
					<div class="stat-content">
						<div class="stat-value">{activeProducts.toLocaleString()}</div>
						<div class="stat-label">Active Products</div>
					</div>
				</button>
				<button class="stat-card" class:active={selectedCardType === 'minimumAlert'} on:click={() => selectCardType('minimumAlert')}>
					<div class="stat-icon">⚠️</div>
					<div class="stat-content">
						<div class="stat-value">{minimumAlertProducts.toLocaleString()}</div>
						<div class="stat-label">Minimum Stock Alert</div>
					</div>
				</button>
				<button class="stat-card" class:active={selectedCardType === 'minimumQty'} on:click={() => selectCardType('minimumQty')}>
					<div class="stat-icon">🔴</div>
					<div class="stat-content">
						<div class="stat-value">{minimumQtyProducts.toLocaleString()}</div>
						<div class="stat-label">Below Minimum Qty</div>
					</div>
				</button>
			</div>

			{#if selectedCardType && filteredProducts.length > 0}
				<div class="products-table-section">
					<h3 class="table-title">
						{selectedCardType === 'active' ? '✅ Active Products' : selectedCardType === 'minimumAlert' ? '⚠️ Minimum Stock Alert Products' : '🔴 Below Minimum Qty Products'}
					</h3>
					<div class="table-wrapper">
						<table class="products-table">
							<thead>
								<tr>
									<th>Barcode</th>
									<th>Product Name</th>
									<th>Current Stock</th>
									<th>Min Alert</th>
									<th>Min Qty</th>
									<th>Cost</th>
									<th>Sale Price</th>
									<th>Margin %</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredProducts as product (product.barcode)}
									<tr>
										<td class="barcode">{product.barcode}</td>
										<td class="product-name">{product.product_name_en || product.product_name_ar || 'N/A'}</td>
										<td class="stock-value" class:low={product.current_stock < 10}>{product.current_stock}</td>
										<td class="alert-value">{product.minimum_qty_alert || '-'}</td>
										<td class="alert-value">{product.minim_qty || '-'}</td>
										<td class="price">{parseFloat(product.cost || 0).toFixed(2)}</td>
										<td class="price">{parseFloat(product.sale_price || 0).toFixed(2)}</td>
										<td class="margin">
											{#if product.cost && product.sale_price}
												{(((parseFloat(product.sale_price) - parseFloat(product.cost)) / parseFloat(product.cost)) * 100).toFixed(1)}%
											{:else}
												-
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{:else if selectedCardType}
				<div class="no-products">No products found</div>
			{/if}
		{/if}
	</div>
</div>

<style>
	.products-manager-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
	}

	.header-section {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e2e8f0;
	}

	.header-section h2 {
		margin: 0;
		color: #1e293b;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.button-group {
		display: flex;
		gap: 0.75rem;
	}

	.manage-products-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #f59e0b;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.manage-products-btn:hover {
		background: #d97706;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
	}

	.manage-products-btn:active {
		transform: translateY(0);
	}

	.manage-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #8b5cf6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.manage-btn:hover {
		background: #7c3aed;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);
	}

	.manage-btn:active {
		transform: translateY(0);
	}

	.tax-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.tax-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.tax-btn:active {
		transform: translateY(0);
	}

	.create-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-icon {
		font-size: 1.2rem;
	}

	.dashboard-section {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
	}

	.dashboard-title {
		margin: 0 0 1.5rem 0;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.25rem;
	}

	.stat-card {
		display: flex;
		align-items: center;
		gap: 1.25rem;
		padding: 1.5rem;
		background: white;
		border-radius: 0.75rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		transition: all 0.2s ease;
		cursor: pointer;
		border: 2px solid transparent;
		font: inherit;
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-card.active {
		border-color: #3b82f6;
		background: #eff6ff;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.stat-icon {
		width: 60px;
		height: 60px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
		border-radius: 0.75rem;
		font-size: 2rem;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 1.875rem;
		font-weight: 700;
		color: #1e293b;
		line-height: 1;
		margin-bottom: 0.375rem;
	}

	.stat-label {
		font-size: 0.875rem;
		color: #64748b;
		font-weight: 500;
	}

	@media (max-width: 1024px) {
		.button-group {
			flex-wrap: wrap;
		}

		.stats-grid {
			grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		}
	}

	@media (max-width: 768px) {
		.header-section {
			flex-direction: column;
			gap: 1rem;
			align-items: stretch;
		}

		.button-group {
			flex-direction: column;
		}

		.stats-grid {
			grid-template-columns: 1fr;
		}
	}

	.loading {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		color: #64748b;
		font-size: 1.125rem;
	}

	.products-table-section {
		margin-top: 2rem;
		background: white;
		border-radius: 0.75rem;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.table-title {
		margin: 0 0 1.5rem 0;
		color: #1e293b;
		font-size: 1.125rem;
		font-weight: 600;
	}

	.table-wrapper {
		overflow-x: auto;
	}

	.products-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.products-table thead {
		background: #f8fafc;
		border-bottom: 2px solid #e2e8f0;
	}

	.products-table th {
		padding: 0.75rem 1rem;
		text-align: left;
		font-weight: 600;
		color: #475569;
	}

	.products-table tbody tr {
		border-bottom: 1px solid #e2e8f0;
		transition: background 0.2s ease;
	}

	.products-table tbody tr:hover {
		background: #f8fafc;
	}

	.products-table td {
		padding: 0.75rem 1rem;
		color: #475569;
	}

	.products-table .barcode {
		font-family: monospace;
		color: #1e293b;
		font-weight: 500;
	}

	.products-table .product-name {
		color: #1e293b;
		font-weight: 500;
	}

	.products-table .stock-value {
		font-weight: 600;
	}

	.products-table .stock-value.low {
		color: #dc2626;
	}

	.products-table .alert-value {
		text-align: center;
		color: #64748b;
	}

	.products-table .price {
		text-align: right;
		font-weight: 500;
	}

	.products-table .margin {
		text-align: right;
		font-weight: 500;
		color: #059669;
	}

	.no-products {
		padding: 2rem;
		text-align: center;
		color: #64748b;
		background: white;
		border-radius: 0.75rem;
		margin-top: 1rem;
	}
</style>
