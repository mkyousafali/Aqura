<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { t } from '$lib/i18n';
	
	// State
	let products: any[] = [];
	let filteredProducts: any[] = [];
	let searchQuery: string = '';
	let filterStatus: 'all' | 'grouped' | 'ungrouped' = 'all';
	let sortBy: 'category' | 'price' = 'category';
	let isLoading: boolean = false;
	let selectedProducts: Set<string> = new Set();
	
	// Image loading state
	let successfullyLoadedImages: Set<string> = new Set(); // Track which images have loaded successfully
	let imageRefs: Record<string, HTMLImageElement> = {}; // Track image element refs
	
	// Cache configuration (shared across all flyer components)
	const CACHE_KEY = 'flyer_products_cache';
	const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
	
	// Group creation/edit modal
	let showGroupModal: boolean = false;
	let isEditMode: boolean = false;
	let groupParentBarcode: string = '';
	let groupNameEn: string = '';
	let groupNameAr: string = '';
	let groupImageOverride: string = '';
	let imageOverrideType: 'parent' | 'variation' | 'custom' = 'parent';
	let selectedImageBarcode: string = '';
	let isCreatingGroup: boolean = false;
	let isGeneratingAIName: boolean = false;
	
	// Group management
	let variationGroups: any[] = [];
	let expandedGroups: Set<string> = new Set();
	let showGroupsView: boolean = false;
	let isLoadingGroups: boolean = false;
	let loadedGroupVariations: Map<string, any[]> = new Map(); // Cache loaded variations
	let groupsPage: number = 1;
	let groupsItemsPerPage: number = 20; // Show 20 groups per page
	
	// Image preview
	let showImagePreview: boolean = false;
	let previewImageUrl: string = '';
	
	// Stats
	let totalProducts: number = 0;
	let groupedProducts: number = 0;
	let totalGroups: number = 0;

	// Category filter
	let categories: any[] = [];
	let selectedCategoryId: string = '';
	let categorySearchQuery: string = '';
	let showCategoryDropdown: boolean = false;

	// Realtime subscriptions
	let realtimeSubscriptions: any[] = [];

	// Subscribe to realtime changes
	function subscribeToRealtimeChanges() {
		try {
			// Subscribe to variation_audit_log table changes
			const auditLogChannel = supabase
				.channel('variation-audit-log-changes')
				.on(
					'postgres_changes',
					{
						event: '*',
						schema: 'public',
						table: 'variation_audit_log'
					},
					(payload) => {
						handleAuditLogChange(payload);
					}
				)
				.subscribe((status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✓ Subscribed to variation_audit_log realtime updates');
					}
				});

			realtimeSubscriptions.push(auditLogChannel);
		} catch (error) {
			console.error('Error setting up realtime subscriptions:', error);
		}
	}

	// Handle variation audit log changes - just log, don't reload (we update locally)
	function handleAuditLogChange(payload: any) {
		const { eventType } = payload;
		
		// Just log the change, we handle updates locally for better UX
		if (eventType === 'INSERT') {
			console.log('✓ Variation group action recorded via realtime');
			// If in groups view, refresh groups list only
			if (showGroupsView) {
				loadVariationGroups();
			}
		}
	}

	// Cleanup subscriptions on unmount
	function unsubscribeFromRealtimeChanges() {
		realtimeSubscriptions.forEach((channel) => {
			supabase.removeChannel(channel);
		});
		realtimeSubscriptions = [];
		console.log('✓ Unsubscribed from realtime updates');
	}

	onMount(async () => {
		await Promise.all([loadProductsAndStats(), loadCategories()]);
		subscribeToRealtimeChanges();

		// Cleanup on unmount
		return () => {
			unsubscribeFromRealtimeChanges();
		};
	});
	
	async function loadProductsAndStats() {
		isLoading = true;
		products = [];
		
		// Clear old cache to ensure we get fresh data with category
		try {
			localStorage.removeItem(CACHE_KEY);
		} catch (err) {
			console.warn('Cache clear error:', err);
		}
		
		try {
			let allProducts: any[] = [];
			let parents: any[] = [];
			let offset = 0;
			const limit = 500; // Load 500 at a time
			let hasMore = true;
			
			// Load products in chunks without blocking UI
			while (hasMore) {
				const { data: productsData, error: productsError } = await supabase
					.from('products')
					.select('barcode, product_name_en, product_name_ar, is_variation, parent_product_barcode, created_at, image_url, category_id, product_categories(name_en, name_ar)')
					.order('product_name_en', { ascending: true })
					.range(offset, offset + limit - 1);
				
				if (productsError) {
					console.error('Error loading products chunk:', productsError);
					break;
				}
				
				if (!productsData || productsData.length === 0) {
					hasMore = false;
					break;
				}
				
				allProducts = [...allProducts, ...productsData];
				
				// Update UI with loaded products so far - triggers reactive display
				products = allProducts;
				
				// Calculate stats progressively
				totalProducts = allProducts.length;
				groupedProducts = allProducts.filter(p => p.is_variation).length;
				parents = allProducts.filter(p => p.is_variation && !p.parent_product_barcode) || [];
				totalGroups = parents.length;
				
				// Small delay to allow UI to render between chunks
				await new Promise(resolve => setTimeout(resolve, 10));
				
				offset += limit;
				if (productsData.length < limit) {
					hasMore = false;
				}
			}
			
			products = allProducts;
			
			// Calculate final stats
			totalProducts = allProducts.length;
			groupedProducts = allProducts.filter(p => p.is_variation).length;
			parents = allProducts.filter(p => p.is_variation && !p.parent_product_barcode) || [];
			totalGroups = parents.length;
			
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
			
			console.log('✓ All products loaded:', allProducts.length);
		} catch (error) {
			console.error('Error loading products and stats:', error);
			notifications.add({
				message: 'Failed to load products',
				type: 'error',
				duration: 3000
			});
		} finally {
			isLoading = false;
		}
	}
	
	async function loadVariationGroups() {
		isLoadingGroups = true;
		try {
			// Get all parent products with pagination (is_variation=true and variation_order=0)
			const { data, error, count } = await supabase
				.from('products')
				.select('*', { count: 'exact' })
				.eq('is_variation', true)
				.eq('variation_order', 0)
				.order('variation_group_name_en', { ascending: true })
				.range((groupsPage - 1) * groupsItemsPerPage, groupsPage * groupsItemsPerPage - 1);
			
			if (error) throw error;
			
			// Get barcodes of all parent products for batch query
			const parentBarcodes = (data || []).map(p => p.barcode);
			
			// Batch load all variations in one query instead of N+1
			let variationsMap: Map<string, any[]> = new Map();
			if (parentBarcodes.length > 0) {
				const { data: allVariations, error: varError } = await supabase
					.from('products')
					.select('*')
					.in('parent_product_barcode', parentBarcodes)
					.order('parent_product_barcode', { ascending: true })
					.order('variation_order', { ascending: true });
				
				if (varError) throw varError;
				
				// Group variations by parent barcode
				(allVariations || []).forEach(variation => {
					const key = variation.parent_product_barcode;
					if (!variationsMap.has(key)) {
						variationsMap.set(key, []);
					}
					variationsMap.get(key)!.push(variation);
				});
			}
			
			// Build groups with variations from map
			const groupsWithVariations = (data || []).map(parent => ({
				parent,
				variations: variationsMap.get(parent.barcode) || [],
				totalCount: (variationsMap.get(parent.barcode)?.length || 0) + 1 // +1 for parent
			}));
			
			variationGroups = groupsWithVariations;
			
			// Store in cache for lazy loading
			groupsWithVariations.forEach(group => {
				loadedGroupVariations.set(group.parent.barcode, group.variations);
			});
		} catch (error) {
			console.error('Error loading groups:', error);
			notifications.add({
				message: 'Failed to load variation groups',
				type: 'error',
				duration: 3000
			});
		} finally {
			isLoadingGroups = false;
		}
	}

	// Load categories for filter
	async function loadCategories() {
		try {
			const { data, error } = await supabase
				.from('product_categories')
				.select('id, name_en, name_ar')
				.order('name_en', { ascending: true });
			
			if (error) throw error;
			categories = data || [];
		} catch (error) {
			console.error('Error loading categories:', error);
		}
	}

	// Filtered categories for searchable dropdown
	$: filteredCategories = categories.filter(cat => {
		if (!categorySearchQuery) return true;
		const query = categorySearchQuery.toLowerCase();
		return cat.name_en?.toLowerCase().includes(query) || cat.name_ar?.includes(query);
	});

	// Get selected category name
	$: selectedCategoryName = categories.find(c => c.id === selectedCategoryId)?.name_en || 'All Categories';
	
	// Reactive filtering - updates automatically when products, searchQuery, filterStatus, or sortBy change
	$: filteredProducts = (() => {
		let filtered = [...products];
		
		// Search filter
		if (searchQuery) {
			const query = searchQuery.toLowerCase();
			filtered = filtered.filter(p => 
				p.barcode?.toLowerCase().includes(query) ||
				p.product_name_en?.toLowerCase().includes(query) ||
				p.product_name_ar?.includes(query)
			);
		}
		
		// Category filter
		if (selectedCategoryId) {
			filtered = filtered.filter(p => p.category_id === selectedCategoryId);
		}
		
		// Status filter
		if (filterStatus === 'grouped') {
			filtered = filtered.filter(p => p.is_variation);
		} else if (filterStatus === 'ungrouped') {
			filtered = filtered.filter(p => !p.is_variation);
		}
		
		// Sort
		filtered.sort((a, b) => {
			if (sortBy === 'category') {
				const catA = a.product_categories?.name_en || '';
				const catB = b.product_categories?.name_en || '';
				return catA.localeCompare(catB);
			}
			return 0;
		});
		
		return filtered;
	})();
	
	// Image loading handlers
	function handleImageLoad(event: Event) {
		const img = event.target as HTMLImageElement;
		const barcode = img.dataset.barcode;
		if (barcode) {
			successfullyLoadedImages.add(barcode);
			successfullyLoadedImages = successfullyLoadedImages; // Trigger reactivity
		}
	}
	
	function handleImageError(event: Event) {
		const img = event.target as HTMLImageElement;
		const barcode = img.dataset.barcode;
		if (barcode && successfullyLoadedImages.has(barcode)) {
			successfullyLoadedImages.delete(barcode);
			successfullyLoadedImages = successfullyLoadedImages; // Trigger reactivity
		}
	}
	
	// Group pagination computed values
	$: totalGroupPages = Math.ceil((variationGroups.length > 0 ? Math.max(...variationGroups.map(() => 1)) * groupsItemsPerPage : groupsItemsPerPage) / groupsItemsPerPage);
	
	function nextGroupsPage() {
		groupsPage++;
		loadVariationGroups();
	}
	
	function prevGroupsPage() {
		if (groupsPage > 1) {
			groupsPage--;
			loadVariationGroups();
		}
	}
	
	function toggleProductSelection(barcode: string) {
		if (selectedProducts.has(barcode)) {
			selectedProducts.delete(barcode);
		} else {
			selectedProducts.add(barcode);
		}
		selectedProducts = selectedProducts; // Trigger reactivity
	}
	
	function selectAll() {
		filteredProducts.forEach(p => selectedProducts.add(p.barcode));
		selectedProducts = selectedProducts;
	}
	
	function deselectAll() {
		selectedProducts.clear();
		selectedProducts = selectedProducts;
	}
	
	function openGroupModal() {
		if (selectedProducts.size < 2) {
			notifications.add({
				message: 'Please select at least 2 products to create a group',
				type: 'warning',
				duration: 3000
			});
			return;
		}
		
		// If not in edit mode, initialize new group creation
		if (!isEditMode) {
			// Pre-select first product as parent
			const firstBarcode = Array.from(selectedProducts)[0];
			groupParentBarcode = firstBarcode;
		}
		// If in edit mode, preserve existing groupNameEn, groupNameAr, and groupParentBarcode
		
		showGroupModal = true;
	}
	
	async function openEditGroupModal(parentBarcode: string, groupName: string, groupNameArParam: string) {
		// Switch to Products View
		showGroupsView = false;
		
		// Load all products in this group
		const { data: groupProducts, error } = await supabase
			.from('products')
			.select('barcode')
			.eq('parent_product_barcode', parentBarcode);
		
		if (error) {
			notifications.add({
				message: 'Failed to load group products',
				type: 'error',
				duration: 3000
			});
			return;
		}
		
		// Pre-select all products in the group
		selectedProducts.clear();
		groupProducts?.forEach(p => selectedProducts.add(p.barcode));
		selectedProducts = selectedProducts; // Trigger reactivity
		
		// Set edit mode state
		isEditMode = true;
		groupParentBarcode = parentBarcode;
		groupNameEn = groupName;
		groupNameAr = groupNameArParam;
		
		console.log('🔧 Edit mode set:', { groupNameEn, groupNameAr: groupNameArParam });
		
		notifications.add({
			message: `Editing "${groupName}" - Select or deselect products, then click Update Group`,
			type: 'info',
			duration: 5000
		});
	}
	
	function closeGroupModal() {
		showGroupModal = false;
		isEditMode = false;
		groupParentBarcode = '';
		groupNameEn = '';
		groupNameAr = '';
		groupImageOverride = '';
		imageOverrideType = 'parent';
		selectedImageBarcode = '';
	}

	// Update products locally without full reload
	function updateProductsLocally(barcodes: string[], updates: Partial<any>) {
		products = products.map(p => {
			if (barcodes.includes(p.barcode)) {
				return { ...p, ...updates };
			}
			return p;
		});
		// Recalculate stats
		totalProducts = products.length;
		groupedProducts = products.filter(p => p.is_variation).length;
		const parents = products.filter(p => p.is_variation && !p.parent_product_barcode) || [];
		totalGroups = parents.length;
	}

	// AI Generate Group Name
	async function generateAIGroupName() {
		if (selectedProducts.size === 0) {
			notifications.add({
				message: 'No products selected',
				type: 'warning',
				duration: 3000
			});
			return;
		}

		isGeneratingAIName = true;
		try {
			// Get product names from selected products
			const productNames: string[] = [];
			selectedProducts.forEach((barcode) => {
				const product = products.find(p => p.barcode === barcode);
				if (product?.product_name_en) {
					productNames.push(product.product_name_en);
				}
			});

			if (productNames.length === 0) {
				notifications.add({
					message: 'Could not find product names',
					type: 'error',
					duration: 3000
				});
				return;
			}

			const response = await fetch('/api/generate-group-name', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ productNames })
			});

			const result = await response.json();

			if (result.error) {
				throw new Error(result.error);
			}

			// Auto-fill the group names
			groupNameEn = result.nameEn || 'Assorted Products';
			groupNameAr = result.nameAr || 'منتجات متنوعة';

			notifications.add({
				message: '✨ AI generated group name successfully!',
				type: 'success',
				duration: 3000
			});

		} catch (error) {
			console.error('Error generating AI group name:', error);
			notifications.add({
				message: `Failed to generate name: ${error instanceof Error ? error.message : 'Unknown error'}`,
				type: 'error',
				duration: 4000
			});
		} finally {
			isGeneratingAIName = false;
		}
	}
	
	async function createGroup() {
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
			if (isEditMode) {
				// EDIT MODE: Update group membership based on selected products
				
				// Step 1: Ensure parent product has correct variation_order = 0 and group names
				await supabase
					.from('products')
					.update({
						is_variation: true,
						parent_product_barcode: groupParentBarcode,
						variation_group_name_en: groupNameEn,
						variation_group_name_ar: groupNameAr,
						variation_order: 0,
						modified_at: new Date().toISOString()
					})
					.eq('barcode', groupParentBarcode);
				
				// Step 2: Get all existing variations in this group
				const { data: existingVariations } = await supabase
					.from('products')
					.select('barcode')
					.eq('parent_product_barcode', groupParentBarcode)
					.neq('barcode', groupParentBarcode); // Exclude parent itself
				
				const existingBarcodes = new Set(existingVariations?.map(v => v.barcode) || []);
				const selectedBarcodes = new Set(
					Array.from(selectedProducts).filter(b => b !== groupParentBarcode)
				);
				
				// Step 3: Find products to remove (were in group but not selected anymore)
				const barcodesToRemove = Array.from(existingBarcodes).filter(
					barcode => !selectedBarcodes.has(barcode)
				);
				
				// Step 4: Find products to add (selected but not in group yet)
				const barcodesToAdd = Array.from(selectedBarcodes).filter(
					barcode => !existingBarcodes.has(barcode)
				);
				
				// Step 5: Remove unselected products from group
				for (const barcode of barcodesToRemove) {
					await supabase
						.from('products')
						.update({
							is_variation: false,
							parent_product_barcode: null,
							variation_group_name_en: null,
							variation_group_name_ar: null,
							variation_order: null,
							modified_at: new Date().toISOString()
						})
						.eq('barcode', barcode);
				}
				
				// Step 6: Add new selected products to group
				for (const barcode of barcodesToAdd) {
					await supabase
						.from('products')
						.update({
							is_variation: true,
							parent_product_barcode: groupParentBarcode,
							variation_group_name_en: groupNameEn,
							variation_group_name_ar: groupNameAr,
							variation_order: 999, // Temporary, will be fixed in Step 7
							modified_at: new Date().toISOString()
						})
						.eq('barcode', barcode);
				}
				
				// Step 7: Re-number all remaining variations sequentially (1, 2, 3...)
				const { data: finalVariations } = await supabase
					.from('products')
					.select('barcode')
					.eq('parent_product_barcode', groupParentBarcode)
					.neq('barcode', groupParentBarcode)
					.order('product_name_en', { ascending: true });
				
				let orderCounter = 1;
				for (const variation of (finalVariations || [])) {
					await supabase
						.from('products')
						.update({
							variation_order: orderCounter++,
							variation_group_name_en: groupNameEn,
							variation_group_name_ar: groupNameAr,
							modified_at: new Date().toISOString()
						})
						.eq('barcode', variation.barcode);
				}
				
				const changesMsg = [];
				if (barcodesToAdd.length > 0) changesMsg.push(`Added ${barcodesToAdd.length}`);
				if (barcodesToRemove.length > 0) changesMsg.push(`Removed ${barcodesToRemove.length}`);
				
				notifications.add({
					message: `Group updated: ${changesMsg.join(', ') || 'No changes'}`,
					type: 'success',
					duration: 3000
				});
				
				// Update products locally
				const allGroupBarcodes = [groupParentBarcode, ...Array.from(selectedBarcodes)];
				updateProductsLocally(allGroupBarcodes, {
					is_variation: true,
					parent_product_barcode: groupParentBarcode,
					variation_group_name_en: groupNameEn,
					variation_group_name_ar: groupNameAr
				});
				// Mark removed products as ungrouped
				updateProductsLocally(barcodesToRemove as string[], {
					is_variation: false,
					parent_product_barcode: null,
					variation_group_name_en: null,
					variation_group_name_ar: null
				});
				
				// Close modal and reset
				deselectAll();
				closeGroupModal();
				isCreatingGroup = false;
			} else {
				// CREATE MODE: Create new group
			// Get selected barcodes excluding parent
			const variationBarcodes = Array.from(selectedProducts).filter(
				b => b !== groupParentBarcode
			);
			
			// Determine image override value
			let imageOverride = null;
			if (imageOverrideType === 'variation' && selectedImageBarcode) {
				const selectedProduct = products.find(p => p.barcode === selectedImageBarcode);
				imageOverride = selectedProduct?.image_url || null;
			} else if (imageOverrideType === 'custom' && groupImageOverride) {
				imageOverride = groupImageOverride;
			}
			
			// Call database function to create group
			const { data, error } = await supabase.rpc('create_variation_group', {
				p_parent_barcode: groupParentBarcode,
				p_variation_barcodes: variationBarcodes,
				p_group_name_en: groupNameEn,
				p_group_name_ar: groupNameAr,
				p_image_override: imageOverride,
				p_user_id: null // TODO: Get from auth context
			});
			
			if (error) throw error;
			
			if (data && data.length > 0 && data[0].success) {
				notifications.add({
					message: `Variation group created: ${data[0].affected_count} products grouped`,
					type: 'success',
					duration: 3000
				});
				
				// Update products locally
				const allGroupBarcodes = [groupParentBarcode, ...variationBarcodes];
				updateProductsLocally(allGroupBarcodes, {
					is_variation: true,
					parent_product_barcode: groupParentBarcode,
					variation_group_name_en: groupNameEn,
					variation_group_name_ar: groupNameAr
				});
				// Mark parent specifically
				updateProductsLocally([groupParentBarcode], {
					parent_product_barcode: null // Parent doesn't have parent_product_barcode
				});
				
				// Close modal and reset
				deselectAll();
				closeGroupModal();
				isCreatingGroup = false;
			} else {
				throw new Error(data?.[0]?.message || 'Failed to create group');
			}
			}
		} catch (error) {
			console.error('Error creating/editing group:', error);
			notifications.add({
				message: `Failed to ${isEditMode ? 'edit' : 'create'} group: ${error.message}`,
				type: 'error',
				duration: 5000
			});
		} finally {
			isCreatingGroup = false;
		}
	}
	
	async function deleteGroup(parentBarcode: string, groupName: string) {
		if (!confirm(`Are you sure you want to ungroup "${groupName}"? All products will become standalone.`)) {
			return;
		}
		
		try {
			// Get all products in the group
			const { data: groupProducts, error: fetchError } = await supabase
				.from('products')
				.select('barcode')
				.or(`barcode.eq.${parentBarcode},parent_product_barcode.eq.${parentBarcode}`);
			
			if (fetchError) throw fetchError;
			
			// Update all products to be standalone
			const barcodes = groupProducts?.map(p => p.barcode) || [];
			
			const { error: updateError } = await supabase
				.from('products')
				.update({
					is_variation: false,
					parent_product_barcode: null,
					variation_group_name_en: null,
					variation_group_name_ar: null,
					variation_order: 0,
					variation_image_override: null,
					modified_at: new Date().toISOString()
				})
				.in('barcode', barcodes);
			
			if (updateError) throw updateError;
			
			// Log to audit
			await supabase.from('variation_audit_log').insert({
				action_type: 'delete_group',
				affected_barcodes: barcodes,
				parent_barcode: parentBarcode,
				group_name_en: groupName,
				details: { ungrouped_count: barcodes.length }
			});
			
			notifications.add({
				message: `Group "${groupName}" deleted. ${barcodes.length} products ungrouped.`,
				type: 'success',
				duration: 3000
			});
			
			// Update products locally
			updateProductsLocally(barcodes, {
				is_variation: false,
				parent_product_barcode: null,
				variation_group_name_en: null,
				variation_group_name_ar: null,
				variation_order: 0,
				variation_image_override: null
			});
			
			// Remove from groups view if showing
			if (showGroupsView) {
				variationGroups = variationGroups.filter(g => g.parent.barcode !== parentBarcode);
			}
		} catch (error) {
			console.error('Error deleting group:', error);
			notifications.add({
				message: `Failed to delete group: ${error.message}`,
				type: 'error',
				duration: 5000
			});
		}
	}
	
	function toggleGroupExpansion(parentBarcode: string) {
		if (expandedGroups.has(parentBarcode)) {
			expandedGroups.delete(parentBarcode);
		} else {
			expandedGroups.add(parentBarcode);
			// Lazy load variations for this group if not cached
			if (!loadedGroupVariations.has(parentBarcode)) {
				loadGroupVariations(parentBarcode);
			}
		}
		expandedGroups = expandedGroups;
	}
	
	// Lazy load variations for a specific group
	async function loadGroupVariations(parentBarcode: string) {
		try {
			const { data: variations, error: varError } = await supabase
				.from('products')
				.select('*')
				.eq('parent_product_barcode', parentBarcode)
				.order('variation_order', { ascending: true });
			
			if (varError) throw varError;
			
			loadedGroupVariations.set(parentBarcode, variations || []);
			
			// Update the group in the array
			variationGroups = variationGroups.map(group => {
				if (group.parent.barcode === parentBarcode) {
					return {
						...group,
						variations: variations || [],
						totalCount: (variations?.length || 0) + 1
					};
				}
				return group;
			});
		} catch (error) {
			console.error('Error loading group variations:', error);
			notifications.add({
				message: 'Failed to load group variations',
				type: 'error',
				duration: 3000
			});
		}
	}
	
	function previewImage(imageUrl: string) {
		previewImageUrl = imageUrl;
		showImagePreview = true;
	}
	
	async function toggleView() {
		showGroupsView = !showGroupsView;
		if (showGroupsView) {
			await loadVariationGroups();
		}
	}
