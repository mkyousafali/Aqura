<script lang="ts">
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import CreateChecklist from './CreateChecklist.svelte';
	import CreateChecklistQuestion from './CreateChecklistQuestion.svelte';
	import ViewChecklistAnswers from './ViewChecklistAnswers.svelte';

	let activeTab = 'create';

	// Checklists from DB
	let checklists: any[] = [];
	let loadingChecklists = true;

	// Questions from DB (for questions tab)
	let allQuestions: any[] = [];
	let loadingQuestions = true;

	// Checklist operations (submissions)
	let submissions: any[] = [];
	let loadingSubmissions = true;

	// Search
	let searchChecklists = '';
	let searchQuestions = '';
	let searchSubmissions = '';

	$: filteredChecklists = searchChecklists.trim()
		? checklists.filter(cl => {
			const s = searchChecklists.toLowerCase();
			return (cl.id || '').toLowerCase().includes(s)
				|| (cl.checklist_name_en || '').toLowerCase().includes(s)
				|| (cl.checklist_name_ar || '').includes(s);
		})
		: checklists;

	$: filteredQuestions = searchQuestions.trim()
		? allQuestions.filter(q => {
			const s = searchQuestions.toLowerCase();
			return (q.id || '').toLowerCase().includes(s)
				|| (q.question_en || '').toLowerCase().includes(s)
				|| (q.question_ar || '').includes(s);
		})
		: allQuestions;

	$: filteredSubmissions = searchSubmissions.trim()
		? submissions.filter(s => {
			const q = searchSubmissions.toLowerCase();
			return (s.id || '').toLowerCase().includes(q)
				|| (s.employee_id || '').toLowerCase().includes(q)
				|| (s.checklist_id || '').toLowerCase().includes(q)
				|| (s.hr_employee_master?.name_en || '').toLowerCase().includes(q)
				|| (s.hr_employee_master?.name_ar || '').includes(q);
		})
		: submissions;

	onMount(async () => {
		await Promise.all([loadChecklists(), loadQuestions(), loadSubmissions()]);
	});

	async function loadChecklists() {
		loadingChecklists = true;
		const { data, error } = await supabase
			.from('hr_checklists')
			.select('*')
			.order('created_at', { ascending: false });
		if (!error) checklists = data || [];
		loadingChecklists = false;
	}

	async function loadQuestions() {
		loadingQuestions = true;
		const { data, error } = await supabase
			.from('hr_checklist_questions')
			.select('*')
			.order('created_at', { ascending: true });
		if (!error) allQuestions = data || [];
		loadingQuestions = false;
	}

	async function loadSubmissions() {
		loadingSubmissions = true;
		const { data, error } = await supabase
			.from('hr_checklist_operations')
			.select(`
				*,
				hr_employee_master(id, name_en, name_ar),
				hr_checklists(id, checklist_name_en, checklist_name_ar),
				branches(id, name_en, name_ar)
			`)
			.order('created_at', { ascending: false });
		if (!error) submissions = data || [];
		loadingSubmissions = false;
	}

	async function deleteSubmission(id: string) {
		if (!confirm('Are you sure you want to delete this submission?')) return;
		const { error } = await supabase.from('hr_checklist_operations').delete().eq('id', id);
		if (!error) {
			submissions = submissions.filter(s => s.id !== id);
		}
	}

	function formatTime12Hour(time: string | null, date: string | null): string {
		if (!time) return '-';
		// Convert UTC to Saudi Arabia time (UTC+3)
		const [hours, minutes] = time.split(':').map(Number);
		let saudiHours = hours + 3;
		if (saudiHours >= 24) saudiHours -= 24;
		const period = saudiHours >= 12 ? 'PM' : 'AM';
		const hour12 = saudiHours % 12 || 12;
		return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
	}

	function formatDateDMY(date: string | null, time: string | null): string {
		if (!date) return '-';
		let [year, month, day] = date.split('-').map(Number);
		// Check if time conversion to Saudi (UTC+3) crosses midnight
		if (time) {
			const [hours] = time.split(':').map(Number);
			if (hours + 3 >= 24) {
				// Add one day
				const d = new Date(year, month - 1, day);
				d.setDate(d.getDate() + 1);
				year = d.getFullYear();
				month = d.getMonth() + 1;
				day = d.getDate();
			}
		}
		return `${day.toString().padStart(2, '0')}-${month.toString().padStart(2, '0')}-${year}`;
	}

	function countAnswers(q: any): number {
		let count = 0;
		for (let i = 1; i <= 6; i++) {
			if (q[`answer_${i}_en`] || q[`answer_${i}_ar`]) count++;
		}
		return count;
	}

	function getRemarks(answers: any[] | null): string {
		if (!answers || !Array.isArray(answers)) return '-';
		const remarks = answers
			.filter(a => a.remarks)
			.map(a => a.remarks)
			.filter(Boolean);
		return remarks.length > 0 ? remarks.join(', ') : '-';
	}

	function getOtherValues(answers: any[] | null): string {
		if (!answers || !Array.isArray(answers)) return '-';
		const others = answers
			.filter(a => a.other_value)
			.map(a => a.other_value)
			.filter(Boolean);
		return others.length > 0 ? others.join(', ') : '-';
	}

	async function deleteChecklist(id: string) {
		const { error } = await supabase.from('hr_checklists').delete().eq('id', id);
		if (!error) checklists = checklists.filter(c => c.id !== id);
	}

	function editChecklist(cl: any) {
		const windowId = generateWindowId('edit-checklist');
		openWindow({
			id: windowId,
			title: `${$t('hr.dailyChecklist.editChecklist')} - ${cl.id}`,
			component: CreateChecklist,
			props: {
				editId: cl.id,
				editNameEn: cl.checklist_name_en || '',
				editNameAr: cl.checklist_name_ar || '',
				editQuestionIds: Array.isArray(cl.question_ids) ? cl.question_ids : []
			},
			icon: '✏️',
			size: { width: 600, height: 500 },
			position: {
				x: 150 + (Math.random() * 100),
				y: 100 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function deleteQuestion(id: string) {
		const { error } = await supabase.from('hr_checklist_questions').delete().eq('id', id);
		if (!error) allQuestions = allQuestions.filter(q => q.id !== id);
	}

	function editQuestion(q: any) {
		const windowId = generateWindowId('edit-question');
		openWindow({
			id: windowId,
			title: `${$t('hr.dailyChecklist.editQuestion')} - ${q.id}`,
			component: CreateChecklistQuestion,
			props: {
				editId: q.id,
				editData: q
			},
			icon: '✏️',
			size: { width: 600, height: 500 },
			position: {
				x: 200 + (Math.random() * 100),
				y: 120 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	$: tabs = [
		{ id: 'create', label: $t('hr.dailyChecklist.createChecklist'), icon: '📝', color: 'green' },
		{ id: 'assign', label: $t('hr.dailyChecklist.assignChecklist'), icon: '📋', color: 'orange' },
		{ id: 'questions', label: $t('hr.dailyChecklist.checklistQuestions'), icon: '❓', color: 'blue' },
		{ id: 'report', label: $t('hr.dailyChecklist.submissionReport'), icon: '📊', color: 'purple' }
	];

	function generateWindowId(type: string) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openCreateChecklist() {
		const windowId = generateWindowId('create-checklist');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `${$t('hr.dailyChecklist.createChecklist')} #${instanceNumber}`,
			component: CreateChecklist,
			icon: '📝',
			size: { width: 600, height: 500 },
			position: {
				x: 150 + (Math.random() * 100),
				y: 100 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openCreateChecklistQuestion() {
		const windowId = generateWindowId('create-checklist-question');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `${$t('hr.dailyChecklist.checklistQuestions')} #${instanceNumber}`,
			component: CreateChecklistQuestion,
			icon: '❓',
			size: { width: 600, height: 500 },
			position: {
				x: 200 + (Math.random() * 100),
				y: 120 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openViewAnswers(sub: any) {
		const windowId = generateWindowId('view-answers');
		const isArabic = $locale === 'ar';
		const employeeName = isArabic 
			? (sub.hr_employee_master?.name_ar || sub.hr_employee_master?.name_en || sub.employee_id || '-')
			: (sub.hr_employee_master?.name_en || sub.hr_employee_master?.name_ar || sub.employee_id || '-');
		const checklistName = isArabic
			? (sub.hr_checklists?.checklist_name_ar || sub.hr_checklists?.checklist_name_en || sub.checklist_id || '-')
			: (sub.hr_checklists?.checklist_name_en || sub.hr_checklists?.checklist_name_ar || sub.checklist_id || '-');
		const branchName = isArabic
			? (sub.branches?.name_ar || sub.branches?.name_en || '-')
			: (sub.branches?.name_en || sub.branches?.name_ar || '-');

		openWindow({
			id: windowId,
			title: `${$t('hr.dailyChecklist.viewAnswers')} - ${sub.id}`,
			component: ViewChecklistAnswers,
			props: {
				submissionId: sub.id,
				employeeName: employeeName,
				checklistName: checklistName,
				answers: sub.answers || [],
				totalPoints: sub.total_points ?? 0,
				maxPoints: sub.max_points ?? 0,
				operationDate: sub.operation_date || '',
				operationTime: sub.operation_time || '',
				boxNumber: sub.box_number || '',
				branchName: branchName
			},
			icon: '👁️',
			size: { width: 550, height: 600 },
			position: {
				x: 250 + (Math.random() * 100),
				y: 80 + (Math.random() * 100)
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header/Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			{#each tabs as tab}
				<button 
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === tab.id 
						? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : tab.color === 'orange' ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]' : tab.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' : 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]')
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => { activeTab = tab.id; }}
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
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if activeTab === 'create'}
				<div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex-1">
					<div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4 flex items-center justify-end">
						<div class="flex items-center gap-2">
							<div class="relative">
								<svg class="w-4 h-4 text-white/60 absolute top-1/2 -translate-y-1/2 {$locale === 'ar' ? 'right-2.5' : 'left-2.5'}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
								<input type="text" bind:value={searchChecklists} placeholder="Search..." class="w-80 {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-1.5 bg-white/20 border border-white/30 rounded-lg text-sm text-white placeholder-white/50 focus:bg-white/30 focus:border-white/50 outline-none" />
							</div>
							<button on:click={loadChecklists} class="bg-white/20 hover:bg-white/30 text-white font-bold p-2 rounded-lg transition-colors shadow" title="Refresh">
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
							</button>
							<button on:click={openCreateChecklist} class="bg-white text-emerald-600 font-bold px-4 py-2 rounded-lg hover:bg-emerald-50 transition-colors flex items-center gap-2 text-sm shadow">
								<span class="text-lg">+</span> {$t('hr.dailyChecklist.newChecklist')}
							</button>
						</div>
					</div>
					<div class="p-6">
						{#if loadingChecklists}
							<div class="flex items-center justify-center py-12">
								<svg class="w-6 h-6 text-emerald-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
							</div>
						{:else}
							<table class="w-full text-sm">
								<thead>
									<tr class="border-b border-slate-200">
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">#</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.checklistName')} (EN)</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.checklistName')} (AR)</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.questionsCount')}</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.actions')}</th>
									</tr>
								</thead>
								<tbody>
									{#if filteredChecklists.length === 0}
										<tr>
											<td colspan="5" class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noChecklists')}</td>
										</tr>
									{:else}
										{#each filteredChecklists as cl, idx}
											<tr class="border-b border-slate-100 hover:bg-emerald-50/50 transition-colors">
												<td class="py-3 px-4 text-xs font-bold text-slate-400">{cl.id}</td>
												<td class="py-3 px-4 text-slate-700" dir="ltr">{cl.checklist_name_en || '-'}</td>
												<td class="py-3 px-4 text-slate-700" dir="rtl">{cl.checklist_name_ar || '-'}</td>
												<td class="py-3 px-4 text-center">
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold {Array.isArray(cl.question_ids) && cl.question_ids.length > 0 ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-400'}">
														{Array.isArray(cl.question_ids) ? cl.question_ids.length : 0}
													</span>
												</td>
												<td class="py-3 px-4 text-center">
													<button
														on:click={() => editChecklist(cl)}
														class="text-blue-500 hover:text-blue-700 transition-colors text-sm font-bold"
														title={$t('hr.dailyChecklist.editChecklist')}
													>
														<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
													</button>
												</td>
											</tr>
										{/each}
									{/if}
								</tbody>
							</table>
						{/if}
					</div>
				</div>
			{:else if activeTab === 'assign'}
				<div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex-1">
					<div class="bg-gradient-to-r from-orange-600 to-orange-500 px-6 py-4 flex items-center justify-end">
						<button class="bg-white/20 hover:bg-white/30 text-white font-bold p-2 rounded-lg transition-colors shadow" title="Refresh">
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
						</button>
					</div>
					<div class="p-6">
						<table class="w-full text-sm">
							<thead>
								<tr class="border-b border-slate-200">
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">#</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.checklist')}</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.assignedTo')}</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.branch')}</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.frequency')}</th>
									<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.actions')}</th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td colspan="6" class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noAssignments')}</td>
								</tr>
							</tbody>
						</table>
					</div>
				</div>
			{:else if activeTab === 'questions'}
				<div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex-1">
					<div class="bg-gradient-to-r from-blue-600 to-blue-500 px-6 py-4 flex items-center justify-end">
						<div class="flex items-center gap-2">
							<div class="relative">
								<svg class="w-4 h-4 text-white/60 absolute top-1/2 -translate-y-1/2 {$locale === 'ar' ? 'right-2.5' : 'left-2.5'}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
								<input type="text" bind:value={searchQuestions} placeholder="Search..." class="w-80 {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-1.5 bg-white/20 border border-white/30 rounded-lg text-sm text-white placeholder-white/50 focus:bg-white/30 focus:border-white/50 outline-none" />
							</div>
							<button on:click={loadQuestions} class="bg-white/20 hover:bg-white/30 text-white font-bold p-2 rounded-lg transition-colors shadow" title="Refresh">
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
							</button>
							<button on:click={openCreateChecklistQuestion} class="bg-white text-blue-600 font-bold px-4 py-2 rounded-lg hover:bg-blue-50 transition-colors flex items-center gap-2 text-sm shadow">
								<span class="text-lg">+</span> {$t('hr.dailyChecklist.checklistQuestions')}
							</button>
						</div>
					</div>
					<div class="p-6">
						{#if loadingQuestions}
							<div class="flex items-center justify-center py-12">
								<svg class="w-6 h-6 text-blue-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
							</div>
						{:else}
							<table class="w-full text-sm">
								<thead>
									<tr class="border-b border-slate-200">
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">#</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.questionText')} (EN)</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.questionText')} (AR)</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.answerCount')}</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.remarks')}</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.other')}</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.actions')}</th>
									</tr>
								</thead>
								<tbody>
									{#if filteredQuestions.length === 0}
										<tr>
											<td colspan="7" class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noQuestions')}</td>
										</tr>
									{:else}
										{#each filteredQuestions as q}
											<tr class="border-b border-slate-100 hover:bg-blue-50/50 transition-colors">
												<td class="py-3 px-4 text-xs font-bold text-slate-400">{q.id}</td>
												<td class="py-3 px-4 text-slate-700" dir="ltr">{q.question_en || '-'}</td>
												<td class="py-3 px-4 text-slate-700" dir="rtl">{q.question_ar || '-'}</td>
												<td class="py-3 px-4 text-center">
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold {countAnswers(q) > 0 ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-400'}">
														{countAnswers(q)}
													</span>
												</td>
												<td class="py-3 px-4 text-center">
													{#if q.has_remarks}<span class="text-purple-500">✓</span>{:else}<span class="text-slate-300">—</span>{/if}
												</td>
												<td class="py-3 px-4 text-center">
													{#if q.has_other}<span class="text-orange-500">✓</span>{:else}<span class="text-slate-300">—</span>{/if}
												</td>
												<td class="py-3 px-4 text-center">
													<button
														on:click={() => editQuestion(q)}
														class="text-blue-500 hover:text-blue-700 transition-colors text-sm font-bold"
														title={$t('hr.dailyChecklist.editQuestion')}
													>
														<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
													</button>
												</td>
											</tr>
										{/each}
									{/if}
								</tbody>
							</table>
						{/if}
					</div>
				</div>
			{:else if activeTab === 'report'}
				<div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex-1 flex flex-col">
					<div class="bg-gradient-to-r from-purple-600 to-purple-500 px-6 py-4 flex items-center justify-between gap-4">
						<div class="relative flex-1 max-w-xs">
							<input
								type="text"
								bind:value={searchSubmissions}
								placeholder="{$t('hr.dailyChecklist.search')}..."
								class="w-full pl-10 pr-4 py-2 rounded-lg bg-white/20 text-white placeholder-white/60 border-none focus:outline-none focus:ring-2 focus:ring-white/30"
							/>
							<svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/60" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
						</div>
						<button on:click={loadSubmissions} class="bg-white/20 hover:bg-white/30 text-white font-bold p-2 rounded-lg transition-colors shadow" title="Refresh">
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
						</button>
					</div>
					<div class="p-6 overflow-auto flex-1">
						{#if loadingSubmissions}
							<div class="flex items-center justify-center py-12">
								<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
							</div>
						{:else if filteredSubmissions.length === 0}
							<div class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noSubmissions')}</div>
						{:else}
							<table class="w-full text-sm">
								<thead>
									<tr class="border-b border-slate-200">
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.id')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.employee')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.checklist')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.boxNumber')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.branch')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.date')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.time')}</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.points')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.remarks')}</th>
										<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.other')}</th>
										<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.actions')}</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredSubmissions as sub}
										<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
											<td class="py-3 px-4 font-medium text-purple-600">{sub.id}</td>
											<td class="py-3 px-4">
												<div class="font-medium text-slate-800">{sub.hr_employee_master?.name_en || sub.employee_id || '-'}</div>
												{#if sub.hr_employee_master?.name_ar}
													<div class="text-xs text-slate-500">{sub.hr_employee_master.name_ar}</div>
												{/if}
											</td>
											<td class="py-3 px-4">
												<div class="font-medium text-slate-800">{sub.hr_checklists?.checklist_name_en || sub.checklist_id || '-'}</div>
												{#if sub.hr_checklists?.checklist_name_ar}
													<div class="text-xs text-slate-500">{sub.hr_checklists.checklist_name_ar}</div>
												{/if}
											</td>
											<td class="py-3 px-4 text-slate-600">{sub.box_number || '-'}</td>
											<td class="py-3 px-4">
												<div class="text-slate-600">{sub.branches?.name_en || '-'}</div>
												{#if sub.branches?.name_ar}
													<div class="text-xs text-slate-500">{sub.branches.name_ar}</div>
												{/if}
											</td>
											<td class="py-3 px-4 text-slate-600">{formatDateDMY(sub.operation_date, sub.operation_time)}</td>
											<td class="py-3 px-4 text-slate-600">{formatTime12Hour(sub.operation_time, sub.operation_date)}</td>
											<td class="py-3 px-4 text-center">
												<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold {sub.total_points >= 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}">
													{sub.total_points ?? 0}{#if sub.max_points}/{sub.max_points}{/if}
												</span>
											</td>
											<td class="py-3 px-4 text-slate-600 text-xs max-w-[200px] truncate" title={getRemarks(sub.answers)}>{getRemarks(sub.answers)}</td>
											<td class="py-3 px-4 text-slate-600 text-xs max-w-[200px] truncate" title={getOtherValues(sub.answers)}>{getOtherValues(sub.answers)}</td>
											<td class="py-3 px-4 text-center">
												<div class="flex items-center justify-center gap-1">
													<button
														on:click={() => openViewAnswers(sub)}
														class="p-1.5 text-blue-500 hover:bg-blue-50 rounded-lg transition-colors"
														title="View Answers"
													>
														<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
													</button>
													<button
														on:click={() => deleteSubmission(sub.id)}
														class="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition-colors"
														title="Delete"
													>
														<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
													</button>
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>
