<script>
	import { onMount } from 'svelte';
	import { deliveryTiers, deliverySettings, deliveryActions, deliveryDataLoading } from '$lib/stores/delivery.js';
	import { supabase } from '$lib/utils/supabase';
	
	// Active tab
	let activeTab = 'tiers'; // 'tiers', 'settings', 'branches'

	// Tiers scope (global or per-branch)
	// Branch tier management (global removed)
	let tierBranchId = null; // selected branch id for tiers tab (required)
	
	// Tier editing
	let editingTier = null;
	let showTierModal = false;
	let isEditMode = false;
	let tierForm = {
		minOrderAmount: 0,
		maxOrderAmount: null,
		deliveryFee: 0,
		tierOrder: 1,
		descriptionEn: '',
		descriptionAr: '',
		isActive: true
	};
	
	// Settings form
	let settingsForm = {
		minimumOrderAmount: 15.00,
		is24Hours: true,
		operatingStartTime: null,
		operatingEndTime: null,
		isActive: true,
		displayMessageAr: 'التوصيل متاح على مدار الساعة (24/7)',
		displayMessageEn: 'Delivery available 24/7'
	};
	
	// Branch services
	let branches = [];
	let loadingBranches = false;
	let selectedBranch = null;
	let branchSettingsForm = {
		minimumOrderAmount: 15.00,
		deliveryServiceEnabled: true,
		deliveryIs24Hours: true,
		deliveryStartTime: null,
		deliveryEndTime: null,
		pickupServiceEnabled: true,
		pickupIs24Hours: true,
		pickupStartTime: null,
		pickupEndTime: null,
		deliveryMessageAr: 'التوصيل متاح على مدار الساعة',
		deliveryMessageEn: 'Delivery available 24/7'
	};
	
	onMount(async () => {
		await loadData();
	});
	
	async function loadData() {
		await deliveryActions.initialize();
		await loadBranches();
		// Initialize tiers view
		if (tierBranchId) {
			await deliveryActions.loadTiers(tierBranchId);
		}
		
		// Sync settings form with store
		deliverySettings.subscribe(settings => {
			settingsForm = { ...settings };
		});
	}
	
	async function loadBranches() {
		loadingBranches = true;
		try {
			branches = await deliveryActions.getAllBranchesSettings();
			if (branches.length > 0 && !selectedBranch) {
				selectBranch(branches[0]);
			}
			if (branches.length > 0 && !tierBranchId) {
				// Set first branch and load its tiers
				tierBranchId = branches[0].branch_id;
				await deliveryActions.loadTiers(tierBranchId);
			}
		} catch (error) {
			console.error('Error loading branches:', error);
			alert('Failed to load branches');
		} finally {
			loadingBranches = false;
		}
	}

	async function reloadBranchTiers() {
		if (tierBranchId) await deliveryActions.loadTiers(tierBranchId);
	}
	
	function selectBranch(branch) {
		selectedBranch = branch;
		branchSettingsForm = {
			minimumOrderAmount: branch.minimum_order_amount || 15.00,
			deliveryServiceEnabled: branch.delivery_service_enabled ?? true,
			deliveryIs24Hours: branch.delivery_is_24_hours ?? true,
			deliveryStartTime: branch.delivery_start_time || null,
			deliveryEndTime: branch.delivery_end_time || null,
			pickupServiceEnabled: branch.pickup_service_enabled ?? true,
			pickupIs24Hours: branch.pickup_is_24_hours ?? true,
			pickupStartTime: branch.pickup_start_time || null,
			pickupEndTime: branch.pickup_end_time || null,
			deliveryMessageAr: branch.delivery_message_ar || 'التوصيل متاح على مدار الساعة',
			deliveryMessageEn: branch.delivery_message_en || 'Delivery available 24/7'
		};
	}
	
	function openTierModal(tier = null) {
		isEditMode = !!tier;
		if (tier) {
			editingTier = tier;
			tierForm = {
				minOrderAmount: tier.min_order_amount,
				maxOrderAmount: tier.max_order_amount,
				deliveryFee: tier.delivery_fee,
				tierOrder: tier.tier_order,
				descriptionEn: tier.description_en || '',
				descriptionAr: tier.description_ar || '',
				isActive: tier.is_active
			};
		} else {
			const tiers = $deliveryTiers;
			const maxOrder = tiers.length > 0 ? Math.max(...tiers.map(t => t.tier_order)) : 0;
			tierForm = {
				minOrderAmount: 0,
				maxOrderAmount: null,
				deliveryFee: 0,
				tierOrder: maxOrder + 1,
				descriptionEn: '',
				descriptionAr: '',
				isActive: true
			};
		}
		showTierModal = true;
	}
	
	function closeTierModal() {
		showTierModal = false;
		editingTier = null;
	}
	
	async function saveTier() {
		try {
			let result;
			if (isEditMode && editingTier) {
				result = await deliveryActions.updateTier(editingTier.id, tierForm, tierBranchId);
			} else {
				result = await deliveryActions.addTier(tierForm, tierBranchId);
			}
			
			if (result.success) {
				alert(isEditMode ? '✅ Tier updated successfully!' : '✅ Tier added successfully!');
				closeTierModal();
			} else {
				alert('❌ Error: ' + result.error);
			}
		} catch (error) {
			console.error('Error saving tier:', error);
			alert('❌ Error saving tier');
		}
	}
	
	async function deleteTier(tier) {
		if (!confirm(`Delete tier: ${tier.description_en}?`)) return;
		const result = await deliveryActions.deleteTier(tier.id, tierBranchId);
		if (result.success) {
			alert('✅ Tier deleted successfully!');
		} else {
			alert('❌ Error: ' + result.error);
		}
	}
	
	async function saveSettings() {
		if (!selectedBranch) {
			alert('❌ Please select a branch');
			return;
		}
		
		const result = await deliveryActions.updateBranchSettings(selectedBranch.branch_id, branchSettingsForm);
		if (result.success) {
			alert('✅ Branch settings updated successfully!');
			await loadBranches();
		} else {
			alert('❌ Error: ' + result.error);
		}
	}
	
	async function toggleBranchService(branchId, serviceType) {
		try {
			const branch = branches.find(b => b.branch_id === branchId);
			if (!branch) return;
			
			const updateData = serviceType === 'delivery' 
				? { delivery_service_enabled: !branch.delivery_service_enabled }
				: { pickup_service_enabled: !branch.pickup_service_enabled };
			
			const { error } = await supabase
				.from('branches')
				.update(updateData)
				.eq('id', branchId);
			
			if (error) throw error;
			
			await loadBranches();
			alert('✅ Service updated successfully!');
		} catch (error) {
			console.error('Error updating service:', error);
			alert('❌ Error updating service');
		}
	}
	
	$: sortedTiers = $deliveryTiers.sort((a, b) => a.tier_order - b.tier_order);
	$: isBranchSpecific = sortedTiers.length > 0 && sortedTiers.every(t => t.branch_id === tierBranchId);
