<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface OfferName {
		id: string;
		name_en: string;
		name_ar: string | null;
	}

	interface FlyerOffer {
		id: string;
		template_id: string;
		template_name: string;
		start_date: string;
		end_date: string;
		is_active: boolean;
		offer_name: OfferName | null;
	}

	interface BranchErp {
		branch_id: number;
		branch_name_en: string;
		branch_name_ar: string;
		location_en: string;
		location_ar: string;
		tunnel_url: string;
		erp_branch_id: number | null;
	}

	interface BranchPriceData {
		cost: number | null;
		salesPrice: number | null;
		unitName: string | null;
	}

	interface ProductRow {
		barcode: string;
		product_name_en: string;
		product_name_ar: string;
		branchData: Record<number, BranchPriceData>;  // keyed by branch_id
		comparedOverrides?: { cost?: number; salesPrice?: number };
	}

	let supabase: any = null;
	let activeOffers: FlyerOffer[] = [];
	let selectedOfferId: string = '';
	let loadingOffers = false;

	// Price Comparison state
	let branches: BranchErp[] = [];
	let selectedBranchIds: Set<number> = new Set();
	let showBranchDropdown = false;
	let productRows: ProductRow[] = [];
	let loadingProducts = false;
	let loadingBranchPrices: Record<number, boolean> = {};
	let showComparison = false;

	// VAT percentage
	let vatPercentage = 15;

	// Send state
	let sendingRows: Set<number> = new Set();
	let sentRows: Set<number> = new Set();
	let sendingAll = false;

	// Search state
	let searchBarcode = '';
	let searchName = '';
	let searchingBarcode = false;
	let searchingName = false;

	// Inline editing state for Compared Prices
	let editingCell: { rowIdx: number; field: 'cost' | 'salesPrice' } | null = null;
	let editValue = '';

	$: selectedBranches = branches.filter(b => selectedBranchIds.has(b.branch_id));
	$: canLoad = selectedOfferId && selectedBranchIds.size > 0;

	function toggleBranch(branchId: number) {
		if (selectedBranchIds.has(branchId)) {
			selectedBranchIds.delete(branchId);
		} else {
			selectedBranchIds.add(branchId);
		}
		selectedBranchIds = new Set(selectedBranchIds); // trigger reactivity
	}

	function toggleAllBranches() {
		if (selectedBranchIds.size === branches.length) {
			selectedBranchIds = new Set();
		} else {
			selectedBranchIds = new Set(branches.map(b => b.branch_id));
		}
	}

	function closeBranchDropdown(e: MouseEvent) {
		const target = e.target as HTMLElement;
		if (!target.closest('.branch-dropdown-container')) {
			showBranchDropdown = false;
		}
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr + 'T00:00:00');
		const day = String(d.getDate()).padStart(2, '0');
		const month = String(d.getMonth() + 1).padStart(2, '0');
		const year = d.getFullYear();
		return `${day}/${month}/${year}`;
	}

	function getOfferDisplayName(offer: FlyerOffer): string {
		const name = $locale === 'ar'
			? (offer.offer_name?.name_ar || offer.offer_name?.name_en || offer.template_name)
			: (offer.offer_name?.name_en || offer.template_name);
		return `${name}  ·  ${formatDate(offer.start_date)} → ${formatDate(offer.end_date)}`;
	}

	async function loadActiveOffers() {
		loadingOffers = true;
		try {
			const { data, error } = await supabase
				.from('flyer_offers')
				.select(`
					id, template_id, template_name, start_date, end_date, is_active,
					offer_name:offer_names(id, name_en, name_ar)
				`)
				.eq('is_active', true)
				.order('start_date', { ascending: false });

			if (error) {
				console.error('Error loading active offers:', error);
			} else {
				activeOffers = data || [];
			}
		} catch (err) {
			console.error('Error loading active offers:', err);
		} finally {
			loadingOffers = false;
		}
	}

	async function loadBranches() {
		try {
			// Get active ERP connections
			const { data: erpConns, error: erpErr } = await supabase
				.from('erp_connections')
				.select('branch_id, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_id');

			if (erpErr || !erpConns || erpConns.length === 0) {
				console.error('Error loading ERP connections:', erpErr);
				return;
			}

			// Get branch names
			const branchIds = erpConns.map((c: any) => c.branch_id);
			const { data: branchData, error: brErr } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.in('id', branchIds);

			if (brErr) {
				console.error('Error loading branches:', brErr);
				return;
			}

			const branchMap = new Map((branchData || []).map((b: any) => [Number(b.id), b]));

			branches = erpConns
				.filter((c: any) => c.tunnel_url)
				.map((c: any) => {
					const info = branchMap.get(Number(c.branch_id)) as {name_en?: string; name_ar?: string; location_en?: string; location_ar?: string} | undefined;
					return {
						branch_id: c.branch_id,
						branch_name_en: info?.name_en || `Branch ${c.branch_id}`,
						branch_name_ar: info?.name_ar || `فرع ${c.branch_id}`,
						location_en: info?.location_en || '',
						location_ar: info?.location_ar || '',
						tunnel_url: c.tunnel_url,
						erp_branch_id: c.erp_branch_id
					};
				});
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadOfferProducts() {
		if (!selectedOfferId) return;
		loadingProducts = true;
		showComparison = true;
		productRows = [];

		try {
			// 1. Load flyer_offer_products for the selected offer
			const { data: offerProducts, error: opErr } = await supabase
				.from('flyer_offer_products')
				.select('product_barcode')
				.eq('offer_id', selectedOfferId)
				.order('page_number', { ascending: true })
				.order('page_order', { ascending: true });

			if (opErr || !offerProducts || offerProducts.length === 0) {
				console.error('Error loading offer products:', opErr);
				loadingProducts = false;
				return;
			}

			const barcodes = offerProducts.map((p: any) => p.product_barcode);

			// 2. Load product names from products table
			const { data: products, error: pErr } = await supabase
				.from('products')
				.select('barcode, product_name_en, product_name_ar')
				.in('barcode', barcodes);

			if (pErr) {
				console.error('Error loading products:', pErr);
			}

			const productMap = new Map((products || []).map((p: any) => [p.barcode, p]));

			// 3. Build product rows
			productRows = barcodes.map((bc: string) => {
				const prod = productMap.get(bc) as {product_name_en?: string; product_name_ar?: string} | undefined;
				return {
					barcode: bc,
					product_name_en: prod?.product_name_en || '',
					product_name_ar: prod?.product_name_ar || '',
					branchData: {}
				};
			});

			loadingProducts = false;

			// 4. Fetch ERP prices for each branch in parallel
			await fetchAllBranchPrices(barcodes);
		} catch (err) {
			console.error('Error loading offer products:', err);
			loadingProducts = false;
		}
	}

	async function fetchAllBranchPrices(barcodes: string[]) {
		if (barcodes.length === 0 || selectedBranches.length === 0) return;

		// Build IN clause for SQL
		const barcodeList = barcodes.map(bc => `'${bc.replace(/'/g, "''")}'`).join(',');

		// Query that searches barcodes across all ERP barcode locations:
		// 1. ProductUnits.BarCode (primary)
		// 2. ProductBatches.MannualBarcode (manual entry)
		// 3. ProductBatches.AutoBarcode (auto-generated, integer → CAST)
		// 4. ProductBatches.Unit2Barcode, Unit3Barcode (alternate units)
		// 5. ProductBarcodes.Barcode (extra barcodes table)
		// Note: No MultiFactor filter — the scanned barcode IS the unit we want
		// Build per-branch SQL with BranchID filter
		const buildSql = (erpBranchId: number | null) => {
			const branchFilter = erpBranchId != null ? `AND pb.BranchID = ${erpBranchId}` : '';
			return `
			SELECT SearchBarcode, Sprice, Cost AS LandingCost, UnitName
			FROM (
				SELECT SearchBarcode, Sprice, Cost, UnitName,
					ROW_NUMBER() OVER (PARTITION BY SearchBarcode ORDER BY BatchID DESC, CASE WHEN Sprice > 0 THEN 0 ELSE 1 END, Sprice ASC) AS rn
				FROM (
					SELECT pu.BarCode AS SearchBarcode,
						pu.Sprice,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) * pu.MultiFactor AS Cost,
						pb.ProductBatchID AS BatchID,
						(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um WHERE um.UnitID = pu.UnitID) AS UnitName
					FROM ProductUnits pu
					INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID
					WHERE pu.BarCode IN (${barcodeList}) ${branchFilter}

					UNION ALL

					SELECT pb.MannualBarcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdSalesPrice, 0), (SELECT TOP 1 pu2.Sprice FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.Sprice > 0 ORDER BY pu2.MultiFactor)) AS Sprice,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						pb.ProductBatchID AS BatchID,
						(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um INNER JOIN ProductUnits pu4 ON pu4.UnitID = um.UnitID WHERE pu4.ProductBatchID = pb.ProductBatchID ORDER BY pu4.MultiFactor ASC) AS UnitName
					FROM ProductBatches pb
					WHERE pb.MannualBarcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BarCode IN (${barcodeList}))

					UNION ALL

					SELECT CAST(pb.AutoBarcode AS NVARCHAR(100)) AS SearchBarcode,
						(SELECT TOP 1 pu2.Sprice FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.Sprice > 0 ORDER BY pu2.MultiFactor) AS Sprice,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						pb.ProductBatchID AS BatchID,
						(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um INNER JOIN ProductUnits pu4 ON pu4.UnitID = um.UnitID WHERE pu4.ProductBatchID = pb.ProductBatchID ORDER BY pu4.MultiFactor ASC) AS UnitName
					FROM ProductBatches pb
					WHERE CAST(pb.AutoBarcode AS NVARCHAR(100)) IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))

					UNION ALL

					SELECT pb.Unit2Barcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdSalesPrice, 0), (SELECT TOP 1 pu2.Sprice FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.Sprice > 0 ORDER BY pu2.MultiFactor)) AS Sprice,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						pb.ProductBatchID AS BatchID,
						(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um INNER JOIN ProductUnits pu4 ON pu4.UnitID = um.UnitID WHERE pu4.ProductBatchID = pb.ProductBatchID ORDER BY pu4.MultiFactor ASC) AS UnitName
					FROM ProductBatches pb
					WHERE pb.Unit2Barcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))
					AND (CAST(pb.AutoBarcode AS NVARCHAR(100)) IS NULL OR CAST(pb.AutoBarcode AS NVARCHAR(100)) NOT IN (${barcodeList}))

					UNION ALL

					SELECT pb.Unit3Barcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdSalesPrice, 0), (SELECT TOP 1 pu2.Sprice FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.Sprice > 0 ORDER BY pu2.MultiFactor)) AS Sprice,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						pb.ProductBatchID AS BatchID,
						(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um INNER JOIN ProductUnits pu4 ON pu4.UnitID = um.UnitID WHERE pu4.ProductBatchID = pb.ProductBatchID ORDER BY pu4.MultiFactor ASC) AS UnitName
					FROM ProductBatches pb
					WHERE pb.Unit3Barcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))
					AND (CAST(pb.AutoBarcode AS NVARCHAR(100)) IS NULL OR CAST(pb.AutoBarcode AS NVARCHAR(100)) NOT IN (${barcodeList}))
					AND (pb.Unit2Barcode IS NULL OR pb.Unit2Barcode NOT IN (${barcodeList}))

					UNION ALL

					SELECT pbc.Barcode AS SearchBarcode,
						COALESCE((SELECT TOP 1 NULLIF(pb2.StdSalesPrice, 0) FROM ProductBatches pb2 WHERE pb2.ProductBatchID = pbc.ProductBatchID ${branchFilter.replace('pb.', 'pb2.')}),
							(SELECT TOP 1 pu2.Sprice FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pbc.ProductBatchID AND pu2.Sprice > 0 ORDER BY pu2.MultiFactor)) AS Sprice,
						(SELECT TOP 1 COALESCE(NULLIF(pb2.StdPurchasePrice, 0), NULLIF(pb2.LastPurchaseCost, 0), NULLIF(pb2.LandingCost, 0), NULLIF(pb2.AvgPurchaseCost, 0), 0) FROM ProductBatches pb2 WHERE pb2.ProductBatchID = pbc.ProductBatchID ${branchFilter.replace('pb.', 'pb2.')}) AS Cost,
						pbc.ProductBatchID AS BatchID,
						(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um INNER JOIN ProductUnits pu4 ON pu4.UnitID = um.UnitID WHERE pu4.ProductBatchID = pbc.ProductBatchID ORDER BY pu4.MultiFactor ASC) AS UnitName
					FROM ProductBarcodes pbc
					WHERE pbc.Barcode IN (${barcodeList})
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pbc.ProductBatchID AND pu3.BarCode IN (${barcodeList}))
				) AS Combined
			) AS Ranked
			WHERE rn = 1
		`;
		};

		// Set all selected branches to loading
		selectedBranches.forEach(b => {
			loadingBranchPrices[b.branch_id] = true;
		});
		loadingBranchPrices = { ...loadingBranchPrices };

		// Fetch in parallel for all selected branches
		const promises = selectedBranches.map(async (branch) => {
			try {
				const sql = buildSql(branch.erp_branch_id);
				const response = await fetch('/api/erp-products', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						action: 'query',
						tunnelUrl: branch.tunnel_url,
						sql
					})
				});
				const result = await response.json();

				if (result.success && result.recordset) {
					// Map results by barcode
					const priceMap = new Map<string, BranchPriceData>();
					for (const row of result.recordset) {
						priceMap.set(row.SearchBarcode, {
							cost: row.LandingCost ?? null,
							salesPrice: row.Sprice ?? null,
							unitName: row.UnitName ?? null
						});
					}

					// Update productRows
					productRows = productRows.map(pr => {
						const data = priceMap.get(pr.barcode);
						return {
							...pr,
							branchData: {
								...pr.branchData,
								[branch.branch_id]: data || { cost: null, salesPrice: null, unitName: null }
							}
						};
					});
				}
			} catch (err) {
				console.error(`Error fetching prices for branch ${branch.branch_id}:`, err);
			} finally {
				loadingBranchPrices[branch.branch_id] = false;
				loadingBranchPrices = { ...loadingBranchPrices };
			}
		});

		await Promise.all(promises);
	}

	function getBranchName(branch: BranchErp): string {
		return $locale === 'ar' ? branch.branch_name_ar : branch.branch_name_en;
	}

	function getHighestCost(row: ProductRow): number | null {
		let max: number | null = null;
		for (const b of selectedBranches) {
			const bd = row.branchData[b.branch_id];
			const c = bd && bd.cost !== null && bd.cost > 0 ? withVat(bd.cost) : null;
			if (c !== null) {
				if (max === null || c > max) max = c;
			}
		}
		return max;
	}

	function withVat(cost: number): number {
		return cost * (1 + vatPercentage / 100);
	}

	function getHighestSalesPrice(row: ProductRow): number | null {
		let max: number | null = null;
		for (const b of selectedBranches) {
			const bd = row.branchData[b.branch_id];
			if (bd && bd.salesPrice !== null && bd.salesPrice > 0) {
				if (max === null || bd.salesPrice > max) max = bd.salesPrice;
			}
		}
		return max;
	}

	function getUnitName(row: ProductRow): string {
		for (const b of selectedBranches) {
			const bd = row.branchData[b.branch_id];
			if (bd && bd.unitName) return bd.unitName;
		}
		return '—';
	}

	function handlePriceComparisonClick() {
		if (!canLoad) return;
		showBranchDropdown = false;
		loadOfferProducts();
	}

	async function handleSearchByBarcode() {
		const trimmed = searchBarcode.trim();
		if (!trimmed || selectedBranchIds.size === 0) return;
		searchingBarcode = true;
		showComparison = true;
		productRows = [];
		sentRows = new Set();

		try {
			// Search Supabase products table for name info
			const barcodes = trimmed.split(/[,\s]+/).filter(b => b.length > 0);
			const { data: products } = await supabase
				.from('products')
				.select('barcode, product_name_en, product_name_ar')
				.in('barcode', barcodes);

			const productMap = new Map((products || []).map((p: any) => [p.barcode, p]));

			productRows = barcodes.map((bc: string) => {
				const prod = productMap.get(bc) as {product_name_en?: string; product_name_ar?: string} | undefined;
				return {
					barcode: bc,
					product_name_en: prod?.product_name_en || '',
					product_name_ar: prod?.product_name_ar || '',
					branchData: {}
				};
			});

			await fetchAllBranchPrices(barcodes);
		} catch (err) {
			console.error('Error searching by barcode:', err);
		} finally {
			searchingBarcode = false;
		}
	}

	async function handleSearchByName() {
		const trimmed = searchName.trim();
		if (!trimmed || selectedBranchIds.size === 0) return;
		searchingName = true;
		showComparison = true;
		productRows = [];
		sentRows = new Set();

		try {
			// Search Supabase products by name (both EN and AR)
			const { data: products, error } = await supabase
				.from('products')
				.select('barcode, product_name_en, product_name_ar')
				.or(`product_name_en.ilike.%${trimmed}%,product_name_ar.ilike.%${trimmed}%`)
				.limit(100);

			if (error || !products || products.length === 0) {
				console.error('No products found by name:', error);
				searchingName = false;
				return;
			}

			const barcodes = products.map((p: any) => p.barcode);

			productRows = products.map((p: any) => ({
				barcode: p.barcode,
				product_name_en: p.product_name_en || '',
				product_name_ar: p.product_name_ar || '',
				branchData: {}
			}));

			await fetchAllBranchPrices(barcodes);
		} catch (err) {
			console.error('Error searching by name:', err);
		} finally {
			searchingName = false;
		}
	}

	function startEditing(rowIdx: number, field: 'cost' | 'salesPrice', currentValue: number | null) {
		editingCell = { rowIdx, field };
		editValue = currentValue !== null ? currentValue.toFixed(2) : '';
		// Focus input after DOM update
		setTimeout(() => {
			const input = document.querySelector('.compared-edit-input') as HTMLInputElement;
			if (input) { input.focus(); input.select(); }
		}, 0);
	}

	function commitEdit(rowIdx: number, field: 'cost' | 'salesPrice') {
		const parsed = parseFloat(editValue);
		if (!isNaN(parsed) && parsed >= 0) {
			const oldOverrides = productRows[rowIdx].comparedOverrides || {};
			const newOverrides = { ...oldOverrides, [field]: parsed };
			// Create a new row object so Svelte detects the change
			productRows[rowIdx] = { ...productRows[rowIdx], comparedOverrides: newOverrides };
			productRows = productRows;
		}
		editingCell = null;
	}

	function cancelEdit() {
		editingCell = null;
	}

	function getComparedCost(row: ProductRow): number | null {
		if ((row as any).comparedOverrides?.cost !== undefined) return (row as any).comparedOverrides.cost;
		return getHighestCost(row);
	}

	function getComparedSalesPrice(row: ProductRow): number | null {
		if ((row as any).comparedOverrides?.salesPrice !== undefined) return (row as any).comparedOverrides.salesPrice;
		return getHighestSalesPrice(row);
	}

	function needsPriceUpdate(row: ProductRow): boolean {
		const compared = getComparedSalesPrice(row);
		if (compared === null) return false;
		for (const b of selectedBranches) {
			const bd = row.branchData[b.branch_id];
			if (bd && bd.salesPrice !== null && bd.salesPrice !== compared) return true;
		}
		return false;
	}

	async function sendPriceChange(row: ProductRow, idx: number) {
		const comparedPrice = getComparedSalesPrice(row);
		if (comparedPrice === null) return;

		// Find branches that need price update
		const branchesToUpdate: { branch: BranchErp; currentPrice: number }[] = [];
		for (const b of selectedBranches) {
			const bd = row.branchData[b.branch_id];
			if (bd && bd.salesPrice !== null && bd.salesPrice !== comparedPrice) {
				branchesToUpdate.push({ branch: b, currentPrice: bd.salesPrice });
			}
		}
		if (branchesToUpdate.length === 0) return;

		sendingRows.add(idx);
		sendingRows = new Set(sendingRows);

		try {
			// Get inventory manager user IDs for affected branches
			const branchIds = branchesToUpdate.map(b => b.branch.branch_id);
			const { data: positionsData, error: posErr } = await supabase
				.from('branch_default_positions')
				.select('branch_id, inventory_manager_user_id')
				.in('branch_id', branchIds);

			if (posErr) {
				console.error('Error fetching branch positions:', posErr);
				return;
			}

			const posMap = new Map((positionsData || []).map((p: any) => [p.branch_id, p.inventory_manager_user_id]));

			const productName = $locale === 'ar'
				? (row.product_name_ar || row.product_name_en || row.barcode)
				: (row.product_name_en || row.product_name_ar || row.barcode);

			// Build description with all branch price changes
			let descEn = `Sales Price Change Required\n\nBarcode: ${row.barcode}\nProduct: ${row.product_name_en || row.product_name_ar || row.barcode}\nTarget Price: ${comparedPrice.toFixed(2)}\n\n`;
			let descAr = `مطلوب تغيير سعر البيع\n\nباركود: ${row.barcode}\nالمنتج: ${row.product_name_ar || row.product_name_en || row.barcode}\nالسعر المطلوب: ${comparedPrice.toFixed(2)}\n\n`;

			for (const { branch, currentPrice } of branchesToUpdate) {
				const bName = $locale === 'ar' ? branch.branch_name_ar : branch.branch_name_en;
				descEn += `${branch.branch_name_en}: ${currentPrice.toFixed(2)} → ${comparedPrice.toFixed(2)}\n`;
				descAr += `${branch.branch_name_ar}: ${currentPrice.toFixed(2)} → ${comparedPrice.toFixed(2)}\n`;
			}

			const taskTitle = `Price Change | تغيير السعر: ${row.barcode} - ${productName}`;

			// Create quick task
			const { data: taskData, error: taskError } = await supabase
				.from('quick_tasks')
				.insert({
					title: taskTitle,
					description: `${descEn}---\n${descAr}`,
					issue_type: 'price_change',
					priority: 'high',
					assigned_by: $currentUser?.id,
					status: 'pending',
					deadline_datetime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
				})
				.select()
				.single();

			if (taskError) {
				console.error('Error creating quick task:', taskError);
				return;
			}

			// Create assignments for each branch's inventory manager
			const assignments: any[] = [];
			for (const { branch } of branchesToUpdate) {
				const invManagerId = posMap.get(branch.branch_id);
				if (invManagerId) {
					assignments.push({
						quick_task_id: taskData.id,
						assigned_to_user_id: invManagerId,
						require_task_finished: true,
						require_photo_upload: false,
						require_erp_reference: true
					});
				}
			}

			if (assignments.length > 0) {
				// Deduplicate by user ID
				const uniqueAssignments = [...new Map(assignments.map(a => [a.assigned_to_user_id, a])).values()];
				const { error: assignErr } = await supabase
					.from('quick_task_assignments')
					.insert(uniqueAssignments);

				if (assignErr) {
					console.error('Error creating task assignments:', assignErr);
				}
			}

			console.log('✅ Price change task sent:', taskData.id, 'for barcode:', row.barcode);			sentRows.add(idx);
			sentRows = new Set(sentRows);		} catch (err) {
			console.error('Error sending price change:', err);
		} finally {
			sendingRows.delete(idx);
			sendingRows = new Set(sendingRows);
		}
	}

	async function sendAllPriceChanges() {
		const rowsToSend = productRows
			.map((row, idx) => ({ row, idx }))
			.filter(({ row }) => needsPriceUpdate(row));
		if (rowsToSend.length === 0) return;

		sendingAll = true;
		for (const { row, idx } of rowsToSend) {
			await sendPriceChange(row, idx);
		}
		sendingAll = false;
	}

	onMount(async () => {
		const { supabase: client } = await import('$lib/utils/supabase');
		supabase = client;
		await Promise.all([loadActiveOffers(), loadBranches()]);
		// Select all branches by default
		selectedBranchIds = new Set(branches.map(b => b.branch_id));
	});
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'} on:click={closeBranchDropdown}>
	<!-- Header / Action Bar -->
	<div class="bg-white border-b border-slate-200 px-3 py-1.5 flex items-center justify-between shadow-sm gap-2">
		<!-- Left: Offer Selector + Search Inputs -->
		<div class="flex items-center gap-2 flex-1 min-w-0">
			<!-- Offer Selector -->
			<div class="relative flex-1 max-w-xs min-w-[140px]">
				{#if loadingOffers}
					<div class="w-full px-3 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs text-slate-400 flex items-center gap-2">
						<div class="w-3 h-3 border-2 border-slate-300 border-t-emerald-500 rounded-full animate-spin"></div>
						{$t('common.loading')}...
					</div>
				{:else}
					<select
						id="offer-select"
						bind:value={selectedOfferId}
						class="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all appearance-none cursor-pointer font-medium"
						style="color: #000000 !important; background-color: #ffffff !important;"
					>
						<option value="" style="color: #64748b !important;">{$t('stock.selectOffer')}</option>
						{#each activeOffers as offer}
							<option value={offer.id} style="color: #000000 !important;">
								{getOfferDisplayName(offer)}
							</option>
						{/each}
					</select>
					<!-- Custom dropdown arrow -->
					<div class="absolute {$locale === 'ar' ? 'left-3' : 'right-3'} top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
						</svg>
					</div>
				{/if}
			</div>

			<!-- Separator -->
			<div class="h-6 w-px bg-slate-200"></div>

			<!-- Search by Barcode -->
			<div class="relative flex items-center gap-1 min-w-[160px]">
				<input
					type="text"
					bind:value={searchBarcode}
					placeholder={$t('stock.searchByBarcode')}
					class="w-full px-2.5 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all font-mono"
					on:keydown={(e) => { if (e.key === 'Enter') handleSearchByBarcode(); }}
				/>
				<button
					on:click={handleSearchByBarcode}
					disabled={!searchBarcode.trim() || selectedBranchIds.size === 0 || searchingBarcode}
					class="flex items-center gap-1 px-2.5 py-1.5 text-[10px] font-bold rounded-lg transition-all
					{searchBarcode.trim() && selectedBranchIds.size > 0 && !searchingBarcode ? 'bg-violet-600 text-white hover:bg-violet-700' : 'bg-slate-200 text-slate-400 cursor-not-allowed'}"
				>
					{#if searchingBarcode}
						<div class="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin"></div>
					{:else}
						<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
					{/if}
				</button>
			</div>

			<!-- Separator -->
			<div class="h-6 w-px bg-slate-200"></div>

			<!-- Search by Name -->
			<div class="relative flex items-center gap-1 min-w-[180px]">
				<input
					type="text"
					bind:value={searchName}
					placeholder={$t('stock.searchByName')}
					class="w-full px-2.5 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent transition-all"
					on:keydown={(e) => { if (e.key === 'Enter') handleSearchByName(); }}
				/>
				<button
					on:click={handleSearchByName}
					disabled={!searchName.trim() || selectedBranchIds.size === 0 || searchingName}
					class="flex items-center gap-1 px-2.5 py-1.5 text-[10px] font-bold rounded-lg transition-all
					{searchName.trim() && selectedBranchIds.size > 0 && !searchingName ? 'bg-sky-600 text-white hover:bg-sky-700' : 'bg-slate-200 text-slate-400 cursor-not-allowed'}"
				>
					{#if searchingName}
						<div class="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin"></div>
					{:else}
						<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
					{/if}
				</button>
			</div>
		</div>

		<!-- Action Buttons -->
		<div class="flex gap-2 bg-slate-100 p-1 rounded-xl border border-slate-200/50 shadow-inner items-center">
			<!-- Branch Selector Dropdown -->
			<div class="relative branch-dropdown-container">
				<button
					on:click={() => showBranchDropdown = !showBranchDropdown}
					class="group relative flex items-center gap-1.5 px-3 py-1.5 text-[10px] font-black uppercase tracking-wide transition-all duration-300 rounded-lg overflow-hidden
					{branches.length > 0 ? 'bg-slate-600 text-white shadow-lg shadow-slate-200 hover:bg-slate-700' : 'bg-slate-300 text-slate-500 cursor-not-allowed'}"
					disabled={branches.length === 0}
				>
					<span class="text-xs">🏪</span>
					<span class="relative z-10">{$t('stock.selectBranches')}</span>
					{#if selectedBranchIds.size > 0}
						<span class="bg-white/25 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{selectedBranchIds.size}</span>
					{/if}
					<svg class="w-3 h-3 transition-transform {showBranchDropdown ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				<!-- Dropdown panel -->
				{#if showBranchDropdown}
					<div class="absolute top-full mt-2 {$locale === 'ar' ? 'right-0' : 'left-0'} z-50 bg-white rounded-xl border border-slate-200 shadow-2xl min-w-[260px] overflow-hidden">
						<!-- Select All -->
						<label class="flex items-center gap-3 px-4 py-3 hover:bg-slate-50 cursor-pointer border-b border-slate-100 transition-colors">
							<input
								type="checkbox"
								checked={selectedBranchIds.size === branches.length}
								on:change={toggleAllBranches}
								class="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
							/>
							<span class="text-xs font-bold text-slate-700 uppercase tracking-wide">{$t('stock.allBranches')}</span>
							<span class="text-[10px] text-slate-400 {$locale === 'ar' ? 'mr-auto' : 'ml-auto'} font-mono">({branches.length})</span>
						</label>
						<!-- Individual Branches -->
						{#each branches as branch}
							<label class="flex items-center gap-3 px-4 py-2.5 hover:bg-emerald-50/50 cursor-pointer transition-colors">
								<input
									type="checkbox"
									checked={selectedBranchIds.has(branch.branch_id)}
									on:change={() => toggleBranch(branch.branch_id)}
									class="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
								/>
								<div class="flex flex-col">
									<span class="text-xs font-medium text-slate-700">{getBranchName(branch)}</span>
									{#if ($locale === 'ar' ? branch.location_ar : branch.location_en)}
										<span class="text-[10px] text-slate-400">{$locale === 'ar' ? branch.location_ar : branch.location_en}</span>
									{/if}
								</div>
							</label>
						{/each}
						<!-- Footer -->
						<div class="px-4 py-2 border-t border-slate-100 bg-slate-50">
							<span class="text-[10px] text-slate-400 font-semibold">
								{selectedBranchIds.size} {$t('stock.selectedBranches')}
							</span>
						</div>
					</div>
				{/if}
			</div>

			<!-- Load Button -->
			<button
				on:click={handlePriceComparisonClick}
				disabled={!canLoad}
				class="group relative flex items-center gap-1.5 px-4 py-1.5 text-[10px] font-black uppercase tracking-wide transition-all duration-500 rounded-lg overflow-hidden
				{canLoad ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:scale-[1.02]' : 'bg-slate-300 text-slate-500 cursor-not-allowed'}"
			>
				<span class="text-xs filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📊</span>
				<span class="relative z-10">{$t('stock.load')}</span>
			</button>

			<!-- VAT % Input -->
			<div class="flex items-center gap-1 bg-white rounded-lg border border-slate-200 px-2 py-1">
				<span class="text-[10px] font-bold text-slate-600 uppercase">{$t('stock.vat')}</span>
				<input
					type="text"
					inputmode="decimal"
					bind:value={vatPercentage}
					class="w-10 text-center text-xs font-mono font-bold border border-slate-200 rounded px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-emerald-500"
				/>
				<span class="text-[10px] font-bold text-slate-500">%</span>
			</div>

			<!-- Export Excel Button -->
			<button
				class="group relative flex items-center gap-1.5 px-4 py-1.5 text-[10px] font-black uppercase tracking-wide transition-all duration-500 rounded-lg overflow-hidden bg-orange-600 text-white shadow-lg shadow-orange-200 hover:bg-orange-700 hover:scale-[1.02]"
			>
				<span class="text-xs filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📥</span>
				<span class="relative z-10">{$t('stock.exportExcel')}</span>
			</button>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-3 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background elements -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if !showComparison}
				<!-- Empty state -->
				<div class="flex-1 flex items-center justify-center">
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<p class="text-slate-600 font-semibold text-lg">{$t('nav.offerCostManager')}</p>
						<p class="text-slate-400 text-sm mt-2">{$t('stock.selectActionAbove')}</p>
					</div>
				</div>
			{:else if loadingProducts || searchingBarcode || searchingName}
				<!-- Loading state -->
				<div class="flex-1 flex items-center justify-center">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{$t('stock.loadingProducts')}</p>
					</div>
				</div>
			{:else if productRows.length === 0}
				<!-- No products -->
				<div class="flex-1 flex items-center justify-center">
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">{$t('stock.noProductsInOffer')}</p>
					</div>
				</div>
			{:else}
				<!-- Price Comparison Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<div class="overflow-x-auto flex-1">
						<table class="w-full border-collapse">
							<thead class="sticky top-0 z-10">
								<!-- Main header row -->
								<tr class="bg-emerald-600 text-white">
									<th rowspan="2" class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider border-b border-emerald-400 border-x border-emerald-500/30 w-8">#</th>
									<th rowspan="2" class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider border-b border-emerald-400 border-x border-emerald-500/30 w-[100px]">{$t('stock.barcode')}</th>
									<th rowspan="2" class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider border-b border-emerald-400 border-x border-emerald-500/30 min-w-[160px]">{$t('stock.productName')}</th>
							<th rowspan="2" class="px-2 py-1.5 text-center text-[10px] font-black uppercase tracking-wider border-b border-emerald-400 border-x border-emerald-500/30 w-[60px]">{$t('stock.unitName')}</th>
									{#each selectedBranches as branch}
										<th colspan="2" class="px-2 py-1.5 text-center text-[10px] font-black uppercase tracking-wider border-b border-emerald-400 border-x border-emerald-500/30 min-w-[140px]">
											<div class="flex flex-col items-center">
												<div class="flex items-center gap-1">
													<span class="text-xs">🏪</span>
													{getBranchName(branch)}
												</div>
												{#if ($locale === 'ar' ? branch.location_ar : branch.location_en)}
													<span class="text-[9px] opacity-60 font-normal normal-case tracking-normal">{$locale === 'ar' ? branch.location_ar : branch.location_en}</span>
												{/if}
											</div>
											{#if loadingBranchPrices[branch.branch_id]}
												<div class="mt-1 flex items-center justify-center gap-1">
													<div class="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin"></div>
													<span class="text-[10px] opacity-70">{$t('common.loading')}...</span>
												</div>
											{/if}
										</th>
									{/each}
									<th colspan="2" class="px-2 py-1.5 text-center text-[10px] font-black uppercase tracking-wider border-b border-amber-300 border-x border-amber-400/30 min-w-[140px] bg-amber-600 text-white">
										<div class="flex items-center justify-center gap-1">
											<span class="text-xs">📊</span>
											{$t('stock.comparedPrices')}
										</div>
									</th>
									<th rowspan="2" class="px-2 py-1.5 text-center text-[10px] font-black uppercase tracking-wider border-b border-blue-300 border-x border-blue-400/30 w-[80px] bg-blue-600 text-white">
										<div class="flex flex-col items-center gap-1">
											<div class="flex items-center justify-center gap-1">
												<span class="text-xs">📤</span>
												{$t('stock.sendPrice')}
											</div>
											<button
												class="px-2 py-0.5 text-[9px] font-bold rounded transition-colors {sendingAll ? 'bg-white/10 cursor-not-allowed' : 'bg-white/20 hover:bg-white/30'}"
												on:click={sendAllPriceChanges}
												disabled={sendingAll}
											>
												{#if sendingAll}
													<div class="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin inline-block"></div>
												{:else}
													{$t('stock.sendAll')}
												{/if}
											</button>
										</div>
									</th>
								</tr>
								<!-- Sub-header row for Cost / Sales Price -->
								<tr class="bg-emerald-700 text-white">
									{#each selectedBranches as _branch}
										<th class="px-2 py-1 text-center text-[9px] font-bold uppercase tracking-wider border-x border-emerald-600/30">{$t('stock.cost')}</th>
										<th class="px-2 py-1 text-center text-[9px] font-bold uppercase tracking-wider border-x border-emerald-600/30">{$t('stock.salesPrice')}</th>
									{/each}
									<th class="px-2 py-1 text-center text-[9px] font-bold uppercase tracking-wider border-x border-amber-500/30 bg-amber-700 text-white">{$t('stock.cost')}</th>
									<th class="px-2 py-1 text-center text-[9px] font-bold uppercase tracking-wider border-x border-amber-500/30 bg-amber-700 text-white">{$t('stock.salesPrice')}</th>
								</tr>
							</thead>
							<tbody>
								{#each productRows as row, idx}
									<tr class="border-b border-slate-100 hover:bg-emerald-50/30 transition-colors {idx % 2 === 0 ? 'bg-white/60' : 'bg-slate-50/40'}">
										<td class="px-3 py-2.5 text-xs text-slate-400 font-mono border-x border-slate-200">{idx + 1}</td>
										<td class="px-3 py-2.5 text-xs font-mono text-slate-700 font-semibold cursor-pointer select-none border-x border-slate-200" on:dblclick={() => navigator.clipboard.writeText(row.barcode)} title="Double-click to copy">{row.barcode}</td>
										<td class="px-3 py-2.5 text-xs text-slate-800 font-medium border-x border-slate-200">
											{$locale === 'ar' ? (row.product_name_ar || row.product_name_en || '—') : (row.product_name_en || row.product_name_ar || '—')}
										</td>
										<td class="px-3 py-2.5 text-center text-xs text-slate-600 font-medium border-x border-slate-200">{getUnitName(row)}</td>
												{#each selectedBranches as branch}
											{@const bd = row.branchData[branch.branch_id]}
									<td class="px-3 py-2.5 text-center text-xs font-mono border-x border-slate-100 {bd && bd.cost !== null && getComparedCost(row) !== null && bd.cost > 0 && withVat(bd.cost) !== getComparedCost(row) ? (withVat(bd.cost) < getComparedCost(row) ? 'bg-red-50' : 'bg-orange-50') : ''}">
										{#if loadingBranchPrices[branch.branch_id]}
											<div class="w-3 h-3 border-2 border-slate-200 border-t-emerald-500 rounded-full animate-spin mx-auto"></div>
										{:else if bd && bd.cost !== null}
								<span class="{withVat(bd.cost) < (getComparedCost(row) ?? 0) ? 'text-red-600' : withVat(bd.cost) > (getComparedCost(row) ?? 0) ? 'text-orange-600' : 'text-slate-700'} font-semibold">{#if withVat(bd.cost) < (getComparedCost(row) ?? 0)}<span class="mr-1">↓</span>{:else if withVat(bd.cost) > (getComparedCost(row) ?? 0)}<span class="mr-1">↑</span>{/if}{withVat(bd.cost).toFixed(2)}{#if withVat(bd.cost) === getComparedCost(row)} <span class="text-emerald-500 ml-1">✓</span>{/if}</span>
												{:else}
													<span class="text-slate-300">—</span>
												{/if}
											</td>
									<td class="px-3 py-2.5 text-center text-xs font-mono border-x border-slate-100 {bd && bd.salesPrice !== null && getComparedSalesPrice(row) !== null && bd.salesPrice !== getComparedSalesPrice(row) ? (bd.salesPrice < getComparedSalesPrice(row) ? 'bg-yellow-100' : 'bg-yellow-50') : ''}">
										{#if loadingBranchPrices[branch.branch_id]}
											<div class="w-3 h-3 border-2 border-slate-200 border-t-emerald-500 rounded-full animate-spin mx-auto"></div>
										{:else if bd && bd.salesPrice !== null}
								<span class="{bd.salesPrice !== (getComparedSalesPrice(row) ?? 0) ? 'text-yellow-700' : 'text-emerald-700'} font-bold">{#if bd.salesPrice < (getComparedSalesPrice(row) ?? 0)}<span class="mr-1">↓</span>{:else if bd.salesPrice > (getComparedSalesPrice(row) ?? 0)}<span class="mr-1">↑</span>{/if}{bd.salesPrice.toFixed(2)}{#if bd.salesPrice === getComparedSalesPrice(row)} <span class="text-emerald-500 ml-1">✓</span>{/if}</span>
												{:else}
													<span class="text-slate-300">—</span>
												{/if}
											</td>
										{/each}
										<td class="px-3 py-2.5 text-center text-xs font-mono border-x border-amber-100 bg-amber-50/40 cursor-pointer select-none" on:dblclick={() => startEditing(idx, 'cost', getComparedCost(row))}>
											{#if editingCell && editingCell.rowIdx === idx && editingCell.field === 'cost'}
												<input
													type="text"
													inputmode="decimal"
													class="compared-edit-input w-16 px-1 py-0.5 text-xs text-center font-mono border border-amber-400 rounded bg-white focus:outline-none focus:ring-1 focus:ring-amber-500"
													bind:value={editValue}
													on:blur={() => commitEdit(idx, 'cost')}
													on:keydown={(e) => { if (e.key === 'Enter') commitEdit(idx, 'cost'); if (e.key === 'Escape') cancelEdit(); }}
												/>
											{:else if getComparedCost(row) !== null}
												<span class="text-amber-800 font-bold">{getComparedCost(row)?.toFixed(2)}</span>
											{:else}
												<span class="text-slate-300">—</span>
											{/if}
										</td>
										<td class="px-3 py-2.5 text-center text-xs font-mono border-x border-amber-100 bg-amber-50/40 cursor-pointer select-none" on:dblclick={() => startEditing(idx, 'salesPrice', getComparedSalesPrice(row))}>
											{#if editingCell && editingCell.rowIdx === idx && editingCell.field === 'salesPrice'}
												<input
													type="text"
													inputmode="decimal"
													class="compared-edit-input w-16 px-1 py-0.5 text-xs text-center font-mono border border-amber-400 rounded bg-white focus:outline-none focus:ring-1 focus:ring-amber-500"
													bind:value={editValue}
													on:blur={() => commitEdit(idx, 'salesPrice')}
													on:keydown={(e) => { if (e.key === 'Enter') commitEdit(idx, 'salesPrice'); if (e.key === 'Escape') cancelEdit(); }}
												/>
											{:else if getComparedSalesPrice(row) !== null}
												<span class="text-amber-800 font-bold">{getComparedSalesPrice(row)?.toFixed(2)}</span>
											{:else}
												<span class="text-slate-300">—</span>
											{/if}
										</td>
										<td class="px-3 py-2.5 text-center border-x border-blue-100">
											{#if sentRows.has(idx)}
												<span class="text-emerald-500 text-xs font-bold">\u2713</span>
											{:else if needsPriceUpdate(row)}
												<button
													class="px-2.5 py-1 text-[10px] font-bold text-white rounded-lg transition-colors shadow-sm {sendingRows.has(idx) ? 'bg-blue-300 cursor-not-allowed' : 'bg-blue-500 hover:bg-blue-600'}"
													on:click={() => sendPriceChange(row, idx)}
													disabled={sendingRows.has(idx)}
												>
													{#if sendingRows.has(idx)}
														<div class="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin inline-block"></div>
													{:else}
														📤 {$t('stock.send')}
													{/if}
												</button>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Footer summary -->
					<div class="bg-slate-50 border-t border-slate-200 px-6 py-3 flex items-center justify-between">
						<span class="text-xs text-slate-500 font-semibold">
							{productRows.length} {$t('stock.productsCount')}
						</span>
						<span class="text-xs text-slate-400">
							{selectedBranches.length} {$t('stock.branchesCount')}
						</span>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>
