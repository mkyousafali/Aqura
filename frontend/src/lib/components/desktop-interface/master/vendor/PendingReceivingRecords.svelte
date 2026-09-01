<!-- PendingReceivingRecords.svelte -->
<!-- Records saved from Start Receiving with a bill type other than "Original Bill".
     Styled like ReceivingRecords.svelte, trimmed to what actually applies before a
     record is finalized: no "mark as paid" / due-date countdown, since no
     vendor_payment_schedule row exists until a record is cleared (see finalize_pending_receiving_record). -->
<script>
	import { onMount } from 'svelte';
	import { _ as t, t as tFn, currentLocale } from '$lib/i18n';
	import { compressImage } from '$lib/utils/imageCompression';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import StartReceiving from '$lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte';

	let records = [];
	let branches = [];
	let loading = false;

	let selectedBranchFilter = '';
	let vendorSearchTerm = '';
	let billDateFilterMode = '';
	let billDateFrom = '';
	let billDateTo = '';

	let uploadingBillId = null;
	let uploadingExcelId = null;
	let deletingRecordId = null;

	$: isMasterAdmin = $currentUser?.isMasterAdmin;

	const BILL_TYPE_LABELS = {
		delivery_note: { icon: '🚚', key: 'billTypeDeliveryNote' },
		duplicate_bill: { icon: '📄', key: 'billTypeDuplicateBill' },
		without_bill: { icon: '🚫', key: 'billTypeWithoutBill' }
	};

	onMount(() => {
		loadBranches();
		loadRecords();
	});

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			if (!error && data) branches = data;
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadRecords() {
		loading = true;
		try {
			const rpcParams = {
				p_limit: 500,
				p_offset: 0,
				p_branch_id: selectedBranchFilter || null,
				p_vendor_search: vendorSearchTerm?.trim() || null,
				p_bill_date_from: billDateFilterMode === 'specific' ? (billDateFrom || null) : (billDateFilterMode === 'period' ? (billDateFrom || null) : null),
				p_bill_date_to: billDateFilterMode === 'specific' ? (billDateFrom || null) : (billDateFilterMode === 'period' ? (billDateTo || null) : null)
			};

			const { data, error } = await supabase.rpc('get_pending_receiving_records_with_details', rpcParams);
			if (error) throw error;

			records = (data || []).map(r => ({
				id: r.id,
				bill_number: r.bill_number,
				vendor_id: r.vendor_id,
				branch_id: r.branch_id,
				bill_date: r.bill_date,
				bill_amount: r.bill_amount,
				created_at: r.created_at,
				user_id: r.user_id,
				original_bill_url: r.original_bill_url,
				erp_purchase_invoice_reference: r.erp_purchase_invoice_reference,
				certificate_url: r.certificate_url,
				pr_excel_file_url: r.pr_excel_file_url,
				final_bill_amount: r.final_bill_amount,
				payment_method: r.payment_method,
				credit_period: r.credit_period,
				bank_name: r.bank_name,
				iban: r.iban,
				bill_document_type: r.bill_document_type,
				status: r.status,
				branches: r.branch_name_en ? {
					name_en: r.branch_name_en,
					name_ar: r.branch_name_ar || r.branch_name_en,
					location_en: r.branch_location_en || '',
					location_ar: r.branch_location_ar || r.branch_location_en || ''
				} : null,
				vendors: r.vendor_name ? { erp_vendor_id: r.vendor_id, vendor_name: r.vendor_name, vat_number: r.vat_number, branch_id: r.branch_id } : null,
				users: r.username ? {
					username: r.username,
					hr_employees: { name_en: r.user_display_name_en || r.user_display_name || r.username, name_ar: r.user_display_name_ar || r.user_display_name || r.username }
				} : null
			}));
		} catch (err) {
			console.error('Error loading pending receiving records:', err);
			records = [];
		} finally {
			loading = false;
		}
	}

	let vendorSearchTimer = null;
	function onFilterChange() { loadRecords(); }
	function onVendorSearchInput() {
		if (vendorSearchTimer) clearTimeout(vendorSearchTimer);
		vendorSearchTimer = setTimeout(loadRecords, 500);
	}
	function onBillDateModeChange() {
		if (!billDateFilterMode) { billDateFrom = ''; billDateTo = ''; loadRecords(); }
		else if (billDateFilterMode === 'specific') { billDateTo = ''; }
	}
	function applyBillDateFilter() {
		if (billDateFilterMode === 'specific' && !billDateFrom) return;
		if (billDateFilterMode === 'period' && !billDateFrom && !billDateTo) return;
		loadRecords();
	}

	function getBranchName(record, locale) {
		if (locale === 'ar') return record.branches?.name_ar || record.branches?.name_en || tFn('receiving.records.naText');
		return record.branches?.name_en || tFn('receiving.records.naText');
	}
	function getReceivedByName(record, locale) {
		const employee = record.users?.hr_employees;
		if (locale === 'ar') return employee?.name_ar || employee?.name_en || record.users?.username || tFn('receiving.records.naText');
		return employee?.name_en || record.users?.username || tFn('receiving.records.naText');
	}
	function translatePaymentMethod(method) {
		if (!method) return tFn('receiving.records.naText');
		const map = { 'Cash on Delivery': 'receiving.cashOnDelivery', 'Bank on Delivery': 'receiving.bankOnDelivery', 'Cash Credit': 'receiving.cashCredit', 'Bank Credit': 'receiving.bankCredit' };
		const key = map[method];
		return key ? tFn(key) : method;
	}
	function formatDate(dateString) {
		if (!dateString) return tFn('receiving.records.naText');
		try {
			const date = new Date(dateString);
			return `${date.getDate().toString().padStart(2, '0')}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getFullYear()}`;
		} catch { return tFn('receiving.records.invalidDate'); }
	}
	function formatDateTime(dateTimeString) {
		if (!dateTimeString) return 'N/A';
		try {
			const date = new Date(dateTimeString);
			return `${formatDate(dateTimeString)} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
		} catch { return 'Invalid Date'; }
	}

	function viewCertificate(url) { if (url) window.open(url, '_blank'); }
	function viewOriginalBill(url) { if (url) window.open(url, '_blank'); }
	function isPdfFile(url) { return !!url && url.toLowerCase().includes('.pdf'); }

	async function uploadOriginalBill(recordId) {
		uploadingBillId = recordId;
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) { uploadingBillId = null; return; }
			try {
				let uploadFile = file;
				let fileExt = file.name.split('.').pop();
				if (file.type.startsWith('image/')) {
					try {
						const compressed = await compressImage(file);
						const res = await fetch(compressed);
						const blob = await res.blob();
						uploadFile = new File([blob], file.name.replace(/\.[^.]+$/, '.jpg'), { type: 'image/jpeg' });
						fileExt = 'jpg';
					} catch { /* fallback to original */ }
				}
				const fileName = `${recordId}_original_bill_${Date.now()}.${fileExt}`;
				const { error: uploadError } = await supabase.storage.from('original-bills').upload(fileName, uploadFile);
				if (uploadError) { alert(tFn('receiving.records.errorUploadFile')); return; }
				const { data: { publicUrl } } = supabase.storage.from('original-bills').getPublicUrl(fileName);
				const { error: updateError } = await supabase.from('pending_receiving_records').update({ original_bill_url: publicUrl }).eq('id', recordId);
				if (updateError) { alert(tFn('receiving.records.errorSaveFileRef')); return; }
				await loadRecords();
			} catch (err) {
				console.error(err);
				alert(tFn('receiving.records.errorUploadFile'));
			} finally {
				uploadingBillId = null;
			}
		};
		fileInput.click();
	}

	async function uploadPRExcel(recordId) {
		uploadingExcelId = recordId;
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.xlsx,.xls,.csv';
		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) { uploadingExcelId = null; return; }
			try {
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_pr_excel_${Date.now()}.${fileExt}`;
				const { error: uploadError } = await supabase.storage.from('pr-excel-files').upload(fileName, file);
				if (uploadError) { alert(tFn('receiving.records.errorUploadPrExcel')); return; }
				const { data: { publicUrl } } = supabase.storage.from('pr-excel-files').getPublicUrl(fileName);
				const { error: updateError } = await supabase.from('pending_receiving_records').update({ pr_excel_file_url: publicUrl }).eq('id', recordId);
				if (updateError) { alert(tFn('receiving.records.errorSavePrExcelRef')); return; }
				await loadRecords();
			} catch (err) {
				console.error(err);
				alert(tFn('receiving.records.errorUploadPrExcel'));
			} finally {
				uploadingExcelId = null;
			}
		};
		fileInput.click();
	}

	async function deletePendingRecord(recordId) {
		if (!isMasterAdmin) { alert(tFn('receiving.records.onlyMasterAdmin')); return; }
		const record = records.find(r => r.id === recordId);
		if (!confirm(tFn('receiving.records.confirmDelete', { bill: record?.bill_number || tFn('receiving.records.naText'), vendor: record?.vendors?.vendor_name || tFn('receiving.records.naText') }))) return;
		try {
			deletingRecordId = recordId;
			const { error } = await supabase.from('pending_receiving_records').delete().eq('id', recordId);
			if (error) throw error;
			records = records.filter(r => r.id !== recordId);
		} catch (err) {
			console.error('Error deleting pending receiving record:', err);
			alert(tFn('receiving.records.deleteFailed', { error: err.message }));
		} finally {
			deletingRecordId = null;
		}
	}

	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Opens the real Start Receiving window pre-filled at Step 3 for this record.
	// On completion it posts to receiving_records and marks this row Cleared.
	function openFinalReceiving(record) {
		const windowId = generateWindowId('start-receiving-final');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		openWindow({
			id: windowId,
			title: `${tFn('receiving.finalReceiving') || 'Final Receiving'} #${instanceNumber}`,
			component: StartReceiving,
			componentName: 'StartReceiving',
			icon: '📦',
			size: { width: 1200, height: 800 },
			position: { x: 100 + Math.random() * 100, y: 100 + Math.random() * 100 },
			resizable: true,
			minimizable: true,
			props: {
				windowId,
				finalReceivingPendingId: record.id
			}
		});
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">

	<div class="px-8 pt-6">
		<div class="mb-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 items-start">
			<div class="min-w-0">
				<label for="pb-branch-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.dashboard.filterByBranch')}</label>
				<select id="pb-branch-filter" bind:value={selectedBranchFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">{$t('receiving.dashboard.allBranches')}</option>
					{#each branches as branch}
						<option value={branch.id}>{$currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}</option>
					{/each}
				</select>
			</div>
			<div class="min-w-0">
				<label for="pb-vendor-search" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.searchVendor')}</label>
				<input id="pb-vendor-search" type="text" bind:value={vendorSearchTerm} on:input={onVendorSearchInput} placeholder={$t('receiving.records.typeVendorName')} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all" />
			</div>
			<div class="min-w-0 xl:col-span-2">
				<label for="pb-bill-date-mode" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.billDateFilter')}</label>
				<div class="flex gap-2">
					<select id="pb-bill-date-mode" bind:value={billDateFilterMode} on:change={onBillDateModeChange} class="w-full min-w-0 px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 focus:ring-2 focus:ring-emerald-500 outline-none">
						<option value="">{$t('receiving.records.anyDate')}</option>
						<option value="specific">{$t('receiving.records.specificDate')}</option>
						<option value="period">{$t('receiving.records.datePeriod')}</option>
					</select>
					{#if billDateFilterMode}
						<input aria-label={$t('receiving.records.dateFrom')} type="date" bind:value={billDateFrom} class="min-w-0 px-3 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 focus:ring-2 focus:ring-emerald-500 outline-none" />
						{#if billDateFilterMode === 'period'}
							<input aria-label={$t('receiving.records.dateTo')} type="date" bind:value={billDateTo} min={billDateFrom || undefined} class="min-w-0 px-3 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 focus:ring-2 focus:ring-emerald-500 outline-none" />
						{/if}
						<button type="button" on:click={applyBillDateFilter} disabled={loading} class="px-4 py-2.5 text-sm font-bold text-white bg-emerald-600 rounded-xl hover:bg-emerald-700 disabled:opacity-50 transition-colors">{$t('receiving.records.apply')}</button>
					{/if}
				</div>
			</div>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 px-8 pb-6 relative overflow-hidden flex flex-col">
		<!-- Decorative blurred circles -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-amber-100/25 rounded-full blur-[120px] pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-indigo-100/20 rounded-full blur-[120px] pointer-events-none"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col w-full">
			<!-- Table Container (glassmorphism card) -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
				{#if loading}
					<div class="flex items-center justify-center py-20">
						<div class="w-8 h-8 border-4 border-amber-200 border-t-amber-600 rounded-full animate-spin"></div>
						<p class="ml-4 text-slate-500">{$t('receiving.records.loading') || 'Loading…'}</p>
					</div>
				{:else if records.length === 0}
					<div class="flex flex-col items-center justify-center py-20 gap-2">
						<span class="text-4xl">📭</span>
						<p class="text-slate-500 text-lg">{$t('receiving.records.noRecords') || 'No pending records'}</p>
					</div>
				{:else}
					<div class="overflow-x-auto flex-1">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-amber-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 bg-amber-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400 w-12">#</th>
									<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">Bill Type</th>
									<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('receiving.records.searchVendor') || 'Vendor'}</th>
									<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('receiving.dashboard.filterByBranch') || 'Branch'}</th>
									<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">Bill Info</th>
									<th class="px-3 py-3 text-right text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">Amount</th>
									<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">PR Excel</th>
									<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">Certificate</th>
									<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">Actions</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each records as record, i (record.id)}
									<tr class="hover:bg-amber-50/40 transition-colors duration-200 {i % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-3 py-3 text-sm text-center font-semibold text-slate-500">{i + 1}</td>
										<td class="px-3 py-3 text-sm">
											{#if record.bill_document_type && BILL_TYPE_LABELS[record.bill_document_type]}
												<span class="inline-flex items-center gap-1 text-xs font-bold text-amber-700 bg-amber-50 border border-amber-200 rounded-full px-2 py-1">
													{BILL_TYPE_LABELS[record.bill_document_type].icon}
													{$t('receiving.' + BILL_TYPE_LABELS[record.bill_document_type].key)}
												</span>
											{:else}—{/if}
										</td>
										<td class="px-3 py-3 text-sm text-slate-700">
											<div class="font-semibold text-slate-800">{record.vendors?.vendor_name || tFn('receiving.records.naText')}</div>
											{#if record.vendors?.vat_number}
												<div class="text-xs text-slate-400">VAT: {record.vendors.vat_number}</div>
											{/if}
										</td>
										<td class="px-3 py-3 text-sm text-slate-700">
											<div>{getBranchName(record, $currentLocale)}</div>
										</td>
										<td class="px-3 py-3 text-sm text-slate-700">
											{#if record.bill_number}
												<div class="font-semibold text-slate-800">#{record.bill_number}</div>
											{/if}
											<div class="text-xs text-slate-400">{$t('receiving.records.billDateLabel') || 'Bill:'} {formatDate(record.bill_date)}</div>
											<div class="text-xs text-slate-400">{$t('receiving.records.receivedLabel') || 'Recv:'} {formatDateTime(record.created_at)}</div>
											<div class="text-xs text-slate-400">{$t('receiving.records.byLabel') || 'By:'} {getReceivedByName(record, $currentLocale)}</div>
										</td>
										<td class="px-3 py-3 text-sm text-right font-mono font-bold text-slate-800">{(record.final_bill_amount ?? record.bill_amount ?? 0).toFixed(2)}</td>
										<td class="px-3 py-3 text-sm text-center">
											{#if record.pr_excel_file_url}
												<a href={record.pr_excel_file_url} target="_blank" rel="noopener" class="inline-flex flex-col items-center gap-0.5 text-blue-700 hover:text-blue-900">
													<span class="text-lg">📊</span><small>View</small>
												</a>
											{:else}
												<button type="button" class="inline-flex flex-col items-center gap-0.5 text-slate-400 hover:text-slate-600" disabled={uploadingExcelId === record.id} on:click={() => uploadPRExcel(record.id)}>
													<span class="text-lg">{uploadingExcelId === record.id ? '⏳' : '⬆️'}</span><small>Upload</small>
												</button>
											{/if}
										</td>
										<td class="px-3 py-3 text-sm text-center">
											{#if record.certificate_url}
												<button type="button" class="inline-flex flex-col items-center gap-0.5 text-emerald-700 hover:text-emerald-900" on:click={() => viewCertificate(record.certificate_url)}>
													<span class="text-lg">🧾</span><small>View</small>
												</button>
											{:else}
												<span class="text-slate-300 text-lg">—</span>
											{/if}
										</td>
										<td class="px-3 py-3 text-sm text-center">
											<div class="inline-flex items-center gap-1.5">
												<button
													type="button"
													class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-indigo-600 hover:bg-indigo-700 hover:shadow-lg transition-all duration-200"
													on:click={() => openFinalReceiving(record)}
												>
													✅ Final Receiving
												</button>
												{#if isMasterAdmin}
													<button
														type="button"
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110 disabled:opacity-50"
														disabled={deletingRecordId === record.id}
														on:click={() => deletePendingRecord(record.id)}
														title="Delete this pending record (Master Admin only)"
													>
														{deletingRecordId === record.id ? '…' : '🗑️'}
													</button>
												{/if}
											</div>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Footer -->
					<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
						{records.length} {records.length === 1 ? 'pending record' : 'pending records'}
					</div>
				{/if}
			</div>
		</div>
	</div>
</div>
