<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';

	// State management
	let branches = [];
	let employees = [];
	let filteredEmployees = [];
	let selectedBranch = '';
	let searchTerm = '';
	let searchCriteria = 'all'; // 'all', 'name', 'employee_id'
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Contact form state
	let showContactForm = false;
	let editingEmployee = null;
	let contactFormData = {
		whatsappNumber: '',
		contactNumber: '',
		email: ''
	};

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		isLoading = true;
		errorMessage = '';

		try {
			const { data: branchesData, error: branchesError } = await dataService.branches.getAll();
			if (branchesError) {
				console.error('Error loading branches:', branchesError);
				errorMessage = 'Failed to load branches: ' + (branchesError.message || branchesError);
				return;
			}
			branches = branchesData || [];
		} catch (error) {
			errorMessage = 'Failed to load branches';
		} finally {
			isLoading = false;
		}
	}

	async function loadEmployeesByBranch(branchId) {
		if (!branchId) {
			employees = [];
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Load employees with their contact information
			const [employeesResponse, contactsResponse] = await Promise.all([
				dataService.hrEmployees.getByBranch(branchId),
				dataService.hrContacts.getByBranch(branchId)
			]);

			if (employeesResponse.error) {
				console.error('Error loading employees:', employeesResponse.error);
				errorMessage = 'Failed to load employees: ' + (employeesResponse.error.message || employeesResponse.error);
				return;
			}

			const employeesData = employeesResponse.data || [];
			const contactsData = contactsResponse.data || [];

			// Merge employee data with contact information
			employees = employeesData.map(employee => {
				const contact = contactsData.find(c => c.employee_id === employee.id);
				return {
					...employee,
					contact: contact ? {
						id: contact.id,
						whatsappNumber: contact.whatsapp_number,
						contactNumber: contact.contact_number,
						email: contact.email
					} : null
				};
			});

		} catch (error) {
			errorMessage = 'Failed to load employees';
		} finally {
			isLoading = false;
		}
	}

	function openContactForm(employee) {
		editingEmployee = employee;
		contactFormData = {
			whatsappNumber: employee.contact?.whatsappNumber || '',
			contactNumber: employee.contact?.contactNumber || '',
			email: employee.contact?.email || ''
		};
		showContactForm = true;
		errorMessage = '';
		successMessage = '';
	}

	function closeContactForm() {
		showContactForm = false;
		editingEmployee = null;
		contactFormData = {
			whatsappNumber: '',
			contactNumber: '',
			email: ''
		};
		errorMessage = '';
		successMessage = '';
	}

	async function saveContactInfo() {
		if (!editingEmployee) return;

		// Validate form data
		if (!contactFormData.email) {
			errorMessage = 'Email is required';
			return;
		}

		// Basic email validation
		const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
		if (!emailRegex.test(contactFormData.email)) {
			errorMessage = 'Please enter a valid email address';
			return;
		}

		// Validate phone numbers format (optional)
		if (contactFormData.whatsappNumber && !contactFormData.whatsappNumber.startsWith('+966')) {
			errorMessage = 'WhatsApp number should start with +966';
			return;
		}

		if (contactFormData.contactNumber && !contactFormData.contactNumber.startsWith('+966')) {
			errorMessage = 'Contact number should start with +966';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			let result;
			
			if (editingEmployee.contact && editingEmployee.contact.id) {
				// Update existing contact
				result = await dataService.hrContacts.update(editingEmployee.contact.id, {
					whatsapp_number: contactFormData.whatsappNumber,
					contact_number: contactFormData.contactNumber,
					email: contactFormData.email
				});
			} else {
				// Create new contact
				result = await dataService.hrContacts.create({
					employee_id: editingEmployee.id,
					whatsapp_number: contactFormData.whatsappNumber,
					contact_number: contactFormData.contactNumber,
					email: contactFormData.email
				});
			}

			if (result.error) {
				errorMessage = 'Failed to save contact information: ' + (result.error.message || result.error);
				return;
			}

			// Update local employee data
			const employeeIndex = employees.findIndex(emp => emp.id === editingEmployee.id);
			if (employeeIndex !== -1) {
				employees[employeeIndex] = {
					...employees[employeeIndex],
					contact: {
						id: result.data.id,
						whatsappNumber: contactFormData.whatsappNumber,
						contactNumber: contactFormData.contactNumber,
						email: contactFormData.email
					}
				};
				employees = [...employees]; // Trigger reactivity
			}

			successMessage = 'Contact information saved successfully';
			closeContactForm();

			// Clear success message after 3 seconds
			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = 'Failed to save contact information';
		} finally {
			isLoading = false;
		}
	}

	// Reactive statement to load employees when branch changes
	$: if (selectedBranch) {
		loadEmployeesByBranch(selectedBranch);
	}

	// Reactive statement to filter employees based on search
	$: {
		if (!employees.length) {
			filteredEmployees = [];
		} else if (!searchTerm.trim()) {
			filteredEmployees = employees;
		} else {
			const search = searchTerm.toLowerCase().trim();
			
			filteredEmployees = employees.filter(employee => {
				switch (searchCriteria) {
					case 'name':
						return employee.name?.toLowerCase().includes(search);
					case 'employee_id':
						return employee.employee_id?.toLowerCase().includes(search);
					case 'all':
					default:
						return (
							employee.name?.toLowerCase().includes(search) ||
							employee.employee_id?.toLowerCase().includes(search) ||
							employee.department?.toLowerCase().includes(search) ||
							employee.position?.toLowerCase().includes(search) ||
							employee.contact?.email?.toLowerCase().includes(search)
						);
				}
			});
		}
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric', month: 'short', day: 'numeric'
		});
	}

	function getBranchName(branchId) {
		const branch = branches.find(b => b.id == branchId);
		return branch ? `${branch.name_en} (${branch.name_ar})` : 'Unknown Branch';
	}

	function formatPhoneNumber(phoneNumber) {
		if (!phoneNumber) return 'N/A';
		// Format +966501234567 to +966 50 123 4567
		return phoneNumber.replace(/(\+966)(\d{2})(\d{3})(\d{4})/, '$1 $2 $3 $4');
	}

	function getStatusColor(status) {
		switch (status?.toLowerCase()) {
			case 'active': return 'text-green-600';
			case 'inactive': return 'text-red-600';
			default: return 'text-gray-600';
		}
	}

	function openWhatsApp(employee) {
		if (!employee.contact?.whatsappNumber) return;
		
		// Clean the phone number - remove spaces and ensure it starts with +
		let phoneNumber = employee.contact.whatsappNumber.replace(/\s/g, '');
		if (!phoneNumber.startsWith('+')) {
			phoneNumber = '+' + phoneNumber;
		}
		
		// Create a pre-filled message
		const message = encodeURIComponent(`Hello ${employee.name}, this is a message from the company HR team.`);
		
		// WhatsApp Web URL format
		const whatsappUrl = `https://wa.me/${phoneNumber.replace('+', '')}?text=${message}`;
		
		// Open in new tab
		window.open(whatsappUrl, '_blank');
	}
