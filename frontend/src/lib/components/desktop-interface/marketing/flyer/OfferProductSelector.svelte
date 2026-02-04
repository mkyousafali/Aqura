<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import VariationSelectionModal from '$lib/components/desktop-interface/marketing/flyer/VariationSelectionModal.svelte';
	import PriceValidationWarning from '$lib/components/desktop-interface/marketing/flyer/PriceValidationWarning.svelte';
	
	// Cache configuration (shared across all flyer components)
	const CACHE_KEY = 'flyer_products_cache';
	const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
	
	let products: any[] = [];
	let filteredProducts: any[] = [];
	let isLoading: boolean = false;
	let searchQuery: string = '';
	
	// Image loading tracking
	let successfullyLoadedImages: Set<string> = new Set();
	let imageRefs: Record<string, HTMLImageElement> = {};
	
	// Variation modal state
	let showVariationModal: boolean = false;
	let currentVariationGroup: any = null;
	let currentVariations: any[] = [];
	let currentTemplateForVariation: string = '';
	
	// Price validation state
	let showPriceValidationModal: boolean = false;
	let priceValidationIssues: any[] = [];
	let pendingSaveData: any = null;
	
	// Offer names from database
	let offerNames: any[] = [];
	
	// Filter selections
	let selectedParentCategory: string = '';
	
	// Filter options (unique values from products)
	let parentCategories: string[] = [];
	
	// Product loading - automatic batch loading
	let pageSize: number = 25; // Batch size for automatic loading
	let totalProducts: number = 0;
	
	// Wizard steps
	let currentStep: number = 1;
	const totalSteps: number = 3;
	
	// Step 1: Templates with auto-generated template_id
	interface OfferTemplate {
		id: string;
		templateId: string; // Unique identifier for database
		name: string;
		offerNameId?: string; // Reference to offer_names table
		startDate: string;
		endDate: string;
		selectedProducts: Set<string>; // Set of barcodes
	}
	
	let templates: OfferTemplate[] = [];
	let nextTemplateId: number = 1;
	
	// Step 3: Summary data
	let savedOfferId: string | null = null;
	
	// Generate unique template ID
	function generateTemplateId(): string {
		const timestamp = Date.now();
		const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
		return `TEMPLATE-${timestamp}-${random}`;
	}
	
	// Generate template name from dates
	function generateTemplateName(startDate: string, endDate: string): string {
		if (!startDate || !endDate) return `Offer ${nextTemplateId}`;
		
		const start = new Date(startDate);
		const end = new Date(endDate);
		
		const formatDate = (date: Date) => {
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			return `${day}-${month}-${year}`;
		};
		
		return `Offer ${formatDate(start)} to ${formatDate(end)}`;
	}
	
	// Add new template
	function addTemplate() {
		const newTemplate: OfferTemplate = {
			id: `temp-${nextTemplateId}`, // Temporary ID for UI
			templateId: generateTemplateId(), // Unique database ID
			name: `Offer ${nextTemplateId}`,
			offerNameId: '', // Selected from dropdown
			startDate: '',
			endDate: '',
			selectedProducts: new Set()
		};
		templates = [...templates, newTemplate];
		nextTemplateId++;
	}
	
	// Update template name when dates change
	function updateTemplateName(templateId: string) {
		templates = templates.map(t => {
			if (t.id === templateId && t.startDate && t.endDate) {
				return { ...t, name: generateTemplateName(t.startDate, t.endDate) };
			}
			return t;
		});
	}
	
	// Image loading handlers
	function handleImageLoad(event: Event) {
		const img = event.target as HTMLImageElement;
		const barcode = img.getAttribute('data-barcode');
		if (barcode) {
			successfullyLoadedImages.add(barcode);
			successfullyLoadedImages = successfullyLoadedImages; // Trigger reactivity
		}
	}
	
	function handleImageError(event: Event) {
		const img = event.target as HTMLImageElement;
		const barcode = img.getAttribute('data-barcode');
		if (barcode) {
			successfullyLoadedImages.delete(barcode);
			successfullyLoadedImages = successfullyLoadedImages; // Trigger reactivity
		}
	}
	
	// Remove template
	function removeTemplate(templateId: string) {
		templates = templates.filter(t => t.id !== templateId);
	}
	
	// Toggle product selection for a template (with variation detection)
	async function toggleProductSelection(templateId: string, barcode: string) {
		// Find the product
		const product = products.find(p => p.barcode === barcode);
		if (!product) return;
		
		// Check if product is part of a variation group
		if (product.is_variation) {
			// Determine parent barcode
			const parentBarcode = product.parent_product_barcode || product.barcode;
			
			// Load all variations in the group
			await loadVariationGroup(templateId, parentBarcode);
			return;
		}
		
		// Normal product selection (not a variation)
		templates = templates.map(t => {
			if (t.id === templateId) {
				const newSet = new Set(t.selectedProducts);
				if (newSet.has(barcode)) {
					newSet.delete(barcode);
				} else {
					newSet.add(barcode);
				}
				return { ...t, selectedProducts: newSet };
			}
			return t;
		});
	}
	
	// Load variation group and show modal
	async function loadVariationGroup(templateId: string, parentBarcode: string) {
		try {
			// Get the parent product first to find the variation group
			const { data: parentData, error: parentError } = await supabase
				.from('products')
				.select('variation_group_name_en, variation_group_name_ar')
				.eq('barcode', parentBarcode)
				.single();
			
			if (parentError) {
				console.error('Error loading parent product:', parentError);
				alert('Error loading variation group. Please try again.');
				return;
			}
			
			// Get all products in the same variation group
			const { data, error } = await supabase
				.from('products')
				.select('*')
				.eq('variation_group_name_en', parentData.variation_group_name_en)
				.eq('is_active', true);
			
			if (error) {
				console.error('Error loading variations:', error);
				alert('Error loading variation group. Please try again.');
				return;
			}
			
			// Separate parent from variations (parent has parent_product_barcode as null)
			const parentProduct = data.find(p => p.parent_product_barcode === null || p.barcode === parentBarcode);
			const variations = data.filter(p => p.parent_product_barcode !== null && p.barcode !== parentBarcode);
			
			if (!parentProduct) {
				console.error('Parent product not found in variation group');
				return;
			}
			
			// Get currently selected products in this template
			const template = templates.find(t => t.id === templateId);
			const preSelected = new Set(
				data.filter(p => template?.selectedProducts.has(p.barcode)).map(p => p.barcode)
			);
			
			// Show variation selection modal
			currentVariationGroup = parentProduct;
			currentVariations = variations;
			currentTemplateForVariation = templateId;
			showVariationModal = true;
		} catch (error) {
			console.error('Error loading variation group:', error);
			alert('Error loading variation group. Please try again.');
		}
	}
	
	// Handle variation selection confirmation
	function handleVariationConfirm(event: CustomEvent) {
		const { templateId, selectedBarcodes } = event.detail;
		
		// Update template with selected variations
		templates = templates.map(t => {
			if (t.id === templateId) {
				const newSet = new Set(t.selectedProducts);
				
				// Remove all products from this group first
				const groupBarcodes = [currentVariationGroup.barcode, ...currentVariations.map(v => v.barcode)];
				groupBarcodes.forEach(barcode => newSet.delete(barcode));
				
				// Add selected products
				selectedBarcodes.forEach(barcode => newSet.add(barcode));
				
				return { ...t, selectedProducts: newSet };
			}
			return t;
		});
		
		// Close modal
		showVariationModal = false;
		currentVariationGroup = null;
		currentVariations = [];
		currentTemplateForVariation = '';
	}
	
	// Handle variation modal cancel
	function handleVariationCancel() {
		showVariationModal = false;
		currentVariationGroup = null;
		currentVariations = [];
		currentTemplateForVariation = '';
	}
	
	// Price validation modal handlers
	function handlePriceValidationContinue() {
		// User acknowledged and wants to continue with different prices
		showPriceValidationModal = false;
		priceValidationIssues = [];
		// Proceed with save without validation
		continueSaveWithoutValidation();
	}
	
	function handleSetUniformPrice(event: CustomEvent) {
		// Apply uniform price to all variations in groups with issues
		const { price } = event.detail;
		console.log('Setting uniform price:', price);
		// TODO: Update prices in database when price capture is implemented
		alert(`Uniform price feature will be implemented when price input is added to the selector.\nSelected price: ${price} SAR`);
		showPriceValidationModal = false;
		priceValidationIssues = [];
	}
	
	function handleRemovePriceMismatches() {
		// Remove variations with different prices, keep most common
		console.log('Removing price mismatches');
		// TODO: Implement when price capture is added
		alert('Remove mismatches feature will be implemented when price input is added.');
		showPriceValidationModal = false;
		priceValidationIssues = [];
	}
	
	function handlePriceValidationCancel() {
		// Cancel the save operation
		showPriceValidationModal = false;
		priceValidationIssues = [];
	}
	
	async function continueSaveWithoutValidation() {
		// Bypass validation and save directly
		// This is the original saveOffers logic without validation
		isLoading = true;
		
		try {
			// Save each template as a separate offer
			for (const template of templates) {
				// Insert offer with template_id
				const { data: offerData, error: offerError } = await supabase
					.from('flyer_offers')
					.insert({
						template_id: template.templateId,
						template_name: template.name,
						offer_name_id: template.offerNameId || null,
						start_date: template.startDate,
						end_date: template.endDate
					})
					.select()
					.single();
				
				if (offerError) {
					console.error('Error saving offer:', offerError);
					alert(`Error saving ${template.name}: ${offerError.message}`);
					continue;
				}
				
				// Insert selected products for this offer
				if (template.selectedProducts.size > 0) {
					const offerProducts = Array.from(template.selectedProducts).map(barcode => ({
						offer_id: offerData.id,
						product_barcode: barcode
					}));
					
					const { error: productsError } = await supabase
						.from('flyer_offer_products')
						.insert(offerProducts);
					
					if (productsError) {
						console.error('Error saving offer products:', productsError);
						alert(`Error saving products for ${template.name}: ${productsError.message}`);
					}
				}
			}
			
			alert('Offers saved successfully!');
			
			// Reset wizard
			currentStep = 1;
			templates = [];
			nextTemplateId = 1;
			
		} catch (error) {
			console.error('Error saving offers:', error);
			alert('Error saving offers. Please try again.');
		}
		
		isLoading = false;
	}
	
	// Check if product is selected in a template
	function isProductSelected(templateId: string, barcode: string): boolean {
		const template = templates.find(t => t.id === templateId);
		return template ? template.selectedProducts.has(barcode) : false;
	}
	
	// Navigation functions
	function goToStep(step: number) {
		if (step === 2 && templates.length === 0) {
			alert('Please add at least one template');
			return;
		}
		if (step === 2) {
			// Validate templates have dates
			const invalidTemplates = templates.filter(t => !t.startDate || !t.endDate);
			if (invalidTemplates.length > 0) {
				alert('Please fill in start and end dates for all templates');
				return;
			}
			
			// Only load products when actually entering step 2
			if (products.length === 0 && !isLoading) {
				console.log('Loading products for step 2...');
				loadProducts();
			}
		}
		currentStep = step;
	}
	
	function nextStep() {
		if (currentStep < totalSteps) {
			goToStep(currentStep + 1);
		}
	}
	
	function previousStep() {
		if (currentStep > 1) {
			currentStep--;
		}
	}
	
	// Validate variation group prices
	async function validateVariationPrices(): Promise<{ valid: boolean; issues: any[] }> {
		const issues = [];
		
		// For now, since we don't capture prices during selection,
		// this is a placeholder that will be expanded when price input is added
		// In the future, this will check if variations in same group have matching offer_price
		
		// Iterate through templates and check for variation groups
		for (const template of templates) {
			const selectedBarcodes = Array.from(template.selectedProducts);
			
			// Get products data
			const selectedProducts = products.filter(p => selectedBarcodes.includes(p.barcode));
			
			// Group by variation_group (products with same parent_product_barcode)
			const variationGroups = new Map<string, any[]>();
			
			selectedProducts.forEach(product => {
				if (product.is_variation && product.parent_product_barcode) {
					const groupKey = product.parent_product_barcode;
					if (!variationGroups.has(groupKey)) {
						variationGroups.set(groupKey, []);
					}
					variationGroups.get(groupKey)?.push(product);
				}
			});
			
			// Check each group (placeholder for future price validation)
			variationGroups.forEach((groupProducts, parentBarcode) => {
				// Future: Check if all products have same offer_price
				// For now, just log that we found a group
				console.log(`Found variation group ${parentBarcode} with ${groupProducts.length} products`);
				
				// Placeholder validation - would check prices here
				// Example structure for price issues:
				// issues.push({
				//   groupName: groupProducts[0].variation_group_name_en,
				//   variations: groupProducts.map(p => ({
				//     barcode: p.barcode,
				//     name: p.product_name_en,
				//     offerPrice: p.offer_price // Would need to be captured during selection
				//   }))
				// });
			});
		}
		
		return {
			valid: issues.length === 0,
			issues
		};
	}
	
	// Save offers to database
	async function saveOffers() {
		// Validate prices first
		const validation = await validateVariationPrices();
		
		if (!validation.valid && validation.issues.length > 0) {
			// Show price validation warning
			priceValidationIssues = validation.issues;
			showPriceValidationModal = true;
			return;
		}
		
		isLoading = true;
		
		try{
			// Save each template as a separate offer
			for (const template of templates) {
				// Insert offer with template_id
				const { data: offerData, error: offerError } = await supabase
					.from('flyer_offers')
					.insert({
						template_id: template.templateId,
						template_name: template.name,
						offer_name_id: template.offerNameId || null,
						start_date: template.startDate,
						end_date: template.endDate
					})
					.select()
					.single();
				
				if (offerError) {
					console.error('Error saving offer:', offerError);
					alert(`Error saving ${template.name}: ${offerError.message}`);
					continue;
				}
				
				// Insert selected products for this offer
				if (template.selectedProducts.size > 0) {
					const offerProducts = Array.from(template.selectedProducts).map(barcode => ({
						offer_id: offerData.id,
						product_barcode: barcode
					}));
					
					const { error: productsError } = await supabase
						.from('flyer_offer_products')
						.insert(offerProducts);
					
					if (productsError) {
						console.error('Error saving offer products:', productsError);
						alert(`Error saving products for ${template.name}: ${productsError.message}`);
					}
				}
			}
			
			alert('Offers saved successfully!');
			
			// Reset wizard
			currentStep = 1;
			templates = [];
			nextTemplateId = 1;
			
		} catch (error) {
			console.error('Error saving offers:', error);
			alert('Error saving offers. Please try again.');
		}
		
		isLoading = false;
	}
	
	// Load products with automatic batch loading
	async function loadProducts() {
		if (isLoading) {
			console.log('Products already loading, skipping...');
			return;
		}
		
		isLoading = true;
		products = [];
		
		// Try to load from cache first
		try {
			const cached = localStorage.getItem(CACHE_KEY);
			if (cached) {
				const { data, timestamp } = JSON.parse(cached);
				const age = Date.now() - timestamp;
				
				if (age < CACHE_DURATION) {
					console.log('✓ Loading products from cache (age: ' + Math.round(age / 1000) + 's)');
					products = data;
					extractFilterOptions();
					applyFilters();
					isLoading = false;
					return;
				}
			}
		} catch (err) {
			console.warn('Cache read error:', err);
		}
		
		console.log('Starting automatic batch loading...');
		
		try {
			// First, get the total count
			const countResult = await supabase
				.from('products')
				.select('*', { count: 'exact', head: true });
			
			if (countResult.error) {
				throw countResult.error;
			}
			
			totalProducts = countResult.count || 0;
			console.log(`Total products to load: ${totalProducts}`);
			
			// Load categories once
			const categoriesResult = await supabase
				.from('product_categories')
				.select('id, name_en')
				.eq('is_active', true);
			
			// Load units once
			const unitsResult = await supabase
				.from('product_units')
				.select('id, name_en');
			
			// Create category lookup map
			const categoryMap = new Map();
			if (categoriesResult.data) {
				console.log('Categories loaded:', categoriesResult.data.length);
				categoriesResult.data.forEach(cat => {
					categoryMap.set(cat.id, cat.name_en);
				});
			}
			
			// Create unit lookup map
			const unitMap = new Map();
			if (unitsResult.data) {
				console.log('Units loaded:', unitsResult.data.length);
				unitsResult.data.forEach(unit => {
					unitMap.set(unit.id, unit.name_en);
				});
			}
			
			// Load all products in batches
			let loadedCount = 0;
			const batchSize = 25;
			
			while (loadedCount < totalProducts) {
				const from = loadedCount;
				const to = Math.min(from + batchSize - 1, totalProducts - 1);
				
				console.log(`Loading batch: ${from} to ${to} (${loadedCount + 1}-${to + 1} of ${totalProducts})`);
				
				const batchResult = await supabase
					.from('products')
					.select('id, barcode, product_name_en, product_name_ar, category_id, unit_id, image_url, is_variation, parent_product_barcode, variation_group_name_en, variation_group_name_ar')
					.order('product_name_en', { ascending: true })
					.range(from, to);
				
				if (batchResult.error) {
					console.error('Batch loading error:', batchResult.error);
					throw batchResult.error;
				}
				
				// Transform batch with category and unit names and create unique key based on position
				const batchProducts = (batchResult.data || []).map((product, index) => ({
					...product,
					category_name: categoryMap.get(product.category_id) || product.category_id || 'Uncategorized',
					unit_name: unitMap.get(product.unit_id) || product.unit_id || '-',
					_uniqueKey: `${from + index}-${product.barcode}`
				}));
				
				// Add to total products
				products = [...products, ...batchProducts];
				loadedCount = to + 1;
				
				console.log(`Loaded ${loadedCount} of ${totalProducts} products`);
				
				// Small delay to prevent overwhelming the UI and server
				await new Promise(resolve => setTimeout(resolve, 100));
			}
			
			// Update filters and apply them once after all batches are loaded
			extractFilterOptions();
			applyFilters();
			
			console.log(`All products loaded successfully! Total: ${products.length}`);
			
			// Cache the loaded data
			try {
				localStorage.setItem(CACHE_KEY, JSON.stringify({
					data: products,
					timestamp: Date.now()
				}));
				console.log('✓ Products cached to localStorage');
			} catch (err) {
				console.warn('Cache write error:', err);
			}

		} catch (error) {
			console.error('Error loading products:', {
				error,
				message: error.message,
				loadedSoFar: products.length
			});
			
			if (error.message?.includes('Failed to fetch')) {
				alert(`Network error: Loaded ${products.length} products before error. Please refresh to try again.`);
			} else {
				alert(`Error loading products: ${error.message || 'Unknown error'}. Loaded ${products.length} products.`);
			}
		}
		
		isLoading = false;
	}

	// Extract unique category values for filter dropdowns
	function extractFilterOptions() {
		const categories = new Set<string>();
		
		products.forEach(product => {
			if (product.category_name) categories.add(product.category_name);
		});
		
		parentCategories = Array.from(categories).sort();
	}
	
	// Apply all filters
	function applyFilters() {
		let filtered = products;
		
		// Apply search filter
		if (searchQuery.trim() !== '') {
			const search = searchQuery.toLowerCase();
			filtered = filtered.filter(product => 
				product.barcode?.toLowerCase().includes(search) ||
				product.product_name_en?.toLowerCase().includes(search) ||
				product.product_name_ar?.includes(search) ||
				product.category_name?.toLowerCase().includes(search)
			);
		}
		
		// Apply category filters
		if (selectedParentCategory) {
			filtered = filtered.filter(product => product.category_name === selectedParentCategory);
		}
		
		// Note: Parent sub category and sub category filters are disabled 
		// since they don't exist in the current database schema
		
		filteredProducts = filtered;
	}
	
	// Clear all filters
	function clearFilters() {
		selectedParentCategory = '';
		searchQuery = '';
		applyFilters();
	}
	
	// Load offer names from database
	async function loadOfferNames() {
		try {
			const { data, error } = await supabase
				.from('offer_names')
				.select('*')
				.eq('is_active', true)
				.order('id', { ascending: true });
			
			if (error) throw error;
			offerNames = data || [];
		} catch (error) {
			console.error('Error loading offer names:', error);
		}
	}
	
	// Watch for filter changes
	$: searchQuery, selectedParentCategory, applyFilters();
	
	onMount(() => {
		// Load offer names when component mounts
		loadOfferNames();
		// Don't load products immediately - only load when user reaches step 2
	});
