<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	// Escape the mobile window's stacking context and overflow clipping.
	function portal(node: HTMLElement) {
		document.body.appendChild(node);
		return { destroy: () => node.remove() };
	}
	
	export let parentProduct: any;
	export let variations: any[] = [];
	export let templateId: string;
	export let preSelectedBarcodes: Set<string> = new Set();
	
	const dispatch = createEventDispatcher();
	
	// Local state for selection
	let selectedVariations: Set<string> = new Set(preSelectedBarcodes);
	let selectAll: boolean = selectedVariations.size === variations.length + 1; // +1 for parent
	let searchQuery: string = '';
	let filteredVariations: any[] = [];
	
	// Image preview
	let showImagePreview: boolean = false;
	let previewImageUrl: string = '';
	
	// Stats
	$: allProducts = [parentProduct, ...variations];
	$: selectedCount = selectedVariations.size;
	$: totalCount = allProducts.length;
	
	// Price consistency check
	$: {
		filteredVariations = variations.filter(v => {
			if (!searchQuery) return true;
			const query = searchQuery.toLowerCase();
			return v.barcode?.toLowerCase().includes(query) ||
				   v.product_name_en?.toLowerCase().includes(query) ||
				   v.product_name_ar?.includes(query);
		});
	}
	
	function toggleVariation(barcode: string) {
		if (selectedVariations.has(barcode)) {
			selectedVariations.delete(barcode);
		} else {
			selectedVariations.add(barcode);
		}
		selectedVariations = selectedVariations;
		updateSelectAllState();
	}
	
	function toggleSelectAll() {
		if (selectAll) {
			selectedVariations.clear();
		} else {
			allProducts.forEach(p => selectedVariations.add(p.barcode));
		}
		selectedVariations = selectedVariations;
		updateSelectAllState();
	}
	
	function updateSelectAllState() {
		selectAll = selectedVariations.size === allProducts.length;
	}
	
	function selectInStockOnly() {
		selectedVariations.clear();
		allProducts
			.filter(p => !p.out_of_stock)
			.forEach(p => selectedVariations.add(p.barcode));
		selectedVariations = selectedVariations;
		updateSelectAllState();
	}
	
	function previewImage(imageUrl: string) {
		previewImageUrl = imageUrl;
		showImagePreview = true;
	}
	
	function confirm() {
		dispatch('confirm', {
			templateId,
			selectedBarcodes: Array.from(selectedVariations),
			groupInfo: {
				parentBarcode: parentProduct.barcode,
				groupNameEn: parentProduct.variation_group_name_en,
				groupNameAr: parentProduct.variation_group_name_ar
			}
		});
	}
	
	function cancel() {
		dispatch('cancel');
	}
</script>

