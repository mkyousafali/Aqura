<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import EditVendor from './EditVendor.svelte';

	// State management
	let totalVendors = 0;
	let vendors = [];
	let filteredVendors = [];
	let searchQuery = '';
	let isLoading = true;
	let error = null;

	// Branch filtering
	let branches = [];
	let selectedBranch = '';
	let loadingBranches = false;
	let branchFilterMode = 'all'; // 'all', 'branch', 'unassigned'

	// Column visibility management
	let showColumnSelector = false;
	let visibleColumns = {
		erp_vendor_id: true,
		vendor_name: true,
		branch_name: true, // Add branch column
		salesman_name: true,
		salesman_contact: false,
		supervisor_name: false,
		supervisor_contact: false,
		vendor_contact: true,
		payment_method: true,
		payment_priority: true,
		credit_period: false,
		bank_name: false,
		iban: false,
		last_visit: false,
		place: true,
		location: true,
		categories: true,
		delivery_modes: true,
		return_expired: false,
		return_near_expiry: false,
		return_over_stock: false,
		return_damage: false,
		no_return: false,
		vat_status: false,
		vat_number: false,
		status: true,
		actions: true
	};

	// Column definitions
	const columnDefinitions = [
		{ key: 'erp_vendor_id', label: 'ERP Vendor ID' },
		{ key: 'vendor_name', label: 'Vendor Name' },
		{ key: 'branch_name', label: 'Branch' },
		{ key: 'salesman_name', label: 'Salesman Name' },
		{ key: 'salesman_contact', label: 'Salesman Contact' },
		{ key: 'supervisor_name', label: 'Supervisor Name' },
		{ key: 'supervisor_contact', label: 'Supervisor Contact' },
		{ key: 'vendor_contact', label: 'Vendor Contact' },
		{ key: 'payment_method', label: 'Payment Method' },
		{ key: 'payment_priority', label: 'Payment Priority' },
		{ key: 'credit_period', label: 'Credit Period' },
		{ key: 'bank_name', label: 'Bank Name' },
		{ key: 'iban', label: 'IBAN' },
		{ key: 'last_visit', label: 'Last Visit' },
		{ key: 'place', label: 'Place' },
		{ key: 'location', label: 'Location' },
		{ key: 'categories', label: 'Categories' },
		{ key: 'delivery_modes', label: 'Delivery Modes' },
		{ key: 'return_expired', label: 'Return Expired' },
		{ key: 'return_near_expiry', label: 'Return Near Expiry' },
		{ key: 'return_over_stock', label: 'Return Over Stock' },
		{ key: 'return_damage', label: 'Return Damage' },
		{ key: 'no_return', label: 'No Return' },
		{ key: 'vat_status', label: 'VAT Status' },
		{ key: 'vat_number', label: 'VAT Number' },
		{ key: 'status', label: 'Status' },
		{ key: 'actions', label: 'Actions' }
	];

	// Load vendor data on component mount
	// Reactive statements
	$: if (branchFilterMode === 'all') {
		selectedBranch = null;
		loadVendors();
	} else if (branchFilterMode === 'unassigned') {
		selectedBranch = null;
		loadVendors();
	} else if (branchFilterMode === 'branch') {
		// Reset vendors when switching to branch mode
		if (!selectedBranch) {
			vendors = [];
			filteredVendors = [];
			totalVendors = 0;
		} else {
			loadVendors();
		}
	}

	// Load vendors when branch selection changes (only for branch mode)
	$: if (branchFilterMode === 'branch' && selectedBranch) {
		loadVendors();
	}

	onMount(async () => {
		await loadBranches();
		await loadVendors();
	});

	// Load branches from database
	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		} finally {
			loadingBranches = false;
		}
	}

	// Load vendors from database
	async function loadVendors() {
		try {
			isLoading = true;
			error = null;

			// If "By Branch" is selected but no branch is chosen, don't load vendors
			if (branchFilterMode === 'branch' && !selectedBranch) {
				vendors = [];
				filteredVendors = [];
				totalVendors = 0;
				isLoading = false;
				return;
			}

			// First get the total count
			let countQuery = supabase
				.from('vendors')
				.select('*', { count: 'exact', head: true });

			// Apply branch filtering for count
			if (branchFilterMode === 'branch' && selectedBranch) {
				countQuery = countQuery.eq('branch_id', selectedBranch);
			} else if (branchFilterMode === 'unassigned') {
				countQuery = countQuery.is('branch_id', null);
			}

			const { count, error: countError } = await countQuery;
			if (countError) throw countError;

			const totalCount = count || 0;
			totalVendors = totalCount;
			console.log('Total vendor count:', totalCount);

			// Fetch ALL vendors using pagination to bypass Supabase 1000 record limit
			let allVendors = [];
			const pageSize = 1000;
			let currentPage = 0;
			let hasMore = true;

			while (hasMore) {
				const startRange = currentPage * pageSize;
				const endRange = startRange + pageSize - 1;

				let query = supabase
					.from('vendors')
					.select('*, branches(name_en)')
					.order('erp_vendor_id', { ascending: true })
					.range(startRange, endRange);

				// Apply branch filtering
				if (branchFilterMode === 'branch' && selectedBranch) {
					query = query.eq('branch_id', selectedBranch);
				} else if (branchFilterMode === 'unassigned') {
					query = query.is('branch_id', null);
				}

				const { data, error: fetchError } = await query;
				if (fetchError) throw fetchError;

				if (data && data.length > 0) {
					allVendors = [...allVendors, ...data];
					currentPage++;
					hasMore = data.length === pageSize; // Continue if we got a full page
					console.log(`Loaded page ${currentPage}, total vendors so far: ${allVendors.length}`);
				} else {
					hasMore = false;
				}
			}

			vendors = allVendors;
			filteredVendors = vendors;

			console.log(`Successfully loaded ${vendors.length} vendors out of ${totalVendors} total`);



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
				(vendor.place && vendor.place.toLowerCase().includes(query)) ||
				(vendor.location_link && vendor.location_link.toLowerCase().includes(query)) ||
				(vendor.categories && vendor.categories.some(cat => cat.toLowerCase().includes(query))) ||
				(vendor.delivery_modes && vendor.delivery_modes.some(mode => mode.toLowerCase().includes(query)))
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
		
		openWindow({
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
				onSave: async (updatedVendor) => {
					console.log('Vendor updated:', updatedVendor);
					try {
						// Update local vendor data with proper reactivity using both erp_vendor_id and branch_id
						const index = vendors.findIndex(v => 
							v.erp_vendor_id === updatedVendor.erp_vendor_id && 
							v.branch_id === vendor.branch_id // Use original branch_id to find the vendor
						);
						if (index !== -1) {
							vendors[index] = { ...updatedVendor };
							vendors = [...vendors]; // Trigger reactivity
							console.log('Vendor updated in local array:', vendors[index]);
							handleSearch(); // Refresh filtered data
						} else {
							console.warn('Vendor not found in local array for update');
							// Reload all vendors as fallback
							await loadVendors();
						}
						// Close the edit window
						windowManager.closeWindow(windowId);
						alert('Vendor updated successfully!');
					} catch (error) {
						console.error('Error updating vendor in UI:', error);
						alert('Vendor updated but there was an issue refreshing the display.');
					}
				},
				onCancel: () => {
					// Close the edit window
					windowManager.closeWindow(windowId);
				}
			}
		});
	}

	// Open create vendor window
	function openCreateVendor() {
		const windowId = generateWindowId();
		
		openWindow({
			id: windowId,
			title: 'Create New Vendor',
			component: EditVendor,
			icon: '➕',
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
				vendor: {
					// Initialize with empty vendor object with mandatory fields
					erp_vendor_id: '',
					vendor_name: '',
					// All other fields optional - set defaults
					salesman_name: '',
					salesman_contact: '',
					supervisor_name: '',
					supervisor_contact: '',
					vendor_contact: '',
					payment_method: '',
					credit_period: '',
					bank_name: '',
					iban: '',
					last_visit: '',
					place: '',
					location: '',
					categories: [],
					delivery_modes: [],
					status: 'Active',
					// Return policy defaults
					return_expired_products: '',
					return_expired_note: '',
					return_near_expiry_products: '',
					return_near_expiry_note: '',
					return_over_stock: '',
					return_over_stock_note: '',
					return_damage_products: '',
					return_damage_note: '',
					no_return: false,
					// VAT defaults
					vat_applicable: 'VAT Applicable',
					vat_number: '',
					no_vat_note: ''
				},
				isCreating: true, // Flag to indicate creation mode
				onSave: (newVendor) => {
					// Add new vendor to local data
					vendors = [...vendors, newVendor];
					totalVendors++;
					handleSearch(); // Refresh filtered data
					// Close the create window
					windowManager.closeWindow(windowId);
					alert('Vendor created successfully!');
				},
				onCancel: () => {
					// Close the create window
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

	// Share location function
	async function shareLocation(locationLink, vendorName) {
		try {
			// Check if Web Share API is supported
			if (navigator.share) {
				await navigator.share({
					title: `${vendorName} Location`,
					text: `Location for vendor: ${vendorName}`,
					url: locationLink
				});
			} else {
				// Fallback: Copy to clipboard
				await navigator.clipboard.writeText(locationLink);
				alert(`Location link copied to clipboard!\n\nVendor: ${vendorName}\nLocation: ${locationLink}`);
			}
		} catch (error) {
			// Manual fallback if clipboard fails
			try {
				await navigator.clipboard.writeText(locationLink);
				alert(`Location link copied to clipboard!\n\nVendor: ${vendorName}\nLocation: ${locationLink}`);
			} catch (clipboardError) {
				// Ultimate fallback - show link in a prompt
				prompt(`Copy this location link:\n\nVendor: ${vendorName}`, locationLink);
			}
		}
	}

	// Toggle column visibility
	function toggleColumn(columnKey) {
		visibleColumns[columnKey] = !visibleColumns[columnKey];
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}

	// Show/hide all columns
	function toggleAllColumns(show) {
		for (let key in visibleColumns) {
			if (key !== 'vendor_name' && key !== 'actions') { // Always keep vendor name and actions
				visibleColumns[key] = show;
			}
		}
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
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
		<div class="vendor-card-minimal">
			<div class="header-buttons-minimal">
				<button class="create-btn-small" on:click={openCreateVendor}>
					➕ Create Vendor
				</button>
				<button class="refresh-btn-small" on:click={refreshData} disabled={isLoading}>
					🔄 Refresh
				</button>
			</div>
		</div>
	</div>

	<!-- Branch Filter Section -->
	<div class="filter-section">
		<div class="branch-filter">
			<h4>🏢 Filter by Branch</h4>
			<div class="filter-controls">
				<div class="filter-options">
					<label class="filter-option">
						<input 
							type="radio" 
							bind:group={branchFilterMode} 
							value="all"
						/>
						<span class="option-text">All Vendors ({totalVendors})</span>
					</label>
					
					<label class="filter-option">
						<input 
							type="radio" 
							bind:group={branchFilterMode} 
							value="branch"
						/>
						<span class="option-text">By Branch</span>
					</label>
					
					<label class="filter-option">
						<input 
							type="radio" 
							bind:group={branchFilterMode} 
							value="unassigned"
						/>
						<span class="option-text">Unassigned Vendors</span>
					</label>
				</div>
				
				{#if branchFilterMode === 'branch'}
					<div class="branch-selector">
						{#if loadingBranches}
							<div class="loading-state">Loading branches...</div>
						{:else}
							<select bind:value={selectedBranch} class="branch-select">
								<option value="">Choose a branch...</option>
								{#each branches as branch}
									<option value={branch.id}>
										{branch.name_en} ({branch.name_ar}) - {branch.location_en}
									</option>
								{/each}
							</select>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	</div>

	<!-- Search Section -->
	<div class="search-section">
		<div class="search-bar">
			<div class="search-input-wrapper">
				<span class="search-icon">🔍</span>
				<input 
					type="text" 
					placeholder="Search by ERP ID, vendor name, place, location, categories, delivery modes..."
					bind:value={searchQuery}
					class="search-input"
				/>
				{#if searchQuery}
					<button class="clear-search" on:click={() => searchQuery = ''}>×</button>
				{/if}
			</div>
		</div>
		<div class="search-results">
			{#if branchFilterMode === 'branch' && !selectedBranch}
				<span class="branch-selection-hint">Please select a branch to view vendors</span>
			{:else}
				Showing {filteredVendors.length} of {totalVendors} vendors
			{/if}
		</div>
	</div>

	<!-- Column Selector -->
	<div class="column-selector-section">
		<div class="column-selector">
			<button class="column-selector-btn" on:click={() => showColumnSelector = !showColumnSelector}>
				🏷️ Show/Hide Columns
				<span class="dropdown-arrow">{showColumnSelector ? '▲' : '▼'}</span>
			</button>
			
			{#if showColumnSelector}
				<div class="column-dropdown">
					<div class="column-controls">
						<button class="control-btn" on:click={() => toggleAllColumns(true)}>✅ Show All</button>
						<button class="control-btn" on:click={() => toggleAllColumns(false)}>❌ Hide All</button>
					</div>
					<div class="column-list">
						{#each columnDefinitions as column}
							<label class="column-item">
								<input 
									type="checkbox" 
									checked={visibleColumns[column.key]} 
									on:change={() => toggleColumn(column.key)}
								/>
								<span class="column-label">{column.label}</span>
							</label>
						{/each}
					</div>
				</div>
			{/if}
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
							{#if visibleColumns.erp_vendor_id}<th>ERP Vendor ID</th>{/if}
							{#if visibleColumns.vendor_name}<th>Vendor Name</th>{/if}
							{#if visibleColumns.branch_name}<th>Branch</th>{/if}
							{#if visibleColumns.salesman_name}<th>Salesman Name</th>{/if}
							{#if visibleColumns.salesman_contact}<th>Salesman Contact</th>{/if}
							{#if visibleColumns.supervisor_name}<th>Supervisor Name</th>{/if}
							{#if visibleColumns.supervisor_contact}<th>Supervisor Contact</th>{/if}
							{#if visibleColumns.vendor_contact}<th>Vendor Contact</th>{/if}
							{#if visibleColumns.payment_method}<th>Payment Method</th>{/if}
							{#if visibleColumns.payment_priority}<th>Payment Priority</th>{/if}
							{#if visibleColumns.credit_period}<th>Credit Period</th>{/if}
							{#if visibleColumns.bank_name}<th>Bank Name</th>{/if}
							{#if visibleColumns.iban}<th>IBAN</th>{/if}
							{#if visibleColumns.last_visit}<th>Last Visit</th>{/if}
							{#if visibleColumns.place}<th>Place</th>{/if}
							{#if visibleColumns.location}<th>Location</th>{/if}
							{#if visibleColumns.categories}<th>Categories</th>{/if}
							{#if visibleColumns.delivery_modes}<th>Delivery Modes</th>{/if}
							{#if visibleColumns.status}<th>Status</th>{/if}
							{#if visibleColumns.actions}<th>Actions</th>{/if}
						</tr>
					</thead>
					<tbody>
						{#each filteredVendors as vendor}
							<tr>
								{#if visibleColumns.erp_vendor_id}
									<td class="vendor-id">{vendor.erp_vendor_id}</td>
								{/if}
								{#if visibleColumns.vendor_name}
									<td class="vendor-name">{vendor.vendor_name}</td>
								{/if}
								{#if visibleColumns.branch_name}
									<td class="branch-name">
										{#if vendor.branches?.name_en}
											<span class="branch-assigned">{vendor.branches.name_en}</span>
										{:else}
											<span class="branch-unassigned">Unassigned</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.salesman_name}
									<td class="vendor-data">
										{#if vendor.salesman_name}
											{vendor.salesman_name}
										{:else}
											<span class="no-data">No salesman</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.salesman_contact}
									<td class="vendor-data">
										{#if vendor.salesman_contact}
											{vendor.salesman_contact}
										{:else}
											<span class="no-data">No contact</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.supervisor_name}
									<td class="vendor-data">
										{#if vendor.supervisor_name}
											{vendor.supervisor_name}
										{:else}
											<span class="no-data">No supervisor</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.supervisor_contact}
									<td class="vendor-data">
										{#if vendor.supervisor_contact}
											{vendor.supervisor_contact}
										{:else}
											<span class="no-data">No contact</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.vendor_contact}
									<td class="vendor-data">
										{#if vendor.vendor_contact_number}
											{vendor.vendor_contact_number}
										{:else}
											<span class="no-data">No contact</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.payment_method}
									<td class="payment-method">
										{#if vendor.payment_method}
											{#if vendor.payment_method.includes(',')}
												<!-- Multiple payment methods -->
												<div class="payment-methods-list">
													{#each vendor.payment_method.split(',').map(m => m.trim()) as method}
														<span class="payment-method-tag">{method}</span>
													{/each}
												</div>
											{:else}
												<!-- Single payment method -->
												{vendor.payment_method}
											{/if}
										{:else}
											<span class="no-data">No method</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.payment_priority}
									<td class="payment-priority">
										{#if vendor.payment_priority}
											<span class="priority-badge priority-{vendor.payment_priority.toLowerCase()}">
												{vendor.payment_priority}
											</span>
										{:else}
											<span class="priority-badge priority-normal">Normal</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.credit_period}
									<td class="credit-period">
										{#if vendor.payment_method && (vendor.payment_method.includes('Cash Credit') || vendor.payment_method.includes('Bank Credit')) && vendor.credit_period}
											{vendor.credit_period} days
										{:else}
											<span class="no-data">No credit period</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.bank_name}
									<td class="bank-info">
										{#if vendor.payment_method && (vendor.payment_method.includes('Bank on Delivery') || vendor.payment_method.includes('Bank Credit')) && vendor.bank_name}
											{vendor.bank_name}
										{:else}
											<span class="no-data">No bank</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.iban}
									<td class="bank-info">
										{#if vendor.payment_method && (vendor.payment_method.includes('Bank on Delivery') || vendor.payment_method.includes('Bank Credit')) && vendor.iban}
											{vendor.iban}
										{:else}
											<span class="no-data">No IBAN</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.last_visit}
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
											<span class="no-visit">Never visited</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.place}
									<td class="vendor-place">
										{#if vendor.place}
											<span class="place-text">📍 {vendor.place}</span>
										{:else}
											<span class="no-place">No place</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.location}
									<td class="vendor-location">
										{#if vendor.location_link}
											<div class="location-actions">
												<a 
													href={vendor.location_link} 
													target="_blank" 
													rel="noopener noreferrer"
													class="location-link"
												>
													🗺️ Open Map
												</a>
												<button 
													class="share-location-btn"
													on:click={() => shareLocation(vendor.location_link, vendor.vendor_name)}
													title="Share Location"
												>
													📤 Share
												</button>
											</div>
										{:else}
											<span class="no-location">No location</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.categories}
									<td class="vendor-categories">
										{#if vendor.categories && vendor.categories.length > 0}
											<div class="category-badges">
												{#each vendor.categories as category}
													<span class="category-badge">{category}</span>
												{/each}
											</div>
										{:else}
											<span class="no-categories">No categories</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.delivery_modes}
									<td class="vendor-delivery-modes">
										{#if vendor.delivery_modes && vendor.delivery_modes.length > 0}
											<div class="delivery-mode-badges">
												{#each vendor.delivery_modes as mode}
													<span class="delivery-mode-badge">{mode}</span>
												{/each}
											</div>
										{:else}
											<span class="no-delivery-modes">No delivery modes</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_expired}
									<td class="return-policy-cell">
										{#if vendor.return_expired_products}
											<span class="return-policy-badge {vendor.return_expired_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_expired_products}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_near_expiry}
									<td class="return-policy-cell">
										{#if vendor.return_near_expiry_products}
											<span class="return-policy-badge {vendor.return_near_expiry_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_near_expiry_products}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_over_stock}
									<td class="return-policy-cell">
										{#if vendor.return_over_stock}
											<span class="return-policy-badge {vendor.return_over_stock === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_over_stock}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_damage}
									<td class="return-policy-cell">
										{#if vendor.return_damage_products}
											<span class="return-policy-badge {vendor.return_damage_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_damage_products}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.no_return}
									<td class="return-policy-cell">
										{#if vendor.no_return}
											<span class="return-policy-badge no-return-badge">🚫 No Returns</span>
										{:else}
											<span class="return-policy-badge returns-accepted">✅ Returns OK</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.vat_status}
									<td class="vat-cell">
										{#if vendor.vat_applicable}
											<span class="vat-badge {vendor.vat_applicable === 'VAT Applicable' ? 'vat-applicable' : 'no-vat'}">
												{vendor.vat_applicable === 'VAT Applicable' ? '💰 VAT Applicable' : '🚫 No VAT'}
											</span>
										{:else}
											<span class="no-vat-info">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.vat_number}
									<td class="vat-number-cell">
										{#if vendor.vat_applicable === 'VAT Applicable' && vendor.vat_number}
											<span class="vat-number">{vendor.vat_number}</span>
										{:else if vendor.vat_applicable === 'No VAT' && vendor.no_vat_note}
											<span class="no-vat-note" title={vendor.no_vat_note}>📝 Note available</span>
										{:else}
											<span class="no-vat-info">-</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.status}
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
								{/if}
								{#if visibleColumns.actions}
									<td class="action-buttons">
										<button class="edit-btn" on:click={() => openEditWindow(vendor)}>✏️ Edit</button>
									</td>
								{/if}
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
		height: 100vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
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

	.header-buttons {
		display: flex;
		gap: 0.75rem;
		align-items: center;
	}

	/* Minimal vendor card styles */
	.vendor-card-minimal {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		padding: 1rem;
		border-radius: 8px;
		display: flex;
		justify-content: center;
		max-width: 400px;
		margin: 0 auto;
	}

	.header-buttons-minimal {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.create-btn-small {
		background: #10b981;
		color: white;
		border: 1px solid #059669;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
		font-size: 0.875rem;
	}

	.create-btn-small:hover {
		background: #059669;
		transform: translateY(-1px);
	}

	.refresh-btn-small {
		background: #6b7280;
		color: white;
		border: 1px solid #4b5563;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
		font-size: 0.875rem;
	}

	.refresh-btn-small:hover:not(:disabled) {
		background: #4b5563;
		transform: translateY(-1px);
	}

	.refresh-btn-small:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		transform: none;
	}

	.create-btn {
		background: #10b981;
		color: white;
		border: 1px solid #059669;
		padding: 0.75rem 1.25rem;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
	}

	.create-btn:hover {
		background: #059669;
		transform: translateY(-1px);
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

	/* Filter Section */
	.filter-section {
		margin-bottom: 2rem;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
	}

	.branch-filter h4 {
		margin: 0 0 1rem 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.filter-controls {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.filter-options {
		display: flex;
		gap: 2rem;
		flex-wrap: wrap;
	}

	.filter-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: 500;
		color: #475569;
	}

	.filter-option input[type="radio"] {
		margin: 0;
		transform: scale(1.2);
	}

	.option-text {
		font-size: 0.95rem;
	}

	.branch-selector {
		margin-top: 0.5rem;
	}

	.branch-select {
		padding: 0.75rem 1rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 1rem;
		background: white;
		color: #1e293b;
		min-width: 300px;
		cursor: pointer;
	}

	.branch-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.loading-state {
		padding: 0.75rem 1rem;
		color: #64748b;
		font-style: italic;
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

	/* Column Selector */
	.column-selector-section {
		margin-bottom: 1rem;
		display: flex;
		justify-content: center;
	}

	.column-selector {
		position: relative;
		display: inline-block;
	}

	.column-selector-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.25rem;
		border-radius: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.column-selector-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.dropdown-arrow {
		font-size: 0.8rem;
		transition: transform 0.2s;
	}

	.column-dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
		z-index: 1000;
		min-width: 280px;
		max-height: 400px;
		overflow-y: auto;
		margin-top: 0.5rem;
	}

	.column-controls {
		padding: 1rem;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		gap: 0.5rem;
	}

	.control-btn {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: all 0.2s;
		flex: 1;
	}

	.control-btn:hover {
		background: #f1f5f9;
		border-color: #cbd5e1;
	}

	.column-list {
		padding: 0.5rem;
	}

	.column-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem;
		border-radius: 6px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.column-item:hover {
		background: #f8fafc;
	}

	.column-item input[type="checkbox"] {
		width: 16px;
		height: 16px;
		accent-color: #3b82f6;
	}

	.column-label {
		font-size: 0.9rem;
		color: #374151;
		user-select: none;
	}

	/* Table Section */
	.table-section {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		overflow: hidden;
		max-height: 70vh;
		display: flex;
		flex-direction: column;
	}

	.vendor-table {
		overflow: auto;
		flex: 1;
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	thead {
		background: #f1f5f9;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		background: #f1f5f9;
		white-space: nowrap;
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

	.payment-priority {
		text-align: center;
	}

	.priority-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.priority-most {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fca5a5;
	}

	.priority-medium {
		background: #fed7aa;
		color: #c2410c;
		border: 1px solid #fdba74;
	}

	.priority-normal {
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid #93c5fd;
	}

	.priority-low {
		background: #f3f4f6;
		color: #6b7280;
		border: 1px solid #d1d5db;
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
		font-size: 0.75rem;
	}

	.vendor-categories {
		font-size: 0.8rem;
		min-width: 150px;
		max-width: 200px;
	}

	.category-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.category-badge {
		background: #e0f2fe;
		color: #0369a1;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.no-categories {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	.no-data {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Delivery Mode Badges */
	.vendor-delivery-modes {
		max-width: 200px;
		padding: 0.5rem;
	}

	.delivery-mode-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.delivery-mode-badge {
		background: #fef3c7;
		color: #d97706;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.no-delivery-modes {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Place & Location Styles */
	.vendor-place {
		max-width: 120px;
		padding: 0.5rem;
	}

	.place-text {
		font-size: 0.75rem;
		color: #374151;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.no-place {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	.vendor-location {
		text-align: center;
		padding: 0.5rem;
	}

	.location-actions {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		align-items: center;
	}

	.location-link {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.375rem 0.75rem;
		background: #3b82f6;
		color: white;
		text-decoration: none;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 500;
		transition: all 0.2s;
		min-width: 90px;
	}

	.location-link:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.share-location-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 0.7rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 90px;
		justify-content: center;
	}

	.share-location-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 2px 6px rgba(16, 185, 129, 0.3);
	}

	.no-location {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
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

	/* Return Policy Styles */
	.return-policy-cell {
		text-align: center;
		padding: 0.75rem 0.5rem;
	}

	.return-policy-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.can-return {
		background-color: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.cannot-return {
		background-color: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
	}

	.no-return-badge {
		background-color: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.returns-accepted {
		background-color: #eff6ff;
		color: #1d4ed8;
		border: 1px solid #bfdbfe;
	}

	.no-policy {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* VAT Styles */
	.vat-cell, .vat-number-cell {
		text-align: center;
		padding: 0.75rem 0.5rem;
	}

	.vat-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.vat-applicable {
		background-color: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.no-vat {
		background-color: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.vat-number {
		font-family: monospace;
		font-weight: 600;
		color: #374151;
		background-color: #f9fafb;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		border: 1px solid #e5e7eb;
	}

	.no-vat-note {
		color: #6366f1;
		cursor: help;
		text-decoration: underline;
		font-size: 0.75rem;
	}

	.no-vat-info {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Payment Method Styles */
	.payment-methods-list {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.payment-method-tag {
		display: inline-block;
		background: #dbeafe;
		color: #1e40af;
		padding: 0.125rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		white-space: nowrap;
	}

	/* Branch Column Styles */
	.branch-name {
		font-weight: 500;
		padding: 0.25rem 0.75rem;
		border-radius: 6px;
		font-size: 0.875rem;
		display: inline-block;
		min-width: 80px;
		text-align: center;
	}

	.branch-assigned {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.branch-unassigned {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fde68a;
		font-style: italic;
	}

	/* Branch Selection Hint */
	.branch-selection-hint {
		color: #64748b;
		font-style: italic;
		font-size: 0.9rem;
		background: #f1f5f9;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
	}
</style>