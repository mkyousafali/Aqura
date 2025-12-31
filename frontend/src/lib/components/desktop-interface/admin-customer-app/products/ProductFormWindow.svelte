<script lang="ts">
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { translateText } from '$lib/utils/translationService';
	import CategoryFormWindow from '$lib/components/desktop-interface/admin-customer-app/products/CategoryFormWindow.svelte';
	import BaseUnitFormWindow from '$lib/components/desktop-interface/admin-customer-app/products/BaseUnitFormWindow.svelte';

	// Export prop for editing existing product
	export let productData: any = null;

	let productNameEn = '';
	let productNameAr = '';
	let selectedCategory = '';
	let selectedTax = '';
	let productSerial = '';
	let categories: Array<{id: string, name_en: string, name_ar: string}> = [];
	let baseUnits: Array<{id: string, name_en: string, name_ar: string}> = [];
	let taxes: Array<{id: string, name_en: string, name_ar: string, percentage: number}> = [];
	let isTranslating = false;
	let translationError = '';
	let validationError = '';
	let useAutoTranslate = false;
	let loadingCategories = false;
	let generatingSerial = false;
	let editMode = false;

	// Product units/variants data
	let productUnits: Array<{
		id: string;
		unit: string;
		barcode: string;
		unitQty: string;
		salePrice: string;
		cost: string;
		profit: string;
		profitPercentage: string;
		minimQty: string;
		minimumQtyAlert: string;
		maximumQty: string;
		imageUrl: string;
	}> = [];

	onMount(async () => {
		await loadCategories();
		await loadBaseUnits();
		await loadTaxes();
		
		// If editing, populate the form with product data
		if (productData) {
			await populateFormForEdit();
		}
		
		// Listen for new categories created
		window.addEventListener('category-created', handleCategoryCreated);
		
		return () => {
			window.removeEventListener('category-created', handleCategoryCreated);
		};
	});

	async function populateFormForEdit() {
		editMode = true;
		
		// Set basic product info
		productNameEn = productData.product_name_en;
		productNameAr = productData.product_name_ar;
		selectedCategory = productData.category_id;
		selectedTax = productData.tax_category_id;
		productSerial = productData.product_serial;
		
		// Load all units for this product serial
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('products')
				.select('*')
				.eq('product_serial', productData.product_serial)
				.order('unit_qty');

			if (error) throw error;
			
			// Populate productUnits array with existing data
			if (data && data.length > 0) {
				productUnits = data.map(unit => ({
					id: unit.id,
					unit: unit.unit_id,
					barcode: unit.barcode || '',
					unitQty: unit.unit_qty.toString(),
					salePrice: unit.sale_price.toString(),
					cost: unit.cost.toString(),
					profit: unit.profit.toString(),
					profitPercentage: unit.profit_percentage.toString(),
					minimQty: unit.minim_qty.toString(),
					minimumQtyAlert: unit.minimum_qty_alert.toString(),
					maximumQty: unit.maximum_qty.toString(),
					imageUrl: unit.image_url || ''
				}));
			}
		} catch (error) {
			console.error('Error loading product units:', error);
			alert('Failed to load product units for editing');
		}
	}

	async function loadBaseUnits() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('product_units')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			
			baseUnits = data || [];
		} catch (error) {
			console.error('Error loading base units:', error);
		}
	}

	async function loadTaxes() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('tax_categories')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			
			taxes = data || [];
		} catch (error) {
			console.error('Error loading taxes:', error);
		}
	}

	async function loadCategories() {
		loadingCategories = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('product_categories')
				.select('*')
				.eq('is_active', true)
				.order('display_order');

			if (error) throw error;
			
			categories = data || [];
		} catch (error) {
			console.error('Error loading categories:', error);
		} finally {
			loadingCategories = false;
		}
	}

	function handleCategoryCreated(event: any) {
		const newCategory = event.detail;
		// Add to list temporarily (will be refreshed from DB)
		loadCategories();
	}

	async function handleEnglishInput() {
		if (!useAutoTranslate || !productNameEn.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			productNameAr = await translateText({
				text: productNameEn,
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
		if (!useAutoTranslate || !productNameAr.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			productNameEn = await translateText({
				text: productNameAr,
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

	async function translateEnglishToArabic() {
		if (!productNameEn.trim()) {
			alert('Please enter English product name first');
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			productNameAr = await translateText({
				text: productNameEn,
				targetLanguage: 'ar',
				sourceLanguage: 'en'
			});
		} catch (error: any) {
			translationError = error.message || 'Translation failed';
			console.error('Translation error:', error);
			alert('Translation failed: ' + error.message);
		} finally {
			isTranslating = false;
		}
	}

	async function translateArabicToEnglish() {
		if (!productNameAr.trim()) {
			alert('Please enter Arabic product name first');
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			productNameEn = await translateText({
				text: productNameAr,
				targetLanguage: 'en',
				sourceLanguage: 'ar'
			});
		} catch (error: any) {
			translationError = error.message || 'Translation failed';
			console.error('Translation error:', error);
			alert('Translation failed: ' + error.message);
		} finally {
			isTranslating = false;
		}
	}

	async function translateProductName() {
		// Determine which field to translate from
		if (productNameEn.trim() && !productNameAr.trim()) {
			// Translate English to Arabic
			await translateEnglishToArabic();
		} else if (productNameAr.trim() && !productNameEn.trim()) {
			// Translate Arabic to English
			await translateArabicToEnglish();
		} else if (productNameEn.trim()) {
			// Default: translate English to Arabic if both exist
			await translateEnglishToArabic();
		} else {
			alert('Please enter a product name in English or Arabic first');
		}
	}

	function toggleAutoTranslate() {
		useAutoTranslate = !useAutoTranslate;
	}

	function openCreateCategory() {
		const windowId = `create-category-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Category #${instanceNumber}`,
			component: CategoryFormWindow,
			icon: '🏷️',
			size: { width: 600, height: 400 },
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

	function handleSave() {
		if (!productNameEn.trim() || !productNameAr.trim()) {
			alert('Please fill in both English and Arabic product names');
			return;
		}

		if (!selectedCategory) {
			alert('Please select a category');
			return;
		}

		// Generate serial and save product
		saveProduct();
	}

	async function saveProduct() {
		generatingSerial = true;
		
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			// Validate we have at least one unit
			if (productUnits.length === 0) {
				alert('Please add at least one product unit');
				return;
			}
			
			// Get category and tax details
			const category = categories.find(c => c.id === selectedCategory);
			const taxCategory = taxes.find(t => t.id === selectedTax);
			
			if (!category || !taxCategory) {
				alert('Category or Tax Category not found');
				return;
			}
			
			let serial = productSerial;
			
			// If creating new product, generate serial
			if (!editMode) {
				// Get the latest product serial number to generate next
				const { data: lastProduct, error: fetchError } = await supabase
					.from('products')
					.select('product_serial')
					.order('product_serial', { ascending: false })
					.limit(1);

				if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 = table doesn't exist yet
					throw fetchError;
				}

				let nextNumber = 1;
				
				if (lastProduct && lastProduct.length > 0 && lastProduct[0].product_serial) {
					// Extract number from last serial (e.g., "UR0001" -> 1)
					const lastSerial = lastProduct[0].product_serial;
					const match = lastSerial.match(/UR(\d+)/);
					if (match) {
						nextNumber = parseInt(match[1]) + 1;
					}
				}

				// Format as UR0001, UR0002, etc.
				serial = `UR${nextNumber.toString().padStart(4, '0')}`;
				productSerial = serial;
			}
			
			// If editing, delete existing units first
			if (editMode) {
				const { error: deleteError } = await supabase
					.from('products')
					.delete()
					.eq('product_serial', serial);
				
				if (deleteError) throw deleteError;
			}
			
			// Prepare products data for insertion
			const productsToInsert = productUnits.map(unit => {
				const unitData = baseUnits.find(u => u.id === unit.unit);
				
				return {
					product_serial: serial,
					product_name_en: productNameEn,
					product_name_ar: productNameAr,
					category_id: selectedCategory,
					category_name_en: category.name_en,
					category_name_ar: category.name_ar,
					tax_category_id: selectedTax,
					tax_category_name_en: taxCategory.name_en,
					tax_category_name_ar: taxCategory.name_ar,
					tax_percentage: taxCategory.percentage,
					unit_id: unit.unit,
					unit_name_en: unitData?.name_en || '',
					unit_name_ar: unitData?.name_ar || '',
					unit_qty: parseFloat(unit.unitQty) || 1,
					barcode: unit.barcode || null,
					sale_price: parseFloat(unit.salePrice) || 0,
					cost: parseFloat(unit.cost) || 0,
					profit: parseFloat(unit.profit) || 0,
					profit_percentage: parseFloat(unit.profitPercentage) || 0,
					current_stock: 0, // Default stock
					minim_qty: parseInt(unit.minimQty) || 0,
					minimum_qty_alert: parseInt(unit.minimumQtyAlert) || 0,
					maximum_qty: parseInt(unit.maximumQty) || 0,
					image_url: unit.imageUrl || null,
					is_active: true
				};
			});
			
			// Insert all units
			const { error: insertError } = await supabase
				.from('products')
				.insert(productsToInsert);
			
			if (insertError) throw insertError;
			
			alert(`Product ${editMode ? 'updated' : 'saved'} successfully with serial: ${serial}`);
			
			// Trigger refresh in ManageProductsWindow if it exists
			window.dispatchEvent(new CustomEvent('product-saved'));
			
		} catch (error) {
			console.error('Error saving product:', error);
			alert('Failed to save product: ' + error.message);
		} finally {
			generatingSerial = false;
		}
	}

	function addProductUnit() {
		// Clear previous validation error
		validationError = '';
		
		// Validate required fields before adding unit
		if (!productNameEn.trim()) {
			validationError = 'Please enter Product Name in English first';
			return;
		}
		
		if (!productNameAr.trim()) {
			validationError = 'Please enter Product Name in Arabic first';
			return;
		}
		
		if (!selectedCategory) {
			validationError = 'Please select a Category first';
			return;
		}
		
		if (!selectedTax) {
			validationError = 'Please select a Tax Category first';
			return;
		}
		
		const newUnit = {
			id: `unit-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
			unit: '',
			barcode: '',
			unitQty: '',
			salePrice: '',
			cost: '',
			profit: '',
			profitPercentage: '',
			minimQty: '',
			minimumQtyAlert: '',
			maximumQty: '',
			imageUrl: ''
		};
		productUnits = [...productUnits, newUnit];
	}

	function deleteProductUnit(index: number) {
		productUnits = productUnits.filter((_, i) => i !== index);
	}

	// Auto-calculate sale price and cost based on first unit
	function handleUnitQtyChange(index: number) {
		const currentUnit = productUnits[index];
		
		// Auto-calculate quantities based on current unit's Unit Qty
		// Minim Qty = Unit Qty × 2
		// Minimum Qty Alert = Minim Qty × 2 = Unit Qty × 4
		// Maximum Qty = Minimum Qty Alert × 2 = Unit Qty × 8
		if (currentUnit.unitQty) {
			const currentUnitQty = parseFloat(currentUnit.unitQty) || 1;
			
			// Minim Qty = Unit Qty × 2
			const calculatedMinimQty = currentUnitQty * 2;
			currentUnit.minimQty = Math.ceil(calculatedMinimQty).toString();
			
			// Minimum Qty Alert = Minim Qty × 2
			const calculatedMinimumQtyAlert = calculatedMinimQty * 2;
			currentUnit.minimumQtyAlert = Math.ceil(calculatedMinimumQtyAlert).toString();
			
			// Maximum Qty = Minimum Qty Alert × 2
			const calculatedMaximumQty = calculatedMinimumQtyAlert * 2;
			currentUnit.maximumQty = Math.ceil(calculatedMaximumQty).toString();
		}
		
		// For first unit, just calculate its profit
		if (index === 0) {
			calculateProfit(0);
			productUnits = [...productUnits];
			return;
		}
		
		if (productUnits.length === 0) return;
		
		const firstUnit = productUnits[0];
		
		// Only auto-calculate if first unit has values and current unit has qty
		if (firstUnit.salePrice && firstUnit.unitQty && currentUnit.unitQty) {
			const firstUnitQty = parseFloat(firstUnit.unitQty) || 1;
			const currentUnitQty = parseFloat(currentUnit.unitQty) || 1;
			const baseSalePrice = parseFloat(firstUnit.salePrice) || 0;
			
			// Calculate: (first unit sale price / first unit qty) * current unit qty
			const calculatedSalePrice = (baseSalePrice / firstUnitQty) * currentUnitQty;
			currentUnit.salePrice = calculatedSalePrice.toFixed(2);
		}
		
		if (firstUnit.cost && firstUnit.unitQty && currentUnit.unitQty) {
			const firstUnitQty = parseFloat(firstUnit.unitQty) || 1;
			const currentUnitQty = parseFloat(currentUnit.unitQty) || 1;
			const baseCost = parseFloat(firstUnit.cost) || 0;
			
			// Calculate: (first unit cost / first unit qty) * current unit qty
			const calculatedCost = (baseCost / firstUnitQty) * currentUnitQty;
			currentUnit.cost = calculatedCost.toFixed(2);
		}
		
		// Calculate profit after price/cost calculation
		calculateProfit(index);
		
		productUnits = [...productUnits]; // Trigger reactivity
	}

	// Calculate profit and profit percentage (prices are inclusive of tax)
	function calculateProfit(index: number) {
		const unit = productUnits[index];
		
		const salePrice = parseFloat(unit.salePrice) || 0;
		const cost = parseFloat(unit.cost) || 0;
		
		if (salePrice > 0 && cost > 0) {
			// Get tax percentage from selected tax category
			let taxPercentage = 0;
			if (selectedTax) {
				const selectedTaxCategory = taxes.find(t => t.id === selectedTax);
				if (selectedTaxCategory) {
					taxPercentage = parseFloat(selectedTaxCategory.percentage) || 0;
				}
			}
			
			// Since prices are inclusive of tax, extract the base amounts
			// Formula: Base Amount = Inclusive Amount / (1 + Tax% / 100)
			const taxMultiplier = 1 + (taxPercentage / 100);
			const baseSalePrice = salePrice / taxMultiplier;
			const baseCost = cost / taxMultiplier;
			
			// Calculate profit on base amounts (excluding tax)
			const profit = baseSalePrice - baseCost;
			unit.profit = profit.toFixed(2);
			
			// Profit % = (Profit / Base Cost) * 100
			const profitPercentage = (profit / baseCost) * 100;
			unit.profitPercentage = profitPercentage.toFixed(2);
		} else {
			unit.profit = '';
			unit.profitPercentage = '';
		}
	}

	// Handle manual price/cost changes to recalculate profit
	function handlePriceChange(index: number) {
		calculateProfit(index);
		productUnits = [...productUnits];
	}

	async function handleUnitImageUpload(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		
		if (!file) return;

		// Validate file type
		const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
		if (!allowedTypes.includes(file.type)) {
			alert('Please upload a valid image file (JPEG, PNG, WebP, or GIF)');
			return;
		}

		// Validate file size (5MB)
		if (file.size > 5 * 1024 * 1024) {
			alert('Image size must be less than 5MB');
			return;
		}

		try {
			const { supabase } = await import('$lib/utils/supabase');
			
		// Create unique filename
		const fileExt = file.name.split('.').pop();
		const fileName = `product-unit-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
		const filePath = `${fileName}`;

		// Upload to storage bucket using supabase
		const { data, error } = await supabase.storage
			.from('product-images')
			.upload(filePath, file, {
				cacheControl: '3600',
				upsert: false
			});

		if (error) throw error;

		// Get public URL
		const { data: urlData } = supabase.storage
			.from('product-images')
			.getPublicUrl(filePath);			// Update the unit's image URL
			productUnits[index].imageUrl = urlData.publicUrl;
			productUnits = [...productUnits]; // Trigger reactivity
		} catch (error) {
			console.error('Error uploading image:', error);
			alert('Failed to upload image: ' + error.message);
		}
	}

	function clearUnitImage(index: number) {
		productUnits[index].imageUrl = '';
		productUnits = [...productUnits];
	}

	// Auto-calculate price and cost based on first unit
	function calculatePrices(index: number) {
		if (index === 0 || productUnits.length < 2) return; // First unit or no base unit
		
		const firstUnit = productUnits[0];
		const currentUnit = productUnits[index];
		
		// Only calculate if first unit has values and current unit has qty
		if (firstUnit.salePrice && firstUnit.unitQty && currentUnit.unitQty) {
			const basePrice = parseFloat(firstUnit.salePrice);
			const baseQty = parseFloat(firstUnit.unitQty);
			const currentQty = parseFloat(currentUnit.unitQty);
			
			if (!isNaN(basePrice) && !isNaN(baseQty) && !isNaN(currentQty) && baseQty > 0) {
				// Calculate proportional price: (basePrice / baseQty) * currentQty
				productUnits[index].salePrice = ((basePrice / baseQty) * currentQty).toFixed(2);
			}
		}
		
		if (firstUnit.cost && firstUnit.unitQty && currentUnit.unitQty) {
			const baseCost = parseFloat(firstUnit.cost);
			const baseQty = parseFloat(firstUnit.unitQty);
			const currentQty = parseFloat(currentUnit.unitQty);
			
			if (!isNaN(baseCost) && !isNaN(baseQty) && !isNaN(currentQty) && baseQty > 0) {
				// Calculate proportional cost: (baseCost / baseQty) * currentQty
				productUnits[index].cost = ((baseCost / baseQty) * currentQty).toFixed(2);
			}
		}
		
		productUnits = [...productUnits]; // Trigger reactivity
	}

	function openCreateBaseUnit() {
		const windowId = `create-base-unit-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Create Base Unit #${instanceNumber}`,
			component: BaseUnitFormWindow,
			icon: '📦',
			size: { width: 500, height: 400 },
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
</script>

<div class="product-form-container">
	<div class="form-content">
		<div class="cards-container">
			<!-- Product Name Card -->
			<div class="info-card">
				<div class="card-header">
					<h4 class="card-title">Product Name</h4>
					<button
						class="translate-card-btn"
						class:active={useAutoTranslate}
						on:click={toggleAutoTranslate}
						title={useAutoTranslate ? 'Auto-translate: ON' : 'Auto-translate: OFF'}
						type="button"
					>
						{#if useAutoTranslate}
							🔄
						{:else}
							⭕
						{/if}
					</button>
				</div>
				<div class="form-group">
					<label for="product-name-en">English</label>
					<input
						id="product-name-en"
						type="text"
						bind:value={productNameEn}
						on:blur={handleEnglishInput}
						placeholder="Enter product name in English"
						disabled={isTranslating}
					/>
				</div>

				<div class="form-group">
					<label for="product-name-ar">Arabic</label>
					<input
						id="product-name-ar"
						type="text"
						bind:value={productNameAr}
						on:blur={handleArabicInput}
						placeholder="أدخل اسم المنتج بالعربية"
						disabled={isTranslating}
						dir="rtl"
					/>
				</div>

				<!-- Tax Category Section -->
				<div class="card-section">
					<h5 class="section-title">Tax Category</h5>
					<div class="form-group">
						<select
							id="tax-category"
							bind:value={selectedTax}
						>
							<option value="">Select tax category</option>
							{#each taxes as tax}
								<option value={tax.id}>
									{tax.name_en} / {tax.name_ar} ({tax.percentage}%)
								</option>
							{/each}
						</select>
					</div>
				</div>
			</div>

			<!-- Product Details Card (Serial & Category) -->
			<div class="info-card">
				<h4 class="card-title">Product Details</h4>
				
				<!-- Product Serial Section -->
				<div class="card-section">
					<h5 class="section-title">Product Serial</h5>
					<div class="form-group">
						<input
							id="product-serial"
							type="text"
							bind:value={productSerial}
							placeholder="Auto-generated on save"
							disabled
							class="serial-input"
						/>
						<p class="helper-text">Serial will be assigned when saving</p>
					</div>
				</div>

				<!-- Category Section -->
				<div class="card-section">
					<h5 class="section-title">Category</h5>
					<div class="form-group">
						<div class="category-selector-container">
							<select
								id="category"
								bind:value={selectedCategory}
								disabled={loadingCategories}
							>
								<option value="">Select a category</option>
								{#each categories as category}
									<option value={category.id}>
										{category.name_en} / {category.name_ar}
									</option>
								{/each}
							</select>
							<button class="add-category-btn" on:click={openCreateCategory} type="button">
								<span class="btn-icon">➕</span>
							</button>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Product Units Table -->
		<div class="units-table-section">
			{#if validationError}
				<div class="error-message validation-error">
					⚠️ {validationError}
				</div>
			{/if}
			<table class="units-table">
				<thead>
					<tr>
						<th>
							<div class="header-with-btn">
								<span>Unit</span>
								<button class="add-unit-header-btn" on:click={openCreateBaseUnit} type="button" title="Create Base Unit">
									➕
								</button>
							</div>
						</th>
						<th>Unit Qty</th>
						<th>Barcode</th>
						<th>Sale Price</th>
						<th>Cost</th>
						<th>Profit</th>
						<th>Profit %</th>
						<th>Minim Qty</th>
						<th>Minimum Qty Alert</th>
						<th>Maximum Qty</th>
						<th>Image</th>
						<th class="action-header">
							<button class="add-unit-btn" on:click={addProductUnit} type="button" title="Add Unit">
								➕
							</button>
						</th>
					</tr>
				</thead>
				<tbody>
					{#if productUnits.length === 0}
						<tr class="empty-row">
							<td colspan="12">
								<div class="empty-state">
									<span class="empty-icon">📦</span>
									<p>No units added yet. Click the + button to add a unit.</p>
								</div>
							</td>
						</tr>
					{:else}
						{#each productUnits as unit, index (unit.id)}
							<tr>
								<td>
									<select
										bind:value={unit.unit}
										class="table-input"
									>
										<option value="">Select unit</option>
										{#each baseUnits as baseUnit}
											<option value={baseUnit.id}>
												{baseUnit.name_en} / {baseUnit.name_ar}
											</option>
										{/each}
									</select>
								</td>
								<td>
									<input
										type="number"
										bind:value={unit.unitQty}
										on:input={() => handleUnitQtyChange(index)}
										placeholder="1"
										step="0.01"
										min="0"
										class="table-input"
									/>
								</td>
								<td>
									<input
										type="text"
										bind:value={unit.barcode}
										placeholder="Barcode"
										class="table-input"
									/>
								</td>
								<td>
									<input
										type="number"
										bind:value={unit.salePrice}
										on:input={() => handlePriceChange(index)}
										placeholder="0.00"
										step="0.01"
										min="0"
										class="table-input"
										class:auto-calculated={index > 0}
									/>
								</td>
								<td>
									<input
										type="number"
										bind:value={unit.cost}
										on:input={() => handlePriceChange(index)}
										placeholder="0.00"
										step="0.01"
										min="0"
										class="table-input"
										class:auto-calculated={index > 0}
									/>
								</td>
								<td>
									<input
										type="number"
										value={unit.profit}
										placeholder="0.00"
										step="0.01"
										class="table-input profit-display"
										readonly
										title="Auto-calculated: (Sale Price - Cost) excluding tax"
									/>
								</td>
								<td>
									<input
										type="number"
										value={unit.profitPercentage}
										placeholder="0.00"
										step="0.01"
										class="table-input profit-display"
										readonly
										title="Auto-calculated: (Profit / Cost) × 100 (excluding tax)"
									/>
								</td>
								<td>
									<input
										type="number"
										bind:value={unit.minimQty}
										placeholder="0"
										min="0"
										class="table-input"
										class:auto-calculated={index > 0}
									/>
								</td>
								<td>
									<input
										type="number"
										bind:value={unit.minimumQtyAlert}
										placeholder="0"
										min="0"
										class="table-input"
										class:auto-calculated={index > 0}
									/>
								</td>
								<td>
									<input
										type="number"
										bind:value={unit.maximumQty}
										placeholder="0"
										min="0"
										class="table-input"
										class:auto-calculated={index > 0}
									/>
								</td>
								<td>
									<div class="image-cell">
										{#if unit.imageUrl}
											<div class="image-preview-container">
												<img src={unit.imageUrl} alt="Unit" class="unit-image-preview" />
												<button
													class="clear-image-btn"
													on:click={() => clearUnitImage(index)}
													type="button"
													title="Clear image"
												>
													❌
												</button>
											</div>
										{:else}
											<label class="upload-image-label">
												<input
													type="file"
													accept="image/jpeg,image/jpg,image/png,image/webp,image/gif"
													on:change={(e) => handleUnitImageUpload(e, index)}
													class="hidden-file-input"
												/>
												<span class="upload-icon">📷</span>
											</label>
										{/if}
									</div>
								</td>
								<td class="action-cell">
									<button
										class="delete-unit-btn"
										on:click={() => deleteProductUnit(index)}
										type="button"
										title="Delete unit"
									>
										🗑️
									</button>
								</td>
							</tr>
						{/each}
					{/if}
				</tbody>
			</table>
		</div>

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
	</div>

	<div class="form-footer">
		<button class="save-btn" on:click={handleSave} disabled={isTranslating}>
			{editMode ? 'Update Product' : 'Save Product'}
		</button>
	</div>
</div>

<style>
	.product-form-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.form-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
	}

	.cards-container {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1.5rem;
		margin-bottom: 1.5rem;
	}

	.info-card {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		padding: 1.5rem;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		border-bottom: 2px solid #e2e8f0;
		padding-bottom: 0.75rem;
	}

	.card-title {
		margin: 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.card-section {
		margin-bottom: 1.5rem;
		padding-bottom: 1.5rem;
		border-bottom: 1px solid #e2e8f0;
	}

	.card-section:last-child {
		margin-bottom: 0;
		padding-bottom: 0;
		border-bottom: none;
	}

	.section-title {
		margin: 0 0 1rem 0;
		color: #475569;
		font-size: 0.95rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.translate-card-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		background: #94a3b8;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1.2rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.translate-card-btn.active {
		background: #10b981;
	}

	.translate-card-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.translate-card-btn.active:hover {
		background: #059669;
	}

	.translate-card-btn:not(.active):hover {
		background: #64748b;
	}

	.translate-card-btn:active {
		transform: translateY(0);
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

	.form-group input,
	.form-group select {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 0.5rem;
		font-size: 1rem;
		transition: border-color 0.2s ease;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.form-group input:disabled,
	.form-group select:disabled {
		background: #f1f5f9;
		cursor: not-allowed;
	}

	.serial-input {
		font-weight: 600;
		color: #1e293b;
		background: #f0fdf4 !important;
		border-color: #86efac !important;
		font-family: 'Courier New', monospace;
		letter-spacing: 0.05em;
	}

	.helper-text {
		margin: 0.5rem 0 0 0;
		font-size: 0.85rem;
		color: #64748b;
	}

	.category-selector-container {
		display: flex;
		gap: 0.5rem;
	}

	.category-selector-container select {
		flex: 1;
	}

	.add-category-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 48px;
		height: 48px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
		flex-shrink: 0;
	}

	.add-category-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.add-category-btn:active {
		transform: translateY(0);
	}

	.btn-icon {
		font-size: 1.25rem;
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
		margin-bottom: 1rem;
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
		margin-bottom: 1rem;
	}

	.validation-error {
		margin: 1rem;
		animation: slideDown 0.3s ease-out;
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.units-table-section {
		margin-top: 1.5rem;
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		overflow: hidden;
	}

	.units-table {
		width: 100%;
		border-collapse: collapse;
	}

	.units-table thead {
		background: #f8fafc;
	}

	.units-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #1e293b;
		border-bottom: 2px solid #e2e8f0;
		font-size: 0.95rem;
	}

	.units-table th.action-header {
		text-align: center;
		width: 60px;
	}

	.header-with-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.add-unit-header-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.9rem;
		cursor: pointer;
		transition: all 0.2s ease;
		flex-shrink: 0;
	}

	.add-unit-header-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.add-unit-header-btn:active {
		transform: translateY(0);
	}

	.units-table tbody {
		background: white;
	}

	.units-table tbody tr {
		border-bottom: 1px solid #e2e8f0;
	}

	.units-table tbody tr:last-child {
		border-bottom: none;
	}

	.units-table td {
		padding: 0.75rem 1rem;
	}

	.units-table td.action-cell {
		text-align: center;
	}

	.table-input {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.375rem;
		font-size: 0.9rem;
		transition: border-color 0.2s ease;
	}

	.table-input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.table-input.auto-calculated {
		background-color: #f0f9ff;
		border-color: #bae6fd;
	}

	.table-input.profit-display {
		background-color: #f0fdf4;
		border-color: #bbf7d0;
		font-weight: 600;
		color: #15803d;
		cursor: not-allowed;
	}

	.table-input.profit-display:focus {
		border-color: #bbf7d0;
	}

	.empty-row td {
		padding: 3rem 1rem;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		color: #64748b;
	}

	.empty-icon {
		font-size: 2rem;
	}

	.empty-state p {
		margin: 0;
		font-size: 0.95rem;
	}

	.add-unit-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1.1rem;
		cursor: pointer;
		transition: all 0.2s ease;
		margin: 0 auto;
	}

	.add-unit-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.add-unit-btn:active {
		transform: translateY(0);
	}

	.delete-unit-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
		margin: 0 auto;
	}

	.delete-unit-btn:hover {
		background: #dc2626;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3);
	}

	.delete-unit-btn:active {
		transform: translateY(0);
	}

	.image-cell {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 60px;
	}

	.image-preview-container {
		position: relative;
		display: inline-block;
	}

	.unit-image-preview {
		width: 60px;
		height: 60px;
		object-fit: cover;
		border-radius: 0.375rem;
		border: 2px solid #e2e8f0;
	}

	.clear-image-btn {
		position: absolute;
		top: -8px;
		right: -8px;
		width: 24px;
		height: 24px;
		background: #ef4444;
		border: 2px solid white;
		border-radius: 50%;
		font-size: 0.7rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		transition: all 0.2s ease;
	}

	.clear-image-btn:hover {
		background: #dc2626;
		transform: scale(1.1);
	}

	.upload-image-label {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 60px;
		height: 60px;
		background: #f1f5f9;
		border: 2px dashed #cbd5e1;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.upload-image-label:hover {
		background: #e2e8f0;
		border-color: #94a3b8;
	}

	.upload-icon {
		font-size: 1.5rem;
	}

	.hidden-file-input {
		display: none;
	}

	.form-footer {
		padding: 1.5rem;
		border-top: 2px solid #e2e8f0;
	}

	.save-btn {
		width: 100%;
		padding: 0.875rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.save-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.save-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.save-btn:disabled {
		background: #94a3b8;
		cursor: not-allowed;
	}

	/* Responsive design */
	@media (max-width: 900px) {
		.cards-container {
			grid-template-columns: 1fr;
		}
	}
</style>
