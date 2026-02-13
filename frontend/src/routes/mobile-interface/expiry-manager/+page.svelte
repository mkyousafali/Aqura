<script lang="ts">
	import { getTranslation } from '$lib/i18n';
	import { currentLocale } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface BranchConfig {
		id: string;
		branch_id: number;
		branch_name: string;
		server_ip: string;
		database_name: string;
		username: string;
		password: string;
		erp_branch_id: number;
	}

	interface ProductResult {
		barcode: string;
		product_name_en: string;
		product_name_ar: string;
		parent_barcode: string | null;
		expiry_dates: any[];
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
	let product: ProductResult | null = null;
	let lookupError = '';

	// Expiry edit state
	let showDatePopup = false;
	let newExpiryDate = '';
	let saving = false;
	let saveSuccess = false;
	let saveError = '';

	// Date picker state (Year → Month → Day) - matches near-expiry page
	let selectedYear = '';
	let selectedMonth = '';
	let selectedDay = '';
	let showYearPicker = false;
	let showMonthPicker = false;
	let showDayPicker = false;

	// Generate year options (current year to +15 years)
	$: yearOptions = (() => {
		const currentYear = new Date().getFullYear();
		const years: number[] = [];
		for (let y = currentYear; y <= currentYear + 15; y++) {
			years.push(y);
		}
		return years;
	})();

	// Generate month options (1-12)
	$: monthOptions = (() => {
		if (!selectedYear) return [];
		const months: number[] = [];
		for (let m = 1; m <= 12; m++) {
			months.push(m);
		}
		return months;
	})();

	// Generate day options based on selected year and month
	$: dayOptions = (() => {
		if (!selectedYear || !selectedMonth) return [];
		const daysInMonth = new Date(Number(selectedYear), Number(selectedMonth), 0).getDate();
		const days: number[] = [];
		for (let d = 1; d <= daysInMonth; d++) {
			days.push(d);
		}
		return days;
	})();

	// Auto-compose expiry date when all three are selected
	$: if (selectedYear && selectedMonth && selectedDay) {
		newExpiryDate = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
	}

	const monthNames = {
		en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
		ar: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر']
	};

	$: isRtl = $currentLocale === 'ar';
	$: selectedConfig = branches.find(b => b.branch_id === selectedBranchId) || null;
	$: currentExpiry = getExpiryForBranch(product, selectedBranchId);

	function getExpiryForBranch(p: ProductResult | null, branchId: number | null): string | null {
		if (!p || !p.expiry_dates || !branchId) return null;
		const entry = p.expiry_dates.find((e: any) => e.branch_id === branchId);
		if (!entry || !entry.expiry_date) return null;
		// Convert yyyy-mm-dd to dd-mm-yyyy
		const parts = entry.expiry_date.split('-');
		if (parts.length === 3 && parts[0].length === 4) {
			return `${parts[2]}-${parts[1]}-${parts[0]}`;
		}
		return entry.expiry_date;
	}

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
				.select('id, branch_id, branch_name, server_ip, database_name, username, password, erp_branch_id')
				.eq('is_active', true)
				.order('branch_name');
			if (error) throw error;
			branches = data || [];

			// Default to user's branch
			const userBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
			if (userBranchId && branches.some(b => b.branch_id === userBranchId)) {
				selectedBranchId = userBranchId;
				await testConnection();
			} else if (branches.length > 0) {
				selectedBranchId = branches[0].branch_id;
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
					serverIp: selectedConfig.server_ip,
					databaseName: selectedConfig.database_name,
					username: selectedConfig.username,
					password: selectedConfig.password
				})
			});
			const result = await response.json();
			if (result.success) {
				connectionStatus = 'ok';
				connectionMessage = isRtl ? 'متصل ✅' : 'Connected ✅';
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
		// Reset product state on branch change
		product = null;
		barcode = '';
		lookupError = '';
		saveSuccess = false;
		saveError = '';
		connectionStatus = 'idle';
		await testConnection();
	}

	// --- Barcode scanning ---
	async function startScan() {
		scanning = true;
		try {
			stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
			await new Promise(r => setTimeout(r, 50));
			if (videoEl) {
				videoEl.srcObject = stream;
				await videoEl.play();
				detectBarcode();
			}
		} catch (err) {
			console.error('Camera access error:', err);
			scanning = false;
		}
	}

	function detectBarcode() {
		// @ts-ignore
		if ('BarcodeDetector' in window) {
			// @ts-ignore
			const detector = new BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'qr_code'] });
			scanInterval = setInterval(async () => {
				if (!videoEl || videoEl.readyState < 2) return;
				try {
					const barcodes = await detector.detect(videoEl);
					if (barcodes.length > 0) {
						barcode = barcodes[0].rawValue;
						stopScan();
						await lookupProduct(barcode);
					}
				} catch (_) {}
			}, 300);
		}
	}

	function stopScan() {
		if (scanInterval) { clearInterval(scanInterval); scanInterval = null; }
		if (stream) { stream.getTracks().forEach(t => t.stop()); stream = null; }
		scanning = false;
	}

	// --- Product lookup ---
	async function lookupProduct(bc: string) {
		if (!bc || bc.trim().length < 3) return;
		lookingUp = true;
		lookupError = '';
		product = null;
		saveSuccess = false;
		saveError = '';
		try {
			const { data, error } = await supabase
				.from('erp_synced_products')
				.select('barcode, product_name_en, product_name_ar, parent_barcode, expiry_dates')
				.eq('barcode', bc.trim())
				.limit(1)
				.maybeSingle();
			if (error) throw error;
			if (!data) {
				lookupError = isRtl ? 'لم يتم العثور على المنتج' : 'Product not found';
			} else {
				product = data;
			}
		} catch (err: any) {
			lookupError = err.message || 'Lookup error';
		} finally {
			lookingUp = false;
		}
	}

	function getProductName(p: ProductResult): string {
		if (isRtl && p.product_name_ar) return p.product_name_ar;
		return p.product_name_en || p.product_name_ar || '';
	}

	// --- Change expiry date ---
	function openDatePopup() {
		// Pre-fill with current expiry - parse into year/month/day
		if (currentExpiry) {
			const parts = currentExpiry.split('-');
			if (parts.length === 3 && parts[0].length === 2) {
				// dd-mm-yyyy format
				selectedYear = parts[2];
				selectedMonth = String(Number(parts[1]));
				selectedDay = String(Number(parts[0]));
				newExpiryDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
			} else if (parts.length === 3 && parts[0].length === 4) {
				// yyyy-mm-dd format
				selectedYear = parts[0];
				selectedMonth = String(Number(parts[1]));
				selectedDay = String(Number(parts[2]));
				newExpiryDate = currentExpiry;
			} else {
				selectedYear = '';
				selectedMonth = '';
				selectedDay = '';
				newExpiryDate = '';
			}
		} else {
			selectedYear = '';
			selectedMonth = '';
			selectedDay = '';
			newExpiryDate = '';
		}
		saveSuccess = false;
		saveError = '';
		showDatePopup = true;
	}

	function closeDatePopup() {
		showDatePopup = false;
	}

	async function saveNewExpiry() {
		if (!newExpiryDate || !product || !selectedConfig || !selectedBranchId) return;
		saving = true;
		saveError = '';
		saveSuccess = false;

		try {
			// 1. Update SQL Server (ERP)
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'update-expiry',
					serverIp: selectedConfig.server_ip,
					databaseName: selectedConfig.database_name,
					username: selectedConfig.username,
					password: selectedConfig.password,
					barcode: product.barcode,
					newExpiryDate
				})
			});
			const result = await response.json();

			if (!result.success) {
				saveError = result.error || (isRtl ? 'فشل تحديث ERP' : 'Failed to update ERP');
				saving = false;
				return;
			}

			// 2. Update Supabase - same logic as ERP Product Manager (update siblings too)
			const newEntry = { branch_id: selectedBranchId, erp_branch_id: selectedConfig.erp_branch_id, expiry_date: newExpiryDate };
			const parentBarcode = product.parent_barcode || product.barcode;
			const { data: siblings } = await supabase
				.from('erp_synced_products')
				.select('barcode, expiry_dates')
				.or(`parent_barcode.eq.${parentBarcode},barcode.eq.${parentBarcode}`);

			const barcodesToUpdate = siblings && siblings.length > 0 ? siblings : [{ barcode: product.barcode, expiry_dates: product.expiry_dates }];

			for (const sibling of barcodesToUpdate) {
				const sibExpiry: any[] = sibling.expiry_dates ? [...sibling.expiry_dates] : [];
				const idx = sibExpiry.findIndex((e: any) => e.branch_id === selectedBranchId);
				if (idx >= 0) {
					sibExpiry[idx] = newEntry;
				} else {
					sibExpiry.push(newEntry);
				}

				await supabase
					.from('erp_synced_products')
					.update({ expiry_dates: sibExpiry, synced_at: new Date().toISOString() })
					.eq('barcode', sibling.barcode);
			}

			// 3. Update local product state
			const localExpiry: any[] = product.expiry_dates ? [...product.expiry_dates] : [];
			const li = localExpiry.findIndex((e: any) => e.branch_id === selectedBranchId);
			if (li >= 0) { localExpiry[li] = newEntry; } else { localExpiry.push(newEntry); }
			product = { ...product, expiry_dates: localExpiry };

			saveSuccess = true;
			showDatePopup = false;
		} catch (err: any) {
			saveError = err.message || 'Error';
		} finally {
			saving = false;
		}
	}
