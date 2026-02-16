<script lang="ts">
	import { currentLocale } from '$lib/i18n';
	import { onMount, onDestroy, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface BranchConfig {
		id: string;
		branch_id: number;
		branch_name: string;
		tunnel_url: string;
		erp_branch_id: number;
	}

	interface PriceResult {
		barcode: string;
		product_name_en: string;
		product_name_ar: string;
		prices: PriceUnit[];
		offer?: OfferInfo | null;
	}

	interface PriceUnit {
		barcode: string;
		sprice: number;
		multi_factor: number;
		unit_name: string;
	}

	interface OfferInfo {
		scheme_name: string;
		scheme_type: string;
		scheme_price: number;
		qty_limit: number;
		free_qty: number;
		date_from: string;
		date_to: string;
		range_from?: number;
		range_to?: number;
	}

	// Branch & connection state
	let branches: BranchConfig[] = [];
	let selectedBranchId: number | null = null;
	let loadingBranches = true;
	let connectionStatus: 'idle' | 'testing' | 'ok' | 'fail' = 'idle';
	let connectionMessage = '';

	// Barcode & product state
	let barcode = '';
	let scanning = false;
	let videoEl: HTMLVideoElement;
	let stream: MediaStream | null = null;
	let scanInterval: ReturnType<typeof setInterval> | null = null;
	let lookingUp = false;
	let product: PriceResult | null = null;
	let lookupError = '';

	// History of scanned items
	let scanHistory: PriceResult[] = [];

	$: isRtl = $currentLocale === 'ar';
	$: selectedConfig = branches.find(b => b.branch_id === selectedBranchId) || null;

	onMount(async () => {
		await loadBranches();
	});

	onDestroy(() => {
		stopScan();
	});

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error } = await supabase
				.from('erp_connections')
				.select('id, branch_id, branch_name, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_name');
			if (error) throw error;
			branches = data || [];

			// Fetch actual branch names
			if (branches.length > 0) {
				const branchIds = branches.map(b => b.branch_id);
				const { data: branchData } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar')
					.in('id', branchIds);
				if (branchData) {
					const branchMap = new Map(branchData.map((b: any) => [Number(b.id), b]));
					branches = branches.map(b => {
						const info: any = branchMap.get(b.branch_id);
						if (info) {
							const name = isRtl ? (info.name_ar || info.name_en) : (info.name_en || info.name_ar);
							const loc = isRtl ? (info.location_ar || info.location_en || '') : (info.location_en || info.location_ar || '');
							b.branch_name = loc ? `${name} - ${loc}` : name;
						}
						return b;
					});
				}
			}

			// Default to user's branch
			const userBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
			if (userBranchId && branches.some(b => b.branch_id === userBranchId)) {
				selectedBranchId = userBranchId;
				await tick();
				await testConnection();
			} else if (branches.length > 0) {
				selectedBranchId = branches[0].branch_id;
				await tick();
				await testConnection();
			}
		} catch (err) {
			console.error('Error loading ERP connections:', err);
		} finally {
			loadingBranches = false;
		}
	}

	async function testConnection() {
		if (!selectedConfig) return;
		connectionStatus = 'testing';
		connectionMessage = '';
		try {
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'test',
					tunnelUrl: selectedConfig.tunnel_url
				})
			});
			const result = await response.json();
			if (result.success) {
				connectionStatus = 'ok';
				connectionMessage = isRtl ? 'متصل' : 'Connected';
			} else {
				connectionStatus = 'fail';
				connectionMessage = result.error || (isRtl ? 'فشل الاتصال' : 'Connection failed');
			}
		} catch (err: any) {
			connectionStatus = 'fail';
			connectionMessage = err.message || 'Error';
		}
	}

	async function onBranchChange() {
		product = null;
		barcode = '';
		lookupError = '';
		connectionStatus = 'idle';
		scanHistory = [];
		await testConnection();
	}

	// --- Barcode scanning ---
	let scanCanvas: HTMLCanvasElement | null = null;
	let scanCtx: CanvasRenderingContext2D | null = null;
	let barcodeDetector: any = null;

	async function startScan() {
		scanning = true;
		try {
			stream = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
			});
			await new Promise(r => setTimeout(r, 100));
			if (videoEl) {
				videoEl.srcObject = stream;
				await videoEl.play();
				// Wait for video to actually start playing
				await new Promise(r => setTimeout(r, 500));
				await initDetector();
				detectBarcode();
			}
		} catch (err: any) {
			console.error('Camera access error:', err);
			lookupError = 'Camera error: ' + (err.message || 'Access denied');
			scanning = false;
		}
	}

	async function initDetector() {
		// Try native BarcodeDetector first (Chrome/Android)
		// @ts-ignore
		if ('BarcodeDetector' in window) {
			try {
				// @ts-ignore
				barcodeDetector = new window.BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'qr_code'] });
				console.log('[scan] Using native BarcodeDetector');
				return;
			} catch (e) {
				console.warn('[scan] Native BarcodeDetector failed:', e);
			}
		}
		// Fallback: dynamically import polyfill (avoids SSR issues)
		try {
			const { BarcodeDetector: Polyfill } = await import('barcode-detector');
			barcodeDetector = new Polyfill({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'qr_code'] });
			console.log('[scan] Using barcode-detector polyfill');
		} catch (e) {
			console.error('[scan] Failed to load barcode detector polyfill:', e);
		}
	}

	function detectBarcode() {
		if (!barcodeDetector) {
			console.error('[scan] No barcode detector available');
			lookupError = 'Barcode scanner not available on this device';
			stopScan();
			return;
		}

		// Create offscreen canvas for frame capture (needed for iOS Safari)
		scanCanvas = document.createElement('canvas');
		scanCtx = scanCanvas.getContext('2d');

		scanInterval = setInterval(async () => {
			if (!videoEl || videoEl.readyState < 2 || !scanCanvas || !scanCtx) return;
			try {
				// Capture video frame to canvas (works on all browsers including iOS Safari)
				const vw = videoEl.videoWidth;
				const vh = videoEl.videoHeight;
				if (vw === 0 || vh === 0) return;
				scanCanvas.width = vw;
				scanCanvas.height = vh;
				scanCtx.drawImage(videoEl, 0, 0, vw, vh);

				// Try detect on canvas first, fallback to ImageData
				let barcodes: any[] = [];
				try {
					barcodes = await barcodeDetector.detect(scanCanvas);
				} catch (_) {
					// Some polyfills need ImageData instead of canvas
					try {
						const imageData = scanCtx.getImageData(0, 0, vw, vh);
						barcodes = await barcodeDetector.detect(imageData);
					} catch (__) {}
				}

				if (barcodes.length > 0) {
					barcode = barcodes[0].rawValue;
					stopScan();
					await lookupProduct(barcode);
				}
			} catch (_) {}
		}, 400);
	}

	function stopScan() {
		if (scanInterval) { clearInterval(scanInterval); scanInterval = null; }
		if (stream) { stream.getTracks().forEach(t => t.stop()); stream = null; }
		scanCanvas = null;
		scanCtx = null;
		scanning = false;
	}

	// --- Product lookup: get name from Supabase, price from ERP bridge ---
	async function lookupProduct(bc: string) {
		if (!bc || bc.trim().length < 3) return;
		lookingUp = true;
		lookupError = '';
		product = null;
		try {
			// 1. Get product name from erp_synced_products
			const { data: syncedProduct, error: spError } = await supabase
				.from('erp_synced_products')
				.select('barcode, product_name_en, product_name_ar, parent_barcode')
				.eq('barcode', bc.trim())
				.limit(1)
				.maybeSingle();
			if (spError) throw spError;

			let productNameEn = '';
			let productNameAr = '';
			let parentBarcode = '';

			if (syncedProduct) {
				productNameEn = syncedProduct.product_name_en || '';
				productNameAr = syncedProduct.product_name_ar || '';
				parentBarcode = syncedProduct.parent_barcode || '';
			}

			// 2. Get price from ERP bridge server directly
			if (!selectedConfig) throw new Error(isRtl ? 'لم يتم اختيار الفرع' : 'No branch selected');

			const priceResponse = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'price-check',
					tunnelUrl: selectedConfig.tunnel_url,
					barcode: bc.trim(),
					erpBranchId: selectedConfig.erp_branch_id
				})
			});
			const priceResult = await priceResponse.json();

			if (!priceResult.success) {
				// If we have product name but no price, still show what we have
				if (syncedProduct) {
					product = {
						barcode: bc.trim(),
						product_name_en: productNameEn,
						product_name_ar: productNameAr,
						prices: []
					};
					lookupError = isRtl ? 'لم يتم العثور على السعر في ERP' : 'Price not found in ERP';
				} else {
					lookupError = isRtl ? 'لم يتم العثور على المنتج' : 'Product not found';
				}
				return;
			}

			// Use ERP name if Supabase didn't have it
			if (!productNameEn && priceResult.productName) {
				productNameEn = priceResult.productName;
			}
			if (!productNameAr && priceResult.productNameAr) {
				productNameAr = priceResult.productNameAr;
			}

			product = {
				barcode: bc.trim(),
				product_name_en: productNameEn,
				product_name_ar: productNameAr,
				prices: priceResult.prices || [],
				offer: priceResult.offer || null
			};

			// Add to history (avoid duplicates)
			if (product && product.prices.length > 0) {
				scanHistory = [product, ...scanHistory.filter(h => h.barcode !== product!.barcode)].slice(0, 20);
			}
		} catch (err: any) {
			lookupError = err.message || 'Lookup error';
		} finally {
			lookingUp = false;
		}
	}

	function getProductName(p: PriceResult): string {
		if (isRtl && p.product_name_ar) return p.product_name_ar;
		return p.product_name_en || p.product_name_ar || '';
	}

	function clearProduct() {
		product = null;
		barcode = '';
		lookupError = '';
	}

	function formatPrice(price: number): string {
		return price.toFixed(2).replace(/\.00$/, '');
	}
