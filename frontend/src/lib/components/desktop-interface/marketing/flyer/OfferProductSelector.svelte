<script lang="ts">
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import VariationSelectionModal from '$lib/components/desktop-interface/marketing/flyer/VariationSelectionModal.svelte';
	import PriceValidationWarning from '$lib/components/desktop-interface/marketing/flyer/PriceValidationWarning.svelte';
	
	let products: any[] = [];
	let filteredProducts: any[] = [];
	let isLoading: boolean = true;
	let searchQuery: string = '';
	
	// Variation modal state
	let showVariationModal: boolean = false;
	let currentVariationGroup: any = null;
	let currentVariations: any[] = [];
	let currentTemplateForVariation: string = '';
	
	// Price validation state
	let showPriceValidationModal: boolean = false;
	let priceValidationIssues: any[] = [];
	let pendingSaveData: any = null;
	
	// Filter selections
	let selectedParentCategory: string = '';
	let selectedParentSubCategory: string = '';
	let selectedSubCategory: string = '';
	
	// Filter options (unique values from products)
	let parentCategories: string[] = [];
	let parentSubCategories: string[] = [];
	let subCategories: string[] = [];
	
	// Wizard steps
	let currentStep: number = 1;
	const totalSteps: number = 3;
	
	// Step 1: Templates with auto-generated template_id
	interface OfferTemplate {
		id: string;
		templateId: string; // Unique identifier for database
		name: string;
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
			// Call database function to get all variations
			const { data, error } = await supabaseAdmin.rpc('get_product_variations', {
				p_barcode: parentBarcode
			});
			
			if (error) {
				console.error('Error loading variations:', error);
				alert('Error loading variation group. Please try again.');
				return;
			}
			
			// Separate parent from variations
			const parentProduct = data.find(p => p.is_parent);
			const variations = data.filter(p => !p.is_parent);
			
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
				const { data: offerData, error: offerError } = await supabaseAdmin
					.from('flyer_offers')
					.insert({
						template_id: template.templateId,
						template_name: template.name,
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
					
					const { error: productsError } = await supabaseAdmin
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
		
		try {
			// Save each template as a separate offer
			for (const template of templates) {
				// Insert offer with template_id
				const { data: offerData, error: offerError } = await supabaseAdmin
					.from('flyer_offers')
					.insert({
						template_id: template.templateId,
						template_name: template.name,
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
					
					const { error: productsError } = await supabaseAdmin
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
	
	// Load all products from database
	async function loadProducts() {
		isLoading = true;
		
		try {
			const { data, error } = await supabaseAdmin
				.from('flyer_products')
				.select('*')
				.order('product_name_en', { ascending: true });
			
			if (error) {
				console.error('Error loading products:', error);
				alert('Error loading products. Please try again.');
			} else {
				products = data || [];
				extractFilterOptions();
				applyFilters();
			}
		} catch (error) {
			console.error('Error loading products:', error);
			alert('Error loading products. Please try again.');
		}
		
		isLoading = false;
	}
	
	// Extract unique category values for filter dropdowns
	function extractFilterOptions() {
		const parentCats = new Set<string>();
		const parentSubCats = new Set<string>();
		const subCats = new Set<string>();
		
		products.forEach(product => {
			if (product.parent_category) parentCats.add(product.parent_category);
			if (product.parent_sub_category) parentSubCats.add(product.parent_sub_category);
			if (product.sub_category) subCats.add(product.sub_category);
		});
		
		parentCategories = Array.from(parentCats).sort();
		parentSubCategories = Array.from(parentSubCats).sort();
		subCategories = Array.from(subCats).sort();
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
				product.parent_category?.toLowerCase().includes(search) ||
				product.parent_sub_category?.toLowerCase().includes(search) ||
				product.sub_category?.toLowerCase().includes(search)
			);
		}
		
		// Apply category filters
		if (selectedParentCategory) {
			filtered = filtered.filter(product => product.parent_category === selectedParentCategory);
		}
		
		if (selectedParentSubCategory) {
			filtered = filtered.filter(product => product.parent_sub_category === selectedParentSubCategory);
		}
		
		if (selectedSubCategory) {
			filtered = filtered.filter(product => product.sub_category === selectedSubCategory);
		}
		
		filteredProducts = filtered;
	}
	
	// Clear all filters
	function clearFilters() {
		selectedParentCategory = '';
		selectedParentSubCategory = '';
		selectedSubCategory = '';
		searchQuery = '';
		applyFilters();
	}
	
	// Watch for filter changes
	$: searchQuery, selectedParentCategory, selectedParentSubCategory, selectedSubCategory, applyFilters();
	
	onMount(() => {
		loadProducts();
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
				<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">Parent Category</label>
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
					
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">Parent Sub Category</label>
						<select 
							bind:value={selectedParentSubCategory}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						>
							<option value="">All Sub Categories</option>
							{#each parentSubCategories as subCategory}
								<option value={subCategory}>{subCategory}</option>
							{/each}
						</select>
					</div>
					
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">Sub Category</label>
						<select 
							bind:value={selectedSubCategory}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						>
							<option value="">All Sub Categories</option>
							{#each subCategories as subCat}
								<option value={subCat}>{subCat}</option>
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
					<p class="text-gray-600">Loading products...</p>
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
										Category
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
								{#each filteredProducts as product (product.barcode)}
									<tr class="hover:bg-gray-50 transition-colors">
										<td class="px-6 py-4 whitespace-nowrap sticky left-0 bg-white z-10">
											<div class="w-16 h-16 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden">
												{#if product.image_url}
													<img 
														src={product.image_url}
														alt={product.product_name_en || product.barcode}
														class="w-full h-full object-contain"
														on:error={(e) => {
															const img = e.target;
															img.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect fill="%23f3f4f6" width="64" height="64"/><text x="32" y="32" font-size="10" text-anchor="middle" alignment-baseline="middle" fill="%239ca3af">No Image</text></svg>';
														}}
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
										{product.parent_sub_category || '-'}
									</td>										<!-- Dynamic Template Checkboxes -->
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
