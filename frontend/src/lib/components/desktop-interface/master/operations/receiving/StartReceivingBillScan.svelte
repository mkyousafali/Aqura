<script lang="ts">
	import { createEventDispatcher, onMount, onDestroy } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { compressImageToFile } from '$lib/utils/imageCompression';

	export let branchId: string | number;
	export let vendorName = '';
	export let visible = true;
	export let savedReceivingId: string | null = null;
	export let requestId: string | null = null;
	export let documentUrl = '';
	export let reading = false;
	export let busy = false;
	const dispatch = createEventDispatcher();
	const text = (en: string, ar: string) => $currentLocale === 'ar' ? ar : en;
	let fileInput: HTMLInputElement;
	let sending = false;
	let uploading = false;
	let completed = false;
	let errorMessage = '';
	let readDone = false;
	let processedUrl = '';
	let ownedRequestId: string | null = null;
	let mounted = false;
	let channel: ReturnType<typeof supabase.channel> | null = null;
	let poll: ReturnType<typeof setInterval> | null = null;
	let readController: AbortController | null = null;
	$: busy = sending || uploading;

	function stopWatching() {
		if (channel) { supabase.removeChannel(channel); channel = null; }
		if (poll) { clearInterval(poll); poll = null; }
	}

	async function readBill() {
		if (!requestId || !documentUrl || reading || savedReceivingId) return;
		const activeId = requestId;
		reading = true; readDone = false; errorMessage = '';
		dispatch('reading');
		readController = new AbortController();
		try {
			const response = await authenticatedFetch('/api/receiving-bill-extract', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ requestId: activeId }), signal: readController.signal
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Could not read this bill.');
			if (!mounted || requestId !== activeId || savedReceivingId) return;
			readDone = true;
			dispatch('extracted', result.fields);
		} catch (error: any) {
			if (!mounted || requestId !== activeId || savedReceivingId || error?.name === 'AbortError') return;
			errorMessage = error?.message || text('Could not read the bill. Enter the fields manually.', 'تعذرت قراءة الفاتورة. أدخل الحقول يدويًا.');
			dispatch('extracted', { billDate: '', billAmount: '', billNumber: '', billVatNumber: '' });
		} finally { if (mounted && requestId === activeId) reading = false; readController = null; }
	}

	async function loadRequest() {
		const activeId = requestId;
		if (!activeId || !mounted) return;
		const { data, error } = await supabase.from('pos_scan_requests')
			.select('status, photo_url').eq('id', activeId).eq('requested_by', $currentUser?.id).maybeSingle();
		if (!mounted || activeId !== requestId) return;
		if (error) { errorMessage = error.message; return; }
		if (!data) {
			stopWatching(); requestId = null; completed = false;
			errorMessage = text('Request cancelled. You can send another request or continue.', 'أُلغي الطلب. يمكنك إرسال طلب آخر أو المتابعة.');
			return;
		}
		if (data.status === 'completed' && data.photo_url) {
			completed = true; documentUrl = data.photo_url;
			if (poll) { clearInterval(poll); poll = null; }
			if (processedUrl !== documentUrl) { processedUrl = documentUrl; void readBill(); }
		}
	}

	async function ensureRequest(): Promise<string> {
		if (requestId && !completed) return requestId;
		if (!$currentUser?.id) throw new Error('Sign in before sending a scan request.');
		if (savedReceivingId) throw new Error('Upload further bill changes from Receiving Records.');
		const { data, error } = await supabase.from('pos_scan_requests').insert({
			box_operation_id: null, receiving_record_id: null, branch_id: Number(branchId),
			request_type: 'receiving_draft_bill', requested_by: $currentUser.id, status: 'pending',
			request_label: `Start Receiving · ${vendorName}`
		}).select('id').single();
		if (error) throw error;
		if (!mounted) {
			await supabase.from('pos_scan_requests').delete().eq('id', data.id).eq('status', 'pending');
			throw new Error('Receiving window was closed.');
		}
		stopWatching();
		requestId = data.id; completed = false; documentUrl = ''; processedUrl = ''; readDone = false;
		ownedRequestId = data.id;
		channel = supabase.channel(`start-receiving-bill-${requestId}`)
			.on('postgres_changes', { event: '*', schema: 'public', table: 'pos_scan_requests', filter: `id=eq.${requestId}` }, loadRequest).subscribe();
		poll = setInterval(loadRequest, 4000);
		void loadRequest();
		return data.id;
	}

	async function sendRequest() {
		if (busy || reading || (requestId && !completed)) return;
		sending = true; errorMessage = '';
		try { await ensureRequest(); }
		catch (error: any) { if (mounted) errorMessage = error?.message || 'Could not send request.'; }
		finally { sending = false; }
	}

	async function uploadBill(event: Event) {
		const file = (event.target as HTMLInputElement).files?.[0];
		if (!file || busy || reading) return;
		uploading = true; errorMessage = '';
		try {
			if (file.size > 50 * 1024 * 1024) throw new Error(text('Maximum file size is 50 MB.', 'الحد الأقصى لحجم الملف ٥٠ ميجابايت.'));
			if (file.type !== 'application/pdf' && !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) throw new Error('Choose a PDF, JPEG, PNG or WebP bill.');
			const uploadFile = file.type === 'application/pdf' ? file : await compressImageToFile(file, 2480, 3508, 0.88);
			const activeId = await ensureRequest();
			const storagePath = `drafts/${activeId}/${crypto.randomUUID()}.${uploadFile.type === 'application/pdf' ? 'pdf' : 'jpg'}`;
			const { error: uploadError } = await supabase.storage.from('original-bills').upload(storagePath, uploadFile, { contentType: uploadFile.type });
			if (uploadError) throw uploadError;
			const { data: { publicUrl } } = supabase.storage.from('original-bills').getPublicUrl(storagePath);
			const { error: saveError } = await supabase.rpc('complete_start_receiving_bill_scan', {
				p_request_id: activeId, p_storage_path: storagePath, p_document_url: publicUrl
			});
			if (saveError) {
				const { data: saved, error: lookupError } = await supabase.from('pos_scan_requests').select('status, photo_url').eq('id', activeId).maybeSingle();
				if (lookupError) throw new Error('Unable to confirm upload. Refresh the request before retrying.');
				if (saved?.status !== 'completed' || saved.photo_url !== publicUrl) {
					await supabase.storage.from('original-bills').remove([storagePath]); throw saveError;
				}
			}
			await loadRequest();
		} catch (error: any) { if (mounted) errorMessage = error?.message || 'Upload failed. Please retry.'; }
		finally { uploading = false; }
	}

	onMount(() => { mounted = true; });
	onDestroy(() => {
		mounted = false; stopWatching(); readController?.abort();
		// Saved requests remain available for a mobile upload after the desktop window closes.
		if (ownedRequestId) void supabase.from('pos_scan_requests').delete()
			.eq('id', ownedRequestId).eq('status', 'pending').is('receiving_record_id', null).is('pending_receiving_record_id', null)
			.then(({ error }) => { if (error) console.error('Could not cancel abandoned bill scan:', error.message); });
	});
