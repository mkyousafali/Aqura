<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	let breaks: any[] = [];
	let loading = true;
	let branches: any[] = [];
	let now = Date.now();
	let tickInterval: ReturnType<typeof setInterval> | null = null;
	let realtimeChannel: any = null;
	let pollInterval: ReturnType<typeof setInterval> | null = null;
	let cleanupVisibility: (() => void) | null = null;
	let cleanupOnline: (() => void) | null = null;

	// Tabs
	let activeTab = 'Break Log';
	$: tabs = [
		{ id: 'Break Log', label: isRtl ? 'سجل الاستراحات' : 'Break Log', icon: '☕', color: 'green' },
		{ id: 'Break Reasons', label: isRtl ? 'أسباب الاستراحة' : 'Break Reasons', icon: '📌', color: 'blue' },
		{ id: 'Employee Summary', label: isRtl ? 'ملخص الموظف' : 'Employee Summary', icon: '📊', color: 'orange' }
	];

	// Filters
	let filterStatus = '';
	let filterBranch = '';
	let filterDateFrom = '';
	let filterDateTo = '';
	let searchQuery = '';

	// Break Reasons
	let breakReasons: any[] = [];
	let showReasonModal = false;
	let editingReasonId: number | null = null;
	let reasonFormData = { name_en: '', name_ar: '', sort_order: 0, is_active: true, requires_note: false };
	let isSaving = false;

	// Employee Summary
	let summaryDateFrom = '';
	let summaryDateTo = '';
	let summaryBranch = '';
	let employeeSummaries: any[] = [];
	let loadingSummary = false;

	$: isRtl = $locale === 'ar';

	$: filteredBreaks = breaks.filter(b => {
		if (filterStatus && b.status !== filterStatus) return false;
		if (filterBranch && String(b.branch_id) !== filterBranch) return false;
		if (searchQuery.trim()) {
			const s = searchQuery.toLowerCase();
			const match = (b.employee_id || '').toLowerCase().includes(s)
				|| (b.employee_name_en || '').toLowerCase().includes(s)
				|| (b.employee_name_ar || '').includes(s)
				|| (b.reason_en || '').toLowerCase().includes(s)
				|| (b.reason_ar || '').includes(s);
			if (!match) return false;
		}
		return true;
	});

	$: openBreaks = filteredBreaks.filter(b => b.status === 'open');
	$: closedBreaks = filteredBreaks.filter(b => b.status === 'closed');

	// Start real-time tick when there are open breaks
	$: if (openBreaks.length > 0 && !tickInterval) {
		tickInterval = setInterval(() => { now = Date.now(); }, 1000);
	} else if (openBreaks.length === 0 && tickInterval) {
		clearInterval(tickInterval);
		tickInterval = null;
	}

	onMount(async () => {
		await Promise.all([loadBreaks(), loadBranches(), loadBreakReasons()]);
		// Set default date range for summary (last 30 days)
		const today = new Date();
		summaryDateTo = today.toISOString().split('T')[0];
		const thirtyDaysAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
		summaryDateFrom = thirtyDaysAgo.toISOString().split('T')[0];

		// Subscribe to realtime changes
		setupRealtimeChannel();

		// Polling fallback for PWA — every 15s silently refresh data
		pollInterval = setInterval(() => {
			loadBreaks(true);
		}, 15000);

		// Handle PWA visibility changes — reconnect realtime + refresh data when app comes back
		const handleVisibilityChange = () => {
			if (document.visibilityState === 'visible') {
				console.log('👁️ Break register: App became visible, refreshing data & reconnecting realtime');
				loadBreaks(true);
				loadBreakReasons();
				// Re-establish realtime channel in case WebSocket dropped
				if (realtimeChannel) {
					supabase.removeChannel(realtimeChannel);
					realtimeChannel = null;
				}
				setupRealtimeChannel();
			}
		};
		document.addEventListener('visibilitychange', handleVisibilityChange);
		cleanupVisibility = () => document.removeEventListener('visibilitychange', handleVisibilityChange);

		// Also handle online event for network reconnection
		const handleOnline = () => {
			console.log('🌐 Break register: Network reconnected, refreshing data & reconnecting realtime');
			loadBreaks(true);
			loadBreakReasons();
			if (realtimeChannel) {
				supabase.removeChannel(realtimeChannel);
				realtimeChannel = null;
			}
			setupRealtimeChannel();
		};
		window.addEventListener('online', handleOnline);
		cleanupOnline = () => window.removeEventListener('online', handleOnline);
	});

	function setupRealtimeChannel() {
		realtimeChannel = supabase
			.channel('break-register-changes-' + Date.now())
			.on('postgres_changes', { event: '*', schema: 'public', table: 'break_register' }, (payload: any) => {
				console.log('🔄 Break register realtime event:', payload);
				loadBreaks(true);
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'break_reasons' }, () => {
				loadBreakReasons();
			})
			.subscribe((status: string) => {
				console.log('📡 Break register realtime status:', status);
			});
	}

	onDestroy(() => {
		if (tickInterval) clearInterval(tickInterval);
		if (pollInterval) clearInterval(pollInterval);
		if (realtimeChannel) supabase.removeChannel(realtimeChannel);
		if (cleanupVisibility) cleanupVisibility();
		if (cleanupOnline) cleanupOnline();
	});

	function handleTabChange() {
		if (activeTab === 'Break Log') {
			loadBreaks();
		} else if (activeTab === 'Break Reasons') {
			loadBreakReasons();
		} else if (activeTab === 'Employee Summary') {
			loadSummaryData();
		}
	}

	function getLiveDuration(startTime: string, _now: number): string {
		const secs = Math.floor((_now - new Date(startTime).getTime()) / 1000);
		return formatDuration(secs > 0 ? secs : 0);
	}

	async function loadBranches() {
		const { data } = await supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').order('id');
		if (data) branches = data;
	}

	async function loadBreaks(silent = false) {
		if (!silent) loading = true;
		const params: any = {};
		if (filterDateFrom) params.p_date_from = filterDateFrom;
		if (filterDateTo) params.p_date_to = filterDateTo;
		if (filterBranch) params.p_branch_id = parseInt(filterBranch);
		if (filterStatus) params.p_status = filterStatus;

		const { data, error } = await supabase.rpc('get_all_breaks', params);
		if (!error && data?.breaks) {
			breaks = data.breaks;
		}
		if (!silent) loading = false;
	}

	// ═══════════════════════════════════════
	// Break Reasons CRUD
	// ═══════════════════════════════════════
	async function loadBreakReasons() {
		const { data, error } = await supabase
			.from('break_reasons')
			.select('*')
			.order('sort_order', { ascending: true });
		if (!error && data) {
			breakReasons = data;
		}
	}

	function openReasonModal(reason?: any) {
		if (reason) {
			editingReasonId = reason.id;
			reasonFormData = {
				name_en: reason.name_en,
				name_ar: reason.name_ar,
				sort_order: reason.sort_order ?? 0,
				is_active: reason.is_active ?? true,
				requires_note: reason.requires_note ?? false
			};
		} else {
			editingReasonId = null;
			const maxSort = breakReasons.reduce((max: number, r: any) => Math.max(max, r.sort_order ?? 0), 0);
			reasonFormData = {
				name_en: '',
				name_ar: '',
				sort_order: maxSort + 1,
				is_active: true,
				requires_note: false
			};
		}
		showReasonModal = true;
	}

	function closeReasonModal() {
		showReasonModal = false;
		editingReasonId = null;
	}

	async function saveReason() {
		if (!reasonFormData.name_en.trim() || !reasonFormData.name_ar.trim()) {
			alert(isRtl ? 'يرجى ملء الاسم بالإنجليزية والعربية' : 'Please fill in both English and Arabic names');
			return;
		}

		isSaving = true;
		try {
			if (editingReasonId !== null) {
				const { error } = await supabase
					.from('break_reasons')
					.update(reasonFormData)
					.eq('id', editingReasonId);
				if (error) throw error;
			} else {
				const { error } = await supabase
					.from('break_reasons')
					.insert([reasonFormData]);
				if (error) throw error;
			}
			await loadBreakReasons();
			closeReasonModal();
		} catch (err) {
			console.error('Error saving reason:', err);
			alert(isRtl ? 'خطأ في الحفظ' : 'Error saving reason');
		} finally {
			isSaving = false;
		}
	}

	async function deleteReason(id: number) {
		if (!confirm(isRtl ? 'هل تريد حذف هذا السبب؟' : 'Delete this reason?')) return;
		try {
			const { error } = await supabase.from('break_reasons').delete().eq('id', id);
			if (error) throw error;
			await loadBreakReasons();
		} catch (err) {
			console.error('Error deleting reason:', err);
			alert(isRtl ? 'خطأ في الحذف' : 'Error deleting reason');
		}
	}

	// ═══════════════════════════════════════
	// Employee Summary
	// ═══════════════════════════════════════
	async function loadSummaryData() {
		loadingSummary = true;
		const params: any = {};
		if (summaryDateFrom) params.p_date_from = summaryDateFrom;
		if (summaryDateTo) params.p_date_to = summaryDateTo;
		if (summaryBranch) params.p_branch_id = parseInt(summaryBranch);

		const { data, error } = await supabase.rpc('get_all_breaks', params);
		if (!error && data?.breaks) {
			breaks = data.breaks;
			computeEmployeeSummaries();
		}
		loadingSummary = false;
	}

	function computeEmployeeSummaries() {
		const map = new Map<string, any>();
		const filtered = summaryBranch
			? breaks.filter(b => String(b.branch_id) === summaryBranch)
			: breaks;

		for (const b of filtered) {
			// Group by employee + date + reason
			const breakDate = b.start_time ? new Date(b.start_time).toISOString().split('T')[0] : 'unknown';
			const reasonKey = isRtl ? (b.reason_ar || b.reason_en || '—') : (b.reason_en || b.reason_ar || '—');
			const key = `${b.employee_id}__${breakDate}__${reasonKey}`;
			if (!map.has(key)) {
				map.set(key, {
					employee_id: b.employee_id,
					employee_name_en: b.employee_name_en,
					employee_name_ar: b.employee_name_ar,
					branch_name_en: b.branch_name_en,
					branch_name_ar: b.branch_name_ar,
					branch_id: b.branch_id,
					date: breakDate,
					reason: reasonKey,
					total_breaks: 0,
					open_breaks: 0,
					total_duration: 0
				});
			}
			const entry = map.get(key);
			entry.total_breaks++;
			if (b.status === 'open') entry.open_breaks++;
			if (b.duration_seconds) entry.total_duration += b.duration_seconds;
		}
		employeeSummaries = Array.from(map.values()).sort((a: any, b: any) => {
			// Sort by date descending, then employee name
			if (a.date !== b.date) return b.date.localeCompare(a.date);
			const nameA = a.employee_name_en || a.employee_name_ar || '';
			const nameB = b.employee_name_en || b.employee_name_ar || '';
			return nameA.localeCompare(nameB);
		});
	}

	function formatSummaryDate(dateStr: string): string {
		if (!dateStr || dateStr === 'unknown') return '—';
		const d = new Date(dateStr + 'T00:00:00');
		return d.toLocaleDateString(isRtl ? 'ar-EG' : 'en-US', {
			year: 'numeric', month: 'short', day: 'numeric',
			weekday: 'short'
		});
	}

	function formatDuration(seconds: number | null): string {
		if (!seconds) return '—';
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		const s = seconds % 60;
		if (h > 0) return `${h}h ${m}m ${s}s`;
		if (m > 0) return `${m}m ${s}s`;
		return `${s}s`;
	}

	function formatDurationHM(seconds: number): string {
		if (!seconds) return '0m';
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		if (h > 0) return `${h}h ${m}m`;
		return `${m}m`;
	}

	function formatDateTime(dt: string | null): string {
		if (!dt) return '—';
		const d = new Date(dt);
		return d.toLocaleString(isRtl ? 'ar-EG' : 'en-US', {
			month: 'short', day: 'numeric',
			hour: '2-digit', minute: '2-digit',
			timeZone: 'Asia/Riyadh'
		});
	}

	function getBranchName(branchId: number): string {
		const b = branches.find(br => Number(br.id) === Number(branchId));
		if (!b) return String(branchId);
		return isRtl ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar);
	}

	function getBranchLocation(branchId: number): string {
		const b = branches.find(br => Number(br.id) === Number(branchId));
		if (!b) return '';
		return isRtl ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '');
	}

