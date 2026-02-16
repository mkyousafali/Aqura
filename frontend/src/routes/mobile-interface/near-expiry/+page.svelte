<script lang="ts">
	import { compressImage } from '$lib/utils/imageCompression';
	import { currentLocale } from '$lib/i18n';
	import { onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	function t(en: string, ar: string): string {
		return $currentLocale === 'ar' ? ar : en;
	}

	interface ExpiryItem {
		barcode: string;
		expiryDate: string;
		photo: string | null;
	}

	interface BranchOption {
		id: number;
		name_en: string;
		name_ar: string;
		location_en: string;
		location_ar: string;
	}

	let items: ExpiryItem[] = [];
	let showModal = false;
	let modalBarcode = '';
	let modalExpiryDate = '';
	let modalPhoto: string | null = null;
	let fileInput: HTMLInputElement;

	// Report title state
	let reportTitle = '';
	let showTitlePopup = false;
	let titleConfirmed = false;

	// Date picker state (Year → Month → Day)
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

	// Generate month options (1-12) based on selected year
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
		modalExpiryDate = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
	}

	const monthNames = {
		en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
		ar: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر']
	};

	// Barcode scanner state
	let scanning = false;
	let videoEl: HTMLVideoElement;
	let stream: MediaStream | null = null;
	let scanInterval: ReturnType<typeof setInterval> | null = null;

	// OCR text recognition state for expiry date
	let textScanning = false;
	let textVideoEl: HTMLVideoElement;
	let textStream: MediaStream | null = null;
	let detectedTexts: string[] = [];
	let showTextResults = false;
	let textDetecting = false;
	let ocrNoResult = false;

	// Save popup state
	let showSavePopup = false;
	let branches: BranchOption[] = [];
	let selectedBranchId: number | null = null;
	let selectedUserId: string | null = null;
	let selectedUserName: string = '';
	let loadingBranches = false;
	let noDefaultPosition = false;
	let sending = false;
	let sendSuccess = false;
	let sendError = '';

	function openSavePopup() {
		selectedBranchId = null;
		selectedUserId = null;
		selectedUserName = '';
		noDefaultPosition = false;
		sendError = '';
		sendSuccess = false;
		showSavePopup = true;
		loadBranches();
	}

	function closeSavePopup() {
		showSavePopup = false;
	}

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en', { ascending: true });
			if (error) throw error;
			branches = data || [];

			// Pre-select user's branch
			const userBranchId = $currentUser?.branch_id;
			if (userBranchId) {
				selectedBranchId = Number(userBranchId);
				await loadInventoryManager(selectedBranchId);
			}
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			loadingBranches = false;
		}
	}

	async function loadInventoryManager(branchId: number) {
		noDefaultPosition = false;
		try {
			const { data, error } = await supabase
				.from('branch_default_positions')
				.select('inventory_manager_user_id')
				.eq('branch_id', branchId)
				.single();
			if (error) {
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
				return;
			}
			if (data?.inventory_manager_user_id) {
				selectedUserId = data.inventory_manager_user_id;
				const { data: empData, error: empError } = await supabase
					.from('hr_employee_master')
					.select('name_en, name_ar')
					.eq('user_id', data.inventory_manager_user_id)
					.single();
				if (!empError && empData) {
					selectedUserName = $currentLocale === 'ar' ? (empData.name_ar || empData.name_en) : (empData.name_en || empData.name_ar);
				}
			} else {
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
			}
		} catch (err) {
			console.error('Error loading branch manager:', err);
			noDefaultPosition = true;
			selectedUserId = null;
			selectedUserName = '';
		}
	}

	async function onBranchSelected() {
		if (!selectedBranchId) return;
		selectedUserId = null;
		selectedUserName = '';
		await loadInventoryManager(selectedBranchId);
	}

	async function uploadPhoto(photo: string, index: number): Promise<string | null> {
		try {
			const res = await fetch(photo);
			const blob = await res.blob();
			const ext = blob.type.split('/')[1] || 'jpg';
			const fileName = `near-expiry-${Date.now()}-${index}.${ext}`;

			const { error } = await supabase.storage
				.from('product-request-photos')
				.upload(fileName, blob, { cacheControl: '3600', upsert: false });

			if (error) {
				console.error('Photo upload error:', error);
				return null;
			}

			const { data: urlData } = supabase.storage
				.from('product-request-photos')
				.getPublicUrl(fileName);

			return urlData.publicUrl;
		} catch (err) {
			console.error('Error uploading photo:', err);
			return null;
		}
	}

	async function handleSend() {
		if (!selectedBranchId || !selectedUserId || !$currentUser?.id) return;
		sending = true;
		sendError = '';
		sendSuccess = false;

		try {
			// Upload photos and build items data
			const itemsData = await Promise.all(items.map(async (item, i) => {
				let photoUrl: string | null = null;
				if (item.photo) {
					photoUrl = await uploadPhoto(item.photo, i);
				}
				return {
					barcode: item.barcode,
					expiry_date: item.expiryDate,
					photo_url: photoUrl
				};
			}));

			const { data, error } = await supabase
				.from('near_expiry_reports')
				.insert({
					reporter_user_id: $currentUser.id,
					branch_id: selectedBranchId,
					target_user_id: selectedUserId,
					title: reportTitle,
					status: 'pending',
					items: itemsData
				})
				.select('id')
				.single();

			if (error) throw error;

			// Create quick task for branch manager
			if (data?.id && selectedUserId) {
				try {
					const requesterName = $currentUser?.username || 'User';
					const branchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;

					const { data: taskData } = await supabase
						.from('quick_tasks')
						.insert({
							title: `Near Expiry Report | تقرير قرب انتهاء الصلاحية`,
							description: `Near expiry products reported by ${requesterName}. ${items.length} item(s).\n---\nمنتجات قريبة من انتهاء الصلاحية بلغ عنها ${requesterName}. ${items.length} منتج(ات).`,
							priority: 'high',
							issue_type: 'near_expiry_report',
							assigned_by: $currentUser.id,
							assigned_to_branch_id: branchId,
							product_request_id: data.id,
							product_request_type: 'EXPIRY'
						})
						.select('id')
						.single();

					if (taskData) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: taskData.id,
							assigned_to_user_id: selectedUserId,
							require_task_finished: true
						});
					}

					console.log('✅ Quick task created for near expiry report:', data.id);
				} catch (taskErr) {
					console.warn('⚠️ Failed to create quick task:', taskErr);
				}
			}

			sendSuccess = true;
			setTimeout(() => {
				items = [];
				reportTitle = '';
				titleConfirmed = false;
				closeSavePopup();
				sendSuccess = false;
			}, 1500);
		} catch (err: any) {
			console.error('Error sending report:', err);
			sendError = err?.message || 'Failed to send report';
		} finally {
			sending = false;
		}
	}

	function addMoreFromSave() {
		closeSavePopup();
		openModal();
	}

	function generateDefaultTitle(): string {
		const now = new Date();
		const monthName = $currentLocale === 'ar' ? monthNames.ar[now.getMonth()] : monthNames.en[now.getMonth()];
		const userName = $currentUser?.username || $currentUser?.full_name || 'User';
		return `${monthName} ${now.getFullYear()} - ${userName}`;
	}

	function handleAddClick() {
		if (!titleConfirmed) {
			reportTitle = generateDefaultTitle();
			showTitlePopup = true;
		} else {
			openModal();
		}
	}

	function confirmTitle() {
		if (!reportTitle.trim()) return;
		titleConfirmed = true;
		showTitlePopup = false;
		openModal();
	}

	function openModal() {
		modalBarcode = '';
		modalExpiryDate = '';
		selectedYear = '';
		selectedMonth = '';
		selectedDay = '';
		showYearPicker = false;
		showMonthPicker = false;
		showDayPicker = false;
		modalPhoto = null;
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		stopScan();
	}

	function addItem() {
		items = [...items, { barcode: modalBarcode, expiryDate: modalExpiryDate, photo: modalPhoto }];
		closeModal();
	}

	function removeItem(index: number) {
		items = items.filter((_, i) => i !== index);
	}

	// --- Barcode scanner ---
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
						modalBarcode = barcodes[0].rawValue;
						stopScan();
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

	// --- Photo handling ---
	async function handlePhoto(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (file) {
			try {
				modalPhoto = await compressImage(file);
			} catch {
				const reader = new FileReader();
				reader.onload = (e) => { modalPhoto = e.target?.result as string; };
				reader.readAsDataURL(file);
			}
		}
	}

	function removePhoto() {
		modalPhoto = null;
		if (fileInput) fileInput.value = '';
	}

	// --- OCR text recognition for expiry date ---
	async function startTextScan() {
		textScanning = true;
		detectedTexts = [];
		showTextResults = false;
		textDetecting = false;
		ocrNoResult = false;
		try {
			textStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
			await new Promise(r => setTimeout(r, 50));
			if (textVideoEl) {
				textVideoEl.srcObject = textStream;
				await textVideoEl.play();
			}
		} catch (err) {
			console.error('Camera access error:', err);
			textScanning = false;
		}
	}

	function stopTextScan() {
		if (textStream) { textStream.getTracks().forEach(t => t.stop()); textStream = null; }
		textScanning = false;
		textDetecting = false;
	}

	async function captureAndDetect() {
		if (!textVideoEl || textVideoEl.readyState < 2) return;
		textDetecting = true;
		ocrNoResult = false;
		try {
			const canvas = document.createElement('canvas');
			canvas.width = textVideoEl.videoWidth;
			canvas.height = textVideoEl.videoHeight;
			const ctx = canvas.getContext('2d');
			if (!ctx) return;
			ctx.drawImage(textVideoEl, 0, 0);
			const base64 = canvas.toDataURL('image/jpeg', 0.85).split(',')[1];

			const apiKey = import.meta.env.VITE_GOOGLE_VISION_API_KEY || import.meta.env.VITE_GOOGLE_TTS_API_KEY;
			if (!apiKey) {
				console.error('No Google API key configured for Vision');
				textDetecting = false;
				ocrNoResult = true;
				return;
			}

			const response = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					requests: [{
						image: { content: base64 },
						features: [{ type: 'TEXT_DETECTION', maxResults: 20 }]
					}]
				})
			});
			const data = await response.json();

			if (data.error) {
				console.error('Vision API error:', data.error);
				textDetecting = false;
				ocrNoResult = true;
				return;
			}

			const annotations = data.responses?.[0]?.textAnnotations || [];
			if (annotations.length > 0) {
				const fullText = annotations[0]?.description || '';
				const lines = fullText.split('\n').filter((l: string) => l.trim().length > 0);
				detectedTexts = lines;
				showTextResults = true;
				stopTextScan();
			} else {
				detectedTexts = [];
				textDetecting = false;
				ocrNoResult = true;
			}
		} catch (err) {
			console.error('OCR error:', err);
			textDetecting = false;
			ocrNoResult = true;
		}
	}

	function selectDetectedText(text: string) {
		// Try to parse date from OCR text (supports YYYY-MM-DD, DD/MM/YYYY, MM/YYYY, etc.)
		const isoMatch = text.match(/(\d{4})[\-\/\.](\d{1,2})[\-\/\.](\d{1,2})/);
		const euMatch = text.match(/(\d{1,2})[\-\/\.](\d{1,2})[\-\/\.](\d{4})/);
		const monthYearMatch = text.match(/(\d{1,2})[\-\/\.](\d{4})/);
		
		if (isoMatch) {
			selectedYear = isoMatch[1];
			selectedMonth = String(Number(isoMatch[2]));
			selectedDay = String(Number(isoMatch[3]));
		} else if (euMatch) {
			selectedDay = String(Number(euMatch[1]));
			selectedMonth = String(Number(euMatch[2]));
			selectedYear = euMatch[3];
		} else if (monthYearMatch) {
			selectedMonth = String(Number(monthYearMatch[1]));
			selectedYear = monthYearMatch[2];
			selectedDay = '';
		} else {
			// Fallback: set raw text
			modalExpiryDate = text;
		}
		showTextResults = false;
		detectedTexts = [];
	}

	function closeTextResults() {
		showTextResults = false;
		detectedTexts = [];
	}

	onDestroy(() => { stopScan(); stopTextScan(); });
