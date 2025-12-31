<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { localeData, _, switchLocale, currentLocale } from '$lib/i18n';
	import { persistentAuthService, currentUser, isAuthenticated } from '$lib/utils/persistentAuth';

	function t(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	let interfaceChoice: 'desktop' | 'mobile' | null = null;
	let loginMethod: 'username' | 'quickAccess' = 'username';
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	let username = '';
	let password = '';
	let rememberMe = false;

	let quickAccessCode = '';
	let quickAccessDigits = ['', '', '', '', '', ''];

	let usernameValid = true;
	let passwordValid = true;
	let quickAccessValid = true;

	let mounted = false;
	let showContent = false;
	let logoClickCount = 0;
	let showCustomerButton = false;

	onMount(async () => {
		mounted = true;
		setTimeout(() => {
			showContent = true;
		}, 300);

		checkExistingAuth();
	});

	function checkExistingAuth() {
		if ($isAuthenticated && $currentUser) {
			goto('/');
		}
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
			goto('/mobile-interface/login');
		} else {
			interfaceChoice = 'desktop';
			clearForm();
		}
	}

	function goBackToChoice() {
		interfaceChoice = null;
		clearForm();
	}

	function goBackToMain() {
		goto('/login');
	}

	function handleLogoClick() {
		logoClickCount++;
		if (logoClickCount === 10) {
			showCustomerButton = true;
		} else if (logoClickCount > 10) {
			logoClickCount = 0;
			showCustomerButton = false;
		}
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

	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			quickAccessDigits[index] = value.slice(-1);
			input.value = quickAccessDigits[index];
			
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
		
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (quickAccessDigits[index] !== '') {
				quickAccessDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
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
		
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		for (let i = 0; i < 6; i++) {
			quickAccessDigits[i] = digits[i] || '';
			const input = document.getElementById(`digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = quickAccessDigits[i];
			}
		}
		
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
	<title>Employee Login - Aqura Management System</title>
	<meta name="description" content="Access your Aqura Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

<div class="login-page" class:mounted>
	{#if showContent}
		<div class="login-content">
			<div class="login-main-card">
				<div class="logo-section">
					<div class="logo-header">
						<div class="logo">
							<button 
								on:click={handleLogoClick}
								class="logo-btn"
								type="button"
								title="Logo"
								aria-label="Aqura Logo"
							>
								<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
							</button>
						</div>
						<button 
							class="language-toggle-main" 
							on:click={() => {
								switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
								setTimeout(() => {
									window.location.reload();
								}, 100);
							}}
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

				<div class="auth-section">
					{#if interfaceChoice === null}
						<div class="interface-choice">
							<button 
								class="back-btn-top"
								on:click={goBackToMain}
								disabled={isLoading}
							>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.back')}
							</button>

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

								<button 
									class="interface-btn cashier-btn"
									on:click={() => goto('/cashier-interface')}
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

								{#if showCustomerButton}
									<button 
										class="interface-btn customer-btn"
										on:click={() => goto('/customer-interface/login')}
										disabled={isLoading}
										type="button"
										title="Customer Login"
									>
										<div class="interface-icon">
											<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<circle cx="12" cy="12" r="9"/>
												<circle cx="12" cy="12" r="1"/>
												<path d="M12 8v-1"/>
												<path d="M12 17v1"/>
												<path d="M16 12h1"/>
												<path d="M7 12h-1"/>
											</svg>
										</div>
										<span class="interface-label">Customer</span>
									</button>
								{/if}
							</div>
						</div>
					{:else}
						<div class="desktop-login-header">
							<button 
								class="back-btn"
								on:click={goBackToChoice}
								disabled={isLoading}
							>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.backToInterfaceChoice')}
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
									<h3>{t('common.usernameAndPassword')}</h3>
									<p>{t('common.traditionalLoginMethod')}</p>
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
									<h3>{t('common.quickAccessCode')}</h3>
									<p>{t('common.sixDigitSecureAccess')}</p>
								</div>
							</button>
						</div>

						<div class="auth-forms">
							{#if loginMethod === 'username'}
								<form class="auth-form" on:submit|preventDefault={handleUsernameLogin}>
									<div class="form-header">
										<h2>{t('common.welcomeBack')}</h2>
										<p>{t('common.enterCredentials')}</p>
									</div>

									<div class="form-fields">
										<div class="field-group">
											<label for="username">{t('common.username')}</label>
											<input 
												id="username"
												type="text" 
												class="field-input"
												class:error={!usernameValid}
												bind:value={username}
												on:input={validateUsername}
												placeholder={t('common.enterUsername')}
												disabled={isLoading}
												autocomplete="username"
											/>
											{#if !usernameValid}
												<span class="field-error">{t('common.usernameMustBeThreeCharacters')}</span>
											{/if}
										</div>

										<div class="field-group">
											<label for="password">{t('common.password')}</label>
											<input 
												id="password"
												type="password" 
												class="field-input"
												class:error={!passwordValid}
												bind:value={password}
												on:input={validatePassword}
												placeholder={t('common.enterPassword')}
												disabled={isLoading}
												autocomplete="current-password"
											/>
											{#if !passwordValid}
												<span class="field-error">{t('common.passwordMustBeSixCharacters')}</span>
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
												{t('common.rememberMeThirtyDays')}
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
											{t('common.signingIn')}
										{:else}
											<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
												<polyline points="10,17 15,12 10,7"/>
												<line x1="15" y1="12" x2="3" y2="12"/>
											</svg>
											{t('common.signInToSystem')}
										{/if}
									</button>
								</form>
							{:else}
								<form class="auth-form" on:submit|preventDefault={handleQuickAccessLogin}>
									<div class="form-header">
										<h2>{t('common.quickAccess')}</h2>
										<p>{t('common.enterSixDigitSecurityCode')}</p>
									</div>

									<div class="form-fields">
										<div class="field-group">
											<label for="quickAccess">{t('common.securityCode')}</label>
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
												<span class="field-error">{t('common.enterValidSixDigitCode')}</span>
											{/if}
										</div>

										<div class="field-spacer"></div>

										<div class="form-options">
											<label class="checkbox-option">
												<input 
													type="checkbox" 
													bind:checked={rememberMe}
													disabled={isLoading}
												/>
												<span class="checkbox-mark"></span>
												{t('common.rememberThisDevice')}
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
											{t('common.accessSystem')}
										{/if}
									</button>
								</form>
							{/if}
						</div>
					{/if}
				</div>

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
							<h4>{t('common.authenticationFailed')}</h4>
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
							<h4>{t('common.accessGranted')}</h4>
							<p>{successMessage}</p>
						</div>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
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
		-webkit-overflow-scrolling: touch;
		position: relative;
	}

	:global(input, select, textarea) {
		font-size: 16px !important;
	}

	.login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 1rem;
		padding-top: 2rem;
		background: #F9FAFB;
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	.login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(245, 158, 11, 0.03) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(21, 163, 74, 0.03) 0%, transparent 50%),
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
		margin: 1rem 0;
		min-height: 0;
	}

	.login-main-card {
		background: #FFFFFF;
		border-radius: 20px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0;
		margin-bottom: 2rem;
	}

	.logo-section {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		gap: 1.5rem;
		min-height: 400px;
	}

	.logo-header {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		width: 100%;
	}

	.logo {
		width: 180px;
		height: 110px;
		background: white;
		border: 5px solid #F59E0B;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 20px rgba(245, 158, 11, 0.6),
			0 0 40px rgba(245, 158, 11, 0.4);
		animation: logoPulse 3s ease-in-out infinite;
	}

	@keyframes logoPulse {
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

	.logo-btn {
		border: none;
		background: none;
		padding: 0;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.2s ease;
	}

	.logo-btn:hover {
		transform: scale(1.05);
	}

	.logo-btn:active {
		transform: scale(0.98);
	}

	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.625rem 1.25rem;
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.3);
		border-color: rgba(255, 255, 255, 0.5);
	}

	.auth-section {
		padding: 2.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.interface-choice {
		width: 100%;
	}

	.back-btn-top {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #F3F4F6;
		border: 1px solid #E5E7EB;
		color: #374151;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		margin-bottom: 1rem;
	}

	.back-btn-top:hover {
		background: #E5E7EB;
		border-color: #D1D5DB;
	}

	.interface-options {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
		justify-items: center;
		margin-top: 1rem;
	}

	.interface-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 1.5rem 1rem;
		background: #F8FAFC;
		border: 2px solid #E2E8F0;
		border-radius: 12px;
		cursor: pointer;
		transition: all 0.3s ease;
		min-width: 140px;
		text-align: center;
	}

	.interface-btn:hover:not(:disabled) {
		border-color: #667eea;
		background: rgba(102, 126, 234, 0.05);
		transform: translateY(-2px);
	}

	.interface-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.interface-icon {
		color: #667eea;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.interface-label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.customer-btn .interface-icon {
		color: #8B5CF6;
	}

	.customer-btn:hover:not(:disabled) {
		border-color: #8B5CF6;
		background: rgba(139, 92, 246, 0.08);
	}

	.desktop-login-header {
		margin-bottom: 1rem;
	}

	.back-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #F3F4F6;
		border: 1px solid #E5E7EB;
		color: #374151;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
	}

	.back-btn:hover:not(:disabled) {
		background: #E5E7EB;
		border-color: #D1D5DB;
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.method-selector {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.method-btn {
		display: flex;
		gap: 0.75rem;
		padding: 1rem;
		background: #F8FAFC;
		border: 2px solid #E2E8F0;
		border-radius: 12px;
		cursor: pointer;
		transition: all 0.3s ease;
		align-items: flex-start;
	}

	.method-btn:hover:not(:disabled) {
		border-color: #667eea;
		background: rgba(102, 126, 234, 0.05);
	}

	.method-btn.active {
		border-color: #667eea;
		background: rgba(102, 126, 234, 0.1);
	}

	.method-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.method-icon {
		flex-shrink: 0;
		color: #667eea;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-top: 0.125rem;
	}

	.method-info {
		flex: 1;
	}

	.method-info h3 {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.25rem 0;
	}

	.method-info p {
		font-size: 0.75rem;
		color: #6B7280;
		margin: 0;
	}

	.auth-forms {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.auth-form {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.form-header {
		text-align: center;
		margin-bottom: 0.5rem;
	}

	.form-header h2 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1F2937;
		margin: 0 0 0.5rem 0;
	}

	.form-header p {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0;
	}

	.form-fields {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.field-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.field-group label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.field-input {
		padding: 0.75rem 1rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 1rem;
		transition: all 0.3s ease;
		background: white;
	}

	.field-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.field-input.error {
		border-color: #DC2626;
		background: rgba(220, 38, 38, 0.05);
	}

	.field-error {
		font-size: 0.75rem;
		color: #DC2626;
	}

	.quick-access-digits {
		display: grid;
		grid-template-columns: repeat(6, 1fr);
		gap: 0.5rem;
	}

	.digit-input {
		width: 100%;
		padding: 0.75rem 0;
		border: none;
		border-bottom: 2px solid #D1D5DB;
		border-radius: 0;
		font-size: 1.25rem;
		font-weight: 600;
		text-align: center;
		transition: all 0.3s ease;
		background: transparent;
	}

	.digit-input:focus {
		outline: none;
		border-bottom-color: #667eea;
		box-shadow: 0 2px 0 #667eea;
	}

	.digit-input.error {
		border-bottom-color: #DC2626;
	}

	.field-spacer {
		height: 0;
	}

	.form-options {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.checkbox-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #374151;
		cursor: pointer;
		user-select: none;
	}

	.checkbox-option input {
		width: 16px;
		height: 16px;
		cursor: pointer;
	}

	.checkbox-mark {
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}

	.auth-submit-btn {
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		min-height: 48px;
	}

	.auth-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
	}

	.auth-submit-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading-spinner {
		display: inline-block;
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.status-message {
		display: flex;
		gap: 1rem;
		padding: 1rem 1.25rem;
		border-radius: 8px;
		margin-top: 1rem;
		align-items: flex-start;
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
		.login-main-card {
			grid-template-columns: 1fr;
		}

		.logo-section {
			min-height: auto;
			padding: 2rem 1.5rem;
		}

		.logo {
			width: 140px;
			height: 85px;
		}

		.logo-image {
			width: 95px;
			height: 55px;
		}

		.auth-section {
			padding: 1.5rem;
		}

		.method-selector {
			grid-template-columns: 1fr;
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

	@media (max-width: 480px) {
		.login-page {
			padding: 0.75rem;
			padding-top: 1rem;
			padding-bottom: 3rem;
		}

		.login-content {
			max-width: 100%;
		}

		.login-main-card {
			grid-template-columns: 1fr;
		}

		.logo-section {
			min-height: auto;
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 120px;
			height: 75px;
		}

		.logo-image {
			width: 85px;
			height: 50px;
		}

		.auth-section {
			padding: 1.5rem 1rem;
		}

		.form-header h2 {
			font-size: 1.125rem;
		}

		.method-selector {
			grid-template-columns: 1fr;
		}

		.method-btn {
			padding: 0.5rem;
		}

		.interface-options {
			grid-template-columns: 1fr;
		}

		.interface-btn {
			width: 100%;
		}
	}

	@media (max-width: 320px) {
		.login-page {
			padding: 0.5rem;
			padding-top: 0.5rem;
			padding-bottom: 4rem;
		}

		.logo {
			width: 100px;
			height: 65px;
		}

		.logo-image {
			width: 70px;
			height: 40px;
		}
	}

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
			text-align: center;
			gap: 0.75rem;
			padding: 1rem;
		}

		.method-icon {
			width: 32px;
			height: 32px;
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
	}
</style>
