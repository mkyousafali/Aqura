<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, locale } from '$lib/i18n';

	// Data
	let employees: any[] = [];
	let branches: any[] = [];
	let nationalities: any[] = [];
	let positions: any[] = [];
	let attendanceData: any[] = [];
	let isLoading = true;
	let error = '';

	// Filters
	let selectedBranch = '';
	let selectedStatus = '';
	let searchQuery = '';

	// Computed stats
	let totalEmployees = 0;
	let activeEmployees = 0;
	let resignedEmployees = 0;
	let vacationEmployees = 0;
	let terminatedEmployees = 0;
	let remoteEmployees = 0;
	let runAwayEmployees = 0;

	// Attendance stats
	let attendanceByStatus: { name: string; count: number; color: string }[] = [];
	let todayAttendanceTotal = 0;

	// Expiry alerts
	let expiringDocuments: any[] = [];
	let expiryDays = 30;

	// Breakdowns
	let byBranch: { name: string; count: number; color: string }[] = [];
	let byNationality: { name: string; count: number; color: string }[] = [];
	let byPosition: { name: string; count: number; color: string }[] = [];
	let byStatus: { name: string; count: number; color: string }[] = [];
	let bySponsor: { name: string; count: number; color: string }[] = [];

	// Tab
	type TabId = 'overview' | 'attendance' | 'expiry' | 'breakdown';
	let activeTab: TabId = 'overview';

	const tabs: { id: TabId; icon: string; label: string; color: string }[] = [
		{ id: 'overview', icon: '📊', label: 'Overview', color: 'blue' },
		{ id: 'attendance', icon: '🕐', label: 'Attendance', color: 'teal' },
		{ id: 'expiry', icon: '⚠️', label: 'Expiry Alerts', color: 'orange' },
		{ id: 'breakdown', icon: '📈', label: 'Breakdowns', color: 'green' },
	];

	const STATUS_COLORS: Record<string, string> = {
		'Job (With Finger)': '#10b981',
		'Job (No Finger)': '#3b82f6',
		'Remote Job': '#8b5cf6',
		'Vacation': '#f59e0b',
		'Resigned': '#ef4444',
		'Terminated': '#dc2626',
		'Run Away': '#991b1b',
	};

	const STATUS_BG: Record<string, string> = {
		'Job (With Finger)': 'bg-emerald-100 text-emerald-800',
		'Job (No Finger)': 'bg-blue-100 text-blue-800',
		'Remote Job': 'bg-violet-100 text-violet-800',
		'Vacation': 'bg-amber-100 text-amber-800',
		'Resigned': 'bg-red-100 text-red-800',
		'Terminated': 'bg-red-200 text-red-900',
		'Run Away': 'bg-red-300 text-red-900',
	};

	const CHART_COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4', '#f97316', '#84cc16', '#6366f1'];

	const ATTENDANCE_COLORS: Record<string, string> = {
		'Worked': '#10b981',
		'Absent': '#ef4444',
		'Check-In Missing': '#f97316',
		'Check-Out Missing': '#f59e0b',
		'Official Day Off': '#8b5cf6',
		'Official Holiday': '#3b82f6',
		'Approved Leave (Deductible)': '#06b6d4',
		'Approved Leave (No Deduction)': '#0ea5e9',
		'Pending Approval': '#eab308',
		'Rejected-Not Deducted': '#dc2626',
	};

	const ATTENDANCE_BG: Record<string, string> = {
		'Worked': 'bg-emerald-100 text-emerald-800',
		'Absent': 'bg-red-100 text-red-800',
		'Check-In Missing': 'bg-orange-100 text-orange-800',
		'Check-Out Missing': 'bg-amber-100 text-amber-800',
		'Official Day Off': 'bg-violet-100 text-violet-800',
		'Official Holiday': 'bg-blue-100 text-blue-800',
		'Approved Leave (Deductible)': 'bg-cyan-100 text-cyan-800',
		'Approved Leave (No Deduction)': 'bg-sky-100 text-sky-800',
		'Pending Approval': 'bg-yellow-100 text-yellow-800',
		'Rejected-Not Deducted': 'bg-red-200 text-red-900',
	};

	function getIsArabic(): boolean {
		return $locale === 'ar';
	}

	async function loadData() {
		isLoading = true;
		error = '';
		try {
			const today = new Date().toISOString().split('T')[0];

			const [empRes, branchRes, natRes, posRes, attRes] = await Promise.all([
				supabase
					.from('hr_employee_master')
					.select('*, branches:current_branch_id(id, name_en, name_ar, is_active), hr_positions:current_position_id(id, position_title_en, position_title_ar), nationalities:nationality_id(id, name_en, name_ar)')
					.order('name_en'),
				supabase.from('branches').select('id, name_en, name_ar').eq('is_active', true).order('name_en'),
				supabase.from('nationalities').select('id, name_en, name_ar').order('name_en'),
				supabase.from('hr_positions').select('id, position_title_en, position_title_ar').eq('is_active', true).order('position_title_en'),
				supabase.from('hr_analysed_attendance_data').select('*').eq('shift_date', today),
			]);

			if (empRes.error) throw empRes.error;
			if (branchRes.error) throw branchRes.error;

			// Filter employees to only those in active branches
			const activeBranchIds = new Set((branchRes.data || []).map((b: any) => b.id));
			employees = (empRes.data || []).filter((e: any) => activeBranchIds.has(e.current_branch_id));

			branches = branchRes.data || [];
			nationalities = natRes.data || [];
			positions = posRes.data || [];
			attendanceData = attRes.data || [];

			// Update tab labels with i18n
			tabs[0].label = $t('employeeDashboard.overview');
			tabs[1].label = $t('employeeDashboard.attendance');
			tabs[2].label = $t('employeeDashboard.expiryAlerts');
			tabs[3].label = $t('employeeDashboard.breakdowns');

			computeStats();
		} catch (err: any) {
			console.error('Error loading dashboard data:', err);
			error = err.message || 'Failed to load data';
		} finally {
			isLoading = false;
		}
	}

	function getFilteredEmployees() {
		let filtered = employees;
		if (selectedBranch) {
			filtered = filtered.filter(e => String(e.current_branch_id) === selectedBranch);
		}
		if (selectedStatus) {
			filtered = filtered.filter(e => e.employment_status === selectedStatus);
		}
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			filtered = filtered.filter(e =>
				(e.name_en || '').toLowerCase().includes(q) ||
				(e.name_ar || '').toLowerCase().includes(q) ||
				(e.id || '').toLowerCase().includes(q)
			);
		}
		return filtered;
	}

	function computeStats() {
		const filtered = getFilteredEmployees();

		totalEmployees = filtered.length;
		activeEmployees = filtered.filter(e => e.employment_status === 'Job (With Finger)' || e.employment_status === 'Job (No Finger)').length;
		resignedEmployees = filtered.filter(e => e.employment_status === 'Resigned').length;
		vacationEmployees = filtered.filter(e => e.employment_status === 'Vacation').length;
		terminatedEmployees = filtered.filter(e => e.employment_status === 'Terminated').length;
		remoteEmployees = filtered.filter(e => e.employment_status === 'Remote Job').length;
		runAwayEmployees = filtered.filter(e => e.employment_status === 'Run Away').length;

		// By status
		const statusMap = new Map<string, number>();
		filtered.forEach(e => {
			const st = e.employment_status || 'Unknown';
			statusMap.set(st, (statusMap.get(st) || 0) + 1);
		});
		byStatus = Array.from(statusMap.entries())
			.sort((a, b) => b[1] - a[1])
			.map(([name, count]) => ({ name, count, color: STATUS_COLORS[name] || '#64748b' }));

		// By branch
		const branchMap = new Map<string, number>();
		filtered.forEach(e => {
			const isAr = getIsArabic();
			const bName = isAr
				? (e.branches?.name_ar || e.branches?.name_en || 'Unknown')
				: (e.branches?.name_en || e.branches?.name_ar || 'Unknown');
			branchMap.set(bName, (branchMap.get(bName) || 0) + 1);
		});
		byBranch = Array.from(branchMap.entries())
			.sort((a, b) => b[1] - a[1])
			.map(([name, count], i) => ({ name, count, color: CHART_COLORS[i % CHART_COLORS.length] }));

		// By nationality
		const natMap = new Map<string, number>();
		filtered.forEach(e => {
			const isAr = getIsArabic();
			const nName = isAr
				? (e.nationalities?.name_ar || e.nationalities?.name_en || 'Unknown')
				: (e.nationalities?.name_en || e.nationalities?.name_ar || 'Unknown');
			natMap.set(nName, (natMap.get(nName) || 0) + 1);
		});
		byNationality = Array.from(natMap.entries())
			.sort((a, b) => b[1] - a[1])
			.map(([name, count], i) => ({ name, count, color: CHART_COLORS[i % CHART_COLORS.length] }));

		// By position
		const posMap = new Map<string, number>();
		filtered.forEach(e => {
			const isAr = getIsArabic();
			const pName = isAr
				? (e.hr_positions?.position_title_ar || e.hr_positions?.position_title_en || 'Unassigned')
				: (e.hr_positions?.position_title_en || e.hr_positions?.position_title_ar || 'Unassigned');
			posMap.set(pName, (posMap.get(pName) || 0) + 1);
		});
		byPosition = Array.from(posMap.entries())
			.sort((a, b) => b[1] - a[1])
			.map(([name, count], i) => ({ name, count, color: CHART_COLORS[i % CHART_COLORS.length] }));

		// By sponsorship
		const sponsored = filtered.filter(e => e.sponsorship_status === true).length;
		const notSponsored = filtered.filter(e => !e.sponsorship_status).length;
		bySponsor = [
			{ name: $t('employeeDashboard.sponsored'), count: sponsored, color: '#10b981' },
			{ name: $t('employeeDashboard.notSponsored'), count: notSponsored, color: '#ef4444' },
		];

		// Expiry alerts
		computeExpiryAlerts(filtered);

		// Attendance breakdown
		computeAttendanceStats(filtered);
	}

	function computeExpiryAlerts(filtered: any[]) {
		const today = new Date();
		const futureDate = new Date();
		futureDate.setDate(today.getDate() + expiryDays);
		const todayStr = today.toISOString().split('T')[0];
		const futureStr = futureDate.toISOString().split('T')[0];

		const alerts: any[] = [];
		const isAr = getIsArabic();

		const expiryFields = [
			{ field: 'id_expiry_date', label: $t('employeeDashboard.idExpiry') },
			{ field: 'health_card_expiry_date', label: $t('employeeDashboard.healthCardExpiry') },
			{ field: 'driving_licence_expiry_date', label: $t('employeeDashboard.drivingLicenceExpiry') },
			{ field: 'contract_expiry_date', label: $t('employeeDashboard.contractExpiry') },
			{ field: 'work_permit_expiry_date', label: $t('employeeDashboard.workPermitExpiry') },
			{ field: 'insurance_expiry_date', label: $t('employeeDashboard.insuranceExpiry') },
			{ field: 'health_educational_renewal_date', label: $t('employeeDashboard.healthEducationalRenewal') },
		];

		filtered.forEach(emp => {
			// Only check active employees
			if (emp.employment_status !== 'Job (With Finger)' && emp.employment_status !== 'Job (No Finger)' && emp.employment_status !== 'Remote Job') return;

			const empName = isAr ? (emp.name_ar || emp.name_en || emp.id) : (emp.name_en || emp.name_ar || emp.id);

			expiryFields.forEach(({ field, label }) => {
				const dateVal = emp[field];
				if (!dateVal) return;

				if (dateVal <= futureStr) {
					const isExpired = dateVal < todayStr;
					const daysUntil = Math.ceil((new Date(dateVal).getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
					alerts.push({
						employeeId: emp.id,
						employeeName: empName,
						documentType: label,
						expiryDate: dateVal,
						isExpired,
						daysUntil,
						branchName: isAr ? (emp.branches?.name_ar || emp.branches?.name_en || '') : (emp.branches?.name_en || emp.branches?.name_ar || ''),
					});
				}
			});
		});

		alerts.sort((a, b) => {
			if (a.isExpired && !b.isExpired) return -1;
			if (!a.isExpired && b.isExpired) return 1;
			return a.daysUntil - b.daysUntil;
		});

		expiringDocuments = alerts;
	}

	function computeAttendanceStats(filtered: any[]) {
		// Filter attendance data by selected branch if needed
		let filteredAttendance = attendanceData;
		if (selectedBranch) {
			filteredAttendance = filteredAttendance.filter(a => String(a.branch_id) === selectedBranch);
		}

		// Also filter to only employees in the filtered list
		const empIds = new Set(filtered.map(e => e.id));
		filteredAttendance = filteredAttendance.filter(a => empIds.has(a.employee_id));

		todayAttendanceTotal = filteredAttendance.length;

		const statusMap = new Map<string, number>();
		filteredAttendance.forEach(a => {
			const st = a.status || 'Unknown';
			statusMap.set(st, (statusMap.get(st) || 0) + 1);
		});

		attendanceByStatus = Array.from(statusMap.entries())
			.sort((a, b) => b[1] - a[1])
			.map(([name, count]) => ({ name, count, color: ATTENDANCE_COLORS[name] || '#64748b' }));
	}

	function getAttendanceEmployees(status: string): any[] {
		const isAr = getIsArabic();
		let filteredAttendance = attendanceData.filter(a => a.status === status);
		if (selectedBranch) {
			filteredAttendance = filteredAttendance.filter(a => String(a.branch_id) === selectedBranch);
		}
		return filteredAttendance.map(a => ({
			id: a.employee_id,
			name: isAr ? (a.employee_name_ar || a.employee_name_en || a.employee_id) : (a.employee_name_en || a.employee_name_ar || a.employee_id),
			status: a.status,
			checkIn: a.check_in_time || '-',
			checkOut: a.check_out_time || '-',
			lateMinutes: a.late_minutes || 0,
			workedMinutes: a.worked_minutes || 0,
			overtimeMinutes: a.overtime_minutes || 0,
		}));
	}

	function formatMinutes(mins: number): string {
		if (!mins || mins === 0) return '-';
		const h = Math.floor(mins / 60);
		const m = mins % 60;
		return h > 0 ? `${h}h ${m}m` : `${m}m`;
	}

	function getBarWidth(count: number, data: { count: number }[]): number {
		const max = Math.max(...data.map(d => d.count), 1);
		return (count / max) * 100;
	}

	function formatDate(dateStr: string): string {
		if (!dateStr) return '-';
		try {
			return new Date(dateStr).toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', {
				year: 'numeric',
				month: 'short',
				day: 'numeric',
			});
		} catch {
			return dateStr;
		}
	}

	function getTabColor(tabId: string): string {
		switch (tabId) {
			case 'overview': return 'blue';
			case 'attendance': return 'teal';
			case 'expiry': return 'orange';
			case 'breakdown': return 'green';
			default: return 'blue';
		}
	}

	function getTabActiveClass(tabId: string): string {
		const color = getTabColor(tabId);
		switch (color) {
			case 'blue': return 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]';
			case 'teal': return 'bg-teal-600 text-white shadow-lg shadow-teal-200 scale-[1.02]';
			case 'orange': return 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]';
			case 'green': return 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]';
			default: return 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]';
		}
	}

	$: if (selectedBranch !== undefined || selectedStatus !== undefined || searchQuery !== undefined) {
		if (employees.length > 0) computeStats();
	}

	onMount(() => {
		loadData();
	});
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header / Tab Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">📊</span>
			<h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('employeeDashboard.title')}</h1>
		</div>
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			{#each tabs as tab}
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === tab.id
						? getTabActiveClass(tab.id)
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => { activeTab = tab.id; }}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
					<span class="relative z-10">{tab.label}</span>
					{#if tab.id === 'expiry' && expiringDocuments.length > 0}
						<span class="inline-flex items-center justify-center px-1.5 py-0.5 text-[10px] font-black bg-red-500 text-white rounded-full min-w-[18px]">{expiringDocuments.length}</span>
					{/if}
					{#if activeTab === tab.id}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			{/each}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative elements -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if isLoading}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{$t('employeeDashboard.loading')}</p>
					</div>
				</div>
			{:else if error}
				<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
					<p class="text-red-700 font-semibold">{error}</p>
					<button
						class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
						on:click={loadData}
					>
						{$t('employeeDashboard.refresh')}
					</button>
				</div>
			{:else}
				<!-- Filter Controls -->
				<div class="mb-4 flex gap-3">
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('employeeDashboard.branch')}</label>
						<select
							bind:value={selectedBranch}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;"
						>
							<option value="" style="color: #000 !important; background-color: #fff !important;">{$t('employeeDashboard.allBranches')}</option>
							{#each branches as branch}
								<option value={String(branch.id)} style="color: #000 !important; background-color: #fff !important;">
									{$locale === 'ar' ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar)}
								</option>
							{/each}
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('employeeDashboard.status')}</label>
						<select
							bind:value={selectedStatus}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;"
						>
							<option value="" style="color: #000 !important; background-color: #fff !important;">{$t('employeeDashboard.allStatuses')}</option>
							<option value="Job (With Finger)" style="color: #000 !important;">Job (With Finger)</option>
							<option value="Job (No Finger)" style="color: #000 !important;">Job (No Finger)</option>
							<option value="Remote Job" style="color: #000 !important;">Remote Job</option>
							<option value="Vacation" style="color: #000 !important;">Vacation</option>
							<option value="Resigned" style="color: #000 !important;">Resigned</option>
							<option value="Terminated" style="color: #000 !important;">Terminated</option>
							<option value="Run Away" style="color: #000 !important;">Run Away</option>
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('employeeDashboard.expiryWindow')}</label>
						<select
							bind:value={expiryDays}
							on:change={() => computeStats()}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;"
						>
							<option value={7} style="color: #000 !important;">7 {$t('employeeDashboard.days')}</option>
							<option value={14} style="color: #000 !important;">14 {$t('employeeDashboard.days')}</option>
							<option value={30} style="color: #000 !important;">30 {$t('employeeDashboard.days')}</option>
							<option value={60} style="color: #000 !important;">60 {$t('employeeDashboard.days')}</option>
							<option value={90} style="color: #000 !important;">90 {$t('employeeDashboard.days')}</option>
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('employeeDashboard.search')}</label>
						<input
							type="text"
							bind:value={searchQuery}
							placeholder={$t('employeeDashboard.searchPlaceholder')}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						/>
					</div>
					<div class="flex items-end">
						<button
							on:click={loadData}
							class="px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
							title={$t('employeeDashboard.refresh')}
						>
							🔄 {$t('employeeDashboard.refresh')}
						</button>
					</div>
				</div>

				<!-- TAB: Overview -->
				{#if activeTab === 'overview'}
					<!-- Summary stat cards -->
					<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-4">
						<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-3 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid #3b82f6;">
							<span class="text-3xl">👥</span>
							<div>
								<div class="text-2xl font-black text-slate-800">{totalEmployees}</div>
								<div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{$t('employeeDashboard.totalEmployees')}</div>
							</div>
						</div>
						<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-3 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid #10b981;">
							<span class="text-3xl">✅</span>
							<div>
								<div class="text-2xl font-black text-emerald-700">{activeEmployees}</div>
								<div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{$t('employeeDashboard.activeEmployees')}</div>
							</div>
						</div>
						<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-3 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid #8b5cf6;">
							<span class="text-3xl">🏠</span>
							<div>
								<div class="text-2xl font-black text-violet-700">{remoteEmployees}</div>
								<div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{$t('employeeDashboard.remoteEmployees')}</div>
							</div>
						</div>
						<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-3 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid #f59e0b;">
							<span class="text-3xl">🏖️</span>
							<div>
								<div class="text-2xl font-black text-amber-700">{vacationEmployees}</div>
								<div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{$t('employeeDashboard.onVacation')}</div>
							</div>
						</div>
						<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-3 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid #ef4444;">
							<span class="text-3xl">🚪</span>
							<div>
								<div class="text-2xl font-black text-red-700">{resignedEmployees}</div>
								<div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{$t('employeeDashboard.resigned')}</div>
							</div>
						</div>
						<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-3 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid #dc2626;">
							<span class="text-3xl">❌</span>
							<div>
								<div class="text-2xl font-black text-red-800">{terminatedEmployees}</div>
								<div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{$t('employeeDashboard.terminated')}</div>
							</div>
						</div>
					</div>

					<!-- Charts Grid -->
					<div class="grid grid-cols-1 md:grid-cols-2 gap-4 flex-1 overflow-y-auto">
						<!-- By Status -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📊 {$t('employeeDashboard.byStatus')}</h3>
							<div class="space-y-2">
								{#each byStatus as item}
									<div class="flex items-center gap-3">
										<span class="text-xs text-slate-600 font-semibold min-w-[120px] max-w-[150px] truncate" title={item.name}>{item.name}</span>
										<div class="flex-1 h-5 bg-slate-100 rounded overflow-hidden">
											<div class="h-full rounded transition-all duration-500" style="width: {getBarWidth(item.count, byStatus)}%; background: {item.color};"></div>
										</div>
										<span class="text-sm font-black text-slate-700 min-w-[30px] {$locale === 'ar' ? 'text-left' : 'text-right'}">{item.count}</span>
									</div>
								{/each}
							</div>
						</div>

						<!-- By Branch -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🏢 {$t('employeeDashboard.byBranch')}</h3>
							<div class="space-y-2">
								{#each byBranch as item}
									<div class="flex items-center gap-3">
										<span class="text-xs text-slate-600 font-semibold min-w-[120px] max-w-[150px] truncate" title={item.name}>{item.name}</span>
										<div class="flex-1 h-5 bg-slate-100 rounded overflow-hidden">
											<div class="h-full rounded transition-all duration-500" style="width: {getBarWidth(item.count, byBranch)}%; background: {item.color};"></div>
										</div>
										<span class="text-sm font-black text-slate-700 min-w-[30px] {$locale === 'ar' ? 'text-left' : 'text-right'}">{item.count}</span>
									</div>
								{/each}
							</div>
						</div>

						<!-- Sponsorship -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🏷️ {$t('employeeDashboard.sponsorship')}</h3>
							<div class="space-y-2">
								{#each bySponsor as item}
									<div class="flex items-center gap-3">
										<span class="text-xs text-slate-600 font-semibold min-w-[120px] max-w-[150px] truncate" title={item.name}>{item.name}</span>
										<div class="flex-1 h-5 bg-slate-100 rounded overflow-hidden">
											<div class="h-full rounded transition-all duration-500" style="width: {getBarWidth(item.count, bySponsor)}%; background: {item.color};"></div>
										</div>
										<span class="text-sm font-black text-slate-700 min-w-[30px] {$locale === 'ar' ? 'text-left' : 'text-right'}">{item.count}</span>
									</div>
								{/each}
							</div>
						</div>

						<!-- Expiry Summary -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">⚠️ {$t('employeeDashboard.expirySummary')}</h3>
							<div class="flex gap-4 justify-center">
								<div class="text-center p-4 bg-red-50 border border-red-200 rounded-xl flex-1">
									<div class="text-3xl font-black text-red-600">{expiringDocuments.filter(d => d.isExpired).length}</div>
									<div class="text-[10px] font-bold text-red-500 uppercase tracking-wide mt-1">{$t('employeeDashboard.alreadyExpired')}</div>
								</div>
								<div class="text-center p-4 bg-amber-50 border border-amber-200 rounded-xl flex-1">
									<div class="text-3xl font-black text-amber-600">{expiringDocuments.filter(d => !d.isExpired).length}</div>
									<div class="text-[10px] font-bold text-amber-500 uppercase tracking-wide mt-1">{$t('employeeDashboard.expiringSoon')}</div>
								</div>
								<div class="text-center p-4 bg-blue-50 border border-blue-200 rounded-xl flex-1">
									<div class="text-3xl font-black text-blue-600">{expiringDocuments.length}</div>
									<div class="text-[10px] font-bold text-blue-500 uppercase tracking-wide mt-1">{$t('employeeDashboard.totalAlerts')}</div>
								</div>
							</div>
						</div>
					</div>

				<!-- TAB: Attendance -->
				{:else if activeTab === 'attendance'}
					<div class="flex-1 overflow-y-auto space-y-4">
						<!-- Attendance Summary Cards -->
						<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3">
							{#each attendanceByStatus as item}
								<div class="bg-white/70 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 hover:shadow-xl transition-all hover:-translate-y-0.5" style="border-left: 4px solid {item.color};">
									<div class="flex items-center justify-between mb-2">
										<span class="text-xs font-bold text-slate-600 uppercase tracking-wide truncate" title={item.name}>{item.name}</span>
										<span class="text-2xl font-black" style="color: {item.color};">{item.count}</span>
									</div>
									<div class="w-full h-2 bg-slate-100 rounded-full overflow-hidden">
										<div class="h-full rounded-full transition-all duration-500" style="width: {todayAttendanceTotal > 0 ? ((item.count / todayAttendanceTotal) * 100) : 0}%; background: {item.color};"></div>
									</div>
									<div class="text-[10px] text-slate-400 font-bold mt-1">
										{todayAttendanceTotal > 0 ? ((item.count / todayAttendanceTotal) * 100).toFixed(1) : 0}%
									</div>
								</div>
							{/each}
						</div>

						<!-- Attendance Bar Chart -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🕐 {$t('employeeDashboard.todayAttendance')} ({todayAttendanceTotal})</h3>
							<div class="space-y-2">
								{#each attendanceByStatus as item}
									<div class="flex items-center gap-3">
										<span class="text-xs text-slate-600 font-semibold min-w-[180px] max-w-[200px] truncate" title={item.name}>{item.name}</span>
										<div class="flex-1 h-6 bg-slate-100 rounded overflow-hidden">
											<div class="h-full rounded transition-all duration-500 flex items-center {$locale === 'ar' ? 'justify-end pr-2' : 'pl-2'}" style="width: {getBarWidth(item.count, attendanceByStatus)}%; background: {item.color};">
												{#if getBarWidth(item.count, attendanceByStatus) > 15}
													<span class="text-[10px] font-black text-white">{item.count}</span>
												{/if}
											</div>
										</div>
										<span class="text-sm font-black text-slate-700 min-w-[40px] {$locale === 'ar' ? 'text-left' : 'text-right'}">{item.count}</span>
									</div>
								{/each}
							</div>
						</div>

						<!-- Attendance Detail Tables per Status -->
						{#each attendanceByStatus as statusItem}
							{@const empList = getAttendanceEmployees(statusItem.name)}
							{#if empList.length > 0}
								<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden">
									<div class="px-5 py-3 border-b border-slate-200 flex items-center gap-2">
										<div class="w-3 h-3 rounded-full" style="background: {statusItem.color};"></div>
										<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">{statusItem.name}</h3>
										<span class="ml-auto text-xs font-bold px-2 py-0.5 rounded-full {ATTENDANCE_BG[statusItem.name] || 'bg-slate-100 text-slate-700'}">{empList.length}</span>
									</div>
									<div class="overflow-x-auto max-h-[300px] overflow-y-auto">
										<table class="w-full border-collapse text-sm">
											<thead class="sticky top-0 z-10" style="background: {statusItem.color};">
												<tr>
													<th class="px-4 py-2.5 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.employeeId')}</th>
													<th class="px-4 py-2.5 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.employeeName')}</th>
													<th class="px-4 py-2.5 text-center text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.checkIn')}</th>
													<th class="px-4 py-2.5 text-center text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.checkOut')}</th>
													<th class="px-4 py-2.5 text-center text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.worked')}</th>
													<th class="px-4 py-2.5 text-center text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.lateMin')}</th>
													<th class="px-4 py-2.5 text-center text-xs font-black uppercase tracking-wider text-white">{$t('employeeDashboard.overtime')}</th>
												</tr>
											</thead>
											<tbody class="divide-y divide-slate-200">
												{#each empList as emp, index}
													<tr class="hover:bg-blue-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
														<td class="px-4 py-2 text-xs text-slate-400 font-mono">{emp.id}</td>
														<td class="px-4 py-2 text-sm text-slate-700 font-semibold">{emp.name}</td>
														<td class="px-4 py-2 text-sm text-center font-mono text-slate-600">{emp.checkIn}</td>
														<td class="px-4 py-2 text-sm text-center font-mono text-slate-600">{emp.checkOut}</td>
														<td class="px-4 py-2 text-sm text-center font-semibold text-emerald-700">{formatMinutes(emp.workedMinutes)}</td>
														<td class="px-4 py-2 text-sm text-center font-semibold {emp.lateMinutes > 0 ? 'text-red-600' : 'text-slate-400'}">{formatMinutes(emp.lateMinutes)}</td>
														<td class="px-4 py-2 text-sm text-center font-semibold {emp.overtimeMinutes > 0 ? 'text-blue-600' : 'text-slate-400'}">{formatMinutes(emp.overtimeMinutes)}</td>
													</tr>
												{/each}
											</tbody>
										</table>
									</div>
								</div>
							{/if}
						{/each}

						{#if attendanceByStatus.length === 0}
							<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
								<div class="text-5xl mb-4">🕐</div>
								<p class="text-slate-600 font-semibold">{$t('employeeDashboard.noAttendanceData')}</p>
							</div>
						{/if}
					</div>

				<!-- TAB: Expiry Alerts -->
				{:else if activeTab === 'expiry'}
					{#if expiringDocuments.length === 0}
						<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
							<div class="text-5xl mb-4">✅</div>
							<p class="text-slate-600 font-semibold">{$t('employeeDashboard.noExpiryAlerts')}</p>
						</div>
					{:else}
						<div class="mb-2 text-xs text-slate-500 font-semibold">
							{$t('employeeDashboard.showing')} <strong class="text-slate-700">{expiringDocuments.length}</strong> {$t('employeeDashboard.alerts')}
						</div>
						<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
							<div class="overflow-x-auto flex-1">
								<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
									<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
										<tr>
											<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.employeeId')}</th>
											<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.employeeName')}</th>
											<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.branch')}</th>
											<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.documentType')}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.expiryDate')}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.daysRemaining')}</th>
											<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('employeeDashboard.statusLabel')}</th>
										</tr>
									</thead>
									<tbody class="divide-y divide-slate-200">
										{#each expiringDocuments as doc, index}
											<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {doc.isExpired ? '!bg-red-50/40' : ''}">
												<td class="px-4 py-3 text-xs text-slate-400 font-mono">{doc.employeeId}</td>
												<td class="px-4 py-3 text-sm text-slate-700 font-semibold">{doc.employeeName}</td>
												<td class="px-4 py-3 text-sm text-slate-600">{doc.branchName}</td>
												<td class="px-4 py-3 text-sm text-slate-700">{doc.documentType}</td>
												<td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{formatDate(doc.expiryDate)}</td>
												<td class="px-4 py-3 text-sm text-center font-bold {doc.daysUntil < 0 ? 'text-red-600' : doc.daysUntil <= 7 ? 'text-orange-600' : 'text-amber-600'}">
													{doc.daysUntil < 0 ? `${Math.abs(doc.daysUntil)} ${$t('employeeDashboard.daysOverdue')}` : `${doc.daysUntil} ${$t('employeeDashboard.days')}`}
												</td>
												<td class="px-4 py-3 text-center">
													{#if doc.isExpired}
														<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-red-100 text-red-700">🔴 {$t('employeeDashboard.expired')}</span>
													{:else if doc.daysUntil <= 7}
														<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-orange-100 text-orange-700">🟠 {$t('employeeDashboard.critical')}</span>
													{:else}
														<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-amber-100 text-amber-700">🟡 {$t('employeeDashboard.expiringSoon')}</span>
													{/if}
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
							<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
								{$t('employeeDashboard.showing')} {expiringDocuments.length} {$t('employeeDashboard.alerts')}
							</div>
						</div>
					{/if}

				<!-- TAB: Breakdowns -->
				{:else if activeTab === 'breakdown'}
					<div class="flex-1 overflow-y-auto space-y-4">
						<!-- By Nationality -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🌍 {$t('employeeDashboard.byNationality')}</h3>
							<div class="space-y-2">
								{#each byNationality as item}
									<div class="flex items-center gap-3">
										<span class="text-xs text-slate-600 font-semibold min-w-[120px] max-w-[150px] truncate" title={item.name}>{item.name}</span>
										<div class="flex-1 h-5 bg-slate-100 rounded overflow-hidden">
											<div class="h-full rounded transition-all duration-500" style="width: {getBarWidth(item.count, byNationality)}%; background: {item.color};"></div>
										</div>
										<span class="text-sm font-black text-slate-700 min-w-[30px] {$locale === 'ar' ? 'text-left' : 'text-right'}">{item.count}</span>
									</div>
								{/each}
							</div>
						</div>

						<!-- By Position -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">💼 {$t('employeeDashboard.byPosition')}</h3>
							<div class="space-y-2">
								{#each byPosition as item}
									<div class="flex items-center gap-3">
										<span class="text-xs text-slate-600 font-semibold min-w-[120px] max-w-[150px] truncate" title={item.name}>{item.name}</span>
										<div class="flex-1 h-5 bg-slate-100 rounded overflow-hidden">
											<div class="h-full rounded transition-all duration-500" style="width: {getBarWidth(item.count, byPosition)}%; background: {item.color};"></div>
										</div>
										<span class="text-sm font-black text-slate-700 min-w-[30px] {$locale === 'ar' ? 'text-left' : 'text-right'}">{item.count}</span>
									</div>
								{/each}
							</div>
						</div>

						<!-- Branch Detail Cards -->
						<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🏢 {$t('employeeDashboard.branchDetails')}</h3>
							<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
								{#each byBranch as branch}
									<div class="bg-white/60 rounded-xl border border-slate-200 p-4 hover:-translate-y-0.5 transition-all shadow-sm" style="border-left: 4px solid {branch.color};">
										<div class="flex justify-between items-center">
											<span class="text-sm text-slate-700 font-semibold truncate">{branch.name}</span>
											<span class="text-xl font-black text-blue-600">{branch.count}</span>
										</div>
										<div class="text-[10px] text-slate-400 font-bold mt-1">
											{totalEmployees > 0 ? ((branch.count / totalEmployees) * 100).toFixed(1) : 0}%
										</div>
									</div>
								{/each}
							</div>
						</div>
					</div>
				{/if}
			{/if}
		</div>
	</div>
</div>
