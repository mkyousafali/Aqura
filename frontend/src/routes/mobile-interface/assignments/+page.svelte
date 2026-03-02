<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase, getStoragePublicUrl, resolveStorageUrl } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';
	import { locale, getTranslation } from '$lib/i18n';

	// Data
	let allAssignments = []; // Full dataset for stats
	let assignments = []; // Display dataset (filtered by showCompleted)
	let filteredAssignments = [];
	let totalStats = {
		total: 0,
		completed: 0,
		in_progress: 0,
		assigned: 0,
		overdue: 0
	};

	// Loading states
	let isLoading = true;

	// Image modal state
	let showImageModal = false;
	let selectedImageUrl = '';

	// Search and filters
	let searchTerm = '';
	let statusFilter = '';
	let priorityFilter = '';
	let showCompleted = false; // Toggle for showing/hiding completed assignments

	// UI state
	let showFilters = false;

	// Helper: batch .in() queries to avoid URL-too-long errors (splits into chunks of 50)
	async function batchedQuery(table: string, selectCols: string, filterCol: string, ids: string[], batchSize = 50) {
		const allResults: any[] = [];
		for (let i = 0; i < ids.length; i += batchSize) {
			const batch = ids.slice(i, i + batchSize);
			const { data, error } = await supabase
				.from(table)
				.select(selectCols)
				.in(filterCol, batch);
			if (error) {
				console.error(`Error querying ${table} (batch ${Math.floor(i / batchSize) + 1}):`, error);
			}
			if (data) allResults.push(...data);
		}
		return allResults;
	}

	onMount(async () => {
		await loadMyAssignments();
	});

	// Load attachments for assignments - optimized batch loading
	async function loadAssignmentAttachments() {
		// Separate assignments by type
		const quickTaskAssignments = assignments.filter(a => a.task_type === 'quick_task');
		const regularTaskAssignments = assignments.filter(a => a.task_type === 'regular');

		// Initialize attachments as empty arrays first
		assignments.forEach(a => { if (!a.attachments) a.attachments = []; });

		// Batch load quick task files
		if (quickTaskAssignments.length > 0) {
			const quickTaskIds = quickTaskAssignments.map(a => a.quick_task_id || a.task_id);
			try {
				const files = await batchedQuery('quick_task_files', '*', 'quick_task_id', quickTaskIds);

				if (files && files.length > 0) {
					// Create a map of quick_task_id to files
					const filesMap = new Map();
					files.forEach(file => {
						if (!filesMap.has(file.quick_task_id)) {
							filesMap.set(file.quick_task_id, []);
						}
						filesMap.get(file.quick_task_id).push({
							...file,
							file_url: getStoragePublicUrl('quick-task-files', file.storage_path),
							source: 'quick_task'
						});
					});

					// Assign files to respective assignments
					quickTaskAssignments.forEach(assignment => {
						const taskId = assignment.quick_task_id || assignment.task_id;
						assignment.attachments = filesMap.get(taskId) || [];
					});
				}
			} catch (error) {
				console.error('Error loading quick task files:', error);
			}
		}

		// Batch load regular task images
		if (regularTaskAssignments.length > 0) {
			const taskIds = regularTaskAssignments.map(a => a.task_id);
			try {
				const images = await batchedQuery('task_images', '*', 'task_id', taskIds);

				if (images && images.length > 0) {
					// Create a map of task_id to images
					const imagesMap = new Map();
					images.forEach(image => {
						if (!imagesMap.has(image.task_id)) {
							imagesMap.set(image.task_id, []);
						}
						imagesMap.get(image.task_id).push({
							...image,
							file_url: getStoragePublicUrl('task-images', image.file_path),
							source: 'task'
						});
					});

					// Assign images to respective assignments
					regularTaskAssignments.forEach(assignment => {
						assignment.attachments = imagesMap.get(assignment.task_id) || [];
					});
				}
			} catch (error) {
				console.error('Error loading task images:', error);
			}
		}
	}

	// Load completion photos from task_completions and quick_task_completions
	async function loadCompletionPhotos() {
		const quickTaskAssignments = assignments.filter(a => a.task_type === 'quick_task');
		const regularTaskAssignments = assignments.filter(a => a.task_type === 'regular');

		// Initialize completionPhotos as empty arrays first
		assignments.forEach(a => { if (!a.completionPhotos) a.completionPhotos = []; });

		// Load completion photos for regular tasks
		if (regularTaskAssignments.length > 0) {
			const taskIds = regularTaskAssignments.map(a => a.task_id);
			try {
				const completions = await batchedQuery('task_completions', 'id, task_id, assignment_id, completion_photo_url, completion_notes, completed_by_name, completed_at', 'task_id', taskIds);

				if (completions && completions.length > 0) {
					const completionMap = new Map();
					completions.forEach(c => {
						const key = c.assignment_id || c.task_id;
						if (!completionMap.has(key)) completionMap.set(key, []);
						if (c.completion_photo_url) {
							completionMap.get(key).push({
								file_url: resolveStorageUrl(c.completion_photo_url),
								file_name: `completion-photo-${c.id}.jpg`,
								file_type: 'image/jpeg',
								completed_by_name: c.completed_by_name,
								completed_at: c.completed_at,
								notes: c.completion_notes
							});
						}
					});
					regularTaskAssignments.forEach(assignment => {
						const photos = completionMap.get(assignment.id) || completionMap.get(assignment.task_id) || [];
						assignment.completionPhotos = photos;
						const completion = completions.find(c => c.assignment_id === assignment.id || c.task_id === assignment.task_id);
						if (completion?.completion_notes) assignment.completionNotes = completion.completion_notes;
					});
				}
			} catch (error) {
				console.error('Error loading regular task completion photos:', error);
			}
		}

		// Load completion photos for quick tasks
		if (quickTaskAssignments.length > 0) {
			const assignmentIds = quickTaskAssignments.map(a => a.id);
			try {
				const completions = await batchedQuery('quick_task_completions', 'id, quick_task_id, assignment_id, photo_path, completion_notes, completed_by_user_id, created_at', 'assignment_id', assignmentIds);

				if (completions && completions.length > 0) {
					const completionMap = new Map();
					completions.forEach(c => {
						if (!completionMap.has(c.assignment_id)) completionMap.set(c.assignment_id, []);
						if (c.photo_path) {
							// photo_path may contain comma-separated paths for multi-photo completions
							const paths = c.photo_path.split(',').map(p => p.trim()).filter(p => p);
							paths.forEach((path, idx) => {
								completionMap.get(c.assignment_id).push({
									file_url: getStoragePublicUrl('completion-photos', path),
									file_name: `completion-photo-${c.id}-${idx + 1}.jpg`,
									file_type: 'image/jpeg',
									completed_at: c.created_at,
									notes: c.completion_notes
								});
							});
						}
					});
					quickTaskAssignments.forEach(assignment => {
						assignment.completionPhotos = completionMap.get(assignment.id) || [];
						const completion = completions.find(c => c.assignment_id === assignment.id);
						if (completion?.completion_notes) assignment.completionNotes = completion.completion_notes;
					});
				}
			} catch (error) {
				console.error('Error loading quick task completion photos:', error);
			}
		}
	}

	// Download file function
	async function downloadFile(file) {
		try {
			const response = await fetch(file.file_url);
			const blob = await response.blob();
			const url = window.URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = file.file_name || file.filename || 'download';
			document.body.appendChild(a);
			a.click();
			window.URL.revokeObjectURL(url);
			document.body.removeChild(a);
		} catch (error) {
			console.error('Error downloading file:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to download file',
				duration: 3000
			});
		}
	}

	// Open image preview
	function openImagePreview(imageUrl) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	// Close image preview
	function closeImagePreview() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	async function loadMyAssignments() {
		if (!$currentUser) return;

		try {
			isLoading = true;

			// Build queries based on showCompleted toggle
			const regularQuery = supabase
				.from('task_assignments')
				.select(`
					*,
					task:tasks!task_assignments_task_id_fkey (
						id,
						title,
						description,
						priority,
						due_date,
						status,
						created_at
					),
					assigned_user:users!task_assignments_assigned_to_user_id_fkey (
						id,
						username,
						hr_employee_master!hr_employee_master_user_id_fkey (
							name_en,
							name_ar
						)
					)
				`)
				.eq('assigned_by', $currentUser.id)
				.order('assigned_at', { ascending: false });

			const quickQuery = supabase
				.from('quick_task_assignments')
				.select(`
					*,
					quick_task:quick_tasks!inner (
						id,
						title,
						description,
						priority,
						price_tag,
						issue_type,
						status,
						created_at,
						deadline_datetime,
						assigned_by,
						product_request_id,
						product_request_type
					),
					assigned_user:users!quick_task_assignments_assigned_to_user_id_fkey (
						id,
						username,
						hr_employee_master!hr_employee_master_user_id_fkey (
							name_en,
							name_ar
						)
					)
				`)
				.eq('quick_task.assigned_by', $currentUser.id)
				.order('created_at', { ascending: false });

			// Always load all assignments for accurate stats
			// Filtering of completed is done in applyFilters()

			// Parallel loading for better performance
			const [regularResult, quickResult] = await Promise.all([
				regularQuery,
				quickQuery
			]);

			// Process regular assignments
			let regularAssignments = [];
			if (regularResult.data && regularResult.data.length > 0) {
				console.log('Regular assignments data:', regularResult.data);
				regularAssignments = regularResult.data.map(assignment => ({
					...assignment,
					task_type: 'regular'
				}));
			}

			if (regularResult.error) {
				console.error('Error loading regular assignments:', regularResult.error);
			}

			// Process quick task assignments
			let quickAssignments = [];
			if (quickResult.data && quickResult.data.length > 0) {
				console.log('Quick task assignments data:', quickResult.data);
				quickAssignments = quickResult.data.map(assignment => ({
					...assignment,
					task_id: assignment.quick_task.id,
					task: {
						id: assignment.quick_task.id,
						title: assignment.quick_task.title,
						description: assignment.quick_task.description,
						priority: assignment.quick_task.priority,
						due_date: null,
						status: assignment.quick_task.status,
						created_at: assignment.quick_task.created_at,
						price_tag: assignment.quick_task.price_tag,
						issue_type: assignment.quick_task.issue_type,
						deadline_datetime: assignment.quick_task.deadline_datetime
					},
					assigned_at: assignment.created_at,
					deadline_date: assignment.quick_task.deadline_datetime 
						? new Date(assignment.quick_task.deadline_datetime).toISOString().split('T')[0] 
						: null,
					deadline_time: assignment.quick_task.deadline_datetime 
						? new Date(assignment.quick_task.deadline_datetime).toTimeString().split(' ')[0].slice(0, 5) 
						: null,
					task_type: 'quick_task'
				}));
			}

			if (quickResult.error) {
				console.warn('Quick tasks might not be available:', quickResult.error);
			}

			// Combine both types of assignments
			// Only include assignments where current user is the assigner
			allAssignments = [...regularAssignments, ...quickAssignments].filter(assignment => {
				const assignedBy = assignment.assigned_by || assignment.quick_task?.assigned_by;
				
				// Must be assigned BY current user (includes self-assigned)
				return assignedBy === $currentUser.id;
			});
			
			console.log('Total assignments loaded:', allAssignments.length);
			console.log('Logged user ID:', $currentUser.id);
			console.log('Sample assignment:', allAssignments[0]);
			
			// Sort by creation date (newest first)
			allAssignments.sort((a, b) => new Date(b.assigned_at) - new Date(a.assigned_at));
			
			// Load attachments for all assignments (in parallel)
			assignments = allAssignments;
			await Promise.all([loadAssignmentAttachments(), loadCompletionPhotos()]);
			
			// Force Svelte reactivity after mutating assignment objects
			allAssignments = [...allAssignments];
			assignments = allAssignments;
			
			// Calculate statistics from ALL assignments (always accurate)
			calculateStats();
			
			// Apply display filters (including showCompleted)
			applyFilters();

		} catch (error) {
			console.error('Error loading assignments:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load assignments: ' + error.message,
				duration: 5000
			});
		} finally {
			isLoading = false;
		}
	}

	function calculateStats() {
		totalStats.total = allAssignments.length;
		totalStats.completed = allAssignments.filter(a => a.status === 'completed').length;
		totalStats.in_progress = allAssignments.filter(a => a.status === 'in_progress').length;
		// Pending = all non-completed assignments (assigned to others, not yet done)
		totalStats.assigned = allAssignments.filter(a => a.status !== 'completed' && a.status !== 'in_progress').length;
		
		// Calculate overdue
		const now = new Date();
		totalStats.overdue = allAssignments.filter(a => {
			if (a.status === 'completed') return false;
			
			let deadline = null;
			
			// Handle quick tasks with deadline_datetime
			if (a.task_type === 'quick_task' && a.task?.deadline_datetime) {
				deadline = new Date(a.task.deadline_datetime);
			}
			// Handle regular tasks with deadline_date
			else if (a.deadline_date) {
				deadline = new Date(a.deadline_date);
				if (a.deadline_time) {
					const [hours, minutes] = a.deadline_time.split(':');
					deadline.setHours(parseInt(hours), parseInt(minutes));
				}
			}
			
			return deadline ? deadline < now : false;
		}).length;
	}

	function applyFilters() {
		filteredAssignments = allAssignments.filter(assignment => {
			// Hide completed unless toggle is on
			if (!showCompleted && assignment.status === 'completed') {
				return false;
			}

			// Search filter
			if (searchTerm) {
				const searchLower = searchTerm.toLowerCase();
				const taskTitle = assignment.task?.title?.toLowerCase() || '';
				const userName = getEmployeeName(assignment.assigned_user)?.toLowerCase() || '';
				
				if (!taskTitle.includes(searchLower) && !userName.includes(searchLower)) {
					return false;
				}
			}

			// Status filter
			if (statusFilter && assignment.status !== statusFilter) {
				return false;
			}

			// Priority filter
			if (priorityFilter && assignment.task?.priority !== priorityFilter) {
				return false;
			}

			return true;
		});
	}

	function clearFilters() {
		searchTerm = '';
		statusFilter = '';
		priorityFilter = '';
		showFilters = false;
		applyFilters();
	}

	function toggleFilters() {
		showFilters = !showFilters;
	}

	function formatDate(dateString) {
		if (!dateString) return getTranslation('mobile.assignmentsContent.taskDetails.noDeadline');
		const date = new Date(dateString);
		const dd = String(date.getDate()).padStart(2, '0');
		const mm = String(date.getMonth() + 1).padStart(2, '0');
		const yyyy = date.getFullYear();
		return `${dd}-${mm}-${yyyy}`;
	}

	/** Format assigned date as time ago */
	function formatTimeAgo(dateString) {
		if (!dateString) return '';
		const date = new Date(dateString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const isAr = $locale === 'ar';
		
		const totalMinutes = Math.floor(diffMs / 60000);
		const totalHours = Math.floor(totalMinutes / 60);
		const days = Math.floor(totalHours / 24);
		const hours = totalHours % 24;
		const mins = totalMinutes % 60;
		
		if (days > 0) {
			return isAr ? `منذ ${days} يوم ${hours} ساعة` : `${days}d ${hours}h ago`;
		} else if (hours > 0) {
			return isAr ? `منذ ${hours} ساعة ${mins} دقيقة` : `${hours}h ${mins}m ago`;
		} else {
			return isAr ? `منذ ${mins} دقيقة` : `${mins}m ago`;
		}
	}

	function formatDateTime(dateString, timeString) {
		if (!dateString) return getTranslation('mobile.assignmentsContent.taskDetails.noDeadline');
		const date = new Date(dateString);
		if (timeString) {
			const [hours, minutes] = timeString.split(':');
			date.setHours(parseInt(hours), parseInt(minutes));
		}
		const dd = String(date.getDate()).padStart(2, '0');
		const mm = String(date.getMonth() + 1).padStart(2, '0');
		const yyyy = date.getFullYear();
		const hh = String(date.getHours()).padStart(2, '0');
		const min = String(date.getMinutes()).padStart(2, '0');
		const hasTime = timeString || (date.getHours() !== 0 || date.getMinutes() !== 0);
		return hasTime ? `${dd}-${mm}-${yyyy}, ${hh}:${min}` : `${dd}-${mm}-${yyyy}`;
	}

	/** Format deadline as remaining time or overdue duration in Saudi timezone */
	function formatDeadline(dateString, timeString) {
		if (!dateString) return { text: getTranslation('mobile.assignmentsContent.taskDetails.noDeadline'), isOverdue: false };
		
		const deadline = new Date(dateString);
		if (timeString) {
			const [hours, minutes] = timeString.split(':');
			deadline.setHours(parseInt(hours), parseInt(minutes));
		}
		
		const now = new Date();
		const diffMs = deadline.getTime() - now.getTime();
		const isAr = $locale === 'ar';
		
		// Format date in Saudi timezone
		const saOpts = { timeZone: 'Asia/Riyadh', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false };
		const saDate = deadline.toLocaleString('en-GB', saOpts).replace(',', '');
		
		if (diffMs > 0) {
			// Future - show remaining
			const totalMinutes = Math.floor(diffMs / 60000);
			const totalHours = Math.floor(totalMinutes / 60);
			const days = Math.floor(totalHours / 24);
			const hours = totalHours % 24;
			const mins = totalMinutes % 60;
			
			let remaining = '';
			if (days > 0) {
				remaining = isAr ? `${days} يوم ${hours} ساعة` : `${days}d ${hours}h left`;
			} else if (hours > 0) {
				remaining = isAr ? `${hours} ساعة ${mins} دقيقة` : `${hours}h ${mins}m left`;
			} else {
				remaining = isAr ? `${mins} دقيقة متبقية` : `${mins}m left`;
			}
			return { text: remaining, isOverdue: false };
		} else {
			// Past - show overdue
			const overMs = Math.abs(diffMs);
			const totalMinutes = Math.floor(overMs / 60000);
			const totalHours = Math.floor(totalMinutes / 60);
			const days = Math.floor(totalHours / 24);
			const hours = totalHours % 24;
			const mins = totalMinutes % 60;
			
			let overdue = '';
			if (days > 0) {
				overdue = isAr ? `متأخر ${days} يوم ${hours} ساعة` : `Overdue ${days}d ${hours}h`;
			} else if (hours > 0) {
				overdue = isAr ? `متأخر ${hours} ساعة ${mins} دقيقة` : `Overdue ${hours}h ${mins}m`;
			} else {
				overdue = isAr ? `متأخر ${mins} دقيقة` : `Overdue ${mins}m`;
			}
			return { text: overdue, isOverdue: true };
		}
	}

	function getStatusColor(status) {
		switch (status) {
			case 'assigned': return 'bg-blue-100 text-blue-800';
			case 'in_progress': return 'bg-yellow-100 text-yellow-800';
			case 'completed': return 'bg-green-100 text-green-800';
			case 'cancelled': return 'bg-red-100 text-red-800';
			case 'escalated': return 'bg-purple-100 text-purple-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'bg-red-100 text-red-800';
			case 'medium': return 'bg-yellow-100 text-yellow-800';
			case 'low': return 'bg-green-100 text-green-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getStatusDisplayText(status) {
		switch (status) {
			case 'assigned': return getTranslation('mobile.assignmentsContent.statuses.assigned');
			case 'in_progress': return getTranslation('mobile.assignmentsContent.statuses.inProgress');
			case 'completed': return getTranslation('mobile.assignmentsContent.statuses.completed');
			case 'cancelled': return getTranslation('mobile.assignmentsContent.statuses.cancelled');
			case 'escalated': return getTranslation('mobile.assignmentsContent.statuses.escalated');
			case 'reassigned': return getTranslation('mobile.assignmentsContent.statuses.reassigned');
			default: return getTranslation('mobile.assignmentsContent.statuses.unknown');
		}
	}

	function isOverdue(assignment) {
		if (assignment.status === 'completed') return false;
		
		const now = new Date();
		let deadline = null;
		
		// Handle quick tasks with deadline_datetime
		if (assignment.task_type === 'quick_task' && assignment.task?.deadline_datetime) {
			deadline = new Date(assignment.task.deadline_datetime);
		}
		// Handle regular tasks with deadline_date
		else if (assignment.deadline_date) {
			deadline = new Date(assignment.deadline_date);
			if (assignment.deadline_time) {
				const [hours, minutes] = assignment.deadline_time.split(':');
				deadline.setHours(parseInt(hours), parseInt(minutes));
			}
		}
		
		return deadline ? deadline < now : false;
	}

	/** Get the localized employee name from hr_employee_master, fallback to username */
	function getEmployeeName(assignedUser) {
		if (!assignedUser) return getTranslation('mobile.assignmentsContent.taskDetails.unknownTask');
		const emp = assignedUser.hr_employee_master;
		// hr_employee_master is an array from the join (one-to-one via unique constraint)
		const empData = Array.isArray(emp) ? emp[0] : emp;
		if (empData) {
			if ($locale === 'ar' && empData.name_ar) return empData.name_ar;
			if ($locale !== 'ar' && empData.name_en) return empData.name_en;
			// Fallback to whichever name exists
			return empData.name_en || empData.name_ar || assignedUser.username || 'Unknown';
		}
		return assignedUser.username || 'Unknown';
	}

	/** Extract the correct language portion from bilingual text.
	 * Supports: "English|||العربية", "English | العربية", "English\n---\nالعربية"
	 */
	function getLocalizedContent(text) {
		if (!text) return '';
		const currentLocale = $locale;
		
		// New format: "English|||العربية"
		if (text.includes('|||')) {
			const parts = text.split('|||');
			return currentLocale === 'ar' ? (parts[1] || parts[0]).trim() : parts[0].trim();
		}
		
		// Check for title format: "English | العربية"
		if (text.includes(' | ')) {
			const parts = text.split(' | ');
			if (parts.length === 2) {
				return currentLocale === 'ar' ? parts[1].trim() : parts[0].trim();
			}
		}
		
		// Check for description format: "English\n---\nالعربية" or "English\n----\nالعربية"
		const descSeparator = text.match(/\n-{3,}\n/);
		if (descSeparator) {
			const parts = text.split(descSeparator[0]);
			if (parts.length === 2) {
				return currentLocale === 'ar' ? parts[1].trim() : parts[0].trim();
			}
		}
		
		return text;
	}

	/** Convert URLs in text to clickable button links */
	function linkifyText(text) {
		if (!text) return '';
		const urlRegex = /(https?:\/\/[^\s<>"]+)/g;
		return text.replace(urlRegex, '<br/><a href="$1" target="_blank" rel="noopener noreferrer" class="url-btn"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>View Clearance Certificate</a>');
	}

	// Reactive statements
	$: {
		searchTerm, statusFilter, priorityFilter;
		applyFilters();
	}

	// Re-filter when showCompleted changes (no need to reload from DB)
	$: if (showCompleted !== undefined) {
		applyFilters();
	}
</script>

<svelte:head>
	<title>{getTranslation('mobile.assignmentsContent.title')}</title>
</svelte:head>

<div class="mobile-assignments">

	<!-- Statistics Cards -->
	<section class="stats-section">
		<div class="stats-grid">
			<div class="stat-card total">
				<div class="stat-number">{totalStats.total}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.total')}</div>
			</div>
			<div class="stat-card completed">
				<div class="stat-number">{totalStats.completed}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.completed')}</div>
			</div>
			<div class="stat-card progress">
				<div class="stat-number">{totalStats.in_progress}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.inProgress')}</div>
			</div>
			<div class="stat-card pending">
				<div class="stat-number">{totalStats.assigned}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.pending')}</div>
			</div>
			<div class="stat-card overdue">
				<div class="stat-number">{totalStats.overdue}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.overdue')}</div>
			</div>
		</div>
	</section>

	<!-- View Completed Button -->
	<section class="completed-link-section">
		<button class="view-completed-btn" on:click={() => goto('/mobile-interface/assignments/completed')}>
			<span class="btn-icon">✅</span>
			<span class="btn-text">{getTranslation('mobile.assignmentsContent.viewCompleted')}</span>
			<span class="btn-count">{totalStats.completed}</span>
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M9 18l6-6-6-6"/>
			</svg>
		</button>
	</section>

	<!-- Floating Filter Button -->
	{#if !isLoading && assignments.length > 0}
		<button class="floating-filter-btn" on:click={toggleFilters} class:active={showFilters}>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M3 4h18M7 8h10M10 12h4"/>
			</svg>
			{showFilters ? 'Hide' : 'Filter'}
		</button>
	{/if}

	<!-- Filters (collapsible) -->
	{#if showFilters}
		<section class="filters-section">
			<div class="filters-content">
				<div class="search-box">
					<input
						type="text"
						bind:value={searchTerm}
						placeholder={getTranslation('mobile.assignmentsContent.search.placeholder')}
						class="search-input"
					/>
				</div>
				
				<div class="filter-row">
					<select bind:value={statusFilter} class="filter-select">
						<option value="">{getTranslation('mobile.assignmentsContent.search.allStatuses')}</option>
						<option value="assigned">{getTranslation('mobile.assignmentsContent.statuses.assigned')}</option>
						<option value="in_progress">{getTranslation('mobile.assignmentsContent.statuses.inProgress')}</option>
						<option value="completed">{getTranslation('mobile.assignmentsContent.statuses.completed')}</option>
						<option value="cancelled">{getTranslation('mobile.assignmentsContent.statuses.cancelled')}</option>
						<option value="escalated">{getTranslation('mobile.assignmentsContent.statuses.escalated')}</option>
					</select>

					<select bind:value={priorityFilter} class="filter-select">
						<option value="">{getTranslation('mobile.assignmentsContent.search.allPriorities')}</option>
						<option value="high">{getTranslation('mobile.assignmentsContent.priorities.high')}</option>
						<option value="medium">{getTranslation('mobile.assignmentsContent.priorities.medium')}</option>
						<option value="low">{getTranslation('mobile.assignmentsContent.priorities.low')}</option>
					</select>
				</div>

				<!-- Show Completed Toggle -->
				<div class="toggle-section">
					<label class="toggle-label">
						<input type="checkbox" bind:checked={showCompleted} class="toggle-checkbox" />
						<span class="toggle-text">{getTranslation('mobile.assignmentsContent.search.showCompleted')}</span>
					</label>
				</div>

				<button class="clear-filters-btn" on:click={clearFilters}>
					{getTranslation('mobile.assignmentsContent.search.clearFilters')}
				</button>
			</div>
		</section>
	{/if}

	<!-- Content -->
	<main class="assignments-content">
		{#if isLoading}
			<div class="loading-skeleton">
				{#each Array(5) as _, i}
					<div class="skeleton-card">
						<div class="skeleton-header">
							<div class="skeleton-title"></div>
							<div class="skeleton-badge"></div>
						</div>
						<div class="skeleton-text"></div>
						<div class="skeleton-text short"></div>
						<div class="skeleton-details">
							<div class="skeleton-detail"></div>
							<div class="skeleton-detail"></div>
						</div>
					</div>
				{/each}
			</div>
		{:else if filteredAssignments.length === 0}
			<div class="empty-state">
				<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
					<path d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
				</svg>
				<h3>{getTranslation('mobile.assignmentsContent.emptyStates.noAssignments')}</h3>
				<p>
					{assignments.length === 0 ? getTranslation('mobile.assignmentsContent.emptyStates.noAssignmentsYet') : getTranslation('mobile.assignmentsContent.emptyStates.noMatchingFilters')}
				</p>
			</div>
		{:else}
			<div class="assignments-list">
				{#each filteredAssignments as assignment}
					<div class="assignment-card" class:overdue={isOverdue(assignment)}>
						<div class="card-header">
							<div class="task-title-section">
								<h3 class="task-title">{getLocalizedContent(assignment.task?.title) || getTranslation('mobile.assignmentsContent.taskDetails.unknownTask')}</h3>
								{#if assignment.task_type === 'quick_task'}
									<span class="task-type-badge quick-task">{getTranslation('mobile.assignmentsContent.taskDetails.quickTask')}</span>
								{/if}
							</div>
							<div class="card-badges">
								{#if assignment.task?.priority}
									<span class="priority-badge {getPriorityColor(assignment.task.priority)}">
										{getTranslation(`mobile.assignmentsContent.priorities.${assignment.task.priority.toLowerCase()}`)}
									</span>
								{/if}
								{#if isOverdue(assignment)}
									<span class="overdue-badge">{getTranslation('mobile.assignmentsContent.taskDetails.overdue')}</span>
								{/if}
							</div>
						</div>

						{#if assignment.task?.description}
							<p class="task-description">{@html linkifyText(getLocalizedContent(assignment.task.description))}</p>
						{/if}

						<div class="assignment-details">
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.assignedTo')}</span>
								<span class="detail-value">{getEmployeeName(assignment.assigned_user)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.status')}</span>
								<span class="status-badge {getStatusColor(assignment.status)}">
									{getStatusDisplayText(assignment.status)}
								</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.assignedDate')}</span>
								<span class="detail-value">{formatTimeAgo(assignment.assigned_at)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.deadline')}</span>
								{#if assignment.status !== 'completed'}
									{@const dl = assignment.task_type === 'quick_task' && assignment.task?.deadline_datetime
										? formatDeadline(assignment.task.deadline_datetime)
										: formatDeadline(assignment.deadline_date, assignment.deadline_time)}
									<span class="detail-value" class:overdue-text={dl.isOverdue} class:remaining-text={!dl.isOverdue && dl.text !== getTranslation('mobile.assignmentsContent.taskDetails.noDeadline')}>
										{dl.text}
									</span>
								{:else}
									<span class="detail-value">
										{formatDate(assignment.deadline_date || assignment.task?.deadline_datetime)}
									</span>
								{/if}
							</div>
						</div>

						{#if assignment.notes}
							<div class="assignment-notes">
								<span class="notes-label">{getTranslation('mobile.assignmentsContent.taskDetails.notes')}</span>
								<p class="notes-text">{@html linkifyText(assignment.notes)}</p>
							</div>
						{/if}

						<!-- Task Attachments (sent by assigner) -->
						{#if assignment.attachments && assignment.attachments.length > 0}
							<div class="attachments-section">
								<div class="attachments-header">
									<span class="attachments-label task-photos-label">📎 {getTranslation('mobile.assignmentsContent.taskDetails.taskPhotos')} ({assignment.attachments.length})</span>
								</div>
								<div class="attachments-grid">
									{#each assignment.attachments as attachment}
										<div class="attachment-item">
											{#if attachment.file_type && (attachment.file_type.startsWith('image/') || (attachment.file_name && /\.(jpg|jpeg|png|gif|webp)$/i.test(attachment.file_name)))}
												<!-- Image Attachment -->
												<div class="image-attachment">
													<img 
														src={attachment.file_url} 
														alt={attachment.file_name || 'Attachment'}
														class="attachment-thumbnail"
														on:click={() => openImagePreview(attachment.file_url)}
													/>
													<button 
														class="view-photo-btn" 
														on:click={() => openImagePreview(attachment.file_url)}
													>
														👁️ {getTranslation('mobile.assignmentsContent.actions.view')}
													</button>
												</div>
											{:else}
												<!-- File Attachment -->
												<div class="file-attachment">
													<div class="file-icon">📄</div>
													<div class="file-info">
														<span class="file-name">{attachment.file_name || attachment.filename || 'Unknown file'}</span>
														<button 
															class="download-file-btn" 
															on:click={() => downloadFile(attachment)}
														>
															⬇️ {getTranslation('mobile.assignmentsContent.actions.download')}
														</button>
													</div>
												</div>
											{/if}
										</div>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Completion Photos (sent by completer) -->
						{#if assignment.completionPhotos && assignment.completionPhotos.length > 0}
							<div class="attachments-section completion-photos-section">
								<div class="attachments-header">
									<span class="attachments-label completion-photos-label">📸 {getTranslation('mobile.assignmentsContent.taskDetails.completionPhotos')} ({assignment.completionPhotos.length})</span>
								</div>
								<div class="attachments-grid">
									{#each assignment.completionPhotos as photo}
										<div class="attachment-item">
											<div class="image-attachment completion-photo">
												<!-- svelte-ignore a11y-click-events-have-key-events -->
												<!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
												<!-- svelte-ignore a11y-click-events-have-key-events -->
												<!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
												<img 
													src={photo.file_url} 
													alt="Completion"
													class="attachment-thumbnail"
													on:click={() => openImagePreview(photo.file_url)}
												/>
												<button 
													class="view-photo-btn" 
													on:click={() => openImagePreview(photo.file_url)}
												>
													👁️ {getTranslation('mobile.assignmentsContent.actions.view')}
												</button>
											</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Completion Notes -->
						{#if assignment.completionNotes}
							<div class="assignment-notes completion-notes-section">
								<span class="notes-label">📝 {getTranslation('mobile.assignmentsContent.taskDetails.completionNotes')}</span>
								<p class="notes-text">{@html linkifyText(assignment.completionNotes)}</p>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</main>

	<!-- Footer Stats -->
	<footer class="mobile-footer">
		<div class="footer-stats">
			<span>{getTranslation('mobile.assignmentsContent.footer.showing')} {filteredAssignments.length} {getTranslation('mobile.assignmentsContent.footer.of')} {assignments.length}</span>
			<span>{getTranslation('mobile.assignmentsContent.footer.completionRate')} {assignments.length > 0 ? Math.round((totalStats.completed / assignments.length) * 100) : 0}%</span>
		</div>
	</footer>
</div>

<!-- Image Preview Modal -->
{#if showImageModal}
	<div class="image-modal-overlay" on:click={closeImagePreview}>
		<div class="image-modal-content" on:click|stopPropagation>
			<img src={selectedImageUrl} alt="Preview" class="modal-image" />
			<button class="modal-close-btn" on:click={closeImagePreview}>×</button>
		</div>
	</div>
{/if}

<style>
	.mobile-assignments {
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		padding: 0;
		padding-bottom: 0.5rem;
	}

	/* Statistics */
	.stats-section {
		padding: 0.4rem 0.6rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.35rem;
	}

	.stat-card {
		text-align: center;
		padding: 0.35rem 0.25rem;
		border-radius: 5px;
		border: 1px solid #E5E7EB;
	}

	.stat-card.total { background: #F3F4F6; }
	.stat-card.completed { background: #ECFDF5; border-color: #D1FAE5; }
	.stat-card.progress { background: #FFFBEB; border-color: #FDE68A; }
	.stat-card.pending { background: #EFF6FF; border-color: #DBEAFE; }
	.stat-card.overdue { background: #FEF2F2; border-color: #FECACA; }

	.stat-number {
		font-size: 0.88rem;
		font-weight: 700;
		color: #1F2937;
	}

	.stat-label {
		font-size: 0.62rem;
		color: #6B7280;
		margin-top: 0.1rem;
	}

	/* Completed Link */
	.completed-link-section {
		padding: 0.3rem 0.6rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.view-completed-btn {
		display: flex;
		align-items: center;
		width: 100%;
		gap: 0.4rem;
		padding: 0.5rem 0.6rem;
		background: #ECFDF5;
		border: 1px solid #A7F3D0;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.view-completed-btn:hover {
		background: #D1FAE5;
	}

	.view-completed-btn .btn-icon {
		font-size: 0.88rem;
	}

	.view-completed-btn .btn-text {
		flex: 1;
		font-size: 0.78rem;
		font-weight: 600;
		color: #065F46;
		text-align: left;
	}

	.view-completed-btn .btn-count {
		background: #059669;
		color: white;
		font-size: 0.68rem;
		font-weight: 700;
		padding: 0.1rem 0.4rem;
		border-radius: 10px;
		min-width: 20px;
		text-align: center;
	}

	.view-completed-btn svg {
		color: #059669;
		flex-shrink: 0;
	}

	/* Filters */
	.floating-filter-btn {
		position: fixed;
		bottom: 4.5rem;
		right: 0.75rem;
		background: #4F46E5;
		color: white;
		border: none;
		border-radius: 20px;
		padding: 0.4rem 0.8rem;
		font-weight: 600;
		font-size: 0.74rem;
		box-shadow: 0 3px 8px rgba(79, 70, 229, 0.4);
		cursor: pointer;
		z-index: 50;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		transition: all 0.2s ease;
	}

	.floating-filter-btn:hover {
		background: #4338CA;
		box-shadow: 0 6px 16px rgba(79, 70, 229, 0.5);
		transform: translateY(-2px);
	}

	.floating-filter-btn.active {
		background: #DC2626;
	}

	.floating-filter-btn.active:hover {
		background: #B91C1C;
	}

	.filters-section {
		background: white;
		border-bottom: 1px solid #E5E7EB;
		padding: 0.5rem 0.6rem;
	}

	.search-box {
		margin-bottom: 0.4rem;
	}

	.search-input {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.78rem;
	}

	.filter-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.4rem;
		margin-bottom: 0.4rem;
	}

	.filter-select {
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		background: white;
		font-size: 0.76rem;
	}

	/* RTL Support for select dropdown arrow */
	:global([dir="rtl"]) .filter-select {
		padding-right: 0.75rem;
		padding-left: 2.5rem;
		background-position: left 0.75rem center;
	}

	/* Show Completed Toggle */
	.toggle-section {
		margin: 0.3rem 0;
		padding: 0.35rem 0.5rem;
		background: #F9FAFB;
		border-radius: 5px;
	}

	.toggle-label {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		cursor: pointer;
		user-select: none;
	}

	.toggle-checkbox {
		width: 15px;
		height: 15px;
		cursor: pointer;
		accent-color: #3B82F6;
	}

	.toggle-text {
		font-size: 0.74rem;
		color: #374151;
		font-weight: 500;
	}

	.clear-filters-btn {
		width: 100%;
		padding: 0.4rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		color: #374151;
		font-weight: 500;
		font-size: 0.76rem;
		cursor: pointer;
	}

	/* Content */
	.assignments-content {
		flex: 1;
		padding: 0.4rem 0.6rem;
	}

	.loading-state, .empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 2rem 1rem;
		color: #6B7280;
		font-size: 0.82rem;
	}

	/* Skeleton Loading */
	.loading-skeleton {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.skeleton-card {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		padding: 0.5rem;
		animation: pulse 1.5s ease-in-out infinite;
	}

	.skeleton-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.75rem;
		gap: 1rem;
	}

	.skeleton-title {
		height: 1.25rem;
		width: 60%;
		background: #E5E7EB;
		border-radius: 4px;
	}

	.skeleton-badge {
		height: 1.5rem;
		width: 4rem;
		background: #E5E7EB;
		border-radius: 4px;
	}

	.skeleton-text {
		height: 0.875rem;
		width: 100%;
		background: #E5E7EB;
		border-radius: 4px;
		margin-bottom: 0.5rem;
	}

	.skeleton-text.short {
		width: 70%;
	}

	.skeleton-details {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-top: 1rem;
	}

	.skeleton-detail {
		height: 2rem;
		background: #E5E7EB;
		border-radius: 4px;
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	.empty-state svg {
		color: #9CA3AF;
		margin-bottom: 0.5rem;
		width: 40px;
		height: 40px;
	}

	.empty-state h3 {
		font-size: 0.88rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.25rem;
	}

	/* Assignment Cards */
	.assignments-list {
		space-y: 1rem;
	}

	.assignment-card {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		margin-bottom: 0.4rem;
		transition: all 0.2s ease;
	}

	.assignment-card.overdue {
		border-color: #F87171;
		background: #FEF2F2;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.3rem;
		gap: 0.4rem;
	}

	.task-title {
		font-size: 0.82rem;
		font-weight: 600;
		color: #1F2937;
		flex: 1;
		margin: 0;
		line-height: 1.3;
	}

	.task-title-section {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		flex: 1;
	}

	.task-type-badge {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.1rem 0.3rem;
		border-radius: 3px;
		text-transform: none;
		width: fit-content;
	}

	.task-type-badge.quick-task {
		background-color: #3b82f615;
		color: #3b82f6;
		border: 1px solid #3b82f640;
	}

	.card-badges {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		flex-shrink: 0;
	}

	.priority-badge, .overdue-badge, .status-badge, .quick-task-badge {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.12rem 0.35rem;
		border-radius: 3px;
		text-align: center;
	}

	.quick-task-badge {
		background: #F3E8FF;
		color: #7C3AED;
		font-size: 0.58rem;
	}

	.overdue-badge {
		background: #FEE2E2;
		color: #DC2626;
	}

	.task-description {
		color: #6B7280;
		font-size: 0.74rem;
		margin: 0 0 0.4rem 0;
		line-height: 1.4;
		word-break: break-word;
		overflow-wrap: break-word;
		white-space: pre-wrap;
		max-width: 100%;
	}

	.task-description :global(.url-btn),
	.notes-text :global(.url-btn) {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.3rem;
		padding: 0.3rem 0.6rem;
		background: #3B82F6;
		color: white;
		border-radius: 5px;
		font-size: 0.74rem;
		font-weight: 500;
		text-decoration: none;
		transition: background 0.2s;
	}

	.task-description :global(.url-btn:hover),
	.notes-text :global(.url-btn:hover) {
		background: #2563EB;
	}

	.assignment-details {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.3rem;
		margin-bottom: 0.4rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.1rem;
	}

	.detail-label {
		font-size: 0.66rem;
		font-weight: 500;
		color: #6B7280;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.detail-value {
		font-size: 0.76rem;
		color: #1F2937;
		font-weight: 500;
	}

	.detail-value.overdue-text {
		color: #DC2626;
		font-weight: 600;
	}

	.detail-value.remaining-text {
		color: #059669;
		font-weight: 600;
	}

	.assignment-notes {
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
	}

	.quick-task-info {
		background: #F3E8FF;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
		margin-top: 0.4rem;
	}

	.quick-detail {
		display: flex;
		justify-content: space-between;
		margin-bottom: 0.25rem;
	}

	.quick-detail:last-child {
		margin-bottom: 0;
	}

	.quick-label {
		font-size: 0.66rem;
		font-weight: 600;
		color: #7C3AED;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.quick-value {
		font-size: 0.76rem;
		color: #5B21B6;
		font-weight: 500;
		text-transform: capitalize;
	}

	.notes-label {
		font-size: 0.66rem;
		font-weight: 600;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.notes-text {
		font-size: 0.76rem;
		color: #6B7280;
		margin: 0.15rem 0 0 0;
		line-height: 1.4;
	}

	/* Footer */
	.mobile-footer {
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 0.35rem 0.6rem;
		margin-top: auto;
	}

	.footer-stats {
		display: flex;
		justify-content: space-between;
		font-size: 0.68rem;
		color: #6B7280;
	}

	/* Responsive */
	@media (max-width: 480px) {
		.stats-grid {
			grid-template-columns: repeat(3, 1fr);
			gap: 0.3rem;
		}

		.stat-card {
			padding: 0.3rem 0.2rem;
		}

		.stat-number {
			font-size: 0.82rem;
		}

		.stat-label {
			font-size: 0.58rem;
		}

		.assignment-details {
			grid-template-columns: 1fr;
			gap: 0.3rem;
		}
	}

	/* Attachments Styles */
	.attachments-section {
		margin-top: 0.4rem;
		padding-top: 0.4rem;
		border-top: 1px solid #E5E7EB;
	}

	.task-photos-label {
		color: #3B82F6;
	}

	.completion-photos-section {
		background: #FFFBEB;
		border: 1px solid #FDE68A;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
		border-top: none;
	}

	.completion-photos-label {
		color: #D97706;
		font-weight: 600;
	}

	.completion-photo {
		border: 2px solid #F59E0B;
		border-radius: 6px;
	}

	.view-photo-btn {
		display: block;
		width: 100%;
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.2rem 0;
		border-radius: 0 0 4px 4px;
		font-size: 0.62rem;
		font-weight: 600;
		cursor: pointer;
		text-align: center;
	}

	.view-photo-btn:active {
		background: #2563EB;
	}

	.completion-notes-section {
		background: #FEF3C7;
		border-color: #FDE68A;
	}

	.attachments-header {
		margin-bottom: 0.3rem;
	}

	.attachments-label {
		font-size: 0.74rem;
		color: #374151;
		font-weight: 500;
	}

	.attachments-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 0.4rem;
	}

	.attachment-item {
		flex: 0 0 auto;
	}

	.image-attachment {
		position: relative;
		display: inline-block;
	}

	.attachment-thumbnail {
		width: 60px;
		height: 60px;
		object-fit: cover;
		border-radius: 5px;
		border: 1px solid #E5E7EB;
		cursor: pointer;
		transition: transform 0.2s;
	}

	.attachment-thumbnail:hover {
		transform: scale(1.05);
		border-color: #3B82F6;
	}

	.download-btn {
		position: absolute;
		top: 4px;
		right: 4px;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		font-size: 12px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.download-btn:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	.file-attachment {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.4rem 0.5rem;
		background: #F3F4F6;
		border-radius: 5px;
		border: 1px solid #E5E7EB;
		min-width: 160px;
	}

	.file-icon {
		font-size: 1rem;
		flex-shrink: 0;
	}

	.file-info {
		flex: 1;
		min-width: 0;
	}

	.file-name {
		display: block;
		font-size: 0.74rem;
		color: #374151;
		font-weight: 500;
		margin-bottom: 0.15rem;
		word-break: break-word;
		line-height: 1.3;
	}

	.download-file-btn {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.2rem 0.5rem;
		border-radius: 4px;
		font-size: 0.68rem;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.download-file-btn:hover {
		background: #2563EB;
	}

	/* Image Modal Styles */
	.image-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 2rem;
	}

	.image-modal-content {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.modal-image {
		width: 100%;
		height: 100%;
		object-fit: contain;
		display: block;
	}

	.modal-close-btn {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 40px;
		height: 40px;
		font-size: 1.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.modal-close-btn:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.mobile-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}
	}
</style>
