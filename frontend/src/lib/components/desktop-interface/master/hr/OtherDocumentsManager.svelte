<script lang="ts">
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import { supabase } from '$lib/utils/supabase';

	// Props
	export let employee;

	// State management
	let otherDocuments = [];
	let isLoading = false;
	let isUploading = false;
	let errorMessage = '';
	let successMessage = '';

	// Document categories with their specific fields
	const documentCategories = [
		{ value: 'warnings', label: 'Warnings', fields: ['details'] },
		{ value: 'sick_leave', label: 'Sick Leave', fields: ['start_date', 'end_date', 'content'] },
		{ value: 'special_leave', label: 'Special Leave Request', fields: ['start_date', 'end_date', 'days'] },
		{ value: 'resignation', label: 'Resignation', fields: ['last_working_day', 'reason'] },
		{ value: 'contract_objection', label: 'Objection for Contract Renewal', fields: ['reason'] },
		{ value: 'annual_leave', label: 'Annual Leave Request', fields: ['start_date', 'end_date', 'days'] },
		{ value: 'other', label: 'Other', fields: ['description'] }
	];

	// New document form
	let newDocument = {
		name: '',
		category: '',
		description: '',
		number: '',
		file: null,
		expiryDate: '',
		// Category-specific fields
		details: '',
		startDate: '',
		endDate: '',
		content: '',
		days: 0,
		lastWorkingDay: '',
		reason: ''
	};

	let fileInput;

	onMount(async () => {
		if (employee) {
			await loadOtherDocuments();
		}
	});

	async function loadOtherDocuments() {
		isLoading = true;
		try {
			const result = await dataService.hrDocuments.getByEmployeeId(employee.id);
			if (result.error) {
				throw new Error(result.error);
			}
			// Filter only "other" type documents
			otherDocuments = (result.data || []).filter(doc => 
				doc.document_type && doc.document_type.startsWith('other')
			);
		} catch (error) {
			console.error('Failed to load other documents:', error);
			errorMessage = 'Failed to load documents';
			otherDocuments = [];
		} finally {
			isLoading = false;
		}
	}

	function handleFileSelect(event) {
		const file = event.target.files[0];
		if (file) {
			newDocument.file = file;
		}
	}

	function resetForm() {
		newDocument = {
			name: '',
			category: '',
			description: '',
			number: '',
			file: null,
			expiryDate: '',
			details: '',
			startDate: '',
			endDate: '',
			content: '',
			days: 0,
			lastWorkingDay: '',
			reason: ''
		};
		if (fileInput) fileInput.value = '';
		errorMessage = '';
		successMessage = '';
	}

	function onCategoryChange() {
		// Reset category-specific fields when category changes
		newDocument.details = '';
		newDocument.startDate = '';
		newDocument.endDate = '';
		newDocument.content = '';
		newDocument.days = 0;
		newDocument.lastWorkingDay = '';
		newDocument.reason = '';
		newDocument.description = '';

		// Auto-fill content for specific categories
		if (newDocument.category === 'sick_leave') {
			newDocument.content = 'Medical leave as per company policy';
		}
	}

	function calculateDays() {
		if (newDocument.startDate && newDocument.endDate) {
			const start = new Date(newDocument.startDate);
			const end = new Date(newDocument.endDate);
			const timeDiff = end.getTime() - start.getTime();
			const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24)) + 1; // +1 to include both start and end dates
			newDocument.days = daysDiff > 0 ? daysDiff : 0;
		} else {
			newDocument.days = 0;
		}
	}

	function getSelectedCategory() {
		return documentCategories.find(cat => cat.value === newDocument.category);
	}

	async function uploadDocument() {
		if (!newDocument.file) {
			errorMessage = 'Please select a file to upload';
			return;
		}

		if (!newDocument.name.trim()) {
			errorMessage = 'Please enter document name';
			return;
		}

		if (!newDocument.category) {
			errorMessage = 'Please select document category';
			return;
		}

		// Validate category-specific required fields
		if (newDocument.category === 'warnings' && !newDocument.details.trim()) {
			errorMessage = 'Please enter warning details';
			return;
		}
		if (['sick_leave', 'special_leave', 'annual_leave'].includes(newDocument.category)) {
			if (!newDocument.startDate || !newDocument.endDate) {
				errorMessage = 'Please enter both start and end dates';
				return;
			}
			if (new Date(newDocument.startDate) > new Date(newDocument.endDate)) {
				errorMessage = 'End date must be after start date';
				return;
			}
		}
		if (newDocument.category === 'resignation' && (!newDocument.lastWorkingDay || !newDocument.reason.trim())) {
			errorMessage = 'Please enter last working day and reason for resignation';
			return;
		}
		if (newDocument.category === 'contract_objection' && !newDocument.reason.trim()) {
			errorMessage = 'Please enter reason for objection';
			return;
		}

		isUploading = true;
		errorMessage = '';
		successMessage = '';

		try {
			// File upload to Supabase Storage
			const fileExtension = newDocument.file.name.split('.').pop();
			const fileName = `${employee.employee_id}_other_${Date.now()}.${fileExtension}`;
			const storagePath = `employees/${employee.employee_id}/${fileName}`;

			// Upload to Supabase Storage bucket
			const { data: uploadData, error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(storagePath, newDocument.file, {
					cacheControl: '3600',
					upsert: false
				});

			if (uploadError) {
				throw new Error(`File upload failed: ${uploadError.message}`);
			}

			// Get the public URL for the uploaded file
			const { data: { publicUrl } } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(storagePath);

			// Generate unique document type
			const documentType = `other_${Date.now()}`;

			// Prepare document data for database with category fields
			const documentData = {
				employee_id: employee.id,
				document_type: documentType,
				document_name: newDocument.name,
				document_number: newDocument.number || null,
				document_description: newDocument.description || null,
				file_path: publicUrl,
				file_type: newDocument.file.type,
				expiry_date: newDocument.expiryDate || null,
				document_category: newDocument.category || 'other',
				category_start_date: newDocument.startDate || null,
				category_end_date: newDocument.endDate || null,
				category_days: newDocument.days || null,
				category_last_working_day: newDocument.lastWorkingDay || null,
				category_reason: newDocument.reason || null,
				category_details: newDocument.details || null,
				category_content: newDocument.content || null
			};

			const result = await dataService.hrDocuments.create(documentData);
			if (result.error) {
				// If database save fails, try to clean up the uploaded file
				try {
					await supabase.storage.from('employee-documents').remove([storagePath]);
				} catch (cleanupError) {
					console.error('Failed to cleanup uploaded file:', cleanupError);
				}
				
				if (typeof result.error === 'object' && result.error.message) {
					throw new Error(result.error.message);
				}
				throw new Error(typeof result.error === 'string' ? result.error : JSON.stringify(result.error));
			}

			successMessage = `${newDocument.name} uploaded successfully!`;
			resetForm();
			
			// Reload other documents
			await loadOtherDocuments();
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
			
			// Reload other documents
			await loadOtherDocuments();
		} catch (error) {
			console.error('Failed to delete document:', error);
			errorMessage = error.message || 'Failed to delete document';
		}
	}

	// Helper function to format dates
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString();
	}

	// Helper function to format file size
	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
	}

