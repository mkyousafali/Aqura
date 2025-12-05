<script lang="ts">
	import { onMount } from 'svelte';
	import { type Branch } from '$lib/utils/supabase';
	import { supabase } from '$lib/utils/supabase';
	// import { goAPI } from '$lib/utils/goAPI'; // Removed - Go backend no longer used

	// State management
	let branches: Branch[] = [];
	let showCreatePopup = false;
	let showEditPopup = false;
	let currentBranch: Partial<Branch> = {
		name_en: '',
		name_ar: '',
		location_en: '',
		location_ar: '',
		is_active: true,
		is_main_branch: false,
		vat_number: ''
	};
	let editingBranch: Branch | null = null;
	let isLoading = false;
	let errorMessage = '';
	let cacheHit = false; // Track if data came from cache

	// Load branches on component mount
	onMount(async () => {
		await loadBranches();
	});

	// Load branches from Supabase
	async function loadBranches() {
		const startTime = performance.now();
		isLoading = true;
		errorMessage = '';
		
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.order('created_at', { ascending: false });
			
			const loadTime = Math.round(performance.now() - startTime);
			
			if (error) {
				errorMessage = error.message || 'Failed to load branches';
				console.error('Failed to load branches:', error);
			} else if (data) {
				branches = data;
				cacheHit = loadTime < 50; // If loaded in under 50ms, likely from cache
				console.log(`✅ Loaded ${data.length} branches in ${loadTime}ms ${cacheHit ? '(cached)' : ''}`);
			}
		} catch (error) {
			errorMessage = 'Failed to connect to server';
			console.error('Error loading branches:', error);
		} finally {
			isLoading = false;
		}
	}

	// Functions
	function openCreatePopup() {
		currentBranch = {
			name_en: '',
			name_ar: '',
			location_en: '',
			location_ar: '',
			is_active: true,
			is_main_branch: false,
			vat_number: ''
		};
		showCreatePopup = true;
	}

	function closeCreatePopup() {
		showCreatePopup = false;
		currentBranch = {
			name_en: '',
			name_ar: '',
			location_en: '',
			location_ar: '',
			is_active: true,
			is_main_branch: false
		};
	}

	function openEditPopup(branch: Branch) {
		editingBranch = branch;
		currentBranch = { ...branch };
		showEditPopup = true;
	}

	function closeEditPopup() {
		showEditPopup = false;
		editingBranch = null;
		currentBranch = {
			name_en: '',
			name_ar: '',
			location_en: '',
			location_ar: '',
			is_active: true,
			is_main_branch: false
		};
	}

	async function saveBranch() {
		if (!currentBranch.name_en || !currentBranch.name_ar || !currentBranch.location_en || !currentBranch.location_ar) {
			alert('Please fill in all fields');
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const branchData = {
				name_en: currentBranch.name_en!,
				name_ar: currentBranch.name_ar!,
				location_en: currentBranch.location_en!,
				location_ar: currentBranch.location_ar!,
				is_active: currentBranch.is_active || true,
				is_main_branch: currentBranch.is_main_branch || false,
				vat_number: currentBranch.vat_number || null
			};

			let result;
			if (showCreatePopup) {
				const { data, error } = await supabase
					.from('branches')
					.insert([branchData])
					.select();
				result = { error };
				
				if (result.error) {
					errorMessage = result.error.message || 'Failed to create branch';
					alert('Error creating branch: ' + errorMessage);
				} else {
					await loadBranches();
					closeCreatePopup();
				}
			} else if (showEditPopup && editingBranch) {
				const { error } = await supabase
					.from('branches')
					.update(branchData)
					.eq('id', editingBranch.id);
				result = { error };
				
				if (result.error) {
					errorMessage = result.error.message || 'Failed to update branch';
					alert('Error updating branch: ' + errorMessage);
				} else {
					await loadBranches();
					closeEditPopup();
				}
			}
		} catch (error) {
			errorMessage = 'Failed to save branch';
			alert('Error saving branch: ' + errorMessage);
			console.error('Error saving branch:', error);
		} finally {
			isLoading = false;
		}
	}

	async function deleteBranch(id: string) {
		if (confirm('Are you sure you want to delete this branch?')) {
			isLoading = true;
			errorMessage = '';

			try {
				const { error } = await supabase
					.from('branches')
					.delete()
					.eq('id', id);
				
				if (error) {
					errorMessage = error.message || 'Failed to delete branch';
					alert('Error deleting branch: ' + errorMessage);
				} else {
					// Refresh the branches list
					await loadBranches();
				}
			} catch (error) {
				errorMessage = 'Failed to delete branch';
				alert('Error deleting branch: ' + errorMessage);
				console.error('Error deleting branch:', error);
			} finally {
				isLoading = false;
			}
		}
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
</script>

<div class="branch-master">
	<!-- Header with Create Button -->
	<div class="header">
		<h1 class="title">Branches Master</h1>
		<button class="create-btn" on:click={openCreatePopup} disabled={isLoading}>
			<span class="icon">+</span>
			Create Branch
		</button>
	</div>

	<!-- Error Message -->
	{#if errorMessage}
		<div class="error-message">
			<strong>Error:</strong> {errorMessage}
			<button class="retry-btn" on:click={loadBranches}>Retry</button>
		</div>
	{/if}

	<!-- Loading State -->
	{#if isLoading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading branches...</p>
		</div>
	{/if}

	<!-- Branches Table -->
	<div class="table-container">
		<table class="branches-table">
			<thead>
				<tr>
					<th>Branch ID</th>
					<th>Name (English)</th>
					<th>Name (Arabic)</th>
					<th>Location (English)</th>
					<th>Location (Arabic)</th>
					<th>VAT Number</th>
					<th>Status</th>
					<th>Main Branch</th>
					<th>Created At</th>
					<th>Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each branches as branch (branch.id)}
					<tr class={branch.is_active ? 'active' : 'inactive'}>
						<td>{branch.id}</td>
						<td>{branch.name_en}</td>
						<td class="arabic">{branch.name_ar}</td>
						<td>{branch.location_en}</td>
						<td class="arabic">{branch.location_ar}</td>
						<td class="vat-number">
							{#if branch.vat_number}
								<span class="vat-badge">{branch.vat_number}</span>
							{:else}
								<span class="no-vat">-</span>
							{/if}
						</td>
						<td>
							<span class="status-badge {branch.is_active ? 'active' : 'inactive'}">
								{branch.is_active ? 'Active' : 'Inactive'}
							</span>
						</td>
						<td>
							{#if branch.is_main_branch}
								<span class="main-branch-badge">✓</span>
							{:else}
								-
							{/if}
						</td>
						<td>{branch.created_at ? formatDate(branch.created_at) : '-'}</td>
						<td>
							<div class="actions">
								<button class="edit-btn" on:click={() => openEditPopup(branch)} disabled={isLoading}>
									Edit
								</button>
								<button class="delete-btn" on:click={() => deleteBranch(branch.id)} disabled={isLoading}>
									Delete
								</button>
							</div>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>

		{#if branches.length === 0 && !isLoading}
			<div class="empty-state">
				<p>No branches available</p>
				<button class="create-btn" on:click={openCreatePopup}>
					<span class="icon">+</span>
					Create Your First Branch
				</button>
			</div>
		{/if}
	</div>
</div>

<!-- Create Branch Popup -->
{#if showCreatePopup}
	<div class="popup-overlay" on:click={closeCreatePopup}>
		<div class="popup" on:click|stopPropagation>
			<div class="popup-header">
				<h2>Create Branch</h2>
				<button class="close-btn" on:click={closeCreatePopup}>×</button>
			</div>
			
			<div class="popup-content">
				<form on:submit|preventDefault={saveBranch}>
					<div class="form-row">
						<div class="form-group">
							<label for="name-en">Name (English)</label>
							<input
								id="name-en"
								type="text"
								bind:value={currentBranch.name_en}
								placeholder="Enter branch name in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="name-ar">Name (Arabic)</label>
							<input
								id="name-ar"
								type="text"
								bind:value={currentBranch.name_ar}
								placeholder="أدخل اسم الفرع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>
					
					<div class="form-row">
						<div class="form-group">
							<label for="location-en">Location (English)</label>
							<input
								id="location-en"
								type="text"
								bind:value={currentBranch.location_en}
								placeholder="Enter location in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="location-ar">Location (Arabic)</label>
							<input
								id="location-ar"
								type="text"
								bind:value={currentBranch.location_ar}
								placeholder="أدخل الموقع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="vat-number-create">VAT Number (Optional)</label>
							<input
								id="vat-number-create"
								type="text"
								bind:value={currentBranch.vat_number}
								placeholder="Enter VAT registration number"
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_active} />
								Active
							</label>
						</div>
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_main_branch} />
								Main Branch
							</label>
						</div>
					</div>
					
					<div class="form-actions">
						<button type="button" class="cancel-btn" on:click={closeCreatePopup}>
							Cancel
						</button>
						<button type="submit" class="save-btn">
							Save
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<!-- Edit Branch Popup -->
{#if showEditPopup}
	<div class="popup-overlay" on:click={closeEditPopup}>
		<div class="popup" on:click|stopPropagation>
			<div class="popup-header">
				<h2>Edit Branch</h2>
				<button class="close-btn" on:click={closeEditPopup}>×</button>
			</div>
			
			<div class="popup-content">
				<form on:submit|preventDefault={saveBranch}>
					<div class="form-row">
						<div class="form-group">
							<label for="edit-name-en">Name (English)</label>
							<input
								id="edit-name-en"
								type="text"
								bind:value={currentBranch.name_en}
								placeholder="Enter branch name in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="edit-name-ar">Name (Arabic)</label>
							<input
								id="edit-name-ar"
								type="text"
								bind:value={currentBranch.name_ar}
								placeholder="أدخل اسم الفرع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>
					
					<div class="form-row">
						<div class="form-group">
							<label for="edit-location-en">Location (English)</label>
							<input
								id="edit-location-en"
								type="text"
								bind:value={currentBranch.location_en}
								placeholder="Enter location in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="edit-location-ar">Location (Arabic)</label>
							<input
								id="edit-location-ar"
								type="text"
								bind:value={currentBranch.location_ar}
								placeholder="أدخل الموقع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="vat-number-edit">VAT Number (Optional)</label>
							<input
								id="vat-number-edit"
								type="text"
								bind:value={currentBranch.vat_number}
								placeholder="Enter VAT registration number"
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_active} />
								Active
							</label>
						</div>
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_main_branch} />
								Main Branch
							</label>
						</div>
					</div>
					
					<div class="form-actions">
						<button type="button" class="cancel-btn" on:click={closeEditPopup}>
							Cancel
						</button>
						<button type="submit" class="save-btn">
							Update
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<style>
	.branch-master {
		padding: 24px;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: white;
		gap: 24px;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.create-btn {
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 20px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.create-btn:hover {
		background: #059669;
		transform: translateY(-1px);
	}

	.create-btn .icon {
		font-size: 18px;
		font-weight: bold;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.branches-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.branches-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.branches-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
		color: #111827;
	}

	.branches-table tr:hover {
		background: #f9fafb;
	}

	.branches-table tr.inactive {
		opacity: 0.6;
	}

	.arabic {
		font-family: 'Tajawal', 'Cairo', Arial, sans-serif;
		direction: rtl;
		text-align: right;
	}

	.status-badge {
		padding: 4px 12px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 500;
		text-transform: uppercase;
	}

	.status-badge.active {
		background: #d1fae5;
		color: #065f46;
	}

	.status-badge.inactive {
		background: #fee2e2;
		color: #991b1b;
	}

	.main-branch-badge {
		background: #dbeafe;
		color: #1d4ed8;
		padding: 4px 8px;
		border-radius: 4px;
		font-weight: 500;
	}

	.actions {
		display: flex;
		gap: 8px;
	}

	.edit-btn, .delete-btn {
		padding: 6px 12px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
	}

	.edit-btn {
		background: #eff6ff;
		color: #1d4ed8;
		border-color: #3b82f6;
	}

	.edit-btn:hover {
		background: #dbeafe;
	}

	.delete-btn {
		background: #fef2f2;
		color: #dc2626;
		border-color: #ef4444;
	}

	.delete-btn:hover {
		background: #fee2e2;
	}

	.empty-state {
		padding: 48px;
		text-align: center;
		color: #6b7280;
	}

	.empty-state .create-btn {
		margin-top: 16px;
		background: #3b82f6;
	}

	.empty-state .create-btn:hover {
		background: #2563eb;
	}

	/* Loading and Error States */
	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 16px;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.retry-btn {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 6px 12px;
		font-size: 12px;
		cursor: pointer;
		font-weight: 500;
	}

	.retry-btn:hover {
		background: #b91c1c;
	}

	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	/* Popup Styles */
	.popup-overlay {
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

	.popup {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
		max-width: 600px;
		width: 90%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.popup-header {
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #f9fafb;
	}

	.popup-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
		color: #111827;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.popup-content {
		padding: 24px;
		flex: 1;
		overflow-y: auto;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 16px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group label {
		margin-bottom: 6px;
		font-weight: 500;
		color: #374151;
	}

	.form-group input {
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.checkbox-label {
		display: flex !important;
		flex-direction: row !important;
		align-items: center;
		gap: 8px;
		margin-top: 8px;
	}

	.checkbox-label input {
		width: auto;
		margin: 0;
	}

	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding-top: 20px;
		border-top: 1px solid #e5e7eb;
		margin-top: 20px;
	}

	.cancel-btn, .save-btn {
		padding: 12px 20px;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover {
		background: #f9fafb;
	}

	.save-btn {
		background: #10b981;
		color: white;
		border-color: #10b981;
	}

	.save-btn:hover {
		background: #059669;
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}
		
		.popup {
			width: 95%;
			margin: 20px;
		}
		
		.branches-table {
			font-size: 12px;
		}
		
		.branches-table th,
		.branches-table td {
			padding: 8px 12px;
		}
	}

	/* VAT Number Styles */
	.vat-number {
		text-align: center;
	}

	.vat-badge {
		background-color: #eff6ff;
		color: #1d4ed8;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		border: 1px solid #bfdbfe;
		font-family: monospace;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.no-vat {
		color: #9ca3af;
		font-style: italic;
	}
</style>
