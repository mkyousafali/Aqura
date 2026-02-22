<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { createClient } from '@supabase/supabase-js';
	import { currentLocale } from '$lib/i18n';
	import type { RealtimeChannel } from '@supabase/supabase-js';

	export let windowId: string;

	const supabase = createClient(
		import.meta.env.VITE_SUPABASE_URL,
		import.meta.env.VITE_SUPABASE_ANON_KEY
	);

	interface Reconciliation {
		id: number;
		operation_id: string;
		branch_id: string;
		pos_number: number;
		supervisor_id: string;
		cashier_id: string;
		reconciliation_number: string;
		mada_amount: number;
		visa_amount: number;
		mastercard_amount: number;
		google_pay_amount: number;
		other_amount: number;
		total_amount: number;
		created_at: string;
		updated_at: string;
		branch_name_en?: string;
		branch_name_ar?: string;
		supervisor_name?: string;
		cashier_name?: string;
		box_number?: number;
		date_closed?: string;
	}

	let reconciliations: Reconciliation[] = [];
	let branches: any[] = [];
	let isLoading = true;
	let selectedBranch = 'all';
	let dateFrom = '';
	let dateTo = '';
	let searchReconNumber = '';
	let realtimeChannel: RealtimeChannel | null = null;

	// Pagination
	let currentPage = 1;
	let pageSize = 50;
	let totalCount = 0;

	// Sort
	let sortField = 'created_at';
	let sortDirection: 'asc' | 'desc' = 'desc';

	$: filteredReconciliations = applyClientFilters(reconciliations);
	$: paginatedReconciliations = filteredReconciliations.slice((currentPage - 1) * pageSize, currentPage * pageSize);
	$: totalPages = Math.ceil(filteredReconciliations.length / pageSize);

	// Totals
	$: grandTotals = filteredReconciliations.reduce((acc, r) => {
		acc.mada += Number(r.mada_amount) || 0;
		acc.visa += Number(r.visa_amount) || 0;
		acc.mastercard += Number(r.mastercard_amount) || 0;
		acc.google_pay += Number(r.google_pay_amount) || 0;
		acc.other += Number(r.other_amount) || 0;
		acc.total += Number(r.total_amount) || 0;
		return acc;
	}, { mada: 0, visa: 0, mastercard: 0, google_pay: 0, other: 0, total: 0 });

	onMount(async () => {
		await Promise.all([loadBranches(), loadReconciliations()]);
		setupRealtime();
		isLoading = false;
	});

	onDestroy(() => {
		if (realtimeChannel) {
			realtimeChannel.unsubscribe();
		}
	});

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true);
			if (error) throw error;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadReconciliations() {
		try {
			isLoading = true;
			let query = supabase
				.from('bank_reconciliations')
				.select('*')
				.order('created_at', { ascending: false });

			if (selectedBranch && selectedBranch !== 'all') {
				query = query.eq('branch_id', selectedBranch);
			}
			if (dateFrom) {
				query = query.gte('created_at', dateFrom + 'T00:00:00');
			}
			if (dateTo) {
				query = query.lte('created_at', dateTo + 'T23:59:59');
			}

			const { data, error } = await query;
			if (error) throw error;

			reconciliations = data || [];
			totalCount = reconciliations.length;

			// Enrich with branch names
			const branchMap = new Map(branches.map(b => [b.id, b]));
			for (const r of reconciliations) {
				const branch = branchMap.get(r.branch_id);
				if (branch) {
					r.branch_name_en = branch.name_en;
					r.branch_name_ar = branch.name_ar;
				}
			}

			// Load user names for supervisors and cashiers
			const userIds = new Set<string>();
			reconciliations.forEach(r => {
				if (r.supervisor_id) userIds.add(r.supervisor_id);
				if (r.cashier_id) userIds.add(r.cashier_id);
			});

			if (userIds.size > 0) {
				const { data: users } = await supabase
					.from('users')
					.select('id, full_name')
					.in('id', Array.from(userIds));

				if (users) {
					const userMap = new Map(users.map(u => [u.id, u.full_name]));
					for (const r of reconciliations) {
						r.supervisor_name = userMap.get(r.supervisor_id) || '-';
						r.cashier_name = userMap.get(r.cashier_id) || '-';
					}
				}
			}

			// Load box details (box_number, date closed)
			const opIds = [...new Set(reconciliations.map(r => r.operation_id).filter(Boolean))];
			if (opIds.length > 0) {
				const { data: ops } = await supabase
					.from('box_operations')
					.select('id, box_number, closing_details')
					.in('id', opIds);
				if (ops) {
					const opMap = new Map(ops.map(o => [o.id, o]));
					for (const r of reconciliations) {
						const op = opMap.get(r.operation_id);
						if (op) {
							r.box_number = op.box_number;
						}
					}
				}
			}

			currentPage = 1;
		} catch (err) {
			console.error('Error loading reconciliations:', err);
		} finally {
			isLoading = false;
		}
	}

	function applyClientFilters(items: Reconciliation[]): Reconciliation[] {
		let result = [...items];
		if (searchReconNumber) {
			const search = searchReconNumber.toLowerCase();
			result = result.filter(r => r.reconciliation_number?.toLowerCase().includes(search));
		}
		// Sort
		result.sort((a: any, b: any) => {
			let av = a[sortField];
			let bv = b[sortField];
			if (typeof av === 'string') av = av.toLowerCase();
			if (typeof bv === 'string') bv = bv.toLowerCase();
			if (av < bv) return sortDirection === 'asc' ? -1 : 1;
			if (av > bv) return sortDirection === 'asc' ? 1 : -1;
			return 0;
		});
		return result;
	}

	function toggleSort(field: string) {
		if (sortField === field) {
			sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
		} else {
			sortField = field;
			sortDirection = 'asc';
		}
	}

	function setupRealtime() {
		realtimeChannel = supabase
			.channel('bank-recon-changes')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'bank_reconciliations' }, () => {
				loadReconciliations();
			})
			.subscribe();
	}

	function formatDate(dateStr: string): string {
		if (!dateStr) return '-';
		const d = new Date(dateStr);
		return d.toLocaleDateString('ar-EG', { year: 'numeric', month: '2-digit', day: '2-digit' }) + ' ' +
			d.toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });
	}

	function formatAmount(amount: number): string {
		return (Number(amount) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}

	function getBranchName(r: Reconciliation): string {
		if ($currentLocale === 'ar') return r.branch_name_ar || r.branch_name_en || '-';
		return r.branch_name_en || r.branch_name_ar || '-';
	}

	async function handleFilterChange() {
		await loadReconciliations();
	}

	function prevPage() {
		if (currentPage > 1) currentPage--;
	}

	function nextPage() {
		if (currentPage < totalPages) currentPage++;
	}

	function getSortIcon(field: string): string {
		if (sortField !== field) return '↕';
		return sortDirection === 'asc' ? '↑' : '↓';
	}
</script>

<div class="manage-recon-container font-sans" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Background decorations -->
	<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-blue-100/20 rounded-full blur-[120px] -mr-48 -mt-48"></div>
	<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-emerald-100/20 rounded-full blur-[120px] -ml-48 -mb-48"></div>

	{#if isLoading && reconciliations.length === 0}
		<div class="flex flex-col items-center justify-center h-full gap-4 animate-in">
			<div class="relative">
				<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
			</div>
			<p class="text-sm text-slate-500">{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
		</div>
	{:else}
		<!-- Filters -->
		<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 mb-4">
			<div class="flex flex-wrap gap-3 items-end">
				<!-- Branch filter -->
				<div class="flex flex-col gap-1">
					<label class="text-xs font-semibold text-slate-600">{$currentLocale === 'ar' ? 'الفرع' : 'Branch'}</label>
					<select
						bind:value={selectedBranch}
						on:change={handleFilterChange}
						class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[160px]"
					>
						<option value="all">{$currentLocale === 'ar' ? 'جميع الفروع' : 'All Branches'}</option>
						{#each branches as branch}
							<option value={branch.id}>{$currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}</option>
						{/each}
					</select>
				</div>

				<!-- Date from -->
				<div class="flex flex-col gap-1">
					<label class="text-xs font-semibold text-slate-600">{$currentLocale === 'ar' ? 'من تاريخ' : 'From'}</label>
					<input
						type="date"
						bind:value={dateFrom}
						on:change={handleFilterChange}
						class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
					/>
				</div>

				<!-- Date to -->
				<div class="flex flex-col gap-1">
					<label class="text-xs font-semibold text-slate-600">{$currentLocale === 'ar' ? 'إلى تاريخ' : 'To'}</label>
					<input
						type="date"
						bind:value={dateTo}
						on:change={handleFilterChange}
						class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
					/>
				</div>

				<!-- Search reconciliation number -->
				<div class="flex flex-col gap-1">
					<label class="text-xs font-semibold text-slate-600">{$currentLocale === 'ar' ? 'رقم التسوية' : 'Recon #'}</label>
					<input
						type="text"
						bind:value={searchReconNumber}
						placeholder={$currentLocale === 'ar' ? 'بحث...' : 'Search...'}
						class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[140px]"
					/>
				</div>

				<!-- Count badge -->
				<div class="flex items-center gap-2 {$currentLocale === 'ar' ? 'mr-auto' : 'ml-auto'}">
					<span class="bg-blue-100 text-blue-800 text-xs font-bold px-3 py-1.5 rounded-full">
						{filteredReconciliations.length} {$currentLocale === 'ar' ? 'تسوية' : 'records'}
					</span>
				</div>
			</div>
		</div>

		<!-- Table -->
		<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex-1 flex flex-col">
			<div class="overflow-auto flex-1">
				<table class="w-full border-collapse">
					<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
						<tr>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 cursor-pointer hover:bg-blue-700 transition" on:click={() => toggleSort('created_at')}>
								{$currentLocale === 'ar' ? 'التاريخ' : 'Date'} {getSortIcon('created_at')}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
								{$currentLocale === 'ar' ? 'الفرع' : 'Branch'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 cursor-pointer hover:bg-blue-700 transition" on:click={() => toggleSort('pos_number')}>
								{$currentLocale === 'ar' ? 'الكاشير' : 'POS'} {getSortIcon('pos_number')}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 cursor-pointer hover:bg-blue-700 transition" on:click={() => toggleSort('reconciliation_number')}>
								{$currentLocale === 'ar' ? 'رقم التسوية' : 'Recon #'} {getSortIcon('reconciliation_number')}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 text-center">
								{$currentLocale === 'ar' ? 'مدى' : 'Mada'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 text-center">
								{$currentLocale === 'ar' ? 'فيزا' : 'Visa'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 text-center">
								{$currentLocale === 'ar' ? 'ماستر كارد' : 'MC'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 text-center">
								{$currentLocale === 'ar' ? 'جوجل باي' : 'GPay'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 text-center">
								{$currentLocale === 'ar' ? 'أخرى' : 'Other'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 text-center cursor-pointer hover:bg-blue-700 transition" on:click={() => toggleSort('total_amount')}>
								{$currentLocale === 'ar' ? 'المجموع' : 'Total'} {getSortIcon('total_amount')}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
								{$currentLocale === 'ar' ? 'المشرف' : 'Supervisor'}
							</th>
							<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
								{$currentLocale === 'ar' ? 'الكاشير' : 'Cashier'}
							</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
						{#if paginatedReconciliations.length === 0}
							<tr>
								<td colspan="12" class="px-4 py-12 text-center text-slate-400">
									<div class="flex flex-col items-center gap-2">
										<span class="text-3xl">🏦</span>
										<span class="text-sm">{$currentLocale === 'ar' ? 'لا توجد تسويات' : 'No reconciliations found'}</span>
									</div>
								</td>
							</tr>
						{:else}
							{#each paginatedReconciliations as recon, index}
								<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
									<td class="px-3 py-2 text-xs text-slate-700 whitespace-nowrap">{formatDate(recon.created_at)}</td>
									<td class="px-3 py-2 text-xs text-slate-700">{getBranchName(recon)}</td>
									<td class="px-3 py-2 text-xs text-slate-700 text-center font-mono">{recon.pos_number || '-'}</td>
									<td class="px-3 py-2 text-xs text-slate-700 font-semibold">{recon.reconciliation_number || '-'}</td>
									<td class="px-3 py-2 text-xs text-slate-700 text-center font-mono">{formatAmount(recon.mada_amount)}</td>
									<td class="px-3 py-2 text-xs text-slate-700 text-center font-mono">{formatAmount(recon.visa_amount)}</td>
									<td class="px-3 py-2 text-xs text-slate-700 text-center font-mono">{formatAmount(recon.mastercard_amount)}</td>
									<td class="px-3 py-2 text-xs text-slate-700 text-center font-mono">{formatAmount(recon.google_pay_amount)}</td>
									<td class="px-3 py-2 text-xs text-slate-700 text-center font-mono">{formatAmount(recon.other_amount)}</td>
									<td class="px-3 py-2 text-xs text-blue-700 text-center font-bold font-mono">{formatAmount(recon.total_amount)}</td>
									<td class="px-3 py-2 text-xs text-slate-600">{recon.supervisor_name || '-'}</td>
									<td class="px-3 py-2 text-xs text-slate-600">{recon.cashier_name || '-'}</td>
								</tr>
							{/each}
						{/if}
					</tbody>
					{#if filteredReconciliations.length > 0}
						<tfoot class="sticky bottom-0 bg-blue-50 border-t-2 border-blue-300 z-10">
							<tr class="font-bold text-sm">
								<td colspan="4" class="px-3 py-2.5 text-blue-800">{$currentLocale === 'ar' ? 'الإجمالي' : 'Grand Total'}</td>
								<td class="px-3 py-2.5 text-center font-mono text-blue-800">{formatAmount(grandTotals.mada)}</td>
								<td class="px-3 py-2.5 text-center font-mono text-blue-800">{formatAmount(grandTotals.visa)}</td>
								<td class="px-3 py-2.5 text-center font-mono text-blue-800">{formatAmount(grandTotals.mastercard)}</td>
								<td class="px-3 py-2.5 text-center font-mono text-blue-800">{formatAmount(grandTotals.google_pay)}</td>
								<td class="px-3 py-2.5 text-center font-mono text-blue-800">{formatAmount(grandTotals.other)}</td>
								<td class="px-3 py-2.5 text-center font-mono text-blue-900 text-base">{formatAmount(grandTotals.total)}</td>
								<td colspan="2"></td>
							</tr>
						</tfoot>
					{/if}
				</table>
			</div>

			<!-- Pagination -->
			{#if totalPages > 1}
				<div class="flex items-center justify-between px-4 py-3 border-t border-slate-200 bg-white/60">
					<button
						on:click={prevPage}
						disabled={currentPage === 1}
						class="px-3 py-1.5 text-sm bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 disabled:opacity-40 disabled:cursor-not-allowed transition"
					>
						{$currentLocale === 'ar' ? 'السابق' : 'Previous'}
					</button>
					<span class="text-sm text-slate-600">
						{$currentLocale === 'ar' ? `صفحة ${currentPage} من ${totalPages}` : `Page ${currentPage} of ${totalPages}`}
					</span>
					<button
						on:click={nextPage}
						disabled={currentPage === totalPages}
						class="px-3 py-1.5 text-sm bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 disabled:opacity-40 disabled:cursor-not-allowed transition"
					>
						{$currentLocale === 'ar' ? 'التالي' : 'Next'}
					</button>
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.manage-recon-container {
		position: relative;
		height: 100%;
		display: flex;
		flex-direction: column;
		padding: 16px;
		overflow: hidden;
	}

	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.animate-in {
		animation: fadeIn 0.2s ease-out;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	:global([dir="rtl"] select) {
		background-position: left 0.75rem center !important;
		padding-left: 2.5rem !important;
		padding-right: 1rem !important;
	}
</style>
