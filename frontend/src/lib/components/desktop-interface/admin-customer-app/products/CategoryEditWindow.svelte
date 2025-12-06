<script lang="ts">
	import { translateText } from '$lib/utils/translationService';
	import { createEventDispatcher } from 'svelte';

	export let category: {
		id: string;
		name_en: string;
		name_ar: string;
		image_url: string | null;
		display_order: number;
		is_active: boolean;
	};

	const dispatch = createEventDispatcher();

	let categoryNameEn = category.name_en;
	let categoryNameAr = category.name_ar;
	let displayOrder = category.display_order;
	let categoryImage: File | null = null;
	let categoryImagePreview = category.image_url || '';
	let isTranslating = false;
	let isSaving = false;
	let translationError = '';
	let uploadError = '';
	let useAutoTranslate = true;

	async function handleEnglishInput() {
		if (!useAutoTranslate || !categoryNameEn.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			categoryNameAr = await translateText({
				text: categoryNameEn,
				targetLanguage: 'ar',
				sourceLanguage: 'en'
			});
		} catch (error: any) {
			translationError = error.message || 'Translation failed';
			console.error('Translation error:', error);
		} finally {
			isTranslating = false;
		}
	}

	async function handleArabicInput() {
		if (!useAutoTranslate || !categoryNameAr.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			categoryNameEn = await translateText({
				text: categoryNameAr,
				targetLanguage: 'en',
				sourceLanguage: 'ar'
			});
		} catch (error: any) {
			translationError = error.message || 'Translation failed';
			console.error('Translation error:', error);
		} finally {
			isTranslating = false;
		}
	}

	function handleImageSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			// Validate file type
			const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
			if (!validTypes.includes(file.type)) {
				uploadError = 'Please select a valid image file (JPEG, PNG, WebP, or GIF)';
				return;
			}
			
			// Validate file size (5MB)
			if (file.size > 5 * 1024 * 1024) {
				uploadError = 'Image size must be less than 5MB';
				return;
			}
			
			categoryImage = file;
			uploadError = '';
			
			// Create preview
			const reader = new FileReader();
			reader.onload = (e) => {
				categoryImagePreview = e.target?.result as string;
			};
			reader.readAsDataURL(file);
		}
	}

	function removeImage() {
		categoryImage = null;
		categoryImagePreview = '';
		uploadError = '';
		// Reset file input
		const fileInput = document.getElementById('category-image-edit') as HTMLInputElement;
		if (fileInput) fileInput.value = '';
	}

	async function uploadImage(): Promise<string | null> {
		if (!categoryImage) return null;

		try {
			const { supabase } = await import('$lib/utils/supabase');
			const fileExt = categoryImage.name.split('.').pop();
			const fileName = `${category.id}-${Date.now()}.${fileExt}`;
			const filePath = fileName;

			const { error: uploadError } = await supabase.storage
				.from('category-images')
				.upload(filePath, categoryImage, {
					cacheControl: '3600',
					upsert: true
				});

			if (uploadError) throw uploadError;

			// Get public URL
			const { data } = supabase.storage
				.from('category-images')
				.getPublicUrl(filePath);

			return data.publicUrl;
		} catch (error) {
			console.error('Image upload error:', error);
			throw error;
		}
	}

	async function handleSave() {
		if (!categoryNameEn.trim() || !categoryNameAr.trim()) {
			alert('Please fill in both English and Arabic names');
			return;
		}

		isSaving = true;
		uploadError = '';

		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			// Upload new image if provided
			let imageUrl = categoryImagePreview;
			if (categoryImage) {
				const newImageUrl = await uploadImage();
				if (newImageUrl) {
					imageUrl = newImageUrl;
				}
			}

			// Update category
			const { error: updateError } = await supabase
				.from('product_categories')
				.update({
					name_en: categoryNameEn,
					name_ar: categoryNameAr,
					image_url: imageUrl,
					display_order: displayOrder
				})
				.eq('id', category.id);

			if (updateError) throw updateError;

			// Dispatch event to parent component
			window.dispatchEvent(new CustomEvent('category-updated', {
				detail: {
					id: category.id,
					name_en: categoryNameEn,
					name_ar: categoryNameAr,
					image_url: imageUrl,
					display_order: displayOrder
				}
			}));

			alert('Category updated successfully!');
		} catch (error: any) {
			uploadError = error.message || 'Failed to update category';
			console.error('Update error:', error);
		} finally {
			isSaving = false;
		}
	}
</script>

