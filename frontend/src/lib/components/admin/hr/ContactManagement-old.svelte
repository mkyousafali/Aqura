<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';

	// State management
	let branches = [];
	let employees = [];
	let selectedBranch = '';
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
		// Main Branch employees
		{
			id: 1,
			employee_id: 'EMP001',
			name_ar: 'أحمد محمد علي',
			name_en: 'Ahmed Mohammed Ali',
			email: 'ahmed.ali@company.com',
			branch_id: 1,
			department: 'Executive Management',
			position: 'Chief Executive Officer',
			hire_date: '2020-01-15',
			status: 'Active',
			contact: {
				whatsappNumber: '+966501234567',
				contactNumber: '+966112345678',
				email: 'ahmed.ali@company.com'
			}
		},
		{
			id: 2,
			employee_id: 'EMP002',
			name_ar: 'فاطمة أحمد سالم',
			name_en: 'Fatima Ahmed Salem',
			email: 'fatima.salem@company.com',
			branch_id: 1,
			department: 'Human Resources',
			position: 'HR Manager',
			hire_date: '2021-03-10',
			status: 'Active',
			contact: {
				whatsappNumber: '+966502345678',
				contactNumber: '+966112345679',
				email: 'fatima.salem@company.com'
			}
		},
		{
			id: 3,
			employee_id: 'EMP003',
			name_ar: 'خالد عبدالله المطيري',
			name_en: 'Khalid Abdullah Al-Mutairi',
			email: 'khalid.mutairi@company.com',
			branch_id: 1,
			department: 'Information Technology',
			position: 'IT Manager',
			hire_date: '2021-06-20',
			status: 'Active',
			contact: {
				whatsappNumber: '+966503456789',
				contactNumber: '+966112345680',
				email: 'khalid.mutairi@company.com'
			}
		},
		{
			id: 4,
			employee_id: 'EMP004',
			name_ar: 'نورا سعد الغامدي',
			name_en: 'Nora Saad Al-Ghamdi',
			email: 'nora.ghamdi@company.com',
			branch_id: 1,
			department: 'Finance and Accounting',
			position: 'Finance Manager',
			hire_date: '2022-01-05',
			status: 'Active',
			contact: {
				whatsappNumber: '+966504567890',
				contactNumber: '+966112345681',
				email: 'nora.ghamdi@company.com'
			}
		},
		{
			id: 5,
			employee_id: 'EMP005',
			name_ar: 'محمد سالم القحطاني',
			name_en: 'Mohammed Salem Al-Qahtani',
			email: 'mohammed.qahtani@company.com',
			branch_id: 1,
			department: 'Human Resources',
			position: 'Recruitment Specialist',
			hire_date: '2022-04-12',
			status: 'Active',
			contact: {
				whatsappNumber: '+966505678901',
				contactNumber: '+966112345682',
				email: 'mohammed.qahtani@company.com'
			}
		},
		// Jeddah Branch employees
		{
			id: 6,
			employee_id: 'EMP006',
			name_ar: 'سارة عبدالرحمن الشهري',
			name_en: 'Sarah Abdulrahman Al-Shahri',
			email: 'sarah.shahri@company.com',
			branch_id: 2,
			department: 'Information Technology',
			position: 'Software Developer',
			hire_date: '2021-09-15',
			status: 'Active',
			contact: {
				whatsappNumber: '+966506789012',
				contactNumber: '+966122345678',
				email: 'sarah.shahri@company.com'
			}
		},
		{
			id: 7,
			employee_id: 'EMP007',
			name_ar: 'عبدالعزيز فهد الحربي',
			name_en: 'Abdulaziz Fahad Al-Harbi',
			email: 'abdulaziz.harbi@company.com',
			branch_id: 2,
			department: 'Finance and Accounting',
			position: 'Senior Accountant',
			hire_date: '2020-11-30',
			status: 'Active',
			contact: {
				whatsappNumber: '+966507890123',
				contactNumber: '+966122345679',
				email: 'abdulaziz.harbi@company.com'
			}
		},
		{
			id: 8,
			employee_id: 'EMP008',
			name_ar: 'ليلى إبراهيم الزهراني',
			name_en: 'Layla Ibrahim Al-Zahrani',
			email: 'layla.zahrani@company.com',
			branch_id: 2,
			department: 'Human Resources',
			position: 'Administrative Assistant',
			hire_date: '2022-07-18',
			status: 'Active',
			contact: {
				whatsappNumber: '+966508901234',
				contactNumber: '+966122345680',
				email: 'layla.zahrani@company.com'
			}
		},
		// Dammam Branch employees
		{
			id: 9,
			employee_id: 'EMP009',
			name_ar: 'عمر حسن العتيبي',
			name_en: 'Omar Hassan Al-Otaibi',
			email: 'omar.otaibi@company.com',
			branch_id: 3,
			department: 'Information Technology',
			position: 'Junior Developer',
			hire_date: '2021-12-01',
			status: 'Active',
			contact: {
				whatsappNumber: '+966509012345',
				contactNumber: '+966132345678',
				email: 'omar.otaibi@company.com'
			}
		},
		{
			id: 10,
			employee_id: 'EMP010',
			name_ar: 'هند محمد الدوسري',
			name_en: 'Hind Mohammed Al-Dosari',
			email: 'hind.dosari@company.com',
			branch_id: 3,
			department: 'Finance and Accounting',
			position: 'Accountant',
			hire_date: '2022-03-22',
			status: 'Active',
			contact: {
				whatsappNumber: '+966500123456',
				contactNumber: '+966132345679',
				email: 'hind.dosari@company.com'
			}
		}
	];

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
			employees = [];
		} finally {
			isLoading = false;
		}
	}

	function openContactForm(employee) {
		editingEmployee = employee;
		contactFormData = {
			whatsappNumber: employee.contact?.whatsappNumber || '',
			contactNumber: employee.contact?.contactNumber || '',
			email: employee.contact?.email || employee.email || ''
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
				};
			}

			successMessage = `Contact information updated successfully for ${editingEmployee.name_en}`;
			
			// Close form after 2 seconds
			setTimeout(() => {
				closeContactForm();
			}, 2000);

		} catch (error) {
			errorMessage = 'Failed to update contact information';
		} finally {
			isLoading = false;
		}
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function getBranchName(branchId) {
		const branch = branches.find(b => b.id === branchId);
		return branch ? `${branch.name_en} (${branch.location})` : 'Unknown Branch';
	}

	function formatPhoneNumber(phoneNumber) {
		if (!phoneNumber) return 'Not provided';
		// Format +966501234567 to +966 50 123 4567
		if (phoneNumber.startsWith('+966') && phoneNumber.length >= 13) {
			return phoneNumber.replace(/(\+966)(\d{2})(\d{3})(\d{4})/, '$1 $2 $3 $4');
		}
		return phoneNumber;
	}

	function getStatusColor(status) {
		return status === 'Active' ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50';
	}

	// Reactive statement to load employees when branch is selected
	$: if (selectedBranch) {
		loadEmployeesByBranch(selectedBranch);
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
		<div class="branch-selection">
			<div class="selection-header">
				<h3>Select Branch</h3>
				<p>Choose a branch to view and manage employee contact information</p>
			</div>
			
			<select 
				bind:value={selectedBranch}
				disabled={isLoading || showContactForm}
				class="branch-select"
			>
				<option value="">Choose a branch...</option>
				{#each branches as branch}
					<option value={branch.id}>
						{branch.name_en} ({branch.name_ar}) - {branch.location}
					</option>
				{/each}
			</select>
		</div>

		<!-- Messages -->
		{#if errorMessage && !showContactForm}
			<div class="error-message">
				<strong>Error:</strong> {errorMessage}
			</div>
		{/if}

		{#if successMessage && !showContactForm}
			<div class="success-message">
				<strong>Success:</strong> {successMessage}
			</div>
		{/if}

		<!-- Employees Table -->
		{#if selectedBranch && !showContactForm}
			<div class="employees-section">
				<div class="section-header">
					<h3>Employees in {getBranchName(parseInt(selectedBranch))}</h3>
					<div class="employee-count">
						{employees.length} employee{employees.length !== 1 ? 's' : ''}
					</div>
				</div>

				{#if isLoading && employees.length === 0}
					<div class="loading-state">
						<div class="spinner large"></div>
						<p>Loading employees...</p>
					</div>
				{:else if employees.length === 0}
					<div class="empty-state">
						<div class="empty-icon">👥</div>
						<h4>No Employees Found</h4>
						<p>No employees found in the selected branch</p>
					</div>
				{:else}
					<div class="table-container">
						<table class="employees-table">
							<thead>
								<tr>
									<th>Employee ID</th>
									<th>Name</th>
									<th>Department</th>
									<th>Position</th>
									<th>Current Email</th>
									<th>Phone Numbers</th>
									<th>Status</th>
									<th>Actions</th>
								</tr>
							</thead>
							<tbody>
								{#each employees as employee (employee.id)}
									<tr class="table-row">
										<td class="employee-id">{employee.employee_id}</td>
										<td class="employee-name">
											<div class="name-container">
												<div class="name-en">{employee.name_en}</div>
												<div class="name-ar">{employee.name_ar}</div>
											</div>
										</td>
										<td class="department">{employee.department}</td>
										<td class="position">{employee.position}</td>
										<td class="email">{employee.email}</td>
										<td class="phone-numbers">
											<div class="phone-container">
												{#if employee.contact?.whatsappNumber}
													<div class="phone-item">
														<span class="phone-label">WhatsApp:</span>
														<span class="phone-number">{formatPhoneNumber(employee.contact.whatsappNumber)}</span>
													</div>
												{/if}
												{#if employee.contact?.contactNumber}
													<div class="phone-item">
														<span class="phone-label">Contact:</span>
														<span class="phone-number">{formatPhoneNumber(employee.contact.contactNumber)}</span>
													</div>
												{/if}
												{#if !employee.contact?.whatsappNumber && !employee.contact?.contactNumber}
													<span class="no-contact">No phone numbers</span>
												{/if}
											</div>
										</td>
										<td class="status">
											<span class="status-badge {getStatusColor(employee.status)}">
												{employee.status}
											</span>
										</td>
										<td class="actions">
											<button 
												class="update-btn"
												on:click={() => openContactForm(employee)}
												disabled={isLoading}
												title="Update Contact Information"
											>
												<span class="icon">📞</span>
												Update Contact
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Contact Form Modal -->
		{#if showContactForm && editingEmployee}
			<div class="modal-overlay">
				<div class="contact-form-modal">
					<div class="modal-header">
						<h3>Update Contact Information</h3>
						<button 
							class="close-btn"
							on:click={closeContactForm}
							disabled={isLoading}
							title="Close"
						>
							❌
						</button>
					</div>

					<div class="modal-body">
						<div class="employee-info">
							<div class="info-row">
								<strong>Employee ID:</strong> {editingEmployee.employee_id}
							</div>
							<div class="info-row">
								<strong>Name:</strong> {editingEmployee.name_en} ({editingEmployee.name_ar})
							</div>
							<div class="info-row">
								<strong>Department:</strong> {editingEmployee.department}
							</div>
							<div class="info-row">
								<strong>Position:</strong> {editingEmployee.position}
							</div>
						</div>

						<form on:submit|preventDefault={saveContactInfo} class="contact-form">
							<div class="form-group">
								<label for="whatsappNumber">WhatsApp Number</label>
								<input
									id="whatsappNumber"
									type="tel"
									bind:value={contactFormData.whatsappNumber}
									placeholder="+966501234567"
									disabled={isLoading}
									class="form-input"
								>
								<small class="form-help">Format: +966XXXXXXXXX</small>
							</div>

							<div class="form-group">
								<label for="contactNumber">Contact Number</label>
								<input
									id="contactNumber"
									type="tel"
									bind:value={contactFormData.contactNumber}
									placeholder="+966112345678"
									disabled={isLoading}
									class="form-input"
								>
								<small class="form-help">Format: +966XXXXXXXXX</small>
							</div>

							<div class="form-group">
								<label for="email">Email Address *</label>
								<input
									id="email"
									type="email"
									bind:value={contactFormData.email}
									placeholder="employee@company.com"
									required
									disabled={isLoading}
									class="form-input"
								>
								<small class="form-help">Required field</small>
							</div>

							<!-- Messages inside form -->
							{#if errorMessage}
								<div class="error-message">
									<strong>Error:</strong> {errorMessage}
								</div>
							{/if}

							{#if successMessage}
								<div class="success-message">
									<strong>Success:</strong> {successMessage}
								</div>
							{/if}

							<div class="form-actions">
								<button 
									type="button"
									class="cancel-btn"
									on:click={closeContactForm}
									disabled={isLoading}
								>
									Cancel
								</button>
								<button 
									type="submit"
									class="save-btn"
									disabled={isLoading}
								>
									{#if isLoading}
										<span class="spinner"></span>
										Updating...
									{:else}
										<span class="icon">💾</span>
										Update Contact
									{/if}
								</button>
							</div>
						</form>
					</div>
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.contact-management {
		padding: 24px;
		height: 100%;
		overflow-y: auto;
		background: white;
	}

	.header {
		margin-bottom: 32px;
		text-align: center;
	}

	.title {
		font-size: 28px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.content {
		max-width: 1600px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: 32px;
	}

	.branch-selection {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
	}

	.selection-header {
		margin-bottom: 20px;
	}

	.selection-header h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.selection-header p {
		color: #6b7280;
		margin: 0;
	}

	.branch-select {
		width: 100%;
		max-width: 500px;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 16px;
		background: white;
		font-family: inherit;
		transition: all 0.2s;
	}

	.branch-select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.branch-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.error-message, .success-message {
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 20px;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
	}

	.success-message {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #059669;
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
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.section-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
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

	.loading-state, .empty-state {
		padding: 48px;
		text-align: center;
		color: #6b7280;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-state h4 {
		margin: 0 0 8px 0;
		color: #111827;
	}

	.empty-state p {
		margin: 0;
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

	.employee-id {
		font-family: 'Courier New', monospace;
		font-weight: 600;
		color: #3b82f6;
		min-width: 100px;
	}

	.name-container {
		display: flex;
		flex-direction: column;
		gap: 4px;
		min-width: 200px;
	}

	.name-en {
		font-weight: 500;
		color: #111827;
	}

	.name-ar {
		font-size: 14px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
	}

	.department, .position {
		color: #4b5563;
		min-width: 120px;
	}

	.email {
		color: #4b5563;
		font-size: 14px;
		min-width: 200px;
		word-break: break-all;
	}

	.phone-numbers {
		min-width: 200px;
	}

	.phone-container {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.phone-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.phone-label {
		font-size: 11px;
		color: #6b7280;
		font-weight: 500;
		text-transform: uppercase;
	}

	.phone-number {
		font-family: 'Courier New', monospace;
		font-size: 13px;
		color: #111827;
	}

	.no-contact {
		color: #9ca3af;
		font-style: italic;
		font-size: 14px;
	}

	.status-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		display: inline-block;
	}

	.update-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 12px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.update-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.update-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
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

	.contact-form-modal {
		background: white;
		border-radius: 12px;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
		max-width: 600px;
		width: 100%;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
		border-radius: 12px 12px 0 0;
	}

	.modal-header h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		transition: all 0.2s;
	}

	.close-btn:hover:not(:disabled) {
		background: #fef2f2;
	}

	.close-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.modal-body {
		padding: 24px;
	}

	.employee-info {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		padding: 20px;
		margin-bottom: 24px;
	}

	.info-row {
		display: flex;
		gap: 12px;
		margin-bottom: 8px;
		align-items: center;
	}

	.info-row:last-child {
		margin-bottom: 0;
	}

	.info-row strong {
		color: #374151;
		min-width: 100px;
	}

	.contact-form {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		font-weight: 500;
		color: #374151;
	}

	.form-input {
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 16px;
		font-family: inherit;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.form-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.form-help {
		color: #6b7280;
		font-size: 14px;
	}

	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		margin-top: 8px;
	}

	.cancel-btn, .save-btn {
		padding: 12px 20px;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.save-btn {
		background: #059669;
		color: white;
		border-color: #059669;
	}

	.save-btn:hover:not(:disabled) {
		background: #047857;
		transform: translateY(-1px);
	}

	.save-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.spinner.large {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.icon {
		font-size: 14px;
	}

	@media (max-width: 768px) {
		.section-header {
			flex-direction: column;
			gap: 12px;
			align-items: flex-start;
		}

		.employees-table th,
		.employees-table td {
			padding: 8px 12px;
			font-size: 14px;
		}

		.name-container,
		.phone-numbers {
			min-width: unset;
		}

		.modal-overlay {
			padding: 12px;
		}

		.modal-body {
			padding: 16px;
		}

		.form-actions {
			flex-direction: column;
		}

		.info-row {
			flex-direction: column;
			align-items: flex-start;
			gap: 4px;
		}

		.info-row strong {
			min-width: unset;
		}
	}
</style>