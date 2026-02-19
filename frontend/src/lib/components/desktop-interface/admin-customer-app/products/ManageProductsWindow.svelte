<script lang="ts">
	import { onMount } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import ExcelJS from 'exceljs';

	let products: any[] = [];
	let loading = true;
	let totalProducts = 0;
	let updatingProductId: string | null = null;
	let showImportPreview = false;
	let importedData: any[] = [];
	let importStats = { matched: 0, unmatched: 0 };
	let previewImageUrl: string | null = null;
	let searchQuery = '';
	let scanBarcode = '';
	let bulkUpdating = false;
	let editingProduct: any = null;
	let editForm = {
		product_name_en: '',
		product_name_ar: '',
		sale_price: 0,
		cost: 0,
		current_stock: 0,
		minim_qty: 0,
		minimum_qty_alert: 0,
		maximum_qty: 0
	};
	let saving = false;

	$: isRTL = $currentLocale === 'ar';

	$: filteredProducts = products.filter(p => {
		if (scanBarcode.trim()) {
			return p.barcode.toLowerCase().includes(scanBarcode.trim().toLowerCase());
		}
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			return (
				(p.product_name_en && p.product_name_en.toLowerCase().includes(q)) ||
				(p.product_name_ar && p.product_name_ar.includes(q)) ||
				(p.barcode && p.barcode.toLowerCase().includes(q))
			);
		}
		return true;
	});

	onMount(async () => {
		await loadProducts();
	});

	async function loadProducts() {
		loading = true;
		
		// Fetch all products in batches of 1000
		let allProducts: any[] = [];
		let offset = 0;
		let hasMore = true;

		while (hasMore) {
			const { data, error } = await supabase
				.from('products')
				.select('barcode, product_name_en, product_name_ar, image_url, sale_price, cost, current_stock, minim_qty, minimum_qty_alert, maximum_qty, is_customer_product')
				.order('barcode')
				.range(offset, offset + 999);

			if (error) {
				console.error('Error loading products:', error);
				break;
			}

			if (data && data.length > 0) {
				allProducts = allProducts.concat(data);
				offset += 1000;
				hasMore = data.length === 1000;
			} else {
				hasMore = false;
			}
		}

		products = allProducts;
		totalProducts = allProducts.length;
		loading = false;
	}

	async function toggleCustomerProduct(product: any) {
		const barcode = product.barcode;
		const newValue = !product.is_customer_product;

		updatingProductId = barcode;

		try {
			// Get current session to ensure auth is set
			const { data: { session }, error: sessionError } = await supabase.auth.getSession();
			
			if (sessionError) {
				console.error('Session error:', sessionError);
			}

			const { error } = await supabase
				.from('products')
				.update({ is_customer_product: newValue })
				.eq('barcode', barcode);

			if (error) {
				console.error('Error updating product:', error);
				console.error('Full error details:', JSON.stringify(error));
				alert('Failed to update product: ' + error.message);
			} else {
				// Update local state
				product.is_customer_product = newValue;
				products = products; // Trigger reactivity
				console.log('Product updated successfully:', barcode);
			}
		} catch (err) {
			console.error('Exception during update:', err);
			alert('Exception occurred during update');
		}

		updatingProductId = null;
	}

	async function exportToExcel() {
		try {
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('Products');

			// Add headers
			worksheet.columns = [
				{ header: 'Barcode', key: 'barcode', width: 15 },
				{ header: 'Name (EN)', key: 'product_name_en', width: 30 },
				{ header: 'Name (AR)', key: 'product_name_ar', width: 30 },
				{ header: 'Price', key: 'sale_price', width: 12 },
				{ header: 'Cost', key: 'cost', width: 12 },
				{ header: 'Stock', key: 'current_stock', width: 12 },
				{ header: 'Stock Min', key: 'minim_qty', width: 12 },
				{ header: 'Min Alert', key: 'minimum_qty_alert', width: 12 },
				{ header: 'Max Stock', key: 'maximum_qty', width: 12 }
			];

			// Style header row
			const headerRow = worksheet.getRow(1);
			headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
			headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1976D2' } };
			headerRow.alignment = { horizontal: 'center', vertical: 'center' };

			// Add all products with is_customer_product = true (fetch all, not just current page)
			let allProducts: any[] = [];
			let offset = 0;
			let hasMore = true;

			while (hasMore) {
				const { data, error } = await supabase
					.from('products')
					.select('barcode, product_name_en, product_name_ar, sale_price, cost, current_stock, minim_qty, minimum_qty_alert, maximum_qty')
					.eq('is_customer_product', true)
					.order('barcode')
					.range(offset, offset + 999);

				if (error) {
					throw error;
				}

				if (data && data.length > 0) {
					allProducts = allProducts.concat(data);
					offset += 1000;
					hasMore = data.length === 1000;
				} else {
					hasMore = false;
				}
			}

			// Add rows
			allProducts.forEach(product => {
				worksheet.addRow({
					barcode: product.barcode,
					product_name_en: product.product_name_en,
					product_name_ar: product.product_name_ar,
					sale_price: product.sale_price,
					cost: product.cost,
					current_stock: product.current_stock,
					minim_qty: product.minim_qty,
					minimum_qty_alert: product.minimum_qty_alert,
					maximum_qty: product.maximum_qty
				});
			});

			// Format number columns
			for (let i = 2; i <= allProducts.length + 1; i++) {
				worksheet.getRow(i).getCell('sale_price').numFmt = '0.00';
				worksheet.getRow(i).getCell('cost').numFmt = '0.00';
				worksheet.getRow(i).getCell('current_stock').numFmt = '0';
				worksheet.getRow(i).getCell('minim_qty').numFmt = '0';
				worksheet.getRow(i).getCell('minimum_qty_alert').numFmt = '0';
				worksheet.getRow(i).getCell('maximum_qty').numFmt = '0';
			}

			// Generate file
			const buffer = await workbook.xlsx.writeBuffer();
			const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = `Products-${new Date().toISOString().split('T')[0]}.xlsx`;
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			URL.revokeObjectURL(url);

			console.log(`Exported ${allProducts.length} products to Excel`);
		} catch (err) {
			console.error('Error exporting to Excel:', err);
			alert('Failed to export to Excel: ' + (err instanceof Error ? err.message : String(err)));
		}
	}

	async function handleImportFile(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];

		if (!file) return;

		try {
			const buffer = await file.arrayBuffer();
			const workbook = new ExcelJS.Workbook();
			await workbook.xlsx.load(buffer);

			const worksheet = workbook.getWorksheet(1);
			if (!worksheet) {
				throw new Error('No worksheet found in file');
			}

			// Parse data
			const importedRows: any[] = [];
			let rowIndex = 2; // Skip header

			worksheet.eachRow((row, index) => {
				if (index === 1) return; // Skip header row

				const barcode = row.getCell('A').value;
				const sale_price = row.getCell('D').value;
				const cost = row.getCell('E').value;
				const current_stock = row.getCell('F').value;
				const minim_qty = row.getCell('G').value;
				const minimum_qty_alert = row.getCell('H').value;
				const maximum_qty = row.getCell('I').value;

				if (barcode) {
					importedRows.push({
						barcode: String(barcode),
						sale_price: Number(sale_price) || 0,
						cost: Number(cost) || 0,
						current_stock: Number(current_stock) || 0,
						minim_qty: Number(minim_qty) || 0,
						minimum_qty_alert: Number(minimum_qty_alert) || 0,
						maximum_qty: Number(maximum_qty) || 0
					});
				}
			});

			// Match with existing products
			const matchedData = importedRows.map(row => {
				const existingProduct = products.find(p => p.barcode === row.barcode);
				return {
					...row,
					matched: !!existingProduct,
					profit: row.sale_price - row.cost,
					profitPercent: row.cost > 0 ? ((row.sale_price - row.cost) / row.cost) * 100 : 0
				};
			});

			importedData = matchedData;
			importStats = {
				matched: matchedData.filter(d => d.matched).length,
				unmatched: matchedData.filter(d => !d.matched).length
			};

			showImportPreview = true;

			// Reset file input
			target.value = '';
		} catch (err) {
			console.error('Error importing from Excel:', err);
			alert('Failed to import from Excel: ' + (err instanceof Error ? err.message : String(err)));
		}
	}

	async function applyImportUpdates() {
		const matchedProducts = importedData.filter(d => d.matched);

		if (matchedProducts.length === 0) {
			alert('No matching products to update');
			return;
		}

		loading = true;

		try {
			// Update each matched product
			const updatePromises = matchedProducts.map(item =>
				supabase
					.from('products')
					.update({
						sale_price: item.sale_price,
						cost: item.cost,
						current_stock: item.current_stock,
						minim_qty: item.minim_qty,
						minimum_qty_alert: item.minimum_qty_alert,
						maximum_qty: item.maximum_qty
					})
					.eq('barcode', item.barcode)
			);

			const results = await Promise.all(updatePromises);

			// Check for errors
			const errors = results.filter(r => r.error);
			if (errors.length > 0) {
				throw new Error(`Failed to update ${errors.length} products`);
			}

			alert(`Successfully updated ${matchedProducts.length} products from Excel`);

			// Reset and reload
			showImportPreview = false;
			importedData = [];
			await loadProducts();
		} catch (err) {
			console.error('Error applying import updates:', err);
			alert('Failed to apply updates: ' + (err instanceof Error ? err.message : String(err)));
		} finally {
			loading = false;
		}
	}

	function cancelImport() {
		showImportPreview = false;
		importedData = [];
	}

	async function enableAll() {
		const targets = filteredProducts.filter(p => !p.is_customer_product);
		if (targets.length === 0) return;
		if (!confirm(isRTL ? `تفعيل ${targets.length} منتج؟` : `Enable ${targets.length} products?`)) return;
		bulkUpdating = true;
		try {
			const barcodes = targets.map(p => p.barcode);
			const { data, error } = await supabase.rpc('bulk_toggle_customer_product', {
				p_barcodes: barcodes,
				p_value: true
			});
			if (error) {
				alert('Failed: ' + error.message);
			} else {
				targets.forEach(p => p.is_customer_product = true);
				products = products;
			}
		} catch (err) {
			alert('Exception: ' + (err instanceof Error ? err.message : String(err)));
		} finally {
			bulkUpdating = false;
		}
	}

	async function disableAll() {
		const targets = filteredProducts.filter(p => p.is_customer_product);
		if (targets.length === 0) return;
		if (!confirm(isRTL ? `تعطيل ${targets.length} منتج؟` : `Disable ${targets.length} products?`)) return;
		bulkUpdating = true;
		try {
			const barcodes = targets.map(p => p.barcode);
			const { data, error } = await supabase.rpc('bulk_toggle_customer_product', {
				p_barcodes: barcodes,
				p_value: false
			});
			if (error) {
				alert('Failed: ' + error.message);
			} else {
				targets.forEach(p => p.is_customer_product = false);
				products = products;
			}
		} catch (err) {
			alert('Exception: ' + (err instanceof Error ? err.message : String(err)));
		} finally {
			bulkUpdating = false;
		}
	}

	function handleScanKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			// Already reactive, just keep focus
			e.preventDefault();
		}
	}

	function openEdit(product: any) {
		editingProduct = product;
		editForm = {
			product_name_en: product.product_name_en || '',
			product_name_ar: product.product_name_ar || '',
			sale_price: product.sale_price ?? 0,
			cost: product.cost ?? 0,
			current_stock: product.current_stock ?? 0,
			minim_qty: product.minim_qty ?? 0,
			minimum_qty_alert: product.minimum_qty_alert ?? 0,
			maximum_qty: product.maximum_qty ?? 0
		};
	}

	function cancelEdit() {
		editingProduct = null;
	}

	async function saveProduct() {
		if (!editingProduct) return;
		saving = true;

		try {
			const { error } = await supabase
				.from('products')
				.update({
					product_name_en: editForm.product_name_en,
					product_name_ar: editForm.product_name_ar,
					sale_price: Number(editForm.sale_price),
					cost: Number(editForm.cost),
					current_stock: Number(editForm.current_stock),
					minim_qty: Number(editForm.minim_qty),
					minimum_qty_alert: Number(editForm.minimum_qty_alert),
					maximum_qty: Number(editForm.maximum_qty)
				})
				.eq('barcode', editingProduct.barcode);

			if (error) {
				console.error('Error saving product:', error);
				alert('Failed to save: ' + error.message);
			} else {
				// Update local state
				Object.assign(editingProduct, {
					product_name_en: editForm.product_name_en,
					product_name_ar: editForm.product_name_ar,
					sale_price: Number(editForm.sale_price),
					cost: Number(editForm.cost),
					current_stock: Number(editForm.current_stock),
					minim_qty: Number(editForm.minim_qty),
					minimum_qty_alert: Number(editForm.minimum_qty_alert),
					maximum_qty: Number(editForm.maximum_qty)
				});
				products = products; // Trigger reactivity
				editingProduct = null;
			}
		} catch (err) {
			console.error('Exception saving product:', err);
			alert('Exception occurred during save');
		} finally {
			saving = false;
		}
	}
