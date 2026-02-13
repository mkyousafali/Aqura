<script>
	import { createEventDispatcher, onMount } from 'svelte';
	import { supabase, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let task;
	export let assignmentId;
	export let onComplete = () => {};

	const dispatch = createEventDispatcher();

	let loading = false;
	let assignment = null;
	let completionNotes = '';
	let erpReference = '';
	let selectedFiles = [];
	let fileInput;
	let uploadingFiles = false;
	let incidentData = null;
	let incidentAttachments = [];

	// Completion requirements
	let requirePhotoUpload = false;
	let requireErpReference = false;

	onMount(async () => {
		await loadAssignmentDetails();
	});

	async function loadAssignmentDetails() {
		try {
			const { data, error } = await supabase
				.from('quick_task_assignments')
				.select(`
					*,
					quick_tasks (
						id,
						title,
						description,
						priority,
						issue_type,
						price_tag,
						incident_id,
						product_request_id,
						product_request_type
					)
				`)
				.eq('id', assignmentId)
				.single();

			if (error) throw error;

			assignment = data;
			requirePhotoUpload = data.require_photo_upload || false;
			requireErpReference = data.require_erp_reference || false;

			console.log('📋 Assignment loaded:', assignment);
			console.log('✅ Requirements:', { requirePhotoUpload, requireErpReference });

			// Load incident data if linked
			if (data.quick_tasks?.incident_id) {
				const { data: incident, error: incidentError } = await supabase
					.from('incidents')
					.select('id, incident_types(incident_type_en, incident_type_ar), attachments, employee_id, branch_id')
					.eq('id', data.quick_tasks.incident_id)
					.single();
				
				if (incident && !incidentError) {
					incidentData = incident;
					incidentAttachments = incident.attachments || [];
					console.log('📎 [CompletionDialog] Incident attachments loaded:', incidentAttachments.length);
				}
			}
		} catch (error) {
			console.error('Error loading assignment:', error);
			alert('Error loading task details. Please try again.');
		}
	}

	function openFileBrowser() {
		fileInput.click();
	}

	function handleFileSelect(event) {
		const files = Array.from(event.target.files);
		
		selectedFiles = [
			...selectedFiles,
			...files.map(file => ({
				id: Math.random().toString(36).substring(7),
				file: file,
				name: file.name,
				size: file.size,
				type: file.type,
				preview: file.type.startsWith('image/') ? URL.createObjectURL(file) : null
			}))
		];

		// Reset file input
		event.target.value = '';
	}

	function removeFile(fileId) {
		const file = selectedFiles.find(f => f.id === fileId);
		if (file && file.preview) {
			URL.revokeObjectURL(file.preview);
		}
		selectedFiles = selectedFiles.filter(f => f.id !== fileId);
	}

	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
	}

	async function handleSubmit() {
		// Check if this is an incident follow-up task that requires incident resolution first
		if (assignment?.quick_tasks?.issue_type === 'incident_followup' && assignment?.quick_tasks?.incident_id) {
			try {
				const { data: incident, error } = await supabase
					.from('incidents')
					.select('resolution_status')
					.eq('id', assignment.quick_tasks.incident_id)
					.single();
				
				if (!error && incident && incident.resolution_status !== 'resolved') {
					alert('⚠️ Cannot complete this task until the linked incident is resolved.\n\nالا يمكن إكمال هذه المهمة حتى يتم حل الحادثة المرتبطة.');
					return;
				}
			} catch (err) {
				console.error('Error checking incident status:', err);
			}
		}

		// Check if this is a product request task that requires accept/reject first
		if ((assignment?.quick_tasks?.issue_type === 'product_request_follow_up' || assignment?.quick_tasks?.issue_type === 'product_request_process') && assignment?.quick_tasks?.product_request_id && assignment?.quick_tasks?.product_request_type) {
			try {
				const reqType = assignment.quick_tasks.product_request_type;
				const tableName = reqType === 'PO' ? 'product_request_po' : reqType === 'ST' ? 'product_request_st' : 'product_request_bt';
				const { data: reqData, error } = await supabase
					.from(tableName)
					.select('status')
					.eq('id', assignment.quick_tasks.product_request_id)
					.single();

				if (!error && reqData && reqData.status === 'pending') {
					alert('⚠️ Cannot complete this task until the product request is accepted or rejected.\n\nلا يمكن إكمال هذه المهمة حتى يتم قبول أو رفض طلب المنتج.');
					return;
				}
			} catch (err) {
				console.error('Error checking product request status:', err);
			}
		}

		// Check if BT process task requires document_url to be uploaded first
		if (assignment?.quick_tasks?.issue_type === 'product_request_process' && assignment?.quick_tasks?.product_request_type === 'BT' && assignment?.quick_tasks?.product_request_id) {
			try {
				const { data: btData, error } = await supabase
					.from('product_request_bt')
					.select('document_url')
					.eq('id', assignment.quick_tasks.product_request_id)
					.single();

				if (!error && btData && (!btData.document_url || btData.document_url.trim() === '')) {
					alert('⚠️ Cannot complete this task until the BT document is uploaded. Please upload the document first.\n\nلا يمكن إكمال هذه المهمة حتى يتم رفع مستند النقل الفرعي. يرجى رفع المستند أولاً.');
					return;
				}
			} catch (err) {
				console.error('Error checking BT document_url:', err);
			}
		}
		
		// Validate completion requirements
		if (requirePhotoUpload && selectedFiles.length === 0) {
			alert('⚠️ Photo upload is required for this task. Please upload at least one photo.\n\nتحميل الصورة مطلوب لهذه المهمة. يرجى تحميل صورة واحدة على الأقل.');
			return;
		}

		if (requireErpReference && (!erpReference || erpReference.trim() === '')) {
			alert('⚠️ ERP reference is required for this task. Please provide an ERP reference.\n\nمرجع ERP مطلوب لهذه المهمة. يرجى تقديم مرجع ERP.');
			return;
		}

		loading = true;
		uploadingFiles = true;

		try {
			// Upload files if any
			let uploadedPhotoPaths = [];
			
			if (selectedFiles.length > 0) {
				console.log('📎 Uploading', selectedFiles.length, 'file(s)...');
				
				for (const selectedFile of selectedFiles) {
					try {
						const timestamp = Date.now();
						const randomString = Math.random().toString(36).substring(2, 15);
						const fileExtension = selectedFile.name.split('.').pop();
						const uniqueFileName = `quick-task-completion-${assignmentId}-${timestamp}-${randomString}.${fileExtension}`;
						
						console.log('⬆️ Uploading:', selectedFile.name);
						const uploadResult = await uploadToSupabase(
							selectedFile.file,
							'quick-task-files',
							uniqueFileName
						);
						
						if (!uploadResult.error) {
							uploadedPhotoPaths.push(uploadResult.data.path);
							console.log('✅ Uploaded:', uploadResult.data.path);
						} else {
							console.error('❌ Upload failed:', uploadResult.error);
							throw new Error(`Failed to upload ${selectedFile.name}`);
						}
					} catch (uploadError) {
						console.error('❌ Error uploading file:', uploadError);
						throw uploadError;
					}
				}
				
				console.log('✅ All files uploaded:', uploadedPhotoPaths);
			}

			uploadingFiles = false;

			// Submit completion
			console.log('📋 Submitting completion with:', {
				assignmentId,
				notes: completionNotes,
				photos: uploadedPhotoPaths,
				erpReference: erpReference || null
			});

			const { data, error } = await supabase.rpc('submit_quick_task_completion', {
				p_assignment_id: assignmentId,
				p_user_id: $currentUser?.id,
				p_completion_notes: completionNotes || null,
				p_photos: uploadedPhotoPaths.length > 0 ? uploadedPhotoPaths : null,
				p_erp_reference: erpReference ? erpReference.trim() : null
			});

			if (error) {
				console.error('❌ Completion error:', error);
				throw error;
			}

			console.log('✅ Task completed successfully!');
			
			// Update incident user status to 'acknowledged' if this is an incident recovery task
			if (assignment?.quick_tasks?.incident_id && $currentUser?.id) {
				try {
					const { data: incident, error: fetchError } = await supabase
						.from('incidents')
						.select('user_statuses')
						.eq('id', assignment.quick_tasks.incident_id)
						.single();
					
					if (!fetchError && incident) {
						const userStatuses = typeof incident.user_statuses === 'string' 
							? JSON.parse(incident.user_statuses)
							: (incident.user_statuses || {});
						
						// Update current user's status to 'acknowledged'
						userStatuses[$currentUser.id] = {
							...userStatuses[$currentUser.id],
							status: 'acknowledged',
							acknowledged_at: new Date().toISOString()
						};
						
						await supabase
							.from('incidents')
							.update({ user_statuses: userStatuses })
							.eq('id', assignment.quick_tasks.incident_id);
						
						console.log('✅ Incident user status updated to acknowledged');
					}
				} catch (err) {
					console.warn('⚠️ Could not update incident user status:', err);
					// Don't fail the whole operation if this fails
				}
			}
			
			alert('✅ Quick Task completed successfully! / تم إكمال المهمة السريعة بنجاح!');
			
			onComplete();
			dispatch('complete');
		} catch (error) {
			console.error('Error completing task:', error);
			alert(`❌ Error completing task / خطأ في إكمال المهمة: ${error.message}`);
		} finally {
			loading = false;
			uploadingFiles = false;
		}
	}
