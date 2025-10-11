<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { userManagement } from '$lib/utils/userManagement';
	import { windowManager } from '$lib/stores/windowManager';
	import EditVendor from '../vendor/EditVendor.svelte';

	// State management
	let vendors = [];
	let filteredVendors = [];
	let selectedVendor = null;
	let searchQuery = '';
	let isLoading = true;
	let error = null;
	let currentUserData = null;
	let branches = [];
	let showBranchSelector = false;
	let selectedBranchId = null; // Branch selected for receiving (not user's branch context)
	let receivingBranchName = 'Select Branch'; // Display name for receiving branch
	
	// Step 2 - File/Bill Management
	let currentStep = 1;
	let billType = null; // 'digital' or 'printed'
	let uploadedFiles = [];
	let pageCount = 0;
	let scannedPages = [];
	let availablePrinters = [];
	let selectedPrinter = null;
	let isScanning = false;
	let currentScanPage = 0;

	// Step indicator
	// Steps management
	let steps = [
		{ number: 1, title: 'Vendor Selection', active: true },
		{ number: 2, title: 'File/Bill Upload', active: false },
		{ number: 3, title: 'Quality Check', active: false },
		{ number: 4, title: 'Final Review', active: false }
	];

	// Update steps based on current step
	$: {
		steps = steps.map(step => ({
			...step,
			active: step.number <= currentStep
		}));
	}

	// Column visibility for vendor table (matching ManageVendor exactly)
	let showColumnSelector = false;
	let visibleColumns = {
		erp_vendor_id: true,
		vendor_name: true,
		salesman_name: true,
		salesman_contact: false,
		supervisor_name: false,
		supervisor_contact: false,
		vendor_contact: true,
		payment_method: true,
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
		actions: true // Enable actions in receiving mode
	};

	// Column definitions (matching ManageVendor exactly)
	const columnDefinitions = [
		{ key: 'erp_vendor_id', label: 'ERP Vendor ID' },
		{ key: 'vendor_name', label: 'Vendor Name' },
		{ key: 'salesman_name', label: 'Salesman Name' },
		{ key: 'salesman_contact', label: 'Salesman Contact' },
		{ key: 'supervisor_name', label: 'Supervisor Name' },
		{ key: 'supervisor_contact', label: 'Supervisor Contact' },
		{ key: 'vendor_contact', label: 'Vendor Contact' },
		{ key: 'payment_method', label: 'Payment Method' },
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

	// Load data on component mount
	onMount(async () => {
		// Get current user data
		currentUser.subscribe(user => {
			console.log('Current user data:', user);
			currentUserData = user;
			
			// Set default receiving branch to user's branch (but allow changing)
			if (user?.branch_id && !selectedBranchId) {
				selectedBranchId = user.branch_id;
				receivingBranchName = user?.branchName || 'Loading...';
				console.log('Set default receiving branch to user branch:', selectedBranchId);
			} else if (!selectedBranchId) {
				// If user has no branch, start with no selection
				selectedBranchId = null;
				receivingBranchName = 'Select Branch for Receiving';
				console.log('No user branch - require manual selection');
			}
		});

		await loadVendors();
		await loadBranches();
	});

	// Load vendors from database
	async function loadVendors() {
		try {
			isLoading = true;
			error = null;

			const { data, error: fetchError } = await supabase
				.from('vendors')
				.select('*')
				.eq('status', 'Active')
				.order('vendor_name', { ascending: true });

			if (fetchError) throw fetchError;

			vendors = data || [];
			filteredVendors = vendors;

		} catch (err) {
			error = err.message;
		} finally {
			isLoading = false;
		}
	}

	// Load branches for branch selector
	async function loadBranches() {
		try {
			console.log('Loading branches from database...');
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.order('name_en');

			if (error) {
				console.error('Error fetching branches:', error);
				throw error;
			}

			branches = data || [];
			console.log('Loaded branches for receiving selection:', branches);
			
			// Update receiving branch name if we have a selected branch
			if (selectedBranchId && branches.length > 0) {
				const selectedBranch = branches.find(b => 
					b.id == selectedBranchId || String(b.id) === String(selectedBranchId)
				);
				if (selectedBranch) {
					receivingBranchName = selectedBranch.name_en;
					console.log('Updated receiving branch name to:', receivingBranchName);
				}
			}
		} catch (err) {
			console.error('Error loading branches:', err);
			branches = []; // Fallback to empty array
		}
	}

	// Search functionality (enhanced like ManageVendor)
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

	// Handle vendor selection
	function selectVendor(vendor) {
		// Unselect if clicking the same vendor
		if (selectedVendor?.erp_vendor_id === vendor.erp_vendor_id) {
			selectedVendor = null;
		} else {
			selectedVendor = vendor;
		}
	}

	// Handle vendor edit
	function editVendor(vendor) {
		const windowId = generateEditWindowId();
		
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
				onSave: async (updatedVendor) => {
					console.log('Vendor updated:', updatedVendor);
					try {
						// Update local vendor data with proper reactivity
						const index = vendors.findIndex(v => v.erp_vendor_id === updatedVendor.erp_vendor_id);
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

	// Generate unique window ID for edit
	function generateEditWindowId() {
		return `edit-vendor-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Step 2 Functions - File/Bill Management
	function proceedToStep2() {
		if (!selectedVendor) {
			alert('Please select a vendor first');
			return;
		}
		if (!selectedBranchId) {
			alert('Please select a branch for receiving');
			return;
		}
		currentStep = 2;
		console.log('Proceeding to Step 2 - File/Bill Management');
	}

	function selectBillType(type) {
		billType = type;
		uploadedFiles = [];
		scannedPages = [];
		pageCount = 0;
		console.log('Selected bill type:', type);
	}

	function handleFileUpload(event) {
		const files = Array.from(event.target.files);
		uploadedFiles = [...uploadedFiles, ...files];
		console.log('Files uploaded:', uploadedFiles);
	}

	function removeFile(index) {
		uploadedFiles = uploadedFiles.filter((_, i) => i !== index);
	}

	function setPageCount() {
		if (pageCount > 0 && pageCount <= 50) {
			scannedPages = Array(pageCount).fill(null);
			currentScanPage = 0;
			loadAvailablePrinters();
			console.log('Set page count:', pageCount);
		} else {
			alert('Please enter a valid page count (1-50)');
		}
	}

	async function loadAvailablePrinters() {
		// Simulate loading printers - in real implementation, this would query system printers
		availablePrinters = [
			{ id: 'hp_laserjet', name: 'HP LaserJet Pro MFP M428fdw' },
			{ id: 'canon_pixma', name: 'Canon PIXMA TR8620' },
			{ id: 'epson_workforce', name: 'Epson WorkForce Pro WF-4730' }
		];
		console.log('Available printers:', availablePrinters);
	}

	async function scanPage(pageIndex) {
		if (!selectedPrinter) {
			alert('Please select a printer first');
			return;
		}
		
		isScanning = true;
		currentScanPage = pageIndex;
		
		try {
			// Simulate scanning process
			await new Promise(resolve => setTimeout(resolve, 3000));
			
			// Simulate scanned image
			const simulatedScan = {
				pageNumber: pageIndex + 1,
				imageUrl: `data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=`,
				timestamp: new Date().toISOString()
			};
			
			scannedPages[pageIndex] = simulatedScan;
			scannedPages = [...scannedPages]; // Trigger reactivity
			
			console.log(`Page ${pageIndex + 1} scanned successfully`);
		} catch (error) {
			console.error('Scanning error:', error);
			alert('Scanning failed. Please try again.');
		} finally {
			isScanning = false;
		}
	}

	async function combinePages() {
		const validPages = scannedPages.filter(page => page !== null);
		if (validPages.length === 0) {
			alert('No pages to combine');
			return;
		}
		
		try {
			// Simulate PDF creation
			console.log('Creating PDF from scanned pages...');
			await new Promise(resolve => setTimeout(resolve, 2000));
			
			// Create a simulated PDF file
			const pdfBlob = new Blob(['%PDF-1.4 simulated content'], { type: 'application/pdf' });
			const pdfFile = new File([pdfBlob], `bill_${selectedVendor.vendor_name}_${Date.now()}.pdf`, { type: 'application/pdf' });
			
			uploadedFiles = [pdfFile];
			
			alert(`PDF created successfully with ${validPages.length} pages in lower quality`);
			console.log('Combined PDF created:', pdfFile);
			
			// Proceed to next step
			currentStep = 3;
		} catch (error) {
			console.error('PDF creation error:', error);
			alert('Failed to create PDF. Please try again.');
		}
	}

	function backToStep1() {
		currentStep = 1;
		billType = null;
		uploadedFiles = [];
		scannedPages = [];
		pageCount = 0;
	}

	// Branch change handler for receiving context
	function changeBranch() {
		showBranchSelector = true;
	}

	function selectBranch(branch) {
		console.log('selectBranch called with:', branch);
		selectedBranchId = branch.id;
		receivingBranchName = branch.name_en;
		console.log('Updated selectedBranchId to:', selectedBranchId);
		console.log('Updated receivingBranchName to:', receivingBranchName);
		showBranchSelector = false;
		
		// TODO: Filter vendors/receiving data by selected branch
		// This branch selection is for receiving operations only
		console.log('Branch selected for receiving operations:', branch.name_en);
	}

	// Toggle column visibility
	function toggleColumn(columnKey) {
		visibleColumns[columnKey] = !visibleColumns[columnKey];
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}

	// Show/hide all columns
	function toggleAllColumns(show) {
		for (let key in visibleColumns) {
			if (key !== 'vendor_name') { // Always keep vendor name visible
				visibleColumns[key] = show;
			}
		}
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}

	// Share location function (from ManageVendor)
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


</script>

<!-- Start Receiving Window -->
<div class="start-receiving">
	<!-- Step Indicator -->
	<div class="step-indicator">
		{#each steps as step}
			<div class="step {step.active ? 'active' : ''}">
				<div class="step-number">{step.number}</div>
				<div class="step-title">{step.title}</div>
			</div>
			{#if step.number < steps.length}
				<div class="step-connector {step.active && steps[step.number]?.active ? 'active' : ''}"></div>
			{/if}
		{/each}
	</div>

	<div class="header">
		<h1 class="title">� Start Receiving - Step 1</h1>
		<p class="subtitle">Select vendor and configure receiving details</p>
	</div>

	<!-- User Information Section -->
	<div class="user-info-section">
		<div class="user-info-card">
			<div class="user-details">
				<div class="user-field">
					<span class="label">Employee:</span>
					<span class="value">{currentUserData?.employeeName || currentUserData?.username || 'Unknown User'}</span>
				</div>
				<div class="user-field">
					<span class="label">Position:</span>
					<span class="value">{currentUserData?.roleType || 'Unknown Position'}</span>
				</div>
				<div class="user-field">
					<span class="label">User Branch:</span>
					<span class="value">{currentUserData?.branchName || 'Unknown'}</span>
				</div>
				<div class="user-field">
					<span class="label">Receiving For:</span>
					<span class="value receiving-branch" class:same-as-user={selectedBranchId == currentUserData?.branch_id}>
						{receivingBranchName}
						{#if selectedBranchId == currentUserData?.branch_id}
							<span class="default-indicator">(Default)</span>
						{/if}
					</span>
					<button class="change-btn" on:click={changeBranch}>
						{selectedBranchId ? 'Change' : 'Select'}
					</button>
				</div>
			</div>
		</div>
	</div>

	<!-- Vendor Selection Section -->
	<div class="vendor-selection-section">
		<div class="section-header">
			<h2>Select Vendor</h2>
			<p>Choose the vendor for this receiving transaction</p>
		</div>

		<!-- Search Bar -->
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
				Showing {filteredVendors.length} of {vendors.length} vendors
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

		<!-- Vendor Table -->
		<div class="table-container">
			{#if isLoading}
				<div class="loading-table">
					<div class="loading-spinner">⏳</div>
					<p>Loading vendors...</p>
				</div>
			{:else if error}
				<div class="error-message">
					<span class="error-icon">⚠️</span>
					<p>Error loading vendors: {error}</p>
					<button class="retry-btn" on:click={loadVendors}>Try Again</button>
				</div>
			{:else if filteredVendors.length === 0}
				<div class="empty-state">
					{#if searchQuery}
						<span class="empty-icon">�</span>
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
								<th style="width: 50px">Select</th>
								{#if visibleColumns.erp_vendor_id}<th>ERP Vendor ID</th>{/if}
								{#if visibleColumns.vendor_name}<th>Vendor Name</th>{/if}
								{#if visibleColumns.salesman_name}<th>Salesman Name</th>{/if}
								{#if visibleColumns.salesman_contact}<th>Salesman Contact</th>{/if}
								{#if visibleColumns.supervisor_name}<th>Supervisor Name</th>{/if}
								{#if visibleColumns.supervisor_contact}<th>Supervisor Contact</th>{/if}
								{#if visibleColumns.vendor_contact}<th>Vendor Contact</th>{/if}
								{#if visibleColumns.payment_method}<th>Payment Method</th>{/if}
								{#if visibleColumns.credit_period}<th>Credit Period</th>{/if}
								{#if visibleColumns.bank_name}<th>Bank Name</th>{/if}
								{#if visibleColumns.iban}<th>IBAN</th>{/if}
								{#if visibleColumns.last_visit}<th>Last Visit</th>{/if}
								{#if visibleColumns.place}<th>Place</th>{/if}
								{#if visibleColumns.location}<th>Location</th>{/if}
								{#if visibleColumns.categories}<th>Categories</th>{/if}
								{#if visibleColumns.delivery_modes}<th>Delivery Modes</th>{/if}
								{#if visibleColumns.return_expired}<th>Return Expired</th>{/if}
								{#if visibleColumns.return_near_expiry}<th>Return Near Expiry</th>{/if}
								{#if visibleColumns.return_over_stock}<th>Return Over Stock</th>{/if}
								{#if visibleColumns.return_damage}<th>Return Damage</th>{/if}
								{#if visibleColumns.no_return}<th>No Return</th>{/if}
								{#if visibleColumns.vat_status}<th>VAT Status</th>{/if}
								{#if visibleColumns.vat_number}<th>VAT Number</th>{/if}
								{#if visibleColumns.status}<th>Status</th>{/if}
								{#if visibleColumns.actions}<th>Actions</th>{/if}
							</tr>
						</thead>
						<tbody>
							{#each filteredVendors as vendor}
								<tr class="vendor-row {selectedVendor?.erp_vendor_id === vendor.erp_vendor_id ? 'selected' : ''}" 
									on:click={() => selectVendor(vendor)}>
									<td>
										<input 
											type="checkbox" 
											checked={selectedVendor?.erp_vendor_id === vendor.erp_vendor_id}
											on:change={() => selectVendor(vendor)}
										/>
									</td>
									{#if visibleColumns.erp_vendor_id}
										<td class="vendor-id">{vendor.erp_vendor_id}</td>
									{/if}
									{#if visibleColumns.vendor_name}
										<td class="vendor-name">{vendor.vendor_name}</td>
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
														on:click|stopPropagation={() => shareLocation(vendor.location_link, vendor.vendor_name)}
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
												<span class="status-badge status-active">✅ Active</span>
											{:else if vendor.status === 'Deactivated'}
												<span class="status-badge status-deactivated">🚫 Deactivated</span>
											{:else if vendor.status === 'Blacklisted'}
												<span class="status-badge status-blacklisted">⚫ Blacklist</span>
											{:else}
												<span class="status-badge status-active">✅ Active</span>
											{/if}
										</td>
									{/if}
									{#if visibleColumns.actions}
										<td class="actions-cell">
											<button 
												class="edit-btn"
												on:click|stopPropagation={() => editVendor(vendor)}
												title="Edit Vendor"
											>
												<i class="fas fa-edit"></i>
												Edit
											</button>
										</td>
									{/if}
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>

		<!-- Action Buttons -->
		<div class="action-buttons">
			<button class="secondary-btn">Cancel</button>
			<button class="primary-btn" disabled={!selectedVendor || !selectedBranchId} on:click={proceedToStep2}>
				Continue to Step 2
			</button>
		</div>
	</div>

	<!-- Step 2: File/Bill Management -->
	{#if currentStep === 2}
		<div class="step-content step-2">
			<div class="header">
				<h1 class="title">📄 File & Bill Management - Step 2</h1>
				<p class="subtitle">Upload digital files or scan printed bills</p>
			</div>

			<!-- Bill Type Selection -->
			{#if !billType}
				<div class="bill-type-selection">
					<h2>Select Bill Type</h2>
					<div class="bill-type-options">
						<button class="bill-type-card" on:click={() => selectBillType('digital')}>
							<div class="card-icon">💾</div>
							<h3>Digital Files</h3>
							<p>Upload images or PDF files</p>
							<span class="file-types">Supports: JPG, PNG, PDF</span>
						</button>
						<button class="bill-type-card" on:click={() => selectBillType('printed')}>
							<div class="card-icon">🖨️</div>
							<h3>Printed Bill</h3>
							<p>Scan physical documents</p>
							<span class="file-types">Scan to PDF</span>
						</button>
					</div>
				</div>
			{/if}

			<!-- Digital File Upload -->
			{#if billType === 'digital'}
				<div class="digital-upload-section">
					<div class="upload-header">
						<h2>📁 Upload Digital Files</h2>
						<button class="back-btn" on:click={() => billType = null}>← Change Type</button>
					</div>
					
					<div class="upload-area">
						<input 
							type="file" 
							id="file-upload" 
							multiple 
							accept=".jpg,.jpeg,.png,.pdf"
							on:change={handleFileUpload}
							style="display: none;"
						/>
						<label for="file-upload" class="upload-label">
							<div class="upload-icon">📎</div>
							<p>Drop files here or <span class="upload-link">choose files</span></p>
							<small>Supports JPG, PNG, PDF • Max 10MB per file</small>
						</label>
					</div>

					{#if uploadedFiles.length > 0}
						<div class="uploaded-files">
							<h3>Uploaded Files ({uploadedFiles.length})</h3>
							<div class="file-list">
								{#each uploadedFiles as file, index}
									<div class="file-item">
										<div class="file-info">
											<span class="file-icon">
												{#if file.type.includes('pdf')}📄{:else}🖼️{/if}
											</span>
											<div class="file-details">
												<span class="file-name">{file.name}</span>
												<span class="file-size">{(file.size / 1024 / 1024).toFixed(2)} MB</span>
											</div>
										</div>
										<button class="remove-file-btn" on:click={() => removeFile(index)}>❌</button>
									</div>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Printed Bill Scanning -->
			{#if billType === 'printed'}
				<div class="scanning-section">
					<div class="scanning-header">
						<h2>🖨️ Scan Printed Bill</h2>
						<button class="back-btn" on:click={() => billType = null}>← Change Type</button>
					</div>

					{#if pageCount === 0}
						<div class="page-count-input">
							<h3>Enter Number of Pages</h3>
							<div class="page-input-group">
								<input 
									type="number" 
									bind:value={pageCount} 
									min="1" 
									max="50" 
									placeholder="Enter page count"
									class="page-count-field"
								/>
								<button class="set-pages-btn" on:click={setPageCount}>Set Pages</button>
							</div>
						</div>
					{:else}
						<!-- Printer Selection -->
						{#if availablePrinters.length > 0 && !selectedPrinter}
							<div class="printer-selection">
								<h3>Select Printer/Scanner</h3>
								<div class="printer-list">
									{#each availablePrinters as printer}
										<button 
											class="printer-item"
											on:click={() => selectedPrinter = printer}
										>
											<span class="printer-icon">🖨️</span>
											<span class="printer-name">{printer.name}</span>
										</button>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Scanning Interface -->
						{#if selectedPrinter}
							<div class="scanning-interface">
								<div class="scanner-info">
									<h3>Selected: {selectedPrinter.name}</h3>
									<p>Scanning {pageCount} pages</p>
								</div>

								<div class="page-templates">
									{#each Array(pageCount) as _, pageIndex}
										<div class="page-template" class:scanned={scannedPages[pageIndex]} class:scanning={isScanning && currentScanPage === pageIndex}>
											<div class="page-header">
												<h4>Page {pageIndex + 1}</h4>
												<span class="page-status">
													{#if scannedPages[pageIndex]}
														✅ Scanned
													{:else if isScanning && currentScanPage === pageIndex}
														⏳ Scanning...
													{:else}
														⏸️ Pending
													{/if}
												</span>
											</div>
											
											{#if scannedPages[pageIndex]}
												<div class="scanned-preview">
													<img src={scannedPages[pageIndex].imageUrl} alt="Scanned page {pageIndex + 1}" />
													<div class="scan-info">
														<small>Scanned: {new Date(scannedPages[pageIndex].timestamp).toLocaleTimeString()}</small>
													</div>
												</div>
											{:else}
												<div class="scan-placeholder">
													<div class="placeholder-icon">📄</div>
													<p>Ready to scan</p>
													<button 
														class="scan-btn" 
														on:click={() => scanPage(pageIndex)}
														disabled={isScanning}
													>
														{#if isScanning && currentScanPage === pageIndex}
															⏳ Scanning...
														{:else}
															📷 Scan Page
														{/if}
													</button>
												</div>
											{/if}
										</div>
									{/each}
								</div>

								<!-- Combine Pages Button -->
								{#if scannedPages.some(page => page !== null)}
									<div class="combine-section">
										<button class="combine-btn" on:click={combinePages}>
											📑 Combine Pages to PDF
											<small>({scannedPages.filter(p => p !== null).length}/{pageCount} pages scanned)</small>
										</button>
									</div>
								{/if}
							</div>
						{/if}
					{/if}
				</div>
			{/if}

			<!-- Step 2 Actions -->
			<div class="step-actions">
				<button class="secondary-btn" on:click={backToStep1}>← Back to Step 1</button>
				{#if (billType === 'digital' && uploadedFiles.length > 0) || (billType === 'printed' && uploadedFiles.length > 0)}
					<button class="primary-btn">Continue to Step 3 →</button>
				{/if}
			</div>
		</div>
	{/if}
</div>

<!-- Branch Selector Modal -->
{#if showBranchSelector}
	<div class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="branch-selector-title" on:click={() => showBranchSelector = false} on:keydown={(e) => e.key === 'Escape' && (showBranchSelector = false)}>
		<div class="modal-content" on:click|stopPropagation on:keydown|stopPropagation>
			<div class="modal-header">
				<h3 id="branch-selector-title">Select Branch for Receiving</h3>
				<button class="close-btn" on:click={() => showBranchSelector = false}>×</button>
			</div>
			<div class="modal-body">
				<p class="modal-description">Choose which branch you are receiving items for:</p>
				{#if branches.length === 0}
					<div class="empty-state">
						<p>No branches available</p>
					</div>
				{:else}
					{#each branches as branch}
						<button class="branch-option" on:click={() => selectBranch(branch)}>
							<div class="branch-info">
								<span class="branch-name">{branch.name_en}</span>
								<span class="branch-name-ar">{branch.name_ar}</span>
								<span class="branch-location">{branch.location_en}</span>
							</div>
							{#if branch.id == selectedBranchId || String(branch.id) === String(selectedBranchId)}
								<span class="current-badge">Current</span>
							{/if}
						</button>
					{/each}
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.start-receiving {
		padding: 24px;
		height: 100%;
		background: #f8fafc;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Step Indicator */
	.step-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 32px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
	}

	.step-number {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 16px;
		background: #e5e7eb;
		color: #6b7280;
		transition: all 0.3s ease;
	}

	.step.active .step-number {
		background: #3b82f6;
		color: white;
	}

	.step-title {
		font-size: 12px;
		font-weight: 500;
		color: #6b7280;
		text-align: center;
	}

	.step.active .step-title {
		color: #1f2937;
		font-weight: 600;
	}

	.step-connector {
		width: 60px;
		height: 2px;
		background: #e5e7eb;
		margin: 0 16px;
	}

	.step-connector.active {
		background: #3b82f6;
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

	/* User Information Section */
	.user-info-section {
		margin-bottom: 2rem;
	}

	.user-info-card {
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 1px solid #0ea5e9;
		border-radius: 12px;
		padding: 20px;
	}

	.user-details {
		display: flex;
		gap: 32px;
		align-items: center;
		flex-wrap: wrap;
	}

	.user-field {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.user-field .label {
		font-weight: 600;
		color: #1f2937;
		font-size: 14px;
	}

	.user-field .value {
		color: #374151;
		font-size: 14px;
	}

	.change-btn {
		background: #0ea5e9;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 4px 12px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.change-btn:hover {
		background: #0284c7;
	}

	.receiving-branch {
		font-weight: 600;
		color: #2563eb;
	}

	.receiving-branch.same-as-user {
		color: #059669;
	}

	.default-indicator {
		font-size: 12px;
		color: #6b7280;
		font-weight: 400;
		margin-left: 8px;
	}

	.modal-description {
		color: #6b7280;
		font-size: 14px;
		margin-bottom: 16px;
		text-align: center;
		font-style: italic;
	}

	/* Vendor Selection Section */
	.vendor-selection-section {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
	}

	.section-header {
		margin-bottom: 24px;
	}

	.section-header h2 {
		font-size: 20px;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 4px 0;
	}

	.section-header p {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
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

	/* Table Container */
	.table-container {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		overflow: hidden;
		margin-bottom: 24px;
	}

	/* Loading/Error/Empty States */
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

	/* Vendor Table */
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

	.vendor-row {
		cursor: pointer;
		transition: background-color 0.2s ease;
	}

	.vendor-row:hover {
		background: #f8fafc;
	}

	.vendor-row.selected {
		background: #eff6ff;
		border-color: #3b82f6;
	}

	.vendor-row.selected td {
		border-bottom-color: #dbeafe;
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

	.no-data {
		color: #9ca3af;
		font-style: italic;
		font-size: 0.75rem;
	}

	/* Payment Method Styles */
	.payment-method {
		font-weight: 500;
		font-size: 0.9rem;
	}

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

	/* Categories and Delivery Modes */
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

	/* Status Badge */
	.status-cell {
		text-align: center;
		padding: 0.5rem;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.status-active {
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		border: 2px solid #059669;
	}

	.status-blacklisted {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: white;
		border: 2px solid #dc2626;
	}

	.status-deactivated {
		background: linear-gradient(135deg, #f59e0b, #d97706);
		color: white;
		border: 2px solid #d97706;
	}

	/* Actions Column */
	.actions-cell {
		text-align: center;
		padding: 0.75rem 0.5rem;
	}

	.edit-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.edit-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.edit-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.edit-btn i {
		font-size: 0.875rem;
	}

	/* Action Buttons */
	.action-buttons {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
	}

	.primary-btn, .secondary-btn {
		padding: 10px 20px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		border: 1px solid;
	}

	.primary-btn {
		background: #3b82f6;
		border-color: #3b82f6;
		color: white;
	}

	.primary-btn:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
	}

	.primary-btn:disabled {
		background: #d1d5db;
		border-color: #d1d5db;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.secondary-btn {
		background: white;
		border-color: #d1d5db;
		color: #374151;
	}

	.secondary-btn:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	/* Modal Styles */
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
		max-width: 400px;
		width: 90%;
		max-height: 80vh;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 6px;
		transition: all 0.2s ease;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.modal-body {
		padding: 16px 24px 24px;
		max-height: 400px;
		overflow-y: auto;
	}

	.branch-option {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px;
		border-radius: 8px;
		cursor: pointer;
		transition: background 0.2s ease;
		margin-bottom: 8px;
		border: 1px solid #e5e7eb;
		background: white;
		width: 100%;
		text-align: left;
		font-family: inherit;
	}

	.branch-option:hover {
		background: #f3f4f6;
		border-color: #d1d5db;
	}

	.branch-option:focus {
		outline: none;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
		border-color: #3b82f6;
	}

	.branch-info {
		flex: 1;
	}

	.branch-name {
		font-size: 16px;
		color: #374151;
		font-weight: 600;
		display: block;
		margin-bottom: 4px;
	}

	.branch-name-ar {
		font-size: 14px;
		color: #6b7280;
		display: block;
		margin-bottom: 4px;
		font-style: italic;
	}

	.branch-location {
		font-size: 12px;
		color: #9ca3af;
		display: block;
	}

	.current-badge {
		background: #3b82f6;
		color: white;
		padding: 4px 12px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.empty-state {
		text-align: center;
		padding: 40px 20px;
		color: #6b7280;
	}

	.empty-state p {
		font-size: 16px;
		margin: 0;
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.step-indicator {
			flex-direction: column;
			gap: 16px;
		}

		.step-connector {
			width: 2px;
			height: 30px;
			margin: 8px 0;
		}

		.user-details {
			flex-direction: column;
			align-items: flex-start;
			gap: 16px;
		}

		th, td {
			padding: 0.75rem 0.5rem;
			font-size: 0.9rem;
		}

		.action-buttons {
			flex-direction: column;
		}

		.search-input {
			padding: 0.875rem 0.875rem 0.875rem 2.5rem;
		}
	}
</style>