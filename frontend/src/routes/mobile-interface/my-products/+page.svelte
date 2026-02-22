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

	// Selection & Send
	let selectMode = false;
	let selectedBarcodes: Set<string> = new Set();
	$: selectedCount = selectedBarcodes.size;

	// Send popup state
	let showSendPopup = false;
	type RequestType = 'BT' | 'ST' | 'PO' | null;
	let requestType: RequestType = null;
	let branches: { id: number; name_en: string; name_ar: string; location_en: string; location_ar: string }[] = [];
	let selectedSendBranchId: number | null = null;
	let selectedUserId: string | null = null;
	let selectedUserName: string = '';
	let branchUsers: { id: string; username: string; name_en?: string; name_ar?: string }[] = [];
	let loadingBranches = false;
	let loadingUsers = false;
	let noDefaultPosition = false;
	let sending = false;
	let sendSuccess = false;
	let sendError = '';

	const PURCHASING_MANAGER_POSITION_ID = '540c129e-79b4-4100-b645-086ef2485449';

	function toggleSelectMode() {
		selectMode = !selectMode;
		if (!selectMode) {
			selectedBarcodes = new Set();
		}
	}

	function toggleProduct(barcode: string) {
		if (selectedBarcodes.has(barcode)) {
			selectedBarcodes.delete(barcode);
		} else {
			selectedBarcodes.add(barcode);
		}
		selectedBarcodes = selectedBarcodes; // trigger reactivity
	}

	function selectAll() {
		if (selectedBarcodes.size === filteredProducts.length) {
			selectedBarcodes = new Set();
		} else {
			selectedBarcodes = new Set(filteredProducts.map(p => p.barcode));
		}
	}

	function openSendPopup() {
		if (selectedCount === 0) return;
		requestType = null;
		selectedSendBranchId = null;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		noDefaultPosition = false;
		sendError = '';
		sendSuccess = false;
		showSendPopup = true;
	}

	function closeSendPopup() {
		showSendPopup = false;
		requestType = null;
	}

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error: err } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en', { ascending: true });
			if (err) throw err;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			loadingBranches = false;
		}
	}

	async function loadBranchManager(bId: number) {
		noDefaultPosition = false;
		try {
			const { data, error: err } = await supabase
				.from('branch_default_positions')
				.select('branch_manager_user_id')
				.eq('branch_id', bId)
				.single();
			if (err) {
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
				return;
			}
			if (data?.branch_manager_user_id) {
				selectedUserId = data.branch_manager_user_id;
				const { data: userData } = await supabase
					.from('users')
					.select('username')
					.eq('id', data.branch_manager_user_id)
					.single();
				if (userData) selectedUserName = userData.username;
			} else {
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
			}
		} catch (err) {
			console.error('Error loading branch manager:', err);
			noDefaultPosition = true;
		}
	}

	async function loadPurchasingManagers() {
		loadingUsers = true;
		try {
			const { data: employees, error: empErr } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar')
				.eq('current_position_id', PURCHASING_MANAGER_POSITION_ID);
			if (empErr) throw empErr;
			if (!employees || employees.length === 0) { branchUsers = []; return; }
			const userIds = employees.map(e => e.user_id);
			const { data: users } = await supabase
				.from('users')
				.select('id, username')
				.in('id', userIds)
				.eq('status', 'active')
				.order('username', { ascending: true });
			branchUsers = (users || []).map(u => {
				const emp = employees.find(e => e.user_id === u.id);
				return { id: u.id, username: u.username, name_en: emp?.name_en || '', name_ar: emp?.name_ar || '' };
			});
			if (branchUsers.length === 1) {
				selectedUserId = branchUsers[0].id;
				selectedUserName = branchUsers[0].name_en || branchUsers[0].username;
			}
		} catch (err) {
			console.error('Error loading purchasing managers:', err);
		} finally {
			loadingUsers = false;
		}
	}

	async function selectSendType(type: RequestType) {
		requestType = type;
		selectedSendBranchId = null;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		noDefaultPosition = false;

		if (type === 'BT') {
			await loadBranches();
		} else if (type === 'ST') {
			await loadBranches();
			const userBranchId = $currentUser?.branch_id;
			if (userBranchId) {
				selectedSendBranchId = Number(userBranchId);
				await loadBranchManager(selectedSendBranchId);
			}
		} else if (type === 'PO') {
			await loadPurchasingManagers();
		}
	}

	async function onSendBranchSelected() {
		if (!selectedSendBranchId) return;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		await loadBranchManager(selectedSendBranchId);
	}

	function onSendUserSelected() {
		const user = branchUsers.find(u => u.id === selectedUserId);
		selectedUserName = user ? (user.name_en || user.username) : '';
	}

	async function handleSendRequest() {
		if (!requestType || !selectedUserId || !$currentUser?.id) return;
		sending = true;
		sendError = '';
		sendSuccess = false;

		try {
			// Build items from selected products
			const selectedProducts = products.filter(p => selectedBarcodes.has(p.barcode));
			const itemsData = selectedProducts.map(p => ({
				barcode: p.barcode,
				product_name: isRtl ? (p.product_name_ar || p.product_name_en) : (p.product_name_en || p.product_name_ar),
				quantity: 1,
				photo_url: null
			}));

			let insertError;
			let requestId: string | null = null;

			if (requestType === 'BT') {
				const fromBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
				const result = await supabase
					.from('product_request_bt')
					.insert({ requester_user_id: $currentUser.id, from_branch_id: fromBranchId, to_branch_id: selectedSendBranchId, target_user_id: selectedUserId, status: 'pending', items: itemsData })
					.select('id').single();
				insertError = result.error;
				requestId = result.data?.id || null;
			} else if (requestType === 'ST') {
				const result = await supabase
					.from('product_request_st')
					.insert({ requester_user_id: $currentUser.id, branch_id: selectedSendBranchId, target_user_id: selectedUserId, status: 'pending', items: itemsData })
					.select('id').single();
				insertError = result.error;
				requestId = result.data?.id || null;
			} else if (requestType === 'PO') {
				const fromBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
				const result = await supabase
					.from('product_request_po')
					.insert({ requester_user_id: $currentUser.id, from_branch_id: fromBranchId, target_user_id: selectedUserId, status: 'pending', items: itemsData })
					.select('id').single();
				insertError = result.error;
				requestId = result.data?.id || null;
			}

			if (insertError) throw insertError;

			// Create Quick Tasks
			if (requestId && requestType && selectedUserId) {
				try {
					const requesterName = $currentUser?.username || 'User';
					const receiverName = selectedUserName || 'Receiver';
					const bId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
					const typeLabel = requestType === 'BT' ? 'Branch Transfer' : requestType === 'ST' ? 'Stock Request' : 'Purchase Order';
					const typeLabelAr = requestType === 'BT' ? 'نقل فرعي' : requestType === 'ST' ? 'طلب مخزون' : 'أمر شراء';

					const { data: requesterTask } = await supabase
						.from('quick_tasks')
						.insert({ title: `Follow up ${requestType} Request | متابعة طلب ${requestType}`, description: `${typeLabel} request sent to ${receiverName}.\n---\nطلب ${typeLabelAr} مرسل إلى ${receiverName}.`, priority: 'medium', issue_type: 'product_request_follow_up', assigned_by: $currentUser.id, assigned_to_branch_id: bId, product_request_id: requestId, product_request_type: requestType })
						.select('id').single();
					if (requesterTask) {
						await supabase.from('quick_task_assignments').insert({ quick_task_id: requesterTask.id, assigned_to_user_id: $currentUser.id, require_task_finished: true });
					}

					const { data: receiverTask } = await supabase
						.from('quick_tasks')
						.insert({ title: `Process ${requestType} Request | معالجة طلب ${requestType}`, description: `${typeLabel} request from ${requesterName}.\n---\nطلب ${typeLabelAr} من ${requesterName}.`, priority: 'high', issue_type: 'product_request_process', assigned_by: $currentUser.id, assigned_to_branch_id: selectedSendBranchId, product_request_id: requestId, product_request_type: requestType })
						.select('id').single();
					if (receiverTask) {
						await supabase.from('quick_task_assignments').insert({ quick_task_id: receiverTask.id, assigned_to_user_id: selectedUserId, require_task_finished: true });
					}
				} catch (taskErr) {
					console.warn('Failed to create quick tasks:', taskErr);
				}
			}

			sendSuccess = true;
			setTimeout(() => {
				selectedBarcodes = new Set();
				selectMode = false;
				closeSendPopup();
				sendSuccess = false;
			}, 1500);
		} catch (err: any) {
			console.error('Error sending request:', err);
			sendError = err?.message || 'Failed to send request';
		} finally {
			sending = false;
		}
	}

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
		const CHUNK_SIZE = 1000;

		try {
			let allData: any[] = [];
			let offset = 0;
			let totalCount = 0;

			// Load in chunks of 1000 via RPC
			while (true) {
				const { data, error: err } = await supabase.rpc('get_employee_products', {
					p_employee_id: employeeId,
					p_limit: CHUNK_SIZE,
					p_offset: offset
				});

				if (err) {
					error = t('Failed to load products', 'فشل تحميل المنتجات');
					console.error('RPC error:', err);
					loading = false;
					return;
				}

				totalCount = data?.total_count || 0;
				const chunk = data?.products || [];
				allData = [...allData, ...chunk];

				if (chunk.length < CHUNK_SIZE) break;
				offset += CHUNK_SIZE;
			}

			if (allData.length === 0) {
				loading = false;
				return;
			}

			const result: MyProduct[] = [];

			for (const row of allData) {
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
				<button class="select-btn" class:active={selectMode} on:click={toggleSelectMode} aria-label="Select mode" title={t('Select products', 'اختيار المنتجات')}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<polyline points="9 11 12 14 22 4"/>
						<path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
					</svg>
				</button>
			</div>
			{#if selectMode}
				<div class="select-actions-bar">
					<button class="select-all-btn" on:click={selectAll}>
						{selectedBarcodes.size === filteredProducts.length ? t('Deselect All', 'إلغاء الكل') : t('Select All', 'تحديد الكل')}
					</button>
					<span class="selected-count">{selectedCount} {t('selected', 'محدد')}</span>
					<button class="send-selected-btn" on:click={openSendPopup} disabled={selectedCount === 0}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
							<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
						</svg>
						{t('Send', 'إرسال')}
					</button>
				</div>
			{/if}
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
				<div class="product-row" class:selected={selectMode && selectedBarcodes.has(item.barcode)} on:click={() => selectMode && toggleProduct(item.barcode)} role={selectMode ? 'button' : undefined} tabindex={selectMode ? 0 : undefined} on:keydown={(e) => selectMode && e.key === 'Enter' && toggleProduct(item.barcode)}>
					{#if selectMode}
						<div class="product-checkbox">
							<div class="checkbox" class:checked={selectedBarcodes.has(item.barcode)}>
								{#if selectedBarcodes.has(item.barcode)}
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3">
										<polyline points="20 6 9 17 4 12"/>
									</svg>
								{/if}
							</div>
						</div>
					{/if}
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

	<!-- Send Popup -->
	{#if showSendPopup}
		<div class="send-overlay" on:click={closeSendPopup} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeSendPopup()}>
			<div class="send-popup" on:click|stopPropagation role="none">
				<div class="send-popup-header">
					<span>{t('Send Request', 'إرسال طلب')} ({selectedCount} {t('products', 'منتج')})</span>
					<button class="send-popup-close" on:click={closeSendPopup}>&times;</button>
				</div>
				<div class="send-popup-body">
					<!-- Type Selection -->
					<div class="send-type-row">
						<button class="send-type-btn" class:active={requestType === 'BT'} on:click={() => selectSendType('BT')}>
							<span class="send-type-code">BT</span>
							<span class="send-type-label">{t('Branch Transfer', 'نقل فرعي')}</span>
						</button>
						<button class="send-type-btn" class:active={requestType === 'ST'} on:click={() => selectSendType('ST')}>
							<span class="send-type-code">ST</span>
							<span class="send-type-label">{t('Stock Request', 'طلب مخزون')}</span>
						</button>
						<button class="send-type-btn" class:active={requestType === 'PO'} on:click={() => selectSendType('PO')}>
							<span class="send-type-code">PO</span>
							<span class="send-type-label">{t('Purchase Order', 'أمر شراء')}</span>
						</button>
					</div>

					{#if requestType}
						<!-- Branch Selection (BT & ST) -->
						{#if requestType === 'BT' || requestType === 'ST'}
							<div class="send-form-group">
								<label>{t('Select Branch', 'اختر الفرع')}</label>
								{#if loadingBranches}
									<div class="send-loading">{t('Loading...', 'جاري التحميل...')}</div>
								{:else}
									<select class="send-select" bind:value={selectedSendBranchId} on:change={onSendBranchSelected}>
										<option value={null}>{t('Choose branch...', 'اختر الفرع...')}</option>
										{#each branches as branch}
											<option value={branch.id}>{isRtl ? branch.name_ar : branch.name_en} - {isRtl ? branch.location_ar : branch.location_en}</option>
										{/each}
									</select>
								{/if}
							</div>
						{/if}

						<!-- Purchasing Manager for PO -->
						{#if requestType === 'PO'}
							<div class="send-form-group">
								<label>{t('Select Manager', 'اختر المسؤول')}</label>
								{#if loadingUsers}
									<div class="send-loading">{t('Loading...', 'جاري التحميل...')}</div>
								{:else}
									<select class="send-select" bind:value={selectedUserId} on:change={onSendUserSelected}>
										<option value={null}>{t('Choose user...', 'اختر المستخدم...')}</option>
										{#each branchUsers as user}
											<option value={user.id}>{isRtl ? (user.name_ar || user.username) : (user.name_en || user.username)}</option>
										{/each}
									</select>
								{/if}
							</div>
						{/if}

						<!-- Auto-selected manager for BT/ST -->
						{#if (requestType === 'BT' || requestType === 'ST') && selectedUserId}
							<div class="send-auto-info">
								<span class="send-auto-label">{t('Manager', 'المسؤول')}:</span>
								<span class="send-auto-value">{selectedUserName}</span>
							</div>
						{/if}

						<!-- No default position warning -->
						{#if (requestType === 'BT' || requestType === 'ST') && noDefaultPosition && selectedSendBranchId}
							<div class="send-warning">
								⚠️ {t('No default manager set for this branch', 'لم يتم تعيين مدير افتراضي لهذا الفرع')}
							</div>
						{/if}

						<!-- Send Button -->
						{#if (requestType === 'BT' && selectedSendBranchId && selectedUserId) || (requestType === 'ST' && selectedUserId) || (requestType === 'PO' && selectedUserId)}
							{#if sendSuccess}
								<div class="send-success">✅ {t('Sent successfully!', 'تم الإرسال بنجاح!')}</div>
							{:else}
								{#if sendError}
									<div class="send-error">{sendError}</div>
								{/if}
								<button class="send-confirm-btn" on:click={handleSendRequest} disabled={sending}>
									{#if sending}
										<div class="spinner-sm"></div>
									{:else}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
											<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
										</svg>
									{/if}
									{t('Send Request', 'إرسال الطلب')}
								</button>
							{/if}
						{/if}
					{/if}
				</div>
			</div>
		</div>
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

	/* Select mode */
	.select-btn {
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
	.select-btn.active {
		background: #047857;
		color: white;
		border-color: #047857;
	}
	.select-btn:active { background: #E5E7EB; }
	.select-btn.active:active { background: #065F46; }

	.select-actions-bar {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		margin-top: 0.4rem;
		padding: 0.35rem 0.5rem;
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		border-radius: 6px;
	}
	.select-all-btn {
		padding: 0.25rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 4px;
		background: white;
		font-size: 0.66rem;
		font-weight: 600;
		color: #374151;
		cursor: pointer;
	}
	.select-all-btn:active { background: #E5E7EB; }
	.selected-count {
		flex: 1;
		font-size: 0.68rem;
		font-weight: 700;
		color: #047857;
		text-align: center;
	}
	.send-selected-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.3rem 0.6rem;
		border: none;
		border-radius: 5px;
		background: #047857;
		color: white;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}
	.send-selected-btn:disabled { opacity: 0.4; }
	.send-selected-btn:active { background: #065F46; }

	/* Checkbox */
	.product-checkbox {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
	.checkbox {
		width: 20px;
		height: 20px;
		border: 2px solid #D1D5DB;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: white;
		transition: all 0.15s;
	}
	.checkbox.checked {
		background: #047857;
		border-color: #047857;
	}
	.product-row.selected {
		background: #F0FDF4;
		border-color: #86EFAC;
	}
	.product-row[role="button"] {
		cursor: pointer;
	}

	/* Send Popup */
	.send-overlay {
		position: fixed;
		top: 0; left: 0; right: 0; bottom: 0;
		background: rgba(0,0,0,0.5);
		z-index: 100;
		display: flex;
		align-items: flex-end;
		justify-content: center;
	}
	.send-popup {
		width: 100%;
		max-width: 420px;
		max-height: 80vh;
		background: white;
		border-radius: 16px 16px 0 0;
		overflow-y: auto;
		box-shadow: 0 -4px 20px rgba(0,0,0,0.15);
		padding-bottom: 4.5rem;
	}
	.send-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #E5E7EB;
		font-size: 0.82rem;
		font-weight: 700;
		color: #1F2937;
	}
	.send-popup-close {
		border: none;
		background: none;
		font-size: 1.4rem;
		color: #9CA3AF;
		cursor: pointer;
		line-height: 1;
	}
	.send-popup-body {
		padding: 0.75rem 1rem 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.65rem;
	}
	.send-type-row {
		display: flex;
		gap: 0.4rem;
	}
	.send-type-btn {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.15rem;
		padding: 0.55rem 0.3rem;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		background: white;
		cursor: pointer;
		transition: all 0.15s;
	}
	.send-type-btn.active {
		border-color: #047857;
		background: #F0FDF4;
	}
	.send-type-btn:active { background: #F3F4F6; }
	.send-type-code {
		font-size: 0.9rem;
		font-weight: 900;
		color: #047857;
	}
	.send-type-label {
		font-size: 0.6rem;
		font-weight: 600;
		color: #6B7280;
	}
	.send-form-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}
	.send-form-group label {
		font-size: 0.68rem;
		font-weight: 700;
		color: #374151;
	}
	.send-select {
		width: 100%;
		padding: 0.45rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.72rem;
		background: white;
		color: #1F2937;
	}
	.send-loading {
		font-size: 0.7rem;
		color: #9CA3AF;
		padding: 0.3rem 0;
	}
	.send-auto-info {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.5rem;
		background: #EFF6FF;
		border-radius: 6px;
	}
	.send-auto-label {
		font-size: 0.66rem;
		font-weight: 600;
		color: #6B7280;
	}
	.send-auto-value {
		font-size: 0.72rem;
		font-weight: 700;
		color: #1D4ED8;
	}
	.send-warning {
		padding: 0.35rem 0.5rem;
		background: #FEF3C7;
		border-radius: 6px;
		font-size: 0.66rem;
		color: #92400E;
		font-weight: 600;
	}
	.send-success {
		padding: 0.5rem;
		background: #D1FAE5;
		border-radius: 6px;
		text-align: center;
		font-size: 0.76rem;
		font-weight: 700;
		color: #065F46;
	}
	.send-error {
		padding: 0.35rem 0.5rem;
		background: #FEE2E2;
		border-radius: 6px;
		font-size: 0.66rem;
		color: #991B1B;
		font-weight: 600;
	}
	.send-confirm-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		width: 100%;
		padding: 0.6rem;
		border: none;
		border-radius: 8px;
		background: #047857;
		color: white;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
	}
	.send-confirm-btn:disabled { opacity: 0.5; }
	.send-confirm-btn:active { background: #065F46; }
	.spinner-sm {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
</style>
