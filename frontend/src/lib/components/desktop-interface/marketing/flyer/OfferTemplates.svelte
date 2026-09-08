<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount, onDestroy } from 'svelte';
	import VariationSelectionModal from '$lib/components/desktop-interface/marketing/flyer/VariationSelectionModal.svelte';
	import SearchableDropdown from '$lib/components/desktop-interface/marketing/flyer/SearchableDropdown.svelte';
	// Same Gemini key (system_api_keys, service_name='google_gemini') the
	// WhatsApp AI Reply bot uses — see supabase/functions/whatsapp-webhook.
	import { correctAndTranslateProductName as aiCorrectAndTranslateProductName } from '$lib/utils/translationService';

	// When true, renders the compact layout (stacked header, hidden category
	// filter, camera scan, inline Create Product, paginated RPC loading) —
	// used by the mobile Offer Selector page. Desktop windows also opt into
	// this now, just with the table view for the product list itself (see
	// useCardLayout below), so both surfaces share the same RPC/UX plumbing.
	export let mobile = false;

	// Controls only the product list's layout: cards (phone-friendly) vs the
	// original wide table. Defaults to whatever `mobile` is, but can be set
	// independently — e.g. desktop passes mobile=true (for the shared RPC
	// loading + inline create-product features) with useCardLayout=false
	// (to keep the table, since desktop windows have the width for it).
	export let useCardLayout = mobile;

	// Cache removed - always load fresh data directly

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
	let units: any[] = [];
	let categoryMap: Map<string, string> = new Map();
	let unitMap: Map<string, string> = new Map();
	
	// Page/Order tracking for products
	let productPageOrderMap: Map<string, {page: number, order: number}> = new Map();
	
	// Store existing flyer_offer_products data to preserve pricing on save
	let existingOfferProductData: Map<string, any> = new Map();
	
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
				// Load selected products for this template with ALL fields (to preserve pricing on save)
				supabase
					.from('flyer_offer_products')
					.select('*')
					.eq('offer_id', templateId),
				// Always load products fresh from DB
				supabase
					.from('products')
					.select('barcode, product_name_en, product_name_ar, unit_id, category_id, image_url, is_variation, variation_group_name_en, cost, sale_price')
					.order('barcode', { ascending: true })
			];
			
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

			// Process products - always fresh data
			if (productsResult) {
				if (productsResult.error) {
					console.error('Error loading products:', productsResult.error);
					alert('Error loading products. Please try again.');
					isLoadingProducts = false;
					return;
				}
				allProducts = productsResult.data || [];
			}

			// Process selected products with page/order and store full data
			productPageOrderMap.clear();
			existingOfferProductData.clear();
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
					// Store full row data so we can preserve pricing fields on save
					existingOfferProductData.set(item.product_barcode, item);
				});
				productPageOrderMap = productPageOrderMap;
				existingOfferProductData = existingOfferProductData;
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
		// Mobile loads products page-by-page via the get_offer_editor_products
		// RPC (search/category filtering and selected-first sorting already
		// happen server-side — see loadMobileProducts), so allProducts IS the
		// filtered list already; nothing left to do client-side.
		if (mobile) {
			filteredProducts = allProducts;
			return;
		}

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

	// --- Mobile: paginated product loading via get_offer_editor_products RPC ---
	// Avoids pulling the entire ~2500-row product catalog on every template
	// open; instead fetches it a page at a time, with search filtering and
	// selected-first sorting done server-side.
	const MOBILE_PAGE_SIZE = 40;
	let mobileTotalCount = 0;
	let mobileOffset = 0;
	let mobileHasMore = false;
	let isLoadingMoreProducts = false;
	let mobileSearchDebounce: ReturnType<typeof setTimeout> | null = null;

	async function loadMobileProducts(reset: boolean) {
		if (!selectedTemplate) return;

		if (reset) {
			isLoadingProducts = true;
			mobileOffset = 0;
			mobileHasMore = false;
			allProducts = [];
			categoryMap.clear();
			unitMap.clear();
			selectedProducts.clear();
			productPageOrderMap.clear();
			existingOfferProductData.clear();
		} else {
			if (!mobileHasMore || isLoadingMoreProducts) return;
			isLoadingMoreProducts = true;
		}

		try {
			const { data, error } = await supabase.rpc('get_offer_editor_products', {
				p_offer_id: selectedTemplate.id,
				p_search: searchQuery.trim() || null,
				p_category_id: null, // category filter is hidden on mobile
				p_limit: MOBILE_PAGE_SIZE,
				p_offset: mobileOffset
			});

			if (error || !data) {
				console.error('Error loading products (mobile RPC):', error);
				alert('Error loading products. Please try again.');
				return;
			}

			if (reset) {
				units = data.units || [];
				categories = data.categories || [];
				(data.units || []).forEach((u: any) => unitMap.set(u.id, u.name_en));
				(data.categories || []).forEach((c: any) => categoryMap.set(c.id, c.name_en));
				(data.selected || []).forEach((item: any) => {
					selectedProducts.add(item.product_barcode);
					productPageOrderMap.set(item.product_barcode, {
						page: item.page_number || 1,
						order: item.page_order || 1
					});
					existingOfferProductData.set(item.product_barcode, item);
				});
				selectedProducts = selectedProducts;
				productPageOrderMap = productPageOrderMap;
				existingOfferProductData = existingOfferProductData;
			}

			const page = data.products || [];
			allProducts = [...allProducts, ...page];
			mobileTotalCount = data.total_count || 0;
			mobileOffset += page.length;
			mobileHasMore = mobileOffset < mobileTotalCount;
			filterProducts();
		} catch (error) {
			console.error('Error loading products (mobile RPC):', error);
			alert('Error loading products. Please try again.');
		} finally {
			isLoadingProducts = false;
			isLoadingMoreProducts = false;
		}
	}

	// Debounced re-fetch, triggered by typing in the search field (mobile only)
	function scheduleMobileSearch() {
		if (mobileSearchDebounce) clearTimeout(mobileSearchDebounce);
		mobileSearchDebounce = setTimeout(() => loadMobileProducts(true), 350);
	}

	// --- Mobile: inline "Create Product" / "Edit Product" (not a popup) ---
	// Lets a user add a barcode that doesn't exist in the products table at
	// all yet, straight from the offer editor, then immediately flows into
	// the normal page/order picker to add it to the current offer. The same
	// form doubles as an edit form (per-product ✏️ button) for fixing up an
	// existing product's name/category/unit/image — barcode stays locked
	// there since it's the join key everything else (offers, prices) hangs
	// off of.
	let showInlineCreateProduct = false;
	let isEditingProduct = false;
	let editingOriginalBarcode = '';
	let isCreatingProduct = false;
	let isCheckingNewProductImage = false;
	let createProductError = '';
	function blankNewProductForm() {
		return { barcode: '', product_name_en: '', product_name_ar: '', unit_id: '', category_id: '', image_url: '' };
	}
	let newProductForm = blankNewProductForm();

	function toggleInlineCreateProduct() {
		showInlineCreateProduct = !showInlineCreateProduct;
		createProductError = '';
		isEditingProduct = false;
		if (showInlineCreateProduct) {
			newProductForm = blankNewProductForm();
		}
	}

	function openEditProduct(product: any) {
		isEditingProduct = true;
		editingOriginalBarcode = product.barcode;
		createProductError = '';
		newProductForm = {
			barcode: product.barcode,
			product_name_en: product.product_name_en || '',
			product_name_ar: product.product_name_ar || '',
			unit_id: product.unit_id || '',
			category_id: product.category_id || '',
			image_url: product.image_url || ''
		};
		showInlineCreateProduct = true;
	}

	// Look up whether an image already exists in storage for the typed
	// barcode (same convention desktop's Product Master uses) and fill it in.
	async function checkNewProductImage() {
		const barcode = newProductForm.barcode.trim();
		if (!barcode) {
			createProductError = 'Enter a barcode first.';
			return;
		}
		isCheckingNewProductImage = true;
		try {
			const { data: urlData } = supabase.storage.from('flyer-product-images').getPublicUrl(`${barcode}.png`);
			const response = await fetch(urlData.publicUrl);
			if (response.ok) {
				newProductForm = { ...newProductForm, image_url: urlData.publicUrl };
			} else {
				createProductError = 'No image found for this barcode yet — you can still create the product without one.';
			}
		} catch (err) {
			console.error('Error checking product image:', err);
		} finally {
			isCheckingNewProductImage = false;
		}
	}

	// Single-button AI action: fix spelling and reorder into natural product-
	// name grammar (e.g. "apple amerca" -> "American Apple"), uppercase it,
	// then translate that corrected name into Arabic — one Gemini call, via
	// the same key the WhatsApp AI Reply bot uses. Uses a dedicated product-
	// name prompt (see translationService.correctAndTranslateProductName),
	// not the shared correctSpelling() used elsewhere in the app (checklist
	// text), which has different rules and shouldn't change behavior there.
	let isFixingProductName = false;
	async function handleFixProductNameClick() {
		const raw = newProductForm.product_name_en.trim();
		if (!raw) {
			createProductError = 'Type the product name (English) first.';
			return;
		}
		createProductError = '';
		isFixingProductName = true;
		try {
			const { en, ar } = await aiCorrectAndTranslateProductName(raw);
			const finalEn = (en || raw).toUpperCase();
			newProductForm = { ...newProductForm, product_name_en: finalEn };
			if (ar) {
				newProductForm = { ...newProductForm, product_name_ar: ar };
			}
		} catch (err: any) {
			console.error('AI name correction/translation error:', err);
			createProductError = err?.message || 'AI correction/translation failed — you can still type the Arabic name manually.';
		} finally {
			isFixingProductName = false;
		}
	}

	async function createInlineProduct() {
		createProductError = '';
		const barcode = newProductForm.barcode.trim();
		const nameEn = newProductForm.product_name_en.trim();

		if (!barcode) { createProductError = 'Barcode is required.'; return; }
		if (!nameEn) { createProductError = 'Product name (English) is required.'; return; }

		isCreatingProduct = true;
		try {
			const { data: existing } = await supabase
				.from('products')
				.select('barcode')
				.eq('barcode', barcode)
				.maybeSingle();
			if (existing) {
				createProductError = 'A product with this barcode already exists.';
				isCreatingProduct = false;
				return;
			}

			// Generate the next P{n} id, same convention as desktop Product Master
			const { data: idRows, error: idError } = await supabase.from('products').select('id');
			if (idError) {
				console.error('Error generating product id:', idError);
				createProductError = 'Failed to create product. Please try again.';
				isCreatingProduct = false;
				return;
			}
			let highestNum = 0;
			(idRows || []).forEach((p: any) => {
				const match = p.id?.match(/\d+/);
				if (match) highestNum = Math.max(highestNum, parseInt(match[0]));
			});
			const newId = `P${highestNum + 1}`;

			const newProductRow = {
				id: newId,
				barcode,
				product_name_en: nameEn,
				product_name_ar: newProductForm.product_name_ar.trim() || null,
				unit_id: newProductForm.unit_id || null,
				category_id: newProductForm.category_id || null,
				image_url: newProductForm.image_url.trim() || null,
				created_at: new Date().toISOString(),
				updated_at: new Date().toISOString()
			};

			const { error } = await supabase.from('products').insert(newProductRow);
			if (error) {
				console.error('Error creating product:', error);
				createProductError = 'Failed to create product: ' + error.message;
				isCreatingProduct = false;
				return;
			}

			// Make the new product available locally so the normal add-to-offer
			// flow (page/order picker) can pick it up right away.
			allProducts = [{
				barcode,
				product_name_en: nameEn,
				product_name_ar: newProductRow.product_name_ar,
				unit_id: newProductRow.unit_id,
				category_id: newProductRow.category_id,
				image_url: newProductRow.image_url,
				is_variation: false,
				variation_group_name_en: null,
				cost: 0,
				sale_price: 0
			}, ...allProducts];
			filterProducts();

			showInlineCreateProduct = false;
			newProductForm = blankNewProductForm();
			await toggleProduct(barcode);
		} catch (err) {
			console.error('Error creating product:', err);
			createProductError = 'Error creating product. Please try again.';
		} finally {
			isCreatingProduct = false;
		}
	}

	// Update an existing product's details (name/category/unit/image).
	// Barcode is never sent — it's locked in the UI and is the join key
	// flyer_offer_products, orders, etc. all reference.
	async function saveEditedProduct() {
		createProductError = '';
		const nameEn = newProductForm.product_name_en.trim();
		if (!nameEn) { createProductError = 'Product name (English) is required.'; return; }

		isCreatingProduct = true;
		try {
			const updates = {
				product_name_en: nameEn,
				product_name_ar: newProductForm.product_name_ar.trim() || null,
				unit_id: newProductForm.unit_id || null,
				category_id: newProductForm.category_id || null,
				image_url: newProductForm.image_url.trim() || null,
				updated_at: new Date().toISOString()
			};

			const { error } = await supabase
				.from('products')
				.update(updates)
				.eq('barcode', editingOriginalBarcode);

			if (error) {
				console.error('Error updating product:', error);
				createProductError = 'Failed to save changes: ' + error.message;
				isCreatingProduct = false;
				return;
			}

			// Reflect the edit in the locally-loaded product immediately.
			allProducts = allProducts.map(p =>
				p.barcode === editingOriginalBarcode ? { ...p, ...updates } : p
			);
			filterProducts();

			showInlineCreateProduct = false;
			isEditingProduct = false;
			newProductForm = blankNewProductForm();
		} catch (err) {
			console.error('Error updating product:', err);
			createProductError = 'Error saving changes. Please try again.';
		} finally {
			isCreatingProduct = false;
		}
	}

	// Select a template
	function selectTemplate(template: any) {
		selectedTemplate = template;
		if (mobile) {
			loadMobileProducts(true);
		} else {
			loadProductsForTemplate(template.id);
		}
	}

	// Toggle product selection
	async function toggleProduct(barcode: string) {
		// Find the product
		const product = allProducts.find(p => p.barcode === barcode);
		if (!product) return;
		
		// Check if product is part of a variation group
		if (product.is_variation && product.variation_group_name_en) {
			// If already selected, REMOVE all variants in the group directly (no modal)
			if (selectedProducts.has(barcode)) {
				const groupBarcodes = [...allProducts]
					.filter(p => p.variation_group_name_en === product.variation_group_name_en)
					.map(p => p.barcode);
				
				let removedPage: number | null = null;
				groupBarcodes.forEach(bc => {
					if (removedPage === null) {
						const po = productPageOrderMap.get(bc);
						if (po) removedPage = po.page;
					}
					selectedProducts.delete(bc);
					productPageOrderMap.delete(bc);
				});
				
				if (removedPage !== null) {
					reassignOrdersForPage(removedPage);
				}
				
				selectedProducts = selectedProducts;
				productPageOrderMap = productPageOrderMap;
				filterProducts();
				return;
			}
			
			// Not selected yet - load all variations in the group and show modal
			await loadVariationGroup(barcode);
			return;
		}
		
		// Normal product toggle
		if (selectedProducts.has(barcode)) {
			// Removing product - get page info BEFORE deleting
			const removedPageOrder = productPageOrderMap.get(barcode);
			selectedProducts.delete(barcode);
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
				.eq('variation_group_name_en', product.variation_group_name_en);
			
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
			// All variants deselected - reassign orders on affected page
			if (existingPageOrder) {
				reassignOrdersForPage(existingPageOrder.page);
			}
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
			// Determine which products were removed
			const previousBarcodes = new Set(existingOfferProductData.keys());
			const currentBarcodes = new Set(selectedProducts);
			const removedBarcodes = [...previousBarcodes].filter(b => !currentBarcodes.has(b));
			
			// Step 1: Delete only REMOVED products (not all)
			if (removedBarcodes.length > 0) {
				const { error: deleteError } = await supabase
					.from('flyer_offer_products')
					.delete()
					.eq('offer_id', selectedTemplate.id)
					.in('product_barcode', removedBarcodes);

				if (deleteError) {
					console.error('Error deleting removed products:', deleteError);
					alert('Error removing products. Please try again.');
					isSaving = false;
					return;
				}
			}

			// Step 2: Upsert all current products (insert new, update existing page/order)
			if (selectedProducts.size > 0) {
				const upsertData = Array.from(selectedProducts).map(barcode => {
					const product = allProducts.find(p => p.barcode === barcode);
					const pageOrder = productPageOrderMap.get(barcode);
					const existing = existingOfferProductData.get(barcode);
					
					if (existing) {
						// Product already existed — preserve ALL fields, only update page/order
						return {
							offer_id: selectedTemplate.id,
							product_barcode: barcode,
							page_number: pageOrder?.page || existing.page_number || 1,
							page_order: pageOrder?.order || existing.page_order || 1,
							cost: existing.cost,
							sales_price: existing.sales_price,
							offer_price: existing.offer_price,
							profit_amount: existing.profit_amount,
							profit_percent: existing.profit_percent,
							profit_after_offer: existing.profit_after_offer,
							decrease_amount: existing.decrease_amount,
							offer_qty: existing.offer_qty,
							limit_qty: existing.limit_qty,
							free_qty: existing.free_qty,
							total_sales_price: existing.total_sales_price,
							total_offer_price: existing.total_offer_price
						};
					} else {
						// New product — use cost/sale_price from products table
						const cost = product?.cost || 0;
						const salesPrice = product?.sale_price || 0;
						return {
							offer_id: selectedTemplate.id,
							product_barcode: barcode,
							page_number: pageOrder?.page || 1,
							page_order: pageOrder?.order || 1,
							cost: cost,
							sales_price: salesPrice,
							profit_amount: cost && salesPrice ? (salesPrice - cost) : 0,
							profit_percent: cost && salesPrice && cost > 0 ? ((salesPrice - cost) / cost) * 100 : 0,
							offer_qty: 1,
							limit_qty: null,
							free_qty: 0,
							offer_price: 0,
							profit_after_offer: 0,
							decrease_amount: 0,
							total_sales_price: 0,
							total_offer_price: 0
						};
					}
				});

				const { error: upsertError } = await supabase
					.from('flyer_offer_products')
					.upsert(upsertData, { onConflict: 'offer_id,product_barcode' });

				if (upsertError) {
					console.error('Error upserting products:', upsertError);
					alert('Error saving product selections. Please try again.');
					isSaving = false;
					return;
				}
			}

			// Refresh existingOfferProductData with the newly saved data
			const { data: refreshedData } = await supabase
				.from('flyer_offer_products')
				.select('*')
				.eq('offer_id', selectedTemplate.id);
			if (refreshedData) {
				existingOfferProductData.clear();
				refreshedData.forEach(item => {
					existingOfferProductData.set(item.product_barcode, item);
				});
				existingOfferProductData = existingOfferProductData;
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
		mobileOffset = 0;
		mobileTotalCount = 0;
		mobileHasMore = false;
		if (mobileSearchDebounce) { clearTimeout(mobileSearchDebounce); mobileSearchDebounce = null; }
	}

	// --- Barcode scanning (mobile search field) ---
	let scanning = false;
	let scanVideoEl: HTMLVideoElement;
	let scanStream: MediaStream | null = null;
	let scanInterval: ReturnType<typeof setInterval> | null = null;
	let scanCanvas: HTMLCanvasElement | null = null;
	let scanCtx: CanvasRenderingContext2D | null = null;
	let barcodeDetector: any = null;
	let scanError = '';

	async function startScan() {
		scanError = '';
		scanning = true;
		try {
			scanStream = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
			});
			await new Promise(r => setTimeout(r, 100));
			if (scanVideoEl) {
				scanVideoEl.srcObject = scanStream;
				await scanVideoEl.play();
				await new Promise(r => setTimeout(r, 500));
				await initScanDetector();
				detectScanBarcode();
			}
		} catch (err: any) {
			console.error('Camera access error:', err);
			scanError = 'Camera error: ' + (err.message || 'Access denied');
			scanning = false;
		}
	}

	async function initScanDetector() {
		// @ts-ignore
		if ('BarcodeDetector' in window) {
			try {
				// @ts-ignore
				barcodeDetector = new window.BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'qr_code'] });
				return;
			} catch (e) {
				console.warn('[scan] Native BarcodeDetector failed:', e);
			}
		}
		try {
			const { BarcodeDetector: Polyfill } = await import('barcode-detector');
			barcodeDetector = new Polyfill({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'qr_code'] });
		} catch (e) {
			console.error('[scan] Failed to load barcode detector polyfill:', e);
		}
	}

	function detectScanBarcode() {
		if (!barcodeDetector) {
			scanError = 'Barcode scanner not available on this device';
			stopScan();
			return;
		}

		scanCanvas = document.createElement('canvas');
		scanCtx = scanCanvas.getContext('2d');

		scanInterval = setInterval(async () => {
			if (!scanVideoEl || scanVideoEl.readyState < 2 || !scanCanvas || !scanCtx) return;
			try {
				const vw = scanVideoEl.videoWidth;
				const vh = scanVideoEl.videoHeight;
				if (vw === 0 || vh === 0) return;
				scanCanvas.width = vw;
				scanCanvas.height = vh;
				scanCtx.drawImage(scanVideoEl, 0, 0, vw, vh);

				let barcodes: any[] = [];
				try {
					barcodes = await barcodeDetector.detect(scanCanvas);
				} catch (_) {
					try {
						const imageData = scanCtx.getImageData(0, 0, vw, vh);
						barcodes = await barcodeDetector.detect(imageData);
					} catch (__) {}
				}

				if (barcodes.length > 0) {
					searchQuery = barcodes[0].rawValue;
					if (mobile) loadMobileProducts(true);
					stopScan();
				}
			} catch (_) {}
		}, 400);
	}

	function stopScan() {
		if (scanInterval) { clearInterval(scanInterval); scanInterval = null; }
		if (scanStream) { scanStream.getTracks().forEach(t => t.stop()); scanStream = null; }
		scanCanvas = null;
		scanCtx = null;
		scanning = false;
	}

	// --- Add Template (inline, not a popup) ---
	// Lets a user create just the template shell (offer name + dates) from
	// the template list screen, without going through the full "Create New
	// Offer" wizard's product-selection step. The new template then appears
	// in the list like any other — click it to add products the normal way.
	let offerNames: any[] = [];
	let showAddTemplateForm = false;
	let isCreatingTemplate = false;
	let createTemplateError = '';
	function blankNewTemplateForm() {
		return { offerNameId: '', startDate: '', endDate: '' };
	}
	let newTemplateForm = blankNewTemplateForm();

	// Inline "create a new offer name" mini-form, nested inside Add Template
	let showCreateOfferNameInline = false;
	let newOfferNameEnInline = '';
	let newOfferNameArInline = '';
	let isSavingOfferNameInline = false;

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
			offerNames = [];
		}
	}

	function toggleAddTemplateForm() {
		showAddTemplateForm = !showAddTemplateForm;
		createTemplateError = '';
		showCreateOfferNameInline = false;
		if (showAddTemplateForm) {
			newTemplateForm = blankNewTemplateForm();
		}
	}

	// Same OF{n} id convention as the "Create New Offer" wizard
	async function getNextOfferNameId(): Promise<string> {
		try {
			const { data, error } = await supabase.from('offer_names').select('id');
			if (error) throw error;
			let maxNum = 0;
			(data || []).forEach((row: any) => {
				const match = row.id?.match(/^OF(\d+)$/);
				if (match) maxNum = Math.max(maxNum, parseInt(match[1], 10));
			});
			return `OF${maxNum + 1}`;
		} catch {
			return `OF${Date.now()}`;
		}
	}

	async function saveNewOfferNameInline() {
		const nameEn = newOfferNameEnInline.trim();
		if (!nameEn) {
			createTemplateError = 'English name is required.';
			return;
		}
		isSavingOfferNameInline = true;
		createTemplateError = '';
		try {
			const nextId = await getNextOfferNameId();
			const { error } = await supabase.from('offer_names').insert({
				id: nextId,
				name_en: nameEn,
				name_ar: newOfferNameArInline.trim() || null
			});
			if (error) throw error;

			await loadOfferNames();
			newTemplateForm = { ...newTemplateForm, offerNameId: nextId };
			showCreateOfferNameInline = false;
			newOfferNameEnInline = '';
			newOfferNameArInline = '';
		} catch (err: any) {
			console.error('Error saving offer name:', err);
			createTemplateError = err?.message || 'Failed to save offer name. Please try again.';
		} finally {
			isSavingOfferNameInline = false;
		}
	}

	// Same "Offer DD-MM-YYYY to DD-MM-YYYY" convention as the wizard
	function generateTemplateNameFromDates(startDate: string, endDate: string): string {
		if (!startDate || !endDate) return `Offer ${Date.now()}`;
		const formatDate = (d: Date) => {
			const day = d.getDate().toString().padStart(2, '0');
			const month = (d.getMonth() + 1).toString().padStart(2, '0');
			return `${day}-${month}-${d.getFullYear()}`;
		};
		return `Offer ${formatDate(new Date(startDate))} to ${formatDate(new Date(endDate))}`;
	}

	async function createTemplate() {
		createTemplateError = '';
		if (!newTemplateForm.startDate) { createTemplateError = 'Start date is required.'; return; }
		if (!newTemplateForm.endDate) { createTemplateError = 'End date is required.'; return; }
		if (newTemplateForm.endDate < newTemplateForm.startDate) {
			createTemplateError = 'End date must be on or after the start date.';
			return;
		}

		isCreatingTemplate = true;
		try {
			const templateId = `TEMPLATE-${Date.now()}-${Math.floor(Math.random() * 1000).toString().padStart(3, '0')}`;
			const templateName = generateTemplateNameFromDates(newTemplateForm.startDate, newTemplateForm.endDate);

			const { error } = await supabase.from('flyer_offers').insert({
				template_id: templateId,
				template_name: templateName,
				offer_name_id: newTemplateForm.offerNameId || null,
				start_date: newTemplateForm.startDate,
				end_date: newTemplateForm.endDate
			});

			if (error) {
				console.error('Error creating template:', error);
				createTemplateError = 'Failed to create template: ' + error.message;
				isCreatingTemplate = false;
				return;
			}

			await loadOfferTemplates();
			showAddTemplateForm = false;
			newTemplateForm = blankNewTemplateForm();
		} catch (err: any) {
			console.error('Error creating template:', err);
			createTemplateError = 'Error creating template. Please try again.';
		} finally {
			isCreatingTemplate = false;
		}
	}

	onMount(() => {
		loadOfferTemplates();
		loadOfferNames();
	});

	onDestroy(() => {
		stopScan();
	});
