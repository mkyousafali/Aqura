<script lang="ts">
	import { getTranslation } from '$lib/i18n';
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

	interface ProductResult {
		barcode: string;
		product_name_en: string;
		product_name_ar: string;
		parent_barcode: string | null;
		expiry_dates: any[];
		managed_by: any[];
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

	// Mine/Claim state
	let claiming = false;
	let claimSuccess = false;
	let claimError = '';
	let employeeId: string | null = null;
	let employeeName: string = '';
	let managerNames: Record<string, string> = {};

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
	$: alreadyClaimed = isAlreadyClaimed(product, employeeId);
	$: daysLeft = (() => {
		if (!currentExpiry) return null;
		// currentExpiry is dd-mm-yyyy
		const parts = currentExpiry.split('-');
		if (parts.length !== 3) return null;
		const expDate = new Date(Number(parts[2]), Number(parts[1]) - 1, Number(parts[0]));
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		return Math.ceil((expDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
	})();

	function isAlreadyClaimed(p: ProductResult | null, empId: string | null): boolean {
		if (!p || !p.managed_by || !empId) return false;
		return p.managed_by.some((m: any) => m.employee_id === empId);
	}

	async function resolveManagerNames(managers: any[]) {
		if (!managers || managers.length === 0) return;
		const ids = managers.map((m: any) => m.employee_id).filter((id: string) => id && !managerNames[id]);
		if (ids.length === 0) return;
		const { data } = await supabase
			.from('hr_employee_master')
			.select('id, name_en, name_ar')
			.in('id', ids);
		if (data) {
			const updated = { ...managerNames };
			for (const emp of data) {
				updated[emp.id] = isRtl ? (emp.name_ar || emp.name_en || emp.id) : (emp.name_en || emp.name_ar || emp.id);
			}
			managerNames = updated;
		}
	}

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
		await loadEmployeeId();
	});

	async function loadEmployeeId() {
		if (!$currentUser?.id) return;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar')
				.eq('user_id', $currentUser.id)
				.maybeSingle();
			if (!error && data) {
				employeeId = data.id;
				employeeName = isRtl ? (data.name_ar || data.name_en || '') : (data.name_en || data.name_ar || '');
			}
		} catch (err) {
			console.error('Error loading employee ID:', err);
		}
	}

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

			// Fetch actual branch names from branches table
			if (branches.length > 0) {
				const branchIds = branches.map(b => b.branch_id);
				const { data: branchData } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar')
					.in('id', branchIds);
				if (branchData) {
					const branchMap = new Map(branchData.map(b => [Number(b.id), b]));
					branches = branches.map(b => {
						const info = branchMap.get(b.branch_id);
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
	let barcodeDetector: any = null;
	let scanCanvas: HTMLCanvasElement | null = null;
	let scanCtx: CanvasRenderingContext2D | null = null;

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
				await new Promise(r => setTimeout(r, 500));
				await initDetector();
				detectBarcode();
			}
		} catch (err) {
			console.error('Camera access error:', err);
			scanning = false;
		}
	}

	async function initDetector() {
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
			stopScan();
			return;
		}

		scanCanvas = document.createElement('canvas');
		scanCtx = scanCanvas.getContext('2d');

		scanInterval = setInterval(async () => {
			if (!videoEl || videoEl.readyState < 2 || !scanCanvas || !scanCtx) return;
			try {
				const vw = videoEl.videoWidth;
				const vh = videoEl.videoHeight;
				if (vw === 0 || vh === 0) return;
				scanCanvas.width = vw;
				scanCanvas.height = vh;
				scanCtx.drawImage(videoEl, 0, 0, vw, vh);

				let barcodes: any[] = [];
				try {
					barcodes = await barcodeDetector.detect(scanCanvas);
				} catch (_) {
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
				.select('barcode, product_name_en, product_name_ar, parent_barcode, expiry_dates, managed_by')
				.eq('barcode', bc.trim())
				.limit(1)
				.maybeSingle();
			if (error) throw error;
			if (!data) {
				lookupError = isRtl ? 'لم يتم العثور على المنتج' : 'Product not found';
			} else {
				product = data;
				if (data.managed_by && data.managed_by.length > 0) {
					resolveManagerNames(data.managed_by);
				}
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

	// Clear product and reset for next scan
	function clearProduct() {
		product = null;
		barcode = '';
		lookupError = '';
		saveSuccess = false;
		saveError = '';
		claimSuccess = false;
		claimError = '';
		newExpiryDate = '';
		selectedYear = '';
		selectedMonth = '';
		selectedDay = '';
		showDatePopup = false;
	}

	// --- Claim product (Mine) ---
	async function claimProduct() {
		if (!product || !employeeId || !selectedBranchId) return;
		claiming = true;
		claimError = '';
		claimSuccess = false;

		try {
			const newEntry = {
				employee_id: employeeId,
				branch_id: selectedBranchId,
				claimed_at: new Date().toISOString()
			};

			// Update product managed_by - add to existing array
			const currentManaged: any[] = product.managed_by ? [...product.managed_by] : [];
			const alreadyExists = currentManaged.some((m: any) => m.employee_id === employeeId && m.branch_id === selectedBranchId);
			if (alreadyExists) {
				claimError = isRtl ? 'أنت تدير هذا المنتج بالفعل' : 'You already manage this product';
				claiming = false;
				return;
			}
			currentManaged.push(newEntry);

			const { error } = await supabase
				.from('erp_synced_products')
				.update({ managed_by: currentManaged })
				.eq('barcode', product.barcode);

			if (error) throw error;

			// Update local state
			product = { ...product, managed_by: currentManaged };
			// Add current employee name to cache
			if (employeeId && employeeName) {
				managerNames = { ...managerNames, [employeeId]: employeeName };
			} else if (employeeId) {
				resolveManagerNames(currentManaged);
			}
			claimSuccess = true;
		} catch (err: any) {
			claimError = err.message || 'Error';
		} finally {
			claiming = false;
		}
	}

	// --- Unclaim product ---
	async function unclaimProduct() {
		if (!product || !employeeId) return;
		claiming = true;
		claimError = '';
		claimSuccess = false;

		try {
			const currentManaged: any[] = product.managed_by ? [...product.managed_by] : [];
			const filtered = currentManaged.filter((m: any) => !(m.employee_id === employeeId && m.branch_id === selectedBranchId));

			const { error } = await supabase
				.from('erp_synced_products')
				.update({ managed_by: filtered })
				.eq('barcode', product.barcode);

			if (error) throw error;

			product = { ...product, managed_by: filtered };
			claimSuccess = true;
		} catch (err: any) {
			claimError = err.message || 'Error';
		} finally {
			claiming = false;
		}
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
			// 1. Update SQL Server (ERP) via bridge
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					action: 'update-expiry',
					tunnelUrl: selectedConfig.tunnel_url,
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
					{#if daysLeft !== null}
						<span class="days-left-badge"
							class:days-expired={daysLeft <= 0}
							class:days-critical={daysLeft > 0 && daysLeft <= 3}
							class:days-warning={daysLeft > 3 && daysLeft <= 7}
							class:days-soon={daysLeft > 7 && daysLeft <= 14}
							class:days-safe={daysLeft > 14}
						>
							{#if daysLeft < 0}
								{isRtl ? `منتهي منذ ${Math.abs(daysLeft)} يوم` : `Expired ${Math.abs(daysLeft)} ${Math.abs(daysLeft) === 1 ? 'day' : 'days'} ago`}
							{:else if daysLeft === 0}
								{isRtl ? 'ينتهي اليوم' : 'Expires today'}
							{:else}
								{isRtl ? `متبقي ${daysLeft} يوم` : `${daysLeft} ${daysLeft === 1 ? 'day' : 'days'} remaining`}
							{/if}
						</span>
					{/if}
				</div>

				<div class="action-buttons-row">
					<button class="change-btn" on:click={openDatePopup}>
						📅 {isRtl ? 'تغيير الصلاحية' : 'Change Expiry'}
					</button>
					<button class="mine-btn" class:mine-btn-claimed={alreadyClaimed} on:click={claimProduct} disabled={claiming || !employeeId || alreadyClaimed}>
						{#if claiming}
							<span class="save-spinner">⏳</span>
						{:else if alreadyClaimed}
							✅ {isRtl ? 'لي' : 'Mine'}
						{:else}
							🙋 {isRtl ? 'لي' : 'Mine'}
						{/if}
					</button>
					<button class="clear-btn" on:click={clearProduct}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
							<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
						{isRtl ? 'التالي' : 'Next'}
					</button>
				</div>

				<!-- Claimed users card section -->
				{#if product.managed_by && product.managed_by.length > 0}
					<div class="claimed-section">
						<div class="claimed-title">👥 {isRtl ? 'المستخدمون' : 'Claimed By'}</div>
						<div class="claimed-cards-row">
							{#each product.managed_by as manager}
								{@const isCurrentBranch = manager.branch_id === selectedBranchId}
								{@const isMe = manager.employee_id === employeeId}
								{@const branchInfo = branches.find(b => b.branch_id === manager.branch_id)}
								{@const branchFullName = branchInfo?.branch_name || ''}
								{@const branchParts = branchFullName.split(' - ')}
								{@const branchName = branchParts[0] || branchFullName}
								{@const branchLoc = branchParts.slice(1).join(' - ')}
								<div class="claimed-card" class:claimed-card-current={isCurrentBranch} class:claimed-card-me={isMe}>
									<div class="claimed-card-header">
										<span class="claimed-avatar">{isMe ? '🙋' : '👤'}</span>
										<div class="claimed-badges">
											{#if isCurrentBranch}
												<span class="badge-current">{isRtl ? 'الفرع الحالي' : 'Current'}</span>
											{/if}
											{#if isMe}
												<span class="badge-me">{isRtl ? 'أنا' : 'Me'}</span>
											{/if}
										</div>
									</div>
									<div class="claimed-name">{managerNames[manager.employee_id] || manager.employee_id}</div>
									<div class="claimed-branch">{branchName}</div>
									{#if branchLoc}
										<div class="claimed-location">📍 {branchLoc}</div>
									{/if}
								</div>
							{/each}
						</div>
						{#if product.managed_by.some((m) => m.employee_id === employeeId)}
							<button class="unclaim-btn" on:click={unclaimProduct} disabled={claiming}>
								{#if claiming}⏳{:else}✖{/if}
								{isRtl ? 'إلغاء المطالبة' : 'Unclaim'}
							</button>
						{/if}
					</div>
				{/if}

				{#if claimSuccess}
					<div class="success-msg">
						✅ {isRtl ? 'تم التحديث' : 'Updated'}
					</div>
				{/if}
				{#if claimError}
					<div class="error-msg">{claimError}</div>
				{/if}

				{#if saveSuccess}
					<div class="success-msg">
						✅ {isRtl ? 'تم التحديث بنجاح' : 'Updated successfully'}
						<button class="next-after-save" on:click={clearProduct}>
							➡️ {isRtl ? 'المنتج التالي' : 'Next Product'}
						</button>
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
		border: 1px solid #D1FAE5;
		background: #F0FDF4;
	}

	.product-name {
		font-size: 0.88rem;
		font-weight: 700;
		color: #065F46;
		margin-bottom: 0.15rem;
	}

	.product-barcode {
		font-size: 0.72rem;
		color: #6B7280;
		font-family: monospace;
		margin-bottom: 0.4rem;
	}

	.expiry-row {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.4rem 0.5rem;
		background: white;
		border-radius: 5px;
		border: 1px solid #D1D5DB;
		margin-bottom: 0.4rem;
	}

	.expiry-label {
		font-size: 0.74rem;
		font-weight: 600;
		color: #374151;
	}

	.expiry-value {
		font-size: 0.82rem;
		font-weight: 700;
		color: #B45309;
		font-family: monospace;
	}

	.expiry-value.no-date {
		color: #9CA3AF;
		font-style: italic;
		font-weight: 400;
	}

	.days-left-badge {
		padding: 0.1rem 0.4rem;
		border-radius: 5px;
		font-size: 0.68rem;
		font-weight: 700;
		white-space: nowrap;
		margin-inline-start: auto;
	}
	.days-expired { background: #FEE2E2; color: #991B1B; }
	.days-critical { background: #FEE2E2; color: #991B1B; }
	.days-warning { background: #FEF3C7; color: #92400E; }
	.days-soon { background: #FEF9C3; color: #854D0E; }
	.days-safe { background: #D1FAE5; color: #065F46; }

	.action-buttons-row {
		display: flex;
		gap: 0.35rem;
	}

	.change-btn {
		flex: 1;
		padding: 0.45rem;
		background: linear-gradient(135deg, #F59E0B, #D97706);
		color: white;
		border: none;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
		box-shadow: none;
		text-align: center;
	}

	.change-btn:active {
		background: linear-gradient(135deg, #D97706, #B45309);
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

	.next-after-save {
		display: block;
		width: 100%;
		margin-top: 0.3rem;
		padding: 0.4rem;
		background: #047857;
		color: white;
		border: none;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
	}

	.next-after-save:active {
		background: #065F46;
	}

	/* Mine button */
	.mine-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.15rem;
		padding: 0.45rem;
		background: linear-gradient(135deg, #3B82F6, #2563EB);
		color: white;
		border: none;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
		box-shadow: none;
	}

	.mine-btn:active {
		background: linear-gradient(135deg, #2563EB, #1D4ED8);
	}

	.mine-btn-claimed {
		background: linear-gradient(135deg, #10B981, #059669);
	}

	.mine-btn-claimed:active {
		background: linear-gradient(135deg, #059669, #047857);
	}

	.mine-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
	}

	.claimed-section {
		margin-top: 0.6rem;
		padding-top: 0.5rem;
		border-top: 1px solid #E2E8F0;
	}

	.claimed-title {
		font-size: 0.65rem;
		font-weight: 700;
		color: #94A3B8;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		margin-bottom: 0.4rem;
	}

	.claimed-cards-row {
		display: flex;
		gap: 0.5rem;
		overflow-x: auto;
		padding-bottom: 0.25rem;
		-webkit-overflow-scrolling: touch;
		scrollbar-width: none;
	}

	.claimed-cards-row::-webkit-scrollbar {
		display: none;
	}

	.claimed-card {
		flex-shrink: 0;
		min-width: 120px;
		max-width: 150px;
		padding: 0.5rem 0.6rem;
		background: #F8FAFC;
		border: 1.5px solid #E2E8F0;
		border-radius: 10px;
	}

	.claimed-card-current {
		background: #F0FDF4;
		border-color: #10B981;
		box-shadow: 0 0 0 1px #10B98120;
	}

	.claimed-card-me:not(.claimed-card-current) {
		background: #EFF6FF;
		border-color: #93C5FD;
	}

	.claimed-card-header {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-bottom: 0.3rem;
		flex-wrap: wrap;
	}

	.claimed-avatar {
		font-size: 1rem;
		line-height: 1;
	}

	.claimed-badges {
		display: flex;
		gap: 0.2rem;
		flex-wrap: wrap;
	}

	.badge-current {
		padding: 0.1rem 0.3rem;
		background: #D1FAE5;
		color: #065F46;
		border-radius: 4px;
		font-size: 0.55rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		white-space: nowrap;
	}

	.badge-me {
		padding: 0.1rem 0.3rem;
		background: #DBEAFE;
		color: #1E40AF;
		border-radius: 4px;
		font-size: 0.55rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}

	.claimed-name {
		font-size: 0.75rem;
		font-weight: 700;
		color: #1E293B;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.claimed-branch {
		font-size: 0.63rem;
		color: #475569;
		margin-top: 0.1rem;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.claimed-location {
		font-size: 0.58rem;
		color: #94A3B8;
		margin-top: 0.05rem;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.unclaim-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		width: 100%;
		margin-top: 0.45rem;
		padding: 0.35rem 0.6rem;
		background: #FEE2E2;
		color: #991B1B;
		border: 1px solid #FECACA;
		border-radius: 7px;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}

	.unclaim-btn:active {
		background: #FECACA;
	}

	.unclaim-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.success-msg {
		margin-top: 0.35rem;
		padding: 0.35rem 0.5rem;
		background: #D1FAE5;
		color: #065F46;
		border-radius: 5px;
		font-size: 0.74rem;
		font-weight: 600;
		text-align: center;
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
		padding: 0.45rem;
		background: #F3F4F6;
		color: #374151;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-cancel:active {
		background: #E5E7EB;
	}

	.btn-save {
		flex: 1;
		padding: 0.45rem;
		background: #047857;
		color: white;
		border: none;
		border-radius: 5px;
		font-size: 0.78rem;
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
