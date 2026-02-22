<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	export let bundles: any[] = [];
	export let offerId: number | null = null;
	export let editMode = false;

	const dispatch = createEventDispatcher();

	let products: any[] = [];
	let showPricingModal = false;
	let selectedBundleIndex: number | null = null;
	let loading = false;
	let error: string | null = null;

	$: isRTL = $currentLocale === 'ar';

	onMount(async () => {
		await loadProducts();
		if (bundles.length === 0) {
			addNewBundle();
		}
	});

	async function loadProducts() {
		const { data, error: err } = await supabase
			.from('products')
			.select('id, product_name_ar, product_name_en, barcode, unit_id, sale_price, image_url')
			.eq('is_active', true)
			.order('product_name_en');

		if (!err && data) {
			products = data.map(p => ({
				id: p.id,
				name_ar: p.product_name_ar || p.name_ar,
				name_en: p.product_name_en || p.name_en,
				barcode: p.barcode,
				unit_id: p.unit_id,
				price: parseFloat(p.sale_price) || parseFloat(p.price) || 0,
				image_url: p.image_url
			}));
		}
	}

	function addNewBundle() {
		bundles = [...bundles, {
			id: null,
			bundle_name_ar: '',
			bundle_name_en: '',
			discount_type: 'amount',
			discount_value: 0,
			required_products: []
		}];
		dispatch('change', bundles);
	}

	function removeBundle(index: number) {
		if (confirm(isRTL ? 'هل تريد حذف هذه الحزمة؟' : 'Do you want to delete this bundle?')) {
			bundles = bundles.filter((_, i) => i !== index);
			dispatch('change', bundles);
		}
	}

	function addProductToBundle(bundleIndex: number) {
		bundles[bundleIndex].required_products = [
			...bundles[bundleIndex].required_products,
			{
				product_id: null,
				quantity: 1,
				unit_id: null
			}
		];
		bundles = [...bundles];
		dispatch('change', bundles);
	}

	function removeProductFromBundle(bundleIndex: number, productIndex: number) {
		bundles[bundleIndex].required_products = bundles[bundleIndex].required_products.filter(
			(_, i) => i !== productIndex
		);
		bundles = [...bundles];
		dispatch('change', bundles);
	}

	function openPricingModal(index: number) {
		selectedBundleIndex = index;
		showPricingModal = true;
	}

	function closePricingModal() {
		showPricingModal = false;
		selectedBundleIndex = null;
	}

	function savePricing() {
		showPricingModal = false;
		selectedBundleIndex = null;
		dispatch('change', bundles);
	}

	async function validateProductUniqueness(productId: string, bundleIndex: number): Promise<boolean> {
		// Check if product is already in another bundle in the current offer
		for (let i = 0; i < bundles.length; i++) {
			if (i !== bundleIndex) {
				const found = bundles[i].required_products.some(p => p.product_id === productId);
				if (found) {
					return false;
				}
			}
		}

		// Check if product is in any other active bundle offers (globally)
		const { data: activeBundles } = await supabase
			.from('offer_bundles')
			.select(`
				id,
				required_products,
				offers!inner(id, is_active, end_date)
			`)
			.eq('offers.is_active', true)
			.gte('offers.end_date', new Date().toISOString())
			.neq('offers.id', offerId || 0);

		if (activeBundles) {
			for (const bundle of activeBundles) {
				if (bundle.required_products && Array.isArray(bundle.required_products)) {
					const found = bundle.required_products.some((p: any) => p.product_id === productId);
					if (found) {
						return false;
					}
				}
			}
		}

		return true;
	}

	async function handleProductChange(bundleIndex: number, productIndex: number, productId: string) {
		if (!productId) return;

		const isUnique = await validateProductUniqueness(productId, bundleIndex);
		
		if (!isUnique) {
			alert(isRTL 
				? 'هذا المنتج موجود بالفعل في حزمة نشطة أخرى. لا يمكن إضافة نفس المنتج في أكثر من حزمة.'
				: 'This product is already in another active bundle. A product cannot be in multiple bundles.'
			);
			bundles[bundleIndex].required_products[productIndex].product_id = null;
			bundles = [...bundles];
			return;
		}

		const product = products.find(p => p.id === productId);
		if (product) {
			bundles[bundleIndex].required_products[productIndex].unit_id = product.unit_id;
		}
		bundles = [...bundles];
		dispatch('change', bundles);
	}

	function getProductName(productId: string): string {
		const product = products.find(p => p.id === productId);
		return product ? (isRTL ? product.name_ar : product.name_en) : '';
	}

	function validateBundle(bundle: any): boolean {
		if (!bundle.bundle_name_ar || !bundle.bundle_name_en) {
			error = isRTL ? 'يرجى إدخال اسم الحزمة بالعربية والإنجليزية' : 'Please enter bundle name in both languages';
			return false;
		}

		if (bundle.required_products.length < 2) {
			error = isRTL ? 'يجب أن تحتوي الحزمة على منتجين على الأقل' : 'Bundle must contain at least 2 products';
			return false;
		}

		for (const product of bundle.required_products) {
			if (!product.product_id) {
				error = isRTL ? 'يرجى اختيار جميع المنتجات' : 'Please select all products';
				return false;
			}
			if (!product.quantity || product.quantity < 1) {
				error = isRTL ? 'يجب أن تكون الكمية أكبر من صفر' : 'Quantity must be greater than zero';
				return false;
			}
		}

		if (!bundle.discount_value || bundle.discount_value <= 0) {
			error = isRTL ? 'يرجى تحديد سعر أو خصم للحزمة' : 'Please set pricing for the bundle';
			return false;
		}

		return true;
	}

	export function validateAll(): boolean {
		error = null;
		
		if (bundles.length === 0) {
			error = isRTL ? 'يجب إضافة حزمة واحدة على الأقل' : 'At least one bundle is required';
			return false;
		}

		for (const bundle of bundles) {
			if (!validateBundle(bundle)) {
				return false;
			}
		}

		return true;
	}
