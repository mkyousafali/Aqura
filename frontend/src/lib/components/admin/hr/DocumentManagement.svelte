<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import { supabase } from '$lib/utils/supabase';

	// State management
	let branches = [];
	let employees = [];
	let documents = [];
	let selectedBranch = '';
	let selectedEmployee = null;
	let isLoading = false;
	let isUploading = false;
	let errorMessage = '';
	let successMessage = '';
	let showDocumentModal = false;

	// Document management state
	let employeeDocuments = [];
	let selectedFiles = {};
	let expiryDates = {};
	let otherDocumentNames = { 1: '', 2: '', 3: '', 4: '' };

	// Document types as per requirements
	const documentTypes = [
		{ 
			key: 'health_card', 
			label: 'Health Card', 
			icon: '🏥', 
			accepts: '.jpg,.jpeg,.png,.webp', 
			requiresExpiry: true,
			description: 'Upload a clear photo/scan of the health card',
			maxSize: '5MB',
			formats: ['JPG', 'JPEG', 'PNG', 'WebP']
		},
		{ 
			key: 'resident_id', 
			label: 'Resident ID', 
			icon: '🆔', 
			accepts: '.jpg,.jpeg,.png,.webp', 
			requiresExpiry: true,
			description: 'Upload both front and back sides if applicable',
			maxSize: '5MB',
			formats: ['JPG', 'JPEG', 'PNG', 'WebP']
		},
		{ 
			key: 'passport', 
			label: 'Passport', 
			icon: '📘', 
			accepts: '.jpg,.jpeg,.png,.webp', 
			requiresExpiry: true,
			description: 'Upload the main page with photo and details',
			maxSize: '5MB',
			formats: ['JPG', 'JPEG', 'PNG', 'WebP']
		},
		{ 
			key: 'resume', 
			label: 'Résumé', 
			icon: '📄', 
			accepts: '.pdf,.doc,.docx', 
			requiresExpiry: false,
			description: 'Upload latest CV/Resume document',
			maxSize: '10MB',
			formats: ['PDF', 'DOC', 'DOCX']
		},
		{ 
			key: 'other_1', 
			label: 'Other Document 1', 
			icon: '📋', 
			accepts: '.pdf,.doc,.docx,.jpg,.jpeg,.png,.webp', 
			requiresExpiry: false,
			description: 'Upload any additional document (specify name below)',
			maxSize: '10MB',
			formats: ['PDF', 'DOC', 'DOCX', 'JPG', 'PNG', 'WebP']
		},
		{ 
			key: 'other_2', 
			label: 'Other Document 2', 
			icon: '📋', 
			accepts: '.pdf,.doc,.docx,.jpg,.jpeg,.png,.webp', 
			requiresExpiry: false,
			description: 'Upload any additional document (specify name below)',
			maxSize: '10MB',
			formats: ['PDF', 'DOC', 'DOCX', 'JPG', 'PNG', 'WebP']
		},
		{ 
			key: 'other_3', 
			label: 'Other Document 3', 
			icon: '📋', 
			accepts: '.pdf,.doc,.docx,.jpg,.jpeg,.png,.webp', 
			requiresExpiry: false,
			description: 'Upload any additional document (specify name below)',
			maxSize: '10MB',
			formats: ['PDF', 'DOC', 'DOCX', 'JPG', 'PNG', 'WebP']
		},
		{ 
			key: 'other_4', 
			label: 'Other Document 4', 
			icon: '📋', 
			accepts: '.pdf,.doc,.docx,.jpg,.jpeg,.png,.webp', 
			requiresExpiry: false,
			description: 'Upload any additional document (specify name below)',
			maxSize: '10MB',
			formats: ['PDF', 'DOC', 'DOCX', 'JPG', 'PNG', 'WebP']
		}
	];

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		isLoading = true;
		errorMessage = '';

		try {
			const result = await dataService.branches.getAll();
			if (result.error) {
				throw new Error(result.error);
			}
			branches = result.data || [];
		} catch (error) {
			console.error('Failed to load branches:', error);
			errorMessage = 'Failed to load branches';
			branches = [];
		} finally {
			isLoading = false;
		}
	}

	async function loadEmployeesByBranch(branchId) {
		if (!branchId) {
			employees = [];
			documents = [];
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Load employees for the branch
			const employeesResult = await dataService.hrEmployees.getByBranch(parseInt(branchId));
			if (employeesResult.error) {
				throw new Error(employeesResult.error);
			}
			
			// Load documents for the branch
			const documentsResult = await dataService.hrDocuments.getByBranch(parseInt(branchId));
			if (documentsResult.error) {
				throw new Error(documentsResult.error);
			}
			
			employees = employeesResult.data || [];
			documents = documentsResult.data || [];
			
			// Debug: Log the first employee to see the actual structure
			if (employees.length > 0) {
				console.log('Employee data structure:', employees[0]);
				console.log('Available fields:', Object.keys(employees[0]));
				
				// Check for department-related fields
				const deptFields = Object.keys(employees[0]).filter(key => 
					key.toLowerCase().includes('dept') || 
					key.toLowerCase().includes('department')
				);
				console.log('Department-related fields:', deptFields);
				
				// Check for position-related fields  
				const posFields = Object.keys(employees[0]).filter(key => 
					key.toLowerCase().includes('pos') || 
					key.toLowerCase().includes('title') ||
					key.toLowerCase().includes('job')
				);
				console.log('Position-related fields:', posFields);
			}
			
			// Merge document counts with employees
			employees = employees.map(employee => ({
				...employee,
				documentCount: documents.filter(doc => doc.employee_id === employee.id).length,
				expiring_documents: documents.filter(doc => 
					doc.employee_id === employee.id && 
					doc.expiry_date && 
					isExpiringSoon(doc.expiry_date)
				).length
			}));
			
		} catch (error) {
			console.error('Failed to load employees and documents:', error);
			errorMessage = 'Failed to load employees and documents';
			employees = [];
			documents = [];
		} finally {
			isLoading = false;
		}
	}

	async function openDocumentModal(employee) {
		selectedEmployee = employee;
		showDocumentModal = true;
		
		// Reset form state
		selectedFiles = {};
		expiryDates = {};
		otherDocumentNames = { 1: '', 2: '', 3: '', 4: '' };
		
		// Load existing documents for this employee
		await loadEmployeeDocuments(employee.id);
		
		// Clear any existing messages
		errorMessage = '';
		successMessage = '';
	}

	async function loadEmployeeDocuments(employeeId) {
		try {
			const result = await dataService.hrDocuments.getByEmployeeId(employeeId);
			if (result.error) {
				throw new Error(result.error);
			}
			employeeDocuments = result.data || [];
		} catch (error) {
			console.error('Failed to load employee documents:', error);
			employeeDocuments = [];
		}
	}

	function closeDocumentModal() {
		showDocumentModal = false;
		selectedEmployee = null;
		employeeDocuments = [];
		// Refresh the employees list to show updated document counts
		if (selectedBranch) {
			loadEmployeesByBranch(selectedBranch);
		}
	}

	function handleFileSelect(documentKey, event) {
		const file = event.target.files[0];
		if (file) {
			selectedFiles = { ...selectedFiles, [documentKey]: file };
		}
	}

	async function uploadDocument(documentKey) {
		const file = selectedFiles[documentKey];
		if (!file) {
			errorMessage = 'Please select a file to upload';
			return;
		}

		const docType = documentTypes.find(dt => dt.key === documentKey);
		if (!docType) {
			errorMessage = 'Invalid document type';
			return;
		}

		// Check if expiry date is required and provided
		if (docType.requiresExpiry && !expiryDates[documentKey]) {
			errorMessage = `Expiry date is required for ${docType.label}`;
			return;
		}

		// Check if document name is required for "other" documents
		if (documentKey.startsWith('other_') && !otherDocumentNames[documentKey.split('_')[1]]) {
			errorMessage = 'Please enter a document name';
			return;
		}

		isUploading = true;
		errorMessage = '';
		successMessage = '';

		try {
			// Upload file to Supabase Storage first
			const fileExtension = file.name.split('.').pop();
			const fileName = `${selectedEmployee.employee_id}_${documentKey}_${Date.now()}.${fileExtension}`;
			const storagePath = `employees/${selectedEmployee.employee_id}/${fileName}`;

			console.log('Uploading file to storage:', { fileName, storagePath, fileSize: file.size });

			// Upload to Supabase Storage bucket
			const { data: uploadData, error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(storagePath, file, {
					cacheControl: '3600',
					upsert: false
				});

			if (uploadError) {
				console.error('Storage upload error:', uploadError);
				throw new Error(`File upload failed: ${uploadError.message}`);
			}

			console.log('File uploaded successfully:', uploadData);

			// Get the public URL for the uploaded file
			const { data: { publicUrl } } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(storagePath);

			console.log('Public URL:', publicUrl);

			// Prepare document data for database (without file_size to avoid schema error)
			let documentName = docType.label;
			if (documentKey.startsWith('other_')) {
				const otherIndex = documentKey.split('_')[1];
				documentName = otherDocumentNames[otherIndex] || `Other Document ${otherIndex}`;
			}

			const documentData = {
				employee_id: selectedEmployee.id,
				document_type: documentKey,
				document_name: documentName,
				file_path: publicUrl,
				file_type: file.type,
				expiry_date: expiryDates[documentKey] || null
			};

			console.log('Saving document metadata to database:', documentData);

			const result = await dataService.hrDocuments.create(documentData);
			
			console.log('Database save result:', result);
			
			if (result.error) {
				// If database save fails, try to clean up the uploaded file
				try {
					await supabase.storage.from('employee-documents').remove([storagePath]);
				} catch (cleanupError) {
					console.error('Failed to cleanup uploaded file:', cleanupError);
				}
				throw new Error(typeof result.error === 'string' ? result.error : JSON.stringify(result.error));
			}

			// Reset this document's form
			delete selectedFiles[documentKey];
			delete expiryDates[documentKey];
			if (documentKey.startsWith('other_')) {
				const otherIndex = documentKey.split('_')[1];
				otherDocumentNames[otherIndex] = '';
			}

			// Clear file input
			const fileInput = document.querySelector(`input[data-document="${documentKey}"]`);
			if (fileInput) fileInput.value = '';

			successMessage = `${docType.label} uploaded successfully!`;
			
			// Reload employee documents
			await loadEmployeeDocuments(selectedEmployee.id);
		} catch (error) {
			console.error('Failed to upload document:', error);
			errorMessage = error.message || 'Failed to upload document';
		} finally {
			isUploading = false;
		}
	}

	async function deleteDocument(docId) {
		if (!confirm('Are you sure you want to delete this document?')) {
			return;
		}

		try {
			const result = await dataService.hrDocuments.delete(docId);
			if (result.error) {
				throw new Error(result.error);
			}
			
			successMessage = 'Document deleted successfully!';
			await loadEmployeeDocuments(selectedEmployee.id);
		} catch (error) {
			console.error('Failed to delete document:', error);
			errorMessage = error.message || 'Failed to delete document';
		}
	}

	function getExistingDocument(documentKey) {
		return employeeDocuments.find(doc => doc.document_type === documentKey);
	}

	function getBranchName(branchId) {
		const branch = branches.find(b => b.id === parseInt(branchId));
		return branch ? `${branch.name_en || branch.name_ar || 'Unknown'} - ${branch.location_en || branch.location_ar || 'Unknown Location'}` : 'Unknown Branch';
	}

	function getStatusColor(status) {
		return status === 'active' ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50';
	}

	// Helper functions for expiry checking
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function isExpiringSoon(expiryDate) {
		if (!expiryDate) return false;
		const expiry = new Date(expiryDate);
		const today = new Date();
		const diffTime = expiry - today;
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		return diffDays <= 30 && diffDays > 0;
	}

	function isExpired(expiryDate) {
		if (!expiryDate) return false;
		const expiry = new Date(expiryDate);
		const today = new Date();
		return expiry < today;
	}

	function formatFileSize(bytes) {
		if (!bytes) return 'Unknown';
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(1024));
		return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
	}

	// Reactive statement to load employees when branch is selected
	$: if (selectedBranch) {
		loadEmployeesByBranch(selectedBranch);
	}
