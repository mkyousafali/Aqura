<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();
	
	// Props from parent component
	export let onDataChanged: (() => Promise<void>) | null = null;

	// Form data
	let formData = {
		username: '',
		password: '',
		confirmPassword: '',
		quickAccessCode: '',
		confirmQuickAccessCode: '',
		userType: 'branch_specific',
		branchId: '',
		employeeId: '',
		roleType: 'Position-based',
		roleId: '',
		positionId: '',
		avatar: null
	};

	// Real data from database
	let branches: any[] = [];
	let employees: any[] = [];
	let roles: any[] = [];
	let positions: any[] = [];

	// State variables
	let isLoading = false;
	let loadingData = true;
	let errors: Record<string, string> = {};
	let successMessage = '';
	let dataError = '';

	// Load data on mount
	onMount(async () => {
		await loadInitialData();
	});

	async function loadInitialData() {
		try {
			loadingData = true;
			dataError = '';

			console.log('🔄 [CreateUser] Loading initial data...');

			// Load all necessary data concurrently
			const [branchesResult, rolesResult, employeesResult, positionsResult] = await Promise.all([
				userManagement.getBranches(),
				userManagement.getUserRoles(),
				userManagement.getEmployees(),
				userManagement.getPositions()
			]);

			branches = branchesResult;
			roles = rolesResult;
			employees = employeesResult;
			positions = positionsResult;

			console.log('✅ [CreateUser] Loaded branches:', branches?.length || 0, branches);
			console.log('✅ [CreateUser] Loaded roles:', roles?.length || 0, roles);
			console.log('✅ [CreateUser] Loaded employees:', employees?.length || 0, employees);
			console.log('✅ [CreateUser] Loaded positions:', positions?.length || 0, positions);

			// Check if any data is missing
			if (!employees || employees.length === 0) {
				console.warn('⚠️ [CreateUser] No employees loaded - this will prevent user creation');
			}

		} catch (err) {
			console.error('❌ [CreateUser] Error loading create user data:', err);
			dataError = err.message;
		} finally {
			loadingData = false;
		}
	}

	// Avatar handling
	let avatarPreview = null;
	let avatarFile = null;

	// Password validation
	let passwordChecks = {
		minLength: false,
		hasUppercase: false,
		hasLowercase: false,
		hasNumber: false,
		hasSpecialChar: false
	};

	// Search and filtering for employees
	let employeeSearchTerm = '';
	let selectedEmployee = null;
	
	// Filtered employees based on selected branch
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

	// Debug logging for employee filtering
	$: {
		console.log('🔍 [CreateUser] Branch filtering debug:', {
			selectedBranch: formData.branchId,
			totalEmployees: employees?.length || 0,
			filteredEmployees: filteredEmployees?.length || 0,
			searchedEmployees: searchedEmployees?.length || 0,
			searchTerm: employeeSearchTerm
		});
	}

	// Update form data when employee is selected
	function selectEmployee(employee) {
		console.log('👤 [CreateUser] Selecting employee:', employee);
		selectedEmployee = employee;
		formData.employeeId = employee.id;
		errors.employeeId = '';
		console.log('👤 [CreateUser] Employee selected - formData.employeeId:', formData.employeeId);
		console.log('👤 [CreateUser] Selected employee object:', selectedEmployee);
	}

	// Clear employee selection when branch changes (not just when branch has value)
	let previousBranchId = '';
	$: if (formData.branchId !== previousBranchId) {
		console.log('🔄 [CreateUser] Branch changed from', previousBranchId, 'to', formData.branchId);
		if (previousBranchId !== '') { // Only clear if this isn't the initial load
			selectedEmployee = null;
			formData.employeeId = '';
			employeeSearchTerm = '';
			console.log('🔄 [CreateUser] Cleared employee selection due to branch change');
		}
		previousBranchId = formData.branchId;
	}

	// Clear role/position selection when role type changes
	$: if (formData.roleType) {
		if (formData.roleType === 'Position-based') {
			formData.roleId = '';
		} else {
			formData.positionId = '';
		}
	}

	// Password validation reactive
	$: {
		const password = formData.password;
		passwordChecks = {
			minLength: password.length >= 8,
			hasUppercase: /[A-Z]/.test(password),
			hasLowercase: /[a-z]/.test(password),
			hasNumber: /[0-9]/.test(password),
			hasSpecialChar: /[^A-Za-z0-9]/.test(password)
		};
	}

	$: isPasswordValid = Object.values(passwordChecks).every(check => check);
	$: isQuickAccessValid = formData.quickAccessCode.length === 6 && /^[0-9]{6}$/.test(formData.quickAccessCode);

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
	}

	function validateForm() {
		errors = {};

		if (!formData.username.trim()) {
			errors.username = 'Username is required';
		} else if (formData.username.length < 3) {
			errors.username = 'Username must be at least 3 characters';
		}

		if (!formData.password) {
			errors.password = 'Password is required';
		} else if (!isPasswordValid) {
			errors.password = 'Password does not meet requirements';
		}

		if (formData.password !== formData.confirmPassword) {
			errors.confirmPassword = 'Passwords do not match';
		}

		if (!formData.quickAccessCode) {
			errors.quickAccessCode = 'Quick Access Code is required';
		} else if (!isQuickAccessValid) {
			errors.quickAccessCode = 'Quick Access Code must be 6 digits';
		}

		if (formData.quickAccessCode !== formData.confirmQuickAccessCode) {
			errors.confirmQuickAccessCode = 'Quick Access Codes do not match';
		}

		if (formData.userType === 'branch_specific' && !formData.branchId) {
			errors.branchId = 'Branch is required for branch-specific users';
		}

		if (!formData.employeeId) {
			errors.employeeId = 'Employee selection is required';
		}

		if (formData.roleType === 'Position-based' && !formData.positionId) {
			errors.positionId = 'Position is required for position-based roles';
		} else if (formData.roleType !== 'Position-based' && !formData.roleId) {
			errors.roleId = 'Role is required';
		}

		return Object.keys(errors).length === 0;
	}

	async function handleSubmit() {
		if (!validateForm()) {
			return;
		}

		isLoading = true;
		successMessage = '';
		errors = {};

		try {
			// Check if username is available
			const isUsernameAvailable = await userManagement.isUsernameAvailable(formData.username);
			if (!isUsernameAvailable) {
				errors.username = 'Username is already taken';
				return;
			}

			// Check if quick access code is available (if provided)
			if (formData.quickAccessCode) {
				const isQuickAccessAvailable = await userManagement.isQuickAccessCodeAvailable(formData.quickAccessCode);
				if (!isQuickAccessAvailable) {
					errors.quickAccessCode = 'Quick access code is already in use';
					return;
				}
			}

			// Prepare user data for creation
			const userData = {
				username: formData.username,
				password: formData.password,
				roleType: formData.roleType as any,
				userType: formData.userType as any,
				branchId: formData.branchId ? parseInt(formData.branchId) : null,
				employeeId: formData.employeeId || null,
				positionId: formData.positionId || null,
				quickAccessCode: formData.quickAccessCode || null
			};

			// Create the user
			const result = await userManagement.createUser(userData);

			if (result.success) {
				successMessage = `User created successfully! Quick Access Code: ${result.quick_access_code}`;
				
				// Notify parent component to refresh data
				if (onDataChanged) {
					await onDataChanged();
				}
				
				// Reset form after success
				setTimeout(() => {
					resetForm();
				}, 3000);
			} else {
				errors.submit = result.message || 'Failed to create user';
			}

		} catch (error) {
			console.error('Error creating user:', error);
			errors.submit = error.message || 'Failed to create user';
		} finally {
			isLoading = false;
		}
	}

	function resetForm() {
		formData = {
			username: '',
			password: '',
			confirmPassword: '',
			quickAccessCode: '',
			confirmQuickAccessCode: '',
			userType: 'branch_specific',
			branchId: '',
			employeeId: '',
			roleType: 'Position-based',
			roleId: '',
			positionId: '',
			avatar: null
		};
		errors = {};
		successMessage = '';
		avatarFile = null;
		avatarPreview = '';
	}

	function handleClose() {
		dispatch('close');
	}
