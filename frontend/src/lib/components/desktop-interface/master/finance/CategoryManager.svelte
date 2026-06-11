<script>
	// Category Manager Component
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { locale, t } from '$lib/i18n';

	// Helper to get locale-aware category name
	function getCatName(cat) {
		if (!cat) return '';
		return $locale === 'ar' ? (cat.name_ar || cat.name_en) : (cat.name_en || cat.name_ar);
	}

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
				alert($locale === 'ar' ? 'يرجى ملء الاسمين بالعربية والإنجليزية' : 'Please fill in both English and Arabic names');
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
				alert($locale === 'ar' ? '✅ تم تحديث الفئة الرئيسية بنجاح!' : '✅ Parent category updated successfully!');
			} else {
				const { error } = await supabase
					.from('expense_parent_categories')
					.insert({
						name_en: parentForm.name_en.trim(),
						name_ar: parentForm.name_ar.trim()
					});

				if (error) throw error;
				alert($locale === 'ar' ? '✅ تم إنشاء الفئة الرئيسية بنجاح!' : '✅ Parent category created successfully!');
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
				alert($locale === 'ar' ? 'يرجى ملء جميع الحقول' : 'Please fill in all fields');
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
				alert($locale === 'ar' ? '✅ تم تحديث الفئة الفرعية بنجاح!' : '✅ Sub category updated successfully!');
			} else {
				const { error } = await supabase
					.from('expense_sub_categories')
					.insert({
						parent_category_id: parentId,
						name_en: subForm.name_en.trim(),
						name_ar: subForm.name_ar.trim()
					});

				if (error) throw error;
				alert($locale === 'ar' ? '✅ تم إنشاء الفئة الفرعية بنجاح!' : '✅ Sub category created successfully!');
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
		const name = getCatName(category);
		if (!confirm($locale === 'ar' ? `هل أنت متأكد من حذف "${name}"؟\n\nسيؤدي هذا إلى حذف جميع الفئات الفرعية المرتبطة.` : `Are you sure you want to delete "${name}"?\n\nThis will also delete all related sub-categories.`)) {
			return;
		}

		try {
			const { error } = await supabase
				.from('expense_parent_categories')
				.delete()
				.eq('id', category.id);

			if (error) throw error;
			alert($locale === 'ar' ? '✅ تم حذف الفئة الرئيسية بنجاح!' : '✅ Parent category deleted successfully!');
			await loadCategories();
		} catch (err) {
			console.error('Error deleting parent category:', err);
			alert('❌ Error: ' + err.message);
		}
	}

	// Delete sub category
	async function deleteSubCategory(category) {
		const name = getCatName(category);
		if (!confirm($locale === 'ar' ? `هل أنت متأكد من حذف "${name}"؟` : `Are you sure you want to delete "${name}"?`)) {
			return;
		}

		try {
			const { error } = await supabase
				.from('expense_sub_categories')
				.delete()
				.eq('id', category.id);

			if (error) throw error;
			alert($locale === 'ar' ? '✅ تم حذف الفئة الفرعية بنجاح!' : '✅ Sub category deleted successfully!');
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

<div class="category-manager" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="header">
		<div class="title-section">
			<h1 class="title">📁 {$locale === 'ar' ? 'مدير الفئات' : 'Category Manager'}</h1>
			<p class="subtitle">{$locale === 'ar' ? 'إدارة فئات المصاريف والتصنيفات' : 'Manage expense categories and classifications'}</p>
		</div>
		<div class="header-actions">
			<button class="btn-primary" on:click={() => openParentModal()}>
				<span>➕</span>
				{$locale === 'ar' ? 'إنشاء فئة رئيسية' : 'Create Parent Category'}
			</button>
			<button class="btn-secondary" on:click={() => openSubModal()}>
				<span>➕</span>
				{$locale === 'ar' ? 'إنشاء فئة فرعية' : 'Create Sub Category'}
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
				{$locale === 'ar' ? 'الفئات الرئيسية' : 'Parent Categories'} ({parentCategories.length})
			</button>
			<button 
				class="tab {activeTab === 'sub' ? 'active' : ''}"
				on:click={() => { activeTab = 'sub'; searchQuery = ''; selectedParentFilter = ''; handleSearch(); }}
			>
				{$locale === 'ar' ? 'الفئات الفرعية' : 'Sub Categories'} ({subCategories.length})
			</button>
		</div>

		<!-- Search and Filter Section -->
		<div class="filter-section">
			<div class="search-box">
				<input 
					type="text" 
					bind:value={searchQuery}
					on:input={handleSearch}
					placeholder={$locale === 'ar' ? 'ابحث بالاسم (عربي أو إنجليزي)...' : 'Search by name (English or Arabic)...'}
					class="search-input"
				/>
			</div>

			{#if activeTab === 'sub'}
				<div class="filter-box">
					<select bind:value={selectedParentFilter} on:change={handleParentFilter} class="filter-select">
						<option value="">{$locale === 'ar' ? 'كل الفئات الرئيسية' : 'All Parent Categories'}</option>
						{#each parentCategories as parent}
							<option value={parent.id}>{getCatName(parent)}</option>
						{/each}
					</select>
				</div>
			{/if}
		</div>

		<!-- Loading State -->
		{#if isLoading}
			<div class="loading">
				<div class="spinner"></div>
				<span>{$locale === 'ar' ? 'جاري تحميل الفئات...' : 'Loading categories...'}</span>
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
                                                                <th>{$locale === 'ar' ? 'الاسم' : 'Name'}</th>
								<th>{$locale === 'ar' ? 'الفئات الفرعية' : 'Sub Categories'}</th>
								<th>{$locale === 'ar' ? 'تاريخ الإنشاء' : 'Created Date'}</th>
								<th>{$locale === 'ar' ? 'الإجراءات' : 'Actions'}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredParentCategories as category}
								<tr>
									<td class="name-cell">{getCatName(category)}</td>
									<td class="count-cell">{getSubCategoryCount(category.id)}</td>
									<td class="date-cell">{new Date(category.created_at).toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US')}</td>
									<td class="actions-cell">
										<button class="btn-edit" on:click={() => openParentModal(category)} title={$locale === 'ar' ? 'تعديل' : 'Edit'}>
											✏️
										</button>
										<button class="btn-delete" on:click={() => deleteParentCategory(category)} title={$locale === 'ar' ? 'حذف' : 'Delete'}>
											🗑️
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>

					{#if filteredParentCategories.length === 0}
						<div class="no-data">
							<span class="no-data-icon">📋</span>
							<span>{$locale === 'ar' ? 'لا توجد فئات رئيسية' : 'No parent categories found'}</span>
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
                                                                <th>{$locale === 'ar' ? 'الفئة الرئيسية' : 'Parent Category'}</th>
								<th>{$locale === 'ar' ? 'الاسم' : 'Name'}</th>
								<th>{$locale === 'ar' ? 'تاريخ الإنشاء' : 'Created Date'}</th>
								<th>{$locale === 'ar' ? 'الإجراءات' : 'Actions'}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredSubCategories as category}
								<tr>
									<td class="parent-cell">
										<div class="parent-badge">
											{getCatName(category.expense_parent_categories) || 'N/A'}
										</div>
									</td>
									<td class="name-cell">{getCatName(category)}</td>
									<td class="date-cell">{new Date(category.created_at).toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US')}</td>
									<td class="actions-cell">
										<button class="btn-edit" on:click={() => openSubModal(category)} title={$locale === 'ar' ? 'تعديل' : 'Edit'}>
											✏️
										</button>
										<button class="btn-delete" on:click={() => deleteSubCategory(category)} title={$locale === 'ar' ? 'حذف' : 'Delete'}>
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
							<span>{$locale === 'ar' ? 'لا توجد فئات فرعية' : 'No sub categories found'}</span>
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
				<h3>{isEditMode ? ($locale === 'ar' ? 'تعديل' : 'Edit') : ($locale === 'ar' ? 'إنشاء' : 'Create')} {$locale === 'ar' ? 'فئة رئيسية' : 'Parent Category'}</h3>
				<button class="close-btn" on:click={closeParentModal}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="form-group">
					<label for="parent_name_en">{$locale === 'ar' ? 'الاسم بالإنجليزية' : 'English Name'}</label>
					<input 
						type="text" 
						id="parent_name_en"
						bind:value={parentForm.name_en}
						placeholder={$locale === 'ar' ? 'أدخل الاسم بالإنجليزية' : 'Enter English name'}
					/>
				</div>
				
				<div class="form-group">
					<label for="parent_name_ar">{$locale === 'ar' ? 'الاسم بالعربية' : 'Arabic Name'}</label>
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
				<button class="btn-cancel" on:click={closeParentModal}>{$locale === 'ar' ? 'إلغاء' : 'Cancel'}</button>
				<button class="btn-save" on:click={saveParentCategory}>
					{isEditMode ? ($locale === 'ar' ? 'تحديث' : 'Update') : ($locale === 'ar' ? 'إنشاء' : 'Create')}
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
				<h3>{isEditMode ? ($locale === 'ar' ? 'تعديل' : 'Edit') : ($locale === 'ar' ? 'إنشاء' : 'Create')} {$locale === 'ar' ? 'فئة فرعية' : 'Sub Category'}</h3>
				<button class="close-btn" on:click={closeSubModal}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="form-group">
					<label for="parent_category">{$locale === 'ar' ? 'الفئة الرئيسية' : 'Parent Category'}</label>
					<select id="parent_category" bind:value={subForm.parent_category_id}>
						<option value={null}>{$locale === 'ar' ? 'اختر الفئة الرئيسية...' : 'Select parent category...'}</option>
						{#each parentCategories as parent}
							<option value={parent.id}>{getCatName(parent)}</option>
						{/each}
					</select>
				</div>

				<div class="form-group">
					<label for="sub_name_en">{$locale === 'ar' ? 'الاسم بالإنجليزية' : 'English Name'}</label>
					<input 
						type="text" 
						id="sub_name_en"
						bind:value={subForm.name_en}
						placeholder={$locale === 'ar' ? 'أدخل الاسم بالإنجليزية' : 'Enter English name'}
					/>
				</div>
				
				<div class="form-group">
					<label for="sub_name_ar">{$locale === 'ar' ? 'الاسم بالعربية' : 'Arabic Name'}</label>
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
				<button class="btn-cancel" on:click={closeSubModal}>{$locale === 'ar' ? 'إلغاء' : 'Cancel'}</button>
				<button class="btn-save" on:click={saveSubCategory}>
					{isEditMode ? ($locale === 'ar' ? 'تحديث' : 'Update') : ($locale === 'ar' ? 'إنشاء' : 'Create')}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	/* ===================== BASE ===================== */
	.category-manager {
		padding: 0.75rem 1rem;
		background: linear-gradient(135deg, #e8f0fe 0%, #f0f7ff 50%, #e8f4f8 100%);
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* ===================== HEADER ===================== */
	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: rgba(255, 255, 255, 0.72);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.9);
		border-radius: 14px;
		padding: 0.9rem 1.25rem;
		box-shadow: 0 4px 20px rgba(59, 130, 246, 0.08);
		flex-shrink: 0;
	}

	.title-section { flex: 1; }

	.title {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 0.2rem 0;
	}

	.subtitle {
		color: #64748b;
		font-size: 0.82rem;
		margin: 0;
	}

	.header-actions {
		display: flex;
		gap: 0.6rem;
	}

	.btn-primary, .btn-secondary {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 0.45rem 0.9rem;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 0.82rem;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.btn-primary {
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.25);
	}
	.btn-primary:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.38);
	}

	.btn-secondary {
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.22);
	}
	.btn-secondary:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
	}

	/* ===================== CONTENT CARD ===================== */
	.content {
		flex: 1;
		background: rgba(255, 255, 255, 0.75);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.9);
		border-radius: 14px;
		padding: 1.25rem;
		display: flex;
		flex-direction: column;
		box-shadow: 0 4px 20px rgba(59, 130, 246, 0.07);
		min-height: 0;
	}

	/* ===================== TABS ===================== */
	.tabs {
		display: flex;
		gap: 6px;
		margin-bottom: 1rem;
		border-bottom: 1.5px solid #e2e8f0;
	}

	.tab {
		padding: 0.5rem 1.1rem;
		background: none;
		border: none;
		border-bottom: 2.5px solid transparent;
		cursor: pointer;
		font-weight: 600;
		font-size: 0.84rem;
		color: #64748b;
		transition: all 0.2s;
		margin-bottom: -1.5px;
		border-radius: 6px 6px 0 0;
	}
	.tab:hover { color: #3b82f6; background: rgba(59, 130, 246, 0.05); }
	.tab.active {
		color: #2563eb;
		border-bottom-color: #3b82f6;
		background: rgba(59, 130, 246, 0.06);
	}

	/* ===================== FILTERS ===================== */
	.filter-section {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.search-box { flex: 1; }

	.search-input {
		width: 100%;
		padding: 0.48rem 0.875rem;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.84rem;
		background: rgba(255, 255, 255, 0.8);
		color: #1e293b;
		transition: all 0.2s;
	}
	.search-input::placeholder { color: #b0bec5; }
	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		background: white;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.filter-box { min-width: 260px; }

	.filter-select {
		width: 100%;
		padding: 0.48rem 0.875rem;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.84rem;
		background: rgba(255, 255, 255, 0.8);
		color: #1e293b;
		cursor: pointer;
		transition: all 0.2s;
	}
	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	/* ===================== TABLE ===================== */
	.table-container {
		flex: 1;
		overflow-x: auto;
		border-radius: 10px;
		border: 1px solid #e2e8f0;
	}

	.categories-table {
		width: 100%;
		border-collapse: collapse;
	}

	.categories-table thead {
		position: sticky;
		top: 0;
		z-index: 5;
	}

	.categories-table th {
		padding: 0.65rem 1rem;
		text-align: left;
		font-weight: 600;
		font-size: 0.72rem;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		background: rgba(241, 245, 249, 0.95);
		border-bottom: 1px solid #e2e8f0;
		border-right: 1px solid #f1f5f9;
		white-space: nowrap;
		backdrop-filter: blur(10px);
	}
	.categories-table th:last-child { border-right: none; }

	.categories-table tbody tr {
		border-bottom: 1px solid #f1f5f9;
		transition: background 0.15s;
	}
	.categories-table tbody tr:hover { background: rgba(59, 130, 246, 0.03); }
	.categories-table tbody tr:last-child { border-bottom: none; }

	.categories-table td {
		padding: 0.6rem 1rem;
		font-size: 0.84rem;
		color: #374151;
		border-right: 1px solid #f8fafc;
	}
	.categories-table td:last-child { border-right: none; }

	.name-cell { font-weight: 500; color: #1e293b; }

	.count-cell {
		text-align: center;
		font-weight: 700;
		color: #2563eb;
	}

	.date-cell { color: #64748b; font-size: 0.78rem; }

	.parent-cell { max-width: 200px; }

	.parent-badge {
		display: inline-block;
		padding: 0.18rem 0.65rem;
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid #bfdbfe;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.actions-cell {
		display: flex;
		gap: 6px;
		justify-content: flex-end;
	}

	.btn-edit, .btn-delete {
		padding: 0.3rem 0.6rem;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		transition: all 0.2s;
	}
	.btn-edit { background: #fef9c3; color: #92400e; border: 1px solid #fde68a; }
	.btn-edit:hover { background: #fde68a; transform: scale(1.08); }
	.btn-delete { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }
	.btn-delete:hover { background: #fecaca; transform: scale(1.08); }

	/* ===================== STATES ===================== */
	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		gap: 0.75rem;
		color: #64748b;
		font-size: 0.88rem;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	.error {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 10px;
		padding: 2.5rem;
		color: #dc2626;
		font-weight: 500;
		font-size: 0.88rem;
	}
	.error-icon { font-size: 1.5rem; }

	.no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		color: #94a3b8;
		gap: 0.6rem;
		font-size: 0.88rem;
	}
	.no-data-icon { font-size: 2.5rem; }

	/* ===================== MODAL ===================== */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(15, 23, 42, 0.35);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal {
		background: rgba(255, 255, 255, 0.97);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.9);
		border-radius: 16px;
		width: 90%;
		max-width: 480px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.12);
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.25rem;
		border-bottom: 1px solid #f1f5f9;
		background: rgba(248, 250, 252, 0.8);
	}

	.modal-header h3 {
		font-size: 1rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
	}

	.close-btn {
		width: 28px;
		height: 28px;
		border: none;
		background: #f1f5f9;
		border-radius: 7px;
		cursor: pointer;
		font-size: 1rem;
		color: #64748b;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
		line-height: 1;
	}
	.close-btn:hover { background: #fee2e2; color: #dc2626; }

	.modal-content {
		padding: 1.25rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.form-group label {
		font-weight: 600;
		color: #374151;
		font-size: 0.82rem;
	}

	.form-group input,
	.form-group select {
		padding: 0.48rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.84rem;
		background: rgba(255, 255, 255, 0.9);
		color: #1e293b;
		transition: all 0.2s;
	}
	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
		background: white;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		padding: 0.9rem 1.25rem;
		border-top: 1px solid #f1f5f9;
		background: rgba(248, 250, 252, 0.6);
	}

	.btn-cancel {
		padding: 0.45rem 1rem;
		border: 1px solid #e2e8f0;
		background: white;
		color: #374151;
		border-radius: 7px;
		cursor: pointer;
		font-weight: 500;
		font-size: 0.84rem;
		transition: all 0.2s;
	}
	.btn-cancel:hover { background: #f8fafc; border-color: #94a3b8; }

	.btn-save {
		padding: 0.45rem 1rem;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		border: none;
		border-radius: 7px;
		cursor: pointer;
		font-weight: 600;
		font-size: 0.84rem;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.22);
	}
	.btn-save:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(59, 130, 246, 0.35); }
</style>
