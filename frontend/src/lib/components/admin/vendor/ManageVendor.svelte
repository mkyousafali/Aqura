<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import EditVendor from './EditVendor.svelte';

	// State management
	let totalVendors = 0;
	let vendors = [];
	let filteredVendors = [];
	let searchQuery = '';
	let isLoading = true;
	let error = null;

	// Load vendor data on component mount
	onMount(async () => {
		await loadVendors();
	});

	// Load vendors from database
	async function loadVendors() {
		try {
			isLoading = true;
			error = null;

			const { data, error: fetchError } = await supabase
				.from('vendors')
				.select('*')
				.order('erp_vendor_id', { ascending: true });

			if (fetchError) throw fetchError;

			vendors = data || [];
			filteredVendors = vendors;
			totalVendors = vendors.length;

		} catch (err) {
			error = err.message;
		} finally {
			isLoading = false;
		}
	}

	// Search functionality
	function handleSearch() {
		if (!searchQuery.trim()) {
			filteredVendors = vendors;
		} else {
			const query = searchQuery.toLowerCase();
			filteredVendors = vendors.filter(vendor => 
				vendor.erp_vendor_id.toString().includes(query) ||
				vendor.vendor_name.toLowerCase().includes(query) ||
				(vendor.salesman_name && vendor.salesman_name.toLowerCase().includes(query)) ||
				(vendor.salesman_contact && vendor.salesman_contact.toLowerCase().includes(query)) ||
				(vendor.supervisor_name && vendor.supervisor_name.toLowerCase().includes(query)) ||
				(vendor.supervisor_contact && vendor.supervisor_contact.toLowerCase().includes(query)) ||
				(vendor.vendor_contact_number && vendor.vendor_contact_number.toLowerCase().includes(query)) ||
				(vendor.payment_method && vendor.payment_method.toLowerCase().includes(query)) ||
				(vendor.credit_period && vendor.credit_period.toString().includes(query)) ||
				(vendor.bank_name && vendor.bank_name.toLowerCase().includes(query)) ||
				(vendor.iban && vendor.iban.toLowerCase().includes(query)) ||
				(vendor.status && vendor.status.toLowerCase().includes(query)) ||
				(vendor.last_visit && vendor.last_visit.toLowerCase().includes(query)) ||
				(vendor.vendor_category && vendor.vendor_category.toLowerCase().includes(query)) ||
				(vendor.warehouse_location && vendor.warehouse_location.toLowerCase().includes(query))
			);
		}
	}

	// Reactive search
	$: if (searchQuery !== undefined) {
		handleSearch();
	}

	// Refresh data
	async function refreshData() {
		await loadVendors();
	}

	// Generate unique window ID
	function generateWindowId() {
		return `edit-vendor-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Open edit vendor window
	function openEditWindow(vendor) {
		const windowId = generateWindowId();
		
		windowManager.openWindow({
			id: windowId,
			title: `Edit Vendor - ${vendor.vendor_name}`,
			component: EditVendor,
			icon: '✏️',
			size: { width: 800, height: 600 },
			position: { 
				x: 150 + (Math.random() * 50),
				y: 150 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				vendor: vendor,
				onSave: (updatedVendor) => {
					// Update local vendor data
					const index = vendors.findIndex(v => v.erp_vendor_id === updatedVendor.erp_vendor_id);
					if (index !== -1) {
						vendors[index] = updatedVendor;
						handleSearch(); // Refresh filtered data
					}
					// Close the edit window
					windowManager.closeWindow(windowId);
				},
				onCancel: () => {
					// Close the edit window
					windowManager.closeWindow(windowId);
				}
			}
		});
	}

	// Update vendor status
	async function updateVendorStatus(vendorId, newStatus) {
		try {
			const { error } = await supabase
				.from('vendors')
				.update({ 
					status: newStatus,
					updated_at: new Date().toISOString()
				})
				.eq('erp_vendor_id', vendorId);

			if (error) throw error;

			// Update local vendor data
			const index = vendors.findIndex(v => v.erp_vendor_id === vendorId);
			if (index !== -1) {
				vendors[index].status = newStatus;
				vendors[index].updated_at = new Date().toISOString();
				handleSearch(); // Refresh filtered data
			}

			// Show success message
			alert(`Vendor status updated to ${newStatus} successfully!`);
		} catch (err) {
			console.error('Error updating vendor status:', err);
			alert('Failed to update vendor status. Please try again.');
		}
	}

	// Cycle vendor status: Active → Blacklist → Deactivate → Active
	async function cycleVendorStatus(vendorId, currentStatus) {
		let nextStatus;
		
		switch (currentStatus) {
			case 'Active':
				nextStatus = 'Blacklisted';
				break;
			case 'Blacklisted':
				nextStatus = 'Deactivated';
				break;
			case 'Deactivated':
				nextStatus = 'Active';
				break;
			default:
				nextStatus = 'Blacklisted'; // Default to blacklist if unknown status
		}
		
		await updateVendorStatus(vendorId, nextStatus);
	}
</script>

<div class="manage-vendor">
	<!-- Header -->
	<div class="header">
		<h1 class="title">📊 Manage Vendors</h1>
		<p class="subtitle">View and manage vendor information</p>
	</div>

	<!-- Dashboard Card -->
	<div class="dashboard-section">
		<div class="vendor-card">
			<div class="card-icon">👥</div>
			<div class="card-content">
				<h3>Total Vendors</h3>
				{#if isLoading}
					<div class="loading-count">...</div>
				{:else}
					<div class="vendor-count">{totalVendors}</div>
				{/if}
				<p>Active vendor records</p>
			</div>
			<button class="refresh-btn" on:click={refreshData} disabled={isLoading}>
				🔄 Refresh
			</button>
		</div>
	</div>

	<!-- Search Section -->
	<div class="search-section">
		<div class="search-bar">
			<div class="search-input-wrapper">
				<span class="search-icon">🔍</span>
				<input 
					type="text" 
					placeholder="Search by ERP ID or vendor name..."
					bind:value={searchQuery}
					class="search-input"
				/>
				{#if searchQuery}
					<button class="clear-search" on:click={() => searchQuery = ''}>×</button>
				{/if}
			</div>
		</div>
		<div class="search-results">
			Showing {filteredVendors.length} of {totalVendors} vendors
		</div>
	</div>

	<!-- Table Section -->
	<div class="table-section">
		{#if error}
			<div class="error-message">
				<span class="error-icon">⚠️</span>
				<p>Error loading vendors: {error}</p>
				<button class="retry-btn" on:click={refreshData}>Try Again</button>
			</div>
		{:else if isLoading}
			<div class="loading-table">
				<div class="loading-spinner">⏳</div>
				<p>Loading vendors...</p>
			</div>
		{:else if filteredVendors.length === 0}
			<div class="empty-state">
				{#if searchQuery}
					<span class="empty-icon">🔍</span>
					<h3>No vendors found</h3>
					<p>No vendors match your search criteria</p>
					<button class="clear-search-btn" on:click={() => searchQuery = ''}>Clear Search</button>
				{:else}
					<span class="empty-icon">📝</span>
					<h3>No vendors yet</h3>
					<p>Upload vendor data to get started</p>
				{/if}
			</div>
		{:else}
			<div class="vendor-table">
				<table>
					<thead>
						<tr>
							<th>ERP Vendor ID</th>
							<th>Vendor Name</th>
							<th>Salesman Name</th>
							<th>Salesman Contact</th>
							<th>Supervisor Name</th>
							<th>Supervisor Contact</th>
							<th>Vendor Contact</th>
							<th>Payment Method</th>
							<th>Credit Period</th>
							<th>Bank Name</th>
							<th>IBAN</th>
							<th>Last Visit</th>
							<th>Category</th>
							<th>Status</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredVendors as vendor}
							<tr>
								<td class="vendor-id">{vendor.erp_vendor_id}</td>
								<td class="vendor-name">{vendor.vendor_name}</td>
								<td class="vendor-data">{vendor.salesman_name || '-'}</td>
								<td class="vendor-data">{vendor.salesman_contact || '-'}</td>
								<td class="vendor-data">{vendor.supervisor_name || '-'}</td>
								<td class="vendor-data">{vendor.supervisor_contact || '-'}</td>
								<td class="vendor-data">{vendor.vendor_contact_number || '-'}</td>
								<td class="payment-method">{vendor.payment_method || '-'}</td>
								<td class="credit-period">
									{#if (vendor.payment_method === 'Cash Credit' || vendor.payment_method === 'Bank Credit') && vendor.credit_period}
										{vendor.credit_period} days
									{:else}
										-
									{/if}
								</td>
								<td class="bank-info">
									{#if (vendor.payment_method === 'Bank on Delivery' || vendor.payment_method === 'Bank Credit') && vendor.bank_name}
										{vendor.bank_name}
									{:else}
										-
									{/if}
								</td>
								<td class="bank-info">
									{#if (vendor.payment_method === 'Bank on Delivery' || vendor.payment_method === 'Bank Credit') && vendor.iban}
										{vendor.iban}
									{:else}
										-
									{/if}
								</td>
								<td class="last-visit">
									{#if vendor.last_visit}
										{new Date(vendor.last_visit).toLocaleDateString('en-US', { 
											year: 'numeric', 
											month: 'short', 
											day: 'numeric',
											hour: '2-digit',
											minute: '2-digit'
										})}
									{:else}
										<span class="no-visit">Never</span>
									{/if}
								</td>
								<td class="vendor-category">
									<span class="category-badge">
										{vendor.vendor_category || 'Daily Fresh Vendor'}
									</span>
									{#if vendor.warehouse_location}
										<div class="location-info">📍 {vendor.warehouse_location}</div>
									{/if}
								</td>
								<td class="status-cell">
									{#if vendor.status === 'Active'}
										<button class="status-cycle-btn status-active" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
											✅ Active
										</button>
									{:else if vendor.status === 'Deactivated'}
										<button class="status-cycle-btn status-deactivated" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
											🚫 Deactivated
										</button>
									{:else if vendor.status === 'Blacklisted'}
										<button class="status-cycle-btn status-blacklisted" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
											⚫ Blacklist
										</button>
									{:else}
										<button class="status-cycle-btn status-active" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
											✅ Active
										</button>
									{/if}
								</td>
								<td class="action-buttons">
									<button class="edit-btn" on:click={() => openEditWindow(vendor)}>✏️ Edit</button>
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
	.manage-vendor {
		padding: 1.5rem;
		background: #f8fafc;
		min-height: 100vh;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Header */
	.header {
		margin-bottom: 2rem;
		text-align: center;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1.1rem;
	}

	/* Dashboard Card */
	.dashboard-section {
		margin-bottom: 2rem;
	}

	.vendor-card {
		background: linear-gradient(135deg, #3b82f6, #1d4ed8);
		color: white;
		padding: 2rem;
		border-radius: 16px;
		display: flex;
		align-items: center;
		gap: 1.5rem;
		box-shadow: 0 10px 25px rgba(59, 130, 246, 0.3);
		max-width: 600px;
		margin: 0 auto;
	}

	.card-icon {
		font-size: 3rem;
		opacity: 0.9;
	}

	.card-content {
		flex: 1;
	}

	.card-content h3 {
		font-size: 1.2rem;
		margin-bottom: 0.5rem;
		opacity: 0.9;
	}

	.vendor-count {
		font-size: 3rem;
		font-weight: 800;
		margin-bottom: 0.25rem;
	}

	.loading-count {
		font-size: 3rem;
		font-weight: 800;
		margin-bottom: 0.25rem;
		opacity: 0.7;
	}

	.card-content p {
		opacity: 0.8;
		font-size: 0.95rem;
	}

	.refresh-btn {
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: 1px solid rgba(255, 255, 255, 0.3);
		padding: 0.75rem 1.25rem;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
	}

	.refresh-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Search Section */
	.search-section {
		margin-bottom: 2rem;
	}

	.search-bar {
		max-width: 600px;
		margin: 0 auto 1rem;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-icon {
		position: absolute;
		left: 1rem;
		font-size: 1.2rem;
		color: #64748b;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 1rem 1rem 1rem 3rem;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		font-size: 1rem;
		background: white;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.clear-search {
		position: absolute;
		right: 1rem;
		background: #64748b;
		color: white;
		border: none;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
		transition: all 0.2s;
	}

	.clear-search:hover {
		background: #475569;
	}

	.search-results {
		text-align: center;
		color: #64748b;
		font-size: 0.9rem;
	}

	/* Table Section */
	.table-section {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		overflow: hidden;
	}

	.vendor-table {
		overflow-x: auto;
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	thead {
		background: #f1f5f9;
	}

	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
	}

	td {
		padding: 1rem;
		border-bottom: 1px solid #f3f4f6;
		color: #374151;
	}

	.vendor-id {
		font-weight: 600;
		color: #3b82f6;
		font-family: 'Courier New', monospace;
	}

	.vendor-name {
		font-weight: 500;
	}

	.vendor-data {
		font-size: 0.9rem;
		color: #6b7280;
	}

	.payment-method {
		font-weight: 500;
		font-size: 0.9rem;
	}

	.credit-period {
		font-size: 0.9rem;
		color: #059669;
		font-weight: 500;
	}

	.bank-info {
		font-size: 0.85rem;
		color: #374151;
		max-width: 120px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.last-visit {
		font-size: 0.8rem;
		color: #4b5563;
		min-width: 120px;
		white-space: nowrap;
	}

	.no-visit {
		color: #9ca3af;
		font-style: italic;
	}

	.vendor-category {
		font-size: 0.8rem;
		min-width: 130px;
	}

	.category-badge {
		background: #e0f2fe;
		color: #0369a1;
		padding: 0.25rem 0.5rem;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 500;
		display: inline-block;
		margin-bottom: 0.25rem;
	}

	.location-info {
		color: #6b7280;
		font-size: 0.7rem;
		margin-top: 0.25rem;
	}

	/* Status Button Styling in Status Column */
	.status-cell {
		text-align: center;
		padding: 0.5rem;
	}

	/* Action Buttons */
	.action-buttons {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		justify-content: center;
		align-items: center;
	}

	.edit-btn, .status-cycle-btn {
		padding: 0.375rem 0.75rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		white-space: nowrap;
	}

	.edit-btn {
		background: #3b82f6;
		color: white;
	}

	.edit-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	/* Status Cycle Button Styles */
	.status-cycle-btn {
		font-weight: 600;
		border: 2px solid transparent;
		transition: all 0.3s ease;
	}

	.status-cycle-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.status-active {
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		border-color: #059669;
	}

	.status-active:hover {
		background: linear-gradient(135deg, #059669, #047857);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.status-blacklisted {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: white;
		border-color: #dc2626;
	}

	.status-blacklisted:hover {
		background: linear-gradient(135deg, #dc2626, #b91c1c);
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3);
	}

	.status-deactivated {
		background: linear-gradient(135deg, #f59e0b, #d97706);
		color: white;
		border-color: #d97706;
	}

	.status-deactivated:hover {
		background: linear-gradient(135deg, #d97706, #b45309);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
	}

	tbody tr:hover {
		background: #f8fafc;
	}

	/* Loading and Error States */
	.loading-table, .empty-state, .error-message {
		text-align: center;
		padding: 3rem 2rem;
	}

	.loading-spinner, .empty-icon, .error-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
		display: block;
	}

	.error-message {
		color: #dc2626;
	}

	.retry-btn, .clear-search-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		margin-top: 1rem;
		font-weight: 500;
		transition: all 0.2s;
	}

	.retry-btn:hover, .clear-search-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	/* Action Buttons */
	.action-buttons {
		white-space: nowrap;
		text-align: center;
	}

	.edit-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
	}

	.edit-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.manage-vendor {
			padding: 1rem;
		}

		.vendor-card {
			flex-direction: column;
			text-align: center;
			gap: 1rem;
		}

		.card-icon {
			font-size: 2.5rem;
		}

		.vendor-count {
			font-size: 2.5rem;
		}

		.search-input {
			padding: 0.875rem 0.875rem 0.875rem 2.5rem;
		}

		th, td {
			padding: 0.75rem 0.5rem;
			font-size: 0.9rem;
		}
	}
</style>