<script lang="ts">
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CategoryFormWindow from './CategoryFormWindow.svelte';
	import CategoryEditWindow from './CategoryEditWindow.svelte';

	let categories: Array<{
		id: string;
		name_en: string;
		name_ar: string;
		image_url: string | null;
		display_order: number;
		is_active: boolean;
		created_at: string;
	}> = [];
	let loading = false;
	let uploadingId: string | null = null;

	onMount(() => {
		loadCategories();
		
		// Listen for new categories
		window.addEventListener('category-created', handleCategoryCreated);
		window.addEventListener('category-updated', handleCategoryUpdated);
		
		return () => {
			window.removeEventListener('category-created', handleCategoryCreated);
			window.removeEventListener('category-updated', handleCategoryUpdated);
		};
	});

	async function loadCategories() {
		loading = true;
		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			const { data, error } = await supabaseAdmin
				.from('product_categories')
				.select('*')
				.order('display_order');

			if (error) throw error;
			
			categories = data || [];
		} catch (error) {
			console.error('Error loading categories:', error);
			alert('Failed to load categories');
		} finally {
			loading = false;
		}
	}

	function handleCategoryCreated(event: any) {
		loadCategories();
	}

	function handleCategoryUpdated(event: any) {
		loadCategories();
	}

	function openCreateCategory() {
		const windowId = `create-category-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Category #${instanceNumber}`,
			component: CategoryFormWindow,
			icon: '🏷️',
			size: { width: 600, height: 500 },
			position: { 
				x: 150 + (Math.random() * 50),
				y: 150 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openEditCategory(category: any) {
		const windowId = `edit-category-${category.id}-${Date.now()}`;
		
		openWindow({
			id: windowId,
			title: `Edit Category: ${category.name_en}`,
			component: CategoryEditWindow,
			props: { category },
			icon: '✏️',
			size: { width: 600, height: 550 },
			position: { 
				x: 170 + (Math.random() * 50),
				y: 170 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function handleImageUpload(categoryId: string, event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;

		// Validate file
		const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
		if (!validTypes.includes(file.type)) {
			alert('Please select a valid image file (JPEG, PNG, WebP, or GIF)');
			return;
		}
		
		if (file.size > 5 * 1024 * 1024) {
			alert('Image size must be less than 5MB');
			return;
		}

		uploadingId = categoryId;

		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			// Upload image
			const fileExt = file.name.split('.').pop();
			const fileName = `${categoryId}-${Date.now()}.${fileExt}`;
			
			const { error: uploadError } = await supabaseAdmin.storage
				.from('category-images')
				.upload(fileName, file, {
					cacheControl: '3600',
					upsert: true
				});

			if (uploadError) throw uploadError;

			// Get public URL
			const { data } = supabaseAdmin.storage
				.from('category-images')
				.getPublicUrl(fileName);

			// Update category
			const { error: updateError } = await supabaseAdmin
				.from('product_categories')
				.update({ image_url: data.publicUrl })
				.eq('id', categoryId);

			if (updateError) throw updateError;

			// Reload categories
			await loadCategories();
		} catch (error) {
			console.error('Upload error:', error);
			alert('Failed to upload image');
		} finally {
			uploadingId = null;
			// Reset file input
			target.value = '';
		}
	}

	async function toggleActive(categoryId: string, currentStatus: boolean) {
		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			const { error } = await supabaseAdmin
				.from('product_categories')
				.update({ is_active: !currentStatus })
				.eq('id', categoryId);

			if (error) throw error;

			await loadCategories();
		} catch (error) {
			console.error('Toggle error:', error);
			alert('Failed to update category status');
		}
	}

	async function deleteCategory(categoryId: string, categoryName: string) {
		if (!confirm(`Are you sure you want to delete "${categoryName}"?`)) {
			return;
		}

		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			const { error } = await supabaseAdmin
				.from('product_categories')
				.delete()
				.eq('id', categoryId);

			if (error) throw error;

			await loadCategories();
		} catch (error) {
			console.error('Delete error:', error);
			alert('Failed to delete category');
		}
	}
</script>

<div class="categories-manager">
	<div class="header">
		<h2>🏷️ Manage Categories</h2>
		<button class="create-btn" on:click={openCreateCategory}>
			<span class="btn-icon">➕</span>
			Create Category
		</button>
	</div>

	{#if loading}
		<div class="loading">
			<div class="spinner">⏳</div>
			Loading categories...
		</div>
	{:else if categories.length === 0}
		<div class="empty-state">
			<div class="empty-icon">📦</div>
			<p>No categories found</p>
			<button class="create-btn" on:click={openCreateCategory}>
				Create First Category
			</button>
		</div>
	{:else}
		<div class="table-container">
			<table class="categories-table">
				<thead>
					<tr>
						<th>Image</th>
						<th>English Name</th>
						<th>Arabic Name</th>
						<th>Order</th>
						<th>Status</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each categories as category}
						<tr>
							<td>
								<div class="image-cell">
									{#if category.image_url}
										<img src={category.image_url} alt={category.name_en} class="category-thumbnail" />
									{:else}
										<div class="no-image">📷</div>
									{/if}
									<label class="upload-btn" class:uploading={uploadingId === category.id}>
										{#if uploadingId === category.id}
											<span class="spinner-small">⏳</span>
										{:else}
											📤
										{/if}
										<input
											type="file"
											accept="image/jpeg,image/jpg,image/png,image/webp,image/gif"
											on:change={(e) => handleImageUpload(category.id, e)}
											disabled={uploadingId === category.id}
										/>
									</label>
								</div>
							</td>
							<td class="name-cell">{category.name_en}</td>
							<td class="name-cell" dir="rtl">{category.name_ar}</td>
							<td class="order-cell">{category.display_order}</td>
							<td>
								<button
									class="status-badge"
									class:active={category.is_active}
									class:inactive={!category.is_active}
									on:click={() => toggleActive(category.id, category.is_active)}
								>
									{category.is_active ? '✓ Active' : '✕ Inactive'}
								</button>
							</td>
							<td>
								<div class="action-buttons">
									<button
										class="edit-btn"
										on:click={() => openEditCategory(category)}
										title="Edit category"
									>
										✏️
									</button>
									<button
										class="delete-btn"
										on:click={() => deleteCategory(category.id, category.name_en)}
										title="Delete category"
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

<style>
	.categories-manager {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		background: white;
		border-bottom: 2px solid #e2e8f0;
	}

	.header h2 {
		margin: 0;
		color: #1e293b;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.create-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.create-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.btn-icon {
		font-size: 1.2rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem;
		color: #64748b;
	}

	.spinner {
		font-size: 2rem;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem;
		color: #64748b;
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		padding: 1.5rem;
	}

	.categories-table {
		width: 100%;
		background: white;
		border-radius: 0.5rem;
		border-collapse: collapse;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
	}

	.categories-table thead {
		background: #f8fafc;
		border-bottom: 2px solid #e2e8f0;
	}

	.categories-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #1e293b;
		font-size: 0.9rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.categories-table td {
		padding: 1rem;
		border-bottom: 1px solid #e2e8f0;
	}

	.categories-table tbody tr:hover {
		background: #f8fafc;
	}

	.image-cell {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.category-thumbnail {
		width: 60px;
		height: 60px;
		object-fit: cover;
		border-radius: 0.5rem;
		border: 2px solid #e2e8f0;
	}

	.no-image {
		width: 60px;
		height: 60px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f1f5f9;
		border: 2px dashed #cbd5e1;
		border-radius: 0.5rem;
		font-size: 1.5rem;
		color: #94a3b8;
	}

	.upload-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		background: #10b981;
		color: white;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 1.2rem;
	}

	.upload-btn:hover:not(.uploading) {
		background: #059669;
		transform: translateY(-1px);
	}

	.upload-btn.uploading {
		background: #94a3b8;
		cursor: not-allowed;
	}

	.upload-btn input[type="file"] {
		display: none;
	}

	.spinner-small {
		animation: spin 1s linear infinite;
	}

	.name-cell {
		font-weight: 500;
		color: #1e293b;
	}

	.order-cell {
		text-align: center;
		font-weight: 600;
		color: #64748b;
	}

	.status-badge {
		padding: 0.375rem 0.75rem;
		border: none;
		border-radius: 1rem;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.status-badge.active {
		background: #dcfce7;
		color: #16a34a;
	}

	.status-badge.active:hover {
		background: #bbf7d0;
	}

	.status-badge.inactive {
		background: #fee2e2;
		color: #dc2626;
	}

	.status-badge.inactive:hover {
		background: #fecaca;
	}

	.action-buttons {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		justify-content: center;
	}

	.edit-btn {
		width: 36px;
		height: 36px;
		background: #dbeafe;
		color: #1e40af;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 1.2rem;
	}

	.edit-btn:hover {
		background: #bfdbfe;
		transform: scale(1.1);
	}

	.delete-btn {
		width: 36px;
		height: 36px;
		background: #fee2e2;
		color: #dc2626;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 1.2rem;
	}

	.delete-btn:hover {
		background: #fecaca;
		transform: scale(1.1);
	}
</style>
