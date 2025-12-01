<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';

	// State management
	let positions = [];
	let reportingMaps = [];
	let isLoading = false;
	let errorMessage = '';
	let isEditing = false;
	let editingId = null;

	// Form data
	let formData = {
		positionId: '',
		reportsTo: ['', '', '', '', ''] // 5 slots for reporting-to positions
	};

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		isLoading = true;
		errorMessage = '';

		try {
			// Load positions from real database
			const { data: positionsData, error: positionsError } = await dataService.hrPositions.getAll();
			if (positionsError) {
				console.error('Error loading positions:', positionsError);
				errorMessage = 'Failed to load positions: ' + (positionsError.message || positionsError);
				return;
			}
			positions = positionsData || [];

			// Load reporting maps from real database
			const { data: reportingData, error: reportingError } = await dataService.hrReporting.getAll();
			if (reportingError) {
				console.error('Error loading reporting maps:', reportingError);
				errorMessage = 'Failed to load reporting maps: ' + (reportingError.message || reportingError);
				return;
			}
			reportingMaps = reportingData || [];
		} catch (error) {
			console.error('Error in loadData:', error);
			errorMessage = error.message || 'Failed to load data';
		} finally {
			isLoading = false;
		}
	}

	async function saveReportingMap() {
		if (!formData.positionId) {
			errorMessage = 'Please select a position';
			return;
		}

		// Filter out empty reporting-to positions
		const validReportsTo = formData.reportsTo.filter(id => id !== '').map(id => parseInt(id));

		if (validReportsTo.length === 0) {
			errorMessage = 'Please select at least one position to report to';
			return;
		}

		// Check for circular reporting (position reporting to itself)
		if (validReportsTo.includes(parseInt(formData.positionId))) {
			errorMessage = 'A position cannot report to itself';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			if (isEditing) {
				// Update existing reporting map
				const { data, error } = await dataService.hrReporting.update(editingId, {
					manager_positions: validReportsTo.map(id => id.toString())
				});
				
				if (error) {
					errorMessage = 'Failed to update reporting map: ' + (error.message || error);
					return;
				}
				
				isEditing = false;
				editingId = null;
				await loadData(); // Reload data to refresh the list
			} else {
				// Check if reporting map already exists for this position
				const existingMap = reportingMaps.find(rm => rm.subordinate_position_id === formData.positionId);
				if (existingMap) {
					errorMessage = 'Reporting map already exists for this position. Please edit the existing one.';
					isLoading = false;
					return;
				}

				// Create new reporting map
				const { data, error } = await dataService.hrReporting.create({
					subordinate_position_id: formData.positionId,
					manager_positions: validReportsTo.map(id => id.toString())
				});
				
				if (error) {
					errorMessage = 'Failed to create reporting map: ' + (error.message || error);
					return;
				}
				
				await loadData(); // Reload data to refresh the list
			}

			// Reset form
			formData = { positionId: '', reportsTo: ['', '', '', '', ''] };
			
		} catch (error) {
			errorMessage = `Failed to ${isEditing ? 'update' : 'create'} reporting map`;
		} finally {
			isLoading = false;
		}
	}

	function editReportingMap(map) {
		isEditing = true;
		editingId = map.id;
		
		// Fill the form with existing data
		const reportsToArray = ['', '', '', '', ''];
		const managerPositions = [
			map.manager_position_1,
			map.manager_position_2,
			map.manager_position_3,
			map.manager_position_4,
			map.manager_position_5
		];
		
		managerPositions.forEach((positionId, index) => {
			if (positionId && index < 5) {
				reportsToArray[index] = positionId.toString();
			}
		});

		formData = {
			positionId: map.subordinate_position_id.toString(),
			reportsTo: reportsToArray
		};
	}

	function cancelEdit() {
		isEditing = false;
		editingId = null;
		formData = { positionId: '', reportsTo: ['', '', '', '', ''] };
	}

	async function deleteReportingMap(id) {
		if (!confirm('Are you sure you want to delete this reporting map?')) {
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const { error } = await dataService.hrReporting.delete(id);
			if (error) {
				errorMessage = 'Failed to delete reporting map: ' + (error.message || error);
				return;
			}
			await loadData(); // Reload data to refresh the list
		} catch (error) {
			errorMessage = error.message || 'Failed to delete reporting map';
		} finally {
			isLoading = false;
		}
	}

	function getPositionName(positionId) {
		const position = positions.find(p => p.id === positionId);
		return position ? position.position_title_en : 'Unknown Position';
	}

	function getPositionNameAr(positionId) {
		const position = positions.find(p => p.id === positionId);
		return position ? position.position_title_ar : 'منصب غير معروف';
	}

	function getPositionDepartment(positionId) {
		const position = positions.find(p => p.id === positionId);
		return position ? (position.hr_departments?.department_name_en || 'Unknown Department') : 'Unknown Department';
	}

	function getPositionLevel(positionId) {
		const position = positions.find(p => p.id === positionId);
		return position ? position.level : 0;
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function getLevelBadgeColor(level) {
		const colors = [
			'bg-red-500',    // Level 1
			'bg-orange-500', // Level 2
			'bg-yellow-500', // Level 3
			'bg-green-500',  // Level 4
			'bg-blue-500'    // Level 5
		];
		return colors[level - 1] || 'bg-gray-500';
	}

	// Get available positions for reporting-to (exclude the selected position)
	function getAvailablePositions(excludeId = null) {
		const excludeIdNum = excludeId ? parseInt(excludeId) : null;
		return positions.filter(p => p.id !== excludeIdNum);
	}

	// Remove duplicates from reporting-to selections
	function handleReportingToChange(index) {
		// Clear any duplicate selections in other slots
		const currentValue = formData.reportsTo[index];
		if (currentValue) {
			formData.reportsTo = formData.reportsTo.map((value, i) => 
				i !== index && value === currentValue ? '' : value
			);
		}
	}
</script>

<div class="reporting-map">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Reporting Map Management</h2>
		<p class="subtitle">Define organizational reporting relationships and hierarchy structure</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Form Section -->
		<div class="form-section">
			<h3>{isEditing ? 'Edit Reporting Map' : 'Create New Reporting Map'}</h3>
			
			<form on:submit|preventDefault={saveReportingMap}>
				<div class="form-grid">
					<div class="form-group span-full">
						<label for="position">Select Position *</label>
						<select
							id="position"
							bind:value={formData.positionId}
							required
							disabled={isLoading}
						>
							<option value="">Choose a position...</option>
							{#each positions as position}
								<option value={position.id}>
									{position.position_title_en} ({position.position_title_ar}) - {position.hr_departments?.department_name_en || 'Unknown Department'} - Level {position.hr_levels?.level_order || 'N/A'}
								</option>
							{/each}
						</select>
					</div>

					<div class="reporting-slots">
						<h4>Reports To (Select up to 5 positions)</h4>
						<div class="slots-grid">
							{#each formData.reportsTo as reportsTo, index}
								<div class="slot-group">
									<label for="reports-to-{index}">Slot {index + 1}</label>
									<select
										id="reports-to-{index}"
										bind:value={formData.reportsTo[index]}
										on:change={() => handleReportingToChange(index)}
										disabled={isLoading}
									>
										<option value="">Select position...</option>
										{#each getAvailablePositions(formData.positionId) as position}
											<option 
												value={position.id}
												disabled={formData.reportsTo.includes(position.id.toString()) && formData.reportsTo[index] !== position.id.toString()}
											>
												{position.position_title_en} - L{position.hr_levels?.level_order || 'N/A'}
											</option>
										{/each}
									</select>
								</div>
							{/each}
						</div>
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
							<span class="icon">{isEditing ? '✏️' : '📈'}</span>
							{isEditing ? 'Update Reporting Map' : 'Save Reporting Map'}
						{/if}
					</button>
				</div>
			</form>
		</div>

		<!-- Reporting Maps Table -->
		<div class="table-section">
			<div class="table-header">
				<h3>Reporting Maps ({reportingMaps.length})</h3>
				<button class="refresh-btn" on:click={loadData} disabled={isLoading}>
					<span class="icon">🔄</span>
					Refresh
				</button>
			</div>

			{#if isLoading && reportingMaps.length === 0}
				<div class="loading-state">
					<div class="spinner large"></div>
					<p>Loading reporting maps...</p>
				</div>
			{:else if reportingMaps.length === 0}
				<div class="empty-state">
					<div class="empty-icon">📈</div>
					<h4>No Reporting Maps Found</h4>
					<p>Create your first reporting map to define organizational hierarchy</p>
				</div>
			{:else}
				<div class="table-container">
					<table class="reporting-table">
						<thead>
							<tr>
								<th>Position</th>
								<th>Department</th>
								<th>Level</th>
								<th>Reports To</th>
								<th>Created Date</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each reportingMaps as map (map.id)}
								<tr class="table-row">
									<td class="position-cell">
										<div class="position-names">
											<div class="name-en">{getPositionName(map.subordinate_position_id)}</div>
											<div class="name-ar">{getPositionNameAr(map.subordinate_position_id)}</div>
										</div>
									</td>
									<td class="department-cell">
										{getPositionDepartment(map.subordinate_position_id)}
									</td>
									<td class="level-cell">
										<div class="level-badge {getLevelBadgeColor(getPositionLevel(map.subordinate_position_id))}">
											L{getPositionLevel(map.subordinate_position_id)}
										</div>
									</td>
									<td class="reports-to-cell">
										<div class="reports-to-list">
											{#each [map.manager_position_1, map.manager_position_2, map.manager_position_3, map.manager_position_4, map.manager_position_5].filter(id => id) as managerId, index}
												<div class="report-item">
													<span class="report-number">{index + 1}.</span>
													<div class="report-position">
														<div class="report-name-en">{getPositionName(managerId)}</div>
														<div class="report-name-ar">{getPositionNameAr(managerId)}</div>
													</div>
												</div>
											{/each}
										</div>
									</td>
									<td class="date-cell">{formatDate(map.created_at)}</td>
									<td>
										<div class="actions">
											<button 
												class="edit-btn" 
												on:click={() => editReportingMap(map)}
												disabled={isLoading}
												title="Edit Reporting Map"
											>
												✏️
											</button>
											<button 
												class="delete-btn" 
												on:click={() => deleteReportingMap(map.id)}
												disabled={isLoading}
												title="Delete Reporting Map"
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
	.reporting-map {
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
		display: flex;
		flex-direction: column;
		gap: 20px;
		margin-bottom: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group.span-full {
		width: 100%;
	}

	.form-group label {
		margin-bottom: 8px;
		font-weight: 500;
		color: #374151;
	}

	.form-group select {
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 16px;
		transition: all 0.2s;
		background: white;
		font-family: inherit;
	}

	.form-group select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.form-group select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.reporting-slots {
		margin-top: 20px;
	}

	.reporting-slots h4 {
		font-size: 16px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 16px 0;
	}

	.slots-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 16px;
	}

	.slot-group {
		display: flex;
		flex-direction: column;
	}

	.slot-group label {
		margin-bottom: 8px;
		font-weight: 500;
		color: #6b7280;
		font-size: 14px;
	}

	.slot-group select {
		padding: 10px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.slot-group select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.slot-group select:disabled {
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
		background: #6366f1;
		color: white;
		border-color: #6366f1;
	}

	.save-btn:hover:not(:disabled) {
		background: #4f46e5;
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

	.reporting-table {
		width: 100%;
		border-collapse: collapse;
	}

	.reporting-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.reporting-table td {
		padding: 16px;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: top;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.position-cell {
		min-width: 200px;
	}

	.position-names .name-en {
		font-weight: 600;
		color: #111827;
		margin-bottom: 4px;
	}

	.position-names .name-ar {
		font-size: 14px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
	}

	.department-cell {
		font-size: 14px;
		color: #4b5563;
		min-width: 150px;
	}

	.level-cell {
		text-align: center;
	}

	.level-badge {
		color: white;
		font-size: 12px;
		font-weight: 600;
		padding: 4px 8px;
		border-radius: 12px;
		text-align: center;
		width: 32px;
		display: inline-block;
	}

	.reports-to-cell {
		min-width: 300px;
	}

	.reports-to-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.report-item {
		display: flex;
		align-items: flex-start;
		gap: 8px;
	}

	.report-number {
		color: #6366f1;
		font-weight: 600;
		font-size: 12px;
		flex-shrink: 0;
		margin-top: 2px;
	}

	.report-position {
		flex: 1;
	}

	.report-name-en {
		font-size: 14px;
		color: #111827;
		font-weight: 500;
	}

	.report-name-ar {
		font-size: 12px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
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
		.slots-grid {
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

		.reporting-table th,
		.reporting-table td {
			padding: 8px 12px;
			font-size: 14px;
		}

		.position-cell,
		.reports-to-cell {
			min-width: unset;
		}
	}
</style>