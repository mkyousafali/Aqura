<script lang="ts">
	import { onMount } from 'svelte';
	import { localeData, t } from '$lib/i18n';

	// Mock data for demonstration
	let branches = [
		{
			id: '1',
			branchId: 'BR001',
			name: 'Riyadh Headquarters',
			code: 'RUH-HQ',
			region: 'Central',
			address: 'King Fahd Road, Olaya District, Riyadh 11564',
			timezone: 'Asia/Riyadh',
			contactPerson: 'Mohammed Al-Rashid',
			contactEmail: 'mohammed.rashid@aqura.com',
			contactPhone: '+966 11 234 5678',
			managerName: 'Ahmed Al-Rahman',
			status: 'active',
			openingDate: '2020-01-15',
			employeeCount: 45
		},
		{
			id: '2',
			branchId: 'BR002',
			name: 'Jeddah Commercial Center',
			code: 'JED-CC',
			region: 'Western',
			address: 'Tahlia Street, Jeddah 21451',
			timezone: 'Asia/Riyadh',
			contactPerson: 'Fatima Mohammed',
			contactEmail: 'fatima.mohammed@aqura.com',
			contactPhone: '+966 12 987 6543',
			managerName: 'Omar Hassan',
			status: 'active',
			openingDate: '2021-06-01',
			employeeCount: 32
		},
		{
			id: '3',
			branchId: 'BR003',
			name: 'Dammam Operations',
			code: 'DMM-OP',
			region: 'Eastern',
			address: 'Al Khobar Corniche, Dammam 31952',
			timezone: 'Asia/Riyadh',
			contactPerson: 'Abdullah Al-Qahtani',
			contactEmail: 'abdullah.qahtani@aqura.com',
			contactPhone: '+966 13 555 1234',
			managerName: 'Sarah Al-Zahrani',
			status: 'inactive',
			openingDate: '2022-03-20',
			employeeCount: 18
		}
	];

	let searchQuery = '';
	let selectedRegion = '';
	let selectedStatus = '';
	let showAddModal = false;
	let showEditModal = false;
	let selectedBranch = null;

	// Form data
	let formData = {
		branchId: '',
		name: '',
		code: '',
		region: '',
		address: '',
		timezone: 'Asia/Riyadh',
		contactPerson: '',
		contactEmail: '',
		contactPhone: '',
		managerName: '',
		status: 'active',
		openingDate: ''
	};

	const regions = ['Central', 'Western', 'Eastern', 'Northern', 'Southern'];
	const statuses = ['active', 'inactive', 'pending'];
	const timezones = ['Asia/Riyadh', 'Asia/Qatar', 'Asia/Kuwait'];

	$: filteredBranches = branches.filter(branch => {
		const matchesSearch = searchQuery === '' || 
			branch.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
			branch.code.toLowerCase().includes(searchQuery.toLowerCase()) ||
			branch.branchId.toLowerCase().includes(searchQuery.toLowerCase()) ||
			branch.address.toLowerCase().includes(searchQuery.toLowerCase());
		
		const matchesRegion = selectedRegion === '' || branch.region === selectedRegion;
		const matchesStatus = selectedStatus === '' || branch.status === selectedStatus;
		
		return matchesSearch && matchesRegion && matchesStatus;
	});

	function resetForm() {
		formData = {
			branchId: '',
			name: '',
			code: '',
			region: '',
			address: '',
			timezone: 'Asia/Riyadh',
			contactPerson: '',
			contactEmail: '',
			contactPhone: '',
			managerName: '',
			status: 'active',
			openingDate: ''
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

	function openEditModal(branch) {
		selectedBranch = branch;
		formData = { ...branch };
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		selectedBranch = null;
		resetForm();
	}

	function handleAddBranch() {
		const newBranch = {
			...formData,
			id: (branches.length + 1).toString(),
			employeeCount: 0
		};
		branches = [...branches, newBranch];
		closeAddModal();
	}

	function handleEditBranch() {
		branches = branches.map(branch => 
			branch.id === selectedBranch.id ? 
				{ ...formData, id: selectedBranch.id, employeeCount: selectedBranch.employeeCount } : 
				branch
		);
		closeEditModal();
	}

	function handleDeleteBranch(branch) {
		if (confirm(`Are you sure you want to delete ${branch.name}?`)) {
			branches = branches.filter(b => b.id !== branch.id);
		}
	}

	function exportData() {
		alert('Export functionality will be implemented with actual data export');
	}

	function importData() {
		alert('Import functionality will be implemented with XLSX import');
	}
</script>

<div class="branch-master">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">🏢 Branch Master</h1>
			<p class="subtitle">Manage company branches and locations</p>
		</div>
		
		<div class="header-actions">
			<button class="btn btn-secondary" on:click={importData}>
				📥 Import
			</button>
			<button class="btn btn-secondary" on:click={exportData}>
				📤 Export
			</button>
			<button class="btn btn-primary" on:click={openAddModal}>
				➕ Add Branch
			</button>
		</div>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="search-container">
			<input
				bind:value={searchQuery}
				type="text"
				placeholder="Search branches..."
				class="search-input"
			/>
		</div>
		
		<select bind:value={selectedRegion} class="filter-select">
			<option value="">All Regions</option>
			{#each regions as region}
				<option value={region}>{region}</option>
			{/each}
		</select>
		
		<select bind:value={selectedStatus} class="filter-select">
			<option value="">All Statuses</option>
			{#each statuses as status}
				<option value={status}>{status}</option>
			{/each}
		</select>

		<div class="results-count">
			{filteredBranches.length} branches found
		</div>
	</div>

	<!-- Stats Cards -->
	<div class="stats-grid">
		<div class="stat-card">
			<div class="stat-value">{branches.filter(b => b.status === 'active').length}</div>
			<div class="stat-label">Active Branches</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{regions.length}</div>
			<div class="stat-label">Regions</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{branches.reduce((sum, b) => sum + b.employeeCount, 0)}</div>
			<div class="stat-label">Total Employees</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{branches.filter(b => b.status === 'pending').length}</div>
			<div class="stat-label">Pending Setup</div>
		</div>
	</div>

	<!-- Branch Cards -->
	<div class="branch-grid">
		{#each filteredBranches as branch}
			<div class="branch-card">
				<div class="branch-header">
					<div class="branch-info">
						<h3 class="branch-name">{branch.name}</h3>
						<div class="branch-code">{branch.code}</div>
					</div>
					<span class="status-badge status-{branch.status}">
						{branch.status}
					</span>
				</div>

				<div class="branch-details">
					<div class="detail-row">
						<span class="detail-label">Region:</span>
						<span class="detail-value">{branch.region}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Manager:</span>
						<span class="detail-value">{branch.managerName}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Employees:</span>
						<span class="detail-value">{branch.employeeCount}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Contact:</span>
						<span class="detail-value">{branch.contactPerson}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Phone:</span>
						<span class="detail-value">{branch.contactPhone}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Email:</span>
						<span class="detail-value">{branch.contactEmail}</span>
					</div>
				</div>

				<div class="branch-address">
					📍 {branch.address}
				</div>

				<div class="branch-actions">
					<button 
						class="action-btn edit-btn"
						on:click={() => openEditModal(branch)}
					>
						✏️ Edit
					</button>
					<button 
						class="action-btn delete-btn"
						on:click={() => handleDeleteBranch(branch)}
					>
						🗑️ Delete
					</button>
				</div>
			</div>
		{/each}
	</div>

	{#if filteredBranches.length === 0}
		<div class="empty-state">
			<div class="empty-icon">🏢</div>
			<div class="empty-title">No branches found</div>
			<div class="empty-subtitle">Try adjusting your search criteria</div>
		</div>
	{/if}
</div>

<!-- Add Branch Modal -->
{#if showAddModal}
	<div class="modal-backdrop" on:click={closeAddModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Add New Branch</h2>
				<button class="modal-close" on:click={closeAddModal}>✕</button>
			</div>
			
			<form class="modal-body" on:submit|preventDefault={handleAddBranch}>
				<div class="form-row">
					<div class="form-group">
						<label>Branch ID</label>
						<input bind:value={formData.branchId} type="text" required />
					</div>
					<div class="form-group">
						<label>Branch Code</label>
						<input bind:value={formData.code} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group full-width">
						<label>Branch Name</label>
						<input bind:value={formData.name} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Region</label>
						<select bind:value={formData.region} required>
							<option value="">Select Region</option>
							{#each regions as region}
								<option value={region}>{region}</option>
							{/each}
						</select>
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
						<label>Address</label>
						<textarea bind:value={formData.address} rows="2" required></textarea>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Contact Person</label>
						<input bind:value={formData.contactPerson} type="text" required />
					</div>
					<div class="form-group">
						<label>Manager Name</label>
						<input bind:value={formData.managerName} type="text" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Contact Email</label>
						<input bind:value={formData.contactEmail} type="email" required />
					</div>
					<div class="form-group">
						<label>Contact Phone</label>
						<input bind:value={formData.contactPhone} type="tel" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Timezone</label>
						<select bind:value={formData.timezone}>
							{#each timezones as tz}
								<option value={tz}>{tz}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Opening Date</label>
						<input bind:value={formData.openingDate} type="date" required />
					</div>
				</div>

				<div class="modal-footer">
					<button type="button" class="btn btn-secondary" on:click={closeAddModal}>
						Cancel
					</button>
					<button type="submit" class="btn btn-primary">
						Add Branch
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<!-- Edit Branch Modal -->
{#if showEditModal}
	<div class="modal-backdrop" on:click={closeEditModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Edit Branch</h2>
				<button class="modal-close" on:click={closeEditModal}>✕</button>
			</div>
			
			<form class="modal-body" on:submit|preventDefault={handleEditBranch}>
				<div class="form-row">
					<div class="form-group">
						<label>Branch ID</label>
						<input bind:value={formData.branchId} type="text" required readonly />
					</div>
					<div class="form-group">
						<label>Branch Code</label>
						<input bind:value={formData.code} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group full-width">
						<label>Branch Name</label>
						<input bind:value={formData.name} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Region</label>
						<select bind:value={formData.region} required>
							<option value="">Select Region</option>
							{#each regions as region}
								<option value={region}>{region}</option>
							{/each}
						</select>
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
						<label>Address</label>
						<textarea bind:value={formData.address} rows="2" required></textarea>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Contact Person</label>
						<input bind:value={formData.contactPerson} type="text" required />
					</div>
					<div class="form-group">
						<label>Manager Name</label>
						<input bind:value={formData.managerName} type="text" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Contact Email</label>
						<input bind:value={formData.contactEmail} type="email" required />
					</div>
					<div class="form-group">
						<label>Contact Phone</label>
						<input bind:value={formData.contactPhone} type="tel" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Timezone</label>
						<select bind:value={formData.timezone}>
							{#each timezones as tz}
								<option value={tz}>{tz}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Opening Date</label>
						<input bind:value={formData.openingDate} type="date" required />
					</div>
				</div>

				<div class="modal-footer">
					<button type="button" class="btn btn-secondary" on:click={closeEditModal}>
						Cancel
					</button>
					<button type="submit" class="btn btn-primary">
						Update Branch
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	.branch-master {
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

	.branch-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
		gap: 20px;
		overflow-y: auto;
		flex: 1;
	}

	.branch-card {
		background: white;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
		padding: 20px;
		display: flex;
		flex-direction: column;
		gap: 16px;
		transition: all 0.2s;
	}

	.branch-card:hover {
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.branch-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		gap: 12px;
	}

	.branch-info {
		flex: 1;
	}

	.branch-name {
		font-size: 18px;
		font-weight: 600;
		margin: 0 0 4px 0;
		color: #333;
	}

	.branch-code {
		font-size: 14px;
		color: #666;
		font-family: monospace;
		background: #f5f5f5;
		padding: 2px 6px;
		border-radius: 4px;
		display: inline-block;
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

	.branch-details {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
	}

	.detail-label {
		font-size: 14px;
		color: #666;
		font-weight: 500;
		min-width: 80px;
	}

	.detail-value {
		font-size: 14px;
		color: #333;
		text-align: right;
	}

	.branch-address {
		background: #f9f9f9;
		padding: 12px;
		border-radius: 6px;
		font-size: 14px;
		color: #666;
		line-height: 1.4;
	}

	.branch-actions {
		display: flex;
		gap: 8px;
		margin-top: auto;
	}

	.action-btn {
		flex: 1;
		padding: 8px 12px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
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
		grid-column: 1 / -1;
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
