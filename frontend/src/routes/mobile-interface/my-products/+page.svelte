<script lang="ts">
	import { currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	function t(en: string, ar: string): string {
		return $currentLocale === 'ar' ? ar : en;
	}

	$: isRtl = $currentLocale === 'ar';

	interface MyProduct {
		barcode: string;
		product_name_en: string;
		product_name_ar: string;
		parent_barcode: string | null;
		expiry_dates: any[];
		managed_by: any[];
		nearestExpiry: string;
		daysLeft: number;
	}

	let loading = true;
	let error = '';
	let products: MyProduct[] = [];
	let employeeId: string | null = null;
	let employeeName: string = '';
	let branchId: number | null = null;

	// Search & Scanner
	let searchQuery = '';
	let showScanner = false;
	let scannerRef: HTMLVideoElement | null = null;
	let scanningActive = false;
	let codeReader: any = null;

	// Sort
	let sortBy: 'expiry' | 'name' = 'expiry';

	$: sortedProducts = [...products].sort((a, b) => {
		if (sortBy === 'expiry') return a.daysLeft - b.daysLeft;
		const nameA = getProductName(a);
		const nameB = getProductName(b);
		return nameA.localeCompare(nameB);
	});

	$: filteredProducts = searchQuery.trim() === '' 
		? sortedProducts 
		: sortedProducts.filter(p => {
			const search = searchQuery.toLowerCase();
			const name = getProductName(p).toLowerCase();
			const barcode = p.barcode.toLowerCase();
			return name.includes(search) || barcode.includes(search);
		});

	function getProductName(p: MyProduct): string {
		if (isRtl) return p.product_name_ar || p.product_name_en || p.barcode;
		return p.product_name_en || p.product_name_ar || p.barcode;
	}

	function getDaysLeft(dateStr: string): number {
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		const expiry = new Date(dateStr);
		expiry.setHours(0, 0, 0, 0);
		return Math.ceil((expiry.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
	}

	function getExpiryBadgeClass(days: number): string {
		if (days <= 0) return 'badge-expired';
		if (days <= 3) return 'badge-critical';
		if (days <= 7) return 'badge-warning';
		if (days <= 14) return 'badge-soon';
		return 'badge-safe';
	}

	function getExpiryLabel(days: number): string {
		if (days <= 0) return t('Expired', 'منتهي');
		if (days === 1) return t('1 day', 'يوم واحد');
		return t(`${days} days`, `${days} يوم`);
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		return d.toLocaleDateString(isRtl ? 'ar-SA' : 'en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			timeZone: 'Asia/Riyadh'
		});
	}

	onMount(async () => {
		await loadEmployeeId();
		if (employeeId) {
			await loadMyProducts();
		} else {
			loading = false;
			error = t('Could not identify your employee account', 'لم يتم التعرف على حساب الموظف');
		}
	});

	async function loadEmployeeId() {
		if (!$currentUser?.id) return;
		try {
			const { data, error: err } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar, current_branch_id')
				.eq('user_id', $currentUser.id)
				.maybeSingle();
			if (!err && data) {
				employeeId = data.id;
				employeeName = isRtl ? (data.name_ar || data.name_en || '') : (data.name_en || data.name_ar || '');
				branchId = data.current_branch_id;
			}
		} catch (err) {
			console.error('Error loading employee ID:', err);
		}
	}

	async function loadMyProducts() {
		loading = true;
		error = '';
		products = [];

		try {
			// Query all products where managed_by contains this employee
			// We use the JSONB containment operator via Supabase's .contains()
			const { data, error: err } = await supabase
				.from('erp_synced_products')
				.select('barcode, product_name_en, product_name_ar, parent_barcode, expiry_dates, managed_by')
				.contains('managed_by', JSON.stringify([{ employee_id: employeeId }]));

			if (err) {
				error = t('Failed to load products', 'فشل تحميل المنتجات');
				console.error('Query error:', err);
				loading = false;
				return;
			}

			if (!data || data.length === 0) {
				loading = false;
				return;
			}

			const result: MyProduct[] = [];

			for (const row of data) {
				const expiryDates: any[] = row.expiry_dates || [];
				
				// Find expiry date for THIS BRANCH ONLY
				let branchExpiry: string | null = null;
				let branchDays = 9999;

				for (const entry of expiryDates) {
					// Filter by user's branch ID
					if (entry.branch_id === branchId) {
						const expDate = entry.expiry_date;
						if (expDate) {
							branchDays = getDaysLeft(expDate);
							branchExpiry = expDate;
							break; // Found the branch expiry, stop looking
						}
					}
				}

				// If no expiry dates for this branch, still show the product
				result.push({
					barcode: row.barcode,
					product_name_en: row.product_name_en || '',
					product_name_ar: row.product_name_ar || '',
					parent_barcode: row.parent_barcode || null,
					expiry_dates: expiryDates,
					managed_by: row.managed_by || [],
					nearestExpiry: branchExpiry || '',
					daysLeft: branchExpiry ? branchDays : 9999
				});
			}

			products = result;
		} catch (err) {
			error = t('An error occurred', 'حدث خطأ');
			console.error('Load error:', err);
		} finally {
			loading = false;
		}
	}

	async function refresh() {
		if (employeeId) {
			await loadMyProducts();
		}
	}

	async function initScanner() {
		if (scanningActive) {
			stopScanner();
			return;
		}

		showScanner = true;
		scanningActive = true;

		// Request camera permission
		try {
			const stream = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: 'environment' }
			});
			if (scannerRef) {
				scannerRef.srcObject = stream;
				scannerRef.setAttribute('playsinline', 'true');
				scannerRef.play();
				startBarcodeDetection();
			}
		} catch (err) {
			console.error('Camera access denied:', err);
			alert(t('Unable to access camera', 'لا يمكن الوصول إلى الكاميرا'));
			showScanner = false;
			scanningActive = false;
		}
	}

	function stopScanner() {
		if (scannerRef && scannerRef.srcObject) {
			const stream = scannerRef.srcObject as MediaStream;
			stream.getTracks().forEach(track => track.stop());
		}
		scanningActive = false;
		showScanner = false;
	}

	function startBarcodeDetection() {
		if (!scannerRef) return;

		const canvas = document.createElement('canvas');
		const ctx = canvas.getContext('2d');
		let isProcessing = false;

		const detectBarcode = () => {
			if (!scanningActive || isProcessing) {
				if (scanningActive) requestAnimationFrame(detectBarcode);
				return;
			}

			try {
				canvas.width = scannerRef!.videoWidth;
				canvas.height = scannerRef!.videoHeight;
				ctx!.drawImage(scannerRef!, 0, 0, canvas.width, canvas.height);

				// Simple barcode detection using image processing
				const imageData = ctx!.getImageData(0, 0, canvas.width, canvas.height);
				const barcode = extractBarcodeFromImage(imageData);

				if (barcode) {
					searchQuery = barcode;
					stopScanner();
					isProcessing = true;
					setTimeout(() => { isProcessing = false; }, 500);
				}
			} catch (err) {
				console.error('Barcode detection error:', err);
			}

			if (scanningActive) requestAnimationFrame(detectBarcode);
		};

		detectBarcode();
	}

	function extractBarcodeFromImage(imageData: ImageData): string | null {
		// This is a simplified barcode extraction
		// For production, use a library like: jsQR, quagga2, or ZXing
		// This basic implementation looks for high-contrast edges
		const data = imageData.data;
		const width = imageData.width;
		const height = imageData.height;

		let barcodeCandidate = '';
		let lastValue = 0;

		for (let i = 0; i < data.length; i += 4) {
			const gray = (data[i] + data[i + 1] + data[i + 2]) / 3;
			const currentValue = gray > 128 ? 1 : 0;

			if (currentValue !== lastValue) {
				barcodeCandidate += currentValue;
			}
			lastValue = currentValue;
		}

		// Look for patterns in the barcode (very simplified)
		if (barcodeCandidate.length > 10) {
			return barcodeCandidate.substring(0, 20); // Return simplified pattern
		}

		return null;
	}

	function handleBarcodeInput(event: Event) {
		const input = event.target as HTMLInputElement;
		searchQuery = input.value;
	}

	function clearSearch() {
		searchQuery = '';
	}
