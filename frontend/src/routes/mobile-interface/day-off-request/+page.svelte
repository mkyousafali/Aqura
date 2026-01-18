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
	let showAlertModal = false;
	let showSuccessModal = false;
	let alertMessage = '';
	let alertTitle = '';
	let errorMessage = '';
	let successMessage = '';

	// Initialize component
	onMount(async () => {

		// Load current user's employee ID
		const currentUserData = get(currentUser);
		if (currentUserData?.id) {
			try {
				// Find employee record with this user ID
				const { data: employees, error } = await supabase
					.from('hr_employee_master')
					.select('id')
					.eq('user_id', currentUserData.id)
					.single();

				if (!error && employees) {
					userEmployeeId = employees.id;
					console.log('✅ Found employee ID for logged-in user:', userEmployeeId);
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
						for (const approverId of approverUserIds) {
							await supabase
								.from('notifications')
								.insert({
									type: 'approval_request',
									title: $currentLocale === 'ar' ? 'طلب موافقة على إجازة' : 'Leave Request Approval',
									message: $currentLocale === 'ar' 
										? `طلب إجازة للموظف ${userEmployeeId} من ${startDate} إلى ${endDate} (${dateArray.length} أيام) يتطلب موافقة`
										: `Leave request for ${userEmployeeId} from ${startDate} to ${endDate} (${dateArray.length} days) requires approval`,
									target_user_id: approverId,
									related_id: dayOffData[0].id,
									read: false,
									created_at: new Date().toISOString()
								});
						}
						console.log('✅ Notifications sent to', approverUserIds.length, 'approvers');
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
					<label for="start-date">{$t('hr.shift.mobile_day_off_request.startDate')}</label>
					<input 
						id="start-date"
						type="date" 
						bind:value={startDate}
						class="form-input"
					/>
				</div>

				<!-- End Date -->
				<div class="form-group">
					<label for="end-date">{$t('hr.shift.mobile_day_off_request.endDate')}</label>
					<input 
						id="end-date"
						type="date" 
						bind:value={endDate}
						class="form-input"
					/>
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
		display: flex;
		flex-direction: column;
		height: 100vh;
		height: 100dvh;
		background: #F8FAFC;
	}

	.mobile-content {
		flex: 1;
		overflow-y: auto;
		padding-bottom: 4rem;
	}

	.form-container {
		padding: 1.5rem;
		max-width: 100%;
	}

	.loading-spinner {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100vh;
		gap: 1rem;
	}

	.spinner {
		width: 3rem;
		height: 3rem;
		border: 3px solid #E5E7EB;
		border-top-color: #10B981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.spinner-small {
		display: inline-block;
		width: 1rem;
		height: 1rem;
		border: 2px solid #ffffff;
		border-top-color: transparent;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-right: 0.5rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
	}

	.field-hint {
		margin-top: 0.5rem;
		font-size: 0.8125rem;
		color: #6B7280;
		font-style: italic;
	}

	.form-input,
	.form-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #E5E7EB;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-family: inherit;
		transition: border-color 0.2s;
	}

	.form-input:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #10B981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.form-textarea {
		resize: vertical;
		min-height: 100px;
	}

	.document-label {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.required-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: #FEE2E2;
		color: #991B1B;
		border-radius: 9999px;
		font-size: 0.7rem;
		font-weight: 700;
		letter-spacing: 0.05em;
	}

	.optional-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: #DBEAFE;
		color: #1E40AF;
		border-radius: 9999px;
		font-size: 0.7rem;
		font-weight: 700;
		letter-spacing: 0.05em;
	}

	.mandatory-notice {
		padding: 0.75rem;
		background: #FEF3C7;
		border-inline-start: 4px solid #F59E0B;
		border-radius: 0.25rem;
		margin-bottom: 0.75rem;
		color: #92400E;
		font-size: 0.875rem;
	}

	.mandatory-notice strong {
		display: block;
		margin-bottom: 0.25rem;
	}

	.mandatory-notice p {
		margin: 0;
		font-size: 0.8rem;
	}

	.form-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.5rem;
		font-size: 1rem;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #10B981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
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
		padding: 1rem;
		border: 2px dashed #D1D5DB;
		border-radius: 0.5rem;
		background: #F9FAFB;
		cursor: pointer;
		transition: all 0.2s;
		gap: 0.75rem;
	}

	.file-upload-trigger:hover {
		border-color: #10B981;
		background: #F0FDF4;
	}

	.camera-upload {
		position: relative;
		width: 100%;
		margin-top: 0.75rem;
	}

	.camera-trigger {
		display: flex;
		align-items: center;
		padding: 1rem;
		border: 2px dashed #3B82F6;
		border-radius: 0.5rem;
		background: #EFF6FF;
		cursor: pointer;
		transition: all 0.2s;
		gap: 0.75rem;
	}

	.camera-trigger:hover {
		border-color: #2563EB;
		background: #DBEAFE;
	}

	.camera-icon {
		font-size: 1.25rem;
	}

	.camera-text {
		color: #1E40AF;
		font-weight: 500;
	}

	.upload-icon {
		font-size: 1.25rem;
	}

	.upload-text {
		color: #374151;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		flex: 1;
	}

	.no-file-text {
		color: #6B7280;
		font-size: 0.8125rem;
	}

	.file-info {
		margin-top: 0.5rem;
		padding: 0.75rem;
		border-radius: 0.5rem;
		font-size: 0.875rem;
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
		height: 4px;
		background: #D1D5DB;
		border-radius: 2px;
		margin-top: 0.5rem;
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
		gap: 0.75rem;
	}

	.reason-item {
		padding: 1rem;
		border: 2px solid #E5E7EB;
		border-radius: 0.5rem;
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
		margin-bottom: 0.5rem;
		gap: 0.75rem;
	}

	.reason-checkbox {
		width: 1.5rem;
		height: 1.5rem;
		border: 2px solid #D1D5DB;
		border-radius: 0.375rem;
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
		font-size: 1rem;
	}

	.reason-title {
		font-weight: 600;
		color: #1F2937;
		flex: 1;
		text-align: inherit;
	}

	.reason-badges {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.badge.mandatory {
		background: #FEF3C7;
		color: #92400E;
	}

	.alert {
		padding: 1rem;
		border-radius: 0.5rem;
		margin-bottom: 1rem;
		display: flex;
		gap: 0.75rem;
	}

	.alert-icon {
		font-size: 1.25rem;
		flex-shrink: 0;
	}

	.alert-content {
		flex: 1;
	}

	.alert-content p {
		margin: 0;
		font-size: 0.875rem;
		line-height: 1.5;
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
		margin-top: 1rem;
		padding-top: 1rem;
	}

	.submit-btn {
		width: 100%;
		padding: 1rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 0.5rem;
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
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		padding: 1rem;
	}

	.modal-content {
		background: white;
		border-radius: 1rem;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.2);
		max-width: 90vw;
		width: 100%;
		max-height: 90vh;
		overflow-y: auto;
		animation: modalSlideUp 0.3s ease-out;
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
		padding: 1.5rem;
		border-bottom: 2px solid #F3F4F6;
	}

	.modal-header.alert-header {
		background: linear-gradient(135deg, #FEF3C7 0%, #FCD34D 100%);
	}

	.modal-header.success-header {
		background: linear-gradient(135deg, #ECFDF5 0%, #10B981 100%);
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 700;
	}

	.modal-header.alert-header h2 {
		color: #92400E;
	}

	.modal-header.success-header h2 {
		color: white;
	}

	.modal-body {
		padding: 1.5rem;
		color: #374151;
		line-height: 1.6;
	}

	.modal-body p {
		margin: 0;
		white-space: pre-wrap;
		word-break: break-word;
	}

	.modal-footer {
		padding: 1rem 1.5rem;
		background: #F9FAFB;
		border-top: 1px solid #E5E7EB;
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
	}

	.modal-btn {
		padding: 0.75rem 1.5rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.modal-btn:active {
		transform: scale(0.98);
	}
</style>
