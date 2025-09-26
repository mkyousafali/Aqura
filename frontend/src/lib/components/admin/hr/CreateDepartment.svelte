<script>
	import { onMount } from 'svelte';
	import { dataService } from '../../../utils/dataService.ts';

	// State management
	let departments = [];
	let isLoading = false;
	let errorMessage = '';
	let isEditing = false;
	let editingId = null;

	// Form data
	let formData = {
		nameAr: '',
		nameEn: ''
	};

	onMount(async () => {
		await loadDepartments();
	});

	async function loadDepartments() {
		isLoading = true;
		errorMessage = '';

		try {
			const { data, error } = await dataService.hrDepartments.getAll();
			
			if (error) {
				console.error('Error loading departments:', error);
				errorMessage = 'Failed to load departments: ' + (error.message || error);
			} else {
				departments = data || [];
			}
		} catch (error) {
			console.error('Error loading departments:', error);
			errorMessage = 'Failed to load departments: ' + error.message;
		} finally {
			isLoading = false;
		}
	}

	async function saveDepartment() {
		if (!formData.nameAr.trim() || !formData.nameEn.trim()) {
			errorMessage = 'Both Arabic and English names are required';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const departmentData = {
				department_name_ar: formData.nameAr.trim(),
				department_name_en: formData.nameEn.trim()
			};

			if (isEditing) {
				// Update existing department
				const { data, error } = await dataService.hrDepartments.update(editingId, departmentData);
				
				if (error) {
					console.error('Error updating department:', error);
					errorMessage = 'Failed to update department: ' + (error.message || error);
				} else {
					// Update local state
					departments = departments.map(d => 
						d.id === editingId ? data : d
					);
					
					isEditing = false;
					editingId = null;
					formData = { nameAr: '', nameEn: '' };
				}
			} else {
				// Create new department
				const { data, error } = await dataService.hrDepartments.create(departmentData);
				
				if (error) {
					console.error('Error creating department:', error);
					errorMessage = 'Failed to create department: ' + (error.message || error);
				} else {
					// Add to local state
					departments = [...departments, data];
					formData = { nameAr: '', nameEn: '' };
				}
			}
		} catch (error) {
			console.error('Error saving department:', error);
			errorMessage = `Failed to ${isEditing ? 'update' : 'create'} department: ` + error.message;
		} finally {
			isLoading = false;
		}
	}

	function editDepartment(department) {
		isEditing = true;
		editingId = department.id;
		formData = {
			nameAr: department.department_name_ar,
			nameEn: department.department_name_en
		};
	}

	function cancelEdit() {
		isEditing = false;
		editingId = null;
		formData = { nameAr: '', nameEn: '' };
	}

	async function deleteDepartment(id) {
		if (!confirm('Are you sure you want to delete this department?')) {
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const { error } = await dataService.hrDepartments.delete(id);
			
			if (error) {
				console.error('Error deleting department:', error);
				errorMessage = 'Failed to delete department: ' + (error.message || error);
			} else {
				departments = departments.filter(d => d.id !== id);
			}
		} catch (error) {
			console.error('Error deleting department:', error);
			errorMessage = 'Failed to delete department: ' + error.message;
		} finally {
			isLoading = false;
		}
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}
</script>