</script>

<!-- Click outside to close category dropdown -->
<svelte:window on:click={() => showCategoryDropdown = false} />

<div class="variation-manager h-full flex flex-col bg-gray-50">
	<!-- Header -->
	<div class="bg-white border-b border-gray-200 px-6 py-4">
		<div class="flex items-center justify-between">
			<div>
				<h1 class="text-2xl font-bold text-gray-800 flex items-center gap-2">
					🔗 Variation Manager
				</h1>
				<p class="text-sm text-gray-600 mt-1">
					Group similar products together for easier management
				</p>
			</div>
			
			<!-- Stats -->
			<div class="flex gap-4">
				<div class="text-center px-4 py-2 bg-blue-50 rounded-lg">
					<div class="text-2xl font-bold text-blue-600">{totalProducts}</div>
					<div class="text-xs text-gray-600">Total Products</div>
				</div>
				<div class="text-center px-4 py-2 bg-green-50 rounded-lg">
					<div class="text-2xl font-bold text-green-600">{totalGroups}</div>
					<div class="text-xs text-gray-600">Groups</div>
				</div>
				<div class="text-center px-4 py-2 bg-purple-50 rounded-lg">
					<div class="text-2xl font-bold text-purple-600">{groupedProducts}</div>
					<div class="text-xs text-gray-600">Grouped Products</div>
				</div>
			</div>
		</div>
	</div>
	
	<!-- Toolbar -->
	<div class="bg-white border-b border-gray-200 px-6 py-3">
		<div class="flex items-center justify-between gap-4">
			<!-- Search -->
			<div class="flex-1 max-w-md">
				<input
					type="text"
					bind:value={searchQuery}
					placeholder="Search by barcode, name..."
					class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
				/>
			</div>
			
			<!-- Filters -->
			<div class="flex items-center gap-3">
				<select
					bind:value={filterStatus}
					class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
				>
					<option value="all">All Products</option>
					<option value="grouped">Grouped Only</option>
					<option value="ungrouped">Ungrouped Only</option>
				</select>
				
				<!-- Searchable Category Dropdown -->
				<div class="relative" on:click|stopPropagation role="listbox" tabindex="0" on:keydown={() => {}}>
					<button
						type="button"
						on:click={() => showCategoryDropdown = !showCategoryDropdown}
						class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 bg-white min-w-[180px] text-left flex items-center justify-between gap-2"
					>
						<span class="truncate">{selectedCategoryName}</span>
						<svg class="w-4 h-4 text-gray-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
						</svg>
					</button>
					
					{#if showCategoryDropdown}
						<div class="absolute top-full left-0 mt-1 w-64 bg-white border border-gray-300 rounded-lg shadow-lg z-50 max-h-80 overflow-hidden">
							<!-- Search input -->
							<div class="p-2 border-b">
								<input
									type="text"
									bind:value={categorySearchQuery}
									placeholder="Search categories..."
									class="w-full px-3 py-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 text-sm"
									on:click|stopPropagation
								/>
							</div>
							
							<!-- Options list -->
							<div class="max-h-56 overflow-y-auto">
								<button
									type="button"
									class="w-full px-4 py-2 text-left hover:bg-gray-100 text-sm {!selectedCategoryId ? 'bg-blue-50 text-blue-700 font-medium' : ''}"
									on:click={() => { selectedCategoryId = ''; showCategoryDropdown = false; categorySearchQuery = ''; }}
								>
									All Categories
								</button>
								{#each filteredCategories as category (category.id)}
									<button
										type="button"
										class="w-full px-4 py-2 text-left hover:bg-gray-100 text-sm {selectedCategoryId === category.id ? 'bg-blue-50 text-blue-700 font-medium' : ''}"
										on:click={() => { selectedCategoryId = category.id; showCategoryDropdown = false; categorySearchQuery = ''; }}
									>
										{category.name_en}
									</button>
								{/each}
								{#if filteredCategories.length === 0}
									<div class="px-4 py-3 text-sm text-gray-500 text-center">No categories found</div>
								{/if}
							</div>
						</div>
					{/if}
				</div>
				
				<button
					on:click={toggleView}
					class="px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors font-medium"
				>
					{showGroupsView ? '📦 Products View' : '🔗 Groups View'}
				</button>
			</div>
		</div>
		
		<!-- Selection actions -->
		{#if selectedProducts.size > 0 && !showGroupsView}
			<div class="mt-3 flex items-center justify-between bg-blue-50 border border-blue-200 rounded-lg px-4 py-2">
				<div class="flex items-center gap-3">
					<span class="text-sm font-medium text-blue-800">
						{selectedProducts.size} product{selectedProducts.size !== 1 ? 's' : ''} selected
					</span>
					{#if isEditMode}
						<span class="text-xs bg-blue-600 text-white px-2 py-1 rounded font-semibold">
							Editing: {groupNameEn}
						</span>
					{/if}
				</div>
				<div class="flex gap-2">
					<button
						on:click={deselectAll}
						class="px-3 py-1 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
					>
						Deselect All
					</button>
					{#if isEditMode}
						<button
							on:click={openGroupModal}
							disabled={selectedProducts.size < 2}
							class="px-4 py-1 text-sm bg-green-600 text-white rounded hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed font-semibold"
						>
							Update Group ({selectedProducts.size})
						</button>
						<button
							on:click={() => {
								isEditMode = false;
								groupParentBarcode = '';
								groupNameEn = '';
								groupNameAr = '';
								deselectAll();
							}}
							class="px-3 py-1 text-sm bg-red-50 text-red-600 border border-red-200 rounded hover:bg-red-100 transition-colors"
						>
							Cancel Edit
						</button>
					{:else}
						<button
							on:click={openGroupModal}
							disabled={selectedProducts.size < 2}
							class="px-4 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Create Group ({selectedProducts.size})
						</button>
					{/if}
				</div>
			</div>
		{/if}
	</div>
	
	<!-- Content -->
	<div class="flex-1 overflow-auto p-6">
		{#if isLoading}
			<div class="flex items-center justify-center h-full">
				<div class="text-center">
					<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
					<p class="mt-4 text-gray-600">Loading products...</p>
				</div>
			</div>
		{:else if showGroupsView}
			<!-- Groups View -->
			{#if isLoadingGroups}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
						<p class="mt-4 text-gray-600">Loading groups...</p>
					</div>
				</div>
			{:else if variationGroups.length === 0}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="text-6xl mb-4">📦</div>
						<h3 class="text-xl font-semibold text-gray-800 mb-2">No Variation Groups Yet</h3>
						<p class="text-gray-600 mb-4">Select products and create your first group</p>
						<button
							on:click={toggleView}
							class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
						>
							Go to Products View
						</button>
					</div>
				</div>
			{:else}
				<div class="space-y-4">
					{#each variationGroups as group}
						<div class="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
							<div class="p-4 flex items-center justify-between cursor-pointer hover:bg-gray-50 transition-colors"
								on:click={() => toggleGroupExpansion(group.parent.barcode)}
							>
								<div class="flex items-center gap-4 flex-1">
									<!-- Group Image -->
									<img
										src={group.parent.variation_image_override || group.parent.image_url}
										alt={group.parent.variation_group_name_en}
										class="w-16 h-16 object-contain rounded border border-gray-200"
										on:click|stopPropagation={() => previewImage(group.parent.variation_image_override || group.parent.image_url)}
									/>
									
									<!-- Group Info -->
									<div class="flex-1">
										<div class="font-semibold text-gray-800">
											{group.parent.variation_group_name_en}
										</div>
										<div class="text-sm text-gray-600 font-arabic">
											{group.parent.variation_group_name_ar}
										</div>
										<div class="text-xs text-gray-500 mt-1">
											Parent: {group.parent.barcode} • {group.totalCount} variations
										</div>
									</div>
									
									<!-- Expand Icon -->
									<div class="text-gray-400">
										{expandedGroups.has(group.parent.barcode) ? '▼' : '▶'}
									</div>
								</div>
								
							<!-- Actions -->
							<div class="flex gap-2" on:click|stopPropagation>
								<button
									on:click={() => openEditGroupModal(group.parent.barcode, group.parent.variation_group_name_en, group.parent.variation_group_name_ar)}
									class="px-3 py-1 text-sm bg-blue-50 text-blue-600 rounded hover:bg-blue-100 transition-colors"
								>
									Edit Group
								</button>
								<button
									on:click={() => deleteGroup(group.parent.barcode, group.parent.variation_group_name_en)}
									class="px-3 py-1 text-sm bg-red-50 text-red-600 rounded hover:bg-red-100 transition-colors"
								>
									Delete Group
								</button>
							</div>
							</div>
							
							<!-- Expanded Variations -->
							{#if expandedGroups.has(group.parent.barcode)}
								<div class="border-t border-gray-200 bg-gray-50 p-4">
									{#if !loadedGroupVariations.has(group.parent.barcode)}
										<!-- Loading state -->
										<div class="flex items-center justify-center py-6">
											<div class="text-center">
												<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
												<p class="mt-2 text-sm text-gray-600">Loading variations...</p>
											</div>
										</div>
									{:else}
										<!-- Variations loaded -->
										<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
											<!-- Parent Product -->
											<div class="bg-white p-3 rounded border-2 border-blue-200">
												<div class="flex items-center gap-3">
													<img
														src={group.parent.image_url}
														alt={group.parent.product_name_en}
														class="w-12 h-12 object-contain rounded"
													/>
													<div class="flex-1 min-w-0">
														<div class="text-xs font-semibold text-blue-600 mb-1">PARENT</div>
														<div class="text-sm font-medium truncate">{group.parent.product_name_en}</div>
														<div class="text-xs text-gray-500">{group.parent.barcode}</div>
													</div>
												</div>
											</div>
											
											<!-- Variation Products -->
											{#each group.variations as variation}
												<div class="bg-white p-3 rounded border border-gray-200">
													<div class="flex items-center gap-3">
														<img
															src={variation.image_url}
															alt={variation.product_name_en}
															class="w-12 h-12 object-contain rounded"
														/>
														<div class="flex-1 min-w-0">
															<div class="text-sm font-medium truncate">{variation.product_name_en}</div>
															<div class="text-xs text-gray-500">{variation.barcode}</div>
															<div class="text-xs text-gray-400">Order: {variation.variation_order}</div>
														</div>
													</div>
												</div>
											{/each}
										</div>
									{/if}
								</div>
							{/if}
						</div>
					{/each}
				</div>
				
				<!-- Pagination Controls for Groups -->
				<div class="mt-6 flex items-center justify-between px-4 py-3 bg-white rounded-lg border border-gray-200">
					<div class="text-sm text-gray-600">
						Page {groupsPage} • {variationGroups.length} groups shown
					</div>
					<div class="flex gap-2">
						<button
							on:click={prevGroupsPage}
							disabled={groupsPage === 1}
							class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
						>
							← Previous
						</button>
						<button
							on:click={nextGroupsPage}
							disabled={variationGroups.length < groupsItemsPerPage}
							class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
						>
							Next →
						</button>
					</div>
				</div>
			{/if}
		{:else}
			<!-- Products Table View -->
			{#if filteredProducts.length === 0}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="text-6xl mb-4">🔍</div>
						<h3 class="text-xl font-semibold text-gray-800 mb-2">No Products Found</h3>
						<p class="text-gray-600">Try adjusting your search or filters</p>
					</div>
				</div>
			{:else}
				<!-- Quick actions -->
				<div class="mb-4 flex items-center justify-between">
					<div class="text-sm text-gray-600">
						Showing {filteredProducts.length} products
					</div>
					<button
						on:click={selectAll}
						class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded transition-colors"
					>
						Select All (page)
					</button>
				</div>
				
				<!-- Products Table -->
				<div class="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden mb-6">
					<div class="overflow-x-auto">
						<table class="w-full">
							<thead class="bg-gray-50 border-b border-gray-200">
								<tr>
									<th class="px-4 py-3 text-center w-16">#</th>
									<th class="px-4 py-3 text-left w-12">
										<input
											type="checkbox"
											on:change={selectAll}
											class="w-4 h-4 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
										/>
									</th>
									<th class="px-4 py-3 text-left w-20">Image</th>
									<th class="px-4 py-3 text-left">Product Name (EN)</th>
									<th class="px-4 py-3 text-left">Product Name (AR)</th>
									<th class="px-4 py-3 text-left w-32">Barcode</th>
									<th class="px-4 py-3 text-left">Category</th>
									<th class="px-4 py-3 text-left w-32">Status</th>
									<th class="px-4 py-3 text-left">Group</th>
									<th class="px-4 py-3 text-center w-24">Image URL</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-200">
								{#each filteredProducts as product, index (product.barcode)}
									<tr
										class="hover:bg-gray-50 cursor-pointer transition-colors
											{selectedProducts.has(product.barcode) ? 'bg-blue-50' : ''}"
										on:click={() => toggleProductSelection(product.barcode)}
									>
										<td class="px-4 py-3 text-center text-sm font-medium text-gray-700">
											{index + 1}
										</td>
										<td class="px-4 py-3">
											<input
												type="checkbox"
												checked={selectedProducts.has(product.barcode)}
												on:click|stopPropagation
												on:change={() => toggleProductSelection(product.barcode)}
												class="w-4 h-4 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
											/>
										</td>
										<td class="px-4 py-3">
											{#if product.image_url}
												<img
													bind:this={imageRefs[product.barcode]}
													src={product.image_url}
													alt={product.product_name_en}
													data-barcode={product.barcode}
													class="w-16 h-16 object-contain cursor-zoom-in"
													loading="lazy"
													decoding="async"
													on:load={handleImageLoad}
													on:error={handleImageError}
													on:click|stopPropagation={() => previewImage(product.image_url)}
												/>
											{:else}
												<div class="w-16 h-16 bg-gray-100 rounded flex items-center justify-center text-gray-400 text-xs">
													No Image
												</div>
											{/if}
										</td>
										<td class="px-4 py-3 text-sm text-gray-800">
											{product.product_name_en}
										</td>
										<td class="px-4 py-3 text-sm text-gray-600 font-arabic">
											{product.product_name_ar}
										</td>
										<td class="px-4 py-3 text-sm text-gray-500 font-mono">
											{product.barcode}
										</td>
										<td class="px-4 py-3 text-sm text-gray-600">
											{#if product.product_categories?.name_en}
												<span class="px-2 py-1 text-xs bg-purple-100 text-purple-700 rounded">
													{product.product_categories.name_en}
												</span>
											{:else}
												<span class="text-gray-400">—</span>
											{/if}
										</td>
										<td class="px-4 py-3">
											{#if product.is_variation}
												<span class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded font-medium">
													🔗 Grouped
												</span>
											{:else}
												<span class="px-2 py-1 text-xs bg-gray-100 text-gray-600 rounded">
													Ungrouped
												</span>
											{/if}
										</td>
										<td class="px-4 py-3 text-sm text-gray-600">
											{#if product.is_variation && product.variation_group_name_en}
												<div class="text-xs text-green-700 font-medium truncate max-w-xs">
													{product.variation_group_name_en}
												</div>
											{:else}
												<span class="text-gray-400">—</span>
											{/if}
										</td>
										<td class="px-4 py-3 text-center" on:click|stopPropagation>
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
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		{/if}
	</div>
</div>

<!-- Group Creation Modal -->
{#if showGroupModal}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
			<div class="p-6 border-b border-gray-200">
				<h2 class="text-2xl font-bold text-gray-800">{isEditMode ? 'Update Variation Group' : 'Create Variation Group'}</h2>
				<p class="text-sm text-gray-600 mt-1">
					{#if isEditMode}
						Updating: {groupNameEn}
					{:else}
						Grouping {selectedProducts.size} products together
					{/if}
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
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
					>
						{#each Array.from(selectedProducts) as barcode}
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
								<div class="text-xs text-purple-600">Automatically generate English & Arabic names from product names</div>
							</div>
						</div>
						<button
							type="button"
							on:click={generateAIGroupName}
							disabled={isGeneratingAIName || selectedProducts.size === 0}
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
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
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
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 font-arabic"
					/>
				</div>
				
				<!-- Image Override -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Group Display Image
					</label>
					<div class="space-y-2">
						<label class="flex items-center gap-2">
							<input
								type="radio"
								bind:group={imageOverrideType}
								value="parent"
								class="w-4 h-4 text-blue-600"
							/>
							<span class="text-sm">Use parent product's image (default)</span>
						</label>
						
						<label class="flex items-center gap-2">
							<input
								type="radio"
								bind:group={imageOverrideType}
								value="variation"
								class="w-4 h-4 text-blue-600"
							/>
							<span class="text-sm">Use specific variation's image</span>
						</label>
						
						{#if imageOverrideType === 'variation'}
							<select
								bind:value={selectedImageBarcode}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
							>
								<option value="">Select a variation...</option>
								{#each Array.from(selectedProducts) as barcode}
									{@const product = products.find(p => p.barcode === barcode)}
									{#if product && product.image_url}
										<option value={barcode}>
											{product.product_name_en}
										</option>
									{/if}
								{/each}
							</select>
						{/if}
					</div>
				</div>
				
				<!-- Preview -->
				<div class="bg-gray-50 rounded-lg p-4">
					<div class="text-sm font-medium text-gray-700 mb-2">Preview:</div>
					<div class="text-sm text-gray-600">
						<div>• <strong>Group:</strong> {groupNameEn || '(not set)'} / {groupNameAr || '(غير محدد)'}</div>
						<div>• <strong>Parent:</strong> {groupParentBarcode || '(not selected)'}</div>
						<div>• <strong>Variations:</strong> {selectedProducts.size - 1} products</div>
					</div>
				</div>
			</div>
			
			<div class="p-6 border-t border-gray-200 flex items-center justify-end gap-3">
				<button
					on:click={closeGroupModal}
					disabled={isCreatingGroup}
					class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50"
				>
					Cancel
				</button>
				<button
					on:click={createGroup}
					disabled={isCreatingGroup || !groupParentBarcode || !groupNameEn || !groupNameAr}
					class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
				>
					{#if isCreatingGroup}
						<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
						{isEditMode ? 'Updating...' : 'Creating...'}
					{:else}
						{isEditMode ? 'Update Group' : 'Create Group'}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Image Preview Modal -->
{#if showImagePreview}
	<div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4"
		on:click={() => showImagePreview = false}
	>
		<div class="max-w-4xl max-h-[90vh]" on:click|stopPropagation>
			<img
				src={previewImageUrl}
				alt="Preview"
				class="max-w-full max-h-[90vh] object-contain rounded-lg shadow-2xl"
			/>
		</div>
	</div>
{/if}

<style>
	.line-clamp-1 {
		display: -webkit-box;
		-webkit-line-clamp: 1;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
	
	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
	
	.font-arabic {
		font-family: 'Noto Sans Arabic', sans-serif;
	}
</style>
