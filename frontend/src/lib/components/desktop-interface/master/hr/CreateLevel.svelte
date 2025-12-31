<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';

	// State management
	let levels = [];
	let isLoading = false;
	let errorMessage = '';
	let isEditing = false;
	let editingId = null;
	let draggedItem = null;

	// Form data
	let formData = {
		nameAr: '',
		nameEn: '',
		description: '',
		level: 1
	};

	// Mock levels data with hierarchical structure
	const mockLevels = [
		{
			id: 1,
			name_ar: 'الإدارة العليا',
			name_en: 'Executive Management',
			description: 'Top-level management and strategic decision makers',
			level: 1,
			order: 1,
			created_at: '2024-01-15T08:00:00Z',
			updated_at: '2024-01-15T08:00:00Z'
		},
		{
			id: 2,
			name_ar: 'الإدارة الوسطى',
			name_en: 'Middle Management',
			description: 'Department heads and regional managers',
			level: 2,
			order: 2,
			created_at: '2024-01-20T08:00:00Z',
			updated_at: '2024-01-20T08:00:00Z'
		},
		{
			id: 3,
			name_ar: 'المشرفون',
			name_en: 'Supervisors',
			description: 'Team leaders and supervisors',
			level: 3,
			order: 3,
			created_at: '2024-02-01T08:00:00Z',
			updated_at: '2024-02-01T08:00:00Z'
		},
		{
			id: 4,
			name_ar: 'كبار الموظفين',
			name_en: 'Senior Staff',
			description: 'Senior level employees with specialized skills',
			level: 4,
			order: 4,
			created_at: '2024-02-05T08:00:00Z',
			updated_at: '2024-02-05T08:00:00Z'
		},
		{
			id: 5,
			name_ar: 'الموظفون',
			name_en: 'Staff',
			description: 'Regular employees and junior staff',
			level: 5,
			order: 5,
			created_at: '2024-02-10T08:00:00Z',
			updated_at: '2024-02-10T08:00:00Z'
		}
	];

	onMount(async () => {
		await loadLevels();
	});

	async function loadLevels() {
		isLoading = true;
		errorMessage = '';

		try {
			const { data, error } = await dataService.hrLevels.getAll();
			
			if (error) {
				console.error('Error loading levels:', error);
				errorMessage = 'Failed to load organizational levels: ' + (error.message || error);
			} else {
				levels = (data || []).sort((a, b) => a.level_order - b.level_order);
			}
		} catch (error) {
			console.error('Error loading levels:', error);
			errorMessage = 'Failed to load organizational levels: ' + error.message;
		} finally {
			isLoading = false;
		}
	}

	async function saveLevel() {
		if (!formData.nameAr.trim() || !formData.nameEn.trim()) {
			errorMessage = 'Both Arabic and English names are required';
			return;
		}

		if (formData.level < 1 || formData.level > 10) {
			errorMessage = 'Level must be between 1 and 10';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const levelData = {
				level_name_ar: formData.nameAr.trim(),
				level_name_en: formData.nameEn.trim(),
				level_order: formData.level
			};

			if (isEditing) {
				// Update existing level
				const { data, error } = await dataService.hrLevels.update(editingId, levelData);
				
				if (error) {
					console.error('Error updating level:', error);
					errorMessage = 'Failed to update level: ' + (error.message || error);
				} else {
					// Update local state
					levels = levels.map(l => 
						l.id === editingId ? data : l
					).sort((a, b) => a.level_order - b.level_order);
					
					isEditing = false;
					editingId = null;
					formData = { nameAr: '', nameEn: '', description: '', level: 1 };
				}
			} else {
				// Create new level
				const { data, error } = await dataService.hrLevels.create(levelData);
				
				if (error) {
					console.error('Error creating level:', error);
					errorMessage = 'Failed to create level: ' + (error.message || error);
				} else {
					// Add to local state
					levels = [...levels, data].sort((a, b) => a.level_order - b.level_order);
					formData = { nameAr: '', nameEn: '', description: '', level: 1 };
				}
			}
		} catch (error) {
			console.error('Error saving level:', error);
			errorMessage = `Failed to ${isEditing ? 'update' : 'create'} level: ` + error.message;
		} finally {
			isLoading = false;
		}
	}

	function editLevel(level) {
		isEditing = true;
		editingId = level.id;
		formData = {
			nameAr: level.level_name_ar,
			nameEn: level.level_name_en,
			description: level.description || '',
			level: level.level_order
		};
	}

	function cancelEdit() {
		isEditing = false;
		editingId = null;
		formData = { nameAr: '', nameEn: '', description: '', level: 1 };
	}

	async function deleteLevel(id) {
		if (!confirm('Are you sure you want to delete this level?')) {
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const { error } = await dataService.hrLevels.delete(id);
			
			if (error) {
				console.error('Error deleting level:', error);
				errorMessage = 'Failed to delete level: ' + (error.message || error);
			} else {
				levels = levels.filter(l => l.id !== id);
			}
		} catch (error) {
			console.error('Error deleting level:', error);
			errorMessage = 'Failed to delete level: ' + error.message;
		} finally {
			isLoading = false;
		}
	}

	// Drag and drop functionality for reordering
	function handleDragStart(event, level) {
		draggedItem = level;
		event.dataTransfer.effectAllowed = 'move';
	}

	function handleDragOver(event) {
		event.preventDefault();
		event.dataTransfer.dropEffect = 'move';
	}

	function handleDrop(event, targetLevel) {
		event.preventDefault();
		
		if (!draggedItem || draggedItem.id === targetLevel.id) {
			return;
		}

		// Reorder levels
		const draggedIndex = levels.findIndex(l => l.id === draggedItem.id);
		const targetIndex = levels.findIndex(l => l.id === targetLevel.id);

		const newLevels = [...levels];
		const [removed] = newLevels.splice(draggedIndex, 1);
		newLevels.splice(targetIndex, 0, removed);

		// Update order values
		levels = newLevels.map((level, index) => ({
			...level,
			order: index + 1
		}));

		draggedItem = null;
	}

	function moveLevel(levelId, direction) {
		const currentIndex = levels.findIndex(l => l.id === levelId);
		if (currentIndex === -1) return;

		let newIndex;
		if (direction === 'up' && currentIndex > 0) {
			newIndex = currentIndex - 1;
		} else if (direction === 'down' && currentIndex < levels.length - 1) {
			newIndex = currentIndex + 1;
		} else {
			return;
		}

		const newLevels = [...levels];
		[newLevels[currentIndex], newLevels[newIndex]] = [newLevels[newIndex], newLevels[currentIndex]];

		// Update order values
		levels = newLevels.map((level, index) => ({
			...level,
			order: index + 1
		}));
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
			'bg-blue-500',   // Level 5
			'bg-indigo-500', // Level 6
			'bg-purple-500', // Level 7
			'bg-pink-500',   // Level 8
			'bg-gray-500',   // Level 9
			'bg-black'       // Level 10
		];
		return colors[level - 1] || 'bg-gray-500';
	}