</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Header/Navigation - matching ShiftAndDayOff -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			{#each tabs as tab}
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === tab.id
						? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
							: tab.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
							: 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={async () => {
						activeTab = tab.id;
						handleTabChange();
					}}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
					<span class="relative z-10">{tab.label}</span>

					{#if activeTab === tab.id}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			{/each}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 min-h-0 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto flex flex-col gap-4">

			<!-- ═══════════════════════════════════════════════════ -->
			<!-- TAB: Break Log -->
			<!-- ═══════════════════════════════════════════════════ -->
			{#if activeTab === 'Break Log'}
				<!-- Filter Controls -->
				<div class="flex gap-3 flex-wrap">
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'الحالة' : 'Status'}</label>
						<select
							bind:value={filterStatus}
							on:change={() => loadBreaks()}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;"
						>
							<option value="" style="color: #000000 !important;">{isRtl ? 'الكل' : 'All'}</option>
							<option value="open" style="color: #000000 !important;">{isRtl ? 'مفتوحة' : 'Open'}</option>
							<option value="closed" style="color: #000000 !important;">{isRtl ? 'مغلقة' : 'Closed'}</option>
						</select>
					</div>
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'الفرع' : 'Branch'}</label>
						<select
							bind:value={filterBranch}
							on:change={() => loadBreaks()}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;"
						>
							<option value="" style="color: #000000 !important;">{isRtl ? 'الكل' : 'All'}</option>
							{#each branches as branch}
								<option value={String(branch.id)} style="color: #000000 !important;">{isRtl ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar)}{branch.location_en || branch.location_ar ? ` - ${isRtl ? (branch.location_ar || branch.location_en) : (branch.location_en || branch.location_ar)}` : ''}</option>
							{/each}
						</select>
					</div>
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'من' : 'From'}</label>
						<input type="date" bind:value={filterDateFrom} on:change={() => loadBreaks()}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'إلى' : 'To'}</label>
						<input type="date" bind:value={filterDateTo} on:change={() => loadBreaks()}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-[2] min-w-[200px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'بحث' : 'Search'}</label>
						<input type="text" bind:value={searchQuery} placeholder={isRtl ? 'اسم الموظف أو معرفه...' : 'Employee name or ID...'}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					</div>
				</div>

				<!-- Stats Row -->
				<div class="flex gap-3">
					<div class="flex-1 bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-4 flex flex-col items-center">
						<span class="text-3xl font-black text-emerald-600">{openBreaks.length}</span>
						<span class="text-xs font-bold text-slate-500 uppercase tracking-wide mt-1">{isRtl ? 'استراحات مفتوحة' : 'Open Breaks'}</span>
					</div>
					<div class="flex-1 bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-4 flex flex-col items-center">
						<span class="text-3xl font-black text-slate-500">{closedBreaks.length}</span>
						<span class="text-xs font-bold text-slate-500 uppercase tracking-wide mt-1">{isRtl ? 'استراحات مغلقة' : 'Closed Breaks'}</span>
					</div>
					<div class="flex-1 bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-4 flex flex-col items-center">
						<span class="text-3xl font-black text-blue-600">{filteredBreaks.length}</span>
						<span class="text-xs font-bold text-slate-500 uppercase tracking-wide mt-1">{isRtl ? 'الإجمالي' : 'Total'}</span>
					</div>
				</div>

				{#if loading}
					<div class="flex items-center justify-center py-16">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">{isRtl ? 'جاري التحميل...' : 'Loading...'}</p>
						</div>
					</div>
				{:else if filteredBreaks.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">☕</div>
						<p class="text-slate-600 font-semibold">{isRtl ? 'لا توجد استراحات مسجلة' : 'No breaks recorded'}</p>
					</div>
				{:else}
					<!-- Open Breaks Section -->
					{#if openBreaks.length > 0}
						<div>
							<h3 class="text-sm font-black uppercase tracking-wider text-emerald-700 mb-3 flex items-center gap-2">
								<span>🟢</span> {isRtl ? 'الاستراحات المفتوحة حالياً' : 'Currently Open Breaks'}
							</h3>
							<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
								<div class="overflow-x-auto">
									<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
										<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
											<tr>
												<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'الموظف' : 'Employee'}</th>
												<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'المعرف' : 'ID'}</th>
												<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'الفرع' : 'Branch'}</th>
												<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'السبب' : 'Reason'}</th>
												<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'ملاحظة' : 'Note'}</th>
												<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'وقت البدء' : 'Start Time'}</th>
												<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'المدة' : 'Duration'}</th>
											</tr>
										</thead>
										<tbody class="divide-y divide-slate-200">
											{#each openBreaks as b}
												<tr class="bg-emerald-50/50 hover:bg-emerald-100/50 transition-colors duration-200">
													<td class="px-4 py-3 text-sm text-slate-700 font-medium">{isRtl ? (b.employee_name_ar || b.employee_name_en) : (b.employee_name_en || b.employee_name_ar)}</td>
													<td class="px-4 py-3 text-sm text-slate-400 font-mono">{b.employee_id}</td>
											<td class="px-4 py-3 text-sm text-slate-700">
												<div class="font-semibold">{b.branch_name_en ? (isRtl ? (b.branch_name_ar || b.branch_name_en) : b.branch_name_en) : getBranchName(b.branch_id)}</div>
												{#if getBranchLocation(b.branch_id)}<div class="text-[10px] text-slate-400">{getBranchLocation(b.branch_id)}</div>{/if}
											</td>
													<td class="px-4 py-3 text-sm text-slate-700">{isRtl ? b.reason_ar : b.reason_en}</td>
													<td class="px-4 py-3 text-sm text-slate-500 max-w-[200px] truncate">{b.reason_note || '—'}</td>
													<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatDateTime(b.start_time)}</td>
													<td class="px-4 py-3 text-sm text-center font-mono font-bold text-red-600">
														{getLiveDuration(b.start_time, now)}
													</td>
												</tr>
											{/each}
										</tbody>
									</table>
								</div>
								<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
									{isRtl ? `${openBreaks.length} استراحة مفتوحة` : `${openBreaks.length} open break(s)`}
								</div>
							</div>
						</div>
					{/if}

					<!-- All Breaks Table -->
					<div>
						<h3 class="text-sm font-black uppercase tracking-wider text-slate-700 mb-3 flex items-center gap-2">
							<span>📋</span> {isRtl ? 'جميع الاستراحات' : 'All Breaks'}
						</h3>
						<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
							<div class="max-h-[calc(100vh-380px)] overflow-auto">
								<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
									<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
										<tr>
											<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'الموظف' : 'Employee'}</th>
											<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'المعرف' : 'ID'}</th>
											<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'الفرع' : 'Branch'}</th>
											<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'السبب' : 'Reason'}</th>
											<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'ملاحظة' : 'Note'}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'البدء' : 'Start'}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'الانتهاء' : 'End'}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'المدة' : 'Duration'}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{isRtl ? 'الحالة' : 'Status'}</th>
										</tr>
									</thead>
									<tbody class="divide-y divide-slate-200">
										{#each filteredBreaks as b, index}
											<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {b.status === 'open' ? '!bg-emerald-50/50' : ''}">
												<td class="px-4 py-3 text-sm text-slate-700 font-medium">{isRtl ? (b.employee_name_ar || b.employee_name_en) : (b.employee_name_en || b.employee_name_ar)}</td>
												<td class="px-4 py-3 text-sm text-slate-400 font-mono">{b.employee_id}</td>
										<td class="px-4 py-3 text-sm text-slate-700">
											<div class="font-semibold">{b.branch_name_en ? (isRtl ? (b.branch_name_ar || b.branch_name_en) : b.branch_name_en) : getBranchName(b.branch_id)}</div>
											{#if getBranchLocation(b.branch_id)}<div class="text-[10px] text-slate-400">{getBranchLocation(b.branch_id)}</div>{/if}
										</td>
												<td class="px-4 py-3 text-sm text-slate-700">{isRtl ? b.reason_ar : b.reason_en}</td>
												<td class="px-4 py-3 text-sm text-slate-500 max-w-[200px] truncate">{b.reason_note || '—'}</td>
												<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatDateTime(b.start_time)}</td>
												<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatDateTime(b.end_time)}</td>
												<td class="px-4 py-3 text-sm text-center font-mono font-bold {b.status === 'open' ? 'text-red-600' : 'text-slate-700'}">{b.status === 'open' ? getLiveDuration(b.start_time, now) : formatDuration(b.duration_seconds)}</td>
												<td class="px-4 py-3 text-sm text-center">
													<span class="inline-block px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wider {b.status === 'open' ? 'bg-emerald-200 text-emerald-800' : 'bg-slate-200 text-slate-600'}">
														{b.status === 'open' ? (isRtl ? 'مفتوحة' : 'Open') : (isRtl ? 'مغلقة' : 'Closed')}
													</span>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
							<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
								{isRtl ? `عرض ${filteredBreaks.length} استراحة` : `Showing ${filteredBreaks.length} break(s)`}
							</div>
						</div>
					</div>
				{/if}

			<!-- ═══════════════════════════════════════════════════ -->
			<!-- TAB: Break Reasons -->
			<!-- ═══════════════════════════════════════════════════ -->
			{:else if activeTab === 'Break Reasons'}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
					<!-- Action Button -->
					<div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
						<button
							class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
							on:click={() => openReasonModal()}
						>
							<span>➕</span>
							{isRtl ? 'إضافة سبب استراحة' : 'Add Break Reason'}
						</button>
					</div>

					<!-- Table -->
					<div class="overflow-x-auto flex-1">
						{#if breakReasons.length === 0}
							<div class="flex items-center justify-center h-64">
								<div class="text-center">
									<div class="text-5xl mb-4">📭</div>
									<p class="text-slate-600 font-semibold">{isRtl ? 'لا توجد أسباب مسجلة' : 'No break reasons found'}</p>
									<p class="text-slate-400 text-sm mt-2">{isRtl ? 'اضغط على الزر أعلاه للإضافة' : 'Click the button above to add one'}</p>
								</div>
							</div>
						{:else}
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{isRtl ? 'الترتيب' : 'Order'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{isRtl ? 'الاسم (EN)' : 'Name (EN)'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{isRtl ? 'الاسم (AR)' : 'Name (AR)'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{isRtl ? 'نشط' : 'Active'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{isRtl ? 'يتطلب ملاحظة' : 'Requires Note'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{isRtl ? 'إجراءات' : 'Actions'}</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each breakReasons as reason, index}
										<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-4 py-3 text-sm text-center font-mono font-bold text-slate-600">{reason.sort_order}</td>
											<td class="px-4 py-3 text-sm text-slate-700">{reason.name_en}</td>
											<td class="px-4 py-3 text-sm text-slate-700" dir="rtl">{reason.name_ar}</td>
											<td class="px-4 py-3 text-sm text-center">
												<span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {reason.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
													{reason.is_active ? (isRtl ? '✓ نشط' : '✓ Yes') : (isRtl ? '✗ غير نشط' : '✗ No')}
												</span>
											</td>
											<td class="px-4 py-3 text-sm text-center">
												<span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {reason.requires_note ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'}">
													{reason.requires_note ? (isRtl ? '✓ نعم' : '✓ Yes') : (isRtl ? '✗ لا' : '✗ No')}
												</span>
											</td>
											<td class="px-4 py-3 text-sm text-center">
												<div class="flex gap-2 justify-center">
													<button
														class="px-3 py-1 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-xs font-semibold"
														on:click={() => openReasonModal(reason)}
													>
														✏️ {isRtl ? 'تعديل' : 'Edit'}
													</button>
													<button
														class="px-3 py-1 bg-red-600 text-white rounded-lg hover:bg-red-700 transition text-xs font-semibold"
														on:click={() => deleteReason(reason.id)}
													>
														🗑️ {isRtl ? 'حذف' : 'Delete'}
													</button>
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						{/if}
					</div>

					<!-- Footer -->
					<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
						{isRtl ? `عرض ${breakReasons.length} سبب` : `Showing ${breakReasons.length} reason(s)`}
					</div>
				</div>

			<!-- ═══════════════════════════════════════════════════ -->
			<!-- TAB: Employee Summary -->
			<!-- ═══════════════════════════════════════════════════ -->
			{:else if activeTab === 'Employee Summary'}
				<!-- Filters -->
				<div class="flex gap-3 flex-wrap">
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'الفرع' : 'Branch'}</label>
						<select
							bind:value={summaryBranch}
							on:change={loadSummaryData}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;"
						>
							<option value="" style="color: #000000 !important;">{isRtl ? 'الكل' : 'All'}</option>
							{#each branches as branch}
								<option value={String(branch.id)} style="color: #000000 !important;">{isRtl ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar)}{branch.location_en || branch.location_ar ? ` - ${isRtl ? (branch.location_ar || branch.location_en) : (branch.location_en || branch.location_ar)}` : ''}</option>
							{/each}
						</select>
					</div>
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'من' : 'From'}</label>
						<input type="date" bind:value={summaryDateFrom} on:change={loadSummaryData}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" />
					</div>
					<div class="flex-1 min-w-[140px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'إلى' : 'To'}</label>
						<input type="date" bind:value={summaryDateTo} on:change={loadSummaryData}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" />
					</div>
				</div>

				{#if loadingSummary}
					<div class="flex items-center justify-center py-16">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">{isRtl ? 'جاري التحميل...' : 'Loading...'}</p>
						</div>
					</div>
				{:else if employeeSummaries.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📊</div>
						<p class="text-slate-600 font-semibold">{isRtl ? 'لا توجد بيانات للملخص' : 'No summary data available'}</p>
					</div>
				{:else}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
						<div class="max-h-[calc(100vh-380px)] overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-orange-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'التاريخ' : 'Date'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'الموظف' : 'Employee'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'المعرف' : 'ID'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'الفرع' : 'Branch'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'السبب' : 'Reason'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'عدد الاستراحات' : 'Break Count'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'مفتوحة' : 'Open'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'إجمالي المدة' : 'Total Duration'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'متوسط المدة' : 'Avg Duration'}</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each employeeSummaries as emp, index}
										<tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-4 py-3 text-sm text-slate-800 font-semibold">{formatSummaryDate(emp.date)}</td>
											<td class="px-4 py-3 text-sm text-slate-700 font-medium">{isRtl ? (emp.employee_name_ar || emp.employee_name_en) : (emp.employee_name_en || emp.employee_name_ar)}</td>
											<td class="px-4 py-3 text-sm text-slate-400 font-mono">{emp.employee_id}</td>
											<td class="px-4 py-3 text-sm text-slate-700">
										<div class="font-semibold">{isRtl ? (emp.branch_name_ar || emp.branch_name_en) : (emp.branch_name_en || emp.branch_name_ar)}</div>
										{#if getBranchLocation(emp.branch_id)}<div class="text-[10px] text-slate-400">{getBranchLocation(emp.branch_id)}</div>{/if}
									</td>
											<td class="px-4 py-3 text-sm text-slate-700">{emp.reason}</td>
											<td class="px-4 py-3 text-sm text-center font-bold text-slate-800">{emp.total_breaks}</td>
											<td class="px-4 py-3 text-sm text-center">
												{#if emp.open_breaks > 0}
													<span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold bg-emerald-200 text-emerald-800">{emp.open_breaks}</span>
												{:else}
													<span class="text-slate-400">0</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-sm text-center font-mono font-bold text-slate-700">{formatDurationHM(emp.total_duration)}</td>
											<td class="px-4 py-3 text-sm text-center font-mono text-slate-600">{emp.total_breaks > 0 ? formatDurationHM(Math.round(emp.total_duration / emp.total_breaks)) : '—'}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>

						<!-- Footer -->
						<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
							{isRtl ? `عرض ${employeeSummaries.length} سجل` : `Showing ${employeeSummaries.length} record(s)`}
						</div>
					</div>
				{/if}
			{/if}

		</div>
	</div>
</div>

<!-- Break Reason Add/Edit Modal -->
{#if showReasonModal}
	<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto" dir={isRtl ? 'rtl' : 'ltr'}>
			<div class="flex items-center justify-between mb-6">
				<h2 class="text-2xl font-bold text-slate-900">
					{editingReasonId !== null ? (isRtl ? 'تعديل سبب الاستراحة' : 'Edit Break Reason') : (isRtl ? 'إضافة سبب استراحة' : 'Add Break Reason')}
				</h2>
				<button
					class="text-slate-400 hover:text-slate-600 text-2xl"
					on:click={closeReasonModal}
				>
					✕
				</button>
			</div>

			<form on:submit|preventDefault={saveReason} class="space-y-4">
				<!-- English Name -->
				<div>
					<label for="reason-name-en" class="block text-sm font-bold text-slate-700 mb-2">{isRtl ? 'الاسم بالإنجليزية' : 'Name (English)'}</label>
					<input
						id="reason-name-en"
						type="text"
						bind:value={reasonFormData.name_en}
						placeholder={isRtl ? 'أدخل الاسم بالإنجليزية' : 'Enter English name'}
						class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>

				<!-- Arabic Name -->
				<div>
					<label for="reason-name-ar" class="block text-sm font-bold text-slate-700 mb-2">{isRtl ? 'الاسم بالعربية' : 'Name (Arabic)'}</label>
					<input
						id="reason-name-ar"
						type="text"
						bind:value={reasonFormData.name_ar}
						placeholder={isRtl ? 'أدخل الاسم بالعربية' : 'Enter Arabic name'}
						dir="rtl"
						class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
					/>
				</div>

				<!-- Sort Order -->
				<div>
					<label for="reason-sort" class="block text-sm font-bold text-slate-700 mb-2">{isRtl ? 'ترتيب العرض' : 'Sort Order'}</label>
					<input
						id="reason-sort"
						type="number"
						bind:value={reasonFormData.sort_order}
						min="0"
						class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>

				<!-- Is Active Toggle -->
				<div>
					<label for="active-toggle" class="block text-sm font-bold text-slate-700 mb-2">{isRtl ? 'نشط' : 'Active'}</label>
					<button
						id="active-toggle"
						type="button"
						on:click={() => reasonFormData.is_active = !reasonFormData.is_active}
						class="w-full px-4 py-3 rounded-lg font-bold text-white transition-all {reasonFormData.is_active ? 'bg-green-600 hover:bg-green-700' : 'bg-red-600 hover:bg-red-700'}"
					>
						{reasonFormData.is_active ? (isRtl ? '✓ نشط' : '✓ Active') : (isRtl ? '✗ غير نشط' : '✗ Inactive')}
					</button>
				</div>

				<!-- Requires Note Toggle -->
				<div>
					<label for="note-toggle" class="block text-sm font-bold text-slate-700 mb-2">{isRtl ? 'يتطلب ملاحظة' : 'Requires Note'}</label>
					<button
						id="note-toggle"
						type="button"
						on:click={() => reasonFormData.requires_note = !reasonFormData.requires_note}
						class="w-full px-4 py-3 rounded-lg font-bold text-white transition-all {reasonFormData.requires_note ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-600 hover:bg-gray-700'}"
					>
						{reasonFormData.requires_note ? (isRtl ? '✓ نعم يتطلب ملاحظة' : '✓ Yes, requires note') : (isRtl ? '✗ لا يتطلب ملاحظة' : '✗ No, note not required')}
					</button>
				</div>

				<!-- Buttons -->
				<div class="flex gap-3 mt-6">
					<button
						type="submit"
						disabled={isSaving}
						class="flex-1 px-4 py-2 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 transition disabled:opacity-50"
					>
						{isSaving ? (isRtl ? 'جاري الحفظ...' : 'Saving...') : (isRtl ? 'حفظ' : 'Save')}
					</button>
					<button
						type="button"
						on:click={closeReasonModal}
						class="flex-1 px-4 py-2 rounded-lg font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
					>
						{isRtl ? 'إلغاء' : 'Cancel'}
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	/* Tailwind classes used inline */
</style>
