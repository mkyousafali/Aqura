<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { persistentAuthService, currentUser, isAuthenticated } from '$lib/utils/persistentAuth';

	// Quick Access form
	let quickAccessCode = '';
	let quickAccessDigits = ['', '', '', '', '', ''];
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';
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
		if ($isAuthenticated && $currentUser) {
			// User is already logged in, redirect to mobile dashboard
			goto('/mobile');
		}
	}

	function validateQuickAccess() {
		quickAccessCode = quickAccessDigits.join('');
		const isNumeric = /^[0-9]+$/.test(quickAccessCode);
		quickAccessValid = quickAccessCode.length === 6 && isNumeric;
		return quickAccessValid;
	}

	async function handleQuickAccessLogin() {
		if (!validateQuickAccess()) {
			errorMessage = 'Please enter a valid 6-digit access code.';
			return;
		}

		isLoading = true;
		errorMessage = '';
		successMessage = '';

		// Add timeout to prevent hanging
		const timeoutMs = 15000; // Reduced to 15 seconds since auth completes quickly
		let timeoutId: NodeJS.Timeout;

		try {
			console.log('🔍 [Mobile Login] Starting quick access login with code:', quickAccessCode);
			
			const loginPromise = persistentAuthService.loginWithQuickAccess(quickAccessCode);
			const timeoutPromise = new Promise((_, reject) => {
				timeoutId = setTimeout(() => {
					reject(new Error('Login request timed out. Please check your connection and try again.'));
				}, timeoutMs);
			});

			const result = await Promise.race([loginPromise, timeoutPromise]) as Awaited<ReturnType<typeof persistentAuthService.loginWithQuickAccess>>;
			
			// Clear timeout if login completed
			if (timeoutId) clearTimeout(timeoutId);
			
			console.log('🔍 [Mobile Login] Login result:', result);
			
			if (result.success) {
				successMessage = 'Access granted! Redirecting...';
				console.log('✅ [Mobile Login] Login successful, redirecting to mobile dashboard');
				
				// Store mobile interface preference
				localStorage.setItem('aqura-interface-preference', 'mobile');
				
				// Force immediate redirect with multiple fallback methods
				console.log('🔄 [Mobile Login] Attempting navigation to /mobile...');
				
				try {
					// Primary method: SvelteKit goto
					await goto('/mobile');
					console.log('✅ [Mobile Login] SvelteKit navigation successful');
				} catch (gotoError) {
					console.warn('⚠️ [Mobile Login] SvelteKit navigation failed, using window.location:', gotoError);
					
					// Fallback method: Direct window navigation
					window.location.href = '/mobile';
				}
			} else {
				console.error('❌ [Mobile Login] Login failed:', result.error);
				errorMessage = result.error || 'Access code invalid. Please try again.';
			}

		} catch (error) {
			// Clear timeout on error
			if (timeoutId) clearTimeout(timeoutId);
			
			console.error('❌ [Mobile Login] Login error:', error);
			
			// Handle different types of errors
			if (error instanceof Error) {
				if (error.message.includes('timed out')) {
					errorMessage = 'Request timed out. Please check your connection and try again.';
				} else if (error.message.includes('fetch')) {
					errorMessage = 'Network error. Please check your connection and try again.';
				} else {
					errorMessage = error.message;
				}
			} else {
				errorMessage = 'Login failed. Please try again.';
			}
		} finally {
			// Ensure loading state is always reset
			console.log('🔍 [Mobile Login] Resetting loading state');
			isLoading = false;
			
			// Clear timeout just in case
			if (timeoutId) clearTimeout(timeoutId);
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !isLoading && quickAccessDigits.every(d => d !== '')) {
			event.preventDefault();
			handleQuickAccessLogin();
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
						nextInput.select();
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

	function goBackToMainLogin() {
		goto('/login');
	}
</script>

<svelte:head>
	<title>Mobile Access - Aqura Management System</title>
	<meta name="description" content="Mobile access to your Aqura Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#3B82F6" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

<div class="mobile-login-page" class:mounted>
	{#if showContent}
		<div class="mobile-login-content">
			<!-- Header Section -->
			<div class="mobile-header">
				<button class="back-btn" on:click={goBackToMainLogin} disabled={isLoading}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M19 12H5M12 19l-7-7 7-7"/>
					</svg>
				</button>
				
				<div class="mobile-logo">
					<div class="logo-icon">
						<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
					</div>
					<h1 class="app-title">Aqura Mobile</h1>
					<p class="app-subtitle">Quick Access Portal</p>
				</div>
			</div>

			<!-- Quick Access Form -->
			<div class="mobile-auth-section">
				<form class="mobile-auth-form" on:submit|preventDefault={handleQuickAccessLogin}>
					<div class="form-header">
						<h2>Enter Access Code</h2>
						<p>Use your 6-digit security code to access the mobile interface</p>
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
					</div>

					<button 
						type="submit" 
						class="mobile-submit-btn"
						disabled={isLoading || quickAccessDigits.some(d => d === '')}
					>
						{#if isLoading}
							<span class="loading-spinner"></span>
							Accessing...
						{:else}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M9 12l2 2 4-4"/>
								<circle cx="12" cy="12" r="10"/>
							</svg>
							Access Mobile Interface
						{/if}
					</button>
				</form>

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
							<h4>Access Denied</h4>
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

			<!-- Mobile Features Info -->
			<div class="mobile-features">
				<h3>Mobile Interface Features</h3>
				<div class="feature-list">
					<div class="feature-item">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 12l2 2 4-4"/>
							<path d="M21 12c-1 0-3-1-3-3s2-3 3-3 3 1 3 3-2 3-3 3"/>
							<path d="M3 12c1 0 3-1 3-3s-2-3-3-3-3 1-3 3 2 3 3 3"/>
							<path d="M12 3c0 1-1 3-3 3s-3-2-3-3 1-3 3-3 3 2 3 3"/>
							<path d="M12 21c0-1 1-3 3-3s3 2 3 3-1 3-3 3-3-2-3-3"/>
						</svg>
						<span>View and manage your tasks</span>
					</div>
					<div class="feature-item">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M14 9V5a3 3 0 0 0-6 0v4"/>
							<rect x="2" y="9" width="20" height="12" rx="2" ry="2"/>
							<circle cx="12" cy="15" r="1"/>
						</svg>
						<span>Create and assign new tasks</span>
					</div>
					<div class="feature-item">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
							<path d="M13.73 21a2 2 0 0 1-3.46 0"/>
						</svg>
						<span>Send and receive notifications</span>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	/* Mobile-first login page */
	.mobile-login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
		color: white;
		-webkit-overflow-scrolling: touch;
	}

	.mobile-login-page.mounted {
		opacity: 1;
	}

	.mobile-login-content {
		width: 100%;
		max-width: 480px;
		margin: 0 auto;
		padding: 2rem 1.5rem;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
	}

	/* Header Section */
	.mobile-header {
		text-align: center;
		margin-bottom: 3rem;
		position: relative;
	}

	.back-btn {
		position: absolute;
		top: 0;
		left: 0;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 12px;
		color: white;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		backdrop-filter: blur(10px);
	}

	.back-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateX(-2px);
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.mobile-logo {
		margin-top: 2rem;
	}

	.logo-icon {
		width: 120px;
		height: 120px;
		margin: 0 auto 1.5rem;
		background: white;
		border: 4px solid rgba(255, 255, 255, 0.3);
		border-radius: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 30px rgba(255, 255, 255, 0.3),
			0 10px 30px rgba(0, 0, 0, 0.2);
		animation: logoGlow 3s ease-in-out infinite alternate;
	}

	@keyframes logoGlow {
		from {
			box-shadow: 
				0 0 30px rgba(255, 255, 255, 0.3),
				0 10px 30px rgba(0, 0, 0, 0.2);
		}
		to {
			box-shadow: 
				0 0 40px rgba(255, 255, 255, 0.5),
				0 15px 40px rgba(0, 0, 0, 0.3);
		}
	}

	.logo-image {
		width: 80px;
		height: 80px;
		border-radius: 16px;
		object-fit: contain;
	}

	.app-title {
		font-size: 2.5rem;
		font-weight: 700;
		margin-bottom: 0.5rem;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.app-subtitle {
		font-size: 1.1rem;
		opacity: 0.9;
		font-weight: 300;
	}

	/* Auth Section */
	.mobile-auth-section {
		flex: 1;
		display: flex;
		flex-direction: column;
		justify-content: center;
	}

	.mobile-auth-form {
		background: rgba(255, 255, 255, 0.1);
		backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 24px;
		padding: 2.5rem 2rem;
		margin-bottom: 2rem;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
	}

	.form-header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.form-header h2 {
		font-size: 1.75rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
	}

	.form-header p {
		opacity: 0.8;
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

	.field-group label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		margin-bottom: 1rem;
		opacity: 0.9;
	}

	/* Quick Access Digits */
	.quick-access-digits {
		display: flex;
		gap: 0.75rem;
		justify-content: center;
		align-items: center;
		margin: 1rem 0;
	}

	.digit-input {
		width: 48px;
		height: 60px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 12px;
		text-align: center;
		font-size: 1.5rem;
		font-weight: 600;
		font-family: 'JetBrains Mono', 'Courier New', monospace;
		background: rgba(255, 255, 255, 0.1);
		color: white;
		transition: all 0.3s ease;
		box-sizing: border-box;
		padding: 0;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		touch-action: manipulation;
		backdrop-filter: blur(10px);
	}

	.digit-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.8);
		background: rgba(255, 255, 255, 0.2);
		box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.2);
	}

	.digit-input.error {
		border-color: #EF4444;
		background: rgba(239, 68, 68, 0.1);
	}

	.digit-input:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.digit-input::placeholder {
		color: rgba(255, 255, 255, 0.5);
		font-weight: 400;
	}

	.field-error {
		color: #FCA5A5;
		font-size: 0.75rem;
		margin-top: 0.5rem;
		display: block;
		text-align: center;
	}

	/* Submit button */
	.mobile-submit-btn {
		width: 100%;
		padding: 1.25rem 1.5rem;
		background: rgba(255, 255, 255, 0.9);
		color: #1D4ED8;
		border: none;
		border-radius: 16px;
		font-size: 1.1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 56px;
		backdrop-filter: blur(10px);
	}

	.mobile-submit-btn:hover:not(:disabled) {
		background: white;
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
	}

	.mobile-submit-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.mobile-submit-btn:disabled {
		background: rgba(255, 255, 255, 0.3);
		color: rgba(255, 255, 255, 0.7);
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(29, 78, 216, 0.3);
		border-top: 2px solid #1D4ED8;
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
		margin-bottom: 1rem;
		border-radius: 16px;
		animation: messageSlideIn 0.4s ease-out;
		backdrop-filter: blur(20px);
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
		background: rgba(239, 68, 68, 0.2);
		border: 1px solid rgba(239, 68, 68, 0.3);
		color: #FCA5A5;
	}

	.success-status {
		background: rgba(34, 197, 94, 0.2);
		border: 1px solid rgba(34, 197, 94, 0.3);
		color: #86EFAC;
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

	/* Mobile Features */
	.mobile-features {
		background: rgba(255, 255, 255, 0.1);
		backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 20px;
		padding: 1.5rem;
		margin-top: auto;
	}

	.mobile-features h3 {
		font-size: 1.1rem;
		font-weight: 600;
		margin-bottom: 1rem;
		text-align: center;
		opacity: 0.9;
	}

	.feature-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.feature-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		font-size: 0.875rem;
		opacity: 0.8;
	}

	.feature-item svg {
		flex-shrink: 0;
		opacity: 0.7;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.mobile-login-content {
			padding: 1.5rem 1rem;
		}

		.mobile-auth-form {
			padding: 2rem 1.5rem;
		}

		.digit-input {
			width: 44px;
			height: 56px;
			font-size: 1.3rem;
		}

		.quick-access-digits {
			gap: 0.5rem;
		}

		.app-title {
			font-size: 2rem;
		}

		.logo-icon {
			width: 100px;
			height: 100px;
		}

		.logo-image {
			width: 65px;
			height: 65px;
		}
	}

	@media (max-width: 375px) {
		.digit-input {
			width: 40px;
			height: 52px;
			font-size: 1.2rem;
		}

		.quick-access-digits {
			gap: 0.4rem;
		}
	}

	/* Landscape mode adjustments */
	@media (orientation: landscape) and (max-height: 500px) {
		.mobile-login-content {
			padding: 1rem;
		}

		.mobile-header {
			margin-bottom: 1.5rem;
		}

		.logo-icon {
			width: 80px;
			height: 80px;
			margin-bottom: 1rem;
		}

		.logo-image {
			width: 50px;
			height: 50px;
		}

		.app-title {
			font-size: 1.75rem;
		}

		.mobile-auth-form {
			padding: 1.5rem;
		}

		.mobile-features {
			padding: 1rem;
		}
	}
</style>