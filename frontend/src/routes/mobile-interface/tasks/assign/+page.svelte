<script>
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { db } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { locale, getTranslation } from '$lib/i18n';

	let tasks = [];
	let users = [];
	let branches = [];
	let filteredTasks = [];
	let filteredUsers = [];
	
	let isLoading = true;
	let isAssigning = false;
	
	// Search and filters
	let taskSearchTerm = '';
	let userSearchTerm = '';
	let userSearchType = 'name'; // 'name', 'branch_id', 'employee_id'
	let selectedBranch = '';
	let taskStatusFilter = 'active'; // 'active', 'completed', 'all'
	
	// Selections
	let selectedTasks = new Set();
	let selectedUsers = new Set();
	
	// Current step (1: users, 2: tasks, 3: settings, 4: criteria)
	let currentStep = 1;
	let showUserPopup = false;
	let showTaskPopup = false;
	
	// Assignment settings
	let assignmentSettings = {
		assignment_type: 'one_time', // 'one_time' or 'repeat'
		notify_assignees: true,
		set_deadline: false,
		deadline: '',
		time: '',
		add_note: '',
		priority_override: '',
		enable_reassigning: false,
		enable_repeat: false,
		repeat_type: 'daily',
		repeat_days: [],
		repeat_interval: 1,
		repeat_date: '',
		repeat_end_type: 'never',
		repeat_end_count: 10,
		repeat_end_date: '',
		// Completion criteria
		require_task_finished: true,
		require_photo_upload: false,
		require_erp_reference: false
	};

	// Debug reactive statement to track assignment settings changes
	$: console.log('Assignment type:', assignmentSettings.assignment_type, 'Set deadline:', assignmentSettings.set_deadline);

	const weekDays = [
		{ value: 'monday', label: 'Monday' },
		{ value: 'tuesday', label: 'Tuesday' },
		{ value: 'wednesday', label: 'Wednesday' },
		{ value: 'thursday', label: 'Thursday' },
		{ value: 'friday', label: 'Friday' },
		{ value: 'saturday', label: 'Saturday' },
		{ value: 'sunday', label: 'Sunday' }
	];

	// Reactive weekDays with translations
	$: translatedWeekDays = [
		{ value: 'monday', label: getTranslation('mobile.assignContent.step3.monday'), short: getTranslation('mobile.assignContent.step3.mon') },
		{ value: 'tuesday', label: getTranslation('mobile.assignContent.step3.tuesday'), short: getTranslation('mobile.assignContent.step3.tue') },
		{ value: 'wednesday', label: getTranslation('mobile.assignContent.step3.wednesday'), short: getTranslation('mobile.assignContent.step3.wed') },
		{ value: 'thursday', label: getTranslation('mobile.assignContent.step3.thursday'), short: getTranslation('mobile.assignContent.step3.thu') },
		{ value: 'friday', label: getTranslation('mobile.assignContent.step3.friday'), short: getTranslation('mobile.assignContent.step3.fri') },
		{ value: 'saturday', label: getTranslation('mobile.assignContent.step3.saturday'), short: getTranslation('mobile.assignContent.step3.sat') },
		{ value: 'sunday', label: getTranslation('mobile.assignContent.step3.sunday'), short: getTranslation('mobile.assignContent.step3.sun') }
	];

	const repeatTypes = [
		{ value: 'daily', label: 'Daily' },
		{ value: 'weekly', label: 'Weekly (specific days)' },
		{ value: 'every_n_days', label: 'Every N Days' },
		{ value: 'every_n_weeks', label: 'Every N Weeks' },
		{ value: 'monthly', label: 'Monthly (specific date)' }
	];

	// Reactive repeat types with translations
	$: translatedRepeatTypes = [
		{ value: 'daily', label: getTranslation('mobile.assignContent.step3.daily') },
		{ value: 'weekly', label: getTranslation('mobile.assignContent.step3.weeklySpecific') },
		{ value: 'every_n_days', label: getTranslation('mobile.assignContent.step3.everyNDays') },
		{ value: 'every_n_weeks', label: getTranslation('mobile.assignContent.step3.everyNWeeks') },
		{ value: 'monthly', label: getTranslation('mobile.assignContent.step3.monthlySpecific') }
	];

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		try {
			isLoading = true;
			
			// Load tasks (include all statuses so user can filter)
			const taskResult = await db.tasks.getAll();
			if (!taskResult.error && taskResult.data) {
				tasks = taskResult.data;
			}

			// Load branches
			const branchResult = await db.branches.getAll();
			if (!branchResult.error && branchResult.data) {
				branches = branchResult.data;
				console.log('🏢 Branches loaded:', branches.map(b => ({ id: b.id, name_en: b.name_en, name_ar: b.name_ar, name: b.name })));
			}

			// Load users
			const userResult = await db.users.getAllWithEmployeeDetailsFlat();
			if (!userResult.error && userResult.data) {
				console.log('� Total users loaded:', userResult.data.length);
				
				// Debug: Check first few users to see what branch data we get
				console.log('🔍 First 3 users raw data:');
				userResult.data.slice(0, 3).forEach((u, i) => {
					console.log(`User ${i + 1}:`, {
						id: u.id,
						username: u.username,
						branch_id: u.branch_id,
						branch_name: u.branch_name,
						branch_name_en: u.branch_name_en,
						branch_name_ar: u.branch_name_ar,
						position_title: u.position_title,
						position_title_en: u.position_title_en,
						position_title_ar: u.position_title_ar
					});
				});
				
				users = userResult.data.map(user => ({
					id: user.id,
					username: user.username || '',
					email: user.email || '',
					employee_name: user.employee_name || '',
					display_name: user.employee_name || user.username || user.email || 'Unknown User',
					role: user.role,
					branch_id: user.branch_id,
					branch_name: user.branch_name || user.branch_name_en || '',
					branch_name_en: user.branch_name_en || user.branch_name || '',
					branch_name_ar: user.branch_name_ar || '',
					position_title: user.position_title || user.position_title_en || '',
					position_title_en: user.position_title_en || user.position_title || '',
					position_title_ar: user.position_title_ar || '',
					contact_number: user.contact_number || ''
				}));
				
				console.log('� Mapped users:', users.length);
				console.log('🔍 First 3 mapped users:');
				users.slice(0, 3).forEach((u, i) => {
					console.log(`Mapped User ${i + 1}:`, {
						id: u.id,
						username: u.username,
						branch_id: u.branch_id,
						branch_name: u.branch_name,
						branch_name_en: u.branch_name_en,
						branch_name_ar: u.branch_name_ar,
						position_title: u.position_title,
						position_title_en: u.position_title_en,
						position_title_ar: u.position_title_ar
					});
				});
				console.log('� All usernames:', users.map(u => u.username).sort());
				
				// Check for admin-like users
				const adminUsers = users.filter(u => 
					u.username && u.username.toLowerCase().includes('admin')
				);
				console.log('� Admin users found:', adminUsers);
			}

			filterTasks();
			filterUsers();
		} catch (error) {
			console.error('Error loading data:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load data'
			});
		} finally {
			isLoading = false;
		}
	}

	function filterTasks() {
		const hiddenTitle = 'New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt';
		filteredTasks = tasks.filter(task => {
			if (task.title === hiddenTitle) return false;
			// Status filter
			if (taskStatusFilter === 'active' && task.status !== 'active' && task.status !== 'draft') return false;
			if (taskStatusFilter === 'completed' && task.status !== 'completed') return false;
			const matchesSearch = task.title.toLowerCase().includes(taskSearchTerm.toLowerCase()) ||
								task.description?.toLowerCase().includes(taskSearchTerm.toLowerCase());
			return matchesSearch;
		});
	}

	function filterUsers() {
		console.log('🔍 Filtering users. Search term:', userSearchTerm, 'Branch:', selectedBranch);
		
		filteredUsers = users.filter(user => {
			// Handle empty search term
			if (!userSearchTerm || userSearchTerm.trim() === '') {
				// Filter by branch_id if a branch is selected
				if (!selectedBranch) {
					return true; // No branch filter selected
				}
				
				// Match user's branch_id to the selected branch's ID
				const matchesBranchById = user.branch_id === parseInt(selectedBranch);
				
				console.log('🔍 Branch filter debug:', {
					selectedBranch,
					userBranchId: user.branch_id,
					matchesBranchById
				});
				
				return matchesBranchById;
			}
			
			// Search in multiple fields - handle null/undefined values properly
			const searchTerm = userSearchTerm.toLowerCase().trim();
			
			const matchesDisplayName = user.display_name && user.display_name.toLowerCase().includes(searchTerm);
			const matchesEmail = user.email && user.email.toLowerCase().includes(searchTerm);
			const matchesUsername = user.username && user.username.toLowerCase().includes(searchTerm);
			const matchesEmployeeName = user.employee_name && user.employee_name.toLowerCase().includes(searchTerm);
			
			// Add branch name search support (both English and Arabic) - for display names only
			const userBranchName = getUserBranchName(user);
			const matchesBranchName = userBranchName && userBranchName.toLowerCase().includes(searchTerm);
			const matchesBranchNameEn = user.branch_name_en && user.branch_name_en.toLowerCase().includes(searchTerm);
			const matchesBranchNameAr = user.branch_name_ar && user.branch_name_ar.toLowerCase().includes(searchTerm);
			
			const matchesSearch = matchesDisplayName || matchesEmail || matchesUsername || matchesEmployeeName || matchesBranchName || matchesBranchNameEn || matchesBranchNameAr;
			
			// Filter by branch_id (not by branch name)
			let matchesBranch = true;
			if (selectedBranch) {
				matchesBranch = user.branch_id === parseInt(selectedBranch);
			}
			
			return matchesSearch && matchesBranch;
		});
		
		console.log('🔍 Filtered to', filteredUsers.length, 'users from', users.length, 'total');
	}

	function toggleTaskSelection(taskId) {
		if (selectedTasks.has(taskId)) {
			selectedTasks.delete(taskId);
		} else {
			selectedTasks.add(taskId);
		}
		selectedTasks = new Set(selectedTasks);
	}

	function toggleUserSelection(userId) {
		if (selectedUsers.has(userId)) {
			selectedUsers.delete(userId);
		} else {
			selectedUsers.add(userId);
		}
		selectedUsers = new Set(selectedUsers);
	}

	function nextStep() {
		if (currentStep === 1 && selectedUsers.size === 0) {
			notifications.add({
				type: 'error',
				message: 'Please select at least one user'
			});
			return;
		}
		if (currentStep === 2 && selectedTasks.size === 0) {
			notifications.add({
				type: 'error',
				message: 'Please select at least one task'
			});
			return;
		}
		if (currentStep < 4) {
			currentStep++;
		}
	}

	function prevStep() {
		if (currentStep > 1) {
			currentStep--;
		}
	}

	function goToStep(step) {
		currentStep = step;
	}

	function toggleRepeatDay(day) {
		const index = assignmentSettings.repeat_days.indexOf(day);
		if (index === -1) {
			assignmentSettings.repeat_days.push(day);
		} else {
			assignmentSettings.repeat_days.splice(index, 1);
		}
		assignmentSettings.repeat_days = [...assignmentSettings.repeat_days];
	}

	async function handleAssignment() {
		if (selectedTasks.size === 0 || selectedUsers.size === 0) {
			notifications.add({
				type: 'error',
				message: 'Please select at least one task and one user'
			});
			return;
		}

		isAssigning = true;
		try {
			const taskIds = Array.from(selectedTasks);
			const userIds = Array.from(selectedUsers);
			const currentUserData = $currentUser;

			if (!currentUserData) {
				throw new Error('User not authenticated');
			}

			// Prepare schedule settings
			const scheduleSettings = {
				notes: assignmentSettings.add_note || undefined,
				priority_override: assignmentSettings.priority_override || undefined,
				require_task_finished: assignmentSettings.require_task_finished,
				require_photo_upload: assignmentSettings.require_photo_upload,
				require_erp_reference: assignmentSettings.require_erp_reference
			};

			// Handle deadline settings
			let fullDeadline = null;
			if (assignmentSettings.assignment_type === 'one_time' && assignmentSettings.set_deadline) {
				scheduleSettings.deadline_date = assignmentSettings.deadline;
				scheduleSettings.deadline_time = assignmentSettings.time;
				
				// Create full deadline string for notifications
				if (assignmentSettings.deadline && assignmentSettings.time) {
					fullDeadline = `${assignmentSettings.deadline}T${assignmentSettings.time}:00`;
				}
			}

			// Create assignments using the database function
			const { data: createdAssignments, error: assignmentError } = await db.taskAssignments.assignTasks(
				taskIds,
				'user', // assignment_type
				currentUserData.id, // assigned_by
				currentUserData.display_name || currentUserData.username, // assigned_by_name
				userIds[0], // assigned_to_user_id (for single user, we'll loop for multiple)
				null, // assigned_to_branch_id
				scheduleSettings
			);

			if (assignmentError) {
				throw new Error(assignmentError.message || 'Failed to create assignments');
			}

			// If multiple users, create additional assignments
			if (userIds.length > 1) {
				for (let i = 1; i < userIds.length; i++) {
					const { error: additionalError } = await db.taskAssignments.assignTasks(
						taskIds,
						'user',
						currentUserData.id,
						currentUserData.display_name || currentUserData.username,
						userIds[i],
						null,
						scheduleSettings
					);
					if (additionalError) {
						console.error('Error creating assignment for user:', userIds[i], additionalError);
					}
				}
			}

			// Show success notification
			const assignmentCount = selectedTasks.size * selectedUsers.size;
			let successMessage = `Successfully created ${assignmentCount} task assignment${assignmentCount !== 1 ? 's' : ''}`;
			
			notifications.add({
				type: 'success',
				message: successMessage,
				duration: 5000
			});

			// Create notification center notifications for assigned users
			if (assignmentSettings.notify_assignees) {
				try {
					// Create notifications for each task-user combination
					const notificationPromises = [];
					
					for (const taskId of selectedTasks) {
						// Find the task details
						const task = tasks.find(t => t.id === taskId);
						if (!task) continue;

						// Create notification for all assigned users for this task
						const notificationPromise = notificationManagement.createTaskAssignmentNotification(
							taskId,
							task.title,
							userIds,
							currentUserData.id, // assigned by ID
							currentUserData.display_name || currentUserData.username, // assigned by name
							fullDeadline, // deadline
							assignmentSettings.add_note, // notes
							{
								assignmentId: null, // We don't have specific assignment ID for multi-user
								require_task_finished: assignmentSettings.require_task_finished,
								require_photo_upload: assignmentSettings.require_photo_upload,
								require_erp_reference: assignmentSettings.require_erp_reference,
								description: task.description
							}
						);
						
						notificationPromises.push(notificationPromise);
					}

					await Promise.all(notificationPromises);
					
					notifications.add({
						type: 'success',
						message: `Notifications sent to ${selectedUsers.size} user${selectedUsers.size !== 1 ? 's' : ''} via Notification Center with push notifications`,
						duration: 3000
					});
				} catch (notificationError) {
					console.error('Error creating notifications:', notificationError);
					notifications.add({
						type: 'warning',
						message: 'Tasks assigned successfully, but failed to send notifications',
						duration: 4000
					});
				}
			}

			// Reset and go back
			selectedTasks.clear();
			selectedUsers.clear();
			selectedTasks = new Set(selectedTasks);
			selectedUsers = new Set(selectedUsers);
			currentStep = 1;
			
			goto('/mobile-interface');

		} catch (error) {
			console.error('Error assigning tasks:', error);
			notifications.add({
				type: 'error',
				message: error.message || 'Failed to assign tasks'
			});
		} finally {
			isAssigning = false;
		}
	}

	function handleCancel() {
		goto('/mobile-interface');
	}

	// Helper function to get localized branch name
	function getBranchName(branch) {
		if (!branch) return '';
		const currentLocale = $locale;
		
		// Debug log for branch name selection
		console.log('🏷️ getBranchName:', {
			branchId: branch.id,
			locale: currentLocale,
			name_ar: branch.name_ar,
			name_en: branch.name_en,
			name: branch.name,
			willUseArabic: currentLocale === 'ar' && branch.name_ar
		});
		
		if (currentLocale === 'ar' && branch.name_ar) {
			console.log('✅ Using Arabic name:', branch.name_ar);
			return branch.name_ar;
		}
		
		const fallbackName = branch.name_en || branch.name || '';
		console.log('📝 Using fallback name:', fallbackName);
		return fallbackName;
	}

	// Helper function to get localized user branch name
	function getUserBranchName(user) {
		if (!user) {
			console.log('👤 getUserBranchName: No user provided');
			return '';
		}
		
		const currentLocale = $locale;
		
		// Debug logging for the first 3 users to see what's happening
		const shouldDebug = users.length > 0 && users.slice(0, 3).some(u => u.id === user.id);
		
		if (shouldDebug) {
			console.log('👤 getUserBranchName Debug for', user.username, ':', {
				userId: user.id,
				username: user.username,
				currentLocale,
				userBranchId: user.branch_id,
				userBranchName: user.branch_name,
				userBranchNameAr: user.branch_name_ar,
				branchesLength: branches.length,
				branches: branches.map(b => ({ id: b.id, name_en: b.name_en, name_ar: b.name_ar }))
			});
		}
		
		// Always try to find branch in branches array first for most up-to-date data
		if (user.branch_id && branches.length > 0) {
			const branch = branches.find(b => b.id === user.branch_id);
			if (branch) {
				const branchName = getBranchName(branch);
				if (shouldDebug) {
					console.log('✅ Found branch in array:', {
						branchId: branch.id,
						selectedName: branchName,
						isArabic: currentLocale === 'ar',
						hasArabicName: !!branch.name_ar
					});
				}
				return branchName;
			}
		}
		
		// NEW: Since branch_id is undefined, try to match by English name
		if (user.branch_name && branches.length > 0) {
			const branch = branches.find(b => 
				b.name_en === user.branch_name || 
				b.name_en === user.branch_name_en ||
				b.name_ar === user.branch_name
			);
			if (branch) {
				const branchName = getBranchName(branch);
				if (shouldDebug) {
					console.log('✅ Found branch by name match:', {
						userBranchName: user.branch_name,
						foundBranch: { id: branch.id, name_en: branch.name_en, name_ar: branch.name_ar },
						selectedName: branchName,
						isArabic: currentLocale === 'ar'
					});
				}
				return branchName;
			}
		}
		
		// Fallback: If we have branch_name_ar and we're in Arabic locale
		if (currentLocale === 'ar' && user.branch_name_ar) {
			if (shouldDebug) {
				console.log('🔄 Using user.branch_name_ar:', user.branch_name_ar);
			}
			return user.branch_name_ar;
		}
		
		// Final fallback: use English branch name or original branch_name
		return user.branch_name_en || user.branch_name || '';
	}

	// Helper function to get localized position title
	function getUserPositionTitle(user) {
		if (!user) return '';
		const currentLocale = $locale;
		
		// Temporary mapping for Arabic position titles until database query is fixed
		const positionMapping = {
			'Marketing Manager': 'مدير التسويق',
			'Inventory Control Supervisor': 'مشرف مراقبة المخزون',
			'Analytics & Business Intelligence': 'تحليلات وذكاء الأعمال',
			'Shelf Stockers': 'مرص البضائع',
			'Vegetable Department Head': 'رئيس قسم الخضروات',
			'Quality Assurance Manager': 'مدير ضمان الجودة',
			'Cleaners': 'منظف',
			'Cheese Department Head': 'رئيس قسم الجبن',
			'CEO': 'الرئيس التنفيذي',
			'Accountant': 'محاسب',
			'Customer Service Supervisor': 'مشرف خدمة العملاء',
			'Finance Manager': 'مدير مالي',
			'Driver': 'سائق',
			'Branch Manager': 'مدير الفرع',
			'Inventory Manager': 'مدير المخزون',
			'Night Supervisors': 'مشرف ليلي',
			'Bakers': 'خباز',
			'Bakery Department Head': 'رئيس قسم المخبز',
			'Checkout Helpers': 'مساعد الدفع',
			'Vegetable Counter Staff': 'موظف عداد الخضروات',
			'Cheese Counter Staff': 'موظف عداد الجبن',
			'No Position': 'بدون منصب'
		};
		
		// Always debug position titles for now to understand the issue
		console.log('💼 getUserPositionTitle for', user.username, ':', {
			userId: user.id,
			username: user.username,
			currentLocale,
			positionTitle: user.position_title,
			positionTitleEn: user.position_title_en,
			positionTitleAr: user.position_title_ar,
			hasArabicTitle: !!user.position_title_ar,
			shouldUseArabic: currentLocale === 'ar' && user.position_title_ar,
			mappedArabicTitle: positionMapping[user.position_title]
		});
		
		// If we're in Arabic locale, try mapping first, then fallback to Arabic field
		if (currentLocale === 'ar') {
			// Try mapping from English to Arabic
			if (user.position_title && positionMapping[user.position_title]) {
				console.log('✅ Using mapped Arabic position title for', user.username, ':', positionMapping[user.position_title]);
				return positionMapping[user.position_title];
			}
			
			// Fallback to database Arabic field if available
			if (user.position_title_ar) {
				console.log('✅ Using database Arabic position title for', user.username, ':', user.position_title_ar);
				return user.position_title_ar;
			}
		}
		
		// Fallback to English or original position title
		const fallbackTitle = user.position_title_en || user.position_title || '';
		console.log('📝 Using fallback position title for', user.username, ':', fallbackTitle);
		return fallbackTitle;
	}

	// Helper function to get translated priority text
	function getPriorityText(priority) {
		if (!priority) return getTranslation('mobile.assignContent.priorities.medium');
		
		const priorityKey = priority.toLowerCase();
		const translationKey = `mobile.assignContent.priorities.${priorityKey}`;
		
		// Check if translation exists, fallback to capitalized original if not
		const translated = getTranslation(translationKey);
		return translated || priority.toUpperCase();
	}

	// Helper function to get translated status text
	function getStatusText(status) {
		if (!status) return '';
		
		const statusKey = status.toLowerCase();
		const translationKey = `mobile.assignContent.statuses.${statusKey}`;
		
		// Check if translation exists, fallback to capitalized original if not
		const translated = getTranslation(translationKey);
		return translated || status.toUpperCase();
	}

	$: if (taskSearchTerm !== undefined) filterTasks();
	$: if (taskStatusFilter) filterTasks();
	$: if (userSearchTerm !== undefined || selectedBranch !== undefined) filterUsers();
	$: if ($locale) {
		// Trigger re-filtering when locale changes to update branch names
		filterUsers();
	}
