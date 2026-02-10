<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { translateText, correctSpelling } from '$lib/utils/translationService';
	import { supabase } from '$lib/utils/supabase';

	let saving = false;
	let saveMessage = '';

	// Questions
	let questions: {
		name_en: string;
		name_ar: string;
		answers: { name_en: string; name_ar: string; points: number }[];
		hasRemarks: boolean;
		hasOther: boolean;
		otherPoints: number;
	}[] = [];
	let questionCounter = 0;

	function addQuestion() {
		questionCounter++;
		questions = [...questions, { name_en: '', name_ar: '', answers: [], hasRemarks: false, hasOther: false, otherPoints: 0 }];
	}

	function removeQuestion(index: number) {
		questions = questions.filter((_, i) => i !== index);
	}

	function addAnswer(questionIndex: number) {
		questions[questionIndex].answers = [...questions[questionIndex].answers, { name_en: '', name_ar: '', points: 0 }];
		questions = questions;
	}

	function removeAnswer(questionIndex: number, answerIndex: number) {
		questions[questionIndex].answers = questions[questionIndex].answers.filter((_, i) => i !== answerIndex);
		questions = questions;
	}

	// Translation
	let translatingQ: { [key: string]: boolean } = {};

	async function translateQuestion(index: number, direction: 'en-to-ar' | 'ar-to-en') {
		const key = `q${index}-${direction}`;
		if (translatingQ[key]) return;

		const sourceText = direction === 'en-to-ar' ? questions[index].name_en : questions[index].name_ar;
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
				questions[index].name_ar = result;
			} else {
				questions[index].name_en = result;
			}
			questions = questions;
		} catch (err) {
			console.error('Translation failed:', err);
		} finally {
			translatingQ[key] = false;
			translatingQ = translatingQ;
		}
	}

	async function translateAnswer(qIndex: number, aIndex: number, direction: 'en-to-ar' | 'ar-to-en') {
		const key = `a${qIndex}-${aIndex}-${direction}`;
		if (translatingQ[key]) return;

		const answer = questions[qIndex].answers[aIndex];
		const sourceText = direction === 'en-to-ar' ? answer.name_en : answer.name_ar;
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
				questions[qIndex].answers[aIndex].name_ar = result;
			} else {
				questions[qIndex].answers[aIndex].name_en = result;
			}
			questions = questions;
		} catch (err) {
			console.error('Translation failed:', err);
		} finally {
			translatingQ[key] = false;
			translatingQ = translatingQ;
		}
	}


	// Save questions to Supabase
	async function saveQuestions() {
		if (questions.length === 0) return;
		saving = true;
		saveMessage = '';
		try {
			const rows = questions.map((q) => {
				const row: Record<string, any> = {
					question_en: q.name_en,
					question_ar: q.name_ar,
					has_remarks: q.hasRemarks,
					has_other: q.hasOther,
					other_points: q.otherPoints
				};
				for (let i = 0; i < 6; i++) {
					const a = q.answers[i];
					row[`answer_${i + 1}_en`] = a ? a.name_en : null;
					row[`answer_${i + 1}_ar`] = a ? a.name_ar : null;
					row[`answer_${i + 1}_points`] = a ? a.points : 0;
				}
				return row;
			});

			const { error } = await supabase.from('hr_checklist_questions').insert(rows);
			if (error) {
				console.error('Save failed:', error);
				saveMessage = 'error';
			} else {
				saveMessage = 'success';
				questions = [];
				questionCounter = 0;
			}
		} catch (err) {
			console.error('Save failed:', err);
			saveMessage = 'error';
		} finally {
			saving = false;
			setTimeout(() => { saveMessage = ''; }, 3000);
		}
	}

	// Spell check on blur for English fields
	async function spellCheckQuestion(index: number) {
		const text = questions[index].name_en;
		if (!text.trim()) return;
		const corrected = await correctSpelling(text);
		if (corrected !== text) {
			questions[index].name_en = corrected;
			questions = questions;
		}
	}

	async function spellCheckAnswer(qIndex: number, aIndex: number) {
		const text = questions[qIndex].answers[aIndex].name_en;
		if (!text.trim()) return;
		const corrected = await correctSpelling(text);
		if (corrected !== text) {
			questions[qIndex].answers[aIndex].name_en = corrected;
			questions = questions;
		}
	}

</script>

