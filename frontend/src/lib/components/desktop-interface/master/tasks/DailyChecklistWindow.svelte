<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, locale } from '$lib/i18n';
	import { 
		getSaudiArabiaTime, 
		getSaudiDayOfWeek,
		getTodaysChecklistsWithDayOff,
		isEmployeeDayOff,
		getShiftStartTime,
		isAfterShiftStart
	} from '$lib/utils/checklistHelpers';

	export let windowId: string;

	let userAssignedChecklists: any[] = [];
	let employeeId: string = '';
	let userBranchId: number | null = null;
	let loading = true;
	let error = '';
	let isDayOff = false;
	let shiftNotStarted = false;
	let noShiftAssigned = false;
	let shiftStartTime: string = '';
	let checklistQuestions: { [key: string]: any[] } = {}; // Store questions for each checklist
	let selectedAnswers: { [key: string]: { [key: string]: string } } = {}; // Store answers per assignment
	let remarksValues: { [key: string]: { [key: string]: string } } = {}; // Store remarks per assignment
	let otherValues: { [key: string]: { [key: string]: string } } = {}; // Store other values per assignment
	let submittingId: string = ''; // Track which checklist is being submitted

	// Fetch questions for a checklist
	async function fetchChecklistQuestions(checklistId: string) {
		if (checklistQuestions[checklistId]) {
			return checklistQuestions[checklistId];
		}
		
		try {
			// First, get the checklist with its question_ids array
			const { data: checklistData, error: checklistErr } = await supabase
				.from('hr_checklists')
				.select('question_ids')
				.eq('id', checklistId)
				.single();

			if (checklistErr) throw checklistErr;
			
			const questionIds = checklistData?.question_ids || [];
			
			if (!questionIds || questionIds.length === 0) {
				checklistQuestions[checklistId] = [];
				return [];
			}

			// Then fetch those specific questions
			const { data: questions, error: questionsErr } = await supabase
				.from('hr_checklist_questions')
				.select('*')
				.in('id', questionIds);

			if (questionsErr) throw questionsErr;
			
			checklistQuestions[checklistId] = questions || [];
			return questions || [];
		} catch (err) {
			console.error('Error fetching questions:', err);
			return [];
		}
	}

	function areAllQuestionsAnswered(assignmentId: string, questions: any[]): boolean {
		if (!questions || questions.length === 0) return false;
		for (const question of questions) {
			if (!selectedAnswers[assignmentId]?.[question.id]) {
				return false;
			}
		}
		return true;
	}

	// Submit checklist
	async function submitChecklist(assignment: any) {
		submittingId = assignment.id;
		
		try {
			const questions = checklistQuestions[assignment.checklist_id] || [];
			const answers: any[] = [];
			let totalPoints = 0;
			let maxPoints = 0;

			// Build answers array
			for (const question of questions) {
				const selectedAnswer = selectedAnswers[assignment.id]?.[question.id];
				
				if (!selectedAnswer) {
					alert('Please answer all questions before submitting');
					submittingId = '';
					return;
				}

				const answerKey = `answer_${selectedAnswer}_en`;
				const answerPointsKey = `answer_${selectedAnswer}_points`;
				const answerText = question[answerKey];
				const points = question[answerPointsKey] || 0;

				answers.push({
					question_id: question.id,
					selected_answer: selectedAnswer,
					points: points,
					remarks: remarksValues[assignment.id]?.[question.id] || '',
					other_response: otherValues[assignment.id]?.[question.id] || ''
				});

				totalPoints += points;
				maxPoints += (Math.max(
					question.answer_1_points || 0,
					question.answer_2_points || 0,
					question.answer_3_points || 0,
					question.answer_4_points || 0,
					question.answer_5_points || 0,
					question.answer_6_points || 0
				));
			}

			// Determine submission type based on frequency
			const submissionTypeEn = assignment.frequency_type === 'daily' ? 'Daily' : 'Weekly';
			const submissionTypeAr = assignment.frequency_type === 'daily' ? 'يومي' : 'أسبوعي';

			// Save to hr_checklist_operations
			const { data, error } = await supabase
				.from('hr_checklist_operations')
				.insert({
					user_id: $currentUser.id,
					checklist_id: assignment.checklist_id,
					employee_id: employeeId,
					answers: answers,
					total_points: totalPoints,
					max_points: maxPoints,
				branch_id: userBranchId,
					submission_type_en: submissionTypeEn,
					submission_type_ar: submissionTypeAr
				});

			if (error) throw error;

			// Remove submitted checklist from the list
			userAssignedChecklists = userAssignedChecklists.filter(a => a.id !== assignment.id);
			
			// Clear form and show success
			selectedAnswers[assignment.id] = {};
			remarksValues[assignment.id] = {};
			otherValues[assignment.id] = {};
			
			alert('✓ Checklist submitted successfully!');
			submittingId = '';
		} catch (err: any) {
			console.error('Error submitting checklist:', err);
			alert('Error submitting checklist: ' + err.message);
			submittingId = '';
		}
	}

	// Convert 24-hour time format (HH:MM) to 12-hour format (HH:MM AM/PM)
	function convertTo12Hour(time24: string): string {
		if (!time24) return '';
		const [hours, minutes] = time24.split(':').map(Number);
		const period = hours >= 12 ? 'PM' : 'AM';
		const hours12 = hours % 12 || 12;
		return `${String(hours12).padStart(2, '0')}:${String(minutes).padStart(2, '0')} ${period}`;
	}

	// Load assigned checklists for current user (excluding day offs)
	async function loadUserChecklists() {
		if (!$currentUser?.id) {
			error = 'User not authenticated';
			loading = false;
			return;
		}

		try {
			// Get employee ID and branch for the current user
			const { data: employeeData, error: empError } = await supabase
				.from('hr_employee_master')
				.select('id, current_branch_id')
				.eq('user_id', $currentUser.id)
				.single();

			if (empError || !employeeData) {
				throw new Error('Employee record not found');
			}

			employeeId = employeeData.id;
			userBranchId = employeeData.current_branch_id;

			// Check if employee has day off today
			isDayOff = await isEmployeeDayOff(employeeId);

			if (isDayOff) {
				userAssignedChecklists = [];
				error = '';
				return;
			}

			// Check if shift is assigned
			shiftStartTime = await getShiftStartTime(employeeId) || '';
			
			if (!shiftStartTime) {
				noShiftAssigned = true;
				userAssignedChecklists = [];
				error = '';
				return;
			}

			// Check if shift has started
			const shiftStarted = await isAfterShiftStart(employeeId);
			shiftNotStarted = !shiftStarted;

			if (shiftNotStarted) {
				userAssignedChecklists = [];
				error = '';
				return;
			}

			// Get today's checklists
			const { data: assignments, error: assignmentError } = await supabase
				.from('employee_checklist_assignments')
				.select(`
					*,
					hr_checklists:checklist_id (
						id,
						checklist_name_en,
						checklist_name_ar
					)
				`)
				.eq('assigned_to_user_id', $currentUser.id)
				.is('deleted_at', null)
				.eq('is_active', true);

			if (assignmentError) throw assignmentError;

			// Get today's submissions for this employee to filter out already submitted checklists
			const today = new Date().toISOString().split('T')[0];
			const { data: submissions, error: submissionsError } = await supabase
				.from('hr_checklist_operations')
				.select('checklist_id')
				.eq('employee_id', employeeId)
				.eq('operation_date', today);

			if (submissionsError) throw submissionsError;

			const submittedChecklistIds = new Set((submissions || []).map(s => s.checklist_id));

			// Filter for today's checklists based on Saudi Arabia timezone AND exclude already submitted ones
			const saToday = getSaudiDayOfWeek();
			userAssignedChecklists = (assignments || []).filter(a => {
				// Skip if already submitted today
				if (submittedChecklistIds.has(a.checklist_id)) {
					return false;
				}
				// Allow daily checklists
				if (a.frequency_type === 'daily') {
					return true;
				}
				// Allow weekly checklists for today
				if (a.frequency_type === 'weekly' && a.day_of_week === saToday) {
					return true;
				}
				return false;
			});

			error = '';
		} catch (err: any) {
			error = err.message || 'Failed to load checklists';
			console.error('Error loading checklists:', err);
		} finally {
			loading = false;
		}
	}

	onMount(async () => {
		await loadUserChecklists();
		// Refresh every hour to check for new assignments and day offs
		const interval = setInterval(loadUserChecklists, 60 * 60 * 1000);
		return () => clearInterval(interval);
	});
