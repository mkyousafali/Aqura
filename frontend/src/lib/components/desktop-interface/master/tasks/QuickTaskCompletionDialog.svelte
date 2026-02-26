<script>
	import { createEventDispatcher, onMount } from 'svelte';
	import { supabase, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale } from '$lib/i18n';

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

	// Shelf tag task feature (for price_change tasks)
	let isPriceChangeTask = false;
	let showShelfTagModal = false;
	let shelfTagBranchUsers = [];
	let shelfTagSelectedUsers = [];
	let shelfTagLoading = false;
	let shelfTagTaskCreated = false;
	let shelfTagTaskId = null;
	let shelfTagTaskStatus = null;
	let loadingBranchUsers = false;
	let shelfTagSearchQuery = '';

	$: filteredShelfTagUsers = shelfTagBranchUsers.filter(u => {
		if (!shelfTagSearchQuery.trim()) return true;
		const q = shelfTagSearchQuery.toLowerCase();
		return (u.name_en || '').toLowerCase().includes(q) || (u.name_ar || '').includes(q);
	});

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
						product_request_type,
						assigned_to_branch_id
					)
				`)
				.eq('id', assignmentId)
				.single();

			if (error) throw error;

			assignment = data;
			requirePhotoUpload = data.require_photo_upload || false;
			requireErpReference = data.require_erp_reference || false;

			// Detect price_change task
			isPriceChangeTask = data.quick_tasks?.issue_type === 'price_change';
			if (isPriceChangeTask) {
				await checkShelfTagTask();
			}

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

	// --- Shelf Tag Change Task Feature (for price_change tasks) ---
	async function checkShelfTagTask() {
		if (!assignment?.quick_tasks?.id) return;
		try {
			// Check if a shelf_tag_change sub-task already exists for this price_change task
			const { data, error } = await supabase
				.from('quick_tasks')
				.select('id, status')
				.eq('issue_type', 'shelf_tag_change')
				.eq('description', `linked_parent_task:${assignment.quick_tasks.id}`)
				.limit(1);
			
			if (!error && data && data.length > 0) {
				shelfTagTaskCreated = true;
				shelfTagTaskId = data[0].id;
				shelfTagTaskStatus = data[0].status;
			}
		} catch (err) {
			console.warn('Error checking shelf tag task:', err);
		}
	}

	async function openShelfTagModal() {
		showShelfTagModal = true;
		loadingBranchUsers = true;
		shelfTagSelectedUsers = [];
		
		try {
			// Try task's branch first, then fall back to current user's branch
			let branchId = assignment?.quick_tasks?.assigned_to_branch_id || task?.assigned_to_branch_id;
			if (!branchId && assignment?.assigned_to_user_id) {
				const { data: empData } = await supabase
					.from('hr_employee_master')
					.select('current_branch_id')
					.eq('user_id', assignment.assigned_to_user_id)
					.single();
				if (empData?.current_branch_id) {
					branchId = empData.current_branch_id;
				}
			}
			if (!branchId) {
				alert($locale === 'ar' ? 'لا يوجد فرع مرتبط بهذه المهمة' : 'No branch associated with this task');
				showShelfTagModal = false;
				return;
			}

			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, user_id, name_en, name_ar, hr_positions(position_title_en, position_title_ar)')
				.eq('current_branch_id', branchId)
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job'])
				.order('name_en');

			if (error) throw error;
			shelfTagBranchUsers = (data || []).filter(u => u.user_id);
		} catch (err) {
			console.error('Error loading branch users:', err);
			alert('Failed to load branch users');
		} finally {
			loadingBranchUsers = false;
		}
	}

	function toggleShelfTagUser(userId) {
		if (shelfTagSelectedUsers.includes(userId)) {
			shelfTagSelectedUsers = shelfTagSelectedUsers.filter(id => id !== userId);
		} else {
			shelfTagSelectedUsers = [...shelfTagSelectedUsers, userId];
		}
	}

	function selectAllShelfTagUsers() {
		if (shelfTagSelectedUsers.length === shelfTagBranchUsers.length) {
			shelfTagSelectedUsers = [];
		} else {
			shelfTagSelectedUsers = shelfTagBranchUsers.map(u => u.user_id);
		}
	}

	async function createShelfTagTask() {
		if (shelfTagSelectedUsers.length === 0) {
			alert($locale === 'ar' ? 'يرجى اختيار مستخدم واحد على الأقل' : 'Please select at least one user');
			return;
		}

		shelfTagLoading = true;
		try {
			const taskTitle = assignment.quick_tasks.title;
			const priceTag = assignment.quick_tasks.price_tag || '';
			const parentDesc = assignment.quick_tasks.description || '';
			
			// Extract old/new price from parent task description
			const oldPriceMatch = parentDesc.match(/Old Price:\s*([\d.]+)/i) || parentDesc.match(/السعر القديم:\s*([\d.]+)/);
			const newPriceMatch = parentDesc.match(/New Price:\s*([\d.]+)/i) || parentDesc.match(/السعر الجديد:\s*([\d.]+)/);
			const oldPrice = oldPriceMatch ? oldPriceMatch[1] : '';
			const newPrice = newPriceMatch ? newPriceMatch[1] : '';
			
			// Also try to extract from OfferCostManager format: "currentPrice → targetPrice"
			const arrowMatch = parentDesc.match(/([\d.]+)\s*→\s*([\d.]+)/);
			const displayOldPrice = oldPrice || (arrowMatch ? arrowMatch[1] : '');
			const displayNewPrice = newPrice || (arrowMatch ? arrowMatch[2] : '');
			
			// Build price info for title and description
			const priceInfo = displayOldPrice && displayNewPrice ? ` (${displayOldPrice} → ${displayNewPrice})` : '';
			const priceInfoAr = displayOldPrice && displayNewPrice ? ` (${displayOldPrice} ← ${displayNewPrice})` : '';

			// Build shelf tag description with price details
			let shelfTagDescEn = `Change the shelf price tags for the price change task.`;
			let shelfTagDescAr = `قم بتغيير بطاقات أسعار الرف لمهمة تغيير السعر.`;
			if (displayOldPrice && displayNewPrice) {
				shelfTagDescEn += `\n\nOld Price: ${displayOldPrice}\nNew Price: ${displayNewPrice}`;
				shelfTagDescAr += `\n\nالسعر القديم: ${displayOldPrice}\nالسعر الجديد: ${displayNewPrice}`;
			}
			shelfTagDescEn += `\n\nlinked_parent_task:${assignment.quick_tasks.id}`;
			
			// Create the shelf tag change task
			const { data: newTask, error: taskError } = await supabase
				.from('quick_tasks')
				.insert({
					title: `Change Shelf Tags - Price Change | تغيير السعر: ${priceTag || taskTitle}${priceInfo}`,
					description: `${shelfTagDescEn}\n---\n${shelfTagDescAr}`,
					issue_type: 'shelf_tag_change',
					priority: 'high',
					assigned_by: $currentUser?.id,
					assigned_to_branch_id: assignment.quick_tasks.assigned_to_branch_id || task?.assigned_to_branch_id,
					require_task_finished: true,
					require_photo_upload: true,
					require_erp_reference: false,
					status: 'pending'
				})
				.select()
				.single();

			if (taskError) throw taskError;

			// Create assignments for selected users
			const assignments = shelfTagSelectedUsers.map(userId => ({
				quick_task_id: newTask.id,
				assigned_to_user_id: userId,
				status: 'assigned',
				require_task_finished: true,
				require_photo_upload: true,
				require_erp_reference: false
			}));

			const { error: assignError } = await supabase
				.from('quick_task_assignments')
				.insert(assignments);

			if (assignError) throw assignError;

			shelfTagTaskCreated = true;
			shelfTagTaskId = newTask.id;
			shelfTagTaskStatus = 'pending';
			showShelfTagModal = false;

			alert($locale === 'ar' 
				? `✅ تم إنشاء مهمة تغيير بطاقة الرف وتعيينها لـ ${shelfTagSelectedUsers.length} مستخدم(ين)`
				: `✅ Shelf tag change task created and assigned to ${shelfTagSelectedUsers.length} user(s)`);
		} catch (err) {
			console.error('Error creating shelf tag task:', err);
			alert($locale === 'ar' ? 'خطأ في إنشاء المهمة' : 'Error creating task');
		} finally {
			shelfTagLoading = false;
		}
	}

	async function refreshShelfTagStatus() {
		if (!shelfTagTaskId) return;
		try {
			const { data, error } = await supabase
				.from('quick_tasks')
				.select('status')
				.eq('id', shelfTagTaskId)
				.single();
			if (!error && data) {
				shelfTagTaskStatus = data.status;
			}
		} catch (err) {
			console.warn('Error refreshing shelf tag status:', err);
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
		// Check if price_change task requires shelf tag task to be assigned and completed first
		if (isPriceChangeTask) {
			if (!shelfTagTaskCreated) {
				alert($locale === 'ar' 
					? '⚠️ يجب تعيين مهمة تغيير بطاقة الرف أولاً قبل إكمال مهمة تغيير السعر.'
					: '⚠️ You must assign a shelf tag change task before completing the price change task.');
				return;
			}
			if (shelfTagTaskId) {
				await refreshShelfTagStatus();
			}
			if (shelfTagTaskStatus !== 'completed') {
				alert($locale === 'ar' 
					? '⚠️ لا يمكن إكمال هذه المهمة حتى يتم إكمال مهمة تغيير بطاقة الرف.'
					: '⚠️ Cannot complete this task until the shelf tag change task is completed.');
				return;
			}
		}

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
						
						// Update current user's status to 'acknowledged' (but don't overwrite 'claimed' status)
						const existingStatus = userStatuses[$currentUser.id];
						const wasClaimed = existingStatus?.status?.toLowerCase() === 'claimed' || existingStatus?.claimed_at;
						userStatuses[$currentUser.id] = {
							...existingStatus,
							status: wasClaimed ? 'claimed' : 'acknowledged',
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

			<!-- Shelf Tag Change Task Section (for price_change tasks) -->
			{#if isPriceChangeTask}
				<div class="shelf-tag-section">
					<h3>🏷️ {$locale === 'ar' ? 'مهمة تغيير بطاقة الرف' : 'Shelf Tag Change Task'}</h3>
					{#if shelfTagTaskCreated}
						<div class="shelf-tag-status">
							<div class="shelf-tag-status-badge {shelfTagTaskStatus === 'completed' ? 'completed' : 'pending'}">
								{shelfTagTaskStatus === 'completed' ? '✅' : '⏳'}
								{shelfTagTaskStatus === 'completed' 
									? ($locale === 'ar' ? 'تم إكمال مهمة تغيير بطاقة الرف' : 'Shelf tag change task completed')
									: ($locale === 'ar' ? 'مهمة تغيير بطاقة الرف قيد الانتظار' : 'Shelf tag change task pending')}
							</div>
							{#if shelfTagTaskStatus !== 'completed'}
								<button type="button" class="btn-refresh" on:click={refreshShelfTagStatus} disabled={loading}>
									🔄 {$locale === 'ar' ? 'تحديث الحالة' : 'Refresh Status'}
								</button>
							{/if}
						</div>
					{:else}
						<p class="shelf-tag-desc">
							{$locale === 'ar' 
								? 'قم بتعيين مهمة تغيير بطاقة الرف لموظفي الفرع. يجب إكمال هذه المهمة قبل إتمام مهمة تغيير السعر.'
								: 'Assign a shelf tag change task to branch employees. This task must be completed before finishing the price change task.'}
						</p>
						<button type="button" class="btn-shelf-tag" on:click={openShelfTagModal} disabled={loading}>
							🏷️ {$locale === 'ar' ? 'تعيين مهمة تغيير بطاقة الرف' : 'Assign Shelf Tag Change Task'}
						</button>
					{/if}
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

<!-- Shelf Tag User Selection Modal -->
{#if showShelfTagModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="shelf-modal-overlay" on:click={() => showShelfTagModal = false}>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="shelf-modal" on:click|stopPropagation>
			<div class="shelf-modal-header">
				<h3>🏷️ {$locale === 'ar' ? 'تعيين مهمة تغيير بطاقة الرف' : 'Assign Shelf Tag Change Task'}</h3>
				<button class="shelf-modal-close" on:click={() => showShelfTagModal = false}>✕</button>
			</div>
			<div class="shelf-modal-body">
				<p class="shelf-modal-desc">
					{$locale === 'ar' 
						? 'اختر الموظفين لتعيين مهمة تغيير بطاقة الرف لهم. سيتطلب منهم تصوير بطاقة الرف بعد التغيير.'
						: 'Select employees to assign the shelf tag change task. They will be required to take a photo of the shelf tag after changing it.'}
				</p>
				
				{#if loadingBranchUsers}
					<div class="shelf-loading">
						<div class="spinner"></div>
						<p>{$locale === 'ar' ? 'جاري تحميل الموظفين...' : 'Loading employees...'}</p>
					</div>
				{:else if shelfTagBranchUsers.length === 0}
					<p class="no-users-msg">{$locale === 'ar' ? 'لا يوجد موظفين في هذا الفرع' : 'No employees found in this branch'}</p>
				{:else}
					<div class="shelf-search-box">
						<input
							type="text"
							placeholder={$locale === 'ar' ? '🔍 بحث عن موظف...' : '🔍 Search employee...'}
							bind:value={shelfTagSearchQuery}
							class="shelf-search-input"
						/>
					</div>
					<div class="shelf-user-controls">
						<button type="button" class="btn-select-all" on:click={selectAllShelfTagUsers}>
							{shelfTagSelectedUsers.length === shelfTagBranchUsers.length 
								? ($locale === 'ar' ? 'إلغاء تحديد الكل' : 'Deselect All')
								: ($locale === 'ar' ? 'تحديد الكل' : 'Select All')}
						</button>
						<span class="selected-count">
							{shelfTagSelectedUsers.length} / {shelfTagBranchUsers.length} {$locale === 'ar' ? 'محدد' : 'selected'}
						</span>
					</div>
					<div class="shelf-user-list">
						{#each filteredShelfTagUsers as user}
							<button 
								type="button"
								class="shelf-user-item" 
								class:selected={shelfTagSelectedUsers.includes(user.user_id)}
								on:click={() => toggleShelfTagUser(user.user_id)}
							>
								<div class="user-checkbox">
									{#if shelfTagSelectedUsers.includes(user.user_id)}
										<span class="check">✓</span>
									{/if}
								</div>
								<div class="user-info">
									<span class="user-name">{$locale === 'ar' ? (user.name_ar || user.name_en) : user.name_en}</span>
									{#if user.hr_positions}
										<span class="user-position">
											{$locale === 'ar' ? (user.hr_positions.position_title_ar || user.hr_positions.position_title_en || '') : (user.hr_positions.position_title_en || '')}
										</span>
									{/if}
								</div>
							</button>
						{/each}
					</div>
				{/if}
			</div>
			<div class="shelf-modal-footer">
				<button type="button" class="btn-cancel" on:click={() => showShelfTagModal = false}>
					{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
				<button 
					type="button" 
					class="btn-submit" 
					on:click={createShelfTagTask} 
					disabled={shelfTagLoading || shelfTagSelectedUsers.length === 0}
				>
					{#if shelfTagLoading}
						<span class="spinner-small"></span>
						{$locale === 'ar' ? 'جاري الإنشاء...' : 'Creating...'}
					{:else}
						🏷️ {$locale === 'ar' ? `تعيين لـ ${shelfTagSelectedUsers.length} موظف` : `Assign to ${shelfTagSelectedUsers.length} user(s)`}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

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

	/* Shelf Tag Section */
	.shelf-tag-section {
		background: #eff6ff;
		border: 2px solid #60a5fa;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 20px;
	}

	.shelf-tag-section h3 {
		margin: 0 0 8px 0;
		font-size: 15px;
		font-weight: 600;
		color: #1e40af;
	}

	.shelf-tag-desc {
		font-size: 13px;
		color: #3b82f6;
		margin: 0 0 12px 0;
	}

	.shelf-tag-status {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 12px;
		flex-wrap: wrap;
	}

	.shelf-tag-status-badge {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 6px 14px;
		border-radius: 20px;
		font-size: 13px;
		font-weight: 600;
	}

	.shelf-tag-status-badge.completed {
		background: #d1fae5;
		color: #065f46;
		border: 1px solid #6ee7b7;
	}

	.shelf-tag-status-badge.pending {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fbbf24;
	}

	.btn-refresh {
		padding: 6px 12px;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.btn-refresh:hover {
		background: #f3f4f6;
	}

	.btn-shelf-tag {
		padding: 10px 20px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn-shelf-tag:hover:not(:disabled) {
		background: #2563eb;
	}

	.btn-shelf-tag:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Shelf Tag Modal */
	.shelf-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
	}

	.shelf-modal {
		background: white;
		border-radius: 12px;
		width: 500px;
		max-width: 90vw;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
	}

	.shelf-modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px;
		border-bottom: 1px solid #e5e7eb;
	}

	.shelf-modal-header h3 {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
		color: #111827;
	}

	.shelf-modal-close {
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: none;
		border: none;
		font-size: 18px;
		color: #6b7280;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.shelf-modal-close:hover {
		background: #f3f4f6;
		color: #111827;
	}

	.shelf-modal-body {
		flex: 1;
		padding: 16px 20px;
		overflow-y: auto;
	}

	.shelf-modal-desc {
		font-size: 13px;
		color: #6b7280;
		margin: 0 0 16px 0;
		line-height: 1.5;
	}

	.shelf-loading {
		text-align: center;
		padding: 20px;
		color: #6b7280;
	}

	.no-users-msg {
		text-align: center;
		color: #9ca3af;
		font-size: 14px;
		padding: 20px;
	}

	.shelf-search-box {
		margin-bottom: 12px;
	}

	.shelf-search-input {
		width: 100%;
		padding: 9px 12px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		outline: none;
		transition: border-color 0.2s;
	}

	.shelf-search-input:focus {
		border-color: #3b82f6;
	}

	.shelf-user-controls {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 12px;
	}

	.btn-select-all {
		padding: 6px 14px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-select-all:hover {
		background: #e5e7eb;
	}

	.selected-count {
		font-size: 13px;
		color: #6b7280;
		font-weight: 500;
	}

	.shelf-user-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
		max-height: 300px;
		overflow-y: auto;
	}

	.shelf-user-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 10px 12px;
		background: #f9fafb;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		text-align: left;
		width: 100%;
	}

	.shelf-user-item:hover {
		border-color: #93c5fd;
		background: #eff6ff;
	}

	.shelf-user-item.selected {
		border-color: #3b82f6;
		background: #eff6ff;
	}

	.user-checkbox {
		width: 22px;
		height: 22px;
		border: 2px solid #d1d5db;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		transition: all 0.2s;
	}

	.shelf-user-item.selected .user-checkbox {
		background: #3b82f6;
		border-color: #3b82f6;
	}

	.check {
		color: white;
		font-size: 14px;
		font-weight: 700;
	}

	.user-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.user-name {
		font-size: 14px;
		font-weight: 500;
		color: #111827;
	}

	.user-position {
		font-size: 12px;
		color: #6b7280;
	}

	.shelf-modal-footer {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: 12px;
		padding: 14px 20px;
		border-top: 1px solid #e5e7eb;
	}
</style>
