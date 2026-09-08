<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { _ as t, locale } from '$lib/i18n';
	import * as XLSX from 'xlsx';

	let supabase: any = null;
	let isLoading = false;
	let loadingOlder = false;
	let allData: any[] = [];
	let reportType: string | null = null;
	let error: string | null = null;
	let branchFilter = '';
	let cashierFilter = '';
	let fromDate = '';
	let toDate = '';
	let amountFilterType = '';
	let amountFilterValue = '';
	let showingOlderData = false;

	function getTwoMonthsAgo(): string {
		const d = new Date();
		d.setMonth(d.getMonth() - 2);
		return d.toISOString();
	}

	$: filteredData = filterData(allData, reportType, branchFilter, cashierFilter, fromDate, toDate, amountFilterType, amountFilterValue);
	$: totalDifference = filteredData.reduce((sum: number, item: any) => sum + item.total_difference, 0);
	$: recordCount = filteredData.length;
	$: groupedByCashier = groupDataByCashier(filteredData);
	$: uniqueBranches = [...new Set(allData.map((r: any) => r.branch_name_en))].sort();

	function groupDataByCashier(data: any[]) {
		const grouped: Record<string, any[]> = {};
		const sorted = [...data].sort((a, b) => (a.cashier_name_en || '').localeCompare(b.cashier_name_en || ''));
		sorted.forEach((item: any) => {
			const name = `${item.cashier_name_en} / ${item.cashier_name_ar}`;
			if (!grouped[name]) grouped[name] = [];
			grouped[name].push(item);
		});
		return Object.entries(grouped).map(([cashierName, items]) => ({
			cashierName,
			items: items.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
			total: items.reduce((sum: number, item: any) => sum + item.total_difference, 0)
		}));
	}

	function filterData(data: any[], type: string | null, branch: string, cashier: string, from: string, to: string, amountType: string, amountValue: string) {
		return data.filter((item: any) => {
			// Filter by report type
			if (type === 'short' && item.total_difference >= 0) return false;
			if (type === 'excess' && item.total_difference <= 0) return false;

			const branchMatch = !branch || item.branch_name_en === branch;
			const cashierMatch = !cashier || 
				(item.cashier_name_en || '').toLowerCase().includes(cashier.toLowerCase()) ||
				(item.cashier_name_ar || '').toLowerCase().includes(cashier.toLowerCase());
			
			let dateMatch = true;
			if (from || to) {
				const itemDate = new Date(item.created_at).getTime();
				const fromDateTime = from ? new Date(from).getTime() : 0;
				const toDateTime = to ? new Date(to).getTime() + 86400000 : Infinity;
				dateMatch = itemDate >= fromDateTime && itemDate <= toDateTime;
			}
			
			let amountMatch = true;
			if (amountType && amountValue) {
				const amount = Math.abs(parseFloat(amountValue));
				if (!isNaN(amount)) {
					const absDiff = Math.abs(item.total_difference);
					if (amountType === 'less') amountMatch = absDiff < amount;
					else if (amountType === 'more') amountMatch = absDiff > amount;
					else if (amountType === 'exact') amountMatch = Math.abs(absDiff - amount) < 0.01;
				}
			}
			
			return branchMatch && cashierMatch && dateMatch && amountMatch;
		});
	}

	async function fetchReportData(type: string) {
		reportType = type;
		if (allData.length > 0) return; // Already loaded, just filter
		
		isLoading = true;
		error = null;
		try {
			const { data, error: rpcError } = await supabase.rpc('get_pos_report', {
				p_date_from: getTwoMonthsAgo(),
				p_date_to: null
			});
			if (rpcError) throw rpcError;
			allData = (data || []).map((r: any) => ({
				...r,
				total_difference: parseFloat(r.total_difference || 0)
			}));
		} catch (err: any) {
			console.error('Error fetching report data:', err);
			error = err.message || 'Failed to load report data';
		} finally {
			isLoading = false;
		}
	}

	async function loadOlderData() {
		if (loadingOlder) return;
		loadingOlder = true;
		try {
			const { data, error: rpcError } = await supabase.rpc('get_pos_report', {
				p_date_from: null,
				p_date_to: getTwoMonthsAgo()
			});
			if (rpcError) throw rpcError;
			const olderRecords = (data || []).map((r: any) => ({
				...r,
				total_difference: parseFloat(r.total_difference || 0)
			}));
			allData = [...allData, ...olderRecords];
			showingOlderData = true;
		} catch (err: any) {
			console.error('Error loading older data:', err);
		} finally {
			loadingOlder = false;
		}
	}

	function formatCurrency(value: number) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(value);
	}

	function formatDate(dateString: string) {
		if (!dateString) return 'N/A';
		const date = new Date(dateString);
		return date.toLocaleDateString('en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' });
	}

	function exportToExcel() {
		try {
			const excelData: any[] = [];
			groupedByCashier.forEach((group: any) => {
				group.items.forEach((row: any) => {
					excelData.push({
						'Date': formatDate(row.created_at),
						'Box Number': row.box_number,
						'Cashier Name (EN)': row.cashier_name_en,
						'Cashier Name (AR)': row.cashier_name_ar,
						'Difference': row.total_difference,
						'Branch Name': row.branch_name_en,
						'Branch Location': row.branch_location_en,
						'Deduction Status': row.transfer_status || 'Not Transferred'
					});
				});
				excelData.push({
					'Date': '',
					'Box Number': '',
					'Cashier Name (EN)': `Total for ${group.cashierName}`,
					'Cashier Name (AR)': '',
					'Difference': group.total,
					'Branch Name': '',
					'Branch Location': ''
				});
				excelData.push({});
			});

			const worksheet = XLSX.utils.json_to_sheet(excelData);
			const workbook = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(workbook, worksheet, reportType === 'short' ? 'Short Report' : reportType === 'excess' ? 'Excess Report' : 'All Report');
			worksheet['!cols'] = [{ wch: 15 }, { wch: 12 }, { wch: 20 }, { wch: 20 }, { wch: 15 }, { wch: 25 }, { wch: 30 }, { wch: 18 }];
			const dateStr = new Date().toISOString().split('T')[0];
			XLSX.writeFile(workbook, `POS_${reportType === 'short' ? 'Short' : reportType === 'excess' ? 'Excess' : 'All'}_Report_${dateStr}.xlsx`);
		} catch (err) {
			console.error('Error exporting to Excel:', err);
			error = 'Failed to export to Excel';
		}
	}

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
	});
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header with report type buttons -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<h2 class="text-lg font-bold text-slate-800">📊 {$t('nav.posReport') || 'POS Report'}</h2>
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{reportType === 'short' ? 'bg-red-600 text-white shadow-lg shadow-red-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => fetchReportData('short')}
				disabled={isLoading}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📉</span>
				<span class="relative z-10">{$locale === 'ar' ? 'تقرير النقص' : 'Short Report'}</span>
			</button>
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{reportType === 'excess' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => fetchReportData('excess')}
				disabled={isLoading}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📈</span>
				<span class="relative z-10">{$locale === 'ar' ? 'تقرير الزيادة' : 'Excess Report'}</span>
			</button>
		</div>
	</div>

	<!-- Main Content -->
	<div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-red-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if !reportType}
				<!-- Initial State -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📊</div>
					<p class="text-slate-600 font-semibold">{$locale === 'ar' ? 'اختر نوع التقرير لعرض البيانات' : 'Select a report type to view data'}</p>
				</div>
			{:else if isLoading}
				<!-- Loading -->
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{$locale === 'ar' ? 'جاري تحميل البيانات...' : 'Loading report data...'}</p>
					</div>
				</div>
			{:else if error}
				<!-- Error -->
				<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
					<p class="text-red-700 font-semibold">Error: {error}</p>
					<button 
						class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
						on:click={() => { allData = []; fetchReportData(reportType); }}
					>
						{$locale === 'ar' ? 'إعادة المحاولة' : 'Retry'}
					</button>
				</div>
			{:else if filteredData.length === 0 && !branchFilter && !cashierFilter && !fromDate && !toDate}
				<!-- No data -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📭</div>
					<p class="text-slate-600 font-semibold">{$locale === 'ar' ? 'لا توجد سجلات' : `No ${reportType === 'short' ? 'shortage' : 'excess'} records found`}</p>
				</div>
			{:else}
				<!-- Filter Controls -->
				<div class="mb-4 flex gap-3 flex-wrap">
					<div class="flex-1 min-w-[160px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="pos-from-date">
							{$locale === 'ar' ? 'من تاريخ' : 'From Date'}
						</label>
						<input id="pos-from-date" type="date" bind:value={fromDate}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-1 min-w-[160px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="pos-to-date">
							{$locale === 'ar' ? 'إلى تاريخ' : 'To Date'}
						</label>
						<input id="pos-to-date" type="date" bind:value={toDate}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-1 min-w-[180px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="pos-branch-filter">
							{$locale === 'ar' ? 'الفرع' : 'Branch'}
						</label>
						<select id="pos-branch-filter" bind:value={branchFilter}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;">
							<option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'جميع الفروع' : 'All Branches'}</option>
							{#each uniqueBranches as branch}
								<option value={branch} style="color: #000000 !important; background-color: #ffffff !important;">{branch}</option>
							{/each}
						</select>
					</div>
					<div class="flex-1 min-w-[180px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="pos-cashier-filter">
							{$locale === 'ar' ? 'بحث بالكاشير' : 'Search Cashier'}
						</label>
						<input id="pos-cashier-filter" type="text" bind:value={cashierFilter}
							placeholder={$locale === 'ar' ? 'اسم الكاشير...' : 'Cashier name...'}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-1 min-w-[200px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="pos-amount-type">
							{$locale === 'ar' ? 'فلتر المبلغ' : 'Amount Filter'}
						</label>
						<div class="flex gap-2">
							<select id="pos-amount-type" bind:value={amountFilterType}
								class="flex-1 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;">
								<option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'بدون فلتر' : 'No Filter'}</option>
								<option value="less" style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'أقل من' : 'Less Than'}</option>
								<option value="more" style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'أكثر من' : 'More Than'}</option>
								<option value="exact" style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'بالضبط' : 'Exact'}</option>
							</select>
							{#if amountFilterType}
								<input type="number" bind:value={amountFilterValue}
									placeholder={$locale === 'ar' ? 'المبلغ...' : 'Amount...'}
									step="0.01"
									class="w-28 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
							{/if}
						</div>
					</div>
					<div class="flex items-end">
						<button 
							class="inline-flex items-center justify-center px-5 py-2.5 rounded-xl bg-blue-600 text-white text-xs font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
							on:click={exportToExcel}
							disabled={filteredData.length === 0}
						>
							📥 {$locale === 'ar' ? 'تصدير إكسل' : 'Export Excel'}
						</button>
					</div>
				</div>

				<!-- Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<div class="overflow-x-auto flex-1">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 {reportType === 'short' ? 'bg-red-600' : 'bg-emerald-600'} text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 {reportType === 'short' ? 'border-red-400' : 'border-emerald-400'}">
										{$locale === 'ar' ? 'التاريخ' : 'Date'}
									</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 {reportType === 'short' ? 'border-red-400' : 'border-emerald-400'}">
										{$locale === 'ar' ? 'رقم الصندوق' : 'Box #'}
									</th>
									<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 {reportType === 'short' ? 'border-red-400' : 'border-emerald-400'}">
										{$locale === 'ar' ? 'الكاشير' : 'Cashier'}
									</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 {reportType === 'short' ? 'border-red-400' : 'border-emerald-400'}">
										{$locale === 'ar' ? 'الفرق' : 'Difference'}
									</th>
									<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 {reportType === 'short' ? 'border-red-400' : 'border-emerald-400'}">
										{$locale === 'ar' ? 'الفرع' : 'Branch'}
									</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 {reportType === 'short' ? 'border-red-400' : 'border-emerald-400'}">
										{$locale === 'ar' ? 'حالة الخصم' : 'Deduction'}
									</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each filteredData as row, index (row.id)}
									<tr class="hover:{reportType === 'short' ? 'bg-red-50/30' : 'bg-emerald-50/30'} transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-4 py-3 text-sm text-slate-700 font-mono">{formatDate(row.created_at)}</td>
										<td class="px-4 py-3 text-sm text-center">
											<span class="inline-block px-2.5 py-1 rounded-full text-xs font-black {reportType === 'short' ? 'bg-red-100 text-red-800' : 'bg-emerald-100 text-emerald-800'}">
												Box {row.box_number}
											</span>
										</td>
										<td class="px-4 py-3 text-sm text-slate-700">
											<div class="font-semibold">{row.cashier_name_en}</div>
											<div class="text-xs text-slate-400" dir="rtl">{row.cashier_name_ar}</div>
										</td>
										<td class="px-4 py-3 text-sm text-center font-bold font-mono {row.total_difference < 0 ? 'text-red-600' : 'text-emerald-600'}">
											{formatCurrency(row.total_difference)}
										</td>
										<td class="px-4 py-3 text-sm text-slate-700">
											<div>{row.branch_name_en}</div>
											<div class="text-xs text-slate-400">{row.branch_location_en}</div>
										</td>									<td class="px-4 py-3 text-sm text-center">
										{#if row.transfer_status === 'Proposed'}
											<span class="inline-block px-2.5 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-800">⏳ {$locale === 'ar' ? 'مقترح' : 'Proposed'}</span>
										{:else if row.transfer_status === 'Forgiven'}
											<span class="inline-block px-2.5 py-1 rounded-full text-xs font-bold bg-green-100 text-green-800">✅ {$locale === 'ar' ? 'معفى' : 'Forgiven'}</span>
										{:else if row.transfer_status === 'Deducted'}
											<span class="inline-block px-2.5 py-1 rounded-full text-xs font-bold bg-red-100 text-red-800">💰 {$locale === 'ar' ? 'مخصوم' : 'Deducted'}</span>
										{:else}
											<span class="inline-block px-2.5 py-1 rounded-full text-xs font-bold bg-slate-100 text-slate-500">— {$locale === 'ar' ? 'لم يتم' : 'None'}</span>
										{/if}
									</td>									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Footer -->
					<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 flex items-center justify-between flex-wrap gap-3">
						<div class="flex gap-6 text-xs font-semibold text-slate-600">
							<span>{$locale === 'ar' ? 'السجلات:' : 'Records:'} <strong class="text-slate-800">{recordCount}</strong></span>
							<span>{$locale === 'ar' ? 'الإجمالي:' : 'Total:'} <strong class="{totalDifference < 0 ? 'text-red-600' : 'text-emerald-600'}">{formatCurrency(totalDifference)}</strong></span>
							<span class="text-slate-400">
								{$locale === 'ar' 
									? `(${showingOlderData ? 'كل الفترات' : 'آخر شهرين'})`
									: `(${showingOlderData ? 'All time' : 'Last 2 months'})`}
							</span>
						</div>
						<div class="flex gap-2">
							{#if loadingOlder}
								<div class="flex items-center gap-2 text-xs text-slate-500">
									<div class="animate-spin w-4 h-4 border-2 border-slate-200 border-t-emerald-600 rounded-full"></div>
									{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}
								</div>
							{:else if !showingOlderData}
								<button 
									class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-indigo-600 text-white text-xs font-bold hover:bg-indigo-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
									on:click={loadOlderData}
								>
									📜 {$locale === 'ar' ? 'تحميل بيانات أقدم' : 'Load Older Data'}
								</button>
							{/if}
						</div>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}
</style>
