<script lang="ts">
	import { compressImage } from '$lib/utils/imageCompression';
	import { getTranslation } from '$lib/i18n';
	import { currentLocale } from '$lib/i18n';
	import { onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface ProductItem {
		barcode: string;
		productName: string;
		quantity: number;
		photo: string | null;
	}

	interface BranchOption {
		id: number;
		name_en: string;
		name_ar: string;
		location_en: string;
		location_ar: string;
	}

	interface UserOption {
		id: string;
		username: string;
		name_en?: string;
		name_ar?: string;
	}

	type RequestType = 'BT' | 'ST' | 'PO' | null;

	let items: ProductItem[] = [];
	let showModal = false;
	let modalBarcode = '';
	let modalProductName = '';
	let modalQuantity = 1;
	let modalPhoto: string | null = null;
	let fileInput: HTMLInputElement;

	let scanning = false;
	let videoEl: HTMLVideoElement;
	let stream: MediaStream | null = null;
	let scanInterval: ReturnType<typeof setInterval> | null = null;

	// Save popup state
	let showSavePopup = false;
	let requestType: RequestType = null;
	let branches: BranchOption[] = [];
	let selectedBranchId: number | null = null;
	let selectedUserId: string | null = null;
	let selectedUserName: string = '';
	let branchUsers: UserOption[] = [];
	let loadingBranches = false;
	let loadingUsers = false;
	let noDefaultPosition = false;
	let sending = false;
	let sendSuccess = false;
	let sendError = '';

	// Text recognition (OCR) state
	let textScanning = false;
	let textVideoEl: HTMLVideoElement;
	let textStream: MediaStream | null = null;
	let detectedTexts: string[] = [];
	let showTextResults = false;
	let textDetecting = false;
	let ocrNoResult = false;

	function openSavePopup() {
		selectedBranchId = null;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		showSavePopup = true;
		// Load data based on already-selected type
		if (requestType) selectRequestType(requestType);
	}

	function closeSavePopup() {
		showSavePopup = false;
		requestType = null;
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
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			loadingBranches = false;
		}
	}

	async function loadBranchManager(branchId: number) {
		noDefaultPosition = false;
		try {
			const { data, error } = await supabase
				.from('branch_default_positions')
				.select('branch_manager_user_id')
				.eq('branch_id', branchId)
				.single();
			if (error) {
				// No row found = no default position assigned
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
				return;
			}
			if (data?.branch_manager_user_id) {
				selectedUserId = data.branch_manager_user_id;
				const { data: userData, error: userError } = await supabase
					.from('users')
					.select('username')
					.eq('id', data.branch_manager_user_id)
					.single();
				if (!userError && userData) {
					selectedUserName = userData.username;
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

	const PURCHASING_MANAGER_POSITION_ID = '540c129e-79b4-4100-b645-086ef2485449';

	async function loadPurchasingManagers() {
		loadingUsers = true;
		try {
			// Get all employees with Purchasing Manager position
			const { data: employees, error: empError } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar')
				.eq('current_position_id', PURCHASING_MANAGER_POSITION_ID);
			if (empError) throw empError;
			if (!employees || employees.length === 0) {
				branchUsers = [];
				return;
			}
			// Get usernames for those user_ids
			const userIds = employees.map(e => e.user_id);
			const { data: users, error: userError } = await supabase
				.from('users')
				.select('id, username')
				.in('id', userIds)
				.eq('status', 'active')
				.order('username', { ascending: true });
			if (userError) throw userError;
			branchUsers = (users || []).map(u => {
				const emp = employees.find(e => e.user_id === u.id);
				return { id: u.id, username: u.username, name_en: emp?.name_en || '', name_ar: emp?.name_ar || '' };
			});
			// Auto-select if only one purchasing manager
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

	async function selectRequestType(type: RequestType) {
		requestType = type;
		selectedBranchId = null;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		noDefaultPosition = false;

		if (type === 'BT') {
			await loadBranches();
		} else if (type === 'ST') {
			// Load branches and pre-select user's branch
			await loadBranches();
			const userBranchId = $currentUser?.branch_id;
			if (userBranchId) {
				selectedBranchId = Number(userBranchId);
				await loadBranchManager(selectedBranchId);
			}
		} else if (type === 'PO') {
			await loadPurchasingManagers();
		}
	}

	async function onBranchSelected() {
		if (!selectedBranchId) return;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];

		if (requestType === 'BT') {
			await loadBranchManager(selectedBranchId);
		} else if (requestType === 'ST') {
			await loadBranchManager(selectedBranchId);
		}
	}

	function onUserSelected() {
		const user = branchUsers.find(u => u.id === selectedUserId);
		selectedUserName = user ? (user.name_en || user.username) : '';
	}

	async function uploadPhoto(photo: string, index: number): Promise<string | null> {
		try {
			// Convert base64 data URL to Blob
			const res = await fetch(photo);
			const blob = await res.blob();
			const ext = blob.type.split('/')[1] || 'jpg';
			const fileName = `pr-${requestType}-${Date.now()}-${index}.${ext}`;

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
		if (!requestType || !selectedUserId || !$currentUser?.id) return;
		sending = true;
		sendError = '';
		sendSuccess = false;

		try {
			// Upload photos to storage and build items data
			const itemsData = await Promise.all(items.map(async (item, i) => {
				let photoUrl: string | null = null;
				if (item.photo) {
					photoUrl = await uploadPhoto(item.photo, i);
				}
				return {
					barcode: item.barcode,
					product_name: item.productName,
					quantity: item.quantity,
					photo_url: photoUrl
				};
			}));

			let error;
			let requestId: string | null = null;

			if (requestType === 'BT') {
				const fromBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
				const result = await supabase
					.from('product_request_bt')
					.insert({
						requester_user_id: $currentUser.id,
						from_branch_id: fromBranchId,
						to_branch_id: selectedBranchId,
						target_user_id: selectedUserId,
						status: 'pending',
						items: itemsData
					})
					.select('id')
					.single();
				error = result.error;
				requestId = result.data?.id || null;

			} else if (requestType === 'ST') {
				const result = await supabase
					.from('product_request_st')
					.insert({
						requester_user_id: $currentUser.id,
						branch_id: selectedBranchId,
						target_user_id: selectedUserId,
						status: 'pending',
						items: itemsData
					})
					.select('id')
					.single();
				error = result.error;
				requestId = result.data?.id || null;

			} else if (requestType === 'PO') {
				const fromBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
				const result = await supabase
					.from('product_request_po')
					.insert({
						requester_user_id: $currentUser.id,
						from_branch_id: fromBranchId,
						target_user_id: selectedUserId,
						status: 'pending',
						items: itemsData
					})
					.select('id')
					.single();
				error = result.error;
				requestId = result.data?.id || null;
			}

			if (error) throw error;

			// Create Quick Tasks for requester (follow up) and receiver (process)
			if (requestId && requestType && selectedUserId) {
				try {
					const requesterName = $currentUser?.username || 'User';
					const receiverName = selectedUserName || 'Receiver';
					const branchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
					const typeLabel = requestType === 'BT' ? 'Branch Transfer' : requestType === 'ST' ? 'Stock Request' : 'Purchase Order';
					const typeLabelAr = requestType === 'BT' ? 'نقل فرعي' : requestType === 'ST' ? 'طلب مخزون' : 'أمر شراء';

					// Task for requester: follow up
					const { data: requesterTask } = await supabase
						.from('quick_tasks')
						.insert({
							title: `Follow up ${requestType} Request | متابعة طلب ${requestType}`,
							description: `${typeLabel} request sent to ${receiverName}. Follow up until processed.\n---\nطلب ${typeLabelAr} مرسل إلى ${receiverName}. تابع حتى تتم المعالجة.`,
							priority: 'medium',
							issue_type: 'product_request_follow_up',
							assigned_by: $currentUser.id,
							assigned_to_branch_id: branchId,
							product_request_id: requestId,
							product_request_type: requestType
						})
						.select('id')
						.single();

					if (requesterTask) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: requesterTask.id,
							assigned_to_user_id: $currentUser.id,
							require_task_finished: true
						});
					}

					// Task for receiver: process request
					const { data: receiverTask } = await supabase
						.from('quick_tasks')
						.insert({
							title: `Process ${requestType} Request | معالجة طلب ${requestType}`,
							description: `${typeLabel} request from ${requesterName}. Review and accept or reject.\n---\nطلب ${typeLabelAr} من ${requesterName}. راجع واقبل أو ارفض.`,
							priority: 'high',
							issue_type: 'product_request_process',
							assigned_by: $currentUser.id,
							assigned_to_branch_id: selectedBranchId,
							product_request_id: requestId,
							product_request_type: requestType
						})
						.select('id')
						.single();

					if (receiverTask) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: receiverTask.id,
							assigned_to_user_id: selectedUserId,
							require_task_finished: true
						});
					}

					console.log('✅ Quick tasks created for product request:', requestId);
				} catch (taskErr) {
					console.warn('⚠️ Failed to create quick tasks:', taskErr);
				}
			}

			sendSuccess = true;
			// Reset everything after successful send
			setTimeout(() => {
				items = [];
				closeSavePopup();
				sendSuccess = false;
			}, 1500);
		} catch (err: any) {
			console.error('Error sending request:', err);
			sendError = err?.message || 'Failed to send request';
		} finally {
			sending = false;
		}
	}

	function addMoreFromSave() {
		closeSavePopup();
		openModal();
	}

	function openModal() {
		modalBarcode = '';
		modalProductName = '';
		modalQuantity = 1;
		modalPhoto = null;
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		stopScan();
	}

	function addItem() {
		const photo = requestType === 'PO' ? modalPhoto : null;
		items = [...items, { barcode: modalBarcode, productName: modalProductName, quantity: modalQuantity, photo }];
		closeModal();
	}

	function removeItem(index: number) {
		items = items.filter((_, i) => i !== index);
	}

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
						lookupProductName(modalBarcode);
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

	// Lookup product name from erp_synced_products by barcode
	let lookingUpProduct = false;
	async function lookupProductName(barcode: string) {
		if (!barcode || barcode.trim().length < 3) return;
		lookingUpProduct = true;
		try {
			const { data, error } = await supabase
				.from('erp_synced_products')
				.select('product_name_en, product_name_ar')
				.eq('barcode', barcode.trim())
				.limit(1)
				.maybeSingle();
			if (!error && data) {
				const name = $currentLocale === 'ar' && data.product_name_ar
					? data.product_name_ar
					: data.product_name_en || data.product_name_ar || '';
				if (name) modalProductName = name;
			}
		} catch (_) {}
		lookingUpProduct = false;
	}

	async function handlePhoto(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (file) {
			try {
				modalPhoto = await compressImage(file);
			} catch {
				// Fallback to uncompressed
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

	// --- Text recognition (OCR) for product name ---
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
		modalProductName = text;
		showTextResults = false;
		detectedTexts = [];
	}

	function closeTextResults() {
		showTextResults = false;
		detectedTexts = [];
	}

	onDestroy(() => { stopScan(); stopTextScan(); });
</script>

<div class="product-request-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Type Selection (shown first before anything) -->
	{#if !requestType}
		<div class="type-selection-screen">
			<div class="type-selection-card">
				<h2 class="type-selection-title">{$currentLocale === 'ar' ? 'اختر نوع الطلب' : 'Select Request Type'}</h2>
				<div class="request-type-row">
					<button type="button" class="type-btn" on:click={() => selectRequestType('BT')}>BT</button>
					<button type="button" class="type-btn" on:click={() => selectRequestType('ST')}>ST</button>
					<button type="button" class="type-btn" on:click={() => selectRequestType('PO')}>PO</button>
				</div>
				<div class="type-labels-row">
					<span class="type-label">{getTranslation('mobile.productRequestContent.branchTransfer')}</span>
					<span class="type-label">{getTranslation('mobile.productRequestContent.inBranch')}</span>
					<span class="type-label">{getTranslation('mobile.productRequestContent.purchaseOrder')}</span>
				</div>
				<div class="type-info-box">
					<p><strong>BT</strong> – {$currentLocale === 'ar' ? 'طلب نقل بين الفروع فقط' : 'Branch Transfer requests only'}</p>
					<p><strong>ST</strong> – {$currentLocale === 'ar' ? 'طلب نقص في المعرض - يُرسل إلى مستودع المتجر' : 'Shortage in showroom - request to shop warehouse'}</p>
					<p><strong>PO</strong> – {$currentLocale === 'ar' ? 'طلب شراء لاحتياجات العملاء وطلبات أخرى من مسؤولي الفرع' : 'Customer needs & other orders from branch officials'}</p>
				</div>
			</div>
		</div>
	{:else}
	<!-- Top buttons (shown after type is selected) -->
	<div class="top-actions">
		<div class="type-badge-row">
			<span class="type-badge">{requestType}</span>
			<button type="button" class="change-type-btn" on:click={() => { requestType = null; items = []; }}>
				{$currentLocale === 'ar' ? 'تغيير' : 'Change'}
			</button>
		</div>
		<button type="button" class="add-btn" on:click={openModal}>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
			</svg>
			<span>{$currentLocale === 'ar' ? 'إضافة منتجات' : 'Add Products'}</span>
		</button>
	</div>

	<!-- Fixed bottom Save & Send button -->
	{#if items.length > 0}
		<div class="fixed-bottom-bar">
			<button type="button" class="save-btn" on:click={openSavePopup}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/>
					<polyline points="17 21 17 13 7 13 7 21"/>
					<polyline points="7 3 7 8 15 8"/>
				</svg>
				<span>{$currentLocale === 'ar' ? 'حفظ وإرسال' : 'Save & Send'}</span>
			</button>
		</div>
	{/if}

	<!-- Items table -->
	{#if items.length > 0}
		<div class="table-wrapper">
			<table class="items-table">
				<thead>
					<tr>
						<th>BRC</th>
						<th>Name</th>
						<th>Qty</th>
						<th>Img</th>
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
							<td>{item.productName || '—'}</td>
							<td>{item.quantity}</td>
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
					<span>{getTranslation('mobile.productRequestContent.addItem')} ({requestType})</span>
					<button type="button" class="modal-close" on:click={closeModal}>&times;</button>
				</div>
				<div class="modal-body">
					<p class="modal-info">{requestType === 'PO' ? ($currentLocale === 'ar' ? '⚠️ يجب ملء حقل واحد على الأقل: الباركود أو اسم المنتج أو الصورة' : '⚠️ At least one is mandatory: Photo, Barcode, or Product Name') : ($currentLocale === 'ar' ? '⚠️ يجب ملء حقل واحد على الأقل: الباركود أو اسم المنتج' : '⚠️ At least one is mandatory: Barcode or Product Name')}</p>
					<div class="form-group">
						<label>{getTranslation('mobile.productRequestContent.barcode')}</label>
						<div class="barcode-input-row">
							<input type="text" bind:value={modalBarcode} class="form-input" placeholder={getTranslation('mobile.productRequestContent.barcodePlaceholder')} inputmode="numeric" on:change={() => lookupProductName(modalBarcode)} />
							{#if lookingUpProduct}<span class="barcode-lookup-spinner">⏳</span>{/if}
							<button type="button" class="scan-btn" on:click={scanning ? stopScan : startScan} title={getTranslation('mobile.productRequestContent.scan')}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/>
									<path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
									<line x1="7" y1="12" x2="17" y2="12"/>
								</svg>
							</button>
						</div>
					</div>
					<div class="form-group">
						<label>{getTranslation('mobile.productRequestContent.productName')}</label>
						<div class="barcode-input-row">
							<input type="text" bind:value={modalProductName} class="form-input" placeholder={getTranslation('mobile.productRequestContent.productNamePlaceholder')} />
							<button type="button" class="scan-btn text-scan-btn" on:click={startTextScan} title={$currentLocale === 'ar' ? 'مسح اسم المنتج بالكاميرا' : 'Scan product name'}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M4 7V4h3"/><path d="M17 4h3v3"/><path d="M20 17v3h-3"/><path d="M7 20H4v-3"/>
									<line x1="7" y1="9" x2="17" y2="9"/><line x1="7" y1="12" x2="17" y2="12"/><line x1="7" y1="15" x2="13" y2="15"/>
								</svg>
							</button>
						</div>
					</div>
					<div class="form-group">
						<label>{getTranslation('mobile.productRequestContent.quantity')}</label>
						<input type="number" bind:value={modalQuantity} class="form-input" min="1" placeholder="1" />
					</div>
					{#if requestType === 'PO'}
					<div class="form-group">
						<label>{getTranslation('mobile.productRequestContent.photo')}</label>
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
								<span>{getTranslation('mobile.productRequestContent.choosePhoto')}</span>
							</button>
							<input bind:this={fileInput} type="file" accept="image/*" capture="environment" class="hidden-file-input" on:change={handlePhoto} />
						{/if}
					</div>
					{/if}
				</div>
				<div class="modal-footer">
					<button type="button" class="btn-close-modal" on:click={closeModal}>{getTranslation('mobile.productRequestContent.close')}</button>
					<button type="button" class="btn-add" on:click={addItem} disabled={!modalBarcode && !modalProductName && (requestType === 'PO' ? !modalPhoto : false)}>{getTranslation('mobile.productRequestContent.add')}</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Scanner overlay -->
	{#if scanning}
		<div class="scanner-overlay" on:click={stopScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopScan()}>
			<div class="scanner-container" on:click|stopPropagation role="none">
				<div class="scanner-header">
					<span>{getTranslation('mobile.productRequestContent.scanTitle')}</span>
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

	<!-- Text Scanner (OCR) overlay -->
	{#if textScanning}
		<div class="scanner-overlay" on:click={stopTextScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopTextScan()}>
			<div class="scanner-container text-scanner" on:click|stopPropagation role="none">
				<div class="scanner-header">
					<span>{$currentLocale === 'ar' ? '📷 مسح اسم المنتج' : '📷 Scan Product Name'}</span>
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
							<span>{$currentLocale === 'ar' ? 'جاري التعرف على النص...' : 'Detecting text...'}</span>
						</div>
					{:else}
						{#if ocrNoResult}
							<p class="ocr-error">{$currentLocale === 'ar' ? 'لم يتم العثور على نص. حاول مرة أخرى.' : 'No text found. Try again.'}</p>
						{/if}
						<button type="button" class="ocr-capture-btn" on:click={captureAndDetect}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
								<circle cx="12" cy="12" r="10"/>
							</svg>
							<span>{$currentLocale === 'ar' ? 'التقاط' : 'Capture'}</span>
						</button>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	<!-- Detected Text Results -->
	{#if showTextResults && detectedTexts.length > 0}
		<div class="modal-overlay" on:click={closeTextResults} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeTextResults()}>
			<div class="modal-container text-results-popup" on:click|stopPropagation role="none">
				<div class="modal-header">
					<span>{$currentLocale === 'ar' ? 'اختر اسم المنتج' : 'Select Product Name'}</span>
					<button type="button" class="modal-close" on:click={closeTextResults}>&times;</button>
				</div>
				<div class="modal-body text-results-body">
					<p class="text-results-hint">{$currentLocale === 'ar' ? 'اضغط على النص المطلوب:' : 'Tap the desired text:'}</p>
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
					<button type="button" class="btn-close-modal" on:click={closeTextResults}>{$currentLocale === 'ar' ? 'إلغاء' : 'Cancel'}</button>
					<button type="button" class="btn-add" on:click={startTextScan}>{$currentLocale === 'ar' ? 'إعادة المسح' : 'Rescan'}</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Save Popup -->
	{#if showSavePopup}
		<div class="modal-overlay" on:click={closeSavePopup} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && closeSavePopup()}>
			<div class="modal-container save-popup" on:click|stopPropagation role="none">
				<div class="modal-header">
					<span>{getTranslation('mobile.productRequestContent.saveRequest')} ({requestType})</span>
					<button type="button" class="modal-close" on:click={closeSavePopup}>&times;</button>
				</div>
				<div class="modal-body">
					{#if requestType}
<!-- Branch Selection (BT & ST) -->
					{#if requestType === 'BT' || requestType === 'ST'}
						<div class="form-group">
							<label>{getTranslation('mobile.productRequestContent.selectBranch')}</label>
							{#if loadingBranches}
								<div class="loading-text">{getTranslation('mobile.productRequestContent.loading')}</div>
							{:else}
								<select class="form-input" bind:value={selectedBranchId} on:change={onBranchSelected}>
									<option value={null}>{getTranslation('mobile.productRequestContent.chooseBranch')}</option>
									{#each branches as branch}
										<option value={branch.id}>{$currentLocale === 'ar' ? branch.name_ar : branch.name_en} - {$currentLocale === 'ar' ? branch.location_ar : branch.location_en}</option>
									{/each}
								</select>
							{/if}
						</div>
					{/if}

<!-- Purchasing Manager for PO (dropdown, all branches) -->
					{#if requestType === 'PO'}
						<div class="form-group">
							<label>{getTranslation('mobile.productRequestContent.selectUser')}</label>
							{#if loadingUsers}
								<div class="loading-text">{getTranslation('mobile.productRequestContent.loading')}</div>
							{:else}
								<select class="form-input" bind:value={selectedUserId} on:change={onUserSelected}>
									<option value={null}>{getTranslation('mobile.productRequestContent.chooseUser')}</option>
									{#each branchUsers as user}
										<option value={user.id}>{$currentLocale === 'ar' ? (user.name_ar || user.username) : (user.name_en || user.username)}</option>
										{/each}
									</select>
								{/if}
							</div>
						{/if}

					<!-- Auto-selected manager for BT / ST -->
						{#if (requestType === 'BT' || requestType === 'ST') && selectedUserId}
							<div class="auto-info">
								<span class="auto-label">{getTranslation('mobile.productRequestContent.manager')}:</span>
								<span class="auto-value">{selectedUserName}</span>
							</div>
						{/if}

						<!-- No default position warning -->
						{#if (requestType === 'BT' || requestType === 'ST') && noDefaultPosition && selectedBranchId}
							<div class="warning-info">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
									<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
								</svg>
								<span>{getTranslation('mobile.productRequestContent.noDefaultPosition')}</span>
							</div>
						{/if}

						<!-- Send + Add More buttons -->
						{#if (requestType === 'BT' && selectedBranchId && selectedUserId) || (requestType === 'ST' && selectedUserId) || (requestType === 'PO' && selectedUserId)}
							{#if sendSuccess}
								<div class="success-info">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
										<polyline points="20 6 9 17 4 12"/>
									</svg>
									<span>{getTranslation('mobile.productRequestContent.sendSuccess')}</span>
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
										{getTranslation('mobile.productRequestContent.send')}
									</button>
									<button type="button" class="btn-add-more" on:click={addMoreFromSave} disabled={sending}>
										<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
											<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
										</svg>
									</button>
								</div>
							{/if}
						{/if}
					{/if}
				</div>
			</div>
		</div>
	{/if}
	{/if}
</div>

<style>
	.product-request-page {
		padding: 0;
		padding-bottom: 4.5rem;
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		height: 100vh;
		overflow: hidden;
	}

	/* Fixed bottom bar for Save & Send */
	.fixed-bottom-bar {
		position: fixed;
		bottom: 3.6rem;
		left: 0;
		right: 0;
		display: flex;
		justify-content: center;
		padding: 0.5rem 1rem;
		background: transparent;
		backdrop-filter: none;
		border-top: none;
		z-index: 999;
		box-shadow: none;
	}

	/* Items table */
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

	/* Type selection screen */
	.type-selection-screen {
		display: flex;
		align-items: center;
		justify-content: center;
		flex: 1;
		padding: 2rem 1rem;
	}

	.type-selection-card {
		background: white;
		border-radius: 1.5rem;
		padding: 2rem 1.5rem;
		box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
		width: 100%;
		max-width: 400px;
	}

	.type-selection-title {
		font-size: 1.1rem;
		font-weight: 700;
		text-align: center;
		color: #1E293B;
		margin-bottom: 1.5rem;
	}

	/* Type badge row */
	.type-badge-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.type-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		background: #059669;
		color: white;
		font-weight: 800;
		font-size: 0.85rem;
		padding: 0.35rem 0.75rem;
		border-radius: 8px;
		letter-spacing: 0.5px;
	}

	.change-type-btn {
		background: none;
		border: 1px solid #CBD5E1;
		color: #64748B;
		font-size: 0.7rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 6px;
		cursor: pointer;
	}

	.change-type-btn:active {
		background: #F1F5F9;
	}

	/* Top actions row */
	.top-actions {
		display: flex;
		gap: 0.5rem;
		padding: 0.5rem;
		background: #F8FAFC;
		flex-shrink: 0;
		align-items: center;
		justify-content: space-between;
	}

	/* Add button */
	.add-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #007bff;
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
		background: #0056b3;
	}

	.save-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem 2rem;
		background: #10B981;
		color: white;
		border: none;
		border-radius: 10px;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
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
		background: #059669;
		animation: none;
	}

	/* Modal */
	.modal-overlay {
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
		background: #007bff;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-add:active {
		background: #0056b3;
	}

	.btn-add:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		opacity: 0.6;
	}

	/* Form fields inside modal */
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
		border-color: #007bff;
		box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
	}

	.barcode-input-row {
		display: flex;
		gap: 0.35rem;
		align-items: stretch;
	}

	.barcode-input-row .form-input {
		flex: 1;
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

	/* Photo field */
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

	/* Save popup */
	.save-popup {
		max-width: 380px;
	}

	.request-type-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.15rem;
	}

	.type-btn {
		flex: 1;
		padding: 0.5rem;
		background: #F3F4F6;
		color: #374151;
		border: 2px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.15s;
		text-align: center;
	}

	.type-btn:active {
		transform: scale(0.97);
	}

	.type-btn.active {
		background: #007bff;
		color: white;
		border-color: #007bff;
	}

	.type-labels-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.type-label {
		flex: 1;
		text-align: center;
		font-size: 0.6rem;
		color: #6B7280;
		font-weight: 500;
	}

	.type-info-box {
		background: #EFF6FF;
		border: 1px solid #BFDBFE;
		border-radius: 6px;
		padding: 0.45rem 0.6rem;
		margin-bottom: 0.75rem;
	}

	.type-info-box p {
		font-size: 0.65rem;
		color: #1E40AF;
		margin: 0.15rem 0;
		line-height: 1.3;
	}

	.type-info-box strong {
		color: #1D4ED8;
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
		background: #10B981;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-send:active {
		background: #059669;
	}

	.btn-add-more {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.55rem 0.75rem;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
	}

	.btn-add-more:active {
		background: #0056b3;
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

	/* Text scan button (OCR) - amber to distinguish from blue barcode */
	.text-scan-btn {
		background: #F59E0B !important;
	}

	.text-scan-btn:active {
		background: #D97706 !important;
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
</style>
