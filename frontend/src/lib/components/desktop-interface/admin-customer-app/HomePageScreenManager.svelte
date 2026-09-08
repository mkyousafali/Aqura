<script lang="ts">
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import VideoTemplatesManager from '$lib/components/desktop-interface/admin-customer-app/VideoTemplatesManager.svelte';
	import ImageTemplatesManager from '$lib/components/desktop-interface/admin-customer-app/ImageTemplatesManager.svelte';

	// Generate unique window ID
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Open Video Templates Manager
	function openVideoManager() {
		const windowId = generateWindowId('video-templates');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Video Templates #${instanceNumber}`,
			component: VideoTemplatesManager,
			icon: '🎥',
			size: { width: 1500, height: 900 },
			position: { 
				x: 50 + (Math.random() * 50),
				y: 50 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open Image Templates Manager
	function openImageManager() {
		const windowId = generateWindowId('image-templates');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Image Templates #${instanceNumber}`,
			component: ImageTemplatesManager,
			icon: '🖼️',
			size: { width: 1500, height: 900 },
			position: { 
				x: 70 + (Math.random() * 50),
				y: 70 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="screen-manager-container">
	<div class="screen-manager-header">
		<h2>🖼️ Home Page Screen Manager</h2>
		<p class="subtitle">Manage media content displayed on customer app home page</p>
	</div>
	
	<div class="screen-manager-content">
		<div class="media-type-grid">
			<!-- Video Templates Button -->
			<button class="media-type-card video-card" on:click={openVideoManager}>
				<div class="card-header">
					<div class="card-icon">🎥</div>
					<h3>Video Templates</h3>
				</div>
				<div class="card-body">
					<p>Manage 6 video slots for the customer home page carousel</p>
					<ul class="feature-list">
						<li>Upload MP4, WebM videos</li>
						<li>Preview in customer app size</li>
						<li>Set expiry dates or infinite</li>
						<li>Activate/Deactivate display</li>
					</ul>
				</div>
				<div class="card-footer">
					<span class="open-button">Open Video Manager →</span>
				</div>
			</button>

			<!-- Image Templates Button -->
			<button class="media-type-card image-card" on:click={openImageManager}>
				<div class="card-header">
					<div class="card-icon">🖼️</div>
					<h3>Image Templates</h3>
				</div>
				<div class="card-body">
					<p>Manage 6 image slots for the customer home page carousel</p>
					<ul class="feature-list">
						<li>Upload JPG, PNG, WebP images</li>
						<li>Preview in customer app size</li>
						<li>Set expiry dates or infinite</li>
						<li>Activate/Deactivate display</li>
					</ul>
				</div>
				<div class="card-footer">
					<span class="open-button">Open Image Manager →</span>
				</div>
			</button>
		</div>

		<!-- Info Section -->
		<div class="info-section">
			<div class="info-card">
				<div class="info-icon">ℹ️</div>
				<div class="info-content">
					<h4>How it works</h4>
					<p>Videos and images you upload will be displayed on the customer app home page in a rotating carousel. 
					Each media type (video/image) has 6 available slots. Only active and non-expired media will be shown to customers.</p>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.screen-manager-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
	}

	.screen-manager-header {
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e2e8f0;
	}

	.screen-manager-header h2 {
		margin: 0 0 0.5rem 0;
		color: #1e293b;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.subtitle {
		margin: 0;
		color: #64748b;
		font-size: 0.875rem;
	}

	.screen-manager-content {
		flex: 1;
		padding: 2rem;
		overflow-y: auto;
	}

	.media-type-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
		gap: 2rem;
		margin-bottom: 2rem;
	}

	.media-type-card {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 16px;
		padding: 0;
		cursor: pointer;
		transition: all 0.3s ease;
		text-align: left;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.media-type-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 12px 24px rgba(0, 0, 0, 0.1);
	}

	.video-card:hover {
		border-color: #ef4444;
	}

	.image-card:hover {
		border-color: #3b82f6;
	}

	.card-header {
		padding: 1.5rem;
		background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.video-card .card-header {
		background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
	}

	.image-card .card-header {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
	}

	.card-icon {
		font-size: 2.5rem;
	}

	.card-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.card-body {
		padding: 1.5rem;
		flex: 1;
	}

	.card-body p {
		margin: 0 0 1rem 0;
		color: #475569;
		line-height: 1.6;
	}

	.feature-list {
		margin: 0;
		padding-left: 1.5rem;
		color: #64748b;
		font-size: 0.875rem;
	}

	.feature-list li {
		margin-bottom: 0.5rem;
	}

	.card-footer {
		padding: 1rem 1.5rem;
		background: #f8fafc;
		border-top: 1px solid #e2e8f0;
	}

	.open-button {
		color: #3b82f6;
		font-weight: 600;
		font-size: 0.9375rem;
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		transition: gap 0.2s ease;
	}

	.media-type-card:hover .open-button {
		gap: 0.75rem;
	}

	.info-section {
		max-width: 900px;
	}

	.info-card {
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 12px;
		padding: 1.5rem;
		display: flex;
		gap: 1rem;
	}

	.info-icon {
		font-size: 1.5rem;
		flex-shrink: 0;
	}

	.info-content h4 {
		margin: 0 0 0.5rem 0;
		color: #1e40af;
		font-size: 1rem;
		font-weight: 600;
	}

	.info-content p {
		margin: 0;
		color: #1e40af;
		font-size: 0.875rem;
		line-height: 1.6;
	}
</style>
