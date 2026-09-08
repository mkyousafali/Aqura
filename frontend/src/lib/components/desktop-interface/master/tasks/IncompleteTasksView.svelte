<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { locale } from '$lib/i18n';

	export let onClose: () => void;

	let allTasks: any[] = [];
	let filteredTasks: any[] = [];
	let isLoading = true;
	let searchQuery = '';
	let selectedBranch = '';
	let selectedType = '';
	let selectedPriority = '';

	let branches: string[] = [];
	let selectedTask: any = null;
	let showDetailPopup = false;

	$: isRTL = $locale === 'ar';

	onMount(async () => {
		await loadTasks();
	});

	async function loadTasks() {
		try {
			isLoading = true;
			const { data, error } = await supabase.rpc('get_incomplete_tasks');
			if (error) throw error;
			allTasks = data?.tasks || [];
			// Extract unique branches
			const branchSet = new Set<string>();
			allTasks.forEach((t: any) => {
				if (t.branch_name && t.branch_name !== 'No Branch') branchSet.add(t.branch_name);
			});
			branches = Array.from(branchSet).sort();
			applyFilters();
		} catch (err) {
			console.error('❌ Error loading incomplete tasks:', err);
		} finally {
			isLoading = false;
		}
	}

	function applyFilters() {
		filteredTasks = allTasks.filter(task => {
			const q = searchQuery.toLowerCase();
			const matchesSearch = !q ||
				task.task_title?.toLowerCase().includes(q) ||
				task.task_description?.toLowerCase().includes(q) ||
				task.assigned_to_name?.toLowerCase().includes(q) ||
				task.assigned_by_name?.toLowerCase().includes(q);
			const matchesBranch = !selectedBranch || task.branch_name === selectedBranch;
			const matchesType = !selectedType || task.task_type === selectedType;
			const matchesPriority = !selectedPriority || task.priority === selectedPriority;
			return matchesSearch && matchesBranch && matchesType && matchesPriority;
		});
	}

	function formatDate(date: any): string {
		if (!date) return '—';
		try {
			const d = new Date(date);
			return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
		} catch { return '—'; }
	}

	function getTimeSince(date: any): string {
		if (!date) return '';
		const now = new Date().getTime();
		const then = new Date(date).getTime();
		const diffMs = now - then;
		const hours = Math.floor(diffMs / 3600000);
		const days = Math.floor(hours / 24);
		if (days > 0) return isRTL ? `منذ ${days} يوم` : `${days}d ago`;
		if (hours > 0) return isRTL ? `منذ ${hours} ساعة` : `${hours}h ago`;
		return isRTL ? 'الآن' : 'Just now';
	}

	function getDueStatus(deadline: any): { text: string; color: string; bg: string } {
		if (!deadline) return { text: isRTL ? 'بدون موعد' : 'No Deadline', color: 'text-slate-400', bg: 'bg-slate-100' };
		const now = new Date();
		const dl = new Date(deadline);
		const diff = Math.ceil((dl.getTime() - now.getTime()) / 86400000);
		if (diff < 0) return { text: isRTL ? 'متأخر' : 'Overdue', color: 'text-red-700', bg: 'bg-red-100' };
		if (diff === 0) return { text: isRTL ? 'اليوم' : 'Due Today', color: 'text-amber-700', bg: 'bg-amber-100' };
		if (diff <= 3) return { text: isRTL ? 'عاجل' : 'Urgent', color: 'text-orange-700', bg: 'bg-orange-100' };
		return { text: isRTL ? 'قريباً' : 'Due Soon', color: 'text-blue-700', bg: 'bg-blue-100' };
	}

	function getTypeInfo(type: string): { label: string; icon: string; color: string; bg: string } {
		if (type === 'quick') return { label: isRTL ? 'سريع' : 'Quick', icon: '⚡', color: 'text-blue-700', bg: 'bg-blue-50 border-blue-200' };
		if (type === 'receiving') return { label: isRTL ? 'استلام' : 'Receiving', icon: '📦', color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200' };
		return { label: isRTL ? 'عادي' : 'Regular', icon: '📋', color: 'text-indigo-700', bg: 'bg-indigo-50 border-indigo-200' };
	}

	function getPriorityInfo(p: string): { label: string; color: string; dot: string } {
		if (p === 'high' || p === 'urgent') return { label: isRTL ? 'عاجل' : 'High', color: 'text-red-600', dot: 'bg-red-500' };
		if (p === 'low') return { label: isRTL ? 'منخفض' : 'Low', color: 'text-slate-500', dot: 'bg-slate-400' };
		return { label: isRTL ? 'متوسط' : 'Medium', color: 'text-amber-600', dot: 'bg-amber-500' };
	}

	function getEmpName(task: any): string {
		if (isRTL) return task.assigned_to_name_ar || task.assigned_to_name_en || task.assigned_to_name || 'غير محدد';
		return task.assigned_to_name_en || task.assigned_to_name || 'Unassigned';
	}

	function getBranch(task: any): string {
		if (isRTL) return task.branch_name_ar || task.branch_name || 'بدون فرع';
		return task.branch_name || 'No Branch';
	}

	function openDetail(task: any) {
		selectedTask = task;
		showDetailPopup = true;
	}

	function closeDetail() {
		showDetailPopup = false;
		selectedTask = null;
	}

	// Stats
	$: totalCount = filteredTasks.length;
	$: overdueCount = filteredTasks.filter(t => {
		if (!t.deadline) return false;
		return new Date(t.deadline).getTime() < Date.now();
	}).length;
	$: regularCount = filteredTasks.filter(t => t.task_type === 'regular').length;
	$: quickCount = filteredTasks.filter(t => t.task_type === 'quick').length;
	$: receivingCount = filteredTasks.filter(t => t.task_type === 'receiving').length;
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Header Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">⏳</span>
			<div>
				<h2 class="text-sm font-black text-slate-800 uppercase tracking-wide">{isRTL ? 'المهام غير المكتملة' : 'Incomplete Tasks'}</h2>
				<p class="text-[10px] text-slate-400 font-semibold">{isRTL ? `${totalCount} مهمة • ${overdueCount} متأخرة` : `${totalCount} tasks • ${overdueCount} overdue`}</p>
			</div>
		</div>
		<button
			class="flex items-center gap-2 px-4 py-2 bg-amber-500 text-white rounded-xl text-xs font-bold hover:bg-amber-600 transition-all shadow-sm hover:shadow-md"
			on:click={loadTasks}
			disabled={isLoading}
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class:animate-spin={isLoading}>
				<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
			</svg>
			{isRTL ? 'تحديث' : 'Refresh'}
		</button>
	</div>

	<!-- Content -->
	<div class="flex-1 p-6 overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blurs -->
		<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-amber-100/20 rounded-full blur-[120px] -mr-48 -mt-48 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-orange-100/15 rounded-full blur-[120px] -ml-48 -mb-48 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if isLoading}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-amber-200 border-t-amber-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{isRTL ? 'جاري تحميل المهام...' : 'Loading tasks...'}</p>
					</div>
				</div>
			{:else if allTasks.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">🎉</div>
					<p class="text-slate-600 font-semibold text-lg">{isRTL ? 'لا توجد مهام غير مكتملة!' : 'No incomplete tasks!'}</p>
					<p class="text-slate-400 text-sm mt-1">{isRTL ? 'جميع المهام مكتملة' : 'All tasks are completed'}</p>
				</div>
			{:else}
				<!-- KPI Cards -->
				<div class="grid grid-cols-5 gap-3 mb-4">
					<div class="bg-white/60 backdrop-blur-sm rounded-2xl border border-white/80 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-slate-800">{totalCount}</p>
						<p class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">{isRTL ? 'إجمالي' : 'Total'}</p>
					</div>
					<div class="bg-red-50/60 backdrop-blur-sm rounded-2xl border border-red-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-red-600">{overdueCount}</p>
						<p class="text-[10px] font-bold text-red-500 uppercase tracking-wide">{isRTL ? 'متأخر' : 'Overdue'}</p>
					</div>
					<div class="bg-indigo-50/60 backdrop-blur-sm rounded-2xl border border-indigo-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-indigo-600">{regularCount}</p>
						<p class="text-[10px] font-bold text-indigo-500 uppercase tracking-wide">{isRTL ? 'عادي' : 'Regular'}</p>
					</div>
					<div class="bg-blue-50/60 backdrop-blur-sm rounded-2xl border border-blue-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-blue-600">{quickCount}</p>
						<p class="text-[10px] font-bold text-blue-500 uppercase tracking-wide">{isRTL ? 'سريع' : 'Quick'}</p>
					</div>
					<div class="bg-purple-50/60 backdrop-blur-sm rounded-2xl border border-purple-100 shadow-sm p-3 text-center">
						<p class="text-2xl font-black text-purple-600">{receivingCount}</p>
						<p class="text-[10px] font-bold text-purple-500 uppercase tracking-wide">{isRTL ? 'استلام' : 'Receiving'}</p>
					</div>
				</div>

				<!-- Filters -->
				<div class="mb-4 flex gap-3">
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'بحث' : 'Search'}</label>
						<input
							type="text"
							placeholder={isRTL ? 'بحث بالعنوان، الموظف...' : 'Search by title, employee...'}
							bind:value={searchQuery}
							on:input={applyFilters}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all"
						/>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الفرع' : 'Branch'}</label>
						<select bind:value={selectedBranch} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'كل الفروع' : 'All Branches'}</option>
							{#each branches as b}
								<option value={b}>{b}</option>
							{/each}
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'النوع' : 'Type'}</label>
						<select bind:value={selectedType} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All Types'}</option>
							<option value="regular">{isRTL ? 'عادي' : 'Regular'}</option>
							<option value="quick">{isRTL ? 'سريع' : 'Quick'}</option>
							<option value="receiving">{isRTL ? 'استلام' : 'Receiving'}</option>
						</select>
					</div>
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{isRTL ? 'الأولوية' : 'Priority'}</label>
						<select bind:value={selectedPriority} on:change={applyFilters} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all">
							<option value="">{isRTL ? 'الكل' : 'All'}</option>
							<option value="high">{isRTL ? 'عاجل' : 'High'}</option>
							<option value="medium">{isRTL ? 'متوسط' : 'Medium'}</option>
							<option value="low">{isRTL ? 'منخفض' : 'Low'}</option>
						</select>
					</div>
				</div>

				<!-- Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<div class="overflow-x-auto flex-1 overflow-y-auto">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-amber-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 bg-amber-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">#</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'المهمة' : 'Task'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'النوع' : 'Type'}</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'الفرع' : 'Branch'}</th>
									<th class="px-4 py-3 {isRTL ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'مسند إلى' : 'Assigned To'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'الأولوية' : 'Priority'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'الموعد' : 'Deadline'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'منذ' : 'Age'}</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-amber-400">{isRTL ? 'عرض' : 'View'}</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each filteredTasks as task, index (task.id + ':' + task.task_type)}
									{@const typeInfo = getTypeInfo(task.task_type)}
									{@const dueInfo = getDueStatus(task.deadline)}
									{@const prioInfo = getPriorityInfo(task.priority)}
									<tr class="hover:bg-amber-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-4 py-2.5 text-xs text-slate-400 font-mono">{index + 1}</td>
										<td class="px-4 py-2.5">
											<div class="text-sm font-semibold text-slate-800 truncate max-w-[280px]">{task.task_title}</div>
											{#if task.task_description}
												<div class="text-[10px] text-slate-400 truncate max-w-[280px]">{task.task_description.substring(0, 80)}</div>
											{/if}
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border text-[10px] font-bold {typeInfo.bg} {typeInfo.color}">
												<span>{typeInfo.icon}</span> {typeInfo.label}
											</span>
										</td>
										<td class="px-4 py-2.5 text-sm text-slate-700">{getBranch(task)}</td>
										<td class="px-4 py-2.5">
											<div class="text-sm text-slate-700 font-medium">{getEmpName(task)}</div>
											<div class="text-[10px] text-slate-400">{isRTL ? 'من: ' : 'By: '}{task.assigned_by_name}</div>
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-flex items-center gap-1.5 {prioInfo.color} text-xs font-bold">
												<span class="w-2 h-2 rounded-full {prioInfo.dot}"></span>
												{prioInfo.label}
											</span>
										</td>
										<td class="px-4 py-2.5 text-center">
											<span class="inline-block px-2.5 py-1 rounded-lg text-[10px] font-bold {dueInfo.bg} {dueInfo.color}">
												{dueInfo.text}
											</span>
										</td>
										<td class="px-4 py-2.5 text-center text-xs text-slate-500 font-medium">
											{getTimeSince(task.assigned_date)}
										</td>
										<td class="px-4 py-2.5 text-center">
											<button
												class="px-3 py-1.5 bg-amber-500 text-white rounded-lg text-[10px] font-bold hover:bg-amber-600 transition-all shadow-sm hover:shadow-md active:scale-95"
												on:click={() => openDetail(task)}
											>
												{isRTL ? 'تفاصيل' : 'Details'}
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
						{#if filteredTasks.length === 0 && allTasks.length > 0}
							<div class="flex items-center justify-center py-12">
								<div class="text-center">
									<div class="text-4xl mb-3">🔍</div>
									<p class="text-slate-500 font-semibold">{isRTL ? 'لا نتائج مطابقة' : 'No matching results'}</p>
									<p class="text-slate-400 text-xs mt-1">{isRTL ? 'حاول تغيير الفلاتر' : 'Try changing filters'}</p>
								</div>
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- Task Detail Popup -->
{#if showDetailPopup && selectedTask}
	{@const t = selectedTask}
	{@const typeInfo = getTypeInfo(t.task_type)}
	{@const dueInfo = getDueStatus(t.deadline)}
	{@const prioInfo = getPriorityInfo(t.priority)}
	<div
		class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[200] flex items-center justify-center"
		style="animation: fadeIn 0.15s ease-out;"
		on:click|self={closeDetail}
		on:keydown={(e) => e.key === 'Escape' && closeDetail()}
		role="dialog"
		aria-modal="true"
	>
		<div class="bg-white rounded-3xl shadow-2xl border border-slate-200 w-[560px] max-h-[80vh] overflow-hidden" style="animation: scaleIn 0.2s ease-out;" dir={isRTL ? 'rtl' : 'ltr'}>
			<!-- Popup Header -->
			<div class="bg-gradient-to-r from-amber-500 to-orange-500 px-6 py-4 flex items-center justify-between">
				<div class="flex items-center gap-3">
					<span class="text-2xl">{typeInfo.icon}</span>
					<div>
						<h3 class="text-sm font-black text-white uppercase tracking-wide">{isRTL ? 'تفاصيل المهمة' : 'Task Details'}</h3>
						<p class="text-[10px] text-amber-100 font-semibold">{typeInfo.label} • ID: {t.id.substring(0, 8)}...</p>
					</div>
				</div>
				<button class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 transition-all flex items-center justify-center" on:click={closeDetail}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
				</button>
			</div>

			<!-- Popup Body -->
			<div class="p-6 overflow-y-auto max-h-[60vh]">
				<!-- Title & Description -->
				<div class="mb-5">
					<h4 class="text-lg font-bold text-slate-800 mb-1">{t.task_title}</h4>
					{#if t.task_description}
						<p class="text-sm text-slate-500 leading-relaxed whitespace-pre-wrap">{t.task_description}</p>
					{/if}
				</div>

				<!-- Info Grid -->
				<div class="grid grid-cols-2 gap-3 mb-5">
					<!-- Type -->
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'النوع' : 'Type'}</p>
						<span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold {typeInfo.bg} {typeInfo.color}">
							{typeInfo.icon} {typeInfo.label}
						</span>
					</div>
					<!-- Priority -->
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الأولوية' : 'Priority'}</p>
						<span class="inline-flex items-center gap-1.5 {prioInfo.color} text-sm font-bold">
							<span class="w-2.5 h-2.5 rounded-full {prioInfo.dot}"></span>
							{prioInfo.label}
						</span>
					</div>
					<!-- Deadline -->
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الموعد النهائي' : 'Deadline'}</p>
						<span class="inline-block px-3 py-1 rounded-lg text-xs font-bold {dueInfo.bg} {dueInfo.color}">
							{t.deadline ? formatDate(t.deadline) : (isRTL ? 'بدون موعد' : 'No Deadline')}
						</span>
						{#if t.deadline}
							<span class="block text-[10px] mt-1 {dueInfo.color} font-semibold">{dueInfo.text}</span>
						{/if}
					</div>
					<!-- Status -->
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الحالة' : 'Status'}</p>
						<span class="inline-block px-3 py-1 rounded-lg text-xs font-bold bg-amber-100 text-amber-700">{t.status || 'pending'}</span>
					</div>
				</div>

				<!-- People & Branch -->
				<div class="grid grid-cols-2 gap-3 mb-5">
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'مسند إلى' : 'Assigned To'}</p>
						<p class="text-sm font-semibold text-slate-700">{getEmpName(t)}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'المسند بواسطة' : 'Assigned By'}</p>
						<p class="text-sm font-semibold text-slate-700">{t.assigned_by_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'الفرع' : 'Branch'}</p>
						<p class="text-sm font-semibold text-slate-700">{getBranch(t)}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
						<p class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mb-1">{isRTL ? 'تاريخ التعيين' : 'Assigned Date'}</p>
						<p class="text-sm font-semibold text-slate-700">{formatDate(t.assigned_date)}</p>
						<p class="text-[10px] text-slate-400 mt-0.5">{getTimeSince(t.assigned_date)}</p>
					</div>
				</div>

				<!-- Notes -->
				{#if t.notes}
					<div class="bg-amber-50 rounded-xl p-4 border border-amber-100">
						<p class="text-[10px] font-bold text-amber-500 uppercase tracking-wide mb-1">{isRTL ? 'ملاحظات' : 'Notes'}</p>
						<p class="text-sm text-slate-700 whitespace-pre-wrap">{t.notes}</p>
					</div>
				{/if}
			</div>

			<!-- Popup Footer -->
			<div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex justify-end">
				<button
					class="px-5 py-2 bg-slate-200 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-300 transition-all"
					on:click={closeDetail}
				>
					{isRTL ? 'إغلاق' : 'Close'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}
	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}
	/* RTL fixes for dropdown arrows */
	:global([dir="rtl"] select) {
		background-position: left 0.75rem center !important;
		padding-left: 2.5rem !important;
		padding-right: 1rem !important;
	}
</style>
