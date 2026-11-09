<script lang="ts">
	import { onMount, onDestroy, tick } from 'svelte';
	import { beforeNavigate } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { compressImage } from '$lib/utils/imageCompression';
	import { ArrowLeft, ArrowUp, ArrowDown, Camera, ImagePlus, Plus, RefreshCw, RotateCcw, Trash2, X, Check } from 'lucide-svelte';

	interface BillRequest {
		id: string;
		receiving_record_id: string;
		request_label: string | null;
		created_at: string;
	}
	interface BillPage { id: string; dataUrl: string }
	let requests: BillRequest[] = [];
	let activeRequest: BillRequest | null = null;
	let pages: BillPage[] = [];
	let expectedOriginalBillUrl: string | null = null;
	let loading = true;
	let opening = false;
	let saving = false;
	let processing = false;
	let errorMessage = '';
	let successMessage = '';
	let cameraError = '';
	let scanning = false;
	let startingCamera = false;
	let stream: MediaStream | null = null;
	let videoEl: HTMLVideoElement;
	let galleryInput: HTMLInputElement;
	let retakeIndex: number | null = null;
	let previewId: string | null = null;
	let selectedPageId: string | null = null;
	let channel: ReturnType<typeof supabase.channel> | null = null;
	let mounted = false;
	$: arabic = $currentLocale === 'ar';
	$: busy = saving || processing || opening || startingCamera;
	$: previewPage = pages.find((page) => page.id === previewId);
	$: selectedPage = pages.find((page) => page.id === selectedPageId) || pages[pages.length - 1];
	$: selectedIndex = selectedPage ? pages.findIndex((page) => page.id === selectedPage.id) : -1;
	const maxPages = 40;
	const a4Ratio = 210 / 297;
	const text = (en: string, ar: string) => $currentLocale === 'ar' ? ar : en;

	async function loadRequests() {
		if (!$currentUser?.id) { loading = false; return; }
		const { data, error } = await supabase.from('pos_scan_requests')
			.select('id, receiving_record_id, request_label, created_at')
			.eq('requested_by', $currentUser.id).eq('request_type', 'receiving_bill')
			.eq('status', 'pending').order('created_at');
		if (error) errorMessage = error.message;
		else requests = data || [];
		loading = false;
	}

	function stopCamera() {
		stream?.getTracks().forEach((track) => track.stop());
		stream = null;
		scanning = false;
	}

	async function startCamera(index: number | null = null) {
		stopCamera();
		retakeIndex = index;
		cameraError = '';
		startingCamera = true;
		try {
			const nextStream = await navigator.mediaDevices.getUserMedia({
				video: {
					facingMode: { ideal: 'environment' },
					width: { ideal: 2480 }, height: { ideal: 3508 },
					aspectRatio: { ideal: a4Ratio }
				}, audio: false
			});
			if (!mounted || !activeRequest) { nextStream.getTracks().forEach((track) => track.stop()); return; }
			stream = nextStream;
			scanning = true;
			await tick();
			videoEl.srcObject = nextStream;
			await videoEl.play();
		} catch {
			stopCamera();
			cameraError = text('Could not open the camera. Allow camera access or choose photos below.', 'تعذر فتح الكاميرا. اسمح بالوصول إليها أو اختر الصور أدناه.');
		} finally { startingCamera = false; }
	}

	async function openRequest(request: BillRequest) {
		if (busy) return;
		opening = true; errorMessage = ''; successMessage = '';
		try {
			const { data, error } = await supabase.from('receiving_records')
				.select('original_bill_url').eq('id', request.receiving_record_id).single();
			if (error) throw error;
			expectedOriginalBillUrl = data.original_bill_url;
			activeRequest = request; pages = []; selectedPageId = null; previewId = null; cameraError = '';
		} catch (error: any) { errorMessage = error?.message || text('Could not open this request.', 'تعذر فتح الطلب.'); }
		finally { opening = false; }
	}

	function leaveRequest() {
		if (busy || (pages.length && !confirm(text('Discard these unsaved bill pages?', 'هل تريد تجاهل صفحات الفاتورة غير المحفوظة؟')))) return;
		stopCamera(); activeRequest = null; pages = []; previewId = null; errorMessage = ''; cameraError = '';
	}

	async function addPhoto(source: File | string, replaceIndex: number | null) {
		const dataUrl = await compressImage(source, 2400, 3200, 0.88);
		if (replaceIndex !== null && pages[replaceIndex]) {
			selectedPageId = pages[replaceIndex].id;
			pages = pages.map((page, index) => index === replaceIndex ? { ...page, dataUrl } : page);
		} else {
			if (pages.length >= maxPages) throw new Error(text('A bill can contain up to 40 pages.', 'يمكن أن تحتوي الفاتورة على ٤٠ صفحة كحد أقصى.'));
			selectedPageId = crypto.randomUUID();
			pages = [...pages, { id: selectedPageId, dataUrl }];
		}
	}

	async function capturePhoto() {
		if (!videoEl || videoEl.readyState < 2 || busy) return;
		processing = true; errorMessage = '';
		try {
			const canvas = document.createElement('canvas');
			// Match the centered A4 crop shown by object-fit: cover in the camera frame.
			// Camera hardware may return landscape video despite portrait constraints.
			const sourceWidth = videoEl.videoWidth;
			const sourceHeight = videoEl.videoHeight;
			const cropWidth = Math.min(sourceWidth, sourceHeight * a4Ratio);
			const cropHeight = cropWidth / a4Ratio;
			canvas.width = Math.min(2480, Math.floor(cropWidth));
			canvas.height = Math.round(canvas.width / a4Ratio);
			const context = canvas.getContext('2d');
			if (!context) throw new Error(text('Could not capture the photo.', 'تعذر التقاط الصورة.'));
			context.drawImage(videoEl, (sourceWidth - cropWidth) / 2, (sourceHeight - cropHeight) / 2,
				cropWidth, cropHeight, 0, 0, canvas.width, canvas.height);
			const dataUrl = canvas.toDataURL('image/jpeg', 0.92);
			stopCamera();
			await addPhoto(dataUrl, retakeIndex);
			retakeIndex = null;
		} catch (error: any) { errorMessage = error?.message || text('Could not add this page.', 'تعذر إضافة الصفحة.'); }
		finally { processing = false; }
	}

	function choosePhotos() {
		stopCamera(); retakeIndex = null; galleryInput.value = ''; galleryInput.click();
	}

	async function selectPhotos(event: Event) {
		const files = Array.from((event.target as HTMLInputElement).files || []);
		if (!files.length || busy) return;
		processing = true; errorMessage = '';
		try {
			if (pages.length + files.length > maxPages) throw new Error(text('A bill can contain up to 40 pages.', 'يمكن أن تحتوي الفاتورة على ٤٠ صفحة كحد أقصى.'));
			for (const file of files) {
				if (!file.type.startsWith('image/')) throw new Error(text('Choose image files only.', 'اختر ملفات صور فقط.'));
				await addPhoto(file, null);
			}
		} catch (error: any) { errorMessage = error?.message || text('Could not read a photo. Try a JPEG or PNG image.', 'تعذرت قراءة الصورة. جرّب صورة JPEG أو PNG.'); }
		finally { processing = false; }
	}

	function movePage(index: number, offset: number) {
		const next = [...pages];
		[next[index], next[index + offset]] = [next[index + offset], next[index]];
		pages = next;
	}

	function removeSelectedPage() {
		if (!selectedPage || busy || scanning) return;
		const remaining = pages.filter((page) => page.id !== selectedPage.id);
		selectedPageId = remaining[Math.min(selectedIndex, remaining.length - 1)]?.id || null;
		pages = remaining;
	}

	async function savePdf() {
		if (!activeRequest || !pages.length || busy) return;
		stopCamera(); saving = true; errorMessage = '';
		const request = activeRequest;
		const storagePath = `${request.receiving_record_id}/${request.id}/${crypto.randomUUID()}.pdf`;
		try {
			const { jsPDF } = await import('jspdf');
			const pdf = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'portrait', compress: true });
			for (let index = 0; index < pages.length; index++) {
				const page = pages[index];
				const { width, height } = pdf.getImageProperties(page.dataUrl);
				if (index > 0) pdf.addPage('a4', 'portrait');
				const pageWidth = pdf.internal.pageSize.getWidth();
				const pageHeight = pdf.internal.pageSize.getHeight();
				const scale = Math.min((pageWidth - 10) / width, (pageHeight - 10) / height);
				pdf.addImage(page.dataUrl, 'JPEG', (pageWidth - width * scale) / 2,
					(pageHeight - height * scale) / 2, width * scale, height * scale);
			}
			const blob = pdf.output('blob');
			if (blob.size > 50 * 1024 * 1024) throw new Error(text('The PDF exceeds 50 MB. Remove some pages or retake them at a lower resolution.', 'حجم ملف PDF يتجاوز ٥٠ ميجابايت. احذف بعض الصفحات أو أعد تصويرها بدقة أقل.'));
			const { error: uploadError } = await supabase.storage.from('original-bills')
				.upload(storagePath, blob, { contentType: 'application/pdf', upsert: false });
			if (uploadError) throw uploadError;
			const { data: { publicUrl } } = supabase.storage.from('original-bills').getPublicUrl(storagePath);
			const { error: saveError } = await supabase.rpc('complete_receiving_bill_scan', {
				p_request_id: request.id, p_storage_path: storagePath, p_pdf_url: publicUrl,
				p_expected_original_bill_url: expectedOriginalBillUrl
			});
			if (saveError) {
				// A lost response may follow a committed save; never delete its PDF.
				const { data: saved, error: lookupError } = await supabase.from('pos_scan_requests')
					.select('status, photo_url').eq('id', request.id).maybeSingle();
				if (lookupError) throw new Error(text('Unable to confirm the save. Reopen the request to see its latest status.', 'تعذر تأكيد الحفظ. أعد فتح الطلب للاطلاع على حالته.'));
				if (saved?.status !== 'completed' || saved.photo_url !== publicUrl) {
					await supabase.storage.from('original-bills').remove([storagePath]);
					throw saveError;
				}
			}
			requests = requests.filter((item) => item.id !== request.id);
			activeRequest = null; pages = []; previewId = null;
			successMessage = text('Bill saved as one PDF and attached to the receiving record.', 'تم حفظ الفاتورة كملف PDF واحد وإرفاقها بسجل الاستلام.');
		} catch (error: any) { errorMessage = error?.message || text('Could not save the bill. Your pages are still here; try again.', 'تعذر حفظ الفاتورة. لا تزال الصفحات موجودة؛ حاول مرة أخرى.'); }
		finally { saving = false; }
	}

	function preventUnload(event: BeforeUnloadEvent) {
		if (pages.length || saving) { event.preventDefault(); event.returnValue = ''; }
	}
	beforeNavigate((navigation) => {
		if (saving || processing || (pages.length && !confirm(text('Discard these unsaved bill pages?', 'هل تريد تجاهل صفحات الفاتورة غير المحفوظة؟')))) navigation.cancel();
		else stopCamera();
	});
	onMount(() => {
		mounted = true;
		loadRequests();
		if ($currentUser?.id) channel = supabase.channel(`mobile-receiving-bills-${$currentUser.id}`)
			.on('postgres_changes', { event: '*', schema: 'public', table: 'pos_scan_requests', filter: `requested_by=eq.${$currentUser.id}` }, loadRequests).subscribe();
	});
	onDestroy(() => { mounted = false; stopCamera(); if (channel) supabase.removeChannel(channel); });
