<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { compressImage } from '$lib/utils/imageCompression';
	let requests: any[] = [], activeRequest: any = null, photoDataUrl = '', errorMessage = '', successMessage = '';
	let saving = false, loading = true, fileInput: HTMLInputElement, channel: any = null;
	async function loadRequests() {
		if (!$currentUser?.id) { loading = false; return; }
		const { data, error } = await supabase.from('pos_scan_requests').select('id, receiving_record_id, request_type, request_label, created_at').eq('requested_by', $currentUser.id).in('request_type', ['receiving_bank_slip', 'pay_to_credit_slip']).eq('status', 'pending').order('created_at');
		if (!error) requests = data || []; else errorMessage = error.message; loading = false;
	}
	async function selectPhoto(event: Event) {
		const file = (event.target as HTMLInputElement).files?.[0]; if (!file) return;
		try { photoDataUrl = await compressImage(file); } catch { photoDataUrl = await new Promise<string>((resolve, reject) => { const r = new FileReader(); r.onload = () => resolve(String(r.result)); r.onerror = reject; r.readAsDataURL(file); }); }
	}
	async function uploadSlip() {
		if (!activeRequest?.id || !photoDataUrl || saving) return;
		saving = true; errorMessage = ''; successMessage = '';
		try {
			if (activeRequest.request_type === 'pay_to_credit_slip') {
				const blob = await (await fetch(photoDataUrl)).blob();
				const extension = blob.type.split('/')[1]?.replace('jpeg', 'jpg') || 'jpg';
				const storagePath = `${activeRequest.id}-${Date.now()}.${extension}`;
				const { error: uploadError } = await supabase.storage.from('pos-scan-photos').upload(storagePath, blob, { contentType: blob.type, upsert: false });
				if (uploadError) throw uploadError;
				const { data: publicUrlData } = supabase.storage.from('pos-scan-photos').getPublicUrl(storagePath);
				const { error: requestError } = await supabase.from('pos_scan_requests').update({
					status: 'completed', photo_url: publicUrlData.publicUrl, completed_by: $currentUser?.id,
					completed_at: new Date().toISOString(), updated_at: new Date().toISOString()
				}).eq('id', activeRequest.id);
				if (requestError) {
					await supabase.storage.from('pos-scan-photos').remove([storagePath]);
					throw requestError;
				}
				requests = requests.filter((item) => item.id !== activeRequest.id); activeRequest = null; photoDataUrl = '';
				successMessage = $currentLocale === 'ar' ? 'تم رفع إيصال الدفع وإرساله إلى معاملة الدفع للمورد.' : 'Payment slip uploaded and sent to the Pay to Credit transaction.';
				return;
			}
			if (!activeRequest.receiving_record_id) throw new Error('Receiving record is missing.');
			const blob = await (await fetch(photoDataUrl)).blob(); const extension = blob.type.split('/')[1]?.replace('jpeg', 'jpg') || 'jpg'; const storagePath = `${activeRequest.receiving_record_id}/${crypto.randomUUID()}.${extension}`;
			const { data: oldSlip, error: oldError } = await supabase.from('receiving_record_bank_slips').select('storage_path').eq('receiving_record_id', activeRequest.receiving_record_id).maybeSingle(); if (oldError) throw oldError;
			const { error: uploadError } = await supabase.storage.from('receiving-bank-slips').upload(storagePath, blob, { contentType: blob.type, upsert: false }); if (uploadError) throw uploadError;
			const { error: saveError } = await supabase.from('receiving_record_bank_slips').upsert({ receiving_record_id: activeRequest.receiving_record_id, storage_path: storagePath, original_file_name: `bank-slip-${Date.now()}.${extension}`, file_mime_type: blob.type, file_size: blob.size, check_result: null, uploaded_by: $currentUser?.id }, { onConflict: 'receiving_record_id' });
			if (saveError) { await supabase.storage.from('receiving-bank-slips').remove([storagePath]); throw saveError; }
			const { error: requestError } = await supabase.from('pos_scan_requests').update({ status: 'completed', completed_by: $currentUser?.id, completed_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', activeRequest.id); if (requestError) throw requestError;
			if (oldSlip?.storage_path) await supabase.storage.from('receiving-bank-slips').remove([oldSlip.storage_path]);
			requests = requests.filter((item) => item.id !== activeRequest.id); activeRequest = null; photoDataUrl = '';
		} catch (error: any) { errorMessage = error?.message || 'Upload failed'; } finally { saving = false; }
	}
	onMount(() => { loadRequests(); if ($currentUser?.id) channel = supabase.channel(`mobile-receiving-slips-${$currentUser.id}`).on('postgres_changes', { event: '*', schema: 'public', table: 'pos_scan_requests', filter: `requested_by=eq.${$currentUser.id}` }, loadRequests).subscribe(); });
	onDestroy(() => { if (channel) supabase.removeChannel(channel); });
</script>
<input bind:this={fileInput} type="file" accept="image/*" capture="environment" class="hidden" on:change={selectPhoto} />
<div class="p-4 min-h-full bg-slate-50" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<h2 class="text-xl font-bold mb-4">{$currentLocale === 'ar' ? 'طلبات إيصالات البنك' : 'Bank Slip Requests'}</h2>
	{#if successMessage}<div class="mb-3 p-3 rounded-lg bg-emerald-50 text-emerald-700 font-semibold">{successMessage}</div>{/if}
	{#if errorMessage}<div class="mb-3 p-3 rounded-lg bg-red-50 text-red-700">{errorMessage}</div>{/if}
	{#if !activeRequest}
		{#if loading}<p class="text-slate-500">Loading...</p>{:else if requests.length === 0}<p class="text-slate-500">{$currentLocale === 'ar' ? 'لا توجد طلبات حاليًا' : 'No bank slip requests right now'}</p>{:else}<div class="space-y-3">{#each requests as request (request.id)}<button class="w-full p-4 bg-white border border-slate-200 rounded-xl text-left shadow-sm" on:click={() => { activeRequest = request; photoDataUrl = ''; errorMessage = ''; }}><div class="font-bold">📄 {request.request_label || 'Bank Slip'}</div><div class="text-xs text-slate-500 mt-1">{new Date(request.created_at).toLocaleString()}</div></button>{/each}</div>{/if}
	{:else}
		<button class="mb-4 text-blue-600 font-semibold" on:click={() => { activeRequest = null; photoDataUrl = ''; }}>← {$currentLocale === 'ar' ? 'رجوع' : 'Back'}</button>
		<div class="p-4 bg-white border border-slate-200 rounded-xl"><h3 class="font-bold mb-3">{activeRequest.request_label}</h3>{#if photoDataUrl}<img src={photoDataUrl} alt="Bank slip" class="w-full max-h-[55vh] object-contain rounded-lg mb-4" />{/if}<button class="w-full p-3 rounded-lg bg-blue-600 text-white font-bold mb-3" on:click={() => { fileInput.value = ''; fileInput.click(); }}>{photoDataUrl ? ($currentLocale === 'ar' ? 'إعادة التصوير' : 'Retake / Choose Again') : ($currentLocale === 'ar' ? 'تصوير إيصال البنك' : 'Take Bank Slip Photo')}</button>{#if photoDataUrl}<button class="w-full p-3 rounded-lg bg-emerald-600 text-white font-bold disabled:opacity-50" on:click={uploadSlip} disabled={saving}>{saving ? 'Uploading...' : ($currentLocale === 'ar' ? 'رفع الإيصال' : 'Upload Slip')}</button>{/if}</div>
	{/if}
</div>