</script>

<div class="page-container" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="page-header">
		<span class="header-icon">📅</span>
		<h1>{isRtl ? 'إدارة تواريخ الصلاحية' : 'Expiry Date Manager'}</h1>
	</div>

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

				<div class="expiry-row">
					<span class="expiry-label">{isRtl ? 'تاريخ الصلاحية الحالي:' : 'Current Expiry Date:'}</span>
					<span class="expiry-value" class:no-date={!currentExpiry}>
						{currentExpiry || (isRtl ? 'غير محدد' : 'Not set')}
					</span>
				</div>

				<button class="change-btn" on:click={openDatePopup}>
					📅 {isRtl ? 'تغيير تاريخ الصلاحية' : 'Change Expiry Date'}
				</button>

				{#if saveSuccess}
					<div class="success-msg">
						✅ {isRtl ? 'تم التحديث بنجاح' : 'Updated successfully'}
					</div>
				{/if}
				{#if saveError}
					<div class="error-msg">{saveError}</div>
				{/if}
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

<!-- Date change popup -->
{#if showDatePopup}
	<div class="popup-overlay" on:click={closeDatePopup} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeDatePopup()}>
		<div class="popup-container" on:click|stopPropagation role="none">
			<div class="popup-header">
				<span>{isRtl ? 'تغيير تاريخ الصلاحية' : 'Change Expiry Date'}</span>
				<button type="button" class="popup-close" on:click={closeDatePopup}>&times;</button>
			</div>
			<div class="popup-body">
				{#if product}
					<div class="popup-product-name">{getProductName(product)}</div>
				{/if}
				<div class="popup-field">
					<label class="field-label">{isRtl ? 'التاريخ الجديد' : 'New Date'}</label>
					<div class="date-fields-row">
						<!-- Year field -->
						<button type="button" class="date-field" class:date-field-filled={selectedYear} on:click={() => { showYearPicker = true; }}>
							<span class="date-field-label">{isRtl ? 'السنة' : 'Year'}</span>
							<span class="date-field-value">{selectedYear || '----'}</span>
						</button>
						<!-- Month field -->
						<button type="button" class="date-field" class:date-field-filled={selectedMonth} class:date-field-disabled={!selectedYear} on:click={() => { if (selectedYear) showMonthPicker = true; }}>
							<span class="date-field-label">{isRtl ? 'الشهر' : 'Month'}</span>
							<span class="date-field-value">{selectedMonth ? (isRtl ? monthNames.ar[Number(selectedMonth) - 1] : monthNames.en[Number(selectedMonth) - 1]) : '--'}</span>
						</button>
						<!-- Day field -->
						<button type="button" class="date-field" class:date-field-filled={selectedDay} class:date-field-disabled={!selectedMonth} on:click={() => { if (selectedMonth) showDayPicker = true; }}>
							<span class="date-field-label">{isRtl ? 'اليوم' : 'Day'}</span>
							<span class="date-field-value">{selectedDay ? String(selectedDay).padStart(2, '0') : '--'}</span>
						</button>
					</div>
					{#if newExpiryDate}
						<div class="date-preview">📅 {newExpiryDate}</div>
					{/if}
				</div>
			</div>
			<div class="popup-footer">
				<button class="btn-cancel" on:click={closeDatePopup} disabled={saving}>
					{isRtl ? 'إلغاء' : 'Cancel'}
				</button>
				<button class="btn-save" on:click={saveNewExpiry} disabled={!selectedYear || !selectedMonth || !selectedDay || saving}>
					{#if saving}
						<span class="save-spinner">⏳</span>
					{:else}
						💾 {isRtl ? 'حفظ' : 'Save'}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Year Picker Popup -->
{#if showYearPicker}
	<div class="picker-overlay" on:click={() => showYearPicker = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showYearPicker = false)}>
		<div class="picker-popup" on:click|stopPropagation role="none">
			<div class="picker-header">
				<span>{isRtl ? 'اختر السنة' : 'Select Year'}</span>
				<button type="button" class="popup-close" on:click={() => showYearPicker = false}>&times;</button>
			</div>
			<div class="picker-scroll-list">
				{#each yearOptions as year}
					<button type="button" class="picker-scroll-item" class:picker-scroll-item-active={selectedYear === String(year)} on:click={() => { selectedYear = String(year); selectedMonth = ''; selectedDay = ''; newExpiryDate = ''; showYearPicker = false; }}>
						{year}
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Month Picker Popup -->
{#if showMonthPicker}
	<div class="picker-overlay" on:click={() => showMonthPicker = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showMonthPicker = false)}>
		<div class="picker-popup" on:click|stopPropagation role="none">
			<div class="picker-header">
				<span>{isRtl ? 'اختر الشهر' : 'Select Month'}</span>
				<button type="button" class="popup-close" on:click={() => showMonthPicker = false}>&times;</button>
			</div>
			<div class="picker-scroll-list">
				{#each monthOptions as month}
					<button type="button" class="picker-scroll-item" class:picker-scroll-item-active={selectedMonth === String(month)} on:click={() => { selectedMonth = String(month); selectedDay = ''; newExpiryDate = ''; showMonthPicker = false; }}>
						{month} - {isRtl ? monthNames.ar[month - 1] : monthNames.en[month - 1]}
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Day Picker Popup -->
{#if showDayPicker}
	<div class="picker-overlay" on:click={() => showDayPicker = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showDayPicker = false)}>
		<div class="picker-popup" on:click|stopPropagation role="none">
			<div class="picker-header">
				<span>{isRtl ? 'اختر اليوم' : 'Select Day'}</span>
				<button type="button" class="popup-close" on:click={() => showDayPicker = false}>&times;</button>
			</div>
			<div class="picker-scroll-list">
				{#each dayOptions as day}
					<button type="button" class="picker-scroll-item" class:picker-scroll-item-active={selectedDay === String(day)} on:click={() => { selectedDay = String(day); showDayPicker = false; }}>
						{day}
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

<style>
	.page-container {
		display: flex;
		flex-direction: column;
		min-height: 100%;
		background: #F0FDF4;
		padding: 0.75rem;
		padding-bottom: 5rem;
		gap: 0.75rem;
	}

	.page-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: linear-gradient(135deg, #065F46, #047857);
		border-radius: 12px;
		color: white;
	}

	.header-icon {
		font-size: 1.5rem;
	}

	.page-header h1 {
		font-size: 1.1rem;
		font-weight: 700;
		margin: 0;
	}

	.section-card {
		background: white;
		border-radius: 12px;
		padding: 0.85rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
	}

	.field-label {
		display: block;
		font-size: 0.78rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.3rem;
	}

	.field-select {
		width: 100%;
		padding: 0.5rem 0.65rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.85rem;
		background: white;
		color: #111827;
		appearance: auto;
	}

	.field-input {
		width: 100%;
		padding: 0.45rem 0.6rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.85rem;
		box-sizing: border-box;
		height: 2.2rem;
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
		gap: 0.4rem;
		margin-top: 0.5rem;
		font-size: 0.78rem;
	}

	.status-dot {
		width: 10px;
		height: 10px;
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
		padding: 0.15rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		background: #F9FAFB;
		font-size: 0.72rem;
		cursor: pointer;
		color: #374151;
	}

	/* Barcode row */
	.barcode-input-row {
		display: flex;
		gap: 0.35rem;
		align-items: stretch;
	}

	.barcode-input-row .field-input {
		flex: 1;
	}

	.scan-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 0.6rem;
		background: #047857;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		flex-shrink: 0;
		height: 2.2rem;
	}

	.scan-btn:active {
		background: #065F46;
	}

	.search-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 0.5rem;
		background: #F59E0B;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-size: 1rem;
		height: 2.2rem;
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
		border: 2px solid #D1FAE5;
		background: #ECFDF5;
	}

	.product-name {
		font-size: 1rem;
		font-weight: 700;
		color: #065F46;
		margin-bottom: 0.25rem;
	}

	.product-barcode {
		font-size: 0.78rem;
		color: #6B7280;
		font-family: monospace;
		margin-bottom: 0.65rem;
	}

	.expiry-row {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.55rem 0.65rem;
		background: white;
		border-radius: 8px;
		border: 1px solid #D1D5DB;
		margin-bottom: 0.75rem;
	}

	.expiry-label {
		font-size: 0.8rem;
		font-weight: 600;
		color: #374151;
	}

	.expiry-value {
		font-size: 0.9rem;
		font-weight: 700;
		color: #B45309;
		font-family: monospace;
	}

	.expiry-value.no-date {
		color: #9CA3AF;
		font-style: italic;
		font-weight: 400;
	}

	.change-btn {
		width: 100%;
		padding: 0.65rem;
		background: linear-gradient(135deg, #F59E0B, #D97706);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(245, 158, 11, 0.3);
	}

	.change-btn:active {
		background: linear-gradient(135deg, #D97706, #B45309);
	}

	.success-msg {
		margin-top: 0.5rem;
		padding: 0.45rem 0.65rem;
		background: #D1FAE5;
		color: #065F46;
		border-radius: 8px;
		font-size: 0.8rem;
		font-weight: 600;
		text-align: center;
	}

	.error-msg {
		margin-top: 0.4rem;
		padding: 0.4rem 0.6rem;
		background: #FEE2E2;
		color: #991B1B;
		border-radius: 8px;
		font-size: 0.78rem;
		font-weight: 500;
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

	/* Date popup */
	.popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1100;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		padding-bottom: 4.5rem;
	}

	.popup-container {
		background: white;
		border-radius: 14px;
		width: 100%;
		max-width: 340px;
		overflow: hidden;
	}

	.popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #E5E7EB;
		font-weight: 700;
		font-size: 0.95rem;
		color: #111827;
	}

	.popup-close {
		background: none;
		border: none;
		font-size: 1.3rem;
		cursor: pointer;
		color: #6B7280;
		line-height: 1;
	}

	.popup-body {
		padding: 1rem;
	}

	.popup-product-name {
		font-size: 0.88rem;
		font-weight: 600;
		color: #065F46;
		margin-bottom: 0.75rem;
		text-align: center;
	}

	.popup-field {
		margin-bottom: 0;
	}

	/* Date field row & popup picker - matches near-expiry page */
	.date-fields-row {
		display: flex;
		gap: 0.35rem;
	}

	.date-field {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 0.4rem 0.25rem;
		border: 2px solid #D1D5DB;
		border-radius: 0.5rem;
		background: white;
		cursor: pointer;
		-webkit-tap-highlight-color: transparent;
		touch-action: manipulation;
		transition: border-color 0.15s;
	}

	.date-field:active {
		background: #F3F4F6;
	}

	.date-field-filled {
		border-color: #DC2626;
		background: #FEF2F2;
	}

	.date-field-disabled {
		opacity: 0.4;
		pointer-events: none;
	}

	.date-field-label {
		font-size: 0.6rem;
		font-weight: 600;
		color: #9CA3AF;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.date-field-value {
		font-size: 0.95rem;
		font-weight: 700;
		color: #1F2937;
		margin-top: 0.1rem;
	}

	.date-field-filled .date-field-value {
		color: #DC2626;
	}

	.date-preview {
		text-align: center;
		font-size: 0.85rem;
		font-weight: 700;
		color: #DC2626;
		padding: 0.3rem;
		margin-top: 0.35rem;
		background: #FEF2F2;
		border-radius: 0.375rem;
		border: 1px dashed #FCA5A5;
	}

	/* Picker popup (bottom sheet) */
	.picker-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1200;
	}

	.picker-popup {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		background: white;
		border-radius: 1rem 1rem 0 0;
		box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.2);
		z-index: 1201;
		max-height: 55vh;
		overflow-y: auto;
		padding-bottom: 0;
	}

	.picker-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #E5E7EB;
		font-weight: 700;
		font-size: 0.9rem;
		color: #1F2937;
		position: sticky;
		top: 0;
		background: white;
		z-index: 1;
	}

	.picker-scroll-list {
		display: flex;
		flex-direction: column;
		max-height: 50vh;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		padding: 0.5rem 0.75rem 5rem;
		gap: 0.3rem;
	}

	.picker-scroll-item {
		width: 100%;
		padding: 0.85rem 1rem;
		border: 1px solid #E5E7EB;
		border-radius: 0.5rem;
		background: #F9FAFB;
		color: #1F2937;
		font-size: 1.1rem;
		font-weight: 700;
		cursor: pointer;
		text-align: center;
		-webkit-tap-highlight-color: transparent;
		touch-action: manipulation;
		transition: all 0.15s;
	}

	.picker-scroll-item:active {
		transform: scale(0.97);
		background: #FEE2E2;
	}

	.picker-scroll-item-active {
		background: #DC2626;
		color: white;
		border-color: #DC2626;
		box-shadow: 0 2px 6px rgba(220, 38, 38, 0.35);
	}

	.popup-footer {
		display: flex;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border-top: 1px solid #E5E7EB;
	}

	.btn-cancel {
		flex: 1;
		padding: 0.55rem;
		background: #F3F4F6;
		color: #374151;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-cancel:active {
		background: #E5E7EB;
	}

	.btn-save {
		flex: 1;
		padding: 0.55rem;
		background: #047857;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
	}

	.btn-save:active {
		background: #065F46;
	}

	.btn-save:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
	}

	.save-spinner {
		animation: spin 1s linear infinite;
	}
</style>