</script>

<svelte:head>
	<title>{getTranslation('mobile.assignContent.title')}</title>
</svelte:head>

<div class="mobile-page">
	{#if isLoading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>{getTranslation('mobile.assignContent.loading')}</p>
		</div>
	{:else}
		<!-- Create Task Template Button -->
		<div class="action-header">
			<button class="create-task-template-btn" on:click={() => goto('/mobile-interface/tasks/create')}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="12" cy="12" r="10"/>
					<line x1="12" y1="8" x2="12" y2="16"/>
					<line x1="8" y1="12" x2="16" y2="12"/>
				</svg>
				{getTranslation('mobile.assignContent.createTaskTemplate')}
			</button>
		</div>

		<!-- Progress Steps -->
		<div class="steps-container">
			<div class="steps">
				<div class="step" class:active={currentStep === 1} class:completed={currentStep > 1}>
					<div class="step-number">1</div>
					<span class="step-label">{getTranslation('mobile.assignContent.steps.users')}</span>
					{#if selectedUsers.size > 0}
						<span class="step-count">{selectedUsers.size}</span>
					{/if}
				</div>
				
				<div class="step-arrow">→</div>
				
				<div class="step" class:active={currentStep === 2} class:completed={currentStep > 2}>
					<div class="step-number">2</div>
					<span class="step-label">{getTranslation('mobile.assignContent.steps.tasks')}</span>
					{#if selectedTasks.size > 0}
						<span class="step-count">{selectedTasks.size}</span>
					{/if}
				</div>
				
				<div class="step-arrow">→</div>
				
				<div class="step" class:active={currentStep === 3} class:completed={currentStep > 3}>
					<div class="step-number">3</div>
					<span class="step-label">{getTranslation('mobile.assignContent.steps.settings')}</span>
				</div>
				
				<div class="step-arrow">→</div>
				
				<div class="step" class:active={currentStep === 4}>
					<div class="step-number">4</div>
					<span class="step-label">{getTranslation('mobile.assignContent.steps.criteria')}</span>
				</div>
			</div>
		</div>

		<div class="mobile-content">
			<!-- Step 1: Select Users -->
			{#if currentStep === 1}
				<div class="step-content">
					<h2>{getTranslation('mobile.assignContent.step1.title')}</h2>
					<p class="step-description">{getTranslation('mobile.assignContent.step1.description')}</p>
					
					<!-- Select Users Button -->
					<button class="select-users-btn" on:click={() => showUserPopup = true}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
							<circle cx="9" cy="7" r="4"/>
							<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
							<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
						</svg>
						<span>{getTranslation('mobile.assignContent.step1.title')}</span>
						{#if selectedUsers.size > 0}
							<span class="selected-count-badge">{selectedUsers.size}</span>
						{/if}
					</button>

					<!-- Selected Users Summary -->
					{#if selectedUsers.size > 0}
						<div class="selected-users-summary">
							{#each users.filter(u => selectedUsers.has(u.id)) as user}
								<div class="selected-user-chip">
									<span>{user.display_name}</span>
									<button class="chip-remove" on:click={() => toggleUserSelection(user.id)}>&times;</button>
								</div>
							{/each}
						</div>
					{/if}
					
					<!-- Inline Action Buttons -->
					<div class="inline-actions">
						<button 
							class="action-btn secondary"
							on:click={handleCancel}
							disabled={isAssigning}
						>
							{getTranslation('mobile.assignContent.actions.cancel')}
						</button>
						
						<button 
							class="action-btn primary"
							on:click={nextStep}
						>
							{getTranslation('mobile.assignContent.actions.nextStep')}
						</button>
					</div>
				</div>

			<!-- Step 2: Select Tasks -->
			{:else if currentStep === 2}
				<div class="step-content">
					<h2>{getTranslation('mobile.assignContent.step2.title')}</h2>
					<p class="step-description">{getTranslation('mobile.assignContent.step2.description')}</p>
					
					<!-- Select Tasks Button -->
					<button class="select-tasks-btn" on:click={() => showTaskPopup = true}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 11l3 3L22 4"/>
							<path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
						</svg>
						<span>{getTranslation('mobile.assignContent.step2.title')}</span>
						{#if selectedTasks.size > 0}
							<span class="selected-count-badge">{selectedTasks.size}</span>
						{/if}
					</button>

					<!-- Selected Tasks Summary -->
					{#if selectedTasks.size > 0}
						<div class="selected-users-summary">
							{#each tasks.filter(t => selectedTasks.has(t.id)) as task}
								<div class="selected-user-chip">
									<span>{task.title}</span>
									<button class="chip-remove" on:click={() => toggleTaskSelection(task.id)}>&times;</button>
								</div>
							{/each}
						</div>
					{/if}
					
					<!-- Inline Action Buttons -->
					<div class="inline-actions">
						<button 
							class="action-btn secondary"
							on:click={prevStep}
							disabled={isAssigning}
						>
							{getTranslation('mobile.assignContent.actions.previous')}
						</button>
						
						<button 
							class="action-btn primary"
							on:click={nextStep}
						>
							{getTranslation('mobile.assignContent.actions.nextStep')}
						</button>
					</div>
				</div>

			<!-- Step 3: Assignment Settings -->
			{:else if currentStep === 3}
				<div class="step-content">
					<h2>{getTranslation('mobile.assignContent.step3.title')}</h2>
					<p class="step-description">{getTranslation('mobile.assignContent.step3.description')}</p>
					
					<div class="settings-form">
						<!-- Basic Settings -->
						<div class="setting-group">
							<h3>{getTranslation('mobile.assignContent.step3.notificationSettings')}</h3>
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.notify_assignees} />
								<span class="checkmark"></span>
								{getTranslation('mobile.assignContent.step3.sendNotifications')}
							</label>
						</div>

						<!-- Assignment Type -->
						<div class="setting-group">
							<h3>{getTranslation('mobile.assignContent.step3.assignmentType')}</h3>
							<div class="radio-group">
								<label class="radio-label">
									<input 
										type="radio" 
										bind:group={assignmentSettings.assignment_type} 
										value="one_time"
										name="assignment_type"
									/>
									<span class="radio-mark"></span>
									{getTranslation('mobile.assignContent.step3.oneTimeAssignment')}
								</label>
								<label class="radio-label">
									<input 
										type="radio" 
										bind:group={assignmentSettings.assignment_type} 
										value="repeat"
										name="assignment_type"
									/>
									<span class="radio-mark"></span>
									{getTranslation('mobile.assignContent.step3.recurringAssignment')}
								</label>
							</div>
						</div>

						<!-- Deadline Settings -->
						{#if assignmentSettings.assignment_type === 'one_time'}
							<div class="setting-group">
								<label class="checkbox-label">
									<input 
										type="checkbox" 
										bind:checked={assignmentSettings.set_deadline}
									/>
									<span class="checkmark"></span>
									{getTranslation('mobile.assignContent.step3.setDeadline')}
								</label>
								
								{#if assignmentSettings.set_deadline}
									<div class="deadline-fields">
										<div class="input-row">
											<div class="input-group">
												<label for="deadline">{getTranslation('mobile.assignContent.step3.deadlineDate')}</label>
												<input
													id="deadline"
													type="date"
													bind:value={assignmentSettings.deadline}
													required
												/>
											</div>
											<div class="input-group">
												<label for="time">{getTranslation('mobile.assignContent.step3.deadlineTime')}</label>
												<input
													id="time"
													type="time"
													bind:value={assignmentSettings.time}
													required
												/>
											</div>
										</div>
									</div>
								{/if}
							</div>
						{/if}

						<!-- Recurring Settings -->
						{#if assignmentSettings.assignment_type === 'repeat'}
							<div class="setting-group">
								<h3>{getTranslation('mobile.assignContent.step3.repeatSettings')}</h3>
								<div class="input-group">
									<label for="repeat_type">{getTranslation('mobile.assignContent.step3.repeatType')}</label>
									<select id="repeat_type" bind:value={assignmentSettings.repeat_type}>
										{#each translatedRepeatTypes as type}
											<option value={type.value}>{type.label}</option>
										{/each}
									</select>
								</div>

								{#if assignmentSettings.repeat_type === 'weekly'}
									<div class="setting-group">
										<label>{getTranslation('mobile.assignContent.step3.selectDays')}</label>
										<div class="day-selector">
											{#each translatedWeekDays as day}
												<label class="day-label">
													<input 
														type="checkbox" 
														checked={assignmentSettings.repeat_days.includes(day.value)}
														on:change={() => toggleRepeatDay(day.value)}
													/>
													<span class="day-mark">{day.short}</span>
												</label>
											{/each}
										</div>
									</div>
								{/if}

								{#if assignmentSettings.repeat_type === 'every_n_days' || assignmentSettings.repeat_type === 'every_n_weeks'}
									<div class="input-group">
										<label for="interval">{getTranslation('mobile.assignContent.step3.repeatEvery')}</label>
										<input
											id="interval"
											type="number"
											min="1"
											bind:value={assignmentSettings.repeat_interval}
											placeholder="1"
										/>
									</div>
								{/if}
							</div>
						{/if}

						<!-- Other Settings -->
						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.enable_reassigning} />
								<span class="checkmark"></span>
								{getTranslation('mobile.assignContent.step3.allowReassign')}
							</label>
						</div>

						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.notify_assignees} />
								<span class="checkmark"></span>
								{getTranslation('mobile.assignContent.step3.notifyAssignees')}
							</label>
						</div>

						<!-- Notes -->
						<div class="input-group">
							<label for="notes">{getTranslation('mobile.assignContent.step3.additionalNotes')}</label>
							<textarea
								id="notes"
								bind:value={assignmentSettings.add_note}
								placeholder={getTranslation('mobile.assignContent.step3.specialInstructions')}
								rows="3"
							></textarea>
						</div>
					</div>
					
					<!-- Inline Action Buttons -->
					<div class="inline-actions">
						<button 
							class="action-btn secondary"
							on:click={prevStep}
							disabled={isAssigning}
						>
							{getTranslation('mobile.assignContent.actions.previous')}
						</button>
						
						<button 
							class="action-btn primary"
							on:click={nextStep}
						>
							{getTranslation('mobile.assignContent.actions.nextStep')}
						</button>
					</div>
				</div>

			<!-- Step 4: Completion Criteria -->
			{:else if currentStep === 4}
				<div class="step-content">
					<h2>{getTranslation('mobile.assignContent.step4.title')}</h2>
					<p class="step-description">{getTranslation('mobile.assignContent.step4.description')}</p>
					
					<div class="settings-form">
						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.require_task_finished} />
								<span class="checkmark"></span>
								{getTranslation('mobile.assignContent.step4.requireTaskFinished')}
							</label>
						</div>

						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.require_photo_upload} />
								<span class="checkmark"></span>
								{getTranslation('mobile.assignContent.step4.requirePhotoUpload')}
							</label>
						</div>

						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.require_erp_reference} />
								<span class="checkmark"></span>
								{getTranslation('mobile.assignContent.step4.requireErpReference')}
							</label>
						</div>

						<!-- Summary -->
						<div class="assignment-summary">
							<h3>{getTranslation('mobile.assignContent.step4.assignmentSummary')}</h3>
							<div class="summary-item">
								<span class="summary-label">{getTranslation('mobile.assignContent.step4.usersLabel')}</span>
								<span class="summary-value">{selectedUsers.size} {getTranslation('mobile.assignContent.step4.selectedUsers')}</span>
							</div>
							<div class="summary-item">
								<span class="summary-label">{getTranslation('mobile.assignContent.step4.tasksLabel')}</span>
								<span class="summary-value">{selectedTasks.size} {getTranslation('mobile.assignContent.step4.selectedTasks')}</span>
							</div>
							<div class="summary-item">
								<span class="summary-label">{getTranslation('mobile.assignContent.step4.typeLabel')}</span>
								<span class="summary-value">{assignmentSettings.assignment_type === 'one_time' ? getTranslation('mobile.assignContent.step4.oneTimeType') : getTranslation('mobile.assignContent.step4.recurringType')}</span>
							</div>
							{#if assignmentSettings.set_deadline && assignmentSettings.deadline}
								<div class="summary-item">
									<span class="summary-label">{getTranslation('mobile.assignContent.step4.deadlineLabel')}</span>
									<span class="summary-value">{assignmentSettings.deadline} {assignmentSettings.time || ''}</span>
								</div>
							{/if}
						</div>
					</div>
					
					<!-- Inline Action Buttons -->
					<div class="inline-actions">
						{#if currentStep > 1}
							<button 
								class="action-btn secondary"
								on:click={prevStep}
								disabled={isAssigning}
							>
								{getTranslation('mobile.assignContent.actions.previous')}
							</button>
						{:else}
							<button 
								class="action-btn secondary"
								on:click={handleCancel}
								disabled={isAssigning}
							>
								{getTranslation('mobile.assignContent.actions.cancel')}
							</button>
						{/if}
						
						{#if currentStep === 4}
							<button 
								class="action-btn primary"
								on:click={handleAssignment}
								disabled={isAssigning || selectedTasks.size === 0 || selectedUsers.size === 0}
							>
								{isAssigning ? getTranslation('mobile.assignContent.actions.assigning') : getTranslation('mobile.assignContent.actions.assignTasks')}
							</button>
						{:else}
							<button 
								class="action-btn primary"
								on:click={nextStep}
							>
								Next Step
							</button>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>

<!-- User Selection Popup -->
{#if showUserPopup}
	<div class="user-popup-overlay" on:click={() => showUserPopup = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showUserPopup = false)}>
		<div class="user-popup" on:click|stopPropagation role="none">
			<div class="user-popup-header">
				<span>{getTranslation('mobile.assignContent.step1.title')}</span>
				<button type="button" class="user-popup-close" on:click={() => showUserPopup = false}>&times;</button>
			</div>
			
			<!-- Filters inside popup -->
			<div class="user-popup-filters">
				<input
					type="text"
					placeholder={getTranslation('mobile.assignContent.step1.searchPlaceholder')}
					bind:value={userSearchTerm}
					class="user-popup-search-input"
				/>
				<select bind:value={selectedBranch} class="user-popup-select">
					<option value="">{getTranslation('mobile.assignContent.step1.allBranches')}</option>
					{#each branches as branch}
						<option value={branch.id}>{getBranchName(branch)}</option>
					{/each}
				</select>
			</div>

			<!-- User List -->
			<div class="user-popup-list">
				{#each filteredUsers as user}
					<div class="user-popup-item" class:selected={selectedUsers.has(user.id)}>
						<label class="checkbox-label">
							<input 
								type="checkbox" 
								checked={selectedUsers.has(user.id)}
								on:change={() => toggleUserSelection(user.id)}
							/>
							<span class="checkmark"></span>
							<div class="item-content">
								<h4>{user.display_name}</h4>
								<p>{user.email}</p>
								<div class="item-meta">
									{#key $locale}
										{#if getUserPositionTitle(user)}
											<span class="meta-tag">{getUserPositionTitle(user)}</span>
										{/if}
									{/key}
									{#key $locale}
										{#if getUserBranchName(user)}
											<span class="meta-tag">{getUserBranchName(user)}</span>
										{/if}
									{/key}
								</div>
							</div>
						</label>
					</div>
				{/each}
			</div>

			<div class="user-popup-footer">
				<button class="user-popup-confirm" on:click={() => showUserPopup = false}>
					{getTranslation('mobile.assignContent.actions.confirm')} ({selectedUsers.size})
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Task Selection Popup -->
{#if showTaskPopup}
	<div class="user-popup-overlay" on:click={() => showTaskPopup = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showTaskPopup = false)}>
		<div class="user-popup" on:click|stopPropagation role="none">
			<div class="user-popup-header">
				<span>{getTranslation('mobile.assignContent.step2.title')}</span>
				<button type="button" class="user-popup-close" on:click={() => showTaskPopup = false}>&times;</button>
			</div>
			
			<!-- Search inside popup -->
			<div class="user-popup-filters">
				<input
					type="text"
					placeholder={getTranslation('mobile.assignContent.step2.searchPlaceholder')}
					bind:value={taskSearchTerm}
					class="user-popup-search-input"
				/>
				<!-- Task Status Filter Tabs -->
				<div class="task-status-tabs">
					<button class="task-status-tab" class:active={taskStatusFilter === 'active'} on:click={() => taskStatusFilter = 'active'}>
						{getTranslation('mobile.assignContent.step2.activeTasks')}
					</button>
					<button class="task-status-tab" class:active={taskStatusFilter === 'completed'} on:click={() => taskStatusFilter = 'completed'}>
						{getTranslation('mobile.assignContent.step2.completedTasks')}
					</button>
					<button class="task-status-tab" class:active={taskStatusFilter === 'all'} on:click={() => taskStatusFilter = 'all'}>
						{getTranslation('mobile.assignContent.step2.allTasks')}
					</button>
				</div>
			</div>

			<!-- Task List -->
			<div class="user-popup-list">
				{#each filteredTasks as task}
					<div class="user-popup-item" class:selected={selectedTasks.has(task.id)}>
						<label class="checkbox-label">
							<input 
								type="checkbox" 
								checked={selectedTasks.has(task.id)}
								on:change={() => toggleTaskSelection(task.id)}
							/>
							<span class="checkmark"></span>
							<div class="item-content">
								<h4>{task.title}</h4>
								<p>{task.description || getTranslation('mobile.assignContent.step2.noDescription')}</p>
								<div class="item-meta">
									<span class="meta-tag priority" style="color: {getPriorityColor(task.priority)}">
										{getPriorityText(task.priority)}
									</span>
									<span class="meta-tag">{getStatusText(task.status)}</span>
								</div>
							</div>
						</label>
					</div>
				{/each}
			</div>

			<div class="user-popup-footer">
				<button class="user-popup-confirm" on:click={() => showTaskPopup = false}>
					{getTranslation('mobile.assignContent.actions.confirm')} ({selectedTasks.size})
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.mobile-page {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.loading-container {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		color: #6B7280;
		padding: 1rem;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 0.5rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Action Header */
	.action-header {
		padding: 0.4rem 0.5rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
		display: flex;
		justify-content: center;
	}

	.create-task-template-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.5rem 0.75rem;
		font-size: 0.78rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.create-task-template-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	.create-task-template-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.steps-container {
		background: white;
		padding: 0.4rem 0.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.steps {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		overflow-x: auto;
		padding: 0.5rem 0;
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
		min-width: 60px;
		position: relative;
	}

	.step-number {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.72rem;
		font-weight: 600;
		border: 1.5px solid #d1d5db;
		background: white;
		color: #6b7280;
	}

	.step.active .step-number {
		border-color: #3B82F6;
		background: #3B82F6;
		color: white;
	}

	.step.completed .step-number {
		border-color: #10b981;
		background: #10b981;
		color: white;
	}

	.step-label {
		font-size: 0.65rem;
		color: #6b7280;
		font-weight: 500;
	}

	.step.active .step-label {
		color: #3B82F6;
		font-weight: 600;
	}

	.step-count {
		background: #3B82F6;
		color: white;
		font-size: 0.58rem;
		font-weight: 600;
		padding: 0.1rem 0.3rem;
		border-radius: 9999px;
		position: absolute;
		top: -0.2rem;
		right: -0.2rem;
	}

	.step-arrow {
		color: #d1d5db;
		font-size: 0.875rem;
		margin: 0 0.25rem;
	}

	.mobile-content {
		flex: 1;
		padding: 0.4rem 0.5rem;
		overflow-y: auto;
	}

	.step-content {
		max-width: 100%;
		margin-top: 0.5rem;
	}

	.step-content h2 {
		color: #1F2937;
		font-size: 0.88rem;
		font-weight: 600;
		margin: 0 0 0.3rem 0;
	}

	.step-description {
		color: #6B7280;
		margin-bottom: 0.5rem;
		font-size: 0.72rem;
	}

	.checkbox-label {
		display: flex;
		align-items: flex-start;
		gap: 0.4rem;
		cursor: pointer;
		line-height: 1.4;
		width: 100%;
	}

	.checkbox-label input[type="checkbox"] {
		display: none;
	}

	.checkmark {
		width: 16px;
		height: 16px;
		border: 1.5px solid #d1d5db;
		border-radius: 3px;
		background: white;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		margin-top: 2px;
	}

	.checkbox-label input[type="checkbox"]:checked + .checkmark {
		background: #3B82F6;
		border-color: #3B82F6;
	}

	.checkbox-label input[type="checkbox"]:checked + .checkmark:after {
		content: '✓';
		color: white;
		font-size: 11px;
	}

	.item-content {
		flex: 1;
	}

	.item-content h4 {
		margin: 0 0 0.15rem 0;
		font-size: 0.82rem;
		font-weight: 600;
		color: #1f2937;
	}

	.item-content p {
		margin: 0 0 0.3rem 0;
		font-size: 0.72rem;
		color: #6b7280;
		line-height: 1.3;
	}

	.item-meta {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.meta-tag {
		font-size: 0.65rem;
		font-weight: 500;
		padding: 0.15rem 0.35rem;
		border-radius: 3px;
		background: #f3f4f6;
		color: #374151;
	}

	.meta-tag.priority {
		font-weight: 600;
	}

	.settings-form {
		background: white;
		border-radius: 6px;
		padding: 0.75rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
	}

	.setting-group {
		margin-bottom: 0.75rem;
	}

	.setting-group h3 {
		margin: 0 0 0.5rem 0;
		font-size: 0.82rem;
		font-weight: 600;
		color: #1f2937;
	}

	.radio-group {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}

	.radio-label {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		cursor: pointer;
	}

	.radio-label input[type="radio"] {
		display: none;
	}

	.radio-mark {
		width: 16px;
		height: 16px;
		border: 1.5px solid #d1d5db;
		border-radius: 50%;
		background: white;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.radio-label input[type="radio"]:checked + .radio-mark {
		border-color: #3B82F6;
		background: #3B82F6;
	}

	.radio-label input[type="radio"]:checked + .radio-mark:after {
		content: '';
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: white;
	}

	.input-group {
		margin-bottom: 0.5rem;
	}

	.input-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.deadline-fields {
		margin-top: 0.5rem;
		padding: 0.5rem;
		background: #f8fafc;
		border-radius: 5px;
		border: 1px solid #e2e8f0;
	}

	.day-selector {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.day-label {
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}

	.day-label input[type="checkbox"] {
		display: none;
	}

	.day-mark {
		width: 30px;
		height: 30px;
		border: 1.5px solid #d1d5db;
		border-radius: 5px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.65rem;
		font-weight: 600;
		color: #6b7280;
		background: white;
	}

	.day-label input[type="checkbox"]:checked + .day-mark {
		border-color: #3B82F6;
		background: #3B82F6;
		color: white;
	}

	.assignment-summary {
		background: #f8fafc;
		border-radius: 5px;
		padding: 0.5rem;
		margin-top: 0.5rem;
	}

	.assignment-summary h3 {
		margin: 0 0 0.5rem 0;
		font-size: 0.82rem;
		font-weight: 600;
		color: #1f2937;
	}

	.summary-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
		border-bottom: 1px solid #e5e7eb;
	}

	.summary-item:last-child {
		border-bottom: none;
	}

	.summary-label {
		font-weight: 500;
		color: #6b7280;
	}

	.summary-value {
		font-weight: 600;
		color: #1f2937;
	}

	label {
		display: block;
		margin-bottom: 0.3rem;
		font-weight: 500;
		color: #374151;
		font-size: 0.78rem;
	}

	input, select, textarea {
		width: 100%;
		padding: 0.4rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		font-size: 0.78rem;
		box-sizing: border-box;
	}

	/* Specific styling for select elements with dropdown arrow */
	select {
		padding-right: 2.5rem;
		background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
		background-position: right 0.75rem center;
		background-repeat: no-repeat;
		background-size: 1.5em 1.5em;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		cursor: pointer;
	}

	/* RTL Support for select dropdown arrow in settings form */
	:global([dir="rtl"]) select {
		padding-right: 0.75rem;
		padding-left: 2.5rem;
		background-position: left 0.75rem center;
	}

	input:focus, select:focus, textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.inline-actions {
		background: white;
		padding: 0.5rem;
		border-top: 1px solid #e5e7eb;
		border-radius: 8px;
		margin-top: 0.5rem;
		display: flex;
		gap: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.action-btn {
		flex: 1;
		padding: 0.5rem;
		border: none;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-btn.secondary {
		background: #f3f4f6;
		color: #374151;
	}

	.action-btn.secondary:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.action-btn.primary {
		background: #3B82F6;
		color: white;
	}

	.action-btn.primary:hover:not(:disabled) {
		background: #2563EB;
	}

	.action-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	@supports (padding: max(0px)) {
		.inline-actions {
			padding-bottom: max(0.5rem, env(safe-area-inset-bottom));
		}
	}

	/* Select Users Button */
	.select-users-btn {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.65rem;
		background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		touch-action: manipulation;
		box-shadow: 0 2px 6px rgba(59, 130, 246, 0.3);
	}

	.select-users-btn:hover {
		box-shadow: 0 4px 10px rgba(59, 130, 246, 0.4);
	}

	.selected-count-badge {
		background: rgba(255, 255, 255, 0.25);
		padding: 0.1rem 0.45rem;
		border-radius: 9999px;
		font-size: 0.72rem;
		font-weight: 700;
	}

	/* Selected Users Chips */
	.selected-users-summary {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		margin-top: 0.5rem;
	}

	.selected-user-chip {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		background: #EFF6FF;
		border: 1px solid #BFDBFE;
		color: #1E40AF;
		padding: 0.2rem 0.45rem;
		border-radius: 9999px;
		font-size: 0.7rem;
		font-weight: 500;
	}

	.chip-remove {
		background: none;
		border: none;
		color: #3B82F6;
		font-size: 0.9rem;
		line-height: 1;
		cursor: pointer;
		padding: 0;
		margin-left: 0.1rem;
	}

	.chip-remove:hover {
		color: #EF4444;
	}

	/* User Selection Popup */
	.user-popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1100;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.75rem;
	}

	.user-popup {
		background: white;
		border-radius: 10px;
		width: 100%;
		max-width: 400px;
		max-height: 75vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		box-shadow: 0 8px 30px rgba(0, 0, 0, 0.2);
	}

	.user-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.6rem 0.75rem;
		border-bottom: 1px solid #E5E7EB;
		font-weight: 700;
		font-size: 0.85rem;
		color: #111827;
		flex-shrink: 0;
	}

	.user-popup-close {
		background: none;
		border: none;
		font-size: 1.3rem;
		cursor: pointer;
		color: #6B7280;
		line-height: 1;
		padding: 0 0.2rem;
	}

	.user-popup-filters {
		padding: 0.5rem 0.75rem;
		border-bottom: 1px solid #F3F4F6;
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		flex-shrink: 0;
	}

	.user-popup-search-input,
	.user-popup-select {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		font-size: 0.78rem;
		box-sizing: border-box;
	}

	.user-popup-search-input:focus,
	.user-popup-select:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.task-status-tabs {
		display: flex;
		gap: 0.25rem;
		background: #F3F4F6;
		border-radius: 6px;
		padding: 2px;
	}

	.task-status-tab {
		flex: 1;
		padding: 0.3rem 0.4rem;
		border: none;
		background: transparent;
		border-radius: 5px;
		font-size: 0.7rem;
		font-weight: 500;
		color: #6B7280;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.task-status-tab.active {
		background: white;
		color: #3B82F6;
		box-shadow: 0 1px 2px rgba(0,0,0,0.1);
	}

	.user-popup-list {
		flex: 1;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		min-height: 0;
	}

	.user-popup-item {
		border-bottom: 1px solid #f3f4f6;
		padding: 0.5rem 0.75rem;
		transition: background-color 0.15s;
	}

	.user-popup-item:last-child {
		border-bottom: none;
	}

	.user-popup-item.selected {
		background: #EFF6FF;
	}

	.user-popup-footer {
		padding: 0.5rem 0.75rem;
		border-top: 1px solid #E5E7EB;
		flex-shrink: 0;
	}

	.user-popup-confirm {
		width: 100%;
		padding: 0.5rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.user-popup-confirm:hover {
		background: #2563EB;
	}

	/* Select Tasks Button */
	.select-tasks-btn {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.65rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		touch-action: manipulation;
		box-shadow: 0 2px 6px rgba(16, 185, 129, 0.3);
	}

	.select-tasks-btn:hover {
		box-shadow: 0 4px 10px rgba(16, 185, 129, 0.4);
	}
</style>

<script context="module">
	function getPriorityColor(priority) {
		switch (priority?.toLowerCase()) {
			case 'urgent': return '#ef4444';
			case 'high': return '#f97316';
			case 'medium': return '#eab308';
			case 'low': return '#22c55e';
			default: return '#6b7280';
		}
	}
</script>
