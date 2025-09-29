<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();

	// Props
	export let user: any = null;

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
		roleType: user?.role_type || 'position_based',
		roleId: user?.role_id || '',
		positionId: user?.position_id || '',
		status: user?.status || 'active',
		avatar: null
	};

	// Real data from database
	let branches: Array<{ id: string; name: string }> = [];
	let employees: Array<{ id: string; name: string; branch_id: string }> = [];
	let roles: Array<{ id: string; name: string; code: string }> = [];
	let positions: Array<{ id: string; name: string }> = [];

	// Load data from database
	async function loadInitialData() {
		try {
			// Load branches
			const branchesData = await userManagement.getBranches();
			branches = branchesData.map(branch => ({
				id: branch.id.toString(),
				name: branch.name
			}));

			// Load roles
			const rolesData = await userManagement.getUserRoles();
			roles = rolesData.map(role => ({
				id: role.id,
				name: role.role_name,
				code: role.role_code
			}));

			// Note: Employees and positions would need additional API methods
			// For now, keeping them empty until those endpoints are implemented
			
		} catch (error) {
			console.error('Error loading initial data:', error);
		}
	}

	onMount(() => {
		loadInitialData();
	});

	// State variables
	let isLoading = false;
	let errors: Record<string, string> = {};
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
		role_type: 'Master Admin' // or 'Admin'
	};

	// Check if current user can edit this user
	let canEdit = true;
	let canChangeStatus = currentUser.role_type === 'Master Admin' || 
		(currentUser.role_type === 'Admin' && user?.role_type !== 'Master Admin');

	// Filtered employees based on selected branch
	$: filteredEmployees = formData.branchId 
		? employees.filter(emp => emp.branch_id === formData.branchId)
		: employees;

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

		if (formData.roleType === 'position_based' && !formData.positionId) {
			errors.positionId = 'Position is required for position-based roles';
		} else if (formData.roleType !== 'position_based' && !formData.roleId) {
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

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 2000));
			
			// Here you would make the actual API call to update the user
			const updateData = {
				...formData,
				avatar: avatarFile,
				passwordChanged: showPasswordFields,
				quickAccessChanged: showQuickAccessFields
			};
			console.log('Updating user with data:', updateData);

			successMessage = 'User updated successfully!';

		} catch (error) {
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
		if (user?.role_type === 'Master Admin' && formData.status === 'inactive') {
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
				
				<div class="form-row">
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
									<option value={branch.id}>{branch.name}</option>
								{/each}
							</select>
							{#if errors.branchId}
								<span class="error-message">{errors.branchId}</span>
							{/if}
						</div>
					{/if}

					<div class="form-group">
						<label for="employeeId" class="form-label">Employee *</label>
						<select
							id="employeeId"
							bind:value={formData.employeeId}
							class="form-select"
							class:error={errors.employeeId}
						>
							<option value="">Select Employee</option>
							{#each filteredEmployees as employee}
								<option value={employee.id}>{employee.name}</option>
							{/each}
						</select>
						{#if errors.employeeId}
							<span class="error-message">{errors.employeeId}</span>
						{/if}
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label for="roleType" class="form-label">Role Type *</label>
						<select
							id="roleType"
							bind:value={formData.roleType}
							class="form-select"
							class:error={errors.roleType}
						>
							<option value="position_based">Position-based</option>
							<option value="admin">Admin</option>
							<option value="master_admin">Master Admin</option>
						</select>
					</div>

					{#if formData.roleType === 'position_based'}
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
									<option value={position.id}>{position.name}</option>
								{/each}
							</select>
							{#if errors.positionId}
								<span class="error-message">{errors.positionId}</span>
							{/if}
						</div>
					{:else}
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
									<option value={role.id}>{role.name}</option>
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

	.icon {
		font-size: 16px;
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