</script>

<div class="delivery-settings">
	<div class="header">
		<h1>📦 Delivery Settings</h1>
		<p>Manage delivery fees, tiers, and service availability</p>
	</div>
	
	<!-- Tabs -->
	<div class="tabs">
		<button 
			class="tab" 
			class:active={activeTab === 'tiers'}
			on:click={() => activeTab = 'tiers'}
		>
			💰 Fee Tiers
		</button>
		<button 
			class="tab" 
			class:active={activeTab === 'settings'}
			on:click={() => activeTab = 'settings'}
		>
			⚙️ General Settings
		</button>
		<button 
			class="tab" 
			class:active={activeTab === 'branches'}
			on:click={() => activeTab = 'branches'}
		>
			🏢 Branch Services
		</button>
	</div>
	
	<!-- Tier Management Tab -->
	{#if activeTab === 'tiers'}
		<div class="tab-content">
				<div class="section-header">
					<h2>Delivery Fee Tiers (Branch Specific)</h2>
					<div class="tier-controls">
						<label>
							Branch:
							<select bind:value={tierBranchId} on:change={reloadBranchTiers}>
								{#each branches as branch}
									<option value={branch.branch_id}>{branch.branch_name_en}</option>
								{/each}
							</select>
						</label>
						<button class="btn-primary" on:click={() => openTierModal()} disabled={!tierBranchId}>
							+ Add New Tier
						</button>
					</div>
				</div>
			
			{#if $deliveryDataLoading}
				<div class="loading">Loading tiers...</div>
			{:else if sortedTiers.length === 0}
				<div class="empty-state">
					<p>No tiers configured. Add your first tier to get started.</p>
				</div>
			{:else}
				<div class="tiers-table">
					<table>
						<thead>
							<tr>
								<th>Order</th>
								<th>Min Amount (SAR)</th>
								<th>Max Amount (SAR)</th>
								<th>Delivery Fee (SAR)</th>
								<th>Description (EN)</th>
								<th>Description (AR)</th>
								<th>Status</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each sortedTiers as tier}
								<tr class:inactive={!tier.is_active}>
									<td>{tier.tier_order}</td>
									<td>{tier.min_order_amount.toFixed(2)}</td>
									<td>{tier.max_order_amount ? tier.max_order_amount.toFixed(2) : 'Unlimited'}</td>
									<td class="fee-cell">
										{#if tier.delivery_fee === 0}
											<span class="free-badge">FREE</span>
										{:else}
											{tier.delivery_fee.toFixed(2)}
										{/if}
									</td>
									<td>{tier.description_en || '-'}</td>
									<td class="arabic">{tier.description_ar || '-'}</td>
									<td>
										<span class="status-badge {tier.is_active ? 'active' : 'inactive'}">
											{tier.is_active ? 'Active' : 'Inactive'}
										</span>
									</td>
									<td class="actions-cell">
										<button class="btn-edit" on:click={() => openTierModal(tier)}>✏️</button>
										<button class="btn-delete" on:click={() => deleteTier(tier)}>🗑️</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}
	
	<!-- General Settings Tab -->
	{#if activeTab === 'settings'}
		<div class="tab-content">
			<div class="section-header">
				<h2>Branch Delivery Settings</h2>
				<button class="btn-primary" on:click={saveSettings} disabled={!selectedBranch}>
					💾 Save Settings
				</button>
			</div>
			
			{#if loadingBranches}
				<div class="loading">Loading branches...</div>
			{:else if branches.length === 0}
				<div class="empty-state">No branches found</div>
			{:else}
				<!-- Branch Selector -->
				<div class="branch-selector">
					<label>Select Branch:</label>
					<div class="branch-buttons">
						{#each branches as branch}
							<button 
								class="branch-btn {selectedBranch?.branch_id === branch.branch_id ? 'selected' : ''}"
								on:click={() => selectBranch(branch)}
							>
								<div class="branch-name-en">{branch.branch_name_en}</div>
								<div class="branch-name-ar">{branch.branch_name_ar}</div>
							</button>
						{/each}
					</div>
				</div>
				
				{#if selectedBranch}
					<div class="settings-form">
						<div class="form-group">
							<label>Minimum Order Amount (SAR)</label>
							<input 
								type="number" 
								step="0.01" 
								bind:value={branchSettingsForm.minimumOrderAmount}
							/>
						</div>
						
						<!-- Delivery Service Settings -->
						<div class="service-section">
							<h3>🚚 Delivery Service</h3>
							
							<div class="form-group checkbox-group">
								<label>
									<input type="checkbox" bind:checked={branchSettingsForm.deliveryServiceEnabled} />
									Enable Delivery Service
								</label>
							</div>
							
							<div class="form-group checkbox-group">
								<label>
									<input type="checkbox" bind:checked={branchSettingsForm.deliveryIs24Hours} />
									24/7 Delivery Service
								</label>
							</div>
							
							{#if !branchSettingsForm.deliveryIs24Hours}
								<div class="form-row">
									<div class="form-group">
										<label>Delivery Start Time</label>
										<input type="time" bind:value={branchSettingsForm.deliveryStartTime} />
									</div>
									
									<div class="form-group">
										<label>Delivery End Time</label>
										<input type="time" bind:value={branchSettingsForm.deliveryEndTime} />
									</div>
								</div>
							{/if}
						</div>
						
						<!-- Pickup Service Settings -->
						<div class="service-section">
							<h3>🏪 Pickup Service</h3>
							
							<div class="form-group checkbox-group">
								<label>
									<input type="checkbox" bind:checked={branchSettingsForm.pickupServiceEnabled} />
									Enable Store Pickup
								</label>
							</div>
							
							<div class="form-group checkbox-group">
								<label>
									<input type="checkbox" bind:checked={branchSettingsForm.pickupIs24Hours} />
									24/7 Pickup Service
								</label>
							</div>
							
							{#if !branchSettingsForm.pickupIs24Hours}
								<div class="form-row">
									<div class="form-group">
										<label>Pickup Start Time</label>
										<input type="time" bind:value={branchSettingsForm.pickupStartTime} />
									</div>
									
									<div class="form-group">
										<label>Pickup End Time</label>
										<input type="time" bind:value={branchSettingsForm.pickupEndTime} />
									</div>
								</div>
							{/if}
						</div>
						
						<div class="form-group">
							<label>Display Message (Arabic)</label>
							<input type="text" bind:value={branchSettingsForm.deliveryMessageAr} />
						</div>
						
						<div class="form-group">
							<label>Display Message (English)</label>
							<input type="text" bind:value={branchSettingsForm.deliveryMessageEn} />
						</div>
					</div>
				{/if}
			{/if}
		</div>
	{/if}
	
	<!-- Branch Services Tab -->
	{#if activeTab === 'branches'}
		<div class="tab-content">
			<div class="section-header">
				<h2>Branch Service Availability</h2>
			</div>
			
			{#if loadingBranches}
				<div class="loading">Loading branches...</div>
			{:else}
				<div class="branches-table">
					<table>
						<thead>
							<tr>
								<th>Branch Name (EN)</th>
								<th>Branch Name (AR)</th>
								<th>Delivery Service</th>
								<th>Store Pickup</th>
							</tr>
						</thead>
						<tbody>
							{#each branches as branch}
								<tr>
									<td>{branch.branch_name_en}</td>
									<td class="arabic">{branch.branch_name_ar}</td>
									<td>
										<button 
											class="toggle-btn {branch.delivery_service_enabled ? 'active' : 'inactive'}"
											on:click={() => toggleBranchService(branch.branch_id, 'delivery')}
										>
											{branch.delivery_service_enabled ? '✅ Enabled' : '❌ Disabled'}
										</button>
									</td>
									<td>
										<button 
											class="toggle-btn {branch.pickup_service_enabled ? 'active' : 'inactive'}"
											on:click={() => toggleBranchService(branch.branch_id, 'pickup')}
										>
											{branch.pickup_service_enabled ? '✅ Enabled' : '❌ Disabled'}
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

<!-- Tier Modal -->
{#if showTierModal}
	<div class="modal-overlay" on:click={closeTierModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{isEditMode ? 'Edit Tier' : 'Add New Tier'}</h3>
				<button class="close-btn" on:click={closeTierModal}>✕</button>
			</div>
			
			<div class="modal-body">
				<div class="form-row">
					<div class="form-group">
						<label>Min Order Amount (SAR) *</label>
						<input type="number" step="0.01" bind:value={tierForm.minOrderAmount} required />
					</div>
					
					<div class="form-group">
						<label>Max Order Amount (SAR)</label>
						<input type="number" step="0.01" bind:value={tierForm.maxOrderAmount} 
							placeholder="Leave empty for unlimited" />
					</div>
				</div>
				
				<div class="form-row">
					<div class="form-group">
						<label>Delivery Fee (SAR) *</label>
						<input type="number" step="0.01" bind:value={tierForm.deliveryFee} required />
					</div>
					
					<div class="form-group">
						<label>Display Order *</label>
						<input type="number" bind:value={tierForm.tierOrder} required />
					</div>
				</div>
				
				<div class="form-group">
					<label>Description (English)</label>
					<input type="text" bind:value={tierForm.descriptionEn} />
				</div>
				
				<div class="form-group">
					<label>Description (Arabic)</label>
					<input type="text" bind:value={tierForm.descriptionAr} dir="rtl" />
				</div>
				
				<div class="form-group checkbox-group">
					<label>
						<input type="checkbox" bind:checked={tierForm.isActive} />
						Active
					</label>
				</div>
			</div>
			
			<div class="modal-footer">
				<button class="btn-secondary" on:click={closeTierModal}>Cancel</button>
				<button class="btn-primary" on:click={saveTier}>
					{isEditMode ? 'Update' : 'Add'} Tier
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.delivery-settings {
		padding: 2rem;
		max-width: 1400px;
		margin: 0 auto;
	}
	
	.header {
		margin-bottom: 2rem;
	}
	
	.header h1 {
		margin: 0 0 0.5rem 0;
		font-size: 2rem;
		color: #374151;
	}
	
	.header p {
		margin: 0;
		color: #6b7280;
	}
	
	.tabs {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 2rem;
		border-bottom: 2px solid #e5e7eb;
	}
	
	.tab {
		padding: 0.75rem 1.5rem;
		background: none;
		border: none;
		border-bottom: 3px solid transparent;
		cursor: pointer;
		font-size: 1rem;
		color: #6b7280;
		transition: all 0.2s;
	}
	
	.tab:hover {
		color: #374151;
		background: #f9fafb;
	}
	
	.tab.active {
		color: #10b300;
		border-bottom-color: #10b300;
		font-weight: 600;
	}
	
	.tab-content {
		background: white;
		border-radius: 12px;
		padding: 2rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}
	
	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
	}
	
	.section-header h2 {
		margin: 0;
		font-size: 1.5rem;
		color: #374151;
	}
	
	.btn-primary {
		background: #10b300;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}
	
	.btn-primary:hover {
		background: #0d9000;
	}
	
	.btn-secondary {
		background: #6b7280;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
	}
	
	.tiers-table, .branches-table {
		overflow-x: auto;
	}
	
	table {
		width: 100%;
		border-collapse: collapse;
	}
	
	thead {
		background: #f9fafb;
	}
	
	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
	}
	
	td {
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		color: #6b7280;
	}
	
	tr.inactive {
		opacity: 0.5;
	}
	
	.fee-cell {
		font-weight: 600;
		color: #10b300;
	}
	
	.free-badge {
		background: #10b300;
		color: white;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 700;
	}
	
	.status-badge {
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.875rem;
		font-weight: 500;
	}
	
	.status-badge.active {
		background: #d1fae5;
		color: #065f46;
	}
	
	.status-badge.inactive {
		background: #fee2e2;
		color: #991b1b;
	}
	
	.actions-cell {
		display: flex;
		gap: 0.5rem;
	}
	
	.btn-edit, .btn-delete {
		background: none;
		border: none;
		font-size: 1.25rem;
		cursor: pointer;
		padding: 0.25rem 0.5rem;
	}
	
	.btn-edit:hover {
		opacity: 0.7;
	}
	
	.btn-delete:hover {
		opacity: 0.7;
	}
	
	.arabic {
		direction: rtl;
		font-family: 'Cairo', sans-serif;
	}
	
	.toggle-btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s;
	}
	
	.toggle-btn.active {
		background: #d1fae5;
		color: #065f46;
	}
	
	.toggle-btn.inactive {
		background: #fee2e2;
		color: #991b1b;
	}
	
	.settings-form {
		max-width: 600px;
	}
	
	.branch-selector {
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: white;
		border-radius: 12px;
		border: 1px solid #e5e7eb;
	}
	
	.branch-selector label {
		display: block;
		margin-bottom: 1rem;
		font-weight: 600;
		color: #374151;
		font-size: 1.1rem;
	}
	
	.branch-buttons {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
		gap: 1rem;
	}
	
	.branch-btn {
		padding: 1rem;
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		text-align: center;
	}
	
	.branch-btn:hover {
		border-color: #3b82f6;
		background: #eff6ff;
	}
	
	.branch-btn.selected {
		border-color: #3b82f6;
		background: #dbeafe;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.branch-name-en {
		font-weight: 600;
		color: #1f2937;
		margin-bottom: 0.25rem;
	}
	
	.branch-name-ar {
		font-size: 0.9rem;
		color: #6b7280;
		direction: rtl;
	}
	
	.form-group {
		margin-bottom: 1.5rem;
	}
	
	.service-section {
		background: #f9fafb;
		padding: 1.5rem;
		border-radius: 8px;
		margin-bottom: 2rem;
		border: 1px solid #e5e7eb;
	}
	
	.service-section h3 {
		margin: 0 0 1rem 0;
		color: #111827;
		font-size: 1.1rem;
	}
	
	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
		color: #374151;
	}
	
	.form-group input[type="text"],
	.form-group input[type="number"],
	.form-group input[type="time"] {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 1rem;
	}
	
	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}
	
	.checkbox-group label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
	}
	
	.checkbox-group input[type="checkbox"] {
		width: 1.25rem;
		height: 1.25rem;
		cursor: pointer;
	}
	
	.loading, .empty-state {
		text-align: center;
		padding: 3rem;
		color: #6b7280;
	}

	.notice {
		margin-bottom: 1rem;
		padding: 0.75rem 1rem;
		background: #fffbeb;
		border: 1px solid #f59e0b;
		border-radius: 8px;
		color: #92400e;
	}

	.tier-controls {
		display: flex;
		align-items: center;
		gap: 0.75rem;
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
	}
	
	.modal-content {
		background: white;
		border-radius: 12px;
		max-width: 600px;
		width: 90%;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}
	
	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
	}
	
	.modal-header h3 {
		margin: 0;
		font-size: 1.25rem;
		color: #374151;
	}
	
	.close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		color: #6b7280;
	}
	
	.close-btn:hover {
		color: #374151;
	}
	
	.modal-body {
		padding: 1.5rem;
	}
	
	.modal-footer {
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
		display: flex;
		justify-content: flex-end;
		gap: 1rem;
	}
</style>