</script>

<div class="create-level">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Organizational Level Management</h2>
		<p class="subtitle">Define hierarchical levels and reporting structure</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Form Section -->
		<div class="form-section">
			<h3>{isEditing ? 'Edit Level' : 'Create New Level'}</h3>
			
			<form on:submit|preventDefault={saveLevel}>
				<div class="form-grid">
					<div class="form-group">
						<label for="name-ar">Arabic Name *</label>
						<input
							id="name-ar"
							type="text"
							bind:value={formData.nameAr}
							placeholder="اسم المستوى بالعربية"
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
							placeholder="Level Name in English"
							required
							disabled={isLoading}
						>
					</div>
					<div class="form-group span-2">
						<label for="description">Description</label>
						<input
							id="description"
							type="text"
							bind:value={formData.description}
							placeholder="Level description and responsibilities"
							disabled={isLoading}
						>
					</div>
					<div class="form-group">
						<label for="level">Hierarchy Level *</label>
						<input
							id="level"
							type="number"
							bind:value={formData.level}
							min="1"
							max="10"
							required
							disabled={isLoading}
						>
						<small>1 = Highest level, 10 = Lowest level</small>
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
							{isEditing ? 'Update Level' : 'Create Level'}
						{/if}
					</button>
				</div>
			</form>
		</div>

		<!-- Levels Hierarchy -->
		<div class="hierarchy-section">
			<div class="section-header">
				<h3>Organizational Hierarchy ({levels.length} levels)</h3>
				<div class="section-actions">
					<button class="refresh-btn" on:click={loadLevels} disabled={isLoading}>
						<span class="icon">🔄</span>
						Refresh
					</button>
				</div>
			</div>

			{#if isLoading && levels.length === 0}
				<div class="loading-state">
					<div class="spinner large"></div>
					<p>Loading organizational levels...</p>
				</div>
			{:else if levels.length === 0}
				<div class="empty-state">
					<div class="empty-icon">📊</div>
					<h4>No Levels Defined</h4>
					<p>Create your first organizational level to get started</p>
				</div>
			{:else}
				<div class="hierarchy-container">
					<div class="hierarchy-info">
						<p><strong>Tip:</strong> Drag levels to reorder them, or use the arrow buttons. Level 1 is the highest in hierarchy.</p>
					</div>
					
					{#each levels as level, index (level.id)}
						<div 
							class="level-item"
							draggable="true"
							on:dragstart={event => handleDragStart(event, level)}
							on:dragover={handleDragOver}
							on:drop={event => handleDrop(event, level)}
						>
							<div class="level-order">
								<div class="order-number">{index + 1}</div>
								<div class="level-badge {getLevelBadgeColor(level.level_order)}">
									L{level.level_order}
								</div>
							</div>

							<div class="level-content">
								<div class="level-names">
									<h4 class="level-name-en">{level.level_name_en}</h4>
									<p class="level-name-ar">{level.level_name_ar}</p>
								</div>
								
								{#if level.description}
									<p class="level-description">{level.description}</p>
								{/if}
								
								<div class="level-meta">
									<span class="meta-item">
										<strong>Created:</strong> {formatDate(level.created_at)}
									</span>
									{#if level.updated_at !== level.created_at}
										<span class="meta-item">
											<strong>Updated:</strong> {formatDate(level.updated_at)}
										</span>
									{/if}
								</div>
							</div>

							<div class="level-actions">
								<div class="move-buttons">
									<button 
										class="move-btn" 
										on:click={() => moveLevel(level.id, 'up')}
										disabled={isLoading || index === 0}
										title="Move Up"
									>
										↑
									</button>
									<button 
										class="move-btn" 
										on:click={() => moveLevel(level.id, 'down')}
										disabled={isLoading || index === levels.length - 1}
										title="Move Down"
									>
										↓
									</button>
								</div>
								
								<div class="action-buttons">
									<button 
										class="edit-btn" 
										on:click={() => editLevel(level)}
										disabled={isLoading}
										title="Edit Level"
									>
										✏️
									</button>
									<button 
										class="delete-btn" 
										on:click={() => deleteLevel(level.id)}
										disabled={isLoading}
										title="Delete Level"
									>
										🗑️
									</button>
								</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.create-level {
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

	.form-group small {
		margin-top: 4px;
		font-size: 12px;
		color: #6b7280;
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
		background: #8b5cf6;
		color: white;
		border-color: #8b5cf6;
	}

	.save-btn:hover:not(:disabled) {
		background: #7c3aed;
		transform: translateY(-1px);
	}

	.save-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.hierarchy-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.section-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.section-actions {
		display: flex;
		gap: 12px;
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

	.hierarchy-container {
		padding: 24px;
	}

	.hierarchy-info {
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 8px;
		padding: 12px 16px;
		margin-bottom: 24px;
	}

	.hierarchy-info p {
		margin: 0;
		font-size: 14px;
		color: #1e40af;
	}

	.level-item {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 20px;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		margin-bottom: 12px;
		background: white;
		cursor: move;
		transition: all 0.2s;
	}

	.level-item:hover {
		border-color: #d1d5db;
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.level-item:last-child {
		margin-bottom: 0;
	}

	.level-order {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		flex-shrink: 0;
	}

	.order-number {
		font-size: 18px;
		font-weight: 600;
		color: #374151;
		background: #f3f4f6;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.level-badge {
		color: white;
		font-size: 12px;
		font-weight: 600;
		padding: 4px 8px;
		border-radius: 12px;
		text-align: center;
		min-width: 32px;
	}

	.level-content {
		flex: 1;
	}

	.level-names {
		margin-bottom: 8px;
	}

	.level-name-en {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.level-name-ar {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
		direction: rtl;
		text-align: right;
	}

	.level-description {
		font-size: 14px;
		color: #4b5563;
		margin: 0 0 12px 0;
		line-height: 1.5;
	}

	.level-meta {
		display: flex;
		gap: 16px;
		font-size: 12px;
		color: #9ca3af;
	}

	.level-actions {
		display: flex;
		flex-direction: column;
		gap: 8px;
		flex-shrink: 0;
	}

	.move-buttons {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.move-btn {
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		padding: 4px 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.move-btn:hover:not(:disabled) {
		background: #e5e7eb;
		border-color: #9ca3af;
	}

	.move-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.action-buttons {
		display: flex;
		gap: 4px;
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

		.section-header {
			flex-direction: column;
			gap: 12px;
			align-items: flex-start;
		}

		.level-item {
			flex-direction: column;
			align-items: flex-start;
			gap: 12px;
		}

		.level-actions {
			flex-direction: row;
			width: 100%;
			justify-content: space-between;
		}

		.move-buttons {
			flex-direction: row;
		}
	}
</style>