</script>

<!-- svelte-ignore a11y-click-events-have-key-events -->
<div class="relative flex flex-col h-full overflow-hidden" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Decorative Blur Orbs -->
	<div class="pointer-events-none absolute -top-32 -right-32 h-96 w-96 rounded-full bg-blue-400/20 blur-3xl"></div>
	<div class="pointer-events-none absolute -bottom-32 -left-32 h-96 w-96 rounded-full bg-indigo-400/20 blur-3xl"></div>

	<!-- Header -->
	<div class="relative flex-shrink-0 bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-5 text-white">
		<div class="flex items-center justify-between flex-wrap gap-3">
			<div class="flex items-center gap-4">
				<h2 class="m-0 text-xl font-bold tracking-tight">
					📦 {isRTL ? 'إدارة المنتجات' : 'Products'}
				</h2>
				<div class="flex items-center gap-2">
					<span class="rounded-full bg-white/20 px-3 py-1 text-xs font-medium backdrop-blur-sm">
						{isRTL ? 'الإجمالي:' : 'Total:'} {totalProducts}
					</span>
					{#if searchQuery || scanBarcode}
						<span class="rounded-full bg-yellow-400/30 px-3 py-1 text-xs font-medium backdrop-blur-sm">
							{isRTL ? 'نتائج:' : 'Showing:'} {filteredProducts.length}
						</span>
					{/if}
				</div>
			</div>
			<div class="flex items-center gap-2">
				<button on:click={exportToExcel} disabled={loading || products.length === 0}
					title={isRTL ? 'تصدير إلى Excel' : 'Export all products to Excel'}
					class="inline-flex items-center gap-1.5 rounded-xl bg-white/20 backdrop-blur-sm px-4 py-2 text-sm font-semibold text-white transition-all hover:bg-white/30 hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
					📥 {isRTL ? 'تصدير Excel' : 'Export Excel'}
				</button>
				<label class="inline-flex items-center gap-1.5 rounded-xl bg-white/20 backdrop-blur-sm px-4 py-2 text-sm font-semibold text-white transition-all hover:bg-white/30 hover:-translate-y-0.5 cursor-pointer"
					title={isRTL ? 'استيراد من Excel' : 'Import products from Excel'}>
					📤 {isRTL ? 'استيراد Excel' : 'Import Excel'}
					<input type="file" accept=".xlsx,.xls" on:change={handleImportFile} class="hidden" />
				</label>
			</div>
		</div>
	</div>

	<!-- Search / Scan / Bulk Actions Bar -->
	<div class="relative flex-shrink-0 flex items-center gap-3 flex-wrap px-4 py-3 bg-white/40 backdrop-blur-md border-b border-white/30">
		<!-- Search by Name -->
		<div class="relative flex-1 min-w-[180px] max-w-xs">
			<span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
			<input type="text" bind:value={searchQuery}
				placeholder={isRTL ? 'بحث بالاسم...' : 'Search by name...'}
				class="w-full rounded-xl border border-slate-300 bg-white/80 pl-9 pr-3 py-2 text-sm text-slate-700 shadow-sm placeholder:text-slate-400 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all" />
		</div>
		<!-- Scan Barcode -->
		<div class="relative min-w-[160px] max-w-[200px]">
			<span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">📷</span>
			<input type="text" bind:value={scanBarcode} on:keydown={handleScanKeydown}
				placeholder={isRTL ? 'مسح الباركود...' : 'Scan barcode...'}
				class="w-full rounded-xl border border-slate-300 bg-white/80 pl-9 pr-3 py-2 text-sm text-slate-700 shadow-sm placeholder:text-slate-400 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
		</div>
		<!-- Clear -->
		{#if searchQuery || scanBarcode}
			<button type="button" on:click={() => { searchQuery = ''; scanBarcode = ''; }}
				class="rounded-xl border border-slate-300 bg-white/80 px-3 py-2 text-sm text-slate-500 transition-all hover:bg-slate-100">
				✕ {isRTL ? 'مسح' : 'Clear'}
			</button>
		{/if}
		<!-- Spacer -->
		<div class="flex-1"></div>
		<!-- Enable All / Disable All -->
		<button type="button" on:click={enableAll} disabled={bulkUpdating || loading}
			class="inline-flex items-center gap-1.5 rounded-xl bg-emerald-500 px-4 py-2 text-sm font-semibold text-white shadow-md shadow-emerald-500/20 transition-all hover:bg-emerald-600 hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
			✅ {isRTL ? 'تفعيل الكل' : 'Enable All'}
		</button>
		<button type="button" on:click={disableAll} disabled={bulkUpdating || loading}
			class="inline-flex items-center gap-1.5 rounded-xl bg-red-500 px-4 py-2 text-sm font-semibold text-white shadow-md shadow-red-500/20 transition-all hover:bg-red-600 hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
			🚫 {isRTL ? 'تعطيل الكل' : 'Disable All'}
		</button>
	</div>

	<!-- Content -->
	<div class="relative flex-1 flex flex-col overflow-hidden p-4">
		{#if loading}
			<div class="flex flex-1 flex-col items-center justify-center gap-4">
				<div class="h-10 w-10 animate-spin rounded-full border-4 border-slate-200 border-t-blue-500"></div>
				<p class="text-sm text-slate-500">{isRTL ? 'جاري تحميل المنتجات...' : 'Loading products...'}</p>
			</div>
		{:else if filteredProducts.length === 0}
			<div class="flex flex-1 flex-col items-center justify-center gap-3">
				<div class="text-5xl">{searchQuery || scanBarcode ? '🔍' : '📦'}</div>
				<p class="text-base text-slate-500">{searchQuery || scanBarcode ? (isRTL ? 'لا توجد نتائج' : 'No results found') : (isRTL ? 'لا توجد منتجات' : 'No products found')}</p>
			</div>
		{:else}
			<!-- Products Table -->
			<div class="flex-1 overflow-hidden rounded-2xl bg-white/60 backdrop-blur-xl border border-white/40 shadow-xl">
				<div class="h-full overflow-auto">
					<table class="w-full border-collapse text-sm">
						<thead class="sticky top-0 z-10">
							<tr class="bg-gradient-to-r from-slate-700 to-slate-800 text-white">
								<th class="px-3 py-3 text-center font-semibold w-[70px]">{isRTL ? 'الصورة' : 'Image'}</th>
								<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'الباركود' : 'Barcode'}</th>
								<th class="px-3 py-3 text-left font-semibold">{isRTL ? 'الاسم (EN)' : 'Name (EN)'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'الاسم (AR)' : 'Name (AR)'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'السعر' : 'Price'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'التكلفة' : 'Cost'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'الربح' : 'Profit'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'الربح %' : 'Profit %'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'المخزون' : 'Stock'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'الحد الأدنى' : 'Min'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'تنبيه' : 'Alert'}</th>
								<th class="px-3 py-3 text-right font-semibold">{isRTL ? 'الحد الأقصى' : 'Max'}</th>
								<th class="px-3 py-3 text-center font-semibold w-[80px]">{isRTL ? 'عميل' : 'Customer'}</th>
								<th class="px-3 py-3 text-center font-semibold w-[60px]">{isRTL ? 'تعديل' : 'Edit'}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredProducts as product}
								<tr class="border-b border-slate-100 transition-colors hover:bg-blue-50/40">
									<td class="px-3 py-1.5 text-center">
										{#if product.image_url}
											<button type="button" on:click={() => previewImageUrl = product.image_url}
												class="border-0 bg-transparent p-0 cursor-pointer">
												<img src={product.image_url} alt={product.product_name_en}
													class="h-12 w-12 rounded-md object-contain ring-1 ring-slate-200 hover:ring-blue-400 transition-all" />
											</button>
										{:else}
											<div class="mx-auto flex h-12 w-12 items-center justify-center rounded-md bg-slate-100 text-[10px] text-slate-400">
												No Image
											</div>
										{/if}
									</td>
									<td class="px-3 py-2.5 font-mono text-xs font-medium text-blue-600">{product.barcode}</td>
									<td class="px-3 py-2.5 text-slate-700 max-w-[200px] truncate">{product.product_name_en || '-'}</td>
									<td class="px-3 py-2.5 text-slate-700 max-w-[200px] truncate text-right" dir="rtl">{product.product_name_ar || '-'}</td>
									<td class="px-3 py-2.5 text-right font-mono text-sm font-medium text-slate-700">{product.sale_price.toFixed(2)}</td>
									<td class="px-3 py-2.5 text-right font-mono text-sm text-slate-600">{product.cost.toFixed(2)}</td>
									<td class="px-3 py-2.5 text-right font-mono text-sm font-medium {(product.sale_price - product.cost) >= 0 ? 'text-emerald-600' : 'text-red-500'}">
										{(product.sale_price - product.cost).toFixed(2)}
									</td>
									<td class="px-3 py-2.5 text-right text-sm font-medium {product.cost > 0 && ((product.sale_price - product.cost) / product.cost) * 100 >= 0 ? 'text-emerald-600' : 'text-red-500'}">
										{product.cost > 0 ? (((product.sale_price - product.cost) / product.cost) * 100).toFixed(1) : '0.0'}%
									</td>
									<td class="px-3 py-2.5 text-right font-medium text-slate-700">{product.current_stock}</td>
									<td class="px-3 py-2.5 text-right text-slate-600">{product.minim_qty}</td>
									<td class="px-3 py-2.5 text-right text-slate-600">{product.minimum_qty_alert}</td>
									<td class="px-3 py-2.5 text-right text-slate-600">{product.maximum_qty}</td>
									<td class="px-3 py-2.5 text-center">
										<button
											on:click={() => toggleCustomerProduct(product)}
											disabled={updatingProductId === product.barcode}
											title={product.is_customer_product ? (isRTL ? 'اضغط للتعطيل' : 'Click to disable') : (isRTL ? 'اضغط للتفعيل' : 'Click to enable')}
											class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-300 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed {product.is_customer_product ? 'bg-emerald-500 shadow-sm shadow-emerald-500/40' : 'bg-slate-300'}">
											<span class="inline-block h-5 w-5 rounded-full bg-white shadow-md transition-transform duration-300 {product.is_customer_product ? 'translate-x-5.5' : 'translate-x-0.5'}"></span>
										</button>
									</td>
									<td class="px-3 py-2.5 text-center">
										<button type="button" on:click={() => openEdit(product)}
											title={isRTL ? 'تعديل' : 'Edit'}
											class="inline-flex h-8 w-8 items-center justify-center rounded-lg bg-blue-100 text-blue-600 transition-all hover:bg-blue-200 hover:scale-110">
											✏️
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>


		{/if}
	</div>
</div>

<!-- Import Preview Modal -->
{#if showImportPreview}
	<!-- svelte-ignore a11y-no-static-element-interactions a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/60 backdrop-blur-sm"
		on:click={cancelImport}>
		<!-- svelte-ignore a11y-no-static-element-interactions a11y-click-events-have-key-events a11y-interactive-supports-focus -->
		<div class="flex flex-col overflow-hidden rounded-2xl bg-white/95 backdrop-blur-xl shadow-2xl border border-white/40 w-[90vw] max-w-5xl max-h-[85vh]"
			on:click|stopPropagation role="dialog" aria-modal="true" tabindex="-1">
			<!-- Modal Header -->
			<div class="flex-shrink-0 flex items-center justify-between bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4 text-white">
				<h3 class="m-0 text-lg font-bold">
					📄 {isRTL ? 'معاينة الاستيراد' : 'Import Preview'}
				</h3>
				<button type="button" on:click={cancelImport}
					class="flex h-8 w-8 items-center justify-center rounded-lg bg-white/20 text-white text-lg font-bold transition-all hover:bg-white/30"
					aria-label="Close">✕</button>
			</div>

			<!-- Stats Bar -->
			<div class="flex-shrink-0 flex items-center gap-4 px-6 py-3 bg-slate-50/80 border-b border-slate-200">
				<div class="inline-flex items-center gap-2 rounded-lg bg-emerald-100 px-4 py-2 text-emerald-800">
					<span class="text-sm font-medium">{isRTL ? 'متطابقة:' : 'Matched:'}</span>
					<span class="text-lg font-bold">{importStats.matched}</span>
				</div>
				<div class="inline-flex items-center gap-2 rounded-lg bg-red-100 px-4 py-2 text-red-800">
					<span class="text-sm font-medium">{isRTL ? 'غير متطابقة:' : 'Unmatched:'}</span>
					<span class="text-lg font-bold">{importStats.unmatched}</span>
				</div>
			</div>

			<!-- Preview Table -->
			<div class="flex-1 overflow-auto">
				<table class="w-full border-collapse text-sm">
					<thead class="sticky top-0 z-10">
						<tr class="bg-gradient-to-r from-slate-600 to-slate-700 text-white">
							<th class="px-3 py-2.5 text-center font-semibold">{isRTL ? 'الحالة' : 'Status'}</th>
							<th class="px-3 py-2.5 text-left font-semibold">{isRTL ? 'الباركود' : 'Barcode'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'السعر' : 'Price'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'التكلفة' : 'Cost'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'الربح' : 'Profit'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'الربح %' : 'Profit %'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'المخزون' : 'Stock'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'الحد الأدنى' : 'Min'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'تنبيه' : 'Alert'}</th>
							<th class="px-3 py-2.5 text-right font-semibold">{isRTL ? 'الحد الأقصى' : 'Max'}</th>
						</tr>
					</thead>
					<tbody>
						{#each importedData as item}
							<tr class="border-b border-slate-100 {item.matched ? 'bg-emerald-50/50' : 'bg-red-50/50 opacity-70'}">
								<td class="px-3 py-2.5 text-center">
									<span class="inline-flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold text-white {item.matched ? 'bg-emerald-500' : 'bg-red-500'}">
										{item.matched ? '✓' : '✗'}
									</span>
								</td>
								<td class="px-3 py-2.5 font-mono text-xs font-medium text-blue-600">{item.barcode}</td>
								<td class="px-3 py-2.5 text-right font-mono">{item.sale_price.toFixed(2)}</td>
								<td class="px-3 py-2.5 text-right font-mono">{item.cost.toFixed(2)}</td>
								<td class="px-3 py-2.5 text-right font-mono">{item.profit.toFixed(2)}</td>
								<td class="px-3 py-2.5 text-right">{item.profitPercent.toFixed(1)}%</td>
								<td class="px-3 py-2.5 text-right">{item.current_stock}</td>
								<td class="px-3 py-2.5 text-right">{item.minim_qty}</td>
								<td class="px-3 py-2.5 text-right">{item.minimum_qty_alert}</td>
								<td class="px-3 py-2.5 text-right">{item.maximum_qty}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			<!-- Modal Actions -->
			<div class="flex-shrink-0 flex items-center justify-end gap-3 px-6 py-4 border-t border-slate-200 bg-white/80">
				<button type="button" on:click={cancelImport}
					class="rounded-xl border border-slate-300 bg-white/80 px-5 py-2.5 text-sm font-medium text-slate-500 transition-all hover:bg-slate-100">
					{isRTL ? 'إلغاء' : 'Cancel'}
				</button>
				<button type="button" on:click={applyImportUpdates} disabled={importStats.matched === 0}
					class="rounded-xl bg-gradient-to-r from-emerald-500 to-green-500 px-6 py-2.5 text-sm font-semibold text-white shadow-lg shadow-emerald-500/25 transition-all hover:shadow-xl hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
					{isRTL ? 'تطبيق التحديثات' : 'Apply Updates'} ({importStats.matched})
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit Product Modal -->
{#if editingProduct}
	<!-- svelte-ignore a11y-no-static-element-interactions a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/60 backdrop-blur-sm"
		on:click={cancelEdit}>
		<!-- svelte-ignore a11y-no-static-element-interactions a11y-click-events-have-key-events a11y-interactive-supports-focus -->
		<div class="flex flex-col overflow-hidden rounded-2xl bg-white/95 backdrop-blur-xl shadow-2xl border border-white/40 w-[90vw] max-w-lg max-h-[85vh]"
			on:click|stopPropagation role="dialog" aria-modal="true" tabindex="-1">
			<!-- Modal Header -->
			<div class="flex-shrink-0 flex items-center justify-between bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4 text-white">
				<div>
					<h3 class="m-0 text-lg font-bold">✏️ {isRTL ? 'تعديل المنتج' : 'Edit Product'}</h3>
					<p class="m-0 mt-0.5 text-xs text-white/70 font-mono">{editingProduct.barcode}</p>
				</div>
				<button type="button" on:click={cancelEdit}
					class="flex h-8 w-8 items-center justify-center rounded-lg bg-white/20 text-white text-lg font-bold transition-all hover:bg-white/30"
					aria-label="Close">✕</button>
			</div>

			<!-- Form -->
			<div class="flex-1 overflow-auto p-6 space-y-4">
				<!-- Names -->
				<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'الاسم (EN)' : 'Name (EN)'}</span>
						<input type="text" bind:value={editForm.product_name_en}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all" />
					</label>
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'الاسم (AR)' : 'Name (AR)'}</span>
						<input type="text" bind:value={editForm.product_name_ar} dir="rtl"
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all" />
					</label>
				</div>

				<!-- Price & Cost -->
				<div class="grid grid-cols-2 gap-4">
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'السعر' : 'Price'}</span>
						<input type="number" step="0.01" bind:value={editForm.sale_price}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
					</label>
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'التكلفة' : 'Cost'}</span>
						<input type="number" step="0.01" bind:value={editForm.cost}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
					</label>
				</div>

				<!-- Profit Preview -->
				<div class="rounded-xl bg-slate-50 border border-slate-200 px-4 py-3 flex items-center justify-between">
					<span class="text-xs font-semibold text-slate-500 uppercase">{isRTL ? 'الربح' : 'Profit'}</span>
					<div class="flex items-center gap-3">
						<span class="font-mono text-sm font-semibold {(Number(editForm.sale_price) - Number(editForm.cost)) >= 0 ? 'text-emerald-600' : 'text-red-500'}">{(Number(editForm.sale_price) - Number(editForm.cost)).toFixed(2)}</span>
						<span class="text-sm font-medium {(Number(editForm.sale_price) - Number(editForm.cost)) >= 0 ? 'text-emerald-600' : 'text-red-500'}">({Number(editForm.cost) > 0 ? (((Number(editForm.sale_price) - Number(editForm.cost)) / Number(editForm.cost)) * 100).toFixed(1) : '0.0'}%)</span>
					</div>
				</div>

				<!-- Stock Fields -->
				<div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'المخزون' : 'Stock'}</span>
						<input type="number" bind:value={editForm.current_stock}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
					</label>
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'الحد الأدنى' : 'Min'}</span>
						<input type="number" bind:value={editForm.minim_qty}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
					</label>
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'تنبيه' : 'Alert'}</span>
						<input type="number" bind:value={editForm.minimum_qty_alert}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
					</label>
					<label class="block">
						<span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">{isRTL ? 'الحد الأقصى' : 'Max'}</span>
						<input type="number" bind:value={editForm.maximum_qty}
							class="mt-1 block w-full rounded-xl border border-slate-300 bg-white/80 px-3 py-2.5 text-sm text-slate-700 shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 focus:outline-none transition-all font-mono" />
					</label>
				</div>
			</div>

			<!-- Modal Actions -->
			<div class="flex-shrink-0 flex items-center justify-end gap-3 px-6 py-4 border-t border-slate-200 bg-white/80">
				<button type="button" on:click={cancelEdit}
					class="rounded-xl border border-slate-300 bg-white/80 px-5 py-2.5 text-sm font-medium text-slate-500 transition-all hover:bg-slate-100">
					{isRTL ? 'إلغاء' : 'Cancel'}
				</button>
				<button type="button" on:click={saveProduct} disabled={saving}
					class="rounded-xl bg-gradient-to-r from-blue-500 to-indigo-500 px-6 py-2.5 text-sm font-semibold text-white shadow-lg shadow-blue-500/25 transition-all hover:shadow-xl hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0">
					{#if saving}
						<span class="inline-flex items-center gap-2">
							<span class="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white"></span>
							{isRTL ? 'جاري الحفظ...' : 'Saving...'}
						</span>
					{:else}
						💾 {isRTL ? 'حفظ' : 'Save'}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Image Preview Overlay -->
{#if previewImageUrl}
	<button type="button" class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm border-0 p-0 cursor-default"
		on:click={() => previewImageUrl = null} aria-label="Close preview">
		<img src={previewImageUrl} alt="Preview" class="max-h-[85vh] max-w-[85vw] rounded-2xl shadow-2xl object-contain" />
	</button>
{/if}

<style>
	/* Tailwind handles all styling */
	.translate-x-5\.5 { transform: translateX(1.375rem); }
	.translate-x-0\.5 { transform: translateX(0.125rem); }
</style>