<div class="create-department">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Department Management</h2>
		<p class="subtitle">Create and manage organizational departments</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Form Section -->
		<div class="form-section">
			<h3>{isEditing ? 'Edit Department' : 'Create New Department'}</h3>
			
			<form on:submit|preventDefault={saveDepartment}>
				<div class="form-row">
					<div class="form-group">
						<label for="name-ar">Arabic Name *</label>
						<input
							id="name-ar"
							type="text"
							bind:value={formData.nameAr}
							placeholder="اسم القسم بالعربية"
							required
							disabled={isLoading}
						>
					</div>
					<div class="form-group">
						<label for="name-en">English Name *</label>
						<input
							id="name-en"
							type="text"
							bind:value={formData.nameEn}
							placeholder="Department Name in English"
							required
							disabled={isLoading}
						>
					</div>
				</div>

				<!-- Error Message -->
				{#if errorMessage}
					<div class="error-message">
						<strong>Error:</strong> {errorMessage}
					</div>
				{/if}

				<!-- Form Actions -->
				<div class="form-actions">
					{#if isEditing}
						<button type="button" class="cancel-btn" on:click={cancelEdit} disabled={isLoading}>
							Cancel
						</button>
					{/if}
					<button type="submit" class="save-btn" disabled={isLoading}>
						{#if isLoading}
							<span class="spinner"></span>
							{isEditing ? 'Updating...' : 'Creating...'}
						{:else}
							<span class="icon">{isEditing ? '✏️' : '➕'}</span>
							{isEditing ? 'Update Department' : 'Create Department'}
						{/if}
					</button>
				</div>
			</form>
		</div>

		<!-- Departments Table -->
		<div class="table-section">
			<div class="table-header">
				<h3>Existing Departments ({departments.length})</h3>
				<button class="refresh-btn" on:click={loadDepartments} disabled={isLoading}>
					<span class="icon">🔄</span>
					Refresh
				</button>
			</div>

			{#if isLoading && departments.length === 0}
				<div class="loading-state">
					<div class="spinner large"></div>
					<p>Loading departments...</p>
				</div>
			{:else if departments.length === 0}
				<div class="empty-state">
					<div class="empty-icon">🏢</div>
					<h4>No Departments Found</h4>
					<p>Create your first department to get started</p>
				</div>
			{:else}
				<div class="table-container">
					<table class="departments-table">
						<thead>
							<tr>
								<th>Arabic Name</th>
								<th>English Name</th>
								<th>Created Date</th>
								<th>Updated Date</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each departments as department (department.id)}
								<tr class="table-row">
									<td class="arabic-text">{department.department_name_ar}</td>
									<td>{department.department_name_en}</td>
									<td class="date-cell">{formatDate(department.created_at)}</td>
									<td class="date-cell">{formatDate(department.updated_at)}</td>
									<td>
										<div class="actions">
											<button 
												class="edit-btn" 
												on:click={() => editDepartment(department)}
												disabled={isLoading}
												title="Edit Department"
											>
												✏️
											</button>
											<button 
												class="delete-btn" 
												on:click={() => deleteDepartment(department.id)}
												disabled={isLoading}
												title="Delete Department"
											>
												🗑️
											</button>
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.create-department {
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
		max-width: 1200px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: 32px;
	}

	.form-section {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
	}

	.form-section h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group label {
		margin-bottom: 8px;
		font-weight: 500;
		color: #374151;
	}

	.form-group input {
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 16px;
		transition: all 0.2s;
		background: white;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-group input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 16px;
	}

	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
	}

	.cancel-btn, .save-btn {
		padding: 12px 20px;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.save-btn {
		background: #10b981;
		color: white;
		border-color: #10b981;
	}

	.save-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.save-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.table-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
	}

	.table-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.table-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.refresh-btn {
		background: #3b82f6;
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
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading-state, .empty-state {
		padding: 48px;
		text-align: center;
		color: #6b7280;
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

	.departments-table {
		width: 100%;
		border-collapse: collapse;
	}

	.departments-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.departments-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
		color: #111827;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.arabic-text {
		font-family: 'Segoe UI', 'Arial', sans-serif;
		direction: rtl;
		text-align: right;
	}

	.date-cell {
		font-size: 14px;
		color: #6b7280;
	}

	.actions {
		display: flex;
		gap: 8px;
	}

	.edit-btn, .delete-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 6px;
		border-radius: 4px;
		font-size: 14px;
		transition: all 0.2s;
	}

	.edit-btn {
		color: #3b82f6;
	}

	.edit-btn:hover:not(:disabled) {
		background: #eff6ff;
	}

	.delete-btn {
		color: #ef4444;
	}

	.delete-btn:hover:not(:disabled) {
		background: #fef2f2;
	}

	.edit-btn:disabled, .delete-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.spinner.large {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.icon {
		font-size: 14px;
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}

		.form-actions {
			flex-direction: column;
		}

		.table-header {
			flex-direction: column;
			gap: 12px;
			align-items: flex-start;
		}

		.departments-table th,
		.departments-table td {
			padding: 8px 12px;
			font-size: 14px;
		}
	}
</style>