</script>

<div class="h-full flex flex-col bg-gray-50">
	{#if !selectedTemplate}
		<!-- Template List View -->
		<div class="{mobile ? 'p-3' : 'p-6'}">
			<div class="{mobile ? 'flex flex-col gap-3 mb-4' : 'flex items-center justify-between mb-6'}">
				{#if !mobile}
				<div>
					<h1 class="text-3xl font-bold text-gray-800">Offer Templates</h1>
					<p class="text-gray-600 mt-1">Select an offer template to manage products</p>
				</div>
				{/if}
				<div class="{mobile ? 'flex gap-2' : 'flex items-center gap-2'}">
					<button
						on:click={toggleAddTemplateForm}
						class="field-border-dashed px-4 py-2 border-2 border-dashed {showAddTemplateForm ? 'border-gray-300 text-gray-600 bg-gray-50' : 'border-blue-300 text-blue-700 bg-blue-50 hover:bg-blue-100'} font-semibold rounded-lg transition-colors flex items-center justify-center gap-2 {mobile ? 'flex-1' : ''}"
					>
						{#if showAddTemplateForm}
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
							</svg>
							Cancel
						{:else}
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
							</svg>
							Add Template
						{/if}
					</button>
					<button
						on:click={loadOfferTemplates}
						disabled={isLoadingTemplates}
						class="px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 {mobile ? 'flex-1' : ''}"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
						</svg>
						Refresh
					</button>
				</div>
			</div>

			{#if showAddTemplateForm}
				<div class="mb-6 bg-white rounded-lg border-2 border-blue-200 p-4 space-y-3 max-w-md">
					<h3 class="text-sm font-bold text-gray-800">Add Template</h3>

					<div>
						<label class="block text-xs font-medium text-gray-700 mb-1">Offer Name (Optional)</label>
						<div class="flex items-center gap-1.5">
							<select
								bind:value={newTemplateForm.offerNameId}
								class="field-border flex-1 px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
							>
								<option value="">-- Select Offer Name --</option>
								{#each offerNames as offerName}
									<option value={offerName.id}>{offerName.name_en}</option>
								{/each}
							</select>
							<button
								type="button"
								on:click={() => { showCreateOfferNameInline = !showCreateOfferNameInline; createTemplateError = ''; }}
								class="field-border-thin px-2 py-2 border border-green-300 bg-green-50 text-green-700 rounded-lg hover:bg-green-100 transition-colors text-xs font-bold flex-shrink-0"
								title="Create new offer name"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" /></svg>
							</button>
						</div>
					</div>

					{#if showCreateOfferNameInline}
						<div class="bg-gray-50 rounded-lg p-3 space-y-2 border border-gray-200">
							<input
								type="text"
								bind:value={newOfferNameEnInline}
								placeholder="Offer name (English) *"
								class="field-border w-full px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
							/>
							<input
								type="text"
								dir="rtl"
								bind:value={newOfferNameArInline}
								placeholder="اسم العرض بالعربية"
								class="field-border w-full px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
							/>
							<button
								type="button"
								on:click={saveNewOfferNameInline}
								disabled={isSavingOfferNameInline}
								class="w-full px-3 py-2 bg-green-600 text-white text-sm font-bold rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
							>
								{isSavingOfferNameInline ? 'Saving...' : 'Save Offer Name'}
							</button>
						</div>
					{/if}

					<div class="grid grid-cols-2 gap-2">
						<div>
							<label class="block text-xs font-medium text-gray-700 mb-1">Start Date *</label>
							<input
								type="date"
								bind:value={newTemplateForm.startDate}
								class="field-border w-full px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
							/>
						</div>
						<div>
							<label class="block text-xs font-medium text-gray-700 mb-1">End Date *</label>
							<input
								type="date"
								bind:value={newTemplateForm.endDate}
								class="field-border w-full px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
							/>
						</div>
					</div>

					{#if createTemplateError}
						<p class="text-sm text-red-600">{createTemplateError}</p>
					{/if}

					<button
						type="button"
						on:click={createTemplate}
						disabled={isCreatingTemplate}
						class="w-full px-3 py-2 bg-blue-600 text-white text-sm font-bold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
					>
						{isCreatingTemplate ? 'Creating...' : 'Create Template'}
					</button>
					<p class="text-xs text-gray-500">Creates just the template. Click it afterward in the list below to add products.</p>
				</div>
			{/if}

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
				<div class="grid grid-cols-1 {mobile ? 'gap-2' : 'md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4'}">
					{#each offerTemplates as template (template.id)}
						<button
							on:click={() => selectTemplate(template)}
							class="bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow text-left border-2 border-transparent hover:border-blue-500 {mobile ? 'p-3' : 'p-6'}"
						>
							<div class="flex items-start justify-between {mobile ? 'mb-2' : 'mb-4'}">
								<div class="flex-1 min-w-0">
								{#if template.offer_name && template.offer_name.name_en}
									<h3 class="{mobile ? 'text-sm' : 'text-lg'} font-bold text-gray-800 mb-1 truncate">{template.offer_name.name_en}</h3>
										{#if !mobile}<p class="text-sm text-gray-600 mb-1">Template: {template.template_name}</p>{/if}
									{:else}
										<h3 class="{mobile ? 'text-sm' : 'text-lg'} font-bold text-gray-800 mb-1 truncate">{template.template_name}</h3>
									{/if}
									{#if !mobile}<p class="text-xs text-gray-500 font-mono">{template.template_id}</p>{/if}
								</div>
								<span class="px-2 py-1 bg-green-100 text-green-800 text-xs font-semibold rounded-full flex-shrink-0">
									Active
								</span>
							</div>

							<div class="{mobile ? 'flex items-center gap-3 text-xs' : 'space-y-2 text-sm'} text-gray-600">
								<div class="flex items-center gap-2">
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
									<span>{new Date(template.start_date).toLocaleDateString()}</span>
								</div>
								<div class="flex items-center gap-2">
									{#if !mobile}
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
									{:else}
										<span>–</span>
									{/if}
									<span>{new Date(template.end_date).toLocaleDateString()}</span>
								</div>
							</div>

							{#if !mobile}
							<div class="mt-4 pt-4 border-t border-gray-200">
								<div class="flex items-center justify-between">
									<span class="text-sm text-gray-500">Click to edit products</span>
									<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
									</svg>
								</div>
							</div>
							{/if}
						</button>
					{/each}
				</div>
			{/if}
		</div>
	{:else}
		<!-- Product Selection View -->
		<div class="flex flex-col h-full">
			<!-- Header -->
			<div class="bg-white border-b border-gray-200 {mobile ? 'px-3 py-3' : 'px-6 py-4'} sticky top-0 z-20">
				{#if mobile}
					<div class="flex items-center justify-between mb-3">
						<button
							on:click={goBackToTemplates}
							class="px-3 py-1.5 bg-gray-200 text-gray-700 text-sm font-semibold rounded-lg hover:bg-gray-300 transition-colors flex items-center gap-1"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
							</svg>
							Back
						</button>
						{#if selectedTemplate.offer_name && selectedTemplate.offer_name.name_en}
							<span class="text-xs text-gray-500 text-right">Template: {selectedTemplate.template_name}</span>
						{:else}
							<span class="text-xs text-gray-500 text-right">{selectedTemplate.template_id}</span>
						{/if}
					</div>
					<div class="flex items-center justify-between gap-2 mb-3">
						{#if selectedTemplate.offer_name && selectedTemplate.offer_name.name_en}
							<h2 class="text-lg font-bold text-gray-800 truncate">{selectedTemplate.offer_name.name_en}</h2>
						{:else}
							<h2 class="text-lg font-bold text-gray-800 truncate">{selectedTemplate.template_name}</h2>
						{/if}
						<button
							on:click={saveProductSelections}
							disabled={isSaving}
							class="px-3 py-1.5 bg-green-600 text-white text-xs font-bold rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-1.5 flex-shrink-0"
						>
							{#if isSaving}
								<svg class="animate-spin w-3.5 h-3.5" fill="none" viewBox="0 0 24 24">
									<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
									<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
								</svg>
								Saving
							{:else}
								<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
								</svg>
								Save ({selectedProducts.size})
							{/if}
						</button>
					</div>
				{:else}
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
				{/if}

				<!-- Category Filter -->
				{#if !mobile}
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
				{/if}

				<!-- Search Bar -->
				<div class="relative mt-4">
					<input
						type="text"
						bind:value={searchQuery}
						on:input={() => { if (mobile) scheduleMobileSearch(); }}
						placeholder={mobile ? 'Search to find and add products...' : 'Search by barcode, name, or category...'}
						class="field-border w-full px-4 py-2 pl-10 {mobile ? 'pr-12' : ''} border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
					/>
					<svg class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
					{#if mobile}
						<button
							type="button"
							on:click={scanning ? stopScan : startScan}
							class="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 flex items-center justify-center bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
							title="Scan barcode"
							aria-label="Scan barcode"
						>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/>
								<path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
								<line x1="7" y1="12" x2="17" y2="12"/>
							</svg>
						</button>
					{/if}
				</div>
				{#if mobile && scanError}
					<p class="mt-2 text-sm text-red-600">{scanError}</p>
				{/if}
			</div>

			<!-- Products List -->
			<div class="flex-1 overflow-auto {mobile ? 'p-3' : 'p-6'}">
				{#if mobile}
					<button
						type="button"
						on:click={toggleInlineCreateProduct}
						class="field-border-dashed w-full mb-3 px-3 py-2 text-sm font-semibold rounded-lg border-2 border-dashed {showInlineCreateProduct ? 'border-gray-300 text-gray-600 bg-gray-50' : 'border-blue-300 text-blue-700 bg-blue-50 hover:bg-blue-100'} transition-colors flex items-center justify-center gap-2"
					>
						{#if showInlineCreateProduct}
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
							</svg>
							Cancel
						{:else}
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
							</svg>
							Create Product (not in database)
						{/if}
					</button>

					{#if showInlineCreateProduct}
						<div class="mb-3 bg-white rounded-lg border-2 border-blue-200 p-3 space-y-3">
							<h3 class="text-sm font-bold text-gray-800">{isEditingProduct ? 'Edit Product' : 'Create New Product'}</h3>

							<div>
								<label class="block text-xs font-medium text-gray-700 mb-1">Barcode {isEditingProduct ? '(cannot be changed)' : '*'}</label>
								<div class="flex gap-2">
									<input
										type="text"
										value={newProductForm.barcode}
										on:input={(e) => { if (!isEditingProduct) newProductForm.barcode = e.currentTarget.value; }}
										readonly={isEditingProduct}
										placeholder="Enter barcode"
										class="field-border flex-1 px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none {isEditingProduct ? 'bg-gray-100 text-gray-500' : ''}"
									/>
									<button
										type="button"
										on:click={checkNewProductImage}
										disabled={isCheckingNewProductImage}
										class="px-3 py-2 text-xs font-semibold bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 disabled:opacity-50 flex-shrink-0"
									>
										{isCheckingNewProductImage ? '...' : 'Find Image'}
									</button>
								</div>
							</div>

							<div>
								<label class="block text-xs font-medium text-gray-700 mb-1">Product Name (EN) *</label>
								<input
									type="text"
									bind:value={newProductForm.product_name_en}
									placeholder="Product name in English"
									class="field-border w-full px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
								/>
							</div>

							<button
								type="button"
								on:click={handleFixProductNameClick}
								disabled={isFixingProductName}
								class="field-border-thin w-full px-3 py-2 text-xs font-bold rounded-lg border border-purple-300 bg-purple-50 text-purple-700 hover:bg-purple-100 transition-colors disabled:opacity-50 flex items-center justify-center gap-1.5"
							>
								{#if isFixingProductName}
									<svg class="animate-spin w-3.5 h-3.5" fill="none" viewBox="0 0 24 24">
										<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
										<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
									</svg>
									Fixing & Translating...
								{:else}
									✨ Fix Spelling, Capitalize & Translate to Arabic
								{/if}
							</button>

							<div>
								<label class="block text-xs font-medium text-gray-700 mb-1">Product Name (AR)</label>
								<input
									type="text"
									dir="rtl"
									bind:value={newProductForm.product_name_ar}
									placeholder="اسم المنتج بالعربية"
									class="field-border w-full px-3 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
								/>
							</div>

							<div class="grid grid-cols-2 gap-2">
								<div>
									<label class="block text-xs font-medium text-gray-700 mb-1">Category</label>
									<SearchableDropdown
										options={categories}
										bind:value={newProductForm.category_id}
										placeholder="Search category..."
									/>
								</div>
								<div>
									<label class="block text-xs font-medium text-gray-700 mb-1">Unit</label>
									<SearchableDropdown
										options={units}
										bind:value={newProductForm.unit_id}
										placeholder="Search unit..."
									/>
								</div>
							</div>

							{#if newProductForm.image_url}
								<div class="flex items-center gap-2">
									<img src={newProductForm.image_url} alt="Preview" class="w-12 h-12 object-contain bg-gray-100 rounded border border-gray-200" />
									<span class="text-xs text-green-700">✓ Image found and attached</span>
								</div>
							{/if}

							{#if createProductError}
								<p class="text-sm text-red-600">{createProductError}</p>
							{/if}

							<button
								type="button"
								on:click={isEditingProduct ? saveEditedProduct : createInlineProduct}
								disabled={isCreatingProduct}
								class="w-full px-3 py-2 bg-blue-600 text-white text-sm font-bold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
							>
								{#if isCreatingProduct}
									{isEditingProduct ? 'Saving...' : 'Creating...'}
								{:else}
									{isEditingProduct ? 'Save Changes' : 'Create & Add to Offer'}
								{/if}
							</button>
						</div>
					{/if}
				{/if}

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
						{#if mobile && !searchQuery.trim()}
							<h3 class="text-xl font-semibold text-gray-800 mb-2">No Products Selected Yet</h3>
							<p class="text-gray-600">Search by barcode or name above to add products.</p>
						{:else}
							<h3 class="text-xl font-semibold text-gray-800 mb-2">No Products Found</h3>
							<p class="text-gray-600">Try adjusting your search criteria.</p>
						{/if}
					</div>
				{:else if useCardLayout}
					<!-- Compact card list instead of the wide table -->
					<div class="mb-3 flex items-center justify-center gap-4 px-3 py-2 text-sm font-semibold rounded-lg border border-gray-200 bg-white text-gray-700">
						<span>✅ {selectedProducts.size} product{selectedProducts.size === 1 ? '' : 's'} selected</span>
						<span class="text-gray-300">|</span>
						<span>📄 {getUniquePages().length} page{getUniquePages().length === 1 ? '' : 's'}</span>
					</div>
					<div class="space-y-2">
						{#each filteredProducts as product (product.barcode)}
							{@const selected = selectedProducts.has(product.barcode)}
							{@const pageOrder = productPageOrderMap.get(product.barcode)}
							<div class="relative bg-white rounded-lg shadow-sm border {selected ? 'border-blue-400 bg-blue-50' : 'border-gray-200'} p-3">
								<!-- Custom checkbox: a plain input's native :checked visual can fail to
								     repaint on some mobile browsers when paired with preventDefault. This
								     button's check mark is driven entirely by the `selected` boolean below,
								     so it is guaranteed to match the actual selection state. -->
								<button
									type="button"
									role="checkbox"
									aria-checked={selected}
									aria-label="Select product"
									on:click={() => toggleProduct(product.barcode)}
									class="absolute top-2 right-2 z-10 w-5 h-5 rounded flex items-center justify-center flex-shrink-0"
									style="border: 2px solid {selected ? '#2563EB' : '#9CA3AF'} !important; background-color: {selected ? '#2563EB' : '#fff'};"
								>
									{#if selected}
										<svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
										</svg>
									{/if}
								</button>
								<div class="flex items-start gap-3 pr-7">
									<div class="w-28 h-28 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden flex-shrink-0">
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
											<svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
											</svg>
										{/if}
									</div>
									<div class="min-w-0 flex-1">
										<p class="text-sm font-semibold text-gray-900 truncate">{product.product_name_en || product.barcode}</p>
										<p class="text-sm text-gray-700 truncate" dir="rtl">{product.product_name_ar || '-'}</p>
										<div class="flex items-center gap-1.5 flex-wrap text-xs text-gray-500">
											<p class="font-mono">{product.barcode}</p>
											<span class="px-1.5 py-0.5 bg-gray-100 rounded">{unitMap.get(product.unit_id) || '-'}</span>
											<button
												type="button"
												on:click={() => openEditProduct(product)}
												class="text-blue-600 hover:text-blue-800 flex items-center gap-0.5"
												title="Edit product"
												aria-label="Edit product"
											>
												<svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
												</svg>
												Edit
											</button>
										</div>
										{#if product.is_variation && product.variation_group_name_en}
											<div class="mt-1">
												<span class="px-1.5 py-0.5 bg-green-100 text-green-700 rounded font-medium text-xs">🔗 {product.variation_group_name_en}</span>
											</div>
										{/if}
										{#if selected && pageOrder}
											<div class="mt-2 flex flex-wrap items-center gap-x-1.5 gap-y-1 min-w-0">
												<span class="text-xs text-gray-500 flex-shrink-0">Page</span>
												<input
													type="number"
													min="1"
													value={pageOrder.page}
													on:change={(e) => {
														const newPage = parseInt(e.currentTarget.value) || 1;
														const nextOrder = getNextOrderForPage(newPage);
														updateProductPageOrder(product.barcode, newPage, nextOrder);
													}}
													class="no-spinner field-border-thin w-11 h-8 text-sm text-center border border-gray-300 rounded focus:ring-blue-500 font-bold flex-shrink-0"
													title="Page number"
												/>
												<span class="text-gray-400 font-bold flex-shrink-0">-</span>
												<span class="text-xs text-gray-500 flex-shrink-0">Order</span>
												<input
													type="number"
													min="1"
													value={pageOrder.order}
													on:change={(e) => {
														const newOrder = parseInt(e.currentTarget.value) || 1;
														updateProductPageOrder(product.barcode, pageOrder.page, newOrder);
													}}
													class="no-spinner field-border-thin w-11 h-8 text-sm text-center border border-gray-300 rounded focus:ring-blue-500 font-bold flex-shrink-0"
													title="Order on page"
												/>
											</div>
										{/if}
									</div>
								</div>
							</div>
						{/each}
					</div>
					{#if mobileHasMore}
						<div class="mt-3">
							<button
								type="button"
								on:click={() => loadMobileProducts(false)}
								disabled={isLoadingMoreProducts}
								class="field-border-thin w-full px-3 py-2 text-sm font-semibold rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
							>
								{#if isLoadingMoreProducts}
									Loading...
								{:else}
									Load More ({allProducts.length} of {mobileTotalCount})
								{/if}
							</button>
						</div>
					{:else if mobileTotalCount > 0}
						<p class="mt-3 text-center text-xs text-gray-400">
							{#if searchQuery.trim()}
								Showing all {mobileTotalCount} matches
							{:else}
								Showing all {mobileTotalCount} selected product{mobileTotalCount === 1 ? '' : 's'}
							{/if}
						</p>
					{/if}
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
									<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
										Actions
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
										<td class="px-6 py-4 text-center">
											<button
												type="button"
												on:click={() => openEditProduct(product)}
												class="px-3 py-1.5 text-xs font-semibold text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-lg transition-colors inline-flex items-center gap-1"
												title="Edit product"
											>
												<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
												</svg>
												Edit
											</button>
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

<!-- Barcode Scanner Overlay -->
{#if scanning}
	<div
		class="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center p-4 z-50"
		on:click={stopScan}
		role="button"
		tabindex="-1"
		on:keydown={(e) => e.key === 'Escape' && stopScan()}
	>
		<div class="bg-gray-900 rounded-xl overflow-hidden w-full max-w-sm" on:click|stopPropagation role="none">
			<div class="flex items-center justify-between px-4 py-3 text-white font-semibold">
				<span>📷 Scan Barcode</span>
				<button type="button" class="text-2xl leading-none px-1" on:click={stopScan}>&times;</button>
			</div>
			<div class="relative w-full bg-black" style="aspect-ratio: 4/3;">
				<!-- svelte-ignore a11y-media-has-caption -->
				<video bind:this={scanVideoEl} playsinline autoplay muted class="w-full h-full object-cover"></video>
				<div class="absolute left-[10%] right-[10%] h-0.5 bg-red-500 shadow-[0_0_8px_rgba(255,59,48,0.6)] scan-line-anim"></div>
			</div>
		</div>
	</div>
{/if}

<style>
	.scan-line-anim {
		top: 50%;
		animation: offerTemplatesScanMove 2s ease-in-out infinite;
	}
	@keyframes offerTemplatesScanMove {
		0%, 100% { top: 30%; }
		50% { top: 70%; }
	}

	/* Hide native number-input spin arrows on the Page/Order fields — mobile
	   browsers don't render them, but desktop browsers do, and they eat into
	   the fixed-width box, squeezing the digit out of view. */
	.no-spinner::-webkit-outer-spin-button,
	.no-spinner::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}
	.no-spinner[type='number'] {
		-moz-appearance: textfield;
		appearance: textfield;
	}

	/* mobile-interface/+layout.svelte has an app-wide, unlayered
	   `:global(input), :global(select), :global(textarea) { border: none; }`
	   (and the same for :global(button)) reset. Because it's unlayered, it
	   beats Tailwind's border-* utilities (those live in @layer utilities —
	   any unlayered CSS wins over layered CSS regardless of selector
	   specificity), so fields/buttons in this component lose their border
	   when rendered inside the mobile route. !important is the only thing
	   that reliably wins that fight. Width/style only (not color), so each
	   element's existing border-{color} utility still controls the color. */
	.field-border {
		border-width: 2px !important;
		border-style: solid !important;
	}
	.field-border-thin {
		border-width: 1px !important;
		border-style: solid !important;
	}
	.field-border-dashed {
		border-width: 2px !important;
		border-style: dashed !important;
	}
</style>

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
							class="field-border-thin w-20 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-lg font-bold text-center"
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
					class="field-border-thin px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
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