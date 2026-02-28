<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import XLSX from 'xlsx-js-style';

	interface CustomerRequest {
		id: string;
		requester_user_id: string;
		branch_id: number;
		target_user_id: string;
		status: string;
		items: { product_name: string; image_url: string | null }[];
		notes: string | null;
		created_at: string;
		updated_at: string;
		// Joined
		requester_name?: string;
		target_name?: string;
		branch_name?: string;
	}

	let requests: CustomerRequest[] = [];
	let loading = true;
	let error = '';

	let lightboxUrl: string | null = null;
	let filterStatus = 'all';
	let arrivedSet: Set<string> = new Set();
	let searchQuery = '';
	let filterBranch = '';
	let filterDateFrom = '';
	let filterDateTo = '';

	interface FlatItem {
		requestId: string;
		product_name: string;
		image_url: string | null;
		requester_name: string;
		target_name: string;
		branch_name: string;
		status: string;
		created_at: string;
		requester_user_id: string;
	}

	function exportToExcel() {
		const items = flatItems;
		if (items.length === 0) return;
		const headerStyle = { font: { bold: true, color: { rgb: 'FFFFFF' } }, fill: { fgColor: { rgb: '7C3AED' } }, alignment: { horizontal: 'center' } };
		const wsData = [
			[
				{ v: '#', s: headerStyle },
				{ v: 'Product Name', s: headerStyle },
				{ v: 'Image URL', s: headerStyle },
				{ v: 'Requester', s: headerStyle },
				{ v: 'Branch', s: headerStyle },
				{ v: 'Status', s: headerStyle },
				{ v: 'Date', s: headerStyle }
			],
			...items.map((item, i) => [i + 1, item.product_name || '', item.image_url || '', item.requester_name, item.branch_name, item.status, formatDate(item.created_at)])
		];
		const ws = XLSX.utils.aoa_to_sheet(wsData);
		ws['!cols'] = [{ wch: 5 }, { wch: 35 }, { wch: 60 }, { wch: 20 }, { wch: 20 }, { wch: 12 }, { wch: 22 }];
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Customer Requests');
		XLSX.writeFile(wb, `CustomerRequests_${new Date().toISOString().slice(0,10)}.xlsx`);
	}

	function printAllItems() {
		const items = flatItems;
		if (items.length === 0) return;
		const printWindow = window.open('', '_blank', 'width=900,height=600');
		if (!printWindow) return;
		printWindow.document.write(`
			<html><head><title>Customer Product Requests</title>
			<style>
				body { font-family: Arial, sans-serif; padding: 20px; }
				h2 { color: #7C3AED; margin-bottom: 10px; }
				table { width: 100%; border-collapse: collapse; margin-top: 10px; }
				th { background: #7C3AED; color: white; padding: 6px 10px; text-align: left; font-size: 11px; }
				td { padding: 6px 10px; border-bottom: 1px solid #e2e8f0; font-size: 12px; }
				tr:nth-child(even) { background: #f8fafc; }
				img { width: 40px; height: 40px; object-fit: cover; border-radius: 4px; }
				.badge { padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: bold; }
				@media print { body { padding: 10px; } }
			</style></head><body>
			<h2>🛍️ Customer Product Requests (${items.length} items)</h2>
			<table><thead><tr><th>#</th><th>Product</th><th>Image</th><th>Requester</th><th>Branch</th><th>Status</th><th>Date</th></tr></thead>
			<tbody>${items.map((item, i) => `<tr><td>${i+1}</td><td>${item.product_name||'—'}</td><td>${item.image_url ? `<img src="${item.image_url}"/>` : '—'}</td><td>${item.requester_name}</td><td>${item.branch_name}</td><td>${item.status}</td><td>${formatDate(item.created_at)}</td></tr>`).join('')}</tbody></table>
			</body></html>
		`);
		printWindow.document.close();
		setTimeout(() => { printWindow.print(); }, 500);
	}

	onMount(() => {
		loadRequests();
	});

	async function loadRequests() {
		loading = true;
		error = '';
		try {
			// Single RPC call replaces 3 separate queries (requests + employees + branches)
			const { data, error: err } = await supabase.rpc('get_customer_requests_with_details');

			if (err) throw err;

			const rows = data || [];
			const isAr = $locale === 'ar';

			// Map RPC results to component format
			requests = rows.map((r: any) => {
				const branchName = isAr ? (r.branch_name_ar || r.branch_name_en) : (r.branch_name_en || r.branch_name_ar);
				const branchLocation = isAr ? (r.branch_location_ar || r.branch_location_en) : (r.branch_location_en || r.branch_location_ar);
				const branchDisplay = branchName ? (branchLocation ? `${branchName} — ${branchLocation}` : branchName) : '—';
				return {
					id: r.id,
					requester_user_id: r.requester_user_id,
					branch_id: r.branch_id,
					target_user_id: r.target_user_id,
					status: r.status,
					items: r.items,
					notes: r.notes,
					created_at: r.created_at,
					updated_at: r.updated_at,
					requester_name: isAr ? (r.requester_name_ar || r.requester_name_en) : (r.requester_name_en || r.requester_name_ar),
					target_name: r.target_user_id ? (isAr ? (r.target_name_ar || r.target_name_en) : (r.target_name_en || r.target_name_ar)) : '—',
					branch_name: r.branch_id ? branchDisplay : '—'
				};
			});
		} catch (err: any) {
			console.error('Error loading customer requests:', err);
			error = err?.message || 'Failed to load';
		} finally {
			loading = false;
		}
	}

	async function updateStatus(id: string, newStatus: 'reviewed' | 'resolved' | 'dismissed') {
		try {
			const { error: err } = await supabase
				.from('customer_product_requests')
				.update({ status: newStatus, updated_at: new Date().toISOString() })
				.eq('id', id);
			if (err) throw err;

			requests = requests.map(r => r.id === id ? { ...r, status: newStatus } : r);

			const req = requests.find(r => r.id === id);
			if (req) {
				try {
					const { data: linkedTasks } = await supabase
						.from('quick_tasks')
						.select('id')
						.eq('product_request_id', id)
						.eq('product_request_type', 'CUSTOMER');

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
					console.warn('Failed to complete quick tasks:', taskErr);
				}

				try {
					const statusLabel = newStatus === 'resolved' ? 'Resolved ✅' : newStatus === 'reviewed' ? 'Reviewed 👁️' : 'Dismissed ❌';
					const statusLabelAr = newStatus === 'resolved' ? 'تم الحل ✅' : newStatus === 'reviewed' ? 'تمت المراجعة 👁️' : 'مرفوض ❌';
					await supabase.from('notifications').insert({
						title: `Customer Request ${statusLabel} | طلب عميل ${statusLabelAr}`,
						message: `Your customer product request has been ${newStatus}.\n---\nطلب منتج العميل تم ${newStatus === 'resolved' ? 'حله' : newStatus === 'reviewed' ? 'مراجعته' : 'رفضه'}.`,
						type: newStatus === 'dismissed' ? 'error' : 'success',
						priority: 'normal',
						target_type: 'specific_users',
						target_users: [req.requester_user_id],
						status: 'published',
						total_recipients: 1,
						created_at: new Date().toISOString()
					});
				} catch (notifErr) {
					console.warn('Failed to send notification:', notifErr);
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

	function getItemsList(items: any): { product_name: string; image_url: string | null }[] {
		if (Array.isArray(items)) return items;
		try { const p = JSON.parse(items); return Array.isArray(p) ? p : []; } catch { return []; }
	}

	function getArrivedKey(item: FlatItem): string {
		return `${item.requestId}::${item.product_name || ''}::${item.image_url || ''}`;
	}

	async function markAsArrived(item: FlatItem) {
		const key = getArrivedKey(item);
		if (arrivedSet.has(key)) return;
		arrivedSet.add(key);
		arrivedSet = arrivedSet; // trigger reactivity

		try {
			const productName = item.product_name || ($locale === 'ar' ? 'منتج' : 'Product');
			const imageInfo = item.image_url ? `\n${item.image_url}` : '';
			await supabase.from('notifications').insert({
				title: `وصل المنتج المطلوب 📦 | Requested Product Arrived 📦`,
				message: `المنتج الذي طلبته "${productName}" قد وصل. يرجى المراجعة.${imageInfo}\n---\nThe product you requested "${productName}" has arrived. Please check.${imageInfo}`,
				type: 'success',
				priority: 'normal',
				target_type: 'specific_users',
				target_users: [item.requester_user_id],
				status: 'published',
				total_recipients: 1,
				created_at: new Date().toISOString()
			});
		} catch (err) {
			console.warn('Failed to send arrived notification:', err);
			arrivedSet.delete(key);
			arrivedSet = arrivedSet;
		}
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
		filterStatus = 'all';
		filterBranch = '';
		filterDateFrom = '';
		filterDateTo = '';
	}

	$: hasActiveFilters = searchQuery || filterStatus !== 'all' || filterBranch || filterDateFrom || filterDateTo;

	$: flatItems = filteredRequests.flatMap(req => {
		const items = getItemsList(req.items);
		return items.map(item => ({
			requestId: req.id,
			product_name: item.product_name,
			image_url: item.image_url,
			requester_name: req.requester_name || '—',
			target_name: req.target_name || '—',
			branch_name: req.branch_name || '—',
			status: req.status,
			created_at: req.created_at,
			requester_user_id: req.requester_user_id
		}));
	}) as FlatItem[];
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">🛍️</span>
			<h2 class="text-lg font-bold text-slate-800">{$t('nav.customerProductRequests') || 'Customer Product Requests'}</h2>
			<span class="text-xs font-semibold bg-purple-100 text-purple-600 px-3 py-1 rounded-full">{flatItems.length}</span>
		</div>
		<div class="flex items-center gap-2">
			<div class="relative min-w-[160px] max-w-[240px]">
				<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
				<input type="text" bind:value={searchQuery} placeholder={$locale === 'ar' ? 'بحث...' : 'Search...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-transparent transition-all" />
			</div>
			<select bind:value={filterStatus} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-purple-400">
				<option value="all">{$locale === 'ar' ? 'الكل' : 'All'}</option>
				<option value="pending">{$locale === 'ar' ? 'معلق' : 'Pending'}</option>
				<option value="reviewed">{$locale === 'ar' ? 'تمت المراجعة' : 'Reviewed'}</option>
				<option value="resolved">{$locale === 'ar' ? 'تم الحل' : 'Resolved'}</option>
				<option value="dismissed">{$locale === 'ar' ? 'مرفوض' : 'Dismissed'}</option>
			</select>
			<select bind:value={filterBranch} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-purple-400 min-w-[110px]">
				<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
				{#each branchOptions as branch}
					<option value={branch}>{branch}</option>
				{/each}
			</select>
			<div class="flex items-center gap-1">
				<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'من' : 'From'}</span>
				<input type="date" bind:value={filterDateFrom} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-purple-400 cursor-pointer" />
			</div>
			<div class="flex items-center gap-1">
				<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'إلى' : 'To'}</span>
				<input type="date" bind:value={filterDateTo} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-purple-400 cursor-pointer" />
			</div>
			{#if hasActiveFilters}
				<button on:click={clearFilters} class="px-3 py-2 bg-red-50 hover:bg-red-100 text-red-600 rounded-xl text-xs font-bold transition-all">✕ {$locale === 'ar' ? 'مسح' : 'Clear'}</button>
			{/if}
			<span class="text-[10px] text-slate-400 font-semibold">{flatItems.length}</span>
			<button class="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all text-xs shadow-lg shadow-emerald-200" on:click={exportToExcel}>
				<span>📥</span> Excel
			</button>
			<button class="flex items-center gap-1.5 px-4 py-2 bg-slate-600 text-white font-bold rounded-xl hover:bg-slate-700 transition-all text-xs shadow-lg shadow-slate-200" on:click={printAllItems}>
				<span>🖨️</span> Print
			</button>
			<button class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs" on:click={loadRequests}>
				<span>🔄</span> {$t('finance.assets.refresh')}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-hidden p-6">
		<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
			{#if loading}
				<div class="flex-1 flex flex-col items-center justify-center">
					<div class="text-5xl mb-4 animate-bounce">🛍️</div>
					<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.loading') || 'Loading...'}</p>
				</div>
			{:else if error}
				<div class="flex-1 flex flex-col items-center justify-center">
					<div class="text-5xl mb-4">❌</div>
					<p class="text-red-500 font-semibold">{error}</p>
				</div>
			{:else if flatItems.length === 0}
				<div class="flex-1 flex flex-col items-center justify-center">
					<div class="text-5xl mb-4">📭</div>
					<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد طلبات' : 'No customer requests found'}</p>
				</div>
			{:else}
				<div class="flex-1 overflow-auto">
					<table class="w-full text-xs border-collapse border border-slate-300">
						<thead class="sticky top-0 z-10">
							<tr class="bg-purple-600 text-white">
								<th class="border-r border-purple-500 py-2.5 px-3 text-left font-bold">#</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'صورة' : 'Image'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'اسم المنتج' : 'Product Name'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'مقدم الطلب' : 'Requester'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.branch') || 'Branch'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'الحالة' : 'Status'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'التاريخ' : 'Date'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'وصل' : 'Arrived'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'مراجعة' : 'Review'}</th>
								<th class="border-r border-purple-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'حل' : 'Resolve'}</th>
								<th class="py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'رفض' : 'Dismiss'}</th>
							</tr>
						</thead>
						<tbody>
							{#each flatItems as item, i}
								<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
									<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
									<td class="border-r border-slate-300 py-2 px-3 text-center">
										{#if item.image_url}
											<img src={item.image_url} alt="Product" class="w-12 h-12 object-cover rounded-lg border border-slate-200 cursor-pointer hover:opacity-80 transition-all hover:shadow-lg inline-block" on:click|stopPropagation={() => lightboxUrl = item.image_url} />
										{:else}
											<span class="text-slate-400">—</span>
										{/if}
									</td>
									<td class="border-r border-slate-300 py-2 px-3 font-bold text-slate-800">{item.product_name || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-700">{item.requester_name}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{item.branch_name}</td>
									<td class="border-r border-slate-300 py-2 px-3">
										<span class="text-[10px] px-2.5 py-1 rounded-full border font-bold {getStatusColor(item.status)}">{getStatusLabel(item.status)}</span>
									</td>
									<td class="border-r border-slate-300 py-2 px-3 text-slate-500 text-[10px]">{formatDate(item.created_at)}</td>
									<td class="border-r border-slate-300 py-2 px-3 text-center">
										{#if arrivedSet.has(getArrivedKey(item))}
											<span class="text-emerald-500 font-bold" title="Arrived">📦✅</span>
										{:else}
											<button class="p-1.5 bg-orange-50 hover:bg-orange-100 rounded-lg transition-all text-orange-600 hover:text-orange-800" on:click|stopPropagation={() => markAsArrived(item)} title="Mark as Arrived">📦</button>
										{/if}
									</td>
									<td class="border-r border-slate-300 py-2 px-3 text-center">
										{#if item.status === 'pending'}
											<button class="p-1.5 bg-blue-50 hover:bg-blue-100 rounded-lg transition-all text-blue-600 hover:text-blue-800" on:click|stopPropagation={() => updateStatus(item.requestId, 'reviewed')} title="Review">👁️</button>
										{/if}
									</td>
									<td class="border-r border-slate-300 py-2 px-3 text-center">
										{#if item.status === 'pending' || item.status === 'reviewed'}
											<button class="p-1.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-600 hover:text-emerald-800" on:click|stopPropagation={() => updateStatus(item.requestId, 'resolved')} title="Resolve">✅</button>
										{/if}
									</td>
									<td class="py-2 px-3 text-center">
										{#if item.status === 'pending' || item.status === 'reviewed'}
											<button class="p-1.5 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-600 hover:text-red-800" on:click|stopPropagation={() => updateStatus(item.requestId, 'dismissed')} title="Dismiss">❌</button>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- Photo Lightbox -->
{#if lightboxUrl}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm" on:click={() => lightboxUrl = null} role="button" tabindex="-1">
		<div class="relative max-w-[80vw] max-h-[80vh]">
			<img src={lightboxUrl} alt="Product" class="max-w-full max-h-[80vh] object-contain rounded-2xl shadow-2xl" />
			<button class="absolute -top-3 -right-3 w-8 h-8 bg-white text-slate-600 rounded-full text-sm font-bold flex items-center justify-center hover:bg-red-50 hover:text-red-600 transition-all shadow-lg" on:click|stopPropagation={() => lightboxUrl = null}>✕</button>
		</div>
	</div>
{/if}