</script>

<div class="completion-dialog">
	<div class="dialog-header">
		<h2>⚡ Complete Quick Task</h2>
		{#if assignment}
			<p class="task-title">{assignment.quick_tasks.title}</p>
		{/if}
	</div>

	<div class="dialog-body">
		{#if assignment}
			<!-- Task Info -->
			<div class="task-info">
				<div class="info-row">
					<span class="label">Issue Type:</span>
					<span class="value">{assignment.quick_tasks.issue_type}</span>
				</div>
				<div class="info-row">
					<span class="label">Priority:</span>
					<span class="value priority-{assignment.quick_tasks.priority}">{assignment.quick_tasks.priority}</span>
				</div>
				{#if assignment.quick_tasks.description}
					<div class="info-row">
						<span class="label">Description:</span>
						<span class="value">{assignment.quick_tasks.description}</span>
					</div>
				{/if}
			</div>

			<!-- Incident Attachments (if any) -->
			{#if incidentAttachments && incidentAttachments.length > 0}
				<div class="incident-attachments-section">
					<h4>📎 Incident Attachments ({incidentAttachments.length})</h4>
					<div class="attachments-grid">
						{#each incidentAttachments as attachment}
							{#if attachment.type === 'image'}
								<div class="attachment-item image">
									<img src={attachment.url} alt={attachment.name || 'Incident attachment'} class="attachment-image" />
									<span class="attachment-name">{attachment.name || 'Image'}</span>
								</div>
							{:else}
								<a href={attachment.url} target="_blank" rel="noopener noreferrer" class="attachment-item file">
									<span class="file-icon">{attachment.type === 'pdf' ? '📄' : '📁'}</span>
									<span class="attachment-name">{attachment.name || 'File'}</span>
								</a>
							{/if}
						{/each}
					</div>
					{#if incidentData}
						<div class="incident-info">
							<p><strong>Incident ID:</strong> {incidentData.id}</p>
							<p><strong>Type:</strong> {incidentData.incident_types?.incident_type_en || 'Unknown'}</p>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Completion Requirements Notice -->
			{#if requirePhotoUpload || requireErpReference}
				<div class="requirements-notice">
					<h3>⚠️ Completion Requirements</h3>
					<ul>
						{#if requirePhotoUpload}
							<li>📸 Photo upload is <strong>required</strong></li>
						{/if}
						{#if requireErpReference}
							<li>🔢 ERP reference is <strong>required</strong></li>
						{/if}
					</ul>
				</div>
			{/if}

			<!-- Completion Notes -->
			<div class="form-group">
				<label for="notes">Completion Notes</label>
				<textarea
					id="notes"
					bind:value={completionNotes}
					placeholder="Add any notes about the completion..."
					rows="4"
					disabled={loading}
				/>
			</div>

			<!-- ERP Reference (if required) -->
			{#if requireErpReference}
				<div class="form-group required">
					<label for="erp">ERP Reference <span class="required-star">*</span></label>
					<input
						type="text"
						id="erp"
						bind:value={erpReference}
						placeholder="Enter ERP reference number"
						required
						disabled={loading}
					/>
				</div>
			{/if}

			<!-- Photo Upload (if required or optional) -->
			<div class="form-group {requirePhotoUpload ? 'required' : ''}">
				<label>
					Photos {#if requirePhotoUpload}<span class="required-star">*</span>{/if}
				</label>
				
				<input
					type="file"
					bind:this={fileInput}
					on:change={handleFileSelect}
					accept="image/*"
					multiple
					style="display: none;"
					disabled={loading}
				/>

				<button
					type="button"
					class="upload-btn"
					on:click={openFileBrowser}
					disabled={loading}
				>
					<span>📸</span>
					Upload Photos
				</button>

				{#if selectedFiles.length > 0}
					<div class="selected-files">
						{#each selectedFiles as file (file.id)}
							<div class="file-item">
								{#if file.preview}
									<img src={file.preview} alt={file.name} class="file-preview" />
								{:else}
									<div class="file-icon">📄</div>
								{/if}
								<div class="file-info">
									<div class="file-name">{file.name}</div>
									<div class="file-size">{formatFileSize(file.size)}</div>
								</div>
								<button
									type="button"
									class="remove-btn"
									on:click={() => removeFile(file.id)}
									disabled={loading}
								>
									×
								</button>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		{:else}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading task details...</p>
			</div>
		{/if}
	</div>

	<div class="dialog-footer">
		<button
			type="button"
			class="btn-cancel"
			on:click={() => dispatch('close')}
			disabled={loading}
		>
			Cancel
		</button>
		<button
			type="button"
			class="btn-submit"
			on:click={handleSubmit}
			disabled={loading || !assignment}
		>
			{#if uploadingFiles}
				<span class="spinner-small"></span>
				Uploading Files...
			{:else if loading}
				<span class="spinner-small"></span>
				Completing...
			{:else}
				✅ Complete Task
			{/if}
		</button>
	</div>
</div>

<style>
	.completion-dialog {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.dialog-header {
		padding: 20px;
		border-bottom: 2px solid #e5e7eb;
		background: #f9fafb;
	}

	.dialog-header h2 {
		margin: 0 0 8px 0;
		font-size: 20px;
		font-weight: 600;
		color: #111827;
	}

	.task-title {
		margin: 0;
		font-size: 14px;
		color: #6b7280;
	}

	.dialog-body {
		flex: 1;
		padding: 20px;
		overflow-y: auto;
	}

	.task-info {
		background: #f3f4f6;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 20px;
	}

	.info-row {
		display: flex;
		gap: 12px;
		margin-bottom: 8px;
	}

	.info-row:last-child {
		margin-bottom: 0;
	}

	.label {
		font-weight: 600;
		color: #374151;
		min-width: 100px;
	}

	.value {
		color: #6b7280;
		flex: 1;
	}

	.priority-low { color: #10b981; }
	.priority-medium { color: #f59e0b; }
	.priority-high { color: #ef4444; }
	.priority-urgent { 
		color: #dc2626;
		font-weight: 600;
	}

	.requirements-notice {
		background: #fef3c7;
		border: 2px solid #f59e0b;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 20px;
	}

	.requirements-notice h3 {
		margin: 0 0 12px 0;
		font-size: 14px;
		font-weight: 600;
		color: #92400e;
	}

	.requirements-notice ul {
		margin: 0;
		padding-left: 20px;
		color: #78350f;
	}

	.requirements-notice li {
		margin-bottom: 4px;
	}

	.form-group {
		margin-bottom: 20px;
	}

	.form-group.required label {
		font-weight: 600;
	}

	.required-star {
		color: #ef4444;
		margin-left: 4px;
	}

	label {
		display: block;
		margin-bottom: 8px;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	textarea,
	input[type="text"] {
		width: 100%;
		padding: 10px 12px;
		border: 2px solid #e5e7eb;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		transition: border-color 0.2s;
	}

	textarea:focus,
	input[type="text"]:focus {
		outline: none;
		border-color: #3b82f6;
	}

	textarea:disabled,
	input[type="text"]:disabled {
		background: #f9fafb;
		cursor: not-allowed;
	}

	.upload-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.upload-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.upload-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.selected-files {
		margin-top: 12px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.file-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
	}

	.file-preview {
		width: 50px;
		height: 50px;
		object-fit: cover;
		border-radius: 4px;
	}

	.file-icon {
		width: 50px;
		height: 50px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #e5e7eb;
		border-radius: 4px;
		font-size: 24px;
	}

	.file-info {
		flex: 1;
	}

	.file-name {
		font-size: 14px;
		font-weight: 500;
		color: #111827;
		margin-bottom: 2px;
	}

	.file-size {
		font-size: 12px;
		color: #6b7280;
	}

	.remove-btn {
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #fee2e2;
		border: none;
		border-radius: 4px;
		color: #dc2626;
		font-size: 20px;
		font-weight: bold;
		cursor: pointer;
		transition: all 0.2s;
	}

	.remove-btn:hover:not(:disabled) {
		background: #fecaca;
	}

	.remove-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.loading {
		text-align: center;
		padding: 40px 20px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-left: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.incident-attachments-section {
		margin-top: 20px;
		margin-bottom: 20px;
		padding: 16px;
		background: #f0f9ff;
		border: 1px solid #bfdbfe;
		border-radius: 8px;
	}

	.incident-attachments-section h4 {
		margin: 0 0 12px 0;
		font-size: 14px;
		font-weight: 600;
		color: #1e40af;
	}

	.attachments-grid {
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin-bottom: 12px;
	}

	.attachment-item {
		display: flex;
		flex-direction: column;
		border-radius: 6px;
		overflow: hidden;
		background: white;
		border: 1px solid #bfdbfe;
		transition: box-shadow 0.2s;
	}

	.attachment-item:hover {
		box-shadow: 0 2px 8px rgba(0,0,0,0.1);
	}

	.attachment-item.image .attachment-image {
		width: 100%;
		height: auto;
		max-height: 300px;
		object-fit: contain;
		background: #f9fafb;
	}

	.attachment-item.file {
		flex-direction: row;
		align-items: center;
		gap: 12px;
		padding: 12px;
		text-decoration: none;
		cursor: pointer;
	}

	.attachment-item .file-icon {
		font-size: 1.5rem;
		flex-shrink: 0;
	}

	.attachment-name {
		font-size: 12px;
		color: #374151;
		padding: 8px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		border-top: 1px solid #e5e7eb;
	}

	.incident-info {
		padding: 8px 12px;
		background: white;
		border-radius: 4px;
		border: 1px solid #bfdbfe;
		font-size: 12px;
		color: #1f2937;
	}

	.incident-info p {
		margin: 4px 0;
	}

	.incident-info strong {
		color: #1e40af;
	}

	.dialog-footer {
		padding: 16px 20px;
		border-top: 1px solid #e5e7eb;
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		background: #f9fafb;
	}

	.btn-cancel,
	.btn-submit {
		padding: 10px 20px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn-cancel {
		background: white;
		color: #6b7280;
		border: 1px solid #d1d5db;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #f9fafb;
	}

	.btn-submit {
		background: #10b981;
		color: white;
	}

	.btn-submit:hover:not(:disabled) {
		background: #059669;
	}

	.btn-cancel:disabled,
	.btn-submit:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.spinner-small {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-left: 2px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
</style>
