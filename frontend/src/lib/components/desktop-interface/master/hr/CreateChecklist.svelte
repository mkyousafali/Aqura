<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { translateText, correctSpelling } from '$lib/utils/translationService';
	import { supabase } from '$lib/utils/supabase';

	// Edit mode props (passed when editing existing checklist)
	export let editId: string | null = null;
	export let editNameEn: string = '';
	export let editNameAr: string = '';
	export let editQuestionIds: string[] = [];

	$: isEditMode = !!editId;

	// Checklist name
	let checklistNameEn = editNameEn;
	let checklistNameAr = editNameAr;

	// Translation state
	let translatingQ: { [key: string]: boolean } = {};

	// Questions from DB
	let allQuestions: any[] = [];
	let selectedQuestionIds: Set<string> = new Set(editQuestionIds);
	let loading = true;
	let saving = false;
	let saveMessage = '';

	onMount(async () => {
		await loadQuestions();
	});

	async function loadQuestions() {
		loading = true;
		const { data, error } = await supabase
			.from('hr_checklist_questions')
			.select('*')
			.order('created_at', { ascending: true });
		if (error) {
			console.error('Failed to load questions:', error);
		} else {
			allQuestions = data || [];
		}
		loading = false;
	}

	function toggleQuestion(id: string) {
		if (selectedQuestionIds.has(id)) {
			selectedQuestionIds.delete(id);
		} else {
			selectedQuestionIds.add(id);
		}
		selectedQuestionIds = new Set(selectedQuestionIds);
	}

	function toggleAll() {
		if (selectedQuestionIds.size === allQuestions.length) {
			selectedQuestionIds = new Set();
		} else {
			selectedQuestionIds = new Set(allQuestions.map(q => q.id));
		}
	}

	// Count non-null answers for a question row
	function countAnswers(q: any): number {
		let count = 0;
		for (let i = 1; i <= 6; i++) {
			if (q[`answer_${i}_en`] || q[`answer_${i}_ar`]) count++;
		}
		return count;
	}

	// Save checklist
	async function saveChecklist() {
		if (!checklistNameEn.trim() && !checklistNameAr.trim()) return;
		if (selectedQuestionIds.size === 0) return;

		saving = true;
		saveMessage = '';
		try {
			if (isEditMode) {
				// Update existing checklist
				const { error } = await supabase.from('hr_checklists').update({
					checklist_name_en: checklistNameEn,
					checklist_name_ar: checklistNameAr,
					question_ids: Array.from(selectedQuestionIds)
				}).eq('id', editId);
				if (error) {
					console.error('Update failed:', error);
					saveMessage = 'error';
				} else {
					saveMessage = 'success';
				}
			} else {
				// Create new checklist
				const { error } = await supabase.from('hr_checklists').insert({
					checklist_name_en: checklistNameEn,
					checklist_name_ar: checklistNameAr,
					question_ids: Array.from(selectedQuestionIds)
				});
				if (error) {
					console.error('Save failed:', error);
					saveMessage = 'error';
				} else {
					saveMessage = 'success';
					checklistNameEn = '';
					checklistNameAr = '';
					selectedQuestionIds = new Set();
				}
			}
		} catch (err) {
			console.error('Save failed:', err);
			saveMessage = 'error';
		} finally {
			saving = false;
			setTimeout(() => { saveMessage = ''; }, 3000);
		}
	}

	// Spell check & translate checklist name
	async function spellCheckChecklistName() {
		if (!checklistNameEn.trim()) return;
		const corrected = await correctSpelling(checklistNameEn);
		if (corrected !== checklistNameEn) checklistNameEn = corrected;
	}

	async function translateChecklistName(direction: 'en-to-ar' | 'ar-to-en') {
		const key = `cl-${direction}`;
		if (translatingQ[key]) return;

		const sourceText = direction === 'en-to-ar' ? checklistNameEn : checklistNameAr;
		if (!sourceText.trim()) return;

		translatingQ[key] = true;
		translatingQ = translatingQ;
		try {
			const result = await translateText({
				text: sourceText,
				sourceLanguage: direction === 'en-to-ar' ? 'en' : 'ar',
				targetLanguage: direction === 'en-to-ar' ? 'ar' : 'en'
			});
			if (direction === 'en-to-ar') {
				checklistNameAr = result;
			} else {
				checklistNameEn = result;
			}
		} catch (err) {
			console.error('Translation failed:', err);
		} finally {
			translatingQ[key] = false;
			translatingQ = translatingQ;
		}
	}
</script>

