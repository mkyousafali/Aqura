<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { localeData, _, switchLocale, currentLocale } from '$lib/i18n';
	import { persistentAuthService, currentUser, isAuthenticated } from '$lib/utils/persistentAuth';

	// Login form states
	let interfaceChoice: 'desktop' | 'mobile' | null = null;
	let loginMethod: 'username' | 'quickAccess' = 'username';
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Username/Password form
	let username = '';
	let password = '';
	let rememberMe = false;

	// Quick Access form
	let quickAccessCode = '';
	let quickAccessDigits = ['', '', '', '', '', ''];

	// Form validation
	let usernameValid = true;
	let passwordValid = true;
	let quickAccessValid = true;

	// Animation states
	let mounted = false;
	let showContent = false;

	onMount(async () => {
		mounted = true;
		setTimeout(() => {
			showContent = true;
		}, 300);

		// Check if user is already logged in
		checkExistingAuth();
	});

	function checkExistingAuth() {
		// Check if user is already authenticated using persistent auth
		if ($isAuthenticated && $currentUser) {
			// User is already logged in, redirect to main page
			goto('/');
		}
	}

	function switchLoginMethod() {
		loginMethod = loginMethod === 'username' ? 'quickAccess' : 'username';
		clearForm();
	}

	function clearForm() {
		loginMethod = 'username';
		username = '';
		password = '';
		quickAccessCode = '';
		quickAccessDigits = ['', '', '', '', '', ''];
		errorMessage = '';
		successMessage = '';
		usernameValid = true;
		passwordValid = true;
		quickAccessValid = true;
	}

	function chooseInterface(choice: 'desktop' | 'mobile') {
		if (choice === 'mobile') {
			// Redirect to mobile login
			goto('/mobile-login');
		} else {
			// Continue with desktop interface
			interfaceChoice = 'desktop';
			clearForm();
		}
	}

	function goBackToChoice() {
		interfaceChoice = null;
		clearForm();
	}

	function goToCustomerLogin() {
		console.log('🔄 [Main Login] Customer Login button clicked');
		goto('/customer-login');
	}

	function validateUsername() {
		usernameValid = username.length >= 3;
		return usernameValid;
	}

	function validatePassword() {
		passwordValid = password.length >= 6;
		return passwordValid;
	}

	function validateQuickAccess() {
		quickAccessCode = quickAccessDigits.join('');
		const isNumeric = /^[0-9]+$/.test(quickAccessCode);
		quickAccessValid = quickAccessCode.length === 6 && isNumeric;
		return quickAccessValid;
	}

	async function handleUsernameLogin() {
		if (!validateUsername() || !validatePassword()) {
			errorMessage = 'Please check your credentials and try again.';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const result = await persistentAuthService.login(username, password);
			
			if (result.success) {
				successMessage = 'Login successful! Redirecting...';
				
				// Redirect to main page after a short delay
				setTimeout(() => {
					goto('/');
				}, 1500);
			} else {
				errorMessage = result.error || 'Login failed. Please try again.';
			}

		} catch (error) {
			errorMessage = error.message || 'Login failed. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	async function handleQuickAccessLogin() {
		if (!validateQuickAccess()) {
			errorMessage = 'Please enter a valid 6-digit access code.';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const result = await persistentAuthService.loginWithQuickAccess(quickAccessCode, 'desktop');
			
			if (result.success) {
				successMessage = 'Quick access successful! Redirecting...';
				
				// Redirect to main page after a short delay
				setTimeout(() => {
					goto('/');
				}, 1500);
			} else {
				errorMessage = result.error || 'Quick access login failed. Please try again.';
			}

		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Login failed. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !isLoading) {
			if (loginMethod === 'username') {
				handleUsernameLogin();
			} else {
				handleQuickAccessLogin();
			}
		}
	}

	// Format quick access code with spaces
	function formatQuickAccess(event: Event) {
		const input = event.target as HTMLInputElement;
		let value = input.value.replace(/\D/g, '').substring(0, 6);
		quickAccessCode = value;
		
		// Update display value with spaces
		if (value.length > 3) {
			input.value = value.substring(0, 3) + ' ' + value.substring(3);
		}
	}

	// Handle quick access digit input
	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			// Take only the last digit entered
			quickAccessDigits[index] = value.slice(-1);
			input.value = quickAccessDigits[index];
			
			// Auto-focus next input if this one is filled and not the last
			if (index < 5 && quickAccessDigits[index] !== '') {
				setTimeout(() => {
					const nextInput = document.getElementById(`digit-${index + 1}`) as HTMLInputElement;
					if (nextInput) {
						nextInput.focus();
						nextInput.select(); // Select any existing content
					}
				}, 10);
			}
		} else {
			quickAccessDigits[index] = '';
		}
		
		validateQuickAccess();
	}

	function handleDigitKeydown(event: KeyboardEvent, index: number) {
		const input = event.target as HTMLInputElement;
		
		// Handle backspace
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (quickAccessDigits[index] !== '') {
				// Clear current digit
				quickAccessDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
				// Move to previous input and clear it
				quickAccessDigits[index - 1] = '';
				const prevInput = document.getElementById(`digit-${index - 1}`) as HTMLInputElement;
				if (prevInput) {
					prevInput.value = '';
					prevInput.focus();
				}
			}
			validateQuickAccess();
			return;
		}
		
		// Handle arrow keys
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
		
		// Allow only numeric input
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		// Fill digits from paste
		for (let i = 0; i < 6; i++) {
			quickAccessDigits[i] = digits[i] || '';
			const input = document.getElementById(`digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = quickAccessDigits[i];
			}
		}
		
		// Focus the last filled input or first empty one
		const lastFilledIndex = digits.length - 1;
		const targetIndex = Math.min(Math.max(lastFilledIndex + 1, 0), 5);
		const targetInput = document.getElementById(`digit-${targetIndex}`) as HTMLInputElement;
		if (targetInput) {
			targetInput.focus();
		}
		
		validateQuickAccess();
	}
</script>

<svelte:head>
	<title>Login - Aqura Management System</title>
	<meta name="description" content="Access your Aqura Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

<!-- Full-page login experience matching main page structure -->
<div class="login-page" class:mounted>
	{#if showContent}
		<div class="login-content">
			<!-- Main Login Card matching main page welcome card -->
			<div class="login-main-card">
				<!-- Logo Section matching main page -->
				<div class="logo-section">
					<div class="logo-header">
						<div class="logo">
							<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
						</div>
						<button 
							class="language-toggle-main" 
							on:click={() => switchLocale($currentLocale === 'ar' ? 'en' : 'ar')}
							title={$_('nav.languageToggle')}
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

				<!-- Authentication Methods Section -->
				<div class="auth-section">
					{#if interfaceChoice === null}
						<!-- Interface Choice -->
						<div class="interface-choice">
							<div class="interface-options">
								<button 
									class="interface-btn desktop-btn"
									on:click={() => chooseInterface('desktop')}
									disabled={isLoading}
									title={$_('customer.login.interface.desktop')}
								>
									<div class="interface-icon">
										<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="2" y="4" width="20" height="12" rx="2"/>
											<path d="M2 16h20"/>
											<path d="M8 20h8"/>
										</svg>
									</div>
									<span class="interface-label">{$_('common.users')}</span>
								</button>

								<button 
									class="interface-btn mobile-btn"
									on:click={() => chooseInterface('mobile')}
									disabled={isLoading}
									title={$_('customer.login.interface.mobile')}
								>
									<div class="interface-icon">
										<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="5" y="2" width="14" height="20" rx="2"/>
											<path d="M12 18h.01"/>
										</svg>
									</div>
									<span class="interface-label">{$_('common.users')}</span>
								</button>

								<!-- Customer Login Button -->
								<button 
									class="interface-btn customer-btn"
									on:click={goToCustomerLogin}
									disabled={isLoading}
									type="button"
									title="Customer Login"
								>
									<div class="interface-icon">
										<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
											<circle cx="12" cy="7" r="4"/>
										</svg>
									</div>
									<span class="interface-label">{$_('common.customer')}</span>
								</button>

								<!-- Cashier Login Button -->
								<button 
									class="interface-btn cashier-btn"
									on:click={() => goto('/cashier')}
									disabled={isLoading}
									type="button"
									title={$_('coupon.cashier') || 'Cashier'}
								>
									<div class="interface-icon">
										<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
											<circle cx="8.5" cy="8.5" r="1.5"/>
											<polyline points="21 15 16 10 5 21"/>
											<line x1="10" y1="18" x2="18" y2="10"/>
										</svg>
									</div>
									<span class="interface-label">{$_('coupon.cashier') || 'Cashier'}</span>
								</button>
							</div>
						</div>
					{:else}
						<!-- Desktop Authentication Interface -->
					<!-- Method Toggle -->
					<div class="desktop-login-header">
						<button 
							class="back-btn"
							on:click={goBackToChoice}
							disabled={isLoading}
						>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M19 12H5M12 19l-7-7 7-7"/>
							</svg>
							Back to Interface Choice
						</button>
					</div>

					<div class="method-selector">
						<button 
							class="method-btn" 
							class:active={loginMethod === 'username'}
							on:click={() => loginMethod = 'username'}
							disabled={isLoading}
						>
							<div class="method-icon">
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
									<circle cx="12" cy="7" r="4"/>
								</svg>
							</div>
							<div class="method-info">
								<h3>Username & Password</h3>
								<p>Traditional login method</p>
							</div>
						</button>

						<button 
							class="method-btn" 
							class:active={loginMethod === 'quickAccess'}
							on:click={() => loginMethod = 'quickAccess'}
							disabled={isLoading}
						>
							<div class="method-icon">
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
									<circle cx="12" cy="16" r="1"/>
									<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
								</svg>
							</div>
							<div class="method-info">
								<h3>Quick Access Code</h3>
								<p>6-digit secure access</p>
							</div>
						</button>
					</div>

					<!-- Authentication Forms -->
					<div class="auth-forms">
						{#if loginMethod === 'username'}
							<!-- Username/Password Form -->
							<form class="auth-form" on:submit|preventDefault={handleUsernameLogin}>
								<div class="form-header">
									<h2>Welcome Back</h2>
									<p>Enter your credentials to access the system</p>
								</div>

								<div class="form-fields">
									<div class="field-group">
										<label for="username">Username</label>
										<input 
											id="username"
											type="text" 
											class="field-input"
											class:error={!usernameValid}
											bind:value={username}
											on:input={validateUsername}
											placeholder="Enter your username"
											disabled={isLoading}
											autocomplete="username"
										/>
										{#if !usernameValid}
											<span class="field-error">Username must be at least 3 characters</span>
										{/if}
									</div>

									<div class="field-group">
										<label for="password">Password</label>
										<input 
											id="password"
											type="password" 
											class="field-input"
											class:error={!passwordValid}
											bind:value={password}
											on:input={validatePassword}
											placeholder="Enter your password"
											disabled={isLoading}
											autocomplete="current-password"
										/>
										{#if !passwordValid}
											<span class="field-error">Password must be at least 6 characters</span>
										{/if}
									</div>

									<div class="form-options">
										<label class="checkbox-option">
											<input 
												type="checkbox" 
												bind:checked={rememberMe}
												disabled={isLoading}
											/>
											<span class="checkbox-mark"></span>
											Remember me for 30 days
										</label>
									</div>
								</div>

								<button 
									type="submit" 
									class="auth-submit-btn"
									disabled={isLoading || !username || !password}
								>
									{#if isLoading}
										<span class="loading-spinner"></span>
										Signing In...
									{:else}
										<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
											<polyline points="10,17 15,12 10,7"/>
											<line x1="15" y1="12" x2="3" y2="12"/>
										</svg>
										Sign In to System
									{/if}
								</button>
							</form>

						{:else}
							<!-- Quick Access Form -->
							<form class="auth-form" on:submit|preventDefault={handleQuickAccessLogin}>
								<div class="form-header">
									<h2>Quick Access</h2>
									<p>Enter your 6-digit security code</p>
								</div>

								<div class="form-fields">
									<div class="field-group">
										<label for="quickAccess">Security Code</label>
										<div class="quick-access-digits">
											{#each quickAccessDigits as digit, index}
												<input 
													id="digit-{index}"
													type="text" 
													class="digit-input"
													class:error={!quickAccessValid && quickAccessDigits.some(d => d !== '')}
													bind:value={quickAccessDigits[index]}
													on:input={(e) => handleDigitInput(e, index)}
													on:keydown={(e) => handleDigitKeydown(e, index)}
													on:paste={handleDigitPaste}
													placeholder=""
													disabled={isLoading}
													maxlength="1"
													autocomplete="off"
													inputmode="numeric"
													pattern="[0-9]*"
												/>
											{/each}
										</div>
										{#if !quickAccessValid && quickAccessDigits.some(d => d !== '')}
											<span class="field-error">Enter a valid 6-digit security code</span>
										{/if}
									</div>

									<!-- Spacer to match username form height -->
									<div class="field-spacer"></div>

									<div class="form-options">
										<label class="checkbox-option">
											<input 
												type="checkbox" 
												bind:checked={rememberMe}
												disabled={isLoading}
											/>
											<span class="checkbox-mark"></span>
											Remember this device
										</label>
									</div>
								</div>

								<button 
									type="submit" 
									class="auth-submit-btn"
									disabled={isLoading || quickAccessDigits.some(d => d === '')}
								>
									{#if isLoading}
										<span class="loading-spinner"></span>
										Accessing...
									{:else}
										<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M9 12l2 2 4-4"/>
											<path d="M21 12c-1 0-3-1-3-3s2-3 3-3 3 1 3 3-2 3-3 3"/>
											<path d="M3 12c1 0 3-1 3-3s-2-3-3-3-3 1-3 3 2 3 3 3"/>
											<path d="M12 3c0 1-1 3-3 3s-3-2-3-3 1-3 3-3 3 2 3 3"/>
											<path d="M12 21c0-1 1-3 3-3s3 2 3 3-1 3-3 3-3-2-3-3"/>
										</svg>
										Access System
									{/if}
								</button>
							</form>
						{/if}
					</div>
					{/if}
				</div>

				<!-- Status Messages -->
				{#if errorMessage}
					<div class="status-message error-status" role="alert">
						<div class="status-icon">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<circle cx="12" cy="12" r="10"/>
								<line x1="15" y1="9" x2="9" y2="15"/>
								<line x1="9" y1="9" x2="15" y2="15"/>
							</svg>
						</div>
						<div class="status-content">
							<h4>Authentication Failed</h4>
							<p>{errorMessage}</p>
						</div>
					</div>
				{/if}

				{#if successMessage}
					<div class="status-message success-status" role="status">
						<div class="status-icon">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M9 12l2 2 4-4"/>
								<circle cx="12" cy="12" r="10"/>
							</svg>
						</div>
						<div class="status-content">
							<h4>Access Granted</h4>
							<p>{successMessage}</p>
						</div>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	/* Global mobile fixes */
	:global(html) {
		touch-action: manipulation;
		-webkit-text-size-adjust: 100%;
		overflow-x: hidden;
		height: 100%;
	}

	:global(body) {
		margin: 0;
		padding: 0;
		overflow-x: hidden;
		min-height: 100vh;
		min-height: 100dvh;
		height: 100%;
		-webkit-overflow-scrolling: touch; /* Enable smooth scrolling on iOS */
		position: relative;
	}

	/* Prevent iOS zoom on input focus */
	:global(input, select, textarea) {
		font-size: 16px !important;
	}

	/* Full-page login layout matching main page structure */
	.login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh; /* Use dynamic viewport height for mobile */
		display: flex;
		align-items: flex-start; /* Change from center to flex-start for better mobile scrolling */
		justify-content: center;
		padding: 1rem;
		padding-top: 2rem; /* Add top padding to center content visually */
		background: #F9FAFB;
		position: relative;
		overflow-x: hidden;
		overflow-y: auto; /* Allow vertical scrolling */
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	/* Background pattern matching main page */
	.login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(107, 114, 128, 0.08) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(156, 163, 175, 0.06) 0%, transparent 50%),
			radial-gradient(circle at 50% 50%, rgba(209, 213, 219, 0.04) 0%, transparent 60%),
			radial-gradient(circle at 80% 20%, rgba(229, 231, 235, 0.08) 0%, transparent 40%),
			radial-gradient(circle at 20% 80%, rgba(243, 244, 246, 0.1) 0%, transparent 45%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%236B7280' fill-opacity='0.02'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 900px;
		position: relative;
		z-index: 1;
		margin: 1rem 0; /* Add vertical margin for mobile */
		min-height: 0; /* Allow content to shrink */
	}

	/* Main login card matching main page welcome card */
	.login-main-card {
		background: #FFFFFF;
		backdrop-filter: blur(10px);
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

	/* Logo section matching main page exactly */
	.logo-section {
		text-align: center;
		padding: 3rem 2rem 2rem;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		position: relative;
	}

	.logo-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 1rem;
	}

	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		color: white;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.3s ease;
		backdrop-filter: blur(10px);
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
	}

	.logo-section::after {
		content: '';
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, #F59E0B 0%, #FBBF24 100%);
	}

	.logo {
		width: 200px;
		height: 120px;
		margin: 0 auto 1.5rem;
		background: #FFFFFF;
		border: 6px solid #F59E0B;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 25px rgba(245, 158, 11, 0.5),
			0 0 50px rgba(245, 158, 11, 0.3),
			inset 0 0 15px rgba(245, 158, 11, 0.15);
		animation: ledGlow 2s ease-in-out infinite alternate;
	}

	@keyframes ledGlow {
		from {
			box-shadow: 
				0 0 25px rgba(245, 158, 11, 0.5),
				0 0 50px rgba(245, 158, 11, 0.3),
				inset 0 0 15px rgba(245, 158, 11, 0.15);
		}
		to {
			box-shadow: 
				0 0 40px rgba(245, 158, 11, 0.7),
				0 0 80px rgba(245, 158, 11, 0.4),
				inset 0 0 25px rgba(245, 158, 11, 0.25);
		}
	}

	.logo-image {
		width: 140px;
		height: 80px;
		border-radius: 12px;
		object-fit: contain;
	}

	.app-title {
		font-size: 2.5rem;
		font-weight: 700;
		margin-bottom: 0.5rem;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.app-subtitle {
		font-size: 1.1rem;
		opacity: 0.9;
		font-weight: 300;
	}

	/* Authentication section */
	.auth-section {
		padding: 2.5rem;
	}

	/* Interface choice styles */
	.interface-choice {
		animation: formSlideIn 0.5s ease-out;
	}

	.interface-options {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 1.5rem;
		margin-top: 2rem;
		justify-items: center;
	}

	.interface-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 1.5rem 1rem;
		background: #F8FAFC;
		border: 2px solid #E2E8F0;
		border-radius: 20px;
		cursor: pointer;
		transition: all 0.3s ease;
		text-align: center;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		width: 120px;
		height: 140px;
		position: relative;
	}

	.interface-btn:hover:not(:disabled) {
		background: #F1F5F9;
		border-color: #CBD5E1;
		transform: translateY(-4px);
		box-shadow: 0 12px 30px rgba(71, 85, 105, 0.2);
	}

	.interface-btn:active:not(:disabled) {
		transform: translateY(-2px);
	}

	.interface-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.desktop-btn:hover:not(:disabled) {
		border-color: #15A34A;
		box-shadow: 0 12px 30px rgba(21, 163, 74, 0.25);
	}

	.mobile-btn:hover:not(:disabled) {
		border-color: #3B82F6;
		box-shadow: 0 12px 30px rgba(59, 130, 246, 0.25);
	}

	.customer-btn:hover:not(:disabled) {
		border-color: #F59E0B;
		box-shadow: 0 12px 30px rgba(245, 158, 11, 0.25);
	}

	.customer-btn .interface-icon {
		background: linear-gradient(135deg, #F59E0B 0%, #FCD34D 100%);
	}

	.cashier-btn:hover:not(:disabled) {
		border-color: #6b7280;
		box-shadow: 0 12px 30px rgba(107, 114, 128, 0.25);
	}

	.cashier-btn .interface-icon {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
	}

	.interface-icon {
		width: 60px;
		height: 60px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		flex-shrink: 0;
	}

	.mobile-btn .interface-icon {
		background: linear-gradient(135deg, #3B82F6 0%, #60A5FA 100%);
	}

	.interface-label {
		font-size: 0.75rem;
		font-weight: 500;
		color: #64748B;
		margin-top: 0.25rem;
	}

	/* Desktop login header */
	.desktop-login-header {
		margin-bottom: 1.5rem;
		padding-bottom: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.back-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: transparent;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		color: #64748B;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.back-btn:hover:not(:disabled) {
		background: #F8FAFC;
		border-color: #CBD5E1;
		color: #475569;
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Method selector */
	.method-selector {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-bottom: 2.5rem;
	}

	.method-btn {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		background: #F8FAFC;
		border: 2px solid #E2E8F0;
		border-radius: 12px;
		cursor: pointer;
		transition: all 0.3s ease;
		text-align: left;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
	}

	.method-btn:hover {
		background: #F1F5F9;
		border-color: #CBD5E1;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(71, 85, 105, 0.1);
	}

	.method-btn:active {
		transform: translateY(0);
	}

	.method-btn.active {
		background: #FFFFFF;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1), 0 4px 12px rgba(21, 163, 74, 0.15);
	}

	.method-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.method-icon {
		width: 48px;
		height: 48px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		flex-shrink: 0;
	}

	.method-btn.active .method-icon {
		box-shadow: 0 0 15px rgba(21, 163, 74, 0.4);
	}

	.method-info h3 {
		font-size: 1.1rem;
		font-weight: 600;
		color: #1E293B;
		margin-bottom: 0.25rem;
	}

	.method-info p {
		font-size: 0.875rem;
		color: #64748B;
		margin: 0;
	}

	/* Authentication forms */
	.auth-forms {
		animation: formSlideIn 0.5s ease-out;
	}

	@keyframes formSlideIn {
		from {
			opacity: 0;
			transform: translateX(20px);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	.auth-form {
		width: 100%;
	}

	.form-header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.form-header h2 {
		font-size: 1.75rem;
		font-weight: 600;
		color: #1E293B;
		margin-bottom: 0.5rem;
	}

	.form-header p {
		color: #64748B;
		font-size: 1rem;
		margin: 0;
	}

	/* Form fields */
	.form-fields {
		margin-bottom: 2rem;
	}

	.field-group {
		margin-bottom: 1.5rem;
	}

	.field-spacer {
		height: 4rem;
		margin-bottom: 1.5rem;
	}

	.field-group label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.field-input {
		width: 100%;
		padding: 0.875rem 1rem;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		font-size: 1rem;
		background: #FFFFFF;
		color: #1E293B;
		transition: all 0.3s ease;
		box-sizing: border-box;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
	}

	.field-input:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.field-input.error {
		border-color: #EF4444;
		background: #FEF2F2;
	}

	.field-input:disabled {
		background: #F9FAFB;
		color: #9CA3AF;
		cursor: not-allowed;
	}

	/* Quick Access Digit Boxes */
	.quick-access-digits {
		display: flex;
		gap: 0.75rem;
		justify-content: center;
		align-items: center;
		margin: 0.5rem 0;
	}

	.digit-input {
		width: 48px;
		height: 48px;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		text-align: center;
		font-size: 1.25rem;
		font-weight: 600;
		font-family: 'JetBrains Mono', 'Courier New', monospace;
		background: #FFFFFF;
		color: #1E293B;
		transition: all 0.3s ease;
		box-sizing: border-box;
		padding: 0;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		touch-action: manipulation;
	}

	.digit-input:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
		background: #F8FAFC;
	}

	.digit-input.error {
		border-color: #EF4444;
		background: #FEF2F2;
	}

	.digit-input:disabled {
		background: #F9FAFB;
		color: #9CA3AF;
		cursor: not-allowed;
	}

	.digit-input::placeholder {
		color: #9CA3AF;
		font-weight: 400;
	}

	.field-error {
		color: #EF4444;
		font-size: 0.75rem;
		margin-top: 0.5rem;
		display: block;
	}

	/* Form options */
	.form-options {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 1.5rem;
	}

	.checkbox-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #64748B;
		cursor: pointer;
	}

	.checkbox-option input[type="checkbox"] {
		width: 18px;
		height: 18px;
		accent-color: #15A34A;
		margin: 0;
	}

	/* Submit button */
	.auth-submit-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		box-shadow: 0 4px 14px rgba(21, 163, 74, 0.3);
		text-transform: none;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 48px; /* Minimum touch target size */
	}

	.auth-submit-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #166534 0%, #15A34A 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 20px rgba(21, 163, 74, 0.4);
	}

	.auth-submit-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.auth-submit-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Status messages */
	.status-message {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		padding: 1rem 1.25rem;
		margin: 1.5rem 2.5rem;
		border-radius: 12px;
		animation: messageSlideIn 0.4s ease-out;
	}

	@keyframes messageSlideIn {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.error-status {
		background: #FEF2F2;
		border: 1px solid #FECACA;
		color: #DC2626;
	}

	.success-status {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		color: #16A34A;
	}

	.status-icon {
		flex-shrink: 0;
		margin-top: 0.125rem;
	}

	.status-content h4 {
		font-size: 0.875rem;
		font-weight: 600;
		margin: 0 0 0.25rem 0;
	}

	.status-content p {
		font-size: 0.875rem;
		margin: 0;
		opacity: 0.9;
	}

		/* Enhanced responsive design */
		@media (max-width: 1024px) {
			.login-page {
				padding: 1rem;
				align-items: flex-start;
				padding-top: 2rem;
				padding-bottom: 2rem;
			}

			.login-content {
				max-width: 600px;
				margin: 0;
			}
		}

		@media (max-width: 768px) {
			.login-page {
				padding: 0.75rem;
				min-height: 100vh;
				min-height: 100dvh; /* Dynamic viewport height */
				height: auto; /* Allow height to expand */
				align-items: flex-start;
				padding-top: 1rem;
				padding-bottom: 4rem; /* Extra bottom padding for mobile */
				overflow-y: auto; /* Ensure scrolling works */
				-webkit-overflow-scrolling: touch; /* Smooth scrolling on iOS */
			}

			.login-content {
				width: 100%;
				max-width: 500px;
				margin: 0;
				flex-shrink: 0; /* Prevent shrinking */
			}

		.logo-section {
			padding: 2rem 1rem 1.5rem;
		}

		.logo {
			width: 160px;
			height: 100px;
			margin-bottom: 1rem;
		}

		.logo-image {
			width: 110px;
			height: 65px;
		}

		.app-title {
			font-size: 2rem;
			margin-bottom: 0.25rem;
		}

		.app-subtitle {
			font-size: 1rem;
		}

		.auth-section {
			padding: 2rem 1.5rem;
		}

		.interface-options {
			grid-template-columns: repeat(2, 1fr);
			gap: 1rem;
			margin-top: 1.5rem;
		}

		.interface-btn {
			width: 100px;
			height: 120px;
			padding: 1.25rem 0.75rem;
		}

		.interface-icon {
			width: 48px;
			height: 48px;
		}

		.interface-label {
			font-size: 0.7rem;
		}

		.method-selector {
			grid-template-columns: 1fr;
			gap: 0.75rem;
			margin-bottom: 2rem;
		}

		.method-btn {
			padding: 1.25rem;
			gap: 0.75rem;
		}

		.method-icon {
			width: 40px;
			height: 40px;
		}

		.form-header {
			margin-bottom: 1.5rem;
		}

		.form-header h2 {
			font-size: 1.5rem;
		}

		.form-header p {
			font-size: 0.9rem;
		}

		.field-input {
			padding: 0.75rem;
			font-size: 16px; /* Prevents zoom on iOS */
		}

		.digit-input {
			width: 44px;
			height: 44px;
			font-size: 1.2rem;
		}

		.quick-access-digits {
			gap: 0.5rem;
		}

		.form-options {
			flex-direction: column;
			align-items: flex-start;
			gap: 1rem;
		}

		.status-message {
			margin: 1.5rem 1.5rem;
			padding: 0.875rem 1rem;
		}
	}

		@media (max-width: 480px) {
			.login-page {
				padding: 0.5rem;
				padding-top: 0.75rem;
				padding-bottom: 3rem; /* Extra bottom padding for safe area */
				overflow-y: auto;
			}		.login-main-card {
			border-radius: 12px;
		}

		.logo-section {
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 140px;
			height: 85px;
			margin-bottom: 0.75rem;
		}

		.logo-image {
			width: 95px;
			height: 55px;
		}

		.app-title {
			font-size: 1.75rem;
			margin-bottom: 0.25rem;
		}

		.app-subtitle {
			font-size: 0.9rem;
		}

		.auth-section {
			padding: 1.5rem 1rem;
		}

		.method-selector {
			gap: 0.5rem;
			margin-bottom: 1.5rem;
		}

		.method-btn {
			flex-direction: column;
			text-align: center;
			gap: 0.75rem;
			padding: 1rem;
		}

		.method-icon {
			width: 36px;
			height: 36px;
			align-self: center;
		}

		.method-info h3 {
			font-size: 1rem;
			margin-bottom: 0.125rem;
		}

		.method-info p {
			font-size: 0.8rem;
		}

		.form-header {
			margin-bottom: 1.25rem;
		}

		.form-header h2 {
			font-size: 1.375rem;
		}

		.form-header p {
			font-size: 0.875rem;
		}

		.field-group {
			margin-bottom: 1.25rem;
		}

		.field-input {
			padding: 0.75rem;
			font-size: 16px;
		}

		.digit-input {
			width: 38px;
			height: 38px;
			font-size: 1.1rem;
		}

		.quick-access-digits {
			gap: 0.375rem;
			flex-wrap: wrap;
			justify-content: center;
		}

			.auth-submit-btn {
				padding: 1rem 1.5rem;
				font-size: 1rem;
				min-height: 52px; /* Larger touch target for mobile */
				border-radius: 12px;
				margin-top: 0.5rem;
			}

			.status-message {
			margin: 1rem;
			padding: 0.75rem 0.875rem;
		}

		.status-content h4 {
			font-size: 0.8rem;
		}

		.status-content p {
			font-size: 0.8rem;
		}
	}

		@media (max-width: 375px) {
			.login-page {
				padding: 0.5rem;
				padding-top: 0.75rem;
				padding-bottom: 4rem; /* More bottom space for safe area */
				overflow-y: auto;
			}		.logo-section {
			padding: 1.25rem 0.75rem;
		}

		.logo {
			width: 120px;
			height: 75px;
		}

		.logo-image {
			width: 85px;
			height: 50px;
		}

		.app-title {
			font-size: 1.5rem;
		}

		.app-subtitle {
			font-size: 0.85rem;
		}

		.auth-section {
			padding: 1.25rem 0.75rem;
		}

		.interface-options {
			grid-template-columns: repeat(2, 1fr);
			gap: 0.75rem;
			margin-top: 1rem;
		}

		.interface-btn {
			width: 80px;
			height: 100px;
			padding: 1rem 0.5rem;
		}

		.interface-icon {
			width: 36px;
			height: 36px;
		}

		.interface-label {
			font-size: 0.65rem;
		}

		.method-btn {
			padding: 0.875rem;
		}

		.method-icon {
			width: 32px;
			height: 32px;
		}

		.method-info h3 {
			font-size: 0.9rem;
		}

		.method-info p {
			font-size: 0.75rem;
		}

		.form-header h2 {
			font-size: 1.25rem;
		}

		.digit-input {
			width: 34px;
			height: 34px;
			font-size: 1rem;
		}

		.quick-access-digits {
			gap: 0.25rem;
		}

		.checkbox-option {
			font-size: 0.8rem;
		}
	}

	@media (max-height: 700px) and (max-width: 768px) {
		.login-page {
			align-items: flex-start;
			padding-top: 0.5rem;
			padding-bottom: 3rem;
			height: auto; /* Allow content to expand beyond viewport */
		}

		.logo-section {
			padding: 1.5rem 1rem 1rem;
		}

		.logo {
			width: 120px;
			height: 75px;
			margin-bottom: 0.75rem;
		}

		.logo-image {
			width: 85px;
			height: 50px;
		}

		.app-title {
			font-size: 1.75rem;
		}

		.auth-section {
			padding: 1.5rem;
		}

		.method-selector {
			margin-bottom: 1.5rem;
		}

		.form-header {
			margin-bottom: 1rem;
		}
	}

	/* Landscape orientation fixes */
	@media (orientation: landscape) and (max-height: 500px) {
		.login-page {
			padding: 0.75rem;
			align-items: flex-start;
		}

		.login-main-card {
			display: flex;
		}

		.logo-section {
			flex: 0 0 280px;
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 100px;
			height: 60px;
			margin-bottom: 0.5rem;
		}

		.logo-image {
			width: 70px;
			height: 40px;
		}

		.app-title {
			font-size: 1.5rem;
		}

		.app-subtitle {
			font-size: 0.875rem;
		}

		.auth-section {
			flex: 1;
			padding: 1.5rem;
		}

		.method-selector {
			grid-template-columns: 1fr 1fr;
			gap: 0.5rem;
			margin-bottom: 1.5rem;
		}

		.method-btn {
			flex-direction: column;
			padding: 0.75rem 0.5rem;
			gap: 0.5rem;
		}

		.method-icon {
			width: 28px;
			height: 28px;
		}

		.method-info h3 {
			font-size: 0.85rem;
		}

		.method-info p {
			font-size: 0.7rem;
		}

		.form-header {
			margin-bottom: 1rem;
		}

		.form-header h2 {
			font-size: 1.25rem;
		}

		.field-group {
			margin-bottom: 1rem;
		}
	}

	/* Critical mobile fixes for very small screens */
		@media (max-width: 320px) {
			.login-page {
				padding: 0.25rem;
				padding-bottom: 5rem;
			}

			.interface-options {
				grid-template-columns: repeat(2, 1fr);
				gap: 0.5rem;
				margin-top: 0.75rem;
			}

			.interface-btn {
				width: 70px;
				height: 90px;
				padding: 0.75rem 0.5rem;
			}

			.interface-icon {
				width: 32px;
				height: 32px;
			}

			.interface-label {
				font-size: 0.6rem;
			}

			.auth-submit-btn {
				font-size: 0.9rem;
				padding: 1rem;
				min-height: 48px;
				margin-top: 1rem;
				margin-bottom: 1rem;
			}

			.login-main-card {
				border-radius: 8px;
			}

			.digit-input {
				width: 30px;
				height: 30px;
				font-size: 0.9rem;
			}

			.quick-access-digits {
				gap: 0.2rem;
			}
		}

		/* Ensure content is always accessible */
		@media (max-height: 600px) {
			.login-page {
				align-items: flex-start;
				padding-top: 0.5rem;
				padding-bottom: 3rem;
			}

			.auth-submit-btn {
				position: sticky;
				bottom: 1rem;
				z-index: 100;
				box-shadow: 0 8px 25px rgba(21, 163, 74, 0.4);
			}
		}

		/* Force scrollable on mobile Safari */
		@supports (-webkit-touch-callout: none) {
			.login-page {
				-webkit-overflow-scrolling: touch;
				overflow-y: scroll;
			}
		}

		/* Customer Login Integration */
		.auth-section :global(.customer-login-container) {
			padding: 0;
			margin: 0;
			background: transparent;
			border: none;
			box-shadow: none;
		}

		.auth-section :global(.customer-header) {
			margin-top: 0;
		}

		/* Ensure proper spacing on mobile for customer login */
		@media (max-width: 768px) {
			.auth-section :global(.customer-login-container) {
				padding: 0;
			}
			
			.auth-section :global(.form-header) {
				margin-bottom: 1rem;
			}
		}
	</style>