<div class="h-full flex flex-col bg-white" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="flex-1 p-6 space-y-4 overflow-y-auto">
		<!-- Add Question + Save Buttons -->
		<div class="flex items-center gap-3">
			<button
				on:click={addQuestion}
				class="px-4 py-2.5 bg-emerald-600 text-white font-bold rounded-lg hover:bg-emerald-700 transition-colors flex items-center gap-1 text-sm shadow whitespace-nowrap"
			>
				<span class="text-lg leading-none">+</span> {$t('hr.dailyChecklist.addQuestion')}
			</button>
			<button
				on:click={saveQuestions}
				disabled={saving || questions.length === 0}
				class="px-4 py-2.5 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-1.5 text-sm shadow whitespace-nowrap disabled:opacity-40 disabled:cursor-not-allowed"
			>
				{#if saving}
					<svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
				{:else}
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
				{/if}
				{$t('hr.dailyChecklist.save')}
			</button>
			{#if saveMessage === 'success'}
				<span class="text-sm font-bold text-green-600">✅ {$t('hr.dailyChecklist.savedSuccess')}</span>
			{:else if saveMessage === 'error'}
				<span class="text-sm font-bold text-red-600">❌ {$t('hr.dailyChecklist.saveFailed')}</span>
			{/if}
		</div>

		<!-- Questions List -->
		{#if questions.length > 0}
			<div class="space-y-3">
				{#each questions as question, index}
					<div class="border border-slate-200 rounded-lg p-4 bg-slate-50">
						<div class="flex items-center justify-between mb-3">
							<span class="text-sm font-bold text-slate-600">Q{index + 1}</span>
							<div class="flex items-center gap-2">
								<button
									on:click={() => addAnswer(index)}
									class="px-2.5 py-1 bg-blue-500 text-white text-xs font-bold rounded-md hover:bg-blue-600 transition-colors flex items-center gap-1"
								>
									<span class="text-sm leading-none">+</span> Add Answer
								</button>							{#if !question.hasRemarks}
								<button
									on:click={() => { questions[index].hasRemarks = true; questions = questions; }}
									class="px-2.5 py-1 bg-purple-500 text-white text-xs font-bold rounded-md hover:bg-purple-600 transition-colors flex items-center gap-1"
								>
								<span class="text-sm leading-none">+</span> {$t('hr.dailyChecklist.remarks')}
								</button>
							{/if}
							{#if !question.hasOther}
								<button
									on:click={() => { questions[index].hasOther = true; questions = questions; }}
									class="px-2.5 py-1 bg-orange-500 text-white text-xs font-bold rounded-md hover:bg-orange-600 transition-colors flex items-center gap-1"
								>
								<span class="text-sm leading-none">+</span> {$t('hr.dailyChecklist.other')}
								</button>
							{/if}								<button
									on:click={() => removeQuestion(index)}
									class="text-red-400 hover:text-red-600 transition-colors text-lg font-bold leading-none"
								title={$t('hr.dailyChecklist.removeQuestion')}
								>&times;</button>
							</div>
						</div>
						<div class="space-y-2">
							<div class="flex items-center gap-1.5">
								<input
									type="text"
								bind:value={question.name_en}								on:blur={() => spellCheckQuestion(index)}								placeholder={$t('hr.dailyChecklist.enterQuestionEn')}
								dir="ltr"
									class="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400 outline-none"
								/>
								<button
									on:click={() => translateQuestion(index, 'en-to-ar')}
									disabled={translatingQ[`q${index}-en-to-ar`] || !question.name_en.trim()}
							title={$t('hr.dailyChecklist.translateEnToAr')}
									class="p-2 rounded-lg border border-slate-200 hover:bg-amber-50 hover:border-amber-300 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
								>
									{#if translatingQ[`q${index}-en-to-ar`]}
										<svg class="w-4 h-4 text-amber-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
									{:else}
										<svg class="w-4 h-4 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" /></svg>
									{/if}
								</button>
							</div>
							<div class="flex items-center gap-1.5">
								<button
									on:click={() => translateQuestion(index, 'ar-to-en')}
									disabled={translatingQ[`q${index}-ar-to-en`] || !question.name_ar.trim()}
							title={$t('hr.dailyChecklist.translateArToEn')}
									class="p-2 rounded-lg border border-slate-200 hover:bg-amber-50 hover:border-amber-300 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
								>
									{#if translatingQ[`q${index}-ar-to-en`]}
										<svg class="w-4 h-4 text-amber-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
									{:else}
										<svg class="w-4 h-4 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" /></svg>
									{/if}
								</button>
								<input
									type="text"
									bind:value={question.name_ar}
									placeholder={$t('hr.dailyChecklist.enterQuestionAr')}
									dir="rtl"
									class="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400 outline-none"
								/>
							</div>
						</div>

						<!-- Answers -->
						{#if question.answers.length > 0}
							<div class="mt-3 ms-4 space-y-2">
								{#each question.answers as answer, aIndex}
									<div class="flex items-start gap-2 bg-white border border-slate-200 rounded-lg p-3">
										<span class="text-xs font-bold text-blue-500 mt-2 whitespace-nowrap">A{aIndex + 1}</span>
										<div class="flex-1 space-y-1.5">
											<div class="flex items-center gap-1">
												<input
													type="text"
													bind:value={answer.name_en}
													on:blur={() => spellCheckAnswer(index, aIndex)}
											placeholder={$t('hr.dailyChecklist.answerEn')}
											dir="ltr"
													class="flex-1 px-2.5 py-1.5 border border-slate-200 rounded-md text-sm focus:ring-2 focus:ring-blue-200 focus:border-blue-400 outline-none"
												/>
												<button
													on:click={() => translateAnswer(index, aIndex, 'en-to-ar')}
													disabled={translatingQ[`a${index}-${aIndex}-en-to-ar`] || !answer.name_en.trim()}
											title={$t('hr.dailyChecklist.translateEnToAr')}
													class="p-1.5 rounded-md border border-slate-200 hover:bg-amber-50 hover:border-amber-300 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
												>
													{#if translatingQ[`a${index}-${aIndex}-en-to-ar`]}
														<svg class="w-3.5 h-3.5 text-amber-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
													{:else}
														<svg class="w-3.5 h-3.5 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" /></svg>
													{/if}
												</button>
											</div>
											<div class="flex items-center gap-1">
												<button
													on:click={() => translateAnswer(index, aIndex, 'ar-to-en')}
													disabled={translatingQ[`a${index}-${aIndex}-ar-to-en`] || !answer.name_ar.trim()}
											title={$t('hr.dailyChecklist.translateArToEn')}
													class="p-1.5 rounded-md border border-slate-200 hover:bg-amber-50 hover:border-amber-300 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
												>
													{#if translatingQ[`a${index}-${aIndex}-ar-to-en`]}
														<svg class="w-3.5 h-3.5 text-amber-500 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
													{:else}
														<svg class="w-3.5 h-3.5 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" /></svg>
													{/if}
												</button>
												<input
													type="text"
													bind:value={answer.name_ar}
													placeholder="الإجابة بالعربية"
													dir="rtl"
													class="flex-1 px-2.5 py-1.5 border border-slate-200 rounded-md text-sm focus:ring-2 focus:ring-blue-200 focus:border-blue-400 outline-none"
												/>
											</div>
										</div>
										<div class="flex flex-col items-center gap-1">
											<label class="text-[10px] font-bold text-slate-400 uppercase">{$t('hr.dailyChecklist.points')}</label>
											<input
												type="number"
												bind:value={answer.points}
												min="0"
												class="w-16 px-2 py-1.5 border border-slate-200 rounded-md text-sm text-center focus:ring-2 focus:ring-blue-200 focus:border-blue-400 outline-none"
											/>
										</div>
										<button
											on:click={() => removeAnswer(index, aIndex)}
											class="text-red-400 hover:text-red-600 transition-colors text-sm font-bold mt-2"
										title={$t('hr.dailyChecklist.removeAnswer')}
										>&times;</button>
									</div>
								{/each}
							</div>
						{/if}

						<!-- Remarks -->
						{#if question.hasRemarks}
							<div class="mt-3 ms-4 bg-purple-50 border border-purple-200 rounded-lg p-3">
								<div class="flex items-center justify-between mb-2">
									<span class="text-xs font-bold text-purple-600 flex items-center gap-1">
										<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" /></svg>
										{$t('hr.dailyChecklist.remarksLabel')}
									</span>
									<button
										on:click={() => { questions[index].hasRemarks = false; questions = questions; }}
										class="text-red-400 hover:text-red-600 transition-colors text-sm font-bold"
										title={$t('hr.dailyChecklist.removeRemarks')}
									>&times;</button>
								</div>
								<div class="bg-white border border-purple-100 rounded-md p-2 text-xs text-slate-400 italic">
									{$t('hr.dailyChecklist.remarksDescription')}
								</div>
							</div>
						{/if}

						<!-- Other (default answer with reply box) -->
						{#if question.hasOther}
							<div class="mt-3 ms-4 bg-orange-50 border border-orange-200 rounded-lg p-3">
								<div class="flex items-center justify-between mb-2">
									<span class="text-xs font-bold text-orange-600 flex items-center gap-1">
										<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
										{$t('hr.dailyChecklist.otherLabel')}
									</span>
									<div class="flex items-center gap-2">
										<div class="flex items-center gap-1">
											<label class="text-[10px] font-bold text-orange-400 uppercase">{$t('hr.dailyChecklist.points')}</label>
											<input
												type="number"
												bind:value={questions[index].otherPoints}
												min="0"
												class="w-16 px-2 py-1 border border-orange-200 rounded-md text-sm text-center focus:ring-2 focus:ring-orange-200 focus:border-orange-400 outline-none"
											/>
										</div>
										<button
											on:click={() => { questions[index].hasOther = false; questions = questions; }}
											class="text-red-400 hover:text-red-600 transition-colors text-sm font-bold"
											title={$t('hr.dailyChecklist.removeOther')}
										>&times;</button>
									</div>
								</div>
								<div class="bg-white border border-orange-100 rounded-md p-2 text-xs text-slate-400 italic">
									{$t('hr.dailyChecklist.otherDescription')}
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
