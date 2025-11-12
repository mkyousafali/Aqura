<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { supabase, supabaseAdmin } from '$lib/utils/supabase';

	export let editMode = false;
	export let offerId: number | null = null;

	const dispatch = createEventDispatcher();

	let currentStep = 1;
	let loading = false;
	let error: string | null = null;

	// Form data for Step 1
	let offerData = {
		name_ar: '',
		name_en: '',
		description_ar: '',
		description_en: '',
		start_date: new Date().toISOString().slice(0, 16),
		end_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 16),
		branch_id: null as number | null,
		service_type: 'both' as 'delivery' | 'pickup' | 'both',
		is_active: true
	};

	let branches: any[] = [];
	let bundles: any[] = [];
	let products: any[] = [];
	let showAddBundleForm = false;
	let currentBundle: any = null;
	let productSearchTerm = '';
	let selectedProductsForBundle: any[] = [];
	let calculatedBundlePrice: number | null = null;

	$: isRTL = $currentLocale === 'ar';
	$: filteredProducts = products.filter(p => 
		!productSearchTerm || 
		p.barcode?.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.name_ar.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase())
	);

	onMount(async () => {
		await loadBranches();
		await loadProducts();
		if (editMode && offerId) {
			await loadOfferData();
		}
	});

	async function loadBranches() {
		const { data, error: err } = await supabase
			.from('branches')
			.select('id, name_ar, name_en')
			.eq('is_active', true)
			.order('name_en');

		if (!err && data) {
			branches = data;
		}
	}

	// Convert UTC datetime to Saudi timezone for datetime-local input
	function toSaudiTimeInput(utcDateString) {
		const date = new Date(utcDateString);
		// Convert to Saudi timezone (UTC+3)
		const saudiTime = new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
		// Format for datetime-local input (YYYY-MM-DDTHH:mm)
		const year = saudiTime.getFullYear();
		const month = String(saudiTime.getMonth() + 1).padStart(2, '0');
		const day = String(saudiTime.getDate()).padStart(2, '0');
		const hours = String(saudiTime.getHours()).padStart(2, '0');
		const minutes = String(saudiTime.getMinutes()).padStart(2, '0');
		return `${year}-${month}-${day}T${hours}:${minutes}`;
	}

	async function loadOfferData() {
		if (!offerId) return;

		const { data, error: err } = await supabase
			.from('offers')
			.select('*')
			.eq('id', offerId)
			.single();

		if (!err && data) {
			offerData = {
				name_ar: data.name_ar || '',
				name_en: data.name_en || '',
				description_ar: data.description_ar || '',
				description_en: data.description_en || '',
				start_date: toSaudiTimeInput(data.start_date),
				end_date: toSaudiTimeInput(data.end_date),
				branch_id: data.branch_id,
				service_type: data.service_type || 'both',
				is_active: data.is_active
			};
			
			// Load existing bundles
			await loadBundles();
		}
	}

	async function loadProducts() {
		const { data, error: err } = await supabaseAdmin
			.from('products')
			.select('id, product_name_ar, product_name_en, barcode, sale_price, image_url, current_stock')
			.eq('is_active', true)
			.order('product_name_en');

		if (!err && data) {
			// Get products already in active offers (product, bogo, bundle)
			const { data: offerProducts } = await supabaseAdmin
				.from('offer_products')
				.select(`
					product_id,
					offers!inner(id, is_active, end_date, type)
				`)
				.eq('offers.is_active', true)
				.gte('offers.end_date', new Date().toISOString())
				.neq('offers.id', offerId || 0);

			// Get products in active bundles
			const { data: bundleData } = await supabaseAdmin
				.from('offer_bundles')
				.select(`
					required_products,
					offers!inner(id, is_active, end_date)
				`)
				.eq('offers.is_active', true)
				.gte('offers.end_date', new Date().toISOString())
				.neq('offers.id', offerId || 0);

			const usedProductIds = new Set();
			
			// Add products from offer_products
			offerProducts?.forEach(op => {
				usedProductIds.add(op.product_id);
			});

			// Add products from bundles
			bundleData?.forEach(bundle => {
				if (bundle.required_products && Array.isArray(bundle.required_products)) {
					bundle.required_products.forEach((p: any) => {
						usedProductIds.add(p.product_id);
					});
				}
			});

			// Filter out used products
			products = data
				.filter(p => !usedProductIds.has(p.id))
				.map(p => ({
					id: p.id,
					name_ar: p.product_name_ar,
					name_en: p.product_name_en,
					barcode: p.barcode,
					price: parseFloat(p.sale_price) || 0,
					image_url: p.image_url,
					stock: p.current_stock || 0
				}));
		}
	}

	async function loadBundles() {
		if (!offerId) return;

		const { data, error: err } = await supabaseAdmin
			.from('offer_bundles')
			.select('*')
			.eq('offer_id', offerId);

		if (!err && data) {
			bundles = data.map(b => ({
				id: b.id,
				name_ar: b.bundle_name_ar,
				name_en: b.bundle_name_en,
				products: b.required_products || [],
				total_price: calculateBundleTotalPrice(b.required_products || [])
			}));
		}
	}

	function calculateBundleTotalPrice(bundleProducts: any[]): number {
		return bundleProducts.reduce((total, bp) => {
			const product = products.find(p => p.id === bp.product_id);
			if (!product) return total;

			const itemTotal = product.price * bp.quantity;
			const discountValue = bp.discount_value || 0;

			if (bp.discount_type === 'percentage') {
				return total + (itemTotal - (itemTotal * discountValue / 100));
			} else {
				return total + (itemTotal - discountValue);
			}
		}, 0);
	}

	function openAddBundleModal() {
		currentBundle = {
			name_ar: '',
			name_en: '',
			products: []
		};
		selectedProductsForBundle = [];
		calculatedBundlePrice = null;
		productSearchTerm = '';
		showAddBundleForm = true;
	}

	function closeAddBundleModal() {
		showAddBundleForm = false;
		currentBundle = null;
		selectedProductsForBundle = [];
		calculatedBundlePrice = null;
		productSearchTerm = '';
	}

	function selectProductForBundle(product: any) {
		// Check if already selected
		if (selectedProductsForBundle.some(p => p.product_id === product.id)) {
			alert(isRTL ? 'هذا المنتج مضاف بالفعل' : 'This product is already added');
			return;
		}

		selectedProductsForBundle = [
			...selectedProductsForBundle,
			{
				product_id: product.id,
				product_name_ar: product.name_ar,
				product_name_en: product.name_en,
				product_barcode: product.barcode,
				product_price: product.price,
				product_image: product.image_url,
				quantity: 1,
				discount_type: 'percentage',
				discount_value: 0
			}
		];
		calculatedBundlePrice = null;
	}

	function removeProductFromBundle(index: number) {
		selectedProductsForBundle = selectedProductsForBundle.filter((_, i) => i !== index);
		calculatedBundlePrice = null;
	}

	function calculateBundlePrice() {
		// Require at least 2 products for a bundle
		if (selectedProductsForBundle.length < 2) {
			error = isRTL 
				? 'يجب إضافة منتجين على الأقل للحزمة' 
				: 'A bundle must contain at least 2 products';
			return;
		}

		let total = 0;
		for (const item of selectedProductsForBundle) {
			if (!item.quantity || item.quantity < 1) {
				error = isRTL ? 'يرجى إدخال كمية صحيحة لجميع المنتجات' : 'Please enter valid quantity for all products';
				return;
			}

			const unitPrice = item.product_price;
			const discountValue = item.discount_value || 0;
			let priceAfterDiscount = unitPrice;

			// Apply discount per unit
			if (item.discount_type === 'percentage') {
				priceAfterDiscount = unitPrice - (unitPrice * discountValue / 100);
			} else {
				// For amount discount, subtract from unit price
				priceAfterDiscount = unitPrice - discountValue;
			}

			// Multiply by quantity
			total += priceAfterDiscount * item.quantity;
		}

		calculatedBundlePrice = Math.max(0, total);
		error = null;
	}

	function saveBundle() {
		if (!currentBundle.name_ar || !currentBundle.name_en) {
			error = isRTL ? 'يرجى إدخال اسم الحزمة بالعربية والإنجليزية' : 'Please enter bundle name in both languages';
			return;
		}

		// Require at least 2 products for a bundle
		if (selectedProductsForBundle.length < 2) {
			error = isRTL 
				? 'يجب إضافة منتجين على الأقل للحزمة' 
				: 'A bundle must contain at least 2 products';
			return;
		}

		if (calculatedBundlePrice === null) {
			error = isRTL ? 'يرجى حساب سعر الحزمة أولاً' : 'Please calculate bundle price first';
			return;
		}

		bundles = [
			...bundles,
			{
				id: null,
				name_ar: currentBundle.name_ar,
				name_en: currentBundle.name_en,
				products: [...selectedProductsForBundle],
				total_price: calculatedBundlePrice
			}
		];

		closeAddBundleModal();
	}

	function editBundle(index: number) {
		const bundle = bundles[index];
		
		// Load bundle data into form
		currentBundle = {
			name_ar: bundle.name_ar,
			name_en: bundle.name_en
		};
		selectedProductsForBundle = [...bundle.products];
		
		// Remove the bundle from the list (will be re-added when saved)
		bundles = bundles.filter((_, i) => i !== index);
		
		// Show the add bundle form
		showAddBundleForm = true;
	}

	function deleteBundle(index: number) {
		if (confirm(isRTL ? 'هل تريد حذف هذه الحزمة؟' : 'Do you want to delete this bundle?')) {
			bundles = bundles.filter((_, i) => i !== index);
		}
	}

	function validateStep1(): boolean {
		error = null;

		if (!offerData.name_ar || !offerData.name_en) {
			error = isRTL
				? 'يرجى إدخال اسم العرض بالعربية والإنجليزية'
				: 'Please enter offer name in both Arabic and English';
			return false;
		}

		if (new Date(offerData.end_date) <= new Date(offerData.start_date)) {
			error = isRTL
				? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء'
				: 'End date must be after start date';
			return false;
		}

		return true;
	}

	function nextStep() {
		if (validateStep1()) {
			currentStep = 2;
		}
	}

	function previousStep() {
		currentStep = 1;
		error = null;
	}

	function cancel() {
		dispatch('cancel');
	}

	async function saveOffer() {
		if (bundles.length === 0) {
			error = isRTL ? 'يرجى إضافة حزمة واحدة على الأقل' : 'Please add at least one bundle';
			return;
		}

		loading = true;
		error = null;

		try {
			const offerPayload = {
				type: 'bundle',
				name_ar: offerData.name_ar,
				name_en: offerData.name_en,
				description_ar: offerData.description_ar,
				description_en: offerData.description_en,
				start_date: new Date(offerData.start_date).toISOString(),
				end_date: new Date(offerData.end_date).toISOString(),
				branch_id: offerData.branch_id,
				service_type: offerData.service_type,
				is_active: offerData.is_active,
				discount_type: 'fixed',
				discount_value: 0
			};

			let savedOfferId = offerId;

			if (editMode && offerId) {
				// Update existing offer
				const { error: updateError } = await supabaseAdmin
					.from('offers')
					.update(offerPayload)
					.eq('id', offerId);

				if (updateError) throw updateError;

				// Delete existing bundles
				await supabaseAdmin
					.from('offer_bundles')
					.delete()
					.eq('offer_id', offerId);
			} else {
				// Create new offer
				const { data, error: insertError } = await supabaseAdmin
					.from('offers')
					.insert(offerPayload)
					.select()
					.single();

				if (insertError) throw insertError;
				savedOfferId = data.id;
			}

			// Insert bundles
			for (const bundle of bundles) {
				const bundlePayload = {
					offer_id: savedOfferId,
					bundle_name_ar: bundle.name_ar,
					bundle_name_en: bundle.name_en,
					discount_type: 'amount',
					discount_value: bundle.total_price,
					required_products: bundle.products.map(p => ({
						product_id: p.product_id,
						quantity: p.quantity,
						discount_type: p.discount_type,
						discount_value: p.discount_value
					}))
				};

				const { error: bundleError } = await supabaseAdmin
					.from('offer_bundles')
					.insert(bundlePayload);

				if (bundleError) throw bundleError;
			}

			// Show success message
			alert(isRTL 
				? '✅ تم حفظ عرض الحزمة بنجاح!' 
				: '✅ Bundle offer saved successfully!'
			);

			dispatch('success');
			cancel();
		} catch (err: any) {
			console.error('Error saving offer:', err);
			error = isRTL ? 'حدث خطأ أثناء الحفظ' : 'An error occurred while saving';
		} finally {
			loading = false;
		}
	}