</script>

<svelte:window on:beforeunload={preventUnload} on:keydown={(event) => { if (event.key === 'Escape') previewId = null; }} />
<input bind:this={galleryInput} type="file" accept="image/*" multiple class="hidden" on:change={selectPhotos} />
<div class="scanner" dir={arabic ? 'rtl' : 'ltr'}>
	<header class="scanner-header">
		{#if activeRequest}
			<button type="button" class="icon-button" on:click={leaveRequest} disabled={busy} aria-label={text('Back', 'رجوع')}><ArrowLeft size={20} class={arabic ? 'rotate-180' : ''} /></button>
			<h1 class="request-title" title={activeRequest.request_label || ''}>{activeRequest.request_label || text('Scan bill', 'تصوير الفاتورة')}</h1>
		{:else}
			<h1>{text('Bill scans', 'تصوير الفواتير')}</h1>
			<button type="button" class="icon-button" on:click={loadRequests} disabled={busy} aria-label={text('Refresh', 'تحديث')}><RefreshCw size={18} /></button>
		{/if}
	</header>
	{#if errorMessage}<p role="alert" class="notice error">{errorMessage}</p>{/if}
	{#if successMessage}<p role="status" class="notice success">{successMessage}</p>{/if}
	{#if !activeRequest}
		<div class="request-list">
			{#if loading}<p class="empty-message">{text('Loading…', 'جارٍ التحميل…')}</p>
			{:else if !requests.length}<p class="empty-message">{text('No pending requests.', 'لا توجد طلبات معلّقة.')}</p>
			{:else}{#each requests as request (request.id)}
				<button type="button" class="request-item" on:click={() => openRequest(request)} disabled={busy}>
					<Camera size={20} aria-hidden="true" />
					<span class="request-details">
						<strong>{request.request_label || text('Original Bill', 'الفاتورة الأصلية')}</strong>
						<small>{new Date(request.created_at).toLocaleString(arabic ? 'ar-SA' : 'en-GB', { dateStyle: 'short', timeStyle: 'short' })}</small>
					</span>
					<Plus size={18} aria-hidden="true" />
				</button>
			{/each}{/if}
		</div>
	{:else}
		{#if expectedOriginalBillUrl}<p class="replacement-note">{text('Replaces the current bill on save.', 'يستبدل الفاتورة الحالية عند الحفظ.')}</p>{/if}
		{#if cameraError}<p role="alert" class="notice error">{cameraError}</p>{/if}
		<div class="workspace" class:camera-active={scanning}>
			{#if scanning}
				<div class="camera-frame">
					<video bind:this={videoEl} autoplay playsinline muted></video>
					<span class="camera-label">A4 · {retakeIndex !== null ? text(`Retake · ${retakeIndex + 1}`, `إعادة تصوير · ${retakeIndex + 1}`) : text(`Page ${pages.length + 1}`, `صفحة ${pages.length + 1}`)}</span>
				</div>
			{:else if selectedPage}
				<button type="button" class="page-preview" on:click={() => previewId = selectedPage.id} disabled={busy} aria-label={text('Enlarge page', 'تكبير الصفحة')}>
					<img src={selectedPage.dataUrl} alt={text(`Bill page ${selectedIndex + 1}`, `صفحة الفاتورة ${selectedIndex + 1}`)} />
				</button>
			{:else}
				<div class="empty-preview"><Camera size={36} strokeWidth={1.5} aria-hidden="true" /><p>{text('Photograph all pages, then save.', 'صوّر جميع الصفحات ثم احفظ.')}</p></div>
			{/if}
		</div>
		{#if !scanning && pages.length}
			<div class="page-tools">
				<span class="page-count" aria-live="polite">{text('Page', 'صفحة')} {selectedIndex + 1} / {pages.length}</span>
				<div class="tool-buttons">
					<button type="button" class="icon-button" on:click={() => movePage(selectedIndex, -1)} disabled={busy || selectedIndex === 0} aria-label={text('Move earlier', 'نقل للأعلى')} title={text('Move earlier', 'نقل للأعلى')}><ArrowUp size={18} /></button>
					<button type="button" class="icon-button" on:click={() => movePage(selectedIndex, 1)} disabled={busy || selectedIndex === pages.length - 1} aria-label={text('Move later', 'نقل للأسفل')} title={text('Move later', 'نقل للأسفل')}><ArrowDown size={18} /></button>
					<button type="button" class="icon-button" on:click={() => startCamera(selectedIndex)} disabled={busy} aria-label={text('Retake page', 'إعادة تصوير الصفحة')} title={text('Retake', 'إعادة التصوير')}><RotateCcw size={18} /></button>
					<button type="button" class="icon-button delete-button" on:click={removeSelectedPage} disabled={busy} aria-label={text('Delete page', 'حذف الصفحة')} title={text('Delete', 'حذف')}><Trash2 size={18} /></button>
				</div>
			</div>
			<div class="thumbnail-strip" aria-label={text('Bill pages', 'صفحات الفاتورة')}>
				{#each pages as page, index (page.id)}
					<button type="button" class="thumbnail" class:selected={selectedPage?.id === page.id} on:click={() => selectedPageId = page.id} disabled={busy} aria-label={text(`Select page ${index + 1}`, `اختيار الصفحة ${index + 1}`)} aria-pressed={selectedPage?.id === page.id}>
						<img src={page.dataUrl} alt="" /><span>{index + 1}</span>
					</button>
				{/each}
				<button type="button" class="thumbnail add-thumbnail" on:click={() => startCamera()} disabled={busy || pages.length >= maxPages} aria-label={text('Add page', 'إضافة صفحة')}><Plus size={22} /></button>
			</div>
		{/if}
		<footer class="scanner-actions" aria-busy={busy}>
			{#if scanning}
				<button type="button" class="icon-button cancel-camera" on:click={stopCamera} disabled={busy} aria-label={text('Cancel camera', 'إغلاق الكاميرا')}><X size={20} /></button>
				<button type="button" class="action-button primary capture-button" on:click={capturePhoto} disabled={busy}><Camera size={20} />{text('Capture', 'التقاط')}</button>
			{:else}
				<button type="button" class="icon-button gallery-button" on:click={choosePhotos} disabled={busy || pages.length >= maxPages} aria-label={text('Choose photos', 'اختيار صور')} title={text('Choose photos', 'اختيار صور')}><ImagePlus size={21} /></button>
				<button type="button" class="action-button primary" on:click={() => startCamera()} disabled={busy || pages.length >= maxPages}>
					{#if pages.length}<Plus size={19} />{:else}<Camera size={19} />{/if}
					{startingCamera ? text('Opening…', 'جارٍ الفتح…') : processing ? text('Adding…', 'جارٍ الإضافة…') : pages.length ? text('Add page', 'إضافة صفحة') : text('Take photo', 'تصوير')}
				</button>
				<button type="button" class="action-button save-button" on:click={savePdf} disabled={busy || !pages.length}><Check size={19} />{saving ? text('Saving…', 'جارٍ الحفظ…') : text('Save PDF', 'حفظ PDF')}</button>
			{/if}
		</footer>
	{/if}
</div>
{#if previewPage}
	<div class="full-preview" role="dialog" aria-modal="true" aria-label={text('Page preview', 'معاينة الصفحة')} dir={arabic ? 'rtl' : 'ltr'}>
		<button type="button" class="icon-button" on:click={() => previewId = null} aria-label={text('Close preview', 'إغلاق المعاينة')}><X size={22} /></button>
		<img src={previewPage.dataUrl} alt={text('Bill page preview', 'معاينة صفحة الفاتورة')} />
	</div>
{/if}

<style>
	.scanner { height: 100%; min-height: 0; box-sizing: border-box; display: flex; flex-direction: column; gap: 6px; padding: 8px; overflow: hidden; background: #f8fafc; color: #1e293b; }
	.scanner-header { display: flex; align-items: center; justify-content: space-between; gap: 6px; min-width: 0; flex-shrink: 0; }
	h1 { margin: 0; font-size: 16px; font-weight: 700; }
	.request-title { flex: 1; min-width: 0; font-size: 13px; line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; overflow-wrap: anywhere; }
	button { touch-action: manipulation; -webkit-tap-highlight-color: transparent; cursor: pointer; }
	button:disabled { opacity: .4; cursor: default; }
	button:focus-visible { outline: 3px solid #60a5fa; outline-offset: 2px; }
	.icon-button { display: inline-flex; align-items: center; justify-content: center; flex: 0 0 44px; width: 44px; min-height: 44px; padding: 0; border: 0; border-radius: 10px; background: #fff; color: #475569; }
	.notice { flex-shrink: 0; margin: 0; padding: 7px 9px; border-radius: 8px; max-height: 16vh; overflow: auto; font-size: 12px; line-height: 1.4; overflow-wrap: anywhere; }
	.error { background: #fef2f2; color: #b91c1c; }
	.success { background: #ecfdf5; color: #047857; }
	.replacement-note { flex-shrink: 0; margin: 0; padding: 2px 4px; font-size: 11px; color: #92400e; }
	.request-list { flex: 1; min-height: 0; overflow-y: auto; display: flex; flex-direction: column; gap: 6px; }
	.request-item { display: flex; align-items: center; gap: 10px; width: 100%; padding: 10px; border: 1px solid #e2e8f0; border-radius: 10px; background: #fff; color: #2563eb; text-align: start; }
	.request-item > :global(svg) { flex-shrink: 0; }
	.request-details { flex: 1; min-width: 0; }
	.request-details strong { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; overflow-wrap: anywhere; color: #1e293b; font-size: 13px; line-height: 1.4; }
	.request-details small { display: block; margin-top: 3px; color: #64748b; font-size: 11px; }
	.empty-message { margin: 10px 0; font-size: 13px; color: #64748b; }
	.workspace { position: relative; display: flex; flex: 1 1 0%; min-height: 0; overflow: hidden; border: 1px solid #e2e8f0; border-radius: 12px; background: #eaf0f6; container-type: size; }
	.page-preview { display: flex; width: 100%; min-height: 0; padding: 5px; border: 0; background: transparent; }
	.page-preview img { width: 100%; height: 100%; min-height: 0; object-fit: contain; }
	.empty-preview { margin: auto; display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 8px; color: #64748b; text-align: center; }
	.empty-preview p { margin: 0; font-size: 12px; }
	.camera-active { background: #0f172a; border-color: #0f172a; }
	.camera-frame { position: relative; flex: none; width: min(100cqw, calc(100cqh * 210 / 297)); aspect-ratio: 210 / 297; margin: auto; overflow: hidden; box-shadow: 0 0 0 1px #ffffff80; }
	video { display: block; width: 100%; height: 100%; min-height: 0; object-fit: cover; object-position: center; }
	.camera-label { position: absolute; top: 8px; inset-inline-start: 8px; padding: 4px 8px; border-radius: 20px; background: #0009; color: #fff; font-size: 12px; pointer-events: none; }
	.page-tools { display: flex; flex-shrink: 0; align-items: center; justify-content: space-between; gap: 4px; min-width: 0; }
	.page-count { padding-inline-start: 4px; white-space: nowrap; color: #64748b; font-size: 12px; }
	.tool-buttons { display: flex; gap: 2px; }
	.tool-buttons .icon-button { background: transparent; }
	.delete-button { color: #dc2626; }
	.thumbnail-strip { display: flex; flex-shrink: 0; gap: 6px; padding: 2px; overflow-x: auto; overscroll-behavior-x: contain; scrollbar-width: thin; }
	.thumbnail { position: relative; flex: 0 0 44px; width: 44px; height: 56px; padding: 2px; overflow: hidden; border: 2px solid #cbd5e1; border-radius: 6px; background: #fff; }
	.thumbnail.selected { border-color: #2563eb; box-shadow: 0 0 0 1px #2563eb; }
	.thumbnail img { width: 100%; height: 100%; object-fit: cover; }
	.thumbnail span { position: absolute; bottom: 0; inset-inline-end: 0; padding: 0 4px; border-start-start-radius: 4px; background: #0f172ad9; color: #fff; font-size: 10px; line-height: 15px; }
	.add-thumbnail { display: flex; align-items: center; justify-content: center; border-style: dashed; color: #2563eb; background: #eff6ff; }
	.scanner-actions { display: grid; grid-template-columns: 44px minmax(0, 1fr) minmax(0, 1fr); flex-shrink: 0; gap: 6px; padding-top: 4px; border-top: 1px solid #e2e8f0; }
	.action-button { min-width: 0; min-height: 44px; display: flex; align-items: center; justify-content: center; gap: 5px; padding: 8px 5px; border: 0; border-radius: 10px; font-size: 13px; font-weight: 700; line-height: 1.2; }
	.action-button :global(svg) { flex-shrink: 0; }
	.primary { background: #2563eb; color: #fff; }
	.save-button { background: #059669; color: #fff; }
	.gallery-button { border: 1px solid #cbd5e1; color: #2563eb; }
	.capture-button { grid-column: 2 / -1; }
	.full-preview { position: fixed; inset: 0; z-index: 1100; display: flex; flex-direction: column; gap: 8px; padding: max(8px, env(safe-area-inset-top)) max(8px, env(safe-area-inset-right)) max(8px, env(safe-area-inset-bottom)) max(8px, env(safe-area-inset-left)); background: #020617f5; }
	.full-preview .icon-button { align-self: flex-end; flex-basis: auto; flex-shrink: 0; }
	.full-preview img { flex: 1; min-height: 0; width: 100%; object-fit: contain; }
	@media (max-width: 340px) {
		.scanner { padding: 6px; gap: 4px; }
		.scanner-actions { gap: 4px; }
		.action-button { font-size: 12px; gap: 3px; }
		.tool-buttons { gap: 0; }
	}
	@media (max-height: 560px) {
		.thumbnail { height: 44px; }
		.scanner { gap: 4px; }
		.replacement-note { padding-block: 0; }
	}
</style>
