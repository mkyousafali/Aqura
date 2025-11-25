<script lang="ts">
	import { supabaseAdmin as supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { t } from '$lib/i18n';
	
	// State
	let products: any[] = [];
	let filteredProducts: any[] = [];
	let searchQuery: string = '';
	let filterStatus: 'all' | 'grouped' | 'ungrouped' = 'all';
	let sortBy: 'name' | 'price' | 'date' = 'name';
	let isLoading: boolean = false;
	let selectedProducts: Set<string> = new Set();
	let currentPage: number = 1;
	let itemsPerPage: number = 50;
	
	// Group creation modal
	let showGroupModal: boolean = false;
	let groupParentBarcode: string = '';
	let groupNameEn: string = '';
	let groupNameAr: string = '';
	let groupImageOverride: string = '';
	let imageOverrideType: 'parent' | 'variation' | 'custom' = 'parent';
	let selectedImageBarcode: string = '';
	let isCreatingGroup: boolean = false;
	
	// Group management
	let variationGroups: any[] = [];
	let expandedGroups: Set<string> = new Set();
	let showGroupsView: boolean = false;
	let isLoadingGroups: boolean = false;
	
	// Image preview
	let showImagePreview: boolean = false;
	let previewImageUrl: string = '';
	
	// Stats
	let totalProducts: number = 0;
	let groupedProducts: number = 0;
	let totalGroups: number = 0;
	
	onMount(async () => {
		await loadProducts();
		await loadStats();
	});
	
	async function loadProducts() {
		isLoading = true;
		try {
			const { data, error } = await supabase
				.from('flyer_products')
				.select('*')
				.order('product_name_en', { ascending: true });
			
			if (error) throw error;
			
			products = data || [];
			applyFilters();
		} catch (error) {
			console.error('Error loading products:', error);
			notifications.add({
				message: 'Failed to load products',
				type: 'error',
				duration: 3000
			});
		} finally {
			isLoading = false;
		}
	}
	
	async function loadStats() {
		try {
			const { data: allProducts, error } = await supabase
				.from('flyer_products')
				.select('id, is_variation, parent_product_barcode');
			
			if (error) throw error;
			
			totalProducts = allProducts?.length || 0;
			groupedProducts = allProducts?.filter(p => p.is_variation).length || 0;
			
			// Count unique groups (products with is_variation=true and parent_product_barcode=null)
			const parents = allProducts?.filter(p => p.is_variation && !p.parent_product_barcode) || [];
			totalGroups = parents.length;
		} catch (error) {
			console.error('Error loading stats:', error);
		}
	}
	
	async function loadVariationGroups() {
		isLoadingGroups = true;
		try {
			// Get all parent products (is_variation=true and parent_product_barcode is null)
			const { data, error } = await supabase
				.from('flyer_products')
				.select('*')
				.eq('is_variation', true)
				.is('parent_product_barcode', null)
				.order('variation_group_name_en', { ascending: true });
			
			if (error) throw error;
			
			// For each parent, get its variations
			const groupsWithVariations = await Promise.all(
				(data || []).map(async (parent) => {
					const { data: variations, error: varError } = await supabase
						.from('flyer_products')
						.select('*')
						.eq('parent_product_barcode', parent.barcode)
						.order('variation_order', { ascending: true });
					
					return {
						parent,
						variations: variations || [],
						totalCount: (variations?.length || 0) + 1 // +1 for parent
					};
				})
			);
			
			variationGroups = groupsWithVariations;
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
	
	function applyFilters() {
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
		
		// Status filter
		if (filterStatus === 'grouped') {
			filtered = filtered.filter(p => p.is_variation);
		} else if (filterStatus === 'ungrouped') {
			filtered = filtered.filter(p => !p.is_variation);
		}
		
		// Sort
		filtered.sort((a, b) => {
			if (sortBy === 'name') {
				return (a.product_name_en || '').localeCompare(b.product_name_en || '');
			} else if (sortBy === 'date') {
				return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
			}
			return 0;
		});
		
		filteredProducts = filtered;
	}
	
	$: {
		searchQuery;
		filterStatus;
		sortBy;
		applyFilters();
	}
	
	$: paginatedProducts = filteredProducts.slice(
		(currentPage - 1) * itemsPerPage,
		currentPage * itemsPerPage
	);
	
	$: totalPages = Math.ceil(filteredProducts.length / itemsPerPage);
	
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
		
		showGroupModal = true;
		// Pre-select first product as parent
		const firstBarcode = Array.from(selectedProducts)[0];
		groupParentBarcode = firstBarcode;
	}
	
	function closeGroupModal() {
		showGroupModal = false;
		groupParentBarcode = '';
		groupNameEn = '';
		groupNameAr = '';
		groupImageOverride = '';
		imageOverrideType = 'parent';
		selectedImageBarcode = '';
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
				
				// Reload and reset
				await loadProducts();
				await loadStats();
				deselectAll();
				closeGroupModal();
			} else {
				throw new Error(data?.[0]?.message || 'Failed to create group');
			}
		} catch (error) {
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
	
	async function deleteGroup(parentBarcode: string, groupName: string) {
		if (!confirm(`Are you sure you want to ungroup "${groupName}"? All products will become standalone.`)) {
			return;
		}
		
		try {
			// Get all products in the group
			const { data: groupProducts, error: fetchError } = await supabase
				.from('flyer_products')
				.select('barcode')
				.or(`barcode.eq.${parentBarcode},parent_product_barcode.eq.${parentBarcode}`);
			
			if (fetchError) throw fetchError;
			
			// Update all products to be standalone
			const barcodes = groupProducts?.map(p => p.barcode) || [];
			
			const { error: updateError } = await supabase
				.from('flyer_products')
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
			
			await loadVariationGroups();
			await loadStats();
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
		}
		expandedGroups = expandedGroups;
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
				
				<select
					bind:value={sortBy}
					class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
				>
					<option value="name">Sort by Name</option>
					<option value="date">Sort by Date</option>
				</select>
				
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
				<span class="text-sm font-medium text-blue-800">
					{selectedProducts.size} product{selectedProducts.size !== 1 ? 's' : ''} selected
				</span>
				<div class="flex gap-2">
					<button
						on:click={deselectAll}
						class="px-3 py-1 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50 transition-colors"
					>
						Deselect All
					</button>
					<button
						on:click={openGroupModal}
						disabled={selectedProducts.size < 2}
						class="px-4 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
					>
						Create Group ({selectedProducts.size})
					</button>
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
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{/if}
		{:else}
			<!-- Products Grid View -->
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
						Showing {(currentPage - 1) * itemsPerPage + 1} - {Math.min(currentPage * itemsPerPage, filteredProducts.length)} of {filteredProducts.length} products
					</div>
					<button
						on:click={selectAll}
						class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded transition-colors"
					>
						Select All (page)
					</button>
				</div>
				
				<!-- Products Grid -->
				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 mb-6">
					{#each paginatedProducts as product}
						<div
							class="bg-white rounded-lg border-2 transition-all cursor-pointer hover:shadow-md
								{selectedProducts.has(product.barcode) ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300'}"
							on:click={() => toggleProductSelection(product.barcode)}
						>
							<div class="p-4">
								<!-- Selection checkbox -->
								<div class="flex items-start justify-between mb-3">
									<input
										type="checkbox"
										checked={selectedProducts.has(product.barcode)}
										on:click|stopPropagation
										on:change={() => toggleProductSelection(product.barcode)}
										class="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
									/>
									{#if product.is_variation}
										<span class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded font-medium">
											🔗 Grouped
										</span>
									{/if}
								</div>
								
								<!-- Product Image -->
								<div class="mb-3 flex items-center justify-center h-32">
									{#if product.image_url}
										<img
											src={product.image_url}
											alt={product.product_name_en}
											class="max-w-full max-h-full object-contain cursor-zoom-in"
											on:click|stopPropagation={() => previewImage(product.image_url)}
										/>
									{:else}
										<div class="w-full h-full bg-gray-100 rounded flex items-center justify-center text-gray-400">
											No Image
										</div>
									{/if}
								</div>
								
								<!-- Product Info -->
								<div class="space-y-2">
									<div class="font-medium text-sm text-gray-800 line-clamp-2">
										{product.product_name_en}
									</div>
									<div class="text-xs text-gray-600 font-arabic line-clamp-1">
										{product.product_name_ar}
									</div>
									<div class="text-xs text-gray-500 font-mono">
										{product.barcode}
									</div>
									{#if product.is_variation && product.variation_group_name_en}
										<div class="text-xs text-green-600 bg-green-50 rounded px-2 py-1 truncate">
											Group: {product.variation_group_name_en}
										</div>
									{/if}
								</div>
							</div>
						</div>
					{/each}
				</div>
				
				<!-- Pagination -->
				{#if totalPages > 1}
					<div class="flex items-center justify-center gap-2">
						<button
							on:click={() => currentPage = Math.max(1, currentPage - 1)}
							disabled={currentPage === 1}
							class="px-4 py-2 bg-white border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Previous
						</button>
						
						<div class="flex gap-1">
							{#each Array(Math.min(7, totalPages)) as _, i}
								{@const pageNum = i + Math.max(1, currentPage - 3)}
								{#if pageNum <= totalPages}
									<button
										on:click={() => currentPage = pageNum}
										class="px-3 py-2 rounded transition-colors
											{currentPage === pageNum ? 'bg-blue-600 text-white' : 'bg-white border border-gray-300 hover:bg-gray-50'}"
									>
										{pageNum}
									</button>
								{/if}
							{/each}
						</div>
						
						<button
							on:click={() => currentPage = Math.min(totalPages, currentPage + 1)}
							disabled={currentPage === totalPages}
							class="px-4 py-2 bg-white border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Next
						</button>
					</div>
				{/if}
			{/if}
		{/if}
	</div>
</div>

<!-- Group Creation Modal -->
{#if showGroupModal}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
			<div class="p-6 border-b border-gray-200">
				<h2 class="text-2xl font-bold text-gray-800">Create Variation Group</h2>
				<p class="text-sm text-gray-600 mt-1">
					Grouping {selectedProducts.size} products together
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
						Creating...
					{:else}
						Create Group
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
