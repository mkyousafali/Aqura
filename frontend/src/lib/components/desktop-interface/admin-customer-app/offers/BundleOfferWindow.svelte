<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

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
		start_date: getSaudiLocalDateTime(),
		end_date: getSaudiLocalDateTime(30),
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
	let previewImageUrl: string | null = null;

	// Get current Saudi local time in datetime-local format
	function getSaudiLocalDateTime(daysToAdd: number = 0): string {
		const now = new Date();
		// Add days if specified
		now.setDate(now.getDate() + daysToAdd);
		
		// Convert to Saudi time (UTC+3)
		const saudiTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
		
		// Format as datetime-local (YYYY-MM-DDTHH:mm)
		const year = saudiTime.getFullYear();
		const month = String(saudiTime.getMonth() + 1).padStart(2, '0');
		const day = String(saudiTime.getDate()).padStart(2, '0');
		const hours = String(saudiTime.getHours()).padStart(2, '0');
		const minutes = String(saudiTime.getMinutes()).padStart(2, '0');
		
		return `${year}-${month}-${day}T${hours}:${minutes}`;
	}

	$: isRTL = $currentLocale === 'ar';
	$: filteredProducts = products.filter(p => 
		!productSearchTerm || 
		p.barcode?.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.name_ar.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
		p.product_serial?.toLowerCase().includes(productSearchTerm.toLowerCase())
	).sort((a, b) => {
		const serialA = a.product_serial || '';
		const serialB = b.product_serial || '';
		return serialA.localeCompare(serialB);
	});

	onMount(async () => {
		await loadBranches();
		await loadProductsData();
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

	// Convert Saudi time from datetime-local input to UTC for database storage
	function toUTCFromSaudiInput(saudiTimeString) {
		// Parse the datetime-local input (assumed to be Saudi time)
		const [datePart, timePart] = saudiTimeString.split('T');
		const [year, month, day] = datePart.split('-').map(Number);
		const [hours, minutes] = timePart.split(':').map(Number);
		
		// Create ISO string for Saudi timezone and parse it
		const saudiISOString = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;
		
		// Parse as if it's UTC, then subtract 3 hours (Saudi is UTC+3)
		const tempDate = new Date(saudiISOString + 'Z');
		const utcDate = new Date(tempDate.getTime() - (3 * 60 * 60 * 1000));
		
		return utcDate.toISOString();
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

	async function loadProductsData() {
		loading = true;
		try {
			const { data, error: err } = await supabase.rpc('get_offer_products_data', {
				p_exclude_offer_id: offerId || 0
			});

			if (err) {
				console.error('Error loading products data:', err);
				return;
			}

			if (data) {
				const usedProductIds = new Set(data.products_in_other_offers || []);

				products = (data.products || [])
					.filter((p: any) => !usedProductIds.has(p.id))
					.map((p: any) => ({
						id: p.id,
						name_ar: p.name_ar || p.product_name_ar,
						name_en: p.name_en || p.product_name_en,
						barcode: p.barcode,
						product_serial: p.product_serial || p.barcode || '',
						price: parseFloat(p.price) || parseFloat(p.sale_price) || 0,
						cost: parseFloat(p.cost) || 0,
						unit_name_en: p.unit_name_en || '',
						unit_name_ar: p.unit_name_ar || '',
						unit_qty: p.unit_qty || 1,
						image_url: p.image_url,
						stock: p.current_stock || 0
					}));
			}
		} finally {
			loading = false;
		}
	}

	async function loadBundles() {
		if (!offerId) return;

		const { data, error: err } = await supabase
			.from('offer_bundles')
			.select('*')
			.eq('offer_id', offerId);

		if (!err && data) {
			bundles = data.map(b => {
				// Enrich bundle products with full product details
				const enrichedProducts = (b.required_products || []).map(bp => {
					const product = products.find(p => p.id === bp.product_id);
					if (!product) return bp;
					
					return {
						...bp,
						product_id: bp.product_id,
						product_name_ar: product.product_name_ar || product.name_ar,
						product_name_en: product.product_name_en || product.name_en,
						product_barcode: product.barcode,
						product_price: product.sale_price || product.price,
						product_image: product.image_url
					};
				});
				
				return {
					id: b.id,
					name_ar: b.bundle_name_ar,
					name_en: b.bundle_name_en,
					products: enrichedProducts,
					total_price: calculateBundleTotalPrice(b.required_products || [])
				};
			});
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
				start_date: toUTCFromSaudiInput(offerData.start_date),
				end_date: toUTCFromSaudiInput(offerData.end_date),
				branch_id: offerData.branch_id,
				service_type: offerData.service_type,
				is_active: offerData.is_active,
				show_on_product_page: true,
				show_in_carousel: true,
				send_push_notification: false
			};

			let savedOfferId = offerId;

			if (editMode && offerId) {
				// Update existing offer
				const { error: updateError } = await supabase
					.from('offers')
					.update(offerPayload)
					.eq('id', offerId);

				if (updateError) throw updateError;

				// Delete existing bundles
				await supabase
					.from('offer_bundles')
					.delete()
					.eq('offer_id', offerId);
			} else {
				// Create new offer
				const { data, error: insertError } = await supabase
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

				const { error: bundleError } = await supabase
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

<!-- svelte-ignore a11y-click-events-have-key-events -->
<div class="relative flex flex-col h-full overflow-hidden" class:rtl={isRTL} dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Decorative Blur Orbs -->
	<div class="pointer-events-none absolute -top-32 -right-32 h-96 w-96 rounded-full bg-teal-400/20 blur-3xl"></div>
	<div class="pointer-events-none absolute -bottom-32 -left-32 h-96 w-96 rounded-full bg-cyan-400/20 blur-3xl"></div>

	<!-- Header -->
	<div class="relative flex-shrink-0 bg-gradient-to-r from-teal-500 to-cyan-500 px-6 py-5 text-white">
		<h2 class="m-0 text-xl font-bold tracking-tight">
			{editMode
				? isRTL ? '📦 تعديل عرض حزمة' : '📦 Edit Bundle Offer'
				: isRTL ? '📦 إنشاء عرض حزمة' : '📦 Create Bundle Offer'}
		</h2>
		<!-- Step Indicator -->
		<div class="mt-4 flex items-center gap-3">
			<div class="flex items-center gap-2">
				<div class="flex h-8 w-8 items-center justify-center rounded-full text-sm font-bold transition-all {currentStep === 1 ? 'bg-white text-teal-600 shadow-lg' : currentStep > 1 ? 'bg-teal-300 text-teal-800' : 'bg-white/30 text-white/70'}">1</div>
				<span class="text-sm font-medium {currentStep === 1 ? 'text-white' : 'text-white/70'}">{isRTL ? 'تفاصيل العرض' : 'Offer Details'}</span>
			</div>
			<div class="h-0.5 flex-1 rounded-full {currentStep > 1 ? 'bg-white/80' : 'bg-white/30'}"></div>
			<div class="flex items-center gap-2">
				<div class="flex h-8 w-8 items-center justify-center rounded-full text-sm font-bold transition-all {currentStep === 2 ? 'bg-white text-teal-600 shadow-lg' : 'bg-white/30 text-white/70'}">2</div>
				<span class="text-sm font-medium {currentStep === 2 ? 'text-white' : 'text-white/70'}">{isRTL ? 'إدارة الحزم' : 'Bundle Management'}</span>
			</div>
		</div>
	</div>

	<!-- Error Banner -->
	{#if error}
		<div class="flex-shrink-0 flex items-center gap-3 bg-red-50 border-b-2 border-red-200 px-6 py-3 text-red-700">
			<span class="text-lg">⚠️</span>
			<span class="text-sm font-medium">{error}</span>
		</div>
	{/if}

	<!-- Content -->
	<div class="relative flex-1 overflow-y-auto p-6">
		{#if currentStep === 1}
			<!-- Step 1: Offer Details -->
			<div class="rounded-2xl bg-white/60 backdrop-blur-xl border border-white/40 shadow-xl p-6">
				<h3 class="text-base font-semibold text-slate-800 mb-4 pb-2 border-b border-slate-200">
					{isRTL ? 'معلومات العرض الأساسية' : 'Basic Offer Information'}
				</h3>

				<!-- Offer Names -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
					<div class="flex flex-col gap-1.5">
						<label for="name_ar" class="text-sm font-medium text-slate-700 flex items-center gap-1">
							{isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'}
							<span class="text-red-500 font-bold">*</span>
						</label>
						<input id="name_ar" type="text" bind:value={offerData.name_ar}
							placeholder={isRTL ? 'أدخل اسم العرض بالعربية' : 'Enter offer name in Arabic'}
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" required />
					</div>
					<div class="flex flex-col gap-1.5">
						<label for="name_en" class="text-sm font-medium text-slate-700 flex items-center gap-1">
							{isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'}
							<span class="text-red-500 font-bold">*</span>
						</label>
						<input id="name_en" type="text" bind:value={offerData.name_en}
							placeholder={isRTL ? 'أدخل اسم العرض بالإنجليزية' : 'Enter offer name in English'}
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" required />
					</div>
				</div>

				<!-- Descriptions -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
					<div class="flex flex-col gap-1.5">
						<label for="desc_ar" class="text-sm font-medium text-slate-700">
							{isRTL ? 'الوصف (عربي)' : 'Description (Arabic)'}
						</label>
						<textarea id="desc_ar" bind:value={offerData.description_ar}
							placeholder={isRTL ? 'أدخل وصف العرض بالعربية' : 'Enter description in Arabic'}
							rows="3"
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 resize-y min-h-[80px]"></textarea>
					</div>
					<div class="flex flex-col gap-1.5">
						<label for="desc_en" class="text-sm font-medium text-slate-700">
							{isRTL ? 'الوصف (إنجليزي)' : 'Description (English)'}
						</label>
						<textarea id="desc_en" bind:value={offerData.description_en}
							placeholder={isRTL ? 'أدخل وصف العرض بالإنجليزية' : 'Enter description in English'}
							rows="3"
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 resize-y min-h-[80px]"></textarea>
					</div>
				</div>

				<h3 class="text-base font-semibold text-slate-800 mb-4 pb-2 border-b border-slate-200">
					{isRTL ? 'الفترة الزمنية' : 'Time Period'}
				</h3>

				<!-- Date Range -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
					<div class="flex flex-col gap-1.5">
						<label for="start_date" class="text-sm font-medium text-slate-700 flex items-center gap-1">
							{isRTL ? 'تاريخ البدء' : 'Start Date & Time'}
							<span class="text-red-500 font-bold">*</span>
							<span class="text-xs text-slate-500 font-normal">({isRTL ? 'التوقيت السعودي' : 'Saudi Time Zone'})</span>
						</label>
						<input id="start_date" type="datetime-local" bind:value={offerData.start_date}
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" required />
					</div>
					<div class="flex flex-col gap-1.5">
						<label for="end_date" class="text-sm font-medium text-slate-700 flex items-center gap-1">
							{isRTL ? 'تاريخ الانتهاء' : 'End Date & Time'}
							<span class="text-red-500 font-bold">*</span>
							<span class="text-xs text-slate-500 font-normal">({isRTL ? 'التوقيت السعودي' : 'Saudi Time Zone'})</span>
						</label>
						<input id="end_date" type="datetime-local" bind:value={offerData.end_date}
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" required />
					</div>
				</div>

				<h3 class="text-base font-semibold text-slate-800 mb-4 pb-2 border-b border-slate-200">
					{isRTL ? 'النطاق والاستهداف' : 'Scope & Targeting'}
				</h3>

				<!-- Branch & Service Type -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
					<div class="flex flex-col gap-1.5">
						<label for="branch" class="text-sm font-medium text-slate-700">
							{isRTL ? 'الفرع المستهدف' : 'Target Branch'}
						</label>
						<select id="branch" bind:value={offerData.branch_id}
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20">
							<option value={null}>{isRTL ? 'جميع الفروع' : 'All Branches'}</option>
							{#each branches as branch}
								<option value={branch.id}>{isRTL ? branch.name_ar : branch.name_en}</option>
							{/each}
						</select>
					</div>
					<div class="flex flex-col gap-1.5">
						<label for="service_type" class="text-sm font-medium text-slate-700">
							{isRTL ? 'نوع الخدمة' : 'Service Type'}
						</label>
						<select id="service_type" bind:value={offerData.service_type}
							class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20">
							<option value="both">{isRTL ? 'التوصيل والاستلام' : 'Delivery & Pickup'}</option>
							<option value="delivery">{isRTL ? 'التوصيل فقط' : 'Delivery Only'}</option>
							<option value="pickup">{isRTL ? 'الاستلام فقط' : 'Pickup Only'}</option>
						</select>
					</div>
				</div>
			</div>

		{:else if currentStep === 2}
			<!-- Step 2: Bundle Management -->
			{#if !showAddBundleForm}
				<!-- Bundle List View -->
				<div class="flex items-center justify-between mb-5">
					<h3 class="text-base font-semibold text-slate-800">
						{isRTL ? 'إدارة الحزم' : 'Bundle Management'}
					</h3>
					<button type="button" on:click={openAddBundleModal}
						class="inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-teal-500 to-cyan-500 px-5 py-2.5 text-sm font-semibold text-white shadow-lg shadow-teal-500/25 transition-all hover:shadow-xl hover:shadow-teal-500/30 hover:-translate-y-0.5 active:scale-95">
						+ {isRTL ? 'إضافة حزمة' : 'Add Bundle'}
					</button>
				</div>

				{#if bundles.length === 0}
					<!-- Empty State -->
					<div class="rounded-2xl bg-white/60 backdrop-blur-xl border border-white/40 shadow-xl p-12 text-center">
						<div class="text-6xl mb-4">📦</div>
						<p class="text-lg font-medium text-slate-600 mb-1">
							{isRTL ? 'لم يتم إضافة أي حزم بعد' : 'No bundles added yet'}
						</p>
						<p class="text-sm text-slate-400">
							{isRTL ? 'انقر على "إضافة حزمة" لإنشاء حزمة جديدة' : 'Click "Add Bundle" to create a new bundle'}
						</p>
					</div>
				{:else}
					<!-- Bundle Cards Grid -->
					<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
						{#each bundles as bundle, index}
							<div class="rounded-2xl bg-white/60 backdrop-blur-xl border border-white/40 shadow-lg hover:shadow-xl hover:border-teal-300 transition-all p-5">
								<!-- Card Header -->
								<div class="flex items-center justify-between mb-3 pb-3 border-b border-slate-200">
									<h4 class="text-base font-semibold text-slate-800 truncate {isRTL ? 'ml-2' : 'mr-2'}">
										{isRTL ? bundle.name_ar : bundle.name_en}
									</h4>
									<div class="flex items-center gap-1.5 flex-shrink-0">
										<button type="button" on:click={() => editBundle(index)}
											title={isRTL ? 'تعديل' : 'Edit'}
											class="rounded-lg border border-teal-300 bg-teal-50 px-2.5 py-1.5 text-base transition-all hover:bg-teal-500 hover:text-white hover:scale-105">
											✏️
										</button>
										<button type="button" on:click={() => deleteBundle(index)}
											title={isRTL ? 'حذف' : 'Delete'}
											class="rounded-lg border border-red-300 bg-red-50 px-2.5 py-1.5 text-base transition-all hover:bg-red-500 hover:text-white hover:scale-105">
											🗑️
										</button>
									</div>
								</div>
								<!-- Card Body -->
								<div class="space-y-2">
									<div class="text-sm text-slate-500">
										{bundle.products.length} {isRTL ? 'منتجات' : 'Products'}
									</div>
									<div class="text-2xl font-bold text-teal-600">
										{bundle.total_price.toFixed(2)} <span class="text-sm font-medium">{isRTL ? 'ريال' : 'SAR'}</span>
									</div>
									<div class="space-y-1.5 pt-2">
										{#each bundle.products as product}
											<div class="flex items-center justify-between rounded-lg bg-slate-50/80 px-3 py-2 text-xs">
												<span class="text-slate-700 truncate {isRTL ? 'ml-2' : 'mr-2'}">
													{isRTL ? product.product_name_ar : product.product_name_en}
												</span>
												<span class="font-semibold text-teal-600 flex-shrink-0">x{product.quantity}</span>
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
				<div class="rounded-2xl bg-white/60 backdrop-blur-xl border border-white/40 shadow-xl p-6">
					<!-- Form Header -->
					<div class="flex items-center justify-between mb-5 pb-3 border-b border-slate-200">
						<h3 class="text-base font-semibold text-slate-800">
							{isRTL ? 'إضافة حزمة جديدة' : 'Add New Bundle'}
						</h3>
						<button type="button" on:click={closeAddBundleModal}
							class="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white/80 px-4 py-2 text-sm font-medium text-slate-600 transition-all hover:bg-slate-100">
							{isRTL ? '← رجوع' : '← Back'}
						</button>
					</div>

					<!-- Bundle Names -->
					<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-5">
						<div class="flex flex-col gap-1.5">
							<span class="text-sm font-medium text-slate-700 flex items-center gap-1">
								{isRTL ? 'اسم الحزمة (عربي)' : 'Bundle Name (Arabic)'}
								<span class="text-red-500 font-bold">*</span>
							</span>
							<input type="text" bind:value={currentBundle.name_ar}
								placeholder={isRTL ? 'أدخل اسم الحزمة' : 'Enter bundle name'}
								class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" />
						</div>
						<div class="flex flex-col gap-1.5">
							<span class="text-sm font-medium text-slate-700 flex items-center gap-1">
								{isRTL ? 'اسم الحزمة (إنجليزي)' : 'Bundle Name (English)'}
								<span class="text-red-500 font-bold">*</span>
							</span>
							<input type="text" bind:value={currentBundle.name_en}
								placeholder={isRTL ? 'أدخل اسم الحزمة' : 'Enter bundle name'}
								class="w-full rounded-lg border border-slate-300 bg-white/80 px-3 py-2.5 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" />
						</div>
					</div>

					<!-- Search Bar -->
					<div class="mb-5">
						<input type="text" bind:value={productSearchTerm}
							placeholder={isRTL ? 'البحث بالباركود أو اسم المنتج...' : 'Search by barcode or product name...'}
							class="w-full rounded-xl border border-slate-300 bg-white/80 px-4 py-3 text-sm outline-none transition-all focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20" />
					</div>

					<!-- Selected Products Section -->
					{#if selectedProductsForBundle.length > 0}
						<div class="rounded-xl bg-teal-50/50 border border-teal-200/60 p-5 mb-5">
							<h4 class="text-sm font-semibold text-slate-800 mb-3">
								{isRTL ? 'المنتجات المحددة' : 'Selected Products'} ({selectedProductsForBundle.length})
							</h4>
							<div class="space-y-3 mb-4">
								{#each selectedProductsForBundle as item, index}
									<div class="rounded-xl bg-white/80 border border-slate-200 p-4">
										<!-- Product Info Row -->
										<div class="flex items-center gap-3 mb-3 pb-3 border-b border-slate-100">
											{#if item.product_image}
												<button type="button" on:click={() => previewImageUrl = item.product_image}
													class="flex-shrink-0 cursor-pointer border-0 bg-transparent p-0">
													<img src={item.product_image} alt={item.product_name_en}
														class="h-14 w-14 rounded-lg object-cover ring-2 ring-teal-200 hover:ring-teal-400 transition-all" />
												</button>
											{:else}
												<div class="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-lg bg-slate-100 text-xs text-slate-400">
													No Image
												</div>
											{/if}
											<div class="flex-1 min-w-0">
												<div class="text-sm font-semibold text-slate-800 truncate">{isRTL ? item.product_name_ar : item.product_name_en}</div>
												<div class="text-xs text-slate-500">{item.product_barcode}</div>
												<div class="text-sm font-semibold text-teal-600">{item.product_price} {isRTL ? 'ريال' : 'SAR'}</div>
											</div>
											<button type="button" on:click={() => removeProductFromBundle(index)}
												class="flex-shrink-0 rounded-lg bg-red-50 border border-red-200 px-2.5 py-1.5 text-red-600 font-bold text-sm transition-all hover:bg-red-500 hover:text-white hover:border-red-500">
												✕
											</button>
										</div>
										<!-- Config Row -->
										<div class="grid grid-cols-3 gap-3">
											<div class="flex flex-col gap-1">
												<span class="text-xs font-medium text-slate-600">{isRTL ? 'الكمية' : 'Quantity'}</span>
												<input type="number" min="1" bind:value={item.quantity}
													class="w-full rounded-lg border border-slate-300 bg-white px-2.5 py-2 text-sm outline-none focus:border-teal-500 focus:ring-1 focus:ring-teal-500/20" />
											</div>
											<div class="flex flex-col gap-1">
												<span class="text-xs font-medium text-slate-600">{isRTL ? 'نوع الخصم' : 'Discount Type'}</span>
												<select bind:value={item.discount_type}
													class="w-full rounded-lg border border-slate-300 bg-white px-2.5 py-2 text-sm outline-none focus:border-teal-500 focus:ring-1 focus:ring-teal-500/20">
													<option value="percentage">{isRTL ? 'نسبة مئوية' : 'Percentage'}</option>
													<option value="amount">{isRTL ? 'مبلغ ثابت' : 'Amount'}</option>
												</select>
											</div>
											<div class="flex flex-col gap-1">
												<span class="text-xs font-medium text-slate-600">{isRTL ? 'قيمة الخصم' : 'Discount Value'}</span>
												<input type="number" min="0" step="0.01" bind:value={item.discount_value} placeholder="0"
													class="w-full rounded-lg border border-slate-300 bg-white px-2.5 py-2 text-sm outline-none focus:border-teal-500 focus:ring-1 focus:ring-teal-500/20" />
											</div>
										</div>
									</div>
								{/each}
							</div>

							<!-- Calculate & Save Buttons -->
							<div class="flex flex-wrap items-center gap-3 pt-3 border-t border-teal-200/60">
								<button type="button" on:click={calculateBundlePrice}
									disabled={selectedProductsForBundle.length < 2}
									class="inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-amber-500 to-yellow-500 px-5 py-2.5 text-sm font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
									💰 {isRTL ? 'حساب سعر الحزمة' : 'Calculate Bundle Price'}
								</button>
								{#if calculatedBundlePrice !== null}
									<div class="text-base text-slate-700">
										{isRTL ? 'السعر الإجمالي:' : 'Total Price:'}
										<strong class="text-xl text-teal-600 {isRTL ? 'mr-1' : 'ml-1'}">{calculatedBundlePrice.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</strong>
									</div>
									<button type="button" on:click={saveBundle}
										class="inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-500 to-green-500 px-5 py-2.5 text-sm font-semibold text-white shadow-lg transition-all hover:shadow-xl hover:-translate-y-0.5">
										✓ {isRTL ? 'حفظ الحزمة' : 'Save Bundle'}
									</button>
								{/if}
							</div>
						</div>
					{/if}

					<!-- Available Products Table -->
					<div>
						<h4 class="text-sm font-semibold text-slate-800 mb-3">
							{isRTL ? 'المنتجات المتاحة' : 'Available Products'} ({filteredProducts.length})
						</h4>
						<div class="overflow-hidden rounded-xl border border-slate-200/80 shadow-sm">
							<div class="max-h-[calc(100vh-400px)] overflow-y-auto">
								<table class="w-full border-collapse text-sm">
									<thead class="sticky top-0 z-10">
										<tr class="bg-gradient-to-r from-slate-700 to-slate-800 text-white">
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'التسلسل' : 'Serial'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'الباركود' : 'Barcode'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'الصورة' : 'Image'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'اسم المنتج (EN)' : 'Product (EN)'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'اسم المنتج (AR)' : 'Product (AR)'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'المخزون' : 'Stock'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'الوحدة' : 'Unit'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'كمية' : 'Qty'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'التكلفة' : 'Cost'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'السعر' : 'Price'}</th>
											<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'إجراء' : 'Action'}</th>
										</tr>
									</thead>
									<tbody>
										{#each filteredProducts as product}
											<tr class="border-b border-slate-100 transition-colors hover:bg-teal-50/40">
												<td class="px-3 py-2.5 text-slate-600">{product.product_serial}</td>
												<td class="px-3 py-2.5 font-mono text-xs text-slate-600">{product.barcode || '-'}</td>
												<td class="px-3 py-2.5">
													{#if product.image_url}
														<button type="button" on:click={() => previewImageUrl = product.image_url}
															class="border-0 bg-transparent p-0 cursor-pointer">
															<img src={product.image_url} alt={product.name_en}
																class="h-10 w-10 rounded-md object-cover ring-1 ring-slate-200 hover:ring-teal-400 transition-all" />
														</button>
													{:else}
														<div class="flex h-10 w-10 items-center justify-center rounded-md bg-slate-100 text-[10px] text-slate-400">
															No Image
														</div>
													{/if}
												</td>
												<td class="px-3 py-2.5 text-slate-700 max-w-[160px] truncate">{product.name_en}</td>
												<td class="px-3 py-2.5 text-slate-700 max-w-[160px] truncate">{product.name_ar}</td>
												<td class="px-3 py-2.5 text-slate-600">{product.stock}</td>
												<td class="px-3 py-2.5 text-slate-600">{isRTL ? product.unit_name_ar : product.unit_name_en}</td>
												<td class="px-3 py-2.5 text-slate-600">{product.unit_qty}</td>
												<td class="px-3 py-2.5 text-slate-600">{product.cost.toFixed(2)}</td>
												<td class="px-3 py-2.5 font-semibold text-teal-600">{product.price.toFixed(2)}</td>
												<td class="px-3 py-2.5">
													<button type="button" on:click={() => selectProductForBundle(product)}
														disabled={selectedProductsForBundle.some(p => p.product_id === product.id)}
														class="rounded-lg bg-gradient-to-r from-teal-500 to-cyan-500 px-3 py-1.5 text-xs font-semibold text-white transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:translate-y-0">
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
				</div>
			{/if}
		{/if}
	</div>

	<!-- Footer Actions -->
	<div class="relative flex-shrink-0 flex items-center justify-between border-t border-slate-200/80 bg-white/60 backdrop-blur-xl px-6 py-4">
		<div>
			{#if currentStep > 1}
				<button type="button" on:click={previousStep}
					class="rounded-xl border border-slate-300 bg-white/80 px-5 py-2.5 text-sm font-semibold text-slate-600 transition-all hover:bg-slate-100">
					{isRTL ? '← السابق' : '← Previous'}
				</button>
			{/if}
		</div>
		<div class="flex items-center gap-3">
			<button type="button" on:click={cancel}
				class="rounded-xl border border-slate-300 bg-white/80 px-5 py-2.5 text-sm font-medium text-slate-500 transition-all hover:bg-slate-100 hover:border-slate-400">
				{isRTL ? 'إلغاء' : 'Cancel'}
			</button>
			{#if currentStep === 1}
				<button type="button" on:click={nextStep}
					class="rounded-xl bg-gradient-to-r from-teal-500 to-cyan-500 px-6 py-2.5 text-sm font-semibold text-white shadow-lg shadow-teal-500/25 transition-all hover:shadow-xl hover:shadow-teal-500/30 hover:-translate-y-0.5">
					{isRTL ? 'التالي →' : 'Next →'}
				</button>
			{:else}
				<button type="button" on:click={saveOffer}
					disabled={loading || bundles.length === 0}
					class="rounded-xl bg-gradient-to-r from-emerald-500 to-green-500 px-6 py-2.5 text-sm font-semibold text-white shadow-lg shadow-emerald-500/25 transition-all hover:shadow-xl hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
					{loading ? (isRTL ? 'جاري الحفظ...' : 'Saving...') : (isRTL ? 'حفظ العرض' : 'Save Offer')}
				</button>
			{/if}
		</div>
	</div>
</div>

<!-- Image Preview Overlay -->
{#if previewImageUrl}
	<button type="button" class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm border-0 p-0 cursor-default"
		on:click={() => previewImageUrl = null} aria-label="Close preview">
		<img src={previewImageUrl} alt="Preview" class="max-h-[85vh] max-w-[85vw] rounded-2xl shadow-2xl object-contain" />
	</button>
{/if}

<style>
	/* Tailwind handles all styling */
	.rtl { direction: rtl; }
</style>
