<script lang="ts">
	import { onMount } from 'svelte';
	import { localeData, t } from '$lib/i18n';

	// Mock data for demonstration
	let vendors = [
		{
			id: '1',
			vendorId: 'VN001',
			name: 'TechSolutions Arabia',
			category: 'Technology',
			taxId: '300123456700003',
			contactPerson: 'Ahmed Al-Khobar',
			email: 'ahmed@techsolutions.sa',
			phone: '+966 11 456 7890',
			address: 'King Abdulaziz Road, Riyadh 11422',
			paymentTerms: '30 days',
			status: 'active',
			registrationDate: '2022-01-15',
			totalOrders: 24
		},
		{
			id: '2',
			vendorId: 'VN002',
			name: 'Gulf Office Supplies',
			category: 'Office Supplies',
			taxId: '300987654300001',
			contactPerson: 'Fatima Al-Zahrani',
			email: 'fatima@gulfoffice.com',
			phone: '+966 12 345 6789',
			address: 'Commercial District, Jeddah 21451',
			paymentTerms: '15 days',
			status: 'active',
			registrationDate: '2021-08-20',
			totalOrders: 156
		},
		{
			id: '3',
			vendorId: 'VN003',
			name: 'Modern Catering Services',
			category: 'Catering',
			taxId: '300555666700002',
			contactPerson: 'Omar Hassan',
			email: 'omar@moderncatering.sa',
			phone: '+966 13 222 3333',
			address: 'Industrial Area, Dammam 31421',
			paymentTerms: '7 days',
			status: 'inactive',
			registrationDate: '2023-03-10',
			totalOrders: 8
		}
	];

	let searchQuery = '';
	let selectedCategory = '';
	let selectedStatus = '';
	let showAddModal = false;
	let showEditModal = false;
	let selectedVendor = null;

	// Form data
	let formData = {
		vendorId: '',
		name: '',
		category: '',
		taxId: '',
		contactPerson: '',
		email: '',
		phone: '',
		address: '',
		paymentTerms: '',
		status: 'active',
		registrationDate: ''
	};

	const categories = ['Technology', 'Office Supplies', 'Catering', 'Transportation', 'Maintenance', 'Consulting'];
	const statuses = ['active', 'inactive', 'pending'];
	const paymentTermOptions = ['7 days', '15 days', '30 days', '45 days', '60 days'];

	$: filteredVendors = vendors.filter(vendor => {
		const matchesSearch = searchQuery === '' || 
			vendor.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
			vendor.vendorId.toLowerCase().includes(searchQuery.toLowerCase()) ||
			vendor.contactPerson.toLowerCase().includes(searchQuery.toLowerCase()) ||
			vendor.email.toLowerCase().includes(searchQuery.toLowerCase());
		
		const matchesCategory = selectedCategory === '' || vendor.category === selectedCategory;
		const matchesStatus = selectedStatus === '' || vendor.status === selectedStatus;
		
		return matchesSearch && matchesCategory && matchesStatus;
	});

	function resetForm() {
		formData = {
			vendorId: '',
			name: '',
			category: '',
			taxId: '',
			contactPerson: '',
			email: '',
			phone: '',
			address: '',
			paymentTerms: '30 days',
			status: 'active',
			registrationDate: ''
		};
	}

	function openAddModal() {
		resetForm();
		showAddModal = true;
	}

	function closeAddModal() {
		showAddModal = false;
		resetForm();
	}

	function openEditModal(vendor) {
		selectedVendor = vendor;
		formData = { ...vendor };
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		selectedVendor = null;
		resetForm();
	}

	function handleAddVendor() {
		const newVendor = {
			...formData,
			id: (vendors.length + 1).toString(),
			totalOrders: 0
		};
		vendors = [...vendors, newVendor];
		closeAddModal();
	}

	function handleEditVendor() {
		vendors = vendors.map(vendor => 
			vendor.id === selectedVendor.id ? 
				{ ...formData, id: selectedVendor.id, totalOrders: selectedVendor.totalOrders } : 
				vendor
		);
		closeEditModal();
	}

	function handleDeleteVendor(vendor) {
		if (confirm(`Are you sure you want to delete ${vendor.name}?`)) {
			vendors = vendors.filter(v => v.id !== vendor.id);
		}
	}

	function exportData() {
		alert('Export functionality will be implemented with actual data export');
	}

	function importData() {
		alert('Import functionality will be implemented with XLSX import');
	}
