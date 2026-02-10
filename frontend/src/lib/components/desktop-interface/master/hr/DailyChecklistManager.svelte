<script lang="ts">
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import CreateChecklist from './CreateChecklist.svelte';
	import CreateChecklistQuestion from './CreateChecklistQuestion.svelte';

	let activeTab = 'create';

	// Checklists from DB
	let checklists: any[] = [];
	let loadingChecklists = true;

	// Questions from DB (for questions tab)
	let allQuestions: any[] = [];
	let loadingQuestions = true;

	onMount(async () => {
		await Promise.all([loadChecklists(), loadQuestions()]);
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

	function countAnswers(q: any): number {
		let count = 0;
		for (let i = 1; i <= 6; i++) {
			if (q[`answer_${i}_en`] || q[`answer_${i}_ar`]) count++;
		}
		return count;
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
					<div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4 flex items-center justify-between">
						<h2 class="text-white font-bold text-lg">📝 {$t('hr.dailyChecklist.createChecklist')}</h2>
						<button on:click={openCreateChecklist} class="bg-white text-emerald-600 font-bold px-4 py-2 rounded-lg hover:bg-emerald-50 transition-colors flex items-center gap-2 text-sm shadow">
							<span class="text-lg">+</span> {$t('hr.dailyChecklist.newChecklist')}
						</button>
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
									{#if checklists.length === 0}
										<tr>
											<td colspan="5" class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noChecklists')}</td>
										</tr>
									{:else}
										{#each checklists as cl, idx}
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
					<div class="bg-gradient-to-r from-orange-600 to-orange-500 px-6 py-4">
						<h2 class="text-white font-bold text-lg">📋 {$t('hr.dailyChecklist.assignChecklist')}</h2>
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
					<div class="bg-gradient-to-r from-blue-600 to-blue-500 px-6 py-4 flex items-center justify-between">
						<h2 class="text-white font-bold text-lg">❓ {$t('hr.dailyChecklist.checklistQuestions')}</h2>
						<button on:click={openCreateChecklistQuestion} class="bg-white text-blue-600 font-bold px-4 py-2 rounded-lg hover:bg-blue-50 transition-colors flex items-center gap-2 text-sm shadow">
							<span class="text-lg">+</span> {$t('hr.dailyChecklist.checklistQuestions')}
						</button>
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
									{#if allQuestions.length === 0}
										<tr>
											<td colspan="7" class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noQuestions')}</td>
										</tr>
									{:else}
										{#each allQuestions as q}
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
														on:click={() => deleteQuestion(q.id)}
														class="text-red-400 hover:text-red-600 transition-colors text-sm font-bold"
														title="Delete"
													>×</button>
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
				<div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex-1">
					<div class="bg-gradient-to-r from-purple-600 to-purple-500 px-6 py-4">
						<h2 class="text-white font-bold text-lg">📊 {$t('hr.dailyChecklist.submissionReport')}</h2>
					</div>
					<div class="p-6">
						<table class="w-full text-sm">
							<thead>
								<tr class="border-b border-slate-200">
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">#</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.employee')}</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.checklist')}</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.date')}</th>
									<th class="text-start py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.status')}</th>
									<th class="text-center py-3 px-4 font-bold text-slate-600 uppercase text-xs">{$t('hr.dailyChecklist.details')}</th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td colspan="6" class="text-center py-12 text-slate-400">{$t('hr.dailyChecklist.noSubmissions')}</td>
								</tr>
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>