</script>

<div class="daily-checklist-window h-full flex flex-col">
	<!-- Content -->
	<div class="flex-1 overflow-y-auto p-6">
		{#if loading}
			<div class="flex items-center justify-center py-12">
				<svg class="w-6 h-6 text-orange-500 animate-spin" fill="none" viewBox="0 0 24 24">
					<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
					<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
				</svg>
			</div>
		{:else if error}
			<div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
				<p class="font-bold">Error</p>
				<p>{error}</p>
			</div>
		{:else if isDayOff}
			<div class="text-center py-12">
				<div class="text-6xl mb-4">🏖️</div>
				<p class="text-lg font-bold text-slate-700">Day Off Today</p>
				<p class="text-sm text-slate-500 mt-2">No checklists scheduled for today</p>
			</div>
		{:else if noShiftAssigned}
			<div class="text-center py-12">
				<div class="text-6xl mb-4">❌</div>
				<p class="text-lg font-bold text-slate-700">No Shift Assigned</p>
				<p class="text-sm text-slate-500 mt-2">Please contact HR to assign a shift first</p>
			</div>
		{:else if shiftNotStarted}
			<div class="text-center py-12">
				<div class="text-6xl mb-4">⏰</div>
				<p class="text-lg font-bold text-slate-700">Shift Not Started Yet</p>
				<p class="text-sm text-slate-500 mt-2">Shift starts at: <span class="font-semibold text-slate-700">{convertTo12Hour(shiftStartTime)}</span></p>
				<p class="text-xs text-slate-400 mt-4">Current time (Saudi Arabia): {new Date().toLocaleString('en-US', { timeZone: 'Asia/Riyadh' })}</p>
			</div>
		{:else if userAssignedChecklists.length === 0}
			<div class="text-center py-12 text-slate-400">
				<p>No checklists assigned for today</p>
				<p class="text-sm mt-2">Today is: {getSaudiDayOfWeek()}</p>
			</div>
		{:else}
			<div class="mb-6 bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
				<p class="text-sm text-blue-700">
					<span class="font-bold">📋 Shift Start Time:</span> {convertTo12Hour(shiftStartTime)}
				</p>
				<p class="text-xs text-blue-600 mt-1">
					Today: {getSaudiDayOfWeek()}
				</p>
			</div>
			<div class="space-y-6">
				{#each userAssignedChecklists as assignment (assignment.id)}
					{#await fetchChecklistQuestions(assignment.checklist_id) then questions}
						<div class="bg-white border-2 border-orange-200 rounded-lg p-6 hover:shadow-md transition-shadow">
							<!-- Checklist Header -->
							<div class="mb-6 pb-4 border-b-2 border-orange-100">
								<h3 class="font-bold text-lg text-slate-800" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
									{$locale === 'ar' 
										? (assignment.hr_checklists?.checklist_name_ar || assignment.hr_checklists?.checklist_name_en)
										: (assignment.hr_checklists?.checklist_name_en || assignment.hr_checklists?.checklist_name_ar)
									}
								</h3>
								<p class="text-xs text-slate-500 mt-1">ID: {assignment.checklist_id}</p>
								<div class="text-xs text-slate-600 mt-2">
									<p>
										<span class="font-semibold">Frequency:</span> 
										{assignment.frequency_type === 'daily' ? '📅 Daily' : `📅 Weekly - ${assignment.day_of_week}`}
									</p>
								</div>
							</div>

							<!-- Questions and Answers -->
							{#if questions && questions.length > 0}
								<div class="space-y-4">
									{#each questions as question (question.id)}
										<div class="bg-slate-50 p-4 rounded-lg border border-slate-200">
											<p class="font-semibold text-slate-700 mb-3" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
												{$locale === 'ar' ? question.question_ar : question.question_en}
											</p>
											
											<!-- Answer Options -->
											<div class="space-y-2">
												{#if question.answer_1_en || question.answer_1_ar}
													<label class="flex items-center gap-3 p-2 hover:bg-white rounded cursor-pointer">
														<input 
															type="radio" 
															name="question_{assignment.id}_{question.id}" 
															value="1"
															checked={selectedAnswers[assignment.id]?.[question.id] === '1'}
															on:change={() => {
																if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																selectedAnswers[assignment.id][question.id] = '1';
															}}
															class="w-4 h-4 text-orange-500"
														/>
														<span class="text-sm text-slate-600">
															{$locale === 'ar' ? question.answer_1_ar : question.answer_1_en}
														</span>
													</label>
												{/if}
												{#if question.answer_2_en || question.answer_2_ar}
													<label class="flex items-center gap-3 p-2 hover:bg-white rounded cursor-pointer">
														<input 
															type="radio" 
															name="question_{assignment.id}_{question.id}" 
															value="2"
															checked={selectedAnswers[assignment.id]?.[question.id] === '2'}
															on:change={() => {
																if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																selectedAnswers[assignment.id][question.id] = '2';
															}}
															class="w-4 h-4 text-orange-500"
														/>
														<span class="text-sm text-slate-600">
															{$locale === 'ar' ? question.answer_2_ar : question.answer_2_en}
														</span>
													</label>
												{/if}
												{#if question.answer_3_en || question.answer_3_ar}
													<label class="flex items-center gap-3 p-2 hover:bg-white rounded cursor-pointer">
														<input 
															type="radio" 
															name="question_{assignment.id}_{question.id}" 
															value="3"
															checked={selectedAnswers[assignment.id]?.[question.id] === '3'}
															on:change={() => {
																if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																selectedAnswers[assignment.id][question.id] = '3';
															}}
															class="w-4 h-4 text-orange-500"
														/>
														<span class="text-sm text-slate-600">
															{$locale === 'ar' ? question.answer_3_ar : question.answer_3_en}
														</span>
													</label>
												{/if}
												{#if question.answer_4_en || question.answer_4_ar}
													<label class="flex items-center gap-3 p-2 hover:bg-white rounded cursor-pointer">
														<input 
															type="radio" 
															name="question_{assignment.id}_{question.id}" 
															value="4"
															checked={selectedAnswers[assignment.id]?.[question.id] === '4'}
															on:change={() => {
																if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																selectedAnswers[assignment.id][question.id] = '4';
															}}
															class="w-4 h-4 text-orange-500"
														/>
														<span class="text-sm text-slate-600">
															{$locale === 'ar' ? question.answer_4_ar : question.answer_4_en}
														</span>
													</label>
												{/if}
												{#if question.answer_5_en || question.answer_5_ar}
													<label class="flex items-center gap-3 p-2 hover:bg-white rounded cursor-pointer">
														<input 
															type="radio" 
															name="question_{assignment.id}_{question.id}" 
															value="5"
															checked={selectedAnswers[assignment.id]?.[question.id] === '5'}
															on:change={() => {
																if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																selectedAnswers[assignment.id][question.id] = '5';
															}}
															class="w-4 h-4 text-orange-500"
														/>
														<span class="text-sm text-slate-600">
															{$locale === 'ar' ? question.answer_5_ar : question.answer_5_en}
														</span>
													</label>
												{/if}
												{#if question.answer_6_en || question.answer_6_ar}
													<label class="flex items-center gap-3 p-2 hover:bg-white rounded cursor-pointer">
														<input 
															type="radio" 
															name="question_{assignment.id}_{question.id}" 
															value="6"
															checked={selectedAnswers[assignment.id]?.[question.id] === '6'}
															on:change={() => {
																if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																selectedAnswers[assignment.id][question.id] = '6';
															}}
															class="w-4 h-4 text-orange-500"
														/>
														<span class="text-sm text-slate-600">
															{$locale === 'ar' ? question.answer_6_ar : question.answer_6_en}
														</span>
													</label>
												{/if}
											</div>

											<!-- Remarks Field -->
											{#if question.has_remarks}
												<textarea 
													placeholder="Enter remarks..."
													value={remarksValues[assignment.id]?.[question.id] || ''}
													on:change={(e) => {
														if (!remarksValues[assignment.id]) remarksValues[assignment.id] = {};
														remarksValues[assignment.id][question.id] = e.target.value;
													}}
													class="mt-3 w-full p-2 border border-slate-300 rounded text-sm focus:outline-none focus:border-orange-500"
													rows="2"
												></textarea>
											{/if}

											<!-- Other Field -->
											{#if question.has_other}
												<input 
													type="text" 
													placeholder="Other (please specify)..."
													value={otherValues[assignment.id]?.[question.id] || ''}
													on:change={(e) => {
														if (!otherValues[assignment.id]) otherValues[assignment.id] = {};
														otherValues[assignment.id][question.id] = e.target.value;
													}}
													class="mt-3 w-full p-2 border border-slate-300 rounded text-sm focus:outline-none focus:border-orange-500"
												/>
											{/if}
										</div>
									{/each}
								</div>
							{:else}
								<p class="text-slate-500 text-sm">No questions for this checklist</p>
							{/if}

							<!-- Save Button -->
							<div class="mt-6 flex gap-3 justify-end">
								<button
									disabled={submittingId === assignment.id || !areAllQuestionsAnswered(assignment.id, questions)}
									class="px-4 py-2 bg-orange-500 hover:bg-orange-600 disabled:bg-slate-400 disabled:cursor-not-allowed text-white rounded-lg font-bold transition-colors text-sm"
									on:click={() => submitChecklist(assignment)}
									title={!areAllQuestionsAnswered(assignment.id, questions) ? 'Please answer all questions' : ''}
								>
									{#if submittingId === assignment.id}
										⏳ Submitting...
									{:else}
										✓ Submit
									{/if}
								</button>
							</div>
						</div>
					{/await}
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.daily-checklist-window {
		background: #f8fafc;
		height: 100%;
		display: flex;
		flex-direction: column;
	}

	/* Square checkbox with visible border */
	:global(input[type="radio"]) {
		appearance: none;
		-webkit-appearance: none;
		-moz-appearance: none;
		width: 1.25rem;
		height: 1.25rem;
		border: 2px solid #f97316;
		border-radius: 2px;
		cursor: pointer;
		accent-color: #f97316;
		background-color: white;
		transition: all 0.2s;
	}

	:global(input[type="radio"]:hover) {
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
	}

	:global(input[type="radio"]:checked) {
		background-color: #f97316;
		border-color: #f97316;
		box-shadow: inset 0 0 0 2px white;
	}

	:global(input[type="radio"]:focus) {
		outline: 2px solid #f97316;
		outline-offset: 2px;
	}
</style>
