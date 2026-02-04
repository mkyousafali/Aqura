<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import VariationSelectionModal from '$lib/components/desktop-interface/marketing/flyer/VariationSelectionModal.svelte';
	import PriceValidationWarning from '$lib/components/desktop-interface/marketing/flyer/PriceValidationWarning.svelte';
	import { notifications } from '$lib/stores/notifications';
	
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
	
	// Image popup modal state
	let showImagePopup: boolean = false;
	let popupImageUrl: string = '';
	let popupImageName: string = '';
	
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
	let selectedCategories: string[] = [];
	let categorySearchQuery: string = '';
	
	// Filter options (unique values from products)
	let parentCategories: string[] = [];
	
	// Product loading - automatic batch loading
	let pageSize: number = 25; // Batch size for automatic loading
	let totalProducts: number = 0;
	
	// CREATE VARIANT GROUP state (for products not already in a group)
	let productsToGroup: Set<string> = new Set();
	let showCreateGroupModal: boolean = false;
	let groupParentBarcode: string = '';
	let groupNameEn: string = '';
	let groupNameAr: string = '';
	let isCreatingGroup: boolean = false;
	let isGeneratingAIName: boolean = false;
	
	// Wizard steps
	let currentStep: number = 1;
	const totalSteps: number = 3;
	
	// Step 1: Templates with auto-generated template_id
	interface ProductSelection {
		page: number;
		order: number;
	}
	
	interface OfferTemplate {
		id: string;
		templateId: string; // Unique identifier for database
		name: string;
		offerNameId?: string; // Reference to offer_names table
		startDate: string;
		endDate: string;
		selectedProducts: Map<string, ProductSelection>; // Map of barcode -> {page, order}
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
			selectedProducts: new Map<string, ProductSelection>()
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
		
		console.log('toggleProductSelection:', { 
			barcode, 
			is_variation: product.is_variation, 
			variation_group_name_en: product.variation_group_name_en,
			parent_product_barcode: product.parent_product_barcode
		});
		
		// Check if product is part of a variation group (must have both is_variation AND variation_group_name_en)
		if (product.is_variation && product.variation_group_name_en) {
			// Determine parent barcode
			const parentBarcode = product.parent_product_barcode || product.barcode;
			
			// Load all variations in the group
			await loadVariationGroup(templateId, parentBarcode);
			return;
		}
		
		// Normal product selection (not a variation or no group name)
		templates = templates.map(t => {
			if (t.id === templateId) {
				const newMap = new Map(t.selectedProducts);
				if (newMap.has(barcode)) {
					newMap.delete(barcode);
				} else {
					// Default page 1, order = next available (using max order, not count)
					const nextOrder = getNextOrderForPage(t, 1, barcode);
					console.log('Adding regular product with order:', nextOrder);
					newMap.set(barcode, { page: 1, order: nextOrder });
				}
				return { ...t, selectedProducts: newMap };
			}
			return t;
		});
	}
	
	// Get next available order number for a page in a template
	// Optionally exclude a barcode or all barcodes from a variation group
	function getNextOrderForPage(template: OfferTemplate, page: number, excludeBarcode?: string, excludeGroupParent?: string): number {
		// Build set of barcodes to exclude
		const excludeBarcodes = new Set<string>();
		if (excludeBarcode) {
			excludeBarcodes.add(excludeBarcode);
		}
		// If excluding a group, find the group name and exclude all products with that group name
		if (excludeGroupParent) {
			const parentProduct = products.find(p => p.barcode === excludeGroupParent);
			const groupName = parentProduct?.variation_group_name_en;
			if (groupName) {
				products.forEach(p => {
					if (p.is_variation && p.variation_group_name_en === groupName) {
						excludeBarcodes.add(p.barcode);
					}
				});
			}
		}
		
		let maxOrder = 0;
		template.selectedProducts.forEach((selection, barcode) => {
			if (selection.page === page && !excludeBarcodes.has(barcode)) {
				if (selection.order > maxOrder) {
					maxOrder = selection.order;
				}
			}
		});
		return maxOrder + 1;
	}
	
	// Update page/order for a selected product - auto-assign next order when page changes
	// For variant products, update ALL variants in the same group together
	function updateProductPageOrder(templateId: string, barcode: string, page: number, order: number, autoOrder: boolean = false) {
		// Check if this product is a variant with a VALID variation group
		const product = products.find(p => p.barcode === barcode);
		// Only treat as variant if it has BOTH is_variation=true AND a parent_product_barcode (meaning it's part of a group)
		const hasParent = product?.parent_product_barcode && product.parent_product_barcode !== product.barcode;
		const isVariant = product?.is_variation && product?.variation_group_name_en && hasParent;
		
		console.log('updateProductPageOrder:', {
			barcode,
			is_variation: product?.is_variation,
			variation_group_name_en: product?.variation_group_name_en,
			parent_product_barcode: product?.parent_product_barcode,
			isVariant,
			hasParent
		});
		
		templates = templates.map(t => {
			if (t.id === templateId && t.selectedProducts.has(barcode)) {
				const newMap = new Map(t.selectedProducts);
				const newPage = page || 1;
				const currentSelection = t.selectedProducts.get(barcode);
				let newOrder = order || 1;
				
				// Only auto-calculate order if autoOrder is true OR page actually changed
				if (autoOrder || (currentSelection && currentSelection.page !== newPage)) {
					// For variants, exclude all products in the same group when calculating next order
					if (isVariant) {
						newOrder = getNextOrderForPage({ ...t, selectedProducts: newMap }, newPage, undefined, product.parent_product_barcode);
					} else {
						newOrder = getNextOrderForPage({ ...t, selectedProducts: newMap }, newPage, barcode);
					}
				}
				
				// If this is a variant with a valid group, update ALL variants in the same group
				if (isVariant) {
					// Find all products in the same variation group by name (more reliable)
					const groupProducts = products.filter(p => 
						p.is_variation && 
						p.variation_group_name_en === product.variation_group_name_en &&
						p.parent_product_barcode // Must have a parent to be considered a variant
					);
					console.log('Updating variant group:', groupProducts.map(p => p.barcode));
					// Update all variants in the group that are selected
					groupProducts.forEach(gp => {
						if (newMap.has(gp.barcode)) {
							newMap.set(gp.barcode, { page: newPage, order: newOrder });
						}
					});
				} else {
					// Regular product - only update this one
					console.log('Updating single product:', barcode, { page: newPage, order: newOrder });
					newMap.set(barcode, { page: newPage, order: newOrder });
				}
				
				return { ...t, selectedProducts: newMap };
			}
			return t;
		});
	}
	
	// Check if two date ranges overlap
	function datesOverlap(start1: string, end1: string, start2: string, end2: string): boolean {
		if (!start1 || !end1 || !start2 || !end2) return false;
		const s1 = new Date(start1).getTime();
		const e1 = new Date(end1).getTime();
		const s2 = new Date(start2).getTime();
		const e2 = new Date(end2).getTime();
		return s1 <= e2 && s2 <= e1;
	}
	
	// Check if product is blocked in a template due to overlap with another template
	function isProductBlockedInTemplate(templateId: string, barcode: string): { blocked: boolean, conflictTemplate: string | null } {
		const targetTemplate = templates.find(t => t.id === templateId);
		if (!targetTemplate || !targetTemplate.startDate || !targetTemplate.endDate) {
			return { blocked: false, conflictTemplate: null };
		}
		
		// Check if product is selected in any other template with overlapping dates
		for (const otherTemplate of templates) {
			if (otherTemplate.id === templateId) continue; // Skip same template
			if (!otherTemplate.startDate || !otherTemplate.endDate) continue;
			
			// Check if this product is selected in the other template
			if (otherTemplate.selectedProducts.has(barcode)) {
				// Check if dates overlap
				if (datesOverlap(targetTemplate.startDate, targetTemplate.endDate, otherTemplate.startDate, otherTemplate.endDate)) {
					return { blocked: true, conflictTemplate: otherTemplate.name };
				}
			}
		}
		
		return { blocked: false, conflictTemplate: null };
	}
	
	// Get page summary for a template (reactive) - counts unique page-order slots, not individual products
	function getPageSummary(template: OfferTemplate): Map<number, number> {
		const summary = new Map<number, number>();
		// Track unique page-order combinations per page
		const uniqueOrdersPerPage = new Map<number, Set<number>>();
		
		template.selectedProducts.forEach((selection) => {
			if (!uniqueOrdersPerPage.has(selection.page)) {
				uniqueOrdersPerPage.set(selection.page, new Set());
			}
			uniqueOrdersPerPage.get(selection.page)!.add(selection.order);
		});
		
		// Count unique orders per page
		uniqueOrdersPerPage.forEach((orders, page) => {
			summary.set(page, orders.size);
		});
		
		return summary;
	}
	
	// Get page-order display string
	function getPageOrderDisplay(template: OfferTemplate, barcode: string): string {
		const selection = template.selectedProducts.get(barcode);
		if (selection) {
			return `${selection.page}-${selection.order}`;
		}
		return '';
	}
	
	// Get selection details for a product
	function getProductSelection(template: OfferTemplate, barcode: string): ProductSelection | undefined {
		return template.selectedProducts.get(barcode);
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
				const newMap = new Map(t.selectedProducts);
				
				// Remove all products from this group first
				const groupBarcodes = [currentVariationGroup.barcode, ...currentVariations.map(v => v.barcode)];
				groupBarcodes.forEach(barcode => newMap.delete(barcode));
				
				// Add selected products with SAME page/order (all variants share one slot)
				if (selectedBarcodes.length > 0) {
					// Get the next available order on page 1 using MAX order (not count)
					let maxOrderOnPage1 = 0;
					newMap.forEach((selection) => {
						if (selection.page === 1 && selection.order > maxOrderOnPage1) {
							maxOrderOnPage1 = selection.order;
						}
					});
					const sharedOrder = maxOrderOnPage1 + 1;
					
					console.log('handleVariationConfirm: maxOrder=', maxOrderOnPage1, 'sharedOrder=', sharedOrder, 'selectedBarcodes=', selectedBarcodes);
					
					// All variants get the same page and order
					selectedBarcodes.forEach((barcode: string) => {
						newMap.set(barcode, { page: 1, order: sharedOrder });
					});
				}
				
				return { ...t, selectedProducts: newMap };
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
	
	// =========================================
	// CREATE VARIANT GROUP FUNCTIONS
	// =========================================
	
	// Toggle product selection for grouping
	function toggleProductForGrouping(barcode: string) {
		if (productsToGroup.has(barcode)) {
			productsToGroup.delete(barcode);
		} else {
			productsToGroup.add(barcode);
		}
		productsToGroup = productsToGroup; // Trigger reactivity
	}
	
	// Check if product can be grouped (not already in a variation group)
	function canProductBeGrouped(product: any): boolean {
		return !product.is_variation || !product.variation_group_name_en;
	}
	
	// Open create group modal
	function openCreateGroupModal() {
		if (productsToGroup.size < 2) {
			notifications.add({
				message: 'Please select at least 2 products to create a group',
				type: 'warning',
				duration: 3000
			});
			return;
		}
		// Set default parent to first selected
		groupParentBarcode = Array.from(productsToGroup)[0];
		groupNameEn = '';
		groupNameAr = '';
		showCreateGroupModal = true;
	}
	
	// Close create group modal
	function closeCreateGroupModal() {
		showCreateGroupModal = false;
		groupParentBarcode = '';
		groupNameEn = '';
		groupNameAr = '';
	}
	
	// Generate AI group name
	async function generateAIGroupName() {
		if (productsToGroup.size === 0) return;
		
		isGeneratingAIName = true;
		try {
			// Get product names for selected products
			const selectedProductNames = products
				.filter(p => productsToGroup.has(p.barcode))
				.map(p => p.product_name_en)
				.filter(Boolean);
			
			if (selectedProductNames.length === 0) {
				notifications.add({
					message: 'No product names available to generate group name',
					type: 'warning',
					duration: 3000
				});
				return;
			}
			
			const response = await fetch('/api/generate-group-name', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ productNames: selectedProductNames })
			});
			
			if (!response.ok) {
				throw new Error('Failed to generate group name');
			}
			
			const result = await response.json();
			
			if (result.success) {
				groupNameEn = result.nameEn || '';
				groupNameAr = result.nameAr || '';
				notifications.add({
					message: 'AI generated group names successfully!',
					type: 'success',
					duration: 2000
				});
			} else {
				throw new Error(result.error || 'Unknown error');
			}
		} catch (error) {
			console.error('Error generating AI name:', error);
			notifications.add({
				message: 'Failed to generate AI name. Please enter manually.',
				type: 'error',
				duration: 4000
			});
		} finally {
			isGeneratingAIName = false;
		}
	}
	
	// Create the variant group
	async function createVariantGroup() {
		if (!groupParentBarcode || !groupNameEn || !groupNameAr) {
			notifications.add({
				message: 'Please fill in all required fields',
				type: 'warning',
				duration: 3000
			});
			return;
		}
		
		isCreatingGroup = true;
		try {
			// Get variation barcodes (excluding parent)
			const variationBarcodes = Array.from(productsToGroup).filter(
				b => b !== groupParentBarcode
			);
			
			// Call database function to create group
			const { data, error } = await supabase.rpc('create_variation_group', {
				p_parent_barcode: groupParentBarcode,
				p_variation_barcodes: variationBarcodes,
				p_group_name_en: groupNameEn,
				p_group_name_ar: groupNameAr,
				p_image_override: null,
				p_user_id: null
			});
			
			if (error) throw error;
			
			if (data && data.length > 0 && data[0].success) {
				notifications.add({
					message: `Variation group created: ${data[0].affected_count} products grouped`,
					type: 'success',
					duration: 3000
				});
				
				// Update local products array for the grouped products
				const allGroupBarcodes = [groupParentBarcode, ...variationBarcodes];
				products = products.map(p => {
					if (allGroupBarcodes.includes(p.barcode)) {
						return {
							...p,
							is_variation: true,
							parent_product_barcode: p.barcode === groupParentBarcode ? null : groupParentBarcode,
							variation_group_name_en: groupNameEn,
							variation_group_name_ar: groupNameAr
						};
					}
					return p;
				});
				
				// Also update filteredProducts
				filteredProducts = filteredProducts.map(p => {
					if (allGroupBarcodes.includes(p.barcode)) {
						return {
							...p,
							is_variation: true,
							parent_product_barcode: p.barcode === groupParentBarcode ? null : groupParentBarcode,
							variation_group_name_en: groupNameEn,
							variation_group_name_ar: groupNameAr
						};
					}
					return p;
				});
				
				// Clear selection and close modal
				productsToGroup.clear();
				productsToGroup = productsToGroup;
				closeCreateGroupModal();
			} else {
				throw new Error(data?.[0]?.message || 'Failed to create group');
			}
		} catch (error: any) {
			console.error('Error creating group:', error);
			notifications.add({
				message: `Failed to create group: ${error.message}`,
				type: 'error',
				duration: 5000
			});
		} finally {
			isCreatingGroup = false;
		}
	}
	
	// Clear products to group selection
	function clearGroupSelection() {
		productsToGroup.clear();
		productsToGroup = productsToGroup;
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
				
				// Insert selected products for this offer with page/order
				if (template.selectedProducts.size > 0) {
					const offerProducts = Array.from(template.selectedProducts.entries()).map(([barcode, selection]) => ({
						offer_id: offerData.id,
						product_barcode: barcode,
						page_number: selection.page,
						page_order: selection.order
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
				
				// Insert selected products for this offer with page/order
				if (template.selectedProducts.size > 0) {
					const offerProducts = Array.from(template.selectedProducts.entries()).map(([barcode, selection]) => ({
						offer_id: offerData.id,
						product_barcode: barcode,
						page_number: selection.page,
						page_order: selection.order
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
		
		// Apply category filters (multiple categories)
		if (selectedCategories.length > 0) {
			filtered = filtered.filter(product => selectedCategories.includes(product.category_name));
		}
		
		// Note: Parent sub category and sub category filters are disabled 
		// since they don't exist in the current database schema
		
		filteredProducts = filtered;
	}
	
	// Clear all filters
	function clearFilters() {
		selectedCategories = [];
		categorySearchQuery = '';
		searchQuery = '';
		applyFilters();
	}
	
	// Toggle category selection
	function toggleCategory(category: string) {
		if (selectedCategories.includes(category)) {
			selectedCategories = selectedCategories.filter(c => c !== category);
		} else {
			selectedCategories = [...selectedCategories, category];
		}
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
			console.log('✅ Loaded offer names:', offerNames.length, offerNames);
		} catch (error) {
			console.error('❌ Error loading offer names:', error);
			offerNames = [];
		}
	}
	
	// Watch for filter changes
	$: searchQuery, selectedCategories, applyFilters();
	
	// Sort products: selected ones at top, sorted by page-order (1-1, 1-2, 2-1, etc.)
	$: sortedFilteredProducts = (() => {
		// Build a map of barcode -> best page-order (lowest page, then lowest order)
		const selectionMap = new Map<string, {page: number, order: number}>();
		templates.forEach(t => {
			t.selectedProducts.forEach((selection, barcode) => {
				const existing = selectionMap.get(barcode);
				if (!existing || selection.page < existing.page || 
					(selection.page === existing.page && selection.order < existing.order)) {
					selectionMap.set(barcode, selection);
				}
			});
		});
		
		return [...filteredProducts].sort((a, b) => {
			const aSelection = selectionMap.get(a.barcode);
			const bSelection = selectionMap.get(b.barcode);
			
			// Selected products come first
			if (aSelection && !bSelection) return -1;
			if (!aSelection && bSelection) return 1;
			
			// Both selected: sort by page, then by order
			if (aSelection && bSelection) {
				if (aSelection.page !== bSelection.page) {
					return aSelection.page - bSelection.page;
				}
				return aSelection.order - bSelection.order;
			}
			
			// Neither selected: keep original order
			return 0;
		});
	})();
	
	// Open image popup
	function openImagePopup(imageUrl: string, productName: string) {
		popupImageUrl = imageUrl;
		popupImageName = productName;
		showImagePopup = true;
	}
	
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
				<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
						<!-- Search input for category -->
						<div class="relative">
							<input
								type="text"
								bind:value={categorySearchQuery}
								placeholder="Search categories..."
								class="w-full px-3 py-2 pr-8 border border-gray-300 rounded-t-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							/>
							{#if categorySearchQuery}
								<button
									on:click={() => categorySearchQuery = ''}
									class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
									title="Clear search"
								>
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							{/if}
						</div>
						<!-- Multi-select category list -->
						<div class="max-h-40 overflow-y-auto border border-gray-300 border-t-0 rounded-b-lg bg-white">
							{#each parentCategories.filter(cat => !categorySearchQuery || cat.toLowerCase().includes(categorySearchQuery.toLowerCase())) as category}
								<label class="flex items-center px-3 py-1.5 hover:bg-blue-50 cursor-pointer border-b border-gray-100 last:border-b-0">
									<input
										type="checkbox"
										checked={selectedCategories.includes(category)}
										on:change={() => toggleCategory(category)}
										class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
									/>
									<span class="ml-2 text-sm text-gray-700">{category}</span>
								</label>
							{:else}
								<p class="px-3 py-2 text-sm text-gray-500 italic">No categories found</p>
							{/each}
						</div>
						<p class="text-xs text-gray-500 mt-1">
							{selectedCategories.length > 0 ? `${selectedCategories.length} selected` : 'All categories'} • {parentCategories.filter(cat => !categorySearchQuery || cat.toLowerCase().includes(categorySearchQuery.toLowerCase())).length} available
						</p>
					</div>
					
					<!-- Page Summary Cards - Right Side -->
					<div class="md:col-span-2">
						<label class="block text-sm font-medium text-gray-700 mb-1">Page Summary</label>
						{#if templates.length > 0 && templates.some(t => t.selectedProducts.size > 0)}
							<div class="grid grid-cols-1 md:grid-cols-3 gap-2 max-h-48 overflow-y-auto">
								{#each templates as template (template.id)}
									{@const pageSummary = getPageSummary(template)}
									{@const offerName = offerNames.find(o => o.id === template.offerNameId)}
									{#if template.selectedProducts.size > 0}
										<div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-2 border border-blue-200">
											<div class="flex flex-col mb-1">
												{#if offerName}
													<span class="text-xs font-bold text-purple-700 uppercase">{offerName.name_en}</span>
												{/if}
												<div class="flex items-center justify-between">
													<h4 class="text-xs font-semibold text-blue-800 truncate" title={template.name}>{template.name}</h4>
													<span class="text-xs font-bold text-green-600 bg-green-100 px-1.5 py-0.5 rounded ml-1 whitespace-nowrap">{template.selectedProducts.size}</span>
												</div>
											</div>
											<div class="grid grid-cols-5 gap-0.5">
												{#each Array.from(pageSummary.entries()).sort((a, b) => a[0] - b[0]) as [pageNum, count]}
													<div class="flex items-center justify-center bg-white rounded px-1 py-1 shadow-sm border border-blue-100">
														<span class="text-xs font-medium text-gray-600">P{pageNum}:</span>
														<span class="ml-0.5 text-xs font-bold text-blue-600">{count}</span>
													</div>
												{/each}
											</div>
										</div>
									{/if}
								{/each}
							</div>
						{:else}
							<div class="bg-gray-50 rounded-lg p-4 border border-gray-200 text-center">
								<p class="text-sm text-gray-500">No products selected yet</p>
								<p class="text-xs text-gray-400 mt-1">Select products to see page summary</p>
							</div>
						{/if}
						
						<div class="mt-2">
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
				</div>
				
				<p class="text-sm text-gray-600">
					Showing {filteredProducts.length} of {products.length} products
				</p>
				
				<!-- Create Variant Group Button (shown when products are selected for grouping) -->
				{#if productsToGroup.size > 0}
					<div class="flex items-center gap-3 mt-2 p-3 bg-purple-50 border border-purple-200 rounded-lg">
						<span class="text-sm font-medium text-purple-700">
							{productsToGroup.size} product{productsToGroup.size > 1 ? 's' : ''} selected for grouping
						</span>
						<button
							on:click={openCreateGroupModal}
							disabled={productsToGroup.size < 2}
							class="px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
							</svg>
							Create Variant Group
						</button>
						<button
							on:click={clearGroupSelection}
							class="px-3 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-300 transition-colors"
						>
							Clear
						</button>
					</div>
				{/if}
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
									<th class="px-2 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-100">
										Group
									</th>
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
												<span class="font-bold text-blue-700">{#if template.offerNameId}{@const selectedOfferName = offerNames.find(o => o.id === template.offerNameId)}{#if selectedOfferName}{selectedOfferName.name_en}{:else}{template.name}{/if}{:else}{template.name}{/if}</span>{#if template.offerNameId}{@const so = offerNames.find(o => o.id === template.offerNameId)}{#if so}<span class="text-xs text-gray-500">{template.name}</span>{/if}{/if}<span class="text-xs text-gray-600">{template.startDate} to {template.endDate}</span><span class="text-xs text-green-600 font-semibold">{template.selectedProducts.size} selected</span>
											</div>
										</th>
									{/each}
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each sortedFilteredProducts as product (product.barcode)}
									<tr class="hover:bg-gray-50 transition-colors">
										<!-- Group Checkbox Column -->
										<td class="px-2 py-4 whitespace-nowrap text-center">
											{#if canProductBeGrouped(product)}
												<input 
													type="checkbox"
													checked={productsToGroup.has(product.barcode)}
													on:change={() => toggleProductForGrouping(product.barcode)}
													class="w-5 h-5 text-purple-600 border-gray-300 rounded focus:ring-purple-500 cursor-pointer"
													title="Select for grouping"
												/>
											{:else}
												<span class="text-xs text-green-600 font-medium">🔗</span>
											{/if}
										</td>
										<td class="px-6 py-4 whitespace-nowrap sticky left-0 bg-white z-10">
											<div class="w-16 h-16 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden">
												{#if product.image_url}
													<button
														type="button"
														on:click={() => openImagePopup(product.image_url, product.product_name_en || product.barcode)}
														class="w-full h-full cursor-zoom-in hover:opacity-80 transition-opacity"
														title="Click to enlarge"
													>
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
													</button>
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
									<!-- Dynamic Template Checkboxes with Page/Order -->
										{#each templates as template (template.id)}
											{@const blockInfo = isProductBlockedInTemplate(template.id, product.barcode)}
											<td class="px-2 py-2 text-center bg-blue-50 border-l-2 border-blue-200">
												<div class="flex flex-col items-center gap-1">
													{#if blockInfo.blocked && !isProductSelected(template.id, product.barcode)}
														<!-- Blocked - show X with tooltip -->
														<div class="relative group">
															<div class="w-5 h-5 flex items-center justify-center bg-red-100 rounded border-2 border-red-300 cursor-not-allowed">
																<svg class="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
																	<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
																</svg>
															</div>
															<div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 bg-red-700 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-30 pointer-events-none">
																Already in "{blockInfo.conflictTemplate}" (dates overlap)
															</div>
														</div>
													{:else}
														<input 
															type="checkbox"
															checked={isProductSelected(template.id, product.barcode)}
															on:change={() => toggleProductSelection(template.id, product.barcode)}
															class="w-5 h-5 text-blue-600 border-gray-300 rounded focus:ring-blue-500 cursor-pointer"
														/>
													{/if}
													{#if isProductSelected(template.id, product.barcode)}
														{@const selection = getProductSelection(template, product.barcode)}
														<div class="flex items-center gap-1 mt-1">
															<input 
																type="number"
																min="1"
																value={selection?.page || 1}
																on:change={(e) => updateProductPageOrder(template.id, product.barcode, parseInt(e.currentTarget.value) || 1, 0, true)}
																class="w-14 h-8 text-sm text-center border border-gray-300 rounded focus:ring-blue-500 font-semibold"
																title="Page number - order auto-assigns"
															/>
															<span class="text-gray-500 font-bold text-lg">-</span>
															<input 
																type="number"
																min="1"
																value={selection?.order || 1}
																on:change={(e) => updateProductPageOrder(template.id, product.barcode, selection?.page || 1, parseInt(e.currentTarget.value) || 1, false)}
																class="w-14 h-8 text-sm text-center border border-gray-300 rounded focus:ring-blue-500 font-semibold"
																title="Order on page"
															/>
														</div>
														<span class="text-sm font-bold text-blue-600">{getPageOrderDisplay(template, product.barcode)}</span>
													{/if}
												</div>
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
									<div class="flex items-center gap-2 bg-blue-50 p-2 rounded mb-3">
										<svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
										</svg>
										<div class="flex-1">
											<span class="text-xs text-gray-600 block">Offer Name:</span>
											<span class="font-semibold text-blue-700">{selectedOfferName.name_en}</span>
										</div>
									</div>
								{:else}
									<!-- Debug: Show when offer name ID exists but not found -->
									<div class="text-xs text-orange-600 mb-2">Offer ID: {template.offerNameId} (not found in {offerNames.length} names)</div>
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
	{@const groupBarcodes = new Set([currentVariationGroup.barcode, ...currentVariations.map(v => v.barcode)])}
	{@const templateSelection = templates.find(t => t.id === currentTemplateForVariation)?.selectedProducts}
	{@const preSelected = new Set([...groupBarcodes].filter(b => templateSelection?.has(b)))}
	<VariationSelectionModal
		parentProduct={currentVariationGroup}
		variations={currentVariations}
		templateId={currentTemplateForVariation}
		preSelectedBarcodes={preSelected}
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

<!-- Image Popup Modal -->
{#if showImagePopup}
	<div 
		class="fixed inset-0 bg-black bg-opacity-80 z-50 flex items-center justify-center p-4"
		on:click={() => showImagePopup = false}
		on:keydown={(e) => e.key === 'Escape' && (showImagePopup = false)}
		role="dialog"
		aria-modal="true"
		aria-label="Image preview"
	>
		<div class="relative max-w-4xl max-h-[90vh] bg-white rounded-lg overflow-hidden shadow-2xl" on:click|stopPropagation>
			<!-- Close button -->
			<button
				on:click={() => showImagePopup = false}
				class="absolute top-2 right-2 z-10 bg-white rounded-full p-2 shadow-lg hover:bg-gray-100 transition-colors"
				title="Close"
			>
				<svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
				</svg>
			</button>
			
			<!-- Image -->
			<div class="p-4 bg-gray-100">
				<img 
					src={popupImageUrl}
					alt={popupImageName}
					class="max-w-full max-h-[70vh] mx-auto object-contain"
				/>
			</div>
			
			<!-- Product name -->
			<div class="p-4 bg-white border-t">
				<p class="text-center text-lg font-semibold text-gray-800">{popupImageName}</p>
			</div>
		</div>
	</div>
{/if}

<!-- Create Variant Group Modal -->
{#if showCreateGroupModal}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
			<div class="p-6 border-b border-gray-200">
				<h2 class="text-2xl font-bold text-gray-800">Create Variation Group</h2>
				<p class="text-sm text-gray-600 mt-1">
					Grouping {productsToGroup.size} products together
				</p>
			</div>
			
			<div class="p-6 space-y-4">
				<!-- Parent Selection -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Parent Product <span class="text-red-500">*</span>
					</label>
					<select
						bind:value={groupParentBarcode}
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
					>
						{#each Array.from(productsToGroup) as barcode}
							{@const product = products.find(p => p.barcode === barcode)}
							{#if product}
								<option value={barcode}>
									{product.product_name_en} ({barcode})
								</option>
							{/if}
						{/each}
					</select>
					<p class="text-xs text-gray-500 mt-1">
						The parent product represents the main item in the group
					</p>
				</div>

				<!-- AI Generate Button -->
				<div class="bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-200 rounded-lg p-4">
					<div class="flex items-center justify-between">
						<div class="flex items-center gap-2">
							<span class="text-lg">✨</span>
							<div>
								<div class="text-sm font-medium text-purple-800">AI Group Name Generator</div>
								<div class="text-xs text-purple-600">Automatically generate English & Arabic names</div>
							</div>
						</div>
						<button
							type="button"
							on:click={generateAIGroupName}
							disabled={isGeneratingAIName || productsToGroup.size === 0}
							class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 text-sm font-medium"
						>
							{#if isGeneratingAIName}
								<svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
									<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
									<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
								</svg>
								Generating...
							{:else}
								🤖 Generate with AI
							{/if}
						</button>
					</div>
				</div>
				
				<!-- Group Name EN -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Group Name (English) <span class="text-red-500">*</span>
					</label>
					<input
						type="text"
						bind:value={groupNameEn}
						placeholder="e.g., Coca Cola Bottles"
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
					/>
				</div>
				
				<!-- Group Name AR -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Group Name (Arabic) <span class="text-red-500">*</span>
					</label>
					<input
						type="text"
						bind:value={groupNameAr}
						placeholder="مثال: زجاجات كوكاكولا"
						dir="rtl"
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 font-arabic"
					/>
				</div>
				
				<!-- Selected Products Preview -->
				<div class="bg-gray-50 rounded-lg p-4">
					<div class="text-sm font-medium text-gray-700 mb-2">Selected Products ({productsToGroup.size}):</div>
					<div class="max-h-40 overflow-y-auto space-y-1">
						{#each Array.from(productsToGroup) as barcode}
							{@const product = products.find(p => p.barcode === barcode)}
							{#if product}
								<div class="text-sm text-gray-600 flex items-center gap-2">
									{#if barcode === groupParentBarcode}
										<span class="px-1.5 py-0.5 bg-purple-100 text-purple-700 text-xs rounded font-medium">Parent</span>
									{:else}
										<span class="px-1.5 py-0.5 bg-gray-100 text-gray-600 text-xs rounded">Variation</span>
									{/if}
									<span>{product.product_name_en}</span>
								</div>
							{/if}
						{/each}
					</div>
				</div>
			</div>
			
			<div class="p-6 border-t border-gray-200 flex items-center justify-end gap-3">
				<button
					on:click={closeCreateGroupModal}
					disabled={isCreatingGroup}
					class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50"
				>
					Cancel
				</button>
				<button
					on:click={createVariantGroup}
					disabled={isCreatingGroup || !groupNameEn || !groupNameAr || !groupParentBarcode}
					class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
				>
					{#if isCreatingGroup}
						<svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Creating...
					{:else}
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
						</svg>
						Create Group
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}