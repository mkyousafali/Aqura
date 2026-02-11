<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';
	import { 
		getSaudiArabiaTime, 
		getSaudiDayOfWeek,
		isEmployeeDayOff,
		getShiftStartTime,
		isAfterShiftStart
	} from '$lib/utils/checklistHelpers';

	let currentUserData = null;
	let employeeId: string = '';
	let userBranchId: number | null = null;
	let userAssignedChecklists: any[] = [];
	let loading = true;
	let error = '';
	let isDayOff = false;
	let shiftNotStarted = false;
	let noShiftAssigned = false;
	let shiftStartTime: string = '';
	let checklistQuestions: { [key: string]: any[] } = {};
	let selectedAnswers: { [key: string]: { [key: string]: string } } = {};
	let remarksValues: { [key: string]: { [key: string]: string } } = {};
	let otherValues: { [key: string]: { [key: string]: string } } = {};
	let submittingId: string = '';

	const isArabic = $localeData.code === 'ar';

	// Fetch questions for a checklist
	async function fetchChecklistQuestions(checklistId: string) {
		if (checklistQuestions[checklistId]) {
			return checklistQuestions[checklistId];
		}
		
		try {
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
			const { data, error: submitError } = await supabase
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

			if (submitError) throw submitError;

			// Remove submitted checklist from the list
			userAssignedChecklists = userAssignedChecklists.filter(a => a.id !== assignment.id);
			
			// Clear form
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

	function convertTo12Hour(time24: string): string {
		if (!time24) return '';
		const [hours, minutes] = time24.split(':').map(Number);
		const period = hours >= 12 ? 'PM' : 'AM';
		const hours12 = hours % 12 || 12;
		return `${String(hours12).padStart(2, '0')}:${String(minutes).padStart(2, '0')} ${period}`;
	}

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
				loading = false;
				return;
			}

			// Check if shift is assigned
			shiftStartTime = await getShiftStartTime(employeeId) || '';
			
			if (!shiftStartTime) {
				noShiftAssigned = true;
				userAssignedChecklists = [];
				error = '';
				loading = false;
				return;
			}

			// Check if shift has started
			const shiftStarted = await isAfterShiftStart(employeeId);
			shiftNotStarted = !shiftStarted;

			if (shiftNotStarted) {
				userAssignedChecklists = [];
				error = '';
				loading = false;
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
		currentUserData = $currentUser;
		await loadUserChecklists();
	});
</script>

