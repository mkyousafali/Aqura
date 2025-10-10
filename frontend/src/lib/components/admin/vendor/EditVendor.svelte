<script>
	export let vendor;
	export let onSave;
	export let onCancel;

	import { supabase } from '$lib/utils/supabase';

	// Payment method options
	const paymentMethods = ['Cash on Delivery', 'Bank on Delivery', 'Cash Credit', 'Bank Credit'];

	// Edit form data
	let editData = { ...vendor };
	let isSaving = false;
	let error = null;

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

	// Check if category needs location fields
	function needsLocationFields(category) {
		const categoriesWithLocation = ['Warehouse', 'Company Direct', 'Manufacturer'];
		return categoriesWithLocation.includes(category);
	}

	// Handle category change
	function handleCategoryChange() {
		// Clear location fields if not needed
		if (!needsLocationFields(editData.vendor_category)) {
			editData.warehouse_location = null;
			editData.location_link = null;
			editData.delivery_method = null;
		}
		
		// Handle custom category creation
		if (editData.vendor_category === 'custom') {
			openCustomCategoryWindow();
		}
	}

	// Open custom category creation window
	function openCustomCategoryWindow() {
		const customCategoryName = prompt('Enter new category name:');
		if (customCategoryName && customCategoryName.trim()) {
			// For now, just set it as the category
			// In the future, this could save to a categories table
			editData.vendor_category = customCategoryName.trim();
			
			// Ask about delivery method fields
			const needsDeliveryFields = confirm('Does this category need warehouse location and delivery method fields?');
			if (!needsDeliveryFields) {
				editData.warehouse_location = null;
				editData.location_link = null;
				editData.delivery_method = null;
			}
		} else {
			// Reset to default if cancelled
			editData.vendor_category = 'Daily Fresh Vendor';
		}
	}

	// Save vendor changes
	async function saveVendor() {
		try {
			isSaving = true;
			error = null;

			const { error: updateError } = await supabase
				.from('vendors')
				.update({
					vendor_name: editData.vendor_name,
					salesman_name: editData.salesman_name || null,
					salesman_contact: editData.salesman_contact || null,
					supervisor_name: editData.supervisor_name || null,
					supervisor_contact: editData.supervisor_contact || null,
					vendor_contact_number: editData.vendor_contact_number || null,
					payment_method: editData.payment_method || null,
					credit_period: ['Cash Credit', 'Bank Credit'].includes(editData.payment_method) ? editData.credit_period : null
				})
				.eq('erp_vendor_id', editData.erp_vendor_id);

			if (updateError) throw updateError;

			onSave(editData);
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
					<label for="erp-id">ERP Vendor ID</label>
					<input 
						id="erp-id"
						type="text" 
						value={editData.erp_vendor_id}
						disabled
						class="form-input disabled"
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

		<!-- Payment Details Section -->
		<div class="form-section">
			<h3>💳 Payment Details</h3>
			<div class="form-grid">
				<div class="form-field">
					<label for="payment-method">Payment Method</label>
					<select 
						id="payment-method"
						bind:value={editData.payment_method}
						on:change={handlePaymentMethodChange}
						class="form-select"
					>
						<option value="">Select payment method...</option>
						{#each paymentMethods as method}
							<option value={method}>{method}</option>
						{/each}
					</select>
				</div>
				{#if ['Cash Credit', 'Bank Credit'].includes(editData.payment_method)}
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
				{#if ['Bank on Delivery', 'Bank Credit'].includes(editData.payment_method)}
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

		<!-- Vendor Category Section -->
		<div class="form-section">
			<h3>🏷️ Vendor Category</h3>
			<div class="form-grid">
				<div class="form-field">
					<label for="vendor-category">Vendor Category</label>
					<select 
						id="vendor-category"
						bind:value={editData.vendor_category}
						on:change={handleCategoryChange}
						class="form-select"
					>
						<option value="Daily Fresh Vendor">Daily Fresh Vendor</option>
						<option value="Warehouse">1. Warehouse</option>
						<option value="Daily Fresh">2. Daily Fresh</option>
						<option value="Sales Van">3. Sales Van</option>
						<option value="Company Direct">4. Company Direct</option>
						<option value="Manufacturer">5. Manufacturer</option>
						<option value="custom">6. Create New Category</option>
					</select>
				</div>
				
				{#if needsLocationFields(editData.vendor_category)}
					<div class="form-field">
						<label for="warehouse-location">Warehouse/Location</label>
						<input 
							id="warehouse-location"
							type="text" 
							bind:value={editData.warehouse_location}
							placeholder="Enter warehouse or location details"
							class="form-input"
						/>
					</div>
					<div class="form-field">
						<label for="location-link">Location Link</label>
						<input 
							id="location-link"
							type="url" 
							bind:value={editData.location_link}
							placeholder="Enter location link (maps, etc.)"
							class="form-input"
						/>
					</div>
					<div class="form-field">
						<label for="delivery-method">Delivery Method</label>
						<select 
							id="delivery-method"
							bind:value={editData.delivery_method}
							class="form-select"
						>
							<option value="">Select delivery method...</option>
							<option value="Delivery Available">Delivery Available</option>
							<option value="Pickup Only">Pickup Only</option>
							<option value="Both Delivery and Pickup">Both Delivery and Pickup</option>
						</select>
					</div>
				{/if}
			</div>
		</div>
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

	.form-input, .form-select {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		transition: all 0.2s;
	}

	.form-input:focus, .form-select:focus {
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
		cursor: pointer;
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

	/* Responsive Design */
	@media (max-width: 768px) {
		.edit-vendor {
			padding: 1rem;
		}

		.form-grid {
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
</style>