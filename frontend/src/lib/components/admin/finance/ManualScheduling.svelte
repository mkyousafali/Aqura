<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	// Component state
	let isLoading = false;
	let branches = [];
	let vendors = [];
	let filteredVendors = [];
	
	// Two-step form state
	let currentStep = 1;
	let selectedBranch = null;
	let selectedVendor = null;
	
	// Manual entry form for vendor_payment_schedule table
	let manualForm = {
		bill_number: '',
		bill_date: '',
		bill_amount: 0,
		final_bill_amount: 0,
		payment_method: 'Manual Transfer',
		bank_name: '',
		iban: '',
		due_date: '',
		credit_period: 30,
		vat_number: '',
		payment_status: 'scheduled',
		notes: ''
	};

	// Payment method options
	const paymentMethods = [
		'Manual Transfer',
		'Bank Transfer',
		'Check',
		'Cash',
		'Credit Card',
		'Cash on Delivery'
	];

	// Payment status options
	const paymentStatuses = [
		'scheduled',
		'pending',
		'processing',
		'paid',
		'overdue',
		'cancelled'
	];

	onMount(async () => {
		await loadData();
		setDefaultDates();
	});

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
				.select('id, name_en, name_ar')
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadVendors() {
		try {
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, bank_name, iban, vat_number, branch_id')
				.order('vendor_name');

			if (error) throw error;
			vendors = data || [];
		} catch (error) {
			console.error('Error loading vendors:', error);
		}
	}

	function onBranchSelect(branchId) {
		selectedBranch = branches.find(b => b.id === branchId);
		if (selectedBranch) {
			// Filter vendors by selected branch
			filteredVendors = vendors.filter(v => v.branch_id === branchId);
			
			// Update form with branch details
			manualForm.branch_id = selectedBranch.id;
			manualForm.branch_name = selectedBranch.name_en;
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

			// Insert into vendor_payment_schedule table
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.insert({
					bill_number: manualForm.bill_number,
					erp_vendor_id: selectedVendor.erp_vendor_id,
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
					payment_status: manualForm.payment_status,
					scheduled_date: new Date().toISOString(),
					notes: manualForm.notes || `Manually created on ${new Date().toLocaleDateString()}`
				})
				.select();

			if (error) throw error;

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
		selectedVendor = null;
		filteredVendors = [];
		
		manualForm = {
			bill_number: '',
			bill_date: '',
			bill_amount: 0,
			final_bill_amount: 0,
			payment_method: 'Manual Transfer',
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
				<p>Choose a branch to see available vendors, then select the vendor for payment scheduling</p>
			</div>

			<!-- Branch Selection -->
			<div class="selection-section">
				<h3>Select Branch</h3>
				<div class="branch-grid">
					{#each branches as branch}
						<div 
							class="branch-card" 
							class:selected={selectedBranch?.id === branch.id}
							on:click={() => onBranchSelect(branch)}
							role="button"
							tabindex="0"
						>
							<div class="branch-icon">🏢</div>
							<div class="branch-name">{branch.name_en}</div>
							<div class="branch-code">{branch.id}</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- Vendor Selection (shown after branch selection) -->
			{#if selectedBranch && filteredVendors.length > 0}
				<div class="selection-section">
					<h3>Select Vendor from {selectedBranch.name_en}</h3>
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
												on:click={() => onVendorSelect(vendor)}
											>
												Select
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{:else if selectedBranch && filteredVendors.length === 0}
				<div class="no-vendors">
					<p>⚠️ No vendors found for {selectedBranch.name_en}</p>
				</div>
			{/if}
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
						<label>Vendor *</label>
						<select bind:value={manualForm.vendor_id} on:change={onVendorChange} required>
							<option value="">Select Vendor</option>
							{#each vendors as vendor}
								<option value={vendor.erp_vendor_id}>{vendor.vendor_name}</option>
							{/each}
						</select>
					</div>

					<div class="form-group">
						<label>Branch *</label>
						<select bind:value={manualForm.branch_id} on:change={onBranchChange} required>
							<option value="">Select Branch</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en}</option>
							{/each}
						</select>
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
						<select bind:value={manualForm.payment_method}>
							{#each paymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>

					<div class="form-group">
						<label>Payment Status</label>
						<select bind:value={manualForm.payment_status}>
							{#each paymentStatuses as status}
								<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
							{/each}
						</select>
					</div>
				</div>
			</div>

			<!-- Payment Information Section -->
			<div class="form-section">
				<h3 class="section-title">🏦 Payment Information</h3>
				<div class="form-grid">
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

					<div class="form-group">
						<label>VAT Number</label>
						<input 
							type="text" 
							bind:value={manualForm.vat_number} 
							placeholder="VAT registration number"
						>
					</div>

					<div class="form-group">
						<label>Credit Period (Days)</label>
						<input 
							type="number" 
							bind:value={manualForm.credit_period} 
							on:change={calculateDueDate}
							min="1" 
							max="365"
						>
					</div>
				</div>
			</div>

			<!-- Due Date and Notes Section -->
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
		padding: 2rem;
	}

	.selection-section h3 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 1rem 0;
	}

	.branch-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 1rem;
	}

	.branch-card {
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
		text-align: center;
		cursor: pointer;
		transition: all 0.3s ease;
		background: white;
	}

	.branch-card:hover {
		border-color: #3b82f6;
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(59, 130, 246, 0.1);
	}

	.branch-card.selected {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(59, 130, 246, 0.2);
	}

	.branch-icon {
		font-size: 2rem;
		margin-bottom: 0.5rem;
	}

	.branch-name {
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 0.25rem;
	}

	.branch-code {
		font-size: 0.875rem;
		color: #64748b;
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