</script>

<div class="contact-management">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Contact Management</h2>
		<p class="subtitle">Manage employee contact information and communication details</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Branch Selection -->
		<div class="branch-section">
			<h3>Select Branch</h3>
			<p class="section-description">Choose a branch to view and manage employee contact information</p>
			
			<select 
				bind:value={selectedBranch}
				disabled={isLoading}
				class="branch-select"
			>
				<option value="">Choose a branch...</option>
				{#each branches as branch}
					<option value={branch.id}>
						{branch.name_en} ({branch.name_ar}) - {branch.location_en}
					</option>
				{/each}
			</select>
		</div>

		<!-- Messages -->
		{#if errorMessage}
			<div class="error-message">
				{errorMessage}
			</div>
		{/if}

		{#if successMessage}
			<div class="success-message">
				{successMessage}
			</div>
		{/if}

		<!-- Loading State -->
		{#if isLoading}
			<div class="loading-section">
				<div class="loading-spinner"></div>
				<p>Loading employees...</p>
			</div>
		{/if}

		<!-- Employees List -->
		{#if selectedBranch && !isLoading && employees.length > 0}
			<div class="employees-section">
				<div class="section-header">
					<h3>Employees</h3>
					<div class="employee-count">
						{filteredEmployees.length} of {employees.length} employee{employees.length !== 1 ? 's' : ''}
					</div>
				</div>

				<!-- Search Employees -->
				<div class="search-section">
					<h4>Search Employees</h4>
					<p class="search-description">Search for employees by name, ID, department, position, or email</p>
					
					<div class="search-controls">
						<div class="search-input-group">
							<select bind:value={searchCriteria} class="search-criteria">
								<option value="all">All Fields</option>
								<option value="name">Name Only</option>
								<option value="employee_id">Employee ID Only</option>
							</select>
							<input
								type="text"
								bind:value={searchTerm}
								placeholder="Search employees..."
								class="search-input"
							/>
						</div>
					</div>
				</div>

				<div class="table-container">
					<table class="employees-table">
						<thead>
							<tr>
								<th>Employee</th>
								<th>Department</th>
								<th>Position</th>
								<th>Contact Information</th>
								<th>Hire Date</th>
								<th>Status</th>
								<th>Contact Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredEmployees as employee (employee.id)}
								<tr class="table-row">
									<td class="employee-cell">
										<div class="employee-info">
											<div class="employee-id">{employee.employee_id}</div>
											<div class="employee-names">
												<div class="name-en">{employee.name}</div>
											</div>
										</div>
									</td>
									<td class="department-cell">{employee.department || 'N/A'}</td>
									<td class="position-cell">{employee.position || 'N/A'}</td>
									<td class="contact-cell">
										{#if employee.contact}
											<div class="contact-info">
												<div class="contact-item">
													<span class="contact-label">📧</span>
													<span class="contact-value">{employee.contact.email || 'N/A'}</span>
												</div>
												<div class="contact-item">
													<span class="contact-label">📱</span>
													<span class="contact-value">{formatPhoneNumber(employee.contact.whatsappNumber)}</span>
												</div>
												<div class="contact-item">
													<span class="contact-label">📞</span>
													<span class="contact-value">{formatPhoneNumber(employee.contact.contactNumber)}</span>
												</div>
											</div>
										{:else}
											<span class="no-contact">No contact information</span>
										{/if}
									</td>
									<td class="date-cell">{formatDate(employee.created_at)}</td>
									<td class="status-cell">
										<span class="status-badge {getStatusColor(employee.status || 'Active')}">
											{employee.status || 'Active'}
										</span>
									</td>
									<td class="actions-cell">
										<div class="action-buttons">
											<button 
												class="edit-btn" 
												on:click={() => openContactForm(employee)}
												disabled={isLoading}
											>
												{employee.contact ? 'Edit' : 'Add'} Contact
											</button>
											{#if employee.contact?.whatsappNumber}
												<button 
													class="whatsapp-btn" 
													on:click={() => openWhatsApp(employee)}
													disabled={isLoading}
													title="Send WhatsApp message to {employee.name}"
												>
													<span class="whatsapp-icon">💬</span>
													WhatsApp
												</button>
											{/if}
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{:else if selectedBranch && !isLoading && employees.length === 0}
			<div class="empty-state">
				<div class="empty-icon">👥</div>
				<h4>No Employees Found</h4>
				<p>No employees found for the selected branch</p>
			</div>
		{/if}
	</div>

	<!-- Contact Form Modal -->
	{#if showContactForm && editingEmployee}
		<div class="modal-overlay" on:click={closeContactForm}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
					<h3>
						{editingEmployee.contact ? 'Edit' : 'Add'} Contact Information
					</h3>
					<button class="close-btn" on:click={closeContactForm}>✕</button>
				</div>

				<div class="modal-body">
					<div class="employee-info-display">
						<h4>{editingEmployee.name}</h4>
						<p>{editingEmployee.employee_id} • {editingEmployee.position || 'N/A'}</p>
					</div>

					<form on:submit|preventDefault={saveContactInfo}>
						<div class="form-group">
							<label for="email">Email Address *</label>
							<input
								type="email"
								id="email"
								bind:value={contactFormData.email}
								placeholder="employee@company.com"
								required
								disabled={isLoading}
							/>
						</div>

						<div class="form-group">
							<label for="whatsapp">WhatsApp Number</label>
							<input
								type="tel"
								id="whatsapp"
								bind:value={contactFormData.whatsappNumber}
								placeholder="+966501234567"
								disabled={isLoading}
							/>
						</div>

						<div class="form-group">
							<label for="contact">Contact Number</label>
							<input
								type="tel"
								id="contact"
								bind:value={contactFormData.contactNumber}
								placeholder="+966112345678"
								disabled={isLoading}
							/>
						</div>

						{#if errorMessage}
							<div class="form-error">
								{errorMessage}
							</div>
						{/if}

						<div class="form-actions">
							<button type="button" class="cancel-btn" on:click={closeContactForm} disabled={isLoading}>
								Cancel
							</button>
							<button type="submit" class="save-btn" disabled={isLoading}>
								{isLoading ? 'Saving...' : 'Save Contact'}
							</button>
						</div>
					</form>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.contact-management {
		padding: 24px;
		height: 100%;
		overflow-y: auto;
		background: white;
	}

	.header {
		margin-bottom: 24px;
	}

	.title {
		color: #1f2937;
		font-size: 24px;
		font-weight: 700;
		margin: 0 0 8px 0;
	}

	.subtitle {
		color: #6b7280;
		font-size: 16px;
		margin: 0;
	}

	.content {
		display: flex;
		flex-direction: column;
		gap: 24px;
	}

	.branch-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
	}

	.branch-section h3 {
		color: #1f2937;
		font-size: 18px;
		font-weight: 600;
		margin: 0 0 8px 0;
	}

	.section-description {
		color: #6b7280;
		font-size: 14px;
		margin: 0 0 16px 0;
	}

	.branch-select {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 16px;
		background: white;
		color: #1f2937;
		transition: border-color 0.2s ease;
	}

	.branch-select:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.branch-select:disabled {
		background: #f9fafb;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
		font-size: 14px;
	}

	.success-message {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #16a34a;
		padding: 12px 16px;
		border-radius: 8px;
		font-size: 14px;
	}

	.loading-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 40px;
		gap: 16px;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.employees-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.section-header h3 {
		color: #1f2937;
		font-size: 18px;
		font-weight: 600;
		margin: 0;
	}

	.employee-count {
		background: #3b82f6;
		color: white;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 14px;
		font-weight: 500;
	}

	.search-section {
		padding: 20px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
	}

	.search-section h4 {
		color: #1f2937;
		font-size: 16px;
		font-weight: 600;
		margin: 0 0 4px 0;
	}

	.search-description {
		color: #6b7280;
		font-size: 14px;
		margin: 0 0 16px 0;
	}

	.search-controls {
		display: flex;
		gap: 16px;
		align-items: flex-start;
	}

	.search-input-group {
		display: flex;
		gap: 12px;
		align-items: center;
		flex: 1;
	}

	.search-criteria {
		padding: 10px 14px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		background: white;
		color: #1f2937;
		font-size: 14px;
		min-width: 140px;
		transition: border-color 0.2s ease;
	}

	.search-criteria:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.search-input {
		flex: 1;
		padding: 10px 16px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 16px;
		background: white;
		color: #1f2937;
		transition: border-color 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.search-input::placeholder {
		color: #9ca3af;
	}

	.table-container {
		overflow-x: auto;
	}

	.employees-table {
		width: 100%;
		border-collapse: collapse;
	}

	.employees-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.employees-table td {
		padding: 16px;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: top;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.employee-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.employee-id {
		font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
		font-size: 13px;
		color: #6b7280;
		font-weight: 500;
	}

	.employee-names .name-en {
		font-weight: 600;
		color: #1f2937;
		font-size: 14px;
	}

	.contact-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.contact-item {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 13px;
	}

	.contact-label {
		font-size: 12px;
	}

	.contact-value {
		color: #374151;
	}

	.no-contact {
		color: #9ca3af;
		font-style: italic;
		font-size: 13px;
	}

	.date-cell {
		color: #6b7280;
		font-size: 13px;
		white-space: nowrap;
	}

	.status-badge {
		font-size: 12px;
		font-weight: 500;
		text-transform: uppercase;
	}

	.edit-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 8px 14px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
		min-width: 90px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.edit-btn:hover {
		background: #2563eb;
	}

	.edit-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.action-buttons {
		display: flex;
		gap: 6px;
		align-items: center;
		justify-content: flex-start;
	}

	.whatsapp-btn {
		background: #25d366;
		color: white;
		border: none;
		padding: 8px 12px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 4px;
		min-width: 85px;
		height: 32px;
	}

	.whatsapp-btn:hover {
		background: #128c7e;
	}

	.whatsapp-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.whatsapp-icon {
		font-size: 14px;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 60px 20px;
		text-align: center;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
		opacity: 0.5;
	}

	.empty-state h4 {
		color: #1f2937;
		font-size: 18px;
		font-weight: 600;
		margin: 0 0 8px 0;
	}

	.empty-state p {
		color: #6b7280;
		margin: 0;
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
		padding: 20px;
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		max-width: 500px;
		width: 100%;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		color: #1f2937;
		font-size: 18px;
		font-weight: 600;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 20px;
		color: #6b7280;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		transition: background 0.2s ease;
	}

	.close-btn:hover {
		background: #f3f4f6;
	}

	.modal-body {
		padding: 20px;
	}

	.employee-info-display {
		margin-bottom: 24px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
	}

	.employee-info-display h4 {
		color: #1f2937;
		font-size: 16px;
		font-weight: 600;
		margin: 0 0 4px 0;
	}

	.employee-info-display p {
		color: #6b7280;
		font-size: 14px;
		margin: 0;
	}

	.form-group {
		margin-bottom: 20px;
	}

	.form-group label {
		display: block;
		color: #374151;
		font-size: 14px;
		font-weight: 500;
		margin-bottom: 6px;
	}

	.form-group input {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 16px;
		transition: border-color 0.2s ease;
		box-sizing: border-box;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.form-group input:disabled {
		background: #f9fafb;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.form-error {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
		font-size: 14px;
		margin-bottom: 20px;
	}

	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
	}

	.cancel-btn {
		background: #f9fafb;
		color: #374151;
		border: 1px solid #d1d5db;
		padding: 12px 24px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.cancel-btn:hover {
		background: #f3f4f6;
	}

	.save-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 12px 24px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.save-btn:hover {
		background: #2563eb;
	}

	.cancel-btn:disabled,
	.save-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.contact-management {
			padding: 16px;
		}

		.search-input-group {
			flex-direction: column;
			gap: 8px;
		}

		.search-criteria {
			width: 100%;
			min-width: auto;
		}

		.table-container {
			font-size: 14px;
		}

		.employees-table th,
		.employees-table td {
			padding: 12px 8px;
		}

		.action-buttons {
			flex-direction: column;
			gap: 4px;
			align-items: stretch;
		}

		.edit-btn,
		.whatsapp-btn {
			font-size: 12px;
			padding: 6px 12px;
			height: 28px; /* Slightly smaller for mobile */
			min-height: 28px;
		}

		.modal-content {
			margin: 20px;
			max-height: calc(100vh - 40px);
		}

		.form-actions {
			flex-direction: column;
		}

		.form-actions button {
			width: 100%;
		}
	}
</style>