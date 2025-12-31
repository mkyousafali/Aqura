<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';

	// State management
	let positions = [];
	let departments = [];
	let levels = [];
	let isLoading = false;
	let errorMessage = '';
	let isEditing = false;
	let editingId = null;

	// Form data
	let formData = {
		nameAr: '',
		nameEn: '',
		departmentId: '',
		levelId: '',
		description: ''
	};

	// Data arrays from database

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		isLoading = true;
		errorMessage = '';

		try {
			// Load departments from real database
			const { data: departmentsData, error: deptError } = await dataService.hrDepartments.getAll();
			if (deptError) {
				console.error('Error loading departments:', deptError);
				errorMessage = 'Failed to load departments: ' + (deptError.message || deptError);
				return;
			}
			departments = departmentsData || [];

			// Load levels from real database
			const { data: levelsData, error: levelsError } = await dataService.hrLevels.getAll();
			if (levelsError) {
				console.error('Error loading levels:', levelsError);
				errorMessage = 'Failed to load levels: ' + (levelsError.message || levelsError);
				return;
			}
			levels = levelsData || [];

			// Load positions from real database
			const { data: positionsData, error: positionsError } = await dataService.hrPositions.getAll();
			if (positionsError) {
				console.error('Error loading positions:', positionsError);
				errorMessage = 'Failed to load positions: ' + (positionsError.message || positionsError);
				return;
			}
			positions = positionsData || [];

		} catch (error) {
			console.error('Error loading data:', error);
			errorMessage = 'Failed to load data: ' + error.message;
		} finally {
			isLoading = false;
		}
	}

	async function savePosition() {
		if (!formData.nameAr.trim() || !formData.nameEn.trim()) {
			errorMessage = 'Both Arabic and English names are required';
			return;
		}

		if (!formData.departmentId || !formData.levelId) {
			errorMessage = 'Department and Level selection are required';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const positionData = {
				position_title_ar: formData.nameAr.trim(),
				position_title_en: formData.nameEn.trim(),
				description: formData.description.trim(),
				department_id: formData.departmentId,
				level_id: formData.levelId
			};

			if (isEditing) {
				// Update existing position
				const { data, error } = await dataService.hrPositions.update(editingId, positionData);
				
				if (error) {
					console.error('Error updating position:', error);
					errorMessage = 'Failed to update position: ' + (error.message || error);
				} else {
					// Update local state
					positions = positions.map(p => 
						p.id === editingId ? data : p
					);
					
					isEditing = false;
					editingId = null;
					formData = { nameAr: '', nameEn: '', departmentId: '', levelId: '', description: '' };
				}
			} else {
				// Create new position
				const { data, error } = await dataService.hrPositions.create(positionData);
				
				if (error) {
					console.error('Error creating position:', error);
					errorMessage = 'Failed to create position: ' + (error.message || error);
				} else {
					// Add to local state
					positions = [...positions, data];
					formData = { nameAr: '', nameEn: '', departmentId: '', levelId: '', description: '' };
				}
			}
		} catch (error) {
			console.error('Error saving position:', error);
			errorMessage = `Failed to ${isEditing ? 'update' : 'create'} position: ` + error.message;
		} finally {
			isLoading = false;
		}
	}

	function editPosition(position) {
		isEditing = true;
		editingId = position.id;
		formData = {
			nameAr: position.position_title_ar,
			nameEn: position.position_title_en,
			description: position.description || '',
			departmentId: position.department_id,
			levelId: position.level_id
		};
	}

	function cancelEdit() {
		isEditing = false;
		editingId = null;
		formData = { nameAr: '', nameEn: '', departmentId: '', levelId: '', description: '' };
	}

	async function deletePosition(id) {
		if (!confirm('Are you sure you want to delete this position?')) {
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			await dataService.hrPositions.delete(id);
			await loadData(); // Reload data to refresh the list
		} catch (error) {
			errorMessage = error.message || 'Failed to delete position';
		} finally {
			isLoading = false;
		}
	}

	function getDepartmentName(departmentId) {
		const department = departments.find(d => d.id === departmentId);
		return department ? department.department_name_en : 'Unknown Department';
	}

	function getDepartmentNameAr(departmentId) {
		const department = departments.find(d => d.id === departmentId);
		return department ? department.department_name_ar : 'قسم غير معروف';
	}

	function getLevelName(levelId) {
		const level = levels.find(l => l.id === levelId);
		return level ? level.level_name_en : 'Unknown Level';
	}

	function getLevelNameAr(levelId) {
		const level = levels.find(l => l.id === levelId);
		return level ? level.level_name_ar : 'مستوى غير معروف';
	}

	function getLevelNumber(levelId) {
		const level = levels.find(l => l.id === levelId);
		return level ? level.level : 0;
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function getLevelBadgeColor(levelNumber) {
		const colors = [
			'bg-red-500',    // Level 1
			'bg-orange-500', // Level 2
			'bg-yellow-500', // Level 3
			'bg-green-500',  // Level 4
			'bg-blue-500'    // Level 5
		];
		return colors[levelNumber - 1] || 'bg-gray-500';
	}
</script>

<div class="create-position">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Position Management</h2>
		<p class="subtitle">Create and manage job positions with department and level assignments</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Form Section -->
		<div class="form-section">
			<h3>{isEditing ? 'Edit Position' : 'Create New Position'}</h3>
			
			<form on:submit|preventDefault={savePosition}>
				<div class="form-grid">
					<div class="form-group">
						<label for="name-ar">Arabic Name *</label>
						<input
							id="name-ar"
							type="text"
							bind:value={formData.nameAr}
							placeholder="اسم المنصب بالعربية"
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
							placeholder="Position Name in English"
							required
							disabled={isLoading}
						>
					</div>
					<div class="form-group">
						<label for="department">Department *</label>
						<select
							id="department"
							bind:value={formData.departmentId}
							required
							disabled={isLoading}
						>
							<option value="">Select Department</option>
							{#each departments as department}
								<option value={department.id}>{department.department_name_en} ({department.department_name_ar})</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label for="level">Level Number *</label>
						<select
							id="level"
							bind:value={formData.levelId}
							required
							disabled={isLoading}
						>
							<option value="">Select Level</option>
							{#each levels as level}
								<option value={level.id}>Level {level.level} - {level.level_name_en}</option>
							{/each}
						</select>
					</div>
					<div class="form-group span-2">
						<label for="description">Description</label>
						<textarea
							id="description"
							bind:value={formData.description}
							placeholder="Position responsibilities and requirements"
							disabled={isLoading}
							rows="3"
						></textarea>
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
							<span class="icon">{isEditing ? '✏️' : '💼'}</span>
							{isEditing ? 'Update Position' : 'Create Position'}
						{/if}
					</button>
				</div>
			</form>
		</div>

		<!-- Positions Table -->
		<div class="table-section">
			<div class="table-header">
				<h3>Available Positions ({positions.length})</h3>
				<button class="refresh-btn" on:click={loadData} disabled={isLoading}>
					<span class="icon">🔄</span>
					Refresh
				</button>
			</div>

			{#if isLoading && positions.length === 0}
				<div class="loading-state">
					<div class="spinner large"></div>
					<p>Loading positions...</p>
				</div>
			{:else if positions.length === 0}
				<div class="empty-state">
					<div class="empty-icon">💼</div>
					<h4>No Positions Found</h4>
					<p>Create your first position to get started</p>
				</div>
			{:else}
				<div class="table-container">
					<table class="positions-table">
						<thead>
							<tr>
								<th>Position Name</th>
								<th>Department</th>
								<th>Level</th>
								<th>Description</th>
								<th>Created Date</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each positions as position (position.id)}
								<tr class="table-row">
									<td class="position-names">
										<div class="name-en">{position.position_title_en}</div>
										<div class="name-ar">{position.position_title_ar}</div>
									</td>
									<td class="department-cell">
										<div class="dept-en">{getDepartmentName(position.department_id)}</div>
										<div class="dept-ar">{getDepartmentNameAr(position.department_id)}</div>
									</td>
									<td class="level-cell">
										<div class="level-badge {getLevelBadgeColor(getLevelNumber(position.level_id))}">
											L{getLevelNumber(position.level_id)}
										</div>
										<div class="level-names">
											<div class="level-en">{getLevelName(position.level_id)}</div>
											<div class="level-ar">{getLevelNameAr(position.level_id)}</div>
										</div>
									</td>
									<td class="description-cell">
										{position.description || 'No description'}
									</td>
									<td class="date-cell">{formatDate(position.created_at)}</td>
									<td>
										<div class="actions">
											<button 
												class="edit-btn" 
												on:click={() => editPosition(position)}
												disabled={isLoading}
												title="Edit Position"
											>
												✏️
											</button>
											<button 
												class="delete-btn" 
												on:click={() => deletePosition(position.id)}
												disabled={isLoading}
												title="Delete Position"
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
	.create-position {
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
		max-width: 1400px;
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

	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group.span-2 {
		grid-column: 1 / -1;
	}

	.form-group label {
		margin-bottom: 8px;
		font-weight: 500;
		color: #374151;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 16px;
		transition: all 0.2s;
		background: white;
		font-family: inherit;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #f59e0b;
		box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.1);
	}

	.form-group input:disabled,
	.form-group select:disabled,
	.form-group textarea:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.form-group textarea {
		resize: vertical;
		min-height: 80px;
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
		background: #f59e0b;
		color: white;
		border-color: #f59e0b;
	}

	.save-btn:hover:not(:disabled) {
		background: #d97706;
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

	.positions-table {
		width: 100%;
		border-collapse: collapse;
	}

	.positions-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.positions-table td {
		padding: 16px;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: top;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.position-names {
		min-width: 200px;
	}

	.name-en {
		font-weight: 600;
		color: #111827;
		margin-bottom: 4px;
	}

	.name-ar {
		font-size: 14px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
	}

	.department-cell {
		min-width: 180px;
	}

	.dept-en {
		color: #111827;
		margin-bottom: 4px;
	}

	.dept-ar {
		font-size: 14px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
	}

	.level-cell {
		min-width: 160px;
	}

	.level-badge {
		color: white;
		font-size: 12px;
		font-weight: 600;
		padding: 4px 8px;
		border-radius: 12px;
		text-align: center;
		width: 32px;
		margin-bottom: 8px;
		display: inline-block;
	}

	.level-names .level-en {
		font-size: 14px;
		color: #111827;
		margin-bottom: 2px;
	}

	.level-names .level-ar {
		font-size: 12px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
	}

	.description-cell {
		max-width: 250px;
		font-size: 14px;
		color: #4b5563;
		line-height: 1.4;
	}

	.date-cell {
		font-size: 14px;
		color: #6b7280;
		white-space: nowrap;
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
		.form-grid {
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

		.positions-table th,
		.positions-table td {
			padding: 8px 12px;
			font-size: 14px;
		}

		.position-names,
		.department-cell,
		.level-cell {
			min-width: unset;
		}

		.description-cell {
			max-width: 200px;
		}
	}
</style>