<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { compressImage } from '$lib/utils/imageCompression';

	interface ScanRequest {
		id: string;
		box_operation_id: string;
		branch_id: number | null;
		box_number: number | null;
		pos_number: number | null;
		status: string;
		created_at: string;
	}

	let requests: ScanRequest[] = [];
	let loading = true;
	let channel: ReturnType<typeof supabase.channel> | null = null;

	let activeRequestId: string | null = null;
	let videoEl: HTMLVideoElement;
	let galleryInput: HTMLInputElement;
	let stream: MediaStream | null = null;
	let scanning = false;
	let cameraError = '';
	let extracting = false;
	let errorMessage = '';
	let photoDataUrl: string | null = null;
	let saving = false;

	let form = {
		date: '',
		time: '',
		terminal_id: '',
		statement_match_number: '',
		mada: '',
		visa: '',
		mastercard: '',
		google_pay: '',
		other: ''
	};

	$: total = [form.mada, form.visa, form.mastercard, form.google_pay, form.other]
		.reduce((sum, v) => sum + (Number(v) || 0), 0);

	// Requests are scoped to the specific cashier the box belongs to (requested_by), not the
	// mobile user's own home branch_id — those two can legitimately differ (e.g. a global user
	// closing a box registered under a different branch), which is why branch-based filtering
	// could silently hide a request from the very cashier it was sent for.
	function getUserId(): string | null {
		return $currentUser?.id || null;
	}

	async function loadRequests() {
		const userId = getUserId();
		if (!userId) { loading = false; return; }
		try {
			const { data, error } = await supabase
				.from('pos_scan_requests')
				.select('id, box_operation_id, branch_id, box_number, pos_number, status, created_at')
				.eq('requested_by', userId)
				.eq('status', 'pending')
				.order('created_at');
			if (error) throw error;
			requests = data || [];
		} catch (e) {
			console.error('Error loading scan requests:', e);
		} finally {
			loading = false;
		}
	}

	function setupRealtime() {
		const userId = getUserId();
		if (!userId) return;
		channel = supabase
			.channel(`mobile-scan-requests-${userId}`)
			.on('postgres_changes', {
				event: '*',
				schema: 'public',
				table: 'pos_scan_requests',
				filter: `requested_by=eq.${userId}`
			}, (payload: any) => {
				const row = payload.new || payload.old;
				if (!row) return;
				if (payload.eventType === 'DELETE' || row.status !== 'pending') {
					requests = requests.filter((r) => r.id !== row.id);
				} else {
					requests = requests.some((r) => r.id === row.id)
						? requests.map((r) => (r.id === row.id ? row : r))
						: [...requests, row];
				}
			})
			.subscribe();
	}

	onMount(() => {
		loadRequests();
		setupRealtime();
	});

	onDestroy(() => {
		if (channel) supabase.removeChannel(channel);
		stopCamera();
	});

	// In-page live camera (getUserMedia + <video>), same pattern as the OCR scanner in
	// near-expiry/+page.svelte — avoids handing off to the OS camera app, which was reloading
	// the whole page (and losing all in-progress state) on some Android browsers/PWAs when
	// using <input type="file" capture="environment">.
	async function startCamera() {
		cameraError = '';
		try {
			stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
			scanning = true;
			await new Promise((r) => setTimeout(r, 50));
			if (videoEl) {
				videoEl.srcObject = stream;
				await videoEl.play();
			}
		} catch (err) {
			console.error('Camera access error:', err);
			scanning = false;
			cameraError = $currentLocale === 'ar' ? 'تعذر الوصول إلى الكاميرا' : 'Could not access the camera';
		}
	}

	function stopCamera() {
		if (stream) { stream.getTracks().forEach((t) => t.stop()); stream = null; }
		scanning = false;
	}

	function openRequest(req: ScanRequest) {
		activeRequestId = req.id;
		errorMessage = '';
		cameraError = '';
		photoDataUrl = null;
		form = { date: '', time: '', terminal_id: '', statement_match_number: '', mada: '', visa: '', mastercard: '', google_pay: '', other: '' };
		startCamera();
	}

	function closeActiveRequest() {
		stopCamera();
		activeRequestId = null;
		photoDataUrl = null;
	}

	function capturePhoto() {
		if (!videoEl || videoEl.readyState < 2) return;
		const canvas = document.createElement('canvas');
		canvas.width = videoEl.videoWidth;
		canvas.height = videoEl.videoHeight;
		const ctx = canvas.getContext('2d');
		if (!ctx) return;
		ctx.drawImage(videoEl, 0, 0);
		photoDataUrl = canvas.toDataURL('image/jpeg', 0.85);
		stopCamera();
		extractFromPhoto();
	}

	// Alternative to the live camera above — lets the user pick an existing photo of the slip
	// instead of taking a new one. Plain file picker (no capture attribute), so it doesn't hand
	// off to the OS camera app the way <input capture="environment"> did.
	function openGalleryPicker() {
		stopCamera();
		cameraError = '';
		errorMessage = '';
		if (galleryInput) {
			galleryInput.value = '';
			galleryInput.click();
		}
	}

	async function handleGallerySelected(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file || !activeRequestId) return;

		errorMessage = '';
		try {
			photoDataUrl = await compressImage(file);
		} catch (e) {
			const reader = new FileReader();
			photoDataUrl = await new Promise<string>((resolve, reject) => {
				reader.onload = (ev) => resolve(ev.target?.result as string);
				reader.onerror = reject;
				reader.readAsDataURL(file);
			});
		}
		await extractFromPhoto();
	}

	async function extractFromPhoto() {
		if (!photoDataUrl) return;
		extracting = true;
		errorMessage = '';
		try {
			const base64 = photoDataUrl.split(',')[1];
			const mimeMatch = photoDataUrl.match(/^data:([^;]+);/);
			const mimeType = mimeMatch ? mimeMatch[1] : 'image/jpeg';

			const res = await fetch('/api/scan-request-extract', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ imageBase64: base64, mimeType })
			});
			const data = await res.json();
			if (!res.ok || data.error) throw new Error(data.error || 'Extraction failed');

			form.date = data.date || '';
			form.time = data.time || '';
			form.terminal_id = data.terminalId || '';
			form.statement_match_number = data.statementMatchNumber || '';
		} catch (e) {
			console.error('Error extracting scan data:', e);
			errorMessage = $currentLocale === 'ar'
				? 'تعذر استخراج البيانات تلقائيًا، يمكنك تعبئتها يدويًا'
				: 'Could not auto-extract data — you can fill it in manually';
		} finally {
			extracting = false;
		}
	}

	function retakePhoto() {
		photoDataUrl = null;
		startCamera();
	}

	async function uploadPhoto(requestId: string): Promise<string | null> {
		if (!photoDataUrl) return null;
		try {
			const res = await fetch(photoDataUrl);
			const blob = await res.blob();
			const ext = blob.type.split('/')[1] || 'jpg';
			const fileName = `${requestId}-${Date.now()}.${ext}`;
			const { error } = await supabase.storage
				.from('pos-scan-photos')
				.upload(fileName, blob, { cacheControl: '3600', upsert: false });
			if (error) { console.error('Photo upload error:', error); return null; }
			const { data } = supabase.storage.from('pos-scan-photos').getPublicUrl(fileName);
			return data.publicUrl;
		} catch (e) {
			console.error('Error uploading photo:', e);
			return null;
		}
	}

	async function saveRequest() {
		if (!activeRequestId || saving) return;
		saving = true;
		errorMessage = '';
		try {
			const photoUrl = await uploadPhoto(activeRequestId);
			const { error } = await supabase
				.from('pos_scan_requests')
				.update({
					status: 'completed',
					photo_url: photoUrl,
					extracted_date: form.date || null,
					extracted_time: form.time || null,
					extracted_terminal_id: form.terminal_id || null,
					extracted_statement_match_number: form.statement_match_number || null,
					final_date: form.date || null,
					final_time: form.time || null,
					final_terminal_id: form.terminal_id || null,
					final_statement_match_number: form.statement_match_number || null,
					final_mada: Number(form.mada) || 0,
					final_visa: Number(form.visa) || 0,
					final_mastercard: Number(form.mastercard) || 0,
					final_google_pay: Number(form.google_pay) || 0,
					final_other: Number(form.other) || 0,
					completed_by: $currentUser?.id || null,
					completed_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				})
				.eq('id', activeRequestId);
			if (error) throw error;

			requests = requests.filter((r) => r.id !== activeRequestId);
			activeRequestId = null;
			photoDataUrl = null;
		} catch (e) {
			console.error('Error saving scan request:', e);
			errorMessage = $currentLocale === 'ar' ? 'حدث خطأ أثناء الحفظ' : 'Error saving';
		} finally {
			saving = false;
		}
	}
