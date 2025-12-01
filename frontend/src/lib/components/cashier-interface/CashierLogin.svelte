<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { setCashierAuth } from '$lib/stores/cashierAuth';
	import { t, currentLocale, switchLocale } from '$lib/i18n';

	const dispatch = createEventDispatcher();

	let accessCode = '';
	let accessDigits = ['', '', '', '', '', ''];
	let selectedBranchId = '';
	let branches: any[] = [];
	let loading = false;
	let loadingBranches = true;
	let error = '';
	let step: 'accessCode' | 'branch' = 'accessCode';
	let authenticatedUser: any = null;

	// Load branches on mount
	async function loadBranches() {
		try {
			loadingBranches = true;
			const { data, error: branchError } = await supabaseAdmin
				.from('branches')
				.select('id, name_ar, name_en')
				.order('name_en');
			
			if (branchError) throw branchError;
			branches = data || [];
		} catch (err: any) {
			console.error('Error loading branches:', err);
			error = 'Failed to load branches';
		} finally {
			loadingBranches = false;
		}
	}

	loadBranches();

	async function handleAccessCodeSubmit() {
		accessCode = accessDigits.join('');
		
		if (accessCode.length !== 6 || !/^[0-9]+$/.test(accessCode)) {
			error = t('coupon.invalidAccessCode');
			return;
		}

		try {
			loading = true;
			error = '';

			// Authenticate with quick access code from users table
			const { data: userData, error: authError } = await supabaseAdmin
				.from('users')
				.select('id, username, employee_id, branch_id')
				.eq('quick_access_code', accessCode)
				.eq('status', 'active')
				.single();

			if (authError || !userData) {
				error = 'Invalid access code';
				accessDigits = ['', '', '', '', '', ''];
				accessCode = '';
				return;
			}

			// Check cashier permission
			const { data: permissionData, error: permissionError } = await supabaseAdmin
				.from('interface_permissions')
				.select('cashier_enabled')
				.eq('user_id', userData.id)
				.single();

			if (permissionError || !permissionData || permissionData.cashier_enabled !== true) {
				error = t('auth.cashierAccessDenied') || 'Access denied. Cashier permission is disabled for this user.';
				accessDigits = ['', '', '', '', '', ''];
				accessCode = '';
				return;
			}

			// Get employee details if employee_id exists
			let fullName = userData.username;
			if (userData.employee_id) {
				const { data: employeeData } = await supabaseAdmin
					.from('hr_employees')
					.select('name')
					.eq('id', userData.employee_id)
					.single();
				
				if (employeeData) {
					fullName = employeeData.name || userData.username;
				}
			}

			authenticatedUser = {
				...userData,
				full_name: fullName,
				employeeName: fullName,
				name: fullName,
				role: 'Cashier'
			};
			
			step = 'branch';
		} catch (err: any) {
			console.error('Login error:', err);
			error = 'Login failed. Please try again.';
			accessDigits = ['', '', '', '', '', ''];
			accessCode = '';
		} finally {
			loading = false;
		}
	}

	function handleBranchSelect() {
		if (!selectedBranchId) {
			error = t('coupon.selectBranch');
			return;
		}

		const selectedBranch = branches.find(b => b.id === selectedBranchId);
		if (!selectedBranch) {
			error = t('coupon.invalidBranchSelection');
			return;
		}

		// Dispatch login success event
		dispatch('loginSuccess', {
			user: authenticatedUser,
			branch: selectedBranch
		});
	}

	function goBack() {
		step = 'accessCode';
		error = '';
		accessDigits = ['', '', '', '', '', ''];
		accessCode = '';
		selectedBranchId = '';
	}

	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			accessDigits[index] = value.slice(-1);
			input.value = accessDigits[index];
			
			// Auto-focus next input
			if (index < 5 && accessDigits[index] !== '') {
				setTimeout(() => {
					const nextInput = document.getElementById(`digit-${index + 1}`) as HTMLInputElement;
					if (nextInput) {
						nextInput.focus();
						nextInput.select();
					}
				}, 10);
			}
		} else {
			accessDigits[index] = '';
		}
	}

	function handleDigitKeydown(event: KeyboardEvent, index: number) {
		const input = event.target as HTMLInputElement;
		
		// Handle Enter key - submit form if all digits are filled
		if (event.key === 'Enter') {
			event.preventDefault();
			const allFilled = accessDigits.every(d => d !== '');
			if (allFilled && !loading) {
				handleAccessCodeSubmit();
			}
			return;
		}
		
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (accessDigits[index] !== '') {
				accessDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
				accessDigits[index - 1] = '';
				const prevInput = document.getElementById(`digit-${index - 1}`) as HTMLInputElement;
				if (prevInput) {
					prevInput.value = '';
					prevInput.focus();
				}
			}
			return;
		}
		
		if (event.key === 'ArrowLeft' && index > 0) {
			event.preventDefault();
			const prevInput = document.getElementById(`digit-${index - 1}`) as HTMLInputElement;
			if (prevInput) {
				prevInput.focus();
				prevInput.select();
			}
		} else if (event.key === 'ArrowRight' && index < 5) {
			event.preventDefault();
			const nextInput = document.getElementById(`digit-${index + 1}`) as HTMLInputElement;
			if (nextInput) {
				nextInput.focus();
				nextInput.select();
			}
		}
		
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Enter'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		for (let i = 0; i < 6; i++) {
			accessDigits[i] = digits[i] || '';
			const input = document.getElementById(`digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = accessDigits[i];
			}
		}
		
		const lastFilledIndex = digits.length - 1;
		const targetIndex = Math.min(Math.max(lastFilledIndex + 1, 0), 5);
		const targetInput = document.getElementById(`digit-${targetIndex}`) as HTMLInputElement;
		if (targetInput) {
			targetInput.focus();
		}
	}
</script>

<div class="cashier-login-page mounted">
	<div class="login-content">
		<div class="login-main-card">
			<!-- Logo Section with Language Toggle -->
			<div class="logo-section">
				<div class="logo-header">
					<div class="logo">
						<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
					</div>
					<button 
						class="language-toggle-main" 
						on:click={() => {
							switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
							setTimeout(() => {
								window.location.reload();
							}, 100);
						}}
						title={t('nav.languageToggle') || 'Switch Language'}
					>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<path d="M8 12h8"/>
							<path d="M12 8v8"/>
						</svg>
						{$currentLocale === 'ar' ? 'English' : 'العربية'}
					</button>
				</div>
			</div>

			<!-- Main Content -->
			<div class="login-container">
				{#if step === 'accessCode'}
					<!-- Access Code Step -->
					<form class="auth-form" on:submit|preventDefault={handleAccessCodeSubmit}>
						<div class="form-header">
							<button type="button" class="back-btn" on:click={() => goto('/login')}>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.backToLogin') || 'Back to Login'}
							</button>
							<h2>{t('auth.quickAccess') || 'Quick Access'}</h2>
							<p>{t('coupon.accessCodeInstructions') || 'Enter your 6-digit security code to access the cashier interface'}</p>
						</div>

						<div class="form-fields">
							<div class="field-group">
								<label for="accessCode">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
										<circle cx="12" cy="16" r="1"/>
										<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
									</svg>
									{t('auth.accessCode') || 'Security Code'}
								</label>
								<div class="quick-access-digits">
									{#each accessDigits as digit, index}
										<input 
											id="digit-{index}"
											type="text" 
											class="digit-input"
											class:error={error && accessDigits.some(d => d !== '')}
											bind:value={accessDigits[index]}
											on:input={(e) => handleDigitInput(e, index)}
											on:keydown={(e) => handleDigitKeydown(e, index)}
											on:paste={handleDigitPaste}
											placeholder=""
											disabled={loading}
											maxlength="1"
											autocomplete="off"
											inputmode="numeric"
											pattern="[0-9]*"
										/>
									{/each}
								</div>
								{#if error}
									<span class="field-error">{error}</span>
								{/if}
							</div>

							<!-- Spacer -->
							<div class="field-spacer"></div>
						</div>

						<button 
							type="submit" 
							class="auth-submit-btn"
							disabled={loading || accessDigits.some(d => d === '')}
						>
							{#if loading}
								<span class="loading-spinner"></span>
								{t('auth.loggingIn') || 'Signing In...'}
							{:else}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
									<polyline points="10,17 15,12 10,7"/>
									<line x1="15" y1="12" x2="3" y2="12"/>
								</svg>
								{t('auth.continueLogin') || 'Continue to System'}
							{/if}
						</button>
					</form>

				{:else}
					<!-- Branch Selection Step -->
					<form class="auth-form" on:submit|preventDefault={handleBranchSelect}>
						<div class="form-header">
							<button type="button" class="back-btn" on:click={goBack}>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.back') || 'Back'}
							</button>
							<h2>{t('coupon.selectBranch') || 'Select Branch'}</h2>
							<p>{t('coupon.chooseBranchLocation') || 'Choose your branch location to continue'}</p>
						</div>

						<!-- User Info Card -->
						<div class="user-info-card">
							<div class="user-avatar">
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
									<circle cx="12" cy="7" r="4"/>
								</svg>
							</div>
							<div class="user-details">
								<div class="user-name">{authenticatedUser?.full_name || authenticatedUser?.username}</div>
								<div class="user-role">{t('coupon.cashier') || 'Cashier'}</div>
							</div>
						</div>

						<div class="form-fields">
							<div class="field-group">
								<label for="branch">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
										<circle cx="12" cy="10" r="3"/>
									</svg>
									{t('coupon.branch') || 'Branch Location'}
								</label>
								<select 
									id="branch"
									class="field-input"
									bind:value={selectedBranchId}
									disabled={loading || loadingBranches}
									on:keydown={(e) => {
										if (e.key === 'Enter' && selectedBranchId && !loading && !loadingBranches) {
											e.preventDefault();
											handleBranchSelect();
										}
									}}
								>
								<option value="">{loadingBranches ? 'Loading branches...' : 'Select a branch'}</option>
								{#each branches as branch}
									<option value={branch.id}>
										{branch.name_en} • {branch.name_ar}
									</option>
								{/each}
								</select>
								{#if error}
									<span class="field-error">{error}</span>
								{/if}
							</div>
						</div>

						<button 
							type="submit" 
							class="auth-submit-btn"
							disabled={loading || !selectedBranchId || loadingBranches}
						>
							{#if loading}
								<span class="loading-spinner"></span>
								{t('common.loading') || 'Loading...'}
							{:else}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
									<polyline points="10,17 15,12 10,7"/>
									<line x1="15" y1="12" x2="3" y2="12"/>
								</svg>
								{t('coupon.startCashier') || 'Start Cashier Session'}
							{/if}
						</button>
					</form>
				{/if}
			</div>

			<!-- Footer -->
			<div class="login-footer">
				<p>{t('app.shortName')} - {t('app.description')}</p>
			</div>
		</div>
	</div>
</div>

<style>
	/* Full-page login layout matching desktop interface */
	.cashier-login-page {
		width: 100%;
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: #F9FAFB;
		position: relative;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Background pattern */
	.cashier-login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(107, 114, 128, 0.08) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(156, 163, 175, 0.06) 0%, transparent 50%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%236B7280' fill-opacity='0.02'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.cashier-login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 900px;
		position: relative;
		z-index: 1;
	}

	/* Main card */
	.login-main-card {
		background: #FFFFFF;
		border-radius: 16px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1), 0 8px 32px rgba(107, 114, 128, 0.08);
		border: 1px solid rgba(229, 231, 235, 0.8);
		overflow: hidden;
		animation: slideInUp 0.8s ease-out;
	}

	@keyframes slideInUp {
		from {
			opacity: 0;
			transform: translateY(40px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	/* Logo section with gray gradient matching original cashier style */
	.logo-section {
		padding: 1.5rem 2rem;
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
		position: relative;
	}

	.logo-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		max-width: 600px;
		margin: 0 auto;
	}

	.logo {
		flex: 1;
		display: flex;
		justify-content: flex-start;
		background: white;
		padding: 0.75rem 1.25rem;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		max-width: fit-content;
	}

	.logo-image {
		height: 50px;
		width: auto;
		object-fit: contain;
	}

	/* Language toggle button */
	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.15);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		color: white;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		backdrop-filter: blur(10px);
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
	}

	.language-toggle-main svg {
		width: 18px;
		height: 18px;
	}

	/* Main content container */
	.login-container {
		padding: 3rem 2rem;
	}

	/* Auth form */
	.auth-form {
		max-width: 500px;
		margin: 0 auto;
	}

	.form-header {
		text-align: center;
		margin-bottom: 2.5rem;
		position: relative;
	}

	.back-btn {
		position: absolute;
		left: -2rem;
		right: auto;
		top: 0;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: none;
		border: none;
		color: #6b7280;
		font-size: 0.95rem;
		cursor: pointer;
		padding: 0.5rem;
		transition: color 0.2s ease;
	}

	/* RTL support for back button */
	[dir="rtl"] .back-btn {
		left: auto;
		right: -2rem;
		flex-direction: row-reverse;
	}

	.back-btn:hover {
		color: #374151;
	}

	.form-header h2 {
		font-size: 1.75rem;
		color: #111827;
		margin: 0 0 0.5rem 0;
		font-weight: 700;
	}

	.form-header p {
		color: #6b7280;
		font-size: 0.95rem;
		margin: 0;
	}

	/* User info card */
	.user-info-card {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1.25rem;
		background: #f9fafb;
		border-radius: 12px;
		margin-bottom: 2rem;
		border: 1px solid #e5e7eb;
	}

	.user-avatar {
		width: 50px;
		height: 50px;
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
	}

	.user-details {
		flex: 1;
	}

	.user-name {
		font-weight: 600;
		color: #111827;
		margin-bottom: 0.25rem;
		font-size: 1.05rem;
	}

	.user-role {
		font-size: 0.875rem;
		color: #6b7280;
	}

	/* Form fields */
	.form-fields {
		margin-bottom: 2rem;
	}

	.field-group {
		margin-bottom: 1.5rem;
	}

	.field-group label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.75rem;
		font-size: 0.95rem;
	}

	.field-group label svg {
		color: #6b7280;
	}

	/* Quick access digits */
	.quick-access-digits {
		display: flex;
		gap: 0.625rem;
		justify-content: center;
		margin-bottom: 0.75rem;
		direction: ltr;
	}

	.digit-input {
		width: 48px;
		height: 48px;
		text-align: center;
		font-size: 1.5rem;
		font-weight: 600;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		background: white;
		color: #1f2937;
		transition: all 0.2s ease;
		outline: none;
		direction: ltr;
	}

	.digit-input:focus {
		border-color: #6b7280;
		box-shadow: 0 0 0 3px rgba(107, 114, 128, 0.1);
		background: #f9fafb;
	}

	.digit-input.error {
		border-color: #ef4444;
	}

	.digit-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
		opacity: 0.6;
	}

	/* Field input (select) */
	.field-input {
		width: 100%;
		padding: 0.875rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 1rem;
		color: #111827;
		background: white;
		transition: all 0.2s ease;
		outline: none;
	}

	.field-input option {
		color: #111827;
		background: white;
	}

	.field-input:focus {
		border-color: #6b7280;
		box-shadow: 0 0 0 3px rgba(107, 114, 128, 0.1);
	}

	.field-input:disabled {
		background: #f9fafb;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.field-error {
		display: block;
		color: #ef4444;
		font-size: 0.875rem;
		margin-top: 0.5rem;
	}

	.field-spacer {
		height: 3rem;
	}

	/* Submit button */
	.auth-submit-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1.05rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.auth-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 10px 25px rgba(75, 85, 99, 0.3);
	}

	.auth-submit-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.loading-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Footer */
	.login-footer {
		padding: 1.5rem 2rem;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
		text-align: center;
	}

	.login-footer p {
		color: #6b7280;
		font-size: 0.875rem;
		margin: 0;
	}

	/* Responsive */
	@media (max-width: 768px) {
		.cashier-login-page {
			padding: 0.5rem;
		}

		.logo-section {
			padding: 2rem 1.5rem 1.5rem;
		}

		.logo-icon {
			font-size: 3rem;
		}

		.system-title {
			font-size: 1.5rem;
		}

		.login-container {
			padding: 2rem 1.5rem;
		}

		.form-header h2 {
			font-size: 1.5rem;
		}

		.quick-access-digits {
			gap: 0.5rem;
		}

		.digit-input {
			width: 42px;
			height: 42px;
			font-size: 1.25rem;
		}

		.back-btn {
			position: static;
			margin-bottom: 1rem;
		}
	}
</style>