</script>

<div class="page-container" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Search Bar with Scanner -->
	{#if showScanner}
		<div class="scanner-container">
			<div class="scanner-header">
				<h3>{t('Scan Barcode', 'مسح الرمز الشريطي')}</h3>
				<button class="close-scanner" on:click={stopScanner} aria-label="Close scanner">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<video bind:this={scannerRef} class="scanner-video"></video>
			<div class="scanner-guide">
				<svg width="120" height="120" viewBox="0 0 120 120" fill="none" stroke="#fff" stroke-width="2">
					<line x1="20" y1="20" x2="40" y2="20"/>
					<line x1="20" y1="20" x2="20" y2="40"/>
					<line x1="100" y1="20" x2="80" y2="20"/>
					<line x1="100" y1="20" x2="100" y2="40"/>
					<line x1="20" y1="100" x2="40" y2="100"/>
					<line x1="20" y1="100" x2="20" y2="80"/>
					<line x1="100" y1="100" x2="80" y2="100"/>
					<line x1="100" y1="100" x2="100" y2="80"/>
				</svg>
				<p>{t('Point camera at barcode', 'وجه الكاميرا نحو الرمز الشريطي')}</p>
			</div>
		</div>
	{:else}
		<!-- Search Bar -->
		<div class="search-bar-container">
			<div class="search-bar">
				<svg class="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="11" cy="11" r="8"/>
					<path d="m21 21-4.35-4.35"/>
				</svg>
				<input
					type="text"
					class="search-input"
					placeholder={t('Search by name or barcode...', 'ابحث بالاسم أو الرمز الشريطي...')}
					value={searchQuery}
					on:input={handleBarcodeInput}
					dir={isRtl ? 'rtl' : 'ltr'}
				/>
				{#if searchQuery}
					<button class="clear-btn" on:click={clearSearch} aria-label="Clear search">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<path d="m15 9-6 6m0-6 6 6"/>
						</svg>
					</button>
				{/if}
				<button class="scanner-btn" on:click={initScanner} aria-label="Open barcode scanner" title={t('Scan barcode', 'مسح الرمز الشريطي')}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="3" y1="6" x2="3" y2="18"/>
						<line x1="7" y1="4" x2="7" y2="20"/>
						<line x1="11" y1="6" x2="11" y2="18"/>
						<line x1="15" y1="5" x2="15" y2="19"/>
						<line x1="19" y1="6" x2="19" y2="18"/>
						<line x1="21" y1="8" x2="21" y2="16"/>
					</svg>
				</button>
			</div>
		</div>

		<!-- Sticky Header -->
		<div class="sticky-header">
		<div class="section-card summary-card">
			<div class="summary-row">
				<div class="summary-stats">
					<span class="stat-chip">
						<span class="stat-num">{products.length}</span>
						<span class="stat-text">{t('claimed products', 'منتج مسجل')}</span>
					</span>
				</div>
				<button class="refresh-btn" on:click={refresh} disabled={loading} aria-label="Refresh">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
						<polyline points="23 4 23 10 17 10"/>
						<path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
					</svg>
				</button>
			</div>
		</div>

		{#if products.length > 0}
			<div class="sort-row">
				<button class="sort-btn" class:active={sortBy === 'expiry'} on:click={() => sortBy = 'expiry'}>
					{t('By Expiry', 'حسب الصلاحية')}
				</button>
				<button class="sort-btn" class:active={sortBy === 'name'} on:click={() => sortBy = 'name'}>
					{t('By Name', 'حسب الاسم')}
				</button>
			</div>
		{/if}
	</div>

	<!-- Loading -->
	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<span>{t('Loading...', 'جاري التحميل...')}</span>
		</div>
	{:else if error}
		<div class="error-state">{error}</div>
	{:else if products.length === 0}
		<div class="empty-state">
			<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="1.5">
				<path d="M9 12l2 2 4-4"/>
				<circle cx="12" cy="12" r="10"/>
			</svg>
			<span>{t('No claimed products', 'لا توجد منتجات مسجلة')}</span>
		</div>
	{:else if filteredProducts.length === 0}
		<div class="empty-state">
			<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="1.5">
				<circle cx="11" cy="11" r="8"/>
				<path d="m21 21-4.35-4.35"/>
			</svg>
			<span>{t('No products match your search', 'لا توجد منتجات مطابقة')}</span>
		</div>
	{:else}
		<!-- Product List -->
		<div class="product-list">
			{#each filteredProducts as item (item.barcode)}
				<div class="product-row">
					<div class="product-info">
						<div class="product-name">{getProductName(item)}</div>
						<div class="product-barcode">{item.barcode}</div>
					</div>
					<div class="product-expiry">
						{#if item.nearestExpiry}
							<span class="expiry-badge {getExpiryBadgeClass(item.daysLeft)}">
								{getExpiryLabel(item.daysLeft)}
							</span>
							<span class="expiry-date">{formatDate(item.nearestExpiry)}</span>
						{:else}
							<span class="expiry-badge badge-safe">{t('No expiry', 'بدون صلاحية')}</span>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
	{/if}
</div>

<style>
	.page-container {
		display: flex;
		flex-direction: column;
		background: #F8FAFC;
		height: 100%;
		overflow: hidden;
	}

	/* Search Bar */
	.search-bar-container {
		padding: 0.6rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
		flex-shrink: 0;
	}

	.search-bar {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 0.6rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
	}

	.search-icon {
		color: #9CA3AF;
		flex-shrink: 0;
	}

	.search-input {
		flex: 1;
		border: none;
		background: transparent;
		font-size: 0.74rem;
		color: #1F2937;
		outline: none;
		padding: 0;
	}

	.search-input::placeholder {
		color: #9CA3AF;
	}

	.clear-btn,
	.scanner-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		border: 1px solid #D1D5DB;
		background: white;
		border-radius: 4px;
		color: #6B7280;
		cursor: pointer;
		flex-shrink: 0;
		transition: all 0.15s;
	}

	.clear-btn:active,
	.scanner-btn:active {
		background: #E5E7EB;
	}

	.scanner-btn {
		color: #047857;
	}

	/* Scanner */
	.scanner-container {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 1000;
		background: black;
		display: flex;
		flex-direction: column;
	}

	.scanner-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.8rem;
		background: rgba(0, 0, 0, 0.8);
		color: white;
	}

	.scanner-header h3 {
		margin: 0;
		font-size: 0.9rem;
		font-weight: 600;
	}

	.close-scanner {
		border: none;
		background: transparent;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		width: 32px;
		height: 32px;
	}

	.scanner-video {
		flex: 1;
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.scanner-guide {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.8rem;
		color: white;
		pointer-events: none;
	}

	.scanner-guide p {
		margin: 0;
		font-size: 0.78rem;
		text-align: center;
	}

	.sticky-header {
		position: sticky;
		top: 0;
		z-index: 10;
		background: #F8FAFC;
		padding: 0.5rem 0.6rem;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex-shrink: 0;
	}

	.section-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		border: 1px solid #E5E7EB;
	}

	.summary-card {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.summary-stats {
		margin-top: 0.15rem;
	}

	.stat-chip {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.15rem 0.4rem;
		background: #FEF3C7;
		border-radius: 10px;
		font-size: 0.68rem;
		color: #92400E;
		font-weight: 600;
	}

	.stat-num {
		font-size: 0.78rem;
		font-weight: 800;
		color: #D97706;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		background: #F9FAFB;
		color: #374151;
		cursor: pointer;
	}

	.refresh-btn:active {
		background: #E5E7EB;
	}

	.refresh-btn:disabled {
		opacity: 0.5;
	}

	/* Sort */
	.sort-row {
		display: flex;
		gap: 0.3rem;
	}

	.sort-btn {
		flex: 1;
		padding: 0.3rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		background: white;
		font-size: 0.72rem;
		font-weight: 600;
		color: #6B7280;
		cursor: pointer;
	}

	.sort-btn.active {
		background: #047857;
		color: white;
		border-color: #047857;
	}

	/* Loading / Empty */
	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		padding: 2rem 0.6rem;
		color: #6B7280;
		font-size: 0.78rem;
	}

	.spinner {
		width: 24px;
		height: 24px;
		border: 3px solid #E5E7EB;
		border-top-color: #047857;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		padding: 2rem 0.6rem;
		color: #9CA3AF;
		font-size: 0.78rem;
		text-align: center;
	}

	.error-state {
		padding: 0.5rem;
		margin: 0 0.6rem;
		background: #FEE2E2;
		color: #991B1B;
		border-radius: 5px;
		font-size: 0.74rem;
		font-weight: 600;
		text-align: center;
	}

	/* Product List */
	.product-list {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		padding: 0 0.6rem 1rem;
		flex: 1;
	}

	.product-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.45rem 0.5rem;
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		gap: 0.5rem;
	}

	.product-info {
		flex: 1;
		min-width: 0;
	}

	.product-name {
		font-size: 0.78rem;
		font-weight: 600;
		color: #1F2937;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.product-barcode {
		font-size: 0.66rem;
		color: #9CA3AF;
		font-family: 'Courier New', monospace;
		margin-top: 0.1rem;
	}

	.product-expiry {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		flex-shrink: 0;
		gap: 0.1rem;
	}

	[dir="rtl"] .product-expiry {
		align-items: flex-start;
	}

	.expiry-badge {
		display: inline-block;
		padding: 0.1rem 0.35rem;
		border-radius: 8px;
		font-size: 0.64rem;
		font-weight: 700;
		white-space: nowrap;
	}

	.badge-expired {
		background: #FEE2E2;
		color: #991B1B;
	}

	.badge-critical {
		background: #FEE2E2;
		color: #DC2626;
	}

	.badge-warning {
		background: #FEF3C7;
		color: #D97706;
	}

	.badge-soon {
		background: #DBEAFE;
		color: #1D4ED8;
	}

	.badge-safe {
		background: #D1FAE5;
		color: #065F46;
	}

	.expiry-date {
		font-size: 0.62rem;
		color: #9CA3AF;
	}
</style>