<div class="category-edit-container">
	<div class="form-header">
		<h3>Edit Category</h3>
		<label class="toggle-container">
			<input type="checkbox" bind:checked={useAutoTranslate} />
			<span class="toggle-label">Auto-translate</span>
		</label>
	</div>

	<div class="form-content">
		<div class="form-group">
			<label for="category-name-en-edit">Category Name (English)</label>
			<input
				id="category-name-en-edit"
				type="text"
				bind:value={categoryNameEn}
				on:blur={handleEnglishInput}
				placeholder="Enter category name in English"
				disabled={isTranslating}
			/>
		</div>

		<div class="form-group">
			<label for="category-name-ar-edit">Category Name (Arabic)</label>
			<input
				id="category-name-ar-edit"
				type="text"
				bind:value={categoryNameAr}
				on:blur={handleArabicInput}
				placeholder="أدخل اسم الفئة بالعربية"
				disabled={isTranslating}
				dir="rtl"
			/>
		</div>

		<div class="form-group">
			<label for="display-order-edit">Display Order</label>
			<input
				id="display-order-edit"
				type="number"
				bind:value={displayOrder}
				min="0"
				placeholder="Display order"
			/>
		</div>

		<div class="form-group">
			<label for="category-image-edit">Category Image</label>
			<input
				id="category-image-edit"
				type="file"
				accept="image/jpeg,image/jpg,image/png,image/webp,image/gif"
				on:change={handleImageSelect}
				disabled={isSaving}
			/>
			<p class="helper-text">Max 5MB. Supported: JPEG, PNG, WebP, GIF</p>
		</div>

		{#if categoryImagePreview}
			<div class="image-preview-container">
				<div class="image-preview">
					<img src={categoryImagePreview} alt="Category preview" />
					<button class="remove-image-btn" on:click={removeImage} type="button">
						✕
					</button>
				</div>
			</div>
		{/if}

		{#if isTranslating}
			<div class="translation-status">
				<span class="spinner">⏳</span>
				Translating...
			</div>
		{/if}

		{#if translationError}
			<div class="error-message">
				⚠️ {translationError}
			</div>
		{/if}

		{#if uploadError}
			<div class="error-message">
				⚠️ {uploadError}
			</div>
		{/if}
	</div>

	<div class="form-footer">
		<button class="save-btn" on:click={handleSave} disabled={isTranslating || isSaving}>
			{isSaving ? 'Updating...' : 'Update Category'}
		</button>
	</div>
</div>

<style>
	.category-edit-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.form-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 2px solid #e2e8f0;
	}

	.form-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.toggle-container {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
	}

	.toggle-container input[type="checkbox"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
	}

	.toggle-label {
		color: #64748b;
		font-size: 0.95rem;
	}

	.form-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		color: #1e293b;
		font-weight: 500;
		font-size: 0.95rem;
	}

	.form-group input {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 0.5rem;
		font-size: 1rem;
		transition: border-color 0.2s ease;
	}

	.form-group input[type="number"] {
		max-width: 200px;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.form-group input:disabled {
		background: #f1f5f9;
		cursor: not-allowed;
	}

	.form-group input[type="file"] {
		padding: 0.5rem;
		border: 2px dashed #e2e8f0;
		cursor: pointer;
	}

	.form-group input[type="file"]:hover {
		border-color: #3b82f6;
		background: #f8fafc;
	}

	.helper-text {
		margin: 0.5rem 0 0 0;
		font-size: 0.85rem;
		color: #64748b;
	}

	.image-preview-container {
		margin-bottom: 1.5rem;
	}

	.image-preview {
		position: relative;
		width: 200px;
		height: 200px;
		border-radius: 0.5rem;
		overflow: hidden;
		border: 2px solid #e2e8f0;
	}

	.image-preview img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.remove-image-btn {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		width: 32px;
		height: 32px;
		background: rgba(239, 68, 68, 0.9);
		color: white;
		border: none;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.2rem;
		transition: all 0.2s ease;
	}

	.remove-image-btn:hover {
		background: rgb(220, 38, 38);
		transform: scale(1.1);
	}

	.translation-status {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 0.5rem;
		color: #0369a1;
		font-size: 0.9rem;
	}

	.spinner {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.error-message {
		padding: 0.75rem;
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 0.5rem;
		color: #dc2626;
		font-size: 0.9rem;
	}

	.form-footer {
		padding: 1.5rem;
		border-top: 2px solid #e2e8f0;
	}

	.save-btn {
		width: 100%;
		padding: 0.875rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.save-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.save-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.save-btn:disabled {
		background: #94a3b8;
		cursor: not-allowed;
	}
</style>
