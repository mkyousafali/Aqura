<script lang="ts">
	import { onMount } from 'svelte';
	import { locale } from '$lib/i18n';

	interface ErpProduct {
		id?: number;
		barcode: string;
		auto_barcode: string;
		parent_barcode: string;
		product_name_en: string;
		product_name_ar: string;
		unit_name: string;
		unit_qty: number;
		is_base_unit: boolean;
		synced_at?: string;
	}

	let supabase: any;
	let loading = false;
	let products: ErpProduct[] = [];
	let searchBarcode = '';
	let searchName = '';
	let showBaseOnly = false;
	let totalSynced = 0;
	let totalFiltered = 0;
	let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

	// Pagination (server-side)
	let currentPage = 1;
	let pageSize = 50;
	$: totalPages = Math.ceil(totalFiltered / pageSize);

	function onSearchChange() {
		if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
		searchDebounceTimer = setTimeout(() => {
			currentPage = 1;
			loadProducts();
		}, 400);
	}

	function onFilterChange() {
		currentPage = 1;
		loadProducts();
	}

	function goToPage(page: number) {
		currentPage = page;
		loadProducts();
	}

	onMount(async () => {
		const { supabase: client } = await import('$lib/utils/supabase');
		supabase = client;
		await loadProducts();
	});

	async function loadProducts() {
		try {
			loading = true;
			const from = (currentPage - 1) * pageSize;
			const to = from + pageSize - 1;

			let query = supabase
				.from('erp_synced_products')
				.select('*', { count: 'exact' });

			if (searchBarcode.trim()) {
				const bc = searchBarcode.trim();
				query = query.or(`barcode.ilike.%${bc}%,auto_barcode.ilike.%${bc}%`);
			}
			if (searchName.trim()) {
				const nm = searchName.trim();
				query = query.or(`product_name_en.ilike.%${nm}%,product_name_ar.ilike.%${nm}%`);
			}
			if (showBaseOnly) {
				query = query.eq('is_base_unit', true);
			}

			const { data, error, count } = await query
				.order('id')
				.range(from, to);

			if (error) throw error;
			products = data || [];
			totalFiltered = count || 0;

			if (totalSynced === 0) {
				const { count: total } = await supabase
					.from('erp_synced_products')
					.select('id', { count: 'exact', head: true });
				totalSynced = total || 0;
			}
		} catch (err: any) {
			console.error('Error loading ERP products:', err);
		} finally {
			loading = false;
		}
	}

	$: isRtl = $locale === 'ar';
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans text-slate-800" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">🏭</span>
			<h2 class="text-lg font-bold text-slate-800 m-0">
				{isRtl ? 'منتجات ERP' : 'ERP Products'}
			</h2>
		</div>
		<div class="flex items-center gap-3">
			<span class="text-xs font-semibold bg-blue-100 text-blue-600 px-3 py-1 rounded-full">
				📦 {totalSynced.toLocaleString()} {isRtl ? 'باركود' : 'barcodes'}
			</span>
		</div>
	</div>

	<!-- Search & Filters -->
	<div class="flex gap-3 items-center flex-wrap px-5 py-3 bg-white border-b border-slate-100">
		<div class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 flex-1 min-w-[200px] focus-within:border-blue-500 transition-colors">
			<span class="text-sm">🔍</span>
			<input
				type="text"
				class="flex-1 bg-transparent border-none text-slate-800 text-xs font-medium outline-none"
				bind:value={searchBarcode}
				on:input={onSearchChange}
				placeholder={isRtl ? 'بحث بالباركود...' : 'Search by barcode...'}
			/>
			{#if searchBarcode}
				<button class="bg-slate-200 border-none text-slate-500 rounded-full w-5 h-5 flex items-center justify-center cursor-pointer text-[10px] hover:bg-slate-300" on:click={() => { searchBarcode = ''; onFilterChange(); }}>✕</button>
			{/if}
		</div>
		<div class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 flex-1 min-w-[200px] focus-within:border-blue-500 transition-colors">
			<span class="text-sm">📝</span>
			<input
				type="text"
				class="flex-1 bg-transparent border-none text-slate-800 text-xs font-medium outline-none"
				bind:value={searchName}
				on:input={onSearchChange}
				placeholder={isRtl ? 'بحث بالاسم...' : 'Search by product name...'}
			/>
			{#if searchName}
				<button class="bg-slate-200 border-none text-slate-500 rounded-full w-5 h-5 flex items-center justify-center cursor-pointer text-[10px] hover:bg-slate-300" on:click={() => { searchName = ''; onFilterChange(); }}>✕</button>
			{/if}
		</div>
		<label class="flex items-center gap-2 text-xs text-slate-600 cursor-pointer whitespace-nowrap font-medium">
			<input type="checkbox" class="accent-blue-600" bind:checked={showBaseOnly} on:change={onFilterChange} />
			<span>{isRtl ? 'الوحدات الأساسية فقط' : 'Base units only'}</span>
		</label>
		<span class="text-xs text-slate-500 whitespace-nowrap px-3 py-1 bg-slate-100 rounded-full font-semibold">
			{totalFiltered.toLocaleString()} / {totalSynced.toLocaleString()}
		</span>
	</div>

	<!-- Table -->
	<div class="flex-1 overflow-auto p-5">
		{#if loading}
			<div class="flex flex-col items-center justify-center gap-3 py-16 text-slate-400">
				<span class="spinner large"></span>
				<span>{isRtl ? 'جاري التحميل...' : 'Loading...'}</span>
			</div>
		{:else if products.length === 0}
			<div class="flex flex-col items-center justify-center gap-2 py-16 text-slate-400">
				<span class="text-5xl">📭</span>
				<p>{isRtl ? 'لا توجد منتجات' : 'No products found'}</p>
				<p class="text-xs text-slate-400">{isRtl ? 'جرب تعديل البحث' : 'Try adjusting your search'}</p>
			</div>
		{:else}
			<div class="overflow-auto rounded-xl border border-slate-200">
				<table class="w-full border-collapse text-xs">
					<thead class="sticky top-0 z-10">
						<tr>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap w-[50px]">#</th>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[130px]">{isRtl ? 'الباركود' : 'Barcode'}</th>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[200px]">{isRtl ? 'الاسم (إنجليزي)' : 'Name (English)'}</th>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[200px]">{isRtl ? 'الاسم (عربي)' : 'Name (Arabic)'}</th>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[80px]">{isRtl ? 'الوحدة' : 'Unit'}</th>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap w-[60px]">{isRtl ? 'الكمية' : 'Qty'}</th>
							<th class="bg-blue-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-blue-700 whitespace-nowrap w-[50px]">{isRtl ? 'أساسي' : 'Base'}</th>
						</tr>
					</thead>
					<tbody>
						{#each products as product, index}
							<tr class="transition-colors duration-150 {product.is_base_unit ? 'bg-emerald-50 hover:bg-emerald-100' : index % 2 === 0 ? 'bg-white hover:bg-slate-50' : 'bg-slate-50/50 hover:bg-slate-100'}">
								<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-center text-slate-500">{(currentPage - 1) * pageSize + index + 1}</td>
								<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 font-mono text-xs text-slate-700">{product.barcode}</td>
								<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-slate-700">{product.product_name_en || '-'}</td>
								<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-slate-700" dir="rtl">{product.product_name_ar || '-'}</td>
								<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-slate-600 font-medium">{product.unit_name || '-'}</td>
								<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-center text-slate-600">{product.unit_qty}</td>
								<td class="px-3 py-2 border-b border-slate-200 text-center">
									{#if product.is_base_unit}
										<span class="bg-emerald-500 text-white rounded-full w-[22px] h-[22px] inline-flex items-center justify-center text-xs font-bold">✓</span>
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</div>

	<!-- Pagination -->
	{#if totalPages > 1}
		<div class="flex items-center justify-center gap-2 py-3 bg-white border-t border-slate-200">
			<button
				class="bg-white border border-slate-200 text-slate-600 rounded-xl px-3 py-1.5 cursor-pointer text-sm transition-all hover:bg-slate-100 disabled:opacity-30 disabled:cursor-not-allowed"
				disabled={currentPage === 1}
				on:click={() => goToPage(1)}
			>⏮</button>
			<button
				class="bg-white border border-slate-200 text-slate-600 rounded-xl px-3 py-1.5 cursor-pointer text-sm transition-all hover:bg-slate-100 disabled:opacity-30 disabled:cursor-not-allowed"
				disabled={currentPage === 1}
				on:click={() => goToPage(currentPage - 1)}
			>◀</button>
			<span class="text-xs text-slate-500 px-2 font-medium">
				{currentPage} / {totalPages}
			</span>
			<button
				class="bg-white border border-slate-200 text-slate-600 rounded-xl px-3 py-1.5 cursor-pointer text-sm transition-all hover:bg-slate-100 disabled:opacity-30 disabled:cursor-not-allowed"
				disabled={currentPage === totalPages}
				on:click={() => goToPage(currentPage + 1)}
			>▶</button>
			<button
				class="bg-white border border-slate-200 text-slate-600 rounded-xl px-3 py-1.5 cursor-pointer text-sm transition-all hover:bg-slate-100 disabled:opacity-30 disabled:cursor-not-allowed"
				disabled={currentPage === totalPages}
				on:click={() => goToPage(totalPages)}
			>⏭</button>
		</div>
	{/if}
</div>

<style>
	.spinner {
		display: inline-block;
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}
	.spinner.large {
		width: 32px;
		height: 32px;
		border-width: 3px;
		border-color: rgba(100, 116, 139, 0.3);
		border-top-color: #3b82f6;
	}
	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
