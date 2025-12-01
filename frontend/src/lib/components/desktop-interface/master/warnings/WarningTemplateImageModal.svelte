<script>
	import { createEventDispatcher } from 'svelte';
	
	export let imageUrl;
	export let warning;
	
	const dispatch = createEventDispatcher();
	
	let loading = true;
	let imageError = false;
	let imageElement;
	
	function handleImageLoad() {
		loading = false;
		imageError = false;
	}
	
	function handleImageError() {
		loading = false;
		imageError = true;
	}
	
	function downloadImage() {
		const link = document.createElement('a');
		link.href = imageUrl;
		link.download = `warning-template-${warning.hr_employees?.name || warning.username}-${warning.warning_reference || warning.id}.png`;
		document.body.appendChild(link);
		link.click();
		document.body.removeChild(link);
	}
	
	function openImageInNewTab() {
		window.open(imageUrl, '_blank');
	}
</script>

<div class="modal-container">
	<!-- Header -->
	<div class="modal-header">
		<div class="header-info">
			<h2 class="modal-title">Warning Template</h2>
			<div class="employee-info">
				<span class="employee-name">{warning.hr_employees?.name || warning.username}</span>
				<span class="warning-ref">{warning.warning_reference || `ID: ${warning.id}`}</span>
			</div>
		</div>
		<div class="header-actions">
			<button class="download-btn" on:click={downloadImage} title="Download Image">
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
				</svg>
				Download
			</button>
			<button class="open-btn" on:click={openImageInNewTab} title="Open in New Tab">
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
				</svg>
				Open
			</button>
		</div>
	</div>
	
	<!-- Image Container -->
	<div class="image-container">
		{#if loading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>Loading template image...</p>
			</div>
		{/if}
		
		{#if imageError}
			<div class="error-state">
				<div class="error-icon">📄</div>
				<h3>Image Not Available</h3>
				<p>The warning template image could not be loaded.</p>
				<p class="error-url">URL: {imageUrl}</p>
			</div>
		{:else}
			<img 
				bind:this={imageElement}
				src={imageUrl} 
				alt="Warning Template for {warning.hr_employees?.name || warning.username}"
				class="warning-image"
				on:load={handleImageLoad}
				on:error={handleImageError}
			/>
		{/if}
	</div>
	
	<!-- Footer Info -->
	<div class="modal-footer">
		<div class="image-info">
			<span class="info-item">
				<strong>Warning Type:</strong> 
				{warning.warning_type?.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()) || 'Unknown'}
			</span>
			<span class="info-item">
				<strong>Issued:</strong> 
				{warning.issued_at ? new Date(warning.issued_at).toLocaleDateString() : 'Unknown'}
			</span>
			<span class="info-item">
				<strong>Status:</strong> 
				{warning.warning_status || 'Unknown'}
			</span>
		</div>
	</div>
</div>

<style>
	.modal-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
		border-radius: 8px;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.header-info {
		flex: 1;
	}

	.modal-title {
		margin: 0 0 8px 0;
		font-size: 18px;
		font-weight: 600;
		color: #111827;
	}

	.employee-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.employee-name {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.warning-ref {
		font-size: 12px;
		color: #6b7280;
	}

	.header-actions {
		display: flex;
		gap: 8px;
	}

	.download-btn, .open-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.download-btn:hover {
		background: #f3f4f6;
		border-color: #9ca3af;
	}

	.open-btn:hover {
		background: #f3f4f6;
		border-color: #9ca3af;
	}

	.image-container {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 20px;
		overflow: auto;
		background: #f8fafc;
	}

	.warning-image {
		max-width: 100%;
		max-height: 100%;
		border-radius: 8px;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
		background: white;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
		color: #6b7280;
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

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		color: #6b7280;
		text-align: center;
	}

	.error-icon {
		font-size: 48px;
		opacity: 0.5;
	}

	.error-state h3 {
		margin: 0;
		font-size: 18px;
		color: #374151;
	}

	.error-state p {
		margin: 0;
		font-size: 14px;
	}

	.error-url {
		font-family: monospace;
		font-size: 12px !important;
		background: #f3f4f6;
		padding: 8px 12px;
		border-radius: 4px;
		word-break: break-all;
	}

	.modal-footer {
		padding: 16px 24px;
		border-top: 1px solid #e5e7eb;
		background: white;
	}

	.image-info {
		display: flex;
		flex-wrap: wrap;
		gap: 16px;
		font-size: 14px;
	}

	.info-item {
		color: #374151;
	}

	.info-item strong {
		color: #111827;
	}

	@media (max-width: 768px) {
		.modal-header {
			flex-direction: column;
			align-items: flex-start;
			gap: 12px;
		}

		.header-actions {
			width: 100%;
			justify-content: flex-end;
		}

		.image-info {
			flex-direction: column;
			gap: 8px;
		}
	}
</style>