<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import YmdDatePicker from './YmdDatePicker.svelte';
	import BreakLog from '$lib/components/common/BreakLog.svelte';
	import BreakTotalSummary from '$lib/components/common/BreakTotalSummary.svelte';
	import { loadBreakRegisterData } from '$lib/utils/breakRegisterApi';
	import { addDays, breakShiftDate, shiftTimeLabel, type ShiftSchedules, type ShiftSlot } from '$lib/utils/breakShiftDate';

	let breaks: any[] = [];
	let branches: any[] = [];
	let realtimeChannel: any = null;
	let cleanupVisibility: (() => void) | null = null;
	let cleanupOnline: (() => void) | null = null;

	// Tabs
	let activeTab = 'Break Log';
	$: tabs = [
		{ id: 'Break Log', label: isRtl ? 'سجل الاستراحات' : 'Break Log', icon: '☕', color: 'green' },
		{ id: 'Break Reasons', label: isRtl ? 'أسباب الاستراحة' : 'Break Reasons', icon: '📌', color: 'blue' },
		{ id: 'Employee Summary', label: isRtl ? 'ملخص الموظف' : 'Employee Summary', icon: '📊', color: 'orange' },
		{ id: 'Total Summary', label: isRtl ? 'الملخص الإجمالي' : 'Total Summary', icon: '📈', color: 'purple' }
	];

	// Break Reasons
	let breakReasons: any[] = [];
	let showReasonModal = false;
	let editingReasonId: number | null = null;
	let reasonFormData = { name_en: '', name_ar: '', sort_order: 0, is_active: true, requires_note: false, max_allowed_minutes: null as number | null };
	let isSaving = false;

	async function loadShiftDatedBreaks(dateFrom: string, dateTo: string, branchId: string, scheduledEmployeeIds: string[]): Promise<{ records: any[]; schedules: ShiftSchedules }> {
		const emptySchedules: ShiftSchedules = { regular: [], weekday: [], dateWise: [] };
		if (!dateFrom || !dateTo) return { records: [], schedules: emptySchedules };
		const params: any = { p_date_from: addDays(dateFrom, -1), p_date_to: addDays(dateTo, 1) };
		if (branchId) params.p_branch_id = parseInt(branchId);
		const { data, error } = await (async () => { try { return { data: await loadBreakRegisterData('logs', { from: params.p_date_from, to: params.p_date_to, branch: params.p_branch_id ? String(params.p_branch_id) : undefined, status: params.p_status }), error: null }; } catch (error) { return { data: null, error }; } })();
		if (error) throw error;
		const records: any[] = data?.breaks || [];
		const ids = [...new Set([...records.map(b => String(b.employee_id)), ...scheduledEmployeeIds])];
		const sources = [
			['hr_regular_shift_versions', 'hr_regular_shift_slots'],
			['hr_special_shift_weekday_versions', 'hr_special_shift_weekday_slots'],
			['hr_special_shift_date_wise_versions', 'hr_special_shift_date_wise_slots']
		] as const;
		const loadSource = async (versionTable: string, slotTable: string): Promise<ShiftSlot[]> => {
			const versions: any[] = [];
			for (let i = 0; i < ids.length; i += 100) {
				let offset = 0;
				while (true) {
					const { data: page, error: versionError } = await supabase.from(versionTable)
						.select('*')
						.in('employee_id', ids.slice(i, i + 100))
						.lte('date_from', dateTo)
						.or(`date_to.is.null,date_to.gte.${addDays(dateFrom, -1)}`)
						.order('id').range(offset, offset + 999);
					if (versionError) throw versionError;
					versions.push(...(page || []));
					if (!page || page.length < 1000) break;
					offset += 1000;
				}
			}
			const slots: ShiftSlot[] = [];
			for (let i = 0; i < versions.length; i += 100) {
				const batch = versions.slice(i, i + 100);
				const { data: rows, error: slotError } = await supabase.from(slotTable)
					.select('version_id, shift_start_time, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day')
					.in('version_id', batch.map(v => v.id));
				if (slotError) throw slotError;
				const versionsById = new Map(batch.map(v => [v.id, v]));
				for (const row of rows || []) {
					const version = versionsById.get(row.version_id);
					if (version) slots.push({ ...version, ...row });
				}
			}
			return slots;
		};
		const [regular, weekday, dateWise] = await Promise.all(sources.map(([v, s]) => loadSource(v, s)));
		const schedules: ShiftSchedules = { regular, weekday, dateWise };
		return {
			schedules,
			records: records.map(b => ({ ...b, shift_date: breakShiftDate(String(b.employee_id), b.start_time, schedules) }))
				.filter(b => b.shift_date >= dateFrom && b.shift_date <= dateTo)
		};
	}

	// Employee Summary
	let summaryDateFrom = '';
	let summaryDateTo = '';
	let summaryBranch = '';
	let summarySearchQuery = '';
	let employeeSummaries: any[] = [];
	let loadingSummary = false;
	let summaryScheduledSet = new Set<string>();
	let summaryEmployeesById = new Map<string, any>();
	let summaryActiveEmployeeIds = new Set<string>();
	let summarySchedules: ShiftSchedules = { regular: [], weekday: [], dateWise: [] };

	// Riyadh-local date string, `daysAgo` days before today (0 = today, 1 = yesterday)
	function riyadhDateStr(daysAgo = 0): string {
		const now = new Date();
		const riyadhOffset = 3 * 60; // UTC+3
		const utcMs = now.getTime() + now.getTimezoneOffset() * 60000;
		const riyadhNow = new Date(utcMs + riyadhOffset * 60000 - daysAgo * 24 * 60 * 60 * 1000);
		return riyadhNow.toISOString().split('T')[0];
	}

	$: filteredSummaries = employeeSummaries.filter(emp => {
		if (!summarySearchQuery.trim()) return true;
		const s = summarySearchQuery.toLowerCase();
		return (emp.employee_name_en || '').toLowerCase().includes(s)
			|| (emp.employee_name_ar || '').includes(s)
			|| (emp.employee_id || '').toLowerCase().includes(s);
	});

	$: isRtl = $locale === 'ar';

	onMount(async () => {
		// Default every tab to yesterday only — the user can pick any custom
		// year/month/day range via the date filters once loaded.
		const yesterdayStr = riyadhDateStr(1);
		summaryDateFrom = yesterdayStr;
		summaryDateTo = yesterdayStr;

		await Promise.all([loadBranches(), loadBreakReasons()]);

		// Subscribe to realtime changes
		setupRealtimeChannel();

		// Handle PWA visibility changes — reconnect realtime + refresh data when app comes back
		const handleVisibilityChange = () => {
			if (document.visibilityState === 'visible') {
				console.log('👁️ Break register: App became visible, refreshing data & reconnecting realtime');
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
			.on('postgres_changes', { event: '*', schema: 'public', table: 'break_reasons' }, () => {
				loadBreakReasons();
			})
			.subscribe((status: string) => {
				console.log('📡 Break register realtime status:', status);
			});
	}

	onDestroy(() => {
		if (realtimeChannel) supabase.removeChannel(realtimeChannel);
		if (cleanupVisibility) cleanupVisibility();
		if (cleanupOnline) cleanupOnline();
	});

	function handleTabChange() {
		if (activeTab === 'Break Reasons') {
			loadBreakReasons();
		} else if (activeTab === 'Employee Summary') {
			loadSummaryData();
		}
	}

	async function loadBranches() {
		const { data } = await supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').eq('is_active', true).order('id');
		if (data) branches = data;
	}

	// Break Reasons CRUD
	// ═══════════════════════════════════════
	async function loadBreakReasons() {
		const { data, error } = await supabase
			.from('break_reasons')
			.select('*')
			.eq('deleted', false)
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
				requires_note: reason.requires_note ?? false,
				max_allowed_minutes: reason.max_allowed_minutes ?? null
			};
		} else {
			editingReasonId = null;
			const maxSort = breakReasons.reduce((max: number, r: any) => Math.max(max, r.sort_order ?? 0), 0);
			reasonFormData = {
				name_en: '',
				name_ar: '',
				sort_order: maxSort + 1,
				is_active: true,
				requires_note: false,
				max_allowed_minutes: null
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
			const { error } = await supabase
				.from('break_reasons')
				.update({ deleted: true, deleted_at: new Date().toISOString() })
				.eq('id', id);
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
		try {
			const scheduled = await computeScheduledSet(summaryDateFrom, summaryDateTo, summaryBranch);
			const shiftDated = await loadShiftDatedBreaks(summaryDateFrom, summaryDateTo, summaryBranch, [...scheduled.employees.keys()]);
			summaryScheduledSet = scheduled.scheduled;
			summaryEmployeesById = scheduled.employees;
			summaryActiveEmployeeIds = scheduled.activeEmployeeIds;
			summarySchedules = shiftDated.schedules;
			breaks = shiftDated.records;
			computeEmployeeSummaries();
		} catch (err) {
			console.error('Error loading employee summary:', err);
		} finally {
			loadingSummary = false;
		}
	}

	function computeEmployeeSummaries() {
		const map = new Map<string, any>();
		let filtered = summaryBranch
			? breaks.filter(b => String(b.branch_id) === summaryBranch)
			: breaks;
		// Drop breaks logged by employees who are now on Vacation / Remote Job / Resigned —
		// only skip this when the active-employee lookup itself failed to load.
		if (summaryActiveEmployeeIds.size > 0) {
			filtered = filtered.filter(b => summaryActiveEmployeeIds.has(b.employee_id));
		}

		const presentDays = new Set<string>();
		for (const b of filtered) {
			// Group by employee + date + reason
			const breakDate = b.shift_date || 'unknown';
			presentDays.add(`${b.employee_id}__${breakDate}`);
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

		// Add placeholder rows for employees who were scheduled that day but logged zero breaks
		for (const key of summaryScheduledSet) {
			if (presentDays.has(key)) continue;
			const [employeeId, date] = key.split('__');
			const emp = summaryEmployeesById.get(employeeId);
			if (!emp) continue;
			map.set(`${key}__none`, {
				employee_id: employeeId,
				employee_name_en: emp.name_en,
				employee_name_ar: emp.name_ar,
				branch_name_en: emp.branch_name_en,
				branch_name_ar: emp.branch_name_ar,
				branch_id: emp.branch_id,
				date,
				reason: '—',
				total_breaks: 0,
				open_breaks: 0,
				total_duration: 0,
				is_placeholder: true
			});
		}

		employeeSummaries = Array.from(map.values()).sort((a: any, b: any) => {
			// Sort by date descending, then employee name
			if (a.date !== b.date) return b.date.localeCompare(a.date);
			const nameA = a.employee_name_en || a.employee_name_ar || '';
			const nameB = b.employee_name_en || b.employee_name_ar || '';
			return nameA.localeCompare(nameB);
		});
	}

	// ═══════════════════════════════════════
	// Shift-schedule resolution (shared by Employee Summary + Total Summary)
	// Backed by the get_break_schedule_status RPC, which mirrors the date-wise >
	// weekday > regular precedence used in Shifts.svelte's loadCurrentShifts(),
	// server-side, across a date range for many employees at once.
	// ═══════════════════════════════════════
	async function computeScheduledSet(dateFrom: string, dateTo: string, branchId: string): Promise<{ scheduled: Set<string>; employees: Map<string, any>; activeEmployeeIds: Set<string> }> {
		const scheduled = new Set<string>();
		const employees = new Map<string, any>();
		const activeEmployeeIds = new Set<string>();
		if (!dateFrom || !dateTo) return { scheduled, employees, activeEmployeeIds };

		const params: any = { p_date_from: dateFrom, p_date_to: dateTo };
		if (branchId) params.p_branch_id = parseInt(branchId);

		const { data, error } = await (async () => { try { return { data: await loadBreakRegisterData('schedule', { from: params.p_date_from, to: params.p_date_to, branch: params.p_branch_id ? String(params.p_branch_id) : undefined }), error: null }; } catch (error) { return { data: null, error }; } })();
		if (error || !data?.rows) {
			console.error('Error loading break schedule status:', error);
			return { scheduled, employees, activeEmployeeIds };
		}

		// The RPC only ever returns currently-active employees (Remote Job / Vacation /
		// Resigned are excluded server-side), so every row here doubles as the
		// active-employee whitelist, regardless of whether that particular day is scheduled.
		for (const r of data.rows) {
			activeEmployeeIds.add(r.employee_id);
			if (r.scheduled) scheduled.add(`${r.employee_id}__${r.shift_date}`);
			if (!employees.has(r.employee_id)) {
				employees.set(r.employee_id, {
					name_en: r.name_en,
					name_ar: r.name_ar,
					branch_id: r.branch_id,
					branch_name_en: r.branch_name_en || 'N/A',
					branch_name_ar: r.branch_name_ar || 'N/A'
				});
			}
		}

		return { scheduled, employees, activeEmployeeIds };
	}

	function formatSummaryDate(dateStr: string): string {
		if (!dateStr || dateStr === 'unknown') return '—';
		const d = new Date(dateStr + 'T00:00:00');
		return d.toLocaleDateString(isRtl ? 'ar-EG' : 'en-US', {
			year: 'numeric', month: 'short', day: 'numeric',
			weekday: 'short'
		});
	}

	function formatDurationHM(seconds: number): string {
		if (!seconds) return '0m';
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		if (h > 0) return `${h}h ${m}m`;
		return `${m}m`;
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

	// ═══════════════════════════════════════
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
							: tab.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'						: tab.color === 'purple' ? 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]'							: tab.color === 'indigo' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200 scale-[1.02]'							: 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
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
				<BreakLog layout="desktop" />
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
					<div class="flex-1 min-w-[220px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'التاريخ' : 'Date'}</label>
						<YmdDatePicker bind:value={summaryDateFrom} {isRtl} accentClass="focus:ring-orange-500" on:change={() => { summaryDateTo = summaryDateFrom; loadSummaryData(); }} />
					</div>
					<div class="flex-[2] min-w-[200px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{isRtl ? 'بحث' : 'Search'}</label>
						<input type="text" bind:value={summarySearchQuery} placeholder={isRtl ? 'اسم الموظف أو معرفه...' : 'Employee name or ID...'}
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
				{:else if filteredSummaries.length === 0}
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
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'وقت الوردية' : 'Shift Time'}</th>
										<th class="px-4 py-3 {isRtl ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'السبب' : 'Reason'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'عدد الاستراحات' : 'Break Count'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'مفتوحة' : 'Open'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'إجمالي المدة' : 'Total Duration'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{isRtl ? 'متوسط المدة' : 'Avg Duration'}</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredSummaries as emp, index}
										<tr class="hover:bg-orange-50/30 transition-colors duration-200 {emp.is_placeholder ? 'opacity-60' : ''} {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-4 py-3 text-sm text-slate-800 font-semibold">{formatSummaryDate(emp.date)}</td>
											<td class="px-4 py-3 text-sm text-slate-700 font-medium">{isRtl ? (emp.employee_name_ar || emp.employee_name_en) : (emp.employee_name_en || emp.employee_name_ar)}</td>
											<td class="px-4 py-3 text-sm text-slate-400 font-mono">{emp.employee_id}</td>
											<td class="px-4 py-3 text-sm text-slate-700">
										<div class="font-semibold">{isRtl ? (emp.branch_name_ar || emp.branch_name_en) : (emp.branch_name_en || emp.branch_name_ar)}</div>
										{#if getBranchLocation(emp.branch_id)}<div class="text-[10px] text-slate-400">{getBranchLocation(emp.branch_id)}</div>{/if}
									</td>
										<td class="px-4 py-3 text-sm text-center font-mono text-slate-700 whitespace-nowrap">{shiftTimeLabel(emp.employee_id, emp.date, summarySchedules)}</td>
											<td class="px-4 py-3 text-sm {emp.is_placeholder ? 'italic text-slate-400' : 'text-slate-700'}">{emp.is_placeholder ? (isRtl ? 'لم تُسجَّل استراحة' : 'No break logged') : emp.reason}</td>
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
							{isRtl ? `عرض ${filteredSummaries.length} سجل` : `Showing ${filteredSummaries.length} record(s)`}
						</div>
					</div>
				{/if}

			<!-- ═══════════════════════════════════════════════════ -->
			<!-- TAB: Total Summary (Flat table - one row per employee per date) -->
			<!-- ═══════════════════════════════════════════════════ -->
			{:else if activeTab === 'Total Summary'}
				<BreakTotalSummary layout="desktop" />
			{/if}

			<!-- Permission Manager moved into the App Permissions window
			     (Controls > Dashboard > Break Register tab) — see
			     Do not delete/PERMISSION_SYSTEMS_AUDIT.md. -->

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

				<!-- Max Allowed Minutes -->
				<div>
					<label for="reason-max-minutes" class="block text-sm font-bold text-slate-700 mb-2">{isRtl ? 'الحد الأقصى للمدة (دقيقة)' : 'Max Allowed Minutes'}</label>
					<input
						id="reason-max-minutes"
						type="number"
						bind:value={reasonFormData.max_allowed_minutes}
						min="1"
						placeholder={isRtl ? 'اتركه فارغاً لعدم التحديد' : 'Leave empty for no limit'}
						class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
					<p class="text-xs text-slate-500 mt-1">{isRtl ? 'الحد الأقصى لمدة الاستراحة لهذا السبب' : 'Maximum break duration allowed for this reason'}</p>
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
