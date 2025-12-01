<script lang="ts">
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import TaxFormWindow from '$lib/components/desktop-interface/admin-customer-app/products/TaxFormWindow.svelte';

	let taxes: Array<{
		id: string;
		name_en: string;
		name_ar: string;
		percentage: number;
		is_active: boolean;
	}> = [];
	let loading = false;

	onMount(() => {
		loadTaxes();
		
		// Listen for new taxes created
		window.addEventListener('tax-created', handleTaxCreated);
		
		return () => {
			window.removeEventListener('tax-created', handleTaxCreated);
		};
	});

	async function loadTaxes() {
		loading = true;
		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			const { data, error } = await supabaseAdmin
				.from('tax_categories')
				.select('*')
				.order('name_en');

			if (error) throw error;
			
			taxes = data || [];
		} catch (error) {
			console.error('Error loading taxes:', error);
		} finally {
			loading = false;
		}
	}

	function handleTaxCreated(event: any) {
		loadTaxes();
	}

	function openCreateTax() {
		const windowId = `create-tax-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Tax Category #${instanceNumber}`,
			component: TaxFormWindow,
			icon: '💰',
			size: { width: 500, height: 400 },
			position: { 
				x: 150 + (Math.random() * 50),
				y: 150 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function toggleActive(tax: any) {
		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			const { error } = await supabaseAdmin
				.from('tax_categories')
				.update({ is_active: !tax.is_active })
				.eq('id', tax.id);

			if (error) throw error;
			
			await loadTaxes();
		} catch (error) {
			console.error('Error updating tax:', error);
			alert('Failed to update tax status');
		}
	}

	async function deleteTax(tax: any) {
		if (!confirm(`Are you sure you want to delete "${tax.name_en}"?`)) {
			return;
		}

		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			const { error } = await supabaseAdmin
				.from('tax_categories')
				.delete()
				.eq('id', tax.id);

			if (error) throw error;
			
			await loadTaxes();
		} catch (error) {
			console.error('Error deleting tax:', error);
			alert('Failed to delete tax');
		}
	}
</script>

<div class="tax-manager-container">
	<div class="header">
		<h3>Tax Categories</h3>
		<button class="add-tax-btn" on:click={openCreateTax}>
			<span class="btn-icon">➕</span>
			Add Tax Category
		</button>
	</div>

	<div class="table-container">
		{#if loading}
			<div class="loading-state">
				<span class="spinner">⏳</span>
				Loading taxes...
			</div>
		{:else if taxes.length === 0}
			<div class="empty-state">
				<span class="empty-icon">💰</span>
				<p>No tax categories found</p>
				<button class="create-first-btn" on:click={openCreateTax}>
					Create First Tax Category
				</button>
			</div>
		{:else}
			<table class="taxes-table">
				<thead>
					<tr>
						<th>English Name</th>
						<th>Arabic Name</th>
						<th>Percentage</th>
						<th>Status</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each taxes as tax (tax.id)}
						<tr>
							<td>{tax.name_en}</td>
							<td dir="rtl">{tax.name_ar}</td>
							<td>{tax.percentage}%</td>
							<td>
								<button
									class="status-badge"
									class:active={tax.is_active}
									class:inactive={!tax.is_active}
									on:click={() => toggleActive(tax)}
								>
									{tax.is_active ? 'Active' : 'Inactive'}
								</button>
							</td>
							<td>
								<div class="action-buttons">
									<button
										class="delete-btn"
										on:click={() => deleteTax(tax)}
										title="Delete"
									>
										🗑️
									</button>
								</div>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<style>
	.tax-manager-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 2px solid #e2e8f0;
	}

	.header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.add-tax-btn {
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

	.add-tax-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.btn-icon {
		font-size: 1.2rem;
	}

	.table-container {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
	}

	.loading-state {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 3rem;
		color: #64748b;
		font-size: 1.1rem;
	}

	.spinner {
		font-size: 1.5rem;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		padding: 3rem;
	}

	.empty-icon {
		font-size: 4rem;
	}

	.empty-state p {
		margin: 0;
		color: #64748b;
		font-size: 1.1rem;
	}

	.create-first-btn {
		margin-top: 1rem;
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

	.create-first-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.taxes-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		overflow: hidden;
	}

	.taxes-table thead {
		background: #f8fafc;
	}

	.taxes-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #1e293b;
		border-bottom: 2px solid #e2e8f0;
	}

	.taxes-table tbody tr {
		border-bottom: 1px solid #e2e8f0;
		transition: background 0.2s ease;
	}

	.taxes-table tbody tr:hover {
		background: #f8fafc;
	}

	.taxes-table tbody tr:last-child {
		border-bottom: none;
	}

	.taxes-table td {
		padding: 1rem;
		color: #475569;
	}

	.status-badge {
		padding: 0.375rem 0.75rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.status-badge.active {
		background: #d1fae5;
		color: #065f46;
	}

	.status-badge.active:hover {
		background: #a7f3d0;
	}

	.status-badge.inactive {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-badge.inactive:hover {
		background: #fecaca;
	}

	.action-buttons {
		display: flex;
		gap: 0.5rem;
	}

	.delete-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.delete-btn:hover {
		background: #dc2626;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3);
	}
</style>
