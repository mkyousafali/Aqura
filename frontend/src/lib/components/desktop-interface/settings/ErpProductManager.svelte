<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';

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
		expiry_dates?: { branch_id?: number; erp_branch_id?: number; erp_row_branch_id?: number; expiry_date: string }[];
	}

	interface ServerSettings {
		tunnelUrl: string;
	}

	// State
	let supabase: any;
	let activeTab: string = 'settings';
	let loading = false;
	let syncing = false;
	let testingConnection = false;
	let connectionStatus: { success: boolean; message: string; counts?: any } | null = null;
	let syncStatus: { success: boolean; message: string } | null = null;
	let products: ErpProduct[] = [];
	let searchBarcode = '';
	let searchName = '';
	let showBaseOnly = false;
	let totalSynced = 0;
	let totalFiltered = 0;
	let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

	// Per-branch connection test status: branch_id -> { testing, success, message }
	let branchTestStatus: Record<number, { testing: boolean; success?: boolean; message?: string }> = {};

	// Inline expiry date editing
	let editingCell: { productIndex: number; branchId: number } | null = null;
	let editingValue = '';
	let savingExpiry = false;

	// Server settings  
	let settings: ServerSettings = {
		tunnelUrl: ''
	};

	// Saved settings from erp_connections
	let savedConfigs: any[] = [];
	let selectedConfigId: string = '';
	let configLoadError: string = '';

	// Tabs
	const tabs = [
		{ id: 'settings', label: 'Server Settings', labelAr: 'إعدادات الخادم', icon: '⚙️' },
		{ id: 'products', label: 'Synced Products', labelAr: 'المنتجات المتزامنة', icon: '📦' }
	];

	// Pagination (server-side)
	let currentPage = 1;
	let pageSize = 50;
	$: totalPages = Math.ceil(totalFiltered / pageSize);

	// Debounced search - triggers server-side query
	function onSearchChange() {
		if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
		searchDebounceTimer = setTimeout(() => {
			currentPage = 1;
			loadSyncedProducts();
		}, 400);
	}

	function onFilterChange() {
		currentPage = 1;
		loadSyncedProducts();
	}

	function goToPage(page: number) {
		currentPage = page;
		loadSyncedProducts();
	}

	onMount(async () => {
		const { supabase: client } = await import('$lib/utils/supabase');
		supabase = client;
		await loadSavedConfigs();
		await loadSyncedProducts();
	});

	async function loadSavedConfigs() {
		try {
			configLoadError = '';
			const { data, error } = await supabase
				.from('erp_connections')
				.select('*')
				.order('branch_name');
			
			if (error) {
				configLoadError = error.message || 'Failed to load saved connections';
				console.error('Error loading ERP configs:', error);
				return;
			}
			savedConfigs = data || [];

			// Auto-select first config if available
			if (savedConfigs.length > 0 && !selectedConfigId) {
				selectConfig(savedConfigs[0]);
			}
		} catch (err: any) {
			configLoadError = err.message || 'Failed to load saved connections';
			console.error('Error loading ERP configs:', err);
		}
	}

	function selectConfig(config: any) {
		selectedConfigId = config.id;
		settings.tunnelUrl = config.tunnel_url || '';
		connectionStatus = null;
	}

	// Reactive: get the full selected config object for branch IDs
	$: selectedConfig = savedConfigs.find(c => c.id === selectedConfigId) || null;

	async function testConnection() {
		if (!settings.tunnelUrl) {
			connectionStatus = { success: false, message: 'No tunnel URL configured for this branch' };
			return;
		}

		testingConnection = true;
		connectionStatus = null;

		try {
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'test',
					tunnelUrl: settings.tunnelUrl
				})
			});

			const result = await response.json();
			connectionStatus = { success: result.success, message: result.message, counts: result.counts || null };
		} catch (err: any) {
			connectionStatus = { success: false, message: `Error: ${err.message}` };
		} finally {
			testingConnection = false;
		}
	}

	async function syncProducts() {
		if (!settings.tunnelUrl) {
			syncStatus = { success: false, message: 'No tunnel URL configured for this branch' };
			return;
		}

		syncing = true;
		syncStatus = null;

		try {
			const FETCH_BATCH_SIZE = 20000; // Fetch from bridge in chunks of 20K
			const UPSERT_BATCH_SIZE = 200;   // Upsert to Supabase in chunks of 200
			let newCount = 0;
			let updatedCount = 0;
			let totalFetched = 0;
			let totalProducts = 0;
			let batchNumber = 0;
			let hasMore = true;

			while (hasMore) {
				batchNumber++;
				syncStatus = { success: true, message: `📦 Fetching batch ${batchNumber} (offset: ${totalFetched})...` };

				// Step 1: Fetch products from bridge in chunks
				const response = await fetch('/api/erp-products', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						action: 'sync',
						tunnelUrl: settings.tunnelUrl,
						erpBranchId: selectedConfig?.erp_branch_id || null,
						appBranchId: selectedConfig?.branch_id || null,
						limit: FETCH_BATCH_SIZE,
						offset: totalFetched
					})
				});

				const result = await response.json();

				if (!result.success) {
					syncStatus = { success: false, message: result.error || 'Failed to fetch products from ERP' };
					return;
				}

				// Handle async build - bridge is building the product list in background
				if (result.retry === true) {
					syncStatus = { success: true, message: `⏳ ${result.message || 'Building product list from SQL...'} (retrying in 5s)` };
					await new Promise(r => setTimeout(r, 5000));
					batchNumber--; // retry same batch
					continue;
				}

				const fetchedProducts: ErpProduct[] = result.products;
				totalProducts = result.totalCount || fetchedProducts.length;
				totalFetched += fetchedProducts.length;

				syncStatus = { success: true, message: `📦 Batch ${batchNumber}: Fetched ${fetchedProducts.length} products (${totalFetched}/${totalProducts}). Upserting...` };

				// Step 2: Upsert this batch to Supabase
				for (let i = 0; i < fetchedProducts.length; i += UPSERT_BATCH_SIZE) {
					const batch = fetchedProducts.slice(i, i + UPSERT_BATCH_SIZE);

					const { data: rpcResult, error: rpcError } = await supabase
						.rpc('upsert_erp_products_with_expiry', {
							p_products: batch
						});

					if (rpcError) {
						console.error(`Error upserting batch ${i}:`, rpcError);
					} else if (rpcResult) {
						newCount += rpcResult.inserted || 0;
						updatedCount += rpcResult.updated || 0;
					}

					syncStatus = {
						success: true,
						message: `⏳ Batch ${batchNumber}: ${i + batch.length}/${fetchedProducts.length} upserted (${totalFetched}/${totalProducts} total, ${newCount} new, ${updatedCount} updated)`
					};
				}

				// Check if there are more products to fetch
				hasMore = result.hasMore === true;
			}

			syncStatus = {
				success: true,
				message: `✅ Sync complete! ${totalFetched} products synced (${newCount} new + ${updatedCount} updated) in ${batchNumber} batch(es).`
			};

			// Reload synced products
			totalSynced = 0;
			await loadSyncedProducts();
			activeTab = 'products';

		} catch (err: any) {
			syncStatus = { success: false, message: `Error: ${err.message}` };
		} finally {
			syncing = false;
		}
	}

	async function loadSyncedProducts() {
		try {
			loading = true;
			const from = (currentPage - 1) * pageSize;
			const to = from + pageSize - 1;

			let query = supabase
				.from('erp_synced_products')
				.select('*', { count: 'exact' });

			// Server-side filters
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

			// Get total count (unfiltered) only on first load
			if (totalSynced === 0) {
				const { count: total } = await supabase
					.from('erp_synced_products')
					.select('id', { count: 'exact', head: true });
				totalSynced = total || 0;
			}
		} catch (err: any) {
			console.error('Error loading synced products:', err);
		} finally {
			loading = false;
		}
	}

	$: isRtl = $locale === 'ar';

	// Dynamic branch columns for expiry dates - one column per saved ERP connection
	$: branchColumns = savedConfigs.map(c => ({ branch_id: c.branch_id, branch_name: c.branch_name }));

	function getExpiryForBranch(product: ErpProduct, branchId: number): string | null {
		if (!product.expiry_dates || product.expiry_dates.length === 0) return null;
		const entry = product.expiry_dates.find(e => e.branch_id === branchId);
		if (!entry?.expiry_date) return null;
		// Convert yyyy-mm-dd to dd-mm-yyyy
		const parts = entry.expiry_date.split('-');
		if (parts.length === 3) return `${parts[2]}-${parts[1]}-${parts[0]}`;
		return entry.expiry_date;
	}

	async function testBranchConnection(branchId: number) {
		const config = savedConfigs.find(c => c.branch_id === branchId);
		if (!config) return;

		branchTestStatus[branchId] = { testing: true };
		branchTestStatus = branchTestStatus; // trigger reactivity

		try {
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'test',
					tunnelUrl: config.tunnel_url
				})
			});
			const result = await response.json();
			branchTestStatus[branchId] = { testing: false, success: result.success, message: result.success ? '✅' : '❌' };
		} catch (err: any) {
			branchTestStatus[branchId] = { testing: false, success: false, message: '❌' };
		}
		branchTestStatus = branchTestStatus;
	}

	function startEditExpiry(productIndex: number, branchId: number, currentValue: string | null) {
		// Convert dd-mm-yyyy display back to yyyy-mm-dd for input
		let inputVal = '';
		if (currentValue) {
			const parts = currentValue.split('-');
			if (parts.length === 3 && parts[0].length === 2) {
				inputVal = `${parts[2]}-${parts[1]}-${parts[0]}`;
			} else {
				inputVal = currentValue;
			}
		}
		editingCell = { productIndex, branchId };
		editingValue = inputVal;
	}

	function cancelEdit() {
		editingCell = null;
		editingValue = '';
	}

	async function saveExpiryDate() {
		if (!editingCell || !editingValue) { cancelEdit(); return; }

		const product = products[editingCell.productIndex];
		const branchId = editingCell.branchId;
		const config = savedConfigs.find(c => c.branch_id === branchId);
		if (!product || !config) { cancelEdit(); return; }

		const newExpiryDate = editingValue; // yyyy-mm-dd format
		savingExpiry = true;

		try {
			// 1. Update SQL Server (ERP) via bridge
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'update-expiry',
					tunnelUrl: config.tunnel_url,
					barcode: product.barcode,
					newExpiryDate
				})
			});
			const result = await response.json();

			if (!result.success) {
				alert(result.error || 'Failed to update ERP');
				savingExpiry = false;
				return;
			}

			// 2. Update Supabase (app) - merge into expiry_dates JSON for this barcode + all sibling barcodes (same parent_barcode)
			const newEntry = { branch_id: branchId, erp_branch_id: config.erp_branch_id, expiry_date: newExpiryDate };

			// Find all barcodes that share the same parent_barcode
			const parentBarcode = product.parent_barcode || product.barcode;
			const { data: siblings } = await supabase
				.from('erp_synced_products')
				.select('barcode, expiry_dates')
				.or(`parent_barcode.eq.${parentBarcode},barcode.eq.${parentBarcode}`);

			const barcodesToUpdate = siblings && siblings.length > 0 ? siblings : [{ barcode: product.barcode, expiry_dates: product.expiry_dates }];
			let sbErrors: string[] = [];

			for (const sibling of barcodesToUpdate) {
				const sibExpiry: any[] = sibling.expiry_dates ? [...sibling.expiry_dates] : [];
				const idx = sibExpiry.findIndex((e: any) => e.branch_id === branchId);
				if (idx >= 0) {
					sibExpiry[idx] = newEntry;
				} else {
					sibExpiry.push(newEntry);
				}

				const { error: sbErr } = await supabase
					.from('erp_synced_products')
					.update({ expiry_dates: sibExpiry, synced_at: new Date().toISOString() })
					.eq('barcode', sibling.barcode);

				if (sbErr) {
					console.error('Supabase update error for', sibling.barcode, sbErr);
					sbErrors.push(sibling.barcode);
				}
			}

			if (sbErrors.length > 0) {
				alert(`ERP updated but Supabase failed for: ${sbErrors.join(', ')}`);
			}

			// 3. Update local state for all matching products
			const updatedBarcodes = new Set(barcodesToUpdate.map(s => s.barcode));
			for (let i = 0; i < products.length; i++) {
				if (updatedBarcodes.has(products[i].barcode)) {
					const localExpiry: any[] = products[i].expiry_dates ? [...products[i].expiry_dates] : [];
					const li = localExpiry.findIndex((e: any) => e.branch_id === branchId);
					if (li >= 0) { localExpiry[li] = newEntry; } else { localExpiry.push(newEntry); }
					products[i].expiry_dates = localExpiry;
				}
			}
			products = products;
		} catch (err: any) {
			alert('Error: ' + err.message);
		} finally {
			savingExpiry = false;
			cancelEdit();
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans text-slate-800" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">🏭</span>
			<h2 class="text-lg font-bold text-slate-800 m-0">
				{isRtl ? 'مدير منتجات ERP' : 'ERP Product Manager'}
			</h2>
		</div>
		<div class="flex items-center gap-3">
			<span class="text-xs font-semibold bg-blue-100 text-blue-600 px-3 py-1 rounded-full">
				📦 {totalSynced.toLocaleString()} {isRtl ? 'باركود' : 'barcodes'}
			</span>
		</div>
	</div>

	<!-- Tabs -->
	<div class="flex gap-2 px-6 py-3 bg-white border-b border-slate-100">
		{#each tabs as tab}
			<button
				class="flex items-center gap-2 px-4 py-2.5 font-bold rounded-xl transition-all text-xs border-none cursor-pointer {activeTab === tab.id ? 'bg-blue-600 text-white shadow-lg shadow-blue-200' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
				on:click={() => activeTab = tab.id}
			>
				<span>{tab.icon}</span>
				<span>{isRtl ? tab.labelAr : tab.label}</span>
			</button>
		{/each}
	</div>

	<!-- Settings Tab -->
	{#if activeTab === 'settings'}
		<div class="flex-1 overflow-y-auto p-5 animate-in">
			<!-- Config Load Error -->
			{#if configLoadError}
				<div class="mb-3 p-3 bg-red-50 border border-red-200 rounded-xl text-sm">
					<span class="text-red-600">
						❌ {isRtl ? 'خطأ في تحميل الاتصالات:' : 'Error loading connections:'} {configLoadError}
					</span>
				</div>
			{/if}

			<!-- Saved Configurations -->
			{#if savedConfigs.length > 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mb-4">
					<h3 class="text-base font-bold text-slate-800 mb-4">
						🔌 {isRtl ? 'الاتصالات المحفوظة' : 'Saved ERP Connections'}
					</h3>
					<div class="grid grid-cols-[repeat(auto-fill,minmax(180px,1fr))] gap-3">
						{#each savedConfigs as config}
							<button
								class="flex items-center justify-center p-3 border-2 rounded-xl cursor-pointer transition-all text-center {selectedConfigId === config.id ? 'border-blue-600 bg-blue-50' : 'bg-slate-50 border-slate-200 hover:border-blue-400'}"
								on:click={() => selectConfig(config)}
							>
								<span class="font-bold text-blue-600 text-sm">{config.branch_name}</span>
							</button>
						{/each}
					</div>
				</div>
			{/if}

			<!-- Server Settings Form -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mb-4">
				<h3 class="text-base font-bold text-slate-800 mb-4">
					⚙️ {isRtl ? 'إعدادات الخادم' : 'Server Settings'}
				</h3>
				<div class="grid grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-4">
					<div class="flex flex-col gap-1.5">
						<label class="text-xs font-bold text-slate-500">
							🌐 {isRtl ? 'رابط النفق' : 'Tunnel URL'}
						</label>
						<input
							type="text"
							class="px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium text-slate-800 focus:outline-none focus:border-blue-500 transition-colors"
							bind:value={settings.tunnelUrl}
							placeholder="https://erp-branch3.urbanaqura.com"
						/>
					</div>
				</div>

				<!-- Action Buttons -->
				<div class="flex gap-3 mt-5 flex-wrap">
					<button
						class="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all text-sm shadow-lg shadow-emerald-200 disabled:opacity-50 disabled:cursor-not-allowed border-none cursor-pointer"
						on:click={testConnection}
						disabled={testingConnection}
					>
						{#if testingConnection}
							<span class="spinner"></span>
							{isRtl ? 'جاري الاختبار...' : 'Testing...'}
						{:else}
							🔗 {isRtl ? 'اختبار الاتصال' : 'Test Connection'}
						{/if}
					</button>

					<button
						class="flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white font-bold rounded-xl hover:bg-blue-700 transition-all text-sm shadow-lg shadow-blue-200 disabled:opacity-50 disabled:cursor-not-allowed border-none cursor-pointer"
						on:click={syncProducts}
						disabled={syncing}
					>
						{#if syncing}
							<span class="spinner"></span>
							{isRtl ? 'جاري المزامنة...' : 'Syncing...'}
						{:else}
							🔄 {isRtl ? 'مزامنة المنتجات' : 'Sync Products'}
						{/if}
					</button>
				</div>

				<!-- Connection Status -->
				{#if connectionStatus}
					<div class="mt-4 p-3 rounded-xl text-sm {connectionStatus.success ? 'bg-emerald-50 border border-emerald-200' : 'bg-red-50 border border-red-200'}">
						<span class={connectionStatus.success ? 'text-emerald-700' : 'text-red-600'}>
							{connectionStatus.success ? '✅' : '❌'} {connectionStatus.message}
						</span>
					</div>
				{/if}

				<!-- Sync Status -->
				{#if syncStatus}
					<div class="mt-4 p-3 rounded-xl text-sm {syncStatus.success ? 'bg-emerald-50 border border-emerald-200' : 'bg-red-50 border border-red-200'}">
						<span class={syncStatus.success ? 'text-emerald-700' : 'text-red-600'}>
							{syncStatus.message}
						</span>
					</div>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Products Tab -->
	{#if activeTab === 'products'}
		<div class="flex-1 overflow-y-auto p-5 flex flex-col animate-in">
			<!-- Search & Filters -->
			<div class="flex gap-3 items-center flex-wrap mb-3">
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

			<!-- Products Table -->
			{#if loading}
				<div class="flex flex-col items-center justify-center gap-3 py-16 text-slate-400">
					<span class="spinner large"></span>
					<span>{isRtl ? 'جاري التحميل...' : 'Loading...'}</span>
				</div>
			{:else if products.length === 0}
				<div class="flex flex-col items-center justify-center gap-2 py-16 text-slate-400">
					<span class="text-5xl">📭</span>
					<p>{isRtl ? 'لا توجد منتجات متزامنة' : 'No synced products found'}</p>
					<p class="text-xs text-slate-400">{isRtl ? 'اذهب لإعدادات الخادم وقم بالمزامنة' : 'Go to Server Settings and sync products'}</p>
				</div>
			{:else}
				<div class="overflow-auto flex-1 rounded-xl border border-slate-200">
					<table class="w-full border-collapse text-xs">
						<thead class="sticky top-0 z-10">
							<tr>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap w-[50px]">#</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[130px]">{isRtl ? 'الباركود' : 'Barcode'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[100px]">{isRtl ? 'باركود تلقائي' : 'Auto Barcode'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[130px]">{isRtl ? 'باركود الأساس' : 'Parent Barcode'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[200px]">{isRtl ? 'الاسم (إنجليزي)' : 'Name (English)'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[200px]">{isRtl ? 'الاسم (عربي)' : 'Name (Arabic)'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-start font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap min-w-[80px]">{isRtl ? 'الوحدة' : 'Unit'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap w-[60px]">{isRtl ? 'الكمية' : 'Qty'}</th>
								<th class="bg-blue-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-blue-700 border-r border-blue-500 whitespace-nowrap w-[50px]">{isRtl ? 'أساسي' : 'Base'}</th>
								{#each branchColumns as branch}
									<th class="bg-orange-600 text-white px-3 py-2.5 text-center font-bold border-b-2 border-orange-700 border-r border-orange-500 whitespace-nowrap min-w-[110px]">
										<div class="flex items-center justify-center gap-1">
											<span>📅 {branch.branch_name}</span>
											<button
												class="ml-1 bg-white/20 hover:bg-white/40 text-white border-none rounded-md px-1.5 py-0.5 text-[10px] cursor-pointer transition-all font-bold leading-none disabled:opacity-50"
												disabled={branchTestStatus[branch.branch_id]?.testing}
												on:click|stopPropagation={() => testBranchConnection(branch.branch_id)}
												title={isRtl ? 'اختبار اتصال SQL' : 'Test SQL connection'}
											>
												{#if branchTestStatus[branch.branch_id]?.testing}
													<span class="inline-block animate-spin">⏳</span>
												{:else if branchTestStatus[branch.branch_id]?.message}
													{branchTestStatus[branch.branch_id].message}
												{:else}
													🔗
												{/if}
											</button>
										</div>
									</th>
								{/each}
							</tr>
						</thead>
						<tbody>
							{#each products as product, index}
								<tr class="transition-colors duration-150 {product.is_base_unit ? 'bg-emerald-50 hover:bg-emerald-100' : index % 2 === 0 ? 'bg-white hover:bg-slate-50' : 'bg-slate-50/50 hover:bg-slate-100'}">
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-center text-slate-500">{(currentPage - 1) * pageSize + index + 1}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 font-mono text-xs text-slate-700">{product.barcode}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 font-mono text-xs text-slate-500">{product.auto_barcode || '-'}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 font-mono text-xs text-slate-500">{product.parent_barcode || '-'}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-slate-700">{product.product_name_en || '-'}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-slate-700" dir="rtl">{product.product_name_ar || '-'}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-slate-600 font-medium">{product.unit_name || '-'}</td>
									<td class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-center text-slate-600">{product.unit_qty}</td>
									<td class="px-3 py-2 border-b border-slate-200 text-center">
										{#if product.is_base_unit}
											<span class="bg-emerald-500 text-white rounded-full w-[22px] h-[22px] inline-flex items-center justify-center text-xs font-bold">✓</span>
										{/if}
									</td>
									{#each branchColumns as branch}
										{@const expDate = getExpiryForBranch(product, branch.branch_id)}
									<td
										class="px-3 py-2 border-b border-slate-200 border-r border-r-slate-100 text-center text-xs cursor-pointer hover:bg-orange-50 transition-colors"
										on:dblclick={() => startEditExpiry(index, branch.branch_id, expDate)}
										title={isRtl ? 'انقر مرتين للتعديل' : 'Double-click to edit'}
									>
										{#if editingCell && editingCell.productIndex === index && editingCell.branchId === branch.branch_id}
											<div class="flex items-center gap-1">
												<input
													type="date"
													class="w-[110px] text-xs border border-orange-400 rounded px-1 py-0.5 outline-none focus:border-orange-600 font-mono"
													bind:value={editingValue}
													on:keydown={(e) => { if (e.key === 'Enter') saveExpiryDate(); if (e.key === 'Escape') cancelEdit(); }}
													disabled={savingExpiry}
												/>
												{#if savingExpiry}
													<span class="text-[10px] animate-spin">⏳</span>
												{:else}
													<button class="text-emerald-600 border-none bg-transparent cursor-pointer text-sm p-0 leading-none" on:click={saveExpiryDate} title="Save">✓</button>
													<button class="text-red-500 border-none bg-transparent cursor-pointer text-sm p-0 leading-none" on:click={cancelEdit} title="Cancel">✕</button>
												{/if}
											</div>
										{:else if expDate}
												<span class="font-mono text-orange-700 font-semibold">{expDate}</span>
											{:else}
												<span class="text-slate-300">—</span>
											{/if}
										</td>
									{/each}
								</tr>
							{/each}
						</tbody>
					</table>
				</div>

				<!-- Pagination -->
				{#if totalPages > 1}
					<div class="flex items-center justify-center gap-2 py-3">
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
			{/if}
		</div>
	{/if}
</div>

<style>
	/* Spinner */
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

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.animate-in {
		animation: fadeIn 0.2s ease-out;
	}
</style>