<div use:portal class="variation-overlay fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
	<div class="variation-dialog bg-white rounded-lg shadow-xl max-w-5xl w-full overflow-hidden flex flex-col">
		<!-- Header -->
		<div class="variation-header shrink-0 p-4 sm:p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-cyan-50">
			<div class="flex items-start justify-between">
				<div class="min-w-0 flex-1 break-words">
					<h2 class="text-xl sm:text-2xl font-bold text-gray-800 mb-2">Select Variations</h2>
					<div class="flex items-center gap-2 sm:gap-4">
						<div class="flex items-center gap-2">
							{#if parentProduct.variation_image_override || parentProduct.image_url}
								<img
									src={parentProduct.variation_image_override || parentProduct.image_url}
									alt={parentProduct.variation_group_name_en}
									class="w-12 h-12 object-contain rounded border border-gray-300 cursor-pointer"
									on:click={() => previewImage(parentProduct.variation_image_override || parentProduct.image_url)}
								/>
							{/if}
							<div>
								<div class="font-semibold text-gray-800">{parentProduct.variation_group_name_en}</div>
								<div class="text-sm text-gray-600 font-arabic">{parentProduct.variation_group_name_ar}</div>
							</div>
						</div>
						<div class="shrink-0 bg-white px-3 py-1 rounded-full border border-blue-200">
							<span class="text-sm font-semibold text-blue-700">{selectedCount} / {totalCount} selected</span>
						</div>
					</div>
				</div>
				<button
					on:click={cancel}
					aria-label="Close variation selector"
					class="text-gray-400 hover:text-gray-600 transition-colors"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>
		</div>
		
		<!-- Toolbar -->
		<div class="shrink-0 p-3 sm:p-4 border-b border-gray-200 bg-gray-50">
			<div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 sm:gap-4">
				<!-- Search -->
				<div class="min-w-0 w-full sm:flex-1 sm:max-w-md">
					<input
						type="text"
						bind:value={searchQuery}
						placeholder="Search variations..."
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
				
				<!-- Quick actions -->
				<div class="flex items-center gap-2">
					<button
						on:click={toggleSelectAll}
						class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium text-sm"
					>
						{selectAll ? 'Deselect All' : 'Select All'}
					</button>
					<button
						on:click={selectInStockOnly}
						class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium text-sm"
					>
						In Stock Only
					</button>
				</div>
			</div>
		</div>
		
		<!-- Content -->
		<div class="variation-list min-h-0 flex-1 overflow-y-auto p-3 sm:p-6">
			<div class="space-y-3">
				<!-- Parent Product (Always first) -->
				<div
					class="border-2 rounded-lg p-3 sm:p-4 cursor-pointer transition-all
						{selectedVariations.has(parentProduct.barcode) ? 'border-blue-500 bg-blue-50' : 'border-blue-300 bg-blue-50'}"
					on:click={() => toggleVariation(parentProduct.barcode)}
				>
					<div class="flex items-center gap-2 sm:gap-4">
						<input
							type="checkbox"
							checked={selectedVariations.has(parentProduct.barcode)}
							on:click|stopPropagation
							on:change={() => toggleVariation(parentProduct.barcode)}
							class="shrink-0 w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
						/>
						
						<div class="shrink-0 w-12 h-12 sm:w-16 sm:h-16 bg-white rounded border border-gray-300 flex items-center justify-center overflow-hidden">
							{#if parentProduct.image_url}
								<img
									src={parentProduct.image_url}
									alt={parentProduct.product_name_en}
									class="w-full h-full object-contain cursor-zoom-in"
									on:click|stopPropagation={() => previewImage(parentProduct.image_url)}
								/>
							{:else}
								<svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
								</svg>
							{/if}
						</div>
						
						<div class="min-w-0 flex-1 break-words">
							<div class="flex flex-wrap items-center gap-2 mb-1">
								<span class="px-2 py-0.5 text-xs bg-blue-600 text-white rounded font-semibold">PARENT</span>
								{#if parentProduct.out_of_stock}
									<span class="px-2 py-0.5 text-xs bg-red-100 text-red-700 rounded font-semibold">OUT OF STOCK</span>
								{/if}
							</div>
							<div class="font-medium text-gray-800">{parentProduct.product_name_en}</div>
							<div class="text-sm text-gray-600 font-arabic">{parentProduct.product_name_ar}</div>
							<div class="text-xs text-gray-500 font-mono mt-1">{parentProduct.barcode}</div>
						</div>
					</div>
				</div>
				
				<!-- Variation Products -->
				{#each filteredVariations as variation (variation.barcode)}
					<div
						class="border-2 rounded-lg p-3 sm:p-4 cursor-pointer transition-all
							{selectedVariations.has(variation.barcode) ? 'border-blue-500 bg-blue-50' : 'border-gray-200 bg-white hover:border-gray-300'}"
						on:click={() => toggleVariation(variation.barcode)}
					>
						<div class="flex items-center gap-2 sm:gap-4">
							<input
								type="checkbox"
								checked={selectedVariations.has(variation.barcode)}
								on:click|stopPropagation
								on:change={() => toggleVariation(variation.barcode)}
								class="shrink-0 w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
							/>
							
							<div class="shrink-0 w-12 h-12 sm:w-16 sm:h-16 bg-gray-100 rounded border border-gray-300 flex items-center justify-center overflow-hidden">
								{#if variation.image_url}
									<img
										src={variation.image_url}
										alt={variation.product_name_en}
										class="w-full h-full object-contain cursor-zoom-in"
										on:click|stopPropagation={() => previewImage(variation.image_url)}
									/>
								{:else}
									<svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
									</svg>
								{/if}
							</div>
							
							<div class="min-w-0 flex-1 break-words">
								<div class="flex flex-wrap items-center gap-2 mb-1">
									<span class="px-2 py-0.5 text-xs bg-gray-200 text-gray-700 rounded font-semibold">Order: {variation.variation_order}</span>
									{#if variation.out_of_stock}
										<span class="px-2 py-0.5 text-xs bg-red-100 text-red-700 rounded font-semibold">OUT OF STOCK</span>
									{/if}
								</div>
								<div class="font-medium text-gray-800">{variation.product_name_en}</div>
								<div class="text-sm text-gray-600 font-arabic">{variation.product_name_ar}</div>
								<div class="text-xs text-gray-500 font-mono mt-1">{variation.barcode}</div>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
		
		<!-- Footer -->
		<div class="variation-footer shrink-0 p-3 sm:p-6 border-t border-gray-200 bg-gray-50 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
			<div class="text-sm text-gray-600">
				<strong>{selectedCount} variations</strong> will be added to this template
			</div>
			<div class="flex items-center justify-end gap-2 sm:gap-3">
				<button
					on:click={cancel}
					aria-label="Close variation selector"
					class="px-3 sm:px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 transition-colors font-medium"
				>
					Cancel
				</button>
				<button
					on:click={confirm}
					disabled={selectedCount === 0}
					class="px-3 sm:px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed font-medium"
				>
					Add Selected ({selectedCount})
				</button>
			</div>
		</div>
	</div>
</div>

<!-- Image Preview Modal -->
{#if showImagePreview}
	<div
		use:portal
		class="variation-preview fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-4"
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
	.variation-overlay {
		z-index: 10000;
		height: 100vh;
		height: 100dvh;
		padding: max(8px, env(safe-area-inset-top)) max(8px, env(safe-area-inset-right)) max(8px, env(safe-area-inset-bottom)) max(8px, env(safe-area-inset-left));
	}

	.variation-dialog {
		max-height: 100%;
		min-height: 0;
	}

	.variation-list {
		overscroll-behavior-y: contain;
		-webkit-overflow-scrolling: touch;
	}

	.variation-preview {
		z-index: 10001;
	}

	@media (min-width: 640px) {
		.variation-overlay { padding: 16px; }
		.variation-dialog { max-height: 90vh; max-height: 90dvh; }
	}

	@media (max-height: 500px) {
		.variation-header, .variation-footer { padding: 8px 12px; }
	}

	.font-arabic {
		font-family: 'Noto Sans Arabic', sans-serif;
	}
</style>
