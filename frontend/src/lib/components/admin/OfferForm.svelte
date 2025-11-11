<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { t, currentLocale } from '$lib/i18n';
	import { supabase, supabaseAdmin } from '$lib/utils/supabase';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import OfferTypeSelector from './OfferTypeSelector.svelte';
	import ProductSelectorWindow from './ProductSelectorWindow.svelte';
	import TierManager from './TierManager.svelte';
	import BundleCreator from './BundleCreator.svelte';

	export let editMode = false;
	export let offerId: number | null = null;
	export let preselectedType: string | null = null;

	const dispatch = createEventDispatcher();

	let currentStep = 1;
	let loading = false;
	let error: string | null = null;

	// Form data
	let offerData = {
		type: preselectedType as string | null,
		name_ar: '',
		name_en: '',
		description_ar: '',
		description_en: '',
		discount_type: 'percentage' as 'percentage' | 'fixed',
		discount_value: 0,
		bogo_buy_quantity: null as number | null,
		bogo_get_quantity: null as number | null,
		start_date: new Date().toISOString().slice(0, 16),
		end_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 16),
		is_active: true,
		min_quantity: null as number | null,
		min_amount: null as number | null,
		max_uses_per_customer: null as number | null,
		max_total_uses: null as number | null,
		branch_id: null as number | null,
		service_type: 'both' as 'delivery' | 'pickup' | 'both',
		show_on_product_page: true,
		show_in_carousel: false,
		send_push_notification: false
	};

	let branches: any[] = [];
	let products: any[] = [];
	let selectedProducts: any[] = [];
	let productSearchTerm = '';
	let showProductSelector = false;
	let cartTiers: any[] = [];
	let bundles: any[] = [];
	let bundleCreatorRef: any;

	$: isRTL = $currentLocale === 'ar';
	$: totalSteps = offerData.type === 'bogo' || offerData.type === 'bundle' ? 4 : 3;
	$: needsProductSelection = ['product', 'bogo', 'bundle'].includes(offerData.type || '');
	$: needsTierConfiguration = offerData.type === 'cart';
	$: filteredProducts = products.filter(p => 
		p.name_ar.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.barcode?.includes(productSearchTerm)
	);

	onMount(async () => {
		await loadBranches();
		await loadProducts();
		if (editMode && offerId) {
			await loadOfferData();
		} else if (preselectedType) {
			// Skip type selection step if type is preselected
			currentStep = 2;
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

	async function loadProducts() {
		const { data, error: err } = await supabase
			.from('products')
			.select('id, product_name_ar, product_name_en, barcode, unit_id, sale_price, image_url, product_serial')
			.eq('is_active', true)
			.order('product_name_en');

		if (!err && data) {
			// Only filter products if this is a product-specific offer type
			// Cart/min_purchase/customer offers don't have product restrictions
			const isProductSpecificOffer = ['product', 'bogo', 'bundle'].includes(offerData.type || '');
			
			if (isProductSpecificOffer) {
				// Get all products currently in active product-specific offers (excluding current offer in edit mode)
				const { data: activeOfferProducts } = await supabaseAdmin
					.from('offer_products')
					.select(`
						product_id,
						offers!inner(id, type, is_active)
					`)
					.eq('offers.is_active', true)
					.in('offers.type', ['product', 'bogo']); // Only check product-specific offers
				
				// Get products from active bundle offers too
				const { data: activeBundles } = await supabaseAdmin
					.from('offer_bundles')
					.select(`
						required_products,
						offers!inner(id, is_active)
					`)
					.eq('offers.is_active', true);

				// Create a Set of product IDs that are already in active product-specific offers
				const usedProductIds = new Set<string>();
				
				// Add products from offer_products table
				if (activeOfferProducts) {
					activeOfferProducts.forEach(op => {
						// Skip products from current offer (when editing)
						const offerId = op.offers?.id;
						if (editMode && offerId === offerData.id) return;
						
						usedProductIds.add(op.product_id);
					});
				}
				
				// Add products from bundle offers
				if (activeBundles) {
					activeBundles.forEach(bundle => {
						// Skip products from current offer (when editing)
						const offerId = bundle.offers?.id;
						if (editMode && offerId === offerData.id) return;
						
						if (bundle.required_products && Array.isArray(bundle.required_products)) {
							bundle.required_products.forEach((p: any) => {
								usedProductIds.add(p.product_id);
							});
						}
					});
				}

				console.log('🚫 Products already in active product-specific offers:', Array.from(usedProductIds));

				// Filter out products that are already in active product-specific offers
				const availableProducts = data.filter(p => !usedProductIds.has(p.id));
				
				products = availableProducts.map(p => ({
					id: p.id,
					name_ar: p.product_name_ar,
					name_en: p.product_name_en,
					barcode: p.barcode,
					unit_id: p.unit_id,
					price: p.sale_price,
					image_url: p.image_url,
					serial: p.product_serial
				}));
				
				console.log(`✅ Available products for product-specific offer: ${products.length} (filtered from ${data.length} total)`);
			} else {
				// For cart/min_purchase/customer offers, show all products (no filtering)
				products = data.map(p => ({
					id: p.id,
					name_ar: p.product_name_ar,
					name_en: p.product_name_en,
					barcode: p.barcode,
					unit_id: p.unit_id,
					price: p.sale_price,
					image_url: p.image_url,
					serial: p.product_serial
				}));
				
				console.log(`✅ All products available for cart/bill offer: ${products.length}`);
			}
		}
	}

	async function loadOfferData() {
		// Load existing offer data for editing
		const { data, error: err } = await supabase
			.from('offers')
			.select('*')
			.eq('id', offerId)
			.single();

		if (!err && data) {
			offerData = {
				...offerData,
				...data,
				start_date: new Date(data.start_date).toISOString().slice(0, 16),
				end_date: new Date(data.end_date).toISOString().slice(0, 16)
			};
			currentStep = 2; // Skip type selection
			
			// Load selected products for this offer
			await loadOfferProducts();
			
			// Load cart tiers if this is a cart offer
			if (data.type === 'cart') {
				await loadCartTiers();
			}
		}
	}

	async function loadOfferProducts() {
		if (!offerId) return;
		
		console.log('🔍 Loading products for offer:', offerId);
		
		// Check if this is a bundle offer
		if (offerData.type === 'bundle') {
			// Load all bundles from offer_bundles table for this offer
			const { data: bundlesData, error: bundleErr } = await supabaseAdmin
				.from('offer_bundles')
				.select('*')
				.eq('offer_id', offerId);
			
			console.log('📦 Bundles data:', bundlesData);
			console.log('❌ Bundle error:', bundleErr);
			
			if (!bundleErr && bundlesData) {
				bundles = bundlesData.map(bundle => ({
					id: bundle.id,
					bundle_name_ar: bundle.bundle_name_ar || '',
					bundle_name_en: bundle.bundle_name_en || '',
					discount_type: bundle.discount_type || 'amount',
					discount_value: parseFloat(bundle.discount_value) || 0,
					required_products: bundle.required_products || []
				}));
				console.log('✅ Bundles loaded:', bundles);
			}
		} else {
			// Load products from offer_products table (for product/bogo offers)
			const { data, error: err } = await supabaseAdmin
				.from('offer_products')
				.select(`
					product_id,
					unit_id
				`)
				.eq('offer_id', offerId);

			console.log('📦 offer_products data:', data);
			console.log('❌ offer_products error:', err);

			if (!err && data) {
				// Load full product details for selected products
				const productIds = data.map(op => op.product_id);
				console.log('🔑 Product IDs:', productIds);
				
				const { data: productsData, error: productsErr } = await supabaseAdmin
					.from('products')
					.select('id, product_name_ar, product_name_en, barcode, sale_price, unit_id, image_url, product_serial')
					.in('id', productIds);

				console.log('🛒 Products data:', productsData);
				console.log('❌ Products error:', productsErr);

				if (productsData) {
					selectedProducts = productsData.map(p => ({
						id: p.id,
						name_ar: p.product_name_ar,
						name_en: p.product_name_en,
						barcode: p.barcode,
						price: p.sale_price,
						unit_id: p.unit_id,
						image_url: p.image_url,
						serial: p.product_serial
					}));
					
					console.log('✅ Selected products set to:', selectedProducts);
				}
			}
		}
	}

	async function loadCartTiers() {
		if (!offerId) return;
		
		console.log('🎯 Loading cart tiers for offer:', offerId);
		
		const { data, error: err } = await supabaseAdmin
			.from('offer_cart_tiers')
			.select('*')
			.eq('offer_id', offerId)
			.order('tier_number');
		
		console.log('📊 Cart tiers data:', data);
		console.log('❌ Cart tiers error:', err);
		
		if (!err && data) {
			cartTiers = data;
			console.log('✅ Cart tiers loaded:', cartTiers);
		}
	}

	function toggleProductSelection(product: any) {
		const index = selectedProducts.findIndex(p => p.id === product.id);
		if (index > -1) {
			selectedProducts = selectedProducts.filter(p => p.id !== product.id);
		} else {
			selectedProducts = [...selectedProducts, product];
		}
	}

	function removeProduct(productId: string) {
		selectedProducts = selectedProducts.filter(p => p.id !== productId);
	}

	function isProductSelected(productId: string): boolean {
		return selectedProducts.some(p => p.id === productId);
	}

	function openProductSelector() {
		const windowId = `product-selector-${Date.now()}`;
		
		openWindow({
			id: windowId,
			title: isRTL ? 'اختيار المنتجات للعرض' : 'Select Products for Offer',
			component: ProductSelectorWindow,
			icon: '📦',
			size: { width: 900, height: 600 },
			position: { 
				x: (window.innerWidth - 900) / 2, 
				y: 50 
			},
			props: {
				products,
				selectedProducts,
				isRTL,
				onSelect: (selected: any[]) => {
					selectedProducts = selected;
				}
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handleTypeSelect(event: CustomEvent) {
		offerData.type = event.detail.type;
		nextStep();
	}

	function nextStep() {
		if (validateCurrentStep()) {
			currentStep++;
		}
	}

	function prevStep() {
		currentStep--;
	}

	function validateCurrentStep(): boolean {
		error = null;

		if (currentStep === 1) {
			if (!offerData.type) {
				error = isRTL ? 'يرجى اختيار نوع العرض' : 'Please select an offer type';
				return false;
			}
		}

		if (currentStep === 2) {
			if (!offerData.name_ar || !offerData.name_en) {
				error = isRTL ? 'يرجى إدخال اسم العرض بالعربية والإنجليزية' : 'Please enter offer name in both Arabic and English';
				return false;
			}
			
			// Validate discount configuration based on offer type
			if (needsTierConfiguration) {
				// Cart offers need at least one tier
				if (cartTiers.length === 0) {
					error = isRTL ? 'يرجى إضافة مستوى خصم واحد على الأقل' : 'Please add at least one discount tier';
					return false;
				}
				// Validate each tier has valid values
				for (const tier of cartTiers) {
					if (tier.discount_value <= 0) {
						error = isRTL ? `المستوى ${tier.tier_number}: قيمة الخصم يجب أن تكون أكبر من صفر` : `Tier ${tier.tier_number}: discount value must be greater than zero`;
						return false;
					}
					if (tier.min_amount < 0) {
						error = isRTL ? `المستوى ${tier.tier_number}: الحد الأدنى يجب أن يكون صفر أو أكثر` : `Tier ${tier.tier_number}: minimum amount must be zero or greater`;
						return false;
					}
				}
			} else {
				// Product-specific offers need single discount value
				if (offerData.discount_value <= 0) {
					error = isRTL ? 'يرجى إدخال قيمة خصم صحيحة' : 'Please enter a valid discount value';
					return false;
				}
			}
			
			if (offerData.type === 'bogo') {
				if (!offerData.bogo_buy_quantity || !offerData.bogo_get_quantity) {
					error = isRTL ? 'يرجى إدخال كميات BOGO' : 'Please enter BOGO quantities';
					return false;
				}
			}
			if (new Date(offerData.end_date) <= new Date(offerData.start_date)) {
				error = isRTL ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء' : 'End date must be after start date';
				return false;
			}
			// Validate product selection for product/bogo offers (not bundle)
			if (needsProductSelection && offerData.type !== 'bundle' && selectedProducts.length === 0) {
				error = isRTL ? 'يرجى اختيار منتج واحد على الأقل' : 'Please select at least one product';
				return false;
			}
			
			// Validate bundles for bundle offers
			if (offerData.type === 'bundle') {
				if (bundleCreatorRef && !bundleCreatorRef.validateAll()) {
					// Error is set by BundleCreator component
					return false;
				}
				if (bundles.length === 0) {
					error = isRTL ? 'يرجى إضافة حزمة واحدة على الأقل' : 'Please add at least one bundle';
					return false;
				}
			}
		}

		return true;
	}

	async function handleSubmit() {
		if (!validateCurrentStep()) return;

		loading = true;
		error = null;

		try {
			// Check if trying to create/activate a cart discount when one already exists
			if (offerData.type === 'cart' && offerData.is_active) {
				const { data: existingCartOffers, error: checkError } = await supabase
					.from('offers')
					.select('id, name_ar, name_en, is_active')
					.eq('type', 'cart')
					.eq('is_active', true)
					.neq('id', offerId || 0); // Exclude current offer in edit mode
				
				if (checkError) throw checkError;
				
				if (existingCartOffers && existingCartOffers.length > 0) {
					const existingOffer = existingCartOffers[0];
					error = isRTL 
						? `يوجد بالفعل خصم سلة نشط: "${existingOffer.name_ar}". لا يمكن تفعيل أكثر من خصم سلة في نفس الوقت.`
						: `There is already an active cart discount: "${existingOffer.name_en}". You cannot activate more than one cart discount at a time.`;
					loading = false;
					return;
				}
			}
			
			const offerPayload = {
				...offerData,
				start_date: new Date(offerData.start_date).toISOString(),
				end_date: new Date(offerData.end_date).toISOString()
			};

			let savedOfferId = offerId;

			if (editMode && offerId) {
				const { error: updateError } = await supabase
					.from('offers')
					.update(offerPayload)
					.eq('id', offerId);

				if (updateError) throw updateError;

				// Delete existing product associations for product/bogo offers
				if (needsProductSelection && offerData.type !== 'bundle') {
					await supabase
						.from('offer_products')
						.delete()
						.eq('offer_id', offerId);
				}
				
				// Delete existing bundles for bundle offers
				if (offerData.type === 'bundle') {
					await supabaseAdmin
						.from('offer_bundles')
						.delete()
						.eq('offer_id', offerId);
				}
				
				// Delete existing cart tiers
				if (needsTierConfiguration) {
					await supabaseAdmin
						.from('offer_cart_tiers')
						.delete()
						.eq('offer_id', offerId);
				}
			} else {
				const { data, error: insertError } = await supabase
					.from('offers')
					.insert(offerPayload)
					.select()
					.single();

				if (insertError) throw insertError;
				savedOfferId = data.id;
			}

			// Insert product associations for product/bogo offers (not bundle)
			if (needsProductSelection && offerData.type !== 'bundle' && selectedProducts.length > 0) {
				const productAssociations = selectedProducts.map(product => ({
					offer_id: savedOfferId,
					product_id: product.id,
					unit_id: product.unit_id
				}));

				const { error: productsError } = await supabase
					.from('offer_products')
					.insert(productAssociations);

				if (productsError) throw productsError;
			}
			
			// Insert bundles for bundle offers
			if (offerData.type === 'bundle' && bundles.length > 0) {
				const bundleInserts = bundles.map(bundle => ({
					offer_id: savedOfferId,
					bundle_name_ar: bundle.bundle_name_ar,
					bundle_name_en: bundle.bundle_name_en,
					discount_type: bundle.discount_type,
					discount_value: bundle.discount_value,
					required_products: bundle.required_products
				}));

				const { error: bundlesError } = await supabaseAdmin
					.from('offer_bundles')
					.insert(bundleInserts);

				if (bundlesError) throw bundlesError;
			}
			
			// Insert cart tiers for cart/min_purchase offers
			if (needsTierConfiguration && cartTiers.length > 0) {
				const tierInserts = cartTiers.map(tier => ({
					offer_id: savedOfferId,
					tier_number: tier.tier_number,
					min_amount: tier.min_amount,
					max_amount: tier.max_amount,
					discount_type: tier.discount_type,
					discount_value: tier.discount_value
				}));

				const { error: tiersError } = await supabaseAdmin
					.from('offer_cart_tiers')
					.insert(tierInserts);

				if (tiersError) throw tiersError;
			}

			dispatch('success', { offerId: savedOfferId });
		} catch (err: any) {
			error = err.message || (isRTL ? 'حدث خطأ أثناء حفظ العرض' : 'Error saving offer');
		} finally {
			loading = false;
		}
	}

	function cancel() {
		dispatch('cancel');
	}
</script>

<div class="offer-form" class:rtl={isRTL}>
	<!-- Progress Steps -->
	<div class="progress-steps">
		<div class="step" class:active={currentStep === 1} class:completed={currentStep > 1}>
			<div class="step-number">1</div>
			<div class="step-label">{isRTL ? 'نوع العرض' : 'Offer Type'}</div>
		</div>
		<div class="step-line" class:completed={currentStep > 1}></div>
		<div class="step" class:active={currentStep === 2} class:completed={currentStep > 2}>
			<div class="step-number">2</div>
			<div class="step-label">{isRTL ? 'التفاصيل' : 'Details'}</div>
		</div>
		<div class="step-line" class:completed={currentStep > 2}></div>
		<div class="step" class:active={currentStep === 3}>
			<div class="step-number">3</div>
			<div class="step-label">{isRTL ? 'المعاينة' : 'Preview'}</div>
		</div>
	</div>

	{#if error}
		<div class="error-message">
			<svg
				xmlns="http://www.w3.org/2000/svg"
				width="20"
				height="20"
				viewBox="0 0 24 24"
				fill="none"
				stroke="currentColor"
				stroke-width="2"
			>
				<circle cx="12" cy="12" r="10"></circle>
				<line x1="12" y1="8" x2="12" y2="12"></line>
				<line x1="12" y1="16" x2="12.01" y2="16"></line>
			</svg>
			<span>{error}</span>
		</div>
	{/if}

	<!-- Step Content -->
	<div class="form-content">
		{#if currentStep === 1}
			<!-- Step 1: Type Selection -->
			<OfferTypeSelector selectedType={offerData.type} on:select={handleTypeSelect} />
		{:else if currentStep === 2}
			<!-- Step 2: Offer Details -->
			<div class="form-fields">
				<h3 class="section-title">{isRTL ? 'معلومات العرض الأساسية' : 'Basic Offer Information'}</h3>

				<!-- Offer Names -->
				<div class="form-row">
					<div class="form-group">
						<label for="name_ar">{isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'}</label>
						<input
							id="name_ar"
							type="text"
							bind:value={offerData.name_ar}
							placeholder={isRTL ? 'أدخل اسم العرض بالعربية' : 'Enter offer name in Arabic'}
							required
						/>
					</div>
					<div class="form-group">
						<label for="name_en">{isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'}</label>
						<input
							id="name_en"
							type="text"
							bind:value={offerData.name_en}
							placeholder={isRTL ? 'أدخل اسم العرض بالإنجليزية' : 'Enter offer name in English'}
							required
						/>
					</div>
				</div>

				<!-- Descriptions -->
				<div class="form-row">
					<div class="form-group">
						<label for="desc_ar">{isRTL ? 'الوصف (عربي)' : 'Description (Arabic)'}</label>
						<textarea
							id="desc_ar"
							bind:value={offerData.description_ar}
							placeholder={isRTL ? 'أدخل وصف العرض بالعربية' : 'Enter description in Arabic'}
							rows="3"
						></textarea>
					</div>
					<div class="form-group">
						<label for="desc_en">{isRTL ? 'الوصف (إنجليزي)' : 'Description (English)'}</label>
						<textarea
							id="desc_en"
							bind:value={offerData.description_en}
							placeholder={isRTL ? 'أدخل وصف العرض بالإنجليزية' : 'Enter description in English'}
							rows="3"
						></textarea>
					</div>
				</div>

				<h3 class="section-title">{isRTL ? 'قيمة الخصم' : 'Discount Value'}</h3>

			{#if needsTierConfiguration}
				<!-- Tier-Based Discount Configuration -->
				<div class="tier-section">
					<p class="tier-hint">
						{isRTL 
							? 'قم بإنشاء مستويات خصم متدرجة بناءً على إجمالي السلة (حتى 6 مستويات)'
							: 'Create tiered discounts based on cart total (up to 6 tiers)'}
					</p>
					<TierManager bind:tiers={cartTiers} on:change={() => {}} />
				</div>
			{:else}
				<!-- Simple Discount Configuration (for product-specific offers) -->
				<div class="form-row">
					<div class="form-group">
						<label for="discount_type">{isRTL ? 'نوع الخصم' : 'Discount Type'}</label>
						<select id="discount_type" bind:value={offerData.discount_type}>
							<option value="percentage">{isRTL ? 'نسبة مئوية (%)' : 'Percentage (%)'}</option>
							<option value="fixed">{isRTL ? 'مبلغ ثابت (ريال)' : 'Fixed Amount (SAR)'}</option>
						</select>
					</div>
					<div class="form-group">
						<label for="discount_value">{isRTL ? 'قيمة الخصم' : 'Discount Value'}</label>
						<input
							id="discount_value"
							type="number"
							min="0"
							step="0.01"
							bind:value={offerData.discount_value}
							placeholder={offerData.discount_type === 'percentage' ? '20' : '50'}
							required
						/>
					</div>
				</div>
			{/if}

				{#if offerData.type === 'bogo'}
					<h3 class="section-title">{isRTL ? 'إعدادات BOGO' : 'BOGO Settings'}</h3>
					<div class="form-row">
						<div class="form-group">
							<label for="bogo_buy">{isRTL ? 'عدد المشتريات' : 'Buy Quantity'}</label>
							<input
								id="bogo_buy"
								type="number"
								min="1"
								bind:value={offerData.bogo_buy_quantity}
								placeholder="2"
								required
							/>
						</div>
						<div class="form-group">
							<label for="bogo_get">{isRTL ? 'عدد المجانيات' : 'Get Quantity'}</label>
							<input
								id="bogo_get"
								type="number"
								min="1"
								bind:value={offerData.bogo_get_quantity}
								placeholder="1"
								required
							/>
						</div>
					</div>
				{/if}

				{#if offerData.type === 'bundle'}
					<!-- Bundle Creator -->
					<h3 class="section-title">{isRTL ? 'إدارة الحزم' : 'Manage Bundles'}</h3>
					<BundleCreator 
						bind:bundles={bundles}
						bind:this={bundleCreatorRef}
						{offerId}
						editMode={editMode}
						on:change={() => {}}
					/>
				{:else if needsProductSelection}
					<!-- Product Selector (for product/bogo offers) -->
					<h3 class="section-title">{isRTL ? 'المنتجات المشمولة في العرض' : 'Products Included in Offer'}</h3>
					
					<!-- Add Products Button -->
					<button 
						type="button" 
						class="add-products-btn"
						on:click={openProductSelector}
					>
						<span style="font-size: 1.2em;">+</span>
						{isRTL ? 'اختيار المنتجات' : 'Select Products'}
						<span class="product-count">({selectedProducts.length})</span>
					</button>
				{/if}

				<h3 class="section-title">{isRTL ? 'الفترة الزمنية' : 'Time Period'}</h3>

				<!-- Date Range -->
				<div class="form-row">
					<div class="form-group">
						<label for="start_date">{isRTL ? 'تاريخ البدء' : 'Start Date'}</label>
						<input id="start_date" type="datetime-local" bind:value={offerData.start_date} required />
					</div>
					<div class="form-group">
						<label for="end_date">{isRTL ? 'تاريخ الانتهاء' : 'End Date'}</label>
						<input id="end_date" type="datetime-local" bind:value={offerData.end_date} required />
					</div>
				</div>

				<h3 class="section-title">{isRTL ? 'النطاق والاستهداف' : 'Scope & Targeting'}</h3>

				<!-- Branch & Service Type -->
				<div class="form-row">
					<div class="form-group">
						<label for="branch">{isRTL ? 'الفرع' : 'Branch'}</label>
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
						<label for="service_type">{isRTL ? 'نوع الخدمة' : 'Service Type'}</label>
						<select id="service_type" bind:value={offerData.service_type}>
							<option value="both">{isRTL ? 'توصيل واستلام' : 'Delivery & Pickup'}</option>
							<option value="delivery">{isRTL ? 'توصيل فقط' : 'Delivery Only'}</option>
							<option value="pickup">{isRTL ? 'استلام فقط' : 'Pickup Only'}</option>
						</select>
					</div>
				</div>

				<h3 class="section-title">{isRTL ? 'الإعدادات المتقدمة' : 'Advanced Settings'}</h3>

				<!-- Limits -->
				<div class="form-row">
					<div class="form-group">
						<label for="max_uses">{isRTL ? 'الحد الأقصى للاستخدامات' : 'Max Total Uses'}</label>
						<input
							id="max_uses"
							type="number"
							min="1"
							bind:value={offerData.max_total_uses}
							placeholder={isRTL ? 'غير محدود' : 'Unlimited'}
						/>
					</div>
					<div class="form-group">
						<label for="max_uses_per_customer">{isRTL ? 'الحد الأقصى لكل عميل' : 'Max Uses Per Customer'}</label>
						<input
							id="max_uses_per_customer"
							type="number"
							min="1"
							bind:value={offerData.max_uses_per_customer}
							placeholder={isRTL ? 'غير محدود' : 'Unlimited'}
						/>
					</div>
				</div>

				<!-- Checkboxes -->
				<div class="checkboxes-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={offerData.is_active} />
						<span>{isRTL ? 'تفعيل العرض فوراً' : 'Activate offer immediately'}</span>
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={offerData.show_on_product_page} />
						<span>{isRTL ? 'عرض في صفحة المنتج' : 'Show on product page'}</span>
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={offerData.show_in_carousel} />
						<span>{isRTL ? 'عرض في الشريط الدوار' : 'Show in carousel'}</span>
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={offerData.send_push_notification} />
						<span>{isRTL ? 'إرسال إشعار فوري' : 'Send push notification'}</span>
					</label>
				</div>
			</div>
		{:else if currentStep === 3}
			<!-- Step 3: Preview -->
			<div class="preview-section">
				<h3 class="section-title">{isRTL ? 'معاينة العرض' : 'Offer Preview'}</h3>

				<div class="preview-card">
					<div class="preview-header">
						<h2>{isRTL ? offerData.name_ar : offerData.name_en}</h2>
						<div class="discount-badge">
							{offerData.discount_type === 'percentage'
								? `${offerData.discount_value}%`
								: `${offerData.discount_value} ${isRTL ? 'ريال' : 'SAR'}`}
						</div>
					</div>
					<p class="preview-desc">{isRTL ? offerData.description_ar : offerData.description_en}</p>

					<div class="preview-details">
						<div class="detail-item">
							<span class="detail-label">{isRTL ? 'النوع:' : 'Type:'}</span>
							<span class="detail-value">{offerData.type}</span>
						</div>
						<div class="detail-item">
							<span class="detail-label">{isRTL ? 'الفرع:' : 'Branch:'}</span>
							<span class="detail-value">
								{offerData.branch_id
									? branches.find((b) => b.id === offerData.branch_id)?.[
											isRTL ? 'name_ar' : 'name_en'
										]
									: isRTL
										? 'جميع الفروع'
										: 'All Branches'}
							</span>
						</div>
						<div class="detail-item">
							<span class="detail-label">{isRTL ? 'الخدمة:' : 'Service:'}</span>
							<span class="detail-value">
								{offerData.service_type === 'both'
									? isRTL
										? 'توصيل واستلام'
										: 'Delivery & Pickup'
									: offerData.service_type === 'delivery'
										? isRTL
											? 'توصيل'
											: 'Delivery'
										: isRTL
											? 'استلام'
											: 'Pickup'}
							</span>
						</div>
						<div class="detail-item">
							<span class="detail-label">{isRTL ? 'الفترة:' : 'Period:'}</span>
							<span class="detail-value">
								{new Date(offerData.start_date).toLocaleDateString(isRTL ? 'ar-SA' : 'en-US')} -
								{new Date(offerData.end_date).toLocaleDateString(isRTL ? 'ar-SA' : 'en-US')}
							</span>
						</div>
						{#if needsProductSelection && selectedProducts.length > 0}
							<div class="detail-item" style="grid-column: 1 / -1;">
								<span class="detail-label">{isRTL ? 'المنتجات:' : 'Products:'}</span>
								<div class="detail-products">
									{#each selectedProducts as product, i}
										<span class="product-tag">
											{isRTL ? product.name_ar : product.name_en}
										</span>
										{#if i < selectedProducts.length - 1}
											<span>, </span>
										{/if}
									{/each}
								</div>
							</div>
						{/if}
					</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Form Actions -->
	<div class="form-actions">
		{#if currentStep > 1}
			<button type="button" class="btn btn-secondary" on:click={prevStep} disabled={loading}>
				{isRTL ? 'السابق' : 'Previous'}
			</button>
		{/if}
		<button type="button" class="btn btn-secondary" on:click={cancel} disabled={loading}>
			{isRTL ? 'إلغاء' : 'Cancel'}
		</button>
		{#if currentStep < 3}
			<button type="button" class="btn btn-primary" on:click={nextStep} disabled={loading}>
				{isRTL ? 'التالي' : 'Next'}
			</button>
		{:else}
			<button type="button" class="btn btn-primary" on:click={handleSubmit} disabled={loading}>
				{#if loading}
					<span class="spinner"></span>
				{/if}
				{isRTL ? (editMode ? 'تحديث العرض' : 'إنشاء العرض') : editMode ? 'Update Offer' : 'Create Offer'}
			</button>
		{/if}
	</div>
</div>

<style>
	.offer-form {
		max-width: 900px;
		margin: 0 auto;
		padding: 2rem;
	}

	.offer-form.rtl {
		direction: rtl;
		text-align: right;
	}

	/* Progress Steps */
	.progress-steps {
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 3rem;
		gap: 1rem;
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
	}

	.step-number {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: #e5e7eb;
		color: #6b7280;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		transition: all 0.3s;
	}

	.step.active .step-number {
		background: #3b82f6;
		color: white;
	}

	.step.completed .step-number {
		background: #10b981;
		color: white;
	}

	.step-label {
		font-size: 0.875rem;
		color: #6b7280;
		font-weight: 500;
	}

	.step.active .step-label {
		color: #3b82f6;
	}

	.step-line {
		flex: 1;
		height: 2px;
		background: #e5e7eb;
		transition: all 0.3s;
	}

	.step-line.completed {
		background: #10b981;
	}

	/* Error Message */
	.error-message {
		background: #fee2e2;
		border: 1px solid #fecaca;
		color: #991b1b;
		padding: 1rem;
		border-radius: 8px;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 2rem;
	}

	/* Form Content */
	.form-content {
		margin-bottom: 2rem;
	}

	.form-fields {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.section-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
		margin-bottom: 1rem;
		padding-bottom: 0.5rem;
		border-bottom: 2px solid #e5e7eb;
	}

	.form-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-group label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		transition: all 0.2s;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.checkboxes-group {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-size: 0.875rem;
	}

	.checkbox-label input[type='checkbox'] {
		width: 18px;
		height: 18px;
		cursor: pointer;
	}

	/* Preview Section */
	.preview-section {
		padding: 2rem;
	}

	.preview-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 2rem;
	}

	.preview-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.preview-header h2 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0;
	}

	.discount-badge {
		background: #10b981;
		color: white;
		padding: 0.5rem 1rem;
		border-radius: 8px;
		font-size: 1.25rem;
		font-weight: 700;
	}

	.preview-desc {
		color: #6b7280;
		margin-bottom: 1.5rem;
	}

	.preview-details {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.detail-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #9ca3af;
		text-transform: uppercase;
	}

	.detail-value {
		font-size: 0.875rem;
		color: #1f2937;
		font-weight: 500;
	}

	/* Tier Section Styles */
	.tier-section {
		margin: 1.5rem 0;
	}

	.tier-hint {
		margin-bottom: 1rem;
		padding: 0.75rem;
		background: #eff6ff;
		border-left: 3px solid #3b82f6;
		border-radius: 4px;
		font-size: 0.9rem;
		color: #1e40af;
	}

	.rtl .tier-hint {
		border-left: none;
		border-right: 3px solid #3b82f6;
	}

	/* Form Actions */
	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 1rem;
		padding-top: 2rem;
		border-top: 1px solid #e5e7eb;
	}

	.btn {
		padding: 0.625rem 1.5rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: #2563eb;
	}

	.btn-secondary {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-secondary:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Product Selection Styles */
	.selected-products {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.selected-product-chip {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: #dbeafe;
		color: #1e40af;
		padding: 0.5rem 0.75rem;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.selected-product-chip .remove-btn {
		background: none;
		border: none;
		color: #1e40af;
		font-size: 1.5rem;
		line-height: 1;
		cursor: pointer;
		padding: 0;
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s;
	}

	.selected-product-chip .remove-btn:hover {
		background: #1e40af;
		color: white;
	}

	.add-products-btn {
		width: 100%;
		padding: 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: all 0.2s;
	}

	.add-products-btn:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.product-count {
		background: rgba(255, 255, 255, 0.2);
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.875rem;
	}

	.product-selector {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		width: 90%;
		max-width: 700px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		z-index: 1000;
	}

	.selector-header {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.search-input {
		flex: 1;
		padding: 0.75rem 1rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 1rem;
	}

	.close-selector-btn {
		padding: 0.75rem 1.5rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-selector-btn:hover {
		background: #dc2626;
	}

	.products-grid {
		overflow-y: auto;
		padding: 1.5rem;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
		gap: 1rem;
	}

	.product-card {
		position: relative;
		padding: 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		background: white;
	}

	.product-card:hover {
		border-color: #3b82f6;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.2);
		transform: translateY(-2px);
	}

	.product-card.selected {
		border-color: #10b981;
		background: #d1fae5;
	}

	.product-name {
		font-weight: 600;
		color: #1f2937;
		margin-bottom: 0.5rem;
	}

	.product-barcode {
		font-size: 0.75rem;
		color: #6b7280;
		margin-bottom: 0.25rem;
	}

	.product-price {
		font-size: 0.875rem;
		color: #059669;
		font-weight: 600;
	}

	.check-icon {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		width: 24px;
		height: 24px;
		background: #10b981;
		color: white;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 0.875rem;
	}

	.no-products {
		grid-column: 1 / -1;
		text-align: center;
		padding: 3rem;
		color: #6b7280;
		font-size: 1rem;
	}

	/* Preview Product Tags */
	.detail-products {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.product-tag {
		background: #dbeafe;
		color: #1e40af;
		padding: 0.25rem 0.75rem;
		border-radius: 4px;
		font-size: 0.875rem;
		font-weight: 500;
	}

	@media (max-width: 768px) {
		.offer-form {
			padding: 1rem;
		}

		.progress-steps {
			gap: 0.5rem;
		}

		.step-label {
			font-size: 0.75rem;
		}

		.form-row {
			grid-template-columns: 1fr;
		}

		.product-selector {
			width: 95%;
			max-height: 90vh;
		}

		.products-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
