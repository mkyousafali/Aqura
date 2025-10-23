<script lang="ts">
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import OtherDocumentsManager from './OtherDocumentsManager.svelte';

	// Props
	export let employee;

	// State management
	let employeeDocuments = [];
	let selectedFiles = {};
	let expiryDates = {};
	let documentNumbers = {};
	let isUploading = false;
	let errorMessage = '';
	let successMessage = '';

	// Document types as per requirements (excluding other documents)
	const documentTypes = [
		{ 
			key: 'health_card', 
			label: 'Health Card', 
			icon: '🏥', 
			accepts: '.jpg,.jpeg,.png,.webp', 
			requiresExpiry: true,
			requiresNumber: true,
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
			requiresNumber: true,
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
			requiresNumber: true,
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
			requiresNumber: false,
			description: 'Upload latest CV/Resume document',
			maxSize: '10MB',
			formats: ['PDF', 'DOC', 'DOCX']
		},
		{ 
			key: 'driving_license', 
			label: 'Driving License', 
			icon: '🚗', 
			accepts: '.jpg,.jpeg,.png,.webp,.pdf', 
			requiresExpiry: true,
			requiresNumber: true,
			description: 'Upload driving license (front and back if applicable)',
			maxSize: '5MB',
			formats: ['JPG', 'JPEG', 'PNG', 'WebP', 'PDF']
		}
	];

	onMount(async () => {
		if (employee) {
			await loadEmployeeDocuments(employee.id);
		}
	});

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

	function handleFileSelect(documentKey, event) {
		const file = event.target.files[0];
		if (file) {
			selectedFiles = { ...selectedFiles, [documentKey]: file };
		}
	}

	async function uploadDocument(documentKey) {
		const file = selectedFiles[documentKey];
		if (!file) return;

		const docType = documentTypes.find(dt => dt.key === documentKey);
		if (!docType) return;

		// Validate expiry date for required documents
		if (docType.requiresExpiry && !expiryDates[documentKey]) {
			errorMessage = 'Expiry date is required for this document';
			return;
		}

		// Validate document number for required documents
		if (docType.requiresNumber && !documentNumbers[documentKey]?.trim()) {
			errorMessage = 'Document number is required for this document';
			return;
		}

		isUploading = true;
		errorMessage = '';
		successMessage = '';

		try {
			// File upload to Supabase Storage
			const fileExtension = file.name.split('.').pop();
			const fileName = `${employee.employee_id}_${documentKey}_${Date.now()}.${fileExtension}`;
			const storagePath = `employees/${employee.employee_id}/${fileName}`;

			// Upload to Supabase Storage bucket
			const { data: uploadData, error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(storagePath, file, {
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

			// Prepare document data for database
			const documentData = {
				employee_id: employee.id,
				document_type: documentKey,
				document_name: docType.label,
				document_number: documentNumbers[documentKey] || null,
				file_path: publicUrl,
				file_type: file.type,
				expiry_date: expiryDates[documentKey] || null
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

			// Reset this document's form
			delete selectedFiles[documentKey];
			delete expiryDates[documentKey];
			delete documentNumbers[documentKey];

			// Clear file input
			const fileInput = document.querySelector(`input[data-document="${documentKey}"]`) as HTMLInputElement;
			if (fileInput) fileInput.value = '';

			successMessage = `${docType.label} uploaded successfully!`;
			
			// Reload employee documents
			await loadEmployeeDocuments(employee.id);
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
			
			// Reload employee documents
			await loadEmployeeDocuments(employee.id);
		} catch (error) {
			console.error('Failed to delete document:', error);
			errorMessage = error.message || 'Failed to delete document';
		}
	}

	// Get existing document for a document type
	function getExistingDocument(documentKey) {
		return employeeDocuments.find(doc => doc.document_type === documentKey);
	}

	// Helper function to format dates
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString();
	}

	// Helper function to check if a document is expiring soon
	function isExpiringSoon(expiryDate) {
		if (!expiryDate) return false;
		const expiry = new Date(expiryDate);
		const today = new Date();
		const daysDiff = Math.ceil((expiry.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
		return daysDiff <= 30 && daysDiff >= 0; // Expiring within 30 days
	}

	// Helper function to format file size
	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
	}

	function openOtherDocumentsWindow() {
		const windowId = `other-documents-${employee.id}-${Date.now()}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `📋 Other Documents - ${employee.name} (#${instanceNumber})`,
			component: OtherDocumentsManager,
			props: { employee },
			icon: '📋',
			size: { width: 1200, height: 800 },
			position: { 
				x: 70 + (Math.random() * 100), 
				y: 70 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="employee-document-manager">
	<!-- Header -->
	<div class="header">
		<div class="employee-info">
			<h2>📄 Document Management</h2>
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
							{#if existingDoc.document_number}
								<span class="doc-number">#{existingDoc.document_number}</span>
							{/if}
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
								{#if docType.requiresNumber}
									<div class="requirement-item">
										<strong>🔢 Document Number:</strong>
										<span class="number-required">Required</span>
									</div>
								{/if}
							</div>
						</div>



						<div class="form-group">
							<label for="doc-number-{docType.key}">
								Document Number {docType.requiresNumber ? '*' : ''}
							</label>
							<input 
								id="doc-number-{docType.key}"
								type="text" 
								bind:value={documentNumbers[docType.key]}
								placeholder="Enter document number or ID"
								class="form-input"
								required={docType.requiresNumber}
							/>
							<div class="field-help-text">
								{docType.requiresNumber ? 'Required: ' : 'Optional: '}Enter the document's reference number, ID, or serial number
							</div>
						</div>

						<div class="form-group">
							<label for="file-{docType.key}">Select File *</label>
							<input 
								id="file-{docType.key}"
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
								<label for="expiry-{docType.key}">Expiry Date *</label>
								<input 
									id="expiry-{docType.key}"
									type="date" 
									bind:value={expiryDates[docType.key]}
									class="form-input"
									required
								/>
							</div>
						{:else if !docType.requiresExpiry && docType.key !== 'resume'}
							<div class="form-group">
								<label for="expiry-{docType.key}">Expiry Date (Optional)</label>
								<input 
									id="expiry-{docType.key}"
									type="date" 
									bind:value={expiryDates[docType.key]}
									class="form-input"
								/>
							</div>
						{/if}

						<button 
							class="upload-doc-btn"
							on:click={() => uploadDocument(docType.key)}
							disabled={isUploading || !selectedFiles[docType.key] || (docType.requiresNumber && !documentNumbers[docType.key]?.trim())}
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

	<!-- Other Documents Section -->
	<div class="other-documents-section">
		<div class="section-header">
			<h3>📋 Other Documents</h3>
			<p>Upload additional documents like certificates, licenses, or any other relevant files</p>
		</div>
		
		<button 
			class="add-other-btn"
			on:click={openOtherDocumentsWindow}
		>
			<span class="btn-icon">📋</span>
			<span class="btn-text">Manage Other Documents</span>
			<span class="btn-arrow">→</span>
		</button>
	</div>
</div>

<style>
	.employee-document-manager {
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

	.doc-number {
		display: inline-block;
		background: #dbeafe;
		color: #1e40af;
		padding: 2px 6px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		margin-bottom: 4px;
		margin-right: 8px;
	}

	.doc-number {
		display: block;
		font-size: 12px;
		color: #6366f1;
		font-weight: 500;
		margin-bottom: 4px;
		background: #eef2ff;
		padding: 2px 6px;
		border-radius: 4px;
		display: inline-block;
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
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 8px 12px;
		font-size: 14px;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.1);
	}

	.file-input::-webkit-file-upload-button {
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		padding: 4px 8px;
		margin-right: 12px;
		cursor: pointer;
		font-size: 12px;
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

	.file-help-text {
		font-size: 11px;
		color: #6b7280;
		margin-top: 4px;
		font-style: italic;
	}

	.field-help-text {
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

	.number-required {
		color: #dc2626;
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

	.other-documents-section {
		margin-top: 32px;
		padding: 24px;
		border: 2px dashed #d1d5db;
		border-radius: 12px;
		background: #f8fafc;
		text-align: center;
	}

	.section-header {
		margin-bottom: 20px;
	}

	.section-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.section-header p {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
	}

	.add-other-btn {
		background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%);
		color: white;
		border: none;
		border-radius: 12px;
		padding: 16px 32px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		gap: 12px;
		transition: all 0.3s;
		box-shadow: 0 4px 12px rgba(124, 58, 237, 0.2);
	}

	.add-other-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 20px rgba(124, 58, 237, 0.3);
	}

	.btn-icon {
		font-size: 20px;
	}

	.btn-text {
		flex: 1;
	}

	.btn-arrow {
		font-size: 18px;
		transition: transform 0.2s;
	}

	.add-other-btn:hover .btn-arrow {
		transform: translateX(4px);
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
		.employee-document-manager {
			padding: 16px;
		}
		
		.document-section {
			padding: 16px;
		}
		
		.section-title h4 {
			font-size: 14px;
		}
		
		.requirement-item {
			flex-direction: column;
			align-items: flex-start;
			gap: 4px;
		}
		
		.requirement-item strong {
			min-width: unset;
		}
	}
</style>