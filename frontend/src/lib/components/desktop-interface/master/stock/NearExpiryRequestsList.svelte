<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import XLSX from 'xlsx-js-style';

	interface NearExpiryReport {
		id: string;
		reporter_user_id: string;
		branch_id: number;
		target_user_id: string;
		title: string;
		status: string;
		items: { barcode: string; expiry_date: string; photo_url: string | null }[];
		notes: string | null;
		created_at: string;
		updated_at: string;
		// Joined
		requester_name?: string;
		target_name?: string;
		branch_name?: string;
	}

	let requests: NearExpiryReport[] = [];
	let loading = true;
	let error = '';

	// Caches
	let userCache: Record<string, string> = {};
	let branchCache: Record<number, { name: string; location: string }> = {};
	let imageCache: Record<string, string> = {};

	// Detail view
	let selectedRequest: NearExpiryReport | null = null;

	// Photo lightbox
	let lightboxUrl: string | null = null;

	// Filter
	let filterStatus = 'all';
	let searchQuery = '';
	let filterBranch = '';
	let filterDateFrom = '';
	let filterDateTo = '';

	function getCachedImage(url: string | null): string | null {
		if (!url) return null;
		return imageCache[url] || url;
	}

	async function cacheImages(rows: NearExpiryReport[]) {
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
		imageCache = imageCache;
	}

	function formatExpiryDateDisplay(dateStr: string): string {
		if (!dateStr) return '—';
		const parts = dateStr.split('-');
		if (parts.length === 3) {
			return `${parts[2]}-${parts[1]}-${parts[0]}`;
		}
		return dateStr;
	}

	function exportToExcel() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		const headerStyle = { font: { bold: true, color: { rgb: 'FFFFFF' } }, fill: { fgColor: { rgb: 'DC2626' } }, alignment: { horizontal: 'center' } };
		const wsData = [
			[
				{ v: 'Barcode', s: headerStyle },
				{ v: 'English name', s: headerStyle },
				{ v: 'Arabic name', s: headerStyle },
				{ v: 'Sales price', s: headerStyle },
				{ v: 'Unit', s: headerStyle },
				{ v: 'Cost (cost + VAT)', s: headerStyle },
				{ v: 'Expiry date (DD-MM-YYYY)', s: headerStyle }
			],
			...items.map((item) => [item.barcode || '', '', '', '', '', '', formatExpiryDateDisplay(item.expiry_date)])
		];
		const ws = XLSX.utils.aoa_to_sheet(wsData);
		ws['!cols'] = [{ wch: 18 }, { wch: 20 }, { wch: 20 }, { wch: 14 }, { wch: 10 }, { wch: 20 }, { wch: 24 }];
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Near Expiry Report');
		const titleSlug = (selectedRequest.title || 'report').replace(/[^a-zA-Z0-9\u0600-\u06FF ]/g, '_').substring(0, 40);
		XLSX.writeFile(wb, `NearExpiry_${titleSlug}.xlsx`);
	}

	function printRequest() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		const printWindow = window.open('', '_blank', 'width=800,height=600');
		if (!printWindow) return;
		printWindow.document.write(`
			<html><head><title>Near Expiry Report</title>
			<style>
				body { font-family: Arial, sans-serif; padding: 30px; }
				h2 { color: #DC2626; margin-bottom: 5px; }
				.subtitle { color: #64748b; font-size: 12px; margin-bottom: 15px; }
				.info { display: flex; gap: 30px; margin: 15px 0; font-size: 14px; }
				.info div { background: #f8fafc; padding: 10px 15px; border-radius: 8px; }
				.info label { font-weight: bold; color: #64748b; font-size: 11px; text-transform: uppercase; display: block; }
				table { width: 100%; border-collapse: collapse; margin-top: 15px; }
				th { background: #DC2626; color: white; padding: 8px 12px; text-align: left; font-size: 12px; }
				td { padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }
				tr:nth-child(even) { background: #f8fafc; }
				img { width: 50px; height: 50px; object-fit: cover; border-radius: 6px; }
				@media print { body { padding: 10px; } }
			</style></head><body>
			<h2>⏰ Near Expiry Report</h2>
			<p class="subtitle">${selectedRequest.title || '—'}</p>
			<p style="color:#64748b;font-size:12px;">${formatDate(selectedRequest.created_at)} &bull; Status: ${selectedRequest.status.toUpperCase()}</p>
			<div class="info">
				<div><label>Branch</label>${selectedRequest.branch_name || '—'}</div>
				<div><label>Reporter</label>${selectedRequest.requester_name || '—'}</div>
				<div><label>Manager</label>${selectedRequest.target_name || '—'}</div>
			</div>
			${selectedRequest.notes ? `<p style="margin:10px 0;padding:8px 12px;background:#FEF2F2;border-radius:8px;font-size:13px;color:#991B1B;"><strong>Notes:</strong> ${selectedRequest.notes}</p>` : ''}
			<table><thead><tr><th>#</th><th>Barcode</th><th>Expiry Date</th><th>Photo</th></tr></thead>
			<tbody>${items.map((item, i) => `<tr><td>${i+1}</td><td>${item.barcode||'—'}</td><td>${formatExpiryDateDisplay(item.expiry_date)}</td><td>${item.photo_url ? `<img src="${item.photo_url}"/>` : '—'}</td></tr>`).join('')}</tbody></table>
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
				.from('near_expiry_reports')
				.select('*')
				.order('created_at', { ascending: false });

			if (err) throw err;

			const rows = data || [];

			// Collect unique user IDs and branch IDs
			const userIds = new Set<string>();
			const branchIds = new Set<number>();
			for (const r of rows) {
				if (r.reporter_user_id) userIds.add(r.reporter_user_id);
				if (r.target_user_id) userIds.add(r.target_user_id);
				if (r.branch_id) branchIds.add(r.branch_id);
			}

			// Batch fetch users
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
					requester_name: userCache[r.reporter_user_id] || r.reporter_user_id,
					target_name: r.target_user_id ? (userCache[r.target_user_id] || r.target_user_id) : '—',
					branch_name: r.branch_id ? branchDisplay : '—'
				};
			});

			cacheImages(requests);
		} catch (err: any) {
			console.error('Error loading near expiry reports:', err);
			error = err?.message || 'Failed to load reports';
		} finally {
			loading = false;
		}
	}

	async function updateStatus(id: string, newStatus: 'reviewed' | 'resolved' | 'dismissed') {
		try {
			const { error: err } = await supabase
				.from('near_expiry_reports')
				.update({ status: newStatus, updated_at: new Date().toISOString() })
				.eq('id', id);
			if (err) throw err;

			requests = requests.map(r => r.id === id ? { ...r, status: newStatus } : r);
			if (selectedRequest?.id === id) selectedRequest = { ...selectedRequest, status: newStatus };

			const req = requests.find(r => r.id === id);
			if (req) {
				// Auto-complete linked quick tasks
				try {
					const { data: linkedTasks } = await supabase
						.from('quick_tasks')
						.select('id')
						.eq('product_request_id', id)
						.eq('product_request_type', 'EXPIRY');

					if (linkedTasks && linkedTasks.length > 0) {
						const taskIds = linkedTasks.map(t => t.id);
						await supabase.from('quick_task_assignments')
							.update({ status: 'completed', completed_at: new Date().toISOString() })
							.in('quick_task_id', taskIds);
						await supabase.from('quick_tasks')
							.update({ status: 'completed', completed_at: new Date().toISOString() })
							.in('id', taskIds);
					}
				} catch (taskErr) {
					console.warn('⚠️ Failed to complete quick tasks:', taskErr);
				}

				// Send notification to reporter
				try {
					const statusLabel = newStatus === 'resolved' ? 'Resolved ✅' : newStatus === 'reviewed' ? 'Reviewed 👁️' : 'Dismissed ❌';
					const statusLabelAr = newStatus === 'resolved' ? 'تم الحل ✅' : newStatus === 'reviewed' ? 'تمت المراجعة 👁️' : 'مرفوض ❌';
					await supabase.from('notifications').insert({
						title: `Near Expiry Report ${statusLabel} | تقرير قرب الانتهاء ${statusLabelAr}`,
						message: `Your near expiry report "${req.title || ''}" has been ${newStatus}.\n---\nتقرير قرب الانتهاء "${req.title || ''}" تم ${newStatus === 'resolved' ? 'حله' : newStatus === 'reviewed' ? 'مراجعته' : 'رفضه'}.`,
						type: newStatus === 'dismissed' ? 'error' : 'success',
						priority: 'normal',
						target_type: 'specific_users',
						target_users: [req.reporter_user_id],
						status: 'published',
						total_recipients: 1,
						created_at: new Date().toISOString()
					});
				} catch (notifErr) {
					console.warn('⚠️ Failed to send notification:', notifErr);
				}
			}
		} catch (err: any) {
			console.error('Error updating status:', err);
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
			case 'reviewed': return 'bg-blue-100 text-blue-700 border-blue-200';
			case 'resolved': return 'bg-emerald-100 text-emerald-700 border-emerald-200';
			case 'dismissed': return 'bg-red-100 text-red-700 border-red-200';
			default: return 'bg-slate-100 text-slate-600 border-slate-200';
		}
	}

	function getStatusLabel(status: string): string {
		switch (status) {
			case 'pending': return $locale === 'ar' ? 'معلق' : 'Pending';
			case 'reviewed': return $locale === 'ar' ? 'تمت المراجعة' : 'Reviewed';
			case 'resolved': return $locale === 'ar' ? 'تم الحل' : 'Resolved';
			case 'dismissed': return $locale === 'ar' ? 'مرفوض' : 'Dismissed';
			default: return status;
		}
	}

	function getItemsCount(items: any): number {
		if (Array.isArray(items)) return items.length;
		try {
			const parsed = JSON.parse(items);
			return Array.isArray(parsed) ? parsed.length : 0;
		} catch { return 0; }
	}

	function getItemsList(items: any): { barcode: string; expiry_date: string; photo_url: string | null }[] {
		if (Array.isArray(items)) return items;
		try {
			const parsed = JSON.parse(items);
			return Array.isArray(parsed) ? parsed : [];
		} catch { return []; }
	}

	$: branchOptions = [...new Set(requests.map(r => r.branch_name).filter(b => b && b !== '—'))] as string[];

	$: filteredRequests = requests.filter(r => {
		if (filterStatus !== 'all' && r.status !== filterStatus) return false;
		if (filterBranch && r.branch_name !== filterBranch) return false;
		if (filterDateFrom) {
			const from = new Date(filterDateFrom);
			if (new Date(r.created_at) < from) return false;
		}
		if (filterDateTo) {
			const to = new Date(filterDateTo);
			to.setHours(23, 59, 59, 999);
			if (new Date(r.created_at) > to) return false;
		}
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			const items = getItemsList(r.items);
			const matchesItems = items.some(item =>
				(item.barcode && item.barcode.toLowerCase().includes(q))
			);
			if (
				!(r.title?.toLowerCase().includes(q)) &&
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
		filterStatus = 'all';
		filterBranch = '';
		filterDateFrom = '';
		filterDateTo = '';
	}

	$: hasActiveFilters = searchQuery || filterStatus !== 'all' || filterBranch || filterDateFrom || filterDateTo;
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">⏰</span>
			<h2 class="text-lg font-bold text-slate-800">{$t('nav.nearExpiryRequests') || 'Near Expiry Reports'}</h2>
			<span class="text-xs font-semibold bg-red-100 text-red-600 px-3 py-1 rounded-full">{filteredRequests.length}</span>
		</div>
		<div class="flex items-center gap-2">
			<!-- Search -->
			<div class="relative min-w-[160px] max-w-[240px]">
				<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
				<input type="text" bind:value={searchQuery} placeholder={$locale === 'ar' ? 'بحث...' : 'Search...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-transparent transition-all" />
			</div>
			<!-- Status filter -->
			<select bind:value={filterStatus} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-red-400">
				<option value="all">{$locale === 'ar' ? 'الكل' : 'All'}</option>
				<option value="pending">{$locale === 'ar' ? 'معلق' : 'Pending'}</option>
				<option value="reviewed">{$locale === 'ar' ? 'تمت المراجعة' : 'Reviewed'}</option>
				<option value="resolved">{$locale === 'ar' ? 'تم الحل' : 'Resolved'}</option>
				<option value="dismissed">{$locale === 'ar' ? 'مرفوض' : 'Dismissed'}</option>
			</select>
			<!-- Branch filter -->
			<select bind:value={filterBranch} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-red-400 min-w-[110px]">
				<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
				{#each branchOptions as branch}
					<option value={branch}>{branch}</option>
				{/each}
			</select>
			<!-- Date range -->
			<div class="flex items-center gap-1">
				<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'من' : 'From'}</span>
				<input type="date" bind:value={filterDateFrom} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-red-400 cursor-pointer" />
			</div>
			<div class="flex items-center gap-1">
				<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'إلى' : 'To'}</span>
				<input type="date" bind:value={filterDateTo} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-red-400 cursor-pointer" />
			</div>
			{#if hasActiveFilters}
				<button on:click={clearFilters} class="px-3 py-2 bg-red-50 hover:bg-red-100 text-red-600 rounded-xl text-xs font-bold transition-all">✕ {$locale === 'ar' ? 'مسح' : 'Clear'}</button>
			{/if}
			<span class="text-[10px] text-slate-400 font-semibold">{filteredRequests.length} / {requests.length}</span>
			<button
				class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
				on:click={loadRequests}
			>
				<span>🔄</span>
				{$t('finance.assets.refresh')}
			</button>
		</div>
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
							<span>⏰</span> {selectedRequest.title || ($locale === 'ar' ? 'تقرير قرب الانتهاء' : 'Near Expiry Report')}
						</h3>
						<span class="text-xs px-3 py-1 rounded-full border font-bold {getStatusColor(selectedRequest.status)}">{getStatusLabel(selectedRequest.status)}</span>
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
						{#if selectedRequest.status === 'pending'}
							<button
								class="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white font-bold rounded-xl hover:bg-blue-700 transition-all text-xs shadow-lg shadow-blue-200"
								on:click={() => updateStatus(selectedRequest.id, 'reviewed')}
							>
								<span>👁️</span> {$locale === 'ar' ? 'مراجعة' : 'Review'}
							</button>
							<button
								class="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all text-xs shadow-lg shadow-emerald-200"
								on:click={() => updateStatus(selectedRequest.id, 'resolved')}
							>
								<span>✅</span> {$locale === 'ar' ? 'حل' : 'Resolve'}
							</button>
							<button
								class="flex items-center gap-1.5 px-4 py-2 bg-red-600 text-white font-bold rounded-xl hover:bg-red-700 transition-all text-xs shadow-lg shadow-red-200"
								on:click={() => updateStatus(selectedRequest.id, 'dismissed')}
							>
								<span>❌</span> {$locale === 'ar' ? 'رفض' : 'Dismiss'}
							</button>
						{/if}
						{#if selectedRequest.status === 'reviewed'}
							<button
								class="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all text-xs shadow-lg shadow-emerald-200"
								on:click={() => updateStatus(selectedRequest.id, 'resolved')}
							>
								<span>✅</span> {$locale === 'ar' ? 'حل' : 'Resolve'}
							</button>
							<button
								class="flex items-center gap-1.5 px-4 py-2 bg-red-600 text-white font-bold rounded-xl hover:bg-red-700 transition-all text-xs shadow-lg shadow-red-200"
								on:click={() => updateStatus(selectedRequest.id, 'dismissed')}
							>
								<span>❌</span> {$locale === 'ar' ? 'رفض' : 'Dismiss'}
							</button>
						{/if}
					</div>
				</div>

				<!-- Request Info -->
				<div class="grid grid-cols-3 gap-4 mb-6">
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">{$t('mobile.productRequestContent.branch') || 'Branch'}</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.branch_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">{$locale === 'ar' ? 'المُبلِّغ' : 'Reporter'}</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.requester_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">{$t('mobile.productRequestContent.manager') || 'Manager'}</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.target_name}</p>
					</div>
				</div>

				<!-- Notes -->
				{#if selectedRequest.notes}
					<div class="bg-red-50 border border-red-200 rounded-xl p-4 mb-4">
						<span class="text-xs text-red-400 font-bold uppercase">{$locale === 'ar' ? 'ملاحظات' : 'Notes'}</span>
						<p class="text-sm text-red-800 mt-1">{selectedRequest.notes}</p>
					</div>
				{/if}

				<!-- Items Table -->
				<div class="flex-1 overflow-auto">
					<table class="w-full text-xs border-collapse border border-slate-300">
						<thead class="sticky top-0 z-10">
							<tr class="bg-red-600 text-white">
								<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">#</th>
								<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode') || 'Barcode'}</th>
								<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'}</th>
								<th class="py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.photo') || 'Photo'}</th>
							</tr>
						</thead>
						<tbody>
							{#each getItemsList(selectedRequest.items) as item, i}
								<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
									<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{item.barcode || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-semibold text-red-700">{formatExpiryDateDisplay(item.expiry_date)}</td>
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
				{#if loading}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4 animate-bounce">⏰</div>
						<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.loading') || 'Loading...'}</p>
					</div>
				{:else if error}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">❌</div>
						<p class="text-red-500 font-semibold">{error}</p>
					</div>
				{:else if filteredRequests.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد تقارير' : 'No near expiry reports found'}</p>
					</div>
				{:else}
					<div class="flex-1 overflow-auto">
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-red-600 text-white">
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">#</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'العنوان' : 'Title'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.branch') || 'Branch'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'المُبلِّغ' : 'Reporter'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.manager') || 'Manager'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'المنتجات' : 'Items'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'الحالة' : 'Status'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'التاريخ' : 'Date'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'مراجعة' : 'Review'}</th>
									<th class="border-r border-red-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'حل' : 'Resolve'}</th>
									<th class="py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'رفض' : 'Dismiss'}</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredRequests as req, i}
									<tr class="border-b border-slate-300 hover:bg-slate-50/50 cursor-pointer {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}" on:click={() => selectedRequest = req}>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-bold text-slate-800 max-w-[180px] truncate" title={req.title}>{req.title || '—'}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-800">{req.branch_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-700">{req.requester_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-emerald-700">{req.target_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<button
												class="px-2.5 py-1 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-700 hover:text-red-900 text-[10px] font-bold whitespace-nowrap"
												on:click|stopPropagation={() => selectedRequest = req}
											>
												{getItemsCount(req.items)} — {$locale === 'ar' ? 'عرض' : 'View'}
											</button>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<span class="text-[10px] px-2.5 py-1 rounded-full border font-bold {getStatusColor(req.status)}">{getStatusLabel(req.status)}</span>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-500 text-[10px]">{formatDate(req.created_at)}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center">
											{#if req.status === 'pending'}
												<button
													class="p-1.5 bg-blue-50 hover:bg-blue-100 rounded-lg transition-all text-blue-600 hover:text-blue-800"
													on:click|stopPropagation={() => updateStatus(req.id, 'reviewed')}
													title="Review"
												>👁️</button>
											{/if}
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center">
											{#if req.status === 'pending' || req.status === 'reviewed'}
												<button
													class="p-1.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-600 hover:text-emerald-800"
													on:click|stopPropagation={() => updateStatus(req.id, 'resolved')}
													title="Resolve"
												>✅</button>
											{/if}
										</td>
										<td class="py-2.5 px-3 text-center">
											{#if req.status === 'pending' || req.status === 'reviewed'}
												<button
													class="p-1.5 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-600 hover:text-red-800"
													on:click|stopPropagation={() => updateStatus(req.id, 'dismissed')}
													title="Dismiss"
												>❌</button>
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