</script>

<div class="bundle-creator" class:rtl={isRTL}>
	<div class="header">
		<h3>{isRTL ? 'إدارة الحزم' : 'Manage Bundles'}</h3>
		<button type="button" class="btn-add-bundle" on:click={addNewBundle}>
			+ {isRTL ? 'إضافة حزمة' : 'Add Bundle'}
		</button>
	</div>

	{#if error}
		<div class="error-message">⚠️ {error}</div>
	{/if}

	<div class="bundles-list">
		{#each bundles as bundle, bundleIndex}
			<div class="bundle-card">
				<div class="bundle-header">
					<span class="bundle-number">
						{isRTL ? 'الحزمة' : 'Bundle'} {bundleIndex + 1}
					</span>
					<button
						type="button"
						class="btn-remove"
						on:click={() => removeBundle(bundleIndex)}
						title={isRTL ? 'حذف الحزمة' : 'Remove bundle'}
					>
						🗑️
					</button>
				</div>

				<!-- Bundle Names -->
				<div class="form-row">
					<div class="form-group">
						<label>{isRTL ? 'اسم الحزمة (عربي)' : 'Bundle Name (Arabic)'}</label>
						<input
							type="text"
							bind:value={bundle.bundle_name_ar}
							placeholder={isRTL ? 'أدخل اسم الحزمة بالعربية' : 'Enter bundle name in Arabic'}
							required
						/>
					</div>
					<div class="form-group">
						<label>{isRTL ? 'اسم الحزمة (إنجليزي)' : 'Bundle Name (English)'}</label>
						<input
							type="text"
							bind:value={bundle.bundle_name_en}
							placeholder={isRTL ? 'أدخل اسم الحزمة بالإنجليزية' : 'Enter bundle name in English'}
							required
						/>
					</div>
				</div>

				<!-- Products -->
				<div class="products-section">
					<div class="products-header">
						<h4>{isRTL ? 'المنتجات في الحزمة' : 'Products in Bundle'}</h4>
						<button
							type="button"
							class="btn-add-product"
							on:click={() => addProductToBundle(bundleIndex)}
						>
							+ {isRTL ? 'إضافة منتج' : 'Add Product'}
						</button>
					</div>

					{#if bundle.required_products.length === 0}
						<div class="empty-products">
							<p>{isRTL ? 'لم يتم إضافة أي منتجات بعد' : 'No products added yet'}</p>
						</div>
					{:else}
						<div class="products-list">
							{#each bundle.required_products as product, productIndex}
								<div class="product-item">
									<div class="product-select">
										<label>{isRTL ? 'المنتج' : 'Product'}</label>
										<select
											bind:value={product.product_id}
											on:change={(e) => handleProductChange(bundleIndex, productIndex, e.target.value)}
											required
										>
											<option value={null}>{isRTL ? 'اختر منتج' : 'Select product'}</option>
											{#each products as p}
												<option value={p.id}>
													{isRTL ? p.name_ar : p.name_en}
													{#if p.barcode} - {p.barcode}{/if}
												</option>
											{/each}
										</select>
									</div>

									<div class="product-quantity">
										<label>{isRTL ? 'الكمية' : 'Quantity'}</label>
										<input
											type="number"
											min="1"
											bind:value={product.quantity}
											required
										/>
									</div>

									<button
										type="button"
										class="btn-remove-product"
										on:click={() => removeProductFromBundle(bundleIndex, productIndex)}
										title={isRTL ? 'حذف المنتج' : 'Remove product'}
									>
										❌
									</button>
								</div>
							{/each}
						</div>
					{/if}
				</div>

				<!-- Pricing Button -->
				<div class="pricing-section">
					<button
						type="button"
						class="btn-pricing"
						on:click={() => openPricingModal(bundleIndex)}
						disabled={bundle.required_products.length < 2}
					>
						💰 {isRTL ? 'تحديد السعر' : 'Set Pricing'}
						{#if bundle.discount_value > 0}
							<span class="pricing-preview">
								({bundle.discount_type === 'percentage' 
									? `${bundle.discount_value}% ${isRTL ? 'خصم' : 'OFF'}` 
									: `${bundle.discount_value} ${isRTL ? 'ريال' : 'SAR'}`})
							</span>
						{/if}
					</button>
				</div>
			</div>
		{/each}
	</div>
</div>

<!-- Pricing Modal -->
{#if showPricingModal && selectedBundleIndex !== null}
	<div class="modal-overlay" on:click={closePricingModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{isRTL ? 'تحديد السعر للحزمة' : 'Set Bundle Pricing'}</h3>
				<button class="modal-close" on:click={closePricingModal}>✕</button>
			</div>

			<div class="modal-body">
				<div class="pricing-type">
					<label>
						<input
							type="radio"
							value="percentage"
							bind:group={bundles[selectedBundleIndex].discount_type}
						/>
						<span>{isRTL ? 'نسبة خصم (%)' : 'Percentage Discount (%)'}</span>
					</label>
					<label>
						<input
							type="radio"
							value="amount"
							bind:group={bundles[selectedBundleIndex].discount_type}
						/>
						<span>{isRTL ? 'سعر الحزمة (ريال)' : 'Bundle Price (SAR)'}</span>
					</label>
				</div>

				<div class="pricing-value">
					<label>
						{bundles[selectedBundleIndex].discount_type === 'percentage'
							? isRTL ? 'نسبة الخصم (%)' : 'Discount Percentage (%)'
							: isRTL ? 'سعر الحزمة (ريال)' : 'Bundle Price (SAR)'}
					</label>
					<input
						type="number"
						min="0"
						step="0.01"
						max={bundles[selectedBundleIndex].discount_type === 'percentage' ? 100 : undefined}
						bind:value={bundles[selectedBundleIndex].discount_value}
						placeholder="0.00"
					/>
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" on:click={closePricingModal}>
					{isRTL ? 'إلغاء' : 'Cancel'}
				</button>
				<button class="btn-save" on:click={savePricing}>
					{isRTL ? 'حفظ' : 'Save'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.bundle-creator {
		width: 100%;
		padding: 1rem;
	}

	.bundle-creator.rtl {
		direction: rtl;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
	}

	.header h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1f2937;
	}

	.btn-add-bundle {
		padding: 0.625rem 1.25rem;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-add-bundle:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-1px);
	}

	.error-message {
		padding: 0.75rem 1rem;
		background: #fee2e2;
		border: 1px solid #fecaca;
		border-radius: 6px;
		color: #dc2626;
		margin-bottom: 1rem;
		font-size: 0.875rem;
	}

	.bundles-list {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.bundle-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
	}

	.bundle-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid #f3f4f6;
	}

	.bundle-number {
		font-size: 1.1rem;
		font-weight: 600;
		color: #3b82f6;
	}

	.btn-remove {
		background: transparent;
		border: 1px solid #ef4444;
		border-radius: 6px;
		padding: 0.375rem 0.75rem;
		cursor: pointer;
		font-size: 1.1rem;
		transition: all 0.2s;
	}

	.btn-remove:hover {
		background: #ef4444;
		transform: scale(1.1);
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.375rem;
	}

	.form-group label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.form-group input,
	.form-group select {
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.95rem;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.products-section {
		margin: 1.5rem 0;
		padding: 1rem;
		background: #f9fafb;
		border-radius: 8px;
	}

	.products-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.products-header h4 {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1f2937;
	}

	.btn-add-product {
		padding: 0.5rem 1rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.813rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-add-product:hover {
		background: #059669;
	}

	.empty-products {
		text-align: center;
		padding: 2rem;
		color: #6b7280;
		font-style: italic;
	}

	.products-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.product-item {
		display: grid;
		grid-template-columns: 1fr 120px auto;
		gap: 0.75rem;
		align-items: end;
		padding: 0.75rem;
		background: white;
		border-radius: 6px;
		border: 1px solid #e5e7eb;
	}

	.product-select,
	.product-quantity {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.product-select label,
	.product-quantity label {
		font-size: 0.813rem;
		font-weight: 500;
		color: #6b7280;
	}

	.btn-remove-product {
		background: transparent;
		border: none;
		cursor: pointer;
		font-size: 1.2rem;
		padding: 0.5rem;
		transition: transform 0.2s;
	}

	.btn-remove-product:hover {
		transform: scale(1.2);
	}

	.pricing-section {
		margin-top: 1rem;
		padding-top: 1rem;
		border-top: 1px solid #e5e7eb;
	}

	.btn-pricing {
		width: 100%;
		padding: 0.75rem 1.5rem;
		background: linear-gradient(135deg, #eab308 0%, #ca8a04 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.btn-pricing:hover:not(:disabled) {
		background: linear-gradient(135deg, #ca8a04 0%, #a16207 100%);
		transform: translateY(-1px);
	}

	.btn-pricing:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.pricing-preview {
		font-size: 0.875rem;
		opacity: 0.9;
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
		z-index: 2000;
	}

	.modal-content {
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
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.modal-close {
		background: transparent;
		border: none;
		font-size: 1.5rem;
		color: #6b7280;
		cursor: pointer;
		padding: 0.25rem;
	}

	.modal-close:hover {
		color: #1f2937;
	}

	.modal-body {
		padding: 1.5rem;
	}

	.pricing-type {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.pricing-type label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.pricing-type label:hover {
		border-color: #3b82f6;
		background: #eff6ff;
	}

	.pricing-type input[type="radio"] {
		width: 18px;
		height: 18px;
	}

	.pricing-value {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.pricing-value label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.pricing-value input {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 1rem;
	}

	.pricing-value input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.modal-footer {
		display: flex;
		gap: 0.75rem;
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.modal-footer button {
		flex: 1;
		padding: 0.75rem;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-cancel {
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		color: #374151;
	}

	.btn-cancel:hover {
		background: #e5e7eb;
	}

	.btn-save {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		border: none;
		color: white;
	}

	.btn-save:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}

		.product-item {
			grid-template-columns: 1fr;
		}
	}
</style>
