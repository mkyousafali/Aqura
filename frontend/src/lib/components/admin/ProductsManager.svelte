<script lang="ts">
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ProductFormWindow from './products/ProductFormWindow.svelte';
	import CategoriesManager from './products/CategoriesManager.svelte';
	import TaxManager from './products/TaxManager.svelte';
	import ManageProductsWindow from './products/ManageProductsWindow.svelte';

	// Generate unique window ID
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openCreateProduct() {
		const windowId = generateWindowId('create-product');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Product #${instanceNumber}`,
			component: ProductFormWindow,
			icon: '📦',
			size: { width: 800, height: 700 },
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

	function openManageTaxes() {
		const windowId = generateWindowId('manage-taxes');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Tax Manager #${instanceNumber}`,
			component: TaxManager,
			icon: '💰',
			size: { width: 900, height: 600 },
			position: { 
				x: 140 + (Math.random() * 50),
				y: 140 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
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
			<button class="tax-btn" on:click={openManageTaxes}>
				<span class="btn-icon">💰</span>
				Tax Manager
			</button>
			<button class="create-btn" on:click={openCreateProduct}>
				<span class="btn-icon">➕</span>
				Create Product
			</button>
		</div>
	</div>
	
	<div class="dashboard-section">
		<h3 class="dashboard-title">📊 Dashboard Overview</h3>
		<div class="stats-grid">
			<div class="stat-card">
				<div class="stat-icon">📦</div>
				<div class="stat-content">
					<div class="stat-value">1,247</div>
					<div class="stat-label">Total Products</div>
				</div>
			</div>
			
			<div class="stat-card">
				<div class="stat-icon">✅</div>
				<div class="stat-content">
					<div class="stat-value">1,189</div>
					<div class="stat-label">Active Products</div>
				</div>
			</div>
			
			<div class="stat-card">
				<div class="stat-icon">⚠️</div>
				<div class="stat-content">
					<div class="stat-value">23</div>
					<div class="stat-label">Low Stock Items</div>
				</div>
			</div>
			
			<div class="stat-card">
				<div class="stat-icon">📈</div>
				<div class="stat-content">
					<div class="stat-value">₿ 45.2K</div>
					<div class="stat-label">Total Inventory Value</div>
				</div>
			</div>
			
			<div class="stat-card">
				<div class="stat-icon">🏷️</div>
				<div class="stat-content">
					<div class="stat-value">20</div>
					<div class="stat-label">Product Categories</div>
				</div>
			</div>
			
			<div class="stat-card">
				<div class="stat-icon">💰</div>
				<div class="stat-content">
					<div class="stat-value">38.5%</div>
					<div class="stat-label">Avg. Profit Margin</div>
				</div>
			</div>
		</div>
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

	.create-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.create-btn:active {
		transform: translateY(0);
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
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
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
</style>
