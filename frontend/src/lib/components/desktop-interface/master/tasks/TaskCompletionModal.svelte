<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { db } from '$lib/utils/supabase';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import FileDownload from '$lib/components/common/FileDownload.svelte';
	
	const dispatch = createEventDispatcher();
	
	// Props
	export let task: any = null; // For MyTasksView compatibility
	export let taskId: string = '';
	export let taskTitle: string = '';
	export let taskDescription: string = '';
	export let requireTaskFinished: boolean = false;
	export let requirePhotoUpload: boolean = false;
	export let requireErpReference: boolean = false;
	export let assignmentId: string = '';
	export let notificationId: string = '';
	export let onClose: () => void = () => {};
	export let onTaskCompleted: () => void = () => {};
	
	// Resolve props from task object if provided
	$: resolvedTaskId = task?.id || taskId;
	$: resolvedTaskTitle = task?.title || taskTitle;
	$: resolvedTaskDescription = task?.description || taskDescription;
	$: resolvedAssignmentId = task?.assignment_id || assignmentId;
	
	// Comprehensive task details - declare these BEFORE reactive statements
	let taskDetails: any = null;
	let taskImages: any[] = [];
	let taskAttachments: any[] = []; // For FileDownload component
	let assignmentDetails: any = null;
	let assignedUsers: any[] = [];
	let showTaskDetails = true;
	let showReassignModal = false;
	let availableUsers: any[] = [];
	let selectedUsersForReassign: Set<string> = new Set();
	let showImageModal = false;
	let selectedImageUrl = '';

	// Component state
	let isLoading = false;
	let isSubmitting = false;
	let errorMessage = '';
	let successMessage = '';
	
	// Completion form data
	let completionData = {
		task_finished_completed: false,
		photo_uploaded_completed: false,
		erp_reference_completed: false,
		erp_reference_number: '',
		completion_notes: ''
	};
	
	// Photo upload
	let photoFile: File | null = null;
	let photoPreview: string | null = null;
	
	// User names for display
	let assignedByUserName = '';
	let assignedToUserName = '';
	
	// Live countdown state
	let liveCountdown = '';
	let countdownInterval: NodeJS.Timeout | null = null;
	
	// Current user
	$: currentUserData = $currentUser;
	
	// Resolve requirement flags from assignment details first, then task object, then props
	$: resolvedRequireTaskFinished = assignmentDetails?.require_task_finished ?? task?.require_task_finished ?? taskDetails?.require_task_finished ?? requireTaskFinished ?? true; // Task finished is always mandatory
	$: resolvedRequirePhotoUpload = assignmentDetails?.require_photo_upload ?? task?.require_photo_upload ?? taskDetails?.require_photo_upload ?? requirePhotoUpload ?? false;
	$: resolvedRequireErpReference = assignmentDetails?.require_erp_reference ?? task?.require_erp_reference ?? taskDetails?.require_erp_reference ?? requireErpReference ?? false;
	
	// Initialize completion data with default unchecked state
	// The user should manually check these when they complete the requirements
	// Note: Don't automatically set completion flags based on requirements - that's wrong logic!
	
	// Debug logging as reactive statement
	$: console.log('🔍 [TaskCompletion] Resolved requirements:', {
		resolvedRequireTaskFinished,
		resolvedRequirePhotoUpload, 
		resolvedRequireErpReference,
		assignmentRequirements: assignmentDetails ? {
			require_task_finished: assignmentDetails.require_task_finished,
			require_photo_upload: assignmentDetails.require_photo_upload,
			require_erp_reference: assignmentDetails.require_erp_reference
		} : 'No assignment details',
		taskRequirements: task ? {
			require_task_finished: task.require_task_finished,
			require_photo_upload: task.require_photo_upload,
			require_erp_reference: task.require_erp_reference
		} : 'No task object',
		propRequirements: { requireTaskFinished, requirePhotoUpload, requireErpReference }
	});
	
	// Calculate completion progress - reactive to completion data changes
	$: completionProgress = calculateProgress(
		completionData.task_finished_completed,
		completionData.erp_reference_number,
		photoFile,
		resolvedRequireTaskFinished,
		resolvedRequirePhotoUpload,
		resolvedRequireErpReference
	);
	
	// Force canSubmit to be recalculated when any relevant data changes
	$: canSubmit = (() => {
		const taskCheck = !resolvedRequireTaskFinished || completionData.task_finished_completed;
		const photoCheck = !resolvedRequirePhotoUpload || !!photoFile;
		const erpCheck = !resolvedRequireErpReference || !!completionData.erp_reference_number?.trim();
		
		console.log('🔍 [TaskCompletion] FORCED canSubmit calculation:', {
			resolvedRequireTaskFinished,
			resolvedRequirePhotoUpload,
			resolvedRequireErpReference,
			taskFinishedCompleted: completionData.task_finished_completed,
			photoFile: !!photoFile,
			erpReference: completionData.erp_reference_number,
			erpTrimmed: completionData.erp_reference_number?.trim(),
			taskCheck,
			photoCheck,
			erpCheck,
			finalCanSubmit: taskCheck && photoCheck && erpCheck
		});
		
		return taskCheck && photoCheck && erpCheck;
	})();
	
	// Auto-update completion flags based on user input
	$: if (completionData.erp_reference_number?.trim()) {
		completionData.erp_reference_completed = true;
	} else {
		completionData.erp_reference_completed = false;
	}
	
	// Debug logging for completion data
	$: console.log('🔍 [TaskCompletion] Completion data updated:', {
		task_finished_completed: completionData.task_finished_completed,
		photo_uploaded_completed: completionData.photo_uploaded_completed,
		erp_reference_completed: completionData.erp_reference_completed,
		erp_reference_number: completionData.erp_reference_number,
		photoFile: !!photoFile,
		canSubmit: canSubmit,
		resolvedRequireTaskFinished,
		resolvedRequirePhotoUpload,
		resolvedRequireErpReference
	});

	// Debug task requirements
	$: console.log('🔍 [TaskCompletion] Task requirements debug:', {
		taskObject: task ? {
			require_task_finished: task.require_task_finished,
			require_photo_upload: task.require_photo_upload,
			require_erp_reference: task.require_erp_reference
		} : 'No task object',
		props: {
			requireTaskFinished,
			requirePhotoUpload,
			requireErpReference
		},
		resolved: {
			resolvedRequireTaskFinished,
			resolvedRequirePhotoUpload,
			resolvedRequireErpReference
		}
	});
	
	function calculateProgress(
		taskFinished?: boolean, 
		erpReference?: string, 
		photo?: File | null, 
		requireTask?: boolean, 
		requirePhoto?: boolean, 
		requireErp?: boolean
	): number {
		let completed = 0;
		let total = 0;
		
		if (resolvedRequireTaskFinished) {
			total++;
			if (completionData.task_finished_completed) completed++;
		}
		if (resolvedRequirePhotoUpload) {
			total++;
			if (photoFile) completed++;
		}
		if (resolvedRequireErpReference) {
			total++;
			if (completionData.erp_reference_number.trim()) completed++;
		}
		
		const progress = total > 0 ? Math.round((completed / total) * 100) : 0;
		console.log('🔍 [TaskCompletion] Progress calculation:', {
			total,
			completed,
			progress,
			taskFinished: completionData.task_finished_completed,
			hasPhoto: !!photoFile,
			erpRef: completionData.erp_reference_number.trim()
		});
		
		return progress;
	}
	
	function checkCanSubmit(): boolean {
		const taskCheck = !resolvedRequireTaskFinished || completionData.task_finished_completed;
		const photoCheck = !resolvedRequirePhotoUpload || !!photoFile;
		const erpCheck = !resolvedRequireErpReference || !!completionData.erp_reference_number.trim();
		
		console.log('🔍 [TaskCompletion] Detailed submit check:', {
			resolvedRequireTaskFinished,
			resolvedRequirePhotoUpload,
			resolvedRequireErpReference,
			taskFinishedCompleted: completionData.task_finished_completed,
			photoFile: !!photoFile,
			erpReference: completionData.erp_reference_number,
			erpTrimmed: completionData.erp_reference_number.trim(),
			taskCheck,
			photoCheck,
			erpCheck,
			finalResult: taskCheck && photoCheck && erpCheck
		});
		
		return taskCheck && photoCheck && erpCheck;
	}

	// Load comprehensive task details
	async function loadTaskDetails() {
		try {
			isLoading = true;
			
			// Debug logging for task ID resolution
			console.log('🔍 [TaskCompletion] Debug values:', {
				task: task,
				taskId: taskId,
				resolvedTaskId: resolvedTaskId,
				taskTitle: taskTitle,
				assignmentId: assignmentId
			});
			
			// Validate taskId
			if (!resolvedTaskId || resolvedTaskId === 'unknown' || resolvedTaskId === 'null') {
				console.error('❌ [TaskCompletion] Invalid task ID detected:', {
					resolvedTaskId,
					task,
					taskId,
					originalProps: { taskId, taskTitle, taskDescription, assignmentId }
				});
				
				// Show user-friendly error message and close modal
				alert('Error: Cannot load task details. The task information is missing or invalid. Please try refreshing the page or contact support.');
				onClose();
				return;
			}
			
			// Load task details
			console.log('🔍 [TaskCompletion] Loading task details for:', resolvedTaskId);
			const taskResult = await db.tasks.getById(resolvedTaskId);
			if (taskResult.data) {
				taskDetails = taskResult.data;
				console.log('✅ [TaskCompletion] Task details loaded:', taskDetails);
			}
			
			// Load task images
			const imageResult = await db.taskImages.getByTaskId(resolvedTaskId);
			if (imageResult.data) {
				taskImages = imageResult.data;
				console.log('🖼️ [TaskCompletion] Task images loaded:', taskImages.length);
			}
			
			// Load task attachments for FileDownload component
			const attachmentResult = await db.taskAttachments.getByTaskId(resolvedTaskId);
			if (attachmentResult.data && attachmentResult.data.length > 0) {
				taskAttachments = attachmentResult.data
					.filter(attachment => attachment && attachment.file_name && attachment.file_path)
					.map(attachment => ({
						id: attachment.id,
						fileName: attachment.file_name || 'Unknown File',
						fileSize: attachment.file_size || 0,
						fileType: attachment.file_type || 'application/octet-stream',
						fileUrl: attachment.file_path && attachment.file_path.startsWith('http') 
							? attachment.file_path 
							: `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
						downloadUrl: attachment.file_path && attachment.file_path.startsWith('http') 
							? attachment.file_path 
							: `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
						uploadedBy: attachment.uploaded_by_name || attachment.uploaded_by || 'Unknown',
						uploadedAt: attachment.created_at
					}));
				console.log('📎 [TaskCompletion] Task attachments loaded:', taskAttachments.length);
			} else {
				taskAttachments = [];
			}
			
			// Load assignment details
			if (resolvedAssignmentId && resolvedAssignmentId !== 'unknown' && resolvedAssignmentId !== 'null') {
				console.log('📋 [TaskCompletion] Loading assignment details for:', resolvedAssignmentId);
				try {
					const assignmentResult = await db.taskAssignments.getById(resolvedAssignmentId);
					console.log('📋 [TaskCompletion] Assignment query result:', assignmentResult);
					if (assignmentResult.data) {
						assignmentDetails = assignmentResult.data;
						console.log('✅ [TaskCompletion] Assignment details loaded:', assignmentDetails);
						
						// Fetch assigned by user name
						if (assignmentDetails.assigned_by) {
							const assignedByResult = await db.users.getById(assignmentDetails.assigned_by);
							if (assignedByResult.data) {
								// Try to get employee name if user has employee_id
								if (assignedByResult.data.employee_id) {
									const employeeResult = await db.employees.getById(assignedByResult.data.employee_id);
									if (employeeResult.data && employeeResult.data.name) {
										assignedByUserName = employeeResult.data.name;
									} else {
										assignedByUserName = assignedByResult.data.username || assignmentDetails.assigned_by_name || 'Unknown User';
									}
								} else {
									assignedByUserName = assignedByResult.data.username || assignmentDetails.assigned_by_name || 'Unknown User';
								}
							} else {
								assignedByUserName = assignmentDetails.assigned_by_name || 'Unknown User';
							}
						}
						
						// Fetch assigned to user name
						if (assignmentDetails.assigned_to_user_id) {
							const assignedToResult = await db.users.getById(assignmentDetails.assigned_to_user_id);
							if (assignedToResult.data) {
								// Try to get employee name if user has employee_id
								if (assignedToResult.data.employee_id) {
									const employeeResult = await db.employees.getById(assignedToResult.data.employee_id);
									if (employeeResult.data && employeeResult.data.name) {
										assignedToUserName = employeeResult.data.name;
									} else {
										assignedToUserName = assignedToResult.data.username || 'Unknown User';
									}
								} else {
									assignedToUserName = assignedToResult.data.username || 'Unknown User';
								}
							} else {
								assignedToUserName = 'Unknown User';
							}
						} else {
							assignedToUserName = 'Not assigned to specific user';
						}
						
						console.log('👥 [TaskCompletion] User names loaded:', {
							assignedBy: assignedByUserName,
							assignedTo: assignedToUserName
						});
						
						console.log('🎯 [TaskCompletion] Completion criteria from assignment:');
						console.log('  - require_task_finished:', assignmentDetails.require_task_finished);
						console.log('  - require_photo_upload:', assignmentDetails.require_photo_upload);
						console.log('  - require_erp_reference:', assignmentDetails.require_erp_reference);
						console.log('🔍 [TaskCompletion] Deadline info check:');
						console.log('  - deadline_date:', assignmentDetails.deadline_date);
						console.log('  - deadline_time:', assignmentDetails.deadline_time); 
						console.log('  - deadline_datetime:', assignmentDetails.deadline_datetime);
						
						// Check if assignment has deadline information
						if (assignmentDetails.deadline_datetime || assignmentDetails.deadline_date) {
							console.log('⏰ [TaskCompletion] Assignment has deadline:', 
								assignmentDetails.deadline_datetime || assignmentDetails.deadline_date);
						} else {
							console.log('⚠️ [TaskCompletion] No deadline found in assignment details');
						}
						
						// Start the live countdown timer
						startCountdownTimer();
						
						// Check if reassignment is enabled
						if (assignmentDetails.is_reassignable) {
							console.log('🔄 [TaskCompletion] Assignment is reassignable');
						}
					} else {
						console.log('❌ [TaskCompletion] Failed to load assignment details:', assignmentResult.error);
					}
				} catch (assignmentError) {
					console.error('❌ [TaskCompletion] Error loading assignment details:', assignmentError);
				}
			} else {
				console.log('⚠️ [TaskCompletion] No valid assignment ID provided:', resolvedAssignmentId);
			}
			
			// Load all users for reassignment functionality
			const usersResult = await db.users.getAll();
			if (usersResult.data) {
				availableUsers = usersResult.data.filter(user => user.status === 'active');
				console.log('👥 [TaskCompletion] Available users loaded:', availableUsers.length);
			}
			
		} catch (error) {
			console.error('❌ [TaskCompletion] Error loading task details:', error);
			errorMessage = 'Failed to load task details';
		} finally {
			isLoading = false;
		}
	}

	// Image modal functions
	function openImageModal(imageUrl: string) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}
	
	function closeImageModal() {
		showImageModal = false;
		selectedImageUrl = '';
	}
	
	// File download function
	async function downloadFile(fileUrl: string, fileName: string) {
		try {
			const response = await fetch(fileUrl);
			if (!response.ok) throw new Error('Download failed');
			
			const blob = await response.blob();
			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = fileName;
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Download error:', error);
			// You could add a toast notification here if you have one
		}
	}	// Reassignment functions
	function openReassignModal() {
		showReassignModal = true;
		selectedUsersForReassign.clear();
	}

	function closeReassignModal() {
		showReassignModal = false;
		selectedUsersForReassign.clear();
	}

	function toggleUserSelection(userId: string) {
		if (selectedUsersForReassign.has(userId)) {
			selectedUsersForReassign.delete(userId);
		} else {
			selectedUsersForReassign.add(userId);
		}
		selectedUsersForReassign = new Set(selectedUsersForReassign);
	}

	async function reassignTask() {
		if (selectedUsersForReassign.size === 0) {
			errorMessage = 'Please select at least one user to reassign the task to';
			return;
		}

		try {
			isSubmitting = true;
			
			// Use the new reassign_task database function for each selected user
			for (const userId of selectedUsersForReassign) {
				const { data, error } = await supabase.rpc('reassign_task', {
					p_assignment_id: resolvedAssignmentId,
					p_reassigned_by: currentUser?.id || '',
					p_new_user_id: userId,
					p_reassignment_reason: `Reassigned from task completion modal by ${currentUser?.employeeName || currentUser?.username || 'Unknown'}`,
					p_copy_deadline: true
				});

				if (error) {
					throw new Error(`Failed to reassign to user ${userId}: ${error.message}`);
				}
				
				console.log(`✅ [TaskCompletion] Task reassigned to user ${userId}, new assignment ID:`, data);
			}

			successMessage = `Task successfully reassigned to ${selectedUsersForReassign.size} user(s)`;
			closeReassignModal();
			
			// Close the current modal since the task has been reassigned
			setTimeout(() => {
				onClose();
			}, 2000);
			
		} catch (error) {
			console.error('❌ [TaskCompletion] Error reassigning task:', error);
			errorMessage = error.message || 'Failed to reassign task';
		} finally {
			isSubmitting = false;
		}
	}

		// Date and time utility functions
	function formatDate(dateString: string): string {
		if (!dateString) return 'Not set';
		try {
			return new Date(dateString).toLocaleDateString('en-US', {
				year: 'numeric',
				month: 'short',
				day: 'numeric'
			});
		} catch {
			return 'Invalid date';
		}
	}

	function formatTime(datetimeString: string): string {
		if (!datetimeString) return '';
		try {
			return new Date(datetimeString).toLocaleTimeString('en-US', {
				hour: '2-digit',
				minute: '2-digit'
			});
		} catch {
			return '';
		}
	}

	function isOverdue(deadlineString: string): boolean {
		if (!deadlineString) return false;
		try {
			return new Date(deadlineString) < new Date();
		} catch {
			return false;
		}
	}

	function getOverdueTime(deadlineString: string): string {
		if (!deadlineString) return '';
		try {
			const deadline = new Date(deadlineString);
			const now = new Date();
			const diffMs = now.getTime() - deadline.getTime();
			const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
			const diffDays = Math.floor(diffHours / 24);
			
			if (diffDays > 0) {
				return `${diffDays} day${diffDays !== 1 ? 's' : ''}`;
			} else {
				return `${diffHours} hour${diffHours !== 1 ? 's' : ''}`;
			}
		} catch {
			return 'Unknown';
		}
	}

	function getTimeUntilDeadline(deadlineString: string): string {
		if (!deadlineString) return '';
		try {
			const deadline = new Date(deadlineString);
			const now = new Date();
			const diffMs = deadline.getTime() - now.getTime();
			
			// If past deadline
			if (diffMs <= 0) {
				return 'Overdue';
			}
			
			const diffMinutes = Math.floor(diffMs / (1000 * 60));
			const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
			const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
			
			// Calculate exact time remaining
			const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
			const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
			const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
			
			// Format the countdown string
			let timeString = '';
			if (days > 0) {
				timeString += `${days} day${days !== 1 ? 's' : ''}`;
			}
			if (hours > 0) {
				if (timeString) timeString += ', ';
				timeString += `${hours} hour${hours !== 1 ? 's' : ''}`;
			}
			if (minutes > 0 || timeString === '') {
				if (timeString) timeString += ', ';
				timeString += `${minutes} minute${minutes !== 1 ? 's' : ''}`;
			}
			
			return timeString;
		} catch {
			return 'Unknown';
		}
	}

	function updateLiveCountdown() {
		const deadlineString = assignmentDetails?.deadline_datetime || assignmentDetails?.deadline_date;
		if (deadlineString) {
			liveCountdown = getTimeUntilDeadline(deadlineString);
		} else {
			liveCountdown = '';
		}
	}

	function startCountdownTimer() {
		// Clear any existing interval
		if (countdownInterval) {
			clearInterval(countdownInterval);
		}
		
		// Update immediately
		updateLiveCountdown();
		
		// Update every minute (60000 ms)
		countdownInterval = setInterval(updateLiveCountdown, 60000);
	}

	function stopCountdownTimer() {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
	}

	function getPriorityColor(priority: string): string {
		switch (priority?.toLowerCase()) {
			case 'high':
			case 'urgent':
				return 'priority-high';
			case 'medium':
				return 'priority-medium';
			case 'low':
				return 'priority-low';
			default:
				return 'priority-medium';
		}
	}

	// Load data on component mount
	onMount(() => {
		loadTaskDetails();
	});
	
	// Cleanup timer on component destroy
	onDestroy(() => {
		stopCountdownTimer();
	});
	
	async function handlePhotoUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			// Validate file type and size
			if (!file.type.startsWith('image/')) {
				errorMessage = 'Please select a valid image file';
				return;
			}
			
			if (file.size > 5 * 1024 * 1024) { // 5MB limit
				errorMessage = 'Image file must be less than 5MB';
				return;
			}
			
			photoFile = file;
			
			// Create preview
			const reader = new FileReader();
			reader.onload = (e) => {
				photoPreview = e.target?.result as string;
			};
			reader.readAsDataURL(file);
			
			// Mark photo as uploaded when file is selected
			completionData.photo_uploaded_completed = true;
			errorMessage = '';
		}
	}
	
	function removePhoto() {
		photoFile = null;
		photoPreview = null;
		completionData.photo_uploaded_completed = false;
		
		// Reset file input
		const fileInput = document.getElementById('photo-upload') as HTMLInputElement;
		if (fileInput) {
			fileInput.value = '';
		}
	}
	
	async function uploadPhoto(): Promise<string | null> {
		if (!photoFile || !currentUserData) return null;
		
		try {
			const fileExt = photoFile.name.split('.').pop();
			const fileName = `task-completion-${resolvedTaskId}-${Date.now()}.${fileExt}`;
			
			console.log('📤 [TaskCompletion] Uploading photo:', {
				fileName,
				fileSize: photoFile.size,
				fileType: photoFile.type,
				currentUser: currentUserData.id,
				bucket: 'completion-photos'
			});
			
			const { data, error } = await supabase.storage
				.from('completion-photos')
				.upload(fileName, photoFile, {
					cacheControl: '3600',
					upsert: false
				});
			
			if (error) {
				console.error('❌ [TaskCompletion] Storage upload error:', error);
				throw error;
			}
			
			console.log('✅ [TaskCompletion] Photo uploaded successfully:', data);
			
			// Get public URL
			const { data: urlData } = supabase.storage
				.from('completion-photos')
				.getPublicUrl(fileName);
			
			console.log('🔗 [TaskCompletion] Public URL generated:', urlData.publicUrl);
			return urlData.publicUrl;
		} catch (error) {
			console.error('❌ [TaskCompletion] Error uploading photo:', error);
			// For now, let's skip photo upload if there's a permission issue
			console.warn('⚠️ [TaskCompletion] Skipping photo upload due to storage permissions');
			return null;
		}
	}
	
	async function submitCompletion() {
		if (!currentUserData || !canSubmit) return;
		
		isSubmitting = true;
		errorMessage = '';
		successMessage = '';
		
		try {
			let photoUrl = null;
			
			// Upload photo if required and provided
			if (resolvedRequirePhotoUpload && photoFile) {
				try {
					photoUrl = await uploadPhoto();
					if (!photoUrl) {
						console.warn('⚠️ [TaskCompletion] Photo upload failed, continuing without photo');
					}
				} catch (uploadError) {
					console.error('❌ [TaskCompletion] Photo upload failed:', uploadError);
					// Continue with task completion even if photo upload fails
					console.warn('⚠️ [TaskCompletion] Continuing task completion without photo due to upload error');
				}
			}
			
			// Create completion record
			const completionRecord = {
				task_id: resolvedTaskId,
				assignment_id: resolvedAssignmentId,
				completed_by: currentUserData.id,
				completed_by_name: currentUserData.employeeName || currentUserData.name || currentUserData.username,
				// Note: completed_by_branch_id removed - branch_id is bigint, not uuid. Branch info can be retrieved from users table via completed_by.
				task_finished_completed: resolvedRequireTaskFinished ? completionData.task_finished_completed : null,
				photo_uploaded_completed: resolvedRequirePhotoUpload ? (photoUrl ? true : false) : null, // Only true if we have a URL
				completion_photo_url: photoUrl, // Store the photo URL in completion record
				erp_reference_completed: resolvedRequireErpReference ? completionData.erp_reference_completed : null,
				erp_reference_number: resolvedRequireErpReference ? completionData.erp_reference_number : null,
				completion_notes: completionData.completion_notes || null,
				completed_at: new Date().toISOString()
			};
			
			console.log('💾 [TaskCompletion] Creating completion record:', completionRecord);
			
			// Insert completion record
			const { data, error } = await supabase
				.from('task_completions')
				.insert([completionRecord])
				.select()
				.single();
			
			if (error) throw error;
			
			console.log('✅ [TaskCompletion] Completion record created successfully:', data);
			
			// Update task assignment status
			const { error: assignmentError } = await supabase
				.from('task_assignments')
				.update({ 
					status: 'completed',
					completed_at: new Date().toISOString()
				})
				.eq('id', resolvedAssignmentId);
			
			if (assignmentError) {
				console.error('Error updating assignment status:', assignmentError);
			}
			
			// If this is a payment task with ERP reference, update vendor_payment_schedule
			// ONLY for tasks that are specifically payment-related (with payment_schedule_id in metadata)
			if (resolvedRequireErpReference && completionData.erp_reference_number?.trim()) {
				try {
					// Get task metadata to check if this is a payment task
					const { data: taskData, error: taskError } = await supabase
						.from('tasks')
						.select('metadata')
						.eq('id', resolvedTaskId)
						.single();
					
					// Only update if this task has payment_schedule_id in metadata (payment tasks only)
					if (taskData?.metadata?.payment_schedule_id && taskData?.metadata?.payment_type === 'vendor_payment') {
						const paymentScheduleId = taskData.metadata.payment_schedule_id;
						console.log('💳 [TaskCompletion] Updating payment_reference for payment schedule:', paymentScheduleId);
						
						// Update payment_reference in vendor_payment_schedule
						const { error: updateError } = await supabase
							.from('vendor_payment_schedule')
							.update({ 
								payment_reference: completionData.erp_reference_number.trim(),
								updated_at: new Date().toISOString()
							})
							.eq('id', paymentScheduleId);
						
						if (updateError) {
							console.error('❌ [TaskCompletion] Failed to update payment_reference:', updateError);
						} else {
							console.log('✅ [TaskCompletion] Payment reference updated successfully');
						}
					} else {
						console.log('ℹ️ [TaskCompletion] Task has ERP reference but is not a payment task, skipping vendor_payment_schedule update');
					}
				} catch (paymentUpdateError) {
					console.error('❌ [TaskCompletion] Error updating payment schedule:', paymentUpdateError);
					// Don't fail task completion if payment update fails
				}
			}
			
			// Mark notification as read
			if (notificationId) {
				await notificationManagement.markAsRead(notificationId, currentUserData.id);
			}
			
			successMessage = 'Task completed successfully!';
			
			// Call the callback function
			if (onTaskCompleted) {
				onTaskCompleted();
			}
			
			// Dispatch completion event
			dispatch('taskCompleted', {
				taskId: resolvedTaskId,
				completionId: data.id,
				completionData: completionRecord
			});
			
			// Close modal after short delay
			setTimeout(() => {
				dispatch('close');
				onClose();
			}, 2000);
			
		} catch (error) {
			console.error('Error submitting completion:', error);
			errorMessage = error.message || 'Failed to complete task';
		} finally {
			isSubmitting = false;
		}
	}
	
	function handleClose() {
		dispatch('close');
	}
