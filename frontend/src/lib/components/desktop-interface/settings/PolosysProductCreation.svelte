<script lang="ts">
	import { onMount, onDestroy, tick } from 'svelte';
	import { WandSparkles, LoaderCircle, Search, Camera, Check } from 'lucide-svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import SearchableDropdown from '$lib/components/desktop-interface/marketing/flyer/SearchableDropdown.svelte';
	import PolosysUnitSelect from './PolosysUnitSelect.svelte';
	import PolosysGroupSelect from './PolosysGroupSelect.svelte';
	import PolosysTablePrices from './PolosysTablePrices.svelte';
	import PolosysBarcodeCamera from './PolosysBarcodeCamera.svelte';
	export let mobile = false;

	type Lookup = { id: string; name: string; name_ar?: string | null };
	type ExtraUnit = { key: number; unitId: string; quantity: number | undefined; barcode: string };
	type BranchPrice = { branch_id: number; branch_name: string; purchase_price: number; sales_price: number; multi_units?: { unit_id: string; barcode: string; quantity_in_base_units: number; price: number | undefined }[]; fetched_at: string; saved_at: string };
	type ProductData = { name: string; arabic_name: string; barcode: string; purchase_price?: number; sales_price?: number; selected_branch_id?: number; branch_prices?: Record<string, BranchPrice>; multi_units: { unit_id: string; quantity_in_base_units: number; barcode: string; price?: number }[] };
	type SavedProduct = { id: string; product_group_id: string; base_unit_id: string; data: ProductData; created_at: string; updated_at: string; creation_status?: Record<string, { status: string; branch_name?: string; error?: string }> };
	const creationStatusLabels: Record<string, string> = { filling: 'Filling — not saved', saving: 'Saving — awaiting confirmation', prepared_unsaved: 'Prepared — NOT SAVED', created: 'Created', failed: 'Failed', needs_verification: 'Needs verification', not_created: 'Not created' };
	let editingProduct: SavedProduct | null = null;
	let activeView: 'create' | 'view' | 'manage' | 'coming-soon' = 'coming-soon';
	let editReturnView: 'view' | 'manage' = 'view';
	let scanBarcode = '';
	let scanError = '';
	let scanningProduct = false;
	let showBarcodeCamera = false;
	let barcodeCameraTarget: 'manage' | 'base' | 'checker' | number = 'manage';
	let barcodeCameraView: 'create' | 'view' | 'manage' | 'coming-soon' = 'manage';
	$: if (showBarcodeCamera && activeView !== barcodeCameraView) showBarcodeCamera = false;
	let scanInput: HTMLInputElement;
	let scanTimer: ReturnType<typeof setTimeout> | undefined;
	onDestroy(() => clearTimeout(scanTimer));
	let savedProducts: SavedProduct[] = [];
	let loadingProducts = false;
	let tablePricingBusy = false;
	let tablePriceController: PolosysTablePrices;
	let priceBranchFilter = '';
	let priceBranches: { id: number; name: string }[] = [];
	let loadingPriceBranches = false;
	let priceBranchError = '';
	let checkerBranchId = '';
	let checkerSearch = '';
	let checkerSearchInput: HTMLInputElement;
	type CheckerProduct = {
		id: string;
		barcode: string;
		checkedAt: string | null;
		name: string;
		arabicName: string;
		groupId: string;
		purchasePrice?: number;
		hasBranchPrices: boolean;
		prices: { barcode: string; unitId: string; multi_factor: number; sprice?: number }[];
	};
	let checkerProduct: CheckerProduct | null = null;
	let checkerLoading = false;
	let checkerError = '';
	let checkerCheckError = '';
	let checkerSavingCheck = false;
	let checkerTimer: ReturnType<typeof setTimeout> | undefined;
	let checkerController: AbortController | undefined;
	let checkerRequest = 0;
	onDestroy(() => resetCheckerLookup());
	$: if (activeView !== 'coming-soon') resetCheckerLookup();

	function resetCheckerLookup() {
		clearTimeout(checkerTimer);
		checkerController?.abort();
		checkerRequest++;
		checkerLoading = false;
		checkerProduct = null;
		checkerError = '';
		checkerCheckError = '';
	}

	function scheduleCheckerLookup() {
		resetCheckerLookup();
		if (checkerSearch.trim() && checkerBranchId) checkerTimer = setTimeout(lookupCheckerProduct, 400);
	}

	function prepareNextCheckerScan() {
		if (activeView !== 'coming-soon' || showBarcodeCamera) return;
		checkerSearch = '';
		checkerSearchInput?.focus({ preventScroll: true });
	}

	async function lookupCheckerProduct() {
		resetCheckerLookup();
		const scanned = checkerSearch.trim();
		const branchId = checkerBranchId;
		if (activeView !== 'coming-soon' || !scanned || !branchId || !$currentUser?.id) return;
		const requestId = checkerRequest;
		checkerController = new AbortController();
		checkerLoading = true;
		try {
			const query = new URLSearchParams({ interface: mobile ? 'mobile' : 'desktop', barcode: scanned, branchId });
			const response = await fetch(`/api/polosys-products/checker?${query}`, { signal: checkerController.signal });
			const result = await response.json();
			if (requestId !== checkerRequest) return;
			if (!response.ok) throw new Error(result.error || 'Unable to load product details.');
			const product = result.product as SavedProduct;
			const branchPrices = product.data.branch_prices?.[branchId];
			const legacyPrices = product.data.selected_branch_id === Number(branchId) ? product.data : undefined;
			const basePrices = branchPrices || legacyPrices;
			checkerProduct = {
				id: product.id,
				barcode: scanned,
				checkedAt: result.check?.checked_at || null,
				name: product.data.name,
				arabicName: product.data.arabic_name,
				groupId: product.product_group_id,
				purchasePrice: basePrices?.purchase_price,
				hasBranchPrices: !!basePrices,
				prices: [
					{ barcode: product.data.barcode, unitId: product.base_unit_id, multi_factor: 1, sprice: basePrices?.sales_price },
					...(product.data.multi_units || []).map(unit => {
						const savedPrice = branchPrices?.multi_units?.find(price => price.unit_id === unit.unit_id && price.barcode === unit.barcode.trim() && price.quantity_in_base_units === unit.quantity_in_base_units);
						return { barcode: unit.barcode, unitId: unit.unit_id, multi_factor: unit.quantity_in_base_units, sprice: branchPrices ? savedPrice?.price : legacyPrices ? unit.price : undefined };
					})
				]
			};
		} catch (error) {
			if (requestId === checkerRequest) checkerError = error instanceof Error ? error.message : 'Unable to load product details. Please try again.';
		} finally {
			if (requestId === checkerRequest) {
				checkerLoading = false;
				await tick();
				if (requestId === checkerRequest) prepareNextCheckerScan();
			}
		}
	}

	function checkerPrice(value: unknown) {
		return value != null && Number.isFinite(Number(value)) ? `${Number(value).toFixed(2)} SAR` : '—';
	}

	async function saveCheckerCheck() {
		if (!checkerProduct || checkerProduct.checkedAt || checkerSavingCheck || !checkerBranchId) return;
		const product = checkerProduct;
		const branchId = checkerBranchId;
		const requestId = checkerRequest;
		checkerSavingCheck = true;
		checkerCheckError = '';
		try {
			const response = await fetch(`/api/polosys-products/checker?interface=${mobile ? 'mobile' : 'desktop'}`, {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ productId: product.id, barcode: product.barcode, branchId: Number(branchId) })
			});
			const result = await response.json();
			if (!response.ok || !result.check?.checked_at) throw new Error(result.error || 'Unable to save checked status. Please try again.');
			if (requestId === checkerRequest) checkerProduct = { ...product, checkedAt: result.check.checked_at };
		} catch (error) {
			if (requestId === checkerRequest) checkerCheckError = error instanceof Error ? error.message : 'Unable to save checked status. Please try again.';
		} finally {
			checkerSavingCheck = false;
			await tick();
			if (requestId === checkerRequest) prepareNextCheckerScan();
		}
	}
	let checkerDefaultBranchId = '';
	let checkerPreferenceError = '';
	let checkerPreferenceMessage = '';

	async function showChecker() {
		resetCheckerLookup();
		activeView = 'coming-soon';
		checkerBranchId = '';
		checkerDefaultBranchId = '';
		checkerPreferenceError = '';
		checkerPreferenceMessage = '';
		const userId = $currentUser?.id;
		if (!userId) return;
		try {
			checkerDefaultBranchId = localStorage.getItem(`polosys-checker-default-branch:${userId}`) || '';
		} catch {
			checkerPreferenceError = 'Unable to read your default branch on this device.';
		}
		await loadPriceBranches();
		if ($currentUser?.id !== userId) return;
		if (priceBranches.some(branch => String(branch.id) === checkerDefaultBranchId)) {
			checkerBranchId = checkerDefaultBranchId;
		}
		if (activeView === 'coming-soon') scheduleCheckerLookup();
	}

	function saveCheckerDefaultBranch() {
		const userId = $currentUser?.id;
		if (!userId || !priceBranches.some(branch => String(branch.id) === checkerBranchId)) return;
		checkerPreferenceError = '';
		checkerPreferenceMessage = '';
		try {
			localStorage.setItem(`polosys-checker-default-branch:${userId}`, checkerBranchId);
			checkerDefaultBranchId = checkerBranchId;
			checkerPreferenceMessage = 'Default branch saved for you on this device.';
		} catch {
			checkerPreferenceError = 'Unable to save your default branch. Please try again.';
		}
	}
	$: priceBranchOptions = [...new Map([
		...savedProducts.flatMap(product => Object.values(product.data.branch_prices || {}).map(branch => [String(branch.branch_id), { id: branch.branch_id, name: branch.branch_name || `Branch ${branch.branch_id}` }] as const)),
		...priceBranches.map(branch => [String(branch.id), branch] as const)
	]).values()].sort((a, b) => a.name.localeCompare(b.name));
	$: priceBranchLabel = priceBranchOptions.find(branch => String(branch.id) === priceBranchFilter)?.name || 'Selected branch';
	let productsError = '';
	let barcodeCopyMessage = '';
	let barcodeCopyError = '';
	let savingProduct = false;
	let productSaveError = '';
	let productMessage = '';
	let draftId = '';
	let productPage = 0;
	let productCount = 0;
	let productSearch = '';
	let appliedProductSearch = '';
	const productPageSize = 25;
	let groups: Lookup[] = [];
	let units: Lookup[] = [];
	let loading = false;
	let loadError = '';
	let errors: string[] = [];
	let reviewed = false;
	let name = '';
	let arabicName = '';
	let translatingName = false;
	let translationError = '';
	let lookingUpBarcode = false;
	let barcodeLookupError = '';
	let barcodeSource: { url: string; title: string } | null = null;
	$: namesBusy = translatingName || lookingUpBarcode;
	let groupId = '';
	let baseUnitId = '';
	let barcode = '';
	let extraUnits: ExtraUnit[] = [];
	let nextKey = 0;
	let showGroupPopup = false;
	let newGroupName = '';
	let newGroupArabicName = '';
	let savingGroup = false;
	let savingUnit = false;
	let groupSaveError = '';
	let groupMessage = '';
	let groupNameInput: HTMLInputElement;
	let groupArabicNameInput: HTMLInputElement;
	let addGroupButton: HTMLButtonElement;
	$: groupOptions = groups.map(group => ({ id: group.id, name_en: group.name }));
	$: baseUnitName = units.find(unit => unit.id === baseUnitId)?.name || 'base units';
	$: canAddUnit = !!name.trim() && !!arabicName.trim() && !!barcode.trim()
		&& groups.some(group => group.id === groupId) && units.some(unit => unit.id === baseUnitId);
	$: groupName = groups.find(group => group.id === groupId)?.name || '';
	$: groupArabicName = groups.find(group => group.id === groupId)?.name_ar || '';
	const unitName = (id: string) => units.find(unit => unit.id === id)?.name || '';

	async function readLookup(table: 'Polosys_units' | 'Polosys_product_groups'): Promise<Lookup[]> {
		const rows: Lookup[] = [];
		for (let offset = 0; ; offset += 1000) {
			const { data, error } = await supabase.from(table).select('id, name, name_ar').order('name').range(offset, offset + 999);
			if (error) throw error;
			rows.push(...(data || []));
			if (!data || data.length < 1000) return rows;
		}
	}

	async function loadLookups() {
		if (!$currentUser?.id || loading || savingGroup || savingUnit) return;
		loading = true;
		loadError = '';
		try {
			[groups, units] = await Promise.all([readLookup('Polosys_product_groups'), readLookup('Polosys_units')]);
		} catch (error) {
			loadError = error instanceof Error ? error.message : 'Unable to load product groups and units.';
		} finally {
			loading = false;
		}
	}
	onMount(() => { void showChecker(); });

	async function loadPriceBranches() {
		if (!$currentUser?.id || loadingPriceBranches) return;
		loadingPriceBranches = true; priceBranchError = '';
		try {
			const response = await fetch(`/api/polosys-products/checker?interface=${mobile ? 'mobile' : 'desktop'}`);
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Unable to load branch filter.');
			priceBranches = result.branches || [];
			groups = result.groups || [];
			units = result.units || [];
		} catch (failure) {
			priceBranchError = failure instanceof Error ? failure.message : 'Unable to load branch filter.';
		} finally { loadingPriceBranches = false; }
	}

	async function loadProducts() {
		if (!$currentUser?.id || loadingProducts) return;
		loadingProducts = true;
		productsError = '';
		try {
			let query = supabase.from('Polosys_products')
				.select('id, product_group_id, base_unit_id, data, created_at, updated_at, creation_status', { count: 'exact' });
			if (appliedProductSearch) {
				const literalSearch = appliedProductSearch.replace(/[\\%_]/g, '\\$&');
				query = query.ilike('data->>name', `%${literalSearch}%`);
			}
			const { data, error, count } = await query
				.order('created_at', { ascending: false }).order('id', { ascending: false })
				.range(productPage * productPageSize, (productPage + 1) * productPageSize - 1);
			if (error) throw error;
			savedProducts = (data || []) as SavedProduct[];
			productCount = count || 0;
		} catch (error) {
			productsError = (error as { message?: string })?.message || 'Unable to load saved products.';
		} finally {
			loadingProducts = false;
		}
	}

	async function showProducts() {
		if (mobile) { await showManageProducts(); return; }
		activeView = 'view';
		productPage = 0;
		await Promise.all([loadLookups(), loadProducts(), loadPriceBranches()]);
	}

	async function changeProductPage(next: number) {
		if (loadingProducts || tablePricingBusy || next < 0) return;
		productPage = next;
		await loadProducts();
	}

	async function searchProducts(clear = false) {
		if (loadingProducts || tablePricingBusy) return;
		if (clear) productSearch = '';
		appliedProductSearch = productSearch.trim();
		productPage = 0;
		await loadProducts();
	}

	async function copyBarcode(value: string) {
		barcodeCopyMessage = ''; barcodeCopyError = '';
		try {
			await navigator.clipboard.writeText(value);
			barcodeCopyMessage = `Barcode ${value} copied.`;
		} catch {
			barcodeCopyError = 'Unable to copy barcode. Please select and copy it manually.';
		}
	}

	async function saveProduct() {
		if (!$currentUser?.id || savingProduct || savingGroup || savingUnit || namesBusy || loading) return;
		productSaveError = ''; productMessage = '';
		if (!review()) return;
		const returnToManage = !!editingProduct && editReturnView === 'manage';
		savingProduct = true;
		try {
			const isEditing = !!editingProduct;
			if (!draftId) draftId = crypto.randomUUID();
			const productData: ProductData = {
				...(editingProduct?.data || {}),
				name: name.trim(), arabic_name: arabicName.trim(), barcode: barcode.trim(),
				multi_units: extraUnits.map(unit => ({ unit_id: unit.unitId, quantity_in_base_units: Number(unit.quantity), barcode: unit.barcode.trim() }))
			};
			if (editingProduct) {
				const original = editingProduct;
				const sameUnits = original.base_unit_id === baseUnitId && original.data.barcode === productData.barcode
					&& original.data.multi_units.length === productData.multi_units.length
					&& productData.multi_units.every(unit => original.data.multi_units.some(saved => saved.unit_id === unit.unit_id
						&& saved.barcode === unit.barcode && saved.quantity_in_base_units === unit.quantity_in_base_units));
				if (sameUnits) {
					productData.multi_units = productData.multi_units.map(unit => ({ ...unit,
						...original.data.multi_units.find(saved => saved.unit_id === unit.unit_id) }));
				} else {
					delete productData.purchase_price;
					delete productData.sales_price;
					delete productData.selected_branch_id;
					delete productData.branch_prices;
				}
				const { error } = await supabase.from('Polosys_products').update({
					product_group_id: groupId, base_unit_id: baseUnitId, data: productData
				}).eq('id', original.id).eq('updated_at', original.updated_at).select('id').single();
				if (error) throw new Error('Unable to update product. It may have changed since you opened it; refresh and reopen Edit. ' + error.message);
			} else {
				// Reuse the draft ID on retries so a delayed response cannot create a second row.
				const { error } = await supabase.from('Polosys_products').upsert({
					id: draftId, product_group_id: groupId, base_unit_id: baseUnitId, data: productData,
					created_by: $currentUser.id
				}, { onConflict: 'id' });
				if (error) throw error;
			}
			clearDraft();
			productMessage = isEditing ? 'Product updated in Aqura.' : 'Product saved in Aqura.';
		} catch (error) {
			productSaveError = (error as { message?: string })?.message || 'Unable to save the product. Please retry.';
		} finally {
			savingProduct = false;
		}
		if (!productSaveError) {
			if (returnToManage) await showManageProducts();
			else await showProducts();
		}
	}

	async function editProduct(product: SavedProduct) {
		if (loadingProducts || tablePricingBusy || savingProduct) return;
		loadingProducts = true;
		productsError = '';
		try {
			const { data, error } = await supabase.from('Polosys_products')
				.select('id, product_group_id, base_unit_id, data, created_at, updated_at').eq('id', product.id).single();
			if (error) throw error;
			product = data as SavedProduct;
		} catch (error) {
			productsError = (error as { message?: string })?.message || 'Unable to open product for editing.';
			return;
		} finally {
			loadingProducts = false;
		}
		openProductEditor(product, 'view');
	}

	function openProductEditor(product: SavedProduct, returnView: 'view' | 'manage') {
		clearDraft();
		editReturnView = returnView;
		editingProduct = structuredClone(product);
		name = product.data.name;
		arabicName = product.data.arabic_name || '';
		groupId = product.product_group_id;
		baseUnitId = product.base_unit_id;
		barcode = product.data.barcode;
		extraUnits = (product.data.multi_units || []).map(unit => ({
			key: ++nextKey, unitId: unit.unit_id, quantity: unit.quantity_in_base_units, barcode: unit.barcode
		}));
		productMessage = '';
		activeView = returnView === 'manage' ? 'manage' : 'create';
	}

	async function showManageProducts() {
		clearTimeout(scanTimer);
		clearDraft();
		activeView = 'manage';
		scanBarcode = ''; scanError = '';
		await loadLookups();
		await tick();
		scanInput?.focus();
	}

	function scheduleBarcodeScan() {
		clearTimeout(scanTimer);
		scanError = '';
		if (scanBarcode.trim()) scanTimer = setTimeout(() => findScannedProduct(), 400);
	}

	function openBarcodeCamera(target: 'manage' | 'base' | 'checker' | number = 'manage') {
		clearTimeout(scanTimer);
		scanError = '';
		barcodeCameraTarget = target;
		barcodeCameraView = activeView;
		showBarcodeCamera = true;
	}

	function focusBarcodeTarget() {
		const inputId = barcodeCameraTarget === 'manage' ? 'polosys-manage-barcode'
			: barcodeCameraTarget === 'checker' ? 'polosys-checker-search'
			: barcodeCameraTarget === 'base' ? 'polosys-product-barcode' : `polosys-unit-barcode-${barcodeCameraTarget}`;
		document.getElementById(inputId)?.focus();
	}

	async function closeBarcodeCamera() {
		showBarcodeCamera = false;
		await tick();
		focusBarcodeTarget();
	}

	async function useCameraBarcode(value: string) {
		showBarcodeCamera = false;
		if (barcodeCameraTarget === 'manage') scanBarcode = value;
		else if (barcodeCameraTarget === 'checker') checkerSearch = value;
		else if (barcodeCameraTarget === 'base') {
			barcode = value;
			barcodeLookupError = ''; barcodeSource = null; reviewed = false;
		} else {
			extraUnits = extraUnits.map(unit => unit.key === barcodeCameraTarget ? { ...unit, barcode: value } : unit);
			reviewed = false;
		}
		await tick();
		if (barcodeCameraTarget === 'manage') await findScannedProduct();
		else if (barcodeCameraTarget === 'checker') await lookupCheckerProduct();
		focusBarcodeTarget();
	}

	async function findScannedProduct() {
		clearTimeout(scanTimer);
		if (!$currentUser?.id || activeView !== 'manage' || scanningProduct || savingProduct || namesBusy || savingGroup || savingUnit) return;
		const scanned = scanBarcode.trim();
		if (!scanned) return;
		scanningProduct = true; scanError = '';
		try {
			const columns = 'id, product_group_id, base_unit_id, data, created_at, updated_at';
			const results = await Promise.all([
				supabase.from('Polosys_products').select(columns).eq('data->>barcode', scanned).limit(2),
				supabase.from('Polosys_products').select(columns).contains('data', { multi_units: [{ barcode: scanned }] }).limit(2)
			]);
			for (const result of results) if (result.error) throw result.error;
			if (activeView !== 'manage' || scanBarcode.trim() !== scanned) return;
			const matches = [...new Map(results.flatMap(result => result.data || []).map(product => [product.id, product])).values()];
			if (!matches.length) { scanError = 'No saved product found for this barcode.'; return; }
			if (matches.length > 1) { scanError = 'This barcode belongs to multiple products. Use View Products to select the correct product.'; return; }
			openProductEditor(matches[0] as SavedProduct, 'manage');
			scanBarcode = '';
		} catch (error) {
			scanError = (error as { message?: string })?.message || 'Unable to find the scanned product.';
		} finally {
			scanningProduct = false;
		}
	}

	async function cancelProductEdit() {
		const returnView = editReturnView;
		clearDraft();
		if (returnView === 'manage') await showManageProducts();
		else if (mobile) await showManageProducts();
		else activeView = 'view';
	}

	function updateBranchPrices(productId: string, branchPrice: BranchPrice, selectedBranchId: number) {
		savedProducts = savedProducts.map(product => product.id !== productId ? product : {
			...product, data: { ...product.data, purchase_price: branchPrice.purchase_price, sales_price: branchPrice.sales_price,
				multi_units: product.data.multi_units.map(unit => ({ ...unit, price: branchPrice.multi_units?.find(price => price.unit_id === unit.unit_id && price.barcode === unit.barcode.trim())?.price })),
				selected_branch_id: selectedBranchId, branch_prices: { ...(product.data.branch_prices || {}), [String(branchPrice.branch_id)]: branchPrice } }
		});
	}

	async function openGroupPopup() {
		newGroupName = '';
		newGroupArabicName = '';
		groupSaveError = '';
		groupMessage = '';
		showGroupPopup = true;
		await tick();
		groupNameInput?.focus();
	}

	async function closeGroupPopup() {
		showGroupPopup = false;
		await tick();
		addGroupButton?.focus();
	}

	async function saveGroup() {
		if (!$currentUser?.id || savingGroup || savingUnit) return;
		const groupName = newGroupName.trim();
		const arabicGroupName = newGroupArabicName.trim();
		if (!groupName) {
			groupSaveError = 'Enter the product group name.';
			groupNameInput?.focus();
			return;
		}
		if (!arabicGroupName) {
			groupSaveError = 'Enter the Arabic product group name.';
			groupArabicNameInput?.focus();
			return;
		}
		savingGroup = true;
		groupSaveError = '';
		try {
			const { data: saved, error } = await supabase.from('Polosys_product_groups')
				.upsert({ name: groupName, name_ar: arabicGroupName }, { onConflict: 'name' })
				.select('id, name, name_ar').single();
			if (error) throw error;
			if (!saved) throw new Error('The saved group could not be loaded.');
			const selectedGroup = saved;
			groups = [...groups.filter(group => group.id !== selectedGroup.id), selectedGroup].sort((a, b) => a.name.localeCompare(b.name));
			groupId = selectedGroup.id;
			reviewed = false;
			groupMessage = 'Product group saved in Aqura with both names and selected.';
			showGroupPopup = false;
		} catch (error) {
			groupSaveError = (error as { message?: string })?.message || 'Unable to save the product group. Try again.';
		} finally {
			savingGroup = false;
		}
		if (!showGroupPopup) await closeGroupPopup();
	}

	async function correctProductNames() {
		if (!$currentUser?.id || namesBusy) return;
		const source = name.trim();
		if (!source) { translationError = 'Enter the English product name first.'; return; }
		translatingName = true;
		translationError = '';
		const previousArabicName = arabicName;
		try {
			const response = await fetch('/api/polosys-products/translate', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-aqura-interface': mobile ? 'mobile' : 'desktop' },
				body: JSON.stringify({ name: source }),
				signal: AbortSignal.timeout(100000)
			});
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Unable to correct and translate the product name.');
			if (typeof result.englishName !== 'string' || !result.englishName.trim() || typeof result.arabicName !== 'string' || !result.arabicName.trim()) throw new Error('Both product names are required. Please retry.');
			if (name.trim() === source && arabicName === previousArabicName) {
				name = result.englishName;
				arabicName = result.arabicName;
				barcodeSource = null;
				reviewed = false;
			}
		} catch (error) {
			translationError = error instanceof Error && ['TimeoutError', 'AbortError'].includes(error.name)
				? 'Name correction and translation timed out. Please retry.'
				: error instanceof Error ? error.message : 'Name correction and translation failed. Please retry.';
		} finally {
			translatingName = false;
		}
	}

	async function lookupBarcode() {
		if (!$currentUser?.id || namesBusy) return;
		const sourceBarcode = barcode.trim();
		if (!/^[0-9]{8,14}$/.test(sourceBarcode)) {
			barcodeLookupError = 'Enter a numeric product barcode of 8 to 14 digits.';
			return;
		}
		lookingUpBarcode = true;
		barcodeLookupError = ''; barcodeSource = null; translationError = '';
		const previousName = name;
		const previousArabicName = arabicName;
		try {
			const response = await fetch('/api/polosys-products/barcode-lookup', {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-aqura-interface': mobile ? 'mobile' : 'desktop' },
				body: JSON.stringify({ barcode: sourceBarcode }), signal: AbortSignal.timeout(190000)
			});
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Barcode lookup failed. Please retry.');
			if (result.barcode !== sourceBarcode || typeof result.englishName !== 'string' || !result.englishName.trim()
				|| typeof result.arabicName !== 'string' || !result.arabicName.trim() || typeof result.source?.url !== 'string'
				|| !/^https?:\/\//.test(result.source.url)) throw new Error('No source-backed product match was returned.');
			if (barcode.trim() === sourceBarcode && name === previousName && arabicName === previousArabicName) {
				name = result.englishName;
				arabicName = result.arabicName;
				barcodeSource = result.source;
				reviewed = false;
			}
		} catch (error) {
			barcodeLookupError = error instanceof Error && ['TimeoutError', 'AbortError'].includes(error.name)
				? 'Barcode search timed out. Please retry.' : error instanceof Error ? error.message : 'Barcode lookup failed. Please retry.';
		} finally {
			lookingUpBarcode = false;
		}
	}

	function rememberUnit(unit: Lookup) {
		units = [...units.filter(item => item.id !== unit.id), unit].sort((a, b) => a.name.localeCompare(b.name));
		reviewed = false;
	}

	function addUnit() {
		if (!canAddUnit || extraUnits.length >= 9) return;
		extraUnits = [...extraUnits, { key: ++nextKey, unitId: '', quantity: undefined, barcode: '' }];
		reviewed = false;
	}

	function review() {
		errors = [];
		if (!name.trim()) errors.push('Enter the product name.');
		if (!groups.some(group => group.id === groupId)) errors.push('Select a product group.');
		if (!units.some(unit => unit.id === baseUnitId)) errors.push('Select a base unit.');
		if (!barcode.trim()) errors.push('Enter the base-unit barcode.');
		if (!arabicName.trim()) errors.push('Enter the Arabic product name.');
		const selectedUnits = new Set([baseUnitId]);
		const barcodes = new Set([barcode.trim()]);
		extraUnits.forEach((unit, index) => {
			const row = `Unit ${index + 2}`;
			if (!units.some(item => item.id === unit.unitId)) errors.push(`${row}: select a unit.`);
			else if (selectedUnits.has(unit.unitId)) errors.push(`${row}: select a different unit from the other rows.`);
			selectedUnits.add(unit.unitId);
			if (typeof unit.quantity !== 'number' || !Number.isFinite(unit.quantity) || unit.quantity <= 0) errors.push(`${row}: enter a positive quantity in ${baseUnitName}.`);
			if (!unit.barcode.trim()) errors.push(`${row}: enter its barcode.`);
			else if (barcodes.has(unit.barcode.trim())) errors.push(`${row}: use a separate barcode.`);
			barcodes.add(unit.barcode.trim());
		});
		reviewed = errors.length === 0;
		return reviewed;
	}

	function clearDraft() {
		editingProduct = null;
		name = ''; arabicName = ''; groupId = ''; baseUnitId = ''; barcode = '';
		extraUnits = [];
		errors = []; reviewed = false;
		showGroupPopup = false; groupMessage = ''; groupSaveError = '';
		translationError = '';
		barcodeLookupError = ''; barcodeSource = null;
		draftId = ''; productSaveError = '';
	}
</script>

<div class="creation-window" class:mobile-product-window={mobile} class:viewing-products={activeView === 'view' && !mobile} class:viewing-coming-soon={activeView === 'coming-soon'} class:editing-products={activeView === 'create' || activeView === 'manage'}>
	{#if !$currentUser?.id}
		<p role="alert">Sign in to access ERP Products.</p>
	{:else}
		<nav class="product-tabs" aria-label="Product views">
			<button type="button" class:active={activeView === 'create'} aria-pressed={activeView === 'create'} disabled={savingProduct || savingGroup || savingUnit || namesBusy || loadingProducts || tablePricingBusy} on:click={() => { if (editingProduct) clearDraft(); activeView = 'create'; }}>Create Product</button>
			{#if !mobile}<button type="button" class:active={activeView === 'view'} aria-pressed={activeView === 'view'} disabled={savingProduct || savingGroup || savingUnit || namesBusy || loadingProducts || tablePricingBusy} on:click={showProducts}>View Products</button>{/if}
			<button type="button" class:active={activeView === 'manage'} aria-pressed={activeView === 'manage'} disabled={savingProduct || savingGroup || savingUnit || namesBusy || loadingProducts || tablePricingBusy || scanningProduct} on:click={showManageProducts}>Manage Products</button>
			<button type="button" class:active={activeView === 'coming-soon'} aria-pressed={activeView === 'coming-soon'} disabled={savingProduct || savingGroup || savingUnit || namesBusy || loadingProducts || tablePricingBusy || scanningProduct || loadingPriceBranches} on:click={showChecker}>Checker</button>
		</nav>
		{#if activeView === 'coming-soon'}
			<section class="checker-branch" aria-label="Checker branch selection">
				<label for="polosys-checker-branch">{mobile ? 'Branch' : 'Step 1: Select branch'}
					<select id="polosys-checker-branch" bind:value={checkerBranchId} disabled={loadingPriceBranches || !!priceBranchError} on:change={() => { checkerPreferenceMessage = ''; checkerPreferenceError = ''; scheduleCheckerLookup(); }}>
						<option value="">{loadingPriceBranches ? 'Loading branches…' : 'Select a branch'}</option>
						{#each priceBranches as branch}<option value={String(branch.id)}>{branch.name}</option>{/each}
					</select>
				</label>
				<button type="button" disabled={!checkerBranchId || loadingPriceBranches || !!priceBranchError || checkerBranchId === checkerDefaultBranchId} on:click={saveCheckerDefaultBranch}>{checkerBranchId && checkerBranchId === checkerDefaultBranchId ? 'Default branch' : 'Set as default'}</button>
				{#if priceBranchError}<p class="translation-error" role="alert">{priceBranchError} <button type="button" disabled={loadingPriceBranches} on:click={showChecker}>Retry</button></p>
				{:else if !loadingPriceBranches && !priceBranches.length}<p>No branches available.</p>{/if}
				{#if checkerPreferenceError}<p class="translation-error" role="alert">{checkerPreferenceError}</p>{/if}
				{#if checkerPreferenceMessage}<p role="status">{checkerPreferenceMessage}</p>{/if}
			</section>
			<form class="checker-search" role="search" on:submit|preventDefault={lookupCheckerProduct}>
				<label for="polosys-checker-search">Search barcode</label>
				<div class="barcode-controls">
					<input id="polosys-checker-search" type="search" bind:this={checkerSearchInput} bind:value={checkerSearch} on:input={scheduleCheckerLookup} placeholder="Enter or scan a barcode" autocomplete="off" disabled={!checkerBranchId || loadingPriceBranches || !!priceBranchError || showBarcodeCamera} />
					<button class="camera-scan-button" type="button" aria-label="Open camera to scan a barcode for Checker" disabled={!checkerBranchId || loadingPriceBranches || !!priceBranchError || showBarcodeCamera} on:click={() => openBarcodeCamera('checker')}><Camera size={18} aria-hidden="true" /> Scan</button>
				</div>
			</form>
			{#if checkerLoading}
				<p role="status">Loading product details…</p>
			{:else if checkerError}
				<p class="translation-error" role="alert">{checkerError} <button type="button" on:click={lookupCheckerProduct}>Retry</button></p>
			{:else if checkerProduct}
				<section class="checker-details" aria-label="Product details">
					<div class="checker-product-name">
						<h3>{checkerProduct.name || checkerProduct.arabicName || 'Product details'}</h3>
						{#if checkerProduct.arabicName}<p lang="ar" dir="rtl">{checkerProduct.arabicName}</p>{/if}
					</div>
					<dl><dt>Branch</dt><dd>{priceBranches.find(branch => String(branch.id) === checkerBranchId)?.name || checkerBranchId}</dd><dt>Product group</dt><dd>{groups.find(group => group.id === checkerProduct?.groupId)?.name || '—'}</dd><dt>Base purchase price</dt><dd>{checkerPrice(checkerProduct.purchasePrice)}</dd></dl>
					{#if !checkerProduct.hasBranchPrices}<p>No saved prices for the selected branch.</p>{/if}
					{#if checkerCheckError}<p class="translation-error" role="alert">{checkerCheckError}</p>{/if}
					{#if checkerProduct.prices.length}
						<div class="table-scroll"><table><thead><tr><th>Unit</th><th>Barcode</th><th title="Quantity in base units" aria-label="Quantity in base units">Base qty</th><th>Sales price</th><th>Check</th></tr></thead><tbody>
							{#each checkerProduct.prices as price}<tr class:scanned-unit={String(price.barcode) === checkerProduct.barcode}><td>{unitName(price.unitId) || '—'}</td><td>{price.barcode}</td><td>{price.multi_factor ?? '—'}</td><td>{checkerPrice(price.sprice)}</td><td>
								{#if String(price.barcode) === checkerProduct.barcode}
									{#if checkerProduct.checkedAt}<span class="checker-checked" role="status" aria-label="Checked for this branch"><Check size={20} aria-hidden="true" /></span>
									{:else}<button class="primary checker-check-button" type="button" disabled={checkerSavingCheck} on:click={saveCheckerCheck}>{checkerSavingCheck ? 'Saving…' : 'Check'}</button>{/if}
								{/if}
							</td></tr>{/each}
						</tbody></table></div>
					{:else}<p>No unit prices available for this product.</p>{/if}
				</section>
			{:else if !mobile}<p class="empty">Select a branch, then enter or scan a barcode to view product details.</p>{/if}
		{/if}
		{#if productMessage}<div class="product-success" role="status">{productMessage}</div>{/if}
		{#if loadError}
			<div class="error" role="alert">{loadError} <button type="button" on:click={loadLookups} disabled={loading}>Retry</button></div>
		{:else if loading}
			<p role="status">Loading product groups and units…</p>
		{/if}
		{#if activeView === 'manage'}
			<form class="manage-scan" role="search" on:submit|preventDefault={findScannedProduct}>
				<label for="polosys-manage-barcode">Scan barcode<input id="polosys-manage-barcode" bind:this={scanInput} bind:value={scanBarcode} on:input={scheduleBarcodeScan} autocomplete="off" placeholder="Scan a product barcode to edit" disabled={showBarcodeCamera || scanningProduct || savingProduct || namesBusy || savingGroup || savingUnit} /></label>
				<button class="camera-scan-button" type="button" disabled={scanningProduct || savingProduct || namesBusy || savingGroup || savingUnit} on:click={() => openBarcodeCamera('manage')}><Camera size={18} aria-hidden="true" /> Scan</button>
				<button type="submit" disabled={scanningProduct || savingProduct || namesBusy || savingGroup || savingUnit || !scanBarcode.trim()}>{scanningProduct ? 'Opening…' : 'Open product'}</button>
			</form>
			{#if scanError}<p class="translation-error" role="alert">{scanError}</p>{/if}
		{/if}
		{#if showBarcodeCamera}<PolosysBarcodeCamera on:scan={(event) => useCameraBarcode(event.detail)} on:close={closeBarcodeCamera} />{/if}
		<div hidden={activeView !== 'create' && !(activeView === 'manage' && editingProduct)}>
		{#if editingProduct}<h3>Edit Product</h3>{#if !mobile}<p>Changing barcodes or units clears saved prices for this product. Fetch prices again after saving.</p>{/if}{/if}
		<form on:submit|preventDefault={saveProduct} on:input={() => { reviewed = false; productMessage = ''; }} on:change={() => reviewed = false}>
			<fieldset class="product-editor" disabled={savingProduct}>
			<section aria-label="Product details">
				<div class="fields">
					<div class="product-names-row full">
						<label>Product name<input bind:value={name} maxlength="300" disabled={namesBusy} placeholder="Enter product name" on:input={() => { translationError = ''; barcodeSource = null; }} /></label>
						<button type="button" class="correct-names" title={translatingName ? 'Correcting English and filling Arabic…' : 'Correct English and fill Arabic'} aria-label="Correct English and fill Arabic" aria-busy={translatingName} disabled={namesBusy || !name.trim()} on:click={correctProductNames}>
							{#if translatingName}<span class="name-spinner" aria-hidden="true"><LoaderCircle size={18} /></span>{:else}<WandSparkles size={18} aria-hidden="true" />{/if}
						</button>
						<label>Product name (Arabic)<input bind:value={arabicName} maxlength="600" disabled={namesBusy} lang="ar" dir="rtl" placeholder="اسم المنتج بالعربية" on:input={() => barcodeSource = null} /></label>
						{#if translationError}<span class="translation-error" role="alert">{translationError}</span>{/if}
					</div>
					<div class="group-field">
						<span>Product group</span>
						<fieldset class="group-controls" disabled={loading || savingGroup || savingUnit} aria-label="Product group">
							<div class="group-selector">
								{#if mobile}<PolosysGroupSelect {groups} bind:value={groupId} disabled={loading || savingGroup || savingUnit} on:change={() => { reviewed = false; groupMessage = ''; }} />
								{:else}<SearchableDropdown options={groupOptions} bind:value={groupId} placeholder="Search and select product group" on:change={() => { reviewed = false; groupMessage = ''; }} />{/if}
							</div>
							<button type="button" class="add-group" bind:this={addGroupButton} aria-label="Create product group" aria-expanded={showGroupPopup} on:click={openGroupPopup}>+</button>
						</fieldset>
						{#if groupMessage}<span class="group-message" role="status">{groupMessage}</span>{/if}
						{#if showGroupPopup}
							<div class="group-popup" role="dialog" aria-label="Create product group">
								<h3>Create product group</h3>
								<label>Group name (English)<input bind:this={groupNameInput} bind:value={newGroupName} disabled={savingGroup} placeholder="Exact group name in Polosys" on:keydown={(event) => { if (event.key === 'Enter') { event.preventDefault(); event.stopPropagation(); groupArabicNameInput?.focus(); } else if (event.key === 'Escape' && !savingGroup) { event.preventDefault(); event.stopPropagation(); closeGroupPopup(); } }} /></label>
								<label class="group-arabic-label">Group name (Arabic)<input bind:this={groupArabicNameInput} bind:value={newGroupArabicName} disabled={savingGroup} lang="ar" dir="rtl" placeholder="اسم مجموعة المنتجات بالعربية" on:keydown={(event) => { if (event.key === 'Enter') { event.preventDefault(); event.stopPropagation(); saveGroup(); } else if (event.key === 'Escape' && !savingGroup) { event.preventDefault(); event.stopPropagation(); closeGroupPopup(); } }} /></label>
								{#if groupSaveError}<div class="error" role="alert">{groupSaveError}</div>{/if}
								<div class="group-actions"><button type="button" disabled={savingGroup} on:click={closeGroupPopup}>Cancel</button><button type="button" class="primary" disabled={savingGroup || savingUnit} on:click={saveGroup}>{savingGroup ? 'Saving…' : 'Save group'}</button></div>
							</div>
						{/if}
					</div>
					<PolosysUnitSelect {units} {mobile} bind:value={baseUnitId} label="Base unit" excludedIds={extraUnits.map(unit => unit.unitId)} disabled={loading || savingGroup || savingUnit} on:saved={(event) => rememberUnit(event.detail)} on:change={() => reviewed = false} on:saving={(event) => savingUnit = event.detail} />
					<div class="barcode-field full">
						<label for="polosys-product-barcode">Barcode</label>
						<div class="barcode-controls">
							<input id="polosys-product-barcode" bind:value={barcode} disabled={namesBusy} placeholder="Base-unit barcode" on:input={() => { barcodeLookupError = ''; barcodeSource = null; }} />
							<button type="button" class="correct-names" title="Scan base-unit barcode" aria-label="Open camera to scan base-unit barcode" disabled={namesBusy} on:click={() => openBarcodeCamera('base')}><Camera size={18} aria-hidden="true" /></button>
							<button type="button" class="correct-names" title="Search barcode and fill product names" aria-label="Search barcode and fill English and Arabic product names" aria-busy={lookingUpBarcode} disabled={namesBusy || !barcode.trim()} on:click={lookupBarcode}>
								{#if lookingUpBarcode}<span class="name-spinner" aria-hidden="true"><LoaderCircle size={18} /></span>{:else}<Search size={18} aria-hidden="true" />{/if}
							</button>
						</div>
						{#if lookingUpBarcode}<span role="status">Searching barcode…</span>{/if}
						{#if barcodeLookupError}<span class="translation-error" role="alert">{barcodeLookupError}</span>{/if}
						{#if barcodeSource}<span class="barcode-source" role="status">Product names filled. Source: <a href={barcodeSource.url} target="_blank" rel="noopener noreferrer">{barcodeSource.title}</a></span>{/if}
					</div>
				</div>
			</section>
			<section class="multi-units" aria-label="Additional units">
				<div class="unit-heading"><div><h3>Multi Units</h3>{#if !mobile}<p>Enter how many {baseUnitName} each additional unit contains.</p>{/if}</div>{#if canAddUnit}<button type="button" on:click={addUnit} disabled={extraUnits.length >= 9}>+ Add unit</button>{/if}</div>
				<div class="base-unit">Unit 1 · {baseUnitId ? baseUnitName : 'Select a base unit in Details'} · Quantity 1</div>
				{#if !mobile && !extraUnits.length}<p class="empty">No additional units. Add a row for each pack, carton, or other unit.</p>{/if}
				{#each extraUnits as unit, index (unit.key)}
					<div class="unit-row">
						<div class="row-heading"><h3>Unit {index + 2}</h3><button type="button" class="remove" disabled={savingUnit} on:click={() => { extraUnits = extraUnits.filter(item => item.key !== unit.key); reviewed = false; }}>Remove</button></div>
						<div class="unit-fields">
							<PolosysUnitSelect {units} {mobile} bind:value={unit.unitId} excludedIds={[baseUnitId, ...extraUnits.filter(other => other.key !== unit.key).map(other => other.unitId)]} disabled={loading || savingGroup || savingUnit} on:saved={(event) => rememberUnit(event.detail)} on:change={() => reviewed = false} on:saving={(event) => savingUnit = event.detail} />
							<label>Contains ({baseUnitName})<input type="number" min="0.000001" step="any" bind:value={unit.quantity} placeholder="e.g. 30" /></label>
							<div class="barcode-field"><label for={`polosys-unit-barcode-${unit.key}`}>Unit barcode</label><div class="barcode-controls"><input id={`polosys-unit-barcode-${unit.key}`} bind:value={unit.barcode} placeholder="Separate barcode" /><button type="button" class="correct-names" title="Scan unit barcode" aria-label={`Open camera to scan unit ${index + 2} barcode`} on:click={() => openBarcodeCamera(unit.key)}><Camera size={18} aria-hidden="true" /></button></div></div>
						</div>
						{#if unit.unitId && unit.quantity}<p class="conversion">1 {unitName(unit.unitId)} = {unit.quantity} {baseUnitName}</p>{/if}
					</div>
				{/each}
				{#if !mobile}<p class="hint">Up to 9 additional units, matching Polosys Unit 2 through Unit 10.</p>{/if}
			</section>
			{#if errors.length}<div class="error" role="alert"><ul>{#each errors as error}<li>{error}</li>{/each}</ul></div>{/if}
			{#if productSaveError}<div class="error" role="alert">{productSaveError}</div>{/if}
			<footer><button type="button" disabled={savingGroup || savingUnit || namesBusy} on:click={() => editingProduct ? cancelProductEdit() : clearDraft()}>{editingProduct ? 'Cancel edit' : 'Clear draft'}</button><button type="button" disabled={loading || savingGroup || savingUnit || namesBusy} on:click={review}>Review product</button><button class="primary" type="submit" disabled={loading || savingGroup || savingUnit || namesBusy}>{savingProduct ? 'Saving…' : editingProduct ? 'Save changes' : 'Save product'}</button></footer>
			</fieldset>
		</form>
		{#if reviewed}
			<section class="review" aria-label="Product review" aria-live="polite">
				<h3>Product review · Unsaved</h3>
				<dl><dt>Product</dt><dd>{name}</dd><dt>Arabic name</dt><dd lang="ar" dir="rtl">{arabicName}</dd><dt>Group</dt><dd>{groupName}{#if groupArabicName}<span lang="ar" dir="rtl"> · {groupArabicName}</span>{/if}</dd></dl>
				<div class="table-scroll"><table><thead><tr><th>Unit</th><th>Contains ({baseUnitName})</th><th>Barcode</th></tr></thead><tbody><tr><td>{baseUnitName} (base)</td><td>1</td><td>{barcode}</td></tr>{#each extraUnits as unit}<tr><td>{unitName(unit.unitId)}</td><td>{unit.quantity}</td><td>{unit.barcode}</td></tr>{/each}</tbody></table></div>
			</section>
		{/if}
		</div>
		{#if activeView === 'view' && !mobile}
			<section class="products-view" aria-label="Saved products">
				<PolosysTablePrices bind:this={tablePriceController} disabled={loadingProducts || productCount === 0} bind:busy={tablePricingBusy} on:saved={(event) => updateBranchPrices(event.detail.productId, event.detail.branchPrice, event.detail.selectedBranchId)}>
				<svelte:fragment slot="toolbar">
				<h3 class="saved-product-count">Products ({productCount})</h3>
				<form class="product-search" role="search" on:submit|preventDefault={() => searchProducts()}>
					<label for="polosys-product-search">Search by product name<input id="polosys-product-search" type="search" bind:value={productSearch} placeholder="Enter product name" disabled={loadingProducts || tablePricingBusy} /></label>
					<button type="submit" disabled={loadingProducts || tablePricingBusy}>Search</button>
					{#if productSearch || appliedProductSearch}<button type="button" disabled={loadingProducts || tablePricingBusy} on:click={() => searchProducts(true)}>Clear</button>{/if}
				</form>
				<div class="price-table-controls"><label>Filter prices by branch<select bind:value={priceBranchFilter} disabled={loadingPriceBranches}><option value="">All branches</option>{#each priceBranchOptions as branch}<option value={String(branch.id)}>{branch.name}</option>{/each}</select></label><button type="button" disabled={loadingProducts || tablePricingBusy} on:click={() => { loadProducts(); loadPriceBranches(); }}>Refresh</button></div>
				</svelte:fragment>
				</PolosysTablePrices>
				{#if priceBranchError}<p class="translation-error" role="alert">{priceBranchError}</p>{/if}
				<span class="clipboard-status" role="status">{barcodeCopyMessage}</span>
				{#if barcodeCopyError}<p class="translation-error" role="alert">{barcodeCopyError}</p>{/if}
				{#if loadingProducts}<p role="status">Loading products…</p>
				{:else if productsError}<div class="error" role="alert">{productsError}</div>
				{:else if !savedProducts.length}<p class="empty">{appliedProductSearch ? 'No products match this name.' : 'No products saved yet. Use Create Product to add one.'}</p>
				{:else}
					<div class="table-scroll saved-products-table">
						<table><thead><tr><th scope="col">#</th><th>Product name</th><th>Arabic name</th><th>Product group</th><th>Base unit</th><th>Barcode</th><th>Standard purchase price</th><th>Standard sales price</th><th>Branch prices</th><th>Multi Units</th><th>Creation status</th><th>Actions</th></tr></thead>
						<tbody>{#each savedProducts as product, index (product.id)}
							{@const productBranches = Object.values(product.data.branch_prices || {}).filter(branch => !priceBranchFilter || String(branch.branch_id) === priceBranchFilter)}
							{@const shownBasePrices = priceBranchFilter ? productBranches[0] : product.data}
							{@const creationStates = Object.entries(product.creation_status || {}).filter(([branchId]) => !priceBranchFilter || branchId === priceBranchFilter)}
							<tr>
								<td>{productPage * productPageSize + index + 1}</td>
								<td>{product.data.name}</td><td lang="ar" dir="rtl">{product.data.arabic_name}</td>
								<td>{groups.find(group => group.id === product.product_group_id)?.name || '—'}</td>
								<td>{unitName(product.base_unit_id) || '—'}</td><td><span class="copyable-barcode" role="button" tabindex="0" title="Double-click to copy barcode" aria-label={`Copy barcode ${product.data.barcode}`} on:dblclick={() => copyBarcode(product.data.barcode)} on:keydown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); copyBarcode(product.data.barcode); } }}>{product.data.barcode}</span></td>
								<td>{shownBasePrices?.purchase_price == null ? '—' : Number(shownBasePrices.purchase_price).toFixed(2)}</td><td>{shownBasePrices?.sales_price == null ? '—' : Number(shownBasePrices.sales_price).toFixed(2)}</td>
								<td>{#each productBranches as price}<div class="saved-branch-summary"><strong>{price.branch_name || `Branch ${price.branch_id}`}{product.data.selected_branch_id === price.branch_id ? ' · Selected' : ''}</strong><small>Purchase: {Number(price.purchase_price).toFixed(2)} · Sales: {Number(price.sales_price).toFixed(2)}</small></div>{/each}{#if priceBranchFilter && !productBranches.length}<small>No saved prices for this branch</small>{/if}</td>
								<td>
									{#if product.data.multi_units?.length}
										<details>
											<summary>{product.data.multi_units.length} additional unit(s)</summary>
											<table class="saved-unit-table">
												<thead><tr><th>Unit</th><th>Contains ({unitName(product.base_unit_id)})</th><th>Barcode</th>
													{#each productBranches as branch}<th>{branch.branch_name || `Branch ${branch.branch_id}`} sales price{product.data.selected_branch_id === branch.branch_id ? ' · Selected' : ''}</th>{/each}
													{#if !productBranches.length}<th>{priceBranchFilter ? `${priceBranchLabel} sales price` : 'Price'}</th>{/if}
												</tr></thead>
												<tbody>{#each product.data.multi_units as unit}<tr>
													<td>{unitName(unit.unit_id)}</td><td>{unit.quantity_in_base_units}</td><td><span class="copyable-barcode" role="button" tabindex="0" title="Double-click to copy barcode" aria-label={`Copy barcode ${unit.barcode}`} on:dblclick={() => copyBarcode(unit.barcode)} on:keydown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); copyBarcode(unit.barcode); } }}>{unit.barcode}</span></td>
													{#each productBranches as branch}
														{@const savedUnit = branch.multi_units?.find(price => price.unit_id === unit.unit_id && price.barcode === unit.barcode.trim() && price.quantity_in_base_units === unit.quantity_in_base_units)}
														<td>{savedUnit?.price == null ? '—' : Number(savedUnit.price).toFixed(2)}</td>
													{/each}
													{#if !productBranches.length}<td>{priceBranchFilter || unit.price == null ? '—' : Number(unit.price).toFixed(2)}</td>{/if}
												</tr>{/each}</tbody>
											</table>
										</details>
									{:else}—{/if}
								</td>
								<td>{#each creationStates as [branchId, state]}<div class="saved-branch-summary" title={state.error || ''}><strong>{state.branch_name || priceBranchOptions.find(branch => String(branch.id) === branchId)?.name || `Branch ${branchId}`}</strong><small>{creationStatusLabels[state.status] || 'Needs verification'}</small></div>{/each}{#if !creationStates.length}<small>Not created</small>{/if}</td>
								<td><div class="row-actions"><button type="button" disabled={loadingProducts || tablePricingBusy} on:click={() => editProduct(product)}>Edit</button><button type="button" disabled={loadingProducts || tablePricingBusy} on:click={() => tablePriceController.showProduct(product.id, product.data.name, priceBranchFilter)}>Get Price</button></div></td>
							</tr>
						{/each}</tbody></table>
					</div>
				{/if}
				<div class="products-pagination"><button type="button" disabled={loadingProducts || tablePricingBusy || productPage === 0} on:click={() => changeProductPage(productPage - 1)}>Previous</button><span>Page {productPage + 1} of {Math.max(1, Math.ceil(productCount / productPageSize))}</span><button type="button" disabled={loadingProducts || tablePricingBusy || (productPage + 1) * productPageSize >= productCount} on:click={() => changeProductPage(productPage + 1)}>Next</button></div>
			</section>
		{/if}
	{/if}
</div>

<style>
	.checker-details{margin-top:20px;padding:20px;background:white;border:1px solid #e2e8f0;border-radius:10px}
	.checker-details .scanned-unit{background:#ecfeff}
	.checker-search{display:flex;flex-direction:column;gap:8px;margin-top:20px;flex-shrink:0}
	.checker-branch{display:flex;align-items:end;gap:12px;flex-wrap:wrap;flex-shrink:0;padding:20px;background:white;border:1px solid #e2e8f0;border-radius:10px}
	.checker-branch label{flex:1;min-width:0;max-width:420px}
	.checker-branch p{flex-basis:100%;margin:0}
	.creation-window.viewing-coming-soon{display:flex;flex-direction:column;min-height:0}
	.viewing-coming-soon>.product-tabs{flex-shrink:0;flex-wrap:wrap}
	.row-actions{display:flex;gap:8px;white-space:nowrap}
	.camera-scan-button{display:inline-flex;align-items:center;gap:8px}
	.manage-scan{display:flex;align-items:end;gap:12px;margin-bottom:20px;flex-wrap:wrap}.manage-scan label{flex:1;min-width:220px}.manage-scan button{white-space:nowrap}
	.copyable-barcode{cursor:copy;white-space:nowrap}.copyable-barcode:focus-visible{outline:2px solid #0891b2;outline-offset:3px;border-radius:2px}.clipboard-status{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
	.creation-window{height:100%;overflow:auto;box-sizing:border-box;padding:24px;background:#f8fafc;color:#1e293b;font-size:14px}
	.creation-window.viewing-products{display:flex;flex-direction:column;overflow:hidden;min-height:0}
	.viewing-products>.product-tabs,.viewing-products>.product-success,.viewing-products>.error{flex-shrink:0}
	.products-view{display:flex;flex-direction:column;flex:1;min-height:0;min-width:0;overflow:hidden}
	.products-view>.saved-products-table{flex:1;min-height:0;overflow:auto;overscroll-behavior:contain}
	.saved-products-table>table>thead>tr>th{position:sticky;top:0;z-index:2;box-shadow:0 1px 0 #cbd5e1}
	.products-view>.products-pagination{flex-shrink:0;margin:12px 0 0}
	.saved-product-count{white-space:nowrap;align-self:center;font-size:13px}.product-search{display:flex;align-items:end;gap:8px;flex:1;min-width:280px;margin:0}.product-search label{flex:1;min-width:120px;font-size:12px}.product-search input{font-size:14px}
	.price-table-controls{display:flex;align-items:end;gap:12px;flex-wrap:wrap}.price-table-controls label{font-size:12px}.price-table-controls select{min-width:220px;max-width:100%;font-size:14px}
	.saved-branch-summary{margin-bottom:10px;min-width:160px}.saved-branch-summary strong,.saved-branch-summary small{display:block;font-size:12px}.saved-branch-summary small{color:#64748b;margin-top:4px}
	.product-tabs{display:flex;gap:8px;border-bottom:1px solid #cbd5e1;padding-bottom:12px;margin-bottom:20px}.product-tabs button.active{background:#0e7490;color:white;border-color:#0e7490}.product-editor{border:0;padding:0;margin:0;min-width:0}.product-success{padding:12px;background:#ecfdf5;color:#047857;border-radius:6px;margin-bottom:16px}.products-toolbar,.products-pagination{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin:16px 0}.products-pagination{justify-content:flex-end}.saved-products-table{background:white;border:1px solid #e2e8f0;border-radius:8px}.saved-products-table>table{min-width:1000px}.saved-products-table td{vertical-align:top}.saved-unit-table{margin-top:12px;min-width:360px}summary{cursor:pointer;color:#0e7490;white-space:nowrap}
	.unit-heading,.row-heading,footer{display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap}
	h3{font-size:15px;margin:0}p{margin:8px 0;color:#64748b;line-height:1.5}
	.fields{display:grid;grid-template-columns:1fr 1fr;gap:20px;background:white;padding:22px;border:1px solid #e2e8f0;border-radius:10px}.full{grid-column:1/-1}
	.group-arabic-label{margin-top:14px}
	.barcode-field{display:flex;flex-direction:column;gap:8px;min-width:0}.barcode-controls{display:flex;align-items:center;gap:10px}.barcode-controls input{flex:1;min-width:0}.barcode-controls button{flex:none;grid-column:auto;grid-row:auto}.barcode-source{font-size:12px;color:#047857;overflow-wrap:anywhere}.barcode-source a{color:#0e7490;text-decoration:underline}
	.product-names-row{display:grid;grid-template-columns:minmax(0,1fr) auto minmax(0,1fr);align-items:end;gap:16px}.correct-names{display:flex;align-items:center;justify-content:center;width:40px;height:40px;padding:0;color:#0e7490}.name-spinner{display:flex;animation:name-spin 1s linear infinite}@keyframes name-spin{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){.name-spinner{animation:none}}.translation-error{grid-column:1/-1;color:#b91c1c;font-size:12px}
	.group-field{position:relative;display:flex;flex-direction:column;gap:8px;min-width:0}.group-controls{display:flex;gap:8px;min-width:0;margin:0;padding:0;border:0}.group-selector{flex:1;min-width:0}.add-group{flex:none;font-size:20px;padding:5px 14px;color:#0e7490}.group-popup{position:absolute;top:100%;left:0;right:0;z-index:40;margin-top:6px;padding:16px;border:1px solid #cbd5e1;border-radius:8px;background:white;box-shadow:0 8px 24px #0f172a26}.group-popup h3{margin-bottom:14px}.group-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:14px;flex-wrap:wrap}.group-message{font-size:12px;color:#047857}
	label{display:flex;flex-direction:column;gap:8px;font-weight:500;min-width:0}input,select{box-sizing:border-box;width:100%;min-width:0;border:1px solid #cbd5e1;border-radius:6px;padding:10px 12px;background:white;color:#0f172a;font:inherit;font-weight:400}
	input:focus,select:focus{outline:2px solid #0891b2;outline-offset:1px}button{border:1px solid #cbd5e1;border-radius:6px;padding:9px 14px;background:white;color:#334155;font:inherit;cursor:pointer}button:disabled,select:disabled{opacity:.55;cursor:default}.primary{background:#0e7490;border-color:#0e7490;color:white}
	.multi-units{margin-top:24px}.unit-heading{margin-bottom:12px}.base-unit{background:#e2e8f0;padding:12px 16px;border-radius:6px}.empty{padding:22px;text-align:center}
	.unit-row{margin-top:16px;padding:18px;background:white;border:1px solid #e2e8f0;border-radius:8px}.row-heading{margin-bottom:14px}.unit-fields{display:grid;grid-template-columns:1fr 1fr 1.4fr;gap:14px}.remove{color:#b91c1c;padding:5px 9px}.conversion{color:#0e7490}.hint{font-size:12px}footer{border-top:1px solid #e2e8f0;margin-top:22px;padding-top:16px;justify-content:flex-end}
	.error{background:#fef2f2;color:#b91c1c;padding:12px;border-radius:6px;margin-top:14px}.error ul{margin:0;padding-left:20px}.review{margin-top:22px;padding:20px;border:1px solid #99f6e4;background:white;border-radius:8px}dl{display:grid;grid-template-columns:140px 1fr;gap:10px}dt{color:#64748b}dd{margin:0;overflow-wrap:anywhere}.table-scroll{overflow:auto}table{width:100%;border-collapse:collapse;text-align:left}th,td{padding:10px;border-bottom:1px solid #e2e8f0;overflow-wrap:anywhere}th{background:#f1f5f9}
	@media(max-width:760px){.creation-window{padding:16px}.unit-fields{grid-template-columns:1fr 1fr}}
	@media(max-width:760px){.product-names-row{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}.correct-names{grid-column:1/-1;grid-row:2;justify-self:center}}
	@media(max-width:520px){.fields,.unit-fields,.product-names-row{grid-template-columns:1fr}.fields{padding:14px}dl{grid-template-columns:1fr}}
	.mobile-product-window{height:auto;min-height:100%;overflow:visible;padding:12px;background:#f8fafc;border-radius:10px}
	.mobile-product-window .product-tabs{gap:8px;margin-bottom:16px}.mobile-product-window .product-tabs button{flex:1;min-height:44px;padding:10px 8px}
	.mobile-product-window .fields,.mobile-product-window .unit-fields,.mobile-product-window .product-names-row{grid-template-columns:minmax(0,1fr)}
	.mobile-product-window .fields{padding:14px;gap:16px}.mobile-product-window .unit-row{padding:14px}
	.mobile-product-window .product-names-row>.correct-names{grid-column:auto;grid-row:auto;justify-self:center}
	.mobile-product-window input,.mobile-product-window select{font-size:16px;min-height:44px}.mobile-product-window button{min-height:44px}
	.mobile-product-window .manage-scan{gap:8px}.mobile-product-window .manage-scan label{flex-basis:100%;min-width:0}.mobile-product-window .manage-scan button{flex:1;justify-content:center}
	.mobile-product-window footer{gap:8px}.mobile-product-window footer button{flex:1}.mobile-product-window .group-popup{position:static;margin-top:6px}
	.viewing-coming-soon .checker-branch{padding:6px 8px;gap:6px;align-items:center}
	.viewing-coming-soon .checker-branch label{display:grid;grid-template-columns:auto minmax(0,1fr);align-items:center;gap:6px;font-size:12px;max-width:none}
	.viewing-coming-soon .checker-branch select{min-height:36px;padding:6px;font-size:16px}
	.viewing-coming-soon .checker-branch button{min-height:36px;padding:6px;font-size:12px;white-space:nowrap}
	.viewing-coming-soon .checker-search{margin:10px 0 0;gap:4px}
	.viewing-coming-soon .checker-search label{font-size:13px}
	.viewing-coming-soon .checker-details{margin-top:10px;padding:12px;font-size:13px}
	.checker-product-name{display:flex;align-items:baseline;justify-content:space-between;gap:4px 12px;flex-wrap:wrap}
	.checker-product-name h3{font-size:14px;overflow-wrap:anywhere}
	.checker-details p{margin:4px 0;line-height:1.35}
	.checker-details dl{grid-template-columns:minmax(80px,110px) minmax(0,1fr);gap:4px 8px;margin:8px 0;line-height:1.35}
	.checker-details th,.checker-details td{padding:6px 5px;font-size:12px;line-height:1.3}
	.checker-details .checker-check-button{min-height:36px;padding:6px 8px;font-size:12px}
	.checker-checked{display:inline-flex;align-items:center;color:#16a34a}
	.mobile-product-window.viewing-coming-soon{padding:8px}
	.mobile-product-window.viewing-coming-soon .product-tabs{gap:6px;padding-bottom:8px;margin-bottom:8px}
	.mobile-product-window.viewing-coming-soon .product-tabs button{padding:6px;font-size:13px}
	.editing-products .product-tabs{gap:6px;padding-bottom:8px;margin-bottom:10px}
	.editing-products .product-tabs button{padding:6px 8px;font-size:13px}
	.editing-products .fields{padding:12px;gap:10px}
	.editing-products label,.editing-products .group-field,.editing-products .barcode-field{gap:4px;font-size:13px}
	.editing-products :global(.unit-picker){gap:4px;font-size:13px}
	.editing-products .product-names-row{gap:8px}
	.editing-products input,.editing-products select{padding:8px 10px}
	.editing-products .barcode-controls{gap:6px}
	.editing-products p{margin:4px 0;line-height:1.35}
	.editing-products .multi-units{margin-top:12px}
	.editing-products .unit-heading,.editing-products .row-heading{gap:8px;margin-bottom:8px}
	.editing-products .base-unit{padding:8px 10px;font-size:13px}
	.editing-products .empty{padding:10px}
	.editing-products .unit-row{padding:10px;margin-top:8px}
	.editing-products .unit-fields{gap:8px}
	.editing-products footer{margin-top:12px;padding-top:10px;gap:8px}
	.editing-products footer button{padding:8px;font-size:13px}
	.editing-products .review{margin-top:12px;padding:12px}
	.editing-products .review dl{grid-template-columns:90px minmax(0,1fr);gap:4px 8px;margin:8px 0;font-size:13px}
	.editing-products .review th,.editing-products .review td{padding:6px;font-size:12px}
	.editing-products .manage-scan{gap:6px;margin-bottom:10px}
	.editing-products .manage-scan button{padding:8px;font-size:13px}
	.mobile-product-window.editing-products{padding:8px}
	.mobile-product-window.editing-products .fields{grid-template-columns:repeat(2,minmax(0,1fr));padding:10px;gap:8px}
	.mobile-product-window.editing-products .product-names-row{grid-template-columns:minmax(0,1fr) auto;gap:8px}
	.mobile-product-window.editing-products .product-names-row>label{grid-column:1}
	.mobile-product-window.editing-products .product-names-row>.correct-names{grid-column:2;grid-row:1 / span 2;align-self:center}
	.mobile-product-window.editing-products .unit-fields{grid-template-columns:repeat(2,minmax(0,1fr))}
	.mobile-product-window.editing-products .unit-fields>.barcode-field{grid-column:1 / -1}
	.creation-window.mobile-product-window .product-tabs{gap:4px;padding-bottom:6px;margin-bottom:8px}
	.creation-window.mobile-product-window .product-tabs button{min-height:36px;padding:4px 6px;font-size:12px;line-height:1.15}
</style>