</script>

<div class="document-management">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Document Management</h2>
		<p class="subtitle">Manage employee documents, certificates, and file uploads</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Branch Selection -->
		<div class="branch-selection">
			<div class="selection-header">
				<h3>Select Branch</h3>
				<p>Choose a branch to view and manage employee documents</p>
			</div>
			
			<select 
				bind:value={selectedBranch}
				disabled={isLoading}
				class="branch-select"
			>
				<option value="">Choose a branch...</option>
				{#each branches as branch}
					<option value={branch.id}>
						{branch.name_en || branch.name_ar || 'Unknown'} - {branch.location_en || branch.location_ar || 'Unknown Location'}
					</option>
				{/each}
			</select>
		</div>

		<!-- Messages -->
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

		<!-- Employees Table -->
		{#if selectedBranch}
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
									<th>Documents Count</th>
									<th>Expiring Soon</th>
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
												<div class="name-en">{employee.name}</div>
											</div>
										</td>
										<td class="department">{employee.department || employee.department_name || employee.dept || 'N/A'}</td>
										<td class="position">{employee.position || employee.position_title || employee.job_title || 'N/A'}</td>
										<td class="document-count">
											<span class="count-badge">
												{employee.documentCount || 0} documents
											</span>
										</td>
										<td class="expiring-docs">
											{#if employee.expiring_documents && employee.expiring_documents > 0}
												<span class="expiring-badge warning">
													{employee.expiring_documents} expiring
												</span>
											{:else}
												<span class="expiring-badge good">All current</span>
											{/if}
										</td>
										<td class="status">
											<span class="status-badge {getStatusColor(employee.status)}">
												{employee.status === 'active' ? 'Active' : 'Inactive'}
											</span>
										</td>
										<td class="actions">
											<button 
												class="manage-btn"
												on:click={() => openDocumentModal(employee)}
												disabled={isLoading}
												title="Manage Documents"
											>
												<span class="icon">📄</span>
												Manage Documents
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
	</div>
</div>

<!-- Document Management Modal -->
{#if showDocumentModal && selectedEmployee}
	<div class="modal-overlay" on:click={closeDocumentModal}>
		<div class="modal-content" on:click|stopPropagation>
			<!-- Modal Header -->
			<div class="modal-header">
				<div class="employee-info">
					<h2>📄 Document Management</h2>
					<p>{selectedEmployee.name} ({selectedEmployee.employee_id})</p>
				</div>
				<button class="close-btn" on:click={closeDocumentModal}>✕</button>
			</div>

			<!-- Modal Body -->
			<div class="modal-body">
				<!-- Messages in modal -->
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

				<!-- Document Upload Sections -->
				<div class="document-sections">
					{#each documentTypes as docType (docType.key)}
						{@const existingDoc = getExistingDocument(docType.key)}
						<div class="document-section">
							<div class="section-title">
								<span class="doc-icon">{docType.icon}</span>
								<h4>{docType.label}</h4>
								{#if existingDoc}
									<span class="existing-badge">✓ Uploaded</span>
								{/if}
							</div>

							{#if existingDoc}
								<!-- Show existing document -->
								<div class="existing-document">
									<div class="doc-info">
										<span class="doc-name">{existingDoc.document_name}</span>
										<span class="doc-meta">
											{formatFileSize(existingDoc.file_size)} • 
											{formatDate(existingDoc.upload_date)}
											{#if existingDoc.expiry_date}
												• Expires: {formatDate(existingDoc.expiry_date)}
											{/if}
										</span>
									</div>
									<button class="delete-doc-btn" on:click={() => deleteDocument(existingDoc.id)}>
										🗑️ Delete
									</button>
								</div>
							{:else}
								<!-- Upload form for this document type -->
								<div class="upload-form">
									<!-- Document Information -->
									<div class="document-info">
										<p class="doc-description">{docType.description}</p>
										<div class="file-requirements">
											<div class="requirement-item">
												<strong>📎 Supported Formats:</strong>
												<span class="format-tags">
													{#each docType.formats as format}
														<span class="format-tag">{format}</span>
													{/each}
												</span>
											</div>
											<div class="requirement-item">
												<strong>📏 Max File Size:</strong>
												<span class="size-limit">{docType.maxSize}</span>
											</div>
											{#if docType.requiresExpiry}
												<div class="requirement-item">
													<strong>📅 Expiry Date:</strong>
													<span class="expiry-required">Required</span>
												</div>
											{/if}
										</div>
									</div>

									{#if docType.key.startsWith('other_')}
										<div class="form-group">
											<label>Document Name *</label>
											<input 
												type="text" 
												bind:value={otherDocumentNames[docType.key.split('_')[1]]}
												placeholder="Enter document name (e.g., Driving License, Certificate)"
												class="form-input"
												required
											/>
										</div>
									{/if}

									<div class="form-group">
										<label>Select File *</label>
										<input 
											type="file" 
											accept={docType.accepts}
											on:change={(e) => handleFileSelect(docType.key, e)}
											data-document={docType.key}
											class="form-input file-input"
											required
										/>
										<div class="file-help-text">
											Accepted formats: {docType.formats.join(', ')} • Max size: {docType.maxSize}
										</div>
										{#if selectedFiles[docType.key]}
											<div class="file-selected">
												<span class="file-icon">📄</span>
												<div class="file-details">
													<div class="file-name">{selectedFiles[docType.key].name}</div>
													<div class="file-size">({formatFileSize(selectedFiles[docType.key].size)})</div>
												</div>
											</div>
										{/if}
									</div>

									{#if docType.requiresExpiry}
										<div class="form-group">
											<label>Expiry Date *</label>
											<input 
												type="date" 
												bind:value={expiryDates[docType.key]}
												class="form-input"
												required
											/>
										</div>
									{:else if !docType.requiresExpiry && docType.key !== 'resume'}
										<div class="form-group">
											<label>Expiry Date (Optional)</label>
											<input 
												type="date" 
												bind:value={expiryDates[docType.key]}
												class="form-input"
											/>
										</div>
									{/if}

									<button 
										class="upload-doc-btn"
										on:click={() => uploadDocument(docType.key)}
										disabled={isUploading || !selectedFiles[docType.key]}
									>
										{#if isUploading}
											<span class="spinner"></span>
											Uploading...
										{:else}
											📤 Upload {docType.label}
										{/if}
									</button>
								</div>
							{/if}
						</div>
					{/each}
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.document-management {
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

	.spinner {
		border: 2px solid #f3f4f6;
		border-top: 2px solid #3b82f6;
		border-radius: 50%;
		width: 16px;
		height: 16px;
		animation: spin 1s linear infinite;
		display: inline-block;
	}

	.spinner.large {
		width: 24px;
		height: 24px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
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

	.department, .position {
		color: #4b5563;
		min-width: 120px;
	}

	.count-badge {
		background: #e0e7ff;
		color: #3730a3;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.expiring-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.expiring-badge.warning {
		background: #fef3c7;
		color: #d97706;
	}

	.expiring-badge.good {
		background: #d1fae5;
		color: #059669;
	}

	.status-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		display: inline-block;
	}

	.manage-btn {
		background: #7c3aed;
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

	.manage-btn:hover:not(:disabled) {
		background: #6d28d9;
		transform: translateY(-1px);
	}

	.manage-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.icon {
		font-size: 14px;
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
		width: 100%;
		max-width: 1000px;
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
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.employee-info h2 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.employee-info p {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
	}

	.close-btn {
		background: #f3f4f6;
		border: none;
		border-radius: 6px;
		padding: 8px 12px;
		cursor: pointer;
		font-size: 16px;
		color: #6b7280;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #e5e7eb;
		color: #374151;
	}

	.modal-body {
		flex: 1;
		overflow-y: auto;
		padding: 24px;
	}

	.document-sections {
		display: flex;
		flex-direction: column;
		gap: 24px;
	}

	.document-section {
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
		background: #fafafa;
	}

	.section-title {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
	}

	.doc-icon {
		font-size: 20px;
	}

	.section-title h4 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0;
		flex: 1;
	}

	.existing-badge {
		background: #d1fae5;
		color: #059669;
		padding: 2px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.existing-document {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 6px;
	}

	.doc-info {
		flex: 1;
	}

	.doc-name {
		display: block;
		font-weight: 500;
		color: #111827;
		margin-bottom: 4px;
	}

	.doc-meta {
		font-size: 12px;
		color: #6b7280;
	}

	.delete-doc-btn {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		border-radius: 4px;
		padding: 4px 8px;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.delete-doc-btn:hover {
		background: #fee2e2;
	}

	.upload-form {
		display: flex;
		flex-direction: column;
		gap: 12px;
		background: white;
		padding: 16px;
		border-radius: 6px;
		border: 1px solid #d1d5db;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.form-group label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.form-input {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 14px;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.file-selected {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-top: 8px;
		padding: 8px 12px;
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		border-radius: 6px;
	}

	.file-icon {
		font-size: 16px;
	}

	.file-details {
		flex: 1;
	}

	.file-name {
		font-weight: 500;
		color: #065f46;
		font-size: 13px;
	}

	.file-size {
		color: #059669;
		font-size: 12px;
	}

	.file-help-text {
		font-size: 11px;
		color: #6b7280;
		margin-top: 4px;
		font-style: italic;
	}

	.document-info {
		margin-bottom: 16px;
		padding: 12px;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
	}

	.doc-description {
		margin: 0 0 12px 0;
		color: #475569;
		font-size: 13px;
		line-height: 1.4;
	}

	.file-requirements {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.requirement-item {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 12px;
	}

	.requirement-item strong {
		color: #374151;
		font-weight: 500;
		min-width: 120px;
	}

	.format-tags {
		display: flex;
		gap: 4px;
		flex-wrap: wrap;
	}

	.format-tag {
		background: #dbeafe;
		color: #1e40af;
		padding: 2px 6px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 500;
	}

	.size-limit {
		color: #dc2626;
		font-weight: 500;
	}

	.expiry-required {
		color: #d97706;
		font-weight: 500;
	}

	.upload-doc-btn {
		background: #7c3aed;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: all 0.2s;
		align-self: flex-start;
	}

	.upload-doc-btn:hover:not(:disabled) {
		background: #6d28d9;
	}

	.upload-doc-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
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

		.name-container {
			min-width: unset;
		}

		.modal-content {
			margin: 10px;
			max-width: none;
		}

		.modal-body {
			padding: 16px;
		}
	}
</style>