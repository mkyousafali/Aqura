<script>
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { db } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';

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
	let selectedBranch = '';
	
	// Selections
	let selectedTasks = new Set();
	let selectedUsers = new Set();
	
	// Current step (1: users, 2: tasks, 3: settings, 4: criteria)
	let currentStep = 1;
	
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

	const repeatTypes = [
		{ value: 'daily', label: 'Daily' },
		{ value: 'weekly', label: 'Weekly (specific days)' },
		{ value: 'every_n_days', label: 'Every N Days' },
		{ value: 'every_n_weeks', label: 'Every N Weeks' },
		{ value: 'monthly', label: 'Monthly (specific date)' }
	];

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		try {
			isLoading = true;
			
			// Load tasks
			const taskResult = await db.tasks.getAll();
			if (!taskResult.error && taskResult.data) {
				tasks = taskResult.data.filter(task => task.status === 'active' || task.status === 'draft');
			}

			// Load branches
			const branchResult = await db.branches.getAll();
			if (!branchResult.error && branchResult.data) {
				branches = branchResult.data;
			}

			// Load users
			const userResult = await db.users.getAllWithEmployeeDetailsFlat();
			if (!userResult.error && userResult.data) {
				console.log('Raw user data:', userResult.data.slice(0, 2)); // Debug first 2 users
				users = userResult.data.map(user => ({
					id: user.id,
					username: user.username || '',
					email: user.email || '',
					employee_name: user.employee_name || '',
					display_name: user.employee_name || user.username || user.email || 'Unknown User',
					role: user.role,
					branch_id: user.branch_id,
					branch_name: user.branch_name || user.branch_name_en || '',
					position_title: user.position_title || '',
					contact_number: user.contact_number || ''
				}));
				console.log('Mapped users:', users.slice(0, 2)); // Debug first 2 mapped users
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
		filteredTasks = tasks.filter(task => {
			const matchesSearch = task.title.toLowerCase().includes(taskSearchTerm.toLowerCase()) ||
								task.description?.toLowerCase().includes(taskSearchTerm.toLowerCase());
			return matchesSearch;
		});
	}

	function filterUsers() {
		console.log('Filtering users with search term:', userSearchTerm);
		console.log('Selected branch:', selectedBranch);
		console.log('Total users:', users.length);
		
		filteredUsers = users.filter(user => {
			// Handle empty search term
			if (!userSearchTerm || userSearchTerm.trim() === '') {
				const matchesBranch = !selectedBranch || user.branch_id == selectedBranch;
				return matchesBranch;
			}
			
			// Search in multiple fields
			const searchTerm = userSearchTerm.toLowerCase().trim();
			const matchesSearch = 
				(user.display_name && user.display_name.toLowerCase().includes(searchTerm)) ||
				(user.email && user.email.toLowerCase().includes(searchTerm)) ||
				(user.username && user.username.toLowerCase().includes(searchTerm)) ||
				(user.employee_name && user.employee_name.toLowerCase().includes(searchTerm));
				
			const matchesBranch = !selectedBranch || user.branch_id == selectedBranch;
			
			return matchesSearch && matchesBranch;
		});
		
		console.log('Filtered users:', filteredUsers.length);
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
			
			goto('/mobile');

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
		goto('/mobile');
	}

	$: if (taskSearchTerm !== undefined) filterTasks();
	$: if (userSearchTerm !== undefined || selectedBranch !== undefined) filterUsers();
</script>

<div class="mobile-page">
	{#if isLoading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading data...</p>
		</div>
	{:else}
		<!-- Progress Steps -->
		<div class="steps-container">
			<div class="steps">
				<div class="step" class:active={currentStep === 1} class:completed={currentStep > 1}>
					<div class="step-number">1</div>
					<span class="step-label">Users</span>
					{#if selectedUsers.size > 0}
						<span class="step-count">{selectedUsers.size}</span>
					{/if}
				</div>
				
				<div class="step-arrow">→</div>
				
				<div class="step" class:active={currentStep === 2} class:completed={currentStep > 2}>
					<div class="step-number">2</div>
					<span class="step-label">Tasks</span>
					{#if selectedTasks.size > 0}
						<span class="step-count">{selectedTasks.size}</span>
					{/if}
				</div>
				
				<div class="step-arrow">→</div>
				
				<div class="step" class:active={currentStep === 3} class:completed={currentStep > 3}>
					<div class="step-number">3</div>
					<span class="step-label">Settings</span>
				</div>
				
				<div class="step-arrow">→</div>
				
				<div class="step" class:active={currentStep === 4}>
					<div class="step-number">4</div>
					<span class="step-label">Criteria</span>
				</div>
			</div>
		</div>

		<div class="mobile-content">
			<!-- Step 1: Select Users -->
			{#if currentStep === 1}
				<div class="step-content">
					<h2>Select Users</h2>
					<p class="step-description">Choose users to assign tasks to</p>
					
					<!-- User Filters -->
					<div class="filter-section">
						<div class="search-bar">
							<input
								type="text"
								placeholder="Search by name, username, email..."
								bind:value={userSearchTerm}
							/>
						</div>
						
						<div class="filter-row">
							<select bind:value={selectedBranch}>
								<option value="">All Branches</option>
								{#each branches as branch}
									<option value={branch.id}>{branch.name_en || branch.name}</option>
								{/each}
							</select>
						</div>
					</div>

					<!-- User List -->
					<div class="selection-list">
						{#each filteredUsers as user}
							<div class="selection-item" class:selected={selectedUsers.has(user.id)}>
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
											{#if user.position_title}
												<span class="meta-tag">{user.position_title}</span>
											{/if}
											{#if user.branch_name}
												<span class="meta-tag">{user.branch_name}</span>
											{/if}
										</div>
									</div>
								</label>
							</div>
						{/each}
					</div>
					
					<!-- Inline Action Buttons -->
					<div class="inline-actions">
						<button 
							class="action-btn secondary"
							on:click={handleCancel}
							disabled={isAssigning}
						>
							Cancel
						</button>
						
						<button 
							class="action-btn primary"
							on:click={nextStep}
						>
							Next Step
						</button>
					</div>
				</div>

			<!-- Step 2: Select Tasks -->
			{:else if currentStep === 2}
				<div class="step-content">
					<h2>Select Tasks</h2>
					<p class="step-description">Choose tasks to assign</p>
					
					<!-- Task Filters -->
					<div class="filter-section">
						<div class="search-bar">
							<input
								type="text"
								placeholder="Search tasks..."
								bind:value={taskSearchTerm}
							/>
						</div>
					</div>

					<!-- Task List -->
					<div class="selection-list">
						{#each filteredTasks as task}
							<div class="selection-item" class:selected={selectedTasks.has(task.id)}>
								<label class="checkbox-label">
									<input 
										type="checkbox" 
										checked={selectedTasks.has(task.id)}
										on:change={() => toggleTaskSelection(task.id)}
									/>
									<span class="checkmark"></span>
									<div class="item-content">
										<h4>{task.title}</h4>
										<p>{task.description || 'No description'}</p>
										<div class="item-meta">
											<span class="meta-tag priority" style="color: {getPriorityColor(task.priority)}">
												{task.priority?.toUpperCase() || 'MEDIUM'}
											</span>
											<span class="meta-tag">{task.status?.toUpperCase()}</span>
										</div>
									</div>
								</label>
							</div>
						{/each}
					</div>
					
					<!-- Inline Action Buttons -->
					<div class="inline-actions">
						<button 
							class="action-btn secondary"
							on:click={prevStep}
							disabled={isAssigning}
						>
							Previous
						</button>
						
						<button 
							class="action-btn primary"
							on:click={nextStep}
						>
							Next Step
						</button>
					</div>
				</div>

			<!-- Step 3: Assignment Settings -->
			{:else if currentStep === 3}
				<div class="step-content">
					<h2>Assignment Settings</h2>
					<p class="step-description">Configure assignment options</p>
					
					<div class="settings-form">
						<!-- Basic Settings -->
						<div class="setting-group">
							<h3>Notification Settings</h3>
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.notify_assignees} />
								<span class="checkmark"></span>
								Send notifications to assignees
							</label>
						</div>

						<!-- Assignment Type -->
						<div class="setting-group">
							<h3>Assignment Type</h3>
							<div class="radio-group">
								<label class="radio-label">
									<input 
										type="radio" 
										bind:group={assignmentSettings.assignment_type} 
										value="one_time"
										name="assignment_type"
									/>
									<span class="radio-mark"></span>
									One-time Assignment
								</label>
								<label class="radio-label">
									<input 
										type="radio" 
										bind:group={assignmentSettings.assignment_type} 
										value="repeat"
										name="assignment_type"
									/>
									<span class="radio-mark"></span>
									Recurring Assignment
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
									Set deadline
								</label>
								
								{#if assignmentSettings.set_deadline}
									<div class="deadline-fields">
										<div class="input-row">
											<div class="input-group">
												<label for="deadline">Deadline Date</label>
												<input
													id="deadline"
													type="date"
													bind:value={assignmentSettings.deadline}
													required
												/>
											</div>
											<div class="input-group">
												<label for="time">Deadline Time</label>
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
								<h3>Repeat Settings</h3>
								<div class="input-group">
									<label for="repeat_type">Repeat Type</label>
									<select id="repeat_type" bind:value={assignmentSettings.repeat_type}>
										{#each repeatTypes as type}
											<option value={type.value}>{type.label}</option>
										{/each}
									</select>
								</div>

								{#if assignmentSettings.repeat_type === 'weekly'}
									<div class="setting-group">
										<label>Select Days</label>
										<div class="day-selector">
											{#each weekDays as day}
												<label class="day-label">
													<input 
														type="checkbox" 
														checked={assignmentSettings.repeat_days.includes(day.value)}
														on:change={() => toggleRepeatDay(day.value)}
													/>
													<span class="day-mark">{day.label.substring(0, 3)}</span>
												</label>
											{/each}
										</div>
									</div>
								{/if}

								{#if assignmentSettings.repeat_type === 'every_n_days' || assignmentSettings.repeat_type === 'every_n_weeks'}
									<div class="input-group">
										<label for="interval">Repeat every</label>
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
								Allow users to reassign tasks
							</label>
						</div>

						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.notify_assignees} />
								<span class="checkmark"></span>
								Notify assignees
							</label>
						</div>

						<!-- Notes -->
						<div class="input-group">
							<label for="notes">Additional Notes</label>
							<textarea
								id="notes"
								bind:value={assignmentSettings.add_note}
								placeholder="Add any special instructions..."
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
							Previous
						</button>
						
						<button 
							class="action-btn primary"
							on:click={nextStep}
						>
							Next Step
						</button>
					</div>
				</div>

			<!-- Step 4: Completion Criteria -->
			{:else if currentStep === 4}
				<div class="step-content">
					<h2>Completion Criteria</h2>
					<p class="step-description">Set requirements for task completion</p>
					
					<div class="settings-form">
						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.require_task_finished} />
								<span class="checkmark"></span>
								Require task to be marked as finished
							</label>
						</div>

						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.require_photo_upload} />
								<span class="checkmark"></span>
								Require photo upload
							</label>
						</div>

						<div class="setting-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={assignmentSettings.require_erp_reference} />
								<span class="checkmark"></span>
								Require ERP reference
							</label>
						</div>

						<!-- Summary -->
						<div class="assignment-summary">
							<h3>Assignment Summary</h3>
							<div class="summary-item">
								<span class="summary-label">Users:</span>
								<span class="summary-value">{selectedUsers.size} selected</span>
							</div>
							<div class="summary-item">
								<span class="summary-label">Tasks:</span>
								<span class="summary-value">{selectedTasks.size} selected</span>
							</div>
							<div class="summary-item">
								<span class="summary-label">Type:</span>
								<span class="summary-value">{assignmentSettings.assignment_type === 'one_time' ? 'One-time' : 'Recurring'}</span>
							</div>
							{#if assignmentSettings.set_deadline && assignmentSettings.deadline}
								<div class="summary-item">
									<span class="summary-label">Deadline:</span>
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
								Previous
							</button>
						{:else}
							<button 
								class="action-btn secondary"
								on:click={handleCancel}
								disabled={isAssigning}
							>
								Cancel
							</button>
						{/if}
						
						{#if currentStep === 4}
							<button 
								class="action-btn primary"
								on:click={handleAssignment}
								disabled={isAssigning || selectedTasks.size === 0 || selectedUsers.size === 0}
							>
								{isAssigning ? 'Assigning...' : 'Assign Tasks'}
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
		padding: 2rem;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid rgba(255, 255, 255, 0.3);
		border-top: 3px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.steps-container {
		background: white;
		padding: 1rem;
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
		width: 32px;
		height: 32px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.875rem;
		font-weight: 600;
		border: 2px solid #d1d5db;
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
		font-size: 0.75rem;
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
		font-size: 0.625rem;
		font-weight: 600;
		padding: 0.125rem 0.375rem;
		border-radius: 9999px;
		position: absolute;
		top: -0.25rem;
		right: -0.25rem;
	}

	.step-arrow {
		color: #d1d5db;
		font-size: 0.875rem;
		margin: 0 0.25rem;
	}

	.mobile-content {
		flex: 1;
		padding: 0.5rem 1rem;
		overflow-y: auto;
	}

	.step-content {
		max-width: 100%;
		margin-top: 0.5rem;
	}

	.step-content h2 {
		color: #1F2937;
		font-size: 1.5rem;
		font-weight: 600;
		margin: 0 0 0.5rem 0;
	}

	.step-description {
		color: #6B7280;
		margin-bottom: 1rem;
		font-size: 0.875rem;
	}

	.filter-section {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		margin-bottom: 1rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.search-bar {
		margin-bottom: 1rem;
	}

	.filter-row {
		display: block;
		margin-bottom: 1rem;
	}

	.selection-list {
		background: white;
		border-radius: 12px;
		max-height: 400px;
		overflow-y: auto;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.selection-item {
		border-bottom: 1px solid #e5e7eb;
		padding: 1rem;
		transition: background-color 0.2s;
	}

	.selection-item:last-child {
		border-bottom: none;
	}

	.selection-item.selected {
		background: #eff6ff;
	}

	.checkbox-label {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		cursor: pointer;
		line-height: 1.5;
		width: 100%;
	}

	.checkbox-label input[type="checkbox"] {
		display: none;
	}

	.checkmark {
		width: 20px;
		height: 20px;
		border: 2px solid #d1d5db;
		border-radius: 4px;
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
		font-size: 14px;
	}

	.item-content {
		flex: 1;
	}

	.item-content h4 {
		margin: 0 0 0.25rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1f2937;
	}

	.item-content p {
		margin: 0 0 0.5rem 0;
		font-size: 0.875rem;
		color: #6b7280;
		line-height: 1.4;
	}

	.item-meta {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.meta-tag {
		font-size: 0.75rem;
		font-weight: 500;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		background: #f3f4f6;
		color: #374151;
	}

	.meta-tag.priority {
		font-weight: 600;
	}

	.settings-form {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.setting-group {
		margin-bottom: 1.5rem;
	}

	.setting-group h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1f2937;
	}

	.radio-group {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.radio-label {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		cursor: pointer;
	}

	.radio-label input[type="radio"] {
		display: none;
	}

	.radio-mark {
		width: 20px;
		height: 20px;
		border: 2px solid #d1d5db;
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
		margin-bottom: 1rem;
	}

	.input-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-top: 1rem;
	}

	.deadline-fields {
		margin-top: 1rem;
		padding: 1rem;
		background: #f8fafc;
		border-radius: 8px;
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
		width: 40px;
		height: 40px;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.75rem;
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
		border-radius: 8px;
		padding: 1rem;
		margin-top: 1rem;
	}

	.assignment-summary h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
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
		margin-bottom: 0.5rem;
		font-weight: 500;
		color: #374151;
	}

	input, select, textarea {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 1rem;
		box-sizing: border-box;
	}

	input:focus, select:focus, textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.inline-actions {
		background: white;
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
		border-radius: 16px;
		margin-top: 1rem;
		display: flex;
		gap: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.action-btn {
		flex: 1;
		padding: 1rem;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
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
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
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