</script>

<div class="task-completion-modal">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h2 class="title">Complete Task</h2>
			<p class="task-title">{taskTitle}</p>
		</div>
		<button class="close-btn" on:click={handleClose}>
			<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
			</svg>
		</button>
	</div>

	<!-- Loading State -->
	{#if isLoading}
		<div class="loading-section">
			<div class="loading-spinner"></div>
			<p>Loading task details...</p>
		</div>
	{:else}
		<!-- Comprehensive Task Details Section -->
		<div class="task-details-section">
			<div class="details-header">
				<h3>📋 Task Details</h3>
				<button 
					class="toggle-btn"
					on:click={() => showTaskDetails = !showTaskDetails}
				>
					{showTaskDetails ? '▼' : '▶'} {showTaskDetails ? 'Hide' : 'Show'} Details
				</button>
			</div>

			{#if showTaskDetails && taskDetails}
				<div class="details-content">
					<!-- Basic Task Information -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>📝 Title:</label>
							<span class="value">{taskDetails.title}</span>
						</div>
						
						<div class="detail-item">
							<label>🎯 Priority:</label>
							<span class="priority-badge {getPriorityColor(taskDetails.priority)}">
								{taskDetails.priority?.toUpperCase() || 'MEDIUM'}
							</span>
						</div>
						
						<div class="detail-item">
							<label>📅 Created:</label>
							<span class="value">{formatDate(taskDetails.created_at)}</span>
						</div>
						
						<div class="detail-item">
							<label>⏰ Deadline:</label>
							<span class="value">
								{#if assignmentDetails?.deadline_datetime}
									{formatDate(assignmentDetails.deadline_datetime)} at {formatTime(assignmentDetails.deadline_datetime)}
								{:else if assignmentDetails?.deadline_date}
									{formatDate(assignmentDetails.deadline_date)}
									{#if assignmentDetails?.deadline_time}
										at {assignmentDetails.deadline_time}
									{/if}
								{:else}
									No deadline set
								{/if}
							</span>
						</div>

						{#if assignmentDetails?.deadline_datetime || assignmentDetails?.deadline_date}
							<div class="detail-item">
								<label>⚠️ Status:</label>
								<span class="value {isOverdue(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date) ? 'overdue' : 'on-time'}">
									{#if isOverdue(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date)}
										Overdue by {getOverdueTime(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date)}
									{:else}
										{liveCountdown} remaining
									{/if}
								</span>
							</div>
						{/if}

						{#if assignmentDetails?.schedule_date}
							<div class="detail-item">
								<label>📅 Scheduled:</label>
								<span class="value">
									{formatDate(assignmentDetails.schedule_date)}
									{#if assignmentDetails?.schedule_time}
										at {assignmentDetails.schedule_time}
									{/if}
								</span>
							</div>
						{/if}

						{#if assignmentDetails}
							<div class="detail-item">
								<label>📌 Assigned to:</label>
								<span class="value">{assignedToUserName}</span>
							</div>
							
							<div class="detail-item">
								<label>👤 Assigned by:</label>
								<span class="value">{assignedByUserName}</span>
							</div>
							
							<div class="detail-item">
								<label>� Assignment date:</label>
								<span class="value">{formatDate(assignmentDetails.assigned_at)}</span>
							</div>
						{/if}
					</div>

					<!-- Task Description -->
					{#if taskDetails.description}
						<div class="description-block">
							<label>📄 Description:</label>
							<div class="description-text">{taskDetails.description}</div>
						</div>
					{/if}

					<!-- Assignment Notes -->
					{#if assignmentDetails?.notes}
						<div class="description-block">
							<label>📝 Assignment Notes:</label>
							<div class="description-text">{assignmentDetails.notes}</div>
						</div>
					{/if}

					<!-- Task Reassignment Section -->
					{#if assignmentDetails?.is_reassignable && !isOverdue(assignmentDetails?.deadline_datetime)}
						<div class="reassignment-section">
							<div class="section-header">
								<h3>🔄 Task Reassignment</h3>
								<p>This task can be reassigned to other users</p>
							</div>
							<button 
								class="reassign-btn"
								on:click={openReassignModal}
								disabled={isSubmitting}
							>
								👥 Reassign Task
							</button>
						</div>
					{/if}

					<!-- Task Attachments -->
					{#if taskAttachments.length > 0}
						<div class="attachments-section">
							<label>� Task Files:</label>
							<FileDownload 
								files={taskAttachments}
								showDetails={true}
								compact={false}
								maxHeight="200px"
								on:download={(e) => console.log('Downloaded:', e.detail.file)}
								on:preview={(e) => console.log('Previewed:', e.detail.file)}
							/>
						</div>
					{/if}

					<!-- Reassignment Section -->
					{#if assignmentDetails?.enable_reassigning}
						<div class="reassign-section">
							<label>🔄 Reassignment:</label>
							<button 
								class="reassign-btn"
								on:click={openReassignModal}
								disabled={isSubmitting}
							>
								👥 Reassign Task
							</button>
							<p class="reassign-note">This task can be reassigned to other users</p>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}
	
	<!-- Progress Bar -->
	<div class="progress-section">
		<div class="progress-label">
			Completion Progress: {completionProgress}%
		</div>
		<div class="progress-bar">
			<div class="progress-fill" style="width: {completionProgress}%"></div>
		</div>
	</div>
	
	<!-- Task Description -->
	{#if taskDescription}
		<div class="description-section">
			<h3>Task Description:</h3>
			<p>{taskDescription}</p>
		</div>
	{/if}
	
	<!-- Messages -->
	{#if errorMessage}
		<div class="message error">
			<span class="icon">❌</span>
			{errorMessage}
		</div>
	{/if}
	
	{#if successMessage}
		<div class="message success">
			<span class="icon">✅</span>
			{successMessage}
		</div>
	{/if}
	
	<!-- Completion Form -->
	<div class="completion-form">
		<h3>Completion Requirements:</h3>
		
		<!-- Scrollable Requirements Container -->
		<div class="requirements-container">
			<!-- Task Finished -->
			{#if resolvedRequireTaskFinished}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="label-text required">✅ Task Finished (Required)</span>
						<input
							type="checkbox"
							bind:checked={completionData.task_finished_completed}
							disabled={isSubmitting}
							class="completion-checkbox"
						/>
					</div>
				</div>
			{/if}
			
			<!-- Photo Upload -->
			{#if resolvedRequirePhotoUpload}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="label-text required">📷 Upload Photo (Required)</span>
					</div>
					
					{#if !photoPreview}
						<div class="upload-section">
							<input
								id="photo-upload"
								type="file"
								accept="image/*"
								on:change={handlePhotoUpload}
								disabled={isSubmitting}
								class="file-input"
								required
							/>
							<label for="photo-upload" class="upload-btn">
								<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
								</svg>
								Choose Photo
							</label>
						</div>
					{:else}
						<div class="photo-preview">
							<img src={photoPreview} alt="Task completion" class="preview-image" />
							<button class="remove-photo" on:click={removePhoto} disabled={isSubmitting}>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
								</svg>
							</button>
						</div>
					{/if}
				</div>
			{/if}
			
			<!-- ERP Reference -->
			{#if resolvedRequireErpReference}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="label-text required">🔢 ERP Reference (Required)</span>
					</div>
					
					<div class="input-section">
						<input
							type="text"
							bind:value={completionData.erp_reference_number}
							placeholder="Enter ERP reference number"
							disabled={isSubmitting}
							class="erp-input"
							required
						/>
					</div>
				</div>
			{/if}
			
			<!-- Completion Notes -->
			<div class="notes-section">
				<label for="completion-notes">Additional Notes (optional):</label>
				<textarea
					id="completion-notes"
					bind:value={completionData.completion_notes}
					placeholder="Add any additional notes about the task completion..."
					disabled={isSubmitting}
					class="notes-textarea"
				></textarea>
			</div>
		</div>
	</div>
	
	<!-- Actions -->
	<div class="actions">
		<button class="cancel-btn" on:click={handleClose} disabled={isSubmitting}>
			Cancel
		</button>
		<button 
			class="complete-btn" 
			on:click={submitCompletion} 
			disabled={!canSubmit || isSubmitting}
		>
			{#if isSubmitting}
				<div class="loading-spinner"></div>
				Completing...
			{:else}
				Complete Task
			{/if}
		</button>
	</div>
</div>

<!-- Reassignment Modal -->
{#if showReassignModal}
	<div class="modal-overlay" on:click={closeReassignModal}>
		<div class="reassign-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>👥 Reassign Task</h3>
				<button class="close-btn" on:click={closeReassignModal}>×</button>
			</div>
			
			<div class="modal-body">
				<p class="reassign-info">Select users to reassign this task to:</p>
				
				<div class="users-list">
					{#each availableUsers as user}
						<label class="user-item">
							<input
								type="checkbox"
								checked={selectedUsersForReassign.has(user.id)}
								on:change={() => toggleUserSelection(user.id)}
							/>
							<div class="user-info">
								<span class="user-name">{user.username}</span>
								<span class="user-role">{user.role_type}</span>
							</div>
						</label>
					{/each}
				</div>
			</div>
			
			<div class="modal-actions">
				<button class="cancel-btn" on:click={closeReassignModal}>Cancel</button>
				<button 
					class="reassign-confirm-btn" 
					on:click={reassignTask}
					disabled={selectedUsersForReassign.size === 0 || isSubmitting}
				>
					{#if isSubmitting}
						<div class="loading-spinner"></div>
						Reassigning...
					{:else}
						Reassign Task ({selectedUsersForReassign.size})
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Image Modal -->
{#if showImageModal}
	<div class="modal-overlay" on:click={closeImageModal}>
		<div class="image-modal" on:click|stopPropagation>
			<button class="image-close-btn" on:click={closeImageModal}>
				<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
				</svg>
			</button>
			<img
				src={selectedImageUrl}
				alt="Task image full size"
				class="modal-image"
			/>
		</div>
	</div>
{/if}

<style>
	.task-completion-modal {
		height: 100%;
		max-height: 100vh;
		background: #ffffff;
		overflow-y: auto; /* Make the whole window scrollable */
		/* Custom scrollbar styling for the entire window */
		scrollbar-width: auto; /* Firefox - always show scrollbar */
		scrollbar-color: #888 #f1f1f1; /* Firefox */
	}
	
	/* WebKit scrollbar styling for the entire modal window */
	.task-completion-modal::-webkit-scrollbar {
		width: 12px; /* Wider scrollbar for better visibility */
		display: block !important; /* Force display */
	}
	
	.task-completion-modal::-webkit-scrollbar-track {
		background: #f1f1f1;
		border-radius: 6px;
		border: 1px solid #ddd;
	}
	
	.task-completion-modal::-webkit-scrollbar-thumb {
		background: #888;
		border-radius: 6px;
		border: 1px solid #666;
		min-height: 20px; /* Minimum thumb size */
	}
	
	.task-completion-modal::-webkit-scrollbar-thumb:hover {
		background: #555;
	}
	
	.header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		padding: 20px;
		border-bottom: 1px solid #e5e7eb;
	}
	
	.title-section {
		flex: 1;
	}
	
	.title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}
	
	.task-title {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		font-weight: 500;
	}
	
	.close-btn {
		background: none;
		border: none;
		cursor: pointer;
		color: #6b7280;
		padding: 4px;
		border-radius: 4px;
		transition: color 0.2s;
	}
	
	.close-btn:hover {
		color: #374151;
	}
	
	.progress-section {
		padding: 16px 20px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}
	
	.progress-label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 8px;
	}
	
	.progress-bar {
		width: 100%;
		height: 8px;
		background: #e5e7eb;
		border-radius: 4px;
		overflow: hidden;
	}
	
	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #10b981, #059669);
		border-radius: 4px;
		transition: width 0.3s ease;
	}
	
	.description-section {
		padding: 16px 20px;
		border-bottom: 1px solid #e5e7eb;
	}
	
	.description-section h3 {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 8px 0;
	}
	
	.description-section p {
		font-size: 14px;
		color: #6b7280;
		line-height: 1.5;
		margin: 0;
	}
	
	.message {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 20px;
		font-size: 14px;
		font-weight: 500;
	}
	
	.message.error {
		background: #fef2f2;
		color: #dc2626;
		border-bottom: 1px solid #fecaca;
	}
	
	.message.success {
		background: #f0fdf4;
		color: #059669;
		border-bottom: 1px solid #bbf7d0;
	}
	
	.completion-form {
		padding: 20px;
		/* Remove flex properties to make it behave as normal content */
	}
	
	.completion-form h3 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}
	
	.requirements-container {
		/* Remove flex properties - let it behave as normal block content */
		padding: 12px;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		background: #fafafa;
		margin-bottom: 20px; /* Add spacing before action buttons */
	}
	
	.requirement-item {
		margin-bottom: 20px;
		padding: 16px;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		background: #f9fafb;
	}
	
	.requirement-header {
		margin-bottom: 12px;
	}
	
	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}
	
	.checkbox-label input[type="checkbox"] {
		width: 16px;
		height: 16px;
		border: 2px solid #d1d5db;
		border-radius: 4px;
		background: white;
		cursor: pointer;
	}
	
	.checkbox-label input[type="checkbox"]:checked {
		background: #10b981;
		border-color: #10b981;
	}
	
	.label-text {
		font-weight: 500;
	}
	
	.upload-section {
		margin-top: 12px;
	}
	
	.file-input {
		display: none;
	}
	
	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}
	
	.upload-btn:hover {
		background: #2563eb;
	}
	
	.photo-preview {
		position: relative;
		display: inline-block;
		margin-top: 12px;
	}
	
	.preview-image {
		width: 120px;
		height: 120px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
	}
	
	.remove-photo {
		position: absolute;
		top: -8px;
		right: -8px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s;
	}
	
	.remove-photo:hover {
		background: #dc2626;
	}
	
	.input-section {
		margin-top: 12px;
	}
	
	.erp-input {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}
	
	.erp-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.notes-section {
		margin-top: 20px;
	}
	
	.notes-section label {
		display: block;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 8px;
	}
	
	.notes-textarea {
		width: 100%;
		min-height: 80px;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		resize: vertical;
	}
	
	.notes-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		padding: 20px;
		border-top: 1px solid #e5e7eb;
		background: #f9fafb;
	}
	
	.cancel-btn {
		padding: 8px 16px;
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}
	
	.cancel-btn:hover {
		background: #e5e7eb;
	}
	
	.complete-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}
	
	.complete-btn:hover:not(:disabled) {
		background: #059669;
	}
	
	.complete-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	
	.loading-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}
	
	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
	
	/* New styles for updated completion criteria */
	.requirement-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 12px;
	}
	
	.label-text.required {
		color: #dc2626;
		font-weight: 600;
		font-size: 14px;
	}
	
	.label-text.completed {
		color: #059669;
		font-weight: 600;
		font-size: 14px;
	}
	
	.completion-checkbox {
		width: 18px;
		height: 18px;
		accent-color: #10b981;
	}
	
	.input-section {
		margin-top: 8px;
	}
	
	.erp-input {
		width: 100%;
		padding: 8px 12px;
		border: 2px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}
	
	.erp-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.erp-input:required:invalid {
		border-color: #dc2626;
	}

	/* New Comprehensive Task Details Styles */
	.task-details {
		margin-bottom: 1.5rem;
	}

	.detail-section {
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		margin-bottom: 1rem;
		overflow: hidden;
	}

	.section-header {
		background: none;
		border: none;
		width: 100%;
		padding: 1rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		cursor: pointer;
		background: #f9fafb;
		font-weight: 600;
		color: #1f2937;
		transition: background-color 0.2s;
	}

	.section-header:hover {
		background: #f3f4f6;
	}

	.section-content {
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.detail-item {
		background: #f9fafb;
		padding: 1rem;
		border-radius: 0.375rem;
		border: 1px solid #e5e7eb;
	}

	.detail-label {
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.25rem;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.detail-value {
		color: #1f2937;
		font-size: 0.875rem;
	}

	.priority-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 1rem;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.description-content {
		background: #f9fafb;
		padding: 1rem;
		border-radius: 0.375rem;
		border: 1px solid #e5e7eb;
		white-space: pre-wrap;
		color: #1f2937;
		line-height: 1.6;
	}

	.assignment-info {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.attachments-section {
		margin-top: 1rem;
	}

	.attachments-section label {
		display: block;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin-bottom: 8px;
	}

	.no-images {
		text-align: center;
		color: #6b7280;
		padding: 2rem;
		background: #f9fafb;
		border-radius: 0.5rem;
		border: 1px dashed #d1d5db;
	}

	.reassign-section {
		margin-top: 1.5rem;
		padding-top: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.reassign-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.375rem;
		cursor: pointer;
		font-weight: 600;
		transition: background-color 0.2s;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.reassign-btn:hover {
		background: #2563eb;
	}

	/* Reassignment Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		justify-content: center;
		align-items: center;
		z-index: 1100;
	}

	.reassign-modal {
		background: white;
		border-radius: 0.5rem;
		width: 90%;
		max-width: 500px;
		max-height: 80vh;
		overflow: hidden;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
		display: flex;
		flex-direction: column;
	}

	.reassign-modal .modal-header h3 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.reassign-info {
		color: #6b7280;
		margin-bottom: 1rem;
		font-size: 0.875rem;
	}

	.users-list {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 0.375rem;
	}

	.user-item {
		display: flex;
		align-items: center;
		padding: 0.75rem;
		border-bottom: 1px solid #f3f4f6;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.user-item:last-child {
		border-bottom: none;
	}

	.user-item:hover {
		background: #f9fafb;
	}

	.user-item input[type="checkbox"] {
		margin-right: 0.75rem;
	}

	.user-info {
		display: flex;
		flex-direction: column;
	}

	.user-name {
		font-weight: 600;
		color: #1f2937;
		font-size: 0.875rem;
	}

	.user-role {
		color: #6b7280;
		font-size: 0.75rem;
		text-transform: uppercase;
	}

	.reassign-confirm-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.375rem;
		cursor: pointer;
		font-weight: 600;
		transition: background-color 0.2s;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.reassign-confirm-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.reassign-confirm-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	/* Image Modal Styles */
	.image-modal {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		justify-content: center;
		align-items: center;
	}

	.image-close-btn {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 3rem;
		height: 3rem;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		z-index: 10;
		transition: background-color 0.2s;
	}

	.image-close-btn:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	.image-close-btn svg {
		width: 1.5rem;
		height: 1.5rem;
	}

	.modal-image {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
		border-radius: 0.5rem;
	}

	.reassignment-section {
		margin-top: 1.5rem;
		padding: 1.5rem;
		background: #f8f9fa;
		border: 1px solid #e9ecef;
		border-radius: 0.5rem;
	}

	.reassignment-section .section-header h3 {
		margin: 0 0 0.5rem 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.reassignment-section .section-header p {
		margin: 0 0 1rem 0;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.reassign-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.375rem;
		cursor: pointer;
		font-weight: 600;
		transition: background-color 0.2s;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.reassign-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.reassign-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.overdue {
		color: #dc2626;
		font-weight: 600;
	}

	.on-time {
		color: #16a34a;
		font-weight: 500;
	}

	/* Additional responsive styles */
	@media (max-width: 768px) {
		.detail-grid {
			grid-template-columns: 1fr;
		}

		.assignment-info {
			grid-template-columns: 1fr;
		}

		.images-grid {
			grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
		}

		.reassign-modal {
			width: 95%;
		}
	}
</style>