</script>

<div class="bundle-offer-window" class:rtl={isRTL}>
	<!-- Header with Steps -->
	<div class="window-header">
		<h2 class="window-title">
			{editMode
				? isRTL
					? '📦 تعديل عرض حزمة'
					: '📦 Edit Bundle Offer'
				: isRTL
					? '📦 إنشاء عرض حزمة'
					: '📦 Create Bundle Offer'}
		</h2>
		<div class="step-indicator">
			<div class="step-item" class:active={currentStep === 1} class:completed={currentStep > 1}>
				<div class="step-circle">1</div>
				<span class="step-label">{isRTL ? 'تفاصيل العرض' : 'Offer Details'}</span>
			</div>
			<div class="step-divider"></div>
			<div class="step-item" class:active={currentStep === 2}>
				<div class="step-circle">2</div>
				<span class="step-label">{isRTL ? 'إدارة الحزم' : 'Bundle Management'}</span>
			</div>
		</div>
	</div>

	{#if error}
		<div class="error-banner">
			<span class="error-icon">⚠️</span>
			<span class="error-text">{error}</span>
		</div>
	{/if}

	<!-- Step Content -->
	<div class="window-content">
		{#if currentStep === 1}
			<!-- Step 1: Offer Details -->
			<div class="step-content">
				<h3 class="section-title">
					{isRTL ? 'معلومات العرض الأساسية' : 'Basic Offer Information'}
				</h3>

				<!-- Offer Names -->
				<div class="form-row">
					<div class="form-group">
						<label for="name_ar">
							{isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'}
							<span class="required">*</span>
						</label>
						<input
							id="name_ar"
							type="text"
							bind:value={offerData.name_ar}
							placeholder={isRTL
								? 'أدخل اسم العرض بالعربية'
								: 'Enter offer name in Arabic'}
							required
						/>
					</div>
					<div class="form-group">
						<label for="name_en">
							{isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'}
							<span class="required">*</span>
						</label>
						<input
							id="name_en"
							type="text"
							bind:value={offerData.name_en}
							placeholder={isRTL
								? 'أدخل اسم العرض بالإنجليزية'
								: 'Enter offer name in English'}
							required
						/>
					</div>
				</div>

				<!-- Descriptions -->
				<div class="form-row">
					<div class="form-group">
						<label for="desc_ar">
							{isRTL ? 'الوصف (عربي)' : 'Description (Arabic)'}
						</label>
						<textarea
							id="desc_ar"
							bind:value={offerData.description_ar}
							placeholder={isRTL
								? 'أدخل وصف العرض بالعربية'
								: 'Enter description in Arabic'}
							rows="3"
						></textarea>
					</div>
					<div class="form-group">
						<label for="desc_en">
							{isRTL ? 'الوصف (إنجليزي)' : 'Description (English)'}
						</label>
						<textarea
							id="desc_en"
							bind:value={offerData.description_en}
							placeholder={isRTL
								? 'أدخل وصف العرض بالإنجليزية'
								: 'Enter description in English'}
							rows="3"
						></textarea>
					</div>
				</div>

				<h3 class="section-title">
					{isRTL ? 'الفترة الزمنية' : 'Time Period'}
				</h3>

				<!-- Date Range -->
				<div class="form-row">
					<div class="form-group">
						<label for="start_date">
							{isRTL ? 'تاريخ البدء' : 'Start Date & Time'}
							<span class="required">*</span>
							<span class="timezone-hint">({isRTL ? 'التوقيت السعودي' : 'Saudi Time Zone'})</span>
						</label>
						<input
							id="start_date"
							type="datetime-local"
							bind:value={offerData.start_date}
							required
						/>
					</div>
					<div class="form-group">
						<label for="end_date">
							{isRTL ? 'تاريخ الانتهاء' : 'End Date & Time'}
							<span class="required">*</span>
							<span class="timezone-hint">({isRTL ? 'التوقيت السعودي' : 'Saudi Time Zone'})</span>
						</label>
						<input
							id="end_date"
							type="datetime-local"
							bind:value={offerData.end_date}
							required
						/>
					</div>
				</div>

				<h3 class="section-title">
					{isRTL ? 'النطاق والاستهداف' : 'Scope & Targeting'}
				</h3>

				<!-- Branch & Service Type -->
				<div class="form-row">
					<div class="form-group">
						<label for="branch">
							{isRTL ? 'الفرع المستهدف' : 'Target Branch'}
						</label>
						<select id="branch" bind:value={offerData.branch_id}>
							<option value={null}>{isRTL ? 'جميع الفروع' : 'All Branches'}</option>
							{#each branches as branch}
								<option value={branch.id}>
									{isRTL ? branch.name_ar : branch.name_en}
								</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label for="service_type">
							{isRTL ? 'نوع الخدمة' : 'Service Type'}
						</label>
						<select id="service_type" bind:value={offerData.service_type}>
							<option value="both">{isRTL ? 'التوصيل والاستلام' : 'Delivery & Pickup'}</option>
							<option value="delivery">{isRTL ? 'التوصيل فقط' : 'Delivery Only'}</option>
							<option value="pickup">{isRTL ? 'الاستلام فقط' : 'Pickup Only'}</option>
						</select>
					</div>
				</div>
			</div>
		{:else if currentStep === 2}
			<!-- Step 2: Bundle Management -->
			<div class="step-content">
				{#if !showAddBundleForm}
					<!-- Bundle List View -->
					<div class="bundle-manager-header">
						<h3 class="section-title">
							{isRTL ? 'إدارة الحزم' : 'Bundle Management'}
						</h3>
						<button type="button" class="btn btn-add-bundle" on:click={openAddBundleModal}>
							+ {isRTL ? 'إضافة حزمة' : 'Add Bundle'}
						</button>
					</div>

					<!-- Saved Bundles List -->
					{#if bundles.length === 0}
						<div class="empty-state">
							<div class="empty-icon">📦</div>
							<p class="empty-text">
								{isRTL ? 'لم يتم إضافة أي حزم بعد' : 'No bundles added yet'}
							</p>
							<p class="empty-hint">
								{isRTL
									? 'انقر على "إضافة حزمة" لإنشاء حزمة جديدة'
									: 'Click "Add Bundle" to create a new bundle'}
							</p>
						</div>
					{:else}
						<div class="bundles-grid">
							{#each bundles as bundle, index}
								<div class="bundle-card-summary">
									<div class="bundle-card-header">
										<h4>{isRTL ? bundle.name_ar : bundle.name_en}</h4>
										<div class="bundle-actions">
											<button
												type="button"
												class="btn-edit-bundle"
												on:click={() => editBundle(index)}
												title={isRTL ? 'تعديل' : 'Edit'}
											>
												✏️
											</button>
											<button
												type="button"
												class="btn-delete-bundle"
												on:click={() => deleteBundle(index)}
												title={isRTL ? 'حذف' : 'Delete'}
											>
												🗑️
											</button>
										</div>
									</div>
									<div class="bundle-card-content">
										<div class="product-count">
											{bundle.products.length} {isRTL ? 'منتجات' : 'Products'}
										</div>
										<div class="bundle-price">
											{bundle.total_price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}
										</div>
										<div class="product-list-mini">
											{#each bundle.products as product}
												<div class="product-mini-item">
													<span class="product-mini-name">
														{isRTL ? product.product_name_ar : product.product_name_en}
													</span>
													<span class="product-mini-qty">x{product.quantity}</span>
												</div>
											{/each}
										</div>
									</div>
								</div>
							{/each}
						</div>
					{/if}
				{:else}
					<!-- Add Bundle Form (Inline) -->
					<div class="add-bundle-form">
						<div class="form-header">
							<h3>{isRTL ? 'إضافة حزمة جديدة' : 'Add New Bundle'}</h3>
							<button type="button" class="btn-back" on:click={closeAddBundleModal}>
								{isRTL ? '← رجوع' : '← Back'}
							</button>
						</div>

						<!-- Bundle Names -->
						<div class="form-row">
							<div class="form-group">
								<label>
									{isRTL ? 'اسم الحزمة (عربي)' : 'Bundle Name (Arabic)'}
									<span class="required">*</span>
								</label>
								<input
									type="text"
									bind:value={currentBundle.name_ar}
									placeholder={isRTL ? 'أدخل اسم الحزمة' : 'Enter bundle name'}
								/>
							</div>
							<div class="form-group">
								<label>
									{isRTL ? 'اسم الحزمة (إنجليزي)' : 'Bundle Name (English)'}
									<span class="required">*</span>
								</label>
								<input
									type="text"
									bind:value={currentBundle.name_en}
									placeholder={isRTL ? 'أدخل اسم الحزمة' : 'Enter bundle name'}
								/>
							</div>
						</div>

						<!-- Search Bar -->
						<div class="search-bar">
							<input
								type="text"
								bind:value={productSearchTerm}
								placeholder={isRTL ? 'البحث بالباركود...' : 'Search by barcode...'}
								class="search-input"
							/>
						</div>

						<!-- Selected Products Section -->
						{#if selectedProductsForBundle.length > 0}
							<div class="selected-products-section">
								<h4>{isRTL ? 'المنتجات المحددة' : 'Selected Products'}</h4>
								<div class="selected-products-list">
									{#each selectedProductsForBundle as item, index}
										<div class="selected-product-item">
											<div class="product-info-row">
												{#if item.product_image}
													<img src={item.product_image} alt={item.product_name_en} class="product-thumb" />
												{:else}
													<div class="product-thumb-placeholder">📦</div>
												{/if}
												<div class="product-details">
													<div class="product-name">{isRTL ? item.product_name_ar : item.product_name_en}</div>
													<div class="product-barcode">{item.product_barcode}</div>
													<div class="product-price">{item.product_price} {isRTL ? 'ريال' : 'SAR'}</div>
												</div>
												<button
													type="button"
													class="btn-remove-product"
													on:click={() => removeProductFromBundle(index)}
												>
													✕
												</button>
											</div>
											
											<div class="product-config-row">
												<div class="config-field">
													<label>{isRTL ? 'الكمية' : 'Quantity'}</label>
													<input type="number" min="1" bind:value={item.quantity} />
												</div>
												<div class="config-field">
													<label>{isRTL ? 'نوع الخصم' : 'Discount Type'}</label>
													<select bind:value={item.discount_type}>
														<option value="percentage">{isRTL ? 'نسبة مئوية' : 'Percentage'}</option>
														<option value="amount">{isRTL ? 'مبلغ ثابت' : 'Amount'}</option>
													</select>
												</div>
												<div class="config-field">
													<label>{isRTL ? 'قيمة الخصم' : 'Discount Value'}</label>
													<input
														type="number"
														min="0"
														step="0.01"
														bind:value={item.discount_value}
														placeholder="0"
													/>
												</div>
											</div>
										</div>
									{/each}
								</div>

							<!-- Calculate & Save Buttons -->
							<div class="bundle-actions">
								<button 
									type="button" 
									class="btn btn-calculate" 
									on:click={calculateBundlePrice}
									disabled={selectedProductsForBundle.length < 2}
								>
									💰 {isRTL ? 'حساب سعر الحزمة' : 'Calculate Bundle Price'}
								</button>
								{#if calculatedBundlePrice !== null}
									<div class="calculated-price">
										{isRTL ? 'السعر الإجمالي:' : 'Total Price:'} 
										<strong>{calculatedBundlePrice.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</strong>
									</div>
									<button type="button" class="btn btn-success" on:click={saveBundle}>
										✓ {isRTL ? 'حفظ الحزمة' : 'Save Bundle'}
									</button>
								{/if}
							</div>
						</div>
					{/if}						<!-- Products Table -->
						<div class="products-table-container">
							<h4>{isRTL ? 'المنتجات المتاحة' : 'Available Products'}</h4>
							<div class="products-table-scroll">
								<table class="products-table">
									<thead>
										<tr>
											<th>{isRTL ? 'الصورة' : 'Image'}</th>
											<th>{isRTL ? 'اسم المنتج' : 'Product Name'}</th>
											<th>{isRTL ? 'الباركود' : 'Barcode'}</th>
											<th>{isRTL ? 'المخزون' : 'Stock'}</th>
											<th>{isRTL ? 'السعر' : 'Price'}</th>
											<th>{isRTL ? 'إجراء' : 'Action'}</th>
										</tr>
									</thead>
									<tbody>
										{#each filteredProducts as product}
											<tr>
												<td>
													{#if product.image_url}
														<img src={product.image_url} alt={product.name_en} class="table-product-img" />
													{:else}
														<div class="table-product-placeholder">📦</div>
													{/if}
												</td>
												<td>{isRTL ? product.name_ar : product.name_en}</td>
												<td>{product.barcode || '-'}</td>
												<td>{product.stock}</td>
												<td>{product.price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
												<td>
													<button
														type="button"
														class="btn-select-product"
														on:click={() => selectProductForBundle(product)}
														disabled={selectedProductsForBundle.some(p => p.product_id === product.id)}
													>
														{isRTL ? 'اختيار' : 'Select'}
													</button>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<!-- Footer Actions -->
	<div class="window-footer">
		<div class="footer-left">
			{#if currentStep > 1}
				<button type="button" class="btn btn-secondary" on:click={previousStep}>
					{isRTL ? '← السابق' : '← Previous'}
				</button>
			{/if}
		</div>
		<div class="footer-right">
			<button type="button" class="btn btn-cancel" on:click={cancel}>
				{isRTL ? 'إلغاء' : 'Cancel'}
			</button>
			{#if currentStep === 1}
				<button type="button" class="btn btn-primary" on:click={nextStep}>
					{isRTL ? 'التالي →' : 'Next →'}
				</button>
			{:else}
				<button 
					type="button" 
					class="btn btn-success" 
					on:click={saveOffer}
					disabled={loading || bundles.length === 0}
				>
					{loading ? (isRTL ? 'جاري الحفظ...' : 'Saving...') : (isRTL ? 'حفظ العرض' : 'Save Offer')}
				</button>
			{/if}
		</div>
	</div>
</div>

<style>
	.bundle-offer-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #ffffff;
	}

	.bundle-offer-window.rtl {
		direction: rtl;
	}

	/* Header */
	.window-header {
		padding: 1.5rem 2rem;
		border-bottom: 2px solid #e5e7eb;
		background: linear-gradient(135deg, #f9fafb 0%, #ffffff 100%);
	}

	.window-title {
		margin: 0 0 1rem 0;
		font-size: 1.5rem;
		font-weight: 700;
		color: #1f2937;
	}

	.step-indicator {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.step-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex: 1;
	}

	.step-circle {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		background: #e5e7eb;
		color: #6b7280;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 0.95rem;
		transition: all 0.3s ease;
	}

	.step-item.active .step-circle {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.step-item.completed .step-circle {
		background: #10b981;
		color: white;
	}

	.step-label {
		font-size: 0.9rem;
		font-weight: 500;
		color: #6b7280;
	}

	.step-item.active .step-label {
		color: #1f2937;
		font-weight: 600;
	}

	.step-divider {
		flex: 1;
		height: 2px;
		background: #e5e7eb;
		margin: 0 0.5rem;
	}

	/* Error Banner */
	.error-banner {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 2rem;
		background: #fee2e2;
		border-bottom: 2px solid #fecaca;
		color: #dc2626;
	}

	.error-icon {
		font-size: 1.25rem;
	}

	.error-text {
		font-size: 0.95rem;
		font-weight: 500;
	}

	/* Content */
	.window-content {
		flex: 1;
		overflow-y: auto;
		padding: 2rem;
	}

	.step-content {
		max-width: 900px;
		margin: 0 auto;
	}

	.section-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 1rem 0;
		padding-bottom: 0.5rem;
		border-bottom: 2px solid #f3f4f6;
	}

	.section-title:not(:first-child) {
		margin-top: 2rem;
	}

	/* Form Elements */
	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.5rem;
		margin-bottom: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-group label {
		font-size: 0.9rem;
		font-weight: 500;
		color: #374151;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.required {
		color: #ef4444;
		font-weight: 700;
	}

	.timezone-hint {
		font-size: 0.813rem;
		color: #6b7280;
		font-weight: 400;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		padding: 0.75rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 0.95rem;
		transition: all 0.2s ease;
		font-family: inherit;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-group textarea {
		resize: vertical;
		min-height: 80px;
	}

	/* Coming Soon */
	.coming-soon {
		text-align: center;
		padding: 4rem 2rem;
		color: #6b7280;
		font-size: 1.125rem;
	}

	/* Footer */
	.window-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 2rem;
		border-top: 2px solid #e5e7eb;
		background: #f9fafb;
	}

	.footer-left,
	.footer-right {
		display: flex;
		gap: 0.75rem;
	}

	/* Buttons */
	.btn {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-primary {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.btn-secondary {
		background: #f3f4f6;
		color: #374151;
		border: 2px solid #e5e7eb;
	}

	.btn-secondary:hover {
		background: #e5e7eb;
	}

	.btn-cancel {
		background: white;
		color: #6b7280;
		border: 2px solid #d1d5db;
	}

	.btn-cancel:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.btn-success {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
	}

	.btn-success:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	/* Responsive */
	@media (max-width: 768px) {
		.window-header,
		.window-content,
		.window-footer {
			padding: 1rem;
		}

		.form-row {
			grid-template-columns: 1fr;
			gap: 1rem;
		}

		.step-indicator {
			flex-direction: column;
			align-items: stretch;
		}

		.step-divider {
			height: 20px;
			width: 2px;
			margin: 0 auto;
		}
	}

	/* Step 2 Styles */
	.bundle-manager-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 2rem;
	}

	.btn-add-bundle {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-add-bundle:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.empty-state {
		text-align: center;
		padding: 4rem 2rem;
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.empty-text {
		font-size: 1.125rem;
		color: #6b7280;
		margin: 0 0 0.5rem 0;
	}

	.empty-hint {
		font-size: 0.95rem;
		color: #9ca3af;
		margin: 0;
	}

	.bundles-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 1.5rem;
	}

	.bundle-card-summary {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
		transition: all 0.2s;
	}

	.bundle-card-summary:hover {
		border-color: #3b82f6;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.1);
	}

	.bundle-card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid #f3f4f6;
	}

	.bundle-card-header h4 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.bundle-actions {
		display: flex;
		gap: 0.5rem;
	}

	.btn-edit-bundle,
	.btn-delete-bundle {
		background: transparent;
		border: 1px solid #3b82f6;
		border-radius: 6px;
		padding: 0.375rem 0.75rem;
		cursor: pointer;
		font-size: 1.1rem;
		transition: all 0.2s;
	}

	.btn-edit-bundle {
		border-color: #3b82f6;
	}

	.btn-delete-bundle {
		border-color: #ef4444;
	}

	.btn-edit-bundle:hover {
		background: #3b82f6;
		transform: scale(1.1);
	}

	.btn-delete-bundle:hover {
		background: #ef4444;
		transform: scale(1.1);
	}

	.bundle-card-content {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.product-count {
		font-size: 0.95rem;
		color: #6b7280;
	}

	.bundle-price {
		font-size: 1.5rem;
		font-weight: 700;
		color: #10b981;
	}

	.product-list-mini {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.product-mini-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem;
		background: #f9fafb;
		border-radius: 6px;
		font-size: 0.875rem;
	}

	.product-mini-name {
		color: #374151;
	}

	.product-mini-qty {
		font-weight: 600;
		color: #3b82f6;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 3000;
	}

	.modal-large {
		background: white;
		border-radius: 16px;
		width: 95%;
		max-width: 1200px;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.2);
	}

	.modal-header-large {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 2rem;
		border-bottom: 2px solid #e5e7eb;
		background: linear-gradient(135deg, #f9fafb 0%, #ffffff 100%);
	}

	.modal-header-large h3 {
		margin: 0;
		font-size: 1.375rem;
		font-weight: 700;
		color: #1f2937;
	}

	.modal-close {
		background: transparent;
		border: none;
		font-size: 1.75rem;
		color: #6b7280;
		cursor: pointer;
		padding: 0.25rem;
		transition: all 0.2s;
	}

	.modal-close:hover {
		color: #1f2937;
		transform: rotate(90deg);
	}

	.modal-body-large {
		flex: 1;
		overflow-y: auto;
		padding: 2rem;
	}

	.search-bar {
		margin-bottom: 1.5rem;
	}

	.search-input {
		width: 100%;
		padding: 0.875rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 10px;
		font-size: 1rem;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.selected-products-section {
		background: #f9fafb;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 2rem;
	}

	.selected-products-section h4 {
		margin: 0 0 1rem 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.selected-products-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.selected-product-item {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 10px;
		padding: 1rem;
	}

	.product-info-row {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 1rem;
		padding-bottom: 1rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.product-thumb,
	.product-thumb-placeholder {
		width: 60px;
		height: 60px;
		border-radius: 8px;
		object-fit: cover;
	}

	.product-thumb-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
		font-size: 1.5rem;
	}

	.product-details {
		flex: 1;
	}

	.product-name {
		font-weight: 600;
		color: #1f2937;
		margin-bottom: 0.25rem;
	}

	.product-barcode {
		font-size: 0.875rem;
		color: #6b7280;
		margin-bottom: 0.25rem;
	}

	.product-price {
		font-size: 0.95rem;
		font-weight: 600;
		color: #10b981;
	}

	.btn-remove-product {
		background: #fee2e2;
		border: 1px solid #fecaca;
		color: #dc2626;
		border-radius: 6px;
		padding: 0.5rem 0.75rem;
		cursor: pointer;
		font-size: 1.125rem;
		font-weight: 700;
		transition: all 0.2s;
	}

	.btn-remove-product:hover {
		background: #dc2626;
		color: white;
	}

	.product-config-row {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 1rem;
	}

	.config-field {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.config-field label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.config-field input,
	.config-field select {
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.95rem;
	}

	.config-field input:focus,
	.config-field select:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.bundle-actions {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding-top: 1rem;
		border-top: 2px solid #e5e7eb;
	}

	.btn-calculate {
		background: linear-gradient(135deg, #eab308 0%, #ca8a04 100%);
		color: white;
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-calculate:hover {
		background: linear-gradient(135deg, #ca8a04 0%, #a16207 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(234, 179, 8, 0.3);
	}

	.calculated-price {
		font-size: 1.125rem;
		color: #374151;
	}

	.calculated-price strong {
		color: #10b981;
		font-size: 1.25rem;
	}

	.products-table-container {
		margin-top: 2rem;
	}

	.products-table-container h4 {
		margin: 0 0 1rem 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.products-table-scroll {
		max-height: 400px;
		overflow-y: auto;
		border: 2px solid #e5e7eb;
		border-radius: 10px;
	}

	.products-table {
		width: 100%;
		border-collapse: collapse;
	}

	.products-table thead {
		position: sticky;
		top: 0;
		background: #f9fafb;
		z-index: 10;
	}

	.products-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
	}

	.products-table tbody tr {
		transition: background 0.2s;
	}

	.products-table tbody tr:hover {
		background: #f9fafb;
	}

	.products-table td {
		padding: 0.875rem 1rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.table-product-img,
	.table-product-placeholder {
		width: 50px;
		height: 50px;
		border-radius: 6px;
		object-fit: cover;
	}

	.table-product-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
		font-size: 1.25rem;
	}

	.btn-select-product {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-select-product:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
	}

	.btn-select-product:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.modal-footer-large {
		padding: 1.5rem 2rem;
		border-top: 2px solid #e5e7eb;
		background: #f9fafb;
		display: flex;
		justify-content: flex-end;
	}

	@media (max-width: 768px) {
		.modal-large {
			width: 100%;
			height: 100%;
			max-height: 100vh;
			border-radius: 0;
		}

		.bundles-grid {
			grid-template-columns: 1fr;
		}

		.product-config-row {
			grid-template-columns: 1fr;
		}
	}
</style>
