<script lang="ts">
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { onMount } from 'svelte';

	let offerTemplates: any[] = [];
	let selectedTemplate: any = null;
	let allProducts: any[] = [];
	let selectedProducts: Set<string> = new Set();
	let isLoadingTemplates: boolean = true;
	let isLoadingProducts: boolean = false;
	let isSaving: boolean = false;
	let searchQuery: string = '';
	let filteredProducts: any[] = [];
	let selectedParentCategory: string = '';
	let selectedParentSubCategory: string = '';
	let selectedSubCategory: string = '';
	let parentCategories: string[] = [];
	let parentSubCategories: string[] = [];
	let subCategories: string[] = [];

	// Load all active offer templates
	async function loadOfferTemplates() {
		isLoadingTemplates = true;
		try {
			const { data, error } = await supabaseAdmin
				.from('flyer_offers')
				.select('*')
				.eq('is_active', true)
				.order('created_at', { ascending: false });

			if (error) {
				console.error('Error loading offer templates:', error);
				alert('Error loading offer templates. Please try again.');
			} else {
				offerTemplates = data || [];
			}
		} catch (error) {
			console.error('Error loading offer templates:', error);
			alert('Error loading offer templates. Please try again.');
		}
		isLoadingTemplates = false;
	}

	// Load all products and check which ones are selected for the template
	async function loadProductsForTemplate(templateId: string) {
		isLoadingProducts = true;
		selectedProducts.clear();

		try {
			// Load all products
			const { data: products, error: productsError } = await supabaseAdmin
				.from('flyer_products')
				.select('*')
				.order('barcode', { ascending: true });

			if (productsError) {
				console.error('Error loading products:', productsError);
				alert('Error loading products. Please try again.');
				isLoadingProducts = false;
				return;
			}

			allProducts = products || [];

			// Extract unique categories
			const parentCatSet = new Set<string>();
			const parentSubCatSet = new Set<string>();
			const subCatSet = new Set<string>();
			
			allProducts.forEach(product => {
				if (product.parent_category) parentCatSet.add(product.parent_category);
				if (product.parent_sub_category) parentSubCatSet.add(product.parent_sub_category);
				if (product.sub_category) subCatSet.add(product.sub_category);
			});
			
			parentCategories = Array.from(parentCatSet).sort();
			parentSubCategories = Array.from(parentSubCatSet).sort();
			subCategories = Array.from(subCatSet).sort();

			// Load selected products for this template
			const { data: selectedProductsData, error: selectedError } = await supabaseAdmin
				.from('flyer_offer_products')
				.select('product_barcode')
				.eq('offer_id', templateId);

			if (selectedError) {
				console.error('Error loading selected products:', selectedError);
				alert('Error loading selected products. Please try again.');
			} else {
				// Add selected products to the Set
				selectedProductsData?.forEach(item => {
					selectedProducts.add(item.product_barcode);
				});
				selectedProducts = selectedProducts; // Trigger reactivity
			}

			// Apply search filter
			filterProducts();
		} catch (error) {
			console.error('Error loading products:', error);
			alert('Error loading products. Please try again.');
		}
		isLoadingProducts = false;
	}

	// Filter products based on search query
	function filterProducts() {
		let products = [];
		
		// Start with all products
		products = allProducts;
		
		// Apply category filters
		if (selectedParentCategory) {
			products = products.filter(p => p.parent_category === selectedParentCategory);
		}
		if (selectedParentSubCategory) {
			products = products.filter(p => p.parent_sub_category === selectedParentSubCategory);
		}
		if (selectedSubCategory) {
			products = products.filter(p => p.sub_category === selectedSubCategory);
		}
		
		// Apply text search (only barcode and name)
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase();
			products = products.filter(product => 
				product.barcode?.toLowerCase().includes(query) ||
				product.product_name_en?.toLowerCase().includes(query) ||
				product.product_name_ar?.includes(query)
			);
		}
		
		// Sort: selected products first, then unselected
		filteredProducts = products.sort((a, b) => {
			const aSelected = selectedProducts.has(a.barcode) ? 0 : 1;
			const bSelected = selectedProducts.has(b.barcode) ? 0 : 1;
			return aSelected - bSelected;
		});
	}

	// Handle search input
	$: {
		searchQuery;
		selectedParentCategory;
		selectedParentSubCategory;
		selectedSubCategory;
		filterProducts();
	}

	// Select a template
	function selectTemplate(template: any) {
		selectedTemplate = template;
		loadProductsForTemplate(template.id);
	}

	// Toggle product selection
	function toggleProduct(barcode: string) {
		if (selectedProducts.has(barcode)) {
			selectedProducts.delete(barcode);
		} else {
			selectedProducts.add(barcode);
		}
		selectedProducts = selectedProducts; // Trigger reactivity
		filterProducts(); // Re-sort to move selected/unselected items
	}

	// Save product selections
	async function saveProductSelections() {
		if (!selectedTemplate) return;

		isSaving = true;

		try {
			// First, delete all existing product selections for this template
			const { error: deleteError } = await supabaseAdmin
				.from('flyer_offer_products')
				.delete()
				.eq('offer_id', selectedTemplate.id);

			if (deleteError) {
				console.error('Error deleting old products:', deleteError);
				alert('Error updating product selections. Please try again.');
				isSaving = false;
				return;
			}

			// Insert new selections
			if (selectedProducts.size > 0) {
				const insertData = Array.from(selectedProducts).map(barcode => {
					// Find the product to get its cost and sales_price
					const product = allProducts.find(p => p.barcode === barcode);
					
					return {
						offer_id: selectedTemplate.id,
						product_barcode: barcode,
						cost: product?.cost || 0,
						sales_price: product?.sales_price || 0,
						profit_amount: product?.cost && product?.sales_price 
							? (product.sales_price - product.cost) 
							: 0,
						profit_percent: product?.cost && product?.sales_price && product.cost > 0
							? ((product.sales_price - product.cost) / product.cost) * 100
							: 0,
						offer_qty: 1,
						limit_qty: null,
						free_qty: 0,
						offer_price: 0,
						profit_after_offer: 0,
						decrease_amount: 0
					};
				});

				const { error: insertError } = await supabaseAdmin
					.from('flyer_offer_products')
					.insert(insertData);

				if (insertError) {
					console.error('Error inserting products:', insertError);
					alert('Error saving product selections. Please try again.');
					isSaving = false;
					return;
				}
			}

			alert(`Successfully saved ${selectedProducts.size} products for ${selectedTemplate.template_name}`);
		} catch (error) {
			console.error('Error saving products:', error);
			alert('Error saving product selections. Please try again.');
		}

		isSaving = false;
	}

	// Go back to template list
	function goBackToTemplates() {
		selectedTemplate = null;
		allProducts = [];
		selectedProducts.clear();
		searchQuery = '';
		selectedParentCategory = '';
		selectedParentSubCategory = '';
		selectedSubCategory = '';
		parentCategories = [];
		parentSubCategories = [];
		subCategories = [];
	}

	onMount(() => {
		loadOfferTemplates();
	});
