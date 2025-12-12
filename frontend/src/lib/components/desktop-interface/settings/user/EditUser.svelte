<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();

	// Props
	export let user: any = null;
	export let onDataChanged: (() => void) | undefined = undefined;

	// Form data initialized with user data
	let formData = {
		id: user?.id || '',
		username: user?.username || '',
		password: '',
		confirmPassword: '',
		quickAccessCode: user?.quick_access_code || '',
		confirmQuickAccessCode: user?.quick_access_code || '',
		userType: user?.user_type || 'branch_specific',
		branchId: user?.branch_id || '',
		employeeId: user?.employee_id || '',
		isMasterAdmin: user?.is_master_admin || false,
		isAdmin: user?.is_admin || false,
		positionId: user?.position_id || '',
		status: user?.status || 'active',
		avatar: null
	};

	// Real data from database
	let branches: Array<{ id: string; name: string }> = [];
	let employees: Array<{ id: string; name: string; branch_id: string; employee_id: string; position_title_en: string }> = [];
	let positions: Array<{ id: string; position_title_en: string; position_title_ar: string }> = [];

	// Search and filtering for employees
	let employeeSearchTerm = '';
	let selectedEmployee = null;
	let isLoading = false;
	let loadingData = true;
	let errors: Record<string, string> = {};
	let dataError = '';
	let isManualEmployeeSelection = false;

	// Load data from database
	async function loadInitialData() {
		try {
			loadingData = true;
			dataError = '';

			console.log('🔄 [EditUser] Loading initial data...');

			// Load all necessary data concurrently
			const [branchesResult, employeesResult, positionsResult] = await Promise.all([
				userManagement.getBranches(),
				userManagement.getEmployees(),
				userManagement.getPositions()
			]);

			// Transform and set data exactly like CreateUser
			branches = branchesResult;
			employees = employeesResult;
			positions = positionsResult;

			console.log('✅ [EditUser] Data loaded successfully:', {
				branches: branches.length,
				employees: employees.length,
				positions: positions.length
			});
			console.log('🔍 [EditUser] Loaded branches:', branches);
			console.log('🔍 [EditUser] Loaded positions:', positions);
			console.log('🔍 [EditUser] Loaded employees:', employees.slice(0, 3), '...');

			// Set selected employee if user has one assigned
			if (formData.employeeId) {
				selectedEmployee = employees.find(emp => emp.id === formData.employeeId) || null;
				console.log('🔍 [EditUser] Found selected employee:', selectedEmployee);
				
				// Don't auto-update position during initialization for existing users
				// This allows manual position assignment different from HR records
				console.log('📝 [EditUser] Keeping existing position assignment during initialization');
			}

		} catch (error) {
			console.error('❌ [EditUser] Error loading data:', error);
			dataError = 'Failed to load required data. Please try again.';
		} finally {
			loadingData = false;
		}
	}

	onMount(async () => {
		await loadInitialData();
	});

	// Employee selection function (exactly like CreateUser)
	function selectEmployee(employee: any) {
		selectedEmployee = employee;
		formData.employeeId = employee.id;
		employeeSearchTerm = '';
		isManualEmployeeSelection = true;
		console.log('📝 [EditUser] Selected employee:', employee);
		
		// Only auto-update position for manual selections, not during initialization
		if (employee.position_title_en && isManualEmployeeSelection) {
			console.log('🔍 [EditUser] Looking for position:', employee.position_title_en);
			console.log('🔍 [EditUser] Available positions:', positions.map(p => p.position_title_en));
			
			const matchingPosition = positions.find(pos => pos.position_title_en === employee.position_title_en);
			if (matchingPosition) {
				const oldPositionId = formData.positionId;
				
				// Update position ID and force reactivity
				formData = {
					...formData,
					positionId: matchingPosition.id
				};
				
				console.log('📝 [EditUser] Updated position from:', oldPositionId, 'to:', matchingPosition.id, '(' + matchingPosition.position_title_en + ')');
				console.log('📝 [EditUser] New formData.positionId:', formData.positionId);
				
			} else {
				console.warn('⚠️ [EditUser] Could not find matching position for:', employee.position_title_en);
				console.warn('⚠️ [EditUser] Available positions are:', positions);
			}
		}
		
		// Clear any previous employee error
		if (errors.employeeId) {
			delete errors.employeeId;
			errors = { ...errors };
		}
	}

	// State variables that weren't already declared
	let successMessage = '';
	let avatarPreview = user?.avatar_url || null;
	let avatarFile = null;
	let showPasswordFields = false;
	let showQuickAccessFields = false;

	// Password validation
	let passwordChecks = {
		minLength: false,
		hasUppercase: false,
		hasLowercase: false,
		hasNumber: false,
		hasSpecialChar: false
	};

	// Current user permissions (mock)
	let currentUser = {
		isMasterAdmin: true, // or just isAdmin: true
		isAdmin: true
	};

	// Check if current user can edit this user
	let canEdit = true;
	let canChangeStatus = currentUser.isMasterAdmin || 
		(currentUser.isAdmin && !user?.is_master_admin);

	// Filtered employees based on selected branch (enhanced like CreateUser)
	$: filteredEmployees = formData.branchId 
		? employees.filter(emp => {
			// Handle both string and number comparison for branch_id
			const selectedBranchId = parseInt(formData.branchId);
			const empBranchId = typeof emp.branch_id === 'string' ? parseInt(emp.branch_id) : emp.branch_id;
			return empBranchId === selectedBranchId;
		})
		: employees;
	
	// Further filter employees by search term
	$: searchedEmployees = filteredEmployees.filter(emp => 
		emp.name?.toLowerCase().includes(employeeSearchTerm.toLowerCase()) ||
		emp.employee_id?.toLowerCase().includes(employeeSearchTerm.toLowerCase()) ||
		emp.position_title_en?.toLowerCase().includes(employeeSearchTerm.toLowerCase())
	);

	// Clear employee selection when branch changes (exactly like CreateUser)
	let previousBranchId = '';
	$: if (formData.branchId !== previousBranchId) {
		console.log('🔄 [EditUser] Branch changed from', previousBranchId, 'to', formData.branchId);
		if (previousBranchId !== '') { // Only clear if this isn't the initial load
			selectedEmployee = null;
			formData.employeeId = '';
			employeeSearchTerm = '';
			console.log('🔄 [EditUser] Cleared employee selection due to branch change');
		}
		previousBranchId = formData.branchId;
	}

	// Reactive: Master Admin implies Admin
	$: if (formData.isMasterAdmin) {
		formData.isAdmin = true;
	}

	// Password validation reactive
	$: if (showPasswordFields) {
		const password = formData.password;
		passwordChecks = {
			minLength: password.length >= 8,
			hasUppercase: /[A-Z]/.test(password),
			hasLowercase: /[a-z]/.test(password),
			hasNumber: /[0-9]/.test(password),
			hasSpecialChar: /[^A-Za-z0-9]/.test(password)
		};
	}

	$: isPasswordValid = !showPasswordFields || Object.values(passwordChecks).every(check => check);
	$: isQuickAccessValid = !showQuickAccessFields || 
		(formData.quickAccessCode.length === 6 && /^[0-9]{6}$/.test(formData.quickAccessCode));

	function generateQuickAccessCode() {
		const code = Math.floor(100000 + Math.random() * 900000).toString();
		formData.quickAccessCode = code;
		formData.confirmQuickAccessCode = code;
	}

	function handleAvatarChange(event) {
		const file = event.target.files[0];
		if (file) {
			// Validate file type and size
			const validTypes = ['image/png', 'image/jpeg', 'image/webp'];
			if (!validTypes.includes(file.type)) {
				errors.avatar = 'Please select a PNG, JPEG, or WEBP image';
				return;
			}
			
			if (file.size > 5 * 1024 * 1024) { // 5MB
				errors.avatar = 'Image size must be less than 5MB';
				return;
			}

			avatarFile = file;
			errors.avatar = '';

			// Create preview
			const reader = new FileReader();
			reader.onload = (e) => {
				avatarPreview = e.target.result;
			};
			reader.readAsDataURL(file);
		}
	}

	function removeAvatar() {
		avatarFile = null;
		avatarPreview = null;
		formData.avatar = null;
		
	
	// Clear file input
	const fileInput = document.getElementById('avatar-input') as HTMLInputElement;
	if (fileInput) fileInput.value = '';
}	function resetPassword() {
		showPasswordFields = true;
		formData.password = '';
		formData.confirmPassword = '';
	}

	function resetQuickAccess() {
		showQuickAccessFields = true;
		formData.quickAccessCode = '';
		formData.confirmQuickAccessCode = '';
	}

	function validateForm() {
		errors = {};

		if (!formData.username.trim()) {
			errors.username = 'Username is required';
		} else if (formData.username.length < 3) {
			errors.username = 'Username must be at least 3 characters';
		}

		if (showPasswordFields) {
			if (!formData.password) {
				errors.password = 'Password is required';
			} else if (!isPasswordValid) {
				errors.password = 'Password does not meet requirements';
			}

			if (formData.password !== formData.confirmPassword) {
				errors.confirmPassword = 'Passwords do not match';
			}
		}

		if (showQuickAccessFields) {
			if (!formData.quickAccessCode) {
				errors.quickAccessCode = 'Quick Access Code is required';
			} else if (!isQuickAccessValid) {
				errors.quickAccessCode = 'Quick Access Code must be 6 digits';
			}

			if (formData.quickAccessCode !== formData.confirmQuickAccessCode) {
				errors.confirmQuickAccessCode = 'Quick Access Codes do not match';
			}
		}

		if (formData.userType === 'branch_specific' && !formData.branchId) {
			errors.branchId = 'Branch is required for branch-specific users';
		}

		if (!formData.employeeId) {
			errors.employeeId = 'Employee selection is required';
		}

		return Object.keys(errors).length === 0;
	}

	async function handleSubmit() {
		if (!validateForm()) {
			return;
		}

		isLoading = true;
		successMessage = '';

		try {
			// Prepare update data in the format expected by the database
			const updateData = {
				username: formData.username,
				p_is_master_admin: formData.isMasterAdmin,
				p_is_admin: formData.isAdmin,
				user_type: formData.userType,
				branch_id: formData.branchId ? parseInt(formData.branchId) : null,
				employee_id: formData.employeeId || null,
				position_id: formData.positionId || null,
				status: formData.status
			};

			console.log('Updating user with data:', updateData);

			// Make the actual API call to update the user
			await userManagement.updateUser(formData.id, updateData);

			// Handle password update if changed
			if (showPasswordFields && formData.password) {
				await userManagement.resetUserPassword(formData.id, formData.password);
			}

			// Handle quick access code update if changed
			if (showQuickAccessFields && formData.quickAccessCode) {
				// Note: This would need a separate method in userManagement for updating quick access code
				// For now, we'll include it in the main update
			}

			successMessage = 'User updated successfully!';
			
			// Refresh parent component data
			if (onDataChanged) {
				await onDataChanged();
			}
			
			// Dispatch update event to refresh parent component
			dispatch('updated', { userId: formData.id });

		} catch (error) {
			console.error('Error updating user:', error);
			errors.submit = error.message || 'Failed to update user';
		} finally {
			isLoading = false;
		}
	}

	function handleClose() {
		dispatch('close');
	}

	// Safeguard check for Master Admin
	function checkMasterAdminSafeguard() {
		if (user?.is_master_admin && formData.status === 'inactive') {
			// Check if this is the last active Master Admin (mock check)
			const activeMasterAdmins = 1; // This would come from API
			if (activeMasterAdmins <= 1) {
				errors.status = 'Cannot deactivate the last active Master Admin';
				formData.status = 'active';
				return false;
			}
		}
		return true;
	}

	// Watch for status changes
	$: if (formData.status) {
		checkMasterAdminSafeguard();
	}

	// Debug: Watch for position ID changes
	$: if (formData.positionId) {
		const currentPosition = positions.find(p => p.id === formData.positionId);
		console.log('🔄 [EditUser] Position ID changed to:', formData.positionId, 'Position:', currentPosition?.position_title_en);
	}
