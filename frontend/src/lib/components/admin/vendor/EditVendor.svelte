<script>
	export let vendor;
	export let onSave;
	export let onCancel;
	export let isCreating = false; // Flag to indicate creation mode

	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	// Payment method options
	const paymentMethods = ['Cash on Delivery', 'Bank on Delivery', 'Cash Credit', 'Bank Credit'];

	// Predefined category options
	const predefinedCategories = [
		'Daily Fresh',
		'Wholesaler', 
		'Company Distributor',
		'Sales Van',
		'Maintenance Related'
	];

	// Predefined delivery mode options
	const predefinedDeliveryModes = [
		'Direct Pick Up',
		'Delivery On Site', 
		'Delivery To Parcel Companies'
	];

	// Edit form data
	let editData = { ...vendor };
	let isSaving = false;
	let error = null;

	// Branch management
	let branches = [];
	let loadingBranches = false;
	let selectedBranchId = editData.branch_id || null;

	// Category management
	let selectedCategories = editData.categories || [];
	let showNewCategoryForm = false;
	let newCategoryName = '';

	// Delivery mode management
	let selectedDeliveryModes = editData.delivery_modes || [];
	let showNewDeliveryModeForm = false;
	let newDeliveryModeName = '';

	// Payment method management
	let selectedPaymentMethods = [];
	// Initialize selected payment methods from editData
	if (editData.payment_method) {
		// Handle legacy single payment method or comma-separated string
		if (Array.isArray(editData.payment_method)) {
			selectedPaymentMethods = editData.payment_method;
		} else {
			selectedPaymentMethods = editData.payment_method.split(',').map(m => m.trim()).filter(m => m);
		}
	}

	// Return policy management
	let returnPolicies = {
		expired: editData.return_expired_products || '',
		expiredNote: editData.return_expired_products_note || '',
		nearExpiry: editData.return_near_expiry_products || '',
		nearExpiryNote: editData.return_near_expiry_products_note || '',
		overStock: editData.return_over_stock || '',
		overStockNote: editData.return_over_stock_note || '',
		damage: editData.return_damage_products || '',
		damageNote: editData.return_damage_products_note || '',
		noReturn: editData.no_return || false
	};

	// VAT management
	let vatInfo = {
		applicable: editData.vat_applicable || 'VAT Applicable',
		number: editData.vat_number || '',
		noVatNote: editData.no_vat_note || ''
	};

	// VAT options
	const vatOptions = [
		'VAT Applicable',
		'No VAT'
	];

	// Return policy options
	const returnPolicyOptions = [
		{ value: 'can_return', label: 'Can Return' },
		{ value: 'cannot_return', label: 'Cannot Return' }
	];

	// Handle category selection change
	function handleCategoryChange(category, isChecked) {
		if (isChecked) {
			if (selectedCategories.length < 5 && !selectedCategories.includes(category)) {
				selectedCategories = [...selectedCategories, category];
			}
		} else {
			selectedCategories = selectedCategories.filter(cat => cat !== category);
		}
		// Update editData
		editData.categories = selectedCategories;
	}

	// Handle category toggle from checkbox
	function handleCategoryToggle(event) {
		const category = event.target.dataset.category;
		const isChecked = event.target.checked;
		handleCategoryChange(category, isChecked);
	}

	// Add new custom category
	function addNewCategory() {
		if (!newCategoryName.trim()) {
			alert('Please enter a category name');
			return;
		}

		const trimmedName = newCategoryName.trim();
		
		// Check if category already exists
		if (predefinedCategories.includes(trimmedName) || selectedCategories.includes(trimmedName)) {
			alert('Category already exists');
			return;
		}

		// Check limit of 5 categories
		if (selectedCategories.length >= 5) {
			alert('Maximum 5 categories allowed');
			return;
		}

		// Add the new category
		selectedCategories = [...selectedCategories, trimmedName];
		editData.categories = selectedCategories;
		
		// Reset form
		newCategoryName = '';
		showNewCategoryForm = false;
	}

	// Remove category
	function removeCategory(category) {
		selectedCategories = selectedCategories.filter(cat => cat !== category);
		editData.categories = selectedCategories;
	}

	// Handle category dropdown change
	function handleCategoryDropdownChange(event) {
		const selectedCategory = event.target.value;
		if (selectedCategory && selectedCategories.length < 5 && !selectedCategories.includes(selectedCategory)) {
			selectedCategories = [...selectedCategories, selectedCategory];
			editData.categories = selectedCategories;
		}
		// Reset dropdown to placeholder
		event.target.value = '';
	}

	// Handle delivery mode selection change
	function handleDeliveryModeToggle(event) {
		const mode = event.target.dataset.deliveryMode;
		if (event.target.checked) {
			if (selectedDeliveryModes.length < 3 && !selectedDeliveryModes.includes(mode)) {
				selectedDeliveryModes = [...selectedDeliveryModes, mode];
			}
		} else {
			selectedDeliveryModes = selectedDeliveryModes.filter(dm => dm !== mode);
		}
		editData.delivery_modes = selectedDeliveryModes;
	}

	// Add new delivery mode
	function addNewDeliveryMode() {
		const trimmedName = newDeliveryModeName.trim();
		if (!trimmedName) {
			alert('Please enter a delivery mode name');
			return;
		}

		if (predefinedDeliveryModes.includes(trimmedName) || selectedDeliveryModes.includes(trimmedName)) {
			alert('This delivery mode already exists');
			return;
		}

		// Check limit of 3 delivery modes
		if (selectedDeliveryModes.length >= 3) {
			alert('Maximum 3 delivery modes allowed');
			return;
		}

		// Add the new delivery mode to predefined list and select it
		predefinedDeliveryModes.push(trimmedName);
		selectedDeliveryModes = [...selectedDeliveryModes, trimmedName];
		editData.delivery_modes = selectedDeliveryModes;
		
		// Reset form
		newDeliveryModeName = '';
		showNewDeliveryModeForm = false;
	}

	// Remove delivery mode
	function removeDeliveryMode(mode) {
		selectedDeliveryModes = selectedDeliveryModes.filter(dm => dm !== mode);
		editData.delivery_modes = selectedDeliveryModes;
	}

	// Handle delivery mode dropdown change
	function handleDeliveryModeDropdownChange(event) {
		const selectedMode = event.target.value;
		if (selectedMode && selectedDeliveryModes.length < 3 && !selectedDeliveryModes.includes(selectedMode)) {
			selectedDeliveryModes = [...selectedDeliveryModes, selectedMode];
			editData.delivery_modes = selectedDeliveryModes;
		}
		// Reset dropdown to placeholder
		event.target.value = '';
	}

	// Handle payment method selection change
	function handlePaymentMethodToggle(event) {
		const method = event.target.dataset.paymentMethod;
		if (event.target.checked) {
			if (!selectedPaymentMethods.includes(method)) {
				selectedPaymentMethods = [...selectedPaymentMethods, method];
			}
		} else {
			selectedPaymentMethods = selectedPaymentMethods.filter(pm => pm !== method);
		}
		// Update editData with comma-separated string for database compatibility
		editData.payment_method = selectedPaymentMethods.join(', ');
		
		// Clear credit period if no credit methods are selected
		const hasCredit = selectedPaymentMethods.some(method => 
			['Cash Credit', 'Bank Credit'].includes(method)
		);
		if (!hasCredit) {
			editData.credit_period = null;
		}
		
		// Clear bank fields if no bank methods are selected
		const hasBank = selectedPaymentMethods.some(method => 
			['Bank on Delivery', 'Bank Credit'].includes(method)
		);
		if (!hasBank) {
			editData.bank_name = null;
			editData.iban = null;
		}
	}

	// Remove payment method
	function removePaymentMethod(method) {
		selectedPaymentMethods = selectedPaymentMethods.filter(pm => pm !== method);
		editData.payment_method = selectedPaymentMethods.join(', ');
		
		// Clear credit period if no credit methods are selected
		const hasCredit = selectedPaymentMethods.some(m => 
			['Cash Credit', 'Bank Credit'].includes(m)
		);
		if (!hasCredit) {
			editData.credit_period = null;
		}
		
		// Clear bank fields if no bank methods are selected
		const hasBank = selectedPaymentMethods.some(m => 
			['Bank on Delivery', 'Bank Credit'].includes(m)
		);
		if (!hasBank) {
			editData.bank_name = null;
			editData.iban = null;
		}
	}

	// Check if credit period should be shown
	$: showCreditPeriod = selectedPaymentMethods.some(method => 
		['Cash Credit', 'Bank Credit'].includes(method)
	);

	// Check if bank fields should be shown
	$: showBankFields = selectedPaymentMethods.some(method => 
		['Bank on Delivery', 'Bank Credit'].includes(method)
	);

	// Handle payment method change
	function handlePaymentMethodChange() {
		// Clear credit period if not a credit method
		if (!['Cash Credit', 'Bank Credit'].includes(editData.payment_method)) {
			editData.credit_period = null;
		}
		// Clear bank fields if not a bank method
		if (!['Bank on Delivery', 'Bank Credit'].includes(editData.payment_method)) {
			editData.bank_name = null;
			editData.iban = null;
		}
	}

	// Share location function
	async function shareLocationFromEdit(locationLink, vendorName) {
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

	// Component initialization
	onMount(async () => {
		await loadBranches();
	});

	// Save vendor changes
	async function saveVendor() {
		try {
			isSaving = true;
			error = null;

			// Validate mandatory fields
			if (!editData.erp_vendor_id || editData.erp_vendor_id <= 0) {
				error = 'ERP Vendor ID is required and must be a positive number';
				isSaving = false;
				return;
			}

			if (!editData.vendor_name || !editData.vendor_name.trim()) {
				error = 'Vendor Name is required';
				isSaving = false;
				return;
			}

			if (!selectedBranchId) {
				error = 'Branch selection is required';
				isSaving = false;
				return;
			}

			const vendorData = {
				vendor_name: editData.vendor_name.trim(),
				salesman_name: editData.salesman_name || null,
				salesman_contact: editData.salesman_contact || null,
				supervisor_name: editData.supervisor_name || null,
				supervisor_contact: editData.supervisor_contact || null,
				vendor_contact_number: editData.vendor_contact_number || null,
				payment_method: editData.payment_method || null,
				payment_priority: editData.payment_priority || 'Normal',
				credit_period: showCreditPeriod ? editData.credit_period : null,
				bank_name: showBankFields ? editData.bank_name : null,
				iban: showBankFields ? editData.iban : null,
				categories: selectedCategories.length > 0 ? selectedCategories : null,
				delivery_modes: selectedDeliveryModes.length > 0 ? selectedDeliveryModes : null,
				place: editData.place || null,
				location_link: editData.location_link || null,
				return_expired_products: returnPolicies.expired,
				return_expired_products_note: returnPolicies.expiredNote || null,
				return_near_expiry_products: returnPolicies.nearExpiry,
				return_near_expiry_products_note: returnPolicies.nearExpiryNote || null,
				return_over_stock: returnPolicies.overStock,
				return_over_stock_note: returnPolicies.overStockNote || null,
				return_damage_products: returnPolicies.damage,
				return_damage_products_note: returnPolicies.damageNote || null,
				no_return: returnPolicies.noReturn,
				vat_applicable: vatInfo.applicable,
				vat_number: vatInfo.number || null,
				no_vat_note: vatInfo.noVatNote || null,
				branch_id: selectedBranchId || null,
				status: editData.status || 'Active'
			};

			let result;
			if (isCreating) {
				// For creation, include ERP vendor ID and add created timestamp
				vendorData.erp_vendor_id = editData.erp_vendor_id;
				vendorData.created_at = new Date().toISOString();
				
				const { data, error: createError } = await supabase
					.from('vendors')
					.insert(vendorData)
					.select()
					.single();

				if (createError) throw createError;
				result = data;
			} else {
				// For updates, use both erp_vendor_id and original branch_id to uniquely identify the vendor
				const originalBranchId = vendor.branch_id;
				const { data, error: updateError } = await supabase
					.from('vendors')
					.update(vendorData)
					.eq('erp_vendor_id', vendor.erp_vendor_id)
					.eq('branch_id', originalBranchId)
					.select()
					.single();

				if (updateError) throw updateError;
				result = data;
			}

			// Call onSave with the result data
			onSave(result);
		} catch (err) {
			error = err.message;
		} finally {
			isSaving = false;
		}
	}

	// Cancel editing
	function cancel() {
		onCancel();
	}
</script>

<div class="edit-vendor">
	<!-- Header -->
	<div class="header">
		<h1 class="title">✏️ Edit Vendor</h1>
		<p class="subtitle">Update vendor information</p>
	</div>

	{#if error}
		<div class="error-message">
			<span class="error-icon">⚠️</span>
			<p>Error: {error}</p>
		</div>
	{/if}

	<!-- Edit Form -->
	<div class="edit-form">
		<!-- Basic Information Section -->
		<div class="form-section">
			<h3>📋 Basic Information</h3>
			<div class="form-grid">
				<div class="form-field">
					<label for="erp-id">ERP Vendor ID *</label>
					<input 
						id="erp-id"
						type="number" 
						bind:value={editData.erp_vendor_id}
						disabled={!isCreating}
						placeholder={isCreating ? "Enter ERP vendor ID" : ""}
						class="form-input {isCreating ? '' : 'disabled'}"
						min="1"
						step="1"
						required
					/>
				</div>
				<div class="form-field">
					<label for="vendor-name">Vendor Name *</label>
					<input 
						id="vendor-name"
						type="text" 
						bind:value={editData.vendor_name}
						placeholder="Enter vendor name"
						class="form-input"
						required
					/>
				</div>
				<div class="form-field">
					<label for="branch-select">Branch *</label>
					{#if loadingBranches}
						<div class="loading-state">Loading branches...</div>
					{:else}
						<select 
							id="branch-select"
							bind:value={selectedBranchId}
							class="form-select"
							required
						>
							<option value="">Choose a branch...</option>
							{#each branches as branch}
								<option value={branch.id}>
									{branch.name_en} ({branch.name_ar}) - {branch.location_en}
								</option>
							{/each}
						</select>
					{/if}
				</div>
			</div>
		</div>

		<!-- Contacts Section -->
		<div class="form-section">
			<h3>📞 Contacts</h3>
			<div class="contact-subsections">
				<!-- Salesman Contact -->
				<div class="contact-subsection">
					<h4>👤 Salesman Information</h4>
					<div class="form-grid">
						<div class="form-field">
							<label for="salesman-name">Salesman Name</label>
							<input 
								id="salesman-name"
								type="text" 
								bind:value={editData.salesman_name}
								placeholder="Enter salesman name"
								class="form-input"
							/>
						</div>
						<div class="form-field">
							<label for="salesman-contact">Salesman Contact</label>
							<input 
								id="salesman-contact"
								type="text" 
								bind:value={editData.salesman_contact}
								placeholder="Enter salesman contact"
								class="form-input"
							/>
						</div>
					</div>
				</div>

				<!-- Supervisor Contact -->
				<div class="contact-subsection">
					<h4>👨‍💼 Supervisor Information</h4>
					<div class="form-grid">
						<div class="form-field">
							<label for="supervisor-name">Supervisor Name</label>
							<input 
								id="supervisor-name"
								type="text" 
								bind:value={editData.supervisor_name}
								placeholder="Enter supervisor name"
								class="form-input"
							/>
						</div>
						<div class="form-field">
							<label for="supervisor-contact">Supervisor Contact</label>
							<input 
								id="supervisor-contact"
								type="text" 
								bind:value={editData.supervisor_contact}
								placeholder="Enter supervisor contact"
								class="form-input"
							/>
						</div>
					</div>
				</div>

				<!-- Vendor Contact -->
				<div class="contact-subsection">
					<h4>🏢 Vendor Contact</h4>
					<div class="form-grid">
						<div class="form-field">
							<label for="vendor-contact">Vendor Contact Number</label>
							<input 
								id="vendor-contact"
								type="text" 
								bind:value={editData.vendor_contact_number}
								placeholder="Enter vendor contact number"
								class="form-input"
							/>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Place & Location Section -->
		<div class="form-section">
			<h3>📍 Place & Location</h3>
			<div class="form-grid">
				<div class="form-field">
					<label for="place">Place/Area</label>
					<input 
						id="place"
						type="text" 
						bind:value={editData.place}
						placeholder="Enter vendor place or area"
						class="form-input"
					/>
				</div>
				<div class="form-field">
					<label for="location-link">Location Link</label>
					<input 
						id="location-link"
						type="url" 
						bind:value={editData.location_link}
						placeholder="Enter Google Maps link or location URL"
						class="form-input"
					/>
				</div>
			</div>
			{#if editData.location_link}
				<div class="location-preview">
					<p class="location-preview-label">📍 Location Preview:</p>
					<div class="location-preview-actions">
						<a 
							href={editData.location_link} 
							target="_blank" 
							rel="noopener noreferrer"
							class="location-link-preview"
						>
							🗺️ Open Location in Maps
						</a>
						<button 
							type="button"
							class="share-location-preview-btn"
							on:click={() => shareLocationFromEdit(editData.location_link, editData.vendor_name)}
							title="Share Location"
						>
							📤 Share Location
						</button>
					</div>
				</div>
			{/if}
		</div>

		<!-- Payment Details Section -->
		<div class="form-section">
			<h3>💳 Payment Details</h3>
			<div class="form-grid">
				<div class="form-field">
					<fieldset>
						<legend>Payment Methods</legend>
						<div class="checkbox-group">
							{#each paymentMethods as method}
								<label class="checkbox-label">
									<input 
										type="checkbox"
										data-payment-method={method}
										checked={selectedPaymentMethods.includes(method)}
										on:change={handlePaymentMethodToggle}
										class="checkbox-input"
									/>
									<span class="checkbox-text">
										{method}
										{#if ['Cash Credit', 'Bank Credit'].includes(method)}
											<span class="credit-indicator" title="Requires credit period">💳</span>
										{/if}
										{#if ['Bank on Delivery', 'Bank Credit'].includes(method)}
											<span class="bank-indicator" title="Requires bank details">🏦</span>
										{/if}
									</span>
								</label>
							{/each}
						</div>
					</fieldset>
					{#if selectedPaymentMethods.length > 0}
						<div class="selected-methods">
							<small class="field-hint">Selected methods:</small>
							<div class="method-tags">
								{#each selectedPaymentMethods as method}
									<span class="method-tag">
										{method}
										<button 
											type="button"
											class="remove-tag-btn"
											on:click={() => removePaymentMethod(method)}
											title="Remove {method}"
										>
											×
										</button>
									</span>
								{/each}
							</div>
						</div>
					{/if}
				</div>
				
				<div class="form-field">
					<label for="payment-priority">Payment Priority</label>
					<select 
						id="payment-priority"
						bind:value={editData.payment_priority}
						class="form-select"
					>
						<option value="Most">Most</option>
						<option value="Medium">Medium</option>
						<option value="Normal" selected>Normal</option>
						<option value="Low">Low</option>
					</select>
					<small class="field-hint">Priority level for payment processing (optional)</small>
				</div>

				{#if showCreditPeriod}
					<div class="form-field credit-field">
						<label for="credit-period">Credit Period (Days)</label>
						<input 
							id="credit-period"
							type="number" 
							bind:value={editData.credit_period}
							placeholder="Enter credit days"
							min="1"
							max="365"
							class="form-input"
						/>
						<small class="field-hint">Enter number of days for credit payment</small>
					</div>
				{/if}
				{#if showBankFields}
					<div class="form-field">
						<label for="bank-name">Bank Name</label>
						<input 
							id="bank-name"
							type="text" 
							bind:value={editData.bank_name}
							placeholder="Enter bank name"
							class="form-input"
						/>
						<small class="field-hint">Enter the bank name for transactions</small>
					</div>
					<div class="form-field">
						<label for="iban">IBAN</label>
						<input 
							id="iban"
							type="text" 
							bind:value={editData.iban}
							placeholder="Enter IBAN number"
							class="form-input"
							maxlength="34"
						/>
						<small class="field-hint">International Bank Account Number</small>
					</div>
				{/if}
			</div>
		</div>
	</div>

	<!-- Vendor Categories Section -->
	<div class="form-section">
		<h3>🏷️ Vendor Categories</h3>
		<p class="section-description">Select up to 5 categories for this vendor</p>
		
		<!-- Category Dropdown -->
		<div class="form-field">
			<label for="category-dropdown">Add Category</label>
			<select 
				id="category-dropdown" 
				class="form-input category-dropdown"
				on:change={handleCategoryDropdownChange}
				disabled={selectedCategories.length >= 5}
			>
				<option value="">-- Select a category --</option>
				{#each predefinedCategories as category}
					{#if !selectedCategories.includes(category)}
						<option value={category}>{category}</option>
					{/if}
				{/each}
			</select>
		</div>
		
		<!-- Predefined Categories (Checkboxes Alternative) -->
		<div class="categories-grid">
			<h4>Or select from checkboxes:</h4>
			{#each predefinedCategories as category}
				<label class="category-checkbox">
					<input 
						type="checkbox" 
						checked={selectedCategories.includes(category)}
						on:change={handleCategoryToggle}
						data-category={category}
						disabled={!selectedCategories.includes(category) && selectedCategories.length >= 5}
					/>
					<span class="category-label">{category}</span>
				</label>
			{/each}
		</div>

		<!-- Selected Categories Display -->
		{#if selectedCategories.length > 0}
			<div class="selected-categories">
				<h4>Selected Categories ({selectedCategories.length}/5):</h4>
				<div class="category-badges">
					{#each selectedCategories as category}
						<span class="category-badge">
							{category}
							<button type="button" class="remove-category" on:click={() => removeCategory(category)}>×</button>
						</span>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Add Custom Category -->
		<div class="custom-category-section">
			{#if !showNewCategoryForm}
				<button 
					type="button" 
					class="add-category-btn"
					on:click={() => showNewCategoryForm = true}
					disabled={selectedCategories.length >= 5}
				>
					➕ Create New Category
				</button>
			{:else}
				<div class="new-category-form">
					<div class="form-field">
						<label for="new-category">New Category Name</label>
						<input 
							id="new-category"
							type="text" 
							bind:value={newCategoryName}
							placeholder="Enter category name"
							class="form-input"
							maxlength="50"
						/>
					</div>
					<div class="form-actions-inline">
						<button type="button" class="save-category-btn" on:click={addNewCategory}>
							✅ Add Category
						</button>
						<button type="button" class="cancel-category-btn" on:click={() => {showNewCategoryForm = false; newCategoryName = '';}}>
							❌ Cancel
						</button>
					</div>
				</div>
			{/if}
		</div>
	</div>

	<!-- Vendor Delivery Modes Section -->
	<div class="form-section">
		<h3>🚚 Delivery Modes</h3>
		<p class="section-description">Select up to 3 delivery modes for this vendor</p>
		
		<!-- Delivery Mode Dropdown -->
		<div class="form-field">
			<label for="delivery-mode-dropdown">Add Delivery Mode</label>
			<select 
				id="delivery-mode-dropdown" 
				class="form-input delivery-mode-dropdown"
				on:change={handleDeliveryModeDropdownChange}
				disabled={selectedDeliveryModes.length >= 3}
			>
				<option value="">-- Select a delivery mode --</option>
				{#each predefinedDeliveryModes as mode}
					{#if !selectedDeliveryModes.includes(mode)}
						<option value={mode}>{mode}</option>
					{/if}
				{/each}
			</select>
		</div>
		
		<!-- Predefined Delivery Modes (Checkboxes Alternative) -->
		<div class="delivery-modes-grid">
			<h4>Or select from checkboxes:</h4>
			{#each predefinedDeliveryModes as mode}
				<label class="delivery-mode-checkbox">
					<input 
						type="checkbox" 
						checked={selectedDeliveryModes.includes(mode)}
						on:change={handleDeliveryModeToggle}
						data-delivery-mode={mode}
						disabled={!selectedDeliveryModes.includes(mode) && selectedDeliveryModes.length >= 3}
					/>
					<span class="delivery-mode-label">{mode}</span>
				</label>
			{/each}
		</div>

		<!-- Selected Delivery Modes Display -->
		{#if selectedDeliveryModes.length > 0}
			<div class="selected-delivery-modes">
				<h4>Selected Delivery Modes ({selectedDeliveryModes.length}/3):</h4>
				<div class="delivery-mode-badges">
					{#each selectedDeliveryModes as mode}
						<span class="delivery-mode-badge">
							{mode}
							<button type="button" class="remove-delivery-mode" on:click={() => removeDeliveryMode(mode)}>×</button>
						</span>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Add Custom Delivery Mode -->
		<div class="custom-delivery-mode-section">
			{#if !showNewDeliveryModeForm}
				<button 
					type="button" 
					class="add-delivery-mode-btn"
					on:click={() => showNewDeliveryModeForm = true}
					disabled={selectedDeliveryModes.length >= 3}
				>
					➕ Create New Delivery Mode
				</button>
			{:else}
				<div class="new-delivery-mode-form">
					<div class="form-field">
						<label for="new-delivery-mode">New Delivery Mode Name</label>
						<input 
							id="new-delivery-mode"
							type="text" 
							bind:value={newDeliveryModeName}
							placeholder="Enter delivery mode name"
							class="form-input"
							maxlength="50"
						/>
					</div>
					<div class="form-actions-inline">
						<button type="button" class="save-delivery-mode-btn" on:click={addNewDeliveryMode}>
							✅ Add Delivery Mode
						</button>
						<button type="button" class="cancel-delivery-mode-btn" on:click={() => {showNewDeliveryModeForm = false; newDeliveryModeName = '';}}>
							❌ Cancel
						</button>
					</div>
				</div>
			{/if}
		</div>
	</div>

	<!-- Return Policy Section -->
	<div class="form-section">
		<h3>🔄 Return Policy</h3>
		
		<!-- No Return Option -->
		<div class="form-group">
			<label class="checkbox-label">
				<input 
					type="checkbox" 
					bind:checked={returnPolicies.noReturn}
					on:change={() => {
						if (returnPolicies.noReturn) {
							// If no return is checked, reset all other policies
							returnPolicies.expired = '';
							returnPolicies.nearExpiry = '';
							returnPolicies.overStock = '';
							returnPolicies.damage = '';
							returnPolicies.expiredNote = '';
							returnPolicies.nearExpiryNote = '';
							returnPolicies.overStockNote = '';
							returnPolicies.damageNote = '';
						}
					}}
				/>
				🚫 No Returns Accepted
			</label>
		</div>

		{#if !returnPolicies.noReturn}
			<!-- Expired Products -->
			<div class="form-group">
				<label for="return-expired">Expired Products</label>
				<select 
					id="return-expired"
					bind:value={returnPolicies.expired}
					class="form-input"
				>
					<option value="">Select policy</option>
					{#each returnPolicyOptions as option}
						<option value={option.value}>{option.label}</option>
					{/each}
				</select>
				{#if returnPolicies.expired}
					<textarea 
						placeholder="Add notes for expired products return policy..."
						bind:value={returnPolicies.expiredNote}
						class="form-input return-note"
						rows="2"
					></textarea>
				{/if}
			</div>

			<!-- Near Expiry Products -->
			<div class="form-group">
				<label for="return-near-expiry">Near Expiry Products</label>
				<select 
					id="return-near-expiry"
					bind:value={returnPolicies.nearExpiry}
					class="form-input"
				>
					<option value="">Select policy</option>
					{#each returnPolicyOptions as option}
						<option value={option.value}>{option.label}</option>
					{/each}
				</select>
				{#if returnPolicies.nearExpiry}
					<textarea 
						placeholder="Add notes for near expiry products return policy..."
						bind:value={returnPolicies.nearExpiryNote}
						class="form-input return-note"
						rows="2"
					></textarea>
				{/if}
			</div>

			<!-- Over Stock Products -->
			<div class="form-group">
				<label for="return-over-stock">Over Stock Products</label>
				<select 
					id="return-over-stock"
					bind:value={returnPolicies.overStock}
					class="form-input"
				>
					<option value="">Select policy</option>
					{#each returnPolicyOptions as option}
						<option value={option.value}>{option.label}</option>
					{/each}
				</select>
				{#if returnPolicies.overStock}
					<textarea 
						placeholder="Add notes for over stock products return policy..."
						bind:value={returnPolicies.overStockNote}
						class="form-input return-note"
						rows="2"
					></textarea>
				{/if}
			</div>

			<!-- Damage Products -->
			<div class="form-group">
				<label for="return-damage">Damage Products</label>
				<select 
					id="return-damage"
					bind:value={returnPolicies.damage}
					class="form-input"
				>
					<option value="">Select policy</option>
					{#each returnPolicyOptions as option}
						<option value={option.value}>{option.label}</option>
					{/each}
				</select>
				{#if returnPolicies.damage}
					<textarea 
						placeholder="Add notes for damage products return policy..."
						bind:value={returnPolicies.damageNote}
						class="form-input return-note"
						rows="2"
					></textarea>
				{/if}
			</div>
		{/if}
	</div>

	<!-- VAT Section -->
	<div class="form-section">
		<h3>💰 VAT Information</h3>
		
		<!-- VAT Applicable Dropdown -->
		<div class="form-group">
			<label for="vat-applicable">VAT Status</label>
			<select 
				id="vat-applicable"
				bind:value={vatInfo.applicable}
				class="form-input"
				on:change={() => {
					// Clear fields when switching VAT status
					if (vatInfo.applicable === 'No VAT') {
						vatInfo.number = '';
					} else {
						vatInfo.noVatNote = '';
					}
				}}
			>
				{#each vatOptions as option}
					<option value={option}>{option}</option>
				{/each}
			</select>
		</div>

		<!-- VAT Number Field (shown when VAT Applicable) -->
		{#if vatInfo.applicable === 'VAT Applicable'}
			<div class="form-group">
				<label for="vat-number">VAT Number</label>
				<input 
					type="text"
					id="vat-number"
					bind:value={vatInfo.number}
					placeholder="Enter VAT number..."
					class="form-input"
				/>
			</div>
		{/if}

		<!-- No VAT Note Field (shown when No VAT) -->
		{#if vatInfo.applicable === 'No VAT'}
			<div class="form-group">
				<label for="no-vat-note">No VAT Note</label>
				<textarea 
					id="no-vat-note"
					bind:value={vatInfo.noVatNote}
					placeholder="Add note for why VAT is not applicable..."
					class="form-input vat-note"
					rows="3"
				></textarea>
			</div>
		{/if}
	</div>

	<!-- Action Buttons -->
	<div class="action-section">
		<button 
			class="save-button" 
			on:click={saveVendor}
			disabled={isSaving || !editData.vendor_name}
		>
			{#if isSaving}
				⏳ Saving...
			{:else}
				💾 Save Changes
			{/if}
		</button>
		<button 
			class="cancel-button" 
			on:click={cancel}
			disabled={isSaving}
		>
			❌ Cancel
		</button>
	</div>
</div>

<style>
	.edit-vendor {
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
		font-size: 1.75rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
	}

	/* Error Message */
	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 1rem;
		margin-bottom: 1.5rem;
		color: #dc2626;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.error-icon {
		font-size: 1.25rem;
	}

	/* Form Sections */
	.edit-form {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.form-section {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.form-section h3 {
		font-size: 1.125rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 1rem;
		padding-bottom: 0.5rem;
		border-bottom: 2px solid #e5e7eb;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	/* Contact Subsections */
	.contact-subsections {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.contact-subsection {
		background: #f8fafc;
		border-radius: 8px;
		padding: 1rem;
		border-left: 4px solid #3b82f6;
	}

	.contact-subsection h4 {
		font-size: 1rem;
		font-weight: 500;
		color: #4b5563;
		margin-bottom: 1rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.form-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1rem;
	}

	.form-field {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-field label {
		font-weight: 500;
		color: #374151;
		font-size: 0.875rem;
	}

	.form-input {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input.disabled {
		background: #f3f4f6;
		color: #6b7280;
		cursor: not-allowed;
	}

	.form-select {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		transition: all 0.2s;
		cursor: pointer;
	}

	.form-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.loading-state {
		padding: 0.75rem;
		color: #64748b;
		font-style: italic;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
	}

	/* Place & Location Styles */
	.location-preview {
		margin-top: 1rem;
		padding: 1rem;
		background: #f0f9ff;
		border: 1px solid #bfdbfe;
		border-radius: 8px;
	}

	.location-preview-label {
		margin: 0 0 0.75rem 0;
		font-size: 0.875rem;
		font-weight: 600;
		color: #1e40af;
	}

	.location-preview-actions {
		display: flex;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	.location-link-preview {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		text-decoration: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.2s;
	}

	.location-link-preview:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.share-location-preview-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.share-location-preview-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	/* Action Buttons */
	.action-section {
		display: flex;
		justify-content: center;
		gap: 1rem;
		padding-top: 1rem;
		border-top: 1px solid #e5e7eb;
	}

	.save-button, .cancel-button {
		padding: 0.875rem 2rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 140px;
	}

	.save-button {
		background: #3b82f6;
		color: white;
	}

	.save-button:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.save-button:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.cancel-button {
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.cancel-button:hover:not(:disabled) {
		background: #e5e7eb;
		transform: translateY(-1px);
	}

	.cancel-button:disabled {
		background: #f9fafb;
		color: #9ca3af;
		cursor: not-allowed;
		transform: none;
	}

	/* Category Styles */
	.section-description {
		color: #6b7280;
		font-size: 0.875rem;
		margin-bottom: 1rem;
	}

	.categories-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.categories-grid h4 {
		grid-column: 1 / -1;
		margin: 0 0 0.5rem 0;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.category-dropdown {
		background-color: white;
		border: 2px solid #e5e7eb;
		transition: border-color 0.2s;
		margin-bottom: 1rem;
	}

	.category-dropdown:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.category-dropdown:disabled {
		background-color: #f3f4f6;
		cursor: not-allowed;
	}

	.category-checkbox {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		background: white;
	}

	.category-checkbox:hover {
		border-color: #3b82f6;
		background: #f8fafc;
	}

	.category-checkbox input[type="checkbox"] {
		margin: 0;
	}

	.category-checkbox input[type="checkbox"]:disabled {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.category-checkbox:has(input[type="checkbox"]:disabled) {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.category-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.selected-categories {
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		padding: 1rem;
		margin-bottom: 1.5rem;
	}

	.selected-categories h4 {
		font-size: 0.875rem;
		font-weight: 600;
		color: #0369a1;
		margin-bottom: 0.75rem;
	}

	.category-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.category-badge {
		background: #3b82f6;
		color: white;
		padding: 0.25rem 0.75rem;
		border-radius: 16px;
		font-size: 0.75rem;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.remove-category {
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: none;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 12px;
		transition: all 0.2s;
	}

	.remove-category:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	.custom-category-section {
		border-top: 1px solid #e5e7eb;
		padding-top: 1rem;
	}

	/* Delivery Modes Styles */
	.delivery-modes-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.delivery-modes-grid h4 {
		grid-column: 1 / -1;
		margin: 0 0 0.5rem 0;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.delivery-mode-dropdown {
		background-color: white;
		border: 2px solid #e5e7eb;
		transition: border-color 0.2s;
		margin-bottom: 1rem;
	}

	.delivery-mode-dropdown:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.1);
	}

	.delivery-mode-dropdown:disabled {
		background-color: #f3f4f6;
		cursor: not-allowed;
	}

	.delivery-mode-checkbox {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		background: white;
	}

	.delivery-mode-checkbox:hover {
		border-color: #f59e0b;
		background: #fffbeb;
	}

	.delivery-mode-checkbox input[type="checkbox"] {
		margin: 0;
	}

	.delivery-mode-checkbox input[type="checkbox"]:disabled {
		cursor: not-allowed;
	}

	.delivery-mode-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.selected-delivery-modes {
		margin-bottom: 1.5rem;
	}

	.selected-delivery-modes h4 {
		margin: 0 0 0.75rem 0;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.delivery-mode-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.delivery-mode-badge {
		background: #f59e0b;
		color: white;
		padding: 0.25rem 0.75rem;
		border-radius: 16px;
		font-size: 0.75rem;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.remove-delivery-mode {
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: none;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 12px;
		transition: all 0.2s;
	}

	.remove-delivery-mode:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	.custom-delivery-mode-section {
		border-top: 1px solid #e5e7eb;
		padding-top: 1rem;
	}

	.add-delivery-mode-btn {
		background: #f59e0b;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.add-delivery-mode-btn:hover:not(:disabled) {
		background: #d97706;
		transform: translateY(-1px);
	}

	.add-delivery-mode-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		transform: none;
	}

	.new-delivery-mode-form {
		background: #fffbeb;
		border: 1px solid #fbbf24;
		border-radius: 8px;
		padding: 1rem;
	}

	.save-delivery-mode-btn, .cancel-delivery-mode-btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.save-delivery-mode-btn {
		background: #f59e0b;
		color: white;
	}

	.save-delivery-mode-btn:hover {
		background: #d97706;
	}

	.cancel-delivery-mode-btn {
		background: #6b7280;
		color: white;
	}

	.cancel-delivery-mode-btn:hover {
		background: #4b5563;
	}

	.add-category-btn {
		background: #10b981;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.add-category-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.add-category-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		transform: none;
	}

	.new-category-form {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1rem;
	}

	.form-actions-inline {
		display: flex;
		gap: 0.75rem;
		margin-top: 0.75rem;
	}

	.save-category-btn, .cancel-category-btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.save-category-btn {
		background: #10b981;
		color: white;
	}

	.save-category-btn:hover {
		background: #059669;
	}

	.cancel-category-btn {
		background: #f3f4f6;
		color: #374151;
	}

	.cancel-category-btn:hover {
		background: #e5e7eb;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.edit-vendor {
			padding: 1rem;
		}

		.form-grid {
			grid-template-columns: 1fr;
		}

		.categories-grid {
			grid-template-columns: 1fr;
		}

		.action-section {
			flex-direction: column;
			align-items: center;
		}

		.save-button, .cancel-button {
			width: 100%;
			max-width: 300px;
		}
	}

	/* Return Policy Styles */
	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		cursor: pointer;
		color: #374151;
	}

	.checkbox-label input[type="checkbox"] {
		width: 1.25rem;
		height: 1.25rem;
		accent-color: #6366f1;
		cursor: pointer;
	}

	.return-note {
		margin-top: 0.5rem;
		font-size: 0.875rem;
		resize: vertical;
		min-height: 60px;
	}

	.return-note::placeholder {
		color: #9ca3af;
		font-style: italic;
	}

	/* VAT Styles */
	.vat-note {
		margin-top: 0.5rem;
		font-size: 0.875rem;
		resize: vertical;
		min-height: 80px;
	}

	.vat-note::placeholder {
		color: #9ca3af;
		font-style: italic;
	}

	/* Payment Method Checkbox Styles */
	fieldset {
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1rem;
		margin: 0;
	}

	legend {
		padding: 0 0.5rem;
		font-weight: 600;
		color: #374151;
	}

	.checkbox-group {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 0.75rem;
		margin-top: 0.5rem;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 6px;
		transition: background-color 0.2s;
	}

	.checkbox-label:hover {
		background-color: #f9fafb;
	}

	.checkbox-input {
		width: 16px;
		height: 16px;
		cursor: pointer;
	}

	.checkbox-text {
		font-size: 0.875rem;
		color: #374151;
	}

	.credit-indicator,
	.bank-indicator {
		margin-left: 0.25rem;
		font-size: 0.75rem;
		opacity: 0.7;
		cursor: help;
	}

	.checkbox-label:hover .credit-indicator,
	.checkbox-label:hover .bank-indicator {
		opacity: 1;
	}

	.selected-methods {
		margin-top: 1rem;
	}

	.method-tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.method-tag {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		background: #dbeafe;
		color: #1e40af;
		padding: 0.25rem 0.75rem;
		border-radius: 16px;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.remove-tag-btn {
		background: none;
		border: none;
		color: #1e40af;
		cursor: pointer;
		font-size: 1rem;
		line-height: 1;
		padding: 0;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.remove-tag-btn:hover {
		background: #1e40af;
		color: white;
	}
</style>