</script>

<div class="space-y-4">
	<!-- Wizard Header -->
	<div class="bg-white rounded-lg shadow-sm p-3">
		<!-- Step Indicator -->
		<div class="flex items-center justify-between">
			<div class="flex items-center flex-1">
				<!-- Step 1 -->
				<div class="flex items-center">
					<div class="flex items-center justify-center w-8 h-8 rounded-full {currentStep >= 1 ? 'bg-blue-600 text-white' : 'bg-gray-300 text-gray-600'} font-semibold text-sm">
						1
					</div>
					<span class="ml-2 text-xs font-medium {currentStep >= 1 ? 'text-blue-600' : 'text-gray-500'}">Offer Info</span>
				</div>
				
				<div class="flex-1 h-0.5 mx-3 {currentStep >= 2 ? 'bg-blue-600' : 'bg-gray-300'}"></div>
				
				<!-- Step 2 -->
				<div class="flex items-center">
					<div class="flex items-center justify-center w-8 h-8 rounded-full {currentStep >= 2 ? 'bg-blue-600 text-white' : 'bg-gray-300 text-gray-600'} font-semibold text-sm">
						2
					</div>
					<span class="ml-2 text-xs font-medium {currentStep >= 2 ? 'text-blue-600' : 'text-gray-500'}">Select Products</span>
				</div>
				
				<div class="flex-1 h-0.5 mx-3 {currentStep >= 3 ? 'bg-blue-600' : 'bg-gray-300'}"></div>
				
				<!-- Step 3 -->
				<div class="flex items-center">
					<div class="flex items-center justify-center w-8 h-8 rounded-full {currentStep >= 3 ? 'bg-blue-600 text-white' : 'bg-gray-300 text-gray-600'} font-semibold text-sm">
						3
					</div>
					<span class="ml-2 text-xs font-medium {currentStep >= 3 ? 'text-blue-600' : 'text-gray-500'}">Review & Save</span>
				</div>
			</div>
		</div>
	</div>

	<!-- Step 1: Offer Templates -->
	{#if currentStep === 1}
		<!-- Navigation -->
		<div class="bg-white rounded-lg shadow-sm p-3 flex justify-end">
			<button 
				on:click={nextStep}
				disabled={templates.length === 0}
				class="px-6 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
			>
				Next: Select Products
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
				</svg>
			</button>
		</div>
		
		<div class="bg-white rounded-lg shadow-md p-6 space-y-6">
			<!-- Templates Section -->
			<div class="border-t pt-6">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-xl font-bold text-gray-800">Offer Templates</h3>
					<button 
						on:click={addTemplate}
						class="px-4 py-2 bg-green-600 text-white font-semibold rounded-lg hover:bg-green-700 transition-colors flex items-center gap-2"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
						</svg>
						Add Template
					</button>
				</div>
				
				{#if templates.length === 0}
					<div class="text-center py-8 text-gray-500">
						<svg class="w-16 h-16 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
						</svg>
						<p>No templates added yet. Click "Add Template" to create one.</p>
					</div>
				{:else}
					<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
						{#each templates as template (template.id)}
							<div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
								<div class="flex items-center justify-between mb-3">
									<div class="text-lg font-semibold text-gray-800">{template.name}</div>
									<button 
										on:click={() => removeTemplate(template.id)}
										class="text-red-500 hover:text-red-700 transition-colors"
										title="Remove template"
									>
										<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
										</svg>
									</button>
								</div>
								
								<div class="space-y-3">
									<div>
										<label class="block text-xs font-medium text-gray-600 mb-1">Offer Name (Optional)</label>
										<select
											bind:value={template.offerNameId}
											class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
										>
											<option value="">-- Select Offer Name --</option>
											{#each offerNames as offerName}
												<option value={offerName.id}>{offerName.name_en}</option>
											{/each}
										</select>
									</div>
									
									<div>
										<label class="block text-xs font-medium text-gray-600 mb-1">Start Date *</label>
										<input 
											type="date" 
											bind:value={template.startDate}
											on:change={() => updateTemplateName(template.id)}
											class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
										/>
									</div>
									
									<div>
										<label class="block text-xs font-medium text-gray-600 mb-1">End Date *</label>
										<input 
											type="date" 
											bind:value={template.endDate}
											on:change={() => updateTemplateName(template.id)}
											class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
										/>
									</div>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Step 2: Select Products -->
	{#if currentStep === 2}
		<!-- Navigation -->
		<div class="bg-white rounded-lg shadow-sm p-3 flex justify-between">
			<button 
				on:click={previousStep}
				class="px-6 py-2 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-2"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
				</svg>
				Previous
			</button>
			
			<button 
				on:click={nextStep}
				class="px-6 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
			>
				Next: Review
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
				</svg>
			</button>
		</div>
		
		<div class="space-y-4">
			<!-- Search Bar and Filters -->
			<div class="bg-white rounded-lg shadow-md p-4 space-y-4">
				<!-- Search Bar -->
				<div class="relative">
					<input
						type="text"
						bind:value={searchQuery}
						placeholder="Search by barcode, name, category..."
						class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
					<svg class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</div>
				
				<!-- Category Filters -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
						<select 
							bind:value={selectedParentCategory}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						>
							<option value="">All Categories</option>
							{#each parentCategories as category}
								<option value={category}>{category}</option>
							{/each}
						</select>
					</div>
					
					<div class="flex items-end">
						<button 
							on:click={clearFilters}
							class="w-full px-4 py-2 bg-gray-100 text-gray-700 font-medium rounded-lg hover:bg-gray-200 transition-colors flex items-center justify-center gap-2"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
							</svg>
							Clear Filters
						</button>
					</div>
				</div>
				
				<p class="text-sm text-gray-600">
					Showing {filteredProducts.length} of {products.length} products
				</p>
			</div>

			<!-- Products Table -->
			{#if isLoading}
				<div class="bg-white rounded-lg shadow-lg p-12 text-center">
					<svg class="animate-spin w-12 h-12 mx-auto text-blue-600 mb-4" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<p class="text-lg font-medium text-gray-800 mb-2">Loading Products...</p>
					<p class="text-sm text-gray-600 mb-4">Loading first 25 products from database</p>
					
					<button 
						on:click={() => {
							isLoading = false;
							console.log('Loading cancelled by user');
						}}
						class="px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-md text-sm font-medium transition-colors"
					>
						Cancel Loading
					</button>
				</div>
			{:else if filteredProducts.length === 0}
				<div class="bg-white rounded-lg shadow-lg p-12 text-center">
					<svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
					</svg>
					<h3 class="text-xl font-semibold text-gray-800 mb-2">No Products Found</h3>
				</div>
			{:else}
				<div class="bg-white rounded-lg shadow-lg overflow-hidden">
					<div class="overflow-x-auto" style="max-height: calc(100vh - 350px); overflow-y: auto;">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-100 sticky top-0 z-10">
								<tr>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider sticky left-0 bg-gray-100 z-20">
										Image
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Barcode
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Product Name
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Unit
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Category
									</th>
									<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
										Image URL
									</th>
									
									<!-- Dynamic Template Columns -->
									{#each templates as template (template.id)}
										<th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider bg-blue-50 border-l-2 border-blue-200">
											<div class="flex flex-col items-center gap-1 min-w-[150px]">
												<span class="font-bold text-blue-700">{template.name}</span>
												<span class="text-xs text-gray-600">{template.startDate} to {template.endDate}</span>
												<span class="text-xs text-green-600 font-semibold">{template.selectedProducts.size} selected</span>
											</div>
										</th>
									{/each}
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each filteredProducts as product, i (i)}
									<tr class="hover:bg-gray-50 transition-colors">
										<td class="px-6 py-4 whitespace-nowrap sticky left-0 bg-white z-10">
											<div class="w-16 h-16 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden">
												{#if product.image_url}
													<img 
														bind:this={imageRefs[product.barcode]}
														src={product.image_url}
														alt={product.product_name_en || product.barcode}
														data-barcode={product.barcode}
														class="w-full h-full object-contain"
														loading="lazy"
														decoding="async"
														on:load={handleImageLoad}
														on:error={handleImageError}
													/>
												{:else}
													<svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
													</svg>
												{/if}
											</div>
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
											{product.barcode}
										</td>
									<td class="px-6 py-4 text-sm text-gray-900" dir="ltr">
										<div class="flex items-center gap-2">
											<span>{product.product_name_en || '-'}</span>
											{#if product.is_variation}
												<span class="px-2 py-0.5 text-xs bg-green-100 text-green-700 rounded font-semibold">🔗 Grouped</span>
											{/if}
										</div>
									</td>
									<td class="px-6 py-4 text-sm text-gray-900">
										{product.unit_name || '-'}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900">
										{product.category_name || 'Uncategorized'}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-center">
										{#if !product.image_url}
											<!-- No URL -->
											<div class="flex items-center justify-center group relative cursor-help">
												<svg class="w-5 h-5 text-red-600" fill="currentColor" viewBox="0 0 20 20">
													<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
												</svg>
												<div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-20 pointer-events-none">
													No image URL
												</div>
											</div>
										{:else if successfullyLoadedImages.has(product.barcode)}
											<!-- Successfully loaded -->
											<div class="flex items-center justify-center group relative cursor-help">
												<svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
													<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
												</svg>
												<div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-20 pointer-events-none">
													✓ Image loaded
												</div>
											</div>
										{:else}
											<!-- URL exists but not loaded yet or failed -->
											<div class="flex items-center justify-center gap-2 group relative">
												<svg class="w-5 h-5 text-orange-600 cursor-help" fill="currentColor" viewBox="0 0 20 20">
													<path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
												</svg>
												<button
													class="px-2 py-1 text-xs bg-orange-100 text-orange-700 rounded hover:bg-orange-200 transition-colors"
													on:click={() => {
														const img = imageRefs[product.barcode];
														if (img && product.image_url) {
															successfullyLoadedImages.delete(product.barcode);
															img.src = product.image_url + '?t=' + Date.now();
														}
													}}
												>
													Retry
												</button>
												<div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-20 pointer-events-none">
													⚠ Failed to load
												</div>
											</div>
										{/if}
									</td>
									<!-- Dynamic Template Checkboxes -->
										{#each templates as template (template.id)}
											<td class="px-4 py-4 text-center bg-blue-50 border-l-2 border-blue-200">
												<input 
													type="checkbox"
													checked={isProductSelected(template.id, product.barcode)}
													on:change={() => toggleProductSelection(template.id, product.barcode)}
													class="w-5 h-5 text-blue-600 border-gray-300 rounded focus:ring-blue-500 cursor-pointer"
												/>
											</td>
										{/each}
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
					
					<!-- Products load automatically in 25-item batches -->
				</div>
			{/if}
		</div>
	{/if}

	<!-- Step 3: Review and Save -->
	{#if currentStep === 3}
		<!-- Navigation -->
		<div class="bg-white rounded-lg shadow-sm p-3 flex justify-between">
			<button 
				on:click={previousStep}
				class="px-6 py-2 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-2"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
				</svg>
				Previous
			</button>
			
			<button 
				on:click={saveOffers}
				disabled={isLoading}
				class="px-8 py-2 bg-green-600 text-white font-bold rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
			>
				<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
				</svg>
				{isLoading ? 'Saving...' : 'Save Offers'}
			</button>
		</div>
		
		<div class="space-y-4">
			<!-- Summary Cards -->
			<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
				{#each templates as template (template.id)}
					<div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-blue-500">
						<h3 class="text-xl font-bold text-gray-800 mb-1">{template.name}</h3>
						<p class="text-xs text-gray-500 mb-3 font-mono">{template.templateId}</p>
						
						<div class="space-y-2 text-sm">
							{#if template.offerNameId}
								{@const selectedOfferName = offerNames.find(o => o.id === template.offerNameId)}
								{#if selectedOfferName}
									<div class="flex items-center gap-2 bg-blue-50 p-2 rounded">
										<svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
										</svg>
										<span class="text-gray-600">Offer:</span>
										<span class="font-semibold text-blue-700">{selectedOfferName.name_en}</span>
									</div>
								{/if}
							{/if}
							
							<div class="flex items-center gap-2">
								<svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
								</svg>
								<span class="text-gray-600">Start:</span>
								<span class="font-semibold">{template.startDate}</span>
							</div>
							
							<div class="flex items-center gap-2">
								<svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
								</svg>
								<span class="text-gray-600">End:</span>
								<span class="font-semibold">{template.endDate}</span>
							</div>
							
							<div class="flex items-center gap-2 mt-4 pt-4 border-t">
								<svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
								<span class="text-gray-600">Products:</span>
								<span class="font-bold text-green-600 text-lg">{template.selectedProducts.size}</span>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/if}
</div>

<!-- Variation Selection Modal -->
{#if showVariationModal && currentVariationGroup}
	<VariationSelectionModal
		parentProduct={currentVariationGroup}
		variations={currentVariations}
		templateId={currentTemplateForVariation}
		preSelectedBarcodes={templates.find(t => t.id === currentTemplateForVariation)?.selectedProducts || new Set()}
		on:confirm={handleVariationConfirm}
		on:cancel={handleVariationCancel}
	/>
{/if}

<!-- Price Validation Warning Modal -->
{#if showPriceValidationModal && priceValidationIssues.length > 0}
	<PriceValidationWarning
		priceIssues={priceValidationIssues}
		on:continue={handlePriceValidationContinue}
		on:setUniformPrice={handleSetUniformPrice}
		on:removeMismatches={handleRemovePriceMismatches}
		on:cancel={handlePriceValidationCancel}
	/>
{/if}
