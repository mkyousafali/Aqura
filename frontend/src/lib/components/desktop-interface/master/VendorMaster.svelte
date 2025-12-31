<script>
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import UploadVendor from '$lib/components/desktop-interface/master/vendor/UploadVendor.svelte';
	import ManageVendor from '$lib/components/desktop-interface/master/vendor/ManageVendor.svelte';

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Vendor Master dashboard buttons
	const vendorButtons = [
		{
			id: 'upload-vendor',
			title: 'Upload Vendor',
			description: 'Import vendor data from Excel files',
			icon: '📤',
			color: 'blue'
		},
		{
			id: 'manage-vendor',
			title: 'Manage Vendor',
			description: 'View, edit and manage vendor records',
			icon: '🏪',
			color: 'green'
		}
	];

	function openVendorWindow(vendorOperation) {
		const windowId = generateWindowId(vendorOperation.id);
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		if (vendorOperation.id === 'upload-vendor') {
			// Open Upload Vendor component
			openWindow({
				id: windowId,
				title: `Upload Vendor #${instanceNumber}`,
				component: UploadVendor,
				icon: vendorOperation.icon,
				size: { width: 900, height: 700 },
				position: { 
					x: 100 + (Math.random() * 100),
					y: 100 + (Math.random() * 100) 
				},
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		} else if (vendorOperation.id === 'manage-vendor') {
			// Open Manage Vendor component
			openWindow({
				id: windowId,
				title: `Manage Vendor #${instanceNumber}`,
				component: ManageVendor,
				icon: vendorOperation.icon,
				size: { width: 1200, height: 800 },
				position: { 
					x: 80 + (Math.random() * 100),
					y: 80 + (Math.random() * 100) 
				},
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		}
	}
</script>

<!-- Vendor Master Dashboard -->
<div class="vendor-master">
	<div class="header">
		<div class="title-section">
			<h1 class="title">🏪 Vendor Master</h1>
			<p class="subtitle">Vendor Management Dashboard</p>
		</div>
	</div>

	<!-- Dashboard Grid -->
	<div class="dashboard-grid">
		{#each vendorButtons as button}
			<div class="dashboard-card {button.color}" on:click={() => openVendorWindow(button)}>
				<div class="card-icon">
					<span class="icon">{button.icon}</span>
				</div>
				<div class="card-content">
					<h3 class="card-title">{button.title}</h3>
					<p class="card-description">{button.description}</p>
				</div>
				<div class="card-arrow">
					<span>→</span>
				</div>
			</div>
		{/each}
	</div>

	<!-- Quick Info Section -->
	<div class="info-section">
		<div class="info-header">
			<h2>🏪 Vendor Management Features</h2>
		</div>
		<div class="features-grid">
			<div class="feature-item">
				<div class="feature-icon">📤</div>
				<h4>Bulk Upload</h4>
				<p>Import multiple vendors from Excel files with validation</p>
			</div>
			<div class="feature-item">
				<div class="feature-icon">🔍</div>
				<h4>Search & Filter</h4>
				<p>Find vendors quickly by name, ID, or other criteria</p>
			</div>
			<div class="feature-item">
				<div class="feature-icon">✏️</div>
				<h4>Edit & Manage</h4>
				<p>Update vendor information and manage relationships</p>
			</div>
			<div class="feature-item">
				<div class="feature-icon">📊</div>
				<h4>Reports & Export</h4>
				<p>Generate vendor reports and export data</p>
			</div>
		</div>
	</div>
</div>

<style>
	.vendor-master {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.header {
		margin-bottom: 32px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
		text-align: center;
	}

	.title-section .title {
		font-size: 32px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.title-section .subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
		gap: 24px;
		margin-bottom: 40px;
	}

	.dashboard-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 16px;
		padding: 32px 24px;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		gap: 20px;
		position: relative;
		overflow: hidden;
	}

	.dashboard-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.dashboard-card.blue:hover {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
	}

	.dashboard-card.green:hover {
		border-color: #10b981;
		background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
	}

	.dashboard-card.purple:hover {
		border-color: #8b5cf6;
		background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
	}

	.card-icon {
		width: 64px;
		height: 64px;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.blue .card-icon {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
	}

	.green .card-icon {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.purple .card-icon {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
	}

	.card-icon .icon {
		font-size: 28px;
		color: white;
	}

	.card-content {
		flex: 1;
	}

	.card-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.5;
	}

	.card-arrow {
		font-size: 24px;
		color: #9ca3af;
		transition: all 0.3s ease;
	}

	.dashboard-card:hover .card-arrow {
		color: #374151;
		transform: translateX(4px);
	}

	.info-section {
		background: #f9fafb;
		border-radius: 16px;
		padding: 32px;
	}

	.info-header {
		text-align: center;
		margin-bottom: 32px;
	}

	.info-header h2 {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.features-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
		gap: 24px;
	}

	.feature-item {
		text-align: center;
		padding: 20px;
	}

	.feature-icon {
		font-size: 32px;
		margin-bottom: 12px;
	}

	.feature-item h4 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.feature-item p {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.5;
	}
</style>