</script>

<div class="vendor-master">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">🤝 Vendor Master</h1>
			<p class="subtitle">Manage vendors and suppliers</p>
		</div>
		
		<div class="header-actions">
			<button class="btn btn-secondary" on:click={importData}>
				📥 Import
			</button>
			<button class="btn btn-secondary" on:click={exportData}>
				📤 Export
			</button>
			<button class="btn btn-primary" on:click={openAddModal}>
				➕ Add Vendor
			</button>
		</div>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="search-container">
			<input
				bind:value={searchQuery}
				type="text"
				placeholder="Search vendors..."
				class="search-input"
			/>
		</div>
		
		<select bind:value={selectedCategory} class="filter-select">
			<option value="">All Categories</option>
			{#each categories as category}
				<option value={category}>{category}</option>
			{/each}
		</select>
		
		<select bind:value={selectedStatus} class="filter-select">
			<option value="">All Statuses</option>
			{#each statuses as status}
				<option value={status}>{status}</option>
			{/each}
		</select>

		<div class="results-count">
			{filteredVendors.length} vendors found
		</div>
	</div>

	<!-- Stats Cards -->
	<div class="stats-grid">
		<div class="stat-card">
			<div class="stat-value">{vendors.filter(v => v.status === 'active').length}</div>
			<div class="stat-label">Active Vendors</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{categories.length}</div>
			<div class="stat-label">Categories</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{vendors.reduce((sum, v) => sum + v.totalOrders, 0)}</div>
			<div class="stat-label">Total Orders</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{vendors.filter(v => v.status === 'pending').length}</div>
			<div class="stat-label">Pending Approval</div>
		</div>
	</div>

	<!-- Vendor Table -->
	<div class="table-container">
		<table class="vendor-table">
			<thead>
				<tr>
					<th>Vendor ID</th>
					<th>Name</th>
					<th>Category</th>
					<th>Contact Person</th>
					<th>Email</th>
					<th>Payment Terms</th>
					<th>Total Orders</th>
					<th>Status</th>
					<th>Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each filteredVendors as vendor}
					<tr>
						<td class="vendor-id">{vendor.vendorId}</td>
						<td class="vendor-name">
							<div class="name-cell">
								<div class="avatar">{vendor.name.split(' ').map(w => w[0]).join('')}</div>
								<div>
									<div class="name">{vendor.name}</div>
									<div class="tax-id">Tax ID: {vendor.taxId}</div>
								</div>
							</div>
						</td>
						<td class="category">
							<span class="category-badge">{vendor.category}</span>
						</td>
						<td class="contact">
							<div>
								<div class="contact-name">{vendor.contactPerson}</div>
								<div class="contact-phone">{vendor.phone}</div>
							</div>
						</td>
						<td class="email">{vendor.email}</td>
						<td class="payment-terms">{vendor.paymentTerms}</td>
						<td class="total-orders">{vendor.totalOrders}</td>
						<td class="status">
							<span class="status-badge status-{vendor.status}">
								{vendor.status}
							</span>
						</td>
						<td class="actions">
							<button 
								class="action-btn edit-btn"
								on:click={() => openEditModal(vendor)}
								title="Edit Vendor"
							>
								✏️
							</button>
							<button 
								class="action-btn delete-btn"
								on:click={() => handleDeleteVendor(vendor)}
								title="Delete Vendor"
							>
								🗑️
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>

		{#if filteredVendors.length === 0}
			<div class="empty-state">
				<div class="empty-icon">🤝</div>
				<div class="empty-title">No vendors found</div>
				<div class="empty-subtitle">Try adjusting your search criteria</div>
			</div>
		{/if}
	</div>
</div>

<!-- Add Vendor Modal -->
{#if showAddModal}
	<div class="modal-backdrop" on:click={closeAddModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Add New Vendor</h2>
				<button class="modal-close" on:click={closeAddModal}>✕</button>
			</div>
			
			<form class="modal-body" on:submit|preventDefault={handleAddVendor}>
				<div class="form-row">
					<div class="form-group">
						<label>Vendor ID</label>
						<input bind:value={formData.vendorId} type="text" required />
					</div>
					<div class="form-group">
						<label>Status</label>
						<select bind:value={formData.status}>
							{#each statuses as status}
								<option value={status}>{status}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group full-width">
						<label>Company Name</label>
						<input bind:value={formData.name} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Category</label>
						<select bind:value={formData.category} required>
							<option value="">Select Category</option>
							{#each categories as category}
								<option value={category}>{category}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Tax ID</label>
						<input bind:value={formData.taxId} type="text" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Contact Person</label>
						<input bind:value={formData.contactPerson} type="text" required />
					</div>
					<div class="form-group">
						<label>Phone</label>
						<input bind:value={formData.phone} type="tel" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Email</label>
						<input bind:value={formData.email} type="email" required />
					</div>
					<div class="form-group">
						<label>Payment Terms</label>
						<select bind:value={formData.paymentTerms}>
							{#each paymentTermOptions as term}
								<option value={term}>{term}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group full-width">
						<label>Address</label>
						<textarea bind:value={formData.address} rows="2"></textarea>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Registration Date</label>
						<input bind:value={formData.registrationDate} type="date" required />
					</div>
				</div>

				<div class="modal-footer">
					<button type="button" class="btn btn-secondary" on:click={closeAddModal}>
						Cancel
					</button>
					<button type="submit" class="btn btn-primary">
						Add Vendor
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<!-- Edit Vendor Modal -->
{#if showEditModal}
	<div class="modal-backdrop" on:click={closeEditModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Edit Vendor</h2>
				<button class="modal-close" on:click={closeEditModal}>✕</button>
			</div>
			
			<form class="modal-body" on:submit|preventDefault={handleEditVendor}>
				<div class="form-row">
					<div class="form-group">
						<label>Vendor ID</label>
						<input bind:value={formData.vendorId} type="text" required readonly />
					</div>
					<div class="form-group">
						<label>Status</label>
						<select bind:value={formData.status}>
							{#each statuses as status}
								<option value={status}>{status}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group full-width">
						<label>Company Name</label>
						<input bind:value={formData.name} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Category</label>
						<select bind:value={formData.category} required>
							<option value="">Select Category</option>
							{#each categories as category}
								<option value={category}>{category}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Tax ID</label>
						<input bind:value={formData.taxId} type="text" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Contact Person</label>
						<input bind:value={formData.contactPerson} type="text" required />
					</div>
					<div class="form-group">
						<label>Phone</label>
						<input bind:value={formData.phone} type="tel" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Email</label>
						<input bind:value={formData.email} type="email" required />
					</div>
					<div class="form-group">
						<label>Payment Terms</label>
						<select bind:value={formData.paymentTerms}>
							{#each paymentTermOptions as term}
								<option value={term}>{term}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group full-width">
						<label>Address</label>
						<textarea bind:value={formData.address} rows="2"></textarea>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Registration Date</label>
						<input bind:value={formData.registrationDate} type="date" required />
					</div>
				</div>

				<div class="modal-footer">
					<button type="button" class="btn btn-secondary" on:click={closeEditModal}>
						Cancel
					</button>
					<button type="submit" class="btn btn-primary">
						Update Vendor
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	.vendor-master {
		padding: 24px;
		height: 100%;
		display: flex;
		flex-direction: column;
		gap: 24px;
		overflow: hidden;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		gap: 16px;
	}

	.title-section {
		flex: 1;
	}

	.title {
		font-size: 24px;
		font-weight: 700;
		margin: 0 0 4px 0;
		color: #1a1a1a;
	}

	.subtitle {
		font-size: 14px;
		color: #666;
		margin: 0;
	}

	.header-actions {
		display: flex;
		gap: 12px;
	}

	.btn {
		padding: 8px 16px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.btn-primary {
		background: #f08300;
		color: white;
	}

	.btn-primary:hover {
		background: #e07600;
	}

	.btn-secondary {
		background: #f5f5f5;
		color: #333;
		border: 1px solid #ddd;
	}

	.btn-secondary:hover {
		background: #e5e5e5;
	}

	.filters {
		display: flex;
		gap: 16px;
		align-items: center;
		padding: 16px;
		background: #f9f9f9;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
	}

	.search-container {
		flex: 1;
	}

	.search-input {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		min-width: 140px;
	}

	.results-count {
		font-size: 14px;
		color: #666;
		white-space: nowrap;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
	}

	.stat-card {
		background: white;
		padding: 20px;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
		text-align: center;
	}

	.stat-value {
		font-size: 32px;
		font-weight: 700;
		color: #f08300;
		margin-bottom: 4px;
	}

	.stat-label {
		font-size: 14px;
		color: #666;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
	}

	.vendor-table {
		width: 100%;
		border-collapse: collapse;
		min-width: 1000px;
	}

	.vendor-table th {
		background: #f5f5f5;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		font-size: 14px;
		color: #333;
		border-bottom: 1px solid #e0e0e0;
		white-space: nowrap;
	}

	.vendor-table td {
		padding: 12px;
		border-bottom: 1px solid #f0f0f0;
		font-size: 14px;
		vertical-align: middle;
	}

	.name-cell {
		display: flex;
		align-items: center;
		gap: 12px;
		min-width: 200px;
	}

	.avatar {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: #f08300;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 12px;
		flex-shrink: 0;
	}

	.name {
		font-weight: 500;
		color: #333;
	}

	.tax-id {
		font-size: 12px;
		color: #666;
		font-family: monospace;
	}

	.category-badge {
		background: #e8f5e8;
		color: #13A538;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.contact-name {
		font-weight: 500;
		color: #333;
	}

	.contact-phone {
		font-size: 12px;
		color: #666;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		text-transform: capitalize;
	}

	.status-active {
		background: #e8f5e8;
		color: #13A538;
	}

	.status-inactive {
		background: #f5e8e8;
		color: #d32f2f;
	}

	.status-pending {
		background: #fff3e0;
		color: #f08300;
	}

	.actions {
		display: flex;
		gap: 8px;
	}

	.action-btn {
		width: 32px;
		height: 32px;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.edit-btn {
		background: #fff3e0;
		color: #f08300;
	}

	.edit-btn:hover {
		background: #f08300;
		color: white;
	}

	.delete-btn {
		background: #f5e8e8;
		color: #d32f2f;
	}

	.delete-btn:hover {
		background: #d32f2f;
		color: white;
	}

	.empty-state {
		text-align: center;
		padding: 48px 24px;
		color: #666;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-title {
		font-size: 18px;
		font-weight: 500;
		margin-bottom: 8px;
	}

	.empty-subtitle {
		font-size: 14px;
	}

	/* Modal Styles */
	.modal-backdrop {
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

	.modal {
		background: white;
		border-radius: 8px;
		max-width: 700px;
		width: 90%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e0e0e0;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 18px;
		cursor: pointer;
		color: #666;
		padding: 4px;
	}

	.modal-body {
		padding: 24px;
		overflow-y: auto;
		flex: 1;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 16px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.form-group.full-width {
		grid-column: 1 / -1;
	}

	.form-group label {
		font-size: 14px;
		font-weight: 500;
		color: #333;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #f08300;
	}

	.form-group input[readonly] {
		background: #f5f5f5;
		color: #666;
	}

	.form-group textarea {
		resize: vertical;
		min-height: 60px;
	}

	.modal-footer {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		margin-top: 24px;
		padding-top: 16px;
		border-top: 1px solid #e0e0e0;
	}
</style>
