<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	let currentUserData = null;
	let isLoading = false;
	let isSubmitting = false;
	let users = [];
	let employees = [];

	// Form data
	let formData: {
		title: string;
		description: string;
		priority: string;
		dueDate: string;
		dueTime: string;
		assignTo: string[];
		deadlineDate: string;
		deadlineTime: string;
	} = {
		title: '',
		description: '',
		priority: 'medium',
		dueDate: '',
		dueTime: '',
		assignTo: [],
		deadlineDate: '',
		deadlineTime: ''
	};

	// Form validation
	let errors: Record<string, string> = {};

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadUsers();
			await loadEmployees();
		}
	});

	async function loadUsers() {
		try {
			const { data, error } = await supabase
				.from('users')
				.select('id, username, display_name')
				.eq('active', true)
				.order('display_name');

			if (error) throw error;
			users = data || [];
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	async function loadEmployees() {
		try {
			const { data, error } = await supabase
				.from('hr_employees')
				.select('id, first_name, last_name, employee_id')
				.eq('active', true)
				.order('first_name');

			if (error) throw error;
			employees = data || [];
		} catch (error) {
			console.error('Error loading employees:', error);
		}
	}

	function validateForm() {
		errors = {};

		if (!formData.title.trim()) {
			errors.title = 'Task title is required';
		}

		if (!formData.description.trim()) {
			errors.description = 'Task description is required';
		}

		if (formData.assignTo.length === 0) {
			errors.assignTo = 'Please assign the task to at least one person';
		}

		if (formData.dueDate && formData.deadlineDate) {
			const dueDateTime = new Date(formData.dueDate + (formData.dueTime ? ' ' + formData.dueTime : ''));
			const deadlineDateTime = new Date(formData.deadlineDate + (formData.deadlineTime ? ' ' + formData.deadlineTime : ''));
			
			if (deadlineDateTime < dueDateTime) {
				errors.deadlineDate = 'Assignment deadline cannot be before task due date';
			}
		}

		return Object.keys(errors).length === 0;
	}

	async function handleSubmit() {
		if (!validateForm()) {
			return;
		}

		isSubmitting = true;

		try {
			// Create the task first
			const taskData = {
				title: formData.title.trim(),
				description: formData.description.trim(),
				priority: formData.priority,
				due_date: formData.dueDate || null,
				due_time: formData.dueTime || null,
				status: 'draft',
				created_by: currentUserData.id,
				created_by_name: currentUserData.display_name || currentUserData.username,
				created_at: new Date().toISOString()
			};

			const { data: task, error: taskError } = await supabase
				.from('tasks')
				.insert(taskData)
				.select()
				.single();

			if (taskError) throw taskError;

			// Create assignments for each selected person
			const assignments = formData.assignTo.map(assigneeId => ({
				task_id: task.id,
				assigned_to_user_id: assigneeId,
				assigned_by: currentUserData.id,
				assigned_by_name: currentUserData.display_name || currentUserData.username,
				assigned_at: new Date().toISOString(),
				deadline_date: formData.deadlineDate || null,
				deadline_time: formData.deadlineTime || null,
				status: 'pending'
			}));

			const { error: assignmentError } = await supabase
				.from('task_assignments')
				.insert(assignments);

			if (assignmentError) throw assignmentError;

			// Update task status to active
			const { error: updateError } = await supabase
				.from('tasks')
				.update({ status: 'active' })
				.eq('id', task.id);

			if (updateError) throw updateError;

			// Navigate back to tasks list
			goto('/mobile/tasks');
		} catch (error) {
			console.error('Error creating task:', error);
			alert('Failed to create task. Please try again.');
		} finally {
			isSubmitting = false;
		}
	}

	function toggleAssignee(userId) {
		if (formData.assignTo.includes(userId)) {
			formData.assignTo = formData.assignTo.filter(id => id !== userId);
		} else {
			formData.assignTo = [...formData.assignTo, userId];
		}
		// Clear assignment error when user makes a selection
		if (formData.assignTo.length > 0 && errors.assignTo) {
			delete errors.assignTo;
		}
	}

	function getDisplayName(user) {
		return user.display_name || user.username || 'Unknown User';
	}

	// Auto-clear errors when user starts typing
	$: if (formData.title) delete errors.title;
	$: if (formData.description) delete errors.description;
</script>

<svelte:head>
	<title>Create Task - Aqura Mobile</title>
</svelte:head>

<div class="mobile-create-task">
	<!-- Header -->
	<header class="page-header">
		<div class="header-content">
			<button class="back-btn" on:click={() => goto('/mobile/tasks')}>
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M19 12H5M12 19l-7-7 7-7"/>
				</svg>
			</button>
			<h1>Create Task</h1>
			<button class="save-btn" on:click={handleSubmit} disabled={isSubmitting}>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
				{:else}
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<polyline points="20,6 9,17 4,12"/>
					</svg>
				{/if}
			</button>
		</div>
	</header>

	<!-- Content -->
	<div class="content-section">
		<form on:submit|preventDefault={handleSubmit} class="task-form">
			<!-- Task Details Section -->
			<div class="form-section">
				<h2>Task Details</h2>
				
				<div class="form-group">
					<label for="title">Task Title *</label>
					<input
						id="title"
						type="text"
						bind:value={formData.title}
						placeholder="Enter task title..."
						class:error={errors.title}
						maxlength="200"
					/>
					{#if errors.title}
						<span class="error-text">{errors.title}</span>
					{/if}
				</div>

				<div class="form-group">
					<label for="description">Description *</label>
					<textarea
						id="description"
						bind:value={formData.description}
						placeholder="Describe what needs to be done..."
						rows="4"
						class:error={errors.description}
						maxlength="1000"
					></textarea>
					{#if errors.description}
						<span class="error-text">{errors.description}</span>
					{/if}
				</div>

				<div class="form-group">
					<label for="priority">Priority</label>
					<select id="priority" bind:value={formData.priority}>
						<option value="low">Low Priority</option>
						<option value="medium">Medium Priority</option>
						<option value="high">High Priority</option>
					</select>
				</div>
			</div>

			<!-- Task Timing Section -->
			<div class="form-section">
				<h2>Task Timing</h2>
				
				<div class="form-row">
					<div class="form-group">
						<label for="dueDate">Due Date</label>
						<input
							id="dueDate"
							type="date"
							bind:value={formData.dueDate}
						/>
					</div>
					<div class="form-group">
						<label for="dueTime">Due Time</label>
						<input
							id="dueTime"
							type="time"
							bind:value={formData.dueTime}
							disabled={!formData.dueDate}
						/>
					</div>
				</div>

				<div class="info-note">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/>
						<line x1="12" y1="16" x2="12" y2="12"/>
						<line x1="12" y1="8" x2="12.01" y2="8"/>
					</svg>
					<span>Due date is optional and represents when the task ideally should be completed.</span>
				</div>
			</div>

			<!-- Assignment Section -->
			<div class="form-section">
				<h2>Assignment</h2>
				
				<div class="form-group">
					<label>Assign To *</label>
					{#if errors.assignTo}
						<span class="error-text">{errors.assignTo}</span>
					{/if}
					
					<div class="assignee-list">
						{#each users as user (user.id)}
							<button
								type="button"
								class="assignee-item"
								class:selected={formData.assignTo.includes(user.id)}
								on:click={() => toggleAssignee(user.id)}
							>
								<div class="assignee-avatar">
									{getDisplayName(user).charAt(0).toUpperCase()}
								</div>
								<div class="assignee-info">
									<div class="assignee-name">{getDisplayName(user)}</div>
									<div class="assignee-username">@{user.username}</div>
								</div>
								<div class="assignee-check">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<polyline points="20,6 9,17 4,12"/>
									</svg>
								</div>
							</button>
						{/each}
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label for="deadlineDate">Assignment Deadline</label>
						<input
							id="deadlineDate"
							type="date"
							bind:value={formData.deadlineDate}
							class:error={errors.deadlineDate}
						/>
						{#if errors.deadlineDate}
							<span class="error-text">{errors.deadlineDate}</span>
						{/if}
					</div>
					<div class="form-group">
						<label for="deadlineTime">Deadline Time</label>
						<input
							id="deadlineTime"
							type="time"
							bind:value={formData.deadlineTime}
							disabled={!formData.deadlineDate}
						/>
					</div>
				</div>

				<div class="info-note">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/>
						<line x1="12" y1="16" x2="12" y2="12"/>
						<line x1="12" y1="8" x2="12.01" y2="8"/>
					</svg>
					<span>Assignment deadline is when assignees need to complete the task by.</span>
				</div>
			</div>

			<!-- Selected Assignees Summary -->
			{#if formData.assignTo.length > 0}
				<div class="form-section">
					<h2>Selected Assignees ({formData.assignTo.length})</h2>
					<div class="selected-assignees">
						{#each formData.assignTo as userId}
							{@const user = users.find(u => u.id === userId)}
							{#if user}
								<div class="selected-assignee">
									<div class="assignee-avatar small">
										{getDisplayName(user).charAt(0).toUpperCase()}
									</div>
									<span>{getDisplayName(user)}</span>
									<button
										type="button"
										class="remove-assignee"
										on:click={() => toggleAssignee(userId)}
									>
										<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<line x1="18" y1="6" x2="6" y2="18"/>
											<line x1="6" y1="6" x2="18" y2="18"/>
										</svg>
									</button>
								</div>
							{/if}
						{/each}
					</div>
				</div>
			{/if}
		</form>
	</div>

	<!-- Action Section -->
	<div class="action-section">
		<div class="action-buttons">
			<button type="button" class="cancel-btn" on:click={() => goto('/mobile/tasks')} disabled={isSubmitting}>
				Cancel
			</button>
			<button type="submit" class="create-btn" on:click={handleSubmit} disabled={isSubmitting}>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
					Creating...
				{:else}
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="12" y1="5" x2="12" y2="19"/>
						<line x1="5" y1="12" x2="19" y2="12"/>
					</svg>
					Create Task
				{/if}
			</button>
		</div>
	</div>
</div>

<style>
	.mobile-create-task {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Header */
	.page-header {
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		color: white;
		padding: 1rem 1.5rem;
		padding-top: calc(1rem + env(safe-area-inset-top));
		box-shadow: 0 2px 10px rgba(59, 130, 246, 0.2);
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.header-content {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.back-btn,
	.save-btn {
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 10px;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		backdrop-filter: blur(10px);
	}

	.back-btn:hover,
	.save-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
	}

	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.page-header h1 {
		font-size: 1.25rem;
		font-weight: 600;
		margin: 0;
	}

	.btn-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Content */
	.content-section {
		padding: 1.5rem;
		padding-bottom: 6rem; /* Space for action section */
	}

	.task-form {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	/* Form Sections */
	.form-section {
		background: white;
		border-radius: 16px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.form-section h2 {
		font-size: 1.1rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 1.5rem 0;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	/* Form Groups */
	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-group label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.form-group input,
	.form-group textarea,
	.form-group select {
		width: 100%;
		padding: 0.75rem 1rem;
		border: 2px solid #E5E7EB;
		border-radius: 12px;
		font-size: 1rem;
		background: #F9FAFB;
		color: #374151;
		transition: all 0.3s ease;
		box-sizing: border-box;
	}

	.form-group input:focus,
	.form-group textarea:focus,
	.form-group select:focus {
		outline: none;
		border-color: #3B82F6;
		background: white;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-group input:disabled,
	.form-group textarea:disabled,
	.form-group select:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		background: #F3F4F6;
	}

	.form-group input.error,
	.form-group textarea.error,
	.form-group select.error {
		border-color: #EF4444;
		background: #FEF2F2;
	}

	.form-group textarea {
		resize: vertical;
		min-height: 100px;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.error-text {
		display: block;
		font-size: 0.75rem;
		color: #EF4444;
		margin-top: 0.25rem;
		font-weight: 500;
	}

	.info-note {
		display: flex;
		align-items: flex-start;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #F0F9FF;
		border: 1px solid #BAE6FD;
		border-radius: 8px;
		font-size: 0.875rem;
		color: #0369A1;
		margin-top: 1rem;
	}

	.info-note svg {
		flex-shrink: 0;
		margin-top: 0.125rem;
	}

	/* Assignee List */
	.assignee-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 0.5rem;
	}

	.assignee-item {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 0.75rem 1rem;
		border: 2px solid transparent;
		border-radius: 10px;
		background: #F9FAFB;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		width: 100%;
		text-align: left;
	}

	.assignee-item:hover {
		background: #F3F4F6;
		border-color: #D1D5DB;
	}

	.assignee-item.selected {
		background: #EBF8FF;
		border-color: #3B82F6;
	}

	.assignee-avatar {
		width: 40px;
		height: 40px;
		background: #3B82F6;
		color: white;
		border-radius: 10px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 1rem;
		flex-shrink: 0;
	}

	.assignee-avatar.small {
		width: 24px;
		height: 24px;
		font-size: 0.75rem;
		border-radius: 6px;
	}

	.assignee-info {
		flex: 1;
	}

	.assignee-name {
		font-size: 0.875rem;
		font-weight: 600;
		color: #1F2937;
		margin-bottom: 0.125rem;
	}

	.assignee-username {
		font-size: 0.75rem;
		color: #6B7280;
	}

	.assignee-check {
		width: 20px;
		height: 20px;
		border: 2px solid #D1D5DB;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.3s ease;
		color: transparent;
	}

	.assignee-item.selected .assignee-check {
		background: #3B82F6;
		border-color: #3B82F6;
		color: white;
	}

	/* Selected Assignees */
	.selected-assignees {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.selected-assignee {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		background: #EBF8FF;
		border: 1px solid #3B82F6;
		border-radius: 8px;
		font-size: 0.875rem;
		color: #1F2937;
	}

	.remove-assignee {
		width: 20px;
		height: 20px;
		background: transparent;
		border: none;
		color: #6B7280;
		cursor: pointer;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.remove-assignee:hover {
		background: #FEE2E2;
		color: #EF4444;
	}

	/* Action Section */
	.action-section {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 1.5rem;
		padding-bottom: calc(1.5rem + env(safe-area-inset-bottom));
		box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
		z-index: 10;
	}

	.action-buttons {
		display: flex;
		gap: 1rem;
	}

	.cancel-btn,
	.create-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 1rem 1.5rem;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		min-height: 48px;
	}

	.cancel-btn {
		background: #F3F4F6;
		color: #374151;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #E5E7EB;
		transform: translateY(-1px);
	}

	.create-btn {
		background: #10B981;
		color: white;
	}

	.create-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.cancel-btn:disabled,
	.create-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
		transform: none;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.page-header {
			padding: 1rem;
			padding-top: calc(1rem + env(safe-area-inset-top));
		}

		.content-section {
			padding: 1rem;
		}

		.form-section {
			padding: 1rem;
		}

		.form-row {
			grid-template-columns: 1fr;
		}

		.action-section {
			padding: 1rem;
			padding-bottom: calc(1rem + env(safe-area-inset-bottom));
		}

		.action-buttons {
			flex-direction: column;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.page-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.action-section {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}
</style>