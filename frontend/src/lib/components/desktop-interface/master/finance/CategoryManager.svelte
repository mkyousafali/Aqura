<script>
	// Category Manager Component
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	// Data variables
	let parentCategories = [];
	let subCategories = [];
	let filteredParentCategories = [];
	let filteredSubCategories = [];
	let isLoading = false;
	let error = '';

	// Search and filter
	let searchQuery = '';
	let selectedParentFilter = '';
	let activeTab = 'parent'; // 'parent' or 'sub'

	// Modal states
	let showParentModal = false;
	let showSubModal = false;
	let isEditMode = false;
	let editingCategory = null;

	// Form data
	let parentForm = {
		name_en: '',
		name_ar: ''
	};

	let subForm = {
		parent_category_id: null,
		name_en: '',
		name_ar: ''
	};

	onMount(async () => {
		await loadCategories();
	});

	// Load all categories
	async function loadCategories() {
		try {
			isLoading = true;
			error = '';

			// Load parent categories using admin client to bypass RLS
			const { data: parentData, error: parentError } = await supabase
				.from('expense_parent_categories')
				.select('*')
				.order('name_en');

			if (parentError) throw parentError;
			parentCategories = parentData || [];
			filteredParentCategories = parentCategories;

			// Load sub categories using admin client to bypass RLS
			const { data: subData, error: subError } = await supabase
				.from('expense_sub_categories')
				.select(`
					*,
					expense_parent_categories (
						id,
						name_en,
						name_ar
					)
				`)
				.order('name_en');

			if (subError) throw subError;
			subCategories = subData || [];
			filteredSubCategories = subCategories;

		} catch (err) {
			error = err.message;
			console.error('Error loading categories:', err);
		} finally {
			isLoading = false;
		}
	}

	// Search functionality
	function handleSearch() {
		const query = searchQuery.toLowerCase();

		if (activeTab === 'parent') {
			filteredParentCategories = parentCategories.filter(cat => 
				cat.name_en.toLowerCase().includes(query) ||
				cat.name_ar.toLowerCase().includes(query)
			);
		} else {
			// First apply parent filter if selected
			let baseCategories = subCategories;
			if (selectedParentFilter && selectedParentFilter !== '') {
				const parentId = parseInt(selectedParentFilter);
				baseCategories = subCategories.filter(cat => 
					cat.parent_category_id === parentId
				);
			}

			// Then apply search query
			if (query) {
				filteredSubCategories = baseCategories.filter(cat => 
					cat.name_en.toLowerCase().includes(query) ||
					cat.name_ar.toLowerCase().includes(query) ||
					cat.expense_parent_categories?.name_en.toLowerCase().includes(query) ||
					cat.expense_parent_categories?.name_ar.toLowerCase().includes(query)
				);
			} else {
				filteredSubCategories = baseCategories;
			}
		}
	}

	// Filter by parent category
	function handleParentFilter() {
		handleSearch(); // Reapply search with new filter
	}

	// Open parent category modal
	function openParentModal(category = null) {
		if (category) {
			isEditMode = true;
			editingCategory = category;
			parentForm = {
				name_en: category.name_en,
				name_ar: category.name_ar
			};
		} else {
			isEditMode = false;
			editingCategory = null;
			parentForm = { name_en: '', name_ar: '' };
		}
		showParentModal = true;
	}

	// Open sub category modal
	function openSubModal(category = null) {
		if (category) {
			isEditMode = true;
			editingCategory = category;
			subForm = {
				parent_category_id: category.parent_category_id,
				name_en: category.name_en,
				name_ar: category.name_ar
			};
		} else {
			isEditMode = false;
			editingCategory = null;
			subForm = { parent_category_id: '', name_en: '', name_ar: '' };
		}
		showSubModal = true;
	}

	// Close modals
	function closeParentModal() {
		showParentModal = false;
		isEditMode = false;
		editingCategory = null;
		parentForm = { name_en: '', name_ar: '' };
	}

	function closeSubModal() {
		showSubModal = false;
		isEditMode = false;
		editingCategory = null;
		subForm = { parent_category_id: '', name_en: '', name_ar: '' };
	}

	// Save parent category
	async function saveParentCategory() {
		try {
			if (!parentForm.name_en.trim() || !parentForm.name_ar.trim()) {
				alert('Please fill in both English and Arabic names');
				return;
			}

			if (isEditMode) {
				const { error } = await supabase
					.from('expense_parent_categories')
					.update({
						name_en: parentForm.name_en.trim(),
						name_ar: parentForm.name_ar.trim(),
						updated_at: new Date().toISOString()
					})
					.eq('id', editingCategory.id);

				if (error) throw error;
				alert('✅ Parent category updated successfully!');
			} else {
				const { error } = await supabase
					.from('expense_parent_categories')
					.insert({
						name_en: parentForm.name_en.trim(),
						name_ar: parentForm.name_ar.trim()
					});

				if (error) throw error;
				alert('✅ Parent category created successfully!');
			}

			closeParentModal();
			await loadCategories();
		} catch (err) {
			console.error('Error saving parent category:', err);
			alert('❌ Error: ' + err.message);
		}
	}

	// Save sub category
	async function saveSubCategory() {
		try {
			if (!subForm.parent_category_id || !subForm.name_en.trim() || !subForm.name_ar.trim()) {
				alert('Please fill in all fields');
				return;
			}

			// Convert parent_category_id to number
			const parentId = parseInt(subForm.parent_category_id);

			if (isEditMode) {
				const { error } = await supabase
					.from('expense_sub_categories')
					.update({
						parent_category_id: parentId,
						name_en: subForm.name_en.trim(),
						name_ar: subForm.name_ar.trim(),
						updated_at: new Date().toISOString()
					})
					.eq('id', editingCategory.id);

				if (error) throw error;
				alert('✅ Sub category updated successfully!');
			} else {
				const { error } = await supabase
					.from('expense_sub_categories')
					.insert({
						parent_category_id: parentId,
						name_en: subForm.name_en.trim(),
						name_ar: subForm.name_ar.trim()
					});

				if (error) throw error;
				alert('✅ Sub category created successfully!');
			}

			closeSubModal();
			await loadCategories();
		} catch (err) {
			console.error('Error saving sub category:', err);
			alert('❌ Error: ' + err.message);
		}
	}

	// Delete parent category
	async function deleteParentCategory(category) {
		if (!confirm(`Are you sure you want to delete "${category.name_en}"?\n\nThis will also delete all related sub-categories.`)) {
			return;
		}

		try {
			const { error } = await supabase
				.from('expense_parent_categories')
				.delete()
				.eq('id', category.id);

			if (error) throw error;
			alert('✅ Parent category deleted successfully!');
			await loadCategories();
		} catch (err) {
			console.error('Error deleting parent category:', err);
			alert('❌ Error: ' + err.message);
		}
	}

	// Delete sub category
	async function deleteSubCategory(category) {
		if (!confirm(`Are you sure you want to delete "${category.name_en}"?`)) {
			return;
		}

		try {
			const { error } = await supabase
				.from('expense_sub_categories')
				.delete()
				.eq('id', category.id);

			if (error) throw error;
			alert('✅ Sub category deleted successfully!');
			await loadCategories();
		} catch (err) {
			console.error('Error deleting sub category:', err);
			alert('❌ Error: ' + err.message);
		}
	}

	// Get sub-category count for parent
	function getSubCategoryCount(parentId) {
		return subCategories.filter(sub => sub.parent_category_id === parentId).length;
	}
