<script lang="ts">
	import { locale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	export let submissionId: string = '';
	export let employeeName: string = '';
	export let checklistName: string = '';
	export let answers: any[] = [];
	export let totalPoints: number = 0;
	export let maxPoints: number = 0;
	export let operationDate: string = '';
	export let operationTime: string = '';
	export let boxNumber: string = '';
	export let branchName: string = '';

	let questions: Record<string, any> = {};
	let loadingQuestions = true;

	// Format date as dd-mm-yyyy
	function formatDate(date: string): string {
		if (!date) return '-';
		const [year, month, day] = date.split('-');
		return `${day}-${month}-${year}`;
	}

	// Format time as 12-hour with AM/PM (Saudi timezone UTC+3)
	function formatTime(time: string): string {
		if (!time) return '-';
		const [hours, minutes] = time.split(':').map(Number);
		let saudiHours = hours + 3;
		if (saudiHours >= 24) saudiHours -= 24;
		const period = saudiHours >= 12 ? 'PM' : 'AM';
		const hour12 = saudiHours % 12 || 12;
		return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
	}

	onMount(async () => {
		await loadQuestions();
	});

	async function loadQuestions() {
		if (!answers || answers.length === 0) {
			loadingQuestions = false;
			return;
		}

		const questionIds = answers.map(a => a.question_id).filter(Boolean);
		if (questionIds.length === 0) {
			loadingQuestions = false;
			return;
		}

		const { data, error } = await supabase
			.from('hr_checklist_questions')
			.select('id, question_en, question_ar')
			.in('id', questionIds);

		if (!error && data) {
			questions = data.reduce((acc: Record<string, any>, q: any) => {
				acc[q.id] = q;
				return acc;
			}, {});
		}
		loadingQuestions = false;
	}

	function getQuestionText(questionId: string): string {
		const q = questions[questionId];
		if (!q) return questionId;
		return $locale === 'ar' ? (q.question_ar || q.question_en) : (q.question_en || q.question_ar);
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200">
		<!-- Top Bar -->
		<div class="px-6 py-4 flex items-center justify-between">
			<div class="flex items-center gap-3">
				<div class="w-10 h-10 bg-slate-100 rounded-lg flex items-center justify-center">
					<svg class="w-5 h-5 text-slate-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" /></svg>
				</div>
				<div>
					<div class="flex items-center gap-2">
						<h2 class="text-lg font-bold text-slate-800">{checklistName}</h2>
						<span class="px-2 py-0.5 bg-slate-100 text-slate-600 rounded text-xs font-medium">{submissionId}</span>
					</div>
					<p class="text-sm text-slate-500">{employeeName}</p>
				</div>
			</div>
			
			<div class="text-center px-4 py-2 bg-slate-800 rounded-lg text-white">
				<div class="text-xl font-bold">{totalPoints}<span class="text-sm font-normal text-slate-400">/{maxPoints}</span></div>
				<div class="text-xs text-slate-400">{$locale === 'ar' ? 'النقاط' : 'Points'}</div>
			</div>
		</div>
		
		<!-- Stats Row -->
		<div class="px-6 py-3 bg-slate-50 border-t border-slate-100 flex items-center gap-6 text-sm">
			<div class="flex items-center gap-2">
				<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
				<span class="text-slate-600">{formatDate(operationDate)}</span>
			</div>
			<div class="w-px h-4 bg-slate-200"></div>
			<div class="flex items-center gap-2">
				<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
				<span class="text-slate-600">{formatTime(operationTime)}</span>
			</div>
			<div class="w-px h-4 bg-slate-200"></div>
			<div class="flex items-center gap-2">
				<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" /></svg>
				<span class="text-slate-600">{boxNumber || '-'}</span>
			</div>
			<div class="w-px h-4 bg-slate-200"></div>
			<div class="flex items-center gap-2">
				<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
				<span class="text-slate-600">{branchName || '-'}</span>
			</div>
		</div>
	</div>

	<!-- Answers List -->
	<div class="flex-1 p-6 overflow-y-auto">
		{#if loadingQuestions}
			<div class="flex items-center justify-center py-12">
				<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-slate-600"></div>
			</div>
		{:else if !answers || answers.length === 0}
			<div class="text-center text-slate-400 py-12">
				{$locale === 'ar' ? 'لا توجد إجابات' : 'No answers found'}
			</div>
		{:else}
			<div class="space-y-3">
				{#each answers as answer, idx}
					<div class="bg-white rounded-lg border border-slate-200 overflow-hidden">
						<div class="px-4 py-3 border-b border-slate-100">
							<div class="flex items-center justify-between mb-1">
								<div class="flex items-center gap-2">
									<span class="w-5 h-5 bg-slate-200 text-slate-600 rounded flex items-center justify-center text-xs font-medium">{idx + 1}</span>
									<span class="text-xs text-slate-400 font-mono">{answer.question_id}</span>
								</div>
								<span class="px-2 py-0.5 rounded text-xs font-medium {answer.points >= 0 ? 'bg-slate-100 text-slate-700' : 'bg-slate-100 text-slate-700'}">
									{answer.points > 0 ? '+' : ''}{answer.points} {$locale === 'ar' ? 'نقاط' : 'pts'}
								</span>
							</div>
							<p class="text-sm font-medium text-slate-800">{getQuestionText(answer.question_id)}</p>
						</div>
						<div class="px-4 py-3 space-y-2 text-sm">
							<div class="flex items-start gap-2">
								<span class="text-slate-400 min-w-[70px]">{$locale === 'ar' ? 'الإجابة' : 'Answer'}:</span>
								<span class="text-slate-700">{answer.answer_text || answer.answer_key || '-'}</span>
							</div>
							{#if answer.other_value}
								<div class="flex items-start gap-2">
									<span class="text-slate-400 min-w-[70px]">{$locale === 'ar' ? 'أخرى' : 'Other'}:</span>
									<span class="text-slate-700">{answer.other_value}</span>
								</div>
							{/if}
							{#if answer.remarks}
								<div class="flex items-start gap-2">
									<span class="text-slate-400 min-w-[70px]">{$locale === 'ar' ? 'ملاحظات' : 'Remarks'}:</span>
									<span class="text-slate-700">{answer.remarks}</span>
								</div>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
