<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	// Component state
	let isLoading = false;
	let branches = [];
	let vendors = [];
	let filteredVendors = [];
	let searchTerm = '';
	
	// Two-step form state
	let currentStep = 1;
	let selectedBranch = null;
	let selectedBranchId = ''; // For dropdown binding
	let selectedVendor = null;
	
	// Manual entry form for vendor_payment_schedule table
	let manualForm = {
		bill_number: '',
		bill_date: '',
		bill_amount: 0,
		final_bill_amount: 0,
		payment_method: 'Cash on Delivery',
		bank_name: '',
		iban: '',
		due_date: '',
		credit_period: 30,
		vat_number: '',
		notes: ''
	};

	// Payment method options
	const paymentMethods = [
		'Cash on Delivery',
		'Bank on Delivery', 
		'Cash Credit',
		'Bank Credit'
	];

	// Payment status removed - now using is_paid boolean

	onMount(async () => {
		await loadData();
		setDefaultDates();
	});

	// Reactive statement to ensure dropdown binding works properly
	$: if (selectedBranch && selectedBranchId !== selectedBranch.id.toString()) {
		selectedBranchId = selectedBranch.id.toString();
		console.log('🔄 Syncing dropdown value:', selectedBranchId);
	}

	async function loadData() {
		isLoading = true;
		try {
			await Promise.all([
				loadBranches(),
				loadVendors()
			]);
		} catch (error) {
			console.error('Error loading data:', error);
		} finally {
			isLoading = false;
		}
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadVendors() {
		try {
			console.log('🔄 Loading vendors - timestamp:', new Date().toISOString());
			
			// Load ALL vendors using pagination to bypass Supabase default limits
			let allVendors = [];
			let hasMore = true;
			let offset = 0;
			const pageSize = 1000;
			
			while (hasMore) {
				console.log(`🔄 Loading vendors page ${Math.floor(offset/pageSize) + 1} (offset: ${offset})`);
				
				const { data, error } = await supabase
					.from('vendors')
					.select('erp_vendor_id, vendor_name, bank_name, iban, vat_number, branch_id, status')
					.order('erp_vendor_id') // Order by ID for consistent pagination
					.range(offset, offset + pageSize - 1);

				if (error) {
					console.error('❌ Error loading vendors:', error);
					throw error;
				}
				
				const pageVendors = data || [];
				allVendors = [...allVendors, ...pageVendors];
				
				console.log(`📄 Page ${Math.floor(offset/pageSize) + 1}: loaded ${pageVendors.length} vendors (total so far: ${allVendors.length})`);
				
				// Check if we got a full page - if not, we're done
				hasMore = pageVendors.length === pageSize;
				offset += pageSize;
				
				// Safety check to prevent infinite loops
				if (offset > 10000) {
					console.warn('⚠️ Safety limit reached, stopping pagination');
					break;
				}
			}
			
			vendors = allVendors;
			
			console.log(`📊 Loaded ${vendors.length} vendors total (no limit applied)`);
			console.log('📊 First 5 vendors:', vendors.slice(0, 5));
			
			// Debug: Check for vendors with branch_id issues
			const vendorsWithNullBranch = vendors.filter(v => !v.branch_id);
			const vendorsWithBranch3 = vendors.filter(v => v.branch_id === 3);
			const vendorsWithBranch3String = vendors.filter(v => v.branch_id === '3');
			
			console.log(`📊 Vendors with null/undefined branch_id: ${vendorsWithNullBranch.length}`);
			console.log(`📊 Vendors with branch_id === 3: ${vendorsWithBranch3.length}`);
			console.log(`📊 Vendors with branch_id === '3': ${vendorsWithBranch3String.length}`);
			
			// Try to detect if we're hitting a limit by checking if the last vendor has branch_id 3
			const lastVendors = vendors.slice(-10);
			const lastVendorsWithBranch3 = lastVendors.filter(v => v.branch_id === 3);
			console.log(`📊 Last 10 vendors:`, lastVendors.map(v => `${v.erp_vendor_id}(${v.branch_id})`));
			console.log(`📊 Last 10 vendors with branch 3: ${lastVendorsWithBranch3.length}`);
			
			// If we're missing vendors, try loading branch 3 specifically
			if (vendorsWithBranch3.length < 500) {
				console.log('� Vendor count seems low, trying direct branch query...');
				await loadVendorsDirectlyForBranch3();
			}
			
			// Group vendors by branch for debugging
			const branchGroups = vendors.reduce((acc, vendor) => {
				const branchId = vendor.branch_id || 'unassigned';
				if (!acc[branchId]) acc[branchId] = [];
				acc[branchId].push(vendor);
				return acc;
			}, {});
			
			console.log('📊 Vendors by branch:', branchGroups);
		} catch (error) {
			console.error('Error loading vendors:', error);
		}
	}

	// Helper function to load vendors directly for branch 3
	async function loadVendorsDirectlyForBranch3() {
		try {
			console.log('🎯 Loading vendors directly for branch 3...');
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, bank_name, iban, vat_number, branch_id, status')
				.eq('branch_id', 3)
				.order('vendor_name');

			if (error) {
				console.error('❌ Error loading branch 3 vendors:', error);
				return;
			}
			
			const branch3Vendors = data || [];
			console.log(`🎯 Direct query found ${branch3Vendors.length} vendors for branch 3`);
			
			// Merge with existing vendors, avoiding duplicates
			const existingVendorIds = new Set(vendors.map(v => `${v.erp_vendor_id}-${v.branch_id}`));
			const newVendors = branch3Vendors.filter(v => 
				!existingVendorIds.has(`${v.erp_vendor_id}-${v.branch_id}`)
			);
			
			if (newVendors.length > 0) {
				console.log(`🎯 Adding ${newVendors.length} missing vendors for branch 3`);
				vendors = [...vendors, ...newVendors];
			}
			
		} catch (error) {
			console.error('Error loading branch 3 vendors directly:', error);
		}
	}

	function onBranchSelect(branchId) {
		console.log('🏛️ Branch selection triggered:', branchId, typeof branchId);
		if (!branchId) {
			selectedBranch = null;
			selectedBranchId = '';
			filteredVendors = [];
			return;
		}
		
		// Convert to number for comparison, but keep string for dropdown
		const branchIdNum = parseInt(branchId);
		selectedBranch = branches.find(b => b.id === branchIdNum);
		selectedBranchId = branchId.toString(); // Ensure it's a string for dropdown
		console.log('🏛️ Selected branch:', selectedBranch);
		console.log('🏛️ Selected branch ID for dropdown:', selectedBranchId);
		
		if (selectedBranch) {
			// Filter vendors by selected branch
			searchTerm = ''; // Clear search when changing branch
			filterVendors();
			
			// Update form with branch details
			manualForm.branch_id = selectedBranch.id;
			manualForm.branch_name = selectedBranch.name_en;
		}
	}

	function filterVendors() {
		if (!selectedBranch) return;
		
		const branchIdStr = selectedBranch.id.toString();
		const branchIdNum = selectedBranch.id;
		
		console.log(`🔍 Filtering for branch: ${selectedBranch.name_en} (ID: ${branchIdNum})`);
		
		// More inclusive filtering - handle both string and number branch_id
		let baseVendors = vendors.filter(v => {
			if (!v.branch_id && v.branch_id !== 0) return false; // Skip null/undefined but allow 0
			
			// Check both string and number comparisons
			const matches = (
				v.branch_id === branchIdNum ||           // Number comparison
				v.branch_id === branchIdStr ||           // String comparison
				v.branch_id.toString() === branchIdStr   // Convert to string comparison
			);
			
			return matches;
		});
		
		console.log(`🏢 Found ${baseVendors.length} vendors for branch ${selectedBranch.name_en} (ID: ${selectedBranch.id})`);
		console.log(`🔍 Expected vendor count: 503 (from exact query)`);
		
		if (baseVendors.length !== 503) {
			console.warn(`⚠️ Vendor count mismatch! Expected 503, got ${baseVendors.length}`);
			// Show some sample vendors that might be missing
			const sampleMissingVendors = vendors.filter(v => 
				v.branch_id && 
				v.branch_id != branchIdNum && 
				v.branch_id != branchIdStr
			).slice(0, 5);
			console.log('🔍 Sample vendors with different branch_id format:', sampleMissingVendors);
		}
		
		if (searchTerm.trim()) {
			const search = searchTerm.toLowerCase();
			const searchOriginal = searchTerm.trim();
			filteredVendors = baseVendors.filter(vendor => 
				vendor.vendor_name.toLowerCase().includes(search) ||
				vendor.erp_vendor_id.toString().includes(searchOriginal)
			);
			console.log(`🔍 Search "${searchTerm}" found ${filteredVendors.length} vendors`);
			console.log(`🔍 Matching vendors:`, filteredVendors.map(v => `${v.erp_vendor_id} - ${v.vendor_name}`));
		} else {
			filteredVendors = baseVendors;
		}
	}

	function onVendorSelect(vendorId) {
		selectedVendor = filteredVendors.find(v => v.erp_vendor_id === vendorId);
		if (selectedVendor) {
			// Update form with vendor details
			manualForm.vendor_id = selectedVendor.erp_vendor_id;
			manualForm.vendor_name = selectedVendor.vendor_name;
			manualForm.bank_name = selectedVendor.bank_name || '';
			manualForm.iban = selectedVendor.iban || '';
			manualForm.vat_number = selectedVendor.vat_number || '';
			
			// Move to step 2
			currentStep = 2;
		}
	}

	function goBackToStep1() {
		currentStep = 1;
		selectedVendor = null;
		// Clear vendor form data but keep branch selection
		manualForm.vendor_id = '';
		manualForm.vendor_name = '';
		manualForm.bank_name = '';
		manualForm.iban = '';
		manualForm.vat_number = '';
	}

	function setDefaultDates() {
		const today = new Date();
		manualForm.bill_date = today.toISOString().split('T')[0];
		
		// Set default due date to 30 days from today
		const dueDate = new Date(today.getTime() + (30 * 24 * 60 * 60 * 1000));
		manualForm.due_date = dueDate.toISOString().split('T')[0];
	}

	function calculateDueDate() {
		if (manualForm.bill_date && manualForm.credit_period) {
			const billDate = new Date(manualForm.bill_date);
			const dueDate = new Date(billDate.getTime() + (manualForm.credit_period * 24 * 60 * 60 * 1000));
			manualForm.due_date = dueDate.toISOString().split('T')[0];
		}
	}

	function handlePaymentMethodChange() {
		if (manualForm.payment_method) {
			// Handle delivery methods
			if (manualForm.payment_method === 'Cash on Delivery' || manualForm.payment_method === 'Bank on Delivery') {
				manualForm.credit_period = '';
				// Set due date to current date for both delivery methods
				const today = new Date();
				manualForm.due_date = today.toISOString().split('T')[0];
				
				if (manualForm.payment_method === 'Cash on Delivery') {
					manualForm.bank_name = '';
					manualForm.iban = '';
				}
			}
			// Clear bank fields for cash credit
			else if (manualForm.payment_method === 'Cash Credit') {
				manualForm.bank_name = '';
				manualForm.iban = '';
			}
		}
	}

	function handleCreditPeriodChange() {
		if (manualForm.credit_period && (manualForm.payment_method === 'Cash Credit' || manualForm.payment_method === 'Bank Credit')) {
			const billDate = new Date(manualForm.bill_date);
			const creditDays = parseInt(manualForm.credit_period);
			if (creditDays > 0) {
				const dueDate = new Date(billDate.getTime() + (creditDays * 24 * 60 * 60 * 1000));
				manualForm.due_date = dueDate.toISOString().split('T')[0];
			}
		}
	}

	function copyBillAmount() {
		manualForm.final_bill_amount = manualForm.bill_amount;
	}

	async function savePaymentSchedule() {
		try {
			isLoading = true;

			// Validate step 1 selections
			if (!selectedBranch || !selectedVendor) {
				alert('❌ Please select both branch and vendor first');
				currentStep = 1;
				return;
			}

			// Validate required fields
			if (!manualForm.bill_number || !manualForm.bill_date || !manualForm.due_date || !manualForm.bill_amount) {
				alert('❌ Please fill in all required fields');
				return;
			}

			// Validate bill amount is greater than 0
			if (parseFloat(manualForm.bill_amount) <= 0) {
				alert('❌ Bill Amount must be greater than 0');
				return;
			}

			// Check for duplicate bills before saving
			console.log('Checking for duplicate payment schedules...');
			const { data: existingRecords, error: duplicateError } = await supabase
				.from('vendor_payment_schedule')
				.select('id, bill_number, bill_amount, created_at, vendor_name, branch_name')
				.eq('vendor_id', selectedVendor.erp_vendor_id.toString()) // Use vendor_id and convert to string
				.eq('branch_id', selectedBranch.id)
				.eq('bill_amount', parseFloat(manualForm.bill_amount))
				.eq('bill_number', manualForm.bill_number.trim());

			if (duplicateError) {
				console.error('Error checking for duplicates:', duplicateError);
				alert('❌ Error checking for duplicate bills: ' + duplicateError.message);
				return;
			}

			if (existingRecords && existingRecords.length > 0) {
				const duplicateRecord = existingRecords[0];
				const duplicateDate = new Date(duplicateRecord.created_at).toLocaleDateString();
				
				alert(
					`❌ Payment Schedule Already Exists!\n\n` +
					`This bill has already been scheduled for payment:\n` +
					`• Bill Number: ${duplicateRecord.bill_number}\n` +
					`• Bill Amount: ${formatCurrency(duplicateRecord.bill_amount)}\n` +
					`• Vendor: ${duplicateRecord.vendor_name}\n` +
					`• Branch: ${duplicateRecord.branch_name}\n` +
					`• Previously scheduled on: ${duplicateDate}\n\n` +
					`Please check the bill details and ensure this is not a duplicate entry.`
				);
				
				console.log('Duplicate payment schedule found:', duplicateRecord);
				return;
			}

			// Insert into vendor_payment_schedule table
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.insert({
					bill_number: manualForm.bill_number,
					vendor_id: selectedVendor.erp_vendor_id.toString(), // Use vendor_id and convert to string
					vendor_name: selectedVendor.vendor_name,
					branch_id: selectedBranch.id,
					branch_name: selectedBranch.name_en,
				bill_date: manualForm.bill_date,
				bill_amount: manualForm.bill_amount,
				final_bill_amount: manualForm.final_bill_amount || manualForm.bill_amount,
				payment_method: manualForm.payment_method,
				bank_name: manualForm.bank_name,
				iban: manualForm.iban,
				due_date: manualForm.due_date,
				credit_period: manualForm.credit_period,
				vat_number: manualForm.vat_number,
				is_paid: false,
				scheduled_date: new Date().toISOString(),
				notes: manualForm.notes || `Manually created on ${new Date().toLocaleDateString()}`
			})
			.select();			if (error) throw error;

			alert(`✅ Payment Schedule Created Successfully!\n\nBill: ${manualForm.bill_number}\nVendor: ${selectedVendor.vendor_name} (${selectedVendor.erp_vendor_id})\nBranch: ${selectedBranch.name_en}\nAmount: ${formatCurrency(manualForm.final_bill_amount || manualForm.bill_amount)}\nDue Date: ${new Date(manualForm.due_date).toLocaleDateString()}`);

			// Reset form
			resetForm();

		} catch (error) {
			console.error('Error saving payment schedule:', error);
			alert('❌ Error saving payment schedule: ' + error.message);
		} finally {
			isLoading = false;
		}
	}

	function resetForm() {
		currentStep = 1;
		selectedBranch = null;
		selectedBranchId = '';
		selectedVendor = null;
		filteredVendors = [];
		searchTerm = '';
		
		manualForm = {
			bill_number: '',
			bill_date: '',
			bill_amount: 0,
			final_bill_amount: 0,
			payment_method: 'Cash on Delivery',
			bank_name: '',
			iban: '',
			due_date: '',
			credit_period: 30,
			vat_number: '',
			payment_status: 'scheduled',
			notes: ''
		};
		setDefaultDates();
	}

	function formatCurrency(amount) {
		if (!amount || amount === 0) return '0.00';
		const numericAmount = typeof amount === 'string' ? parseFloat(amount) : Number(amount);
		const formattedAmount = numericAmount.toFixed(2);
		const [integer, decimal] = formattedAmount.split('.');
		const integerWithCommas = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
		return `${integerWithCommas}.${decimal}`;
	}
</script>

<div class="manual-scheduling">
	<div class="header">
		<h1 class="title">📅 Manual Payment Schedule Entry</h1>
		<p class="subtitle">Two-step process: Select branch and vendor, then complete payment details</p>
	</div>

	<!-- Step Indicator -->
	<div class="step-indicator">
		<div class="step" class:active={currentStep === 1} class:completed={currentStep > 1}>
			<div class="step-number">1</div>
			<div class="step-label">Select Branch & Vendor</div>
		</div>
		<div class="step-connector" class:completed={currentStep > 1}></div>
		<div class="step" class:active={currentStep === 2}>
			<div class="step-number">2</div>
			<div class="step-label">Payment Details</div>
		</div>
	</div>

	{#if currentStep === 1}
		<!-- Step 1: Branch & Vendor Selection -->
		<div class="step-container">
			<div class="step-header">
				<h2>🏢 Step 1: Select Branch & Vendor</h2>
				<p>Choose a branch from the dropdown, then search and select the vendor for payment scheduling</p>
			</div>

			<div class="selection-content">
				<!-- Branch Selection Dropdown -->
				<div class="selection-section">
					<h3>Select Branch</h3>
					<div class="dropdown-container">
						<select 
							bind:value={selectedBranchId} 
							on:change={(e) => onBranchSelect(e.target.value)}
							class="branch-dropdown"
						>
							<option value="">Choose a branch...</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Vendor Selection (shown after branch selection) -->
				{#if selectedBranch}
					<div class="selection-section">
						<h3>Select Vendor from {selectedBranch.name_en} ({filteredVendors.length} vendors available)</h3>
						
						<!-- Search Input -->
						<div class="search-container">
							<div class="search-input-wrapper">
								<span class="search-icon">🔍</span>
								<input 
									type="text" 
									bind:value={searchTerm}
									on:input={filterVendors}
									placeholder="Search vendors by name or ID..."
									class="search-input"
								>
								{#if searchTerm}
									<button 
										type="button" 
										class="clear-search" 
										on:click={() => { searchTerm = ''; filterVendors(); }}
									>
										✕
									</button>
								{/if}
							</div>
						</div>

						<!-- Vendor Table -->
						{#if filteredVendors.length > 0}
							<div class="vendor-table-container">
								<table class="vendor-table">
									<thead>
										<tr>
											<th>Vendor ID</th>
											<th>Vendor Name</th>
											<th>Action</th>
										</tr>
									</thead>
									<tbody>
										{#each filteredVendors as vendor}
											<tr 
												class="vendor-row" 
												class:selected={selectedVendor?.erp_vendor_id === vendor.erp_vendor_id}
											>
												<td class="vendor-id">{vendor.erp_vendor_id}</td>
												<td class="vendor-name">{vendor.vendor_name}</td>
												<td class="vendor-action">
													<button 
														type="button" 
														class="select-vendor-btn"
														on:click={() => onVendorSelect(vendor.erp_vendor_id)}
													>
														Select
													</button>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						{:else if selectedBranch && searchTerm}
							<div class="no-vendors">
								<p>🔍 No vendors found matching "{searchTerm}" in {selectedBranch.name_en}</p>
							</div>
						{:else if selectedBranch}
							<div class="no-vendors">
								<p>⚠️ No vendors found for {selectedBranch.name_en}</p>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	{:else if currentStep === 2}
		<!-- Step 2: Payment Details Form -->
		<div class="step-container">
			<div class="step-header">
				<h2>💰 Step 2: Payment Details</h2>
				<div class="selected-info">
					<span class="info-item">
						<strong>Branch:</strong> {selectedBranch?.name_en}
					</span>
					<span class="info-item">
						<strong>Vendor:</strong> {selectedVendor?.vendor_name} (ID: {selectedVendor?.erp_vendor_id})
					</span>
					<button type="button" class="back-btn" on:click={goBackToStep1}>
						← Back to Selection
					</button>
				</div>
			</div>

			<div class="form-container">
				<form on:submit|preventDefault={savePaymentSchedule} class="payment-form">
					
					<!-- Basic Information Section -->
					<div class="form-section">
						<h3 class="section-title">📋 Basic Information</h3>
						<div class="form-grid">
							<div class="form-group">
								<label>Bill Number *</label>
								<input 
									type="text" 
									bind:value={manualForm.bill_number} 
									placeholder="Enter bill number"
									required
								>
							</div>

							<div class="form-group">
								<label>Bill Date *</label>
								<input 
									type="date" 
									bind:value={manualForm.bill_date} 
									on:change={calculateDueDate}
									required
								>
							</div>
						</div>
					</div>

					<!-- Financial Information Section -->
					<div class="form-section">
						<h3 class="section-title">💰 Financial Details</h3>
						<div class="form-grid">
							<div class="form-group">
								<label>Bill Amount *</label>
								<div class="amount-input-group">
									<input 
										type="number" 
										bind:value={manualForm.bill_amount} 
										step="0.01" 
										min="0"
										placeholder="0.00"
										required
									>
									<button type="button" class="copy-btn" on:click={copyBillAmount} title="Copy to Final Amount">
										📋
									</button>
								</div>
							</div>

							<div class="form-group">
								<label>Final Bill Amount</label>
								<input 
									type="number" 
									bind:value={manualForm.final_bill_amount} 
									step="0.01" 
									min="0"
									placeholder="Same as bill amount"
								>
							</div>

					<div class="form-group">
						<label>Payment Method</label>
						<select bind:value={manualForm.payment_method} on:change={handlePaymentMethodChange}>
							{#each paymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>
				</div>
			</div>

			<!-- Payment Information Section -->
			<div class="form-section">
				<h3 class="section-title">🏦 Payment Information</h3>
				<div class="form-grid">
					<!-- Show Bank Name and IBAN only for Bank methods -->
					{#if manualForm.payment_method && (manualForm.payment_method === 'Bank on Delivery' || manualForm.payment_method === 'Bank Credit')}
						<div class="form-group">
							<label>Bank Name</label>
							<input 
								type="text" 
								bind:value={manualForm.bank_name} 
								placeholder="Bank name"
							>
						</div>

						<div class="form-group">
							<label>IBAN</label>
							<input 
								type="text" 
								bind:value={manualForm.iban} 
								placeholder="SA00 0000 0000 0000 0000 0000"
							>
						</div>
					{:else}
						<!-- Empty placeholders when bank fields are not needed -->
						<div class="form-group placeholder-field">
							<label>Bank Name</label>
							<div class="disabled-field">Not applicable for {manualForm.payment_method || 'selected payment method'}</div>
						</div>
						<div class="form-group placeholder-field">
							<label>IBAN</label>
							<div class="disabled-field">Not applicable for {manualForm.payment_method || 'selected payment method'}</div>
						</div>
					{/if}

					<div class="form-group">
						<label>VAT Number</label>
						<input 
							type="text" 
							bind:value={manualForm.vat_number} 
							placeholder="VAT registration number"
						>
					</div>

					<!-- Show Credit Period only for Credit methods -->
					{#if manualForm.payment_method && (manualForm.payment_method === 'Cash Credit' || manualForm.payment_method === 'Bank Credit')}
						<div class="form-group">
							<label>Credit Period (Days)</label>
							<input 
								type="number" 
								bind:value={manualForm.credit_period} 
								on:input={handleCreditPeriodChange}
								min="1" 
								max="365"
								placeholder="Enter credit period in days"
							>
						</div>
					{:else if manualForm.payment_method}
						<div class="form-group placeholder-field">
							<label>Credit Period (Days)</label>
							<div class="disabled-field">Not applicable for {manualForm.payment_method}</div>
						</div>
					{/if}
				</div>
			</div>					<!-- Due Date and Notes Section -->
					<div class="form-section">
						<h3 class="section-title">📅 Schedule Information</h3>
						<div class="form-grid">
							<div class="form-group">
								<label>Due Date *</label>
								<input 
									type="date" 
									bind:value={manualForm.due_date} 
									required
								>
							</div>

							<div class="form-group full-width">
								<label>Notes</label>
								<textarea 
									bind:value={manualForm.notes} 
									rows="3"
									placeholder="Additional notes about this payment schedule..."
								></textarea>
							</div>
						</div>
					</div>

					<!-- Form Actions -->
					<div class="form-actions">
						<button type="button" class="reset-btn" on:click={resetForm} disabled={isLoading}>
							🔄 Reset Form
						</button>
						<button type="submit" class="save-btn" disabled={isLoading}>
							{#if isLoading}
								💾 Saving...
							{:else}
								💾 Save Payment Schedule
							{/if}
						</button>
					</div>
				</form>
			</div>
	</div>
	{/if}
</div>

<style>
	.manual-scheduling {
		padding: 2rem;
		background: #f8fafc;
		height: 100vh;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Step Indicator Styles */
	.step-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 2rem 0;
		padding: 1rem;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		opacity: 0.5;
		transition: all 0.3s ease;
	}

	.step.active {
		opacity: 1;
		color: #3b82f6;
	}

	.step.completed {
		opacity: 1;
		color: #22c55e;
	}

	.step-number {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: #e2e8f0;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		margin-bottom: 0.5rem;
		transition: all 0.3s ease;
	}

	.step.active .step-number {
		background: #3b82f6;
		color: white;
	}

	.step.completed .step-number {
		background: #22c55e;
		color: white;
	}

	.step-connector {
		width: 100px;
		height: 2px;
		background: #e2e8f0;
		margin: 0 1rem;
		transition: all 0.3s ease;
	}

	.step-connector.completed {
		background: #22c55e;
	}

	.step-label {
		font-size: 0.875rem;
		font-weight: 500;
		text-align: center;
	}

	/* Step Container Styles */
	.step-container {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		overflow: hidden;
	}

	.selection-content {
		padding: 2rem;
	}

	/* Dropdown Styles */
	.dropdown-container {
		margin-bottom: 2rem;
	}

	.branch-dropdown {
		width: 100%;
		padding: 0.875rem 1rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 1rem;
		background: white;
		color: #1e293b;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.branch-dropdown:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.branch-dropdown:hover {
		border-color: #cbd5e1;
	}

	/* Search Styles */
	.search-container {
		margin-bottom: 1.5rem;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
		max-width: 400px;
	}

	.search-icon {
		position: absolute;
		left: 0.875rem;
		color: #64748b;
		font-size: 1rem;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 0.875rem 1rem 0.875rem 2.5rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 1rem;
		background: white;
		transition: all 0.3s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.clear-search {
		position: absolute;
		right: 0.875rem;
		background: none;
		border: none;
		color: #64748b;
		cursor: pointer;
		font-size: 1rem;
		padding: 0.25rem;
		border-radius: 4px;
		transition: all 0.2s ease;
	}

	.clear-search:hover {
		background: #f1f5f9;
		color: #374151;
	}

	.step-header {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		padding: 2rem;
	}

	.step-header h2 {
		font-size: 1.5rem;
		font-weight: 700;
		margin: 0 0 0.5rem 0;
	}

	.step-header p {
		margin: 0;
		opacity: 0.9;
	}

	.selected-info {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 1rem;
		margin-top: 1rem;
	}

	.info-item {
		background: rgba(255, 255, 255, 0.2);
		padding: 0.5rem 1rem;
		border-radius: 8px;
		font-size: 0.875rem;
	}

	/* Branch Selection Styles */
	.selection-section {
		margin-bottom: 2rem;
	}

	.selection-section h3 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 1rem 0;
	}

	/* Vendor Table Styles */
	.vendor-table-container {
		background: white;
		border-radius: 8px;
		overflow: hidden;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		max-height: 400px;
		overflow-y: auto;
	}

	.vendor-table {
		width: 100%;
		border-collapse: collapse;
	}

	.vendor-table th {
		background: #f8fafc;
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
	}

	.vendor-table td {
		padding: 1rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.vendor-row:hover {
		background: #f8fafc;
	}

	.vendor-row.selected {
		background: #dbeafe;
	}

	.vendor-id {
		font-family: 'Courier New', monospace;
		font-weight: 600;
		color: #3b82f6;
	}

	.vendor-name {
		color: #1e293b;
	}

	.select-vendor-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.select-vendor-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.no-vendors {
		text-align: center;
		padding: 2rem;
		color: #6b7280;
	}

	.back-btn {
		background: #6b7280;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.back-btn:hover {
		background: #4b5563;
	}

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
		font-size: 1rem;
		margin: 0;
	}

	.form-container {
		max-width: 1000px;
		margin: 0 auto;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		overflow: hidden;
	}

	.payment-form {
		padding: 2rem;
	}

	.form-section {
		margin-bottom: 2rem;
		padding-bottom: 2rem;
		border-bottom: 1px solid #e2e8f0;
	}

	.form-section:last-of-type {
		border-bottom: none;
		margin-bottom: 0;
		padding-bottom: 0;
	}

	.section-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 1.5rem 0;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.form-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group.full-width {
		grid-column: 1 / -1;
	}

	.form-group label {
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
		font-size: 0.9rem;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		padding: 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.9rem;
		transition: border-color 0.3s ease;
		background: white;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-group.placeholder-field .disabled-field {
		padding: 0.75rem;
		border: 2px solid #f3f4f6;
		border-radius: 8px;
		background: #f8fafc;
		color: #9ca3af;
		font-size: 0.9rem;
		font-style: italic;
	}

	.amount-input-group {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.amount-input-group input {
		flex: 1;
	}

	.copy-btn {
		background: #f1f5f9;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		padding: 0.75rem;
		cursor: pointer;
		font-size: 0.9rem;
		transition: all 0.3s ease;
	}

	.copy-btn:hover {
		background: #e2e8f0;
		border-color: #cbd5e1;
	}

	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 1rem;
		padding-top: 2rem;
		border-top: 1px solid #e2e8f0;
		margin-top: 2rem;
	}

	.reset-btn {
		background: #6b7280;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 600;
		transition: background-color 0.3s ease;
	}

	.reset-btn:hover:not(:disabled) {
		background: #4b5563;
	}

	.save-btn {
		background: #059669;
		color: white;
		border: none;
		padding: 0.75rem 2rem;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 600;
		transition: background-color 0.3s ease;
	}

	.save-btn:hover:not(:disabled) {
		background: #047857;
	}

	.reset-btn:disabled,
	.save-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
</style>