</script>

{#if visible}
	<section class="bill-scan-step">
		<div class="scan-step-header"><button type="button" class="scan-secondary" on:click={() => dispatch('back')} disabled={busy}>{text('Back', 'رجوع')}</button><h2>{text('Scan Bill', 'تصوير الفاتورة')}</h2><span>{text('Optional', 'اختياري')}</span></div>
		<p class="scan-vendor">{vendorName}</p>
		<p class="scan-hint">{text('Scan from your mobile or upload a bill. AI fills the bill fields; unreadable fields appear in red.', 'صوّر من الجوال أو ارفع الفاتورة. تُملأ الحقول تلقائيًا وتُميّز الحقول غير المقروءة بالأحمر.')}</p>
		<div class="scan-options">
			<button type="button" class="scan-primary" on:click={sendRequest} disabled={busy || reading || Boolean(requestId && !completed) || Boolean(savedReceivingId)}>📱 {sending ? text('Sending…', 'جارٍ الإرسال…') : requestId && !completed ? text('Request sent', 'تم إرسال الطلب') : text('Send Scan Request', 'إرسال طلب تصوير')}</button>
			<button type="button" class="scan-secondary" on:click={() => { fileInput.value = ''; fileInput.click(); }} disabled={busy || reading || Boolean(savedReceivingId)}>📎 {uploading ? text('Uploading…', 'جارٍ الرفع…') : text('Upload Bill', 'رفع الفاتورة')}</button>
		</div>
		<input bind:this={fileInput} class="hidden" type="file" accept="application/pdf,image/jpeg,image/png,image/webp" on:change={uploadBill} />
		{#if requestId && !completed}<p class="scan-status" role="status">{text('Open Bill Scan Requests on your mobile home page. You can continue while waiting.', 'افتح طلبات مسح الفواتير في صفحة الجوال الرئيسية. يمكنك المتابعة أثناء الانتظار.')}</p>{/if}
		{#if documentUrl}<div class="scan-result"><a href={documentUrl} target="_blank" rel="noopener noreferrer">📄 {text('View bill', 'عرض الفاتورة')}</a><span role="status">{reading ? text('AI is reading…', 'جارٍ قراءة الفاتورة…') : readDone ? text('Ready — review bill fields next.', 'جاهز — راجع الحقول في الخطوة التالية.') : text('Bill attached', 'تم إرفاق الفاتورة')}</span><button type="button" class="scan-secondary" on:click={readBill} disabled={reading || busy || Boolean(savedReceivingId)}>{text('Read again', 'إعادة القراءة')}</button></div>{/if}
		{#if errorMessage}<p class="scan-error" role="alert">{errorMessage}</p>{/if}
		<div class="scan-step-footer"><button type="button" class="scan-primary" on:click={() => dispatch('next')}>{text('Next → Bill Details', 'التالي ← تفاصيل الفاتورة')}</button></div>
	</section>
{/if}

<style>
	.bill-scan-step { margin: 0 auto; max-width: 840px; padding: 20px; border: 1px solid #dbeafe; border-radius: 14px; background: #fff; color: #1e293b; }
	.scan-step-header, .scan-options, .scan-result { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
	h2 { flex: 1; margin: 0; font-size: 18px; font-weight: 700; }
	.scan-step-header > span { color: #64748b; font-size: 12px; }
	.scan-vendor { margin: 14px 0 6px; font-weight: 700; overflow-wrap: anywhere; }
	.scan-hint, .scan-status { margin: 8px 0 16px; font-size: 13px; color: #64748b; }
	.scan-primary, .scan-secondary { min-height: 42px; padding: 9px 14px; border-radius: 8px; cursor: pointer; font-size: 13px; font-weight: 600; }
	.scan-primary { border: 1px solid #2563eb; background: #2563eb; color: #fff; }
	.scan-secondary { border: 1px solid #cbd5e1; background: #f8fafc; color: #334155; }
	button:disabled { opacity: .5; cursor: default; }
	.scan-status { margin-top: 12px; padding: 10px; border-radius: 8px; background: #eff6ff; color: #1d4ed8; }
	.scan-result { margin-top: 14px; padding: 10px; border-radius: 8px; background: #ecfdf5; font-size: 13px; color: #047857; }
	.scan-result a { color: #2563eb; text-decoration: underline; }
	.scan-result span { flex: 1; }
	.scan-error { margin: 12px 0; font-size: 13px; color: #dc2626; overflow-wrap: anywhere; }
	.scan-step-footer { display: flex; justify-content: flex-end; margin-top: 20px; padding-top: 14px; border-top: 1px solid #e2e8f0; }
	@media (max-width: 480px) { .bill-scan-step { padding: 12px; } .scan-options button, .scan-step-footer button { flex: 1; } }
</style>