</script>

<div class="category-manager">
	<div class="header">
		<div class="title-section">
			<h1 class="title">📁 Category Manager</h1>
			<p class="subtitle">Manage expense categories and classifications</p>
		</div>
		<div class="header-actions">
			<button class="btn-primary" on:click={() => openParentModal()}>
				<span>➕</span>
				Create Parent Category
			</button>
			<button class="btn-secondary" on:click={() => openSubModal()}>
				<span>➕</span>
				Create Sub Category
			</button>
		</div>
	</div>

	<div class="content">
		<!-- Tabs -->
		<div class="tabs">
			<button 
				class="tab {activeTab === 'parent' ? 'active' : ''}"
				on:click={() => { activeTab = 'parent'; searchQuery = ''; handleSearch(); }}
			>
				Parent Categories ({parentCategories.length})
			</button>
			<button 
				class="tab {activeTab === 'sub' ? 'active' : ''}"
				on:click={() => { activeTab = 'sub'; searchQuery = ''; selectedParentFilter = ''; handleSearch(); }}
			>
				Sub Categories ({subCategories.length})
			</button>
		</div>

		<!-- Search and Filter Section -->
		<div class="filter-section">
			<div class="search-box">
				<input 
					type="text" 
					bind:value={searchQuery}
					on:input={handleSearch}
					placeholder="Search by name (English or Arabic)..."
					class="search-input"
				/>
			</div>

			{#if activeTab === 'sub'}
				<div class="filter-box">
					<select bind:value={selectedParentFilter} on:change={handleParentFilter} class="filter-select">
						<option value="">All Parent Categories</option>
						{#each parentCategories as parent}
							<option value={parent.id}>{parent.name_en} - {parent.name_ar}</option>
						{/each}
					</select>
				</div>
			{/if}
		</div>

		<!-- Loading State -->
		{#if isLoading}
			<div class="loading">
				<div class="spinner"></div>
				<span>Loading categories...</span>
			</div>
		{:else if error}
			<div class="error">
				<span class="error-icon">⚠️</span>
				<span>Error: {error}</span>
			</div>
		{:else}
			<!-- Parent Categories Table -->
			{#if activeTab === 'parent'}
				<div class="table-container">
					<table class="categories-table">
						<thead>
							<tr>
								<th>English Name</th>
								<th>Arabic Name</th>
								<th>Sub Categories</th>
								<th>Created Date</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredParentCategories as category}
								<tr>
									<td class="name-cell">{category.name_en}</td>
									<td class="name-cell arabic">{category.name_ar}</td>
									<td class="count-cell">{getSubCategoryCount(category.id)}</td>
									<td class="date-cell">{new Date(category.created_at).toLocaleDateString()}</td>
									<td class="actions-cell">
										<button class="btn-edit" on:click={() => openParentModal(category)} title="Edit">
											✏️
										</button>
										<button class="btn-delete" on:click={() => deleteParentCategory(category)} title="Delete">
											🗑️
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>

					{#if filteredParentCategories.length === 0}
						<div class="no-data">
							<span class="no-data-icon">�</span>
							<span>No parent categories found</span>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Sub Categories Table -->
			{#if activeTab === 'sub'}
				<div class="table-container">
					<table class="categories-table">
						<thead>
							<tr>
								<th>Parent Category</th>
								<th>English Name</th>
								<th>Arabic Name</th>
								<th>Created Date</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredSubCategories as category}
								<tr>
									<td class="parent-cell">
										<div class="parent-badge">
											{category.expense_parent_categories?.name_en || 'N/A'}
										</div>
									</td>
									<td class="name-cell">{category.name_en}</td>
									<td class="name-cell arabic">{category.name_ar}</td>
									<td class="date-cell">{new Date(category.created_at).toLocaleDateString()}</td>
									<td class="actions-cell">
										<button class="btn-edit" on:click={() => openSubModal(category)} title="Edit">
											✏️
										</button>
										<button class="btn-delete" on:click={() => deleteSubCategory(category)} title="Delete">
											🗑️
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>

					{#if filteredSubCategories.length === 0}
						<div class="no-data">
							<span class="no-data-icon">📋</span>
							<span>No sub categories found</span>
						</div>
					{/if}
				</div>
			{/if}
		{/if}
	</div>
</div>

<!-- Parent Category Modal -->
{#if showParentModal}
	<div class="modal-overlay" on:click={closeParentModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{isEditMode ? 'Edit' : 'Create'} Parent Category</h3>
				<button class="close-btn" on:click={closeParentModal}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="form-group">
					<label for="parent_name_en">English Name</label>
					<input 
						type="text" 
						id="parent_name_en"
						bind:value={parentForm.name_en}
						placeholder="Enter English name"
					/>
				</div>
				
				<div class="form-group">
					<label for="parent_name_ar">Arabic Name</label>
					<input 
						type="text" 
						id="parent_name_ar"
						bind:value={parentForm.name_ar}
						placeholder="أدخل الاسم بالعربية"
						dir="rtl"
					/>
				</div>
			</div>
			
			<div class="modal-footer">
				<button class="btn-cancel" on:click={closeParentModal}>Cancel</button>
				<button class="btn-save" on:click={saveParentCategory}>
					{isEditMode ? 'Update' : 'Create'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Sub Category Modal -->
{#if showSubModal}
	<div class="modal-overlay" on:click={closeSubModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{isEditMode ? 'Edit' : 'Create'} Sub Category</h3>
				<button class="close-btn" on:click={closeSubModal}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="form-group">
					<label for="parent_category">Parent Category</label>
					<select id="parent_category" bind:value={subForm.parent_category_id}>
						<option value={null}>Select parent category...</option>
						{#each parentCategories as parent}
							<option value={parent.id}>{parent.name_en} - {parent.name_ar}</option>
						{/each}
					</select>
				</div>

				<div class="form-group">
					<label for="sub_name_en">English Name</label>
					<input 
						type="text" 
						id="sub_name_en"
						bind:value={subForm.name_en}
						placeholder="Enter English name"
					/>
				</div>
				
				<div class="form-group">
					<label for="sub_name_ar">Arabic Name</label>
					<input 
						type="text" 
						id="sub_name_ar"
						bind:value={subForm.name_ar}
						placeholder="أدخل الاسم بالعربية"
						dir="rtl"
					/>
				</div>
			</div>
			
			<div class="modal-footer">
				<button class="btn-cancel" on:click={closeSubModal}>Cancel</button>
				<button class="btn-save" on:click={saveSubCategory}>
					{isEditMode ? 'Update' : 'Create'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.category-manager {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.header {
		margin-bottom: 2rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
	}

	.title-section {
		flex: 1;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 0.5rem 0;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
	}

	.header-actions {
		display: flex;
		gap: 12px;
	}

	.btn-primary, .btn-secondary {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 20px;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 14px;
		transition: all 0.2s ease;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.btn-secondary {
		background: #10b981;
		color: white;
	}

	.btn-secondary:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.content {
		flex: 1;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 2rem;
		display: flex;
		flex-direction: column;
	}

	.tabs {
		display: flex;
		gap: 8px;
		margin-bottom: 24px;
		border-bottom: 2px solid #e5e7eb;
	}

	.tab {
		padding: 12px 24px;
		background: none;
		border: none;
		border-bottom: 3px solid transparent;
		cursor: pointer;
		font-weight: 600;
		font-size: 14px;
		color: #6b7280;
		transition: all 0.2s ease;
		margin-bottom: -2px;
	}

	.tab:hover {
		color: #3b82f6;
		background: #f0f9ff;
	}

	.tab.active {
		color: #3b82f6;
		border-bottom-color: #3b82f6;
		background: #f0f9ff;
	}

	.filter-section {
		display: flex;
		gap: 16px;
		margin-bottom: 24px;
	}

	.search-box {
		flex: 1;
	}

	.search-input {
		width: 100%;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		transition: border-color 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-box {
		min-width: 300px;
	}

	.filter-select {
		width: 100%;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		transition: border-color 0.2s ease;
		cursor: pointer;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.table-container {
		flex: 1;
		overflow-x: auto;
	}

	.categories-table {
		width: 100%;
		border-collapse: collapse;
	}

	.categories-table thead {
		background: #f9fafb;
		border-bottom: 2px solid #e5e7eb;
	}

	.categories-table th {
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		font-size: 13px;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.categories-table tbody tr {
		border-bottom: 1px solid #e5e7eb;
		transition: background-color 0.2s ease;
	}

	.categories-table tbody tr:hover {
		background: #f9fafb;
	}

	.categories-table td {
		padding: 12px 16px;
		font-size: 14px;
		color: #1f2937;
	}

	.name-cell {
		font-weight: 500;
	}

	.name-cell.arabic {
		direction: rtl;
		text-align: right;
	}

	.count-cell {
		text-align: center;
		font-weight: 600;
		color: #3b82f6;
	}

	.date-cell {
		color: #6b7280;
		font-size: 13px;
	}

	.parent-cell {
		max-width: 200px;
	}

	.parent-badge {
		display: inline-block;
		padding: 4px 12px;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.actions-cell {
		display: flex;
		gap: 8px;
		justify-content: flex-end;
	}

	.btn-edit, .btn-delete {
		padding: 6px 12px;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 16px;
		transition: all 0.2s ease;
	}

	.btn-edit {
		background: #fef3c7;
		color: #92400e;
	}

	.btn-edit:hover {
		background: #fde68a;
		transform: scale(1.1);
	}

	.btn-delete {
		background: #fee2e2;
		color: #991b1b;
	}

	.btn-delete:hover {
		background: #fecaca;
		transform: scale(1.1);
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 60px;
		gap: 16px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.error {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 12px;
		padding: 40px;
		color: #dc2626;
		font-weight: 500;
	}

	.error-icon {
		font-size: 24px;
	}

	.no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 60px;
		color: #9ca3af;
		gap: 12px;
	}

	.no-data-icon {
		font-size: 48px;
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

	.modal {
		background: white;
		border-radius: 12px;
		width: 90%;
		max-width: 500px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #9ca3af;
		cursor: pointer;
		padding: 4px;
		line-height: 1;
	}

	.close-btn:hover {
		color: #6b7280;
	}

	.modal-content {
		padding: 24px;
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		font-weight: 500;
		color: #374151;
		font-size: 14px;
	}

	.form-group input,
	.form-group select {
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s ease;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 24px;
		border-top: 1px solid #e5e7eb;
	}

	.btn-cancel {
		padding: 10px 20px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.btn-cancel:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.btn-save {
		padding: 10px 20px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.btn-save:hover {
		background: #2563eb;
	}
</style>
