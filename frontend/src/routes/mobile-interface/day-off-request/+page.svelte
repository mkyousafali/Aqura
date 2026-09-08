<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, currentLocale } from '$lib/i18n';
	
	interface DayOffReason {
		id: string;
		reason_en: string;
		reason_ar: string;
		is_deductible: boolean;
		is_document_mandatory: boolean;
	}

	let loading = false;
	let saving = false;
	let dayOffReasons: DayOffReason[] = [];
	let selectedReason: DayOffReason | null = null;
	let startDate: string = new Date().toISOString().split('T')[0];
	let endDate: string = new Date().toISOString().split('T')[0];
	let description: string = '';
	let documentUploadSection: HTMLElement;
	let submitSection: HTMLElement;
	let documentFile: File | null = null;
	let documentProgress = 0;
	let isUploadingDocument = false;
	let userEmployeeId: string | null = null;
	let userEmployeeName: string = '';
	let userEmployeeNameAr: string = '';
	let showAlertModal = false;
	let showSuccessModal = false;
	let alertMessage = '';
	let alertTitle = '';
	let errorMessage = '';
	let successMessage = '';

	// Calendar date picker state
	let showDatePicker = false;
	let datePickerTarget: 'start' | 'end' = 'start';
	let pickerYear: number = new Date().getFullYear();
	let pickerMonth: number = new Date().getMonth(); // 0-based

	function openDatePicker(target: 'start' | 'end') {
		datePickerTarget = target;
		const dateStr = target === 'start' ? startDate : endDate;
		const d = new Date(dateStr);
		pickerYear = d.getFullYear();
		pickerMonth = d.getMonth();
		showDatePicker = true;
	}

	function closeDatePicker() {
		showDatePicker = false;
	}

	function selectCalendarDay(day: number) {
		const m = String(pickerMonth + 1).padStart(2, '0');
		const d = String(day).padStart(2, '0');
		const dateVal = `${pickerYear}-${m}-${d}`;
		if (datePickerTarget === 'start') {
			startDate = dateVal;
		} else {
			endDate = dateVal;
		}
		showDatePicker = false;
	}

	function prevMonth() {
		if (pickerMonth === 0) {
			pickerMonth = 11;
			pickerYear--;
		} else {
			pickerMonth--;
		}
	}

	function nextMonth() {
		if (pickerMonth === 11) {
			pickerMonth = 0;
			pickerYear++;
		} else {
			pickerMonth++;
		}
	}

	function getDaysInMonth(year: number, month: number): number {
		return new Date(year, month + 1, 0).getDate();
	}

	function getFirstDayOfMonth(year: number, month: number): number {
		return new Date(year, month, 1).getDay();
	}

	function formatDisplayDate(dateStr: string): string {
		if (!dateStr) return '';
		const d = new Date(dateStr);
		const day = d.getDate();
		const monthNames = $currentLocale === 'ar'
			? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
			: ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
		return `${day} ${monthNames[d.getMonth()]} ${d.getFullYear()}`;
	}

	function getMonthName(month: number): string {
		const names = $currentLocale === 'ar'
			? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
			: ['January','February','March','April','May','June','July','August','September','October','November','December'];
		return names[month];
	}

	$: calendarDays = (() => {
		const daysInMonth = getDaysInMonth(pickerYear, pickerMonth);
		const firstDay = getFirstDayOfMonth(pickerYear, pickerMonth);
		const days: (number | null)[] = [];
		for (let i = 0; i < firstDay; i++) days.push(null);
		for (let i = 1; i <= daysInMonth; i++) days.push(i);
		return days;
	})();

	$: selectedPickerDate = datePickerTarget === 'start' ? startDate : endDate;

	// Initialize component
	onMount(async () => {

		// Load current user's employee ID
		const currentUserData = get(currentUser);
		if (currentUserData?.id) {
			try {
				// Find employee record with this user ID
				const { data: employees, error } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.eq('user_id', currentUserData.id)
					.single();

				if (!error && employees) {
					userEmployeeId = employees.id;
					userEmployeeName = employees.name_en || employees.id;
					userEmployeeNameAr = employees.name_ar || employees.name_en || employees.id;
					console.log('✅ Found employee for logged-in user:', userEmployeeId, userEmployeeName, userEmployeeNameAr);
				} else {
					errorMessage = 'Could not find your employee record. Please contact admin.';
					console.error('❌ Error finding employee:', error);
				}
			} catch (err) {
				errorMessage = 'Failed to load employee information';
				console.error('Error:', err);
			}
		}

		// Load day off reasons
		await loadDayOffReasons();
	});

	async function loadDayOffReasons() {
		loading = true;
		try {
			const { data, error } = await supabase
				.from('day_off_reasons')
				.select('*')
				.order('id');

			if (!error && data) {
				dayOffReasons = data;
				console.log('✅ Loaded', dayOffReasons.length, 'day-off reasons');
				console.log('📋 Reasons:', dayOffReasons);
				// Log document mandatory status for each reason
				dayOffReasons.forEach(reason => {
					console.log(`  - ${reason.reason_en}: mandatory=${reason.is_document_mandatory}`);
				});
			} else {
				errorMessage = 'Failed to load day-off reasons';
				console.error('Error loading reasons:', error);
			}
		} catch (err) {
			errorMessage = 'Error loading reasons';
			console.error(err);
		} finally {
			loading = false;
		}
	}

	function handleDocumentSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		documentFile = target.files?.[0] || null;
		errorMessage = '';
	}

	function scrollToSubmit() {
		// After a reason is chosen, automatically scroll down to the bottom (submit section)
		setTimeout(() => {
			if (submitSection) {
				submitSection.scrollIntoView({ behavior: 'smooth', block: 'end' });
			} else if (documentUploadSection) {
				documentUploadSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
			}
		}, 150);
	}

	function showAlert(title: string, message: string) {
		alertTitle = title;
		alertMessage = message;
		showAlertModal = true;
	}

	function closeAlert() {
		showAlertModal = false;
	}

	function closeSuccessModal() {
		showSuccessModal = false;
		successMessage = '';
	}

	async function uploadDocument() {
		if (!documentFile || !userEmployeeId) {
			return null;
		}

		isUploadingDocument = true;
		documentProgress = 0;

		try {
			const fileExt = documentFile.name.split('.').pop();
			const fileName = `day_off_docs/${userEmployeeId}/${Date.now()}.${fileExt}`;

			const { data, error: uploadError } = await supabase.storage
				.from('employee-documents')
				.upload(fileName, documentFile);

			if (uploadError) throw uploadError;

			const { data: publicUrlData } = supabase.storage
				.from('employee-documents')
				.getPublicUrl(fileName);

			documentProgress = 100;
			return publicUrlData.publicUrl;
		} catch (err) {
			console.error('Error uploading document:', err);
			throw err;
		} finally {
			isUploadingDocument = false;
		}
	}

	async function submitDayOffRequest() {
		errorMessage = '';
		successMessage = '';

		// Validation
		if (!userEmployeeId) {
			showAlert('error', 'errorEmployeeNotFound');
			return;
		}

		if (!selectedReason) {
			showAlert('requiredFields', 'selectReason');
			return;
		}

		if (!startDate || !endDate) {
			showAlert('requiredFields', 'selectDates');
			return;
		}

		if (startDate > endDate) {
			showAlert('invalidDateRange', 'startBeforeEnd');
			return;
		}

		if (selectedReason.is_document_mandatory && !documentFile) {
			showAlert('documentRequiredError', 'uploadRelatedDocument');
			scrollToSubmit();
			return;
		}

		saving = true;

		try {
			let documentUrl = null;

			// Upload document if provided
			if (documentFile) {
				documentUrl = await uploadDocument();
			}

			const currentUserData = get(currentUser);
			if (!currentUserData?.id) {
				throw new Error('No user logged in');
			}

			// Generate array of dates in range
			const dateArray: string[] = [];
			let currentDate = new Date(startDate);
			const endDateObj = new Date(endDate);

			while (currentDate <= endDateObj) {
				const dateStr = currentDate.toISOString().split('T')[0];
				dateArray.push(dateStr);
				currentDate.setDate(currentDate.getDate() + 1);
			}

			console.log(`Creating ${dateArray.length} day-off entries from ${startDate} to ${endDate}`);

			// Create day off records for each date
			const dayOffRecords = dateArray.map(dateStr => {
				const dateStrFormatted = dateStr.replace(/-/g, ''); // 20260118
				const dayOffId = `${userEmployeeId}_${dateStrFormatted}`;

				return {
					id: dayOffId,
					employee_id: userEmployeeId,
					day_off_date: dateStr,
					day_off_reason_id: selectedReason!.id,
					approval_status: 'pending',
					approval_requested_by: currentUserData.id,
					approval_requested_at: new Date().toISOString(),
					document_url: documentUrl,
					description: description || null,
					is_deductible_on_salary: selectedReason!.is_deductible
				};
			});

			// Insert all records
			const { data: dayOffData, error: dayOffError } = await supabase
				.from('day_off')
				.insert(dayOffRecords)
				.select();

			if (dayOffError) throw dayOffError;

			console.log(`✅ Created ${dayOffData?.length || 0} day-off records`);

			// Send notifications to approvers
			try {
				const { data: approvers, error: approvingError } = await supabase
					.from('approval_permissions')
					.select('user_id')
					.eq('can_approve_leave_requests', true)
					.eq('is_active', true);

				if (!approvingError && approvers && approvers.length > 0) {
					const approverUserIds = approvers.map((a: any) => a.user_id);

					try {
						const { error: notifError } = await supabase
							.from('notifications')
							.insert({
								type: 'approval_request',
								title: 'طلب موافقة على إجازة | Leave Request Approval',
								message: `طلب إجازة للموظف ${userEmployeeNameAr} (${userEmployeeId}) من ${startDate} إلى ${endDate} (${dateArray.length} أيام) يتطلب موافقة\n\nLeave request for ${userEmployeeName} (${userEmployeeId}) from ${startDate} to ${endDate} (${dateArray.length} days) requires approval`,
								priority: 'high',
								target_type: 'specific_users',
								target_users: approverUserIds,
								created_by: currentUserData.username || currentUserData.id,
								created_by_name: currentUserData.username || 'Unknown',
								created_by_role: currentUserData.role || 'User',
								status: 'published'
							});

						if (notifError) {
							console.error('Error creating notification:', notifError);
						} else {
							console.log('✅ Notification sent to', approverUserIds.length, 'approvers');
						}
					} catch (notificationError) {
						console.warn('⚠️ Warning: Could not send notifications:', notificationError);
					}
				}
			} catch (approvalError) {
				console.warn('⚠️ Warning: Could not check approvals:', approvalError);
			}

			// Success!
			successMessage = $t('hr.shift.mobile_day_off_request.successMessage')
				.replace('{days}', dateArray.length.toString())
				.replace('{plural}', dateArray.length !== 1 ? ($currentLocale === 'ar' ? 'ات' : 's') : '');
			
			showSuccessModal = true;
			
			// Reset form
			selectedReason = null;
			startDate = new Date().toISOString().split('T')[0];
			endDate = new Date().toISOString().split('T')[0];
			description = '';
			documentFile = null;
			documentProgress = 0;
			isUploadingDocument = false;
			errorMessage = '';
		} catch (err) {
			console.error('Error submitting day-off:', err);
			errorMessage = 'Error: ' + (err instanceof Error ? err.message : 'Failed to submit request');
		} finally {
			saving = false;
		}
	}