</script>

<div class="h-full flex flex-col bg-gray-50">
	{#if !selectedTemplate}
		<!-- Template List View -->
		<div class="p-6">
			<div class="flex items-center justify-between mb-6">
				<div>
					<h1 class="text-3xl font-bold text-gray-800">Offer Templates</h1>
					<p class="text-gray-600 mt-1">Select an offer template to manage products</p>
				</div>
				<button 
					on:click={loadOfferTemplates}
					disabled={isLoadingTemplates}
					class="px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
					</svg>
					Refresh
				</button>
			</div>

			{#if isLoadingTemplates}
				<div class="bg-white rounded-lg shadow-lg p-12 text-center">
					<svg class="animate-spin w-12 h-12 mx-auto text-blue-600 mb-4" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<p class="text-gray-600">Loading offer templates...</p>
				</div>
			{:else if offerTemplates.length === 0}
				<div class="bg-white rounded-lg shadow-lg p-12 text-center">
					<svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
					<h3 class="text-xl font-semibold text-gray-800 mb-2">No Active Offer Templates</h3>
					<p class="text-gray-600">Create and activate offer templates from the Offer Manager.</p>
				</div>
			{:else}
				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
					{#each offerTemplates as template (template.id)}
						<button
							on:click={() => selectTemplate(template)}
							class="bg-white rounded-lg shadow-md p-6 hover:shadow-xl transition-shadow text-left border-2 border-transparent hover:border-blue-500"
						>
							<div class="flex items-start justify-between mb-4">
								<div class="flex-1">
									<h3 class="text-lg font-bold text-gray-800 mb-1">{template.template_name}</h3>
									<p class="text-xs text-gray-500 font-mono">{template.template_id}</p>
								</div>
								<span class="px-2 py-1 bg-green-100 text-green-800 text-xs font-semibold rounded-full">
									Active
								</span>
							</div>
							
							<div class="space-y-2 text-sm text-gray-600">
								<div class="flex items-center gap-2">
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
									<span>{new Date(template.start_date).toLocaleDateString()}</span>
								</div>
								<div class="flex items-center gap-2">
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
									<span>{new Date(template.end_date).toLocaleDateString()}</span>
								</div>
							</div>

							<div class="mt-4 pt-4 border-t border-gray-200">
								<div class="flex items-center justify-between">
									<span class="text-sm text-gray-500">Click to edit products</span>
									<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
									</svg>
								</div>
							</div>
						</button>
					{/each}
				</div>
			{/if}
		</div>
	{:else}
		<!-- Product Selection View -->
		<div class="flex flex-col h-full">
			<!-- Header -->
			<div class="bg-white border-b border-gray-200 px-6 py-4 sticky top-0 z-10">
				<div class="flex items-center justify-between mb-4">
					<div class="flex items-center gap-4">
						<button
							on:click={goBackToTemplates}
							class="px-4 py-2 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-2"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
							</svg>
							Back to Templates
						</button>
						<div>
							<h2 class="text-2xl font-bold text-gray-800">{selectedTemplate.template_name}</h2>
							<p class="text-sm text-gray-600">{selectedTemplate.template_id}</p>
						</div>
					</div>
					<button
						on:click={saveProductSelections}
						disabled={isSaving}
						class="px-6 py-3 bg-green-600 text-white font-bold rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
					>
						{#if isSaving}
							<svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Saving...
						{:else}
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
							</svg>
							Save Changes ({selectedProducts.size} products)
						{/if}
					</button>
				</div>

				<!-- Category Filters -->
				<div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Parent Category</label>
						<select
							bind:value={selectedParentCategory}
							class="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
						>
							<option value="">All Parent Categories</option>
							{#each parentCategories as category}
								<option value={category}>{category}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Parent Sub Category</label>
						<select
							bind:value={selectedParentSubCategory}
							class="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
						>
							<option value="">All Parent Sub Categories</option>
							{#each parentSubCategories as category}
								<option value={category}>{category}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Sub Category</label>
						<select
							bind:value={selectedSubCategory}
							class="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
						>
							<option value="">All Sub Categories</option>
							{#each subCategories as category}
								<option value={category}>{category}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Search Bar -->
				<div class="relative mt-4">
					<input
						type="text"
						bind:value={searchQuery}
						placeholder="Search by barcode, name, or category..."
						class="w-full px-4 py-2 pl-10 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
					/>
					<svg class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</div>
			</div>

			<!-- Products List -->
			<div class="flex-1 overflow-auto p-6">
				{#if isLoadingProducts}
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
						<p class="text-gray-600">Try adjusting your search criteria.</p>
					</div>
				{:else}
					<div class="bg-white rounded-lg shadow-md overflow-hidden">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th class="w-16 px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										<input
											type="checkbox"
											checked={filteredProducts.every(p => selectedProducts.has(p.barcode))}
											on:change={(e) => {
												if (e.currentTarget.checked) {
													filteredProducts.forEach(p => selectedProducts.add(p.barcode));
												} else {
													filteredProducts.forEach(p => selectedProducts.delete(p.barcode));
												}
												selectedProducts = selectedProducts;
											}}
											class="w-5 h-5 text-blue-600 rounded border-gray-300 focus:ring-2 focus:ring-blue-500"
										/>
									</th>
									<th class="w-20 px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Image
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Barcode
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Product Name (EN)
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Product Name (AR)
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Parent Category
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Parent Sub Category
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Sub Category
									</th>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each filteredProducts as product (product.barcode)}
									<tr class="hover:bg-gray-50 transition-colors {selectedProducts.has(product.barcode) ? 'bg-blue-50' : ''}">
										<td class="px-6 py-4">
											<input
												type="checkbox"
												checked={selectedProducts.has(product.barcode)}
												on:change={() => toggleProduct(product.barcode)}
												class="w-5 h-5 text-blue-600 rounded border-gray-300 focus:ring-2 focus:ring-blue-500"
											/>
										</td>
										<td class="px-6 py-4">
											<div class="w-14 h-14 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden">
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
													<svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
													</svg>
												{/if}
											</div>
										</td>
										<td class="px-6 py-4 text-sm font-medium text-gray-900">
											{product.barcode}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.product_name_en || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900" dir="rtl">
											{product.product_name_ar || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.parent_category || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.parent_sub_category || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.sub_category || '-'}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Results Summary -->
					<div class="mt-4 text-center text-sm text-gray-600">
						Showing {filteredProducts.length} of {allProducts.length} products
						{#if searchQuery}
							(filtered by: "{searchQuery}")
						{/if}
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>
