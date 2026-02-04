<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import VariationSelectionModal from '$lib/components/desktop-interface/marketing/flyer/VariationSelectionModal.svelte';

	// Cache configuration (shared across all flyer components)
	const CACHE_KEY = 'flyer_products_cache';
	const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

	// Image loading tracking
	let successfullyLoadedImages: Set<string> = new Set();
	let imageRefs: Record<string, HTMLImageElement> = {};

	let offerTemplates: any[] = [];
	let selectedTemplate: any = null;
	let allProducts: any[] = [];
	let selectedProducts: Set<string> = new Set();
	let isLoadingTemplates: boolean = true;
	let isLoadingProducts: boolean = false;
	let isSaving: boolean = false;
	let searchQuery: string = '';
	let filteredProducts: any[] = [];
	let selectedCategoryId: string = '';
	let categories: any[] = [];
	let categoryMap: Map<string, string> = new Map();
	let unitMap: Map<string, string> = new Map();
	
	// Page/Order tracking for products
	let productPageOrderMap: Map<string, {page: number, order: number}> = new Map();
	
	// Page selection modal state
	let showPageSelectModal: boolean = false;
	let pendingProductBarcode: string = '';
	let selectedPage: number = 1;
	
	// Variation modal state
	let showVariationModal: boolean = false;
	let currentVariationGroup: any = null;
	let currentVariations: any[] = [];
	let pendingVariantBarcodes: string[] = []; // Barcodes pending page assignment after variant selection

	// Load all active offer templates
	async function loadOfferTemplates() {
		isLoadingTemplates = true;
		try {
			const { data, error } = await supabase
				.from('flyer_offers')
				.select(`
					*,
					offer_name:offer_names(id, name_en, name_ar)
				`)
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

		// Try to load products from cache first
		let cachedProducts: any[] | null = null;
		try {
			const cached = localStorage.getItem(CACHE_KEY);
			if (cached) {
				const { data, timestamp } = JSON.parse(cached);
				const age = Date.now() - timestamp;
				
				if (age < CACHE_DURATION) {
					console.log('✓ Loading products from cache (age: ' + Math.round(age / 1000) + 's)');
					cachedProducts = data;
				}
			}
		} catch (err) {
			console.warn('Cache read error:', err);
		}

		try {
			const loadTasks = [
				// Load categories
				supabase
					.from('product_categories')
					.select('id, name_en')
					.eq('is_active', true),
				// Load units
				supabase
					.from('product_units')
					.select('id, name_en'),
				// Load selected products for this template with page/order
				supabase
					.from('flyer_offer_products')
					.select('product_barcode, page_number, page_order')
					.eq('offer_id', templateId)
			];
			
			// Only load products from DB if not cached
			if (!cachedProducts) {
				loadTasks.push(
					supabase
						.from('products')
						.select('barcode, product_name_en, product_name_ar, unit_id, category_id, image_url, is_variation, variation_group_name_en')
						.order('barcode', { ascending: true })
				);
			}
			
			// Load everything in parallel for better performance
			const results = await Promise.all(loadTasks);
			const [categoriesResult, unitsResult, selectedResult, productsResult] = results;

			// Process categories
			if (categoriesResult.error) {
				console.error('Error loading categories:', categoriesResult.error);
			} else if (categoriesResult.data) {
				categories = categoriesResult.data;
				categoriesResult.data.forEach(cat => {
					categoryMap.set(cat.id, cat.name_en);
				});
			}

			// Process units
			if (unitsResult.error) {
				console.error('Error loading units:', unitsResult.error);
			} else if (unitsResult.data) {
				unitsResult.data.forEach(unit => {
					unitMap.set(unit.id, unit.name_en);
				});
			}

			// Process products - use cache or fresh data
			if (cachedProducts) {
				// Use cached products
				allProducts = cachedProducts;
			} else if (productsResult) {
				// Fresh load from database
				if (productsResult.error) {
					console.error('Error loading products:', productsResult.error);
					alert('Error loading products. Please try again.');
					isLoadingProducts = false;
					return;
				}

				allProducts = productsResult.data || [];
				
				// Cache the loaded data
				try {
					localStorage.setItem(CACHE_KEY, JSON.stringify({
						data: allProducts,
						timestamp: Date.now()
					}));
					console.log('✓ Products cached to localStorage');
				} catch (err) {
					console.warn('Cache write error:', err);
				}
			}

			// Process selected products with page/order
			productPageOrderMap.clear();
			if (selectedResult.error) {
				console.error('Error loading selected products:', selectedResult.error);
				alert('Error loading selected products. Please try again.');
			} else if (selectedResult.data) {
				selectedResult.data.forEach(item => {
					selectedProducts.add(item.product_barcode);
					productPageOrderMap.set(item.product_barcode, {
						page: item.page_number || 1,
						order: item.page_order || 1
					});
				});
				productPageOrderMap = productPageOrderMap;
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
		
		// Apply category filter
		if (selectedCategoryId) {
			products = products.filter(p => p.category_id === selectedCategoryId);
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
		
		// Sort: selected products first (sorted by page-order), then unselected
		filteredProducts = products.sort((a, b) => {
			const aSelected = selectedProducts.has(a.barcode);
			const bSelected = selectedProducts.has(b.barcode);
			
			// Selected products come first
			if (aSelected && !bSelected) return -1;
			if (!aSelected && bSelected) return 1;
			
			// Both selected: sort by page, then by order
			if (aSelected && bSelected) {
				const aPageOrder = productPageOrderMap.get(a.barcode);
				const bPageOrder = productPageOrderMap.get(b.barcode);
				const aPage = aPageOrder?.page || 999;
				const bPage = bPageOrder?.page || 999;
				const aOrder = aPageOrder?.order || 999;
				const bOrder = bPageOrder?.order || 999;
				
				if (aPage !== bPage) return aPage - bPage;
				return aOrder - bOrder;
			}
			
			// Neither selected: keep original order
			return 0;
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

	// Handle search input and filters
	$: {
		searchQuery;
		selectedCategoryId;
		filterProducts();
	}

	// Select a template
	function selectTemplate(template: any) {
		selectedTemplate = template;
		loadProductsForTemplate(template.id);
	}

	// Toggle product selection
	async function toggleProduct(barcode: string) {
		// Find the product
		const product = allProducts.find(p => p.barcode === barcode);
		if (!product) return;
		
		// Check if product is part of a variation group
		if (product.is_variation && product.variation_group_name_en) {
			// Load all variations in the group and show modal
			await loadVariationGroup(barcode);
			return;
		}
		
		// Normal product toggle
		if (selectedProducts.has(barcode)) {
			// Removing product - delete and reassign orders
			selectedProducts.delete(barcode);
			const removedPageOrder = productPageOrderMap.get(barcode);
			productPageOrderMap.delete(barcode);
			
			// Reassign orders for remaining products on the same page
			if (removedPageOrder) {
				reassignOrdersForPage(removedPageOrder.page);
			}
			
			selectedProducts = selectedProducts;
			productPageOrderMap = productPageOrderMap;
			filterProducts();
		} else {
			// Adding product - show modal to select page
			pendingProductBarcode = barcode;
			selectedPage = 1;
			showPageSelectModal = true;
		}
	}
	
	// Load variation group for modal
	async function loadVariationGroup(clickedBarcode: string) {
		try {
			const product = allProducts.find(p => p.barcode === clickedBarcode);
			if (!product || !product.variation_group_name_en) return;
			
			// Get all products in the same variation group
			const { data, error } = await supabase
				.from('products')
				.select('*')
				.eq('variation_group_name_en', product.variation_group_name_en)
				.eq('is_active', true);
			
			if (error) {
				console.error('Error loading variations:', error);
				alert('Error loading variation group. Please try again.');
				return;
			}
			
			// Add any missing products to allProducts so they're available for saving
			data.forEach(p => {
				if (!allProducts.find(ap => ap.barcode === p.barcode)) {
					allProducts.push(p);
				}
			});
			allProducts = allProducts; // Trigger reactivity
			
			// Separate parent from variations (use clicked barcode as fallback parent)
			const parentProduct = data.find(p => p.parent_product_barcode === null || p.barcode === clickedBarcode);
			const variations = data.filter(p => p.parent_product_barcode !== null && p.barcode !== (parentProduct?.barcode || clickedBarcode));
			
			if (!parentProduct) {
				console.error('Parent product not found in variation group');
				return;
			}
			
			// Show variation selection modal
			currentVariationGroup = parentProduct;
			currentVariations = variations;
			showVariationModal = true;
		} catch (error) {
			console.error('Error loading variation group:', error);
			alert('Error loading variation group. Please try again.');
		}
	}
	
	// Handle variation selection confirmation
	function handleVariationConfirm(event: CustomEvent) {
		const { selectedBarcodes } = event.detail;
		
		// Get all barcodes in this group
		const groupBarcodes = [currentVariationGroup.barcode, ...currentVariations.map(v => v.barcode)];
		
		// Check if any variant in the group already has a page/order assigned BEFORE removing
		let existingPageOrder: { page: number, order: number } | null = null;
		for (const bc of groupBarcodes) {
			const po = productPageOrderMap.get(bc);
			if (po) {
				existingPageOrder = { page: po.page, order: po.order };
				break;
			}
		}
		
		// Remove all products from this group (don't trigger reactivity yet)
		groupBarcodes.forEach(bc => {
			selectedProducts.delete(bc);
			productPageOrderMap.delete(bc);
		});
		
		// Close variation modal
		showVariationModal = false;
		currentVariationGroup = null;
		currentVariations = [];
		
		// If variants were selected
		if (selectedBarcodes.length > 0) {
			if (existingPageOrder) {
				// Use existing page/order for all selected variants (same page/order as group)
				selectedBarcodes.forEach((barcode: string) => {
					selectedProducts.add(barcode);
					productPageOrderMap.set(barcode, { page: existingPageOrder!.page, order: existingPageOrder!.order });
				});
				// Trigger reactivity ONCE after all changes
				selectedProducts = selectedProducts;
				productPageOrderMap = productPageOrderMap;
				filterProducts();
			} else {
				// Trigger reactivity for deletions first
				selectedProducts = selectedProducts;
				productPageOrderMap = productPageOrderMap;
				// No existing page/order - show page selection modal
				pendingVariantBarcodes = selectedBarcodes;
				selectedPage = 1;
				showPageSelectModal = true;
			}
		} else {
			// Trigger reactivity after all deletions
			selectedProducts = selectedProducts;
			productPageOrderMap = productPageOrderMap;
			filterProducts();
		}
	}
	
	// Handle variation modal cancel
	function handleVariationCancel() {
		showVariationModal = false;
		currentVariationGroup = null;
		currentVariations = [];
	}
	
	// Get next order for a page
	function getNextOrderForPage(page: number): number {
		let maxOrder = 0;
		productPageOrderMap.forEach((po) => {
			if (po.page === page && po.order > maxOrder) {
				maxOrder = po.order;
			}
		});
		return maxOrder + 1;
	}
	
	// Reassign orders for all products on a page sequentially
	// Keeps variants in the same group with the same order number
	function reassignOrdersForPage(page: number) {
		// Get all products on this page with their variation group
		const productsOnPage: {barcode: string, order: number, variationGroup: string | null}[] = [];
		productPageOrderMap.forEach((po, barcode) => {
			if (po.page === page) {
				const product = allProducts.find(p => p.barcode === barcode);
				const variationGroup = product?.is_variation ? product.variation_group_name_en : null;
				productsOnPage.push({ barcode, order: po.order, variationGroup });
			}
		});
		
		// Sort by current order
		productsOnPage.sort((a, b) => a.order - b.order);
		
		// Group by variation group and assign sequential orders
		// Variants in the same group get the same order
		let currentOrder = 0;
		const groupOrderMap = new Map<string, number>(); // variation_group_name -> assigned order
		
		productsOnPage.forEach((item) => {
			let assignedOrder: number;
			
			if (item.variationGroup) {
				// This is a variant - check if its group already has an order
				if (groupOrderMap.has(item.variationGroup)) {
					assignedOrder = groupOrderMap.get(item.variationGroup)!;
				} else {
					// First variant of this group encountered
					currentOrder++;
					groupOrderMap.set(item.variationGroup, currentOrder);
					assignedOrder = currentOrder;
				}
			} else {
				// Normal product - gets its own order
				currentOrder++;
				assignedOrder = currentOrder;
			}
			
			const existing = productPageOrderMap.get(item.barcode);
			if (existing) {
				productPageOrderMap.set(item.barcode, { page: existing.page, order: assignedOrder });
			}
		});
	}
	
	// Confirm page selection and add product(s)
	function confirmPageSelection() {
		const nextOrder = getNextOrderForPage(selectedPage);
		
		// Check if we're adding variant group or single product
		if (pendingVariantBarcodes.length > 0) {
			// Add all variants with SAME page/order (they share one slot)
			pendingVariantBarcodes.forEach((bc: string) => {
				selectedProducts.add(bc);
				productPageOrderMap.set(bc, { page: selectedPage, order: nextOrder });
			});
			pendingVariantBarcodes = [];
		} else if (pendingProductBarcode) {
			// Single product
			selectedProducts.add(pendingProductBarcode);
			productPageOrderMap.set(pendingProductBarcode, { page: selectedPage, order: nextOrder });
			pendingProductBarcode = '';
		}
		
		selectedProducts = selectedProducts;
		productPageOrderMap = productPageOrderMap;
		filterProducts();
		
		// Close modal
		showPageSelectModal = false;
	}
	
	// Cancel page selection
	function cancelPageSelection() {
		showPageSelectModal = false;
		pendingProductBarcode = '';
		pendingVariantBarcodes = [];
	}
	
	// Update page/order for a product
	function updateProductPageOrder(barcode: string, newPage: number, newOrder: number) {
		const existing = productPageOrderMap.get(barcode);
		if (existing) {
			const oldPage = existing.page;
			productPageOrderMap.set(barcode, { page: newPage, order: newOrder });
			productPageOrderMap = productPageOrderMap;
			
			// If page changed, reassign orders on old page
			if (oldPage !== newPage) {
				reassignOrdersForPage(oldPage);
			}
			
			filterProducts();
		}
	}
	
	// Get unique pages from current selections
	function getUniquePages(): number[] {
		const pages = new Set<number>();
		productPageOrderMap.forEach((po) => pages.add(po.page));
		return Array.from(pages).sort((a, b) => a - b);
	}

	// Save product selections
	async function saveProductSelections() {
		if (!selectedTemplate) return;

		isSaving = true;

		try {
			// First, delete all existing product selections for this template
			const { error: deleteError } = await supabase
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
					const pageOrder = productPageOrderMap.get(barcode);
					
					return {
						offer_id: selectedTemplate.id,
						product_barcode: barcode,
						page_number: pageOrder?.page || 1,
						page_order: pageOrder?.order || 1,
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

				const { error: insertError } = await supabase
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
		selectedCategoryId = '';
		categories = [];
		categoryMap.clear();
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
								{#if template.offer_name && template.offer_name.name_en}
									<h3 class="text-lg font-bold text-gray-800 mb-1">{template.offer_name.name_en}</h3>
										<p class="text-sm text-gray-600 mb-1">Template: {template.template_name}</p>
									{:else}
										<h3 class="text-lg font-bold text-gray-800 mb-1">{template.template_name}</h3>
									{/if}
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
						{#if selectedTemplate.offer_name && selectedTemplate.offer_name.name_en}
							<h2 class="text-2xl font-bold text-gray-800">{selectedTemplate.offer_name.name_en}</h2>
								<p class="text-sm text-gray-600">Template: {selectedTemplate.template_name} • {selectedTemplate.template_id}</p>
							{:else}
								<h2 class="text-2xl font-bold text-gray-800">{selectedTemplate.template_name}</h2>
								<p class="text-sm text-gray-600">{selectedTemplate.template_id}</p>
							{/if}
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

				<!-- Category Filter -->
				<div class="flex gap-4">
					<div class="flex-1">
						<label class="block text-sm font-medium text-gray-700 mb-2">Category</label>
						<select
							bind:value={selectedCategoryId}
							class="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
						>
							<option value="">All Categories</option>
							{#each categories as category}
								<option value={category.id}>{category.name_en}</option>
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
									</th>								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Image URL
								</th>									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Product Name (EN)
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Product Name (AR)
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Unit
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Category
									</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
										Variation Group
									</th>
									<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
										Page-Order
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
													<svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
													</svg>
												{/if}
											</div>
										</td>
										<td class="px-6 py-4 text-sm font-medium text-gray-900">
											{product.barcode}
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
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.product_name_en || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900" dir="rtl">
											{product.product_name_ar || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.unit_id ? (unitMap.get(product.unit_id) || '-') : '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900">
											{product.category_id ? (categoryMap.get(product.category_id) || '-') : '-'}
										</td>
										<td class="px-6 py-4 text-sm">
											{#if product.is_variation && product.variation_group_name_en}
												<span class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded font-medium inline-flex items-center gap-1">
													🔗 {product.variation_group_name_en}
												</span>
											{:else}
												<span class="text-gray-400">—</span>
											{/if}
										</td>
										<td class="px-6 py-4 text-sm text-center">
											{#if selectedProducts.has(product.barcode)}
												{@const pageOrder = productPageOrderMap.get(product.barcode)}
												{#if pageOrder}
													<div class="flex items-center justify-center gap-1">
														<input 
															type="number"
															min="1"
															value={pageOrder.page}
															on:change={(e) => {
																const newPage = parseInt(e.currentTarget.value) || 1;
																const nextOrder = getNextOrderForPage(newPage);
																updateProductPageOrder(product.barcode, newPage, nextOrder);
															}}
															class="w-16 h-10 text-base text-center border border-gray-300 rounded focus:ring-blue-500 font-bold"
															title="Page number"
														/>
														<span class="text-gray-500 font-bold text-lg">-</span>
														<input 
															type="number"
															min="1"
															value={pageOrder.order}
															on:change={(e) => {
																const newOrder = parseInt(e.currentTarget.value) || 1;
																updateProductPageOrder(product.barcode, pageOrder.page, newOrder);
															}}
															class="w-16 h-10 text-base text-center border border-gray-300 rounded focus:ring-blue-500 font-bold"
															title="Order on page"
														/>
													</div>
												{:else}
													<span class="text-gray-400">—</span>
												{/if}
											{:else}
												<span class="text-gray-400">—</span>
											{/if}
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

<!-- Page Selection Modal -->
{#if showPageSelectModal}
	{@const pendingProduct = allProducts.find(p => p.barcode === pendingProductBarcode)}
	{@const isVariantGroup = pendingVariantBarcodes.length > 0}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg shadow-xl max-w-md w-full">
			<div class="p-6 border-b border-gray-200">
				<h2 class="text-xl font-bold text-gray-800">Select Page</h2>
				<p class="text-sm text-gray-600 mt-1">
					{#if isVariantGroup}
						Adding {pendingVariantBarcodes.length} variant product{pendingVariantBarcodes.length > 1 ? 's' : ''} (same page/order)
					{:else}
						Adding: {pendingProduct?.product_name_en || pendingProductBarcode}
					{/if}
				</p>
			</div>
			
			<div class="p-6 space-y-4">
				<div>
					<span class="block text-sm font-medium text-gray-700 mb-2">Page Number</span>
					<div class="flex items-center gap-2">
						<input 
							type="number"
							min="1"
							bind:value={selectedPage}
							class="w-20 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-lg font-bold text-center"
						/>
						<span class="text-sm text-gray-500">
							(Next order: {getNextOrderForPage(selectedPage)})
						</span>
					</div>
				</div>
				
				{#if getUniquePages().length > 0}
					<div>
						<span class="block text-sm font-medium text-gray-700 mb-2">Existing Pages</span>
						<div class="flex flex-wrap gap-2">
							{#each getUniquePages() as page}
								<button
									type="button"
									on:click={() => selectedPage = page}
									class="px-3 py-1 text-sm rounded-lg transition-colors {selectedPage === page ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
								>
									Page {page}
								</button>
							{/each}
						</div>
					</div>
				{/if}
			</div>
			
			<div class="p-6 border-t border-gray-200 flex items-center justify-end gap-3">
				<button
					on:click={cancelPageSelection}
					class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
				>
					Cancel
				</button>
				<button
					on:click={confirmPageSelection}
					class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
					</svg>
					Add to Page {selectedPage}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Variation Selection Modal -->
{#if showVariationModal && currentVariationGroup}
	{@const groupBarcodes = new Set([currentVariationGroup.barcode, ...currentVariations.map(v => v.barcode)])}
	{@const preSelected = new Set([...groupBarcodes].filter(b => selectedProducts.has(b)))}
	<VariationSelectionModal
		parentProduct={currentVariationGroup}
		variations={currentVariations}
		templateId={selectedTemplate?.id || ''}
		preSelectedBarcodes={preSelected}
		on:confirm={handleVariationConfirm}
		on:cancel={handleVariationCancel}
	/>
{/if}