</script>

<div class="near-expiry-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Top buttons -->
	<div class="top-actions">
		<button type="button" class="add-btn" on:click={handleAddClick}>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
			</svg>
			<span>{t('Add Products', 'إضافة منتجات')}</span>
		</button>
	</div>

	<!-- Report title display -->
	{#if titleConfirmed && reportTitle}
		<div class="report-title-bar">
			<span class="report-title-label">📋</span>
			<span class="report-title-text">{reportTitle}</span>
		</div>
	{/if}

	<!-- Fixed bottom Save & Send button -->
	{#if items.length > 0}
		<div class="fixed-bottom-bar">
			<button type="button" class="save-btn" on:click={openSavePopup}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/>
					<polyline points="17 21 17 13 7 13 7 21"/>
					<polyline points="7 3 7 8 15 8"/>
				</svg>
				<span>{t('Save & Send', 'حفظ وإرسال')}</span>
			</button>
		</div>
	{/if}

	<!-- Items table -->
	{#if items.length > 0}
		<div class="table-wrapper">
			<table class="items-table">
				<thead>
					<tr>
						<th>{t('BRC', 'باركود')}</th>
						<th>{t('Expiry', 'الصلاحية')}</th>
						<th>{t('Img', 'صورة')}</th>
						<th></th>
					</tr>
				</thead>
			</table>
			<div class="table-scroll">
				<table class="items-table">
					<tbody>
					{#each items as item, i}
						<tr>
							<td>{item.barcode || '—'}</td>
							<td>{item.expiryDate ? item.expiryDate.split('-').reverse().join('-') : '—'}</td>
							<td>
								{#if item.photo}
									<img src={item.photo} alt="Product" class="table-photo" />
								{:else}
									—
								{/if}
							</td>
							<td>
								<button type="button" class="remove-btn" on:click={() => removeItem(i)}>&times;</button>
							</td>
						</tr>
					{/each}
				</tbody>
				</table>
			</div>
		</div>
	{/if}

	<!-- Add Item Modal -->
	{#if showModal}
		<div class="modal-overlay" on:click={closeModal} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeModal()}>
			<div class="modal-container" on:click|stopPropagation role="none">
				<div class="modal-header">
					<span>{t('Add Item', 'إضافة منتج')}</span>
					<button type="button" class="modal-close" on:click={closeModal}>&times;</button>
				</div>
				<div class="modal-body">
					<p class="modal-info">{t('⚠️ At least Barcode or Photo is required', '⚠️ يجب ملء حقل واحد على الأقل: الباركود أو الصورة')}</p>
					<!-- Barcode -->
					<div class="form-group">
						<label>{t('Barcode', 'الباركود')}</label>
						<div class="barcode-input-row">
							<input type="text" bind:value={modalBarcode} class="form-input" placeholder={t('Enter barcode...', 'أدخل الباركود...')} inputmode="numeric" />
							<button type="button" class="scan-btn" on:click={scanning ? stopScan : startScan} title={t('Scan barcode', 'مسح الباركود')}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/>
									<path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
									<line x1="7" y1="12" x2="17" y2="12"/>
								</svg>
							</button>
						</div>
					</div>
					<!-- Expiry Date -->
					<div class="form-group">
						<label>{t('Expiry Date', 'تاريخ الصلاحية')}</label>
						<div class="date-fields-row">
							<!-- Year field -->
							<button type="button" class="date-field" class:date-field-filled={selectedYear} on:click={() => { showYearPicker = true; }}>
								<span class="date-field-label">{t('Year', 'السنة')}</span>
								<span class="date-field-value">{selectedYear || '----'}</span>
							</button>
							<!-- Month field -->
							<button type="button" class="date-field" class:date-field-filled={selectedMonth} class:date-field-disabled={!selectedYear} on:click={() => { if (selectedYear) showMonthPicker = true; }}>
								<span class="date-field-label">{t('Month', 'الشهر')}</span>
								<span class="date-field-value">{selectedMonth ? ($currentLocale === 'ar' ? monthNames.ar[Number(selectedMonth) - 1] : monthNames.en[Number(selectedMonth) - 1]) : '--'}</span>
							</button>
							<!-- Day field -->
							<button type="button" class="date-field" class:date-field-filled={selectedDay} class:date-field-disabled={!selectedMonth} on:click={() => { if (selectedMonth) showDayPicker = true; }}>
								<span class="date-field-label">{t('Day', 'اليوم')}</span>
								<span class="date-field-value">{selectedDay ? String(selectedDay).padStart(2, '0') : '--'}</span>
							</button>
						</div>
						{#if modalExpiryDate}
							<div class="date-preview">📅 {modalExpiryDate}</div>
						{/if}
						<!-- OCR scan button -->
						<button type="button" class="ocr-date-btn" on:click={startTextScan} title={t('Scan expiry date with camera', 'مسح تاريخ الصلاحية بالكاميرا')}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M4 7V4h3"/><path d="M17 4h3v3"/><path d="M20 17v3h-3"/><path d="M7 20H4v-3"/>
								<line x1="7" y1="9" x2="17" y2="9"/><line x1="7" y1="12" x2="17" y2="12"/><line x1="7" y1="15" x2="13" y2="15"/>
							</svg>
							{t('Scan Date', 'مسح التاريخ')}
						</button>
					</div>
					<!-- Photo -->
					<div class="form-group">
						<label>{t('Photo', 'صورة')}</label>
						{#if modalPhoto}
							<div class="photo-preview">
								<img src={modalPhoto} alt="Preview" />
								<button type="button" class="photo-remove" on:click={removePhoto}>&times;</button>
							</div>
						{:else}
							<button type="button" class="photo-btn" on:click={() => fileInput?.click()}>
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<rect x="3" y="3" width="18" height="18" rx="2"/>
									<circle cx="8.5" cy="8.5" r="1.5"/>
									<polyline points="21 15 16 10 5 21"/>
								</svg>
								<span>{t('Choose Photo', 'اختر صورة')}</span>
							</button>
							<input bind:this={fileInput} type="file" accept="image/*" capture="environment" class="hidden-file-input" on:change={handlePhoto} />
						{/if}
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn-close-modal" on:click={closeModal}>{t('Close', 'إغلاق')}</button>
					<button type="button" class="btn-add" on:click={addItem} disabled={!modalBarcode || !selectedYear || !selectedMonth || !selectedDay || !modalPhoto}>{t('Add', 'إضافة')}</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Barcode Scanner overlay -->
	{#if scanning}
		<div class="scanner-overlay" on:click={stopScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopScan()}>
			<div class="scanner-container" on:click|stopPropagation role="none">
				<div class="scanner-header">
					<span>{t('Scan Barcode', 'مسح الباركود')}</span>
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

	<!-- Text Scanner (OCR) overlay for expiry date -->
	{#if textScanning}
		<div class="scanner-overlay" on:click={stopTextScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopTextScan()}>
			<div class="scanner-container text-scanner" on:click|stopPropagation role="none">
				<div class="scanner-header">
					<span>{t('📷 Scan Expiry Date', '📷 مسح تاريخ الصلاحية')}</span>
					<button type="button" class="scanner-close" on:click={stopTextScan}>&times;</button>
				</div>
				<div class="scanner-video-wrapper">
					<!-- svelte-ignore a11y-media-has-caption -->
					<video bind:this={textVideoEl} playsinline autoplay muted class="scanner-video"></video>
					{#if !textDetecting}
						<div class="ocr-guide-overlay">
							<div class="ocr-guide-box"></div>
						</div>
					{/if}
				</div>
				<div class="ocr-capture-bar">
					{#if textDetecting}
						<div class="ocr-detecting">
							<span class="spinner"></span>
							<span>{t('Detecting text...', 'جاري التعرف على النص...')}</span>
						</div>
					{:else}
						{#if ocrNoResult}
							<p class="ocr-error">{t('No text found. Try again.', 'لم يتم العثور على نص. حاول مرة أخرى.')}</p>
						{/if}
						<button type="button" class="ocr-capture-btn" on:click={captureAndDetect}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
								<circle cx="12" cy="12" r="10"/>
							</svg>
							<span>{t('Capture', 'التقاط')}</span>
						</button>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	<!-- Detected Text Results popup -->
	{#if showTextResults && detectedTexts.length > 0}
		<div class="modal-overlay" on:click={closeTextResults} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeTextResults()}>
			<div class="modal-container text-results-popup" on:click|stopPropagation role="none">
				<div class="modal-header">
					<span>{t('Select Expiry Date', 'اختر تاريخ الصلاحية')}</span>
					<button type="button" class="modal-close" on:click={closeTextResults}>&times;</button>
				</div>
				<div class="modal-body text-results-body">
					<p class="text-results-hint">{t('Tap the desired text:', 'اضغط على النص المطلوب:')}</p>
					<div class="text-results-list">
						{#each detectedTexts as text, i}
							<button type="button" class="text-result-item" on:click={() => selectDetectedText(text)}>
								<span class="text-result-num">{i + 1}</span>
								<span class="text-result-value">{text}</span>
							</button>
						{/each}
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn-close-modal" on:click={closeTextResults}>{t('Cancel', 'إلغاء')}</button>
					<button type="button" class="btn-add" on:click={startTextScan}>{t('Rescan', 'إعادة المسح')}</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Year Picker Popup -->
	{#if showYearPicker}
		<div class="modal-overlay" on:click={() => showYearPicker = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showYearPicker = false)}>
			<div class="picker-popup" on:click|stopPropagation role="none">
				<div class="picker-header">
					<span>{t('Select Year', 'اختر السنة')}</span>
					<button type="button" class="modal-close" on:click={() => showYearPicker = false}>&times;</button>
				</div>
				<div class="picker-scroll-list">
					{#each yearOptions as year}
						<button type="button" class="picker-scroll-item" class:picker-scroll-item-active={selectedYear === String(year)} on:click={() => { selectedYear = String(year); selectedMonth = ''; selectedDay = ''; modalExpiryDate = ''; showYearPicker = false; }}>
							{year}
						</button>
					{/each}
				</div>
			</div>
		</div>
	{/if}

	<!-- Month Picker Popup -->
	{#if showMonthPicker}
		<div class="modal-overlay" on:click={() => showMonthPicker = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showMonthPicker = false)}>
			<div class="picker-popup" on:click|stopPropagation role="none">
				<div class="picker-header">
					<span>{t('Select Month', 'اختر الشهر')}</span>
					<button type="button" class="modal-close" on:click={() => showMonthPicker = false}>&times;</button>
				</div>
				<div class="picker-scroll-list">
					{#each monthOptions as month}
						<button type="button" class="picker-scroll-item" class:picker-scroll-item-active={selectedMonth === String(month)} on:click={() => { selectedMonth = String(month); selectedDay = ''; modalExpiryDate = ''; showMonthPicker = false; }}>
							{month} - {$currentLocale === 'ar' ? monthNames.ar[month - 1] : monthNames.en[month - 1]}
						</button>
					{/each}
				</div>
			</div>
		</div>
	{/if}

	<!-- Day Picker Popup -->
	{#if showDayPicker}
		<div class="modal-overlay" on:click={() => showDayPicker = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showDayPicker = false)}>
			<div class="picker-popup" on:click|stopPropagation role="none">
				<div class="picker-header">
					<span>{t('Select Day', 'اختر اليوم')}</span>
					<button type="button" class="modal-close" on:click={() => showDayPicker = false}>&times;</button>
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

	<!-- Title Popup (shown before first item) -->
	{#if showTitlePopup}
		<div class="modal-overlay" on:click={() => showTitlePopup = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showTitlePopup = false)}>
			<div class="modal-container" on:click|stopPropagation role="none">
				<div class="modal-header">
					<span>{t('Report Title', 'عنوان التقرير')}</span>
					<button type="button" class="modal-close" on:click={() => showTitlePopup = false}>&times;</button>
				</div>
				<div class="modal-body" style="padding: 1rem;">
					<div class="form-group">
						<label style="font-weight: 600; margin-bottom: 0.3rem; display: block;">{t('Title', 'العنوان')}</label>
						<input type="text" class="form-input" bind:value={reportTitle} placeholder={t('Enter report title...', 'أدخل عنوان التقرير...')} style="font-size: 1rem; padding: 0.75rem;" />
					</div>
				</div>
				<div class="modal-footer">
					<button type="button" class="btn-close-modal" on:click={() => showTitlePopup = false}>{t('Cancel', 'إلغاء')}</button>
					<button type="button" class="btn-add" on:click={confirmTitle} disabled={!reportTitle.trim()}>{t('Continue', 'متابعة')}</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Save & Send Popup -->
	{#if showSavePopup}
		<div class="modal-overlay" on:click={closeSavePopup} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeSavePopup()}>
			<div class="modal-container save-popup" on:click|stopPropagation role="none">
				<div class="modal-header">
					<span>{t('Send Near Expiry Report', 'إرسال تقرير قرب الانتهاء')}</span>
					<button type="button" class="modal-close" on:click={closeSavePopup}>&times;</button>
				</div>
				<div class="modal-body">
					<!-- Branch Selection -->
					<div class="form-group">
						<label>{t('Select Branch', 'اختر الفرع')}</label>
						{#if loadingBranches}
							<div class="loading-text">{t('Loading...', 'جاري التحميل...')}</div>
						{:else}
							<select class="form-input" bind:value={selectedBranchId} on:change={onBranchSelected}>
								<option value={null}>{t('Choose branch...', 'اختر الفرع...')}</option>
								{#each branches as branch}
									<option value={branch.id}>{$currentLocale === 'ar' ? branch.name_ar : branch.name_en} - {$currentLocale === 'ar' ? branch.location_ar : branch.location_en}</option>
								{/each}
							</select>
						{/if}
					</div>

					<!-- Auto-selected manager -->
					{#if selectedUserId}
						<div class="auto-info">
							<span class="auto-label">{t('Manager:', 'المدير:')}</span>
							<span class="auto-value">{selectedUserName}</span>
						</div>
					{/if}

					<!-- No default position warning -->
					{#if noDefaultPosition && selectedBranchId}
						<div class="warning-info">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
								<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
							</svg>
							<span>{t('No branch manager assigned', 'لم يتم تعيين مدير للفرع')}</span>
						</div>
					{/if}

					<!-- Send + Add More buttons -->
					{#if selectedBranchId && selectedUserId}
						{#if sendSuccess}
							<div class="success-info">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
									<polyline points="20 6 9 17 4 12"/>
								</svg>
								<span>{t('Sent successfully!', 'تم الإرسال بنجاح!')}</span>
							</div>
						{:else}
							{#if sendError}
								<div class="error-info">
									<span>{sendError}</span>
								</div>
							{/if}
							<div class="save-actions">
								<button type="button" class="btn-send" on:click={handleSend} disabled={sending}>
									{#if sending}
										<span class="spinner"></span>
									{:else}
										<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
										</svg>
									{/if}
									{t('Send', 'إرسال')}
								</button>
								<button type="button" class="btn-add-more" on:click={addMoreFromSave} disabled={sending}>
									<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
										<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
									</svg>
								</button>
							</div>
						{/if}
					{/if}
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.near-expiry-page {
		padding: 0;
		padding-bottom: 4.5rem;
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		height: 100vh;
		overflow: hidden;
	}

	.fixed-bottom-bar {
		position: fixed;
		bottom: 3.6rem;
		left: 0;
		right: 0;
		display: flex;
		justify-content: center;
		padding: 0.5rem 1rem;
		background: transparent;
		z-index: 999;
	}

	.table-wrapper {
		background: white;
		border-radius: 8px;
		overflow: hidden;
		margin: 0 0.5rem 0.5rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
		display: flex;
		flex-direction: column;
		flex: 1;
		min-height: 0;
	}

	.items-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.75rem;
	}

	.items-table thead {
		position: sticky;
		top: 0;
		z-index: 2;
	}

	.items-table th {
		background: #F3F4F6;
		color: #374151;
		font-weight: 700;
		padding: 0.4rem 0.35rem;
		text-align: start;
		white-space: nowrap;
		border-bottom: 1px solid #E5E7EB;
	}

	.table-scroll {
		flex: 1;
		overflow-y: auto;
		min-height: 0;
		-webkit-overflow-scrolling: touch;
	}

	.items-table td {
		padding: 0.35rem;
		border-bottom: 1px solid #F3F4F6;
		vertical-align: middle;
		color: #111827;
	}

	.items-table tbody tr:last-child td {
		border-bottom: none;
	}

	.table-photo {
		width: 2rem;
		height: 2rem;
		object-fit: cover;
		border-radius: 3px;
		border: 1px solid #E5E7EB;
		display: block;
	}

	.remove-btn {
		background: none;
		border: none;
		color: #EF4444;
		font-size: 1rem;
		cursor: pointer;
		line-height: 1;
		padding: 0.1rem 0.2rem;
		border-radius: 4px;
	}

	.remove-btn:active {
		background: #FEE2E2;
	}

	.top-actions {
		display: flex;
		gap: 0.5rem;
		padding: 0.5rem;
		background: #F8FAFC;
		flex-shrink: 0;
	}

	.report-title-bar {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.4rem 0.75rem;
		background: #FEF3C7;
		border-bottom: 1px solid #FDE68A;
		flex-shrink: 0;
	}

	.report-title-label {
		font-size: 0.9rem;
	}

	.report-title-text {
		font-size: 0.85rem;
		font-weight: 700;
		color: #92400E;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.add-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #DC2626;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
		font-size: 0.85rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.add-btn:active {
		background: #B91C1C;
	}

	.save-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem 2rem;
		background: #DC2626;
		color: white;
		border: none;
		border-radius: 10px;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(220, 38, 38, 0.3);
		font-size: 0.95rem;
		font-weight: 600;
		white-space: nowrap;
		min-width: 200px;
		animation: heartbeat 2.5s ease-in-out infinite;
	}

	@keyframes heartbeat {
		0% { transform: scale(1); }
		14% { transform: scale(1.03); }
		28% { transform: scale(1); }
		42% { transform: scale(1.03); }
		56% { transform: scale(1); }
		100% { transform: scale(1); }
	}

	.save-btn:active {
		background: #B91C1C;
		animation: none;
	}

	/* Modal */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.modal-container {
		background: white;
		border-radius: 12px;
		width: 100%;
		max-width: 360px;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.65rem 0.85rem;
		border-bottom: 1px solid #E5E7EB;
		font-weight: 700;
		font-size: 0.9rem;
		color: #111827;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 1.3rem;
		cursor: pointer;
		color: #6B7280;
		line-height: 1;
		padding: 0 0.2rem;
	}

	.modal-body {
		padding: 0.75rem 0.85rem;
	}

	.modal-info {
		font-size: 0.75rem;
		color: #B45309;
		background: #FEF3C7;
		border: 1px solid #FDE68A;
		border-radius: 6px;
		padding: 0.5rem 0.65rem;
		margin-bottom: 0.6rem;
		text-align: center;
		font-weight: 500;
	}

	.modal-footer {
		display: flex;
		gap: 0.5rem;
		padding: 0.65rem 0.85rem;
		border-top: 1px solid #E5E7EB;
	}

	.btn-close-modal {
		flex: 1;
		padding: 0.45rem;
		background: #F3F4F6;
		color: #374151;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-close-modal:active {
		background: #E5E7EB;
	}

	.btn-add {
		flex: 1;
		padding: 0.45rem;
		background: #DC2626;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-add:active {
		background: #B91C1C;
	}

	.btn-add:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.form-group {
		margin-bottom: 0.6rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.15rem;
		font-weight: 600;
		color: #374151;
		font-size: 0.75rem;
	}

	.form-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.375rem;
		font-size: 0.8rem;
		box-sizing: border-box;
		height: 2rem;
	}

	.form-input:focus {
		outline: none;
		border-color: #DC2626;
		box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
	}

	.barcode-input-row {
		display: flex;
		gap: 0.35rem;
		align-items: stretch;
	}

	.barcode-input-row .form-input {
		flex: 1;
	}

	/* Date field row & popup picker */
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

	/* Picker popup */
	.picker-popup {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		background: white;
		border-radius: 1rem 1rem 0 0;
		box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.2);
		z-index: 10002;
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

	.picker-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.4rem;
		padding: 0.75rem;
		max-height: 50vh;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.picker-grid.months {
		grid-template-columns: repeat(3, 1fr);
	}

	.picker-grid.days {
		grid-template-columns: repeat(7, 1fr);
	}

	.picker-btn {
		padding: 0.7rem 0.3rem;
		border: 1px solid #E5E7EB;
		border-radius: 0.5rem;
		background: #F9FAFB;
		color: #1F2937;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		text-align: center;
		-webkit-tap-highlight-color: transparent;
		touch-action: manipulation;
		transition: all 0.15s;
	}

	.picker-btn:active {
		transform: scale(0.93);
		background: #FEE2E2;
	}

	.picker-btn-active {
		background: #DC2626;
		color: white;
		border-color: #DC2626;
		box-shadow: 0 2px 6px rgba(220, 38, 38, 0.35);
	}

	/* Scrollable single-column year list */
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

	.ocr-date-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		margin-top: 0.35rem;
		width: 100%;
		padding: 0.4rem;
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 600;
		cursor: pointer;
	}

	.ocr-date-btn:active {
		background: #DC2626;
	}

	.scan-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 0.5rem;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		flex-shrink: 0;
		height: 2rem;
	}

	.scan-btn:active {
		background: #0056b3;
	}

	.text-scan-btn {
		background: #F59E0B !important;
	}

	.text-scan-btn:active {
		background: #D97706 !important;
	}

	.hidden-file-input {
		display: none;
	}

	.photo-btn {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		width: 100%;
		padding: 0.4rem 0.5rem;
		background: #F3F4F6;
		color: #374151;
		border: 1px dashed #D1D5DB;
		border-radius: 0.375rem;
		font-size: 0.78rem;
		cursor: pointer;
		height: 2rem;
		box-sizing: border-box;
	}

	.photo-btn:active {
		background: #E5E7EB;
	}

	.photo-preview {
		position: relative;
		display: inline-block;
		margin-top: 0.25rem;
	}

	.photo-preview img {
		width: 4rem;
		height: 4rem;
		object-fit: cover;
		border-radius: 6px;
		border: 1px solid #D1D5DB;
	}

	.photo-remove {
		position: absolute;
		top: -0.3rem;
		right: -0.3rem;
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 1.2rem;
		height: 1.2rem;
		font-size: 0.8rem;
		line-height: 1;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
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

	/* OCR scanner additions */
	.text-scanner {
		max-width: 400px;
	}

	.ocr-guide-overlay {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		pointer-events: none;
	}

	.ocr-guide-box {
		width: 80%;
		height: 30%;
		border: 2px dashed rgba(255, 255, 255, 0.7);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.05);
	}

	.ocr-capture-bar {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #1a1a1a;
	}

	.ocr-capture-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.6rem 1.5rem;
		background: #F59E0B;
		color: white;
		border: none;
		border-radius: 25px;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
	}

	.ocr-capture-btn:active {
		background: #D97706;
		transform: scale(0.97);
	}

	.ocr-detecting {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #F59E0B;
		font-size: 0.85rem;
		font-weight: 600;
	}

	.ocr-error {
		color: #EF4444;
		font-size: 0.78rem;
		font-weight: 600;
		margin: 0;
	}

	/* Text results popup */
	.text-results-popup {
		max-width: 380px;
	}

	.text-results-body {
		max-height: 50vh;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.text-results-hint {
		font-size: 0.75rem;
		color: #6B7280;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}

	.text-results-list {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.text-result-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		width: 100%;
		padding: 0.55rem 0.65rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		font-size: 0.82rem;
		color: #111827;
		cursor: pointer;
		text-align: start;
		transition: all 0.1s;
	}

	.text-result-item:active {
		background: #FEF3C7;
		border-color: #F59E0B;
	}

	.text-result-num {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 1.4rem;
		height: 1.4rem;
		background: #F59E0B;
		color: white;
		border-radius: 50%;
		font-size: 0.65rem;
		font-weight: 700;
		flex-shrink: 0;
	}

	.text-result-value {
		flex: 1;
		word-break: break-word;
		line-height: 1.3;
	}

	/* Save popup */
	.save-popup {
		max-width: 380px;
	}

	.auto-info {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.4rem 0.5rem;
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		border-radius: 6px;
		margin-bottom: 0.6rem;
		font-size: 0.78rem;
	}

	.auto-label {
		color: #374151;
		font-weight: 600;
	}

	.auto-value {
		color: #059669;
		font-weight: 600;
	}

	.warning-info {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.4rem 0.5rem;
		background: #FEF3C7;
		border: 1px solid #FCD34D;
		border-radius: 6px;
		margin-bottom: 0.6rem;
		font-size: 0.78rem;
		color: #92400E;
		font-weight: 600;
	}

	.loading-text {
		padding: 0.4rem;
		color: #6B7280;
		font-size: 0.78rem;
		font-style: italic;
	}

	.save-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.75rem;
	}

	.btn-send {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.35rem;
		padding: 0.55rem;
		background: #DC2626;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-send:active {
		background: #B91C1C;
	}

	.btn-add-more {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.55rem 0.75rem;
		background: #DC2626;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
	}

	.btn-add-more:active {
		background: #B91C1C;
	}

	.btn-send:disabled, .btn-add-more:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.success-info {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.5rem;
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		border-radius: 6px;
		margin-top: 0.5rem;
		font-size: 0.85rem;
		color: #059669;
		font-weight: 600;
	}

	.error-info {
		padding: 0.4rem 0.5rem;
		background: #FEF2F2;
		border: 1px solid #FECACA;
		border-radius: 6px;
		margin-bottom: 0.5rem;
		font-size: 0.75rem;
		color: #DC2626;
		font-weight: 600;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