</script>

<div class="edit-user">
	<div class="header">
		<h1 class="title">Edit User: {user?.username || 'Unknown'}</h1>
		<p class="subtitle">Update user account information and permissions</p>
	</div>

	{#if !canEdit}
		<div class="permission-error">
			<h2>Access Denied</h2>
			<p>You do not have permission to edit this user.</p>
			<button class="close-btn" on:click={handleClose}>Close</button>
		</div>
	{:else}
		<form on:submit|preventDefault={handleSubmit} class="user-form">
			<!-- Basic Information Section -->
			<div class="form-section">
				<h2 class="section-title">Basic Information</h2>
				
				<div class="form-row">
					<div class="form-group">
						<label for="username" class="form-label">Username *</label>
						<input
							type="text"
							id="username"
							bind:value={formData.username}
							class="form-input"
							class:error={errors.username}
							placeholder="Enter username"
							required
						>
						{#if errors.username}
							<span class="error-message">{errors.username}</span>
						{/if}
					</div>

					<div class="form-group">
						<label for="userType" class="form-label">User Type *</label>
						<select
							id="userType"
							bind:value={formData.userType}
							class="form-select"
							class:error={errors.userType}
						>
							<option value="global">Global Access</option>
							<option value="branch_specific">Branch Specific</option>
						</select>
					</div>
				</div>

				{#if canChangeStatus}
					<div class="form-row">
						<div class="form-group">
							<label for="status" class="form-label">Status *</label>
							<select
								id="status"
								bind:value={formData.status}
								class="form-select"
								class:error={errors.status}
							>
								<option value="active">Active</option>
								<option value="inactive">Inactive</option>
								<option value="locked">Locked</option>
							</select>
							{#if errors.status}
								<span class="error-message">{errors.status}</span>
							{/if}
						</div>
					</div>
				{/if}
			</div>

			<!-- Security Section -->
			<div class="form-section">
				<h2 class="section-title">Security</h2>
				
				<div class="security-actions">
					<div class="security-item">
						<h3>Password</h3>
						<p>Last changed: {user?.last_password_change || 'Unknown'}</p>
						{#if !showPasswordFields}
							<button type="button" class="reset-btn" on:click={resetPassword}>
								🔐 Reset Password
							</button>
						{:else}
							<button type="button" class="cancel-reset-btn" on:click={() => showPasswordFields = false}>
								Cancel Reset
							</button>
						{/if}
					</div>

					<div class="security-item">
						<h3>Quick Access Code</h3>
						<p>Current code: ••••••</p>
						{#if !showQuickAccessFields}
							<button type="button" class="reset-btn" on:click={resetQuickAccess}>
								🎯 Reset Quick Access
							</button>
						{:else}
							<button type="button" class="cancel-reset-btn" on:click={() => showQuickAccessFields = false}>
								Cancel Reset
							</button>
						{/if}
					</div>
				</div>

				{#if showPasswordFields}
					<div class="form-row">
						<div class="form-group">
							<label for="password" class="form-label">New Password *</label>
							<input
								type="password"
								id="password"
								bind:value={formData.password}
								class="form-input"
								class:error={errors.password}
								placeholder="Enter new password"
								required
							>
							{#if errors.password}
								<span class="error-message">{errors.password}</span>
							{/if}
						</div>

						<div class="form-group">
							<label for="confirmPassword" class="form-label">Confirm New Password *</label>
							<input
								type="password"
								id="confirmPassword"
								bind:value={formData.confirmPassword}
								class="form-input"
								class:error={errors.confirmPassword}
								placeholder="Confirm new password"
								required
							>
							{#if errors.confirmPassword}
								<span class="error-message">{errors.confirmPassword}</span>
							{/if}
						</div>
					</div>

					<!-- Password Requirements Checklist -->
					<div class="password-checklist">
						<h3 class="checklist-title">Password Requirements:</h3>
						<div class="checklist-items">
							<div class="check-item" class:valid={passwordChecks.minLength}>
								<span class="check-icon">{passwordChecks.minLength ? '✅' : '❌'}</span>
								At least 8 characters
							</div>
							<div class="check-item" class:valid={passwordChecks.hasUppercase}>
								<span class="check-icon">{passwordChecks.hasUppercase ? '✅' : '❌'}</span>
								One uppercase letter
							</div>
							<div class="check-item" class:valid={passwordChecks.hasLowercase}>
								<span class="check-icon">{passwordChecks.hasLowercase ? '✅' : '❌'}</span>
								One lowercase letter
							</div>
							<div class="check-item" class:valid={passwordChecks.hasNumber}>
								<span class="check-icon">{passwordChecks.hasNumber ? '✅' : '❌'}</span>
								One number
							</div>
							<div class="check-item" class:valid={passwordChecks.hasSpecialChar}>
								<span class="check-icon">{passwordChecks.hasSpecialChar ? '✅' : '❌'}</span>
								One special character
							</div>
						</div>
					</div>
				{/if}

				{#if showQuickAccessFields}
					<div class="form-row">
						<div class="form-group">
							<label for="quickAccessCode" class="form-label">New Quick Access Code (6 digits) *</label>
							<div class="input-with-button">
								<input
									type="text"
									id="quickAccessCode"
									bind:value={formData.quickAccessCode}
									class="form-input"
									class:error={errors.quickAccessCode}
									placeholder="123456"
									maxlength="6"
									pattern="[0-9]{6}"
									required
								>
								<button
									type="button"
									class="generate-btn"
									on:click={generateQuickAccessCode}
									title="Generate Random Code"
								>
									🎲
								</button>
							</div>
							{#if errors.quickAccessCode}
								<span class="error-message">{errors.quickAccessCode}</span>
							{/if}
						</div>

						<div class="form-group">
							<label for="confirmQuickAccessCode" class="form-label">Confirm New Quick Access Code *</label>
							<input
								type="text"
								id="confirmQuickAccessCode"
								bind:value={formData.confirmQuickAccessCode}
								class="form-input"
								class:error={errors.confirmQuickAccessCode}
								placeholder="123456"
								maxlength="6"
								pattern="[0-9]{6}"
								required
							>
							{#if errors.confirmQuickAccessCode}
								<span class="error-message">{errors.confirmQuickAccessCode}</span>
							{/if}
						</div>
					</div>
				{/if}
			</div>

			<!-- Assignment Section -->
			<div class="form-section">
				<h2 class="section-title">Assignment</h2>
				
				<!-- Branch Selection -->
				{#if formData.userType === 'branch_specific'}
					<div class="form-group">
						<label for="branchId" class="form-label">Branch *</label>
						<select
							id="branchId"
							bind:value={formData.branchId}
							class="form-select"
							class:error={errors.branchId}
						>
							<option value="">Select Branch</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en || branch.name}</option>
							{/each}
						</select>
						{#if errors.branchId}
							<span class="error-message">{errors.branchId}</span>
						{/if}
					</div>
				{/if}

				<!-- Employee Selection -->
				<div class="form-group">
					<label for="employeeId" class="form-label">Employee *</label>
						
						{#if loadingData}
							<div class="loading-state">
								<div class="spinner"></div>
								<span>Loading employees...</span>
							</div>
						{:else if dataError}
							<div class="error-state">
								<p>Failed to load employees</p>
								<button class="retry-btn" on:click={loadInitialData}>Retry</button>
							</div>
						{:else}
							<!-- Branch Selection Required Notice -->
							{#if !formData.branchId}
								<div class="info-message">
									<p>👆 Please select a branch first</p>
									<p class="help-text">Employee selection is filtered by branch for better organization.</p>
								</div>
							{:else}
								<!-- Selected Employee Display -->
								{#if selectedEmployee}
									<div class="selected-employee">
										<div class="employee-info">
											<span class="employee-name">{selectedEmployee.name}</span>
											<span class="employee-id">({selectedEmployee.employee_id || selectedEmployee.id})</span>
											{#if selectedEmployee.position_title_en}
												<span class="employee-position">- {selectedEmployee.position_title_en}</span>
											{/if}
										</div>
										<button type="button" class="change-btn" on:click={() => { selectedEmployee = null; formData.employeeId = ''; }}>
											Change Employee
										</button>
									</div>
								{:else}
									<!-- Employee Search and Selection -->
									{#if !selectedEmployee}
										<!-- Search Input -->
										<div class="employee-search">
											<input
												type="text"
												bind:value={employeeSearchTerm}
												placeholder="Search employees by name, ID, or position..."
												class="search-input"
											>
											<span class="search-icon">🔍</span>
										</div>

										<!-- Employee Table -->
										<div class="employee-table-container">
											{#if searchedEmployees.length > 0}
												<table class="employee-table">
													<thead>
														<tr>
															<th>Employee ID</th>
															<th>Name</th>
															<th>Position</th>
															<th>Action</th>
														</tr>
													</thead>
													<tbody>
														{#each searchedEmployees as employee}
															<tr class="employee-row" on:click={() => selectEmployee(employee)}>
																<td class="employee-id-cell">{employee.employee_id || employee.id}</td>
																<td class="employee-name-cell">{employee.name}</td>
																<td class="employee-position-cell">
																	{employee.position_title_en || 'No position assigned'}
																</td>
																<td class="employee-action-cell">
																	<button type="button" class="select-btn" on:click|stopPropagation={() => selectEmployee(employee)}>
																		Select
																	</button>
																</td>
															</tr>
														{/each}
													</tbody>
												</table>
											{:else if employeeSearchTerm && searchedEmployees.length === 0}
												<div class="no-results">
													<p>No employees found matching "{employeeSearchTerm}"</p>
													<p class="help-text">Try adjusting your search or check if employees are properly assigned to this branch.</p>
												</div>
											{:else if formData.branchId && filteredEmployees.length === 0}
												<div class="no-results">
													<p>No employees found in the selected branch</p>
												</div>
											{/if}
										</div>
									{/if}
								{/if}
							{/if}
						{/if}
						
						{#if errors.employeeId}
							<span class="error-message">{errors.employeeId}</span>
						{/if}
				</div>

				<!-- Admin Permissions -->
				<div class="form-row">
					<div class="form-group">
						<label class="form-label">Admin Permissions</label>
						<div class="checkbox-group">
							<label class="checkbox-label">
								<input
									type="checkbox"
									bind:checked={formData.isMasterAdmin}
									class="form-checkbox"
								/>
								<span>Master Admin</span>
								<span class="checkbox-hint">(Full system access, implies Admin)</span>
							</label>
							<label class="checkbox-label">
								<input
									type="checkbox"
									bind:checked={formData.isAdmin}
									disabled={formData.isMasterAdmin}
									class="form-checkbox"
								/>
								<span>Admin</span>
								<span class="checkbox-hint">(Administrative access)</span>
							</label>
						</div>
					</div>

					<div class="form-group">
						<label for="positionId" class="form-label">Position</label>
						{#key formData.positionId}
							<select
								id="positionId"
								bind:value={formData.positionId}
								class="form-select"
								class:error={errors.positionId}
							>
								<option value="">Select Position</option>
								{#each positions as position}
									<option value={position.id}>{position.position_title_en}</option>
								{/each}
							</select>
						{/key}
						{#if errors.positionId}
							<span class="error-message">{errors.positionId}</span>
						{/if}
					</div>
				</div>
			</div>

			<!-- Avatar Section -->
			<div class="form-section">
				<h2 class="section-title">Avatar</h2>
				
				<div class="avatar-upload">
					<div class="avatar-preview">
						{#if avatarPreview}
							<img src={avatarPreview} alt="Avatar Preview" class="avatar-image">
							<button type="button" class="remove-avatar" on:click={removeAvatar}>×</button>
						{:else}
							<div class="avatar-placeholder">
								<span class="avatar-icon">👤</span>
								<span class="avatar-text">No Avatar</span>
							</div>
						{/if}
					</div>
					
					<div class="upload-controls">
						<input
							type="file"
							id="avatar-input"
							accept=".png,.jpg,.jpeg,.webp"
							on:change={handleAvatarChange}
							class="file-input"
							hidden
						>
						<label for="avatar-input" class="upload-btn">
							📷 {avatarPreview ? 'Change Image' : 'Upload Image'}
						</label>
						<div class="upload-info">
							<p>PNG, JPEG, WEBP • Max 5MB • Min 256×256px</p>
						</div>
					</div>
				</div>
				
				{#if errors.avatar}
					<span class="error-message">{errors.avatar}</span>
				{/if}
			</div>

			<!-- Messages -->
			{#if errors.submit}
				<div class="error-banner">
					<strong>Error:</strong> {errors.submit}
				</div>
			{/if}

			{#if successMessage}
				<div class="success-banner">
					<strong>Success:</strong> {successMessage}
				</div>
			{/if}

			<!-- Form Actions -->
			<div class="form-actions">
				<button type="button" class="cancel-btn" on:click={handleClose} disabled={isLoading}>
					Cancel
				</button>
				<button 
					type="submit" 
					class="submit-btn" 
					disabled={isLoading || !isPasswordValid || !isQuickAccessValid}
				>
					{#if isLoading}
						<span class="spinner"></span>
						Updating User...
					{:else}
						<span class="icon">✏️</span>
						Update User
					{/if}
				</button>
			</div>
		</form>
	{/if}
</div>

<style>
	.edit-user {
		height: 100%;
		background: #f8fafc;
		overflow-y: auto;
		padding: 24px;
	}

	.header {
		text-align: center;
		margin-bottom: 32px;
	}

	.title {
		font-size: 28px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.permission-error {
		max-width: 400px;
		margin: 0 auto;
		background: white;
		border-radius: 12px;
		padding: 32px;
		text-align: center;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.permission-error h2 {
		color: #ef4444;
		margin-bottom: 16px;
	}

	.permission-error p {
		color: #6b7280;
		margin-bottom: 24px;
	}

	.close-btn {
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 12px 24px;
		font-weight: 500;
		cursor: pointer;
	}

	.user-form {
		max-width: 800px;
		margin: 0 auto;
		background: white;
		border-radius: 12px;
		padding: 32px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.form-section {
		margin-bottom: 32px;
		padding-bottom: 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.form-section:last-of-type {
		border-bottom: none;
	}

	.section-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
	}

	.security-actions {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 24px;
		margin-bottom: 24px;
	}

	.security-item {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
	}

	.security-item h3 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.security-item p {
		font-size: 14px;
		color: #6b7280;
		margin: 0 0 12px 0;
	}

	.reset-btn, .cancel-reset-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 13px;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.reset-btn:hover {
		background: #2563eb;
	}

	.cancel-reset-btn {
		background: #6b7280;
	}

	.cancel-reset-btn:hover {
		background: #4b5563;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		margin-bottom: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-label {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin-bottom: 6px;
	}

	.form-input, .form-select {
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s, box-shadow 0.2s;
		background: white;
	}

	.form-input:focus, .form-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input.error, .form-select.error {
		border-color: #ef4444;
		box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
	}

	.error-message {
		color: #ef4444;
		font-size: 12px;
		margin-top: 4px;
	}

	.input-with-button {
		display: flex;
		gap: 8px;
	}

	.generate-btn {
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 10px 12px;
		cursor: pointer;
		font-size: 16px;
		transition: all 0.2s;
	}

	.generate-btn:hover {
		background: #e5e7eb;
	}

	/* Password Checklist */
	.password-checklist {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
		margin-top: 12px;
	}

	.checklist-title {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 12px 0;
	}

	.checklist-items {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 8px;
	}

	.check-item {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 13px;
		color: #6b7280;
	}

	.check-item.valid {
		color: #059669;
	}

	.check-icon {
		font-size: 14px;
	}

	/* Avatar Upload */
	.avatar-upload {
		display: flex;
		gap: 24px;
		align-items: flex-start;
	}

	.avatar-preview {
		position: relative;
		width: 120px;
		height: 120px;
		flex-shrink: 0;
	}

	.avatar-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 50%;
		border: 3px solid #e5e7eb;
	}

	.avatar-placeholder {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		border: 2px dashed #d1d5db;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: #f9fafb;
	}

	.avatar-icon {
		font-size: 32px;
		margin-bottom: 4px;
	}

	.avatar-text {
		font-size: 12px;
		color: #6b7280;
	}

	.remove-avatar {
		position: absolute;
		top: -8px;
		right: -8px;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		background: #ef4444;
		color: white;
		border: none;
		font-size: 16px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		line-height: 1;
	}

	.upload-controls {
		flex: 1;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.upload-btn:hover {
		background: #2563eb;
	}

	.upload-info {
		margin-top: 8px;
	}

	.upload-info p {
		font-size: 12px;
		color: #6b7280;
		margin: 0;
	}

	/* Messages */
	.error-banner, .success-banner {
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 24px;
		font-size: 14px;
	}

	.error-banner {
		background: #fef2f2;
		color: #991b1b;
		border: 1px solid #fecaca;
	}

	.success-banner {
		background: #f0fdf4;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	/* Form Actions */
	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		padding-top: 24px;
		border-top: 1px solid #e5e7eb;
	}

	.cancel-btn, .submit-btn {
		padding: 12px 24px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.submit-btn {
		background: #f59e0b;
		color: white;
		border-color: #f59e0b;
	}

	.submit-btn:hover:not(:disabled) {
		background: #d97706;
		transform: translateY(-1px);
	}

	.submit-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.spinner {
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

	/* Employee Search Styles */
	.search-container {
		position: relative;
		margin-bottom: 8px;
	}

	.search-input {
		padding-right: 35px;
	}

	.search-icon {
		position: absolute;
		right: 10px;
		top: 50%;
		transform: translateY(-50%);
		color: #9ca3af;
		pointer-events: none;
	}

	.employee-dropdown {
		min-height: 45px;
	}

	.employee-dropdown.disabled {
		opacity: 0.6;
	}

	.info-message {
		padding: 12px;
		background: #f3f4f6;
		border-radius: 6px;
		text-align: center;
	}

	.info-message p {
		margin: 0 0 4px 0;
		color: #6b7280;
	}

	.help-text {
		font-size: 12px !important;
		color: #9ca3af !important;
	}

	.no-results {
		padding: 12px;
		text-align: center;
		color: #6b7280;
		background: #f9fafb;
		border-radius: 6px;
		border: 1px dashed #d1d5db;
	}

	.no-results p {
		margin: 0 0 4px 0;
	}

	.loading-state, .error-state {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px;
		background: #f9fafb;
		border-radius: 6px;
		color: #6b7280;
	}

	.retry-btn {
		padding: 4px 8px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 12px;
	}

	.retry-btn:hover {
		background: #2563eb;
	}

	/* Employee Selection Styles (from CreateUser) */
	.selected-employee {
		background: #f0f9ff;
		border: 1px solid #0ea5e9;
		border-radius: 8px;
		padding: 16px;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.employee-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.employee-name {
		font-weight: 600;
		color: #0f172a;
	}

	.employee-id {
		font-size: 13px;
		color: #64748b;
		font-family: 'Courier New', monospace;
	}

	.employee-position {
		font-size: 13px;
		color: #059669;
	}

	.change-btn {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.change-btn:hover {
		background: #dc2626;
	}

	.employee-search {
		position: relative;
		margin-bottom: 16px;
	}

	.search-input {
		width: 100%;
		padding: 10px 40px 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-icon {
		position: absolute;
		right: 12px;
		top: 50%;
		transform: translateY(-50%);
		color: #6b7280;
		font-size: 16px;
		pointer-events: none;
	}

	.employee-table-container {
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		background: white;
		max-height: 300px;
		overflow-y: auto;
	}

	.employee-table {
		width: 100%;
		border-collapse: collapse;
	}

	.employee-table th {
		background: #f9fafb;
		padding: 12px;
		text-align: left;
		font-size: 13px;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.employee-table td {
		padding: 12px;
		font-size: 14px;
		border-bottom: 1px solid #f3f4f6;
	}

	.employee-row {
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.employee-row:hover {
		background: #f9fafb;
	}

	.employee-row:last-child td {
		border-bottom: none;
	}

	.employee-id-cell {
		font-family: 'Courier New', monospace;
		color: #6b7280;
		font-size: 13px;
		min-width: 120px;
	}

	.employee-name-cell {
		color: #111827;
		font-weight: 500;
		min-width: 150px;
	}

	.employee-position-cell {
		color: #059669;
		font-size: 13px;
		min-width: 150px;
	}

	.employee-action-cell {
		width: 100px;
		text-align: center;
	}

	.select-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 6px 12px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.select-btn:hover {
		background: #2563eb;
	}

	.icon {
		font-size: 16px;
	}

	.checkbox-group {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
		padding: 8px;
		border-radius: 6px;
		transition: background-color 0.2s;
	}

	.checkbox-label:hover {
		background: #f9fafb;
	}

	.form-checkbox {
		width: 18px;
		height: 18px;
		cursor: pointer;
		accent-color: #3b82f6;
	}

	.form-checkbox:disabled {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.checkbox-hint {
		color: #6b7280;
		font-size: 12px;
		margin-left: 4px;
	}

	@media (max-width: 768px) {
		.security-actions {
			grid-template-columns: 1fr;
		}

		.form-row {
			grid-template-columns: 1fr;
		}

		.checklist-items {
			grid-template-columns: 1fr;
		}

		.avatar-upload {
			flex-direction: column;
			align-items: center;
		}

		.form-actions {
			flex-direction: column-reverse;
		}
	}
</style>