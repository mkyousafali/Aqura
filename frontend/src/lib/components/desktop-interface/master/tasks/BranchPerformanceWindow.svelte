<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    let supabase: any;
    let loading = true;
    let error = '';
    let daysBack = 30;
    let data: any = null;
    let filterMode: 'range' | 'today' | 'yesterday' | 'specific' = 'today';
    let specificDate = '';
    let showDatePicker = false;
    let showFilterPopup = false;
    let empBranchFilter = 'all';
    let showBranchPopup = false;

    function selectBranch(val: string) {
        empBranchFilter = val;
        showBranchPopup = false;
    }

    function getBranchFilterLabel(): string {
        if (empBranchFilter === 'all') return isRTL ? 'كل الفروع' : 'All Branches';
        if (isRTL) {
            const found = branchStats.find((b: any) => b.branch_name_en === empBranchFilter);
            return found?.branch_name_ar || empBranchFilter;
        }
        return empBranchFilter;
    }

    $: isRTL = $locale === 'ar';
    $: filterLabel = (filterMode, daysBack, specificDate, isRTL, getFilterLabel());
    $: filterDateInfo = (filterMode, daysBack, specificDate, isRTL, getFilterDateInfo());

    onMount(async () => {
        const { supabase: client } = await import('$lib/utils/supabase');
        supabase = client;
        await loadData();
    });

    function getToday(): string {
        return new Date().toISOString().split('T')[0];
    }

    function getYesterday(): string {
        const d = new Date();
        d.setDate(d.getDate() - 1);
        return d.toISOString().split('T')[0];
    }

    function selectToday() {
        filterMode = 'today';
        showDatePicker = false;
        loadData();
    }

    function selectYesterday() {
        filterMode = 'yesterday';
        showDatePicker = false;
        loadData();
    }

    function selectRange(days: number) {
        filterMode = 'range';
        daysBack = days;
        showDatePicker = false;
        loadData();
    }

    function selectSpecificDate() {
        if (!specificDate) return;
        filterMode = 'specific';
        showDatePicker = false;
        loadData();
    }

    function getFilterLabel(): string {
        if (filterMode === 'today') return isRTL ? 'اليوم' : 'Today';
        if (filterMode === 'yesterday') return isRTL ? 'أمس' : 'Yesterday';
        if (filterMode === 'specific') {
            const d = new Date(specificDate + 'T00:00:00');
            return d.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        }
        return isRTL ? `آخر ${daysBack} يوم` : `Last ${daysBack} days`;
    }

    function getFilterDateInfo(): string {
        const loc = isRTL ? 'ar-SA' : 'en-US';
        const fmt: Intl.DateTimeFormatOptions = { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' };
        if (filterMode === 'today') return new Date().toLocaleDateString(loc, fmt);
        if (filterMode === 'yesterday') {
            const d = new Date(); d.setDate(d.getDate() - 1);
            return d.toLocaleDateString(loc, fmt);
        }
        if (filterMode === 'specific') {
            return new Date(specificDate + 'T00:00:00').toLocaleDateString(loc, fmt);
        }
        const from = new Date(); from.setDate(from.getDate() - daysBack);
        return `${from.toLocaleDateString(loc, { month: 'short', day: 'numeric' })} — ${new Date().toLocaleDateString(loc, { month: 'short', day: 'numeric' })}`;
    }

    async function loadData() {
        loading = true;
        error = '';
        try {
            const params: any = {};
            if (filterMode === 'today') {
                params.p_specific_date = getToday();
            } else if (filterMode === 'yesterday') {
                params.p_specific_date = getYesterday();
            } else if (filterMode === 'specific' && specificDate) {
                params.p_specific_date = specificDate;
            } else {
                params.p_days_back = daysBack;
            }
            const { data: result, error: err } = await supabase.rpc('get_branch_performance_dashboard', params);
            if (err) throw err;
            data = result;
        } catch (e: any) {
            console.error('Error loading branch performance:', e);
            error = e.message || 'Failed to load data';
        } finally {
            loading = false;
        }
    }

    // Period options
    const periods = [
        { value: 7, label: '7 Days', labelAr: '7 أيام' },
        { value: 14, label: '14 Days', labelAr: '14 يوم' },
        { value: 30, label: '30 Days', labelAr: '30 يوم' },
        { value: 60, label: '60 Days', labelAr: '60 يوم' },
        { value: 90, label: '90 Days', labelAr: '90 يوم' }
    ];

    // Chart helpers
    function getBarChartMaxValue(stats: any[]) {
        if (!stats || stats.length === 0) return 10;
        return Math.max(...stats.map(s => s.total_tasks || 0), 10);
    }

    function getDailyMax(daily: any[]) {
        if (!daily || daily.length === 0) return 10;
        return Math.max(...daily.map(d => Math.max(d.completed || 0, d.created || 0)), 10);
    }

    function formatDay(dateStr: string) {
        const d = new Date(dateStr);
        return d.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { month: 'short', day: 'numeric' });
    }

    function getBranchName(b: any) {
        if (isRTL) {
            return b.branch_name_ar
                ? `${b.branch_name_ar}${b.branch_location_ar ? ' (' + b.branch_location_ar + ')' : ''}`
                : b.branch_name_en || '';
        }
        return `${b.branch_name_en || ''}${b.branch_location_en ? ' (' + b.branch_location_en + ')' : ''}`;
    }

    function getCompletionColor(rate: number) {
        if (rate >= 80) return '#22c55e';
        if (rate >= 60) return '#eab308';
        if (rate >= 40) return '#f97316';
        return '#ef4444';
    }

    function getEmpName(emp: any) {
        return isRTL ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar);
    }

    function getEmpBranch(emp: any) {
        return isRTL ? (emp.branch_name_ar || emp.branch_name_en) : (emp.branch_name_en || emp.branch_name_ar);
    }

    // Pie chart calculations
    function getPieSlices(typeStats: any) {
        if (!typeStats) return [];
        const total = (typeStats.regular || 0) + (typeStats.quick || 0) + (typeStats.receiving || 0);
        if (total === 0) return [];

        const slices = [];
        let currentAngle = 0;

        const types = [
            { key: 'regular', color: '#3b82f6', label: isRTL ? 'مهام عادية' : 'Regular', count: typeStats.regular || 0 },
            { key: 'quick', color: '#f59e0b', label: isRTL ? 'مهام سريعة' : 'Quick', count: typeStats.quick || 0 },
            { key: 'receiving', color: '#8b5cf6', label: isRTL ? 'مهام استلام' : 'Receiving', count: typeStats.receiving || 0 }
        ];

        for (const type of types) {
            if (type.count === 0) continue;
            const pct = type.count / total;
            const angle = pct * 360;
            const startAngle = currentAngle;
            const endAngle = currentAngle + angle;

            const x1 = 50 + 40 * Math.cos((startAngle - 90) * Math.PI / 180);
            const y1 = 50 + 40 * Math.sin((startAngle - 90) * Math.PI / 180);
            const x2 = 50 + 40 * Math.cos((endAngle - 90) * Math.PI / 180);
            const y2 = 50 + 40 * Math.sin((endAngle - 90) * Math.PI / 180);
            const largeArc = angle > 180 ? 1 : 0;

            slices.push({
                ...type,
                pct: Math.round(pct * 100),
                path: `M 50 50 L ${x1} ${y1} A 40 40 0 ${largeArc} 1 ${x2} ${y2} Z`
            });

            currentAngle = endAngle;
        }

        return slices;
    }

    // Status pie for totals
    function getStatusPieSlices(totals: any) {
        if (!totals) return [];
        const completed = totals.completed_tasks || 0;
        const pending = totals.pending_tasks || 0;
        const overdue = totals.overdue_tasks || 0;
        const total = completed + pending;
        if (total === 0) return [];

        const slices = [];
        let currentAngle = 0;

        const items = [
            { label: isRTL ? 'مكتمل' : 'Completed', color: '#22c55e', count: completed },
            { label: isRTL ? 'قيد الانتظار' : 'Pending', color: '#eab308', count: pending - overdue },
            { label: isRTL ? 'متأخر' : 'Overdue', color: '#ef4444', count: overdue }
        ].filter(i => i.count > 0);

        for (const item of items) {
            const pct = item.count / total;
            const angle = pct * 360;
            const startAngle = currentAngle;
            const endAngle = currentAngle + angle;

            const x1 = 50 + 40 * Math.cos((startAngle - 90) * Math.PI / 180);
            const y1 = 50 + 40 * Math.sin((startAngle - 90) * Math.PI / 180);
            const x2 = 50 + 40 * Math.cos((endAngle - 90) * Math.PI / 180);
            const y2 = 50 + 40 * Math.sin((endAngle - 90) * Math.PI / 180);
            const largeArc = angle > 180 ? 1 : 0;

            slices.push({
                ...item,
                pct: Math.round(pct * 100),
                path: `M 50 50 L ${x1} ${y1} A 40 40 0 ${largeArc} 1 ${x2} ${y2} Z`
            });

            currentAngle = endAngle;
        }

        return slices;
    }

    $: pieSlices = data ? getPieSlices(data.task_type_stats) : [];
    $: statusPieSlices = data ? getStatusPieSlices(data.totals) : [];
    $: branchStats = data?.branch_stats || [];
    $: dailyStats = data?.daily_stats || [];
    $: topEmployees = data?.top_employees || [];
    $: filteredEmployees = empBranchFilter === 'all'
        ? topEmployees
        : topEmployees.filter((e: any) => e.branch_name_en === empBranchFilter);
    $: availableBranches = [...new Set(topEmployees.map((e: any) => e.branch_name_en).filter(Boolean))] as string[];
    $: totals = data?.totals || {};
    $: completionRate = totals.total_tasks > 0 ? Math.round((totals.completed_tasks / totals.total_tasks) * 100) : 0;

    // For daily chart: show last 14 days max on screen
    $: visibleDaily = dailyStats.length > 14 ? dailyStats.slice(-14) : dailyStats;
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
    <!-- Header Bar -->
    <div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <span class="text-2xl">📊</span>
            <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{isRTL ? 'أداء الفروع' : 'Branch Performance'}</h1>
        </div>
        <div class="flex items-center gap-3">
            <!-- Period filter trigger -->
            <button
                class="flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 hover:shadow-md transition-all cursor-pointer"
                on:click={() => showFilterPopup = !showFilterPopup}
            >
                <span class="text-base">📆</span>
                <div class="flex flex-col items-start">
                    <span class="text-xs font-black text-slate-700 uppercase tracking-wide">{filterLabel}</span>
                    <span class="text-[10px] font-semibold text-slate-400">{filterDateInfo}</span>
                </div>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="text-slate-400"><polyline points="6 9 12 15 18 9"/></svg>
            </button>
            <p class="text-[9px] font-semibold text-indigo-400 -mt-0.5 tracking-wide pointer-events-none opacity-70">{isRTL ? 'اضغط لتغيير الفترة ⟵' : '⟶ Click to change period'}</p>
            {#if showFilterPopup}
                <!-- Filter Popup Overlay -->
                <div class="fixed inset-0 bg-black/30 z-[100] flex items-center justify-center" style="animation: fadeIn 0.15s;"
                    on:click|self={() => { showFilterPopup = false; }} on:keydown={(e) => e.key === 'Escape' && (showFilterPopup = false)} role="dialog" aria-modal="true">
                    <div class="bg-white rounded-2xl shadow-2xl border border-slate-200 w-[320px] overflow-hidden" style="animation: scaleIn 0.2s ease-out;">
                        <div class="px-5 py-3 bg-indigo-600">
                            <h3 class="text-sm font-black text-white uppercase tracking-wide">{isRTL ? 'اختر الفترة' : 'Select Period'}</h3>
                        </div>
                        <div class="max-h-[400px] overflow-y-auto">
                            <button class="flex items-center gap-3 w-full px-5 py-3 hover:bg-slate-50 transition-colors text-left border-b border-slate-100
                                {filterMode === 'today' ? 'bg-emerald-50' : ''}"
                                on:click={selectToday}>
                                <span class="text-base">🟢</span>
                                <span class="flex-1 text-xs font-bold {filterMode === 'today' ? 'text-emerald-700' : 'text-slate-600'} uppercase">{isRTL ? 'اليوم' : 'Today'}</span>
                                {#if filterMode === 'today'}<span class="text-emerald-600 font-black">✓</span>{/if}
                            </button>
                            <button class="flex items-center gap-3 w-full px-5 py-3 hover:bg-slate-50 transition-colors text-left border-b border-slate-100
                                {filterMode === 'yesterday' ? 'bg-amber-50' : ''}"
                                on:click={selectYesterday}>
                                <span class="text-base">🟡</span>
                                <span class="flex-1 text-xs font-bold {filterMode === 'yesterday' ? 'text-amber-700' : 'text-slate-600'} uppercase">{isRTL ? 'أمس' : 'Yesterday'}</span>
                                {#if filterMode === 'yesterday'}<span class="text-amber-600 font-black">✓</span>{/if}
                            </button>
                            <div class="h-px bg-slate-200"></div>
                            {#each periods as period}
                                <button class="flex items-center gap-3 w-full px-5 py-3 hover:bg-slate-50 transition-colors text-left border-b border-slate-100
                                    {filterMode === 'range' && daysBack === period.value ? 'bg-indigo-50' : ''}"
                                    on:click={() => selectRange(period.value)}>
                                    <span class="text-base">📅</span>
                                    <span class="flex-1 text-xs font-bold {filterMode === 'range' && daysBack === period.value ? 'text-indigo-700' : 'text-slate-600'} uppercase">
                                        {isRTL ? `آخر ${period.labelAr} يوم` : `Last ${period.label}`}
                                    </span>
                                    {#if filterMode === 'range' && daysBack === period.value}<span class="text-indigo-600 font-black">✓</span>{/if}
                                </button>
                            {/each}
                            <div class="h-px bg-slate-200"></div>
                            <div class="px-5 py-4">
                                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-2">{isRTL ? 'تاريخ محدد' : 'Specific Date'}</p>
                                <input
                                    type="date"
                                    bind:value={specificDate}
                                    max={getToday()}
                                    class="w-full px-3 py-2.5 bg-slate-50 border-2 border-slate-200 rounded-xl text-sm font-semibold focus:ring-2 focus:ring-violet-500 focus:border-violet-500 focus:outline-none transition-all"
                                />
                                <button
                                    class="w-full mt-2 px-3 py-2.5 bg-violet-600 text-white text-xs font-bold uppercase rounded-xl hover:bg-violet-700 transition-all disabled:opacity-50 shadow-lg shadow-violet-200"
                                    disabled={!specificDate}
                                    on:click={selectSpecificDate}
                                >
                                    {isRTL ? 'عرض' : 'Apply'}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            {/if}
            <button
                class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white text-xs font-bold uppercase rounded-xl hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-200"
                on:click={loadData}
                disabled={loading}
            >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class:animate-spin={loading}>
                    <polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
                </svg>
                {isRTL ? 'تحديث' : 'Refresh'}
            </button>
        </div>
    </div>

    <!-- Main Content -->
    <div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-indigo-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-violet-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto space-y-6">
            {#if loading}
                <div class="flex items-center justify-center h-64">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-indigo-200 border-t-indigo-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">{isRTL ? 'جاري تحميل البيانات...' : 'Loading performance data...'}</p>
                    </div>
                </div>
            {:else if error}
                <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                    <p class="text-red-600 font-semibold">{error}</p>
                    <button class="mt-4 px-6 py-2 bg-red-600 text-white rounded-xl text-sm font-bold" on:click={loadData}>{isRTL ? 'إعادة المحاولة' : 'Retry'}</button>
                </div>
            {:else if data}
                <!-- KPI Cards Row -->
                <div class="grid grid-cols-5 gap-4">
                    <!-- Total Tasks -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 relative overflow-hidden">
                        <div class="absolute top-0 right-0 w-20 h-20 bg-blue-100/40 rounded-full -mr-6 -mt-6"></div>
                        <div class="relative">
                            <p class="text-xs font-bold text-slate-500 uppercase tracking-wide mb-1">{isRTL ? 'إجمالي المهام' : 'Total Tasks'}</p>
                            <p class="text-3xl font-black text-slate-900">{totals.total_tasks?.toLocaleString() || 0}</p>
                            <p class="text-xs text-slate-400 mt-1">{filterLabel}</p>
                        </div>
                    </div>

                    <!-- Completed -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 relative overflow-hidden">
                        <div class="absolute top-0 right-0 w-20 h-20 bg-green-100/40 rounded-full -mr-6 -mt-6"></div>
                        <div class="relative">
                            <p class="text-xs font-bold text-emerald-600 uppercase tracking-wide mb-1">{isRTL ? 'مكتمل' : 'Completed'}</p>
                            <p class="text-3xl font-black text-emerald-700">{totals.completed_tasks?.toLocaleString() || 0}</p>
                            <p class="text-xs text-emerald-500 mt-1">{completionRate}% {isRTL ? 'معدل الإنجاز' : 'completion rate'}</p>
                        </div>
                    </div>

                    <!-- Pending -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 relative overflow-hidden">
                        <div class="absolute top-0 right-0 w-20 h-20 bg-yellow-100/40 rounded-full -mr-6 -mt-6"></div>
                        <div class="relative">
                            <p class="text-xs font-bold text-amber-600 uppercase tracking-wide mb-1">{isRTL ? 'قيد الانتظار' : 'Pending'}</p>
                            <p class="text-3xl font-black text-amber-700">{totals.pending_tasks?.toLocaleString() || 0}</p>
                            <p class="text-xs text-amber-500 mt-1">{isRTL ? 'بحاجة لإكمال' : 'awaiting completion'}</p>
                        </div>
                    </div>

                    <!-- Overdue -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 relative overflow-hidden">
                        <div class="absolute top-0 right-0 w-20 h-20 bg-red-100/40 rounded-full -mr-6 -mt-6"></div>
                        <div class="relative">
                            <p class="text-xs font-bold text-red-600 uppercase tracking-wide mb-1">{isRTL ? 'متأخر' : 'Overdue'}</p>
                            <p class="text-3xl font-black text-red-700">{totals.overdue_tasks?.toLocaleString() || 0}</p>
                            <p class="text-xs text-red-400 mt-1">{isRTL ? 'تجاوز الموعد' : 'past deadline'}</p>
                        </div>
                    </div>

                    <!-- Avg Completion Time -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5 relative overflow-hidden">
                        <div class="absolute top-0 right-0 w-20 h-20 bg-violet-100/40 rounded-full -mr-6 -mt-6"></div>
                        <div class="relative">
                            <p class="text-xs font-bold text-violet-600 uppercase tracking-wide mb-1">{isRTL ? 'متوسط الإنجاز' : 'Avg Completion'}</p>
                            <p class="text-3xl font-black text-violet-700">{totals.avg_completion_hours || 0}<span class="text-sm font-bold text-violet-400 ml-1">{isRTL ? 'ساعة' : 'hrs'}</span></p>
                            <p class="text-xs text-violet-400 mt-1">{isRTL ? 'وقت الإنجاز' : 'avg response time'}</p>
                        </div>
                    </div>
                </div>

                <!-- Charts Row -->
                <div class="grid grid-cols-3 gap-4">
                    <!-- Task Type Distribution (Pie) -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
                        <h3 class="text-sm font-black text-slate-800 uppercase tracking-wide mb-4">{isRTL ? 'توزيع أنواع المهام' : 'Task Type Distribution'}</h3>
                        <div class="flex items-center justify-center gap-6">
                            <svg viewBox="0 0 100 100" class="w-28 h-28">
                                {#if pieSlices.length === 0}
                                    <circle cx="50" cy="50" r="40" fill="#e2e8f0"/>
                                {:else}
                                    {#each pieSlices as slice}
                                        <path d={slice.path} fill={slice.color} opacity="0.85">
                                            <title>{slice.label}: {slice.count} ({slice.pct}%)</title>
                                        </path>
                                    {/each}
                                {/if}
                            </svg>
                            <div class="space-y-2">
                                {#each pieSlices as slice}
                                    <div class="flex items-center gap-2">
                                        <div class="w-3 h-3 rounded-full" style="background-color: {slice.color}"></div>
                                        <span class="text-xs font-semibold text-slate-700">{slice.label}</span>
                                        <span class="text-xs font-bold text-slate-900">{slice.count}</span>
                                        <span class="text-xs text-slate-400">({slice.pct}%)</span>
                                    </div>
                                {/each}
                                {#if pieSlices.length === 0}
                                    <p class="text-xs text-slate-400">{isRTL ? 'لا توجد بيانات' : 'No data'}</p>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <!-- Status Distribution (Pie) -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
                        <h3 class="text-sm font-black text-slate-800 uppercase tracking-wide mb-4">{isRTL ? 'حالة المهام' : 'Task Status Overview'}</h3>
                        <div class="flex items-center justify-center gap-6">
                            <svg viewBox="0 0 100 100" class="w-28 h-28">
                                {#if statusPieSlices.length === 0}
                                    <circle cx="50" cy="50" r="40" fill="#e2e8f0"/>
                                {:else}
                                    {#each statusPieSlices as slice}
                                        <path d={slice.path} fill={slice.color} opacity="0.85">
                                            <title>{slice.label}: {slice.count} ({slice.pct}%)</title>
                                        </path>
                                    {/each}
                                {/if}
                            </svg>
                            <div class="space-y-2">
                                {#each statusPieSlices as slice}
                                    <div class="flex items-center gap-2">
                                        <div class="w-3 h-3 rounded-full" style="background-color: {slice.color}"></div>
                                        <span class="text-xs font-semibold text-slate-700">{slice.label}</span>
                                        <span class="text-xs font-bold text-slate-900">{slice.count}</span>
                                        <span class="text-xs text-slate-400">({slice.pct}%)</span>
                                    </div>
                                {/each}
                                {#if statusPieSlices.length === 0}
                                    <p class="text-xs text-slate-400">{isRTL ? 'لا توجد بيانات' : 'No data'}</p>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <!-- Completion Rate Gauge -->
                    <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
                        <h3 class="text-sm font-black text-slate-800 uppercase tracking-wide mb-4">{isRTL ? 'معدل الإنجاز الكلي' : 'Overall Completion Rate'}</h3>
                        <div class="flex items-center justify-center">
                            <div class="relative">
                                <svg viewBox="0 0 100 100" class="w-32 h-32">
                                    <circle cx="50" cy="50" r="42" fill="none" stroke="#e2e8f0" stroke-width="8"/>
                                    <circle cx="50" cy="50" r="42" fill="none"
                                        stroke={getCompletionColor(completionRate)}
                                        stroke-width="8"
                                        stroke-dasharray="{completionRate * 2.64} 264"
                                        stroke-linecap="round"
                                        transform="rotate(-90 50 50)"
                                        class="transition-all duration-1000"
                                    />
                                </svg>
                                <div class="absolute inset-0 flex items-center justify-center flex-col">
                                    <span class="text-2xl font-black" style="color: {getCompletionColor(completionRate)}">{completionRate}%</span>
                                    <span class="text-[10px] text-slate-400 font-bold">{isRTL ? 'إنجاز' : 'completed'}</span>
                                </div>
                            </div>
                        </div>
                        <div class="flex justify-center gap-4 mt-3">
                            <div class="text-center">
                                <p class="text-lg font-black text-emerald-600">{totals.completed_tasks || 0}</p>
                                <p class="text-[10px] text-slate-400 font-bold uppercase">{isRTL ? 'مكتمل' : 'Done'}</p>
                            </div>
                            <div class="text-center">
                                <p class="text-lg font-black text-amber-600">{totals.pending_tasks || 0}</p>
                                <p class="text-[10px] text-slate-400 font-bold uppercase">{isRTL ? 'متبقي' : 'Left'}</p>
                            </div>
                            <div class="text-center">
                                <p class="text-lg font-black text-red-600">{totals.overdue_tasks || 0}</p>
                                <p class="text-[10px] text-slate-400 font-bold uppercase">{isRTL ? 'متأخر' : 'Late'}</p>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Daily Trend Chart -->
                <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
                    <h3 class="text-sm font-black text-slate-800 uppercase tracking-wide mb-4">
                        {isRTL ? 'الاتجاه اليومي (إنشاء مقابل إنجاز)' : 'Daily Trend (Created vs Completed)'}
                    </h3>
                    {#if visibleDaily.length > 0}
                        <div class="overflow-x-auto">
                            <svg viewBox="0 0 {visibleDaily.length * 50 + 40} 160" class="w-full min-w-[600px]" style="max-height: 200px;">
                                <!-- Grid lines -->
                                {#each [0, 25, 50, 75, 100] as pct}
                                    <line x1="30" y1={10 + (100 - pct)} x2={visibleDaily.length * 50 + 30} y2={10 + (100 - pct)} stroke="#e2e8f0" stroke-width="0.5"/>
                                    <text x="25" y={14 + (100 - pct)} text-anchor="end" class="text-[8px] fill-slate-400">{Math.round(getDailyMax(visibleDaily) * pct / 100)}</text>
                                {/each}

                                {#each visibleDaily as day, i}
                                    {@const barX = 35 + i * 50}
                                    {@const maxVal = getDailyMax(visibleDaily)}
                                    {@const createdH = maxVal > 0 ? (day.created / maxVal) * 100 : 0}
                                    {@const completedH = maxVal > 0 ? (day.completed / maxVal) * 100 : 0}

                                    <!-- Created bar -->
                                    <rect x={barX} y={110 - createdH} width="16" height={createdH} rx="3" fill="#93c5fd" opacity="0.7">
                                        <title>{isRTL ? 'تم إنشاء' : 'Created'}: {day.created}</title>
                                    </rect>
                                    <!-- Completed bar -->
                                    <rect x={barX + 18} y={110 - completedH} width="16" height={completedH} rx="3" fill="#22c55e" opacity="0.8">
                                        <title>{isRTL ? 'مكتمل' : 'Completed'}: {day.completed}</title>
                                    </rect>
                                    <!-- Date label -->
                                    <text x={barX + 17} y="125" text-anchor="middle" class="text-[7px] fill-slate-500 font-semibold">{formatDay(day.day)}</text>
                                {/each}

                                <!-- Legend -->
                                <rect x={visibleDaily.length * 50 - 30} y="135" width="10" height="6" rx="2" fill="#93c5fd" opacity="0.7"/>
                                <text x={visibleDaily.length * 50 - 16} y="141" class="text-[7px] fill-slate-500">{isRTL ? 'إنشاء' : 'Created'}</text>
                                <rect x={visibleDaily.length * 50 + 20} y="135" width="10" height="6" rx="2" fill="#22c55e" opacity="0.8"/>
                                <text x={visibleDaily.length * 50 + 34} y="141" class="text-[7px] fill-slate-500">{isRTL ? 'إنجاز' : 'Done'}</text>
                            </svg>
                        </div>
                    {:else}
                        <p class="text-center text-sm text-slate-400 py-8">{isRTL ? 'لا توجد بيانات يومية' : 'No daily data available'}</p>
                    {/if}
                </div>

                <!-- Branch Comparison Table + Top Employees -->
                <div class="grid grid-cols-3 gap-4">
                    <!-- Branch Table (2/3) -->
                    <div class="col-span-2 bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden">
                        <div class="px-5 py-3 bg-indigo-600">
                            <h3 class="text-sm font-black text-white uppercase tracking-wide">{isRTL ? 'أداء الفروع' : 'Branch Comparison'}</h3>
                        </div>
                        <div class="overflow-x-auto max-h-[320px] overflow-y-auto">
                            <table class="w-full border-collapse text-xs">
                                <thead class="sticky top-0 bg-indigo-50 z-10">
                                    <tr>
                                        <th class="px-4 py-2.5 {isRTL ? 'text-right' : 'text-left'} font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'الفرع' : 'Branch'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'إجمالي' : 'Total'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'مكتمل' : 'Done'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'متبقي' : 'Pending'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'متأخر' : 'Overdue'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'عادي' : 'Regular'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'سريع' : 'Quick'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'استلام' : 'Recv'}</th>
                                        <th class="px-3 py-2.5 text-center font-bold text-indigo-900 uppercase tracking-wide">{isRTL ? 'إنجاز %' : 'Rate'}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each branchStats as branch, idx}
                                        <tr class="hover:bg-indigo-50/50 transition-colors {idx % 2 === 0 ? 'bg-white/50' : 'bg-slate-50/30'}">
                                            <td class="px-4 py-2.5 font-semibold text-slate-800">{getBranchName(branch)}</td>
                                            <td class="px-3 py-2.5 text-center font-bold text-slate-900">{branch.total_tasks}</td>
                                            <td class="px-3 py-2.5 text-center font-bold text-emerald-600">{branch.completed}</td>
                                            <td class="px-3 py-2.5 text-center font-bold text-amber-600">{branch.pending}</td>
                                            <td class="px-3 py-2.5 text-center font-bold {branch.overdue > 0 ? 'text-red-600' : 'text-slate-400'}">{branch.overdue}</td>
                                            <td class="px-3 py-2.5 text-center text-blue-600">{branch.regular_count}</td>
                                            <td class="px-3 py-2.5 text-center text-amber-600">{branch.quick_count}</td>
                                            <td class="px-3 py-2.5 text-center text-violet-600">{branch.receiving_count}</td>
                                            <td class="px-3 py-2.5 text-center">
                                                <div class="flex items-center gap-1.5 justify-center">
                                                    <div class="w-16 h-1.5 bg-slate-200 rounded-full overflow-hidden">
                                                        <div class="h-full rounded-full transition-all" style="width: {branch.completion_rate}%; background-color: {getCompletionColor(branch.completion_rate)}"></div>
                                                    </div>
                                                    <span class="font-bold" style="color: {getCompletionColor(branch.completion_rate)}">{branch.completion_rate}%</span>
                                                </div>
                                            </td>
                                        </tr>
                                    {/each}
                                    {#if branchStats.length === 0}
                                        <tr><td colspan="9" class="px-4 py-8 text-center text-slate-400">{isRTL ? 'لا توجد بيانات' : 'No branch data'}</td></tr>
                                    {/if}
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Top Employees (1/3) -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden">
                        <div class="px-5 py-3 bg-emerald-600 flex items-center justify-between">
                            <h3 class="text-sm font-black text-white uppercase tracking-wide">{isRTL ? 'أفضل الموظفين' : 'Top Performers'}</h3>
                            <span class="text-[10px] font-bold text-emerald-100">{filteredEmployees.length} {isRTL ? 'موظف' : 'emp'}</span>
                        </div>
                        <div class="px-3 py-2 border-b border-slate-100 relative">
                            <button class="flex items-center gap-2 w-full px-3 py-1.5 bg-slate-50 hover:bg-slate-100 rounded-lg transition-all text-left"
                                on:click={() => showBranchPopup = !showBranchPopup}>
                                <span class="text-sm">🏢</span>
                                <span class="flex-1 text-[11px] font-bold text-slate-700">{getBranchFilterLabel()}</span>
                                <span class="text-[9px] font-bold text-slate-400 bg-white px-1.5 py-0.5 rounded">{filteredEmployees.length}</span>
                                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="text-slate-400"><polyline points="6 9 12 15 18 9"/></svg>
                            </button>
                            {#if showBranchPopup}
                                <div class="absolute {isRTL ? 'right-2' : 'left-2'} top-full mt-1 bg-white rounded-xl shadow-xl border border-slate-200 z-50 w-56 max-h-64 overflow-y-auto" style="animation: fadeIn 0.15s;">
                                    <button class="flex items-center gap-2 w-full px-3 py-2 hover:bg-slate-50 transition-colors text-left
                                        {empBranchFilter === 'all' ? 'bg-emerald-50' : ''}"
                                        on:click={() => selectBranch('all')}>
                                        <span class="text-sm">🌐</span>
                                        <span class="flex-1 text-[11px] font-semibold {empBranchFilter === 'all' ? 'text-emerald-700' : 'text-slate-600'}">{isRTL ? 'كل الفروع' : 'All Branches'}</span>
                                        {#if empBranchFilter === 'all'}<span class="text-emerald-600 font-black text-xs">✓</span>{/if}
                                    </button>
                                    {#each availableBranches as br}
                                        <button class="flex items-center gap-2 w-full px-3 py-2 hover:bg-slate-50 transition-colors text-left border-t border-slate-100
                                            {empBranchFilter === br ? 'bg-emerald-50' : ''}"
                                            on:click={() => selectBranch(br)}>
                                            <span class="text-sm">🏢</span>
                                            <span class="flex-1 text-[11px] font-semibold {empBranchFilter === br ? 'text-emerald-700' : 'text-slate-600'}">
                                                {isRTL ? (branchStats.find((b) => b.branch_name_en === br)?.branch_name_ar || br) : br}
                                            </span>
                                            {#if empBranchFilter === br}<span class="text-emerald-600 font-black text-xs">✓</span>{/if}
                                        </button>
                                    {/each}
                                </div>
                                <!-- Click-away backdrop -->
                                <button class="fixed inset-0 z-40" on:click={() => showBranchPopup = false} aria-label="Close" tabindex="-1"></button>
                            {/if}
                        </div>
                        <div class="overflow-y-auto max-h-[280px]">
                            {#each filteredEmployees as emp, idx}
                                <div class="flex items-center gap-3 px-4 py-2.5 border-b border-slate-100 hover:bg-emerald-50/50 transition-colors">
                                    <div class="w-7 h-7 rounded-full flex items-center justify-center text-xs font-black
                                        {idx === 0 ? 'bg-amber-100 text-amber-700' : idx === 1 ? 'bg-slate-200 text-slate-700' : idx === 2 ? 'bg-orange-100 text-orange-700' : 'bg-slate-100 text-slate-500'}">
                                        {idx + 1}
                                    </div>
                                    <div class="flex-1 min-w-0">
                                        <p class="text-xs font-bold text-slate-800 truncate">{getEmpName(emp)}</p>
                                        <p class="text-[10px] text-slate-400 truncate">{getEmpBranch(emp)}</p>
                                    </div>
                                    <div class="text-right">
                                        <p class="text-sm font-black text-emerald-600">{emp.completed}</p>
                                        <p class="text-[10px] text-slate-400">{isRTL ? `من ${emp.total}` : `of ${emp.total}`}</p>
                                    </div>
                                    <div class="w-10">
                                        <div class="w-full h-1.5 bg-slate-200 rounded-full overflow-hidden">
                                            <div class="h-full rounded-full" style="width: {emp.rate}%; background-color: {getCompletionColor(emp.rate)}"></div>
                                        </div>
                                        <p class="text-[9px] text-center font-bold mt-0.5" style="color: {getCompletionColor(emp.rate)}">{emp.rate}%</p>
                                    </div>
                                </div>
                            {/each}
                            {#if filteredEmployees.length === 0}
                                <div class="px-4 py-8 text-center text-slate-400 text-xs">{isRTL ? 'لا توجد بيانات' : 'No data'}</div>
                            {/if}
                        </div>
                    </div>
                </div>

                <!-- Branch Horizontal Bar Chart -->
                <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-5">
                    <h3 class="text-sm font-black text-slate-800 uppercase tracking-wide mb-4">{isRTL ? 'مقارنة حجم المهام بين الفروع' : 'Branch Task Volume Comparison'}</h3>
                    {#if branchStats.length > 0}
                        <div class="space-y-2.5">
                            {#each branchStats.slice(0, 10) as branch}
                                {@const maxVal = getBarChartMaxValue(branchStats)}
                                {@const pct = maxVal > 0 ? (branch.total_tasks / maxVal) * 100 : 0}
                                <div class="flex items-center gap-3">
                                    <div class="w-40 text-xs font-semibold text-slate-700 truncate {isRTL ? 'text-right' : 'text-left'}" title={getBranchName(branch)}>{getBranchName(branch)}</div>
                                    <div class="flex-1 h-5 bg-slate-100 rounded-lg overflow-hidden relative">
                                        <div class="h-full rounded-lg flex items-center transition-all duration-700" style="width: {pct}%; background: linear-gradient(90deg, #6366f1, #8b5cf6);">
                                            {#if pct > 15}
                                                <span class="text-[10px] font-bold text-white px-2">{branch.total_tasks}</span>
                                            {/if}
                                        </div>
                                        {#if pct <= 15}
                                            <span class="absolute top-0.5 text-[10px] font-bold text-slate-600" style="{isRTL ? 'right' : 'left'}: {pct + 2}%">{branch.total_tasks}</span>
                                        {/if}
                                    </div>
                                    <div class="w-14 text-right">
                                        <span class="text-xs font-bold" style="color: {getCompletionColor(branch.completion_rate)}">{branch.completion_rate}%</span>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {:else}
                        <p class="text-center text-sm text-slate-400 py-8">{isRTL ? 'لا توجد بيانات' : 'No data'}</p>
                    {/if}
                </div>
            {/if}
        </div>
    </div>
</div>