</script>

<input
	bind:this={galleryInput}
	type="file"
	accept="image/*"
	style="display:none"
	on:change={handleGallerySelected}
/>

<div class="scan-request-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	{#if !activeRequestId}
		<div class="page-header">
			<h2>{$currentLocale === 'ar' ? 'طلبات المسح' : 'Scan Requests'}</h2>
		</div>

		{#if loading}
			<div class="empty-state">{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</div>
		{:else if requests.length === 0}
			<div class="empty-state">{$currentLocale === 'ar' ? 'لا توجد طلبات مسح حاليًا' : 'No scan requests right now'}</div>
		{:else}
			<div class="request-list">
				{#each requests as req (req.id)}
					<button class="request-card" on:click={() => openRequest(req)}>
						<div class="request-card-icon">📷</div>
						<div class="request-card-info">
							<div class="request-card-title">
								{$currentLocale === 'ar' ? 'صندوق' : 'Box'} {req.box_number ?? '-'}{req.pos_number ? ` · POS ${req.pos_number}` : ''}
							</div>
							<div class="request-card-sub">{new Date(req.created_at).toLocaleString()}</div>
						</div>
						<div class="request-card-arrow">{$currentLocale === 'ar' ? '‹' : '›'}</div>
					</button>
				{/each}
			</div>
		{/if}
	{:else}
		<div class="page-header">
			<button class="back-btn" on:click={closeActiveRequest}>{$currentLocale === 'ar' ? 'رجوع' : 'Back'}</button>
			<h2>{$currentLocale === 'ar' ? 'مسح التسوية' : 'Scan Reconciliation'}</h2>
		</div>

		{#if !photoDataUrl && scanning}
			<div class="camera-wrap">
				<video bind:this={videoEl} playsinline autoplay muted class="camera-video"></video>
				<button class="capture-btn" on:click={capturePhoto} aria-label="Capture">
					<span class="capture-btn-ring"></span>
				</button>
			</div>
			<button class="gallery-btn" on:click={openGalleryPicker}>
				{$currentLocale === 'ar' ? 'اختيار من المعرض' : 'Choose from Gallery'}
			</button>
		{:else if !photoDataUrl && cameraError}
			<div class="error-banner">{cameraError}</div>
			<button class="retake-btn" on:click={startCamera}>{$currentLocale === 'ar' ? 'إعادة المحاولة' : 'Try again'}</button>
			<button class="gallery-btn" on:click={openGalleryPicker}>
				{$currentLocale === 'ar' ? 'اختيار من المعرض' : 'Choose from Gallery'}
			</button>
		{:else if !photoDataUrl}
			<div class="empty-state">{$currentLocale === 'ar' ? 'جاري فتح الكاميرا...' : 'Opening camera...'}</div>
		{:else if photoDataUrl}
			<div class="photo-preview-wrap">
				<img src={photoDataUrl} alt="Scan" class="photo-preview" />
				<button class="retake-btn" on:click={retakePhoto} disabled={extracting || saving}>
					{$currentLocale === 'ar' ? 'إعادة التصوير' : 'Retake'}
				</button>
			</div>

			{#if errorMessage}
				<div class="error-banner">{errorMessage}</div>
			{/if}

			{#if extracting}
				<div class="empty-state">{$currentLocale === 'ar' ? 'جاري استخراج البيانات...' : 'Extracting data...'}</div>
			{:else}
				<div class="review-form">
					<div class="form-row">
						<div class="form-group">
							<label for="sr-date">{$currentLocale === 'ar' ? 'التاريخ' : 'Date'}</label>
							<input id="sr-date" type="date" bind:value={form.date} class="form-input" />
						</div>
						<div class="form-group">
							<label for="sr-time">{$currentLocale === 'ar' ? 'الوقت' : 'Time'}</label>
							<input id="sr-time" type="time" step="1" bind:value={form.time} class="form-input" />
						</div>
					</div>
					<div class="form-group">
						<label for="sr-terminal">{$currentLocale === 'ar' ? 'رقم الجهاز' : 'Terminal ID'}</label>
						<input id="sr-terminal" type="text" bind:value={form.terminal_id} class="form-input" />
					</div>
					<div class="form-group">
						<label for="sr-statement">{$currentLocale === 'ar' ? 'رقم مطابقة الكشف' : 'Statement match number'}</label>
						<input id="sr-statement" type="text" bind:value={form.statement_match_number} class="form-input" />
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="sr-mada">{$currentLocale === 'ar' ? 'مدى' : 'Mada'}</label>
							<input id="sr-mada" type="text" inputmode="decimal" bind:value={form.mada} placeholder="0.00" class="form-input" />
						</div>
						<div class="form-group">
							<label for="sr-visa">{$currentLocale === 'ar' ? 'فيزا' : 'Visa'}</label>
							<input id="sr-visa" type="text" inputmode="decimal" bind:value={form.visa} placeholder="0.00" class="form-input" />
						</div>
					</div>
					<div class="form-row">
						<div class="form-group">
							<label for="sr-mc">{$currentLocale === 'ar' ? 'ماستر كارد' : 'MasterCard'}</label>
							<input id="sr-mc" type="text" inputmode="decimal" bind:value={form.mastercard} placeholder="0.00" class="form-input" />
						</div>
						<div class="form-group">
							<label for="sr-gpay">{$currentLocale === 'ar' ? 'جوجل باي' : 'Google Pay'}</label>
							<input id="sr-gpay" type="text" inputmode="decimal" bind:value={form.google_pay} placeholder="0.00" class="form-input" />
						</div>
					</div>
					<div class="form-group">
						<label for="sr-other">{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</label>
						<input id="sr-other" type="text" inputmode="decimal" bind:value={form.other} placeholder="0.00" class="form-input" />
					</div>

					<div class="total-row">
						<span>{$currentLocale === 'ar' ? 'المجموع' : 'Total'}</span>
						<strong>{total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</strong>
					</div>

					<button class="save-btn" on:click={saveRequest} disabled={saving}>
						{saving ? ($currentLocale === 'ar' ? 'جاري الحفظ...' : 'Saving...') : ($currentLocale === 'ar' ? 'حفظ' : 'Save')}
					</button>
				</div>
			{/if}
		{:else if errorMessage}
			<div class="error-banner">{errorMessage}</div>
			<button class="retake-btn" on:click={retakePhoto}>{$currentLocale === 'ar' ? 'إعادة المحاولة' : 'Try again'}</button>
		{/if}
	{/if}
</div>

<style>
	.scan-request-page {
		padding: 16px;
		min-height: 100%;
		background: #f9fafb;
	}

	.page-header {
		display: flex;
		align-items: center;
		gap: 10px;
		margin-bottom: 16px;
	}

	.page-header h2 {
		font-size: 1.1rem;
		font-weight: 700;
		color: #111827;
		margin: 0;
	}

	.back-btn {
		background: none;
		border: none;
		color: #2563eb;
		font-weight: 600;
		font-size: 0.9rem;
		cursor: pointer;
		padding: 4px 8px;
	}

	.empty-state {
		text-align: center;
		color: #6b7280;
		font-size: 0.9rem;
		padding: 40px 0;
	}

	.error-banner {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 10px 12px;
		font-size: 0.85rem;
		margin-bottom: 12px;
	}

	.request-list {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.request-card {
		display: flex;
		align-items: center;
		gap: 12px;
		background: #fff;
		border: 1px solid #e5e7eb;
		border-radius: 10px;
		padding: 12px 14px;
		text-align: left;
		cursor: pointer;
		width: 100%;
	}

	.request-card-icon {
		font-size: 1.4rem;
	}

	.request-card-info {
		flex: 1;
	}

	.request-card-title {
		font-weight: 700;
		color: #111827;
		font-size: 0.9rem;
	}

	.request-card-sub {
		color: #6b7280;
		font-size: 0.75rem;
		margin-top: 2px;
	}

	.request-card-arrow {
		color: #9ca3af;
		font-size: 1.2rem;
	}

	.camera-wrap {
		position: relative;
		border-radius: 10px;
		overflow: hidden;
		background: #000;
		margin-bottom: 14px;
	}

	.camera-video {
		width: 100%;
		display: block;
	}

	.capture-btn {
		position: absolute;
		bottom: 16px;
		left: 50%;
		transform: translateX(-50%);
		width: 64px;
		height: 64px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.25);
		border: 3px solid #fff;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		padding: 0;
	}

	.capture-btn-ring {
		width: 48px;
		height: 48px;
		border-radius: 50%;
		background: #fff;
	}

	.gallery-btn {
		display: block;
		width: 100%;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		padding: 10px 12px;
		font-size: 0.85rem;
		font-weight: 600;
		color: #374151;
		cursor: pointer;
		margin-bottom: 14px;
	}

	.photo-preview-wrap {
		position: relative;
		margin-bottom: 14px;
	}

	.photo-preview {
		width: 100%;
		border-radius: 10px;
		display: block;
	}

	.retake-btn {
		margin-top: 8px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		padding: 8px 12px;
		font-size: 0.85rem;
		font-weight: 600;
		color: #374151;
		cursor: pointer;
	}

	.review-form {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.form-row {
		display: flex;
		gap: 10px;
	}

	.form-row .form-group {
		flex: 1;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.form-group label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #374151;
	}

	.form-input {
		border: 1px solid #d1d5db;
		border-radius: 8px;
		padding: 8px 10px;
		font-size: 0.9rem;
	}

	.total-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 8px;
		padding: 10px 12px;
		font-size: 0.9rem;
		color: #1e40af;
	}

	.save-btn {
		background: #2563eb;
		color: #fff;
		border: none;
		border-radius: 8px;
		padding: 12px;
		font-size: 0.95rem;
		font-weight: 700;
		cursor: pointer;
	}

	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>

