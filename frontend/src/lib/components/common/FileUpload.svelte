<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { uploadToSupabase } from '$lib/utils/supabase';
	
	const dispatch = createEventDispatcher();
	
	// Props
	export let acceptedTypes: string = 'image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt,.sql'; // Default accepted types
	export let maxSizeInMB: number = 10; // Default 10MB
	export let bucket: string = 'documents'; // Default bucket
	export let multiple: boolean = false; // Allow multiple files
	export let showPreview: boolean = true; // Show file preview
	export let label: string = 'Upload File (optional)';
	export let placeholder: string = 'Choose files or drag and drop here';
	export let required: boolean = false;
	export let disabled: boolean = false;
	export let currentFiles: File[] = []; // For external file management
	export let previewUrls: string[] = []; // For external preview management
	export let uploadedUrls: string[] = []; // For tracking uploaded file URLs
	
	// Internal state
	let dragActive = false;
	let isUploading = false;
	let uploadProgress = 0;
	let errors: string[] = [];
	
	// File input reference
	let fileInput: HTMLInputElement;
	
	// Helper function to format file size
	function formatFileSize(bytes: number): string {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}
	
	// Helper function to get file icon based on type
	function getFileIcon(fileType: string): string {
		if (fileType.startsWith('image/')) return '🖼️';
		if (fileType.includes('pdf')) return '📄';
		if (fileType.includes('sheet') || fileType.includes('excel') || fileType.includes('.xls')) return '📊';
		if (fileType.includes('document') || fileType.includes('word') || fileType.includes('.doc')) return '📝';
		if (fileType.includes('sql')) return '🗄️';
		if (fileType.includes('text')) return '📃';
		return '📎';
	}
	
	// Validate file
	function validateFile(file: File): string | null {
		// Check file size
		if (file.size > maxSizeInMB * 1024 * 1024) {
			return `File size must be less than ${maxSizeInMB}MB`;
		}
		
		// Check file type if acceptedTypes is specified
		if (acceptedTypes && acceptedTypes !== '*') {
			const types = acceptedTypes.split(',').map(t => t.trim());
			let isValidType = false;
			
			for (const type of types) {
				if (type.startsWith('.')) {
					// File extension check
					if (file.name.toLowerCase().endsWith(type.toLowerCase())) {
						isValidType = true;
						break;
					}
				} else if (type.includes('*')) {
					// MIME type with wildcard
					const baseType = type.split('/')[0];
					if (file.type.startsWith(baseType + '/')) {
						isValidType = true;
						break;
					}
				} else if (file.type === type) {
					// Exact MIME type match
					isValidType = true;
					break;
				}
			}
			
			if (!isValidType) {
				return `File type not supported. Accepted types: ${acceptedTypes}`;
			}
		}
		
		return null;
	}
	
	// Handle file input change
	function handleFileChange(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = Array.from(target.files || []);
		processFiles(files);
	}
	
	// Process selected files
	function processFiles(files: File[]) {
		errors = [];
		const validFiles: File[] = [];
		const newPreviewUrls: string[] = [];
		
		// Validate each file
		for (const file of files) {
			const error = validateFile(file);
			if (error) {
				errors.push(`${file.name}: ${error}`);
			} else {
				validFiles.push(file);
				
				// Create preview URL for images
				if (file.type.startsWith('image/') && showPreview) {
					const reader = new FileReader();
					reader.onload = (e) => {
						if (e.target?.result) {
							newPreviewUrls.push(e.target.result as string);
							previewUrls = [...previewUrls, ...newPreviewUrls];
						}
					};
					reader.readAsDataURL(file);
				}
			}
		}
		
		// Update files
		if (multiple) {
			currentFiles = [...currentFiles, ...validFiles];
		} else {
			currentFiles = validFiles.slice(0, 1);
			previewUrls = previewUrls.slice(0, 1);
		}
		
		// Dispatch event
		dispatch('filesChanged', { files: currentFiles, errors });
	}
	
	// Remove file
	function removeFile(index: number) {
		currentFiles = currentFiles.filter((_, i) => i !== index);
		previewUrls = previewUrls.filter((_, i) => i !== index);
		uploadedUrls = uploadedUrls.filter((_, i) => i !== index);
		
		// Clear file input if no files left
		if (currentFiles.length === 0 && fileInput) {
			fileInput.value = '';
		}
		
		dispatch('filesChanged', { files: currentFiles, errors: [] });
	}
	
	// Upload files to storage
	export async function uploadFiles(): Promise<{success: boolean, uploadedFiles: any[], errors: string[]}> {
		if (currentFiles.length === 0) {
			return { success: true, uploadedFiles: [], errors: [] };
		}
		
		isUploading = true;
		uploadProgress = 0;
		const uploadErrors: string[] = [];
		const uploadedFileData: any[] = [];
		
		try {
			for (let i = 0; i < currentFiles.length; i++) {
				const file = currentFiles[i];
				uploadProgress = Math.round(((i + 0.5) / currentFiles.length) * 100);
				
				// Generate unique filename
				const timestamp = Date.now();
				const fileExtension = file.name.split('.').pop() || 'bin';
				const uniqueFileName = `file-${timestamp}-${Math.random().toString(36).substring(2)}.${fileExtension}`;
				
				try {
					const uploadResult = await uploadToSupabase(file, bucket, uniqueFileName);
					
					if (uploadResult.error) {
						uploadErrors.push(`${file.name}: ${uploadResult.error.message}`);
					} else {
						uploadedFileData.push({
							fileName: file.name,
							filePath: uniqueFileName,
							fileSize: file.size,
							fileType: file.type,
							fileUrl: uploadResult.data?.publicUrl || '',
							originalFile: file
						});
						
						// Add to uploadedUrls for tracking
						if (uploadResult.data?.publicUrl) {
							uploadedUrls = [...uploadedUrls, uploadResult.data.publicUrl];
						}
					}
				} catch (error) {
					uploadErrors.push(`${file.name}: Upload failed`);
				}
				
				uploadProgress = Math.round(((i + 1) / currentFiles.length) * 100);
			}
			
			isUploading = false;
			uploadProgress = 100;
			
			const success = uploadErrors.length === 0;
			dispatch('uploadComplete', { 
				success, 
				uploadedFiles: uploadedFileData, 
				errors: uploadErrors 
			});
			
			return { success, uploadedFiles: uploadedFileData, errors: uploadErrors };
			
		} catch (error) {
			isUploading = false;
			uploadProgress = 0;
			const errorMsg = error instanceof Error ? error.message : 'Upload failed';
			uploadErrors.push(errorMsg);
			
			dispatch('uploadComplete', { 
				success: false, 
				uploadedFiles: [], 
				errors: uploadErrors 
			});
			
			return { success: false, uploadedFiles: [], errors: uploadErrors };
		}
	}
	
	// Drag and drop handlers
	function handleDragOver(event: DragEvent) {
		event.preventDefault();
		if (!disabled) {
			dragActive = true;
		}
	}
	
	function handleDragLeave(event: DragEvent) {
		event.preventDefault();
		dragActive = false;
	}
	
	function handleDrop(event: DragEvent) {
		event.preventDefault();
		dragActive = false;
		
		if (disabled) return;
		
		const files = Array.from(event.dataTransfer?.files || []);
		processFiles(files);
	}
	
	// Clear all files
	export function clearFiles() {
		currentFiles = [];
		previewUrls = [];
		uploadedUrls = [];
		errors = [];
		if (fileInput) {
			fileInput.value = '';
		}
		dispatch('filesChanged', { files: [], errors: [] });
	}