<div class="h-full flex flex-col bg-white" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4">
		<h2 class="text-white font-bold text-lg">📝 {isEditMode ? $t('hr.dailyChecklist.editChecklist') : $t('hr.dailyChecklist.newChecklist')}</h2>
	</div>

	<div class="flex-1 p-6 space-y-4 overflow-y-auto">
		<!-- Checklist Name -->
		<div>
			<label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.dailyChecklist.checklistName')} <span class="text-red-500">*</span></label>
			<div class="flex items-center gap-2">
				<div class="flex-1 flex items-center gap-1.5">
					<input
						type="text"
						bind:value={checklistNameEn}
						on:blur={spellCheckChecklistName}
						placeholder={$t('hr.dailyChecklist.checklistNameEn')}
						dir="ltr"
						class="flex-1 px-3 py-2.5 border-2 border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400 outline-none"
					/>
					<button
						on:click={() => translateChecklistName('en-to-ar')}
						disabled={translatingQ['cl-en-to-ar'] || !checklistNameEn.trim()}
						title={$t('hr.dailyChecklist.translateEnToAr')}
						class="p-2 rounded-lg border border-slate-200 hover:bg-amber-50 hover:border-amber-300 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
					>
						{#if translatingQ['cl-en-to-ar']}
							<svg class="w-4 h-4 text-amber-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
						{:else}
							<svg class="w-4 h-4 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" /></svg>
						{/if}
					</button>
				</div>
				<div class="flex-1 flex items-center gap-1.5">
					<button
						on:click={() => translateChecklistName('ar-to-en')}
						disabled={translatingQ['cl-ar-to-en'] || !checklistNameAr.trim()}
						title={$t('hr.dailyChecklist.translateArToEn')}
						class="p-2 rounded-lg border border-slate-200 hover:bg-amber-50 hover:border-amber-300 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
					>
						{#if translatingQ['cl-ar-to-en']}
							<svg class="w-4 h-4 text-amber-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
						{:else}
							<svg class="w-4 h-4 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" /></svg>
						{/if}
					</button>
					<input
						type="text"
						bind:value={checklistNameAr}
						placeholder={$t('hr.dailyChecklist.checklistNameAr')}
						dir="rtl"
						class="flex-1 px-3 py-2.5 border-2 border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400 outline-none"
					/>
				</div>
			</div>
		</div>

		<!-- Questions Table -->
		<div>
			<div class="flex items-center justify-between mb-3">
				<h3 class="text-sm font-bold text-slate-700">{$t('hr.dailyChecklist.selectQuestions')} <span class="text-xs text-slate-400">({selectedQuestionIds.size}/{allQuestions.length})</span></h3>
				<div class="flex items-center gap-3">
					{#if saveMessage === 'success'}
						<span class="text-sm font-bold text-green-600">✅ {$t('hr.dailyChecklist.savedSuccess')}</span>
					{:else if saveMessage === 'error'}
						<span class="text-sm font-bold text-red-600">❌ {$t('hr.dailyChecklist.saveFailed')}</span>
					{/if}
					<button
						on:click={saveChecklist}
						disabled={saving || selectedQuestionIds.size === 0 || (!checklistNameEn.trim() && !checklistNameAr.trim())}
						class="px-4 py-2 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-1.5 text-sm shadow whitespace-nowrap disabled:opacity-40 disabled:cursor-not-allowed"
					>
						{#if saving}
							<svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
						{:else}
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
						{/if}
						{$t(isEditMode ? 'hr.dailyChecklist.update' : 'hr.dailyChecklist.save')}
					</button>
				</div>
			</div>

			{#if loading}
				<div class="flex items-center justify-center py-12">
					<svg class="w-6 h-6 text-emerald-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
				</div>
			{:else if allQuestions.length === 0}
				<div class="text-center py-12 text-slate-400 text-sm">
					{$t('hr.dailyChecklist.noQuestions')}
				</div>
			{:else}
				<div class="border border-slate-200 rounded-lg overflow-hidden">
					<table class="w-full text-sm">
						<thead>
							<tr class="bg-slate-100 border-b border-slate-200">
								<th class="px-3 py-2.5 text-start w-10">
									<input
										type="checkbox"
										checked={selectedQuestionIds.size === allQuestions.length && allQuestions.length > 0}
										on:change={toggleAll}
										class="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
									/>
								</th>
								<th class="px-3 py-2.5 text-start text-xs font-bold text-slate-500 uppercase w-16">#</th>
								<th class="px-3 py-2.5 text-start text-xs font-bold text-slate-500 uppercase">{$t('hr.dailyChecklist.questionText')} (EN)</th>
								<th class="px-3 py-2.5 text-start text-xs font-bold text-slate-500 uppercase">{$t('hr.dailyChecklist.questionText')} (AR)</th>
								<th class="px-3 py-2.5 text-center text-xs font-bold text-slate-500 uppercase w-20">{$t('hr.dailyChecklist.answerCount')}</th>
								<th class="px-3 py-2.5 text-center text-xs font-bold text-slate-500 uppercase w-20">{$t('hr.dailyChecklist.remarks')}</th>
								<th class="px-3 py-2.5 text-center text-xs font-bold text-slate-500 uppercase w-20">{$t('hr.dailyChecklist.other')}</th>
							</tr>
						</thead>
						<tbody>
							{#each allQuestions as q, idx}
								<tr
									class="border-b border-slate-100 hover:bg-emerald-50/50 transition-colors cursor-pointer {selectedQuestionIds.has(q.id) ? 'bg-emerald-50' : ''}"
									on:click={() => toggleQuestion(q.id)}
								>
									<td class="px-3 py-2.5">
										<input
											type="checkbox"
											checked={selectedQuestionIds.has(q.id)}
											on:change={() => toggleQuestion(q.id)}
											on:click|stopPropagation
											class="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
										/>
									</td>
									<td class="px-3 py-2.5 text-xs font-bold text-slate-400">{q.id}</td>
									<td class="px-3 py-2.5 text-slate-700" dir="ltr">{q.question_en || '-'}</td>
									<td class="px-3 py-2.5 text-slate-700" dir="rtl">{q.question_ar || '-'}</td>
									<td class="px-3 py-2.5 text-center">
										<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold {countAnswers(q) > 0 ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-400'}">
											{countAnswers(q)}
										</span>
									</td>
									<td class="px-3 py-2.5 text-center">
										{#if q.has_remarks}
											<span class="text-purple-500">✓</span>
										{:else}
											<span class="text-slate-300">—</span>
										{/if}
									</td>
									<td class="px-3 py-2.5 text-center">
										{#if q.has_other}
											<span class="text-orange-500">✓</span>
										{:else}
											<span class="text-slate-300">—</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</div>
</div>
