<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { t } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import {
		getAllCampaigns,
		getProductsByCampaign,
		createProduct,
		updateProduct,
		toggleProductStatus,
		uploadProductImage
	} from '$lib/services/couponService';
	import type { CouponCampaign, CouponProduct } from '$lib/types/coupon';

	// Props
	let { campaignId = null, onClose = null }: { campaignId?: string | null; onClose?: (() => void) | null } = $props();

	// State
	let loading = $state(false);
	let loadingProgress = $state(0);
	let totalCount = $state(0);
	let saving = $state(false);
	let error = $state<string | null>(null);
	let campaigns: CouponCampaign[] = $state([]);
	let selectedCampaignId = $state<string | null>(campaignId);
	let products: CouponProduct[] = $state([]);
	let flyerProducts: any[] = $state([]);
	let selectedProducts: Map<string, any> = $state(new Map());
	let searchQuery = $state('');
	let filteredFlyerProducts = $state<any[]>([]);
	let displayedProducts = $state<any[]>([]);
	let searchTimeout: any;
	let couponProductMapping: Map<string, string> = $state(new Map()); // Maps coupon_product.id to flyer_product.id

	// Debounce utility
	function debounce(func: Function, wait: number) {
		return function executedFunction(...args: any[]) {
			const later = () => {
				clearTimeout(searchTimeout);
				func(...args);
			};
			clearTimeout(searchTimeout);
			searchTimeout = setTimeout(later, wait);
		};
	}

	// Optimized search and filter function
	function handleSearch() {
		let filtered: any[];
		if (searchQuery.trim() === '') {
			filtered = flyerProducts;
		} else {
			const query = searchQuery.toLowerCase();
			// Quick checks on main fields (short-circuit evaluation)
			filtered = flyerProducts.filter(p => {
				if (p.product_name_en?.toLowerCase().includes(query)) return true;
				if (p.product_name_ar?.toLowerCase().includes(query)) return true;
				if (p.barcode?.toLowerCase().includes(query)) return true;
				return false;
			});
		}
		
		// Sort: selected products first, then unselected
		const selected = filtered.filter(p => selectedProducts.has(p.id) && !selectedProducts.get(p.id)?.markedForDeletion);
		const unselected = filtered.filter(p => !selectedProducts.has(p.id) || selectedProducts.get(p.id)?.markedForDeletion);
		
		filteredFlyerProducts = [...selected, ...unselected];
		displayedProducts = filteredFlyerProducts.slice(0, 100); // Show only first 100
		
		console.log(`Search results: ${filteredFlyerProducts.length} products found, displaying ${displayedProducts.length}`);
	}

	// Debounced search
	const debouncedSearch = debounce(handleSearch, 300);

	// Watch search query changes
	$effect(() => {
		if (searchQuery !== undefined) {
			debouncedSearch();
		}
	});

	// Load campaigns
	async function loadCampaigns() {
		loading = true;
		try {
			campaigns = await getAllCampaigns();
			if (campaigns.length > 0 && !selectedCampaignId) {
				selectedCampaignId = campaigns[0].id;
				await loadProducts();
				await loadFlyerProducts();
			}
		} catch (error: any) {
			notifications.add({
				message: t('coupon.errorLoadingCampaigns'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Load flyer products from database with pagination
	async function loadFlyerProducts() {
		loading = true;
		loadingProgress = 0;
		error = null;
		
		try {
			// Get total count first
			const { count, error: countError } = await supabase
				.from('products')
				.select('*', { count: 'exact', head: true });
			
			if (countError) throw countError;
			
			totalCount = count || 0;
			loadingProgress = 10;
			console.log(`Total flyer products: ${totalCount}`);

			// Load in chunks for better performance
			let allProducts: any[] = [];
			const pageSize = 500;
			let currentPage = 0;
			let hasMore = true;

			while (hasMore) {
				const startRange = currentPage * pageSize;
				const endRange = startRange + pageSize - 1;

				const { data, error: fetchError } = await supabase
					.from('products')
					.select('id, product_name_en, product_name_ar, barcode, image_url')
					.order('product_name_en', { ascending: true })
					.range(startRange, endRange);

				if (fetchError) throw fetchError;

				if (data && data.length > 0) {
					allProducts = [...allProducts, ...data];
					currentPage++;
					hasMore = data.length === pageSize;
					
					// Update progress
					loadingProgress = Math.min(90, 10 + (allProducts.length / totalCount) * 80);
					
					// Allow UI to update
					await tick();
					
					console.log(`Loaded ${allProducts.length}/${totalCount} products (${Math.round(loadingProgress)}%)`);
				} else {
					hasMore = false;
				}
			}

			flyerProducts = allProducts;
			filteredFlyerProducts = flyerProducts;
			displayedProducts = filteredFlyerProducts.slice(0, 100);
			loadingProgress = 100;
			console.log(`Flyer products loaded successfully: ${flyerProducts.length} total`);

		} catch (err: any) {
			console.error('Error loading flyer products:', err);
			error = err.message || 'Failed to load products';
			notifications.add({
				message: 'Error loading products from flyer',
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Load products for selected campaign
	async function loadProducts() {
		if (!selectedCampaignId) return;

		loading = true;
		try {
			products = await getProductsByCampaign(selectedCampaignId);
			
			// Pre-populate selectedProducts with existing coupon products
			// Use flyer_product_id if available, otherwise fall back to barcode matching
			selectedProducts.clear();
			
			for (const product of products) {
				let flyerProductId = product.flyer_product_id;
				
				// If no flyer_product_id stored, try to find by barcode
				if (!flyerProductId) {
					const flyerProduct = flyerProducts.find(fp => fp.barcode === product.special_barcode);
					flyerProductId = flyerProduct?.id;
				}
				
				// Use flyer_product_id as the key, or coupon product id if no flyer reference
				const key = flyerProductId || product.id;
				
				selectedProducts.set(key, {
					id: product.id, // coupon_products id for updates
					flyerProductId: flyerProductId,
					product_name_en: product.product_name_en,
					product_name_ar: product.product_name_ar,
					product_image_url: product.product_image_url,
					barcode: product.special_barcode,
					original_price: product.original_price,
					offer_price: product.offer_price,
					stock_limit: product.stock_limit,
					stock_remaining: product.stock_remaining,
					is_active: product.is_active
				});
			}
			selectedProducts = new Map(selectedProducts); // Trigger reactivity
		} catch (error: any) {
			notifications.add({
				message: t('coupon.errorLoadingProducts'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Handle campaign selection
	async function handleCampaignChange() {
		await loadProducts();
		await loadFlyerProducts();
	}

	// Toggle product selection
	function toggleProductSelection(flyerProduct: any) {
		const key = flyerProduct.id;
		
		if (selectedProducts.has(key)) {
			// If unchecking, check if this product exists in coupon_products
			const productData = selectedProducts.get(key);
			if (productData?.id) {
				// Mark for deletion
				productData.markedForDeletion = true;
				selectedProducts.set(key, productData);
			} else {
				// Just remove from selection if not saved yet
				selectedProducts.delete(key);
			}
		} else {
			// Check if this was marked for deletion
			const existingData = selectedProducts.get(key);
			if (existingData?.markedForDeletion) {
				// Unmark deletion
				existingData.markedForDeletion = false;
				selectedProducts.set(key, existingData);
			} else {
				// Add new selection
				selectedProducts.set(key, {
					flyerProductId: flyerProduct.id,
					product_name_en: flyerProduct.product_name_en,
					product_name_ar: flyerProduct.product_name_ar,
					product_image_url: flyerProduct.image_url,
					barcode: flyerProduct.barcode,
					original_price: 0,
					offer_price: 0,
					stock_limit: 0,
					is_active: true
				});
			}
		}
		selectedProducts = new Map(selectedProducts); // Trigger reactivity
	}

	// Update selected product field
	function updateProductField(flyerProductId: string, field: string, value: any) {
		const product = selectedProducts.get(flyerProductId);
		if (product) {
			product[field] = value;
			selectedProducts.set(flyerProductId, product);
			selectedProducts = new Map(selectedProducts); // Trigger reactivity
		}
	}

	// Load more items (virtual scrolling)
	function loadMoreItems() {
		const currentLength = displayedProducts.length;
		const nextBatch = filteredFlyerProducts.slice(currentLength, currentLength + 100);
		if (nextBatch.length > 0) {
			displayedProducts = [...displayedProducts, ...nextBatch];
			console.log(`Loaded more items: ${displayedProducts.length}/${filteredFlyerProducts.length}`);
		}
	}

	// Handle scroll event for lazy loading
	function handleScroll(event: Event) {
		const element = event.target as HTMLElement;
		const scrolledToBottom = element.scrollHeight - element.scrollTop <= element.clientHeight + 200;
		
		if (scrolledToBottom && displayedProducts.length < filteredFlyerProducts.length && !loading) {
			loadMoreItems();
		}
	}

	// Clear cache and reload products from database
	async function clearCacheAndReload() {
		try {
			// Clear local data
			flyerProducts = [];
			selectedProducts.clear();
			selectedProducts = new Map(selectedProducts);
			filteredFlyerProducts = [];
			displayedProducts = [];
			searchQuery = '';
			
			// Reload flyer products
			loading = true;
			await loadFlyerProducts();
			
			// Show success message
			notifications.add({
				message: 'Cache cleared and data reloaded from database successfully!',
				type: 'success'
			});
		} catch (error: any) {
			notifications.add({
				message: 'Error clearing cache. Please try again.',
				type: 'error'
			});
			console.error('Error clearing cache:', error);
		}
	}

	// Save all selected products
	async function saveProducts() {
		if (!selectedCampaignId) {
			notifications.add({
				message: t('coupon.selectCampaignFirst'),
				type: 'error'
			});
			return;
		}

		if (selectedProducts.size === 0) {
			notifications.add({
				message: 'Please select at least one product',
				type: 'error'
			});
			return;
		}

		// Separate products to create, update, and delete
		const toCreate: any[] = [];
		const toUpdate: any[] = [];
		const toDelete: string[] = [];

		selectedProducts.forEach((product, key) => {
			if (product.markedForDeletion && product.id) {
				toDelete.push(product.id);
			} else if (!product.markedForDeletion) {
				// Validate
				if (!product.barcode || product.barcode.trim() === '') {
					throw new Error(`Barcode required for ${product.product_name_en}`);
				}
				if (product.original_price <= 0) {
					throw new Error(`Original price required for ${product.product_name_en}`);
				}
				if (product.offer_price < 0 || product.offer_price > product.original_price) {
					throw new Error(`Invalid offer price for ${product.product_name_en}`);
				}
				if (product.stock_limit < 1) {
					throw new Error(`Stock limit required for ${product.product_name_en}`);
				}

				const payload = {
					campaign_id: selectedCampaignId,
					product_name_en: product.product_name_en,
					product_name_ar: product.product_name_ar,
					product_image_url: product.product_image_url || null,
					original_price: product.original_price,
					offer_price: product.offer_price,
					special_barcode: product.barcode,
					stock_limit: product.stock_limit,
					stock_remaining: product.stock_remaining || product.stock_limit,
					is_active: product.is_active,
					flyer_product_id: product.flyerProductId || null,
					created_by: $currentUser?.id || null
				};

				if (product.id) {
					toUpdate.push({ id: product.id, ...payload });
				} else {
					toCreate.push(payload);
				}
			}
		});

		saving = true;
		try {
			let successCount = 0;
			let failedDeletes: string[] = [];

			// Check products for claims before attempting deletion
			for (const id of toDelete) {
				try {
					// First, check if the product has any claims
					const { data: claims, error: claimError } = await supabase
						.from('coupon_claims')
						.select('id')
						.eq('product_id', id)
						.limit(1);
					
					if (claimError) {
						console.error('Error checking claims:', claimError);
						continue;
					}

					// If product has claims, mark as inactive instead of deleting
					if (claims && claims.length > 0) {
						const { error: updateError } = await supabase
							.from('coupon_products')
							.update({ is_active: false })
							.eq('id', id);
						
						if (updateError) {
							console.error(`Error marking product inactive:`, updateError);
						} else {
							failedDeletes.push(id);
							successCount++;
						}
					} else {
						// No claims, safe to delete
						const { error } = await supabase
							.from('coupon_products')
							.delete()
							.eq('id', id);
						
						if (error) {
							console.error(`Error deleting product:`, error);
							notifications.add({
								message: `Failed to delete product: ${error.message}`,
								type: 'error'
							});
						} else {
							successCount++;
						}
					}
				} catch (error: any) {
					console.error(`Unexpected error processing product deletion:`, error);
				}
			}

			// Create new products
			for (const payload of toCreate) {
				try {
					await createProduct(payload);
					successCount++;
				} catch (error: any) {
					console.error(`Error creating product ${payload.product_name_en}:`, error);
					
					// If it's a duplicate key error, show a specific message
					if (error.code === '23505') {
						notifications.add({
							message: `Product "${payload.product_name_en}" (${payload.special_barcode}) already exists in this campaign`,
							type: 'warning'
						});
					} else {
						throw error;
					}
				}
			}

			// Update existing products
			for (const item of toUpdate) {
				try {
					const { id, ...payload } = item;
					await updateProduct(id, payload);
					successCount++;
				} catch (error: any) {
					console.error(`Error updating product:`, error);
					throw error;
				}
			}

			notifications.add({
				message: `Successfully saved ${successCount} product(s)`,
				type: 'success'
			});

			// Show additional message if products were marked inactive instead of deleted
			if (failedDeletes.length > 0) {
				notifications.add({
					message: `${failedDeletes.length} product(s) with claims were marked as inactive instead of deleted`,
					type: 'info'
				});
			}

			// Reload products to refresh the view
			await loadProducts();
		} catch (error: any) {
			console.error('Error saving products:', error);
			
			// Don't show generic error if we've already handled specific errors (like duplicates)
			if (error.code !== '23505') {
				notifications.add({
					message: error.message || 'Error saving products',
					type: 'error'
				});
			}
		} finally {
			saving = false;
		}
	}

	onMount(() => {
		loadCampaigns();
	});
</script>

<div class="flex flex-col h-full bg-gray-50">
	<!-- Header -->
	<div class="bg-white border-b border-gray-200 px-6 py-4">
		<div class="flex items-center justify-between">
			<div>
				<h2 class="text-2xl font-bold text-gray-900">{t('coupon.manageProducts')}</h2>
				<p class="text-sm text-gray-600 mt-1">Select products from flyer and configure for campaign</p>
			</div>
			<button
				onclick={saveProducts}
				disabled={saving || !selectedCampaignId || selectedProducts.size === 0}
				class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 flex items-center gap-2"
			>
				<span class="text-xl">💾</span>
				{saving ? 'Saving...' : `Save (${selectedProducts.size})`}
			</button>
		</div>

		<!-- Campaign Selector -->
		<div class="mt-4">
			<label class="block text-sm font-medium text-gray-700 mb-2">
				{t('coupon.selectCampaign')}
			</label>
			<select
				bind:value={selectedCampaignId}
				onchange={handleCampaignChange}
				class="w-full md:w-96 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
			>
				<option value={null}>{t('coupon.selectCampaign')}</option>
				{#each campaigns as campaign}
					<option value={campaign.id}>
						{campaign.name_en || campaign.campaign_name || 'Unnamed'} - {campaign.campaign_code}
					</option>
				{/each}
			</select>
		</div>

		<!-- Search Bar -->
		{#if selectedCampaignId}
			<div class="mt-4 flex gap-3 items-end">
				<div class="flex-1">
					<input
						type="text"
						bind:value={searchQuery}
						placeholder="Search products by name or barcode..."
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
				<button
					onclick={clearCacheAndReload}
					class="px-4 py-2 bg-red-500 hover:bg-red-600 text-white font-semibold rounded-lg transition-colors flex items-center gap-2"
					title="Clear cache and reload all data from database"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
					</svg>
					Clear Cache & Reload
				</button>
			</div>
		{/if}
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-auto p-6" onscroll={handleScroll}>
		{#if !selectedCampaignId}
			<div class="text-center py-12">
				<div class="text-6xl mb-4">📦</div>
				<h3 class="text-xl font-semibold text-gray-900 mb-2">{t('coupon.selectCampaignFirst')}</h3>
				<p class="text-gray-600">{t('coupon.selectCampaignToManageProducts')}</p>
			</div>
		{:else if loading}
			<div class="space-y-4">
				<!-- Progress bar -->
				<div class="w-full bg-gray-200 rounded-full h-2">
					<div 
						class="bg-blue-600 h-2 rounded-full transition-all duration-300"
						style="width: {loadingProgress}%"
					></div>
				</div>
				
				<!-- Loading message -->
				<div class="flex items-center justify-center py-8">
					<svg class="animate-spin w-8 h-8 text-blue-600 mr-3" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<span class="text-gray-700 font-medium">
						Loading products... {loadingProgress}%
					</span>
				</div>
				
				<!-- Skeleton items -->
				{#each Array(5) as _, i}
					<div class="animate-pulse bg-gray-200 h-16 rounded-lg"></div>
				{/each}
			</div>
		{:else if error}
			<div class="bg-red-50 border border-red-200 rounded-lg p-6">
				<div class="flex items-center gap-3">
					<svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
					<div>
						<h3 class="font-semibold text-red-900">Error Loading Data</h3>
						<p class="text-red-700 text-sm">{error}</p>
					</div>
				</div>
				<button 
					onclick={loadFlyerProducts}
					class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
				>
					Retry
				</button>
			</div>
		{:else if filteredFlyerProducts.length === 0}
			<div class="text-center py-12">
				<div class="text-6xl mb-4">🔍</div>
				<h3 class="text-xl font-semibold text-gray-900 mb-2">No products found</h3>
				<p class="text-gray-600">Try adjusting your search criteria</p>
			</div>
		{:else}
			<!-- Products Table -->
			<div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
				<div class="overflow-x-auto">
					<table class="w-full">
						<thead class="bg-gray-50 border-b border-gray-200">
							<tr>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-12">
									Select
								</th>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-20">
									Image
								</th>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-64">
									Product Name
								</th>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-40">
									Barcode
								</th>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-32">
									Original Price
								</th>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-32">
									Offer Price
								</th>
								<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-28">
									Stock Limit
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each displayedProducts as product (product.id)}
								{@const isSelected = selectedProducts.has(product.id)}
								{@const selectedData = selectedProducts.get(product.id) || {}}
								{@const isMarkedForDeletion = selectedData.markedForDeletion}
								<tr class={isMarkedForDeletion ? 'bg-red-50' : isSelected ? 'bg-blue-50' : 'hover:bg-gray-50'}>
									<!-- Checkbox -->
									<td class="px-4 py-3">
										<input
											type="checkbox"
											checked={isSelected && !isMarkedForDeletion}
											onchange={() => toggleProductSelection(product)}
											class="w-5 h-5 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
										/>
									</td>

									<!-- Image -->
									<td class="px-4 py-3">
										{#if product.image_url}
											<img 
												src={product.image_url} 
												alt={product.product_name_en}
												loading="lazy"
												decoding="async"
												class="w-12 h-12 object-cover rounded border"
											/>
										{:else}
											<div class="w-12 h-12 bg-gray-100 rounded border flex items-center justify-center text-xl">
												📦
											</div>
										{/if}
									</td>

									<!-- Product Name -->
									<td class="px-4 py-3">
										<div class="text-sm font-medium text-gray-900">{product.product_name_en}</div>
										<div class="text-sm text-gray-500" dir="rtl">{product.product_name_ar}</div>
									</td>

									<!-- Barcode -->
									<td class="px-4 py-3">
										{#if isSelected && !isMarkedForDeletion}
											<input
												type="text"
												value={selectedData.barcode || product.barcode || ''}
												oninput={(e) => updateProductField(product.id, 'barcode', e.currentTarget.value)}
												class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"
												placeholder="Enter barcode"
											/>
										{:else}
											<code class="text-xs text-gray-600">{selectedData.barcode || product.barcode || '-'}</code>
										{/if}
									</td>

									<!-- Original Price -->
									<td class="px-4 py-3">
										{#if isSelected && !isMarkedForDeletion}
											<input
												type="number"
												value={selectedData.original_price || 0}
												oninput={(e) => updateProductField(product.id, 'original_price', parseFloat(e.currentTarget.value) || 0)}
												min="0"
												step="0.01"
												class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"
												placeholder="0.00"
											/>
										{:else if selectedData.original_price}
											<span class="text-sm text-gray-600">{selectedData.original_price.toFixed(2)}</span>
										{:else}
											<span class="text-sm text-gray-400">-</span>
										{/if}
									</td>

									<!-- Offer Price -->
									<td class="px-4 py-3">
										{#if isSelected && !isMarkedForDeletion}
											<input
												type="number"
												value={selectedData.offer_price || 0}
												oninput={(e) => updateProductField(product.id, 'offer_price', parseFloat(e.currentTarget.value) || 0)}
												min="0"
												step="0.01"
												class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"
												placeholder="0.00"
											/>
										{:else if selectedData.offer_price !== undefined}
											<span class="text-sm text-gray-600">{selectedData.offer_price.toFixed(2)}</span>
										{:else}
											<span class="text-sm text-gray-400">-</span>
										{/if}
									</td>

									<!-- Stock Limit -->
									<td class="px-4 py-3">
										{#if isSelected && !isMarkedForDeletion}
											<input
												type="number"
												value={selectedData.stock_limit || 0}
												oninput={(e) => updateProductField(product.id, 'stock_limit', parseInt(e.currentTarget.value) || 0)}
												min="1"
												class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"
												placeholder="0"
											/>
										{:else if selectedData.stock_limit}
											<span class="text-sm text-gray-600">{selectedData.stock_limit}</span>
										{:else}
											<span class="text-sm text-gray-400">-</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>

			<!-- Lazy Loading Indicator -->
			{#if displayedProducts.length < filteredFlyerProducts.length}
				<div class="text-center p-4 text-gray-500 text-sm">
					Showing {displayedProducts.length} of {filteredFlyerProducts.length} products
					<span class="block mt-1 text-xs text-gray-400">Scroll down to load more</span>
				</div>
			{/if}

			<!-- Summary -->
			{#if selectedProducts.size > 0}
				<div class="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
					<div class="flex items-center justify-between">
						<div class="text-sm text-blue-900">
							<strong>{selectedProducts.size}</strong> product(s) selected for campaign
						</div>
						<button
							onclick={() => {
								selectedProducts.clear();
								selectedProducts = new Map(selectedProducts);
							}}
							class="text-sm text-blue-700 hover:text-blue-900 underline"
						>
							Clear Selection
						</button>
					</div>
				</div>
			{/if}
		{/if}
	</div>
</div>