</script>

<div class="page-container" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Branch Selection -->
	<div class="section-card">
		<label class="field-label">{isRtl ? 'الفرع' : 'Branch'}</label>
		<select class="field-select" bind:value={selectedBranchId} on:change={onBranchChange} disabled={loadingBranches}>
			{#if loadingBranches}
				<option>{isRtl ? 'جار التحميل...' : 'Loading...'}</option>
			{:else}
				{#each branches as b}
					<option value={b.branch_id}>{b.branch_name}</option>
				{/each}
			{/if}
		</select>

		<!-- Connection status -->
		<div class="connection-status">
			{#if connectionStatus === 'testing'}
				<span class="status-dot testing"></span>
				<span class="status-text">{isRtl ? 'جار الاختبار...' : 'Testing...'}</span>
			{:else if connectionStatus === 'ok'}
				<span class="status-dot ok"></span>
				<span class="status-text ok-text">{connectionMessage}</span>
			{:else if connectionStatus === 'fail'}
				<span class="status-dot fail"></span>
				<span class="status-text fail-text">{connectionMessage}</span>
				<button class="retry-btn" on:click={testConnection}>{isRtl ? 'إعادة' : 'Retry'}</button>
			{/if}
		</div>
	</div>

	<!-- Barcode Field (only if connection OK) -->
	{#if connectionStatus === 'ok'}
		<div class="section-card">
			<label class="field-label">{isRtl ? 'باركود المنتج' : 'Product Barcode'}</label>
			<div class="barcode-input-row">
				<input
					type="text"
					class="field-input"
					bind:value={barcode}
					placeholder={isRtl ? 'أدخل الباركود' : 'Enter barcode'}
					inputmode="numeric"
					on:keydown={(e) => { if (e.key === 'Enter') lookupProduct(barcode); }}
				/>
				{#if lookingUp}<span class="lookup-spinner">⏳</span>{/if}
				<button class="scan-btn" on:click={scanning ? stopScan : startScan}>
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/>
						<path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
						<line x1="7" y1="12" x2="17" y2="12"/>
					</svg>
				</button>
				<button class="search-btn" on:click={() => lookupProduct(barcode)} disabled={!barcode || lookingUp}>
					🔍
				</button>
			</div>

			{#if lookupError}
				<div class="error-msg">{lookupError}</div>
			{/if}
		</div>

		<!-- Product Info -->
		{#if product}
			<div class="section-card product-card">
				<div class="product-name">{getProductName(product)}</div>
				<div class="product-barcode">{isRtl ? 'باركود:' : 'Barcode:'} {product.barcode}</div>

				{#if product.prices.length > 0}
					<!-- Main price (the scanned barcode's unit) -->
					{@const mainPrice = product.prices.find(p => p.barcode === product?.barcode) || product.prices[0]}
					<div class="price-main-row">
						<div class="price-main-label">{isRtl ? 'السعر' : 'Price'}</div>
						<div class="price-main-value" class:has-offer={product.offer}>{formatPrice(mainPrice.sprice)}</div>
						<div class="price-main-unit">{mainPrice.unit_name} {mainPrice.multi_factor > 1 ? `(×${mainPrice.multi_factor})` : ''}</div>
					</div>

					<!-- Offer / Scheme info -->
					{#if product.offer}
						{@const offer = product.offer}
						{@const isCashDiscount = offer.scheme_type === 'Cash Discount'}
						{@const isBuyNForPrice = offer.scheme_type === 'Buy Exact N for off' && offer.qty_limit > 1}
						{@const isBuyNGetFree = (offer.scheme_type === 'Buy N qty off' || offer.scheme_type === 'Buy N get M free' || offer.scheme_type === '@Buy N qty off') && offer.qty_limit > 0 && offer.free_qty > 0}
						{@const isGiftOnBilling = offer.scheme_type === 'Gift on Billing' && (offer.range_from ?? 0) > 0}
						{@const regularTotal = mainPrice.sprice * offer.qty_limit}
						{@const offerTotal = offer.scheme_price * offer.qty_limit}
						{@const freeTotal = isBuyNGetFree ? mainPrice.sprice * offer.free_qty : 0}
						<div class="offer-card">
							<div class="offer-badge">
								<span class="offer-badge-icon">{isGiftOnBilling ? '🎁' : '🏷️'}</span>
								<span>{isCashDiscount 
									? (isRtl ? 'عرض خاص' : 'Special Offer')
									: isBuyNGetFree
										? (isRtl ? 'عرض مجاني' : 'Free Offer')
										: isGiftOnBilling
											? (isRtl ? 'هدية على الفاتورة' : 'Gift on Billing')
											: (isRtl ? 'عرض كمية' : 'Qty Offer')}</span>
							</div>

							{#if isCashDiscount}
								<!-- Cash Discount: simple price override, qty_limit = max per customer -->
								<div class="offer-prices-simple">
									<div class="offer-price-before">
										<span class="offer-label">{isRtl ? 'قبل' : 'Before'}</span>
										<span class="offer-old-price">{formatPrice(mainPrice.sprice)}</span>
									</div>
									<div class="offer-arrow">→</div>
									<div class="offer-price-after">
										<span class="offer-label">{isRtl ? 'بعد' : 'After'}</span>
										<span class="offer-new-price">{formatPrice(offer.scheme_price)}</span>
									</div>
								</div>
								{#if offer.qty_limit >= 1}
									<div class="offer-limit">
										{isRtl 
											? `الحد: ${offer.qty_limit} لكل عميل` 
											: `Limit: ${offer.qty_limit} per customer`}
									</div>
								{/if}
								<div class="offer-savings">
									{isRtl ? 'توفير' : 'Save'} {formatPrice(mainPrice.sprice - offer.scheme_price)}
								</div>
							{:else if isBuyNGetFree}
								<!-- Buy N get M free: e.g. Buy 5 get 1 free -->
								<div class="offer-qty-badge offer-free-badge">
									{isRtl 
										? `اشتري ${offer.qty_limit} واحصل على ${offer.free_qty} مجاناً`
										: `Buy ${offer.qty_limit} Get ${offer.free_qty} Free`}
								</div>
								<div class="offer-prices-simple">
									<div class="offer-price-before">
										<span class="offer-label">{isRtl ? 'بدون العرض' : 'Without offer'}</span>
										<span class="offer-old-price">{formatPrice(mainPrice.sprice * (offer.qty_limit + offer.free_qty))}</span>
									</div>
									<div class="offer-arrow">→</div>
									<div class="offer-price-after">
										<span class="offer-label">{isRtl ? 'مع العرض' : 'With offer'}</span>
										<span class="offer-new-price">{formatPrice(mainPrice.sprice * offer.qty_limit)}</span>
									</div>
								</div>
								<div class="offer-savings">
									{isRtl ? 'توفير' : 'Save'} {formatPrice(freeTotal)}
								</div>
							{:else if isGiftOnBilling}
								<!-- Gift on Billing: discounted price when bill total reaches threshold -->
								<div class="offer-qty-badge offer-gift-badge">
									{isRtl 
										? `عند شراء بقيمة ${offer.range_from} - ${offer.range_to} ر.س`
										: `On bill ${offer.range_from} - ${offer.range_to} SAR`}
								</div>
								<div class="offer-prices-simple">
									<div class="offer-price-before">
										<span class="offer-label">{isRtl ? 'السعر العادي' : 'Regular'}</span>
										<span class="offer-old-price">{formatPrice(mainPrice.sprice)}</span>
									</div>
									<div class="offer-arrow">→</div>
									<div class="offer-price-after">
										<span class="offer-label">{isRtl ? 'سعر العرض' : 'Offer price'}</span>
										<span class="offer-new-price">{formatPrice(offer.scheme_price)}</span>
									</div>
								</div>
								{#if offer.qty_limit > 1}
									<div class="offer-limit">
										{isRtl 
											? `الكمية: ${offer.qty_limit}` 
											: `Qty: ${offer.qty_limit}`}
									</div>
								{/if}
								<div class="offer-savings">
									{isRtl ? 'توفير' : 'Save'} {formatPrice(mainPrice.sprice - offer.scheme_price)}
								</div>
							{:else if isBuyNForPrice}
								<!-- Buy Exact N: must buy N pieces to get scheme price -->
								<div class="offer-qty-badge">
									{isRtl ? `اشتري ${offer.qty_limit}` : `Buy ${offer.qty_limit}`}
								</div>
								<div class="offer-prices-simple">
									<div class="offer-price-before">
										<span class="offer-label">{isRtl ? 'قبل' : 'Before'}</span>
										<span class="offer-old-price">{formatPrice(regularTotal)}</span>
									</div>
									<div class="offer-arrow">→</div>
									<div class="offer-price-after">
										<span class="offer-label">{isRtl ? 'بعد' : 'After'}</span>
										<span class="offer-new-price">{formatPrice(offerTotal)}</span>
									</div>
								</div>
								<div class="offer-per-piece">
									{isRtl ? `سعر الحبة: ${formatPrice(offer.scheme_price)}` : `Per piece: ${formatPrice(offer.scheme_price)}`}
								</div>
								<div class="offer-savings">
									{isRtl ? 'توفير' : 'Save'} {formatPrice(regularTotal - offerTotal)}
								</div>
							{:else}
								<!-- Other scheme types: show simple before/after -->
								<div class="offer-prices-simple">
									<div class="offer-price-before">
										<span class="offer-label">{isRtl ? 'قبل' : 'Before'}</span>
										<span class="offer-old-price">{formatPrice(mainPrice.sprice)}</span>
									</div>
									<div class="offer-arrow">→</div>
									<div class="offer-price-after">
										<span class="offer-label">{isRtl ? 'بعد' : 'After'}</span>
										<span class="offer-new-price">{formatPrice(offer.scheme_price)}</span>
									</div>
								</div>
								<div class="offer-savings">
									{isRtl ? 'توفير' : 'Save'} {formatPrice(mainPrice.sprice - offer.scheme_price)}
								</div>
							{/if}
						</div>
					{/if}
				{:else}
					<div class="no-price-msg">
						{isRtl ? 'لا يوجد سعر متاح' : 'No price available'}
					</div>
				{/if}

				<div class="action-buttons-row">
					<button class="clear-btn" on:click={clearProduct}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
							<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
						{isRtl ? 'التالي' : 'Next'}
					</button>
				</div>
			</div>
		{/if}

		<!-- Scan History -->
		{#if scanHistory.length > 0 && !product}
			<div class="section-card history-section">
				<div class="history-header">
					<span class="history-title">{isRtl ? 'السجل' : 'History'}</span>
					<button class="history-clear" on:click={() => scanHistory = []}>
						{isRtl ? 'مسح' : 'Clear'}
					</button>
				</div>
				{#each scanHistory as item}
					<button class="history-item" on:click={() => { barcode = item.barcode; product = item; }}>
						<div class="history-item-name">{getProductName(item)}</div>
						<div class="history-item-info">
							<span class="history-item-barcode">{item.barcode}</span>
							{#if item.prices.length > 0}
								<span class="history-item-price">{formatPrice(item.prices[0].sprice)}</span>
							{/if}
						</div>
					</button>
				{/each}
			</div>
		{/if}
	{/if}
</div>

<!-- Scanner overlay -->
{#if scanning}
	<div class="scanner-overlay" on:click={stopScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopScan()}>
		<div class="scanner-container" on:click|stopPropagation role="none">
			<div class="scanner-header">
				<span>{isRtl ? '📷 مسح الباركود' : '📷 Scan Barcode'}</span>
				<button type="button" class="scanner-close" on:click={stopScan}>&times;</button>
			</div>
			<div class="scanner-video-wrapper">
				<!-- svelte-ignore a11y-media-has-caption -->
				<video bind:this={videoEl} playsinline autoplay muted class="scanner-video"></video>
				<div class="scan-line"></div>
			</div>
		</div>
	</div>
{/if}

<style>
	.page-container {
		display: flex;
		flex-direction: column;
		min-height: 100%;
		background: #F8FAFC;
		padding: 0.5rem 0.6rem;
		padding-bottom: 5rem;
		gap: 0.5rem;
	}

	.section-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		box-shadow: none;
		border: 1px solid #E5E7EB;
	}

	.field-label {
		display: block;
		font-size: 0.76rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.2rem;
	}

	.field-select {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.82rem;
		background: white;
		color: #111827;
		appearance: auto;
	}

	.field-input {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.82rem;
		box-sizing: border-box;
		height: 2rem;
	}

	.field-input:focus {
		outline: none;
		border-color: #047857;
		box-shadow: 0 0 0 3px rgba(4, 120, 87, 0.1);
	}

	/* Connection status */
	.connection-status {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.3rem;
		font-size: 0.72rem;
	}

	.status-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.status-dot.testing {
		background: #F59E0B;
		animation: pulse-dot 1s infinite;
	}

	.status-dot.ok {
		background: #10B981;
	}

	.status-dot.fail {
		background: #EF4444;
	}

	@keyframes pulse-dot {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.4; }
	}

	.status-text {
		color: #6B7280;
	}

	.ok-text {
		color: #047857;
		font-weight: 600;
	}

	.fail-text {
		color: #DC2626;
		font-weight: 500;
	}

	.retry-btn {
		padding: 0.1rem 0.4rem;
		border: 1px solid #D1D5DB;
		border-radius: 4px;
		background: #F9FAFB;
		font-size: 0.68rem;
		cursor: pointer;
		color: #374151;
	}

	/* Barcode row */
	.barcode-input-row {
		display: flex;
		gap: 0.25rem;
		align-items: stretch;
	}

	.barcode-input-row .field-input {
		flex: 1;
	}

	.scan-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 0.5rem;
		background: #047857;
		color: white;
		border: none;
		border-radius: 5px;
		cursor: pointer;
		flex-shrink: 0;
		height: 2rem;
	}

	.scan-btn:active {
		background: #065F46;
	}

	.search-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 0.4rem;
		background: #F59E0B;
		border: none;
		border-radius: 5px;
		cursor: pointer;
		font-size: 0.9rem;
		height: 2rem;
		flex-shrink: 0;
	}

	.search-btn:active {
		background: #D97706;
	}

	.search-btn:disabled {
		background: #D1D5DB;
		cursor: not-allowed;
	}

	.lookup-spinner {
		display: flex;
		align-items: center;
		font-size: 0.9rem;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Product card */
	.product-card {
		border: 1px solid #DBEAFE;
		background: #EFF6FF;
	}

	.product-name {
		font-size: 0.92rem;
		font-weight: 700;
		color: #1E40AF;
		margin-bottom: 0.15rem;
	}

	.product-barcode {
		font-size: 0.72rem;
		color: #6B7280;
		font-family: monospace;
		margin-bottom: 0.5rem;
	}

	/* Main price display */
	.price-main-row {
		display: flex;
		align-items: baseline;
		gap: 0.4rem;
		padding: 0.6rem 0.7rem;
		background: white;
		border-radius: 8px;
		border: 2px solid #3B82F6;
		margin-bottom: 0.5rem;
	}

	.price-main-label {
		font-size: 0.76rem;
		font-weight: 600;
		color: #6B7280;
	}

	.price-main-value {
		font-size: 1.8rem;
		font-weight: 800;
		color: #1E40AF;
		line-height: 1;
	}

	.price-main-unit {
		font-size: 0.72rem;
		font-weight: 600;
		color: #6B7280;
		margin-inline-start: auto;
	}

	.no-price-msg {
		padding: 0.5rem;
		background: #FEF3C7;
		color: #92400E;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 600;
		text-align: center;
		margin-bottom: 0.5rem;
	}

	.price-main-value.has-offer {
		color: #6B7280;
		font-size: 1.3rem;
	}

	/* Offer card */
	.offer-card {
		background: linear-gradient(135deg, #FEF3C7, #FDE68A);
		border: 2px solid #F59E0B;
		border-radius: 8px;
		padding: 0.6rem 0.7rem;
		margin-bottom: 0.5rem;
	}

	.offer-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		background: #F59E0B;
		color: white;
		padding: 0.15rem 0.5rem;
		border-radius: 20px;
		font-size: 0.72rem;
		font-weight: 700;
		margin-bottom: 0.4rem;
	}

	.offer-badge-icon {
		font-size: 0.8rem;
	}

	.offer-qty-badge {
		text-align: center;
		font-size: 1.1rem;
		font-weight: 800;
		color: #92400E;
		margin: 0.3rem 0;
	}

	.offer-free-badge {
		color: #065F46;
		background: linear-gradient(135deg, #D1FAE5, #A7F3D0);
		border-radius: 12px;
		padding: 0.4rem 0.8rem;
		font-size: 1.15rem;
	}

	.offer-gift-badge {
		color: #7C2D12;
		background: linear-gradient(135deg, #FED7AA, #FDBA74);
		border-radius: 12px;
		padding: 0.4rem 0.8rem;
		font-size: 1.05rem;
	}

	.offer-prices-simple {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.8rem;
		margin: 0.4rem 0;
	}

	.offer-price-before, .offer-price-after {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.1rem;
	}

	.offer-label {
		font-size: 0.65rem;
		font-weight: 600;
		color: #78716C;
		text-transform: uppercase;
	}

	.offer-old-price {
		font-size: 1.3rem;
		font-weight: 800;
		color: #DC2626;
		text-decoration: line-through;
	}

	.offer-arrow {
		font-size: 1.4rem;
		color: #92400E;
		font-weight: 800;
	}

	.offer-new-price {
		font-size: 1.6rem;
		font-weight: 800;
		color: #047857;
	}

	.offer-per-piece {
		text-align: center;
		font-size: 0.72rem;
		color: #78716C;
		font-weight: 600;
	}

	.offer-savings {
		text-align: center;
		font-size: 0.78rem;
		font-weight: 700;
		color: #047857;
		background: #D1FAE5;
		padding: 0.2rem 0.5rem;
		border-radius: 20px;
		margin-top: 0.4rem;
		display: inline-block;
		width: 100%;
	}

	.offer-limit {
		text-align: center;
		font-size: 0.68rem;
		color: #B45309;
		font-weight: 600;
		margin-top: 0.2rem;
	}

	.action-buttons-row {
		display: flex;
		gap: 0.35rem;
	}

	.clear-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.2rem;
		padding: 0.45rem;
		background: linear-gradient(135deg, #6366F1, #4F46E5);
		color: white;
		border: none;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
		box-shadow: none;
	}

	.clear-btn:active {
		background: linear-gradient(135deg, #4F46E5, #4338CA);
	}

	.error-msg {
		margin-top: 0.3rem;
		padding: 0.3rem 0.5rem;
		background: #FEE2E2;
		color: #991B1B;
		border-radius: 5px;
		font-size: 0.72rem;
		font-weight: 500;
	}

	/* History */
	.history-section {
		padding: 0.4rem 0.5rem;
	}

	.history-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.3rem;
	}

	.history-title {
		font-size: 0.76rem;
		font-weight: 700;
		color: #374151;
	}

	.history-clear {
		padding: 0.1rem 0.4rem;
		background: none;
		border: 1px solid #D1D5DB;
		border-radius: 4px;
		font-size: 0.65rem;
		color: #6B7280;
		cursor: pointer;
	}

	.history-item {
		width: 100%;
		padding: 0.35rem 0.4rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		margin-bottom: 0.2rem;
		cursor: pointer;
		text-align: start;
	}

	.history-item:active {
		background: #EFF6FF;
	}

	.history-item-name {
		font-size: 0.76rem;
		font-weight: 600;
		color: #1F2937;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.history-item-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 0.1rem;
	}

	.history-item-barcode {
		font-size: 0.65rem;
		color: #9CA3AF;
		font-family: monospace;
	}

	.history-item-price {
		font-size: 0.82rem;
		font-weight: 800;
		color: #1E40AF;
	}

	/* Scanner overlay */
	.scanner-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.8);
		z-index: 1100;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.scanner-container {
		background: #111;
		border-radius: 12px;
		overflow: hidden;
		width: 100%;
		max-width: 400px;
	}

	.scanner-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		color: white;
		font-weight: 600;
		font-size: 0.95rem;
	}

	.scanner-close {
		background: none;
		border: none;
		color: white;
		font-size: 1.5rem;
		cursor: pointer;
		line-height: 1;
		padding: 0 0.25rem;
	}

	.scanner-video-wrapper {
		position: relative;
		width: 100%;
		aspect-ratio: 4/3;
		background: #000;
	}

	.scanner-video {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.scan-line {
		position: absolute;
		left: 10%;
		right: 10%;
		height: 2px;
		background: #ff3b30;
		box-shadow: 0 0 8px rgba(255, 59, 48, 0.6);
		top: 50%;
		animation: scanMove 2s ease-in-out infinite;
	}

	@keyframes scanMove {
		0%, 100% { top: 30%; }
		50% { top: 70%; }
	}
</style>
