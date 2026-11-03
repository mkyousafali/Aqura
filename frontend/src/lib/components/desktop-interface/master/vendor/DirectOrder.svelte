<script lang="ts">
	import { onDestroy } from 'svelte';
	import { currentLocale, t } from '$lib/i18n';
	import { directOrderFetch, directOrderRpc, directOrderPhotoData, encodeDirectOrderPhoto } from '$lib/utils/directOrderApi';
	import type { DirectOrder, DirectOrderTemplate } from '$lib/types/directOrder';
	import DirectOrderCamera from './DirectOrderCamera.svelte';
	import DirectOrderTemplates from './DirectOrderTemplates.svelte';

	export let mobile = false;

	let activeTab: 'create' | 'manage' = 'create';
	let selectedTemplate: DirectOrderTemplate | null = null;
	$: templateMeta = selectedTemplate ? [selectedTemplate.shop_location,
		$currentLocale === 'ar' ? selectedTemplate.branch_name_ar || selectedTemplate.branch_name_en : selectedTemplate.branch_name_en || selectedTemplate.branch_name_ar
	].filter(Boolean).join(' · ') : '';
	let draftTemplateId = '';
	let showCreateForm = false;
	let editingOrder: DirectOrder | null = null;
	let existingPhotoUrl = '';
	let editLoading = false;
	let editLoadFailed = false;
	let editController: AbortController | undefined;
	let editRequestId = 0;
	let saveMutationId = '';
	let cameraMode: 'photo' | 'barcode' | null = null;
	let branches: { id: number; name_en: string; name_ar: string | null; location_en: string | null; location_ar: string | null }[] = [];
	let branchesLoading = false;
	let branchError = false;
	let selectedBranchId = '';
	let productCode = '';
	let barcode = '';
	let productNameEn = '';
	let productLookupState: 'idle' | 'loading' | 'found' | 'not-found' | 'error' = 'idle';
	let lookupTimer: ReturnType<typeof setTimeout> | undefined;
	let lookupController: AbortController | undefined;
	let lookupRequestId = 0;
	let photoFile: File | null = null;
	let photoUrl = '';
	let quantity: number | undefined;
	let draftId = '';
	let saving = false;
	let saveErrorKey = '';
	let orderSaved = false;
	let orders: DirectOrder[] = [];
	let ordersLoading = false;
	let ordersError = false;
	let ordersHasMore = false;
	let ordersRequestId = 0;
	let ordersController: AbortController | undefined;
	let selectedOrder: DirectOrder | null = null;
	let detailsLoading = false;
	let detailsError = false;
	let photoLoadError = false;
	let detailsRequestId = 0;
	let detailsController: AbortController | undefined;
	let failedPhotoUrls = new Set<string>();
	let failedPhotoKeys = new Set<string>();
	const photoRequests = new Map<string, Promise<string>>();
	let photoViewer: DirectOrder | null = null;
	let viewerPhotoUrl = '';
	let viewerLoading = false;
	let viewerError = false;
	let viewerRequestId = 0;

	async function loadBranches() {
		if (branchesLoading) return;
		branchesLoading = true;
		branchError = false;
		try {
			const result = await directOrderRpc(mobile, 'direct_order_branches');
			branches = result.branches || [];
		} catch {
			branches = [];
			branchError = true;
		} finally {
			branchesLoading = false;
		}
	}

	function branchLabel(branch: typeof branches[number]): string {
		const name = $currentLocale === 'ar' ? branch.name_ar || branch.name_en : branch.name_en;
		const location = $currentLocale === 'ar' ? branch.location_ar || branch.location_en : branch.location_en;
		return location ? `${name} - ${location}` : name;
	}

	function openCreateForm() {
		if (!selectedTemplate) return;
		if (editingOrder || draftTemplateId !== selectedTemplate.id) resetProductDraft();
		draftTemplateId = selectedTemplate.id;
		if (!draftId) {
			draftId = crypto.randomUUID();
			saveMutationId = crypto.randomUUID();
			selectedBranchId = selectedTemplate.branch_id == null ? '' : String(selectedTemplate.branch_id);
		}
		saveErrorKey = '';
		orderSaved = false;
		showCreateForm = true;
		void loadBranches();
		scheduleProductLookup();
	}

	function closeCreateForm() {
		if (saving) return;
		editRequestId++;
		editController?.abort();
		editController = undefined;
		clearProductLookup();
		cameraMode = null;
		showCreateForm = false;
		if (editingOrder) resetProductDraft();
	}

	function resetProductDraft() {
		editRequestId++;
		editController?.abort();
		editController = undefined;
		clearProductLookup();
		removePhoto();
		editingOrder = null;
		existingPhotoUrl = '';
		editLoading = false;
		editLoadFailed = false;
		quantity = undefined;
		selectedBranchId = '';
		productCode = '';
		barcode = '';
		draftId = '';
		saveMutationId = '';
	}

	function markProductChanged() {
		saveMutationId = crypto.randomUUID();
		saveErrorKey = '';
	}

	async function openEditForm(order: DirectOrder) {
		if (saving || selectedTemplate?.id !== order.template_id) return;
		resetProductDraft();
		closePhoto();
		editingOrder = order;
		draftId = order.id;
		draftTemplateId = order.template_id;
		saveMutationId = crypto.randomUUID();
		saveErrorKey = '';
		orderSaved = false;
		showCreateForm = true;
		editLoading = true;
		const controller = new AbortController();
		editController = controller;
		const requestId = ++editRequestId;
		void loadBranches();
		try {
			const result = await directOrderRpc(mobile, 'direct_order_get_product', { p_template_id: order.template_id, p_product_id: order.id }, controller.signal);
			if (requestId !== editRequestId) return;
			const fresh: DirectOrder = result.order;
			if (!fresh?.id) throw new Error('Product unavailable');
			editingOrder = fresh;
			quantity = Number(fresh.quantity);
			selectedBranchId = fresh.branch_id == null ? '' : String(fresh.branch_id);
			productCode = fresh.product_code || '';
			barcode = fresh.barcode || '';
			productNameEn = fresh.product_name_en || '';
			productLookupState = productNameEn ? 'found' : 'idle';
			const photo = await loadProductPhoto(fresh).catch(() => '');
			if (requestId !== editRequestId) return;
			existingPhotoUrl = photo;
			photoUrl = photo;
		} catch {
			if (requestId === editRequestId) { editLoadFailed = true; saveErrorKey = 'editLoadError'; }
		} finally {
			if (requestId === editRequestId) { editLoading = false; editController = undefined; }
		}
	}

	function showDialog(node: HTMLDialogElement) {
		node.showModal();
		return { destroy: () => node.close() };
	}

	function removePhoto() {
		if (photoUrl.startsWith('blob:')) URL.revokeObjectURL(photoUrl);
		photoUrl = '';
		photoFile = null;
	}

	function removeDraftPhoto() {
		removePhoto();
		if (editingOrder) photoUrl = existingPhotoUrl;
		markProductChanged();
	}

	function usePhoto(file: File) {
		removePhoto();
		photoFile = file;
		photoUrl = URL.createObjectURL(file);
		markProductChanged();
		cameraMode = null;
	}

	function useBarcode(value: string) {
		barcode = value;
		markProductChanged();
		cameraMode = null;
		void lookupProduct();
	}

	function clearProductLookup() {
		clearTimeout(lookupTimer);
		lookupController?.abort();
		lookupController = undefined;
		lookupRequestId++;
		productNameEn = '';
		productLookupState = 'idle';
	}

	function scheduleProductLookup() {
		clearProductLookup();
		if (showCreateForm && selectedBranchId && barcode.trim()) {
			lookupTimer = setTimeout(() => { void lookupProduct(); }, 400);
		}
	}

	function handleBarcodeInput(event: Event) {
		barcode = (event.currentTarget as HTMLInputElement).value;
		markProductChanged();
		scheduleProductLookup();
	}

	function handleBranchChange(event: Event) {
		selectedBranchId = (event.currentTarget as HTMLSelectElement).value;
		markProductChanged();
		scheduleProductLookup();
	}

	async function lookupProduct() {
		clearProductLookup();
		const scanned = barcode.trim();
		const branchId = selectedBranchId;
		if (!showCreateForm || !branchId || !scanned) return;
		const requestId = lookupRequestId;
		const controller = new AbortController();
		lookupController = controller;
		productLookupState = 'loading';
		const timeout = setTimeout(() => controller.abort(), 25000);
		try {
			const response = await directOrderFetch(mobile, '/api/direct-orders/product-lookup', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ branchId: Number(branchId), barcode: scanned }),
				signal: controller.signal
			});
			const result = await response.json();
			if (requestId !== lookupRequestId || branchId !== selectedBranchId || scanned !== barcode.trim()) return;
			if (!response.ok || result?.success !== true) throw new Error('Product lookup failed');
			productNameEn = typeof result.productNameEn === 'string' ? result.productNameEn.trim() : '';
			productLookupState = result.found && productNameEn ? 'found' : 'not-found';
		} catch {
			if (requestId === lookupRequestId) productLookupState = 'error';
		} finally {
			clearTimeout(timeout);
			if (requestId === lookupRequestId) lookupController = undefined;
		}
	}

	async function saveOrder() {
		if (saving || editLoading || editLoadFailed) return;
		const templateId = selectedTemplate?.id;
		if (!templateId || templateId !== draftTemplateId) return;
		saveErrorKey = '';
		if (!photoFile && !editingOrder?.has_photo) { saveErrorKey = 'photoRequired'; return; }
		if (quantity === undefined || !Number.isFinite(quantity) || quantity <= 0) {
			saveErrorKey = 'quantityRequired';
			return;
		}
		if (photoFile && photoFile.size > 10485760) { saveErrorKey = 'photoTooLarge'; return; }
		saving = true;
		try {
			const photo = photoFile ? await encodeDirectOrderPhoto(photoFile) : null;
			const result = await directOrderRpc(mobile, 'direct_order_save_product', {
				p_product_id: draftId, p_template_id: templateId, p_quantity: quantity, p_mutation_id: saveMutationId,
				p_branch_id: selectedBranchId ? Number(selectedBranchId) : null, p_product_code: productCode.trim() || null,
				p_barcode: barcode.trim() || null, p_product_name_en: productLookupState === 'found' ? productNameEn : null,
				p_photo_base64: photo?.base64 || null, p_photo_mime: photo?.mimeType || null,
				p_expected_revision: editingOrder?.revision ?? null
			});
			if (!result.order?.id) throw new Error('Save failed');
			const savedPhoto = photo?.dataUrl || existingPhotoUrl;
			if (savedPhoto) photoRequests.set(productPhotoKey(result.order), Promise.resolve(savedPhoto));
			showCreateForm = false;
			cameraMode = null;
			resetProductDraft();
			orderSaved = true;
			backToOrders();
			void loadOrders();
		} catch (failure) {
			saveErrorKey = (failure as { code?: string })?.code === '40001' ? 'editConflict' : 'saveError';
		} finally {
			saving = false;
		}
	}

	async function loadOrders(more = false) {
		const templateId = selectedTemplate?.id;
		if (!templateId) return;
		if (more && (ordersLoading || !ordersHasMore)) return;
		ordersController?.abort();
		const controller = new AbortController();
		ordersController = controller;
		const requestId = ++ordersRequestId;
		ordersLoading = true;
		ordersError = false;
		try {
			const before = more ? orders[orders.length - 1]?.order_number : undefined;
			const result = await directOrderRpc(mobile, 'direct_order_get_products', { p_template_id: templateId, p_before: before || null }, controller.signal);
			if (requestId !== ordersRequestId || selectedTemplate?.id !== templateId) return;
			if (!Array.isArray(result.orders)) throw new Error('Load failed');
			selectedTemplate = result.template;
			orders = more ? [...orders, ...result.orders] : result.orders;
			ordersHasMore = result.hasMore === true;
		} catch {
			if (requestId === ordersRequestId) ordersError = true;
		} finally {
			if (requestId === ordersRequestId) {
				ordersLoading = false;
				ordersController = undefined;
			}
		}
	}

	function backToOrders() {
		closePhoto();
		detailsRequestId++;
		detailsController?.abort();
		detailsController = undefined;
		selectedOrder = null;
		detailsLoading = false;
		detailsError = false;
		photoLoadError = false;
	}

	function openManageOrders() {
		activeTab = 'manage';
		backToTemplates();
	}

	function backToTemplates() {
		ordersRequestId++;
		ordersController?.abort();
		ordersController = undefined;
		ordersLoading = false;
		ordersError = false;
		orders = [];
		ordersHasMore = false;
		backToOrders();
		selectedTemplate = null;
		orderSaved = false;
	}

	function openTemplate(template: DirectOrderTemplate) {
		backToTemplates();
		selectedTemplate = template;
		void loadOrders();
	}

	async function openOrder(order: DirectOrder) {
		const templateId = selectedTemplate?.id;
		if (!templateId) return;
		detailsController?.abort();
		const controller = new AbortController();
		detailsController = controller;
		const requestId = ++detailsRequestId;
		selectedOrder = { ...order, photo_url: undefined };
		detailsLoading = true;
		detailsError = false;
		photoLoadError = false;
		try {
			const result = await directOrderRpc(mobile, 'direct_order_get_product', { p_template_id: templateId, p_product_id: order.id }, controller.signal);
			if (requestId !== detailsRequestId) return;
			if (!result.order?.id) throw new Error('Details unavailable');
			selectedOrder = result.order;
			const photo = await loadProductPhoto(result.order);
			if (requestId !== detailsRequestId) return;
			selectedOrder = { ...result.order, photo_url: photo };
		} catch {
			if (requestId === detailsRequestId) detailsError = true;
		} finally {
			if (requestId === detailsRequestId) {
				detailsLoading = false;
				detailsController = undefined;
			}
		}
	}

	function productPhotoKey(order: DirectOrder): string {
		return `${order.id}:${order.revision}`;
	}

	function loadProductPhoto(order: DirectOrder): Promise<string> {
		const key = productPhotoKey(order);
		let pending = photoRequests.get(key);
		if (!pending) {
			pending = directOrderPhotoData(mobile, order.template_id, order.id).catch(failure => {
				photoRequests.delete(key);
				throw failure;
			});
			photoRequests.set(key, pending);
		}
		return pending;
	}

	function loadThumbnail(node: HTMLButtonElement, initial: DirectOrder) {
		let order = initial;
		let key = productPhotoKey(order);
		let generation = 0;
		let active = true;
		let observer: IntersectionObserver | undefined;
		async function load() {
			const current = ++generation;
			const product = order;
			const productKey = key;
			try {
				const photo = await loadProductPhoto(product);
				if (!active || current !== generation) return;
				orders = orders.map(item => productPhotoKey(item) === productKey ? { ...item, photo_url: photo } : item);
			} catch {
				if (active && current === generation) failedPhotoKeys = new Set([...failedPhotoKeys, productKey]);
			}
		}
		function observe() {
			if (order.photo_url) return;
			if (typeof IntersectionObserver === 'undefined') { void load(); return; }
			observer = new IntersectionObserver(entries => {
				if (entries.some(entry => entry.isIntersecting)) { observer?.disconnect(); void load(); }
			}, { rootMargin: '200px' });
			observer.observe(node);
		}
		observe();
		return {
			update(next: DirectOrder) {
				order = next;
				const nextKey = productPhotoKey(next);
				if (nextKey !== key) {
					key = nextKey;
					generation++;
					observer?.disconnect();
					observe();
				} else if (!next.photo_url) {
					// Metadata refreshes omit image data; restore a cached photo or
					// retry the RPC when this card becomes visible again.
					observer?.disconnect();
					observe();
				}
			},
			destroy() { active = false; generation++; observer?.disconnect(); }
		};
	}

	function markPhotoFailed(order: DirectOrder) {
		if (order.photo_url) failedPhotoUrls = new Set([...failedPhotoUrls, order.photo_url]);
		failedPhotoKeys = new Set([...failedPhotoKeys, productPhotoKey(order)]);
		photoRequests.delete(productPhotoKey(order));
	}

	function closePhoto() {
		viewerRequestId++;
		photoViewer = null;
		viewerPhotoUrl = '';
		viewerLoading = false;
		viewerError = false;
	}

	async function openPhoto(order: DirectOrder) {
		const requestId = ++viewerRequestId;
		photoViewer = order;
		viewerPhotoUrl = '';
		viewerLoading = true;
		viewerError = false;
		try {
			const photo = await loadProductPhoto(order);
			if (requestId !== viewerRequestId) return;
			viewerPhotoUrl = photo;
			orders = orders.map(product => product.id === order.id ? { ...product, photo_url: viewerPhotoUrl } : product);
			if (selectedOrder?.id === order.id) {
				selectedOrder = { ...selectedOrder, photo_url: viewerPhotoUrl };
				photoLoadError = false;
			}
		} catch {
			if (requestId === viewerRequestId) { viewerError = true; viewerLoading = false; }
		}
	}

	function viewerImageFailed() {
		if (photoViewer) photoRequests.delete(productPhotoKey(photoViewer));
		viewerPhotoUrl = '';
		viewerLoading = false;
		viewerError = true;
	}

	function orderBranch(order: DirectOrder): string {
		return ($currentLocale === 'ar' ? order.branch_name_ar || order.branch_name_en : order.branch_name_en || order.branch_name_ar) || '—';
	}

	function orderDate(value: string): string {
		return new Date(value).toLocaleString($currentLocale === 'ar' ? 'ar-SA' : 'en-GB', {
			dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Riyadh'
		});
	}

	onDestroy(() => {
		editRequestId++;
		editController?.abort();
		ordersRequestId++;
		ordersController?.abort();
		backToOrders();
		clearProductLookup();
		removePhoto();
		photoRequests.clear();
	});
