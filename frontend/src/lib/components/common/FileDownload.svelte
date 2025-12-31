<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	
	const dispatch = createEventDispatcher();
	
	// Props
	export let files: Array<{
		fileName: string;
		fileUrl: string;
		fileSize?: number;
		fileType?: string;
		uploadedAt?: string;
		uploadedBy?: string;
	}> = [];
	export let showDetails: boolean = true;
	export let allowDelete: boolean = false;
	export let compact: boolean = false;
	export let maxHeight: string = '300px';
	
	// Helper function to format file size
	function formatFileSize(bytes: number): string {
		if (!bytes || bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}
	
	// Helper function to get file icon based on type or extension
	function getFileIcon(fileName: string, fileType?: string): string {
		// Add null/undefined checks
		if (!fileName || typeof fileName !== 'string') {
			return '📄'; // Default file icon
		}
		
		const extension = fileName.split('.').pop()?.toLowerCase() || '';
		
		// Check MIME type first
		if (fileType) {
			if (fileType.startsWith('image/')) return '🖼️';
			if (fileType.includes('pdf')) return '📄';
			if (fileType.includes('sheet') || fileType.includes('excel')) return '📊';
			if (fileType.includes('document') || fileType.includes('word')) return '📝';
			if (fileType.includes('text')) return '📃';
		}
		
		// Check file extension
		switch (extension) {
			case 'pdf': return '📄';
			case 'doc':
			case 'docx': return '📝';
			case 'xls':
			case 'xlsx':
			case 'csv': return '📊';
			case 'sql': return '🗄️';
			case 'txt':
			case 'log': return '📃';
			case 'jpg':
			case 'jpeg':
			case 'png':
			case 'gif':
			case 'webp':
			case 'svg': return '🖼️';
			case 'zip':
			case 'rar':
			case '7z': return '📦';
			case 'mp4':
			case 'avi':
			case 'mov': return '🎬';
			case 'mp3':
			case 'wav':
			case 'ogg': return '🎵';
			default: return '📎';
		}
	}
	
	// Format date
	function formatDate(dateString?: string): string {
		if (!dateString) return '';
		try {
			const date = new Date(dateString);
			return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
		} catch {
			return dateString;
		}
	}
	
	// Download file
	async function downloadFile(file: any) {
		try {
			dispatch('download', { file });
			
			// Create download link
			const link = document.createElement('a');
			link.href = file.fileUrl;
			link.download = file.fileName;
			link.target = '_blank';
			
			// Trigger download
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			
		} catch (error) {
			console.error('Download failed:', error);
			dispatch('downloadError', { file, error });
		}
	}
	
	// Delete file
	function deleteFile(file: any, index: number) {
		dispatch('delete', { file, index });
	}
	
	// Preview file (for images and PDFs)
	function previewFile(file: any) {
		const extension = file.fileName.split('.').pop()?.toLowerCase();
		const isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].includes(extension || '');
		const isPdf = extension === 'pdf';
		
		if (isImage || isPdf) {
			dispatch('preview', { file });
			// Open in new window for preview
			window.open(file.fileUrl, '_blank');
		} else {
			// For other files, just download
			downloadFile(file);
		}
	}
</script>

<div class="file-list-wrapper" style="max-height: {maxHeight};">
	{#if files.length === 0}
		<div class="no-files">
			<div class="no-files-icon">📁</div>
			<p class="no-files-text">No files attached</p>
		</div>
	{:else}
		<div class="files-container" class:compact>
			{#each files as file, index}
				<div class="file-item" class:compact>
					<!-- File Icon -->
					<div class="file-icon">
						{getFileIcon(file.fileName, file.fileType)}
					</div>
					
					<!-- File Info -->
					<div class="file-info">
						<div class="file-name" title={file.fileName}>
							{file.fileName}
						</div>
						
						{#if showDetails && !compact}
							<div class="file-details">
								{#if file.fileSize}
									<span class="file-size">{formatFileSize(file.fileSize)}</span>
								{/if}
								{#if file.fileType}
									<span class="file-type">{file.fileType}</span>
								{/if}
								{#if file.uploadedAt}
									<span class="file-date">{formatDate(file.uploadedAt)}</span>
								{/if}
								{#if file.uploadedBy}
									<span class="file-uploader">by {file.uploadedBy}</span>
								{/if}
							</div>
						{/if}
					</div>
					
					<!-- Actions -->
					<div class="file-actions">
						<!-- Preview/Open Button -->
						<button
							type="button"
							class="action-btn preview-btn"
							on:click={() => previewFile(file)}
							title="Preview/Open file"
						>
							👁️
						</button>
						
						<!-- Download Button -->
						<button
							type="button"
							class="action-btn download-btn"
							on:click={() => downloadFile(file)}
							title="Download file"
						>
							⬇️
						</button>
						
						<!-- Delete Button -->
						{#if allowDelete}
							<button
								type="button"
								class="action-btn delete-btn"
								on:click={() => deleteFile(file, index)}
								title="Delete file"
							>
								🗑️
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.file-list-wrapper {
		width: 100%;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		background: white;
	}
	
	.no-files {
		padding: 40px 20px;
		text-align: center;
		color: #6b7280;
	}
	
	.no-files-icon {
		font-size: 48px;
		margin-bottom: 12px;
	}
	
	.no-files-text {
		margin: 0;
		font-size: 14px;
	}
	
	.files-container {
		padding: 8px;
	}
	
	.files-container.compact {
		padding: 4px;
	}
	
	.file-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		border: 1px solid #f3f4f6;
		border-radius: 6px;
		margin-bottom: 8px;
		background: #fafafa;
		transition: all 0.2s ease;
	}
	
	.file-item:hover {
		background: #f0f9ff;
		border-color: #e0e7ff;
	}
	
	.file-item.compact {
		padding: 8px;
		gap: 8px;
	}
	
	.file-item:last-child {
		margin-bottom: 0;
	}
	
	.file-icon {
		font-size: 24px;
		min-width: 32px;
		text-align: center;
	}
	
	.file-info {
		flex: 1;
		min-width: 0; /* Allow text truncation */
	}
	
	.file-name {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 4px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	
	.file-details {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		font-size: 11px;
		color: #6b7280;
	}
	
	.file-size,
	.file-type,
	.file-date,
	.file-uploader {
		padding: 2px 6px;
		background: #f3f4f6;
		border-radius: 3px;
		white-space: nowrap;
	}
	
	.file-actions {
		display: flex;
		gap: 4px;
		align-items: center;
	}
	
	.action-btn {
		width: 32px;
		height: 32px;
		border: none;
		border-radius: 4px;
		background: #f9fafb;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
	}
	
	.action-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}
	
	.preview-btn:hover {
		background: #dbeafe;
	}
	
	.download-btn:hover {
		background: #dcfce7;
	}
	
	.delete-btn:hover {
		background: #fee2e2;
	}
	
	.action-btn:active {
		transform: translateY(0);
	}
	
	/* Compact mode adjustments */
	.compact .file-icon {
		font-size: 20px;
		min-width: 24px;
	}
	
	.compact .file-name {
		font-size: 13px;
		margin-bottom: 2px;
	}
	
	.compact .file-details {
		font-size: 10px;
		gap: 4px;
	}
	
	.compact .action-btn {
		width: 28px;
		height: 28px;
		font-size: 12px;
	}
</style>