<script lang="ts">
	import { supabase } from '\$lib/utils/supabase';
	import { onMount } from 'svelte';
	
	let products: any[] = [];
	let filteredProducts: any[] = [];
	let isLoading: boolean = true;
	let searchQuery: string = '';
	
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
	
	// Toggle product selection for a template
	function toggleProductSelection(templateId: string, barcode: string) {
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
	
	// Save offers to database
	async function saveOffers() {
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
	
	// Load all products from database
	async function loadProducts() {
		isLoading = true;
		
		try {
			const { data, error } = await supabase
				.from('products')
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

<div class="space-y-6">
	<!-- Wizard Header -->
	<div class="bg-white rounded-lg shadow-md p-6">
		<h1 class="text-3xl font-bold text-gray-800 mb-4">Create Offer - Wizard</h1>
		
		<!-- Step Indicator -->
		<div class="flex items-center justify-between mb-6">
			<div class="flex items-center flex-1">
				<!-- Step 1 -->
				<div class="flex items-center">
					<div class="flex items-center justify-center w-10 h-10 rounded-full {currentStep >= 1 ? 'bg-blue-600 text-white' : 'bg-gray-300 text-gray-600'} font-bold">
						1
					</div>
					<span class="ml-2 text-sm font-medium {currentStep >= 1 ? 'text-blue-600' : 'text-gray-500'}">Offer Info</span>
				</div>
				
				<div class="flex-1 h-1 mx-4 {currentStep >= 2 ? 'bg-blue-600' : 'bg-gray-300'}"></div>
				
				<!-- Step 2 -->
				<div class="flex items-center">
					<div class="flex items-center justify-center w-10 h-10 rounded-full {currentStep >= 2 ? 'bg-blue-600 text-white' : 'bg-gray-300 text-gray-600'} font-bold">
						2
					</div>
					<span class="ml-2 text-sm font-medium {currentStep >= 2 ? 'text-blue-600' : 'text-gray-500'}">Select Products</span>
				</div>
				
				<div class="flex-1 h-1 mx-4 {currentStep >= 3 ? 'bg-blue-600' : 'bg-gray-300'}"></div>
				
				<!-- Step 3 -->
				<div class="flex items-center">
					<div class="flex items-center justify-center w-10 h-10 rounded-full {currentStep >= 3 ? 'bg-blue-600 text-white' : 'bg-gray-300 text-gray-600'} font-bold">
						3
					</div>
					<span class="ml-2 text-sm font-medium {currentStep >= 3 ? 'text-blue-600' : 'text-gray-500'}">Review & Save</span>
				</div>
			</div>
		</div>
	</div>

	<!-- Step 1: Offer Templates -->
	{#if currentStep === 1}
		<div class="bg-white rounded-lg shadow-md p-6 space-y-6">
			<h2 class="text-2xl font-bold text-gray-800">Step 1: Create Offer Templates</h2>
			<p class="text-gray-600">Each template will have a unique ID and can contain different products.</p>
			
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
			
			<!-- Navigation -->
			<div class="flex justify-end pt-4 border-t">
				<button 
					on:click={nextStep}
					disabled={templates.length === 0}
					class="px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
				>
					Next: Select Products
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
					</svg>
				</button>
			</div>
		</div>
	{/if}

	<!-- Step 2: Select Products -->
	{#if currentStep === 2}
		<div class="space-y-4">
			<div class="bg-white rounded-lg shadow-md p-6">
				<h2 class="text-2xl font-bold text-gray-800 mb-4">Step 2: Select Products for Each Template</h2>
				<p class="text-gray-600">Select products for your {templates.length} template{templates.length > 1 ? 's' : ''}</p>
			</div>

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
					<div class="overflow-x-auto max-h-[500px] overflow-y-auto">
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
											{product.product_name_en || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.parent_category || '-'}
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
				</div>
			{/if}
			
			<!-- Navigation -->
			<div class="bg-white rounded-lg shadow-md p-4 flex justify-between">
				<button 
					on:click={previousStep}
					class="px-6 py-3 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-2"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
					</svg>
					Previous
				</button>
				
				<button 
					on:click={nextStep}
					class="px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
				>
					Next: Review
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
					</svg>
				</button>
			</div>
		</div>
	{/if}

	<!-- Step 3: Review and Save -->
	{#if currentStep === 3}
		<div class="space-y-4">
			<div class="bg-white rounded-lg shadow-md p-6">
				<h2 class="text-2xl font-bold text-gray-800 mb-4">Step 3: Review & Save</h2>
				<p class="text-gray-600">Review your {templates.length} template{templates.length > 1 ? 's' : ''} before saving</p>
			</div>

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
						
						{#if template.selectedProducts.size > 0}
							<div class="mt-4 pt-4 border-t">
								<p class="text-xs text-gray-500 mb-2">Selected Barcodes:</p>
								<div class="max-h-32 overflow-y-auto text-xs text-gray-600 space-y-1">
									{#each Array.from(template.selectedProducts) as barcode}
										<div class="bg-gray-50 px-2 py-1 rounded">{barcode}</div>
									{/each}
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
			
			<!-- Total Summary -->
			<div class="bg-gradient-to-r from-blue-500 to-purple-600 text-white rounded-lg shadow-lg p-6">
				<div class="flex items-center justify-between">
					<div>
						<h3 class="text-2xl font-bold mb-2">Total Summary</h3>
						<p class="text-blue-100">Ready to save {templates.length} template(s)</p>
					</div>
					<div class="text-right">
						<div class="text-4xl font-bold">{templates.reduce((sum, t) => sum + t.selectedProducts.size, 0)}</div>
						<div class="text-blue-100">Total Products Selected</div>
					</div>
				</div>
			</div>
			
			<!-- Navigation -->
			<div class="bg-white rounded-lg shadow-md p-4 flex justify-between">
				<button 
					on:click={previousStep}
					class="px-6 py-3 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-2"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
					</svg>
					Previous
				</button>
				
				<button 
					on:click={saveOffers}
					disabled={isLoading}
					class="px-8 py-3 bg-green-600 text-white font-bold rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 text-lg"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
					</svg>
					{isLoading ? 'Saving...' : 'Save Offers'}
				</button>
			</div>
		</div>
	{/if}
</div>