</script>

<div class="create-user">
	<div class="header">
		<h1 class="title">Create New User</h1>
		<p class="subtitle">Add a new user account to the system</p>
	</div>

	{#if loadingData}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading form data...</p>
		</div>
	{:else if dataError}
		<div class="error-container">
			<div class="error-message">
				<h3>Error Loading Data</h3>
				<p>{dataError}</p>
				<button class="retry-btn" on:click={loadInitialData}>
					🔄 Retry
				</button>
			</div>
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
		</div>

		<!-- Security Section -->
		<div class="form-section">
			<h2 class="section-title">Security</h2>
			
			<div class="form-row">
				<div class="form-group">
					<label for="password" class="form-label">Password *</label>
					<input
						type="password"
						id="password"
						bind:value={formData.password}
						class="form-input"
						class:error={errors.password}
						placeholder="Enter password"
						required
					>
					{#if errors.password}
						<span class="error-message">{errors.password}</span>
					{/if}
				</div>

				<div class="form-group">
					<label for="confirmPassword" class="form-label">Confirm Password *</label>
					<input
						type="password"
						id="confirmPassword"
						bind:value={formData.confirmPassword}
						class="form-input"
						class:error={errors.confirmPassword}
						placeholder="Confirm password"
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

			<!-- Quick Access Code -->
			<div class="form-row">
				<div class="form-group">
					<label for="quickAccessCode" class="form-label">Quick Access Code (6 digits) *</label>
					<div class="input-with-button">
						<input
							type="text"
							id="quickAccessCode"
							bind:value={formData.quickAccessCode}
							class="form-input"
							class:error={errors.quickAccessCode}
							placeholder="123456"
							maxlength="6"
							inputmode="numeric"
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
					<label for="confirmQuickAccessCode" class="form-label">Confirm Quick Access Code *</label>
					<input
						type="text"
						id="confirmQuickAccessCode"
						bind:value={formData.confirmQuickAccessCode}
						class="form-input"
						class:error={errors.confirmQuickAccessCode}
						placeholder="123456"
						maxlength="6"
						inputmode="numeric"
					>
					{#if errors.confirmQuickAccessCode}
						<span class="error-message">{errors.confirmQuickAccessCode}</span>
					{/if}
				</div>
			</div>
		</div>

		<!-- Assignment Section -->
		<div class="form-section">
			<h2 class="section-title">Assignment</h2>
			
			<!-- Branch Selection -->
			{#if formData.userType === 'branch_specific'}
				<div class="form-group full-width">
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

			<!-- Employee Selection Table -->
			{#if formData.branchId || formData.userType === 'global'}
				<div class="employee-selection">
					<div class="selection-header">
						<h3 class="selection-title">Select Employee *</h3>
						{#if selectedEmployee}
							<div class="selected-employee-info">
								<span class="selected-badge">Selected:</span>
								<span class="employee-name">{selectedEmployee.name}</span>
								<span class="employee-id">({selectedEmployee.employee_id || selectedEmployee.id})</span>
								{#if selectedEmployee.position_title_en}
									<span class="employee-position">- {selectedEmployee.position_title_en}</span>
								{/if}
								<button type="button" class="clear-selection" on:click={() => { selectedEmployee = null; formData.employeeId = ''; }}>
									×
								</button>
							</div>
						{/if}
					</div>
					
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
													{employee.position_title_en || 'No Position'}
												</td>
												<td class="employee-action-cell">
													<button 
														type="button" 
														class="select-btn"
														on:click|stopPropagation={() => selectEmployee(employee)}
													>
														Select
													</button>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							{:else if employeeSearchTerm}
								<div class="no-results">
									<p>No employees found matching "{employeeSearchTerm}"</p>
									<p class="help-text">Try adjusting your search or check if employees are properly assigned to this branch.</p>
								</div>
							{:else if formData.branchId && filteredEmployees.length === 0}
								<div class="no-results">
									<p>No employees found in the selected branch</p>
									<p class="help-text">This branch may not have any employees assigned yet. Please contact your administrator.</p>
								</div>
							{:else if !formData.branchId}
								<div class="no-results">
									<p>Please select a branch to view employees</p>
									<p class="help-text">Employee selection is filtered by branch for better organization.</p>
								</div>
							{:else if employees.length === 0}
								<div class="no-results">
									<p>No employees available in the system</p>
									<p class="help-text">Please add employees to the HR system before creating users.</p>
								</div>
							{/if}
						</div>
					{/if}
				</div>
				
				{#if errors.employeeId}
					<span class="error-message">{errors.employeeId}</span>
				{/if}
			{/if}

			<!-- Role Type Selection -->
			<div class="form-row role-selection">
				<div class="form-group">
					<label for="roleType" class="form-label">Role Type *</label>
					<select
						id="roleType"
						bind:value={formData.roleType}
						class="form-select"
						class:error={errors.roleType}
					>
						<option value="Position-based">Position-based</option>
						<option value="Admin">Admin</option>
						<option value="Master Admin">Master Admin</option>
					</select>
				</div>

				<!-- Position Selection (only for Position-based roles) -->
				{#if formData.roleType === 'Position-based'}
					<div class="form-group">
						<label for="positionId" class="form-label">Position *</label>
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
						{#if errors.positionId}
							<span class="error-message">{errors.positionId}</span>
						{/if}
					</div>
				{:else}
					<!-- Role Selection for non-position-based roles -->
					<div class="form-group">
						<label for="roleId" class="form-label">Role *</label>
						<select
							id="roleId"
							bind:value={formData.roleId}
							class="form-select"
							class:error={errors.roleId}
						>
							<option value="">Select Role</option>
							{#each roles as role}
								<option value={role.id}>{role.role_name}</option>
							{/each}
						</select>
						{#if errors.roleId}
							<span class="error-message">{errors.roleId}</span>
						{/if}
					</div>
				{/if}
			</div>
		</div>

		<!-- Avatar Section -->
		<div class="form-section">
			<h2 class="section-title">Avatar (Optional)</h2>
			
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
						📷 Choose Image
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
					Creating User...
				{:else}
					<span class="icon">👤</span>
					Create User
				{/if}
			</button>
		</div>
	</form>
	{/if}
</div>

<style>
	.create-user {
		height: 100%;
		background: #f8fafc;
		overflow-y: auto;
		padding: 24px;
	}

	/* Loading and Error States */
	.loading-container, .error-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 300px;
		text-align: center;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-left-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.loading-container p {
		color: #6b7280;
		font-size: 14px;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 20px;
		max-width: 400px;
	}

	.error-message h3 {
		color: #dc2626;
		margin: 0 0 8px 0;
		font-size: 16px;
	}

	.error-message p {
		color: #7f1d1d;
		margin: 0 0 16px 0;
		font-size: 14px;
	}

	.retry-btn {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.retry-btn:hover {
		background: #b91c1c;
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

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		margin-bottom: 20px;
	}

	.form-row.role-selection {
		margin-top: 24px;
		padding-top: 20px;
		border-top: 1px solid #e5e7eb;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group.full-width {
		grid-column: 1 / -1;
	}

	/* Employee Selection Styles */
	.employee-selection {
		margin: 24px 0;
	}

	.selection-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 16px;
		flex-wrap: wrap;
		gap: 12px;
	}

	.selection-title {
		font-size: 16px;
		font-weight: 600;
		color: #374151;
		margin: 0;
	}

	.selected-employee-info {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #ecfdf5;
		border: 1px solid #a7f3d0;
		border-radius: 6px;
		padding: 8px 12px;
		font-size: 14px;
	}

	.selected-badge {
		color: #065f46;
		font-weight: 600;
	}

	.employee-name {
		color: #111827;
		font-weight: 500;
	}

	.employee-id {
		color: #6b7280;
		font-size: 13px;
	}

	.employee-position {
		color: #059669;
		font-size: 13px;
	}

	.clear-selection {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 4px;
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 14px;
		line-height: 1;
	}

	.clear-selection:hover {
		background: #b91c1c;
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

	.no-results {
		padding: 40px 20px;
		text-align: center;
		color: #6b7280;
		background: #f9fafb;
	}

	.no-results p {
		margin: 0;
		font-size: 14px;
	}

	.no-results .help-text {
		margin-top: 8px;
		font-size: 12px;
		color: #9ca3af;
		font-style: italic;
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
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.submit-btn:hover:not(:disabled) {
		background: #2563eb;
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

	.icon {
		font-size: 16px;
	}

	@media (max-width: 768px) {
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

		.selection-header {
			flex-direction: column;
			align-items: flex-start;
		}

		.selected-employee-info {
			width: 100%;
			justify-content: space-between;
		}

		.employee-table-container {
			overflow-x: auto;
		}

		.employee-table {
			min-width: 600px;
		}

		.employee-table th,
		.employee-table td {
			padding: 8px;
		}
	}
</style>