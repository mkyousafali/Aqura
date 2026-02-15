<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import XLSX from 'xlsx-js-style';

	interface STRequest {
		id: string;
		requester_user_id: string;
		branch_id: number;
		target_user_id: string;
		status: string;
		items: { barcode: string; product_name: string; quantity: number; photo_url: string | null; is_available?: boolean; available_qty?: number }[];
		document_url?: string | null;
		created_at: string;
		updated_at: string;
		// Joined
		requester_name?: string;
		target_name?: string;
		branch_name?: string;
	}

	let requests: STRequest[] = [];
	let loading = true;
	let error = '';

	// Caches
	let userCache: Record<string, string> = {};
	let branchCache: Record<number, { name: string; location: string }> = {};
	let imageCache: Record<string, string> = {};

	// Search & Filters
	let searchQuery = '';
	let filterStatus = '';
	let filterBranch = '';
	let filterDateFrom = '';
	let filterDateTo = '';

	// Derived: unique branches for dropdown
	$: branchOptions = [...new Set(requests.map(r => r.branch_name).filter(Boolean))] as string[];

	// Derived: filtered requests
	$: filteredRequests = requests.filter(r => {
		// Status filter
		if (filterStatus && r.status !== filterStatus) return false;
		// Branch filter
		if (filterBranch && r.branch_name !== filterBranch) return false;
		// Date range
		if (filterDateFrom) {
			const from = new Date(filterDateFrom);
			if (new Date(r.created_at) < from) return false;
		}
		if (filterDateTo) {
			const to = new Date(filterDateTo);
			to.setHours(23, 59, 59, 999);
			if (new Date(r.created_at) > to) return false;
		}
		// Search
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			const items = getItemsList(r.items);
			const matchesItems = items.some(item =>
				(item.barcode && item.barcode.toLowerCase().includes(q)) ||
				(item.product_name && item.product_name.toLowerCase().includes(q))
			);
			if (
				!(r.requester_name?.toLowerCase().includes(q)) &&
				!(r.target_name?.toLowerCase().includes(q)) &&
				!(r.branch_name?.toLowerCase().includes(q)) &&
				!(r.status?.toLowerCase().includes(q)) &&
				!matchesItems
			) return false;
		}
		return true;
	});

	function clearFilters() {
		searchQuery = '';
		filterStatus = '';
		filterBranch = '';
		filterDateFrom = '';
		filterDateTo = '';
	}

	$: hasActiveFilters = searchQuery || filterStatus || filterBranch || filterDateFrom || filterDateTo;

	// Detail view
	let selectedRequest: STRequest | null = null;

	// Photo lightbox
	let lightboxUrl: string | null = null;

	// Document upload
	let uploadingDoc: string | null = null;

	// Editable availability items for detail view
	let editableItems: { barcode: string; product_name: string; quantity: number; photo_url: string | null; is_available: boolean; available_qty: number }[] = [];
	let savingAvailability = false;

	function getCachedImage(url: string | null): string | null {
		if (!url) return null;
		return imageCache[url] || url;
	}

	async function cacheImages(rows: STRequest[]) {
		const urls = new Set<string>();
		for (const r of rows) {
			const items = Array.isArray(r.items) ? r.items : [];
			for (const item of items) {
				if (item.photo_url && !imageCache[item.photo_url]) urls.add(item.photo_url);
			}
		}
		const promises = [...urls].map(async (url) => {
			try {
				const resp = await fetch(url);
				if (resp.ok) {
					const blob = await resp.blob();
					imageCache[url] = URL.createObjectURL(blob);
				}
			} catch { /* skip failed images */ }
		});
		await Promise.all(promises);
		imageCache = imageCache; // trigger reactivity
	}

	function exportToExcel() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		const headerStyle = { font: { bold: true, color: { rgb: 'FFFFFF' } }, fill: { fgColor: { rgb: '059669' } }, alignment: { horizontal: 'center' } };
		const wsData = [
			[{ v: '#', s: headerStyle }, { v: 'Barcode', s: headerStyle }, { v: 'Product Name', s: headerStyle }, { v: 'Quantity', s: headerStyle }],
			...items.map((item, i) => [i + 1, item.barcode || '', item.product_name || '', item.quantity])
		];
		const ws = XLSX.utils.aoa_to_sheet(wsData);
		ws['!cols'] = [{ wch: 5 }, { wch: 20 }, { wch: 35 }, { wch: 12 }];
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Stock Request');
		XLSX.writeFile(wb, `Stock_Request_${formatDate(selectedRequest.created_at).replace(/[^a-zA-Z0-9]/g, '_')}.xlsx`);
	}

	function printRequest() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		const printWindow = window.open('', '_blank', 'width=800,height=600');
		if (!printWindow) return;
		printWindow.document.write(`
			<html><head><title>Stock Request</title>
			<style>
				body { font-family: Arial, sans-serif; padding: 30px; }
				h2 { color: #059669; margin-bottom: 5px; }
				.info { display: flex; gap: 30px; margin: 15px 0; font-size: 14px; }
				.info div { background: #f8fafc; padding: 10px 15px; border-radius: 8px; }
				.info label { font-weight: bold; color: #64748b; font-size: 11px; text-transform: uppercase; display: block; }
				table { width: 100%; border-collapse: collapse; margin-top: 15px; }
				th { background: #059669; color: white; padding: 8px 12px; text-align: left; font-size: 12px; }
				td { padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }
				tr:nth-child(even) { background: #f8fafc; }
				img { width: 50px; height: 50px; object-fit: cover; border-radius: 6px; }
				@media print { body { padding: 10px; } }
			</style></head><body>
			<h2>📦 Stock Request</h2>
			<p style="color:#64748b;font-size:12px;">${formatDate(selectedRequest.created_at)} &bull; Status: ${selectedRequest.status.toUpperCase()}</p>
			<div class="info">
				<div><label>Branch</label>${selectedRequest.branch_name}</div>
				<div><label>Requester</label>${selectedRequest.requester_name}</div>
				<div><label>Manager</label>${selectedRequest.target_name}</div>
			</div>
			<table><thead><tr><th>#</th><th>Barcode</th><th>Product Name</th><th>Quantity</th><th>Photo</th></tr></thead>
			<tbody>${items.map((item, i) => `<tr><td>${i+1}</td><td>${item.barcode||'—'}</td><td>${item.product_name||'—'}</td><td>${item.quantity}</td><td>${item.photo_url ? `<img src="${item.photo_url}"/>` : '—'}</td></tr>`).join('')}</tbody></table>
			</body></html>
		`);
		printWindow.document.close();
		setTimeout(() => { printWindow.print(); }, 500);
	}

	onMount(() => {
		loadRequests();
	});

	onDestroy(() => {
		for (const blobUrl of Object.values(imageCache)) {
			if (blobUrl.startsWith('blob:')) URL.revokeObjectURL(blobUrl);
		}
	});

	async function loadRequests() {
		loading = true;
		error = '';
		try {
			const { data, error: err } = await supabase
				.from('product_request_st')
				.select('*')
				.order('created_at', { ascending: false });

			if (err) throw err;

			const rows = data || [];

			// Collect unique user IDs and branch IDs
			const userIds = new Set<string>();
			const branchIds = new Set<number>();
			for (const r of rows) {
				userIds.add(r.requester_user_id);
				userIds.add(r.target_user_id);
				if (r.branch_id) branchIds.add(r.branch_id);
			}

			// Batch fetch users from hr_employee_master
			const uncachedUsers = [...userIds].filter(id => !userCache[id]);
			if (uncachedUsers.length > 0) {
				const { data: employees } = await supabase
					.from('hr_employee_master')
					.select('user_id, name_en, name_ar')
					.in('user_id', uncachedUsers);
				for (const e of employees || []) {
					userCache[e.user_id] = $locale === 'ar' ? (e.name_ar || e.name_en || e.user_id) : (e.name_en || e.name_ar || e.user_id);
				}
			}

			// Batch fetch branches
			const uncachedBranches = [...branchIds].filter(id => !branchCache[id]);
			if (uncachedBranches.length > 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar')
					.in('id', uncachedBranches);
				for (const b of branches || []) {
					const name = $locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar);
					const location = $locale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '');
					branchCache[b.id] = { name, location };
				}
			}

			// Enrich rows
			requests = rows.map(r => {
				const branch = branchCache[r.branch_id];
				const branchDisplay = branch ? (branch.location ? `${branch.name} — ${branch.location}` : branch.name) : '—';
				return {
					...r,
					requester_name: userCache[r.requester_user_id] || r.requester_user_id,
					target_name: userCache[r.target_user_id] || r.target_user_id,
					branch_name: branchDisplay
				};
			});
			// Pre-cache images as blob URLs
			cacheImages(requests);
		} catch (err: any) {
			console.error('Error loading ST requests:', err);
			error = err?.message || 'Failed to load requests';
		} finally {
			loading = false;
		}
	}

	async function updateStatus(id: string, newStatus: 'approved' | 'rejected') {
		console.log('🔵 [ST] updateStatus called — id:', id, 'newStatus:', newStatus);
		try {
			const { error: err } = await supabase
				.from('product_request_st')
				.update({ status: newStatus, updated_at: new Date().toISOString() })
				.eq('id', id);
			if (err) throw err;
			console.log('🟢 [ST] Status updated in DB successfully');
			requests = requests.map(r => r.id === id ? { ...r, status: newStatus } : r);
			if (selectedRequest?.id === id) selectedRequest = { ...selectedRequest, status: newStatus };

			// Auto-complete linked quick tasks & send notification to requester
			const req = requests.find(r => r.id === id);
			console.log('🟡 [ST] Found request object:', req ? 'YES' : 'NO');
			console.log('🟡 [ST] req.requester_user_id:', req?.requester_user_id);
			console.log('🟡 [ST] Full req keys:', req ? Object.keys(req) : 'N/A');
			if (req) {
				// 1) Auto-complete linked quick tasks (non-blocking)
				try {
					console.log('🔵 [ST] Querying linked quick tasks...');
					const { data: linkedTasks, error: qtErr } = await supabase
						.from('quick_tasks')
						.select('id')
						.eq('product_request_id', id)
						.eq('product_request_type', 'ST');
					console.log('🔵 [ST] Quick tasks query result:', { linkedTasks, qtErr });

					if (linkedTasks && linkedTasks.length > 0) {
						const taskIds = linkedTasks.map(t => t.id);
						await supabase.from('quick_task_assignments')
							.update({ status: 'completed', completed_at: new Date().toISOString() })
							.in('quick_task_id', taskIds);
						await supabase.from('quick_tasks')
							.update({ status: 'completed', completed_at: new Date().toISOString() })
							.in('id', taskIds);
						console.log('✅ [ST] Quick tasks auto-completed');
					}
				} catch (taskErr) {
					console.warn('⚠️ [ST] Failed to complete quick tasks:', taskErr);
				}

				// 2) Send notification to requester (independent - always runs)
				console.log('🔵 [ST] === NOTIFICATION BLOCK START ===');
				try {
					const statusLabel = newStatus === 'approved' ? 'Accepted ✅' : 'Rejected ❌';
					const statusLabelAr = newStatus === 'approved' ? 'مقبول ✅' : 'مرفوض ❌';
					const notifPayload = {
						title: `ST Request ${statusLabel} | طلب ST ${statusLabelAr}`,
						message: `Your Stock Request has been ${newStatus}.\n---\nطلب المخزون الخاص بك تم ${newStatus === 'approved' ? 'قبوله' : 'رفضه'}.`,
						type: newStatus === 'approved' ? 'success' : 'error',
						priority: 'normal',
						target_type: 'specific_users',
						target_users: [req.requester_user_id],
						status: 'published',
						total_recipients: 1,
						created_at: new Date().toISOString()
					};
					console.log('📨 [ST] Notification payload:', JSON.stringify(notifPayload, null, 2));
					const { data: notifData, error: notifErr } = await supabase.from('notifications').insert(notifPayload).select();
					console.log('📨 [ST] Notification insert result — data:', notifData, 'error:', notifErr);
					if (notifErr) {
						console.error('❌ [ST] Notification insert failed:', notifErr);
					} else {
						console.log('✅ [ST] Notification sent successfully');
					}
				} catch (notifCatchErr) {
					console.error('⚠️ [ST] Notification CATCH error:', notifCatchErr);
				}
				console.log('🔵 [ST] === NOTIFICATION BLOCK END ===');
			} else {
				console.warn('🔴 [ST] req is falsy — cannot send notification! requests array length:', requests.length);
			}
		} catch (err: any) {
			console.error('🔴 [ST] OUTER catch — Error updating status:', err);
			alert('Failed to update status: ' + (err?.message || 'Unknown error'));
		}
	}

	function formatDate(dateStr: string) {
		if (!dateStr) return '—';
		const d = new Date(dateStr);
		return d.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', {
			year: 'numeric', month: 'short', day: 'numeric',
			hour: '2-digit', minute: '2-digit'
		});
	}

	function getStatusColor(status: string) {
		switch (status) {
			case 'pending': return 'bg-amber-100 text-amber-700 border-amber-200';
			case 'approved': return 'bg-emerald-100 text-emerald-700 border-emerald-200';
			case 'rejected': return 'bg-red-100 text-red-700 border-red-200';
			case 'completed': return 'bg-blue-100 text-blue-700 border-blue-200';
			default: return 'bg-slate-100 text-slate-600 border-slate-200';
		}
	}

	function getItemsCount(items: any): number {
		if (Array.isArray(items)) return items.length;
		try {
			const parsed = JSON.parse(items);
			return Array.isArray(parsed) ? parsed.length : 0;
		} catch { return 0; }
	}

	function getItemsList(items: any): { barcode: string; product_name: string; quantity: number; photo_url: string | null; is_available?: boolean; available_qty?: number }[] {
		if (Array.isArray(items)) return items;
		try {
			const parsed = JSON.parse(items);
			return Array.isArray(parsed) ? parsed : [];
		} catch { return []; }
	}

	function initEditableItems() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		editableItems = items.map(item => ({
			...item,
			is_available: item.is_available ?? false,
			available_qty: item.available_qty ?? 0
		}));
	}

	$: if (selectedRequest) initEditableItems();

	async function toggleAvailability(index: number) {
		editableItems[index].is_available = !editableItems[index].is_available;
		if (!editableItems[index].is_available) {
			editableItems[index].available_qty = 0;
		} else {
			editableItems[index].available_qty = editableItems[index].quantity;
		}
		editableItems = editableItems;
		await saveAvailability();
	}

	async function uploadDocForRequest(reqId: string, event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input?.files?.[0];
		if (!file) return;
		uploadingDoc = reqId;
		try {
			const path = `st/${reqId}/${Date.now()}_${file.name}`;
			const { error: upErr } = await supabase.storage.from('stock-documents').upload(path, file);
			if (upErr) throw upErr;
			const { data: urlData } = supabase.storage.from('stock-documents').getPublicUrl(path);
			const docUrl = urlData.publicUrl;
			const { error: dbErr } = await supabase.from('product_request_st').update({ document_url: docUrl, updated_at: new Date().toISOString() }).eq('id', reqId);
			if (dbErr) throw dbErr;
			requests = requests.map(r => r.id === reqId ? { ...r, document_url: docUrl } : r);
			if (selectedRequest?.id === reqId) selectedRequest = { ...selectedRequest, document_url: docUrl };
		} catch (err: any) {
			console.error('Upload error:', err);
			alert('Upload failed: ' + (err?.message || 'Unknown error'));
		} finally {
			uploadingDoc = null;
			if (input) input.value = '';
		}
	}

	async function saveAvailability() {
		if (!selectedRequest) return;
		savingAvailability = true;
		try {
			const updatedItems = editableItems.map(item => ({
				barcode: item.barcode,
				product_name: item.product_name,
				quantity: item.quantity,
				photo_url: item.photo_url,
				is_available: item.is_available,
				available_qty: item.available_qty
			}));
			const { error: err } = await supabase
				.from('product_request_st')
				.update({ items: updatedItems, updated_at: new Date().toISOString() })
				.eq('id', selectedRequest.id);
			if (err) throw err;
			selectedRequest.items = updatedItems;
			requests = requests.map(r => r.id === selectedRequest!.id ? { ...r, items: updatedItems } : r);
		} catch (err: any) {
			console.error('Error saving availability:', err);
			alert('Failed to save: ' + (err?.message || 'Unknown error'));
		} finally {
			savingAvailability = false;
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">📦</span>
			<h2 class="text-lg font-bold text-slate-800">{$t('nav.stockRequests') || 'Stock Requests'}</h2>
			<span class="text-xs font-semibold bg-emerald-100 text-emerald-600 px-3 py-1 rounded-full">{requests.length}</span>
		</div>
		<button
			class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
			on:click={loadRequests}
		>
			<span>🔄</span>
			{$t('finance.assets.refresh')}
		</button>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-hidden p-6">
		{#if selectedRequest}
			<!-- Detail View -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
				<div class="flex items-center justify-between mb-6">
					<div class="flex items-center gap-3">
						<button
							class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600"
							on:click={() => selectedRequest = null}
						>←</button>
						<h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
							<span>📦</span> Stock Request
						</h3>
						<span class="text-xs px-3 py-1 rounded-full border font-bold {getStatusColor(selectedRequest.status)}">{selectedRequest.status.toUpperCase()}</span>
					</div>
					<div class="flex items-center gap-2">
						<span class="text-xs text-slate-400">{formatDate(selectedRequest.created_at)}</span>
						<button
							class="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all text-xs shadow-lg shadow-emerald-200"
							on:click={exportToExcel}
						>
							<span>📥</span> Export Excel
						</button>
						<button
							class="flex items-center gap-1.5 px-4 py-2 bg-slate-600 text-white font-bold rounded-xl hover:bg-slate-700 transition-all text-xs shadow-lg shadow-slate-200"
							on:click={printRequest}
						>
							<span>🖨️</span> Print
						</button>
				</div>
			</div>

				<!-- Request Info -->
				<div class="grid grid-cols-3 gap-4 mb-6">
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">{$t('mobile.productRequestContent.branch') || 'Branch'}</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.branch_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">Requester</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.requester_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">{$t('mobile.productRequestContent.manager') || 'Manager'}</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.target_name}</p>
					</div>
				</div>

				<!-- Items Table -->
				<div class="flex-1 overflow-auto">
					<table class="w-full text-xs border-collapse border border-slate-300">
						<thead class="sticky top-0 z-10">
							<tr class="bg-emerald-600 text-white">
								<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">#</th>
								<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode')}</th>
								<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.productName')}</th>
								<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.quantity')}</th>
								<th class="border-r border-emerald-500 py-2.5 px-3 text-center font-bold">Availability</th>
								<th class="py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.photo')}</th>
							</tr>
						</thead>
						<tbody>
							{#each editableItems as item, i}
								<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
									<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{item.barcode || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{item.product_name || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 text-slate-600 font-mono">{item.quantity}</td>
									<td class="border-r border-slate-300 py-2 px-3">
										<div class="flex items-center gap-2 justify-center">
											<input type="checkbox" checked={item.is_available} on:change={() => toggleAvailability(i)} class="w-4 h-4 accent-emerald-600 cursor-pointer" />
											<input type="number" bind:value={item.available_qty} min="0" max={item.quantity} on:change={saveAvailability} class="w-14 px-1.5 py-0.5 border border-slate-300 rounded-lg text-center text-xs font-mono focus:outline-none focus:ring-2 focus:ring-emerald-400" />
										</div>
									</td>
									<td class="py-2 px-3">
										{#if item.photo_url}
										<img src={getCachedImage(item.photo_url)} alt="Product" class="w-14 h-14 object-cover rounded-lg border border-slate-200 cursor-pointer hover:opacity-80 transition-all hover:shadow-lg" on:click|stopPropagation={() => lightboxUrl = getCachedImage(item.photo_url)} />
										{:else}
											<span class="text-slate-400">—</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{:else}
			<!-- List View -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
				<!-- Search & Filters Bar -->
				<div class="flex flex-wrap items-center gap-2 mb-4">
					<!-- Search -->
					<div class="relative flex-1 min-w-[180px] max-w-[320px]">
						<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
						<input
							type="text"
							bind:value={searchQuery}
							placeholder={$locale === 'ar' ? 'بحث بالاسم، الفرع، الباركود...' : 'Search name, branch, barcode...'}
							class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all"
						/>
					</div>
					<!-- Status Filter -->
					<select bind:value={filterStatus} class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-400 cursor-pointer min-w-[110px]">
						<option value="">{$locale === 'ar' ? 'كل الحالات' : 'All Status'}</option>
						<option value="pending">{$locale === 'ar' ? 'قيد الانتظار' : 'Pending'}</option>
						<option value="approved">{$locale === 'ar' ? 'مقبول' : 'Approved'}</option>
						<option value="rejected">{$locale === 'ar' ? 'مرفوض' : 'Rejected'}</option>
						<option value="completed">{$locale === 'ar' ? 'مكتمل' : 'Completed'}</option>
					</select>
					<!-- Branch Filter -->
					<select bind:value={filterBranch} class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-400 cursor-pointer min-w-[120px]">
						<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
						{#each branchOptions as branch}
							<option value={branch}>{branch}</option>
						{/each}
					</select>
					<!-- Date From -->
					<div class="flex items-center gap-1">
						<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'من' : 'From'}</span>
						<input type="date" bind:value={filterDateFrom} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-400 cursor-pointer" />
					</div>
					<!-- Date To -->
					<div class="flex items-center gap-1">
						<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'إلى' : 'To'}</span>
						<input type="date" bind:value={filterDateTo} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-400 cursor-pointer" />
					</div>
					<!-- Clear Filters -->
					{#if hasActiveFilters}
						<button
							on:click={clearFilters}
							class="px-3 py-2 bg-red-50 hover:bg-red-100 text-red-600 rounded-xl text-xs font-bold transition-all"
						>
							✕ {$locale === 'ar' ? 'مسح' : 'Clear'}
						</button>
					{/if}
					<!-- Results count -->
					<span class="text-[10px] text-slate-400 font-semibold {$locale === 'ar' ? 'mr-auto' : 'ml-auto'}">
						{filteredRequests.length} / {requests.length}
					</span>
				</div>

				{#if loading}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4 animate-bounce">📦</div>
						<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.loading')}</p>
					</div>
				{:else if error}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">❌</div>
						<p class="text-red-500 font-semibold">{error}</p>
					</div>
				{:else if requests.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد طلبات مخزون' : 'No stock requests found'}</p>
					</div>
				{:else if filteredRequests.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">🔍</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}</p>
						<button on:click={clearFilters} class="mt-2 px-4 py-2 bg-emerald-50 text-emerald-600 rounded-xl text-xs font-bold hover:bg-emerald-100 transition-all">
							{$locale === 'ar' ? 'مسح الفلاتر' : 'Clear Filters'}
						</button>
					</div>
				{:else}
					<div class="flex-1 overflow-auto">
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-emerald-600 text-white">
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">#</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.branch') || 'Branch'}</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">Requester</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.manager') || 'Manager'}</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">Items</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">Status</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-left font-bold">Date</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-center font-bold">Docs</th>
									<th class="border-r border-emerald-500 py-2.5 px-3 text-center font-bold">Approve</th>
									<th class="py-2.5 px-3 text-center font-bold">Reject</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredRequests as req, i}
									<tr class="border-b border-slate-300 hover:bg-slate-50/50 cursor-pointer {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}" on:click={() => selectedRequest = req}>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-800">{req.branch_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-700">{req.requester_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-emerald-700">{req.target_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<button
												class="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-700 hover:text-emerald-900 text-[10px] font-bold whitespace-nowrap"
												on:click|stopPropagation={() => selectedRequest = req}
											>
												{getItemsCount(req.items)} — View
											</button>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<span class="text-[10px] px-2.5 py-1 rounded-full border font-bold {getStatusColor(req.status)}">{req.status.toUpperCase()}</span>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-500 text-[10px]">{formatDate(req.created_at)}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center" on:click|stopPropagation>
											{#if req.document_url}
												<div class="flex items-center gap-1 justify-center">
													<a href={req.document_url} target="_blank" rel="noopener" class="px-2 py-0.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg text-emerald-600 hover:text-emerald-800 text-[10px] font-bold" title="View Document">📄 View</a>
													<label class="px-2 py-0.5 bg-slate-100 hover:bg-slate-200 rounded-lg text-slate-600 hover:text-slate-800 text-[10px] font-bold cursor-pointer {uploadingDoc === req.id ? 'opacity-50 pointer-events-none' : ''}">
														🔄 {uploadingDoc === req.id ? '...' : 'Update'}
														<input type="file" class="hidden" on:change={(e) => uploadDocForRequest(req.id, e)} />
													</label>
												</div>
											{:else}
												<label class="px-2 py-1 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-700 text-[10px] font-bold cursor-pointer whitespace-nowrap {uploadingDoc === req.id ? 'opacity-50 pointer-events-none' : ''}">
													📎 {uploadingDoc === req.id ? '...' : 'Upload'}
													<input type="file" class="hidden" on:change={(e) => uploadDocForRequest(req.id, e)} on:click|stopPropagation />
												</label>
											{/if}
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center">
											{#if req.status === 'pending' && req.target_user_id === $currentUser?.id}
												<button
													class="p-1.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-600 hover:text-emerald-800"
													on:click|stopPropagation={() => updateStatus(req.id, 'approved')}
													title="Approve"
												>
													✅
												</button>
											{/if}
										</td>
										<td class="py-2.5 px-3 text-center">
											{#if req.status === 'pending' && req.target_user_id === $currentUser?.id}
												<button
													class="p-1.5 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-600 hover:text-red-800"
													on:click|stopPropagation={() => updateStatus(req.id, 'rejected')}
													title="Reject"
												>
													❌
												</button>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<!-- Photo Lightbox -->
{#if lightboxUrl}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm" on:click={() => lightboxUrl = null} role="button" tabindex="-1">
		<div class="relative max-w-[80vw] max-h-[80vh]">
			<img src={lightboxUrl} alt="Product" class="max-w-full max-h-[80vh] object-contain rounded-2xl shadow-2xl" />
			<button
				class="absolute -top-3 -right-3 w-8 h-8 bg-white text-slate-600 rounded-full text-sm font-bold flex items-center justify-center hover:bg-red-50 hover:text-red-600 transition-all shadow-lg"
				on:click|stopPropagation={() => lightboxUrl = null}
			>✕</button>
		</div>
	</div>
{/if}