<div class="mobile-checklist-page" dir={isArabic ? 'rtl' : 'ltr'}>
	<!-- Content -->
	<div class="content">
		{#if loading}
			<div class="loading-state">
				<div class="spinner"></div>
				<p>{isArabic ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else if error}
			<div class="error-state">
				<p>{error}</p>
			</div>
		{:else if isDayOff}
			<div class="empty-state">
				<div class="emoji">🏖️</div>
				<p class="title">{isArabic ? 'يوم إجازة' : 'Day Off Today'}</p>
				<p class="subtitle">{isArabic ? 'لا توجد قوائم مجدولة لهذا اليوم' : 'No checklists scheduled for today'}</p>
			</div>
		{:else if noShiftAssigned}
			<div class="empty-state">
				<div class="emoji">❌</div>
				<p class="title">{isArabic ? 'لا توجد نوبة معينة' : 'No Shift Assigned'}</p>
				<p class="subtitle">{isArabic ? 'يرجى التواصل مع الموارد البشرية' : 'Please contact HR to assign a shift'}</p>
			</div>
		{:else if shiftNotStarted}
			<div class="empty-state">
				<div class="emoji">⏰</div>
				<p class="title">{isArabic ? 'لم تبدأ النوبة بعد' : 'Shift Not Started Yet'}</p>
				<p class="subtitle">{isArabic ? 'تبدأ النوبة في' : 'Shift starts at'}: {convertTo12Hour(shiftStartTime)}</p>
			</div>
		{:else if userAssignedChecklists.length === 0}
			<div class="empty-state">
				<div class="emoji">✓</div>
				<p class="title">{isArabic ? 'تم الانتهاء من كل شيء' : 'All Done!'}</p>
				<p class="subtitle">{isArabic ? 'لا توجد قوائم متبقية لهذا اليوم' : 'No remaining checklists for today'}</p>
			</div>
		{:else}
			<div class="checklists-list">
				{#each userAssignedChecklists as assignment (assignment.id)}
					{#await fetchChecklistQuestions(assignment.checklist_id) then questions}
						<div class="checklist-card">
							<!-- Checklist Header -->
							<div class="card-header">
								<h2>{isArabic 
									? (assignment.hr_checklists?.checklist_name_ar || assignment.hr_checklists?.checklist_name_en)
									: (assignment.hr_checklists?.checklist_name_en || assignment.hr_checklists?.checklist_name_ar)
								}</h2>
								<span class="badge {assignment.frequency_type === 'daily' ? 'daily' : 'weekly'}">
									{assignment.frequency_type === 'daily' ? '📅 Daily' : `📅 Weekly - ${assignment.day_of_week}`}
								</span>
							</div>

							<!-- Questions List -->
							{#if questions && questions.length > 0}
								<div class="questions-container">
									{#each questions as question, questionIndex (question.id)}
										<div class="question-item">
											<div class="question-number">{questionIndex + 1}</div>
											<div class="question-content">
												<!-- Question Text -->
												<p class="question-text">
													{isArabic ? question.question_ar : question.question_en}
												</p>

												<!-- Answer Options -->
												<div class="answer-options">
													{#if question.answer_1_en || question.answer_1_ar}
														<label class="answer-option">
															<input 
																type="radio" 
																name="question_{assignment.id}_{question.id}" 
																value="1"
																checked={selectedAnswers[assignment.id]?.[question.id] === '1'}
																on:change={() => {
																	if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																	selectedAnswers[assignment.id][question.id] = '1';
																}}
															/>
															<span>{isArabic ? question.answer_1_ar : question.answer_1_en}</span>
														</label>
													{/if}
													{#if question.answer_2_en || question.answer_2_ar}
														<label class="answer-option">
															<input 
																type="radio" 
																name="question_{assignment.id}_{question.id}" 
																value="2"
																checked={selectedAnswers[assignment.id]?.[question.id] === '2'}
																on:change={() => {
																	if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																	selectedAnswers[assignment.id][question.id] = '2';
																}}
															/>
															<span>{isArabic ? question.answer_2_ar : question.answer_2_en}</span>
														</label>
													{/if}
													{#if question.answer_3_en || question.answer_3_ar}
														<label class="answer-option">
															<input 
																type="radio" 
																name="question_{assignment.id}_{question.id}" 
																value="3"
																checked={selectedAnswers[assignment.id]?.[question.id] === '3'}
																on:change={() => {
																	if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																	selectedAnswers[assignment.id][question.id] = '3';
																}}
															/>
															<span>{isArabic ? question.answer_3_ar : question.answer_3_en}</span>
														</label>
													{/if}
													{#if question.answer_4_en || question.answer_4_ar}
														<label class="answer-option">
															<input 
																type="radio" 
																name="question_{assignment.id}_{question.id}" 
																value="4"
																checked={selectedAnswers[assignment.id]?.[question.id] === '4'}
																on:change={() => {
																	if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																	selectedAnswers[assignment.id][question.id] = '4';
																}}
															/>
															<span>{isArabic ? question.answer_4_ar : question.answer_4_en}</span>
														</label>
													{/if}
													{#if question.answer_5_en || question.answer_5_ar}
														<label class="answer-option">
															<input 
																type="radio" 
																name="question_{assignment.id}_{question.id}" 
																value="5"
																checked={selectedAnswers[assignment.id]?.[question.id] === '5'}
																on:change={() => {
																	if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																	selectedAnswers[assignment.id][question.id] = '5';
																}}
															/>
															<span>{isArabic ? question.answer_5_ar : question.answer_5_en}</span>
														</label>
													{/if}
													{#if question.answer_6_en || question.answer_6_ar}
														<label class="answer-option">
															<input 
																type="radio" 
																name="question_{assignment.id}_{question.id}" 
																value="6"
																checked={selectedAnswers[assignment.id]?.[question.id] === '6'}
																on:change={() => {
																	if (!selectedAnswers[assignment.id]) selectedAnswers[assignment.id] = {};
																	selectedAnswers[assignment.id][question.id] = '6';
																}}
															/>
															<span>{isArabic ? question.answer_6_ar : question.answer_6_en}</span>
														</label>
													{/if}
												</div>

												<!-- Remarks Field -->
												{#if question.has_remarks}
													<textarea 
														placeholder={isArabic ? 'ملاحظات...' : 'Remarks...'}
														value={remarksValues[assignment.id]?.[question.id] || ''}
														on:change={(e) => {
															if (!remarksValues[assignment.id]) remarksValues[assignment.id] = {};
															remarksValues[assignment.id][question.id] = e.target.value;
														}}
														class="remarks-field"
													></textarea>
												{/if}

												<!-- Other Field -->
												{#if question.has_other}
													<input 
														type="text" 
														placeholder={isArabic ? 'أخرى (يرجى التوضيح)...' : 'Other (please specify)...'}
														value={otherValues[assignment.id]?.[question.id] || ''}
														on:change={(e) => {
															if (!otherValues[assignment.id]) otherValues[assignment.id] = {};
															otherValues[assignment.id][question.id] = e.target.value;
														}}
														class="other-field"
													/>
												{/if}
											</div>
										</div>
									{/each}
								</div>
							{:else}
								<p class="no-questions">{isArabic ? 'لا توجد أسئلة لهذه القائمة' : 'No questions for this checklist'}</p>
							{/if}

							<!-- Submit Button -->
							<button
								class="submit-btn {submittingId === assignment.id ? 'submitting' : ''}"
								disabled={submittingId === assignment.id || !areAllQuestionsAnswered(assignment.id, questions)}
								on:click={() => submitChecklist(assignment)}
								title={!areAllQuestionsAnswered(assignment.id, questions) ? (isArabic ? 'يرجى الإجابة على جميع الأسئلة' : 'Please answer all questions') : ''}
							>
								{#if submittingId === assignment.id}
									<span class="spinner-small"></span>
									{isArabic ? 'جاري الحفظ...' : 'Submitting...'}
								{:else}
									✓ {isArabic ? 'تأكيد' : 'Submit'}
								{/if}
							</button>
						</div>
					{/await}
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.mobile-checklist-page {
		min-height: 100vh;
		background: #f8fafc;
		display: flex;
		flex-direction: column;
	}

	.content {
		flex: 1;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		padding: 1rem;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		text-align: center;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top-color: #f97316;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	.spinner-small {
		display: inline-block;
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-right: 0.5rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.error-state {
		background: #fee2e2;
		border: 1px solid #fca5a5;
		border-radius: 8px;
		padding: 1rem;
		color: #991b1b;
		margin: 1rem;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 1rem;
		text-align: center;
	}

	.emoji {
		font-size: 3rem;
		margin-bottom: 1rem;
	}

	.title {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 0.5rem 0;
	}

	.subtitle {
		font-size: 0.875rem;
		color: #6b7280;
		margin: 0;
	}

	.checklists-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding-bottom: 1rem;
	}

	.checklist-card {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0,0,0,0.1);
		border: 1px solid #e5e7eb;
	}

	.card-header {
		background: #f3f4f6;
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1rem;
	}

	.card-header h2 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.badge {
		font-size: 0.75rem;
		padding: 0.25rem 0.75rem;
		border-radius: 6px;
		background: #dbeafe;
		color: #1e40af;
		white-space: nowrap;
	}

	.badge.daily {
		background: #dcfce7;
		color: #166534;
	}

	.questions-container {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.question-item {
		display: flex;
		gap: 1rem;
	}

	.question-number {
		min-width: 28px;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		background: #f97316;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 0.875rem;
		flex-shrink: 0;
	}

	.question-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.question-text {
		margin: 0;
		font-weight: 600;
		color: #1f2937;
		font-size: 0.95rem;
		line-height: 1.4;
	}

	.answer-options {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.answer-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem;
		border-radius: 6px;
		cursor: pointer;
		transition: background 0.2s;
		user-select: none;
	}

	.answer-option:hover {
		background: #f9fafb;
	}

	.answer-option input[type="radio"] {
		cursor: pointer;
		accent-color: #f97316;
	}

	.answer-option span {
		font-size: 0.9rem;
		color: #4b5563;
	}

	.remarks-field,
	.other-field {
		width: 100%;
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.9rem;
		font-family: inherit;
		resize: vertical;
	}

	.remarks-field::placeholder,
	.other-field::placeholder {
		color: #9ca3af;
	}

	.remarks-field:focus,
	.other-field:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
	}

	.remarks-field {
		min-height: 60px;
	}

	.no-questions {
		text-align: center;
		color: #6b7280;
		margin: 1rem 0;
	}

	.submit-btn {
		width: calc(100% - 2rem);
		margin: 0 1rem 1rem 1rem;
		padding: 0.875rem;
		background: #f97316;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.submit-btn:active:not(:disabled) {
		background: #ea580c;
		transform: scale(0.98);
	}

	.submit-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.submit-btn.submitting {
		background: #ea580c;
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

	@media (max-width: 640px) {
		.header h1 {
			font-size: 1.25rem;
		}

		.card-header {
			flex-direction: column;
			align-items: flex-start;
		}

		.badge {
			align-self: flex-start;
		}
	}
</style>