</script>

<div class="other-documents-manager">
	<!-- Header -->
	<div class="header">
		<div class="employee-info">
			<h2>📋 Other Documents</h2>
			<p>{employee.name} ({employee.employee_id})</p>
		</div>
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

	<!-- Add New Document Form -->
	<div class="add-document-section">
		<h3>📄 Add New Document</h3>
		
		<div class="form-grid">
			<div class="form-group">
				<label for="doc-name">Document Name *</label>
				<input 
					id="doc-name"
					type="text" 
					bind:value={newDocument.name}
					placeholder="Enter document name (e.g., Driving License, Certificate)"
					class="form-input"
					required
				/>
			</div>

			<div class="form-group">
				<label for="doc-category">Document Category *</label>
				<select 
					id="doc-category"
					bind:value={newDocument.category}
					on:change={onCategoryChange}
					class="form-input"
					required
				>
					<option value="">Select category...</option>
					{#each documentCategories as category}
						<option value={category.value}>{category.label}</option>
					{/each}
				</select>
			</div>

			<!-- Category-specific fields -->
			{#if newDocument.category}
				<!-- Warnings specific fields -->
				{#if newDocument.category === 'warnings'}
					<div class="form-group full-width">
						<label for="warning-details">Warning Details *</label>
						<textarea 
							id="warning-details"
							bind:value={newDocument.details}
							placeholder="Enter warning details and reasons"
							class="form-input textarea"
							rows="3"
							required
						></textarea>
					</div>
				{/if}

				<!-- Leave-type specific fields -->
				{#if ['sick_leave', 'special_leave', 'annual_leave'].includes(newDocument.category)}
					<div class="form-row">
						<div class="form-group">
							<label for="start-date">Start Date *</label>
							<input 
								id="start-date"
								type="date" 
								bind:value={newDocument.startDate}
								on:change={calculateDays}
								class="form-input"
								required
							/>
						</div>
						<div class="form-group">
							<label for="end-date">End Date *</label>
							<input 
								id="end-date"
								type="date" 
								bind:value={newDocument.endDate}
								on:change={calculateDays}
								class="form-input"
								required
							/>
						</div>
						<div class="form-group">
							<label for="days">Days</label>
							<input 
								id="days"
								type="number" 
								bind:value={newDocument.days}
								class="form-input"
								readonly
							/>
						</div>
					</div>
					<div class="form-group full-width">
						<label for="leave-content">Content/Reason</label>
						<textarea 
							id="leave-content"
							bind:value={newDocument.content}
							placeholder="Enter reason or additional details"
							class="form-input textarea"
							rows="2"
						></textarea>
					</div>
				{/if}

				<!-- Resignation specific fields -->
				{#if newDocument.category === 'resignation'}
					<div class="form-group">
						<label for="last-working-day">Last Working Day *</label>
						<input 
							id="last-working-day"
							type="date" 
							bind:value={newDocument.lastWorkingDay}
							class="form-input"
							required
						/>
					</div>
					<div class="form-group full-width">
						<label for="resignation-reason">Reason for Resignation *</label>
						<textarea 
							id="resignation-reason"
							bind:value={newDocument.reason}
							placeholder="Enter reason for resignation"
							class="form-input textarea"
							rows="3"
							required
						></textarea>
					</div>
				{/if}

				<!-- Contract Objection specific fields -->
				{#if newDocument.category === 'contract_objection'}
					<div class="form-group full-width">
						<label for="objection-reason">Reason for Objection *</label>
						<textarea 
							id="objection-reason"
							bind:value={newDocument.reason}
							placeholder="Enter reason for contract renewal objection"
							class="form-input textarea"
							rows="3"
							required
						></textarea>
					</div>
				{/if}

				<!-- Other category general description -->
				{#if newDocument.category === 'other'}
					<div class="form-group full-width">
						<label for="other-details">Document Details</label>
						<textarea 
							id="other-details"
							bind:value={newDocument.details}
							placeholder="Enter document details and purpose"
							class="form-input textarea"
							rows="3"
						></textarea>
					</div>
				{/if}
			{/if}

			<div class="form-group">
				<label for="doc-number">Document Number</label>
				<input 
					id="doc-number"
					type="text" 
					bind:value={newDocument.number}
					placeholder="Enter document number or ID"
					class="form-input"
				/>
				<div class="field-help">Optional: Enter the document's reference number, ID, or serial number</div>
			</div>

			<!-- General description only shown when no category selected or for 'other' category -->
			{#if !newDocument.category || newDocument.category === 'other'}
				<div class="form-group full-width">
					<label for="doc-description">Document Description</label>
					<textarea 
						id="doc-description"
						bind:value={newDocument.description}
						placeholder="Enter document description"
						class="form-input textarea"
						rows="3"
					></textarea>
					<div class="field-help">Provide details about this document</div>
				</div>
			{/if}

			<div class="form-group">
				<label for="doc-file">Select File *</label>
				<input 
					id="doc-file"
					type="file" 
					accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.webp"
					on:change={handleFileSelect}
					bind:this={fileInput}
					class="form-input file-input"
					required
				/>
				<div class="file-help-text">
					Accepted formats: PDF, DOC, DOCX, JPG, PNG, WebP • Max size: 10MB
				</div>
				{#if newDocument.file}
					<div class="file-selected">
						<span class="file-icon">📄</span>
						<div class="file-details">
							<div class="file-name">{newDocument.file.name}</div>
							<div class="file-size">({formatFileSize(newDocument.file.size)})</div>
						</div>
					</div>
				{/if}
			</div>

			<div class="form-group">
				<label for="doc-expiry">Expiry Date (Optional)</label>
				<input 
					id="doc-expiry"
					type="date" 
					bind:value={newDocument.expiryDate}
					class="form-input"
				/>
			</div>
		</div>

		<div class="form-actions">
			<button 
				class="upload-btn"
				on:click={uploadDocument}
				disabled={isUploading || !newDocument.file || !newDocument.name.trim()}
			>
				{#if isUploading}
					<span class="spinner"></span>
					Uploading...
				{:else}
					📤 Upload Document
				{/if}
			</button>

			<button 
				class="reset-btn"
				on:click={resetForm}
				disabled={isUploading}
			>
				🔄 Reset Form
			</button>
		</div>
	</div>

	<!-- Existing Other Documents -->
	<div class="existing-documents-section">
		<h3>📁 Existing Other Documents ({otherDocuments.length})</h3>
		
		{#if isLoading}
			<div class="loading">
				<div class="spinner"></div>
				Loading documents...
			</div>
		{:else if otherDocuments.length === 0}
			<div class="empty-state">
				<div class="empty-icon">📄</div>
				<p>No other documents uploaded yet</p>
				<p class="empty-subtitle">Use the form above to upload additional documents</p>
			</div>
		{:else}
			<div class="documents-grid">
				{#each otherDocuments as doc (doc.id)}
					<div class="document-card">
						<div class="document-header">
							<div class="document-icon">📄</div>
							<div class="document-title">{doc.document_name}</div>
							<button class="delete-btn" on:click={() => deleteDocument(doc.id)}>
								🗑️
							</button>
						</div>
						
						<div class="document-details">
							{#if doc.document_number}
								<div class="detail-item">
									<strong>Number:</strong> {doc.document_number}
								</div>
							{/if}
							
							{#if doc.document_category}
								<div class="detail-item category">
									<strong>Category:</strong> 
									{documentCategories.find(cat => cat.value === doc.document_category)?.label || 'Other'}
								</div>
							{/if}
							
							{#if doc.category_start_date && doc.category_end_date}
								<div class="detail-item">
									<strong>Period:</strong> {formatDate(doc.category_start_date)} - {formatDate(doc.category_end_date)}
									{#if doc.category_days}
										({doc.category_days} days)
									{/if}
								</div>
							{/if}
							
							{#if doc.category_last_working_day}
								<div class="detail-item">
									<strong>Last Working Day:</strong> {formatDate(doc.category_last_working_day)}
								</div>
							{/if}
							
							{#if doc.category_reason}
								<div class="detail-item description">
									<strong>Reason:</strong> {doc.category_reason}
								</div>
							{/if}
							
							{#if doc.category_details}
								<div class="detail-item description">
									<strong>Details:</strong> {doc.category_details}
								</div>
							{/if}
							
							{#if doc.category_content}
								<div class="detail-item description">
									<strong>Content:</strong> {doc.category_content}
								</div>
							{/if}
							
							{#if doc.document_description}
								<div class="detail-item description">
									<strong>Description:</strong> {doc.document_description}
								</div>
							{/if}
							
							<div class="detail-item">
								<strong>Uploaded:</strong> {formatDate(doc.upload_date)}
							</div>
							
							{#if doc.expiry_date}
								<div class="detail-item">
									<strong>Expires:</strong> {formatDate(doc.expiry_date)}
								</div>
							{/if}
							
							{#if doc.file_size}
								<div class="detail-item">
									<strong>Size:</strong> {formatFileSize(doc.file_size)}
								</div>
							{/if}
						</div>
						
						<div class="document-actions">
							<a href={doc.file_path} target="_blank" class="view-btn">
								👁️ View Document
							</a>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.other-documents-manager {
		padding: 24px;
		height: 100%;
		overflow-y: auto;
		background: white;
	}

	.header {
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.employee-info h2 {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.employee-info p {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 6px;
		margin-bottom: 16px;
		font-size: 14px;
	}

	.success-message {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #16a34a;
		padding: 12px 16px;
		border-radius: 6px;
		margin-bottom: 16px;
		font-size: 14px;
	}

	.add-document-section {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		padding: 24px;
		margin-bottom: 32px;
	}

	.add-document-section h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
	}

	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group.full-width {
		grid-column: 1 / -1;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr auto;
		gap: 16px;
		align-items: end;
	}

	.form-group label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.form-input {
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 10px 12px;
		font-size: 14px;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.1);
	}

	.textarea {
		resize: vertical;
		min-height: 80px;
	}

	.field-help {
		font-size: 12px;
		color: #6b7280;
		font-style: italic;
	}

	.file-help-text {
		font-size: 11px;
		color: #6b7280;
		margin-top: 4px;
		font-style: italic;
	}

	.file-selected {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px;
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		border-radius: 4px;
		margin-top: 8px;
	}

	.file-icon {
		font-size: 16px;
	}

	.file-name {
		color: #065f46;
		font-size: 13px;
	}

	.file-size {
		color: #059669;
		font-size: 12px;
	}

	.form-actions {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.upload-btn {
		background: #7c3aed;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 12px 24px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.upload-btn:hover:not(:disabled) {
		background: #6d28d9;
	}

	.upload-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.reset-btn {
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 12px 20px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.reset-btn:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.existing-documents-section h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
	}

	.loading {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 40px;
		text-align: center;
		color: #6b7280;
	}

	.empty-state {
		text-align: center;
		padding: 40px;
		color: #6b7280;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-subtitle {
		font-size: 14px;
		margin-top: 8px;
	}

	.documents-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 16px;
	}

	.document-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		transition: all 0.2s;
	}

	.document-card:hover {
		border-color: #7c3aed;
		box-shadow: 0 4px 12px rgba(124, 58, 237, 0.1);
	}

	.document-header {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 16px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.document-icon {
		font-size: 20px;
	}

	.document-title {
		flex: 1;
		font-weight: 500;
		color: #111827;
	}

	.delete-btn {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		border-radius: 4px;
		padding: 4px 8px;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.delete-btn:hover {
		background: #fee2e2;
	}

	.document-details {
		padding: 16px;
	}

	.detail-item {
		margin-bottom: 8px;
		font-size: 13px;
		line-height: 1.4;
	}

	.detail-item strong {
		color: #374151;
	}

	.detail-item.description {
		margin-bottom: 12px;
	}

	.detail-item.category strong {
		color: #7c3aed;
	}

	.document-actions {
		padding: 12px 16px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
	}

	.view-btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		color: #7c3aed;
		text-decoration: none;
		font-size: 13px;
		font-weight: 500;
		padding: 4px 8px;
		border-radius: 4px;
		transition: all 0.2s;
	}

	.view-btn:hover {
		background: #ede9fe;
	}

	.spinner {
		width: 14px;
		height: 14px;
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@media (max-width: 768px) {
		.other-documents-manager {
			padding: 16px;
		}
		
		.form-grid {
			grid-template-columns: 1fr;
		}
		
		.form-actions {
			flex-direction: column;
			align-items: stretch;
		}
		
		.documents-grid {
			grid-template-columns: 1fr;
		}
	}
</style>