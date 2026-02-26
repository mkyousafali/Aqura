<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';
	import { supabase } from '$lib/utils/supabase';

	const dispatch = createEventDispatcher();
	
	// Generate unique IDs for this component instance to avoid duplicate ID warnings
	const componentId = Math.random().toString(36).substr(2, 9);
	const usernameId = `username-${componentId}`;
	const passwordId = `password-${componentId}`;
	const confirmPasswordId = `confirmPassword-${componentId}`;
	const quickAccessCodeId = `quickAccessCode-${componentId}`;
	const confirmQuickAccessCodeId = `confirmQuickAccessCode-${componentId}`;
	const userTypeId = `userType-${componentId}`;
	const branchId = `branchId-${componentId}`;
	const employeeId = `employeeId-${componentId}`;
	const positionIdField = `positionId-${componentId}`;
	const isMasterAdminId = `isMasterAdmin-${componentId}`;
	const isAdminId = `isAdmin-${componentId}`;
	const avatarInputId = `avatar-input-${componentId}`;
	const whatsappNumberId = `whatsappNumber-${componentId}`;
	const emailFieldId = `email-${componentId}`;
	
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
		isMasterAdmin: false,
		isAdmin: false,
		positionId: '',
		avatar: null,
		whatsappNumber: '',
		email: ''
	};

	// Real data from database
	let branches: any[] = [];
	let employees: any[] = [];
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
		const [branchesResult, employeesResult, positionsResult] = await Promise.all([
			userManagement.getBranches(),
			userManagement.getEmployees(),
			userManagement.getPositions()
		]);

		branches = branchesResult;
		employees = employeesResult;
		positions = positionsResult;

		console.log('✅ [CreateUser] Loaded branches:', branches?.length || 0, branches);
		console.log('✅ [CreateUser] Loaded employees:', employees?.length || 0, employees);
		console.log('✅ [CreateUser] Loaded positions:', positions?.length || 0, positions);		// Check if any data is missing
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

	// Reactive: Master Admin implies Admin
	$: if (formData.isMasterAdmin) {
		formData.isAdmin = true;
	}

	// Avatar handling
	let avatarPreview = null;
	let avatarFile = null;	// Password validation
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

		if (!formData.whatsappNumber.trim()) {
			errors.whatsappNumber = 'WhatsApp number is required';
		} else if (!/^\+?[0-9]{7,15}$/.test(formData.whatsappNumber.replace(/[\s-]/g, ''))) {
			errors.whatsappNumber = 'Enter a valid phone number (e.g. +966501234567)';
		}

		if (!formData.email.trim()) {
			errors.email = 'Email is required';
		} else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
			errors.email = 'Enter a valid email address';
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
				isMasterAdmin: formData.isMasterAdmin,
				isAdmin: formData.isAdmin,
				userType: formData.userType as any,
				branchId: formData.branchId ? parseInt(formData.branchId) : null,
				employeeId: formData.employeeId || null,
				positionId: formData.positionId || null,
				quickAccessCode: formData.quickAccessCode || null
			};

			// Create the user
			const result = await userManagement.createUser(userData);

			if (result.success) {
				// Save whatsapp_number and email to hr_employee_master
				if (formData.employeeId) {
					const { error: empUpdateError } = await supabase
						.from('hr_employee_master')
						.update({
							whatsapp_number: formData.whatsappNumber.trim(),
							email: formData.email.trim()
						})
						.eq('id', formData.employeeId);
					if (empUpdateError) {
						console.warn('⚠️ Could not update hr_employee_master with WhatsApp/email:', empUpdateError);
					}
				}

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
			isMasterAdmin: false,
			isAdmin: false,
			positionId: '',
			avatar: null,
			whatsappNumber: '',
			email: ''
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

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div>
            <h1 class="text-xl font-black text-slate-800 uppercase tracking-wide">👤 Create New User</h1>
            <p class="text-xs text-slate-500 mt-0.5">Add a new user account to the system</p>
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Futuristic background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-4xl mx-auto">
            {#if loadingData}
                <div class="flex items-center justify-center h-64">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">Loading form data...</p>
                    </div>
                </div>
            {:else if dataError}
                <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                    <p class="text-red-700 font-semibold">Error: {dataError}</p>
                    <button 
                        class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                        on:click={loadInitialData}
                    >
                        🔄 Retry
                    </button>
                </div>
            {:else}
                <form on:submit|preventDefault={handleSubmit}>
                    <!-- Basic Information Section -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mb-6">
                        <h2 class="text-sm font-black text-slate-700 uppercase tracking-wider mb-5 flex items-center gap-2">
                            <span class="inline-block w-1.5 h-5 bg-blue-600 rounded-full"></span>
                            Basic Information
                        </h2>
                        
                        <div class="grid grid-cols-2 gap-4 mb-4">
                            <div>
                                <label for={usernameId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Username *</label>
                                <input
                                    type="text"
                                    id={usernameId}
                                    bind:value={formData.username}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all {errors.username ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    placeholder="Enter username"
                                    required
                                >
                                {#if errors.username}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.username}</p>
                                {/if}
                            </div>

                            <div>
                                <label for={userTypeId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">User Type *</label>
                                <select
                                    id={userTypeId}
                                    bind:value={formData.userType}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                                    style="color: #000000 !important; background-color: #ffffff !important;"
                                >
                                    <option value="global" style="color: #000000 !important; background-color: #ffffff !important;">Global Access</option>
                                    <option value="branch_specific" style="color: #000000 !important; background-color: #ffffff !important;">Branch Specific</option>
                                </select>
                            </div>
                        </div>

                        <!-- WhatsApp Number and Email -->
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label for={whatsappNumberId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">📱 WhatsApp Number *</label>
                                <input
                                    type="tel"
                                    id={whatsappNumberId}
                                    bind:value={formData.whatsappNumber}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all {errors.whatsappNumber ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    placeholder="+966501234567"
                                    required
                                >
                                {#if errors.whatsappNumber}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.whatsappNumber}</p>
                                {/if}
                            </div>

                            <div>
                                <label for={emailFieldId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">📧 Email *</label>
                                <input
                                    type="email"
                                    id={emailFieldId}
                                    bind:value={formData.email}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all {errors.email ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    placeholder="user@example.com"
                                    required
                                >
                                {#if errors.email}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.email}</p>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <!-- Security Section -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mb-6">
                        <h2 class="text-sm font-black text-slate-700 uppercase tracking-wider mb-5 flex items-center gap-2">
                            <span class="inline-block w-1.5 h-5 bg-amber-500 rounded-full"></span>
                            Security
                        </h2>
                        
                        <div class="grid grid-cols-2 gap-4 mb-4">
                            <div>
                                <label for={passwordId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Password *</label>
                                <input
                                    type="password"
                                    id={passwordId}
                                    bind:value={formData.password}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all {errors.password ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    placeholder="Enter password"
                                    required
                                >
                                {#if errors.password}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.password}</p>
                                {/if}
                            </div>

                            <div>
                                <label for={confirmPasswordId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Confirm Password *</label>
                                <input
                                    type="password"
                                    id={confirmPasswordId}
                                    bind:value={formData.confirmPassword}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all {errors.confirmPassword ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    placeholder="Confirm password"
                                    required
                                >
                                {#if errors.confirmPassword}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.confirmPassword}</p>
                                {/if}
                            </div>
                        </div>

                        <!-- Password Requirements Checklist -->
                        <div class="bg-slate-50/80 border border-slate-200 rounded-xl p-4 mb-4">
                            <h3 class="text-xs font-bold text-slate-600 uppercase tracking-wide mb-3">Password Requirements</h3>
                            <div class="grid grid-cols-2 gap-2">
                                <div class="flex items-center gap-2 text-xs {passwordChecks.minLength ? 'text-emerald-600' : 'text-slate-400'}">
                                    <span>{passwordChecks.minLength ? '✅' : '❌'}</span>
                                    At least 8 characters
                                </div>
                                <div class="flex items-center gap-2 text-xs {passwordChecks.hasUppercase ? 'text-emerald-600' : 'text-slate-400'}">
                                    <span>{passwordChecks.hasUppercase ? '✅' : '❌'}</span>
                                    One uppercase letter
                                </div>
                                <div class="flex items-center gap-2 text-xs {passwordChecks.hasLowercase ? 'text-emerald-600' : 'text-slate-400'}">
                                    <span>{passwordChecks.hasLowercase ? '✅' : '❌'}</span>
                                    One lowercase letter
                                </div>
                                <div class="flex items-center gap-2 text-xs {passwordChecks.hasNumber ? 'text-emerald-600' : 'text-slate-400'}">
                                    <span>{passwordChecks.hasNumber ? '✅' : '❌'}</span>
                                    One number
                                </div>
                                <div class="flex items-center gap-2 text-xs {passwordChecks.hasSpecialChar ? 'text-emerald-600' : 'text-slate-400'}">
                                    <span>{passwordChecks.hasSpecialChar ? '✅' : '❌'}</span>
                                    One special character
                                </div>
                            </div>
                        </div>

                        <!-- Quick Access Code -->
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label for={quickAccessCodeId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Quick Access Code (6 digits) *</label>
                                <div class="flex gap-2">
                                    <input
                                        type="text"
                                        id={quickAccessCodeId}
                                        bind:value={formData.quickAccessCode}
                                        class="flex-1 px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all font-mono {errors.quickAccessCode ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                        placeholder="123456"
                                        maxlength="6"
                                        inputmode="numeric"
                                    >
                                    <button
                                        type="button"
                                        class="px-3.5 py-2.5 bg-slate-100 border border-slate-200 rounded-xl hover:bg-slate-200 transition-all text-lg"
                                        on:click={generateQuickAccessCode}
                                        title="Generate Random Code"
                                    >
                                        🎲
                                    </button>
                                </div>
                                {#if errors.quickAccessCode}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.quickAccessCode}</p>
                                {/if}
                            </div>

                            <div>
                                <label for={confirmQuickAccessCodeId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Confirm Quick Access Code *</label>
                                <input
                                    type="text"
                                    id={confirmQuickAccessCodeId}
                                    bind:value={formData.confirmQuickAccessCode}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all font-mono {errors.confirmQuickAccessCode ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    placeholder="123456"
                                    maxlength="6"
                                    inputmode="numeric"
                                >
                                {#if errors.confirmQuickAccessCode}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.confirmQuickAccessCode}</p>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <!-- Assignment Section -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mb-6">
                        <h2 class="text-sm font-black text-slate-700 uppercase tracking-wider mb-5 flex items-center gap-2">
                            <span class="inline-block w-1.5 h-5 bg-emerald-600 rounded-full"></span>
                            Assignment
                        </h2>
                        
                        <!-- Branch Selection -->
                        {#if formData.userType === 'branch_specific'}
                            <div class="mb-4">
                                <label for={branchId} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Branch *</label>
                                <select
                                    id={branchId}
                                    bind:value={formData.branchId}
                                    class="w-full px-4 py-2.5 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all {errors.branchId ? 'border-red-400 ring-2 ring-red-200' : 'border-slate-200'}"
                                    style="color: #000000 !important; background-color: #ffffff !important;"
                                >
                                    <option value="" style="color: #000000 !important; background-color: #ffffff !important;">Select Branch</option>
                                    {#each branches as branch}
                                        <option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">{branch.name_en || branch.name}</option>
                                    {/each}
                                </select>
                                {#if errors.branchId}
                                    <p class="text-red-500 text-xs mt-1.5 font-medium">{errors.branchId}</p>
                                {/if}
                            </div>
                        {/if}

                        <!-- Employee Selection Table -->
                        {#if formData.branchId || formData.userType === 'global'}
                            <div class="mb-4">
                                <div class="flex items-center justify-between mb-3 flex-wrap gap-3">
                                    <h3 class="text-xs font-bold text-slate-600 uppercase tracking-wide">Select Employee *</h3>
                                    {#if selectedEmployee}
                                        <div class="flex items-center gap-2 bg-emerald-50 border border-emerald-200 rounded-xl px-3 py-2 text-sm">
                                            <span class="text-emerald-700 font-bold text-xs">Selected:</span>
                                            <span class="text-slate-800 font-semibold text-xs">{selectedEmployee.name}</span>
                                            <span class="text-slate-500 text-xs">({selectedEmployee.employee_id || selectedEmployee.id})</span>
                                            {#if selectedEmployee.position_title_en}
                                                <span class="text-emerald-600 text-xs">- {selectedEmployee.position_title_en}</span>
                                            {/if}
                                            <button type="button" class="ml-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs flex items-center justify-center hover:bg-red-600 transition" on:click={() => { selectedEmployee = null; formData.employeeId = ''; }}>
                                                ×
                                            </button>
                                        </div>
                                    {/if}
                                </div>
                                
                                {#if !selectedEmployee}
                                    <!-- Search Input -->
                                    <div class="relative mb-3">
                                        <input
                                            type="text"
                                            bind:value={employeeSearchTerm}
                                            placeholder="Search employees by name, ID, or position..."
                                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all pr-10"
                                        >
                                        <span class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none">🔍</span>
                                    </div>

                                    <!-- Employee Table -->
                                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] overflow-hidden max-h-64 overflow-y-auto">
                                        {#if searchedEmployees.length > 0}
                                            <table class="w-full border-collapse">
                                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                                    <tr>
                                                        <th class="px-4 py-2.5 text-left text-xs font-black uppercase tracking-wider">Employee ID</th>
                                                        <th class="px-4 py-2.5 text-left text-xs font-black uppercase tracking-wider">Name</th>
                                                        <th class="px-4 py-2.5 text-left text-xs font-black uppercase tracking-wider">Position</th>
                                                        <th class="px-4 py-2.5 text-center text-xs font-black uppercase tracking-wider">Action</th>
                                                    </tr>
                                                </thead>
                                                <tbody class="divide-y divide-slate-200">
                                                    {#each searchedEmployees as employee, index}
                                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 cursor-pointer {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}" on:click={() => selectEmployee(employee)}>
                                                            <td class="px-4 py-2.5 text-xs text-slate-500 font-mono">{employee.employee_id || employee.id}</td>
                                                            <td class="px-4 py-2.5 text-sm text-slate-800 font-semibold">{employee.name}</td>
                                                            <td class="px-4 py-2.5 text-xs text-emerald-600">{employee.position_title_en || 'No Position'}</td>
                                                            <td class="px-4 py-2.5 text-center">
                                                                <button 
                                                                    type="button" 
                                                                    class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
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
                                            <div class="p-8 text-center text-slate-500">
                                                <p class="font-semibold text-sm">No employees found matching "{employeeSearchTerm}"</p>
                                                <p class="text-xs mt-1 text-slate-400">Try adjusting your search or check if employees are properly assigned to this branch.</p>
                                            </div>
                                        {:else if formData.branchId && filteredEmployees.length === 0}
                                            <div class="p-8 text-center text-slate-500">
                                                <p class="font-semibold text-sm">No employees found in the selected branch</p>
                                                <p class="text-xs mt-1 text-slate-400">This branch may not have any employees assigned yet.</p>
                                            </div>
                                        {:else if !formData.branchId}
                                            <div class="p-8 text-center text-slate-500">
                                                <p class="font-semibold text-sm">Please select a branch to view employees</p>
                                            </div>
                                        {:else if employees.length === 0}
                                            <div class="p-8 text-center text-slate-500">
                                                <p class="font-semibold text-sm">No employees available in the system</p>
                                                <p class="text-xs mt-1 text-slate-400">Please add employees to the HR system before creating users.</p>
                                            </div>
                                        {/if}
                                    </div>
                                {/if}
                            </div>
                            
                            {#if errors.employeeId}
                                <p class="text-red-500 text-xs mt-1 font-medium">{errors.employeeId}</p>
                            {/if}
                        {/if}

                        <!-- Admin Privileges Section -->
                        <div class="grid grid-cols-2 gap-4 mt-4 pt-4 border-t border-slate-200/50">
                            <div class="flex items-start gap-3 bg-slate-50/60 rounded-xl p-3">
                                <input
                                    type="checkbox"
                                    id={isMasterAdminId}
                                    bind:checked={formData.isMasterAdmin}
                                    class="mt-0.5 w-4 h-4 accent-blue-600 cursor-pointer"
                                />
                                <div>
                                    <label for={isMasterAdminId} class="text-sm font-semibold text-slate-700 cursor-pointer">Make Master Admin</label>
                                    <p class="text-xs text-slate-400 mt-0.5">Full system access</p>
                                </div>
                            </div>

                            <div class="flex items-start gap-3 bg-slate-50/60 rounded-xl p-3">
                                <input
                                    type="checkbox"
                                    id={isAdminId}
                                    bind:checked={formData.isAdmin}
                                    disabled={formData.isMasterAdmin}
                                    class="mt-0.5 w-4 h-4 accent-blue-600 cursor-pointer disabled:opacity-50"
                                />
                                <div>
                                    <label for={isAdminId} class="text-sm font-semibold text-slate-700 cursor-pointer">Make Admin</label>
                                    <p class="text-xs text-slate-400 mt-0.5">Manage users & approve workflows</p>
                                </div>
                            </div>
                        </div>

                        <!-- Position Selection -->
                        <div class="mt-4">
                            <label for={positionIdField} class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Position</label>
                            <select
                                id={positionIdField}
                                bind:value={formData.positionId}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">Select Position (Optional)</option>
                                {#each positions as position}
                                    <option value={position.id} style="color: #000000 !important; background-color: #ffffff !important;">{position.position_title_en}</option>
                                {/each}
                            </select>
                        </div>
                    </div>

                    <!-- Avatar Section -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mb-6">
                        <h2 class="text-sm font-black text-slate-700 uppercase tracking-wider mb-5 flex items-center gap-2">
                            <span class="inline-block w-1.5 h-5 bg-purple-500 rounded-full"></span>
                            Avatar (Optional)
                        </h2>
                        
                        <div class="flex gap-6 items-start">
                            <div class="relative w-24 h-24 flex-shrink-0">
                                {#if avatarPreview}
                                    <img src={avatarPreview} alt="Avatar Preview" class="w-full h-full object-cover rounded-full border-3 border-slate-200 shadow-lg">
                                    <button type="button" class="absolute -top-1 -right-1 w-6 h-6 bg-red-500 text-white rounded-full text-xs flex items-center justify-center hover:bg-red-600 transition shadow-md" on:click={removeAvatar}>×</button>
                                {:else}
                                    <div class="w-full h-full rounded-full border-2 border-dashed border-slate-300 flex flex-col items-center justify-center bg-slate-50/80">
                                        <span class="text-3xl">👤</span>
                                        <span class="text-[10px] text-slate-400 mt-0.5">No Avatar</span>
                                    </div>
                                {/if}
                            </div>
                            
                            <div class="flex-1">
                                <input
                                    type="file"
                                    id={avatarInputId}
                                    accept=".png,.jpg,.jpeg,.webp"
                                    on:change={handleAvatarChange}
                                    hidden
                                >
                                <label for={avatarInputId} class="inline-flex items-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-bold cursor-pointer hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105">
                                    📷 Choose Image
                                </label>
                                <p class="text-xs text-slate-400 mt-2">PNG, JPEG, WEBP • Max 5MB • Min 256×256px</p>
                            </div>
                        </div>
                        
                        {#if errors.avatar}
                            <p class="text-red-500 text-xs mt-2 font-medium">{errors.avatar}</p>
                        {/if}
                    </div>

                    <!-- Messages -->
                    {#if errors.submit}
                        <div class="bg-red-50 border border-red-200 rounded-2xl p-4 mb-6 text-sm text-red-800 font-semibold">
                            <strong>Error:</strong> {errors.submit}
                        </div>
                    {/if}

                    {#if successMessage}
                        <div class="bg-emerald-50 border border-emerald-200 rounded-2xl p-4 mb-6 text-sm text-emerald-800 font-semibold">
                            <strong>Success:</strong> {successMessage}
                        </div>
                    {/if}

                    <!-- Form Actions -->
                    <div class="flex gap-3 justify-end pt-2 pb-4">
                        <button type="button" class="px-6 py-2.5 bg-white border border-slate-200 text-slate-600 rounded-xl text-sm font-bold hover:bg-slate-50 hover:shadow-md transition-all duration-200" on:click={handleClose} disabled={isLoading}>
                            Cancel
                        </button>
                        <button 
                            type="submit" 
                            class="inline-flex items-center gap-2 px-6 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                            disabled={isLoading || !isPasswordValid || !isQuickAccessValid}
                        >
                            {#if isLoading}
                                <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                                Creating User...
                            {:else}
                                👤 Create User
                            {/if}
                        </button>
                    </div>
                </form>
            {/if}
        </div>
    </div>
</div>

<style>
	/* Minimal scoped styles - most styling is via Tailwind classes */
</style>