</script>

<div class="mobile-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Content -->
	<div class="mobile-content">
		{#if loading}
			<div class="loading-spinner">
				<div class="spinner"></div>
				<p>{$t('hr.shift.mobile_day_off_request.loading')}</p>
			</div>
		{:else}
			<div class="form-container">
				<!-- Error Message -->
				{#if errorMessage}
					<div class="alert error-alert">
						<div class="alert-icon">⚠️</div>
						<div class="alert-content">
							<p>{errorMessage}</p>
						</div>
					</div>
				{/if}

				<!-- Start Date -->
				<div class="form-group">
					<span class="form-label">{$t('hr.shift.mobile_day_off_request.startDate')}</span>
					<!-- svelte-ignore a11y-click-events-have-key-events -->
					<!-- svelte-ignore a11y-no-static-element-interactions -->
					<div class="date-trigger" on:click={() => openDatePicker('start')}>
						<span class="date-trigger-text">{formatDisplayDate(startDate)}</span>
						<span class="date-trigger-icon">📅</span>
					</div>
				</div>

				<!-- End Date -->
				<div class="form-group">
					<span class="form-label">{$t('hr.shift.mobile_day_off_request.endDate')}</span>
					<!-- svelte-ignore a11y-click-events-have-key-events -->
					<!-- svelte-ignore a11y-no-static-element-interactions -->
					<div class="date-trigger" on:click={() => openDatePicker('end')}>
						<span class="date-trigger-text">{formatDisplayDate(endDate)}</span>
						<span class="date-trigger-icon">📅</span>
					</div>
				</div>

				<!-- Reason Selection -->
				<div class="form-group">
					<label for="reason-select">{$t('hr.shift.mobile_day_off_request.reason')}</label>
					<div class="reason-list">
						{#each dayOffReasons as reason}
							<button 
								class="reason-item {selectedReason?.id === reason.id ? 'selected' : ''}"
								on:click={() => {
									selectedReason = reason;
									console.log('✅ Selected reason:', $currentLocale === 'ar' ? reason.reason_ar : reason.reason_en);
									console.log('   - Document mandatory:', reason.is_document_mandatory);
									console.log('   - Deductible:', reason.is_deductible);
									scrollToSubmit();
								}}
							>
								<div class="reason-header">
									<div class="reason-checkbox {selectedReason?.id === reason.id ? 'checked' : ''}">
										{#if selectedReason?.id === reason.id}
											<span class="check-mark">✓</span>
										{/if}
									</div>
									<span class="reason-title">
										{$currentLocale === 'ar' ? reason.reason_ar : reason.reason_en}
									</span>
								</div>
								<div class="reason-badges">
									{#if reason.is_document_mandatory}
										<span class="badge mandatory">📄 {$t('hr.shift.mobile_day_off_request.documentRequired')}</span>
									{/if}
								</div>
							</button>
						{/each}
					</div>
				</div>

				<!-- Document Upload (if reason selected) -->
				{#if selectedReason}
					<div class="form-group" bind:this={documentUploadSection}>
						<label for="document" class="document-label {selectedReason.is_document_mandatory ? 'mandatory-label' : ''}">
						📄 {$t('hr.shift.mobile_day_off_request.documentUpload')}
						{#if selectedReason.is_document_mandatory}
							<span class="required-badge">{$t('hr.shift.mobile_day_off_request.required')}</span>
						{:else}
							<span class="optional-badge">{$t('hr.shift.mobile_day_off_request.optional')}</span>
						{/if}
					</label>
					
					{#if selectedReason.is_document_mandatory}
						<div class="mandatory-notice">
							<strong>⚠️ {$t('hr.shift.mobile_day_off_request.mandatoryNotice')}</strong>
							<p>{$t('hr.shift.mobile_day_off_request.mustUploadFile')}</p>
						</div>
					{/if}

						<div class="custom-file-upload">
							<input 
								id="document"
								type="file" 
								on:change={handleDocumentSelect}
								class="hidden-file-input"
								required={selectedReason.is_document_mandatory}
							/>
							<label for="document" class="file-upload-trigger">
								<span class="upload-icon">📁</span>
								<span class="upload-text">
									{documentFile ? documentFile.name : $t('hr.shift.mobile_day_off_request.chooseFile')}
								</span>
								{#if !documentFile}
									<span class="no-file-text">({$t('hr.shift.mobile_day_off_request.noFileChosen')})</span>
								{/if}
							</label>
						</div>

					<div class="camera-upload">
						<input 
							id="camera"
							type="file" 
							accept="image/*"
							capture="environment"
							on:change={handleDocumentSelect}
							class="hidden-file-input"
						/>
						<label for="camera" class="camera-trigger">
							<span class="camera-icon">📷</span>
							<span class="camera-text">{$t('hr.shift.mobile_day_off_request.takePhoto') || 'Take Photo'}</span>
						</label>
					</div>
						
					{#if documentFile}
						<div class="file-info success">
							<p>✓ {$t('hr.shift.mobile_day_off_request.selectFile')} {documentFile.name}</p>
							{#if isUploadingDocument}
								<div class="progress-bar">
									<div class="progress-fill" style="width: {documentProgress}%"></div>
								</div>
							{/if}
						</div>
					{:else if selectedReason.is_document_mandatory}
						<div class="file-info warning">
							<p>⚠️ {$t('hr.shift.mobile_day_off_request.pleaseUploadDocument')}</p>
						</div>
					{/if}
					</div>
				{/if}

				<!-- Description Field (optional) -->
				{#if selectedReason}
					<div class="form-group">
						<label for="description">
							📝 {$t('hr.shift.mobile_day_off_request.description') || 'Description'}
							<span class="optional-badge">{$t('hr.shift.mobile_day_off_request.optional')}</span>
						</label>
						<textarea 
							id="description"
							bind:value={description}
							placeholder={$currentLocale === 'ar' 
								? 'أدخل وصفاً أو ملاحظة (اختياري)' 
								: 'Enter a description or note (optional)'}
							class="form-textarea"
							rows="4"
						/>
						<p class="field-hint">
							{$currentLocale === 'ar' 
								? 'يمكنك إضافة أي معلومات إضافية عن طلب إجازتك' 
								: 'You can add any additional information about your leave request'}
						</p>
					</div>
				{/if}

				<!-- Submit Button -->
				<div class="submit-section" bind:this={submitSection}>
					<button 
						class="submit-btn {saving ? 'loading' : ''}"
						on:click={submitDayOffRequest}
						disabled={saving || !selectedReason || !userEmployeeId}
					>
						{#if saving}
							<span class="spinner-small"></span>
							{$t('hr.shift.mobile_day_off_request.submitting')}
						{:else}
							{$t('hr.shift.mobile_day_off_request.sendRequest')}
						{/if}
					</button>
				</div>
			</div>
		{/if}
	</div>
</div>

<!-- Calendar Date Picker Popup -->
{#if showDatePicker}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="calendar-overlay" on:click={closeDatePicker}>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="calendar-popup" on:click|stopPropagation>
			<!-- Calendar Header -->
			<div class="calendar-header">
				<button class="cal-nav-btn" on:click={prevMonth}>‹</button>
				<span class="cal-month-year">{getMonthName(pickerMonth)} {pickerYear}</span>
				<button class="cal-nav-btn" on:click={nextMonth}>›</button>
			</div>

			<!-- Day of week headers -->
			<div class="cal-weekdays">
				{#if $currentLocale === 'ar'}
					<span>أح</span><span>إث</span><span>ثل</span><span>أر</span><span>خم</span><span>جم</span><span>سب</span>
				{:else}
					<span>Su</span><span>Mo</span><span>Tu</span><span>We</span><span>Th</span><span>Fr</span><span>Sa</span>
				{/if}
			</div>

			<!-- Days grid -->
			<div class="cal-days">
				{#each calendarDays as day}
					{#if day === null}
						<span class="cal-day empty"></span>
					{:else}
						{@const m = String(pickerMonth + 1).padStart(2, '0')}
						{@const d = String(day).padStart(2, '0')}
						{@const thisDayStr = `${pickerYear}-${m}-${d}`}
						{@const isToday = thisDayStr === new Date().toISOString().split('T')[0]}
						{@const isSelected = thisDayStr === selectedPickerDate}
						<button
							class="cal-day {isToday ? 'today' : ''} {isSelected ? 'selected' : ''}"
							on:click={() => selectCalendarDay(day)}
						>
							{day}
						</button>
					{/if}
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Alert Modal Popup -->
{#if showAlertModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="modal-overlay" on:click={closeAlert}>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header alert-header">
				<h2>⚠️ {$t('hr.shift.mobile_day_off_request.' + alertTitle)}</h2>
			</div>
			<div class="modal-body">
				<p>{$t('hr.shift.mobile_day_off_request.' + alertMessage)}</p>
			</div>
			<div class="modal-footer">
				<button class="modal-btn" on:click={closeAlert}>
					{$currentLocale === 'ar' ? 'موافق' : 'OK'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Success Modal Popup -->
{#if showSuccessModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="modal-overlay" on:click={closeSuccessModal}>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header success-header">
				<h2>✅ {$currentLocale === 'ar' ? 'تم بنجاح' : 'Success'}</h2>
			</div>
			<div class="modal-body">
				<p>{successMessage}</p>
			</div>
			<div class="modal-footer">
				<button class="modal-btn" on:click={closeSuccessModal}>
					{$currentLocale === 'ar' ? 'موافق' : 'OK'}
				</button>
			</div>
		</div>
	</div>
{/if}<style>
	.mobile-page {
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
	}

	.mobile-content {
		padding: 0;
		max-width: 100%;
	}

	.form-container {
		padding: 0.5rem 0.6rem;
		max-width: 100%;
	}

	.loading-spinner {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 40vh;
		gap: 0.5rem;
		font-size: 0.82rem;
		color: #6B7280;
	}

	.spinner {
		width: 24px;
		height: 24px;
		border: 2px solid #E5E7EB;
		border-top-color: #10B981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.spinner-small {
		display: inline-block;
		width: 0.8rem;
		height: 0.8rem;
		border: 2px solid #ffffff;
		border-top-color: transparent;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-right: 0.3rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.form-group {
		margin-bottom: 0.5rem;
	}

	.form-group label,
	.form-label {
		display: block;
		margin-bottom: 0.2rem;
		font-weight: 600;
		color: #374151;
		font-size: 0.76rem;
	}

	.field-hint {
		margin-top: 0.2rem;
		font-size: 0.68rem;
		color: #6B7280;
		font-style: italic;
	}

	.form-input,
	.form-textarea {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.78rem;
		font-family: inherit;
		transition: border-color 0.2s;
		box-sizing: border-box;
	}

	.form-input:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #10B981;
		box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.1);
	}

	.form-textarea {
		resize: vertical;
		min-height: 60px;
	}

	/* Date Trigger Button */
	.date-trigger {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0.6rem;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		background: white;
		cursor: pointer;
		min-height: 38px;
		transition: border-color 0.2s;
	}

	.date-trigger:active {
		border-color: #10B981;
		background: #F0FDF4;
	}

	.date-trigger-text {
		font-size: 0.82rem;
		font-weight: 500;
		color: #1e293b;
	}

	.date-trigger-icon {
		font-size: 0.9rem;
	}

	/* Calendar Popup */
	.calendar-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: calc(3.6rem + env(safe-area-inset-bottom));
		background: rgba(0, 0, 0, 0.4);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
		padding: 1rem;
		animation: calFadeIn 0.15s ease-out;
	}

	@keyframes calFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.calendar-popup {
		background: white;
		border-radius: 10px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.18);
		width: 100%;
		max-width: 320px;
		overflow: hidden;
		animation: calSlideUp 0.2s ease-out;
	}

	@keyframes calSlideUp {
		from { opacity: 0; transform: translateY(16px); }
		to { opacity: 1; transform: translateY(0); }
	}

	.calendar-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0.6rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
	}

	.cal-nav-btn {
		width: 30px;
		height: 30px;
		border: none;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border-radius: 50%;
		font-size: 1.1rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.15s;
	}

	.cal-nav-btn:active {
		background: rgba(255, 255, 255, 0.35);
	}

	.cal-month-year {
		font-size: 0.88rem;
		font-weight: 700;
	}

	.cal-weekdays {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		text-align: center;
		padding: 0.4rem 0.5rem 0.2rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.cal-weekdays span {
		font-size: 0.68rem;
		font-weight: 700;
		color: #9CA3AF;
		text-transform: uppercase;
	}

	.cal-days {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		padding: 0.3rem 0.5rem 0.5rem;
		gap: 2px;
	}

	.cal-day {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 36px;
		border: none;
		background: transparent;
		border-radius: 50%;
		font-size: 0.78rem;
		font-weight: 500;
		color: #374151;
		cursor: pointer;
		transition: all 0.15s;
	}

	.cal-day.empty {
		cursor: default;
	}

	.cal-day:not(.empty):active {
		transform: scale(0.9);
	}

	.cal-day.today {
		border: 2px solid #10B981;
		font-weight: 700;
		color: #10B981;
	}

	.cal-day.selected {
		background: #10B981;
		color: white;
		font-weight: 700;
	}

	.cal-day.selected.today {
		border-color: #10B981;
		color: white;
	}

	.document-label {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.required-badge {
		display: inline-block;
		padding: 0.1rem 0.4rem;
		background: #FEE2E2;
		color: #991B1B;
		border-radius: 9999px;
		font-size: 0.6rem;
		font-weight: 700;
	}

	.optional-badge {
		display: inline-block;
		padding: 0.1rem 0.4rem;
		background: #DBEAFE;
		color: #1E40AF;
		border-radius: 9999px;
		font-size: 0.6rem;
		font-weight: 700;
	}

	.mandatory-notice {
		padding: 0.4rem 0.5rem;
		background: #FEF3C7;
		border-inline-start: 3px solid #F59E0B;
		border-radius: 4px;
		margin-bottom: 0.4rem;
		color: #92400E;
		font-size: 0.74rem;
	}

	.mandatory-notice strong {
		display: block;
		margin-bottom: 0.1rem;
		font-size: 0.74rem;
	}

	.mandatory-notice p {
		margin: 0;
		font-size: 0.7rem;
	}

	.form-input {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.78rem;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #10B981;
		box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.1);
	}

	.custom-file-upload {
		position: relative;
		width: 100%;
	}

	.hidden-file-input {
		position: absolute;
		width: 0.1px;
		height: 0.1px;
		opacity: 0;
		overflow: hidden;
		z-index: -1;
	}

	.file-upload-trigger {
		display: flex;
		align-items: center;
		padding: 0.5rem 0.6rem;
		border: 1px dashed #D1D5DB;
		border-radius: 5px;
		background: #F9FAFB;
		cursor: pointer;
		transition: all 0.2s;
		gap: 0.4rem;
	}

	.file-upload-trigger:hover {
		border-color: #10B981;
		background: #F0FDF4;
	}

	.camera-upload {
		position: relative;
		width: 100%;
		margin-top: 0.35rem;
	}

	.camera-trigger {
		display: flex;
		align-items: center;
		padding: 0.5rem 0.6rem;
		border: 1px dashed #3B82F6;
		border-radius: 5px;
		background: #EFF6FF;
		cursor: pointer;
		transition: all 0.2s;
		gap: 0.4rem;
	}

	.camera-trigger:hover {
		border-color: #2563EB;
		background: #DBEAFE;
	}

	.camera-icon {
		font-size: 0.9rem;
	}

	.camera-text {
		color: #1E40AF;
		font-weight: 500;
		font-size: 0.76rem;
	}

	.upload-icon {
		font-size: 0.9rem;
	}

	.upload-text {
		color: #374151;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		flex: 1;
		font-size: 0.76rem;
	}

	.no-file-text {
		color: #6B7280;
		font-size: 0.68rem;
	}

	.file-info {
		margin-top: 0.3rem;
		padding: 0.35rem 0.5rem;
		border-radius: 5px;
		font-size: 0.74rem;
	}

	.file-info p {
		margin: 0;
	}

	.file-info.success {
		background: #ECFDF5;
		color: #047857;
		border: 1px solid #A7F3D0;
	}

	.file-info.warning {
		background: #FEF3C7;
		color: #92400E;
		border: 1px solid #FCD34D;
	}

	.progress-bar {
		width: 100%;
		height: 3px;
		background: #D1D5DB;
		border-radius: 2px;
		margin-top: 0.3rem;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: #10B981;
		transition: width 0.3s;
	}

	.reason-list {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.reason-item {
		padding: 0.45rem 0.5rem;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		background: white;
		cursor: pointer;
		text-align: start;
		transition: all 0.2s;
	}

	.reason-item:active {
		transform: scale(0.98);
	}

	.reason-item.selected {
		border-color: #10B981;
		background: #ECFDF5;
	}

	.reason-header {
		display: flex;
		align-items: center;
		margin-bottom: 0.15rem;
		gap: 0.4rem;
	}

	.reason-checkbox {
		width: 1.1rem;
		height: 1.1rem;
		border: 2px solid #D1D5DB;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: white;
		transition: all 0.2s;
		flex-shrink: 0;
	}

	.reason-checkbox.checked {
		background: #10B981;
		border-color: #10B981;
	}

	.check-mark {
		color: white;
		font-weight: 800;
		font-size: 0.7rem;
	}

	.reason-title {
		font-weight: 600;
		color: #1F2937;
		flex: 1;
		text-align: inherit;
		font-size: 0.78rem;
	}

	.reason-badges {
		display: flex;
		gap: 0.3rem;
		flex-wrap: wrap;
	}

	.badge {
		display: inline-block;
		padding: 0.1rem 0.4rem;
		border-radius: 9999px;
		font-size: 0.64rem;
		font-weight: 600;
	}

	.badge.mandatory {
		background: #FEF3C7;
		color: #92400E;
	}

	.alert {
		padding: 0.4rem 0.5rem;
		border-radius: 5px;
		margin-bottom: 0.5rem;
		display: flex;
		gap: 0.4rem;
	}

	.alert-icon {
		font-size: 0.88rem;
		flex-shrink: 0;
	}

	.alert-content {
		flex: 1;
	}

	.alert-content p {
		margin: 0;
		font-size: 0.76rem;
		line-height: 1.4;
	}

	.error-alert {
		background: #FEE2E2;
		color: #991B1B;
		border: 1px solid #FECACA;
	}

	.success-alert {
		background: #ECFDF5;
		color: #047857;
		border: 1px solid #A7F3D0;
	}

	.submit-section {
		margin-top: 0.5rem;
		padding-top: 0.5rem;
	}

	.submit-btn {
		width: 100%;
		padding: 0.5rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		min-height: 36px;
	}

	.submit-btn:active:not(:disabled) {
		transform: scale(0.98);
	}

	.submit-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.submit-btn.loading {
		opacity: 0.8;
	}

	/* Alert Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		padding: 0.5rem;
	}

	.modal-content {
		background: white;
		border-radius: 8px;
		box-shadow: 0 10px 20px rgba(0, 0, 0, 0.15);
		max-width: 280px;
		width: 100%;
		max-height: 90vh;
		overflow-y: auto;
		animation: modalSlideUp 0.2s ease-out;
	}

	@keyframes modalSlideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.modal-header {
		padding: 0.6rem 0.8rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.modal-header.alert-header {
		background: linear-gradient(135deg, #FEF3C7 0%, #FCD34D 100%);
	}

	.modal-header.success-header {
		background: linear-gradient(135deg, #ECFDF5 0%, #10B981 100%);
	}

	.modal-header h2 {
		margin: 0;
		font-size: 0.88rem;
		font-weight: 700;
	}

	.modal-header.alert-header h2 {
		color: #92400E;
	}

	.modal-header.success-header h2 {
		color: white;
	}

	.modal-body {
		padding: 0.6rem 0.8rem;
		color: #374151;
		line-height: 1.5;
	}

	.modal-body p {
		margin: 0;
		white-space: pre-wrap;
		word-break: break-word;
		font-size: 0.78rem;
	}

	.modal-footer {
		padding: 0.5rem 0.8rem;
		background: #F9FAFB;
		border-top: 1px solid #E5E7EB;
		display: flex;
		gap: 0.5rem;
		justify-content: flex-end;
	}

	.modal-btn {
		padding: 0.4rem 0.8rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 5px;
		font-weight: 600;
		font-size: 0.82rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.modal-btn:active {
		transform: scale(0.98);
	}
</style>