</script>

<div class="direct-order" class:mobile dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<nav class="tab-bar" aria-label={t('nav.directOrder')}>
		<button
			type="button"
			class:active={activeTab === 'create'}
			aria-pressed={activeTab === 'create'}
			on:click={() => { activeTab = 'create'; backToTemplates(); }}
		>
			{t('directOrder.createOrder')}
		</button>
		<button
			type="button"
			class:active={activeTab === 'manage'}
			aria-pressed={activeTab === 'manage'}
			on:click={openManageOrders}
		>
			{t('directOrder.manageOrder')}
		</button>
	</nav>

	<div class="content-area">
		{#if orderSaved}<p class="saved-message" role="status">{t('directOrder.orderSaved')}</p>{/if}
		{#if selectedTemplate}
			<div class="section-header template-header">
				<button class="secondary-button icon-button back-button" type="button" on:click={backToTemplates} aria-label={t('directOrder.backToTemplates')} title={t('directOrder.backToTemplates')}>
					<svg class="back-arrow" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m15 18-6-6 6-6" /></svg>
				</button>
				<div class="template-summary">
					<h2>{selectedTemplate.shop_name || t('directOrder.legacyOrder')} <span class="template-number">#{selectedTemplate.order_number}</span></h2>
					{#if templateMeta}<p class="template-meta" title={templateMeta}>{templateMeta}</p>{/if}
				</div>
			</div>
		{/if}
		{#if !selectedTemplate}
			<DirectOrderTemplates {mobile} canCreate={activeTab === 'create'} on:select={(event) => openTemplate(event.detail)} />
		{:else if selectedOrder}
			<section class="order-details">
				<div class="section-header">
					<h2>{t('directOrder.productDetails')} #{selectedOrder.order_number}</h2>
					<button class="secondary-button icon-button" type="button" on:click={backToOrders} aria-label={t('directOrder.backToProducts')} title={t('directOrder.backToProducts')}>
						<svg class="back-arrow" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m15 18-6-6 6-6" /></svg>
					</button>
				</div>
				{#if detailsLoading}<p class="field-hint" role="status">{t('directOrder.loadingDetails')}</p>{/if}
				{#if detailsError || photoLoadError}
					<div class="load-error" role="alert">
						<p>{t('directOrder.detailsError')}</p>
						<button class="secondary-button" type="button" on:click={() => selectedOrder && openOrder(selectedOrder)}>{t('directOrder.retry')}</button>
					</div>
				{/if}
				<div class="details-grid">
					{#if selectedOrder.photo_url && !photoLoadError}
						<button class="order-photo-button" type="button" on:click={() => selectedOrder && openPhoto(selectedOrder)} aria-label={t('directOrder.viewPhoto')}>
							<img class="order-photo" src={selectedOrder.photo_url} alt={t('directOrder.productPhoto')} on:error={() => photoLoadError = true} />
						</button>
					{/if}
					<dl>
						<div><dt>{t('directOrder.quantity')}</dt><dd>{selectedOrder.quantity}</dd></div>
						<div><dt>{t('directOrder.branch')}</dt><dd>{orderBranch(selectedOrder)}</dd></div>
						<div><dt>{t('directOrder.productNameEnglish')}</dt><dd lang="en" dir="ltr">{selectedOrder.product_name_en || '—'}</dd></div>
						<div><dt>{t('directOrder.productCode')}</dt><dd dir="ltr">{selectedOrder.product_code || '—'}</dd></div>
						<div><dt>{t('directOrder.barcode')}</dt><dd class="barcode-value" dir="ltr">{selectedOrder.barcode || '—'}</dd></div>
						<div><dt>{t('directOrder.createdAt')}</dt><dd>{orderDate(selectedOrder.created_at)}</dd></div>
					</dl>
				</div>
			</section>
		{:else}
			<div class="section-header products-toolbar">
				<h2>{t('directOrder.products')} ({selectedTemplate.product_count})</h2>
				<div class="actions">
					<button class="secondary-button icon-button" type="button" disabled={ordersLoading} on:click={() => loadOrders()} aria-label={t('directOrder.refresh')} title={t('directOrder.refresh')}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 7v5h-5M4 17v-5h5" /><path d="M6.1 7a7 7 0 0 1 11.5-2L20 8M4 16l2.4 3A7 7 0 0 0 17.9 17" /></svg>
					</button>
					<button class="primary-button icon-button add-product-button" type="button" on:click={openCreateForm} aria-label={t('directOrder.addProduct')} title={t('directOrder.addProduct')}>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
					</button>
				</div>
			</div>
			{#if ordersError}
				<div class="load-error" role="alert">
					<p>{t('directOrder.ordersError')}</p>
					<button class="secondary-button" type="button" on:click={() => loadOrders()}>{t('directOrder.retry')}</button>
				</div>
			{/if}
			{#if ordersLoading}<p class="field-hint" role="status">{t('directOrder.loadingOrders')}</p>{/if}
			{#if orders.length > 0}
				{#if mobile}
					<div class="mobile-product-list">
						{#each orders as order (order.id)}
							<article class="product-card">
								<button class="thumbnail-button" type="button" use:loadThumbnail={order} on:click={() => openPhoto(order)} aria-label={t('directOrder.viewPhoto')}>
									{#if order.photo_url && !failedPhotoUrls.has(order.photo_url)}
										<img src={order.photo_url} alt={t('directOrder.productPhoto')} loading="lazy" on:error={() => markPhotoFailed(order)} />
									{:else}
										<span>{t(failedPhotoKeys.has(productPhotoKey(order)) ? 'directOrder.photoUnavailable' : 'directOrder.productPhoto')}</span>
									{/if}
								</button>
								<button class="product-card-details" type="button" on:click={() => openOrder(order)}>
									<span class="card-heading">
										<strong class="product-title" lang="en" dir="ltr" title={order.product_name_en || order.product_code || `#${order.order_number}`}>{order.product_name_en || order.product_code || `#${order.order_number}`}</strong>
										<span class="product-quantity" title={t('directOrder.quantity')}><span class="visually-hidden">{t('directOrder.quantity')}: </span><span aria-hidden="true">× </span>{order.quantity}</span>
									</span>
									{#if order.barcode}<span class="barcode-value product-identifier" dir="ltr" title={t('directOrder.barcode')}><span class="visually-hidden">{t('directOrder.barcode')}: </span>{order.barcode}</span>{/if}
									{#if order.product_name_en && order.product_code && order.product_code !== order.barcode}<span class="product-identifier" dir="ltr" title={t('directOrder.productCode')}><span class="visually-hidden">{t('directOrder.productCode')}: </span>{order.product_code}</span>{/if}
								</button>
								<button class="edit-product-button" type="button" on:click={() => openEditForm(order)} aria-label={t('directOrder.editProduct')} title={t('directOrder.editProduct')}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m16 4 4 4M4 20l4-1L20 7a2.8 2.8 0 0 0-4-4L4 15z" /></svg>
								</button>
							</article>
						{/each}
					</div>
				{:else}
				<div class="orders-table-container">
					<table>
						<thead><tr>
							<th scope="col">{t('directOrder.productNumber')}</th>
							<th scope="col">{t('directOrder.productPhoto')}</th>
							<th scope="col">{t('directOrder.createdAt')}</th>
							<th scope="col">{t('directOrder.branch')}</th>
							<th scope="col">{t('directOrder.productNameEnglish')}</th>
							<th scope="col">{t('directOrder.barcode')}</th>
							<th scope="col">{t('directOrder.quantity')}</th>
							<th scope="col">{t('directOrder.editProduct')}</th>
						</tr></thead>
						<tbody>
							{#each orders as order (order.id)}
								<tr class="order-row">
									<td><button class="order-link" type="button" on:click={() => openOrder(order)} aria-label={t('directOrder.viewProduct', { number: order.order_number })}>#{order.order_number}</button></td>
									<td>
										<button class="thumbnail-button" type="button" use:loadThumbnail={order} on:click={() => openPhoto(order)} aria-label={t('directOrder.viewPhoto')}>
											{#if order.photo_url && !failedPhotoUrls.has(order.photo_url)}
												<img src={order.photo_url} alt={t('directOrder.productPhoto')} loading="lazy" on:error={() => markPhotoFailed(order)} />
											{:else}
												<span>{t(failedPhotoKeys.has(productPhotoKey(order)) ? 'directOrder.photoUnavailable' : 'directOrder.productPhoto')}</span>
											{/if}
										</button>
									</td>
									<td>{orderDate(order.created_at)}</td>
									<td>{orderBranch(order)}</td>
									<td lang="en" dir="ltr">{order.product_name_en || '—'}</td>
									<td class="barcode-value" dir="ltr">{order.barcode || '—'}</td>
									<td>{order.quantity}</td>
									<td><button class="edit-product-button" type="button" on:click={() => openEditForm(order)} aria-label={t('directOrder.editProduct')} title={t('directOrder.editProduct')}>
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m16 4 4 4M4 20l4-1L20 7a2.8 2.8 0 0 0-4-4L4 15z" /></svg>
									</button></td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
				{/if}
				{#if ordersHasMore}
					<button class="secondary-button load-more" type="button" disabled={ordersLoading} on:click={() => loadOrders(true)}>{t('directOrder.loadMore')}</button>
				{/if}
			{:else if !ordersLoading && !ordersError}
				<section class="placeholder"><p>{t('directOrder.noProducts')}</p></section>
			{/if}
		{/if}
	</div>
</div>

{#if photoViewer}
	<dialog class="photo-viewer" use:showDialog dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'} aria-label={t('directOrder.viewPhoto')} on:cancel|preventDefault={closePhoto}>
		<header class="photo-viewer-header">
			<h2>{t('directOrder.productPhoto')} #{photoViewer.order_number}</h2>
			<button class="secondary-button" type="button" on:click={closePhoto}>{t('directOrder.close')}</button>
		</header>
		{#if viewerLoading}<p class="field-hint" role="status">{t('directOrder.loadingPhoto')}</p>{/if}
		{#if viewerError}
			<div class="load-error" role="alert">
				<p>{t('directOrder.photoLoadError')}</p>
				<button class="secondary-button" type="button" on:click={() => photoViewer && openPhoto(photoViewer)}>{t('directOrder.retry')}</button>
			</div>
		{/if}
		{#if viewerPhotoUrl}
			<img class="enlarged-photo" src={viewerPhotoUrl} alt={t('directOrder.productPhoto')} on:load={() => viewerLoading = false} on:error={viewerImageFailed} />
		{/if}
	</dialog>
{/if}

{#if showCreateForm}
	<dialog
		class="order-dialog"
		class:mobile
		dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}
		aria-label={t(editingOrder ? 'directOrder.editProduct' : 'directOrder.addProduct')}
		use:showDialog
		on:cancel|preventDefault={closeCreateForm}
	>
		<header class="section-header">
			<h2>{t(editingOrder ? 'directOrder.editProduct' : 'directOrder.addProduct')}</h2>
			<button class="secondary-button" type="button" on:click={closeCreateForm} disabled={saving} aria-label={t('directOrder.close')}>×</button>
		</header>
		<p class="form-context">{selectedTemplate?.shop_name || t('directOrder.legacyOrder')} · {selectedTemplate?.shop_location || '—'}</p>
		{#if editLoading}<p class="field-hint" role="status">{t('directOrder.loadingDetails')}</p>{/if}
		<fieldset class="order-fields" disabled={saving || editLoading || editLoadFailed}>
			<label class="form-field">
				<span>{t('directOrder.branch')} <span class="optional">({t('directOrder.optional')})</span></span>
				<select bind:value={selectedBranchId} on:change={handleBranchChange} disabled={branchesLoading || branchError}>
					<option value="">{t(branchesLoading ? 'directOrder.loadingBranches' : 'directOrder.selectBranch')}</option>
					{#each branches as branch}
						<option value={String(branch.id)}>{branchLabel(branch)}</option>
					{/each}
				</select>
			</label>
			{#if branchError}
				<div class="branch-error" role="alert">
					<p>{t('directOrder.branchError')}</p>
					<button class="secondary-button" type="button" on:click={loadBranches}>{t('directOrder.retry')}</button>
				</div>
			{:else if !branchesLoading && branches.length === 0}
				<p class="field-hint">{t('directOrder.noBranches')}</p>
			{/if}

			<div class="form-field">
				<span>{t('directOrder.productPhoto')} <span class="required">({t('directOrder.required')})</span></span>
				{#if photoUrl}
					<img class="photo-preview" src={photoUrl} alt={t('directOrder.productPhoto')} />
				{/if}
				<div class="photo-actions">
					<button class="secondary-button" type="button" on:click={() => cameraMode = 'photo'}>
						{t(photoUrl || editingOrder?.has_photo ? 'directOrder.retakePhoto' : 'directOrder.takePhoto')}
					</button>
					{#if photoFile}
						<button class="secondary-button" type="button" on:click={removeDraftPhoto}>{t('directOrder.removePhoto')}</button>
					{/if}
				</div>
			</div>

			<label class="form-field">
				<span>{t('directOrder.quantity')} <span class="required">({t('directOrder.required')})</span></span>
				<input type="number" min="0" step="any" bind:value={quantity} on:input={markProductChanged} placeholder={t('directOrder.enterQuantity')} required />
			</label>

			<label class="form-field">
				<span>{t('directOrder.productCode')} <span class="optional">({t('directOrder.optional')})</span></span>
				<input type="text" bind:value={productCode} on:input={markProductChanged} maxlength="100" placeholder={t('directOrder.enterProductCode')} />
			</label>

			<div class="barcode-controls">
				<label class="form-field">
					<span>{t('directOrder.barcode')} <span class="optional">({t('directOrder.optional')})</span></span>
					<input
						type="text"
						bind:value={barcode}
						on:input={handleBarcodeInput}
						on:keydown={(event) => { if (event.key === 'Enter') { event.preventDefault(); void lookupProduct(); } }}
						maxlength="100"
						placeholder={t('directOrder.enterBarcode')}
						dir="ltr"
					/>
				</label>
				<button class="secondary-button" type="button" on:click={() => cameraMode = 'barcode'} disabled={!selectedBranchId || branchesLoading || branchError} aria-label={t('directOrder.scanBarcode')}>
					{t('directOrder.scan')}
				</button>
			</div>
			{#if !selectedBranchId}
				<p class="field-hint">{t('directOrder.selectBranchToScan')}</p>
			{/if}
			<div class="product-lookup" role="status" aria-live="polite" aria-atomic="true">
				{#if productLookupState === 'loading'}
					<p class="field-hint">{t('directOrder.lookingUpProduct')}</p>
				{:else if productLookupState === 'found'}
					<span class="product-name-label">{t('directOrder.productNameEnglish')}</span>
					<p class="product-name" lang="en" dir="ltr">{productNameEn}</p>
				{:else if productLookupState === 'not-found'}
					<p class="lookup-error">{t('directOrder.productNotFound')}</p>
				{:else if productLookupState === 'error'}
					<p class="lookup-error">{t('directOrder.productLookupError')}</p>
					<button class="secondary-button" type="button" on:click={lookupProduct}>{t('directOrder.retry')}</button>
				{/if}
			</div>
		</fieldset>
		{#if saveErrorKey}
			<div class="load-error" role="alert">
				<p>{t(`directOrder.${saveErrorKey}`)}</p>
				{#if editingOrder && (editLoadFailed || saveErrorKey === 'editConflict')}
					<button class="secondary-button" type="button" on:click={() => editingOrder && openEditForm(editingOrder)}>{t('directOrder.refresh')}</button>
				{/if}
			</div>
		{/if}
		<footer>
			<button class="secondary-button" type="button" on:click={closeCreateForm} disabled={saving}>{t('directOrder.close')}</button>
			<button class="primary-button" type="button" on:click={saveOrder} disabled={saving || editLoading || editLoadFailed}>{t(saving ? 'directOrder.saving' : 'directOrder.save')}</button>
		</footer>
		{#if cameraMode}
			<DirectOrderCamera
				mode={cameraMode}
				on:photo={(event) => usePhoto(event.detail)}
				on:scan={(event) => useBarcode(event.detail)}
				on:close={() => cameraMode = null}
			/>
		{/if}
	</dialog>
{/if}

<style>
	.direct-order {
		display: flex;
		flex-direction: column;
		min-height: 100%;
		background: #fff;
	}

	.tab-bar {
		display: flex;
		gap: 8px;
		padding: 16px 24px 0;
		border-bottom: 1px solid #e5e7eb;
	}

	.tab-bar button {
		padding: 12px 16px;
		border: 0;
		border-bottom: 3px solid transparent;
		background: transparent;
		color: #6b7280;
		font: inherit;
		font-weight: 600;
		cursor: pointer;
	}

	.tab-bar button:hover {
		background: #f9fafb;
		color: #1f2937;
	}

	.tab-bar button.active {
		border-bottom-color: #2563eb;
		color: #2563eb;
	}

	.tab-bar button:focus-visible {
		outline: 2px solid #2563eb;
		outline-offset: 2px;
	}

	.content-area {
		flex: 1;
		padding: 24px;
	}

	.placeholder {
		padding: 56px 24px;
		border: 1px dashed #d1d5db;
		border-radius: 12px;
		background: #f9fafb;
		text-align: center;
	}

	.placeholder p {
		margin: 0;
		color: #6b7280;
	}

	.section-header { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-bottom: 20px; }
	.actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
	.template-header { display: grid; grid-template-columns: 40px minmax(0, 1fr); align-items: center; gap: 8px; margin-bottom: 12px; padding-bottom: 10px; border-bottom: 1px solid #e5e7eb; }
	.template-summary { min-width: 0; }
	.template-summary h2 { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.template-meta { margin: 3px 0 0; overflow: hidden; color: #6b7280; font-size: 12px; line-height: 1.4; text-overflow: ellipsis; white-space: nowrap; }
	.template-number { color: #6b7280; font-size: 14px; font-weight: 400; }
	.form-context { margin: 0 0 20px; color: #6b7280; font-size: 14px; }
	.section-header h2 { margin: 0; font-size: 20px; font-weight: 600; color: #1f2937; }
	.primary-button, .secondary-button { padding: 10px 16px; border: 1px solid #d1d5db; border-radius: 8px; background: white; color: #374151; font: inherit; font-weight: 600; cursor: pointer; }
	.primary-button { background: #2563eb; color: white; border-color: #2563eb; }
	.primary-button:hover { background: #1d4ed8; }
	.secondary-button:hover { background: #f3f4f6; }
	.primary-button:focus-visible, .secondary-button:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
	.order-dialog { box-sizing: border-box; width: calc(100% - 32px); max-width: 600px; max-height: calc(100% - 32px); padding: 24px; border: 0; border-radius: 12px; color: #1f2937; background: white; }
	.order-dialog::backdrop { background: #0f172a99; }
	.order-fields { display: flex; flex-direction: column; gap: 20px; min-width: 0; margin: 0; padding: 0; border: 0; }
	.form-field { display: flex; flex-direction: column; gap: 8px; min-width: 0; font-size: 14px; font-weight: 600; }
	.form-field input, .form-field select { box-sizing: border-box; width: 100%; min-width: 0; padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 8px; color: #1f2937; background: white; font: inherit; font-weight: 400; }
	.form-field input:focus, .form-field select:focus { outline: 2px solid #2563eb; outline-offset: 1px; }
	.form-field select:disabled { background: #f3f4f6; }
	.optional, .field-hint { color: #6b7280; font-weight: 400; }
	.field-hint { margin: 0; font-size: 14px; }
	.barcode-controls { display: flex; align-items: flex-end; gap: 8px; }
	.barcode-controls .form-field { flex: 1; }
	.photo-actions { display: flex; flex-wrap: wrap; gap: 8px; }
	.photo-preview { max-width: 100%; width: 320px; max-height: 240px; object-fit: contain; border: 1px solid #e5e7eb; border-radius: 8px; }
	.branch-error { color: #b91c1c; font-size: 14px; }
	.branch-error p { margin: 0 0 8px; }
	.primary-button:disabled, .secondary-button:disabled { opacity: 0.5; cursor: not-allowed; }
	.product-name-label { font-size: 14px; font-weight: 600; color: #374151; }
	.product-name { margin: 8px 0 0; padding: 12px; border: 1px solid #bbf7d0; border-radius: 8px; background: #f0fdf4; color: #166534; overflow-wrap: anywhere; }
	.lookup-error { margin: 0 0 8px; font-size: 14px; color: #b91c1c; }
	footer { display: flex; justify-content: flex-end; gap: 8px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #e5e7eb; }
	.required { color: #b91c1c; font-size: 12px; font-weight: 400; }
	.saved-message { margin: 0 0 20px; padding: 12px 16px; border: 1px solid #bbf7d0; border-radius: 8px; background: #f0fdf4; color: #166534; }
	.load-error { margin: 16px 0; padding: 12px; border: 1px solid #fecaca; border-radius: 8px; background: #fef2f2; color: #b91c1c; }
	.load-error p { margin: 0 0 8px; }
	.orders-table-container { overflow-x: auto; margin-top: 16px; border: 1px solid #e5e7eb; border-radius: 10px; }
	table { width: 100%; border-collapse: collapse; font-size: 14px; }
	th, td { padding: 14px 16px; text-align: start; border-bottom: 1px solid #e5e7eb; }
	th { background: #f9fafb; color: #374151; white-space: nowrap; }
	tbody tr:last-child td { border-bottom: 0; }
	.order-row { position: relative; }
	.order-row:hover, .order-row:focus-within { background: #eff6ff; }
	.order-link { padding: 0; border: 0; background: transparent; color: #2563eb; font: inherit; font-weight: 600; cursor: pointer; }
	.order-link::after { content: ''; position: absolute; inset: 0; }
	.order-link:focus-visible { outline: 2px solid #2563eb; outline-offset: 4px; }
	.barcode-value { font-family: monospace; overflow-wrap: anywhere; }
	.load-more { margin-top: 16px; }
	.details-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(220px, 1fr); gap: 24px; margin-top: 20px; }
	.order-photo { width: 100%; max-height: 520px; object-fit: contain; border: 1px solid #e5e7eb; border-radius: 12px; }
	dl { display: flex; flex-direction: column; gap: 16px; margin: 0; }
	dl > div { padding-bottom: 12px; border-bottom: 1px solid #e5e7eb; }
	dt { margin-bottom: 6px; color: #6b7280; font-size: 13px; }
	dd { margin: 0; color: #1f2937; font-weight: 600; overflow-wrap: anywhere; }
	@media (max-width: 640px) { .details-grid { grid-template-columns: minmax(0, 1fr); } }
	.mobile { min-height: 0; min-width: 0; width: 100%; }
	.mobile .tab-bar { gap: 0; padding: 0 12px; }
	.mobile .tab-bar button { flex: 1; min-height: 40px; padding: 8px; font-size: 14px; }
	.mobile .content-area { min-width: 0; padding: 10px 12px; }
	.mobile .section-header { flex-wrap: wrap; align-items: flex-start; gap: 12px; }
	.mobile .section-header h2 { font-size: 18px; overflow-wrap: anywhere; }
	.mobile .actions { width: 100%; }
	.mobile .actions button { flex: 1; }
	.mobile .primary-button, .mobile .secondary-button { min-height: 44px; }
	.mobile .section-header > .secondary-button { width: 100%; }
	.mobile .details-grid { grid-template-columns: minmax(0, 1fr); gap: 16px; }
	.mobile .order-photo { max-height: 55dvh; }
	.mobile-product-list { display: grid; gap: 8px; margin-top: 8px; }
	.product-card { box-sizing: border-box; display: flex; align-items: center; gap: 10px; width: 100%; padding: 8px; border: 1px solid #e5e7eb; border-radius: 8px; background: white; color: #1f2937; font: inherit; text-align: start; }
	.product-card:hover, .product-card:focus-within { background: #eff6ff; border-color: #93c5fd; }
	.product-card-details { display: flex; flex: 1; flex-direction: column; justify-content: center; gap: 4px; min-width: 0; min-height: 64px; padding: 0; border: 0; background: transparent; color: inherit; font: inherit; font-size: 14px; line-height: 1.3; text-align: start; cursor: pointer; }
	.product-card-details:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
	.edit-product-button { position: relative; z-index: 1; display: inline-flex; align-items: center; justify-content: center; align-self: center; flex: 0 0 32px; width: 32px; height: 32px; padding: 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; color: #374151; cursor: pointer; }
	.edit-product-button:hover { background: #eff6ff; border-color: #93c5fd; }
	.edit-product-button:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
	.card-heading { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; }
	.card-heading strong { min-width: 0; overflow-wrap: anywhere; text-align: start; }
	.card-heading > span { color: #2563eb; white-space: nowrap; }
	.card-heading .product-quantity { flex-shrink: 0; padding: 3px 6px; border-radius: 5px; background: #f3f4f6; color: #374151; font-size: 13px; font-weight: 600; }
	.product-title { display: -webkit-box; overflow: hidden; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
	.product-identifier { overflow: hidden; color: #6b7280; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
	.visually-hidden { position: absolute; width: 1px; height: 1px; margin: -1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
	.order-dialog.mobile { width: calc(100% - 16px); max-height: calc(100dvh - 16px); padding: 16px; padding-bottom: max(16px, env(safe-area-inset-bottom)); }
	.order-dialog.mobile input, .order-dialog.mobile select { min-height: 44px; font-size: 16px; }
	.order-dialog.mobile footer { position: sticky; bottom: 0; background: white; }
	.order-dialog.mobile footer button { flex: 1; }
	.thumbnail-button { position: relative; z-index: 1; flex-shrink: 0; display: flex; align-items: center; justify-content: center; width: 72px; height: 72px; padding: 0; overflow: hidden; border: 1px solid #d1d5db; border-radius: 8px; background: #f3f4f6; color: #6b7280; cursor: zoom-in; }
	.thumbnail-button img { display: block; width: 100%; height: 100%; object-fit: cover; }
	.thumbnail-button span { padding: 4px; font-size: 11px; line-height: 1.3; text-align: center; }
	.thumbnail-button:focus-visible, .order-photo-button:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
	.product-card .thumbnail-button { width: 64px; height: 64px; }
	.order-photo-button { align-self: start; padding: 0; border: 0; border-radius: 12px; background: transparent; cursor: zoom-in; }
	.photo-viewer { position: fixed; inset: 0; margin: auto; box-sizing: border-box; width: calc(100% - 16px); height: fit-content; max-width: 1100px; max-height: calc(100dvh - 16px); overflow: auto; padding: 16px; border: 0; border-radius: 12px; background: white; color: #1f2937; }
	.photo-viewer::backdrop { background: #0f172ad9; }
	.photo-viewer-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 16px; }
	.photo-viewer-header h2 { margin: 0; font-size: 18px; font-weight: 600; }
	.photo-viewer button { min-height: 44px; }
	.enlarged-photo { display: block; max-width: 100%; max-height: calc(100dvh - 140px); width: auto; height: auto; margin: 0 auto; object-fit: contain; border-radius: 8px; }
	.icon-button { display: inline-flex; align-items: center; justify-content: center; flex: 0 0 40px; width: 40px; height: 40px; min-height: 40px; padding: 0; }
	.back-button { border-color: transparent; background: transparent; }
	.direct-order[dir="rtl"] .back-arrow { transform: rotate(180deg); }
	.products-toolbar { flex-wrap: nowrap; gap: 8px; margin-bottom: 8px; }
	.products-toolbar h2 { font-size: 16px; }
	.products-toolbar .actions { flex-shrink: 0; gap: 6px; }
	.mobile .template-header { align-items: center; gap: 8px; }
	.mobile .section-header > .icon-button { flex: 0 0 40px; width: 40px; min-height: 40px; }
	.mobile .products-toolbar { flex-wrap: nowrap; align-items: center; gap: 8px; }
	.mobile .products-toolbar h2 { font-size: 16px; }
	.mobile .products-toolbar .actions { width: auto; }
	.mobile .products-toolbar .actions .icon-button { flex: 0 0 40px; width: 40px; min-height: 40px; }
	@media (max-width: 360px) { .product-card { gap: 8px; } .product-card .thumbnail-button { width: 56px; height: 56px; } }
</style>