</script>

<div class="file-upload-wrapper">
	<!-- Label -->
	<label for="file-upload" class="file-upload-label">
		{label}
		{#if required}
			<span class="required">*</span>
		{/if}
	</label>
	
	<!-- Upload Area -->
	<div 
		class="upload-area"
		class:drag-active={dragActive}
		class:has-files={currentFiles.length > 0}
		class:disabled={disabled}
		on:dragover={handleDragOver}
		on:dragleave={handleDragLeave}
		on:drop={handleDrop}
		role="button"
		tabindex="0"
		on:click={() => !disabled && fileInput?.click()}
		on:keydown={(e) => e.key === 'Enter' && !disabled && fileInput?.click()}
	>
		{#if currentFiles.length === 0}
			<div class="upload-prompt">
				<div class="upload-icon">📁</div>
				<p class="upload-text">{placeholder}</p>
				<p class="upload-hint">
					Supported: {acceptedTypes} • Max: {maxSizeInMB}MB
					{#if multiple}• Multiple files allowed{/if}
				</p>
			</div>
		{:else}
			<div class="files-list">
				{#each currentFiles as file, index}
					<div class="file-item">
						<div class="file-info">
							<div class="file-icon">{getFileIcon(file.type)}</div>
							<div class="file-details">
								<div class="file-name">{file.name}</div>
								<div class="file-size">{formatFileSize(file.size)}</div>
								<div class="file-type">{file.type || 'Unknown type'}</div>
							</div>
						</div>
						
						<!-- Image Preview -->
						{#if file.type.startsWith('image/') && showPreview && previewUrls[index]}
							<div class="image-preview">
								<img src={previewUrls[index]} alt="Preview" />
							</div>
						{/if}
						
						<!-- Remove Button -->
						<button
							type="button"
							class="remove-file-btn"
							on:click|stopPropagation={() => removeFile(index)}
							disabled={disabled || isUploading}
							title="Remove file"
						>
							×
						</button>
					</div>
				{/each}
			</div>
		{/if}
	</div>
	
	<!-- Hidden File Input -->
	<input
		bind:this={fileInput}
		id="file-upload"
		type="file"
		accept={acceptedTypes}
		{multiple}
		{disabled}
		{required}
		on:change={handleFileChange}
		class="file-input"
	/>
	
	<!-- Upload Progress -->
	{#if isUploading}
		<div class="upload-progress">
			<div class="progress-header">
				<span>Uploading files...</span>
				<span>{uploadProgress}%</span>
			</div>
			<div class="progress-bar">
				<div class="progress-fill" style="width: {uploadProgress}%"></div>
			</div>
		</div>
	{/if}
	
	<!-- Errors -->
	{#if errors.length > 0}
		<div class="error-messages">
			{#each errors as error}
				<div class="error-message">{error}</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.file-upload-wrapper {
		width: 100%;
	}
	
	.file-upload-label {
		display: block;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 8px;
	}
	
	.required {
		color: #ef4444;
	}
	
	.upload-area {
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		padding: 20px;
		text-align: center;
		cursor: pointer;
		transition: all 0.2s ease;
		background: #f9fafb;
		min-height: 120px;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	
	.upload-area:hover:not(.disabled) {
		border-color: #9ca3af;
		background: #f3f4f6;
	}
	
	.upload-area.drag-active {
		border-color: #3b82f6;
		background: #dbeafe;
	}
	
	.upload-area.has-files {
		padding: 16px;
		text-align: left;
	}
	
	.upload-area.disabled {
		opacity: 0.6;
		cursor: not-allowed;
		background: #f5f5f5;
	}
	
	.upload-prompt {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
	}
	
	.upload-icon {
		font-size: 48px;
		color: #6b7280;
	}
	
	.upload-text {
		margin: 0;
		font-size: 16px;
		font-weight: 500;
		color: #374151;
	}
	
	.upload-hint {
		margin: 0;
		font-size: 12px;
		color: #6b7280;
	}
	
	.files-list {
		width: 100%;
	}
	
	.file-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		margin-bottom: 8px;
		position: relative;
	}
	
	.file-info {
		display: flex;
		align-items: center;
		gap: 12px;
		flex: 1;
	}
	
	.file-icon {
		font-size: 24px;
		min-width: 32px;
		text-align: center;
	}
	
	.file-details {
		flex: 1;
	}
	
	.file-name {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 2px;
		word-break: break-word;
	}
	
	.file-size {
		font-size: 12px;
		color: #6b7280;
	}
	
	.file-type {
		font-size: 11px;
		color: #9ca3af;
	}
	
	.image-preview {
		width: 60px;
		height: 60px;
		border-radius: 4px;
		overflow: hidden;
		border: 1px solid #e5e7eb;
	}
	
	.image-preview img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	
	.remove-file-btn {
		position: absolute;
		top: 4px;
		right: 4px;
		width: 24px;
		height: 24px;
		border: none;
		background: #ef4444;
		color: white;
		border-radius: 50%;
		cursor: pointer;
		font-size: 16px;
		font-weight: bold;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;
	}
	
	.remove-file-btn:hover:not(:disabled) {
		background: #dc2626;
	}
	
	.remove-file-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	
	.file-input {
		display: none;
	}
	
	.upload-progress {
		margin-top: 12px;
	}
	
	.progress-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
		font-size: 14px;
		color: #374151;
	}
	
	.progress-bar {
		width: 100%;
		height: 8px;
		background: #e5e7eb;
		border-radius: 4px;
		overflow: hidden;
	}
	
	.progress-fill {
		height: 100%;
		background: #3b82f6;
		transition: width 0.3s ease;
	}
	
	.error-messages {
		margin-top: 8px;
	}
	
	.error-message {
		font-size: 12px;
		color: #ef4444;
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 4px;
		padding: 8px;
		margin-bottom: 4px;
	}
</style>